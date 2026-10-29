--!strict
-- SpeedUp : bulle « ACCÉLÉRER » (prix en Robux) sur chacun de MES œufs qui couvent dans la couveuse (29 oct., comme le
-- « Skip Growth » de la référence). Le prix suit le temps qu'il reste (Config.GetSpeedUpProduct) ; une accélération
-- déjà payée et gardée (attribut SpeedUps) s'affiche GRATUIT. Le serveur vérifie tout et propose l'achat
-- (server/SpeedUpController) ; la capsule a son propre bouton (client/CapsuleMenu). Messages du serveur : « Done » (c'est
-- accéléré), « Saved » (rien à accélérer : gardé pour le prochain œuf).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local player = Players.LocalPlayer
local prompts: { [BasePart]: ProximityPrompt } = {}

-- Texte du prix pour une attente de `left` secondes, nil s'il n'y a rien à proposer.
local function priceText(left: number): string?
	if left < Config.SpeedUp.MinSeconds then
		return nil
	end
	local saved = player:GetAttribute("SpeedUps")
	if type(saved) == "number" and saved > 0 then
		return "GRATUIT"
	end
	local product = Config.GetSpeedUpProduct(left)
	return if product then string.format("%d R$", product.Price) else nil
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or prompts[instance] or instance:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local eggId = string.match(instance.Name, "^(.-)#%d+$")
	if not eggId then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpeedUpPrompt"
	prompt.ActionText = "ACCÉLÉRER"
	prompt.ObjectText = ""
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Triggered:Connect(function()
		Remotes.SpeedUp:FireServer("Nest", eggId)
	end)
	prompt.Parent = instance
	prompts[instance] = prompt
end

local function remove(instance: Instance)
	if instance:IsA("BasePart") then
		local prompt = prompts[instance]
		if prompt then
			prompt:Destroy()
			prompts[instance] = nil
		end
	end
end

CollectionService:GetInstanceAddedSignal("IncubatingEgg"):Connect(add)
CollectionService:GetInstanceRemovedSignal("IncubatingEgg"):Connect(remove)
for _, instance in ipairs(CollectionService:GetTagged("IncubatingEgg")) do
	add(instance)
end

Remotes.SpeedUp.OnClientEvent:Connect(function(result: unknown)
	if result == "Done" then
		Toast.show("C'EST PARTI : TOUT DE SUITE !", UiStyle.Colors.Gold)
	elseif result == "Saved" then
		Toast.show("GARDÉ POUR TON PROCHAIN ŒUF", UiStyle.Colors.Cyan)
	end
end)

-- Prix et bulle à jour (le temps qui reste baisse, l'œuf qui part dans la capsule n'est plus à accélérer ici).
while true do
	task.wait(0.5)
	local now = Workspace:GetServerTimeNow()
	for anchor, prompt in pairs(prompts) do
		if not anchor.Parent then
			remove(anchor)
			continue
		end
		local readyAt = anchor:GetAttribute("ReadyAt")
		local text = if type(readyAt) == "number" and anchor:GetAttribute("Leaving") ~= true then priceText(readyAt - now) else nil
		prompt.Enabled = text ~= nil
		if text and prompt.ObjectText ~= text then
			prompt.ObjectText = text
		end
	end
end
