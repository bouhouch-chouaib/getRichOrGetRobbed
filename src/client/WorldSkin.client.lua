--!strict
-- WorldSkin : chaque joueur voit le jeu dans SON monde (Config.Worlds, visuel dans shared/Worlds).
--   - L'arène (sol, mur d'enceinte, chemins, kiosques, tableau) est repeinte aux couleurs du monde du joueur local.
--   - Chaque base est repeinte aux couleurs du monde de son PROPRIÉTAIRE : on voit chez les autres une base désert,
--     glace ou cosmique (les stations d'entraînement gardent leur propre modèle, server/StationLooks).
--   - Les arbres sont remplacés par le décor du monde (cactus, roches de lave, cristaux, coraux, astéroïdes, colonnes).
--   - L'air, la teinte de l'image, les nuages et des particules d'ambiance changent avec le monde.
-- Tout est local (rien ne part au serveur) : les pièces portent l'attribut "Skin" (rôle) posé par server/MapGenerator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Worlds = require(ReplicatedStorage.Shared.Worlds)

local player = Players.LocalPlayer

type Entry = { part: BasePart, role: string, color: Color3, material: Enum.Material, baseIndex: number? }

local entries: { Entry } = {}
local treeParts: { BasePart } = {}
local spots: { { position: Vector3, scale: number } } = {}
local decorFolder: Folder? = nil
local decorKind: string? = nil
local spinning: { { part: Part, origin: CFrame, speed: number } } = {}

-- Monde où se trouve le joueur (attribut "World" : il peut être retourné dans un monde déjà visité), sinon son palier.
local function tierOf(target: Player?): number
	local world = target and (target:GetAttribute("World") or target:GetAttribute("Tier"))
	return if type(world) == "number" then world else 1
end

local function lookOf(tier: number): Worlds.Look
	local world = Config.GetWorld(tier)
	return Worlds.Looks[world.Id] or Worlds.Looks.Prairie
end

-- Propriétaire de chaque base (BaseIndex -> joueur).
local function owners(): { [number]: Player }
	local map = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local index = other:GetAttribute("BaseIndex")
		if type(index) == "number" then
			map[index] = other
		end
	end
	return map
end

----------------------------------------------------------------------
-- Inventaire des pièces à repeindre
----------------------------------------------------------------------

local function baseIndexOf(part: Instance, map: Instance): (number?, boolean)
	local node: Instance? = part.Parent
	local inStation = false
	while node and node ~= map do
		if node.Name == "Treadmill" or node.Name == "Bench" then
			inStation = true
		end
		local index = node.Name:match("^Base_(%d+)$")
		if index then
			return tonumber(index), inStation
		end
		node = node.Parent
	end
	return nil, inStation
end

local function collect(map: Instance)
	table.clear(entries)
	table.clear(treeParts)
	table.clear(spots)
	for _, part in ipairs(map:GetDescendants()) do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("Skin")
			if type(role) == "string" then
				local baseIndex, inStation = baseIndexOf(part, map)
				if not inStation then
					table.insert(entries, { part = part, role = role, color = part.Color, material = part.Material, baseIndex = baseIndex })
				end
			end
			if part.Parent and part.Parent.Name == "Trees" then
				table.insert(treeParts, part)
				local scale = part:GetAttribute("DecorSpot")
				if type(scale) == "number" then
					table.insert(spots, { position = part.Position - Vector3.new(0, part.Size.Y / 2, 0), scale = scale })
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Décors (remplacent les arbres)
----------------------------------------------------------------------

local function block(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = material or Enum.Material.Plastic
	p.TopSurface = if p.Shape == Enum.PartType.Block then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local DECORS: { [string]: (Folder, Vector3, number, Random) -> () } = {
	Cactus = function(folder, base, s, rng)
		local green, dark = rgb(80, 180, 80), rgb(56, 140, 60)
		local height = 9 * s
		block(folder, Vector3.new(2.8, height, 2.8) * Vector3.new(s, 1, s), CFrame.new(base + Vector3.new(0, height / 2, 0)), green)
		for _, side in ipairs({ -1, 1 }) do
			local y = height * rng:NextNumber(0.35, 0.6)
			block(folder, Vector3.new(2.2, 1.6, 1.6) * s, CFrame.new(base + Vector3.new(side * 2.2 * s, y, 0)), dark)
			block(folder, Vector3.new(1.6, 3.4, 1.6) * s, CFrame.new(base + Vector3.new(side * 2.9 * s, y + 2 * s, 0)), green)
		end
		block(folder, Vector3.new(1.2, 1, 1.2) * s, CFrame.new(base + Vector3.new(0, height + 0.5 * s, 0)), rgb(255, 120, 170))
		block(folder, Vector3.new(6, 0.6, 6) * s, CFrame.new(base + Vector3.new(0, 0.3, 0)), rgb(230, 190, 120))
	end,
	LavaRock = function(folder, base, s, rng)
		local rock, rock2 = rgb(60, 50, 56), rgb(44, 36, 40)
		for index = 1, 4 do
			local size = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(3, 7), rng:NextNumber(3, 6)) * s
			local offset = Vector3.new(rng:NextNumber(-2.5, 2.5), size.Y / 2, rng:NextNumber(-2.5, 2.5)) * Vector3.new(s, 1, s)
			block(folder, size, CFrame.new(base + offset) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(rng:NextNumber(-10, 10))), if index % 2 == 0 then rock else rock2)
		end
		local crack = block(folder, Vector3.new(0.6, 5 * s, 0.6), CFrame.new(base + Vector3.new(0.4, 2.5 * s, 0)), rgb(255, 120, 30), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 120, 40)
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = crack
		block(folder, Vector3.new(7, 0.3, 7) * s, CFrame.new(base + Vector3.new(0, 0.15, 0)), rgb(255, 90, 20), Enum.Material.Neon)
	end,
	IceCrystal = function(folder, base, s, rng)
		for index = 1, 5 do
			local height = rng:NextNumber(4, 10) * s
			local tilt = CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber(0, 6), math.rad(rng:NextNumber(-20, 20)))
			local position = base + Vector3.new(rng:NextNumber(-2, 2) * s, height / 2, rng:NextNumber(-2, 2) * s)
			local shard = block(folder, Vector3.new(1.6, height, 1.6) * Vector3.new(s, 1, s), CFrame.new(position) * tilt, rgb(170, 225, 255), Enum.Material.Glass)
			shard.Transparency = 0.2
			if index == 1 then
				block(folder, Vector3.new(0.7, height * 0.8, 0.7) * Vector3.new(s, 1, s), shard.CFrame, rgb(120, 220, 255), Enum.Material.Neon)
			end
		end
		block(folder, Vector3.new(7, 0.5, 7) * s, CFrame.new(base + Vector3.new(0, 0.25, 0)), rgb(250, 252, 255))
	end,
	Coral = function(folder, base, s, rng)
		local colors = { rgb(255, 120, 140), rgb(255, 160, 90), rgb(200, 90, 230) }
		for branch = 1, 3 do
			local color = colors[(branch - 1) % #colors + 1]
			local position = base + Vector3.new(rng:NextNumber(-2.5, 2.5) * s, 0, rng:NextNumber(-2.5, 2.5) * s)
			local y = 0
			for step = 1, 4 do
				local length = (3.4 - step * 0.4) * s
				block(folder, Vector3.new(1.2, length, 1.2) * Vector3.new(s, 1, s), CFrame.new(position + Vector3.new(0, y + length / 2, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))), color)
				y += length * 0.85
				position += Vector3.new(rng:NextNumber(-0.8, 0.8) * s, 0, rng:NextNumber(-0.8, 0.8) * s)
			end
			block(folder, Vector3.one * 1.3 * s, CFrame.new(position + Vector3.new(0, y, 0)), color:Lerp(Color3.new(1, 1, 1), 0.3), nil, Enum.PartType.Ball)
		end
		for _ = 1, 3 do
			local height = rng:NextNumber(5, 9) * s
			block(folder, Vector3.new(0.5, height, 0.5), CFrame.new(base + Vector3.new(rng:NextNumber(-3, 3) * s, height / 2, rng:NextNumber(-3, 3) * s)), rgb(60, 200, 120))
		end
	end,
	Asteroid = function(folder, base, s, rng)
		local center = base + Vector3.new(0, rng:NextNumber(9, 14) * s, 0)
		local rock = block(folder, Vector3.one * rng:NextNumber(4, 6) * s, CFrame.new(center), rgb(120, 100, 150), nil, Enum.PartType.Ball)
		for _ = 1, 3 do
			block(folder, Vector3.one * rng:NextNumber(0.8, 1.6) * s, CFrame.new(center + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)) * s), rgb(90, 70, 120), nil, Enum.PartType.Ball)
		end
		local ring = block(folder, Vector3.new(0.3, 9 * s, 9 * s), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(70)) * CFrame.Angles(math.rad(20), 0, 0), rgb(255, 150, 240), Enum.Material.Neon, Enum.PartType.Cylinder)
		ring.Transparency = 0.5
		table.insert(spinning, { part = rock, origin = rock.CFrame, speed = rng:NextNumber(0.2, 0.6) })
		-- Petit socle lumineux au sol sous l'astéroïde.
		block(folder, Vector3.new(0.2, 5 * s, 5 * s), CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), rgb(140, 90, 255), Enum.Material.Neon, Enum.PartType.Cylinder).Transparency = 0.4
	end,
	Pillar = function(folder, base, s, rng)
		local marble, gold = rgb(250, 248, 240), rgb(255, 205, 60)
		local height = rng:NextNumber(10, 14) * s
		block(folder, Vector3.new(4.4, 1.2, 4.4) * s, CFrame.new(base + Vector3.new(0, 0.6 * s, 0)), gold)
		block(folder, Vector3.new(2.8, height, 2.8) * Vector3.new(s, 1, s), CFrame.new(base + Vector3.new(0, height / 2 + 1.2 * s, 0)), marble)
		block(folder, Vector3.new(4, 1, 4) * s, CFrame.new(base + Vector3.new(0, height + 1.7 * s, 0)), gold, Enum.Material.Neon)
		for _ = 1, 3 do
			block(folder, Vector3.new(rng:NextNumber(3, 5), 1.6, rng:NextNumber(2, 3)) * s, CFrame.new(base + Vector3.new(rng:NextNumber(-3, 3) * s, height * rng:NextNumber(0.4, 0.9), rng:NextNumber(-3, 3) * s)), Color3.new(1, 1, 1))
		end
	end,
}

local function setTreesVisible(visible: boolean)
	for _, part in ipairs(treeParts) do
		part.LocalTransparencyModifier = if visible then 0 else 1
	end
end

local function buildDecor(kind: string)
	if kind == decorKind then
		return
	end
	decorKind = kind
	if decorFolder then
		decorFolder:Destroy()
		decorFolder = nil
	end
	table.clear(spinning)
	local builder = DECORS[kind]
	setTreesVisible(builder == nil)
	if not builder then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "WorldDecor"
	local rng = Random.new(7)
	for _, spot in ipairs(spots) do
		builder(folder, spot.position, spot.scale, rng)
	end
	folder.Parent = Workspace
	decorFolder = folder
end

RunService.RenderStepped:Connect(function()
	if #spinning == 0 then
		return
	end
	local t = os.clock()
	for _, item in ipairs(spinning) do
		item.part.CFrame = item.origin * CFrame.Angles(t * item.speed, t * item.speed * 0.7, 0) + Vector3.new(0, math.sin(t * item.speed * 2) * 0.8, 0)
	end
end)

----------------------------------------------------------------------
-- Ambiance (air, teinte, nuages, particules)
----------------------------------------------------------------------

local ambienceTier = 0
local particlePart: Part? = nil

local PARTICLES: { [string]: { texture: string, color: ColorSequence, size: NumberSequence, speed: NumberRange, rate: number, light: number, accel: Vector3 } } = {
	Sand = { texture = "rbxasset://textures/particles/smoke_main.dds", color = ColorSequence.new(rgb(240, 210, 150)), size = NumberSequence.new(0.6, 0.2), speed = NumberRange.new(6, 10), rate = 40, light = 0, accel = Vector3.new(6, 0, 0) },
	Embers = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = ColorSequence.new(rgb(255, 160, 50), rgb(255, 70, 20)), size = NumberSequence.new(0.35, 0), speed = NumberRange.new(2, 5), rate = 35, light = 1, accel = Vector3.new(0, 4, 0) },
	Snow = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = ColorSequence.new(Color3.new(1, 1, 1)), size = NumberSequence.new(0.35, 0.3), speed = NumberRange.new(2, 4), rate = 70, light = 0.4, accel = Vector3.new(1, -4, 0) },
	Bubbles = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = ColorSequence.new(rgb(200, 245, 255)), size = NumberSequence.new(0.3, 0.6), speed = NumberRange.new(1, 3), rate = 30, light = 0.3, accel = Vector3.new(0, 5, 0) },
	Stars = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = ColorSequence.new(rgb(255, 230, 255), rgb(150, 200, 255)), size = NumberSequence.new(0.4, 0), speed = NumberRange.new(0.2, 1), rate = 30, light = 1, accel = Vector3.zero },
	Feathers = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = ColorSequence.new(rgb(255, 245, 200), Color3.new(1, 1, 1)), size = NumberSequence.new(0.45, 0.2), speed = NumberRange.new(1, 2), rate = 30, light = 0.8, accel = Vector3.new(0, -1.5, 0) },
}

local function applyAmbience(look: Worlds.Look)
	local ambience = look.Ambience
	local fade = TweenInfo.new(1.5)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, fade, { Color = ambience.AirColor, Decay = ambience.AirDecay, Density = ambience.AirDensity }):Play()
	end
	local grading = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if grading then
		TweenService:Create(grading, fade, { TintColor = ambience.Tint, Saturation = ambience.Saturation }):Play()
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		TweenService:Create(clouds, fade, { Color = ambience.CloudColor }):Play()
	end
	if particlePart then
		particlePart:Destroy()
		particlePart = nil
	end
	local def = if ambience.Particles then PARTICLES[ambience.Particles] else nil
	if def then
		local part = Instance.new("Part")
		part.Name = "WorldParticles"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(90, 1, 90)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = def.texture
		emitter.Color = def.color
		emitter.Size = def.size
		emitter.Speed = def.speed
		emitter.Rate = def.rate
		emitter.LightEmission = def.light
		emitter.Acceleration = def.accel
		emitter.Lifetime = NumberRange.new(5, 8)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
		emitter.Parent = part
		part.Parent = Workspace
		particlePart = part
	end
end

-- Les particules suivent le joueur (une zone de 90 x 90 au-dessus de lui).
RunService.Heartbeat:Connect(function()
	local part = particlePart
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if part and root and root:IsA("BasePart") then
		part.Position = root.Position + Vector3.new(0, 18, 0)
	end
end)

----------------------------------------------------------------------
-- Application
----------------------------------------------------------------------

local function paint(entry: Entry, look: Worlds.Look)
	local color = look.Palette[entry.role]
	entry.part.Color = color or entry.color
	local neon = look.Neon and look.Neon[entry.role]
	entry.part.Material = if neon then Enum.Material.Neon else entry.material
end

local dirty = true
local function refresh()
	dirty = false
	local myTier = tierOf(player)
	local myLook = lookOf(myTier)
	local baseOwners = owners()
	for _, entry in ipairs(entries) do
		if entry.part.Parent then
			if entry.baseIndex then
				-- Base : le monde de son propriétaire (une base libre suit le monde du joueur local).
				paint(entry, lookOf(tierOf(baseOwners[entry.baseIndex] or player)))
			else
				paint(entry, myLook)
			end
		end
	end
	buildDecor(myLook.Decor)
	if myTier ~= ambienceTier then
		ambienceTier = myTier
		applyAmbience(myLook)
	end
end

local function markDirty()
	dirty = true
end

local function watchPlayer(other: Player)
	other:GetAttributeChangedSignal("Tier"):Connect(markDirty)
	other:GetAttributeChangedSignal("World"):Connect(markDirty)
	other:GetAttributeChangedSignal("BaseIndex"):Connect(markDirty)
	markDirty()
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(markDirty)
for _, other in ipairs(Players:GetPlayers()) do
	watchPlayer(other)
end

task.spawn(function()
	local map = Workspace:WaitForChild("Map")
	-- La carte arrive par morceaux au chargement : on attend qu'elle ne grossisse plus.
	local last = -1
	while true do
		local count = #map:GetDescendants()
		if count == last and count > 0 then
			break
		end
		last = count
		task.wait(1)
	end
	collect(map)
	refresh()
	while true do
		task.wait(0.5)
		if dirty then
			refresh()
		end
	end
end)
