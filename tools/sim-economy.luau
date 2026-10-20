-- Simulateur de progression (docs/PLAN_EQUILIBRAGE.md, étape 1).
-- Joue un joueur manche après manche avec les VRAIES règles et valeurs du jeu (Config, PetCatalog, LootEngine) :
-- points des objets, tirages (chance, pitié, rang, nouveaux familiers d'abord), œufs qui incubent, doublons vendus,
-- récompenses d'Index, fusion, revenu des 15 meilleurs familiers, mondes, améliorations de la Boutique, Rebirths.
-- Répète la partie RUNS fois (le hasard des tirages change tout) et donne le temps de jeu pour chaque étape :
-- chanceux (10 % des parties les plus rapides), moyen (la moitié), malchanceux (90 %).
--
--   lune run tools/sim-economy.luau . [RUNS=200] [HEURES=40]
--
-- Hypothèses (à affiner avec les vraies parties) : un joueur seul, toujours présent ; il lance HOLE.Items objets par
-- manche (plus avec le sac, l'aimant et l'entraînement) ; il achète le monde suivant dès qu'il peut, sinon la moins
-- chère des améliorations si elle coûte moins de 30 % de son argent ; il fusionne ses familiers en réserve ; il équipe
-- son meilleur familier en réserve. Pas de passes Robux, d'amis, de vols, de capsule d'évolution ni de cadeaux du jour.
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local process = require("@lune/process")
local project = process.args[1] or "."
local RUNS = tonumber(process.args[2]) or 200
local HOURS = tonumber(process.args[3]) or 40
local FUSION = process.args[4] ~= "nofusion" -- « nofusion » : le joueur n'utilise jamais la fusion

local cache = {}
local parent = setmetatable({}, { __index = function(_, key) return key end })
local random = {
	NextNumber = function(_, a, b)
		local x = math.random()
		return if a then a + ((b or 1) - a) * x else x
	end,
	NextInteger = function(_, a, b)
		return math.random(a, b)
	end,
}
local load
load = function(name)
	if cache[name] then
		return cache[name]
	end
	local env = table.clone(r)
	env.script = { Parent = parent }
	env.require = load
	env.Random = { new = function() return random end }
	env.game = { GetService = function() return {} end }
	cache[name] = luau.load(fs.readFile(project .. "/src/shared/" .. name .. ".lua"), { environment = env })()
	return cache[name]
end
local Config = load("Config")
local Catalog = load("PetCatalog")
local Loot = load("LootEngine")

local ROUND = Config.Durations.Feeding + Config.Durations.Digesting
local HOLE = {
	Items = 16, -- objets avalés par manche au départ (un joueur seul, sans amélioration)
	PerBackpack = 3, -- + par niveau de sac à dos
	PerMagnet = 2, -- + par niveau d'aimant
	PerTraining = 0.15, -- + par niveau de tapis / banc (on court plus vite, on lance plus loin)
	MaxItems = 38, -- objets disponibles par manche (palettes + arène)
	Bonus = 1.3, -- bonus moyen des paliers du trou noir (centre, combo, lave, jackpot)
}
local UPGRADES = { "Treadmill", "Bench", "ItemQuality", "Backpack", "Magnet" }
local shopById = {}
for _, item in ipairs(Config.Shop) do
	shopById[item.Id] = item
end
local function rarityOf(petId)
	return Config.RarityIndex[Catalog.ById[petId].Rarity]
end

-- Valeur moyenne d'un objet avec ce niveau de Chance (même règle que server/ItemSpawner).
local function itemValue(quality)
	local boost = 1 + quality * Config.Items.QualityBoost
	local total, value = 0, 0
	for index, tier in ipairs(Config.ItemTiers) do
		local weight = tier.Weight * boost ^ (index - 1)
		total += weight
		value += weight * tier.Value
	end
	return value / total
end

-- Familier au hasard de cette rareté (les nouveaux d'abord, comme LootEngine).
local function pickPet(rarityIndex, owned)
	local bucket = Catalog.ByRarity[Config.Rarities[rarityIndex].Id]
	local total = 0
	for _, entry in ipairs(bucket) do
		total += if (owned[entry.Id] or 0) > 0 then 1 else Config.Loot.NewPetWeight
	end
	local roll = math.random() * total
	for _, entry in ipairs(bucket) do
		roll -= if (owned[entry.Id] or 0) > 0 then 1 else Config.Loot.NewPetWeight
		if roll <= 0 then
			return entry.Id
		end
	end
	return bucket[#bucket].Id
end

local roundStats: { [number]: { { number } } } = {} -- checkpoint -> { {points, tirages} }
local sources: { [string]: number } = {} -- argent gagné par source (toutes parties), jusqu'au 1er Rebirth
local function simulate(): ({ [string]: number }, { [number]: number })
	local s = {
		t = 0,
		money = Config.Newcomer.BonusMoney,
		tier = 1,
		rebirths = 0,
		up = {} :: { [string]: number },
		pets = { [Config.Newcomer.PetId] = 1 } :: { [string]: number }, -- éclos
		eggs = {} :: { { id: string, at: number } },
		discovered = { [Config.Newcomer.PetId] = true } :: { [string]: boolean },
		claimed = {} :: { [string]: boolean },
		pity = 0,
		totalPulls = 0,
	}
	local events: { [string]: number } = {}
	local incomeAt: { [number]: number } = {}
	local function earn(source, amount)
		s.money += amount
		if s.rebirths == 0 then
			sources[source] = (sources[source] or 0) + amount
		end
	end
	local function mark(name)
		if not events[name] then
			events[name] = s.t
		end
	end

	-- Base : une place par espèce d'abord, les plus rentables (shared/PetRoster), puis les doublons ; l'équipé est à part.
	local function layout(): ({ string }, string?, { [string]: number })
		local slots = Config.GetIncomeSlots(s.rebirths)
		local species = {}
		for petId, count in pairs(s.pets) do
			if count > 0 then
				table.insert(species, petId)
			end
		end
		table.sort(species, function(a, b)
			return Catalog.GetIncome(a) > Catalog.GetIncome(b)
		end)
		local base, used = {}, {}
		for _, petId in ipairs(species) do
			if #base < slots then
				table.insert(base, petId)
				used[petId] = 1
			end
		end
		for _, petId in ipairs(species) do
			while #base < slots and (used[petId] or 0) < s.pets[petId] do
				table.insert(base, petId)
				used[petId] = (used[petId] or 0) + 1
			end
		end
		-- Réserve = ce qui n'est pas dans la base ; on équipe le meilleur multiplicateur de la réserve.
		local reserve: { [string]: number } = {}
		local equipped, best = nil, 0
		for petId, count in pairs(s.pets) do
			local spare = count - (used[petId] or 0)
			if spare > 0 then
				reserve[petId] = spare
				local mult = Config.Rarities[rarityOf(petId)].Multiplier
				if mult > best then
					equipped, best = petId, mult
				end
			end
		end
		if equipped then
			reserve[equipped] -= 1
		end
		return base, equipped, reserve
	end

	local function income(base): number
		local sum = 0
		for _, petId in ipairs(base) do
			sum += Catalog.GetIncome(petId)
		end
		return sum * Config.GetWorld(s.tier).IncomeMultiplier * Config.GetRebirthMultiplier(s.rebirths)
	end

	local function shop()
		local bought = true
		while bought do
			bought = false
			local nextWorld = Config.Worlds[s.tier + 1]
			if nextWorld and s.money >= nextWorld.Price then
				s.money -= nextWorld.Price
				s.tier += 1
				mark("Monde " .. s.tier .. " " .. nextWorld.Name)
				bought = true
			elseif not nextWorld and s.tier >= Config.Rebirth.RequiredTier
				and s.money >= Config.GetRebirthPrice(s.rebirths) then
				s.rebirths += 1
				s.money, s.tier, s.up = 0, 1, {}
				mark("Rebirth " .. s.rebirths)
				bought = true
			else
				local cheapest, price = nil, math.huge
				for _, id in ipairs(UPGRADES) do
					local cost = Config.GetUpgradePrice(shopById[id], s.up[id] or 0)
					if cost and cost < price then
						cheapest, price = id, cost
					end
				end
				if cheapest and price <= 0.3 * s.money then
					s.money -= price
					s.up[cheapest] = (s.up[cheapest] or 0) + 1
					local level = s.up[cheapest]
					if level == shopById[cheapest].MaxLevel then
						mark(cheapest .. " max")
					end
					if cheapest == "Treadmill" and level % 5 == 0 then
						mark("Tapis niveau " .. level)
					end
					bought = true
				end
			end
		end
	end

	local checkpoints = { 600, 1800, 3600, 7200, 18000, 36000, 72000, 144000 }
	local nextCheck = 1
	local rounds = math.floor(HOURS * 3600 / ROUND)
	for _ = 1, rounds do
		-- Œufs éclos : ils rejoignent la collection (et la récompense d'Index est réclamée).
		for index = #s.eggs, 1, -1 do
			local egg = s.eggs[index]
			if egg.at <= s.t then
				table.remove(s.eggs, index)
				s.pets[egg.id] = (s.pets[egg.id] or 0) + 1
				if not s.claimed[egg.id] then
					s.claimed[egg.id] = true
					earn("Index", Config.GetIndexReward(egg.id))
				end
			end
		end
		shop()
		local base, equipped, reserve = layout()
		local perSecond = income(base)
		local checkpoint = nil
		while checkpoints[nextCheck] and s.t >= checkpoints[nextCheck] do
			incomeAt[checkpoints[nextCheck]] = perSecond
			checkpoint = checkpoints[nextCheck]
			nextCheck += 1
		end

		-- Fusion des familiers en réserve (Config.Fusion) si elle coûte moins de la moitié de l'argent.
		for rarityIndex = 1, if FUSION then Config.Fusion.MaxFromRarity else 0 do
			local pool = {}
			for petId, count in pairs(reserve) do
				if rarityOf(petId) == rarityIndex then
					for _ = 1, count do
						table.insert(pool, petId)
					end
				end
			end
			local cost = Config.Fusion.Costs[rarityIndex]
			while #pool >= Config.Fusion.Count and s.money * 0.5 >= cost do
				s.money -= cost
				for _ = 1, Config.Fusion.Count do
					local petId = table.remove(pool)
					s.pets[petId] -= 1
				end
				local owned = table.clone(s.pets)
				for _, egg in ipairs(s.eggs) do
					owned[egg.id] = (owned[egg.id] or 0) + 1
				end
				local result = pickPet(rarityIndex + 1, owned)
				table.insert(s.eggs, { id = result, at = s.t + Config.Eggs.Seconds[Config.Rarities[rarityIndex + 1].Id] })
			end
		end

		-- La manche : objets lancés -> points -> tirages.
		local items = math.min(HOLE.Items + HOLE.PerBackpack * (s.up.Backpack or 0) + HOLE.PerMagnet * (s.up.Magnet or 0)
			+ HOLE.PerTraining * ((s.up.Treadmill or 0) + (s.up.Bench or 0)), HOLE.MaxItems)
		local multiplier = if equipped then Config.Rarities[rarityOf(equipped)].Multiplier else 1
		local score = math.floor(items * itemValue(s.up.ItemQuality or 0) * multiplier * HOLE.Bonus * 10) / 10
		local pulls = Loot.countPulls(score)
		if checkpoint then
			roundStats[checkpoint] = roundStats[checkpoint] or {}
			table.insert(roundStats[checkpoint], { score, pulls })
		end
		local owned = table.clone(s.pets)
		for _, egg in ipairs(s.eggs) do
			owned[egg.id] = (owned[egg.id] or 0) + 1
		end
		local floorIndex = Loot.floor(s.totalPulls, s.discovered)
		local outcome = Loot.rollPulls(pulls, s.pity, Loot.luck(score, 0), owned, floorIndex)
		s.pity = outcome.pity
		s.totalPulls += outcome.pulls
		local world = Config.GetWorld(s.tier)
		for _, petId in ipairs(outcome.drops) do
			s.discovered[petId] = true
			if (owned[petId] or 0) >= Config.Loot.KeepCopies then
				earn("Doublons vendus", Catalog.GetIncome(petId) * Config.Loot.SellSeconds * world.IncomeMultiplier)
			else
				owned[petId] = (owned[petId] or 0) + 1
				table.insert(s.eggs, { id = petId, at = s.t + Config.Eggs.Seconds[Catalog.ById[petId].Rarity] })
				if rarityOf(petId) >= #Config.Rarities - 1 then
					mark("1er " .. Catalog.ById[petId].Rarity)
				end
			end
		end
		earn("Points du trou", score * math.max(Config.Economy.MoneyPerPoint, perSecond * Config.Economy.IncomeSecondsPerPoint))
		earn("Revenu des familiers", perSecond * ROUND)
		s.t += ROUND
	end
	return events, incomeAt
end

----------------------------------------------------------------------
-- Résultats
----------------------------------------------------------------------

local function duration(seconds: number?): string
	if not seconds then
		return "   jamais"
	end
	if seconds < 3600 then
		return string.format("%6.0f min", seconds / 60)
	end
	return string.format("%6.1f h  ", seconds / 3600)
end
local function short(n: number): string
	local units = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }
	local i = 1
	while n >= 1000 and i < #units do
		n /= 1000
		i += 1
	end
	return string.format("%.3g%s", n, units[i])
end

math.randomseed(1234)
local all: { [string]: { number } } = {}
local incomes: { [number]: { number } } = {}
for _ = 1, RUNS do
	local events, incomeAt = simulate()
	for name, at in pairs(events) do
		all[name] = all[name] or {}
		table.insert(all[name], at)
	end
	for at, value in pairs(incomeAt) do
		incomes[at] = incomes[at] or {}
		table.insert(incomes[at], value)
	end
end
local function pct(list: { number }, p: number): number?
	-- Parties qui n'ont pas atteint l'étape = temps infini.
	local sorted = table.clone(list)
	table.sort(sorted)
	local index = math.ceil(p * RUNS)
	return sorted[index]
end
local names = {}
for name, list in pairs(all) do
	table.insert(names, { name = name, median = pct(list, 0.5) or math.huge })
end
table.sort(names, function(a, b)
	return a.median < b.median
end)
print(string.format("Simulation : %d parties de %d h de jeu (manche de %d s). Temps de jeu pour chaque étape :", RUNS, HOURS, ROUND))
print(string.format("%-26s %11s %11s %11s %8s", "Étape", "chanceux", "moyen", "malchanceux", "atteinte"))
for _, row in ipairs(names) do
	local list = all[row.name]
	print(string.format("%-26s %11s %11s %11s %7d%%", row.name, duration(pct(list, 0.1)), duration(pct(list, 0.5)),
		duration(pct(list, 0.9)), math.floor(#list / RUNS * 100)))
end
print("\nRevenu par seconde (moyen) :")
local at = {}
for key in pairs(incomes) do
	table.insert(at, key)
end
table.sort(at)
for _, key in ipairs(at) do
	local scores, pulls = {}, {}
	for _, stat in ipairs(roundStats[key] or {}) do
		table.insert(scores, stat[1])
		table.insert(pulls, stat[2])
	end
	print(string.format("  après %s : %s/s   (une manche : %s points, %s tirages)", duration(key), short(pct(incomes[key], 0.5) or 0),
		short(pct(scores, 0.5) or 0), short(pct(pulls, 0.5) or 0)))
end
local total = 0
for _, amount in pairs(sources) do
	total += amount
end
print("\nD'où vient l'argent avant le 1er Rebirth :")
for name, amount in pairs(sources) do
	print(string.format("  %-22s %5.1f %%", name, amount / math.max(total, 1) * 100))
end
