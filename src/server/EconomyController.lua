--!strict
-- EconomyController : revenu passif des familiers (chaque seconde) et achats de la boutique.
-- Tout est validé côté serveur : le client envoie seulement l'Id de l'amélioration voulue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SessionData = require(script.Parent.SessionData)

local EconomyController = {}

local shopById: { [string]: Config.ShopItem } = {}
for _, item in ipairs(Config.Shop) do
	shopById[item.Id] = item
end

-- Revenu par seconde d'un joueur selon ses familiers.
function EconomyController.GetIncome(player: Player): number
	local data = SessionData.Get(player)
	if not data then
		return 0
	end
	local income = 0
	for rarity, count in pairs(data.pets) do
		income += (Config.Economy.PetIncome[rarity] or 0) * count
	end
	return income
end

local function onBuy(player: Player, itemId: unknown)
	if type(itemId) ~= "string" then
		return
	end
	local item = shopById[itemId]
	if not item or SessionData.HasUnlock(player, item.Id) then
		return
	end
	if SessionData.SpendMoney(player, item.Price) then
		SessionData.GiveUnlock(player, item.Id)
		print(string.format("[Shop] %s a acheté %s", player.Name, item.Name))
	end
end

function EconomyController.Init()
	Remotes.BuyUpgrade.OnServerEvent:Connect(onBuy)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local income = EconomyController.GetIncome(player)
				player:SetAttribute("Income", income)
				if income > 0 then
					SessionData.AddMoney(player, income)
				end
			end
		end
	end)
end

return EconomyController
