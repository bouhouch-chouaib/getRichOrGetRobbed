--!strict
-- StationLooks : habillage du tapis de course et du banc selon leur niveau (style briques à tenons).
-- 25 niveaux = 5 modèles (Config.Training.StationTiers) : Bois, Acier, Or, Cristal, Cosmique.
-- Dans un modèle, chaque niveau allume un voyant de plus ; au 5e, une étoile dorée coiffe la station.
--
-- La station garde ses pièces « utiles » créées par MapGenerator (Zone, Bar, Plate, Seat... marquées "Tint") :
-- on ne fait que les recolorer. Tout le décor est reconstruit dans le dossier "Look" à chaque changement de niveau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local StationLooks = {}

local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- cylindre couché à plat
local OFF_LAMP = Color3.fromRGB(45, 45, 52)
local GOLD = Color3.fromRGB(255, 205, 50)

type Tier = Config.StationTier

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.Parent = parent
	return part
end

local function neon(part: Part, transparency: number?): Part
	part.Material = Enum.Material.Neon
	part.Transparency = transparency or 0
	part.CastShadow = false
	return part
end

-- Cercle lumineux au sol sous la station (anneau + disque plus pâle), comme les zones de la référence.
local function groundCircle(origin: CFrame, diameter: number, color: Color3, parent: Instance)
	local ring = block("GlowRing", Vector3.new(0.1, diameter, diameter), origin * CFrame.new(0, 0.07, 0) * FLAT, color, parent)
	ring.Shape = Enum.PartType.Cylinder
	neon(ring, 0.25)
	local fill = block("GlowFill", Vector3.new(0.1, diameter - 1.6, diameter - 1.6), origin * CFrame.new(0, 0.1, 0) * FLAT, color:Lerp(Color3.new(1, 1, 1), 0.5), parent)
	fill.Shape = Enum.PartType.Cylinder
	neon(fill, 0.7)
end

-- Rangée de voyants : `lit` allumés sur LevelsPerTier.
local function lamps(origin: CFrame, spacing: number, lit: number, tier: Tier, parent: Instance)
	local count = Config.Training.LevelsPerTier
	for index = 1, count do
		local x = (index - (count + 1) / 2) * spacing
		local lamp = block("Lamp", Vector3.new(0.7, 0.7, 0.4), origin * CFrame.new(x, 0, 0), if index <= lit then tier.Accent else OFF_LAMP, parent)
		if index <= lit then
			neon(lamp)
		end
	end
end

-- Étoile dorée (niveau max du modèle) : deux blocs croisés à 45°.
local function star(origin: CFrame, parent: Instance)
	for _, angle in ipairs({ 0, math.pi / 4 }) do
		neon(block("Star", Vector3.new(1.6, 1.6, 0.5), origin * CFrame.Angles(0, 0, angle), GOLD, parent))
	end
end

-- Portique au-dessus de la station (Or et au-delà).
local function arch(origin: CFrame, width: number, height: number, tier: Tier, parent: Instance)
	local trim = tier.Trim or tier.Dark
	for _, side in ipairs({ -1, 1 }) do
		block("ArchPillar", Vector3.new(1.4, height, 1.4), origin * CFrame.new(side * width / 2, height / 2, 0), tier.Main, parent)
		block("ArchFoot", Vector3.new(2.2, 0.8, 2.2), origin * CFrame.new(side * width / 2, 0.4, 0), trim, parent)
	end
	block("ArchBeam", Vector3.new(width + 2.4, 1.4, 1.8), origin * CFrame.new(0, height + 0.7, 0), tier.Main, parent)
	block("ArchTrim", Vector3.new(width + 2.6, 0.4, 2), origin * CFrame.new(0, height, 0), trim, parent)
end

-- Cristaux lumineux (Cristal) : blocs de verre inclinés.
local function crystal(origin: CFrame, height: number, color: Color3, parent: Instance)
	local shard = block("Crystal", Vector3.new(1.4, height, 1.4), origin * CFrame.new(0, height / 2, 0) * CFrame.Angles(math.rad(12), math.rad(45), math.rad(8)), color, parent)
	shard.Material = Enum.Material.Glass
	shard.Transparency = 0.15
	local core = block("CrystalCore", Vector3.new(0.6, height * 0.7, 0.6), shard.CFrame, color, parent)
	neon(core)
end

-- Halo de blocs (Cosmique) : un cercle vertical de petits cubes néon.
local function halo(origin: CFrame, radius: number, color: Color3, parent: Instance)
	local count = 14
	for index = 0, count - 1 do
		local angle = index / count * math.pi * 2
		neon(block("Halo", Vector3.new(0.8, 0.8, 0.8), origin * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0) * CFrame.Angles(0, 0, angle), color, parent))
	end
end

local function glowEffects(anchor: BasePart, tier: Tier)
	local light = Instance.new("PointLight")
	light.Name = "StationLight"
	light.Range = 16
	light.Brightness = 1.6
	light.Color = tier.Accent
	light.Parent = anchor
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "StationSparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Rate = 16
	sparkles.Lifetime = NumberRange.new(0.8, 1.6)
	sparkles.Speed = NumberRange.new(2, 5)
	sparkles.SpreadAngle = Vector2.new(30, 30)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.LightEmission = 1
	sparkles.Color = ColorSequence.new(tier.Accent, tier.Trim or tier.Accent)
	sparkles.Parent = anchor
end

----------------------------------------------------------------------
-- Tapis de course (repère : sol, -Z vers la console)
----------------------------------------------------------------------

local function treadmill(origin: CFrame, tier: Tier, rank: number, tierIndex: number, look: Folder)
	groundCircle(origin, 27, tier.Accent, look)
	block("Deck", Vector3.new(11.2, 0.5, 21), origin * CFrame.new(0, 0.25, 0), tier.Dark, look)
	for _, side in ipairs({ -1, 1 }) do
		block("SideRail", Vector3.new(1.4, 1.4, 21.4), origin * CFrame.new(side * 5.7, 0.7, 0), tier.Main, look)
		block("Upright", Vector3.new(1, 4.2, 1), origin * CFrame.new(side * 5.7, 3.5, -9.6), tier.Main, look)
		block("Handrail", Vector3.new(0.7, 0.7, 8), origin * CFrame.new(side * 5.7, 5, -5.6), tier.Main, look)
		block("RailFoot", Vector3.new(1.6, 0.6, 2.2), origin * CFrame.new(side * 5.7, 0.3, 9.6), tier.Dark, look)
		if tierIndex >= 2 then
			-- Bande de couleur sur les rails (Acier et au-delà).
			block("RailStripe", Vector3.new(0.3, 0.5, 21.4), origin * CFrame.new(side * 6.45, 0.9, 0), tier.Trim or tier.Accent, look)
		end
	end
	block("Console", Vector3.new(12.6, 1.8, 2.2), origin * CFrame.new(0, 6.3, -9.6), tier.Main, look)
	block("ConsoleBase", Vector3.new(12.8, 0.5, 2.4), origin * CFrame.new(0, 5.2, -9.6), tier.Dark, look)
	neon(block("Screen", Vector3.new(5, 0.9, 0.2), origin * CFrame.new(0, 6.05, -8.45), tier.Accent, look))
	lamps(origin * CFrame.new(0, 6.95, -8.4), 1.3, rank, tier, look)
	lamps(origin * CFrame.new(0, 6.95, -10.8), 1.3, rank, tier, look) -- visibles aussi du côté du trou noir
	-- Chevrons lumineux sur le tapis (Cristal et au-delà).
	if tierIndex >= 4 then
		for index = 0, 3 do
			local z = -6 + index * 4.5
			for _, side in ipairs({ -1, 1 }) do
				local chevron = block("Chevron", Vector3.new(3.2, 0.1, 0.6), origin * CFrame.new(side * 1.4, 0.64, z) * CFrame.Angles(0, side * math.rad(35), 0), tier.Accent, look)
				neon(chevron)
			end
		end
	end
	if tierIndex >= 3 then
		arch(origin * CFrame.new(0, 0, 9.6), 11.4, 9, tier, look)
	end
	if tierIndex == 4 then
		for _, corner in ipairs({ Vector2.new(-7.2, -10), Vector2.new(7.2, -10), Vector2.new(-7.2, 10.5), Vector2.new(7.2, 10.5) }) do
			crystal(origin * CFrame.new(corner.X, 0, corner.Y), 4.5, tier.Accent, look)
		end
	end
	if tierIndex == 5 then
		halo(origin * CFrame.new(0, 10.5, 9.6), 5.2, tier.Accent, look)
		for _, side in ipairs({ -1, 1 }) do
			neon(block("TrimLine", Vector3.new(0.3, 0.3, 21.4), origin * CFrame.new(side * 6.45, 1.5, 0), tier.Trim or tier.Accent, look))
		end
	end
	if rank == Config.Training.LevelsPerTier then
		star(origin * CFrame.new(0, 8.2, -9.6), look)
	end
end

----------------------------------------------------------------------
-- Banc de muscu (repère : sol, -Z vers la tête / la barre)
----------------------------------------------------------------------

local function dumbbell(origin: CFrame, tier: Tier, parent: Instance)
	block("DumbbellBar", Vector3.new(2.4, 0.4, 0.4), origin * CFrame.new(0, 0.5, 0), tier.Dark, parent)
	for _, side in ipairs({ -1, 1 }) do
		block("DumbbellWeight", Vector3.new(0.7, 1, 1), origin * CFrame.new(side * 1.2, 0.5, 0), tier.Main, parent)
	end
end

local function bench(origin: CFrame, tier: Tier, rank: number, tierIndex: number, look: Folder)
	groundCircle(origin, 22, tier.Accent, look)
	for _, side in ipairs({ -1, 1 }) do
		block("RackFoot", Vector3.new(1.6, 0.6, 3.4), origin * CFrame.new(side * 2.2, 0.3, -3.2), tier.Dark, look)
		block("Hook", Vector3.new(1, 0.4, 1), origin * CFrame.new(side * 2.2, 4.6, -3.6), tier.Dark, look)
	end
	-- Petit tableau de voyants au pied du banc.
	block("Panel", Vector3.new(7.2, 1.6, 0.8), origin * CFrame.new(0, 0.8, 7.2), tier.Main, look)
	lamps(origin * CFrame.new(0, 1.85, 7.2), 1.3, rank, tier, look)
	-- Haltères posées au sol et porte-disques.
	dumbbell(origin * CFrame.new(-5, 0, 4.5), tier, look)
	dumbbell(origin * CFrame.new(-5, 0, 6.2), tier, look)
	block("PlateTree", Vector3.new(0.8, 4, 0.8), origin * CFrame.new(5, 2, 4.5), tier.Dark, look)
	block("PlateTreeFoot", Vector3.new(2.4, 0.4, 2.4), origin * CFrame.new(5, 0.2, 4.5), tier.Dark, look)
	for index, y in ipairs({ 1.4, 2.6 }) do
		local plate = block("SparePlate", Vector3.new(0.5, 2.2 - index * 0.3, 2.2 - index * 0.3), origin * CFrame.new(5.5, y, 4.5), tier.Main, look)
		plate.Shape = Enum.PartType.Cylinder
	end
	if tierIndex >= 3 then
		arch(origin * CFrame.new(0, 0, -6.2), 10, 8, tier, look)
	end
	if tierIndex == 4 then
		for _, corner in ipairs({ Vector2.new(-6.5, -6.5), Vector2.new(6.5, -6.5), Vector2.new(-6.5, 6.5), Vector2.new(6.5, 6.5) }) do
			crystal(origin * CFrame.new(corner.X, 0, corner.Y), 4, tier.Accent, look)
		end
	end
	if tierIndex == 5 then
		halo(origin * CFrame.new(0, 9.4, -6.2), 4.6, tier.Accent, look)
	end
	if rank == Config.Training.LevelsPerTier then
		star(origin * CFrame.new(0, 3.2, 7.2), look)
	end
end

----------------------------------------------------------------------

-- Couleurs des pièces utiles (créées par MapGenerator) selon leur nom.
local function recolor(model: Model, tier: Tier, tierIndex: number)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			if part.Name == "Zone" then
				part.Color = tier.Belt
			elseif part.Name == "Bar" then
				part.Color = if tierIndex >= 3 then GOLD else Color3.fromRGB(205, 208, 215)
			elseif part.Name == "Plate" then
				part.Color = if tierIndex == 1 then Color3.fromRGB(35, 35, 40) else tier.Accent
				part.Material = if tierIndex >= 4 then Enum.Material.Neon else Enum.Material.Plastic
			elseif part:GetAttribute("Tint") then
				part.Color = if part.Name == "Seat" then tier.Belt else tier.Main
			end
		end
	end
end

-- Repère au sol de la station, retrouvé à partir de sa Zone (posée sur le sol).
local function originOf(zone: BasePart): CFrame
	return zone.CFrame * CFrame.new(0, -zone.Size.Y / 2, 0)
end

-- Applique le modèle du niveau (1 à 25) à la station. kind = "Treadmill" ou "Bench".
function StationLooks.Apply(model: Model, kind: string, level: number)
	local zone = model:FindFirstChild("Zone")
	if not zone or not zone:IsA("BasePart") then
		return
	end
	local old = model:FindFirstChild("Look")
	if old then
		old:Destroy()
	end
	for _, name in ipairs({ "StationLight", "StationSparkles" }) do
		local effect = zone:FindFirstChild(name)
		if effect then
			effect:Destroy()
		end
	end
	if level <= 0 then
		return
	end

	local tier, rank = Config.GetStationTier(level)
	local tierIndex = table.find(Config.Training.StationTiers, tier) or 1
	local look = Instance.new("Folder")
	look.Name = "Look"
	local origin = originOf(zone)
	if kind == "Treadmill" then
		treadmill(origin, tier, rank, tierIndex, look)
	else
		bench(origin, tier, rank, tierIndex, look)
	end
	recolor(model, tier, tierIndex)
	if tier.Glow then
		glowEffects(zone, tier)
	end
	look.Parent = model
end

return StationLooks
