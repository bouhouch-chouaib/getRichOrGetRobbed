-- Exporte les valeurs d'équilibrage du jeu en JSON pour le simulateur Python (dataset_and_pipeline/economy_simulator.py).
-- Charge les VRAIS modules (Config, PetCatalog, PetSizes) comme tools/sim-economy.luau : rien n'est recopié à la main.
--
--   lune run tools/export-economy.luau . <sortie.json>
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local project = process.args[1] or "."
local output = process.args[2] or (project .. "/dataset_and_pipeline/economy_data.json")

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
local Sizes = load("PetSizes")

-- Valeurs Roblox (Color3, Vector3, Enum) en texte ou en tableau ; les fonctions sont ignorées.
local function clean(value: any): any
	local kind = typeof(value)
	if kind == "table" then
		local out = {}
		for key, item in pairs(value) do
			local cleaned = clean(item)
			if cleaned ~= nil then
				out[if type(key) == "number" then key else tostring(key)] = cleaned
			end
		end
		return out
	elseif kind == "Color3" then
		return value:ToHex()
	elseif kind == "Vector3" then
		return { value.X, value.Y, value.Z }
	elseif kind == "Vector2" then
		return { value.X, value.Y }
	elseif kind == "EnumItem" then
		return tostring(value)
	elseif kind == "function" then
		return nil
	end
	return value
end

local pets = {}
for _, entry in ipairs(Catalog.List) do
	table.insert(pets, {
		id = entry.Id,
		rarity = entry.Rarity,
		rarityIndex = Config.RarityIndex[entry.Rarity],
		world = entry.World,
		category = entry.Category,
		income = Catalog.GetIncome(entry.Id),
		size = Sizes.Of(entry.Id, entry.Rarity),
	})
end
local incomes = {}
for _, entry in ipairs(Catalog.Everything) do
	incomes[entry.Id] = Catalog.GetIncome(entry.Id)
end

-- Valeurs calculées par les fonctions de Config (le simulateur ne recopie pas les formules).
local derived = { rebirthPrices = {}, capsuleSlots = {} }
for n = 0, 40 do
	derived.rebirthPrices[n + 1] = Config.GetRebirthPrice(n)
	derived.capsuleSlots[n + 1] = if Config.GetCapsuleSlots then Config.GetCapsuleSlots(n) else Config.Evolution.Slots
end

local data = { config = clean(Config), pets = pets, incomes = incomes, derived = derived }
fs.writeFile(output, serde.encode("json", data, true))
print(string.format("%d familiers, %d formes -> %s", #pets, #Catalog.Everything, output))
