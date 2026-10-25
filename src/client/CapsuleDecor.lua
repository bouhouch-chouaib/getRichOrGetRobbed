--!strict
-- CapsuleDecor : la capsule d'évolution suit le niveau du joueur (monde le plus loin atteint, attribut CapsuleTier
-- publié par server/EggController). Plus le monde est loin, plus elle est grande et épique, avec le thème du monde
-- (shared/Worlds) :
--   1 Prairie  : la capsule de base.
--   2 Désert   : 2 obélisques de grès à pointe dorée, tourbillon de sable.
--   3 Volcan   : blocs de roche volcanique fissurés de lave, cheminées qui crachent des braises.
--   4 Glace    : pics de cristal de glace, anneau de givre au sol, neige.
--   5 Abysses  : spirale lumineuse qui tourne autour du verre, algues, bulles.
--   6 Cosmos   : 2 anneaux d'orbite inclinés qui tournent, petites planètes en orbite, étoiles.
--   7 Divin    : auréole dorée qui tourne, ailes de lumière, rayon jusqu'au ciel, plumes.
-- Tout est local (chaque client décore les capsules), ni collision ni requête.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Worlds = require(ReplicatedStorage.Shared.Worlds)

local CapsuleDecor = {}

local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local WHITE = Color3.new(1, 1, 1)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local FLAT = ANG(0, 0, math.pi / 2)

export type Decor = {
	folder: Folder,
	accent: Color3,
	scale: number,
	update: (clock: number) -> (),
}

-- Couleur du monde de ce niveau.
function CapsuleDecor.Accent(tier: number): Color3
	local world = Config.Worlds[math.clamp(tier, 1, #Config.Worlds)]
	local look = Worlds.Looks[world.Id]
	return if look then look.Accent else Color3.fromRGB(70, 230, 255)
end

-- Taille de la capsule à ce niveau (elle grandit d'un monde à l'autre).
function CapsuleDecor.Scale(tier: number): number
	return 1 + (math.clamp(tier, 1, #Config.Worlds) - 1) * 0.07
end

local function block(folder: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, neon: boolean?, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size, part.CFrame, part.Color = size, cf, color
	-- plus de néon sur la capsule (Chouaib, 25 oct.) : les pièces « vives » restent en plastique lisse coloré
	part.Material = if neon then Enum.Material.SmoothPlastic else (material or Enum.Material.Plastic)
	part.TopSurface = Enum.SurfaceType.Studs
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Parent = folder
	return part
end

-- Pièce invisible qui porte des particules.
local function source(folder: Instance, name: string, size: Vector3, cf: CFrame): Part
	local part = block(folder, name, size, cf, WHITE)
	part.Transparency = 1
	return part
end

-- Anneau fait de blocs lumineux (un vrai anneau, pas un disque plein), dans un Model qu'on fait tourner d'un coup.
local function blockRing(folder: Instance, name: string, center: CFrame, radius: number, count: number, size: number, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	for index = 1, count do
		local angle = index * 2 * math.pi / count
		block(model, "RingBlock", V(size, size * 0.6, size * 1.6), center * CF(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			* ANG(0, -angle, 0), if index % 4 == 0 then WHITE else color, true)
	end
	local pivot = Instance.new("Part")
	pivot.Name = "Pivot"
	pivot.Size, pivot.CFrame, pivot.Transparency = V(0.2, 0.2, 0.2), center, 1
	pivot.Anchored, pivot.CanCollide, pivot.CanQuery, pivot.CanTouch = true, false, false, false
	pivot.Parent = model
	model.PrimaryPart = pivot
	model.Parent = folder
	return model
end

local function emitter(parent: Instance, texture: string, color: Color3, rate: number, speed: number, size: number, life: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture, e.Color = texture, ColorSequence.new(color, WHITE)
	e.Rate, e.Speed, e.Lifetime = rate, NumberRange.new(speed * 0.6, speed), NumberRange.new(life * 0.7, life)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = if texture == SMOKE then 0 else 0.8
	e.SpreadAngle = Vector2.new(30, 30)
	e.Parent = parent
	return e
end

-- Construit le décor autour de la capsule. pad = le socle (pièce EvolutionMachine), déjà à la bonne taille.
function CapsuleDecor.Build(pad: BasePart, tier: number, parent: Instance): Decor
	tier = math.clamp(tier, 1, #Config.Worlds)
	local folder = Instance.new("Folder")
	folder.Name = "CapsuleDecor"
	folder.Parent = parent
	local accent = CapsuleDecor.Accent(tier)
	local s = CapsuleDecor.Scale(tier)
	local base = pad.CFrame * CF(0, -pad.Size.Y / 2, 0) -- au sol, au centre de la capsule
	local function at(x: number, y: number, z: number): CFrame
		return base * CF(x * s, y * s, z * s)
	end
	local spinners: { { model: Model, center: CFrame, speed: number, offset: CFrame } } = {}
	local orbiters: { { part: Part, radius: number, height: number, speed: number, phase: number, tilt: number } } = {}

	if tier == 2 then
		-- Désert : obélisques de grès à pointe dorée.
		for _, side in ipairs({ -1, 1 }) do
			block(folder, "ObeliskBase", V(2.6, 1, 2.6) * s, at(side * 8, 0.5, 2), Color3.fromRGB(226, 170, 100))
			block(folder, "Obelisk", V(1.6, 8, 1.6) * s, at(side * 8, 5, 2), Color3.fromRGB(236, 190, 120))
			block(folder, "ObeliskTip", V(1.2, 1.2, 1.2) * s, at(side * 8, 9.6, 2) * ANG(math.pi / 4, 0, math.pi / 4), Color3.fromRGB(255, 200, 60), true)
		end
		emitter(source(folder, "SandSwirl", V(1, 1, 1), at(0, 1, 0)), SMOKE, Color3.fromRGB(240, 200, 130), 4, 3, 2, 2.5)
	elseif tier == 3 then
		-- Volcan : roche fissurée de lave aux coins, cheminées à braises.
		for index, corner in ipairs({ V(-1, 0, -1), V(1, 0, -1), V(-1, 0, 1), V(1, 0, 1) }) do
			local rock = block(folder, "LavaRock", V(3, 2.4, 3) * s, at(corner.X * 6.6, 1.2, corner.Z * 6.6) * ANG(0, index, 0.15), Color3.fromRGB(60, 50, 54))
			block(folder, "LavaCrack", V(3.1, 0.25, 0.4) * s, rock.CFrame * CF(0, 0.3 * s, 0), Color3.fromRGB(255, 110, 30), true)
		end
		for _, side in ipairs({ -1, 1 }) do
			local vent = block(folder, "Vent", V(1.6, 3, 1.6) * s, at(side * 6.5, 1.5, -3), Color3.fromRGB(46, 38, 42))
			local embers = emitter(vent, FIRE, Color3.fromRGB(255, 120, 30), 10, 6, 0.8, 1.2)
			embers.EmissionDirection = Enum.NormalId.Top
		end
	elseif tier == 4 then
		-- Glace : pics de cristal autour, anneau de givre, neige.
		for index = 1, 8 do
			local angle = index * math.pi / 4
			local height = if index % 2 == 0 then 6 else 4
			local crystal = block(folder, "IceSpike", V(1.2, height, 1.2) * s,
				at(math.cos(angle) * 6.8, height / 2, math.sin(angle) * 6.8) * ANG(math.sin(angle) * 0.3, 0, -math.cos(angle) * 0.3),
				Color3.fromRGB(190, 235, 255), false, Enum.Material.Glass)
			crystal.Transparency = 0.25
		end
		local frost = block(folder, "FrostRing", V(0.2, 15, 15) * s, at(0, 0.15, 0) * FLAT, Color3.fromRGB(230, 248, 255), true)
		frost.Shape = Enum.PartType.Cylinder
		frost.Transparency = 0.5
		local snow = emitter(source(folder, "SnowSource", V(12, 0.2, 12) * s, at(0, 16, 0)), SPARK, WHITE, 14, 2, 0.3, 4)
		snow.EmissionDirection = Enum.NormalId.Bottom
	elseif tier == 5 then
		-- Abysses : spirale lumineuse autour du verre, algues, bulles.
		for index = 1, 26 do
			local t = index / 26
			local angle = t * math.pi * 4
			local piece = block(folder, "Helix", V(0.6, 0.6, 0.6) * s, at(math.cos(angle) * 4, 2.5 + t * 9, math.sin(angle) * 4), accent, true)
			table.insert(orbiters, { part = piece, radius = 4 * s, height = (2.5 + t * 9) * s, speed = 0.8, phase = angle, tilt = 0 })
		end
		for _, side in ipairs({ -1, 1 }) do
			for level = 0, 5 do
				block(folder, "Seaweed", V(0.8, 1.4, 0.8) * s, at(side * 7.2 + math.sin(level) * 0.4, 0.7 + level * 1.4, 3), Color3.fromRGB(40, 160, 110))
			end
		end
		emitter(source(folder, "Bubbles", V(4, 0.2, 4) * s, at(0, 2.5, 0)), SPARK, Color3.fromRGB(160, 255, 240), 8, 3, 0.35, 3)
	elseif tier == 6 then
		-- Cosmos : anneaux d'orbite qui tournent, planètes, étoiles.
		for index, tilt in ipairs({ 0.45, -0.6 }) do
			local center = at(0, 7.5, 0)
			local orbit = blockRing(folder, "OrbitRing", center, 7.5 * s, 28, 0.7 * s, if index == 1 then accent else Color3.fromRGB(255, 150, 230))
			table.insert(spinners, { model = orbit, center = center, speed = if index == 1 then 0.6 else -0.45, offset = ANG(tilt, 0, tilt * 0.5) })
		end
		for index, color in ipairs({ Color3.fromRGB(255, 120, 80), Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 220, 90) }) do
			local planet = block(folder, "Planet", V(1.4, 1.4, 1.4) * s, at(0, 0, 0), color)
			table.insert(orbiters, { part = planet, radius = (6 + index) * s, height = (4 + index * 2.5) * s, speed = 0.5 + index * 0.2, phase = index * 2, tilt = 0.3 })
		end
		emitter(source(folder, "Stars", V(14, 14, 14) * s, at(0, 8, 0)), SPARK, accent, 10, 0.5, 0.35, 2.5)
	elseif tier >= 7 then
		-- Divin : auréole dorée, ailes de lumière, rayon jusqu'au ciel, plumes.
		local haloCenter = at(0, 20.5, 0)
		local halo = blockRing(folder, "Halo", haloCenter, 5 * s, 20, 0.8 * s, Color3.fromRGB(255, 215, 70))
		table.insert(spinners, { model = halo, center = haloCenter, speed = 0.8, offset = CFrame.identity })
		local innerCenter = at(0, 19.5, 0)
		local inner = blockRing(folder, "HaloInner", innerCenter, 3.4 * s, 14, 0.6 * s, WHITE)
		table.insert(spinners, { model = inner, center = innerCenter, speed = -1.2, offset = CFrame.identity })
		-- Grandes ailes de lumière dans le dos de la capsule (7 plumes chacune, en éventail).
		for _, side in ipairs({ -1, 1 }) do
			for feather = 0, 6 do
				local length = 12 - feather * 1.1
				block(folder, "Wing", V(0.6, length, 2.2) * s,
					at(side * (4.8 + feather * 0.35), 8 + feather * 0.9, 3.5) * ANG(0, 0, side * (0.35 + feather * 0.22)) * CF(0, length / 2 * s, 0),
					if feather % 2 == 0 then Color3.fromRGB(255, 244, 200) else Color3.fromRGB(255, 220, 110), true).Transparency = 0.1
			end
		end
		local beam = block(folder, "SkyBeam", V(80, 3, 3) * s, at(0, 21 + 40, 0) * FLAT, Color3.fromRGB(255, 235, 150), true)
		beam.Shape = Enum.PartType.Cylinder
		beam.Transparency = 0.7
		emitter(source(folder, "Feathers", V(12, 1, 12) * s, at(0, 18, 0)), SPARK, Color3.fromRGB(255, 225, 120), 12, 1.5, 0.45, 3.5)
	end

	local function update(clock: number)
		for _, spin in ipairs(spinners) do
			spin.model:PivotTo(spin.center * spin.offset * ANG(0, clock * spin.speed, 0))
		end
		for _, orbit in ipairs(orbiters) do
			local angle = orbit.phase + clock * orbit.speed
			orbit.part.CFrame = base * ANG(orbit.tilt, 0, 0) * CF(math.cos(angle) * orbit.radius, orbit.height, math.sin(angle) * orbit.radius)
				* ANG(clock, clock * 0.7, 0)
		end
	end
	return { folder = folder, accent = accent, scale = s, update = update }
end

return CapsuleDecor
