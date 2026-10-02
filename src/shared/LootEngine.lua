--!strict
-- LootEngine : convertit un score (objets avalés) en tirages pondérés.
-- Plus le score est haut, plus les raretés hautes ont de poids (chance).

local Config = require(script.Parent.Config)

local LootEngine = {}

export type Results = { [string]: number }

local rng = Random.new()

-- Poids effectifs pour un niveau de chance donné : seul "Commun" n'est pas boosté.
local function getWeights(luck: number): { number }
	local weights = {}
	for index, rarity in ipairs(Config.Rarities) do
		if index == 1 then
			weights[index] = rarity.Weight
		else
			weights[index] = rarity.Weight * (1 + luck)
		end
	end
	return weights
end

local function rollSingle(weights: { number }): string
	local total = 0
	for _, weight in ipairs(weights) do
		total += weight
	end

	local roll = rng:NextNumber() * total
	for index, weight in ipairs(weights) do
		roll -= weight
		if roll <= 0 then
			return Config.Rarities[index].Name
		end
	end

	return Config.Rarities[1].Name
end

-- Retourne (results, pulls). results contient toutes les raretés (0 si non obtenue).
function LootEngine.processRewards(score: number): (Results, number)
	local results: Results = {}
	for _, rarity in ipairs(Config.Rarities) do
		results[rarity.Name] = 0
	end

	if score <= 0 then
		return results, 0
	end

	-- Filet de sécurité : au moins un tirage dès qu'un point a été marqué.
	local pulls = math.max(1, math.floor(score / Config.Loot.PointsPerPull))
	local luck = math.min(score * Config.Loot.LuckPerPoint, Config.Loot.MaxLuck)
	local weights = getWeights(luck)

	for _ = 1, pulls do
		local name = rollSingle(weights)
		results[name] += 1
	end

	return results, pulls
end

return LootEngine
