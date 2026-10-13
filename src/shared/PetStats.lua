--!strict
-- PetStats : les stats qu'un familier ÉQUIPÉ donne au joueur (en niveaux de Vitesse et de Force).
--
-- Un familier équipé suit le joueur : il ne rapporte plus d'argent (il n'est plus dans la base), mais il ajoute
-- des niveaux d'entraînement tant qu'il est équipé (Config.Pets.EquipBonus) :
--   - le total dépend de la rareté (Levels) ;
--   - le partage dépend de la taille du familier dans sa tranche (shared/PetSizes) : les petits rendent
--     surtout plus RAPIDE, les gros surtout plus FORT.
-- Le serveur l'ajoute aux niveaux du joueur (SessionData), le client l'affiche (Index, HUD).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetSizes = require(ReplicatedStorage.Shared.PetSizes)

local PetStats = {}

export type Bonus = { Speed: number, Strength: number }

-- Niveaux de Vitesse et de Force donnés par un familier équipé.
function PetStats.Of(petId: string): Bonus
	local entry = PetCatalog.ById[petId]
	if not entry then
		return { Speed = 0, Strength = 0 }
	end
	local bonus = Config.Pets.EquipBonus
	local total = bonus.Levels[Config.RarityIndex[entry.Rarity] or 1] or 0
	local band = PetSizes.Bands[entry.Rarity] or PetSizes.Bands.Commun
	local size = PetSizes.Of(petId, entry.Rarity)
	local t = if band[2] > band[1] then math.clamp((size - band[1]) / (band[2] - band[1]), 0, 1) else 0.5
	local speed = math.floor(total * (bonus.SpeedShareSmall + (bonus.SpeedShareBig - bonus.SpeedShareSmall) * t) + 0.5)
	return { Speed = speed, Strength = total - speed }
end

-- Somme pour une liste de familiers équipés (plafonnée à Config.Pets.EquipBonus.MaxLevels par stat).
function PetStats.Sum(petIds: { string }): Bonus
	local speed, strength = 0, 0
	for _, petId in ipairs(petIds) do
		local one = PetStats.Of(petId)
		speed += one.Speed
		strength += one.Strength
	end
	local maxLevels = Config.Pets.EquipBonus.MaxLevels
	return { Speed = math.min(speed, maxLevels), Strength = math.min(strength, maxLevels) }
end

return PetStats
