--!strict
-- BadgeController : badges Roblox (Config.Badges). Deux façons de les donner :
--   - BadgeController.Award(joueur, clé) depuis un autre script, au moment de l'action (premier œuf éclos, vol réussi,
--     duel gagné) ;
--   - une ronde toutes les 5 s qui regarde la progression (monde atteint, Rebirth, familiers découverts, Ultime, Sigma).
-- Un badge dont l'Id vaut 0 (pas encore créé sur Roblox) est ignoré. Studio : rien n'est envoyé (BadgeService refuse).
-- Ne dépend que de Config et SessionData : n'importe quel contrôleur peut l'appeler sans boucle de require.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local SessionData = require(script.Parent.SessionData)

local BadgeController = {}

local byKey: { [string]: Config.BadgeDef } = {}
for _, badge in ipairs(Config.Badges) do
	byKey[badge.Key] = badge
end

-- Badges déjà donnés (ou déjà possédés) pendant cette session : on ne redemande pas à Roblox.
local given: { [Player]: { [string]: boolean } } = {}

function BadgeController.Award(player: Player, key: string)
	local badge = byKey[key]
	if not badge or badge.Id == 0 or RunService:IsStudio() or not player.Parent then
		return
	end
	local mine = given[player]
	if not mine then
		mine = {}
		given[player] = mine
	end
	if mine[key] then
		return
	end
	mine[key] = true -- réservé tout de suite : deux appels rapprochés ne donnent pas deux requêtes
	task.spawn(function()
		local ok, err = pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, badge.Id) then
				BadgeService:AwardBadge(player.UserId, badge.Id)
				print(string.format("[Badge] %s : %s", player.Name, badge.Name))
			end
		end)
		if not ok then
			mine[key] = nil -- on réessaiera à la prochaine occasion
			warn(string.format("[Badge] %s : %s impossible (%s)", player.Name, key, tostring(err)))
		end
	end)
end

-- Progression lue dans la sauvegarde du joueur.
local function check(player: Player)
	local data = SessionData.Get(player)
	if not data or not data.loaded then
		return
	end
	BadgeController.Award(player, "Welcome")
	if data.tier >= 2 then
		BadgeController.Award(player, "WorldDesert")
	end
	if data.tier >= 6 then
		BadgeController.Award(player, "WorldCosmos")
	end
	if data.tier >= #Config.Worlds then
		BadgeController.Award(player, "WorldDivin")
	end
	if data.rebirths >= 1 then
		BadgeController.Award(player, "FirstRebirth")
	end
	local discovered = SessionData.GetDiscovered(player)
	local species = 0
	for _, entry in ipairs(PetCatalog.List) do
		if discovered[entry.Id] then
			species += 1
		end
	end
	if species >= 25 then
		BadgeController.Award(player, "Index25")
	end
	if species >= 50 then
		BadgeController.Award(player, "Index50")
	end
	if species >= #PetCatalog.List then
		BadgeController.Award(player, "Index75")
	end
	for petId, count in pairs(data.pets) do
		local entry = PetCatalog.ById[petId]
		if entry and count > 0 then
			if entry.Stage == #Config.Evolution.Names then
				BadgeController.Award(player, "Ultime")
			end
			if entry.Rarity == "Sigma" then
				BadgeController.Award(player, "Sigma")
			end
		end
	end
end

function BadgeController.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		given[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(function()
					check(player)
				end)
				if not ok then
					warn("[Badge] " .. tostring(err))
				end
			end
		end
	end)
end

return BadgeController
