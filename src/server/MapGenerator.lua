--!strict
-- MapGenerator : construit l'arène (prairie, chemins de terre, trou noir, bases clôturées, arbres).
-- Ne contient aucune logique de jeu : il ne fait que poser les pièces.
-- L'éclairage jour/nuit est géré par DayNightController.
--
-- Structure générée :
-- Workspace.Map
--   ArenaFloor, HoleDirt, HoleRing, BlackholeZone (+ Aura), BlackholeCore (+ Light), BlackholeHalo, BlackholeDome
--   Paths (Folder), Trees (Folder), Kiosks (Folder : boutique + machine de fusion entre deux bases)
--   LooseItems (Folder) : objets ramassés / lancés
--   Base_1 .. Base_N (Model) : BasePart, Fence (Folder), Gate, LockButton (+ LockSign), SpawnLocation,
--                              SafeZone (invisible), Treadmill + Bench (Models à l'extérieur, cachés tant que non achetés),
--                              SpawnPoints (Folder), ItemSpawns (Folder)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapGenerator = {}

local ARENA = Config.Arena
-- Une Part "Cylinder" a son axe sur X : on la couche pour en faire un disque horizontal.
local FLAT = CFrame.Angles(0, 0, math.pi / 2)

local COLORS = {
	Grass = Color3.fromRGB(96, 178, 72),
	BaseGrass = Color3.fromRGB(120, 196, 88),
	Dirt = Color3.fromRGB(150, 108, 66),
	WoodRail = Color3.fromRGB(150, 102, 58),
	WoodPost = Color3.fromRGB(112, 74, 42),
	Trunk = Color3.fromRGB(110, 76, 46),
	Leaves = Color3.fromRGB(64, 150, 62),
}

local FENCE_HEIGHT = 4
local FENCE_GAP = 14 -- largeur de l'entrée côté trou noir

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Pièce purement visuelle : ne bloque rien, n'est ni touchée ni raycastée.
local function makeGhost(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- Texte des panneaux dans le décor : police cartoon + gros contour noir (style Steal a Brainrot).
local function styleSignText(label: TextLabel, color: Color3)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
end

local function makeDisc(name: string, radius: number, thickness: number, topY: number, color: Color3, parent: Instance): Part
	local disc = makePart(
		name,
		Vector3.new(thickness, radius * 2, radius * 2),
		CFrame.new(0, topY - thickness / 2, 0) * FLAT,
		color,
		parent
	)
	disc.Shape = Enum.PartType.Cylinder
	return disc
end

local function applyLighting()
	Lighting.GlobalShadows = true

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 199, 199)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting
end

local function createBlackhole(map: Folder)
	local feeding = Config.Colors.Feeding

	makeDisc("ArenaFloor", ARENA.FloorRadius, 4, 0, COLORS.Grass, map).Material = Enum.Material.Grass

	local dirt = makeDisc("HoleDirt", ARENA.HoleRadius + 10, 0.2, 0.15, COLORS.Dirt, map)
	dirt.Material = Enum.Material.Ground
	makeGhost(dirt)

	local ring = makeDisc("HoleRing", ARENA.HoleRadius + 3, 0.3, 0.3, feeding, map)
	ring.Material = Enum.Material.Neon
	makeGhost(ring)

	-- Zone de consommation : disque noir de 80x80. La détection se fait par distance
	-- dans BlackholeController (pas de .Touched, qui rate les objets rapides).
	local zone = makeDisc("BlackholeZone", ARENA.HoleRadius, 0.4, 0.5, Color3.fromRGB(5, 0, 12), map)
	zone.CanCollide = false
	zone.CanTouch = false
	zone:SetAttribute("CanConsume", false)

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Rate = 60
	aura.Lifetime = NumberRange.new(1, 2)
	aura.Speed = NumberRange.new(6, 12)
	aura.SpreadAngle = Vector2.new(20, 20)
	aura.EmissionDirection = Enum.NormalId.Right -- "Right" = haut une fois le cylindre couché
	aura.LightEmission = 1
	aura.Color = ColorSequence.new(feeding)
	aura.Size = NumberSequence.new(2, 0)
	aura.Transparency = NumberSequence.new(0, 1)
	aura.Parent = zone

	local core = makePart("BlackholeCore", Vector3.new(18, 18, 18), CFrame.new(0, 9, 0), Color3.new(0, 0, 0), map)
	core.Shape = Enum.PartType.Ball
	makeGhost(core)

	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Range = 60
	light.Brightness = 3
	light.Color = feeding
	light.Parent = core

	local halo = makePart("BlackholeHalo", Vector3.new(24, 24, 24), CFrame.new(0, 9, 0), feeding, map)
	halo.Shape = Enum.PartType.Ball
	halo.Material = Enum.Material.ForceField
	halo.Transparency = 0.2
	makeGhost(halo)

	-- Dôme répulsif : visible seulement en Digesting. Purement visuel,
	-- la répulsion est gérée par distance dans BlackholeController.
	local diameter = ARENA.DomeRadius * 2
	local dome = makePart("BlackholeDome", Vector3.new(diameter, diameter, diameter), CFrame.new(), Config.Colors.Digesting, map)
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.ForceField
	dome.Transparency = 1
	makeGhost(dome)
end

-- Chemin de terre entre une base et le trou noir.
local function createPath(direction: Vector3, folder: Folder)
	local startRadius = ARENA.HoleRadius + 8
	local endRadius = ARENA.BaseRingRadius - ARENA.BaseSize.Z / 2 + 2
	local middle = (startRadius + endRadius) / 2
	local path = makePart(
		"Path",
		Vector3.new(12, 0.2, endRadius - startRadius),
		CFrame.lookAt(direction * middle + Vector3.new(0, 0.1, 0), Vector3.new(0, 0.1, 0)),
		COLORS.Dirt,
		folder
	)
	path.Material = Enum.Material.Ground
	makeGhost(path)
end

-- Clôture en bois entre deux points (coordonnées XZ locales à la base).
local function createFenceLine(origin: CFrame, top: number, from: Vector2, to: Vector2, folder: Folder)
	local length = (to - from).Magnitude
	local a = Vector3.new(from.X, 0, from.Y)
	local b = Vector3.new(to.X, 0, to.Y)
	local middle = (a + b) / 2

	for _, height in ipairs({ 1.4, 3 }) do
		local y = Vector3.new(0, top + height, 0)
		local rail = makePart(
			"Rail",
			Vector3.new(0.4, 0.6, length),
			origin * CFrame.lookAt(middle + y, b + y),
			COLORS.WoodRail,
			folder
		)
		rail.Material = Enum.Material.Wood
	end

	local postCount = math.max(1, math.ceil(length / 6))
	for index = 0, postCount do
		local point = a:Lerp(b, index / postCount)
		local post = makePart(
			"Post",
			Vector3.new(1, FENCE_HEIGHT, 1),
			origin * CFrame.new(point + Vector3.new(0, top + FENCE_HEIGHT / 2, 0)),
			COLORS.WoodPost,
			folder
		)
		post.Material = Enum.Material.Wood
	end
end

local function createFence(origin: CFrame, top: number, base: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Fence"
	folder.Parent = base

	local h = ARENA.BaseSize.X / 2 - 0.5
	local gap = FENCE_GAP / 2
	-- Arrière, gauche, droite, puis l'avant (côté trou noir) en deux morceaux pour laisser l'entrée.
	createFenceLine(origin, top, Vector2.new(-h, h), Vector2.new(h, h), folder)
	createFenceLine(origin, top, Vector2.new(-h, -h), Vector2.new(-h, h), folder)
	createFenceLine(origin, top, Vector2.new(h, -h), Vector2.new(h, h), folder)
	createFenceLine(origin, top, Vector2.new(-h, -h), Vector2.new(-gap, -h), folder)
	createFenceLine(origin, top, Vector2.new(gap, -h), Vector2.new(h, -h), folder)
end

local function createTree(position: Vector3, scale: number, folder: Folder)
	local trunkHeight = 10 * scale
	local trunk = makePart(
		"Trunk",
		Vector3.new(trunkHeight, 2.5 * scale, 2.5 * scale),
		CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)) * FLAT,
		COLORS.Trunk,
		folder
	)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Material = Enum.Material.Wood

	local leaves = makePart(
		"Leaves",
		Vector3.one * 12 * scale,
		CFrame.new(position + Vector3.new(0, trunkHeight + 3 * scale, 0)),
		COLORS.Leaves,
		folder
	)
	leaves.Shape = Enum.PartType.Ball
	leaves.Material = Enum.Material.Grass

	local top = makePart(
		"Leaves",
		Vector3.one * 8 * scale,
		CFrame.new(position + Vector3.new(1.5 * scale, trunkHeight + 8 * scale, -1 * scale)),
		COLORS.Leaves,
		folder
	)
	top.Shape = Enum.PartType.Ball
	top.Material = Enum.Material.Grass
end

local function createTrees(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Trees"
	folder.Parent = map

	local rng = Random.new(42) -- graine fixe : la forêt est toujours la même
	local step = math.pi * 2 / ARENA.BaseCount
	for index = 0, ARENA.BaseCount - 1 do
		-- Entre deux bases, puis derrière chaque base.
		local spots = { { angle = index * step, radius = ARENA.BaseRingRadius + 67 } }
		-- Entre deux bases, sauf là où se trouve un kiosque (boutique + fusion, un toutes les deux bases).
		if index % 2 == 1 then
			table.insert(spots, { angle = (index + 0.5) * step, radius = ARENA.BaseRingRadius + 30 })
		end
		for _, spot in ipairs(spots) do
			local position = Vector3.new(math.cos(spot.angle) * spot.radius, 0, math.sin(spot.angle) * spot.radius)
			createTree(position, rng:NextNumber(0.9, 1.3), folder)
		end
	end
end

-- Panneau au-dessus d'une station d'entraînement (texte mis à jour par TrainingController).
local function createStationSign(model: Model, adornee: BasePart, title: string)
	local sign = Instance.new("BillboardGui")
	sign.Name = "StationSign"
	sign.Adornee = adornee
	sign.Size = UDim2.fromScale(16, 4)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 250
	sign.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = title
	styleSignText(label, Color3.fromRGB(255, 230, 90))
	label.Parent = sign
	sign.Parent = model
end

-- Les pièces marquées "Tint" prennent la couleur/matière du niveau de la station.
local function tint(part: BasePart)
	part:SetAttribute("Tint", true)
end

local function hideStation(model: Model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
			makeGhost(part)
		end
	end
end

local function createTreadmill(cframe: CFrame, base: Model)
	local model = Instance.new("Model")
	model.Name = "Treadmill"
	local belt = makePart("Zone", Vector3.new(10, 0.6, 20), cframe * CFrame.new(0, 0.3, 0), Color3.fromRGB(45, 45, 50), model)
	belt.Material = Enum.Material.Fabric
	for _, side in ipairs({ -5.5, 5.5 }) do
		tint(makePart("Rail", Vector3.new(1, 1.2, 20), cframe * CFrame.new(side, 0.6, 0), COLORS.WoodPost, model))
		tint(makePart("Handle", Vector3.new(0.6, 3.5, 0.6), cframe * CFrame.new(side, 2.3, -9), COLORS.WoodPost, model))
	end
	tint(makePart("Console", Vector3.new(11.6, 1.2, 1.2), cframe * CFrame.new(0, 4, -9), COLORS.WoodPost, model))
	createStationSign(model, belt, "TAPIS DE COURSE")
	hideStation(model)
	model.Parent = base
end

local function createBench(cframe: CFrame, base: Model)
	local model = Instance.new("Model")
	model.Name = "Bench"
	local mat = makePart("Zone", Vector3.new(12, 0.3, 16), cframe * CFrame.new(0, 0.15, 0), Color3.fromRGB(45, 45, 50), model)
	mat.Material = Enum.Material.Fabric
	tint(makePart("Seat", Vector3.new(3, 1, 9), cframe * CFrame.new(0, 2, 1), COLORS.WoodPost, model))
	for _, z in ipairs({ -2.5, 4.5 }) do
		tint(makePart("Leg", Vector3.new(2.4, 1.6, 1), cframe * CFrame.new(0, 0.8, z), COLORS.WoodPost, model))
	end
	for _, side in ipairs({ -2.2, 2.2 }) do
		tint(makePart("Upright", Vector3.new(0.6, 5, 0.6), cframe * CFrame.new(side, 2.5, -3.2), COLORS.WoodPost, model))
	end
	local bar = makePart("Bar", Vector3.new(10, 0.35, 0.35), cframe * CFrame.new(0, 5, -3.2), Color3.fromRGB(200, 200, 205), model)
	bar.Shape = Enum.PartType.Cylinder
	for _, side in ipairs({ -4.4, 4.4 }) do
		local plate = makePart("Plate", Vector3.new(0.6, 2.6, 2.6), cframe * CFrame.new(side, 5, -3.2), Color3.fromRGB(35, 35, 40), model)
		plate.Shape = Enum.PartType.Cylinder
	end
	createStationSign(model, mat, "BANC DE MUSCU")
	hideStation(model)
	model.Parent = base
end

-- Grand panneau flottant au-dessus d'un bâtiment (boutique, fusion).
local function createTitleSign(adornee: BasePart, title: string, color: Color3, height: number)
	local sign = Instance.new("BillboardGui")
	sign.Name = "TitleSign"
	sign.Adornee = adornee
	sign.Size = UDim2.fromScale(16, 4)
	sign.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	sign.LightInfluence = 0
	sign.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = title
	styleSignText(label, color)
	label.Parent = sign
	sign.Parent = adornee
end

-- Prompt "[E]" qui ouvre une fenêtre côté client (attribut OpensWindow lu par le HUD).
local function addWindowPrompt(part: BasePart, objectText: string, window: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ouvrir"
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensWindow", window)
	prompt.Parent = part
end

-- Échoppe de marché en bois avec auvent rayé.
local function createShop(cframe: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Shop"
	local wood = COLORS.WoodRail
	local dark = COLORS.WoodPost

	local counter = makePart("Counter", Vector3.new(12, 3.5, 3), cframe * CFrame.new(0, 1.75, -1.5), wood, model)
	counter.Material = Enum.Material.WoodPlanks
	local top = makePart("CounterTop", Vector3.new(12.6, 0.4, 3.6), cframe * CFrame.new(0, 3.7, -1.5), dark, model)
	top.Material = Enum.Material.Wood
	local back = makePart("BackWall", Vector3.new(12, 8, 0.8), cframe * CFrame.new(0, 4, 4), wood, model)
	back.Material = Enum.Material.WoodPlanks
	for _, y in ipairs({ 3.5, 6 }) do
		makePart("Shelf", Vector3.new(11, 0.3, 1.6), cframe * CFrame.new(0, y, 3), dark, model).Material = Enum.Material.Wood
	end
	-- Marchandise sur les étagères (petites caisses et sacs colorés).
	local goods = { Color3.fromRGB(255, 200, 40), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 110, 110), Color3.fromRGB(130, 230, 110) }
	for index = 0, 7 do
		local y = if index < 4 then 4.2 else 6.7
		local x = -4.2 + (index % 4) * 2.8
		makePart("Goods", Vector3.new(1.4, 1.2, 1.2), cframe * CFrame.new(x, y, 3), goods[index % 4 + 1], model)
	end
	for _, x in ipairs({ -6, 6 }) do
		for _, z in ipairs({ -3, 4 }) do
			local post = makePart("Post", Vector3.new(9, 0.7, 0.7), cframe * CFrame.new(x, 4.5, z) * FLAT, dark, model)
			post.Shape = Enum.PartType.Cylinder
			post.Material = Enum.Material.Wood
		end
	end
	-- Auvent rayé rouge / blanc, incliné vers l'avant.
	for index = 0, 6 do
		local color = if index % 2 == 0 then Color3.fromRGB(230, 50, 50) else Color3.fromRGB(250, 245, 235)
		local stripe = makePart("Awning", Vector3.new(2, 0.3, 9), cframe * CFrame.new(-6 + index * 2, 9.4, 0.4) * CFrame.Angles(math.rad(-14), 0, 0), color, model)
		stripe.Material = Enum.Material.Fabric
	end
	makeGhost(makePart("Hitbox", Vector3.new(12, 1, 1), cframe * CFrame.new(0, 2, -3.5), wood, model))
	local hitbox = model:FindFirstChild("Hitbox") :: BasePart
	hitbox.Transparency = 1
	addWindowPrompt(hitbox, "Boutique", "Shop")
	createTitleSign(counter, "🛒 BOUTIQUE", Color3.fromRGB(255, 210, 60), 9.5)
	model.Parent = parent
end

-- Machine de fusion "laboratoire" : deux cuves, une chambre centrale lumineuse, une console.
local function createFusionMachine(cframe: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "FusionMachine"
	local metal = Color3.fromRGB(150, 155, 170)
	local darkMetal = Color3.fromRGB(70, 72, 85)
	local glow = Color3.fromRGB(200, 90, 255)

	local platform = makePart("Platform", Vector3.new(1, 12, 12), cframe * CFrame.new(0, 0.5, 0.5) * FLAT, darkMetal, model)
	platform.Shape = Enum.PartType.Cylinder
	platform.Material = Enum.Material.DiamondPlate

	for _, x in ipairs({ -3.6, 3.6 }) do
		local tube = makePart("Tube", Vector3.new(8, 3, 3), cframe * CFrame.new(x, 5, 2) * FLAT, Color3.fromRGB(200, 230, 255), model)
		tube.Shape = Enum.PartType.Cylinder
		tube.Material = Enum.Material.Glass
		tube.Transparency = 0.5
		local liquid = makePart("Liquid", Vector3.new(5.5, 2.2, 2.2), cframe * CFrame.new(x, 3.8, 2) * FLAT, if x < 0 then Color3.fromRGB(80, 255, 140) else glow, model)
		liquid.Shape = Enum.PartType.Cylinder
		liquid.Material = Enum.Material.Neon
		for _, y in ipairs({ 1.2, 9.2 }) do
			local cap = makePart("Cap", Vector3.new(0.8, 3.6, 3.6), cframe * CFrame.new(x, y, 2) * FLAT, metal, model)
			cap.Shape = Enum.PartType.Cylinder
			cap.Material = Enum.Material.Metal
		end
		-- Tuyau entre la cuve et la chambre centrale.
		local pipe = makePart("Pipe", Vector3.new(3.4, 0.6, 0.6), cframe * CFrame.new(x / 2, 8.4, 2), metal, model)
		pipe.Shape = Enum.PartType.Cylinder
		pipe.Material = Enum.Material.Metal
	end

	local chamber = makePart("Chamber", Vector3.new(5, 5, 5), cframe * CFrame.new(0, 6, 2), Color3.fromRGB(220, 235, 255), model)
	chamber.Shape = Enum.PartType.Ball
	chamber.Material = Enum.Material.Glass
	chamber.Transparency = 0.45
	local core = makePart("Core", Vector3.new(2.6, 2.6, 2.6), cframe * CFrame.new(0, 6, 2), glow, model)
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = 12
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Color = ColorSequence.new(glow)
	sparks.LightEmission = 1
	sparks.Parent = core
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 18
	light.Brightness = 2
	light.Parent = core
	local stand = makePart("Stand", Vector3.new(3.5, 1.4, 1.4), cframe * CFrame.new(0, 2.4, 2) * FLAT, metal, model)
	stand.Shape = Enum.PartType.Cylinder
	stand.Material = Enum.Material.Metal

	-- Console de commande devant la machine.
	local console = makePart("Console", Vector3.new(5, 3, 2), cframe * CFrame.new(0, 1.5, -3.5), darkMetal, model)
	console.Material = Enum.Material.Metal
	local screen = makePart("Screen", Vector3.new(4, 1.4, 0.2), cframe * CFrame.new(0, 3.2, -3.6) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(80, 255, 140), model)
	screen.Material = Enum.Material.Neon
	for index, color in ipairs({ Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 220, 60), Color3.fromRGB(90, 200, 255) }) do
		local knob = makePart("Button", Vector3.new(0.5, 0.8, 0.8), cframe * CFrame.new(-1.4 + (index - 1) * 1.4, 3.05, -4.2) * FLAT, color, model)
		knob.Shape = Enum.PartType.Cylinder
		knob.Material = Enum.Material.Neon
	end
	addWindowPrompt(console, "Machine de fusion", "Fusion")
	createTitleSign(console, "🧪 FUSION", Color3.fromRGB(220, 140, 255), 10)
	model.Parent = parent
end

-- Un "kiosque" entre deux bases : boutique + machine de fusion, sur une dalle de pavés.
local function createKiosks(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Kiosks"
	folder.Parent = map
	local step = math.pi * 2 / ARENA.BaseCount
	for pair = 0, ARENA.BaseCount / 2 - 1 do
		local angle = (pair * 2 + 0.5) * step
		local radius = ARENA.BaseRingRadius - 12
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		-- Repère local : -Z vers le trou noir.
		local origin = CFrame.lookAt(position, Vector3.zero)
		local kiosk = Instance.new("Model")
		kiosk.Name = "Kiosk_" .. (pair + 1)
		local floor = makePart("Floor", Vector3.new(36, 0.2, 18), origin * CFrame.new(0, 0.1, 0.5), Color3.fromRGB(150, 140, 125), kiosk)
		floor.Material = Enum.Material.Cobblestone
		createShop(origin * CFrame.new(-9, 0.2, 0), kiosk)
		createFusionMachine(origin * CFrame.new(9, 0.2, 0), kiosk)
		kiosk.Parent = folder
	end
end

local function createBase(index: number, map: Folder, paths: Folder): Model
	local angle = (index - 1) * (math.pi * 2 / ARENA.BaseCount)
	local position = Vector3.new(math.cos(angle) * ARENA.BaseRingRadius, 0, math.sin(angle) * ARENA.BaseRingRadius)
	-- Repère local de la base : -Z (LookVector) pointe vers le trou noir, Y = 0 au niveau du sol.
	local origin = CFrame.lookAt(position, Vector3.zero)
	local size = ARENA.BaseSize
	local color = Config.BaseColors[(index - 1) % #Config.BaseColors + 1]

	createPath(position.Unit, paths)

	local base = Instance.new("Model")
	base.Name = "Base_" .. index
	base:SetAttribute("BaseIndex", index)

	local platform = makePart("BasePart", size, origin * CFrame.new(0, size.Y / 2, 0), COLORS.BaseGrass, base)
	platform.Material = Enum.Material.Grass

	local top = size.Y -- hauteur du dessus de la plateforme

	createFence(origin, top, base)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = origin * CFrame.new(0, top + 0.5, 18)
	spawn.Color = color
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = base

	-- Zone de sécurité : invisible pour l'instant (pas encore de gameplay associé).
	local safeZone = makePart("SafeZone", Vector3.new(16, 8, 16), origin * CFrame.new(0, top + 4, 18), color, base)
	safeZone.Transparency = 1
	makeGhost(safeZone)

	-- Bouton de verrouillage au sol (géré par LockController) + portail affiché quand la base est fermée.
	local buttonCFrame = origin * CFrame.new(0, top, -17)
	local buttonBase = makePart("LockButtonBase", Vector3.new(0.4, 10, 10), buttonCFrame * CFrame.new(0, 0.2, 0) * FLAT, Color3.fromRGB(60, 60, 65), base)
	buttonBase.Shape = Enum.PartType.Cylinder
	local button = makePart("LockButton", Vector3.new(0.6, 8, 8), buttonCFrame * CFrame.new(0, 0.5, 0) * FLAT, Color3.fromRGB(220, 50, 50), base)
	button.Shape = Enum.PartType.Cylinder
	button.CanCollide = false

	local lockSign = Instance.new("BillboardGui")
	lockSign.Name = "LockSign"
	lockSign.Adornee = button
	lockSign.Size = UDim2.fromScale(12, 3)
	lockSign.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	lockSign.AlwaysOnTop = true
	lockSign.LightInfluence = 0
	lockSign.MaxDistance = 120
	local lockLabel = Instance.new("TextLabel")
	lockLabel.Name = "Label"
	lockLabel.Size = UDim2.fromScale(1, 1)
	lockLabel.BackgroundTransparency = 1
	styleSignText(lockLabel, Color3.new(1, 1, 1))
	lockLabel.Text = "FERMER LA BASE"
	lockLabel.Parent = lockSign
	lockSign.Parent = base

	local half = size.X / 2 - 0.5
	local gate = makePart("Gate", Vector3.new(FENCE_GAP, FENCE_HEIGHT - 0.5, 0.6), origin * CFrame.new(0, top + (FENCE_HEIGHT - 0.5) / 2, -half), COLORS.WoodRail, base)
	gate.Material = Enum.Material.WoodPlanks
	gate.Transparency = 1
	makeGhost(gate)

	-- Stations d'entraînement à l'extérieur de la base (cachées tant qu'elles ne sont pas achetées) :
	-- tapis de course à gauche (Vitesse), banc de développé couché à droite (Force).
	-- TrainingController gère l'affichage, la matière selon le niveau et l'XP.
	createTreadmill(origin * CFrame.new(-half - 10, 0, -4), base)
	createBench(origin * CFrame.new(half + 10, 0, -4), base)

	-- Socles des familiers : 5 de chaque côté de la base (PedestalController y pose les meilleurs familiers).
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = base
	local pedestalIndex = 0
	for _, x in ipairs({ -23, 23 }) do
		for _, z in ipairs({ -10, -4, 2, 8, 14 }) do
			pedestalIndex += 1
			local pedestal = makePart("Pedestal", Vector3.new(1.2, 4.4, 4.4), origin * CFrame.new(x, top + 0.6, z) * FLAT, Color3.fromRGB(235, 225, 205), pedestals)
			pedestal.Shape = Enum.PartType.Cylinder
			pedestal.Material = Enum.Material.Marble
			pedestal:SetAttribute("Index", pedestalIndex)
			-- Le familier regarde vers le centre de la base.
			pedestal:SetAttribute("Facing", if x < 0 then 1 else -1)

			local sign = Instance.new("BillboardGui")
			sign.Name = "PetSign"
			sign.Adornee = pedestal
			sign.Size = UDim2.fromScale(8, 2.6)
			sign.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0) -- recalé selon la taille du familier
			sign.AlwaysOnTop = true
			sign.LightInfluence = 0
			sign.MaxDistance = 90
			sign.Enabled = false
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "PetName"
			nameLabel.Size = UDim2.fromScale(1, 0.55)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = ""
			styleSignText(nameLabel, Color3.new(1, 1, 1))
			nameLabel.Parent = sign
			local incomeLabel = Instance.new("TextLabel")
			incomeLabel.Name = "PetIncome"
			incomeLabel.Position = UDim2.fromScale(0, 0.55)
			incomeLabel.Size = UDim2.fromScale(1, 0.45)
			incomeLabel.BackgroundTransparency = 1
			incomeLabel.Text = ""
			styleSignText(incomeLabel, Color3.fromRGB(110, 240, 70))
			incomeLabel.Parent = sign
			sign.Parent = pedestal
		end
	end

	local spawnPoints = Instance.new("Folder")
	spawnPoints.Name = "SpawnPoints"
	spawnPoints.Parent = base
	for _, offset in ipairs({ Vector2.new(-21, -21), Vector2.new(21, -21), Vector2.new(-21, 21), Vector2.new(21, 21) }) do
		local point = makePart("SpawnPoint", Vector3.new(1, 1, 1), origin * CFrame.new(offset.X, top + 4, offset.Y), color, spawnPoints)
		point.Transparency = 1
		makeGhost(point)
	end

	local itemSpawns = Instance.new("Folder")
	itemSpawns.Name = "ItemSpawns"
	itemSpawns.Parent = base

	local sign = Instance.new("BillboardGui")
	sign.Name = "OwnerSign"
	sign.Adornee = spawn
	sign.Size = UDim2.fromScale(30, 6)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	sign.LightInfluence = 0
	sign.MaxDistance = 500
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	styleSignText(label, color)
	label.Text = "Base libre"
	label.Parent = sign
	sign.Parent = base

	base.PrimaryPart = platform
	base.Parent = map
	return base
end

-- Génère toute la map et retourne la liste ordonnée des bases.
function MapGenerator.generate(): { Model }
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	-- L'ancienne Baseplate du template serait au même niveau que ArenaFloor (z-fighting).
	local oldBaseplate = Workspace:FindFirstChild("Baseplate")
	if oldBaseplate then
		oldBaseplate:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	applyLighting()
	createBlackhole(map)
	createTrees(map)
	createKiosks(map)

	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = map

	local looseItems = Instance.new("Folder")
	looseItems.Name = "LooseItems"
	looseItems.Parent = map

	local bases = {}
	for index = 1, ARENA.BaseCount do
		table.insert(bases, createBase(index, map, paths))
	end

	map.Parent = Workspace
	return bases
end

return MapGenerator
