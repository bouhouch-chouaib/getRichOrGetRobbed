-- Offline check of the actual server/MarketController (player market, Config.Market).
-- lune run tools/check-market.luau <project>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local project = require("@lune/process").args[1]

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in ipairs(callbacks) do
				callback(...)
			end
		end,
	}
end

-- Joueurs et sauvegardes simulés.
local function newPlayer(name, userId)
	return { Name = name, DisplayName = name, UserId = userId, Parent = "Players" }
end
local seller, buyer = newPlayer("Seller", 1), newPlayer("Buyer", 2)
local data = {
	[seller] = { loaded = true, money = 0, pets = { Rex = 2, Fish = 1 }, equipped = { Fish = 1 } },
	[buyer] = { loaded = true, money = 1000, pets = {}, equipped = {} },
}
local saved, celebrated, sent, published = {}, {}, {}, {}
local SessionData = {
	Get = function(player)
		return data[player]
	end,
	IsLoaded = function(player)
		return data[player] ~= nil and data[player].loaded
	end,
	GetSpareCount = function(player, petId)
		local d = data[player]
		return (d.pets[petId] or 0) - (d.equipped[petId] or 0)
	end,
	RemovePets = function(player, list)
		local d = data[player]
		for petId, count in pairs(list) do
			if (d.pets[petId] or 0) - (d.equipped[petId] or 0) < count then
				return false
			end
		end
		for petId, count in pairs(list) do
			d.pets[petId] -= count
		end
		return true
	end,
	AddPets = function(player, list)
		for petId, count in pairs(list) do
			data[player].pets[petId] = (data[player].pets[petId] or 0) + count
		end
	end,
	SpendMoney = function(player, amount)
		if data[player].money < amount then
			return false
		end
		data[player].money -= amount
		return true
	end,
	AddMoney = function(player, amount)
		data[player].money += amount
	end,
	Save = function(player)
		saved[player] = (saved[player] or 0) + 1
		return true
	end,
}
local Remotes = {
	Market = { OnServerEvent = signal(), FireClient = function(_, player, ok, message)
		table.insert(sent, { player = player, ok = ok, message = message })
	end },
	MarketUpdate = { FireAllClients = function(_, list)
		table.insert(published, list)
	end },
}
local modules = {
	Config = { Market = { MaxListings = 3, MinPrice = 1, MaxPrice = 1e30, Tax = 0.1 } },
	NumberFormat = { money = function(value)
		return "$" .. tostring(value)
	end },
	PetCatalog = { ById = { Rex = { Name = "Rex" }, Fish = { Name = "Fish" } } },
	Remotes = Remotes,
	BaseManager = { GetBase = function()
		return nil
	end },
	BasePetsController = {
		GetReserved = function()
			return 0
		end,
		Celebrate = function(player, list)
			table.insert(celebrated, { player = player, list = list })
		end,
	},
	SessionData = SessionData,
}
local guid = 0
local services = {
	HttpService = { GenerateGUID = function()
		guid += 1
		return "id" .. guid
	end },
	Players = { PlayerRemoving = signal() },
	ReplicatedStorage = { Shared = setmetatable({}, { __index = function(_, name)
		return name
	end }) },
}
local env = {
	game = { GetService = function(_, name)
		return services[name]
	end },
	script = { Parent = setmetatable({}, { __index = function(_, name)
		return name
	end }) },
	require = function(name)
		return assert(modules[name], name)
	end,
	task = { spawn = function(fn, ...)
		assert(coroutine.resume(coroutine.create(fn), ...))
	end, wait = function()
		coroutine.yield()
	end },
	os = os,
	print = function() end,
}
setmetatable(env, { __index = _G })
local Market = luau.load(fs.readFile(project .. "/src/server/MarketController.lua"), { environment = env })()
Market.Init()

-- Vendre : prix invalides, familier équipé, limite.
assert(not Market.List(seller, "Rex", 0), "price 0 accepted")
assert(not Market.List(seller, "Rex", 0 / 0), "NaN price accepted")
assert(not Market.List(seller, "Nope", 10), "unknown pet accepted")
assert(not Market.List(seller, "Fish", 10), "equipped pet listed")
assert(Market.List(seller, "Rex", 300.7), "listing refused")
assert(Market.List(seller, "Rex", 500), "second copy refused")
assert(not Market.List(seller, "Rex", 500), "listed more copies than owned")
local first = published[#published][1]
assert(first.price == 300 and first.available and first.seller == 1, "published listing")

-- Acheter : soi-même, pas assez d'argent, succès, déjà vendu.
assert(not Market.Buy(seller, first.id), "bought own listing")
local second = published[#published][2]
data[buyer].money = 100
assert(not Market.Buy(buyer, first.id), "bought without money")
assert(data[seller].pets.Rex == 2 and data[buyer].money == 100, "state changed on refused buy")
data[buyer].money = 1000
local ok, message = Market.Buy(buyer, first.id)
assert(ok, message)
assert(data[seller].pets.Rex == 1 and data[buyer].pets.Rex == 1, "pet not transferred")
assert(data[buyer].money == 700 and data[seller].money == 270, "money not transferred with tax")
assert(saved[seller] == 1 and saved[buyer] == 1, "profiles not saved")
assert(celebrated[1] and celebrated[1].player == buyer, "no celebration")
assert(sent[#sent].player == seller and sent[#sent].ok, "seller not told")
assert(not Market.Buy(buyer, first.id), "bought twice")

-- La seconde vente : le vendeur équipe le familier -> indisponible, achat refusé, rien ne bouge.
data[seller].equipped.Rex = 1
assert(not Market.Buy(buyer, second.id), "bought an equipped pet")
assert(data[seller].pets.Rex == 1 and data[buyer].money == 700, "state changed on unavailable buy")
data[seller].equipped.Rex = nil

-- Vendeur qui part pendant la sauvegarde en chargement / déconnecté.
data[seller].loaded = false
assert(not Market.Buy(buyer, second.id), "bought from an unloaded profile")
data[seller].loaded = true

-- Retirer : seulement le vendeur.
assert(not Market.Cancel(buyer, second.id), "cancelled someone else's listing")
assert(Market.Cancel(seller, second.id), "cancel refused")
assert(#published[#published] == 0, "listing not removed")

-- Départ du vendeur : ses ventes disparaissent.
assert(Market.List(seller, "Rex", 50))
services.Players.PlayerRemoving:Fire(seller)
assert(#published[#published] == 0, "listings kept after leaving")
print("PASS: market lists, refuses bad prices/equipped/extra copies, transfers pet + money (tax) atomically, saves both, cancels and cleans up")
