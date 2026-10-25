-- Test hors Studio des calculs du deuxième lot (ECONOMY_REPORT.md, étape 5) : plafond de revenu (shared/PowerCap,
-- Config.PowerCap), vol utile, durée du verrou à cycle (Config.GetLockDuration). Les contrôleurs (LockController,
-- bouclier de StealController) ne sont pas joués ici : à vérifier dans Studio.
--
--   lune run tools/check-steal-rules.luau .
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local process = require("@lune/process")
local project = process.args[1] or "."

local cache = {}
local parent = setmetatable({}, { __index = function(_, key) return key end })
local load
load = function(name)
	if cache[name] then
		return cache[name]
	end
	local env = table.clone(r)
	env.script = { Parent = parent }
	env.require = load
	env.game = { GetService = function() return {} end }
	cache[name] = luau.load(fs.readFile(project .. "/src/shared/" .. name .. ".lua"), { environment = env })()
	return cache[name]
end
local Config = load("Config")
local Catalog = load("PetCatalog")
local PowerCap = load("PowerCap")

local function rarity(id: string): number
	return Config.RarityIndex[id]
end
local sigma = Catalog.BaseByRarity.Sigma[1].Id
local topSigma = Catalog.ByRarity.Sigma[#Catalog.ByRarity.Sigma].Id -- le dernier = le plus rentable (rang)
local divin = Catalog.BaseByRarity.Divin[1].Id
local rare = Catalog.BaseByRarity.Rare[1].Id

-- Plafond : revenu de base de la rareté selfBest + 2 ; rien au-delà du Sigma ; rien avant le chargement (nil).
assert(PowerCap.Max(rarity("Rare")) == Config.Rarities[rarity("Legendaire")].Income, "Rare -> plafond Légendaire")
assert(PowerCap.Max(rarity("Divin")) == nil and PowerCap.Max(nil) == nil, "Divin ou pas chargé : pas de plafond")
assert(PowerCap.Income(sigma, rarity("Rare")) == Config.Rarities[rarity("Legendaire")].Income, "Sigma bridé en Légendaire")
assert(PowerCap.Income(rare, rarity("Rare")) == Catalog.GetIncome(rare), "un Rare n'est pas bridé pour un joueur qui a un Rare")
assert(PowerCap.IsCapped(sigma, rarity("Rare")) and not PowerCap.IsCapped(sigma, rarity("Divin")), "bridé / libéré")

-- Pour libérer un Sigma de base, il faut un Mythique à soi ; le Sigma le plus rentable, un Divin.
assert(PowerCap.UnlockRarity(sigma, rarity("Rare")) == rarity("Mythique"), "Sigma : obtenir un Mythique")
assert(PowerCap.UnlockRarity(topSigma, rarity("Rare")) == rarity("Divin"), "meilleur Sigma : obtenir un Divin")
assert(PowerCap.UnlockRarity(divin, rarity("Sigma")) == nil, "rien à libérer")

-- Le gain d'un vol est borné : à 10 min (meilleur familier Rare), un Sigma volé rapporte au plus un Légendaire.
assert(PowerCap.Income(topSigma, rarity("Rare")) <= Config.Rarities[rarity("Legendaire")].Income, "jackpot borné")

-- Vol utile : seulement si le familier (plafonné) dépasse le moins bon de la base, ou s'il reste une place (0).
assert(PowerCap.IsUseful(rare, rarity("Rare"), 0), "place libre : tout est utile")
assert(not PowerCap.IsUseful(rare, rarity("Sigma"), Catalog.GetIncome(divin)), "un Rare n'apporte rien à une base de Divins")
assert(PowerCap.IsUseful(sigma, rarity("Sigma"), Catalog.GetIncome(divin)), "un Sigma apporte à une base de Divins")
-- Un Sigma bridé en Légendaire n'apporte rien à quelqu'un dont la base est pleine de Mythiques.
assert(not PowerCap.IsUseful(sigma, rarity("Rare"), Config.Rarities[rarity("Mythique")].Income), "bridé : inutile")

-- Verrou à cycle : 45 s, +10 s (Verrou renforcé), +10 s (VIP), jamais moins de MinOpen secondes ouvertes par cycle.
local lock = Config.Lock
assert(Config.GetLockDuration(false, 0) == lock.Duration, "durée de base")
assert(Config.GetLockDuration(true, 0) == lock.Duration + lock.LongBonus, "Verrou renforcé")
assert(Config.GetLockDuration(true, 10) == 65, "Verrou renforcé + VIP = 65 s")
assert(Config.GetLockDuration(true, 1000) == lock.Cycle - lock.MinOpen, "plafonné pour laisser la base ouverte")
assert(lock.Cycle == Config.Durations.Feeding + Config.Durations.Digesting, "un cycle = une manche")

print("PASS: plafond de revenu, rareté à obtenir, vol utile, durée du verrou à cycle")
