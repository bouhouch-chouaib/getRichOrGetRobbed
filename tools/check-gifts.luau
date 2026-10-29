-- Cadeaux du créateur (server/Gifts, Config.Gifts) : le bon joueur reçoit ses familiers une seule fois, les autres rien.
--   lune run tools/check-gifts.luau .
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local project = require("@lune/process").args[1] or "."
local parent = setmetatable({}, { __index = function(_, key) return key end })
local function loadShared(name)
	local env = table.clone(r)
	env.script = { Parent = parent }
	env.require = function(module)
		return if module == "Typography" then {} else loadShared(module)
	end
	return luau.load(fs.readFile(project .. "/src/shared/" .. name .. ".lua"), { environment = env })()
end
local Config, PetCatalog = loadShared("Config"), loadShared("PetCatalog")

-- Faux joueurs, sauvegardes et services.
local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end
local playerAdded = signal()
local saves, celebrated, messages, announced = {}, {}, {}, 0
local function newPlayer(userId)
	local player = { UserId = userId, Name = "P" .. userId, DisplayName = "P" .. userId, Parent = true }
	saves[player] = { loaded = true, codes = {}, pets = {} }
	return player
end
local modules = {
	Config = Config,
	PetCatalog = PetCatalog,
	Remotes = {
		BonusResult = { FireClient = function(_, player, kind, pets) messages[player] = { kind = kind, pets = pets } end },
		Announcement = { FireAllClients = function() announced += 1 end },
	},
	BasePetsController = { Celebrate = function(player, pets) celebrated[player] = pets end },
	SessionData = {
		IsLoaded = function(player) return saves[player].loaded end,
		Get = function(player) return saves[player] end,
		AddPets = function(player, pets)
			for petId, count in pets do
				saves[player].pets[petId] = (saves[player].pets[petId] or 0) + count
			end
		end,
		Save = function() return true end,
	},
}
local env = table.clone(r)
env.script = { Parent = parent }
env.require = function(name) return assert(modules[name], name) end
env.game = { GetService = function(_, name)
	if name == "Players" then
		return { PlayerAdded = playerAdded, GetPlayers = function() return {} end }
	end
	return { Shared = parent }
end }
env.task = {
	spawn = function(fn, ...) fn(...) end,
	delay = function(_, fn) fn() end,
	wait = function() end,
}
local Gifts = luau.load(fs.readFile(project .. "/src/server/Gifts.lua"), { environment = env })()
Gifts.Init()

-- Chaque cadeau de Config.Gifts : des familiers qui existent.
for _, gift in Config.Gifts do
	for _, petId in gift.Pets do
		assert(PetCatalog.ById[petId], "familier inconnu dans Config.Gifts : " .. petId)
	end
end

local gift = assert(Config.Gifts[1], "Config.Gifts vide")
local lucky, other = newPlayer(gift.UserId), newPlayer(1)
playerAdded:Fire(lucky)
playerAdded:Fire(other)
for _, petId in gift.Pets do
	assert(saves[lucky].pets[petId] == 1, "familier pas reçu : " .. petId)
end
assert(table.find(saves[lucky].codes, "gift:" .. gift.Id), "cadeau pas noté dans la sauvegarde")
assert(celebrated[lucky] and #celebrated[lucky] == #gift.Pets, "pas de chute dans la base")
assert(messages[lucky] and messages[lucky].kind == "Gift", "pas de message")
assert(announced == #gift.Pets, "pas d'annonce au serveur")
assert(next(saves[other].pets) == nil and not messages[other], "un autre joueur a reçu le cadeau")

-- Il revient (autre serveur, même sauvegarde) : rien de plus.
saves[lucky].pets = {}
local again = { UserId = gift.UserId, Name = lucky.Name, DisplayName = lucky.DisplayName, Parent = true }
saves[again] = { loaded = true, codes = saves[lucky].codes, pets = {} }
playerAdded:Fire(again)
assert(next(saves[again].pets) == nil, "cadeau reçu deux fois")

-- Sauvegarde pas chargée : rien n'est donné (on ne pourrait pas noter le cadeau).
local failed = newPlayer(gift.UserId)
saves[failed].loaded = false
failed.Parent = false
playerAdded:Fire(failed)
assert(next(saves[failed].pets) == nil, "cadeau donné sans sauvegarde chargée")
print("check-gifts PASS")
