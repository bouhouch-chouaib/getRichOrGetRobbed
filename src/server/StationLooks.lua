--!strict
-- StationLooks : habillage du tapis de course et du banc selon leur niveau (style briques à tenons).
-- 25 niveaux = 10 modèles (Config.Training.StationTiers, Training.ModelStarts) : Bois, Acier, Sport, Or, Jade, Cristal,
-- Lave, Royal, Cosmique, Céleste.
-- Dans un modèle, chaque niveau allume un voyant de plus ; au 5e, une étoile dorée coiffe la station.
--
-- La station garde ses pièces « utiles » créées par MapGenerator (Zone, Bar, Plate, Seat... marquées "Tint") :
-- on ne fait que les recolorer. Tout le décor est reconstruit dans le dossier "Look" à chaque changement de niveau.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Modèles faits à la main (Blender -> Importer 3D de Studio, 19 oct.) : ReplicatedStorage.ArtModels.<Station>_<Niveau>
-- (ex. Treadmill_Bois, Bench_Or). Leur pivot est le sol, au centre, -Z vers la console. Les MeshParts nommées "Main" / "Dark" prennent
-- les couleurs du modèle de niveau (Config.Training.StationTiers) ; les autres gardent la leur. Sans modèle, la station
-- est construite en blocs comme avant. L'écran, les voyants et l'étoile restent ajoutés par le code (attribut "StarY" du
-- modèle : hauteur de l'étoile) ; les décors en blocs des niveaux (portique, cristaux, halo) ne le sont plus : le modèle a
-- les siens. Pièces en verre / néon : réglées une fois dans le modèle (Material, Transparency), gardées telles quelles.

local Config = require(ReplicatedStorage.Shared.Config)

local StationLooks = {}

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

-- Pièce « allumée » (voyant, écran, étoile, cristal) : couleur vive mais SANS néon (Chouaib, 25 oct. : plus de néon sur
-- les stations, ni cercle lumineux au sol, ni lumière ni étincelles autour).
local function lit(part: Part, transparency: number?): Part
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.CastShadow = false
	return part
end

-- Rangée de voyants : `on` allumés sur `count` (les niveaux du modèle).
local function lamps(origin: CFrame, spacing: number, on: number, count: number, tier: Tier, parent: Instance)
	for index = 1, count do
		local x = (index - (count + 1) / 2) * spacing
		local lamp = block("Lamp", Vector3.new(0.7, 0.7, 0.4), origin * CFrame.new(x, 0, 0), if index <= on then tier.Accent else OFF_LAMP, parent)
		if index <= on then
			lit(lamp)
		end
	end
end

-- Étoile dorée (niveau max du modèle) : deux blocs croisés à 45°.
local function star(origin: CFrame, parent: Instance)
	for _, angle in ipairs({ 0, math.pi / 4 }) do
		lit(block("Star", Vector3.new(1.6, 1.6, 0.5), origin * CFrame.Angles(0, 0, angle), GOLD, parent))
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
	lit(core)
end

-- Halo de blocs (Cosmique) : un cercle vertical de petits cubes.
local function halo(origin: CFrame, radius: number, color: Color3, parent: Instance)
	local count = 14
	for index = 0, count - 1 do
		local angle = index / count * math.pi * 2
		lit(block("Halo", Vector3.new(0.8, 0.8, 0.8), origin * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0) * CFrame.Angles(0, 0, angle), color, parent))
	end
end

local function authoredStation(name: string, origin: CFrame, tier: Tier, parent: Instance): Model?
	local folder = ReplicatedStorage:FindFirstChild("ArtModels")
	local source = folder and folder:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return nil
	end
	local clone = source:Clone()
	clone:PivotTo(origin)
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			if part.Name == "Main" then
				part.Color = tier.Main
			elseif part.Name == "Dark" then
				part.Color = tier.Dark
			end
		end
	end
	clone.Parent = parent
	return clone
end

----------------------------------------------------------------------
-- Tapis de course (repère : sol, -Z vers la console)
----------------------------------------------------------------------

local function treadmill(origin: CFrame, tier: Tier, rank: number, count: number, tierIndex: number, look: Model)
	local authored = authoredStation("Treadmill_" .. tier.Name, origin, tier, look)
	if not authored then
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
	end
	lit(block("Screen", Vector3.new(5, 0.9, 0.2), origin * CFrame.new(0, 6.05, -8.45), tier.Accent, look))
	lamps(origin * CFrame.new(0, 6.95, -8.4), 1.3, rank, count, tier, look)
	lamps(origin * CFrame.new(0, 6.95, -10.8), 1.3, rank, count, tier, look) -- visibles aussi du côté du trou noir
	-- Chevrons lumineux sur le tapis (Cristal et au-delà).
	if tierIndex >= 4 then
		for index = 0, 3 do
			local z = -6 + index * 4.5
			for _, side in ipairs({ -1, 1 }) do
				local chevron = block("Chevron", Vector3.new(3.2, 0.1, 0.6), origin * CFrame.new(side * 1.4, 0.64, z) * CFrame.Angles(0, side * math.rad(35), 0), tier.Accent, look)
				lit(chevron)
			end
		end
	end
	if tierIndex >= 3 and not authored then
		arch(origin * CFrame.new(0, 0, 9.6), 11.4, 9, tier, look)
	end
	if tierIndex == 4 and not authored then
		for _, corner in ipairs({ Vector2.new(-7.2, -10), Vector2.new(7.2, -10), Vector2.new(-7.2, 10.5), Vector2.new(7.2, 10.5) }) do
			crystal(origin * CFrame.new(corner.X, 0, corner.Y), 4.5, tier.Accent, look)
		end
	end
	if tierIndex == 5 and not authored then
		halo(origin * CFrame.new(0, 10.5, 9.6), 5.2, tier.Accent, look)
		for _, side in ipairs({ -1, 1 }) do
			lit(block("TrimLine", Vector3.new(0.3, 0.3, 21.4), origin * CFrame.new(side * 6.45, 1.5, 0), tier.Trim or tier.Accent, look))
		end
	end
	if rank == count then
		local starY = if authored then authored:GetAttribute("StarY") else nil
		star(origin * CFrame.new(0, if type(starY) == "number" then starY else 8.2, -9.6), look)
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

-- Modèle fait à la main (ReplicatedStorage.ArtModels.Bench_<Niveau>, 22 oct.) : il remplace le banc en blocs (banc,
-- pieds, montants, panneau, haltères, porte-disques, décors). Le jeu garde la barre et les disques (animés pendant le
-- développé couché), le cercle, les voyants et l'étoile. Renvoie le modèle s'il existe.
local function bench(origin: CFrame, tier: Tier, rank: number, count: number, tierIndex: number, look: Model): Model?
	local authored = authoredStation("Bench_" .. tier.Name, origin, tier, look)
	if not authored then
		for _, side in ipairs({ -1, 1 }) do
			block("RackFoot", Vector3.new(1.6, 0.6, 3.4), origin * CFrame.new(side * 2.2, 0.3, -3.2), tier.Dark, look)
			block("Hook", Vector3.new(1, 0.4, 1), origin * CFrame.new(side * 2.2, 4.6, -3.6), tier.Dark, look)
		end
		-- Petit tableau de voyants au pied du banc.
		block("Panel", Vector3.new(7.2, 1.6, 0.8), origin * CFrame.new(0, 0.8, 7.2), tier.Main, look)
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
	end
	lamps(origin * CFrame.new(0, 1.85, 7.2), 1.3, rank, count, tier, look)
	if rank == count then
		local starY = if authored then authored:GetAttribute("StarY") else nil
		star(origin * CFrame.new(0, if type(starY) == "number" then starY else 3.2, 7.2), look)
	end
	return authored
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
				part.Material = Enum.Material.Plastic
			elseif part:GetAttribute("Tint") then
				part.Color = if part.Name == "Seat" then tier.Belt else tier.Main
			end
		end
	end
end

-- Flèches sur la bande du tapis (Config.Training.BeltArrows), une par rangée sur toute la largeur, couleur du niveau.
-- client/TreadmillBelt les fait défiler (étiquette "TreadmillBelt").
local function beltArrows(zone: BasePart, tier: Tier?)
	local old = zone:FindFirstChild("BeltArrows")
	if not tier then
		if old then
			old:Destroy()
		end
		return
	end
	local settings = Config.Training.BeltArrows
	local arrows = if old and old:IsA("Texture") then old else Instance.new("Texture")
	arrows.Name = "BeltArrows"
	arrows.Face = Enum.NormalId.Top
	arrows.Texture = settings.Image
	arrows.StudsPerTileU = zone.Size.X
	arrows.StudsPerTileV = settings.Length
	arrows.Color3 = tier.Accent
	arrows.Transparency = settings.Transparency
	arrows.Parent = zone
	CollectionService:AddTag(arrows, "TreadmillBelt")
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
		if kind == "Treadmill" then
			beltArrows(zone, nil)
		end
		return
	end

	local tier, rank, count = Config.GetStationTier(level)
	local tierIndex = table.find(Config.Training.StationTiers, tier) or 1
	local look = Instance.new("Model")
	look.Name = "Look"
	local origin = originOf(zone)
	if kind == "Treadmill" then
		-- Construit à la taille d'origine puis réduit autour du sol (Config.Training.TreadmillScale).
		treadmill(origin, tier, rank, count, tierIndex, look)
		look.WorldPivot = origin
		look:ScaleTo(Config.Training.TreadmillScale)
		beltArrows(zone, tier)
	elseif bench(origin, tier, rank, count, tierIndex, look) then
		-- Le modèle a son propre banc et ses montants : ceux en blocs de MapGenerator sont cachés (la barre et les
		-- disques restent, ils bougent pendant le développé couché).
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") and (part.Name == "Seat" or part.Name == "Leg" or part.Name == "Upright") then
				part.Transparency = 1
				part.CastShadow = false
			end
		end
	end
	recolor(model, tier, tierIndex)
	look.Parent = model
end

return StationLooks
