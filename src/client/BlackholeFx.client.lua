--!strict
-- BlackholeFx : l'aspect du trou noir selon son palier (server/BlackholeTiers, Config.Blackhole), en blocs à tenons.
--   1 Éveil      couronne violette + vortex de cubes qui tourbillonnent vers le centre
--   2 Éruption   bord de roches et de lave, braises, gerbe de feu quand il recrache des roches
--   3 Cible      trois anneaux rouges et blancs qui tournent en sens opposés (centre = x2)
--   4 Abysses    six tentacules en cubes qui ondulent et frappent quand ils rattrapent un objet
--   5 Gravité    disque de matière incliné qui tourne autour du cœur, éclairs bleus
--   6 Supernova  pointes de lumière qui pulsent, ondes de choc
--   7 Divin      couronne d'or, anneaux gyroscopiques, rayons de lumière, paillettes
-- + la jauge commune au-dessus du trou, les annonces (évolution, jackpot, effondrement) et les bulles de bonus.
-- Tout est local (aucune donnée envoyée) : le serveur publie l'état en attributs de ReplicatedStorage
-- (HoleTier, HoleGauge, HoleNeed, HoleCollapse, HoleJackpotUntil) et les moments forts par Remotes.HoleEvent.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Worlds = require(ReplicatedStorage.Shared.Worlds)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)

local HOLE = Config.Blackhole
local R = Config.Arena.HoleRadius
local CORE_Y = 9 -- hauteur du cœur noir (server/MapGenerator)
local localPlayer = Players.LocalPlayer
local rng = Random.new()
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles

local folder = Instance.new("Folder")
folder.Name = "BlackholeFx"
folder.Parent = Workspace

----------------------------------------------------------------------
-- Briques
----------------------------------------------------------------------

local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, neon: boolean?, alpha: number?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = alpha or 0
	if neon then
		p.Material = Enum.Material.Neon
	else
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
		p.FrontSurface = Enum.SurfaceType.Studs
		p.BackSurface = Enum.SurfaceType.Studs
		p.LeftSurface = Enum.SurfaceType.Studs
		p.RightSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Smooth
	end
	p.Parent = parent
	return p
end

local function newModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Anneau de `count` blocs autour de l'origine du modèle (plan horizontal), couleurs alternées.
local function ring(parent: Instance, radius: number, count: number, depth: number, height: number, y: number,
	colorA: Color3, colorB: Color3, neonA: boolean?, neonB: boolean?): Model
	local m = newModel("Ring", parent)
	local width = 2 * math.pi * radius / count * 0.86
	for i = 0, count - 1 do
		local a = i * math.pi * 2 / count
		local even = i % 2 == 0
		block(m, V(width, height, depth), ANG(0, a, 0) * CF(0, y, -radius), if even then colorA else colorB,
			if even then neonA else neonB)
	end
	m.WorldPivot = CFrame.identity
	return m
end

local function emitter(parent: Instance, texture: string, color: Color3, rate: number, size: number, speed: number,
	life: number): ParticleEmitter
	local fx = Instance.new("ParticleEmitter")
	fx.Texture = texture
	fx.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
	fx.Rate = rate
	fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	fx.Transparency = NumberSequence.new(0.1, 1)
	fx.Speed = NumberRange.new(speed * 0.5, speed)
	fx.Lifetime = NumberRange.new(life * 0.6, life)
	fx.LightEmission = 1
	fx.SpreadAngle = Vector2.new(25, 25)
	fx.EmissionDirection = Enum.NormalId.Top
	fx.Parent = parent
	return fx
end

-- Zone invisible qui émet des particules sur toute sa surface (braises, bulles, paillettes).
local function emitArea(parent: Instance, size: Vector3, cf: CFrame): Part
	return block(parent, size, cf, Color3.new(), false, 1)
end

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

----------------------------------------------------------------------
-- Ondes de choc (palier 6, évolution, effondrement)
----------------------------------------------------------------------

type Wave = { model: Model, parts: { BasePart }, from: number, to: number, born: number, life: number }
local waves: { Wave } = {}

local function shockwave(color: Color3, from: number, to: number, life: number)
	local m = newModel("Wave", folder)
	local parts: { BasePart } = {}
	for i = 0, 35 do
		local part = block(m, V(4, 0.8, 1.2), CFrame.identity, color, true)
		part:SetAttribute("Angle", i * math.pi * 2 / 36)
		table.insert(parts, part)
	end
	table.insert(waves, { model = m, parts = parts, from = from, to = to, born = os.clock(), life = life })
end

local function updateWaves()
	local now = os.clock()
	for i = #waves, 1, -1 do
		local wave = waves[i]
		local f = (now - wave.born) / wave.life
		if f >= 1 then
			wave.model:Destroy()
			table.remove(waves, i)
		else
			local eased = 1 - (1 - f) ^ 2
			local radius = wave.from + (wave.to - wave.from) * eased
			local width = 2 * math.pi * radius / 36 * 0.8
			for _, part in ipairs(wave.parts) do
				local a = part:GetAttribute("Angle") :: number
				part.Size = V(width, 0.8 + (1 - f) * 2, 1.2)
				part.CFrame = ANG(0, a, 0) * CF(0, 1.5, -radius)
				part.Transparency = f
			end
		end
	end
end

----------------------------------------------------------------------
-- Aspects des paliers
----------------------------------------------------------------------

type Look = {
	model: Model,
	update: (t: number, dt: number) -> (),
	event: ((kind: string, a: any, b: any) -> ())?,
}

-- Cadre du trou, aux couleurs du MONDE du joueur (shared/Worlds, comme le reste de la map qu'il voit) : un muret en
-- damier de 2 tons + chapeau, en blocs à tenons, comme le mur d'enceinte (docs/DIRECTION_ARTISTIQUE.md §1-2), et 8
-- petits décors du monde tout autour (buissons, cactus, roches de lave, cristaux, coraux, astéroïdes, colonnes).
-- Le décor du PALIER (vortex, lave, cible, tentacules...) est commun à tout le serveur et se pose par-dessus.
local WALL_RADIUS = R + 5.5
local WALL_COUNT = 44
local PRAIRIE_WALL = { Color3.fromRGB(202, 145, 86), Color3.fromRGB(185, 125, 73), Color3.fromRGB(110, 214, 42) }

local function worldIndex(): number
	local value = localPlayer:GetAttribute("World") or localPlayer:GetAttribute("Tier")
	return if type(value) == "number" then value else 1
end

local function prop(parent: Instance, kind: string, at: CFrame, spinning: { { part: Part, origin: CFrame, phase: number } })
	local rgb = Color3.fromRGB
	if kind == "Cactus" then
		block(parent, V(4, 0.8, 4), at * CF(0, 0.4, 0), rgb(250, 214, 130))
		block(parent, V(1.6, 5.5, 1.6), at * CF(0, 3.5, 0), rgb(80, 180, 80))
		block(parent, V(1.2, 2.4, 1.2), at * CF(1.4, 3.8, 0), rgb(70, 160, 70))
		block(parent, V(1.2, 1.8, 1.2), at * CF(-1.4, 3, 0), rgb(70, 160, 70))
		block(parent, V(0.6, 0.6, 0.6), at * CF(0, 6.5, 0), rgb(255, 120, 200))
	elseif kind == "LavaRock" then
		block(parent, V(4, 2.6, 3.4), at * CF(0, 1.3, 0), rgb(70, 60, 64))
		block(parent, V(2.6, 1.8, 2.4), at * CF(0.4, 3.4, 0.2) * ANG(0, 0.5, 0), rgb(54, 46, 50))
		block(parent, V(0.5, 2, 3.6), at * CF(-0.6, 1.4, 0), rgb(255, 110, 30), true)
	elseif kind == "IceCrystal" then
		block(parent, V(3.6, 0.8, 3.6), at * CF(0, 0.4, 0), rgb(240, 248, 255))
		block(parent, V(1.2, 5, 1.2), at * CF(0, 3, 0) * ANG(0, 0, 0.15), rgb(150, 210, 245))
		block(parent, V(0.9, 3.4, 0.9), at * CF(1, 2.2, 0.4) * ANG(0.2, 0, -0.4), rgb(200, 235, 255))
		block(parent, V(0.8, 2.6, 0.8), at * CF(-1, 1.8, -0.3) * ANG(-0.2, 0, 0.45), rgb(124, 190, 235))
	elseif kind == "Coral" then
		block(parent, V(3.4, 0.8, 3.4), at * CF(0, 0.4, 0), rgb(230, 210, 150))
		block(parent, V(1, 4, 1), at * CF(0, 2.6, 0), rgb(255, 120, 140))
		block(parent, V(0.8, 2.4, 0.8), at * CF(0.9, 3.4, 0) * ANG(0, 0, -0.5), rgb(230, 90, 160))
		block(parent, V(0.8, 2, 0.8), at * CF(-0.9, 3, 0) * ANG(0, 0, 0.55), rgb(255, 150, 90))
		block(parent, V(0.6, 0.6, 0.6), at * CF(0, 4.9, 0), rgb(90, 230, 200), true)
	elseif kind == "Asteroid" then
		local rock = block(parent, V(2.6, 2.2, 2.4), at * CF(0, 5, 0), rgb(110, 80, 170))
		local small = block(parent, V(1.2, 1.2, 1.2), at * CF(1.8, 7, 0.6), rgb(150, 110, 220))
		table.insert(spinning, { part = rock, origin = at * CF(0, 5, 0), phase = at.Position.X })
		table.insert(spinning, { part = small, origin = at * CF(1.8, 7, 0.6), phase = at.Position.Z })
	elseif kind == "Pillar" then
		block(parent, V(2.6, 0.7, 2.6), at * CF(0, 0.35, 0), rgb(255, 205, 60))
		block(parent, V(1.6, 5.6, 1.6), at * CF(0, 3.5, 0), rgb(250, 248, 240))
		block(parent, V(2.6, 0.7, 2.6), at * CF(0, 6.6, 0), rgb(255, 205, 60))
	else -- Prairie : un buisson en cubes et une fleur
		block(parent, V(3.2, 2.4, 3.2), at * CF(0, 1.2, 0), rgb(80, 198, 58))
		block(parent, V(2, 1.2, 2), at * CF(0.3, 3, 0.2), rgb(104, 218, 74))
		block(parent, V(0.7, 0.7, 0.7), at * CF(-0.8, 2.6, -1), rgb(255, 90, 90))
		block(parent, V(0.7, 0.7, 0.7), at * CF(1, 2.2, 1.1), rgb(255, 230, 80))
	end
end

type Frame = { model: Model, spinning: { { part: Part, origin: CFrame, phase: number } } }
local worldFrame: Frame? = nil
local frameWorld = 0

local function buildWorldFrame()
	local index = worldIndex()
	if index == frameWorld then
		return
	end
	frameWorld = index
	if worldFrame then
		worldFrame.model:Destroy()
	end
	local look = Worlds.Looks[Config.GetWorld(index).Id] or Worlds.Looks.Prairie
	local palette = look.Palette
	local wallA = palette.WallA or PRAIRIE_WALL[1]
	local wallB = palette.WallB or PRAIRIE_WALL[2]
	local top = palette.WallTop or PRAIRIE_WALL[3]
	local topNeon = look.Neon ~= nil and look.Neon.WallTop == true
	local model = newModel("WorldFrame", folder)
	local width = 2 * math.pi * WALL_RADIUS / WALL_COUNT * 0.98
	for i = 0, WALL_COUNT - 1 do
		local a = i * math.pi * 2 / WALL_COUNT
		for row = 0, 1 do
			block(model, V(width, 1.6, 3), ANG(0, a, 0) * CF(0, 0.8 + row * 1.6, -WALL_RADIUS),
				if (i + row) % 2 == 0 then wallA else wallB)
		end
		block(model, V(width + 0.05, 0.6, 3.6), ANG(0, a, 0) * CF(0, 3.5, -WALL_RADIUS), top, topNeon)
	end
	local spinning = {}
	for k = 0, 7 do
		local a = k * math.pi / 4 + math.pi / 8
		prop(model, look.Decor, ANG(0, a, 0) * CF(0, 0, -(WALL_RADIUS + 5)), spinning)
	end
	worldFrame = { model = model, spinning = spinning }
end

local builders: { [number]: (Model, Config.HoleTier) -> Look } = {}

-- 1 Éveil : vortex de cubes à tenons en spirale vers le centre (quelques cubes lumineux comme étincelles).
builders[1] = function(model, def)
	local vortex = newModel("Vortex", model)
	for arm = 0, 3 do
		for i = 0, 15 do
			local f = i / 16
			local radius = (R - 3) * (1 - f) + 9
			local a = arm * math.pi / 2 + f * 2.8
			local s = 2.6 - f * 1.4
			block(vortex, V(s, s, s), ANG(0, a, 0) * CF(0, 1.4 + f * 2.5, -radius) * ANG(f, f * 2, 0),
				if i % 2 == 0 then def.Wall[1] else def.Wall[3], i % 4 == 3)
		end
	end
	vortex.WorldPivot = CFrame.identity
	local area = emitArea(model, V(R * 1.6, 1, R * 1.6), CF(0, 1, 0))
	emitter(area, SPARK, def.Color2, 14, 1.2, 3, 2)
	return {
		model = model,
		update = function(t)
			vortex:PivotTo(ANG(0, -t * 0.55, 0))
		end,
	}
end

-- 2 Éruption : rochers à tenons du monde Volcan, coulée de lave qui pulse, braises ; gerbe de feu quand il recrache.
builders[2] = function(model, def)
	local rockA, rockB = def.Wall[1], def.Wall[2]
	local lava = ring(model, R + 1.5, 30, 3.5, 0.5, 0.45, def.Color, def.Color2, true, true)
	for i = 0, 9 do
		local a = i * math.pi * 2 / 10 + 0.2
		local base = ANG(0, a, 0) * CF(0, 0, -(R + 11))
		local h = 4 + (i % 3) * 2
		block(model, V(6, h, 5), base * CF(0, h / 2, 0), rockA)
		block(model, V(4, h * 0.6, 3.6), base * CF(0.8, h + h * 0.3, 0.4) * ANG(0, 0.4, 0), rockB)
		block(model, V(0.6, h * 0.7, 5.2), base * CF(-1, h / 2, 0), def.Color, true) -- fissure de lave
	end
	local area = emitArea(model, V(R * 2, 1, R * 2), CF(0, 1, 0))
	local embers = emitter(area, FIRE, def.Color, 30, 1.4, 12, 1.6)
	embers.Acceleration = V(0, 6, 0)
	local mouth = emitArea(model, V(6, 1, 6), CF(0, CORE_Y + 9, 0))
	local burst = emitter(mouth, FIRE, def.Color2, 0, 6, 60, 1.4)
	burst.SpreadAngle = Vector2.new(40, 40)
	local lavaParts = lava:GetChildren()
	return {
		model = model,
		update = function(t)
			for i, part in ipairs(lavaParts) do
				if part:IsA("BasePart") then
					part.Transparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(t * 2.2 + i * 0.7))
				end
			end
		end,
		event = function(kind)
			if kind == "Spit" then
				burst:Emit(70)
			end
		end,
	}
end

-- 3 Cible : trois anneaux de blocs rouges et blancs à tenons qui tournent en sens opposés ; le premier marque la
-- zone x2 (il s'allume un instant quand quelqu'un vise juste).
builders[3] = function(model, def)
	local red, white = def.Wall[1], def.Wall[2]
	local inner = ring(model, HOLE.Target.Radius, 18, 2.6, 0.8, 1, red, def.Wall[3])
	local middle = ring(model, 25, 30, 2.6, 0.7, 0.9, white, red)
	local outer = ring(model, R - 3, 40, 2.8, 0.7, 0.9, red, white)
	local innerParts = inner:GetChildren()
	local flash = 0
	return {
		model = model,
		update = function(t, dt)
			inner:PivotTo(ANG(0, t * 0.6, 0))
			middle:PivotTo(ANG(0, -t * 0.35, 0))
			outer:PivotTo(ANG(0, t * 0.2, 0))
			local was = flash > 0
			flash = math.max(0, flash - dt * 2)
			if was then
				for _, part in ipairs(innerParts) do
					if part:IsA("BasePart") then
						part.Size = V(part.Size.X, 0.8 + flash * 3, part.Size.Z)
						part.Material = if flash > 0 then Enum.Material.Neon else Enum.Material.Plastic
					end
				end
			end
		end,
		event = function(kind)
			if kind == "Bullseye" then
				flash = 1
			end
		end,
	}
end

-- 4 Abysses : tentacules de cubes à tenons couleur corail (palette du monde Abysses), recalculés à chaque image.
builders[4] = function(model, def)
	local SEGMENTS, LENGTH = 10, 3.4
	local CORAL, CORAL_DARK, SUCKER = Color3.fromRGB(255, 120, 140), Color3.fromRGB(230, 90, 160), Color3.fromRGB(255, 225, 200)
	type Tentacle = { base: CFrame, angle: number, phase: number, segs: { BasePart }, suckers: { BasePart }, slam: number }
	local tentacles: { Tentacle } = {}
	for k = 0, 5 do
		local angle = k * math.pi / 3 + math.pi / 6
		local root = V(math.sin(angle) * (R + 2), 0.4, math.cos(angle) * (R + 2))
		local tentacle: Tentacle = {
			base = CFrame.lookAt(root, V(0, 0.4, 0)),
			angle = angle,
			phase = k * 1.3,
			segs = {},
			suckers = {},
			slam = 0,
		}
		for i = 1, SEGMENTS do
			local w = 4.6 - (i - 1) * 0.34
			table.insert(tentacle.segs, block(model, V(w, LENGTH + 0.2, w), CFrame.identity,
				if i % 2 == 0 then CORAL_DARK else CORAL))
			table.insert(tentacle.suckers, block(model, V(w * 0.5, w * 0.5, 0.4), CFrame.identity, SUCKER))
		end
		table.insert(tentacles, tentacle)
	end
	local area = emitArea(model, V(R * 2, 1, R * 2), CF(0, 1, 0))
	local bubbles = emitter(area, SPARK, def.Color, 18, 1, 5, 2.5)
	bubbles.Acceleration = V(0, 3, 0)
	return {
		model = model,
		update = function(t, dt)
			for _, tentacle in ipairs(tentacles) do
				tentacle.slam = math.max(0, tentacle.slam - dt * 1.6)
				local curl = 1 + math.sin(tentacle.slam * math.pi) * 1.4
				local cf = tentacle.base
				for i, seg in ipairs(tentacle.segs) do
					-- Presque droit à la base, de plus en plus courbé vers le bout (crochet au-dessus du trou).
					local bend = (0.02 + 0.2 * (i / SEGMENTS) ^ 2 + 0.05 * math.sin(t * 1.4 + tentacle.phase + i * 0.5)) * curl
					local sway = 0.07 * math.sin(t * 0.9 + tentacle.phase + i * 0.35)
					cf = cf * ANG(-bend, 0, sway) * CF(0, LENGTH, 0)
					local center = cf * CF(0, -LENGTH / 2, 0)
					seg.CFrame = center
					tentacle.suckers[i].CFrame = center * CF(0, 0, -seg.Size.Z / 2 - 0.15)
				end
			end
		end,
		event = function(kind, position)
			if kind == "Catch" and typeof(position) == "Vector3" then
				local best, bestDistance = tentacles[1], math.huge
				for _, tentacle in ipairs(tentacles) do
					local distance = (tentacle.base.Position - position).Magnitude
					if distance < bestDistance then
						best, bestDistance = tentacle, distance
					end
				end
				best.slam = 1
			end
		end,
	}
end

-- 5 Gravité : disque de matière incliné (cubes à tenons blancs et orange, quelques-uns lumineux) + éclairs bleus.
builders[5] = function(model, def)
	local disc = newModel("Disc", model)
	local inner = ring(disc, 19, 28, 2, 1.6, 0, Color3.fromRGB(255, 245, 225), def.Color, false, true)
	local outer = ring(disc, 28, 36, 2.4, 1.4, 0, def.Color, def.Wall[1])
	inner.Parent, outer.Parent = disc, disc
	disc.WorldPivot = CFrame.identity
	local bolts = newModel("Bolts", model)
	local nextBolt = 0
	local function bolt(t: number)
		local a = rng:NextNumber(0, math.pi * 2)
		local from = V(math.sin(a) * (R + 4), 3, math.cos(a) * (R + 4))
		local to = V(rng:NextNumber(-3, 3), CORE_Y + rng:NextNumber(-3, 3), rng:NextNumber(-3, 3))
		local last = from
		for i = 1, 6 do
			local point = if i == 6 then to else from:Lerp(to, i / 6) + V(rng:NextNumber(-3, 3), rng:NextNumber(-2, 4), rng:NextNumber(-3, 3))
			local part = block(bolts, V(0.5, 0.5, (point - last).Magnitude), CFrame.lookAt((point + last) / 2, point), def.Color2, true)
			Debris:AddItem(part, 0.14)
			last = point
		end
		nextBolt = t + rng:NextNumber(0.7, 2.2)
	end
	return {
		model = model,
		update = function(t)
			local tilt = CF(0, CORE_Y, 0) * ANG(0.25, 0, 0.1)
			inner:PivotTo(tilt * ANG(0, t * 0.9, 0))
			outer:PivotTo(tilt * ANG(0, t * 0.5, 0))
			if t >= nextBolt then
				bolt(t)
			end
		end,
	}
end

-- 6 Supernova : pointes de lumière qui pulsent (un effet : néon) et ondes de choc régulières.
builders[6] = function(model, def)
	type Spike = { part: Part, dir: Vector3, phase: number }
	local spikes: { Spike } = {}
	for i = 0, 11 do
		local a = i * math.pi * 2 / 12
		local up = if i % 2 == 0 then 0.45 else -0.05
		local dir = V(math.sin(a), up, math.cos(a)).Unit
		table.insert(spikes, {
			part = block(model, V(2.6, 2.6, 10), CFrame.identity, if i % 2 == 0 then def.Color else def.Color2, true),
			dir = dir,
			phase = i * 0.6,
		})
	end
	local area = emitArea(model, V(8, 8, 8), CF(0, CORE_Y, 0))
	local glitter = emitter(area, SPARK, def.Color, 25, 1.6, 18, 1.2)
	glitter.SpreadAngle = Vector2.new(180, 180)
	local nextWave = 0
	return {
		model = model,
		update = function(t)
			for _, spike in ipairs(spikes) do
				local length = 12 + 14 * (0.5 + 0.5 * math.sin(t * 2.4 + spike.phase))
				spike.part.Size = V(2.6, 2.6, length)
				local start = V(0, CORE_Y, 0) + spike.dir * 10
				spike.part.CFrame = CFrame.lookAt(start + spike.dir * length / 2, start + spike.dir * length)
			end
			if t >= nextWave then
				nextWave = t + 2.6
				shockwave(def.Color, 12, 75, 1.4)
			end
		end,
	}
end

-- 7 Divin : muret blanc et or, anneaux gyroscopiques d'or à tenons, rayons de lumière (effet), paillettes.
builders[7] = function(model, def)
	local gold = def.Wall[3]
	local ringA = ring(model, 15, 26, 1.8, 1.8, 0, gold, def.Wall[1])
	local ringB = ring(model, 18.5, 30, 1.6, 1.6, 0, def.Wall[1], gold)
	local rays = newModel("Rays", model)
	for i = 0, 11 do
		local a = i * math.pi * 2 / 12
		-- Pied du rayon contre le cœur, le haut s'écarte vers l'extérieur : une couronne de lumière qui s'ouvre.
		block(rays, V(2.6, 80, 0.6), ANG(0, a, 0) * CF(0, CORE_Y, -7) * ANG(-0.38, 0, 0) * CF(0, 40, 0), def.Color2, true, 0.72)
	end
	rays.WorldPivot = CFrame.identity
	local area = emitArea(model, V(R * 2, 1, R * 2), CF(0, 1, 0))
	local glitter = emitter(area, SPARK, def.Color, 30, 1.2, 6, 2.5)
	glitter.Acceleration = V(0, 2, 0)
	local rayParts = rays:GetChildren()
	return {
		model = model,
		update = function(t)
			ringA:PivotTo(CF(0, CORE_Y, 0) * ANG(0, t * 0.7, 0) * ANG(math.pi / 2, 0, 0))
			ringB:PivotTo(CF(0, CORE_Y, 0) * ANG(0, -t * 0.45, 0) * ANG(math.pi / 2, 0, math.pi / 3) * ANG(0, t * 0.8, 0))
			rays:PivotTo(ANG(0, t * 0.12, 0))
			local jackpot = Workspace:GetServerTimeNow() < (ReplicatedStorage:GetAttribute("HoleJackpotUntil") or 0) :: number
			local alpha = if jackpot then 0.25 + 0.15 * math.sin(t * 10) else 0.72
			for _, part in ipairs(rayParts) do
				if part:IsA("BasePart") then
					part.Transparency = alpha
				end
			end
		end,
	}
end

----------------------------------------------------------------------
-- Changement de palier : l'ancien aspect s'effondre dans le cœur, le nouveau apparaît dans un flash
----------------------------------------------------------------------

local current: Look? = nil
local currentTier = 0
local dying: { { model: Model, born: number, scale: number } } = {}
local startClock = os.clock()

local function resizeCore(tier: number)
	local map = Workspace:FindFirstChild("Map")
	local halo = map and map:FindFirstChild("BlackholeHalo")
	if halo and halo:IsA("BasePart") then
		local size = 24 + (tier - 1) * 3
		halo.Size = V(size, size, size)
	end
end

local function build(tier: number)
	tier = math.clamp(tier, 1, #HOLE.Tiers)
	if tier == currentTier then
		return
	end
	if current then
		table.insert(dying, { model = current.model, born = os.clock(), scale = current.model:GetScale() })
	end
	currentTier = tier
	local model = newModel("Tier" .. tier, folder)
	current = builders[tier](model, HOLE.Tiers[tier])
	model.WorldPivot = CFrame.identity
	resizeCore(tier)
end

----------------------------------------------------------------------
-- Jauge au-dessus du trou
----------------------------------------------------------------------

local anchor = block(folder, V(1, 1, 1), CF(0, 40, 0), Color3.new(), false, 1)
anchor.Name = "GaugeAnchor"
local board = Instance.new("BillboardGui")
board.Name = "HoleGauge"
-- Taille en studs : un panneau dans le monde, petit de loin (ne cache pas le HUD), grand de près.
board.Size = UDim2.fromScale(38, 16)
board.LightInfluence = 0
board.MaxDistance = 1200
board.Adornee = anchor
board.Parent = anchor

local function stroke(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = Color3.new(0, 0, 0)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function label(parent: Instance, text: string, y: number, height: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, height)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	stroke(l, 3)
	l.Parent = parent
	return l
end

local title = label(board, "", 0, 0.27, Color3.new(1, 1, 1))
local bar = Instance.new("Frame")
bar.Position = UDim2.fromScale(0.06, 0.3)
bar.Size = UDim2.fromScale(0.88, 0.21)
bar.BackgroundColor3 = Color3.fromRGB(25, 22, 40)
bar.Parent = board
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 10)
barCorner.Parent = bar
local barStroke = Instance.new("UIStroke")
barStroke.Thickness = 3
barStroke.Parent = bar
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.Parent = bar
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 10)
fillCorner.Parent = fill
local fillGradient = Instance.new("UIGradient")
fillGradient.Parent = fill
local amount = label(bar, "", 0.08, 0.84, Color3.new(1, 1, 1))
amount.ZIndex = 2
local hint = label(board, "", 0.54, 0.24, Color3.new(1, 1, 1))
-- Les 3 meilleurs contributeurs du cycle (attribut HoleTop, server/BlackholeTiers) : ils gagnent les cadeaux de
-- l'effondrement (Config.Blackhole.Collapse.Rewards).
local top = label(board, "", 0.8, 0.2, Color3.fromRGB(255, 210, 60))

local function refreshGauge()
	local tier = (ReplicatedStorage:GetAttribute("HoleTier") or 1) :: number
	local gauge = (ReplicatedStorage:GetAttribute("HoleGauge") or 0) :: number
	local need = (ReplicatedStorage:GetAttribute("HoleNeed") or 1) :: number
	local collapse = ReplicatedStorage:GetAttribute("HoleCollapse") == true
	local jackpotUntil = (ReplicatedStorage:GetAttribute("HoleJackpotUntil") or 0) :: number
	local def = HOLE.Tiers[math.clamp(tier, 1, #HOLE.Tiers)]
	title.Text = string.format("TROU NOIR · PALIER %d · %s", tier, def.Name)
	title.TextColor3 = def.Color
	fillGradient.Color = ColorSequence.new(def.Color, def.Color2)
	local f = math.clamp(gauge / math.max(need, 1), 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.max(f, 0.04), 1) }):Play()
	local left = jackpotUntil - Workspace:GetServerTimeNow()
	if collapse then
		amount.Text = "PLEIN !"
		hint.Text = "EFFONDREMENT À LA PROCHAINE DIGESTION !"
		hint.TextColor3 = Color3.fromRGB(255, 90, 90)
	elseif left > 0 then
		amount.Text = string.format("%d / %d", math.floor(gauge), need)
		hint.Text = string.format("JACKPOT x%d : %d s !", HOLE.Jackpot.Multiplier, math.ceil(left))
		hint.TextColor3 = def.Color
	else
		amount.Text = string.format("%d / %d", math.floor(gauge), need)
		hint.Text = if tier < #HOLE.Tiers then def.Hint else def.Hint .. " Remplis la jauge : effondrement !"
		hint.TextColor3 = Color3.new(1, 1, 1)
	end
	local entries = {}
	for name, value in string.gmatch((ReplicatedStorage:GetAttribute("HoleTop") or "") :: string, "([^=|]+)=(%d+)") do
		table.insert(entries, string.format("%d. %s %s", #entries + 1, tostring(name), tostring(value)))
	end
	top.Text = if #entries > 0 then "TOP 3 (CADEAUX À L'EFFONDREMENT) : " .. table.concat(entries, "  ") else ""
end

for _, name in ipairs({ "HoleTier", "HoleGauge", "HoleNeed", "HoleCollapse", "HoleJackpotUntil", "HoleTop" }) do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshGauge)
end
ReplicatedStorage:GetAttributeChangedSignal("HoleTier"):Connect(function()
	build((ReplicatedStorage:GetAttribute("HoleTier") or 1) :: number)
end)

----------------------------------------------------------------------
-- Annonces à l'écran
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HoleAnnounce"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

local root = ScreenScale.attach(gui)
local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.42)
banner.Size = UDim2.fromOffset(900, 190)
banner.BackgroundTransparency = 1
banner.Visible = false
banner.Parent = root
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
local bannerTop = label(banner, "", 0, 0.24, Color3.new(1, 1, 1))
local bannerTitle = label(banner, "", 0.22, 0.5, Color3.new(1, 1, 1))
local bannerSub = label(banner, "", 0.74, 0.24, Color3.new(1, 1, 1))
for _, l in ipairs({ bannerTop, bannerTitle, bannerSub }) do
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Thickness = if l == bannerTitle then 6 else 4
	end
end
local bannerToken = 0

local function showBanner(top: string, text: string, sub: string, color: Color3, hold: number)
	bannerToken += 1
	local token = bannerToken
	bannerTop.Text, bannerTitle.Text, bannerSub.Text = top, text, sub
	bannerTitle.TextColor3 = color
	for _, l in ipairs({ bannerTop, bannerTitle, bannerSub }) do
		l.TextTransparency = 0
		local s = l:FindFirstChildOfClass("UIStroke")
		if s then
			s.Transparency = 0
		end
	end
	banner.Visible = true
	bannerScale.Scale = 0.3
	TweenService:Create(bannerScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(hold, function()
		if token ~= bannerToken then
			return
		end
		local fade = TweenInfo.new(0.5)
		for _, l in ipairs({ bannerTop, bannerTitle, bannerSub }) do
			TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
			local s = l:FindFirstChildOfClass("UIStroke")
			if s then
				TweenService:Create(s, fade, { Transparency = 1 }):Play()
			end
		end
		task.delay(0.55, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	end)
end

local function screenFlash(color: Color3, strength: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

-- Petite secousse de caméra (décalage du Humanoid, rendu local).
local shakeUntil, shakePower = 0, 0
local function shake(power: number, duration: number)
	shakePower = power
	shakeUntil = os.clock() + duration
end

-- Bulle de texte qui monte au-dessus d'un point du monde (centre x2, combo, tentacule).
local function popText(position: Vector3, text: string, color: Color3)
	local holder = block(folder, V(1, 1, 1), CF(position + V(0, 3, 0)), Color3.new(), false, 1)
	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(240, 60)
	bubble.AlwaysOnTop = true
	bubble.LightInfluence = 0
	bubble.MaxDistance = 260
	bubble.Parent = holder
	local l = label(bubble, text, 0, 1, color)
	TweenService:Create(bubble, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { StudsOffset = V(0, 8, 0) }):Play()
	local fade = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
	local outline = l:FindFirstChildOfClass("UIStroke")
	if outline then
		TweenService:Create(outline, fade, { Transparency = 1 }):Play()
	end
	Debris:AddItem(holder, 1.3)
end

-- Un familier jeté dans le trou : le porteur prend son élan (client/PetFollow anime les bras), ses mains le lâchent
-- (Config.Sacrifice.Throw.Release) ; il part de là, à la même taille, s'envole en cloche en tournoyant, rétrécit dans
-- le cœur, gerbe d'étincelles.
type Flight = { model: Model, from: Vector3, rotation: CFrame, born: number, scale: number, color: Color3 }
local flights: { Flight } = {}
local FLIGHT_TIME = 1.1
local RELEASE = Config.Sacrifice.Throw.Release

-- Le familier que tient encore ce joueur (client/PetFollow, attribut "HeldBy"), s'il est affiché.
local function heldModel(carrier: Player?): Model?
	local pets = Workspace:FindFirstChild("Pets")
	if not carrier or not pets then
		return nil
	end
	for _, child in ipairs(pets:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("HeldBy") == carrier.UserId then
			return child
		end
	end
	return nil
end

local function launch(from: Vector3, petId: string, money: number, mine: boolean, carrier: Player?)
	local model = PetModelBuilder.Build(petId)
	local entry = PetCatalog.ById[petId]
	if not model or not entry then
		return
	end
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity] or 1]
	local start, rotation = from + V(0, 4, 0), CFrame.identity
	local held = heldModel(carrier)
	if held then
		-- Il quitte les mains exactement où il était, à la même taille.
		local pivot = held:GetPivot()
		start, rotation = pivot.Position, pivot.Rotation
		model:ScaleTo(held:GetScale())
	else
		-- Les très grands familiers sont réduits pour le vol (sinon ils cacheraient tout le trou).
		local _, size = PetModelBuilder.BodyBounds(model)
		if size.Y > 12 then
			model:ScaleTo(model:GetScale() * 12 / size.Y)
		end
	end
	model:PivotTo(CF(start) * rotation)
	model.Parent = folder
	table.insert(flights, { model = model, from = start, rotation = rotation, born = os.clock(), scale = model:GetScale(), color = rarity.Color })
	if mine then
		Sounds.play("Throw")
		Sounds.play("HoleCatch")
	else
		Sounds.playAt("HoleCatch", start)
	end
	task.delay(FLIGHT_TIME, function()
		local burst = emitArea(folder, V(4, 4, 4), CF(0, CORE_Y, 0))
		local fx = emitter(burst, SPARK, rarity.Color, 0, 3, 40, 1.2)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx:Emit(60)
		Debris:AddItem(burst, 2)
		shockwave(rarity.Color, 6, 70, 1)
		popText(V(0, CORE_Y + 14, 0), "+" .. NumberFormat.money(money), Color3.fromRGB(110, 240, 70))
		if mine then
			Sounds.play("HoleBonus")
			shake(0.4, 0.4)
		end
	end)
end

local function sacrifice(from: Vector3, petId: string, money: number, mine: boolean, carrier: Player?)
	-- Le serveur a déjà validé : on attend juste que les mains le lâchent.
	task.delay(RELEASE, launch, from, petId, money, mine, carrier)
end

local function updateFlights()
	local now = os.clock()
	for i = #flights, 1, -1 do
		local flight = flights[i]
		local f = (now - flight.born) / FLIGHT_TIME
		if f >= 1 then
			flight.model:Destroy()
			table.remove(flights, i)
		else
			local target = V(0, CORE_Y, 0)
			local position = flight.from:Lerp(target, f) + V(0, math.sin(f * math.pi) * 22, 0)
			flight.model:ScaleTo(math.max(0.05, flight.scale * (1 - f * 0.85)))
			flight.model:PivotTo(CF(position) * flight.rotation * ANG(f * 7, f * 11, 0))
		end
	end
end

----------------------------------------------------------------------
-- Événements du serveur
----------------------------------------------------------------------

Remotes.HoleEvent.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any)
	local tier = (ReplicatedStorage:GetAttribute("HoleTier") or 1) :: number
	local def = HOLE.Tiers[math.clamp(tier, 1, #HOLE.Tiers)]
	if kind == "TierUp" and type(a) == "number" then
		local newDef = HOLE.Tiers[math.clamp(a, 1, #HOLE.Tiers)]
		build(a)
		screenFlash(newDef.Color, 0.55)
		shockwave(newDef.Color, 8, 140, 1.6)
		shockwave(newDef.Color2, 8, 90, 1.1)
		shake(0.8, 0.9)
		Sounds.play("HoleTierUp")
		Sounds.play("HoleRumble")
		Sounds.duck(4)
		showBanner("LE TROU NOIR ÉVOLUE !", string.format("PALIER %d : %s", a, newDef.Name), newDef.Hint, newDef.Color, 3.6)
	elseif kind == "Spit" then
		Sounds.playAt("HoleRumble", V(0, CORE_Y, 0))
		shake(0.3, 0.4)
	elseif kind == "Bullseye" and typeof(a) == "Vector3" then
		popText(a, string.format("CENTRE ! x%d", HOLE.Target.Multiplier), def.Color)
		if b == localPlayer then
			Sounds.play("HoleBonus")
		end
	elseif kind == "Catch" and typeof(a) == "Vector3" then
		popText(a, "ATTRAPÉ !", def.Color)
		Sounds.playAt("HoleCatch", a)
	elseif kind == "Meteors" then
		Sounds.play("HoleMeteors")
		showBanner("", "PLUIE DE MÉTÉORITES !", "Ramasse-les : +" .. HOLE.Gravity.MeteorValue .. " points chacune", def.Color, 2.2)
	elseif kind == "Combo" and typeof(a) == "Vector3" and type(c) == "number" then
		popText(a, "COMBO x" .. tostring(math.floor(c * 100 + 0.5) / 100), if c >= HOLE.Combo.Max then def.Color2 else def.Color)
		if b == localPlayer then
			Sounds.play("HoleBonus")
		end
	elseif kind == "Jackpot" then
		Sounds.play("HoleJackpot")
		screenFlash(def.Color, 0.35)
		showBanner("", string.format("JACKPOT x%d !", HOLE.Jackpot.Multiplier),
			string.format("Pendant %d s, chaque objet avalé vaut %d fois plus !", HOLE.Jackpot.Duration, HOLE.Jackpot.Multiplier), def.Color, 3)
	elseif kind == "CollapseSoon" then
		Sounds.play("HoleRumble")
		shake(0.5, 0.8)
		showBanner("LA JAUGE EST PLEINE !", "EFFONDREMENT IMMINENT", string.format(
			"À la prochaine digestion : score x%d et familiers offerts aux 3 meilleurs !", HOLE.Collapse.ScoreMultiplier),
			Color3.fromRGB(255, 80, 80), 3.6)
	elseif kind == "Sacrifice" and typeof(a) == "Vector3" and type(b) == "string" then
		local carrier = if typeof(c) == "Instance" and c:IsA("Player") then c else nil
		sacrifice(a, b, if type(d) == "number" then d else 0, c == localPlayer, carrier)
	elseif kind == "Collapse" then
		local names = if type(a) == "table" then a else {}
		screenFlash(Color3.new(1, 1, 1), 0.9)
		shockwave(Color3.new(1, 1, 1), 150, 6, 1.2)
		shockwave(Color3.fromRGB(255, 80, 80), 6, 160, 1.8)
		shake(1.2, 1.4)
		Sounds.play("HoleCollapse")
		Sounds.play("HoleRumble")
		Sounds.duck(4)
		local sub = if #names > 0 then "Cadeaux : " .. table.concat(names, ", ") else "Le trou noir renaît au palier 1."
		showBanner(string.format("SCORE DU TOUR x%d !", HOLE.Collapse.ScoreMultiplier), "EFFONDREMENT !", sub,
			Color3.fromRGB(255, 80, 80), 4)
	end
	if current and current.event then
		current.event(kind, a, b)
	end
end)

----------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt: number)
	local t = os.clock() - startClock
	if current then
		current.update(t, dt)
	end
	-- L'ancien aspect est aspiré dans le cœur.
	for i = #dying, 1, -1 do
		local entry = dying[i]
		local f = (os.clock() - entry.born) / 0.9
		if f >= 1 then
			entry.model:Destroy()
			table.remove(dying, i)
		else
			entry.model:ScaleTo(math.max(0.02, entry.scale * (1 - f) ^ 2))
			entry.model:PivotTo(ANG(0, f * 6, 0))
		end
	end
	updateWaves()
	updateFlights()
	-- Astéroïdes du cadre (monde Cosmos) : ils flottent et tournent doucement.
	local frame = worldFrame
	if frame then
		for _, spin in ipairs(frame.spinning) do
			spin.part.CFrame = spin.origin * CF(0, math.sin(t * 1.3 + spin.phase) * 0.8, 0) * ANG(t * 0.4, t * 0.6 + spin.phase, 0)
		end
	end
	-- Secousse.
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local left = shakeUntil - os.clock()
		if left > 0 then
			local p = shakePower * math.min(1, left * 2)
			humanoid.CameraOffset = V(rng:NextNumber(-p, p), rng:NextNumber(-p, p), rng:NextNumber(-p, p))
		elseif humanoid.CameraOffset ~= Vector3.zero and shakeUntil > 0 then
			humanoid.CameraOffset = Vector3.zero
			shakeUntil = 0
		end
	end
end)

-- Compte à rebours du jackpot sur la jauge.
task.spawn(function()
	while true do
		task.wait(1)
		local until_ = (ReplicatedStorage:GetAttribute("HoleJackpotUntil") or 0) :: number
		if until_ > Workspace:GetServerTimeNow() - 1 then
			refreshGauge()
		end
	end
end)

build((ReplicatedStorage:GetAttribute("HoleTier") or 1) :: number)
refreshGauge()

-- Cadre du trou aux couleurs du monde du joueur, reconstruit quand il change de monde.
buildWorldFrame()
localPlayer:GetAttributeChangedSignal("World"):Connect(buildWorldFrame)
localPlayer:GetAttributeChangedSignal("Tier"):Connect(buildWorldFrame)
