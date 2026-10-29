--!strict
-- Halloween 2026 côté joueur (Config.Halloween, shared/Halloween) ; le chaudron est dans client/HalloweenMenu.
--   - Heure hantée : comme le trou noir doré (client/GoldenHour), une ligne sous l'horloge (attribut "Wanted", client/HUD
--     décide si elle a la place), un message une minute avant et au début.
--   - Bonbons : « +15 BONBONS ! » quand une citrouille est avalée, et un message d'accueil au début de l'événement.
--   - Ambiance : les nuits (Feeding) tirent sur le violet, sans rien changer de jour.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local Halloween = require(ReplicatedStorage.Shared.Halloween)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)
local player = Players.LocalPlayer

local SETTINGS = Config.Halloween
local HAUNTED = SETTINGS.HauntedHour
local ORANGE = Color3.fromRGB(255, 150, 40)

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
local line = UiStyle.text(findStack(), "", 18, ORANGE)
line.Name = "Haunted"
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

-- Nuits violettes pendant l'événement (effet local, retiré à la fin).
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "HalloweenNight"
tint.Enabled = false
tint.Parent = Lighting
local NIGHT = Color3.fromRGB(232, 210, 255)
local tintOn: boolean? = nil
local function setTint(on: boolean)
	if tintOn == on then
		return
	end
	tintOn = on
	tint.Enabled = true
	TweenService:Create(tint, TweenInfo.new(3, Enum.EasingStyle.Sine), {
		TintColor = if on then NIGHT else Color3.new(1, 1, 1),
		Saturation = if on then 0.08 else 0,
	}):Play()
end

-- « +15 BONBONS ! » : seulement pour une grosse poignée d'un coup (citrouille, code), pas pour chaque objet.
local lastCandy: number? = nil
player:GetAttributeChangedSignal("Candy"):Connect(function()
	local candy = player:GetAttribute("Candy")
	if type(candy) ~= "number" then
		return
	end
	if lastCandy and candy - lastCandy >= 10 then
		Sounds.play("Coins")
		Toast.show(string.format("+%d BONBONS !", candy - lastCandy), ORANGE)
	end
	lastCandy = candy
end)

local welcomed = false
local stage = "idle"
while true do
	local now = Halloween.Now()
	local on = Halloween.Active(now)
	setTint(on and ReplicatedStorage:GetAttribute("GameState") == "Feeding")
	if on and not welcomed and player:GetAttribute("DataLoaded") == true then
		welcomed = true
		task.delay(6, function()
			Toast.show("HALLOWEEN ! JETTE DES OBJETS : GAGNE DES BONBONS !", ORANGE)
		end)
	end
	local active, seconds = Halloween.HauntedState(now)
	local left = math.max(0, math.ceil(seconds))
	local nextStage = if not on then "idle" elseif active then "active" elseif seconds <= HAUNTED.WarnSeconds then "soon" else "idle"
	if nextStage ~= stage then
		if nextStage == "soon" then
			Toast.show(string.format("DANS 1 MIN : HEURE HANTÉE, BONBONS x%d !", HAUNTED.CandyMultiplier), ORANGE)
		elseif nextStage == "active" and player:GetAttribute("DataLoaded") == true then
			Sounds.play("HoleBonus")
			Toast.show(string.format("HEURE HANTÉE : BONBONS x%d PENDANT %d MIN !", HAUNTED.CandyMultiplier, HAUNTED.Minutes), ORANGE)
		end
		stage = nextStage
	end
	if nextStage == "active" then
		line.Text = string.format("HEURE HANTÉE : BONBONS x%d  •  %d:%02d", HAUNTED.CandyMultiplier, left // 60, left % 60)
	elseif nextStage == "soon" then
		line.Text = string.format("HEURE HANTÉE DANS %d S !", left)
	end
	line:SetAttribute("Wanted", nextStage ~= "idle")
	task.wait(0.5)
end
