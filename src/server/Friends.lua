--!strict
-- Friends : qui est ami avec qui parmi les joueurs du serveur (Player:IsFriendsWithAsync, gardé en mémoire), pour le jeu
-- entre amis (Config.Friends, ECONOMY_REPORT.md règles 17 à 19) : base voisine (server/BaseManager), refuge, escorte et
-- « Reprendre » pour un ami (server/StealController). Attribut "FriendIds" sur chaque joueur : les UserId de ses amis
-- présents, séparés par des virgules (lu par client/PetFollow pour la bulle « Reprendre »).
-- Le bonus de revenu des amis (attribut "FriendsHere") reste calculé par server/ProgressionController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Friends = {}

local cache: { [Player]: { [Player]: boolean } } = {}

local function publish(player: Player)
	local ids = {}
	for other in pairs(cache[player] or {}) do
		if other.Parent then
			table.insert(ids, tostring(other.UserId))
		end
	end
	table.sort(ids)
	player:SetAttribute("FriendIds", if #ids > 0 then table.concat(ids, ",") else nil)
end

-- Ces deux joueurs sont-ils amis sur Roblox ? (sans attente : ce qui a déjà été vérifié)
function Friends.Are(a: Player, b: Player): boolean
	local list = cache[a]
	return list ~= nil and list[b] == true
end

-- Les amis présents de ce joueur.
function Friends.Of(player: Player): { Player }
	local list = {}
	for other in pairs(cache[player] or {}) do
		if other.Parent then
			table.insert(list, other)
		end
	end
	return list
end

-- Vérifie les amitiés d'un joueur qui arrive avec tous les présents, en parallèle, en attendant au plus
-- Config.Friends.CheckTimeout secondes (appelé par server/BaseManager avant de choisir sa base).
function Friends.Check(player: Player)
	cache[player] = cache[player] or {}
	local pending = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			pending += 1
			task.spawn(function()
				local ok, friends = pcall(function()
					return player:IsFriendsWithAsync(other.UserId)
				end)
				if ok and friends and player.Parent and other.Parent then
					cache[player][other] = true
					cache[other] = cache[other] or {}
					cache[other][player] = true
					publish(other)
				end
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < Config.Friends.CheckTimeout do
		task.wait(0.1)
	end
	publish(player)
end

function Friends.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		local list = cache[player]
		cache[player] = nil
		for other in pairs(list or {}) do
			if cache[other] then
				cache[other][player] = nil
				publish(other)
			end
		end
	end)
end

return Friends
