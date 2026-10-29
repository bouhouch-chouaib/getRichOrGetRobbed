--!strict
-- Gifts : cadeaux du créateur à des joueurs précis (Config.Gifts, 29 oct.). À la prochaine connexion du joueur, ses
-- familiers tombent du ciel dans sa base (BasePetsController.Celebrate), un message le lui dit et le serveur l'annonce.
-- Le cadeau est noté dans sa sauvegarde (liste des codes utilisés, clé « gift:<Id> ») : il ne se reçoit qu'une fois,
-- même sur plusieurs serveurs (verrou de session de SessionData).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BasePetsController = require(script.Parent.BasePetsController)
local SessionData = require(script.Parent.SessionData)

local SHOW_DELAY = 4 -- s : après l'écran de chargement, pour qu'il voie ses familiers tomber

local Gifts = {}

local function deliver(player: Player)
	while player.Parent and not SessionData.IsLoaded(player) do
		task.wait(0.5)
	end
	local data = SessionData.Get(player)
	if not player.Parent or not data or not data.loaded then
		return
	end
	for _, gift in ipairs(Config.Gifts) do
		local key = "gift:" .. gift.Id
		if gift.UserId == player.UserId and not table.find(data.codes, key) then
			local pets: { [string]: number } = {}
			local given: { string } = {}
			for _, petId in ipairs(gift.Pets) do
				if PetCatalog.ById[petId] then
					pets[petId] = (pets[petId] or 0) + 1
					table.insert(given, petId)
				end
			end
			table.insert(data.codes, key)
			SessionData.AddPets(player, pets)
			SessionData.Save(player)
			print(string.format("[Gifts] %s reçoit le cadeau %s : %s", player.Name, gift.Id, table.concat(given, ", ")))
			task.delay(SHOW_DELAY, function()
				if player.Parent then
					BasePetsController.Celebrate(player, given)
					Remotes.BonusResult:FireClient(player, "Gift", given)
					for _, petId in ipairs(given) do
						Remotes.Announcement:FireAllClients(player.DisplayName, petId)
					end
				end
			end)
		end
	end
end

function Gifts.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(deliver, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(deliver, player)
	end
end

return Gifts
