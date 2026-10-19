--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiStyle = require(script.Parent.UiStyle)
local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local stack = hud:WaitForChild("Root"):WaitForChild("TopStack")
local button = UiStyle.button(stack, "", UDim2.fromOffset(230, 34), UiStyle.Colors.Cyan, 15)
button.Name, button.LayoutOrder = "MagnetToggle", 5
button.Visible = false
local function refresh()
	button.Visible = Perks.MagnetLevel(player) > 0
	local enabled = player:GetAttribute("MagnetEnabled") == true
	(button:FindFirstChild("Caption") :: TextLabel).Text = "AIMANT : "
		.. (if enabled then "ACTIF" else "ARRÊT")
		.. (if UserInputService.KeyboardEnabled then " [G]" else "")
	UiStyle.setButtonColor(button, if enabled then UiStyle.Colors.Green else UiStyle.Colors.Cyan)
end
local function toggle()
	if button.Visible then
		Remotes.SetMagnet:FireServer(player:GetAttribute("MagnetEnabled") ~= true)
	end
end
button.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.G then
		toggle()
	end
end)
for _, attribute in ipairs({ "MagnetEnabled", "Upgrade_Magnet", "Pass_AutoMagnet", "DataLoaded" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()
