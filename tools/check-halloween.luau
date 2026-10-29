-- Halloween 2026 (shared/Halloween, Config.Halloween) : dates, heure hantée, tirage de l'œuf Citrouille, familiers limités.
--   lune run tools/check-halloween.luau .
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local project = require("@lune/process").args[1] or "."
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
	env.game = { GetService = function() return { IsStudio = function() return false end } end }
	env.workspace = { GetServerTimeNow = function() return 0 end, GetAttribute = function() return nil end }
	cache[name] = luau.load(fs.readFile(project .. "/src/shared/" .. name .. ".lua"), { environment = env })()
	return cache[name]
end
local Config, Halloween, Catalog = load("Config"), load("Halloween"), load("PetCatalog")
local S = Config.Halloween

-- Dates : vendredi 30 oct. 0 h UTC -> lundi 9 nov. 5 h UTC.
assert(not Halloween.Active(S.Start - 1) and Halloween.Active(S.Start) and Halloween.Active(S.End - 1) and not Halloween.Active(S.End), "dates")
assert(Halloween.Left(S.End - 90) == 90 and Halloween.Left(S.End + 5) == 0, "temps restant")
assert(Config.Codes.HALLOWEEN.Until == S.End and Config.Codes.BOO.Until == S.End, "codes jusqu'à la fin")

-- Heure hantée : à la demie, Minutes minutes, jamais en même temps que le trou noir doré.
local hour = 1761742800
local active, seconds = Halloween.HauntedState(hour + 1800)
assert(active and seconds == S.HauntedHour.Minutes * 60, "active à la demie")
active, seconds = Halloween.HauntedState(hour + 1800 + S.HauntedHour.Minutes * 60)
assert(not active and seconds == 3600 - S.HauntedHour.Minutes * 60, "finie")
active = Halloween.HauntedState(hour + 10)
assert(not active, "pas à l'heure pile (trou noir doré)")
assert(Halloween.CandyMultiplier(hour + 1810) == S.HauntedHour.CandyMultiplier and Halloween.CandyMultiplier(hour) == 1, "multiplicateur")

-- Familiers limités : 5, dans l'ordre des raretés, hors des tirages ordinaires.
assert(#S.Order == 5 and #Catalog.ByEvent.Halloween == 5, "5 familiers")
for _, petId in ipairs(S.Order) do
	local entry = Catalog.ById[petId]
	assert(entry and entry.Event == "Halloween" and not entry.World, petId)
	for _, bucket in pairs(Catalog.BaseByRarity) do
		for _, other in ipairs(bucket) do
			assert(other.Id ~= petId, petId .. " ne doit pas sortir des tirages ordinaires")
		end
	end
	assert(Catalog.ById[petId .. "__E3__MRainbow"], petId .. " : formes évoluées / mutées")
	assert(Catalog.GetIncome(petId) > 0, petId .. " : revenu")
end

-- Tirage de l'œuf : bornes et proportions.
assert(Halloween.Roll(0) == S.Order[1] and Halloween.Roll(0.999999) == S.Order[#S.Order], "bornes")
local counts, n = {}, 200000
math.randomseed(7)
for _ = 1, n do
	local id = Halloween.Roll(math.random())
	counts[id] = (counts[id] or 0) + 1
end
for _, petId in ipairs(S.Order) do
	local want = S.Chances[petId] / 100
	local got = (counts[petId] or 0) / n
	assert(math.abs(got - want) < 0.01, string.format("%s : %.3f au lieu de %.3f", petId, got, want))
end
print("check-halloween PASS")
