-- LootEngine : moteur de récompenses RNG.
-- Convertit un score (nombre d'items avalés par le trou noir) en tirages de loot.
-- Utilise un système de poids entiers pour éviter les flottants capricieux.

local LootEngine = {}

-- Nombre de points nécessaires pour obtenir un tirage.
local POINTS_PER_PULL = 100

-- Table de loot avec poids entiers (total = 1000).
local LOOT_TABLE = {
	Commun = 800,
	Rare = 150,
	Epique = 49,
	Sigma = 1,
}

-- Générateur pseudo-aléatoire dédié au loot.
local rng = Random.new()

-- Effectue un tirage unique et retourne la rareté gagnée.
local function rollSingle()
	local totalWeight = 0
	for _, weight in pairs(LOOT_TABLE) do
		totalWeight += weight
	end

	local roll = rng:NextInteger(1, totalWeight)
	for rarity, weight in pairs(LOOT_TABLE) do
		roll -= weight
		if roll <= 0 then
			return rarity
		end
	end

	-- Sécurité : ne devrait jamais arriver si les poids sont corrects.
	return "Commun"
end

-- Convertit un score en tirages et retourne les résultats agrégés.
-- Retourne : results (dictionnaire rareté -> quantité), pulls (nombre de tirages).
function LootEngine.processRewards(score)
	-- Aucun point : aucun tirage.
	if not score or score <= 0 then
		return {}, 0
	end

	local pulls = math.floor(score / POINTS_PER_PULL)

	-- Petit effort récompensé : au moins un tirage si le score est positif.
	if pulls == 0 then
		pulls = 1
	end

	local results = {
		Commun = 0,
		Rare = 0,
		Epique = 0,
		Sigma = 0,
	}

	for _ = 1, pulls do
		local rarity = rollSingle()
		results[rarity] = (results[rarity] or 0) + 1
	end

	return results, pulls
end

return LootEngine
