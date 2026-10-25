-- Test hors Studio de la pitié par palier (shared/LootEngine, Config.Loot.PityPercentile ; ECONOMY_REPORT.md règle 11) :
-- seuil = tirage où 9 joueurs sur 10 auraient eu la rareté visée, garantie au seuil, compteur remis à zéro, rien
-- à garantir quand on a déjà un Sigma.
--
--   lune run tools/check-pity.luau .
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local process = require("@lune/process")
local project = process.args[1] or "."

local cache = {}
local parent = setmetatable({}, { __index = function(_, key) return key end })
math.randomseed(7)
local random = { -- Random.new() n'existe pas dans Lune : même remplaçant que tools/sim-economy.luau
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

local function firstOf(rarityId: string): string
	return Catalog.BaseByRarity[rarityId][1].Id
end

-- Rareté visée : celle juste au-dessus de la meilleure possédée.
assert(Loot.pityTarget({}) == 1, "rien possédé : vise le Commun")
assert(Loot.pityTarget({ [firstOf("Commun")] = 1 }) == 2, "un Commun : vise l'Inhabituel")
assert(Loot.pityTarget({ [firstOf("Rare")] = 1, [firstOf("Commun")] = 3 }) == 4, "un Rare : vise l'Épique")
assert(Loot.pityTarget({ [firstOf("Sigma")] = 1 }) == #Config.Rarities + 1, "un Sigma : plus rien au-dessus")

-- Seuil : ln(1 - 0,9) / ln(1 - p), p = chance de la rareté visée ou mieux.
local odds = Loot.odds(0, 1, 1)
local p = 0
for index = 6, #odds do
	p += odds[index]
end
local expected = math.ceil(math.log(1 - Config.Loot.PityPercentile) / math.log(1 - p))
assert(Loot.pityAt(6, 0, 1, 1) == expected, "seuil du Mythique en Prairie : " .. tostring(Loot.pityAt(6, 0, 1, 1)) .. " au lieu de " .. expected)
assert(Loot.pityAt(#Config.Rarities + 1, 0, 1, 1) == nil, "pas de seuil au-dessus du Sigma")
assert(Loot.pityAt(1, 0, 1, 1) == 1, "le Commun (ou mieux) sort toujours")

-- Garantie : arrivé au seuil, le tirage suivant donne la rareté visée ou mieux, puis le compteur repart de zéro.
local owned = { [firstOf("Legendaire")] = 1 }
local at = Loot.pityAt(6, 0, 1, 1) :: number
for _ = 1, 300 do
	local outcome = Loot.rollPulls(1, at - 1, 0, owned, 1, 1)
	local rarity = Config.RarityIndex[Catalog.ById[outcome.drops[1]].Rarity]
	assert(rarity >= 6, "pitié non garantie : " .. outcome.drops[1])
	assert(outcome.pity == 0, "compteur non remis à zéro")
	assert(outcome.pityTarget == rarity + 1, "la pitié doit viser la rareté suivante")
end

-- Sans pitié atteinte, un Commun reste possible ; avec un Sigma, aucun tirage n'est forcé.
local commons = 0
for _ = 1, 400 do
	local outcome = Loot.rollPulls(1, 0, 0, { [firstOf("Sigma")] = 1 }, 1, 1)
	if Catalog.ById[outcome.drops[1]].Rarity == "Commun" then
		commons += 1
	end
	assert(outcome.pityAt == nil, "un Sigma ne laisse rien à garantir")
end
assert(commons > 100, "tirages forcés alors qu'il n'y a rien à garantir")

-- Une longue série : la pitié ne fait pas sortir le Mythique beaucoup plus souvent que ses chances (elle ne sert qu'aux
-- plus malchanceux) : au plus 15 % de Mythiques forcés par rapport aux Mythiques tirés au hasard.
local forced, natural, pity = 0, 0, 0
for _ = 1, 20000 do
	local before = pity
	local outcome = Loot.rollPulls(1, pity, 0, owned, 1, 1)
	pity = outcome.pity
	local rarity = Config.RarityIndex[Catalog.ById[outcome.drops[1]].Rarity]
	if rarity >= 6 then
		if before + 1 >= at then
			forced += 1
		else
			natural += 1
		end
		pity = 0
	end
end
assert(forced <= 0.15 * natural, string.format("trop de garanties : %d forcées pour %d au hasard", forced, natural))
print(string.format("PASS: pitié par palier (seuil Mythique en Prairie %d tirages ; %d garanties pour %d Mythiques au hasard)", at, forced, natural))
