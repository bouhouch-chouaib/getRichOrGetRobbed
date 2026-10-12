--!strict
-- UpgradeSigns : bulle [E] « Améliorer » sur les panneaux d'amélioration du tapis et du banc de SA base
-- (créés par server/MapGenerator, textes écrits par server/TrainingController). Elle n'existe que chez le
-- propriétaire : les autres joueurs voient le panneau, sans bulle. Le serveur valide le prix (Remotes.BuyUpgrade).
-- Quand une station passe à un nouveau modèle (bois -> acier...), un message le célèbre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)

local player = Players.LocalPlayer

local STATIONS = { { model = "Treadmill", title = "Tapis de course" }, { model = "Bench", title = "Banc de muscu" } }

local shopItem: { [string]: Config.ShopItem } = {}
for _, item in ipairs(Config.Shop) do
	shopItem[item.Id] = item
end

local prompts: { [string]: ProximityPrompt } = {}

local function levelOf(id: string): number
	local level = player:GetAttribute("Upgrade_" .. id)
	return if type(level) == "number" then level else 0
end

local function refreshPrompt(id: string)
	local prompt = prompts[id]
	local item = shopItem[id]
	if not prompt or not item then
		return
	end
	local level = levelOf(id)
	local price = Config.GetUpgradePrice(item, level)
	prompt.Enabled = price ~= nil
	prompt.ActionText = if level <= 0 then "Acheter" else "Améliorer"
	if price then
		prompt.ObjectText = NumberFormat.money(price)
	end
end

local function clearPrompts()
	for id, prompt in pairs(prompts) do
		prompt:Destroy()
		prompts[id] = nil
	end
end

local function attachPrompts()
	clearPrompts()
	local index = player:GetAttribute("BaseIndex")
	local map = Workspace:FindFirstChild("Map")
	local base = map and type(index) == "number" and map:FindFirstChild("Base_" .. index)
	if not base then
		return
	end
	for _, station in ipairs(STATIONS) do
		local model = base:WaitForChild(station.model, 5)
		local sign = model and model:WaitForChild("UpgradeSign", 5)
		local board = sign and sign:WaitForChild("Board", 5)
		local id = sign and sign:GetAttribute("UpgradeId")
		if board and board:IsA("BasePart") and type(id) == "string" then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "UpgradePrompt"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Triggered:Connect(function()
				local item = shopItem[id]
				local price = item and Config.GetUpgradePrice(item, levelOf(id))
				local money = player:GetAttribute("Money")
				if price and type(money) == "number" and money < price then
					Toast.show("Pas assez d'argent : " .. NumberFormat.money(price), Color3.fromRGB(255, 90, 90))
					Sounds.play("Error")
					return
				end
				Remotes.BuyUpgrade:FireServer(id)
			end)
			prompt.Parent = board
			prompts[id] = prompt
			refreshPrompt(id)
		end
	end
end

for _, station in ipairs(STATIONS) do
	local id = station.model
	local previous = levelOf(id)
	player:GetAttributeChangedSignal("Upgrade_" .. id):Connect(function()
		local level = levelOf(id)
		refreshPrompt(id)
		-- Nouveau modèle débloqué (niveaux 6, 11, 16, 21) : on le fête.
		if level > previous and level > 1 and (level - 1) % Config.Training.LevelsPerTier == 0 then
			local tier = Config.GetStationTier(level)
			Toast.show(string.format("%s : MODÈLE %s !", TextFormat.upper(station.title), TextFormat.upper(tier.Name)), tier.Accent)
		end
		previous = level
	end)
end

player:GetAttributeChangedSignal("BaseIndex"):Connect(attachPrompts)
-- La carte est générée par le serveur : on attend qu'elle soit là.
task.spawn(function()
	Workspace:WaitForChild("Map")
	attachPrompts()
end)
