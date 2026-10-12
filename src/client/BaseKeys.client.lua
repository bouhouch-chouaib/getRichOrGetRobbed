--!strict
-- BaseKeys : bulle [E] devant le portail des bases adverses FERMÉES pour les ouvrir avec une clé (Config.Keys).
-- La bulle est créée ici (comme celle du vol) et envoie Remotes.UseKey ; server/LockController vérifie tout
-- (base fermée, pas la sienne, distance, clé en réserve) puis ouvre la base Config.Keys.Duration secondes.
-- Sans clé, la bulle explique où en acheter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toast = require(script.Parent.Toast)

local player = Players.LocalPlayer

type Gate = { base: Model, prompt: ProximityPrompt }
local gates: { Gate } = {}

local function keyCount(): number
	local keys = player:GetAttribute("Keys")
	return if type(keys) == "number" then keys else 0
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
		else
			Toast.show("IL TE FAUT UNE CLÉ 🗝 : ACHÈTE-LA À LA BOUTIQUE !", Color3.fromRGB(255, 200, 60))
		end
	end)
	prompt.Parent = gate
	table.insert(gates, { base = base, prompt = prompt })
end

-- Bulle visible seulement devant une base adverse fermée (et pas déjà ouverte par une clé).
local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	local keys = keyCount()
	local myBase = player:GetAttribute("BaseIndex")
	for _, entry in ipairs(gates) do
		local base = entry.base
		local show = base:GetAttribute("Locked") == true
			and base:GetAttribute("BaseIndex") ~= myBase
			and base:GetAttribute("ForcedOpenUntil") == nil
			and base:GetAttribute("OwnerName") ~= nil
		entry.prompt.Enabled = show
		entry.prompt.ActionText = if keys > 0 then string.format("Ouvrir avec une clé 🗝 (x%d)", keys) else "Il faut une clé 🗝"
	end
end)

local map = Workspace:WaitForChild("Map")
map.ChildAdded:Connect(watchBase)
for _, child in ipairs(map:GetChildren()) do
	task.spawn(watchBase, child)
end
