--!strict
-- LootEngine : convertit les points d'une manche en tirages de familiers.
--   - Le 1er tirage coûte Config.Loot.PullCost points, chaque suivant coûte PullCostGrowth % de plus.
--   - Minimum 1 tirage dès qu'un point a été marqué.
--   - Plus le score est haut, plus les raretés hautes ont de poids (chance plafonnée).
--   - Pitié : après PityPulls tirages sans rareté >= PityMinRarity, ce palier est garanti.

local Config = require(script.Parent.Config)
local PetCatalog = require(script.Parent.PetCatalog)

local LootEngine = {}

export type Results = { [string]: number } -- petId -> quantité

export type Outcome = {
	results: Results,
	pulls: number,
	pity: number, -- compteur de pitié mis à jour (à sauvegarder pour la manche suivante)
	drops: { string }, -- petIds dans l'ordre des tirages
}

local rng = Random.new()

-- Nombre de tirages pour un score donné (coût croissant).
function LootEngine.countPulls(score: number): number
	if score <= 0 then
		return 0
	end
	local pulls = 0
	local cost = Config.Loot.PullCost
	local remaining = score
	while remaining >= cost do
		remaining -= cost
		pulls += 1
		cost *= 1 + Config.Loot.PullCostGrowth
	end
	return math.max(1, pulls)
end

-- Tire un index de rareté parmi [minIndex, #Rarities].
local function rollRarity(luck: number, minIndex: number): number
	local weights = {}
	local total = 0
	for index, rarity in ipairs(Config.Rarities) do
		local weight = 0
		if index >= minIndex then
			weight = if index == 1 then rarity.Weight else rarity.Weight * (1 + luck)
		end
		weights[index] = weight
		total += weight
	end

	local roll = rng:NextNumber() * total
	for index, weight in ipairs(weights) do
		roll -= weight
		if roll <= 0 and weight > 0 then
			return index
		end
	end
	return #Config.Rarities
end

local function pickPet(rarityIndex: number): string
	-- Si une rareté n'a aucun familier, on descend jusqu'à en trouver un.
	for index = rarityIndex, 1, -1 do
		local bucket = PetCatalog.ByRarity[Config.Rarities[index].Id]
		if bucket and #bucket > 0 then
			return bucket[rng:NextInteger(1, #bucket)].Id
		end
	end
	return PetCatalog.List[1].Id
end

-- Probabilité de chaque rareté pour un tirage avec cette chance (hors garantie de la pitié).
-- Sert à afficher les chances exactes avant un achat de tirage (règle Roblox sur les objets aléatoires payants).
function LootEngine.odds(luck: number): { number }
	local weights = {}
	local total = 0
	for index, rarity in ipairs(Config.Rarities) do
		local weight = if index == 1 then rarity.Weight else rarity.Weight * (1 + luck)
		weights[index] = weight
		total += weight
	end
	for index, weight in ipairs(weights) do
		weights[index] = weight / total
	end
	return weights
end

-- Effectue `pulls` tirages avec cette chance (tirages achetés, ou ceux d'une manche).
function LootEngine.rollPulls(pulls: number, pity: number, luck: number): Outcome
	local outcome: Outcome = { results = {}, pulls = 0, pity = pity, drops = {} }
	for _ = 1, pulls do
		outcome.pity += 1
		local minIndex = if outcome.pity >= Config.Loot.PityPulls then Config.Loot.PityMinRarity else 1
		local rarityIndex = rollRarity(luck, minIndex)
		if rarityIndex >= Config.Loot.PityMinRarity then
			outcome.pity = 0
		end
		local petId = pickPet(rarityIndex)
		outcome.results[petId] = (outcome.results[petId] or 0) + 1
		table.insert(outcome.drops, petId)
	end

	outcome.pulls = pulls
	return outcome
end

-- score : points de la manche (déjà multipliés). pity : compteur actuel du joueur.
-- luckBonus : bonus de chance externe (passe "Chance Chanceuse", boost serveur : shared/Perks), 0 par défaut.
function LootEngine.roll(score: number, pity: number, luckBonus: number?): Outcome
	local luck = math.min(score * Config.Loot.LuckPerPoint, Config.Loot.MaxLuck) + (luckBonus or 0)
	return LootEngine.rollPulls(LootEngine.countPulls(score), pity, luck)
end

return LootEngine
