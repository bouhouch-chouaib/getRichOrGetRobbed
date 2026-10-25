--!strict
-- Retours discrets du premier œuf, de sa prime et de la protection anti-vol.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)
local player = Players.LocalPlayer

-- La pile du HUD réserve la place : aucun chevauchement avec le chrono ou ses consignes.
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local stack = hud:WaitForChild("Root"):WaitForChild("TopStack")
local shield = UiStyle.text(stack, "", 14, UiStyle.Colors.Cyan)
shield.Name = "TheftProtection"
shield.LayoutOrder = 4
shield.Size = UDim2.fromOffset(420, 32)
shield.BackgroundColor3 = UiStyle.Colors.Panel
shield.BackgroundTransparency = 0.25
shield.Visible = false
UiStyle.corner(shield, 7)
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
padding.Parent = shield

player:GetAttributeChangedSignal("StarterEggGiven"):Connect(function()
	if player:GetAttribute("DataLoaded") == true and player:GetAttribute("StarterEggGiven") == true then
		Toast.show("PREMIER OBJET ! UN ŒUF OFFERT T’ATTEND DANS TA COUVEUSE.", UiStyle.Colors.Cyan)
	end
end)
player:GetAttributeChangedSignal("StarterBonusPaid"):Connect(function()
	if player:GetAttribute("DataLoaded") == true and player:GetAttribute("StarterBonusPaid") == true then
		Toast.show(
			NumberFormat.money(Config.Newcomer.BonusMoney)
				.. " OFFERTS ! ACHÈTE TON PREMIER TAPIS OU BANC EN BOUTIQUE.",
			UiStyle.Colors.Money
		)
	end
end)

task.spawn(function()
	local wasProtected = false
	local wasShielded = false
	while shield.Parent do
		local deadline = player:GetAttribute("NewcomerProtectedUntil")
		local seconds = if type(deadline) == "number"
			then math.max(0, math.ceil(deadline - Workspace:GetServerTimeNow()))
			else 0
		local protected = player:GetAttribute("DataLoaded") == true and seconds > 0
		-- Bouclier après une grosse perte (Config.StealShield, server/StealController).
		local shieldUntil = player:GetAttribute("StealShieldUntil")
		local shieldSeconds = if type(shieldUntil) == "number"
			then math.max(0, math.ceil(shieldUntil - Workspace:GetServerTimeNow()))
			else 0
		local shielded = not protected and shieldSeconds > 0
		if shielded and not wasShielded then
			Toast.show("TU AS BEAUCOUP PERDU : TA BASE EST PROTÉGÉE DES VOLS PENDANT "
				.. math.ceil(shieldSeconds / 60) .. " MIN.", UiStyle.Colors.Cyan)
		end
		wasShielded = shielded
		shield.Visible = protected or shielded
		if shielded then
			shield.Text = string.format("BOUCLIER %d:%02d • Personne ne peut te voler", shieldSeconds // 60, shieldSeconds % 60)
		elseif protected then
			shield.Text =
				string.format("ANTI-VOL %d:%02d • Voler met fin à ta protection", seconds // 60, seconds % 60)
		elseif wasProtected then
			Toast.show(
				"PROTECTION TERMINÉE : UTILISE LE VERROU DE TA BASE POUR PROTÉGER TES FAMILIERS !",
				UiStyle.Colors.Gold
			)
		end
		wasProtected = protected
		task.wait(0.25)
	end
end)
