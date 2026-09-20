-- MapGenerator : construit physiquement la Part centrale noire (trou noir)
-- et les 4 bases grises disposées en cercle autour.

local MapGenerator = {}

local Workspace = game:GetService("Workspace")

-- Paramètres de génération
local BLACKHOLE_SIZE = Vector3.new(200, 1, 200)
local BLACKHOLE_POSITION = Vector3.new(0, 30, 0)
local BLACKHOLE_COLOR = Color3.fromRGB(20, 20, 20)

local BASE_SIZE = Vector3.new(50, 2, 50)
local BASE_COLOR = Color3.fromRGB(120, 120, 120)
local BASE_RADIUS = 180          -- distance du centre aux bases
local BASE_HEIGHT = 1            -- hauteur Y des bases

-- Crée une Part simple avec les propriétés de base
local function createPart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Crée le trou noir central (disque plat au sol)
local function createBlackhole(parent)
	local blackhole = createPart(
		"BlackholeZone",
		Vector3.new(80, 1, 80),
		Vector3.new(0, 0.5, 0),
		BLACKHOLE_COLOR,
		parent
	)
	blackhole.Material = Enum.Material.Neon
	blackhole.CanCollide = false
	blackhole:SetAttribute("CanConsume", false)

	-- Disque plat au sol
	local mesh = Instance.new("CylinderMesh")
	mesh.Parent = blackhole

	-- Aura violette
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Color = ColorSequence.new(Color3.fromRGB(150, 0, 255))
	aura.Rate = 40
	aura.Speed = NumberRange.new(5, 10)
	aura.Lifetime = NumberRange.new(2, 4)
	aura.EmissionDirection = Enum.NormalId.Top
	aura.Parent = blackhole

	return blackhole
end

-- Crée une base grise avec ses sous-dossiers (ItemSpawns, zones)
local function createBase(index, angle, parent)
	local base = Instance.new("Model")
	base.Name = "Base" .. index

	-- Position de la base sur le cercle
	local x = math.cos(angle) * BASE_RADIUS
	local z = math.sin(angle) * BASE_RADIUS
	local basePosition = Vector3.new(x, BASE_HEIGHT, z)

	-- Part principale de la base
	local basePart = createPart(
		"BasePart",
		BASE_SIZE,
		basePosition,
		BASE_COLOR,
		base
	)
	basePart.CanCollide = true

	-- SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = basePosition + Vector3.new(0, BASE_SIZE.Y / 2 + 0.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Parent = base

	-- SafeZone (part transparente verte)
	local safeZone = createPart(
		"SafeZone",
		Vector3.new(BASE_SIZE.X, 10, BASE_SIZE.Z),
		basePosition + Vector3.new(0, 5, 0),
		Color3.fromRGB(0, 255, 0),
		base
	)
	safeZone.Transparency = 0.7
	safeZone.CanCollide = false
	safeZone.Material = Enum.Material.ForceField

	-- TreadmillZone (part grise pour s'entraîner)
	local treadmill = createPart(
		"TreadmillZone",
		Vector3.new(BASE_SIZE.X * 0.6, 1, BASE_SIZE.Z * 0.6),
		basePosition + Vector3.new(0, BASE_SIZE.Y / 2 + 0.5, 0),
		Color3.fromRGB(90, 90, 90),
		base
	)
	treadmill.CanCollide = true

	-- IncubatorZone (pour les œufs)
	local incubator = createPart(
		"IncubatorZone",
		Vector3.new(10, 1, 10),
		basePosition + Vector3.new(BASE_SIZE.X * 0.3, BASE_SIZE.Y / 2 + 0.5, BASE_SIZE.Z * 0.3),
		Color3.fromRGB(255, 200, 100),
		base
	)
	incubator.CanCollide = true

	-- Dossier ItemSpawns
	local itemSpawns = Instance.new("Folder")
	itemSpawns.Name = "ItemSpawns"
	itemSpawns.Parent = base

	base.PrimaryPart = basePart
	base.Parent = parent
	return base
end

-- Point d'entrée : génère le trou noir et les 4 bases
function MapGenerator.generate()
	-- Dossier racine de la map
	local mapFolder = Workspace:FindFirstChild("Map")
	if not mapFolder then
		mapFolder = Instance.new("Folder")
		mapFolder.Name = "Map"
		mapFolder.Parent = Workspace
	end

	-- Nettoyage des anciennes générations
	for _, child in ipairs(mapFolder:GetChildren()) do
		child:Destroy()
	end

	-- Trou noir central
	createBlackhole(mapFolder)

	-- 8 bases réparties en cercle
	local baseCount = 8
	for i = 1, baseCount do
		local angle = (i - 1) * (math.pi * 2 / baseCount)
		createBase(i, angle, mapFolder)
	end
end

return MapGenerator
