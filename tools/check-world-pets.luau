-- Familiers exclusifs des mondes (PetCatalog.ByWorld) : ils ne sortent des tirages que dans leur monde, ne comptent pas
-- dans le rang de tirage, et rapportent au moins autant que les familiers de base de leur rareté.
--   lune run tools/check-world-pets.luau .
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local project = require("@lune/process").args[1] or "."
local cache = {}
local parent = setmetatable({}, { __index = function(_, key) return key end })
local random = {
	NextNumber = function(_, a, b)
		local x = math.random()
		return if a then a + ((b or 1) - a) * x else x
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
	cache[name] = luau.load(fs.readFile(project .. "/src/shared/" .. name .. ".lua"), { environment = env })()
	return cache[name]
end
local Config, Catalog, Loot = load("Config"), load("PetCatalog"), load("LootEngine")
math.randomseed(7)

local count = 0
for worldIndex, world in ipairs(Config.Worlds) do
	local pets = Catalog.ByWorld[world.Id] or {}
	if worldIndex == 1 then
		assert(#pets == 0, "la Prairie n'a pas d'exclusifs")
	else
		local expected = if world.Id == "Volcan" then 6 else 5 -- + le Cerbère Infernal (25 oct.)
		assert(#pets == expected, world.Id .. " : " .. expected .. " exclusifs")
	end
	for _, entry in ipairs(pets) do
		count += 1
		assert(entry.World == world.Id and Config.WorldIndex[entry.World] == worldIndex)
		assert(not table.find(Catalog.BaseByRarity[entry.Rarity] or {}, entry), entry.Id .. " hors des tirages ordinaires")
		assert(table.find(Catalog.ByRarity[entry.Rarity], entry), entry.Id .. " dans l'Index")
		local best = 0
		for _, base in ipairs(Catalog.BaseByRarity[entry.Rarity] or {}) do
			best = math.max(best, Catalog.GetIncome(base.Id))
		end
		assert(Catalog.GetIncome(entry.Id) >= best, entry.Id .. " rapporte au moins autant que la base")
		assert(Catalog.ById[Catalog.Compose(entry.Id, 3, "Gold")].World == world.Id, "les formes gardent leur monde")
	end
end
assert(count == 31 and #Catalog.List == 111) -- + 5 familiers limités d'Halloween 2026 (hors mondes)

-- 20 000 tirages dans chaque monde : les exclusifs d'un AUTRE monde ne sortent jamais, ceux du monde oui.
for worldIndex, world in ipairs(Config.Worlds) do
	local outcome = Loot.rollPulls(20000, 0, 1, {}, 1, worldIndex, world.Id)
	local mine = 0
	for _, petId in ipairs(outcome.drops) do
		local entry = Catalog.ById[petId]
		assert(entry.World == nil or entry.World == world.Id, petId .. " sorti hors de son monde (" .. world.Id .. ")")
		if entry.World then
			mine += 1
		end
	end
	assert((worldIndex == 1) == (mine == 0), world.Id .. " : exclusifs tirés " .. mine)
end
-- Sans monde (anciens appels) : aucun exclusif.
for _, petId in ipairs(Loot.rollPulls(5000, 0, 1, {}, 1).drops) do
	assert(Catalog.ById[petId].World == nil, "aucun exclusif sans monde")
end
print("PASS: 31 world-exclusive pets (5 per world, 6 in Volcan), only pulled in their world, out of rank floor and fusion pools")
