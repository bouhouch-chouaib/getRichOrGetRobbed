--!strict
-- EconomyController : revenu passif des familiers (chaque seconde) et achats de la boutique.
-- Tout est validé côté serveur : le client envoie seulement l'Id de l'amélioration voulue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetRoster = require(ReplicatedStorage.Shared.PetRoster)
local Perks = require(ReplicatedStorage.Shared.Perks)
local PowerCap = require(ReplicatedStorage.Shared.PowerCap)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Quests = require(script.Parent.Quests)
local SessionData = require(script.Parent.SessionData)
local OnboardingAnalytics = require(script.Parent.OnboardingAnalytics)

local EconomyController = {}

local shopById: { [string]: Config.ShopItem } = {}
for _, item in ipairs(Config.Shop) do
	shopById[item.Id] = item
end

local petIncome = PetCatalog.GetIncome

-- Revenu de chaque familier pour CE joueur : plafonné s'il est trop fort pour lui (Config.PowerCap, shared/PowerCap).
function EconomyController.IncomeFor(player: Player): (string) -> number
	local cap = PowerCap.Max(SessionData.GetSelfBest(player)) or math.huge
	return function(petId: string): number
		return math.min(petIncome(petId), cap)
	end
end

-- Places de base + Rebirths (Config.GetIncomeSlots) : une place par espèce non équipée avant les doublons, par revenu.
-- Ce sont ceux
-- qui se baladent dans sa base et rapportent de l'argent. Un familier équipé suit le joueur (bonus de points) mais ne
-- rapporte rien.
function EconomyController.GetTopPets(player: Player): { string }
	local data = SessionData.Get(player)
	if not data then
		return {}
	end
	local slots = Config.GetIncomeSlots(data.rebirths)
	local available: { [string]: number } = {}
	for petId in pairs(data.pets) do available[petId] = SessionData.GetSpareCount(player, petId) end
	local placed, removed = SessionData.GetBasePicks(player)
	return PetRoster.Select(available, slots, EconomyController.IncomeFor(player), placed, removed)
end

-- Revenu (plafonné) du moins bon familier de la base, 0 s'il reste une place : un vol n'est utile que s'il rapporte
-- plus (Config.StealShield, règle du vol utile ; attribut "BaseMin" lu par client/BasePets et client/LoosePets).
function EconomyController.GetBaseMin(player: Player): number
	local data = SessionData.Get(player)
	local top = EconomyController.GetTopPets(player)
	if not data or #top < Config.GetIncomeSlots(data.rebirths) then
		return 0
	end
	local income = EconomyController.IncomeFor(player)
	local low = math.huge
	for _, petId in ipairs(top) do
		low = math.min(low, income(petId))
	end
	return low
end

-- Valeur de la base (somme des revenus plafonnés, sans monde ni bonus) : sert à mesurer une perte (bouclier).
function EconomyController.GetBaseValue(player: Player): number
	local income = EconomyController.IncomeFor(player)
	local total = 0
	for _, petId in ipairs(EconomyController.GetTopPets(player)) do
		total += income(petId)
	end
	return total
end

-- Revenu par seconde : seuls les familiers qui se baladent dans la base rapportent.
function EconomyController.GetIncome(player: Player): number
	local income = EconomyController.GetBaseValue(player)
	-- Passes 2X Argent et VIP (shared/Perks), puis bonus du monde le plus loin débloqué (Config.Worlds, attribut Tier),
	-- même s'il est retourné dans un monde précédent, puis Rebirths (Config.Rebirth) et amis présents (Config.Friends).
	local tier = player:GetAttribute("Tier")
	local world = Config.GetWorld(if type(tier) == "number" then tier else 1)
	return income * Perks.MoneyMultiplier(player) * world.IncomeMultiplier * EconomyController.BonusMultiplier(player)
end

-- Rebirths x amis sur le serveur (affiché par le HUD).
function EconomyController.BonusMultiplier(player: Player): number
	local friends = player:GetAttribute("FriendsHere")
	local friendBonus = 1 + math.min(if type(friends) == "number" then friends else 0, Config.Friends.MaxFriends)
		* Config.Friends.BonusPerFriend
	local groupBonus = if player:GetAttribute("InGroup") == true then 1 + Config.Group.IncomeBonus else 1
	return Config.GetRebirthMultiplier(SessionData.GetRebirths(player)) * friendBonus * groupBonus
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
		OnboardingAnalytics.Mark(player, "Upgraded")
		Quests.Add(player, "Upgrade", 1)
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
				-- Formes dans la base (l'Index affiche « DANS TA BASE » / « EN RÉSERVE »).
				local inBase: { [string]: boolean } = {}
				local list: { string } = {}
				for _, petId in ipairs(EconomyController.GetTopPets(player)) do
					if not inBase[petId] then
						inBase[petId] = true
						table.insert(list, petId)
					end
				end
				table.sort(list)
				local text = table.concat(list, ",")
				if player:GetAttribute("InBase") ~= text then
					player:SetAttribute("InBase", text)
				end
				local baseMin = EconomyController.GetBaseMin(player)
				if player:GetAttribute("BaseMin") ~= baseMin then
					player:SetAttribute("BaseMin", baseMin)
				end
				if income > 0 then
					SessionData.AddMoney(player, income)
				end
			end
		end
	end)
end

return EconomyController
