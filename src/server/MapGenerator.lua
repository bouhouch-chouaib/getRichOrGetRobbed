--!strict
-- MapGenerator : construit l'arène (prairie, chemins de terre, trou noir, bases clôturées, arbres).
-- Ne contient aucune logique de jeu : il ne fait que poser les pièces.
-- L'éclairage jour/nuit est géré par DayNightController.
--
-- Structure générée :
-- Workspace.Map
--   ArenaFloor, HoleDirt, HoleRing, BlackholeZone (+ Aura), BlackholeCore (+ Light), BlackholeHalo, BlackholeDome
--   Paths (Folder), Trees (Folder)
--   LooseItems (Folder) : objets ramassés / lancés
--   Base_1 .. Base_N (Model) : BasePart, Fence (Folder), SpawnLocation, SafeZone (invisible), TreadmillZone,
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
		for _, spot in ipairs({ { angle = (index + 0.5) * step, radius = 205 }, { angle = index * step, radius = 242 } }) do
			local position = Vector3.new(math.cos(spot.angle) * spot.radius, 0, math.sin(spot.angle) * spot.radius)
			createTree(position, rng:NextNumber(0.9, 1.3), folder)
		end
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

	-- Tapis de course : la vitesse du tapis (AssemblyLinearVelocity) est réglée par TrainingController.
	local treadmill = makePart("TreadmillZone", Vector3.new(10, 0.6, 20), origin * CFrame.new(-16, top + 0.3, 2), Color3.fromRGB(70, 70, 75), base)
	treadmill.Material = Enum.Material.DiamondPlate
	for _, side in ipairs({ -5.5, 5.5 }) do
		local edge = makePart("TreadmillEdge", Vector3.new(1, 1, 20), origin * CFrame.new(-16 + side, top + 0.5, 2), COLORS.WoodPost, base)
		edge.Material = Enum.Material.Wood
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
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
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
