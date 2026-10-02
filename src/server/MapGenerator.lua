--!strict
-- MapGenerator : construit l'arène (sol, trou noir, dôme, bases) et l'ambiance lumineuse.
-- Ne contient aucune logique de jeu : il ne fait que poser les pièces.
--
-- Structure générée :
-- Workspace.Map
--   ArenaFloor, HoleRing, BlackholeZone (+ Aura), BlackholeCore (+ Light), BlackholeHalo, BlackholeDome
--   LooseItems (Folder) : objets ramassés / lancés
--   Base_1 .. Base_N (Model) : BasePart, Rim, SpawnLocation, SafeZone, TreadmillZone,
--                              SpawnPoints (Folder), ItemSpawns (Folder), Lane

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapGenerator = {}

local ARENA = Config.Arena
-- Une Part "Cylinder" a son axe sur X : on la couche pour en faire un disque horizontal.
local FLAT = CFrame.Angles(0, 0, math.pi / 2)

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
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 60, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 90, 140)
	Lighting.GlobalShadows = true

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.StarCount = 5000
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Color = Color3.fromRGB(120, 80, 180)
	atmosphere.Decay = Color3.fromRGB(60, 30, 90)
	atmosphere.Glare = 0
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 30
	bloom.Threshold = 0.9
	bloom.Parent = Lighting

	local grading = Instance.new("ColorCorrectionEffect")
	grading.Saturation = 0.2
	grading.Contrast = 0.1
	grading.Parent = Lighting
end

local function createBlackhole(map: Folder)
	local feeding = Config.Colors.Feeding

	makeDisc("ArenaFloor", ARENA.FloorRadius, 4, 0, Color3.fromRGB(28, 26, 40), map).Material = Enum.Material.Slate

	local ring = makeDisc("HoleRing", ARENA.HoleRadius + 4, 0.3, 0.3, feeding, map)
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

	local platform = makePart("BasePart", size, origin * CFrame.new(0, size.Y / 2, 0), Color3.fromRGB(55, 52, 70), base)
	platform.Material = Enum.Material.Concrete

	local rim = makePart("Rim", Vector3.new(size.X + 2, 0.8, size.Z + 2), origin * CFrame.new(0, 0.4, 0), color, base)
	rim.Material = Enum.Material.Neon

	local top = size.Y -- hauteur du dessus de la plateforme

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = origin * CFrame.new(0, top + 0.5, 18)
	spawn.Color = color
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = base

	local safeZone = makePart("SafeZone", Vector3.new(16, 8, 16), origin * CFrame.new(0, top + 4, 18), Color3.fromRGB(60, 255, 120), base)
	safeZone.Material = Enum.Material.ForceField
	safeZone.Transparency = 0.6
	makeGhost(safeZone)

	-- Tapis de course : la vitesse du tapis (AssemblyLinearVelocity) est réglée par TrainingController.
	local treadmill = makePart("TreadmillZone", Vector3.new(10, 0.6, 20), origin * CFrame.new(-16, top + 0.3, 2), Color3.fromRGB(40, 40, 50), base)
	treadmill.Material = Enum.Material.DiamondPlate
	for _, side in ipairs({ -5.25, 5.25 }) do
		local stripe = makePart("TreadmillStripe", Vector3.new(0.5, 0.7, 20), origin * CFrame.new(-16 + side, top + 0.35, 2), color, base)
		stripe.Material = Enum.Material.Neon
		makeGhost(stripe)
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

	-- Bande lumineuse au sol entre la base et le trou noir (aide à s'orienter).
	local laneStart = ARENA.HoleRadius + 7
	local laneEnd = ARENA.BaseRingRadius - size.Z / 2 - 2
	local laneMid = (laneStart + laneEnd) / 2
	local direction = position.Unit
	local lane = makePart(
		"Lane",
		Vector3.new(2, 0.1, laneEnd - laneStart),
		CFrame.lookAt(direction * laneMid + Vector3.new(0, 0.05, 0), Vector3.new(0, 0.05, 0)),
		color,
		base
	)
	lane.Material = Enum.Material.Neon
	lane.Transparency = 0.4
	makeGhost(lane)

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

	local looseItems = Instance.new("Folder")
	looseItems.Name = "LooseItems"
	looseItems.Parent = map

	local bases = {}
	for index = 1, ARENA.BaseCount do
		table.insert(bases, createBase(index, map))
	end

	map.Parent = Workspace
	return bases
end

return MapGenerator
