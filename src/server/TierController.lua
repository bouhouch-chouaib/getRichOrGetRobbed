--!strict
-- TierController : voyage vers le monde suivant (Config.Worlds). Le joueur paie le prix du monde suivant depuis la
-- fenêtre Mondes (client/WorldMenu -> Remotes.BuyTier) ; SessionData.AdvanceTier vérifie l'argent et sauvegarde le
-- palier (attribut "Tier"). Tout le serveur est prévenu (Remotes.TierReached) : célébration chez le voyageur, annonce
-- chez les autres, et sa base change de monde aux yeux de tous (client/WorldSkin).
-- Retour dans un monde déjà visité (Remotes.GoToWorld) : gratuit ; seule l'apparence et la musique changent (attribut
-- "World") ; le bonus de revenu reste celui du monde le plus loin atteint ("Tier").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SessionData = require(script.Parent.SessionData)

local TierController = {}

local lastRequest: { [Player]: number } = {}

function TierController.Init()
	Remotes.BuyTier.OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 1 then
			return -- un double clic ne fait pas sauter deux mondes
		end
		lastRequest[player] = now
		local tier = SessionData.AdvanceTier(player)
		if tier then
			Remotes.TierReached:FireAllClients(player, tier)
			print(string.format("[Tier] %s voyage vers %s", player.Name, Config.GetWorld(tier).Name))
		end
	end)
	-- Retour dans un monde déjà visité : gratuit, le bonus de revenu reste celui du monde le plus loin débloqué.
	Remotes.GoToWorld.OnServerEvent:Connect(function(player: Player, world: unknown)
		local now = os.clock()
		if type(world) ~= "number" or now - (lastRequest[player] or 0) < 1 then
			return
		end
		lastRequest[player] = now
		if SessionData.SetWorld(player, world) then
			Remotes.TierReached:FireClient(player, player, world, true)
			print(string.format("[Tier] %s retourne dans %s", player.Name, Config.GetWorld(world).Name))
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastRequest[player] = nil
	end)
end

return TierController
