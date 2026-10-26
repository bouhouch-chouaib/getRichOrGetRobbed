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

-- La pile du HUD réserve la place : aucun chevauchement avec le chrono ou ses consignes. Une courte pastille, montrée
-- seulement si la ligne sous l'horloge est libre (attribut "Wanted", client/HUD) ; l'explication passe une fois en Toast.
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
-- Cherchée partout : dans l'aperçu téléphone de Studio, la pile est sous HUD.PhonePreview.Root.
local function findStack(): Instance
	while true do
		local found = hud:FindFirstChild("TopStack", true)
		if found then
			return found
		end
		hud.DescendantAdded:Wait()
	end
end
local stack = findStack()
local shield = UiStyle.text(stack, "", 18, UiStyle.Colors.Cyan)
shield.Name = "TheftProtection"
shield.LayoutOrder = 4
shield.Size = UDim2.fromOffset(0, 34)
shield.AutomaticSize = Enum.AutomaticSize.X
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
		Toast.show("BRAVO ! UN ŒUF CADEAU T’ATTEND DANS TA BASE !", UiStyle.Colors.Cyan)
	end
end)
player:GetAttributeChangedSignal("StarterBonusPaid"):Connect(function()
	if player:GetAttribute("DataLoaded") == true and player:GetAttribute("StarterBonusPaid") == true then
		Toast.show(
			NumberFormat.money(Config.Newcomer.BonusMoney)
				.. " POUR TOI ! ACHÈTE UN TAPIS DANS LA BOUTIQUE !",
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
			Toast.show("ON T’A BEAUCOUP VOLÉ : PERSONNE NE PEUT TE VOLER PENDANT "
				.. math.ceil(shieldSeconds / 60) .. " MIN !", UiStyle.Colors.Cyan)
		end
		wasShielded = shielded
		if protected and not wasProtected then
			Toast.show("PERSONNE NE PEUT TE VOLER AU DÉBUT  •  SI TU VOLES, ÇA S’ARRÊTE", UiStyle.Colors.Cyan)
		end
		shield:SetAttribute("Wanted", protected or shielded)
		if shielded then
			shield.Text = string.format("BOUCLIER  %d:%02d", shieldSeconds // 60, shieldSeconds % 60)
		elseif protected then
			shield.Text = string.format("PROTÉGÉ  %d:%02d", seconds // 60, seconds % 60)
		elseif wasProtected then
			Toast.show(
				"PROTECTION FINIE ! FERME TA BASE AVEC SON BOUTON POUR TE PROTÉGER",
				UiStyle.Colors.Gold
			)
		end
		wasProtected = protected
		task.wait(0.25)
	end
end)
