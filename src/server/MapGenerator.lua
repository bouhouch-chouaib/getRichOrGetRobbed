--!strict
-- MapGenerator : construit l'arène (prairie, chemins, trou noir, bases clôturées, arbres, mur d'enceinte).
-- Ne contient aucune logique de jeu : il ne fait que poser les pièces.
-- L'éclairage jour/nuit est géré par DayNightController.
--
-- Style (docs/DIRECTION_ARTISTIQUE.md) : briques à tenons partout. Les tenons de Roblox ne s'affichent
-- que sur la matière Plastic et sur les faces planes : on construit donc en blocs, et les sols sont des
-- damiers de blocs purement visuels posés sur un sol invisible qui, lui, porte les collisions.
--
-- Structure générée :
-- Workspace.Map
--   ArenaFloor (invisible, collisions), Floor (Folder : dalles du damier), Wall (Folder : enceinte circulaire)
--   HoleRing, BlackholeZone (+ Aura), BlackholeCore (+ Light), BlackholeHalo, BlackholeDome
--   Paths (Folder, vide : les chemins sont des dalles de couleur), Trees (Folder),
--   Kiosks (Folder : boutique + machine de fusion entre deux bases)
--   Leaderboard (Model) : tableau des plus riches (Screen rempli par LeaderboardController)
--   LooseItems (Folder) : objets ramassés / lancés
--   Base_1 .. Base_N (Model) : BasePart, Fence (Folder), Gate, LockButton (+ LockSign), SpawnLocation (invisible), Pallets,
--                              SafeZone (invisible), Treadmill + Bench (Models à l'extérieur, cachés tant que non achetés),
--                              SpawnPoints (Folder), ItemSpawns (Folder), Incubator (Folder : couveuse, nids Nest_1..12),
--                              <Monde>Look (Folders PrairieLook, DesertLook... : clôture, porte, escalier du monde ;
--                              client/WorldSkin montre celui du monde du propriétaire, sinon l'ancienne clôture).
--                              Plan de la base (entrée, palettes, prairie, couveuse) : shared/BaseLayout.

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BaseLayout = require(ReplicatedStorage.Shared.BaseLayout)
local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)

local MapGenerator = {}

local ARENA = Config.Arena
-- Une Part "Cylinder" a son axe sur X : on la couche pour en faire un disque horizontal.
local FLAT = CFrame.Angles(0, 0, math.pi / 2)

-- Palette relevée sur les captures de référence (docs/DIRECTION_ARTISTIQUE.md §2) : couleurs pures et saturées.
-- Les paires A / B forment les damiers.
local COLORS = {
	GrassA = Color3.fromRGB(150, 228, 58),
	GrassB = Color3.fromRGB(122, 210, 46),
	PathA = Color3.fromRGB(246, 214, 128),
	PathB = Color3.fromRGB(232, 194, 104),
	HoleA = Color3.fromRGB(70, 46, 112),
	HoleB = Color3.fromRGB(52, 34, 88),
	WallA = Color3.fromRGB(202, 145, 86),
	WallB = Color3.fromRGB(185, 125, 73),
	WallTop = Color3.fromRGB(110, 214, 42),
	Stone = Color3.fromRGB(205, 198, 186),
	WoodRail = Color3.fromRGB(216, 128, 42),
	WoodPost = Color3.fromRGB(96, 76, 70),
	WoodCap = Color3.fromRGB(124, 102, 95),
	Trunk = Color3.fromRGB(138, 90, 51),
	LeavesA = Color3.fromRGB(80, 198, 58),
	LeavesB = Color3.fromRGB(60, 170, 46),
	LeavesC = Color3.fromRGB(104, 218, 74),
}

local FENCE_HEIGHT = 4
local FENCE_GAP = 14 -- largeur de l'entrée côté trou noir
local TILE = 12 -- côté d'une dalle du damier de l'arène
local BASE_TILE = 7 -- côté d'une dalle du damier des bases (84 / 7 = 12 dalles)
local WALL_HEIGHT = 36
local WALL_THICKNESS = 10
local WALL_ROW = 12 -- hauteur d'une rangée du damier du mur

-- Tenons sur les 6 faces (ils ne s'affichent qu'en Plastic).
local function studify(part: BasePart)
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
end

-- Par défaut, toute pièce est un bloc de Plastic à tenons. Les appelants ne changent la matière que pour
-- les effets (Neon, Glass, ForceField).
-- Rôle de chaque couleur de la palette : client/WorldSkin repeint les pièces de ce rôle aux couleurs du monde.
local SKIN_OF: { [string]: string } = {}
for role, color in pairs(COLORS) do
	SKIN_OF[color:ToHex()] = role
end

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	studify(part)
	local role = SKIN_OF[color:ToHex()]
	if role then
		part:SetAttribute("Skin", role)
	end
	part.Parent = parent
	return part
end

-- Pièce purement visuelle : ne bloque rien, n'est ni touchée ni raycastée.
local function makeGhost(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- Objets faits à la main (Blender, 25 oct.) : ReplicatedStorage.ArtModels.<name> (Shop, FusionMachine, EvolutionCapsule),
-- pivot au sol au centre, -Z vers l'avant du repère. Ses pièces sont copiées dans `model` sans collision ; le jeu garde
-- des volumes invisibles pour les collisions, les bulles [E] et les panneaux. Renvoie false s'il n'existe pas.
local function addArt(name: string, cframe: CFrame, model: Model): boolean
	local folder = ReplicatedStorage:FindFirstChild("ArtModels")
	local source = folder and folder:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return false
	end
	local pivot = source:GetPivot()
	for _, descendant in ipairs(source:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= source.PrimaryPart then
			local copy = descendant:Clone()
			for _, child in ipairs(copy:GetChildren()) do
				if not child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			copy.CFrame = cframe * pivot:ToObjectSpace(descendant.CFrame)
			copy.Anchored = true
			makeGhost(copy)
			copy.Parent = model
		end
	end
	return true
end

-- Volume invisible (collision, ancre d'une bulle [E] ou d'un panneau) sous un objet fait à la main.
local function invisible(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Transparency = 1
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- Texte des panneaux dans le décor : police cartoon + gros contour noir (style Steal a Brainrot).
local function styleSignText(label: TextLabel, color: Color3)
	label.FontFace = Typography.Face
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
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

	-- Préréglage « jour » de dataset_and_pipeline/map_art_bible.json (25 oct.). DayNightController fait varier
	-- l'heure, la lumière, le bloom, le contraste, Glare et Haze entre le jour et la nuit ; client/WorldSkin teinte l'air
	-- (Color, Decay, Density) et l'image (TintColor, Saturation) selon le monde.
	Lighting.GeographicLatitude = 35
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.ShadowSoftness = 0.25

	-- Air bleuté qui donne de la profondeur aux falaises lointaines sans ternir l'arène.
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(207, 226, 255)
	atmosphere.Decay = Color3.fromRGB(122, 150, 208)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting

	-- Lueur douce des runes, champignons et cristaux (seuil haut : pas de néon qui bave).
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.45
	bloom.Size = 22
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local grading = Instance.new("ColorCorrectionEffect")
	grading.Saturation = 0.18
	grading.Contrast = 0.08
	grading.TintColor = Color3.fromRGB(255, 250, 240)
	grading.Parent = Lighting

	-- Flou léger du très lointain seulement (falaises, monts) : jamais sur l'arène.
	local depth = Instance.new("DepthOfFieldEffect")
	depth.FarIntensity = 0.12
	depth.FocusDistance = 120
	depth.InFocusRadius = 160
	depth.NearIntensity = 0
	depth.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.04
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting

	-- Gros cumulus blancs (nuages dynamiques du Terrain).
	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.75
	clouds.Color = Color3.new(1, 1, 1)
	clouds.Parent = terrain
end

-- Vrai si le point (x, z) est sur un chemin entre le trou noir et une base.
local function isOnPath(x: number, z: number): boolean
	local startRadius = ARENA.HoleRadius + 8
	local endRadius = ARENA.BaseRingRadius - ARENA.BaseSize.Z / 2 + 2
	for index = 0, ARENA.BaseCount - 1 do
		local angle = index * (math.pi * 2 / ARENA.BaseCount)
		local along = x * math.cos(angle) + z * math.sin(angle)
		local across = math.abs(-x * math.sin(angle) + z * math.cos(angle))
		if along > startRadius and along < endRadius and across < 8 then
			return true
		end
	end
	return false
end

-- Vrai si le point (x, z) est caché sous la plateforme d'une base (inutile d'y poser une dalle).
local function isUnderBase(x: number, z: number): boolean
	local half = ARENA.BaseSize.X / 2 - TILE / 2
	for index = 0, ARENA.BaseCount - 1 do
		local angle = index * (math.pi * 2 / ARENA.BaseCount)
		local dx = x - math.cos(angle) * ARENA.BaseRingRadius
		local dz = z - math.sin(angle) * ARENA.BaseRingRadius
		local along = dx * math.cos(angle) + dz * math.sin(angle)
		local across = -dx * math.sin(angle) + dz * math.cos(angle)
		if math.abs(along) < half and math.abs(across) < half then
			return true
		end
	end
	return false
end

-- Damier de dalles à tenons : purement visuel, posé sur le sol invisible ArenaFloor.
local function createFloor(map: Folder)
	local floor = makeDisc("ArenaFloor", ARENA.FloorRadius, 4, 0, COLORS.GrassA, map)
	floor.Transparency = 1

	local folder = Instance.new("Folder")
	folder.Name = "Floor"
	local count = math.ceil(ARENA.FloorRadius / TILE)
	for gx = -count, count - 1 do
		for gz = -count, count - 1 do
			local x = (gx + 0.5) * TILE
			local z = (gz + 0.5) * TILE
			local radius = math.sqrt(x * x + z * z)
			-- Les dalles du bord dépassent sous le mur d'enceinte : pas de trou au pied du mur.
			if radius <= ARENA.FloorRadius + TILE / 2 and not isUnderBase(x, z) then
				local even = (gx + gz) % 2 == 0
				local color = if radius < ARENA.HoleRadius + 12
					then (if even then COLORS.HoleA else COLORS.HoleB)
					elseif isOnPath(x, z) then (if even then COLORS.PathA else COLORS.PathB)
					else (if even then COLORS.GrassA else COLORS.GrassB)
				local tile = makePart("Tile", Vector3.new(TILE, 1, TILE), CFrame.new(x, -0.5, z), color, folder)
				tile.CastShadow = false
				makeGhost(tile)
			end
		end
	end
	folder.Parent = map
end

-- Mur d'enceinte circulaire en damier, liseré d'herbe sur le dessus (comme les murs de la référence).
local function createWall(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Wall"
	local radius = ARENA.FloorRadius + WALL_THICKNESS / 2 - 2
	local segments = math.ceil(math.pi * 2 * radius / TILE)
	local width = math.pi * 2 * radius / segments + 0.4 -- léger chevauchement : pas de fente entre deux blocs
	local rows = WALL_HEIGHT // WALL_ROW
	for index = 0, segments - 1 do
		local angle = index * (math.pi * 2 / segments)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local origin = CFrame.lookAt(position, Vector3.zero)
		for row = 0, rows - 1 do
			local color = if (index + row) % 2 == 0 then COLORS.WallA else COLORS.WallB
			local block = makePart("Block", Vector3.new(width, WALL_ROW, WALL_THICKNESS), origin * CFrame.new(0, (row + 0.5) * WALL_ROW, 0), color, folder)
			block.CastShadow = row == rows - 1 -- seule la rangée du haut projette l'ombre du mur
		end
		makePart("GrassTop", Vector3.new(width, 1.5, WALL_THICKNESS + 1), origin * CFrame.new(0, WALL_HEIGHT + 0.75, 0), COLORS.WallTop, folder)
	end
	folder.Parent = map
end

local function createBlackhole(map: Folder)
	local feeding = Config.Colors.Feeding

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

-- Clôture en bois entre deux points (coordonnées XZ locales à la base) : deux lisses, une croix entre
-- chaque paire de poteaux, poteaux sombres coiffés d'un chapeau (style ranch de la référence).
local function createFenceLine(origin: CFrame, top: number, from: Vector2, to: Vector2, folder: Folder)
	local length = (to - from).Magnitude
	local a = Vector3.new(from.X, 0, from.Y)
	local b = Vector3.new(to.X, 0, to.Y)
	local middle = (a + b) / 2
	local low = Vector3.new(0, top + 0.9, 0)
	local high = Vector3.new(0, top + FENCE_HEIGHT - 0.6, 0)

	for _, y in ipairs({ low, high }) do
		makePart("Rail", Vector3.new(0.5, 0.7, length), origin * CFrame.lookAt(middle + y, b + y), COLORS.WoodRail, folder)
	end

	local postCount = math.max(1, math.ceil(length / 7))
	for index = 0, postCount do
		local point = a:Lerp(b, index / postCount)
		makePart("Post", Vector3.new(1.2, FENCE_HEIGHT, 1.2), origin * CFrame.new(point + Vector3.new(0, top + FENCE_HEIGHT / 2, 0)), COLORS.WoodPost, folder)
		makePart("Cap", Vector3.new(1.6, 0.5, 1.6), origin * CFrame.new(point + Vector3.new(0, top + FENCE_HEIGHT + 0.25, 0)), COLORS.WoodCap, folder)
		if index < postCount then
			local nextPoint = a:Lerp(b, (index + 1) / postCount)
			for _, ends in ipairs({ { point + low, nextPoint + high }, { point + high, nextPoint + low } }) do
				local span = ends[2] - ends[1]
				makePart("Brace", Vector3.new(0.45, 0.55, span.Magnitude), origin * CFrame.lookAt((ends[1] + ends[2]) / 2, ends[2]), COLORS.WoodRail, folder)
			end
		end
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

-- Habillage « niveau studio » des bases, un par monde (dataset_and_pipeline/MAP.md) : sections de clôture (palissades
-- sur muret en Prairie, muret d'adobe crénelé au Désert), porte à l'entrée, escalier devant. Modèles faits dans Blender,
-- rangés dans ReplicatedStorage.ArtModels.Map (fichier du jeu) ; un monde dont les modèles manquent n'a pas de dossier.
-- Purement visuel : l'ancienne clôture garde les collisions et client/WorldSkin montre l'habillage du monde du
-- propriétaire (ou l'ancienne clôture si ce monde n'a pas encore le sien).
-- Repère des modèles importés : leur face avant (rail, poutres, marches, côté runes) regarde -Z.
local DRESSING_SECTION = 12 -- longueur d'une section de clôture (studs)
local DRESSINGS: { [string]: { Fence: string, Gate: string, Stairs: string } } = {
	Prairie = { Fence = "Palissade", Gate = "ArcheAncienne", Stairs = "EscalierPierre" },
	Desert = { Fence = "Desert_Muret", Gate = "Desert_PorteTemple", Stairs = "Desert_Escalier" },
	Volcan = { Fence = "Volcan_Rempart", Gate = "Volcan_PorteForge", Stairs = "Volcan_Escalier" },
	Glace = { Fence = "Glace_Barriere", Gate = "Glace_PorteGlace", Stairs = "Glace_Escalier" },
	Abysses = { Fence = "Abysses_Muret", Gate = "Abysses_PorteAtlante", Stairs = "Abysses_Escalier" },
	Cosmos = { Fence = "Cosmos_Barriere", Gate = "Cosmos_PorteStellaire", Stairs = "Cosmos_Escalier" },
	Divin = { Fence = "Divin_Balustrade", Gate = "Divin_PorteCeleste", Stairs = "Divin_Escalier" },
	Divin = { Fence = "Divin_Balustrade", Gate = "Divin_PorteCeleste", Stairs = "Divin_Escalier" },
}

local function createDressing(origin: CFrame, top: number, base: Model, worldId: string, library: Instance)
	local spec = DRESSINGS[worldId]
	local fence = library:FindFirstChild(spec.Fence)
	if not (fence and fence:IsA("BasePart")) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = worldId .. "Look"

	local function place(name: string, cframe: CFrame, scale: Vector3)
		local source = library:FindFirstChild(name)
		if not (source and source:IsA("BasePart")) then
			return
		end
		local copy = source:Clone()
		copy.Size = source.Size * scale
		copy.CFrame = origin * cframe * CFrame.new(0, copy.Size.Y / 2, 0)
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.Parent = folder
	end

	local h = ARENA.BaseSize.X / 2 - 0.5
	local gap = FENCE_GAP / 2
	-- Arrière et côtés : 7 sections de 12 studs, face avant tournée vers l'extérieur.
	local count = math.round(ARENA.BaseSize.X / DRESSING_SECTION)
	for i = 0, count - 1 do
		local along = (i + 0.5) * DRESSING_SECTION - ARENA.BaseSize.X / 2
		place(spec.Fence, CFrame.new(along, 0, h) * CFrame.Angles(0, math.pi, 0), Vector3.one)
		place(spec.Fence, CFrame.new(-h, 0, along) * CFrame.Angles(0, math.pi / 2, 0), Vector3.one)
		place(spec.Fence, CFrame.new(h, 0, along) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.one)
	end
	-- Avant : de chaque côté de l'entrée, 3 sections étirées pour finir pile au bord de l'ouverture.
	local span = (ARENA.BaseSize.X / 2 - gap) / 3
	for side = -1, 1, 2 do
		for i = 0, 2 do
			place(spec.Fence, CFrame.new(side * (gap + (i + 0.5) * span), 0, -h), Vector3.new(span / DRESSING_SECTION, 1, 1))
		end
	end
	-- Porte à cheval sur l'entrée (ouverture ~15 studs pour une porte de 14) et escalier qui monte sur la plateforme.
	place(spec.Gate, CFrame.new(0, 0, -h), Vector3.new(0.82, 0.9, 0.82))
	local stairs = library:FindFirstChild(spec.Stairs)
	if stairs and stairs:IsA("BasePart") then
		local depth = stairs.Size.Z
		place(spec.Stairs, CFrame.new(0, 0, -h - 0.5 - depth / 2), Vector3.new(1, top / 1.8, 1))
	end
	folder.Parent = base
end

local function createDressings(origin: CFrame, top: number, base: Model)
	local art = ReplicatedStorage:FindFirstChild("ArtModels")
	local library = art and art:FindFirstChild("Map")
	if not library then
		return
	end
	for worldId in pairs(DRESSINGS) do
		createDressing(origin, top, base, worldId, library)
	end
end

-- Arbre en cubes : tronc carré, feuillage de blocs empilés en trois verts.
local function createTree(position: Vector3, scale: number, folder: Folder)
	local trunkHeight = 10 * scale
	local trunk = makePart("Trunk", Vector3.new(2.6, trunkHeight, 2.6) * Vector3.new(scale, 1, scale), CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)), COLORS.Trunk, folder)
	trunk:SetAttribute("DecorSpot", scale) -- client/WorldSkin y pose le décor du monde (cactus, cristal...)

	local y = trunkHeight
	local leaves = {
		{ size = Vector3.new(12, 5, 12), offset = Vector3.new(0, 2.5, 0), color = COLORS.LeavesB },
		{ size = Vector3.new(9, 4, 9), offset = Vector3.new(0.5, 6.5, -0.5), color = COLORS.LeavesA },
		{ size = Vector3.new(5, 3, 5), offset = Vector3.new(-0.5, 10, 0.5), color = COLORS.LeavesC },
		{ size = Vector3.new(4, 3, 4), offset = Vector3.new(5, 3.5, 4), color = COLORS.LeavesA },
	}
	for _, leaf in ipairs(leaves) do
		makePart("Leaves", leaf.size * scale, CFrame.new(position + Vector3.new(0, y, 0) + leaf.offset * scale), leaf.color, folder)
	end
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

-- Les pièces marquées "Tint" prennent la couleur du modèle de la station (server/StationLooks).
local function tint(part: BasePart)
	part:SetAttribute("Tint", true)
end

local function hideStation(model: Model)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
			makeGhost(part)
		end
	end
end

-- Texte d'un panneau d'amélioration (police cartoon, contour noir).
local function signLine(name: string, text: string, height: number, color: Color3, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, height)
	label.BackgroundTransparency = 1
	label.Text = text
	styleSignText(label, color)
	label.Parent = parent
	return label
end

-- Panneau « Amélioration » planté à côté d'une station (comme dans la référence) : niveau actuel > suivant et prix.
-- Textes écrits par TrainingController ; la bulle [E] « Améliorer » est créée par le client du propriétaire
-- (client/UpgradeSigns). Face avant tournée vers le trou noir.
local function createUpgradeSign(cframe: CFrame, upgradeId: string, model: Model)
	local sign = Instance.new("Model")
	sign.Name = "UpgradeSign"
	sign:SetAttribute("UpgradeId", upgradeId)
	makePart("Post", Vector3.new(0.8, 4.4, 0.8), cframe * CFrame.new(0, 2.2, 0.3), COLORS.WoodPost, sign)
	local board = makePart("Board", Vector3.new(6.4, 3.6, 0.6), cframe * CFrame.new(0, 5.6, 0), Color3.fromRGB(30, 36, 64), sign)
	makePart("Frame", Vector3.new(6.8, 4, 0.4), cframe * CFrame.new(0, 5.6, 0.3), Color3.fromRGB(16, 18, 34), sign)
	board.FrontSurface = Enum.SurfaceType.Smooth
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = gui
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	signLine("Title", "AMÉLIORATION", 0.28, Color3.new(1, 1, 1), gui).LayoutOrder = 1
	signLine("Levels", "", 0.26, Color3.fromRGB(255, 220, 70), gui).LayoutOrder = 2
	signLine("Price", "", 0.32, Color3.fromRGB(120, 255, 90), gui).LayoutOrder = 3
	gui.Parent = board
	sign.Parent = model
end

local function createTreadmill(cframe: CFrame, outward: number, base: Model)
	local model = Instance.new("Model")
	model.Name = "Treadmill"
	local s = Config.Training.TreadmillScale -- tout le tapis est réduit (server/StationLooks fait pareil pour le décor)
	local belt = makePart("Zone", Vector3.new(10 * s, 0.6 * s, 20 * s), cframe * CFrame.new(0, 0.3 * s, 0), Color3.fromRGB(45, 45, 50), model)
	createStationSign(model, belt, "TAPIS DE COURSE")
	createUpgradeSign(cframe * CFrame.new(outward * (5 * s + 4.5), 0, -(10 * s + 2)), "Treadmill", model)
	hideStation(model)
	model.Parent = base
end

local function createBench(cframe: CFrame, outward: number, base: Model)
	local model = Instance.new("Model")
	model.Name = "Bench"
	local mat = makePart("Zone", Vector3.new(12, 0.3, 16), cframe * CFrame.new(0, 0.15, 0), Color3.fromRGB(45, 45, 50), model)
	tint(makePart("Seat", Vector3.new(3, 1, 9), cframe * CFrame.new(0, 2, 1), COLORS.WoodPost, model))
	for _, z in ipairs({ -2.5, 4.5 }) do
		tint(makePart("Leg", Vector3.new(2.4, 1.6, 1), cframe * CFrame.new(0, 0.8, z), COLORS.WoodPost, model))
	end
	for _, side in ipairs({ -2.2, 2.2 }) do
		tint(makePart("Upright", Vector3.new(0.9, 5, 0.9), cframe * CFrame.new(side, 2.5, -3.2), COLORS.WoodPost, model))
	end
	local bar = makePart("Bar", Vector3.new(10, 0.35, 0.35), cframe * CFrame.new(0, 5, -3.2), Color3.fromRGB(200, 200, 205), model)
	bar.Shape = Enum.PartType.Cylinder
	for _, side in ipairs({ -4.4, 4.4 }) do
		local plate = makePart("Plate", Vector3.new(0.6, 2.6, 2.6), cframe * CFrame.new(side, 5, -3.2), Color3.fromRGB(35, 35, 40), model)
		plate.Shape = Enum.PartType.Cylinder
	end
	createStationSign(model, mat, "BANC DE MUSCU")
	createUpgradeSign(cframe * CFrame.new(outward * 9, 0, -9), "Bench", model)
	hideStation(model)
	model.Parent = base
end

-- Grand panneau flottant au-dessus d'un bâtiment (boutique, fusion).
local function createTitleSign(adornee: BasePart, title: string, color: Color3, height: number, icon: string?)
	local sign = Instance.new("BillboardGui")
	sign.Name = "TitleSign"
	sign.Adornee = adornee
	sign.Size = UDim2.fromScale(13, 3.5)
	sign.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	sign.LightInfluence = 0
	sign.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = title
	styleSignText(label, color)
	label.Parent = sign
	if icon then
		-- Icône à gauche du texte, le texte se décale d'autant.
		label.Position = UDim2.fromScale(0.24, 0)
		label.Size = UDim2.fromScale(0.76, 1)
		Icons.image(sign, icon, UDim2.fromScale(0.24, 1))
	end
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
	if addArt("Shop", cframe, model) then
		local counter = invisible("Counter", Vector3.new(12, 3.5, 3), cframe * CFrame.new(0, 1.75, -1.5), model)
		invisible("BackWall", Vector3.new(12, 8, 0.8), cframe * CFrame.new(0, 4, 4), model)
		local hitbox = invisible("Hitbox", Vector3.new(12, 1, 1), cframe * CFrame.new(0, 2, -3.5), model)
		makeGhost(hitbox)
		addWindowPrompt(hitbox, "Boutique", "Shop")
		createTitleSign(counter, "BOUTIQUE", Color3.fromRGB(255, 210, 60), 9.5, "Shop")
		model.Parent = parent
		return
	end
	local wood = COLORS.WoodRail
	local dark = COLORS.WoodPost

	local counter = makePart("Counter", Vector3.new(12, 3.5, 3), cframe * CFrame.new(0, 1.75, -1.5), wood, model)
	makePart("CounterTop", Vector3.new(12.6, 0.4, 3.6), cframe * CFrame.new(0, 3.7, -1.5), dark, model)
	makePart("BackWall", Vector3.new(12, 8, 0.8), cframe * CFrame.new(0, 4, 4), wood, model)
	for _, y in ipairs({ 3.5, 6 }) do
		makePart("Shelf", Vector3.new(11, 0.3, 1.6), cframe * CFrame.new(0, y, 3), dark, model)
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
			makePart("Post", Vector3.new(0.8, 9, 0.8), cframe * CFrame.new(x, 4.5, z), dark, model)
		end
	end
	-- Auvent rayé rouge / blanc, incliné vers l'avant.
	for index = 0, 6 do
		local color = if index % 2 == 0 then Color3.fromRGB(230, 50, 50) else Color3.fromRGB(250, 245, 235)
		makePart("Awning", Vector3.new(2, 0.3, 9), cframe * CFrame.new(-6 + index * 2, 9.4, 0.4) * CFrame.Angles(math.rad(-14), 0, 0), color, model)
	end
	makeGhost(makePart("Hitbox", Vector3.new(12, 1, 1), cframe * CFrame.new(0, 2, -3.5), wood, model))
	local hitbox = model:FindFirstChild("Hitbox") :: BasePart
	hitbox.Transparency = 1
	addWindowPrompt(hitbox, "Boutique", "Shop")
	createTitleSign(counter, "BOUTIQUE", Color3.fromRGB(255, 210, 60), 9.5, "Shop")
	model.Parent = parent
end

-- Machine de fusion "laboratoire" : deux cuves, une chambre centrale lumineuse, une console.
local function createFusionMachine(cframe: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "FusionMachine"
	if addArt("FusionMachine", cframe, model) then
		-- sans néon, sans lumière ni étincelles (Chouaib, 25 oct.)
		local platform = invisible("Platform", Vector3.new(1, 12, 12), cframe * CFrame.new(0, 0.5, 0.5) * FLAT, model)
		platform.Shape = Enum.PartType.Cylinder
		invisible("Body", Vector3.new(11, 10, 4.4), cframe * CFrame.new(0, 6, 2), model)
		local console = invisible("Console", Vector3.new(5, 3, 2), cframe * CFrame.new(0, 1.5, -3.5), model)
		addWindowPrompt(console, "Machine de fusion", "Fusion")
		createTitleSign(console, "FUSION", Color3.fromRGB(220, 140, 255), 14, "Fusion")
		model.Parent = parent
		return
	end
	local metal = Color3.fromRGB(150, 155, 170)
	local darkMetal = Color3.fromRGB(70, 72, 85)
	local glow = Color3.fromRGB(200, 90, 255)

	local platform = makePart("Platform", Vector3.new(1, 12, 12), cframe * CFrame.new(0, 0.5, 0.5) * FLAT, darkMetal, model)
	platform.Shape = Enum.PartType.Cylinder

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
		end
		-- Tuyau entre la cuve et la chambre centrale.
		local pipe = makePart("Pipe", Vector3.new(3.4, 0.6, 0.6), cframe * CFrame.new(x / 2, 8.4, 2), metal, model)
		pipe.Shape = Enum.PartType.Cylinder
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

	-- Console de commande devant la machine.
	local console = makePart("Console", Vector3.new(5, 3, 2), cframe * CFrame.new(0, 1.5, -3.5), darkMetal, model)
	local screen = makePart("Screen", Vector3.new(4, 1.4, 0.2), cframe * CFrame.new(0, 3.2, -3.6) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(80, 255, 140), model)
	screen.Material = Enum.Material.Neon
	for index, color in ipairs({ Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 220, 60), Color3.fromRGB(90, 200, 255) }) do
		local knob = makePart("Button", Vector3.new(0.5, 0.8, 0.8), cframe * CFrame.new(-1.4 + (index - 1) * 1.4, 3.05, -4.2) * FLAT, color, model)
		knob.Shape = Enum.PartType.Cylinder
		knob.Material = Enum.Material.Neon
	end
	addWindowPrompt(console, "Machine de fusion", "Fusion")
	-- Plus haut que BOUTIQUE : vus de biais, les deux panneaux ne se chevauchent pas.
	createTitleSign(console, "FUSION", Color3.fromRGB(220, 140, 255), 14, "Fusion")
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
		makePart("Floor", Vector3.new(36, 0.2, 18), origin * CFrame.new(0, 0.1, 0.5), COLORS.Stone, kiosk)
		createShop(origin * CFrame.new(-9, 0.2, 0), kiosk)
		createFusionMachine(origin * CFrame.new(9, 0.2, 0), kiosk)
		-- (plus de cercles lumineux au sol devant les machines : Chouaib, 25 oct.)
		kiosk.Parent = folder
	end
end

-- Tableau des plus riches : grand panneau en bois sur deux poteaux, face au trou noir (lisible des deux côtés).
-- Le contenu (SurfaceGui sur Screen) est écrit par LeaderboardController.
local function createLeaderboard(map: Folder)
	local settings = Config.Leaderboard
	local angle = math.rad(settings.Angle)
	local position = Vector3.new(math.cos(angle) * settings.Radius, 0, math.sin(angle) * settings.Radius)
	-- Repère local : -Z vers le trou noir (la face avant du panneau regarde le centre).
	local origin = CFrame.lookAt(position, Vector3.zero)
	local model = Instance.new("Model")
	model.Name = "Leaderboard"

	makePart("Floor", Vector3.new(40, 0.2, 14), origin * CFrame.new(0, 0.1, 0), COLORS.Stone, model)
	for _, x in ipairs({ -16.5, 16.5 }) do
		makePart("Post", Vector3.new(2, 27, 2), origin * CFrame.new(x, 13.5, 0), COLORS.WoodPost, model)
	end
	-- Cadre en bois autour de l'écran (30 x 18 studs).
	makePart("Frame", Vector3.new(32, 20, 1), origin * CFrame.new(0, 15, 0), COLORS.WoodRail, model)
	-- Écran lisse : le SurfaceGui du classement s'affiche dessus.
	local screen = makePart("Screen", Vector3.new(30, 18, 1.4), origin * CFrame.new(0, 15, 0), Color3.fromRGB(40, 32, 60), model)
	screen.Material = Enum.Material.SmoothPlastic
	screen.FrontSurface = Enum.SurfaceType.Smooth
	screen.BackSurface = Enum.SurfaceType.Smooth
	makePart("Roof", Vector3.new(36, 1, 4), origin * CFrame.new(0, 25.5, 0), COLORS.WoodPost, model)
	-- Trophée doré au sommet.
	local gold = Color3.fromRGB(255, 200, 40)
	local cup = makePart("Trophy", Vector3.new(3.2, 3.2, 3.2), origin * CFrame.new(0, 28.6, 0), gold, model)
	cup.Shape = Enum.PartType.Ball
	makePart("TrophyFoot", Vector3.new(2.2, 1, 2.2), origin * CFrame.new(0, 26.5, 0), gold, model)
	model.Parent = map
end

-- Palette en bois basse : plateau de lattes sur 3 chevrons, avec un petit rebord pour que les objets
-- ne roulent pas par terre. Les objets restent bien accessibles (pas de parois hautes).
local PALLET_SIZE = 9
local function createPallet(cframe: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Pallet"
	local light = COLORS.WoodRail
	local dark = COLORS.WoodPost
	local half = PALLET_SIZE / 2
	for _, x in ipairs({ -half + 0.5, 0, half - 0.5 }) do
		makePart("Runner", Vector3.new(1, 0.5, PALLET_SIZE), cframe * CFrame.new(x, 0.25, 0), dark, model)
	end
	for index = 0, 4 do
		local z = -half + 0.8 + index * (PALLET_SIZE - 1.6) / 4
		makePart("Board", Vector3.new(PALLET_SIZE, 0.3, 1.4), cframe * CFrame.new(0, 0.65, z), light, model)
	end
	-- Plateau plein (sous les lattes) pour que les petits objets ne passent pas entre elles.
	makePart("Deck", Vector3.new(PALLET_SIZE - 0.2, 0.2, PALLET_SIZE - 0.2), cframe * CFrame.new(0, 0.55, 0), dark, model)
	-- Petit rebord.
	for _, side in ipairs({ -1, 1 }) do
		makePart("Lip", Vector3.new(PALLET_SIZE, 0.45, 0.3), cframe * CFrame.new(0, 1, side * (half - 0.15)), dark, model)
		makePart("Lip", Vector3.new(0.3, 0.45, PALLET_SIZE), cframe * CFrame.new(side * (half - 0.15), 1, 0), dark, model)
	end
	model.Parent = parent
end

-- Couveuse au fond de la base (shared/BaseLayout) : sol de paille, rebord en bois ouvert au milieu, 12 nids et un
-- panneau « COUVEUSE ». Les œufs posés dans les nids sont affichés par client/Eggs (server/EggController).
local STRAW = Color3.fromRGB(240, 202, 96)
local STRAW_DARK = Color3.fromRGB(200, 148, 56)
local function createIncubator(origin: CFrame, top: number, base: Model): BasePart
	local folder = Instance.new("Folder")
	folder.Name = "Incubator"
	local center = BaseLayout.IncubatorCenter
	local half = BaseLayout.IncubatorHalf
	local floor = makePart("Straw", Vector3.new(half.X * 2, 0.2, half.Y * 2), origin * CFrame.new(center.X, top + 0.1, center.Y), STRAW, folder)
	makeGhost(floor)
	-- Rebord côté prairie, ouvert au milieu (les familiers éclos en sortent), et sur les côtés.
	local frontZ = center.Y - half.Y
	local opening = 7
	for _, side in ipairs({ -1, 1 }) do
		local length = half.X - opening
		local curb = makePart("Curb", Vector3.new(length, 0.9, 0.9), origin * CFrame.new(side * (opening + length / 2), top + 0.45, frontZ), COLORS.WoodRail, folder)
		makeGhost(curb)
		local sideCurb = makePart("Curb", Vector3.new(0.9, 0.9, half.Y * 2), origin * CFrame.new(side * half.X, top + 0.45, center.Y), COLORS.WoodRail, folder)
		makeGhost(sideCurb)
		local post = makePart("CurbPost", Vector3.new(1.4, 1.6, 1.4), origin * CFrame.new(side * opening, top + 0.8, frontZ), COLORS.WoodPost, folder)
		makeGhost(post)
	end
	-- Les nids : couronne de paille foncée + lit de paille clair.
	for index = 1, BaseLayout.MAX_NESTS do
		local spot = BaseLayout.Nest(index)
		local cframe = origin * CFrame.new(spot.X, top, spot.Y)
		local ring = makePart("Nest_" .. index, Vector3.new(0.7, 5.4, 5.4), cframe * CFrame.new(0, 0.35, 0) * FLAT, STRAW_DARK, folder)
		ring.Shape = Enum.PartType.Cylinder
		makeGhost(ring)
		local bed = makePart("NestBed", Vector3.new(0.76, 4.2, 4.2), cframe * CFrame.new(0, 0.38, 0) * FLAT, STRAW, folder)
		bed.Shape = Enum.PartType.Cylinder
		makeGhost(bed)
	end
	-- Panneau contre la clôture du fond, lisible depuis l'entrée.
	local boardCFrame = origin * CFrame.new(0, top + 6.5, BaseLayout.HALF - 1.6)
	local board = makePart("IncubatorSign", Vector3.new(24, 4.6, 0.6), boardCFrame, COLORS.WoodPost, folder)
	makeGhost(board)
	for _, side in ipairs({ -1, 1 }) do
		local post = makePart("SignPost", Vector3.new(1, 6.5, 1), origin * CFrame.new(side * 10, top + 3.25, BaseLayout.HALF - 1.6), COLORS.WoodPost, folder)
		makeGhost(post)
	end
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front -- -Z de la pièce : vers l'intérieur de la base
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 24
	surface.LightInfluence = 0.3
	surface.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "COUVEUSE"
	styleSignText(label, STRAW)
	label.Parent = surface
	surface.Parent = board
	folder.Parent = base
	return board
end

-- Capsule d'évolution (Config.Evolution), dehors derrière la base : un cylindre de stase de science-fiction.
-- Socle de métal à tenons, anneau inférieur, cylindre de verre (la brume froide et l'œuf sont ajoutés par
-- client/EvolutionMachine), trois anneaux lumineux, tuyaux, chapeau avec émetteur, console à écran devant.
-- La pièce "EvolutionMachine" (le socle) porte l'état publié par server/EggController et la bulle [E] du client.
local METAL = Color3.fromRGB(150, 158, 176)
local METAL_DARK = Color3.fromRGB(58, 62, 78)
local STASIS = Color3.fromRGB(70, 230, 255)
local function createEvolutionCapsule(origin: CFrame, base: Model)
	local model = Instance.new("Model")
	model.Name = "EvolutionCapsule"
	local spot = BaseLayout.EvolutionCapsule
	local cframe = origin * CFrame.new(spot.X, 0, spot.Y) * CFrame.Angles(0, math.pi, 0) -- console tournée vers la base
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local part = makePart(name, size, cframe * offset, color, model)
		makeGhost(part)
		return part
	end
	local pad = piece("EvolutionMachine", Vector3.new(11, 1.2, 11), CFrame.new(0, 0.6, 0), METAL_DARK)
	pad.CanCollide = true
	pad.CanQuery = true -- la bulle [E] du client s'y accroche
	if addArt("EvolutionCapsule", cframe, model) then
		-- Capsule en briques (Blender, 25 oct.), sans néon : le jeu garde le socle (invisible, bulle [E]), la vitre où
		-- l'on voit l'œuf et l'écran ÉVOLUTION.
		pad.Transparency = 1
		local artGlass = piece("StasisGlass", Vector3.new(9.5, 6.4, 6.4), CFrame.new(0, 2.4 + 4.75, 0) * FLAT, Color3.fromRGB(200, 245, 255))
		artGlass.Shape = Enum.PartType.Cylinder
		artGlass.Material = Enum.Material.Glass
		artGlass.Transparency = 0.6
		local consoleBase = piece("ConsoleBase", Vector3.new(5, 3, 2), CFrame.new(0, 1.5, -6.6), METAL_DARK)
		consoleBase.Transparency = 1
		consoleBase.CanCollide = true
		local artScreen = piece("ConsoleScreen", Vector3.new(4.6, 2.6, 0.4), CFrame.new(0, 3.6, -6.9) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(20, 40, 60))
		local artGui = Instance.new("SurfaceGui")
		artGui.Face = Enum.NormalId.Front
		artGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		artGui.PixelsPerStud = 40
		artGui.LightInfluence = 0
		artGui.MaxDistance = 120
		local artLabel = Instance.new("TextLabel")
		artLabel.Name = "Label"
		artLabel.Size = UDim2.fromScale(1, 1)
		artLabel.BackgroundTransparency = 1
		artLabel.Text = "ÉVOLUTION"
		styleSignText(artLabel, STASIS)
		artLabel.Parent = artGui
		artGui.Parent = artScreen
		model.PrimaryPart = pad
		model.Parent = base
		return
	end
	for _, corner in ipairs({ Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) }) do
		piece("Foot", Vector3.new(2, 0.8, 2), CFrame.new(corner.X * 4.6, 1.4, corner.Y * 4.6), STASIS):SetAttribute("Light", true)
	end
	local lowRing = piece("LowerRing", Vector3.new(1.2, 8.6, 8.6), CFrame.new(0, 1.8, 0) * FLAT, METAL)
	lowRing.Shape = Enum.PartType.Cylinder
	local glass = piece("StasisGlass", Vector3.new(9.5, 6.4, 6.4), CFrame.new(0, 2.4 + 4.75, 0) * FLAT, Color3.fromRGB(200, 245, 255))
	glass.Shape = Enum.PartType.Cylinder
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.6
	for index, height in ipairs({ 3.4, 7.1, 10.8 }) do
		local band = piece("StasisRing" .. index, Vector3.new(0.35, 7, 7), CFrame.new(0, height, 0) * FLAT, STASIS)
		band.Shape = Enum.PartType.Cylinder
		band.Material = Enum.Material.Neon
		band.Transparency = 0.25
	end
	local cap = piece("Cap", Vector3.new(1.4, 8.6, 8.6), CFrame.new(0, 12.6, 0) * FLAT, METAL)
	cap.Shape = Enum.PartType.Cylinder
	piece("CapTop", Vector3.new(5, 1, 5), CFrame.new(0, 13.8, 0), METAL_DARK)
	piece("Emitter", Vector3.new(1.2, 2.4, 1.2), CFrame.new(0, 15.5, 0), METAL)
	local tip = piece("EmitterTip", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 17.4, 0), STASIS)
	tip.Material = Enum.Material.Neon
	-- Tuyaux de chaque côté, du socle au chapeau.
	for _, side in ipairs({ -1, 1 }) do
		local pipe = piece("Pipe", Vector3.new(11, 1, 1), CFrame.new(side * 4.4, 7, 2.6) * CFrame.Angles(0, 0, math.pi / 2), METAL_DARK)
		pipe.Shape = Enum.PartType.Cylinder
		piece("PipeClamp", Vector3.new(1.6, 0.6, 1.6), CFrame.new(side * 4.4, 4, 2.6), METAL)
		piece("PipeClamp", Vector3.new(1.6, 0.6, 1.6), CFrame.new(side * 4.4, 10, 2.6), METAL)
	end
	-- Console inclinée devant, avec son écran.
	piece("ConsoleBase", Vector3.new(5, 3, 2), CFrame.new(0, 1.5, -6.6), METAL_DARK)
	local screen = piece("ConsoleScreen", Vector3.new(4.6, 2.6, 0.4), CFrame.new(0, 3.6, -6.9) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(20, 40, 60))
	local screenGui = Instance.new("SurfaceGui")
	screenGui.Face = Enum.NormalId.Front
	screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screenGui.PixelsPerStud = 40
	screenGui.LightInfluence = 0
	screenGui.MaxDistance = 120
	local screenLabel = Instance.new("TextLabel")
	screenLabel.Name = "Label"
	screenLabel.Size = UDim2.fromScale(1, 1)
	screenLabel.BackgroundTransparency = 1
	screenLabel.Text = "ÉVOLUTION"
	styleSignText(screenLabel, STASIS)
	screenLabel.Parent = screenGui
	screenGui.Parent = screen
	for index = -1, 1 do
		local button = piece("ConsoleButton", Vector3.new(0.6, 0.3, 0.6), CFrame.new(index * 1.4, 3.05, -5.7), if index == 0 then Color3.fromRGB(255, 80, 80) else STASIS)
		button.Material = Enum.Material.Neon
	end
	model.PrimaryPart = pad
	model.Parent = base
end

local function createBase(index: number, map: Folder): Model
	local angle = (index - 1) * (math.pi * 2 / ARENA.BaseCount)
	local position = Vector3.new(math.cos(angle) * ARENA.BaseRingRadius, 0, math.sin(angle) * ARENA.BaseRingRadius)
	-- Repère local de la base : -Z (LookVector) pointe vers le trou noir, Y = 0 au niveau du sol.
	local origin = CFrame.lookAt(position, Vector3.zero)
	local size = ARENA.BaseSize
	local color = Config.BaseColors[(index - 1) % #Config.BaseColors + 1]

	local base = Instance.new("Model")
	base.Name = "Base_" .. index
	base:SetAttribute("BaseIndex", index)

	-- Plateforme invisible (collisions, repère des familiers) recouverte d'un damier de dalles visuelles.
	local platform = makePart("BasePart", size, origin * CFrame.new(0, size.Y / 2, 0), COLORS.GrassA, base)
	platform.Transparency = 1
	local tiles = Instance.new("Folder")
	tiles.Name = "Floor"
	local count = math.floor(size.X / BASE_TILE)
	for gx = 0, count - 1 do
		for gz = 0, count - 1 do
			local x = (gx + 0.5) * BASE_TILE - size.X / 2
			local z = (gz + 0.5) * BASE_TILE - size.Z / 2
			local tileColor = if (gx + gz) % 2 == 0 then COLORS.GrassA else COLORS.GrassB
			local tile = makePart("Tile", Vector3.new(BASE_TILE, size.Y, BASE_TILE), origin * CFrame.new(x, size.Y / 2, z), tileColor, tiles)
			tile.CastShadow = false
			makeGhost(tile)
		end
	end
	tiles.Parent = base

	local top = size.Y -- hauteur du dessus de la plateforme

	createFence(origin, top, base)
	createDressings(origin, top, base)
	local incubatorSign = createIncubator(origin, top, base)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = origin * CFrame.new(BaseLayout.Spawn.X, top + 0.5, BaseLayout.Spawn.Y)
	spawn.Color = color
	-- Invisible : elle sert seulement de point d'apparition (le nom du joueur flotte au-dessus).
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = base

	-- Zone de sécurité : invisible pour l'instant (pas encore de gameplay associé).
	local safeZone = makePart("SafeZone", Vector3.new(16, 8, 16), origin * CFrame.new(BaseLayout.Spawn.X, top + 4, BaseLayout.Spawn.Y), color, base)
	safeZone.Transparency = 1
	makeGhost(safeZone)

	-- Bouton de verrouillage au sol (géré par LockController) + portail affiché quand la base est fermée.
	-- Socle carré sombre bordé de bandes jaunes et noires, gros bouton rond par-dessus.
	local buttonCFrame = origin * CFrame.new(BaseLayout.Lock.X, top, BaseLayout.Lock.Y)
	local pedestal = Instance.new("Model")
	pedestal.Name = "LockPedestal"
	makePart("Plate", Vector3.new(10, 0.5, 10), buttonCFrame * CFrame.new(0, 0.25, 0), Color3.fromRGB(52, 54, 66), pedestal)
	for side = 0, 3 do
		local edge = buttonCFrame * CFrame.Angles(0, side * math.pi / 2, 0)
		for index = 0, 4 do
			local stripe = if index % 2 == 0 then Color3.fromRGB(255, 205, 40) else Color3.fromRGB(28, 28, 32)
			makePart("Hazard", Vector3.new(2, 0.6, 0.8), edge * CFrame.new(-4 + index * 2, 0.3, -4.6), stripe, pedestal)
		end
	end
	local ring = makePart("ButtonRing", Vector3.new(0.4, 9, 9), buttonCFrame * CFrame.new(0, 0.7, 0) * FLAT, Color3.fromRGB(28, 28, 32), pedestal)
	ring.Shape = Enum.PartType.Cylinder
	for _, part in ipairs(pedestal:GetChildren()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	pedestal.Parent = base
	local button = makePart("LockButton", Vector3.new(0.6, 8, 8), buttonCFrame * CFrame.new(0, 0.9, 0) * FLAT, Color3.fromRGB(220, 50, 50), base)
	button.Shape = Enum.PartType.Cylinder
	button.CanCollide = false

	-- « ZONE SÛRE » peint au sol juste après l'entrée et ligne rouge au bord de la base (comme la référence) :
	-- un familier volé devient celui du voleur dès qu'il arrive dans SA base.
	local half = size.X / 2 - 0.5
	local line = makePart("SafeLine", Vector3.new(size.X - 1.5, 0.06, 0.7), origin * CFrame.new(0, top + 0.03, -half + 1.4), Color3.fromRGB(235, 40, 60), base)
	line.Material = Enum.Material.Neon
	line.Transparency = 0.15
	line.CastShadow = false
	makeGhost(line)
	-- Face du dessus : la largeur du SurfaceGui suit l'axe Z de la pièce, d'où le quart de tour.
	local paint = makePart("SafeZoneSign", Vector3.new(3.6, 0.05, 24), origin * CFrame.new(0, top + 0.03, -half + 3.5) * CFrame.Angles(0, math.pi / 2, 0), Color3.new(1, 1, 1), base)
	paint.Transparency = 1
	makeGhost(paint)
	local paintGui = Instance.new("SurfaceGui")
	paintGui.Face = Enum.NormalId.Top
	paintGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	paintGui.PixelsPerStud = 30
	paintGui.LightInfluence = 0.4
	paintGui.MaxDistance = 160
	local paintLabel = Instance.new("TextLabel")
	paintLabel.Size = UDim2.fromScale(1, 1)
	paintLabel.BackgroundTransparency = 1
	paintLabel.Text = "ZONE SÛRE"
	styleSignText(paintLabel, Color3.new(1, 1, 1))
	paintLabel.TextTransparency = 0.1
	paintLabel.Parent = paintGui
	paintGui.Parent = paint

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

	local gate = makePart("Gate", Vector3.new(FENCE_GAP, FENCE_HEIGHT - 0.5, 0.6), origin * CFrame.new(0, top + (FENCE_HEIGHT - 0.5) / 2, -half), COLORS.WoodRail, base)
	gate.Transparency = 1
	makeGhost(gate)

	-- Stations d'entraînement à l'extérieur de la base (cachées tant qu'elles ne sont pas achetées) :
	-- tapis de course à gauche (Vitesse), banc de développé couché à droite (Force).
	-- TrainingController gère l'affichage, la matière selon le niveau et l'XP.
	createEvolutionCapsule(origin, base)
	createTreadmill(origin * CFrame.new(-half - 10, 0, -4), -1, base)
	createBench(origin * CFrame.new(half + 10, 0, -4), 1, base)

	local spawnPoints = Instance.new("Folder")
	spawnPoints.Name = "SpawnPoints"
	spawnPoints.Parent = base
	local pallets = Instance.new("Folder")
	pallets.Name = "Pallets"
	pallets.Parent = base
	-- 2 palettes à objets, à l'avant de la base de chaque côté du bouton de verrouillage (shared/BaseLayout).
	for _, offset in ipairs(BaseLayout.Pallets) do
		local palletCFrame = origin * CFrame.new(offset.X, top, offset.Y)
		createPallet(palletCFrame, pallets)
		-- Point d'apparition au-dessus du centre de la palette : l'objet tombe dessus.
		local point = makePart("SpawnPoint", Vector3.new(1, 1, 1), palletCFrame * CFrame.new(0, 3.5, 0), color, spawnPoints)
		point.Transparency = 1
		makeGhost(point)
	end

	local itemSpawns = Instance.new("Folder")
	itemSpawns.Name = "ItemSpawns"
	itemSpawns.Parent = base

	local sign = Instance.new("BillboardGui")
	sign.Name = "OwnerSign"
	-- Au-dessus du panneau de la couveuse, au fond : le nom se voit de loin sans cacher les œufs ni les familiers.
	sign.Adornee = incubatorSign
	sign.Size = UDim2.fromScale(30, 6)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
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
	createLeaderboard(map)

	createFloor(map)
	createWall(map)

	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = map

	local looseItems = Instance.new("Folder")
	looseItems.Name = "LooseItems"
	looseItems.Parent = map

	local wildItems = Instance.new("Folder")
	wildItems.Name = "WildItems" -- objets qui apparaissent dans l'arène, hors des bases
	wildItems.Parent = map

	local bases = {}
	for index = 1, ARENA.BaseCount do
		table.insert(bases, createBase(index, map))
	end

	map.Parent = Workspace
	return bases
end

return MapGenerator
