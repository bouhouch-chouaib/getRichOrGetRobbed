--!strict
-- BaseKeys : bulle [E] devant le portail des bases adverses FERMÉES pour les ouvrir avec une clé (Config.Keys).
--   - Avec une clé : Remotes.UseKey ; server/LockController vérifie tout (base fermée, pas la sienne, distance, clé en
--     réserve, base pas crochetée il y a peu) puis ouvre la base Config.Keys.Duration secondes.
--   - Sans clé : la bulle propose d'en acheter une en Robux (produit "Key1" de Config.Monetization) ; dès que l'achat est
--     validé (attribut "Keys" qui augmente), la clé est utilisée sur ce portail si le joueur y est encore.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 205, 50)

local keyProduct: Config.MonetizationItem? = nil
for _, product in ipairs(Config.Monetization.Products) do
	if product.Keys then
		keyProduct = product
	end
end

type Gate = { base: Model, part: BasePart, prompt: ProximityPrompt }
local gates: { Gate } = {}
local pendingBase: Model? = nil -- portail sur lequel utiliser la clé qu'on est en train d'acheter

local function keyCount(): number
	local keys = player:GetAttribute("Keys")
	return if type(keys) == "number" then keys else 0
end

local function isOpenable(base: Model): boolean
	local protected = base:GetAttribute("KeyProtectedUntil")
	return base:GetAttribute("Locked") == true
		and base:GetAttribute("BaseIndex") ~= player:GetAttribute("BaseIndex")
		and base:GetAttribute("ForcedOpenUntil") == nil
		and base:GetAttribute("OwnerName") ~= nil
		and not (type(protected) == "number" and protected > Workspace:GetServerTimeNow())
end

local function watchBase(base: Instance)
	if not base:IsA("Model") or not base.Name:match("^Base_%d+$") then
		return
	end
	local gate = base:WaitForChild("Gate", 10)
	if not gate or not gate:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "KeyPrompt"
	prompt.ObjectText = "Base fermée"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.Keys.HoldDuration
	prompt.MaxActivationDistance = Config.Keys.UseDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Triggered:Connect(function()
		if keyCount() > 0 then
			Remotes.UseKey:FireServer(base)
		elseif keyProduct and keyProduct.Id ~= 0 then
			pendingBase = base
			MarketplaceService:PromptProductPurchase(player, keyProduct.Id)
		else
			Sounds.play("Error")
			Toast.show("LES CLÉS ARRIVENT BIENTÔT !", Color3.fromRGB(255, 90, 90))
		end
	end)
	prompt.Parent = gate
	table.insert(gates, { base = base, part = gate, prompt = prompt })
end

-- Achat refusé ou annulé : on oublie le portail visé.
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _productId: number, purchased: boolean)
	if userId == player.UserId and not purchased then
		pendingBase = nil
	end
end)

-- Clé reçue (achat validé par le serveur) : utilisée tout de suite sur le portail visé si on y est encore.
local lastKeys = keyCount()
player:GetAttributeChangedSignal("Keys"):Connect(function()
	local keys = keyCount()
	if keys > lastKeys then
		Sounds.play("Purchase")
		local base = pendingBase
		pendingBase = nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local gate = base and base:FindFirstChild("Gate")
		if base and isOpenable(base) and root and root:IsA("BasePart") and gate and gate:IsA("BasePart")
			and (root.Position - gate.Position).Magnitude <= Config.Keys.UseDistance then
			Remotes.UseKey:FireServer(base)
		else
			Toast.show(string.format("CLÉ OBTENUE ! (x%d)  [E] DEVANT UNE BASE FERMÉE", keys), GOLD)
		end
	end
	lastKeys = keys
end)

-- Bulle visible seulement devant une base adverse fermée (et pas déjà ouverte, ni protégée après une clé).
local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	local keys = keyCount()
	for _, entry in ipairs(gates) do
		local show = isOpenable(entry.base)
		entry.prompt.Enabled = show
		if keys > 0 then
			entry.prompt.ActionText = string.format("Ouvrir avec une clé (x%d)", keys)
		else
			entry.prompt.ActionText = string.format("Clé : %d R$", if keyProduct then keyProduct.Price else 49)
		end
	end
end)

local map = Workspace:WaitForChild("Map")
map.ChildAdded:Connect(watchBase)
for _, child in ipairs(map:GetChildren()) do
	task.spawn(watchBase, child)
end
