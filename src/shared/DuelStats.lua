--!strict
-- DuelStats : puissance d'un familier en duel (Config.Duel), la même pour le serveur (server/DuelController) et pour
-- l'aperçu de la fenêtre de choix (client/DuelClient).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetSizes = require(ReplicatedStorage.Shared.PetSizes)

local DuelStats = {}

function DuelStats.rarity(petId: string): number
	local entry = PetCatalog.ById[petId]
	return if entry then Config.RarityIndex[entry.Rarity] or 1 else 1
end

-- Points de vie et attaque (nombres entiers).
function DuelStats.of(petId: string): (number, number)
	local DUEL = Config.Duel
	local entry = PetCatalog.ById[petId]
	local rarity = DuelStats.rarity(petId)
	local scale = 1 + DUEL.PerRarity * (rarity - 1)
	-- Place du familier dans la tranche de taille de sa rareté : le plus grand a un petit bonus.
	local band = PetSizes.Bands[if entry then entry.Rarity else "Commun"]
	local place = 0
	if band and band[2] > band[1] then
		place = math.clamp((PetSizes.Of(petId, entry and entry.Rarity) - band[1]) / (band[2] - band[1]), 0, 1)
	end
	scale *= 1 + DUEL.SizeBonus * place
	-- Un familier évolué (machine d'évolution) est plus fort.
	scale *= Config.Evolution.PowerMultiplier[if entry then entry.Stage or 1 else 1] or 1
	return math.floor(DUEL.BaseHP * scale + 0.5), math.floor(DUEL.BaseAttack * scale + 0.5)
end

-- Les deux familiers peuvent-ils s'affronter ? (raretés proches)
function DuelStats.compatible(petA: string, petB: string): boolean
	return math.abs(DuelStats.rarity(petA) - DuelStats.rarity(petB)) <= Config.Duel.MaxRarityGap
end

return DuelStats
