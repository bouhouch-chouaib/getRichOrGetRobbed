--!strict
-- EconomyController : revenu passif des familiers (chaque seconde) et achats de la boutique.
-- Tout est validé côté serveur : le client envoie seulement l'Id de l'amélioration voulue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SessionData = require(script.Parent.SessionData)

local EconomyController = {}

local shopById: { [string]: Config.ShopItem } = {}
for _, item in ipairs(Config.Shop) do
	shopById[item.Id] = item
end

-- Revenu par seconde : seuls les Config.Pets.IncomeSlots meilleurs familiers de la base rapportent.
function EconomyController.GetIncome(player: Player): number
	local data = SessionData.Get(player)
	if not data then
		return 0
	end
	local incomes = {}
	for petId, count in pairs(data.pets) do
		local entry = PetCatalog.ById[petId]
		local rarity = entry and Config.Rarities[Config.RarityIndex[entry.Rarity]]
		if rarity then
			for _ = 1, math.min(count, Config.Pets.IncomeSlots) do
				table.insert(incomes, rarity.Income)
			end
		end
	end
	table.sort(incomes, function(a, b)
		return a > b
	end)
	local income = 0
	for index = 1, math.min(#incomes, Config.Pets.IncomeSlots) do
		income += incomes[index]
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
