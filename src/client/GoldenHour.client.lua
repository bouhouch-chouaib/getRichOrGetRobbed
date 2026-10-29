--!strict
-- Trou noir doré (Config.GoldenHour, shared/GoldenHour) : le rendez-vous des premières minutes de chaque heure.
-- Une minute avant : compte à rebours sous l'horloge et un message ; au début : message et son ; pendant : le temps qui
-- reste. La ligne sous l'horloge passe par l'attribut "Wanted" (client/HUD décide si elle a la place).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local GoldenHour = require(ReplicatedStorage.Shared.GoldenHour)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)
local player = Players.LocalPlayer

local SETTINGS = Config.GoldenHour
local GOLD = UiStyle.Colors.Gold

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
local line = UiStyle.text(findStack(), "", 18, GOLD)
line.Name = "GoldenHour"
line.LayoutOrder = 3
line.Size = UDim2.fromOffset(0, 34)
line.AutomaticSize = Enum.AutomaticSize.X
line.BackgroundColor3 = UiStyle.Colors.Panel
line.BackgroundTransparency = 0.25
line.Visible = false
UiStyle.corner(line, 7)
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
padding.Parent = line

-- "idle" (rien), "soon" (moins d'une minute avant) ou "active" : un message à chaque changement.
local stage = "idle"
while true do
	local active, seconds = GoldenHour.State(GoldenHour.Now())
	local left = math.max(0, math.ceil(seconds))
	local nextStage = if active then "active" elseif seconds <= SETTINGS.WarnSeconds then "soon" else "idle"
	if nextStage ~= stage then
		if nextStage == "soon" then
			Toast.show(string.format("DANS 1 MIN : TROU NOIR DORÉ, POINTS x%d !", SETTINGS.PointsMultiplier), GOLD)
		elseif nextStage == "active" and player:GetAttribute("DataLoaded") == true then
			Sounds.play("HoleBonus")
			Toast.show(string.format("TROU NOIR DORÉ : POINTS x%d PENDANT %d MIN !", SETTINGS.PointsMultiplier, SETTINGS.Minutes), GOLD)
		end
		stage = nextStage
	end
	if active then
		line.Text = string.format("TROU NOIR DORÉ : POINTS x%d  •  %d:%02d", SETTINGS.PointsMultiplier, left // 60, left % 60)
	elseif nextStage == "soon" then
		line.Text = string.format("TROU NOIR DORÉ DANS %d S !", left)
	end
	line:SetAttribute("Wanted", nextStage ~= "idle")
	task.wait(0.5)
end
