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

local petIncome = PetCatalog.GetIncome

-- Les Config.Pets.IncomeSlots meilleurs familiers NON équipés du joueur : ceux qui se baladent dans sa base
-- et rapportent de l'argent. Un familier équipé suit le joueur (bonus de points) mais ne rapporte rien.
function EconomyController.GetTopPets(player: Player): { string }
	local data = SessionData.Get(player)
	if not data then
		return {}
	end
	local list = {}
	for petId in pairs(data.pets) do
		for _ = 1, math.min(SessionData.GetSpareCount(player, petId), Config.Pets.IncomeSlots) do
			table.insert(list, petId)
		end
	end
	table.sort(list, function(a, b)
		local incomeA, incomeB = petIncome(a), petIncome(b)
		if incomeA ~= incomeB then
			return incomeA > incomeB
		end
		return a < b
	end)
	local top = {}
	for index = 1, math.min(#list, Config.Pets.IncomeSlots) do
		top[index] = list[index]
	end
	return top
end

-- Revenu par seconde : seuls les familiers qui se baladent dans la base rapportent.
function EconomyController.GetIncome(player: Player): number
	local income = 0
	for _, petId in ipairs(EconomyController.GetTopPets(player)) do
		income += petIncome(petId)
	end
	return income
end

EconomyController.GetPetIncome = petIncome

local function onBuy(player: Player, itemId: unknown)
	if type(itemId) ~= "string" then
		return
	end
	local item = shopById[itemId]
	if not item then
		return
	end
	local level = SessionData.GetUpgradeLevel(player, item.Id)
	local price = Config.GetUpgradePrice(item, level)
	if price and SessionData.SpendMoney(player, price) then
		SessionData.SetUpgradeLevel(player, item.Id, level + 1)
		print(string.format("[Shop] %s a acheté %s niveau %d", player.Name, item.Name, level + 1))
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
