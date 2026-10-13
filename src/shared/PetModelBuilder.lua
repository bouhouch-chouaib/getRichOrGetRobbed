--!strict
-- PetModelBuilder : fabrique le modèle 3D d'un familier.
-- 1. Si le familier a un vrai modèle 3D en assets (shared/PetMeshes), on clone ce modèle (préparé au démarrage
--    côté client ; tant qu'il n'est pas prêt, on utilise les solutions suivantes, puis MeshesReady est déclenché).
-- 2. Si ReplicatedStorage.PetModels contient un Model nommé comme l'Id du familier, on le clone.
-- 3. Sinon, on assemble un modèle de remplacement à partir de formes de base (PetCatalog.Look).
-- Le modèle retourné est ancré, sans collision, avec un PrimaryPart "Root" invisible à l'origine
-- (le familier regarde vers -Z). On le place avec model:PivotTo().
-- Style (15 oct., docs/DIRECTION_ARTISTIQUE.md §5) : les modèles de remplacement sont en VOXELS (tout en blocs à tenons,
-- yeux carrés), la taille dépend de la rareté (Config.Pets.RarityScale) et les raretés Épique+ ont une AURA (particules,
-- lumière, anneau au sol, auréole...). Les pièces de l'aura portent l'attribut "Aura" (retirées des aperçus 2D).

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local PetCatalog = require(script.Parent.PetCatalog)
local PetMeshes = require(script.Parent.PetMeshes)
local PetModelColors = require(script.Parent.PetModelColors)

local PetModelBuilder = {}

-- Déclenché quand les modèles 3D de PetMeshes sont prêts : les scripts qui ont déjà construit des familiers
-- les reconstruisent pour afficher les vrais modèles.
local meshesReady = Instance.new("BindableEvent")
PetModelBuilder.MeshesReady = meshesReady.Event
local meshTemplates: { [string]: Model } = {}

local normalizeCustom: (Model, PetCatalog.Pet) -> Model

local GOLD = Color3.fromRGB(255, 205, 50)
local EYE = Color3.fromRGB(20, 20, 25)
local WHITE = Color3.fromRGB(245, 245, 245)

type Anchors = {
	head: CFrame, -- centre de la tête
	headSize: number,
	top: CFrame, -- dessus du corps
	width: number, -- demi-largeur du corps (pour les ailes)
}

-- Toute pièce est un BLOC (style voxel) : boules et cylindres deviennent des pavés de même taille. Les blocs assez
-- larges portent des tenons sur le dessus.
local function part(model: Model, _shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
	local studded = not neon and size.X >= 0.9 and size.Z >= 0.9
	p.TopSurface = if studded then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
-- Un cylindre Roblox a son axe sur X : UPRIGHT le met debout, FORWARD le pointe vers -Z.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local FORWARD = CFrame.Angles(0, math.pi / 2, 0)

-- Yeux carrés façon pixel : un carré noir avec un reflet blanc (grands yeux : blanc puis pupille noire).
local function eyes(model: Model, head: CFrame, size: number, big: boolean?)
	local eyeSize = size * (if big then 0.36 else 0.22)
	local depth = 0.08
	for _, side in ipairs({ -1, 1 }) do
		local offset = CFrame.new(side * size * 0.24, size * 0.1, -size * 0.5 - depth / 2)
		if big then
			part(model, BLOCK, Vector3.new(eyeSize, eyeSize, depth), head * offset * CFrame.new(0, size * 0.12, 0), WHITE)
			part(model, BLOCK, Vector3.new(eyeSize * 0.5, eyeSize * 0.5, depth), head * offset * CFrame.new(0, size * 0.1, -depth), EYE)
		else
			part(model, BLOCK, Vector3.new(eyeSize, eyeSize * 1.2, depth), head * offset, EYE)
			part(model, BLOCK, Vector3.new(eyeSize * 0.4, eyeSize * 0.4, depth), head * offset * CFrame.new(eyeSize * 0.18, eyeSize * 0.25, -depth * 0.6), WHITE)
		end
	end
end

----------------------------------------------------------------------
-- Silhouettes
----------------------------------------------------------------------

local function quadruped(model: Model, look: PetCatalog.Look): Anchors
	local length = if look.Long then 4 else 2.2
	part(model, BLOCK, Vector3.new(1.6, 1.2, length), CFrame.new(0, 0, 0), look.Body)
	local head = CFrame.new(0, 0.6, -length / 2 - 0.35)
	part(model, BLOCK, Vector3.new(1.3, 1.2, 1.2), head, look.Body)
	part(model, BLOCK, Vector3.new(0.7, 0.45, 0.4), head * CFrame.new(0, -0.25, -0.7), look.Detail, look.Neon)
	for _, x in ipairs({ -0.5, 0.5 }) do
		for _, z in ipairs({ -length / 2 + 0.4, length / 2 - 0.4 }) do
			part(model, BLOCK, Vector3.new(0.4, 0.8, 0.4), CFrame.new(x, -0.95, z), look.Body)
		end
	end
	part(model, BLOCK, Vector3.new(0.3, 0.3, 1), CFrame.new(0, 0.35, length / 2 + 0.4) * CFrame.Angles(math.rad(25), 0, 0), look.Detail, look.Neon)
	-- Bande de couleur sur le dos (rayures, marques).
	part(model, BLOCK, Vector3.new(1.65, 0.25, length * 0.5), CFrame.new(0, 0.5, 0), look.Detail, look.Neon)
	return { head = head, headSize = 1.2, top = CFrame.new(0, 0.6, 0), width = 0.8 }
end

local function bird(model: Model, look: PetCatalog.Look): Anchors
	if look.Long then
		part(model, BLOCK, Vector3.new(1.4, 1.2, 2.6), CFrame.new(0, 0, 0.2), look.Detail, look.Neon)
	end
	part(model, BALL, Vector3.one * 1.8, CFrame.new(), look.Body)
	part(model, BALL, Vector3.one * 1.2, CFrame.new(0, 0.3, -0.4), look.Detail, look.Neon)
	local head = CFrame.new(0, 1.05, -0.45)
	part(model, BALL, Vector3.one * 1.15, head, look.Body)
	part(model, BLOCK, Vector3.new(0.3, 0.25, 0.5), head * CFrame.new(0, -0.1, -0.7), GOLD)
	for _, side in ipairs({ -1, 1 }) do
		part(model, BLOCK, Vector3.new(0.2, 0.9, 1.2), CFrame.new(side * 0.95, 0.1, 0.1) * CFrame.Angles(0, 0, side * 0.3), look.Body)
		part(model, BLOCK, Vector3.new(0.2, 0.5, 0.2), CFrame.new(side * 0.35, -1, 0), GOLD)
	end
	return { head = head, headSize = 1.15, top = CFrame.new(0, 0.9, 0), width = 0.9 }
end

local function blob(model: Model, look: PetCatalog.Look): Anchors
	if look.Extra == "Cube" then
		local cube = part(model, BLOCK, Vector3.one * 2.2, CFrame.new(), look.Body)
		cube.Transparency = 0.3
	else
		part(model, BALL, Vector3.one * 2.3, CFrame.new(), look.Body, look.Neon)
		for _, side in ipairs({ -1, 1 }) do
			part(model, BALL, Vector3.one * 0.6, CFrame.new(side * 0.6, -1, -0.2), look.Detail)
		end
	end
	return { head = CFrame.new(0, 0.1, 0.1), headSize = 2.2, top = CFrame.new(0, 1.1, 0), width = 1.1 }
end

local function serpent(model: Model, look: PetCatalog.Look): Anchors
	local segments = 8
	if look.Extra == "Ring" then
		for index = 0, segments - 1 do
			local angle = index / segments * math.pi * 2
			part(model, BALL, Vector3.one * 0.9, CFrame.new(math.cos(angle) * 1.4, math.sin(angle) * 1.4, 0), look.Body, look.Neon)
		end
		local head = CFrame.new(0, 1.4, -0.1)
		part(model, BALL, Vector3.one * 1.2, head, look.Body, look.Neon)
		return { head = head, headSize = 1.2, top = CFrame.new(0, 2, 0), width = 1.4 }
	end
	for index = 1, segments do
		local z = (index - 1) * 0.55
		local x = math.sin(index * 0.9) * 0.45
		local color = if index % 2 == 0 then look.Detail else look.Body
		part(model, BALL, Vector3.one * (1 - index * 0.06), CFrame.new(x, -0.3, z), color, look.Neon and index % 2 == 0)
	end
	local head = CFrame.new(0, 0, -0.6)
	part(model, BALL, Vector3.one * 1.2, head, look.Body)
	return { head = head, headSize = 1.2, top = CFrame.new(0, 0.3, 1), width = 0.6 }
end

local function fish(model: Model, look: PetCatalog.Look): Anchors
	part(model, BALL, Vector3.one * 2, CFrame.new(0, 0, -0.3), look.Body)
	part(model, BALL, Vector3.one * 1.6, CFrame.new(0, 0, 0.6), look.Body)
	part(model, BALL, Vector3.one * 1.2, CFrame.new(0, -0.35, -0.2), look.Detail)
	local tail = Instance.new("WedgePart")
	tail.Size = Vector3.new(0.3, 1.4, 1)
	tail.CFrame = CFrame.new(0, 0, 1.7)
	tail.Color = look.Detail
	tail.Material = if look.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	tail.Parent = model
	return { head = CFrame.new(0, 0.15, -0.4), headSize = 1.8, top = CFrame.new(0, 1, 0), width = 0.9 }
end

local function plant(model: Model, look: PetCatalog.Look): Anchors
	local extra = look.Extra
	if extra == "Pot" then
		part(model, CYL, Vector3.new(1, 1.6, 1.6), CFrame.new(0, -0.9, 0) * UPRIGHT, look.Detail)
	elseif not look.Float then
		part(model, BALL, Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, -1.2, 0), Color3.fromRGB(110, 75, 45))
	end

	if extra == "Flower" then
		part(model, CYL, Vector3.new(1.6, 0.25, 0.25), CFrame.new(0, -0.3, 0) * UPRIGHT, Color3.fromRGB(70, 170, 60))
		local head = CFrame.new(0, 0.9, 0)
		part(model, CYL, Vector3.new(0.3, 2.4, 2.4), head * FORWARD, look.Body, look.Neon)
		part(model, CYL, Vector3.new(0.4, 1.2, 1.2), head * CFrame.new(0, 0, -0.1) * FORWARD, look.Detail)
		return { head = head * CFrame.new(0, 0, -0.1), headSize = 1.2, top = CFrame.new(0, 2, 0), width = 1.2 }
	elseif extra == "Mushroom" then
		part(model, CYL, Vector3.new(1.4, 0.8, 0.8), CFrame.new(0, -0.4, 0) * UPRIGHT, WHITE)
		part(model, BALL, Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 0.6, 0), look.Body)
		for index = 1, 5 do
			local angle = index * 1.25
			part(model, BALL, Vector3.one * 0.4, CFrame.new(math.cos(angle) * 0.8, 1.3, math.sin(angle) * 0.8), look.Detail)
		end
		return { head = CFrame.new(0, -0.3, 0.05), headSize = 0.8, top = CFrame.new(0, 1.8, 0), width = 1.2 }
	elseif extra == "Tree" then
		part(model, CYL, Vector3.new(1.8, 0.6, 0.6), CFrame.new(0, -0.3, 0) * UPRIGHT, look.Detail, look.Neon)
		part(model, BALL, Vector3.one * 2.2, CFrame.new(0, 1.2, 0), look.Body)
		part(model, BALL, Vector3.one * 1.4, CFrame.new(0.8, 1.8, 0.3), look.Body)
		return { head = CFrame.new(0, 1.2, 0), headSize = 2, top = CFrame.new(0, 2.4, 0), width = 1.1 }
	elseif extra == "Clover" then
		for index = 0, 3 do
			local angle = index * math.pi / 2
			part(model, BALL, Vector3.one * 1.1, CFrame.new(math.cos(angle) * 0.6, 0.7 + math.sin(angle) * 0.6, 0), look.Body)
		end
		local head = CFrame.new(0, 0.7, -0.2)
		return { head = head, headSize = 1.2, top = CFrame.new(0, 1.6, 0), width = 1.2 }
	elseif extra == "Jaws" then
		part(model, CYL, Vector3.new(1.4, 0.4, 0.4), CFrame.new(0, -0.3, 0) * UPRIGHT, look.Detail, look.Neon)
		local head = CFrame.new(0, 1, 0)
		part(model, BALL, Vector3.one * 1.8, head * CFrame.new(0, 0.4, 0), look.Body, look.Neon)
		part(model, BALL, Vector3.one * 1.6, head * CFrame.new(0, -0.4, 0), look.Detail, look.Neon)
		for index = -2, 2 do
			part(model, BLOCK, Vector3.new(0.15, 0.4, 0.15), head * CFrame.new(index * 0.3, 0, -0.8), WHITE)
		end
		return { head = head, headSize = 1.6, top = CFrame.new(0, 2, 0), width = 0.9 }
	elseif extra == "Fractal" then
		for level = 0, 4 do
			local size = 1.6 * (0.7 ^ level)
			part(model, BLOCK, Vector3.one * size, CFrame.new(0, level * 0.9, 0) * CFrame.Angles(0, level * 0.6, math.rad(45)), look.Body, true)
		end
		return { head = CFrame.new(0, 0, 0), headSize = 1.6, top = CFrame.new(0, 3.8, 0), width = 1 }
	end

	-- Par défaut : tige + tête ronde avec des yeux (haricot, cactus, navet).
	part(model, CYL, Vector3.new(1.2, 0.3, 0.3), CFrame.new(0, -0.2, 0) * UPRIGHT, Color3.fromRGB(70, 170, 60))
	local head = CFrame.new(0, 0.9, 0)
	part(model, BALL, Vector3.one * 1.8, head, look.Body, look.Neon)
	if extra == "Leaf" then
		part(model, BLOCK, Vector3.new(1.2, 0.15, 0.6), head * CFrame.new(0.4, 1, 0) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(70, 190, 60))
	end
	return { head = head, headSize = 1.8, top = CFrame.new(0, 1.8, 0), width = 0.9 }
end

local function humanoid(model: Model, look: PetCatalog.Look, offset: CFrame?): Anchors
	local base = offset or CFrame.new()
	part(model, BLOCK, Vector3.new(1.4, 1.4, 0.8), base * CFrame.new(0, -0.2, 0), look.Detail, look.Neon)
	for _, side in ipairs({ -1, 1 }) do
		part(model, BLOCK, Vector3.new(0.6, 1.2, 0.7), base * CFrame.new(side * 0.4, -1.4, 0), Color3.fromRGB(60, 160, 60))
		part(model, BLOCK, Vector3.new(0.5, 1.3, 0.6), base * CFrame.new(side * 1, -0.2, 0), look.Body)
	end
	local head = base * CFrame.new(0, 1.1, 0)
	part(model, BLOCK, Vector3.new(1.1, 1.1, 1.1), head, look.Body)
	return { head = head, headSize = 1.1, top = base * CFrame.new(0, 1.7, 0), width = 1.2 }
end

local function object(model: Model, look: PetCatalog.Look): Anchors
	local extra = look.Extra
	if extra == "Twin" then
		for _, side in ipairs({ -1, 1 }) do
			local color = if side < 0 then look.Body else look.Detail
			part(model, CYL, Vector3.new(2.2, 1.1, 1.1), CFrame.new(side * 0.8, 0, 0) * UPRIGHT, color)
			part(model, CYL, Vector3.new(0.6, 0.5, 0.5), CFrame.new(side * 0.8, 1.4, 0) * UPRIGHT, color)
			eyes(model, CFrame.new(side * 0.8, 0.3, 0), 1.1)
		end
		return { head = CFrame.new(0, 0.3, 0), headSize = 1, top = CFrame.new(0, 1.8, 0), width = 1.4 }
	end

	local size = Vector3.new(1.8, 1.6, 1.4)
	if extra == "Mug" then
		part(model, CYL, Vector3.new(1.8, 1.8, 1.8), CFrame.new() * UPRIGHT, look.Body)
		part(model, CYL, Vector3.new(0.4, 1, 1), CFrame.new(1.1, 0, 0) * FORWARD, look.Body)
		local head = CFrame.new(0, 1, 0)
		part(model, BALL, Vector3.one * 1.3, head, look.Detail)
		return { head = head, headSize = 1.3, top = CFrame.new(0, 1.6, 0), width = 1 }
	end
	part(model, BLOCK, size, CFrame.new(), look.Body)
	part(model, BLOCK, size + Vector3.new(0.05, -1.2, 0.05), CFrame.new(0, 0.55, 0), look.Detail, look.Neon)
	return { head = CFrame.new(0, 0, 0.2), headSize = 1.6, top = CFrame.new(0, size.Y / 2, 0), width = size.X / 2 }
end

local function dragon(model: Model, look: PetCatalog.Look): Anchors
	local anchors = serpent(model, look)
	part(model, BLOCK, Vector3.new(0.4, 0.3, 0.8), anchors.head * CFrame.new(0, -0.2, -0.7), look.Detail, look.Neon)
	for _, side in ipairs({ -1, 1 }) do
		part(model, BLOCK, Vector3.new(0.2, 0.2, 0.8), anchors.head * CFrame.new(side * 0.35, 0.6, 0.2) * CFrame.Angles(math.rad(40), 0, 0), look.Detail, look.Neon)
	end
	return { head = anchors.head, headSize = anchors.headSize, top = CFrame.new(0, 0.3, 1), width = 0.8 }
end

----------------------------------------------------------------------
-- Accessoires et effets
----------------------------------------------------------------------

local function addExtra(model: Model, look: PetCatalog.Look, a: Anchors)
	local extra = look.Extra
	local head, s = a.head, a.headSize
	if extra == "Wings" then
		for _, side in ipairs({ -1, 1 }) do
			part(model, BLOCK, Vector3.new(0.15, 1.2, 1.6), a.top * CFrame.new(side * (a.width + 0.5), 0.3, 0) * CFrame.Angles(0, 0, side * -0.6), look.Detail, look.Neon)
		end
	elseif extra == "Crown" then
		part(model, CYL, Vector3.new(0.4, s * 0.7, s * 0.7), head * CFrame.new(0, s * 0.6, 0) * UPRIGHT, GOLD, true)
	elseif extra == "Horn" then
		part(model, CYL, Vector3.new(1, 0.25, 0.25), head * CFrame.new(0, s * 0.7, -0.2) * CFrame.Angles(math.rad(-30), 0, 0) * UPRIGHT, look.Detail)
	elseif extra == "Propeller" then
		part(model, CYL, Vector3.new(0.5, 0.15, 0.15), head * CFrame.new(0, s * 0.7, 0) * UPRIGHT, look.Detail)
		part(model, BLOCK, Vector3.new(2.4, 0.08, 0.3), head * CFrame.new(0, s * 0.95, 0), look.Detail)
	elseif extra == "Hat" then
		part(model, BALL, Vector3.one * s * 0.6, head * CFrame.new(0, s * 0.75, 0), look.Detail)
	elseif extra == "Rings" then
		local ring = part(model, CYL, Vector3.new(0.1, 3.6, 3.6), CFrame.new() * CFrame.Angles(0.3, 0, math.pi / 2), look.Detail, true)
		ring.Transparency = 0.3
	elseif extra == "ThreeHeads" then
		for _, side in ipairs({ -1, 1 }) do
			local extraHead = head * CFrame.new(side * 1.1, -0.1, 0.2)
			part(model, BLOCK, Vector3.new(1, 1, 1), extraHead, look.Body)
			eyes(model, extraHead, 1)
		end
		part(model, CYL, Vector3.new(0.3, 1.8, 1.8), head * CFrame.new(0, -0.7, 0.3) * UPRIGHT, look.Detail)
	elseif extra == "Bandana" then
		part(model, BLOCK, Vector3.new(1.4, 0.3, 1.3), head * CFrame.new(0, -0.6, 0.1), look.Detail)
	elseif extra == "Coin" then
		part(model, CYL, Vector3.new(0.15, 0.7, 0.7), head * CFrame.new(0, -0.2, -s * 0.8) * FORWARD, GOLD, true)
	elseif extra == "Ears" then
		for _, side in ipairs({ -1, 1 }) do
			part(model, BLOCK, Vector3.new(0.3, 0.5, 0.2), head * CFrame.new(side * s * 0.35, s * 0.6, 0), look.Body)
		end
	elseif extra == "Trunk" then
		part(model, CYL, Vector3.new(1.2, 0.35, 0.35), head * CFrame.new(0, -0.5, -0.8) * CFrame.Angles(math.rad(60), 0, 0) * UPRIGHT, look.Body)
		part(model, BLOCK, Vector3.new(1.4, 0.15, 0.8), head * CFrame.new(0, s * 0.6, 0), Color3.fromRGB(70, 190, 60))
		for index = 1, 6 do
			part(model, BALL, Vector3.one * 0.2, a.top * CFrame.new(math.cos(index) * 0.6, -0.1, math.sin(index * 1.7) * 0.8), look.Detail)
		end
	elseif extra == "Cannon" then
		part(model, CYL, Vector3.new(2, 0.5, 0.5), a.top * CFrame.new(0, 0.4, -0.3) * FORWARD, look.Detail)
	elseif extra == "Exhaust" then
		part(model, CYL, Vector3.new(0.8, 0.4, 0.4), a.top * CFrame.new(0.4, -0.2, 1.3) * FORWARD, look.Detail)
	elseif extra == "Tracks" then
		for _, side in ipairs({ -1, 1 }) do
			part(model, BLOCK, Vector3.new(0.6, 0.7, 2.4), CFrame.new(side * 0.8, -1.2, 0), GOLD, true)
		end
	elseif extra == "Burger" then
		part(model, BLOCK, Vector3.new(1.9, 0.3, 2.3), a.top * CFrame.new(0, 0.2, 0), Color3.fromRGB(90, 200, 70))
		part(model, BLOCK, Vector3.new(1.8, 0.35, 2.2), a.top * CFrame.new(0, 0.5, 0), Color3.fromRGB(120, 60, 35))
		part(model, BALL, Vector3.new(2, 2, 2), a.top * CFrame.new(0, 1.1, 0), look.Detail)
	elseif extra == "Mane" then
		for index = 0, 5 do
			local angle = index / 6 * math.pi * 2
			part(model, BLOCK, Vector3.new(0.5, 0.5, 0.4), head * CFrame.new(math.cos(angle) * 0.9, math.sin(angle) * 0.9, 0.3), look.Detail)
		end
	elseif extra == "Bulb" then
		part(model, BALL, Vector3.one * 1, head * CFrame.new(0, s * 0.8, 0), look.Detail, true)
	elseif extra == "Gear" then
		part(model, CYL, Vector3.new(0.2, 1, 1), a.top * CFrame.new(0, -0.6, -0.7) * FORWARD, look.Detail)
	elseif extra == "Antennas" then
		for _, side in ipairs({ -1, 1 }) do
			part(model, CYL, Vector3.new(1.2, 0.15, 0.15), a.top * CFrame.new(side * 0.5, 0.5, 0.3) * CFrame.Angles(0, 0, side * 0.3) * UPRIGHT, look.Detail)
		end
	elseif extra == "Fin" then
		local fin = Instance.new("WedgePart")
		fin.Size = Vector3.new(0.2, 1, 1)
		fin.CFrame = a.top * CFrame.new(0, 0.3, 0)
		fin.Color = look.Body
		fin.Parent = model
	elseif extra == "Trio" then
		humanoid(model, look, CFrame.new(-1.7, -0.2, 0.3))
		humanoid(model, look, CFrame.new(1.7, -0.2, 0.3))
		eyes(model, CFrame.new(-1.7, 0.9, 0.3), 1.1)
		eyes(model, CFrame.new(1.7, 0.9, 0.3), 1.1)
	end
end

local EFFECTS: { [string]: { Rate: number, Speed: NumberRange, Lifetime: NumberRange, Size: number, Color: Color3, Texture: string? } } = {
	Aura = { Rate = 25, Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(1, 2), Size = 0.6, Color = GOLD },
	Fire = { Rate = 30, Speed = NumberRange.new(2, 4), Lifetime = NumberRange.new(0.4, 0.8), Size = 0.8, Color = Color3.fromRGB(255, 120, 30), Texture = "rbxasset://textures/particles/fire_main.dds" },
	Sparkles = { Rate = 15, Speed = NumberRange.new(1, 2), Lifetime = NumberRange.new(0.8, 1.5), Size = 0.3, Color = GOLD, Texture = "rbxasset://textures/particles/sparkles_main.dds" },
	Smoke = { Rate = 10, Speed = NumberRange.new(1, 2), Lifetime = NumberRange.new(1.5, 2.5), Size = 1, Color = Color3.fromRGB(60, 60, 65), Texture = "rbxasset://textures/particles/smoke_main.dds" },
	Snow = { Rate = 12, Speed = NumberRange.new(0.5, 1), Lifetime = NumberRange.new(1.5, 2.5), Size = 0.25, Color = WHITE },
	Bubbles = { Rate = 8, Speed = NumberRange.new(1, 2), Lifetime = NumberRange.new(1, 2), Size = 0.35, Color = Color3.fromRGB(180, 230, 255) },
	Coins = { Rate = 6, Speed = NumberRange.new(1, 2), Lifetime = NumberRange.new(1, 1.5), Size = 0.35, Color = GOLD },
	Spores = { Rate = 12, Speed = NumberRange.new(0.5, 1), Lifetime = NumberRange.new(1.5, 2.5), Size = 0.2, Color = Color3.fromRGB(180, 90, 255) },
	Music = { Rate = 4, Speed = NumberRange.new(1, 2), Lifetime = NumberRange.new(1, 1.5), Size = 0.4, Color = Color3.fromRGB(255, 120, 200) },
	Steam = { Rate = 10, Speed = NumberRange.new(2, 3), Lifetime = NumberRange.new(0.8, 1.4), Size = 0.7, Color = WHITE, Texture = "rbxasset://textures/particles/smoke_main.dds" },
	Pulse = { Rate = 6, Speed = NumberRange.new(0, 0), Lifetime = NumberRange.new(0.6, 0.8), Size = 3, Color = Color3.fromRGB(0, 255, 255) },
}

local function addEffect(root: BasePart, look: PetCatalog.Look)
	local effect = look.Effect and EFFECTS[look.Effect]
	if not effect then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Effect"
	emitter.Rate = effect.Rate
	emitter.Speed = effect.Speed
	emitter.Lifetime = effect.Lifetime
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.6
	emitter.Color = ColorSequence.new(look.EffectColor or effect.Color)
	emitter.Size = NumberSequence.new(effect.Size, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	if effect.Texture then
		emitter.Texture = effect.Texture
	end
	emitter.Parent = root
end

----------------------------------------------------------------------
-- API
----------------------------------------------------------------------

local SHAPES: { [string]: (Model, PetCatalog.Look) -> Anchors } = {
	Quadruped = quadruped,
	Bird = bird,
	Blob = blob,
	Serpent = serpent,
	Fish = fish,
	Plant = plant,
	Humanoid = function(model, look)
		return humanoid(model, look)
	end,
	Object = object,
	Dragon = dragon,
}

local function finalize(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
end

-- Hauteur visée d'un familier selon sa rareté (même gabarit que les modèles de remplacement).
local function rarityScale(rarityId: string): number
	local rarityIndex = Config.RarityIndex[rarityId] or 1
	return Config.Pets.RarityScale[rarityIndex] or 1
end

local function targetHeight(rarityId: string): number
	return 3.2 * rarityScale(rarityId)
end

----------------------------------------------------------------------
-- Auras de rareté (Épique et au-delà)
----------------------------------------------------------------------

type AuraDef = {
	Color: Color3,
	Color2: Color3,
	Texture: string,
	Rate: number,
	Speed: NumberRange,
	Size: number,
	Rise: number, -- accélération vers le haut des particules
	Light: number, -- portée de la lumière (0 = pas de lumière)
	Ring: boolean, -- anneau lumineux au sol
	Halo: boolean, -- auréole au-dessus de la tête
	Rays: boolean, -- rayons dorés tout autour
}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local AURAS: { [string]: AuraDef } = {
	Epique = { Color = Color3.fromRGB(180, 80, 255), Color2 = Color3.fromRGB(110, 40, 200), Texture = SMOKE, Rate = 6, Speed = NumberRange.new(0.5, 1.2), Size = 1.4, Rise = 1.5, Light = 0, Ring = true, Halo = false, Rays = false },
	Legendaire = { Color = Color3.fromRGB(255, 170, 40), Color2 = Color3.fromRGB(255, 80, 20), Texture = FIRE, Rate = 14, Speed = NumberRange.new(1, 2.5), Size = 1.2, Rise = 4, Light = 12, Ring = true, Halo = false, Rays = false },
	Mythique = { Color = Color3.fromRGB(255, 80, 150), Color2 = Color3.fromRGB(255, 200, 240), Texture = SPARKLE, Rate = 18, Speed = NumberRange.new(3, 6), Size = 0.7, Rise = 0, Light = 14, Ring = true, Halo = false, Rays = false },
	Divin = { Color = Color3.fromRGB(140, 255, 245), Color2 = Color3.new(1, 1, 1), Texture = SPARKLE, Rate = 20, Speed = NumberRange.new(0.5, 1.5), Size = 0.8, Rise = -1, Light = 16, Ring = true, Halo = true, Rays = false },
	Sigma = { Color = Color3.fromRGB(255, 215, 60), Color2 = Color3.fromRGB(255, 255, 200), Texture = SPARKLE, Rate = 26, Speed = NumberRange.new(1, 3), Size = 1, Rise = 2, Light = 20, Ring = true, Halo = true, Rays = true },
}

local function auraPart(model: Model, size: Vector3, cframe: CFrame, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = "AuraPart"
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transparency
	p.CastShadow = false
	p:SetAttribute("Aura", true)
	p.Parent = model
	return p
end

-- Ajoute l'aura de la rareté au modèle déjà mis à sa taille finale.
local function addAura(model: Model, root: BasePart, rarityId: string)
	local def = AURAS[rarityId]
	if not def then
		return
	end
	local box, size = model:GetBoundingBox()
	local center = root.CFrame:ToObjectSpace(box)
	local radius = math.max(size.X, size.Z) / 2 + 0.6
	local bottom = center.Position.Y - size.Y / 2
	local top = center.Position.Y + size.Y / 2

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Texture = def.Texture
	emitter.Color = ColorSequence.new(def.Color, def.Color2)
	emitter.LightEmission = 0.8
	emitter.Rate = def.Rate
	emitter.Speed = def.Speed
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, def.Rise, 0)
	emitter.Size = NumberSequence.new(def.Size * math.max(size.Y / 3, 1), 0)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.25), NumberSequenceKeypoint.new(1, 1) })
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	-- L'émetteur couvre le corps du familier : on le pose sur une pièce invisible de la taille du familier.
	local volume = Instance.new("Part")
	volume.Name = "AuraVolume"
	volume.Size = size * 0.8
	volume.CFrame = root.CFrame * center
	volume.Transparency = 1
	volume:SetAttribute("Aura", true)
	volume.Parent = model
	emitter.Parent = volume

	if def.Light > 0 then
		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = def.Color
		light.Range = def.Light
		light.Brightness = 1.2
		light.Parent = volume
	end
	if def.Ring then
		-- Anneau carré lumineux au sol (4 barres) + dalle pâle.
		local y = bottom + 0.06
		for _, angle in ipairs({ 0, math.pi / 2, math.pi, -math.pi / 2 }) do
			local offset = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
			auraPart(model, Vector3.new(radius * 2 + 0.3, 0.12, 0.3), root.CFrame * CFrame.new(center.Position.X, y, center.Position.Z) * offset, def.Color, 0.15)
		end
		auraPart(model, Vector3.new(radius * 2, 0.06, radius * 2), root.CFrame * CFrame.new(center.Position.X, y - 0.02, center.Position.Z), def.Color, 0.75)
	end
	if def.Halo then
		local haloRadius = math.max(size.X, size.Z) * 0.28 + 0.4
		for _, angle in ipairs({ 0, math.pi / 2, math.pi, -math.pi / 2 }) do
			local offset = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -haloRadius)
			auraPart(model, Vector3.new(haloRadius * 2 + 0.25, 0.2, 0.25), root.CFrame * CFrame.new(center.Position.X, top + 0.8, center.Position.Z) * offset, def.Color2, 0)
		end
	end
	if def.Rays then
		for index = 0, 7 do
			local angle = index / 8 * math.pi * 2
			local ray = auraPart(model, Vector3.new(0.25, size.Y * 1.2, 0.25), root.CFrame * CFrame.new(center.Position.X, bottom + size.Y * 0.6, center.Position.Z) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius - 0.4), def.Color, 0.35)
			ray.Name = "AuraRay"
		end
	end
end

-- Prépare un modèle 3D importé (ReplicatedStorage.PetModels.<Id>) pour qu'il se comporte comme les autres :
--   - tourné pour regarder vers -Z (les fichiers .glb/.fbx regardent en général vers +Z : 180° par défaut,
--     réglable avec l'attribut "FacingYaw" en degrés sur le Model),
--   - mis à la hauteur standard de sa rareté (attribut "HeightScale" sur le Model pour l'ajuster),
--   - centré sur un "Root" invisible à l'origine (comme les modèles de remplacement).
function normalizeCustom(custom: Model, entry: PetCatalog.Pet): Model
	local source = custom:Clone()
	-- Boîte englobante du contenu importé SEUL, mesurée avant d'ajouter le Root à l'origine : un modèle importé
	-- loin de l'origine (ex. Capybara Zen à Y = -78) donnerait sinon une boîte énorme et un modèle minuscule.
	local box, contentSize = source:GetBoundingBox()
	local model = Instance.new("Model")
	model.Name = entry.Id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.2
	root.Transparency = 1
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	for _, child in ipairs(source:GetChildren()) do
		child.Parent = model
	end
	source:Destroy()

	-- Couleurs perdues à l'import : on les réapplique (PetModelColors), avec un rendu lisse "cartoon".
	local colors = PetModelColors[entry.Id]
	if colors then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and colors[descendant.Name] then
				descendant.Color = colors[descendant.Name]
				descendant.Material = Enum.Material.SmoothPlastic
			end
		end
	end

	-- Centre de la boîte englobante du contenu importé -> origine, puis rotation.
	local yaw = custom:GetAttribute("FacingYaw")
	local yawDegrees = if type(yaw) == "number" then yaw else 180
	local offset = CFrame.Angles(0, math.rad(yawDegrees), 0) * CFrame.new(-box.Position)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= root then
			descendant.CFrame = offset * descendant.CFrame
		end
	end

	-- La rotation autour de l'axe vertical ne change pas la hauteur : contentSize.Y reste valable.
	local heightScale = custom:GetAttribute("HeightScale")
	local wanted = targetHeight(entry.Rarity) * (if type(heightScale) == "number" then heightScale else 1)
	if contentSize.Y > 0 then
		model:ScaleTo(wanted / contentSize.Y)
	end

	addAura(model, root, entry.Rarity)
	finalize(model)
	addEffect(root, entry.Look)
	model:SetAttribute("Float", entry.Look.Float == true)
	return model
end

-- Prépare un vrai modèle 3D de PetMeshes (forme + texture recréées à partir des assets).
local function loadMesh(petId: string, def: PetMeshes.MeshDef)
	local entry = PetCatalog.ById[petId]
	if not entry then
		warn("[PetModelBuilder] PetMeshes : familier inconnu " .. petId)
		return
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(def.MeshId))
	end)
	if ok and typeof(result) == "Instance" and result:IsA("MeshPart") then
		result.Name = "Mesh"
		result.TextureID = def.TextureId
		local source = Instance.new("Model")
		source:SetAttribute("FacingYaw", def.FacingYaw or 180)
		source:SetAttribute("HeightScale", def.HeightScale or 1)
		result.Parent = source
		meshTemplates[petId] = normalizeCustom(source, entry)
		source:Destroy()
	else
		warn(string.format("[PetModelBuilder] Modèle 3D de %s non chargé : %s", petId, tostring(result)))
	end
end

-- Tous les modèles sont chargés en même temps ; MeshesReady quand le dernier est prêt.
local function loadMeshes()
	local pending = 0
	for petId, def in pairs(PetMeshes) do
		pending += 1
		task.spawn(function()
			loadMesh(petId, def)
			pending -= 1
			if pending == 0 then
				meshesReady:Fire()
			end
		end)
	end
	if pending == 0 then
		meshesReady:Fire()
	end
end
if RunService:IsClient() then
	task.spawn(loadMeshes)
end

-- Construit le modèle du familier petId (nil si l'Id est inconnu).
function PetModelBuilder.Build(petId: string): Model?
	local entry = PetCatalog.ById[petId]
	if not entry then
		return nil
	end

	local template = meshTemplates[petId]
	if template then
		return template:Clone()
	end

	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	local custom = folder and folder:FindFirstChild(petId)
	if custom and custom:IsA("Model") then
		return normalizeCustom(custom, entry)
	end

	local look = entry.Look
	local model = Instance.new("Model")
	model.Name = petId

	local root = part(model, BLOCK, Vector3.one * 0.2, CFrame.new(), WHITE)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root

	local build: (Model, PetCatalog.Look) -> Anchors = SHAPES[look.Shape] or blob
	local anchors = build(model, look)
	if look.Shape ~= "Object" or (look.Extra ~= "Twin") then
		eyes(model, anchors.head, anchors.headSize, look.Extra == "BigEyes")
	end
	addExtra(model, look, anchors)
	addEffect(root, look)

	-- Taille selon la rareté (les plus rares dépassent largement l'avatar), puis aura.
	model:ScaleTo(rarityScale(entry.Rarity))
	addAura(model, root, entry.Rarity)

	finalize(model)
	model:SetAttribute("Float", look.Float == true)
	return model
end

return PetModelBuilder
