--!strict
-- LootEngine : convertit les points d'une manche en tirages de familiers.
--   - Le 1er tirage coûte Config.Loot.PullCost points, chaque suivant coûte PullCostGrowth % de plus.
--   - Minimum 1 tirage dès qu'un point a été marqué.
--   - Plus le score est haut, plus les raretés hautes ont de poids (chance plafonnée).
--   - Pitié : après PityPulls tirages sans rareté >= PityMinRarity, ce palier est garanti.
--   - Dans une rareté, les familiers pas encore possédés sortent Config.Loot.NewPetWeight fois plus souvent.
--   - Rang de tirage (Config.Loot.Ranks, selon les tirages faits depuis le début) : un tirage sous la rareté
--     plancher monte au plancher (les raretés au-dessus gardent exactement leurs chances).
--   - progress : où en est la barre « prochain tirage » (affichée en direct par le HUD).

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

-- Barre « prochain tirage » : tirages déjà gagnés avec ce score, et avancement (0 à 1) vers le suivant.
-- Même règle que countPulls (le 1er tirage est offert dès le premier point).
function LootEngine.progress(score: number): (number, number)
	local pulls = 0
	local cost = Config.Loot.PullCost
	local spent = 0
	while score - spent >= cost do
		spent += cost
		pulls += 1
		cost *= 1 + Config.Loot.PullCostGrowth
	end
	if pulls == 0 and score > 0 then
		-- Tirage offert : la barre avance vers le 2e (coût des deux premiers).
		return 1, score / (cost + cost * (1 + Config.Loot.PullCostGrowth))
	end
	return pulls, (score - spent) / cost
end

-- Chance de la manche (poids des raretés hautes) : grandit avec le score, plafonnée, + bonus des passes.
function LootEngine.luck(score: number, luckBonus: number?): number
	return math.min(score * Config.Loot.LuckPerPoint, Config.Loot.MaxLuck) + (luckBonus or 0)
end

-- Rang de tirage selon les tirages faits depuis le début (index dans Config.Loot.Ranks).
function LootEngine.rank(totalPulls: number): number
	local index = 1
	for i, rank in ipairs(Config.Loot.Ranks) do
		if totalPulls >= rank.Pulls then
			index = i
		end
	end
	return index
end

-- Rareté plancher réelle : celle du rang, mais une rareté reste tant que tous ses familiers ne sont pas découverts.
function LootEngine.floor(totalPulls: number, discovered: { [string]: boolean }): number
	local target = Config.Loot.Ranks[LootEngine.rank(totalPulls)].Floor
	local floorIndex = 1
	while floorIndex < target do
		for _, entry in ipairs(PetCatalog.ByRarity[Config.Rarities[floorIndex].Id] or {}) do
			if not discovered[entry.Id] then
				return floorIndex
			end
		end
		floorIndex += 1
	end
	return floorIndex
end

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

-- Poids de chaque rareté avec cette chance et ce plancher : les raretés sous le plancher donnent leur poids au plancher.
local function rarityWeights(luck: number, floorIndex: number): { number }
	local weights = {}
	for index, rarity in ipairs(Config.Rarities) do
		weights[index] = if index == 1 then rarity.Weight else rarity.Weight * (1 + luck)
	end
	for index = 1, math.min(floorIndex, #weights) - 1 do
		weights[floorIndex] += weights[index]
		weights[index] = 0
	end
	return weights
end

-- Tire un index de rareté parmi [minIndex, #Rarities].
local function rollRarity(luck: number, minIndex: number, floorIndex: number): number
	local weights = rarityWeights(luck, floorIndex)
	local total = 0
	for index, weight in ipairs(weights) do
		if index < minIndex then
			weights[index] = 0
		else
			total += weight
		end
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

export type Owned = { [string]: number } -- petId -> quantité possédée (sauvegarde du joueur)

-- owned : familiers déjà possédés (y compris ceux tirés juste avant dans la même série).
local function pickPet(rarityIndex: number, owned: Owned): string
	-- Si une rareté n'a aucun familier, on descend jusqu'à en trouver un.
	for index = rarityIndex, 1, -1 do
		local bucket = PetCatalog.ByRarity[Config.Rarities[index].Id]
		if bucket and #bucket > 0 then
			local total = 0
			for _, entry in ipairs(bucket) do
				total += if (owned[entry.Id] or 0) > 0 then 1 else Config.Loot.NewPetWeight
			end
			local roll = rng:NextNumber() * total
			for _, entry in ipairs(bucket) do
				roll -= if (owned[entry.Id] or 0) > 0 then 1 else Config.Loot.NewPetWeight
				if roll <= 0 then
					return entry.Id
				end
			end
			return bucket[#bucket].Id
		end
	end
	return PetCatalog.List[1].Id
end

-- Probabilité de chaque rareté pour un tirage avec cette chance et ce plancher (hors garantie de la pitié).
-- Sert à afficher les chances exactes avant un achat de tirage (règle Roblox sur les objets aléatoires payants).
function LootEngine.odds(luck: number, floorIndex: number?): { number }
	local weights = rarityWeights(luck, floorIndex or 1)
	local total = 0
	for _, weight in ipairs(weights) do
		total += weight
	end
	for index, weight in ipairs(weights) do
		weights[index] = weight / total
	end
	return weights
end

-- Effectue `pulls` tirages avec cette chance (tirages achetés, ou ceux d'une manche).
-- owned : familiers du joueur (non modifié : une copie suit les tirages de la série). floorIndex : rareté plancher.
function LootEngine.rollPulls(pulls: number, pity: number, luck: number, owned: Owned?, floorIndex: number?): Outcome
	local outcome: Outcome = { results = {}, pulls = 0, pity = pity, drops = {} }
	local have: Owned = table.clone(owned or {})
	for _ = 1, pulls do
		outcome.pity += 1
		local minIndex = if outcome.pity >= Config.Loot.PityPulls then Config.Loot.PityMinRarity else 1
		local rarityIndex = rollRarity(luck, minIndex, floorIndex or 1)
		if rarityIndex >= Config.Loot.PityMinRarity then
			outcome.pity = 0
		end
		local petId = pickPet(rarityIndex, have)
		have[petId] = (have[petId] or 0) + 1
		outcome.results[petId] = (outcome.results[petId] or 0) + 1
		table.insert(outcome.drops, petId)
	end

	outcome.pulls = pulls
	return outcome
end

-- score : points de la manche (déjà multipliés). pity : compteur actuel du joueur.
-- luckBonus : bonus de chance externe (passe "Chance Chanceuse", boost serveur : shared/Perks), 0 par défaut.
function LootEngine.roll(score: number, pity: number, luckBonus: number?, owned: Owned?, floorIndex: number?): Outcome
	return LootEngine.rollPulls(LootEngine.countPulls(score), pity, LootEngine.luck(score, luckBonus), owned, floorIndex)
end

return LootEngine
