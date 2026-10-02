--!strict
-- HUD : phase + chrono, score de la manche, vitesse, inventaire de familiers, popup de récompenses.
-- Tout est lu depuis des attributs répliqués (ReplicatedStorage et Player), aucun appel serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local PHASES = {
	Feeding = {
		Title = "NOURRIS LE TROU NOIR",
		Hint = "[E] pour ramasser un objet  •  Maintiens le clic gauche pour viser, relâche pour lancer",
		Color = Config.Colors.Feeding,
	},
	Digesting = {
		Title = "DIGESTION",
		Hint = "Le dôme repousse tout ! Cours sur le tapis de ta base pour gagner de la vitesse",
		Color = Config.Colors.Digesting,
	},
}

----------------------------------------------------------------------
-- Construction de l'interface
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, size: number, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.Font = font
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = parent
	return l
end

local function card(name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = Color3.fromRGB(18, 14, 30)
	frame.BackgroundTransparency = 0.25
	corner(frame, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(90, 70, 140)
	stroke.Parent = frame
	frame.Parent = gui
	return frame
end

-- Phase + chrono (haut centre)
local phaseCard = card("Phase", UDim2.fromOffset(420, 86), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
local phaseStroke = phaseCard:FindFirstChildOfClass("UIStroke") :: UIStroke
local phaseTitle = label(phaseCard, "", 24, Enum.Font.FredokaOne)
phaseTitle.Size = UDim2.new(1, 0, 0, 30)
phaseTitle.Position = UDim2.fromOffset(0, 6)
local timerLabel = label(phaseCard, "0:00", 36, Enum.Font.FredokaOne)
timerLabel.Size = UDim2.new(1, 0, 0, 40)
timerLabel.Position = UDim2.fromOffset(0, 38)

local hintLabel = label(gui, "", 16, Enum.Font.GothamMedium)
hintLabel.Size = UDim2.fromOffset(700, 24)
hintLabel.AnchorPoint = Vector2.new(0.5, 0)
hintLabel.Position = UDim2.new(0.5, 0, 0, 102)
hintLabel.TextStrokeTransparency = 0.4

-- Stats joueur (gauche)
local statsCard = card("Stats", UDim2.fromOffset(200, 80), UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
local scoreLabel = label(statsCard, "", 22, Enum.Font.FredokaOne)
scoreLabel.Size = UDim2.new(1, -20, 0, 34)
scoreLabel.Position = UDim2.fromOffset(10, 6)
scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
local speedLabel = label(statsCard, "", 18, Enum.Font.GothamMedium)
speedLabel.Size = UDim2.new(1, -20, 0, 28)
speedLabel.Position = UDim2.fromOffset(10, 42)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Inventaire de familiers (droite)
local petsCard = card("Pets", UDim2.fromOffset(200, 40 + #Config.Rarities * 30), UDim2.new(1, -10, 0.5, 0), Vector2.new(1, 0.5))
local petsTitle = label(petsCard, "FAMILIERS", 18, Enum.Font.FredokaOne)
petsTitle.Size = UDim2.new(1, 0, 0, 30)
petsTitle.Position = UDim2.fromOffset(0, 4)
local petLabels: { [string]: TextLabel } = {}
for index, rarity in ipairs(Config.Rarities) do
	local row = label(petsCard, "", 18, Enum.Font.GothamBold)
	row.Size = UDim2.new(1, -24, 0, 28)
	row.Position = UDim2.fromOffset(12, 6 + index * 30)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = rarity.Color
	petLabels[rarity.Name] = row
end

-- Popup de récompenses (centre)
local rewardCard = card("Rewards", UDim2.fromOffset(360, 80 + #Config.Rarities * 28), UDim2.fromScale(0.5, 0.42), Vector2.new(0.5, 0.5))
rewardCard.Visible = false
local rewardTitle = label(rewardCard, "", 24, Enum.Font.FredokaOne)
rewardTitle.Size = UDim2.new(1, 0, 0, 36)
rewardTitle.Position = UDim2.fromOffset(0, 8)
local rewardBody = label(rewardCard, "", 20, Enum.Font.GothamBold)
rewardBody.Size = UDim2.new(1, -20, 1, -54)
rewardBody.Position = UDim2.fromOffset(10, 46)
rewardBody.RichText = true
rewardBody.TextYAlignment = Enum.TextYAlignment.Top

----------------------------------------------------------------------
-- Mise à jour
----------------------------------------------------------------------

local function updatePhase()
	local state = ReplicatedStorage:GetAttribute("GameState")
	local remaining = ReplicatedStorage:GetAttribute("TimeRemaining")
	local phase = if state == "Digesting" then PHASES.Digesting else PHASES.Feeding

	phaseTitle.Text = phase.Title
	phaseTitle.TextColor3 = phase.Color
	phaseStroke.Color = phase.Color
	hintLabel.Text = phase.Hint

	local seconds = if type(remaining) == "number" then math.max(0, remaining) else 0
	timerLabel.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function updateStats()
	local score = player:GetAttribute("RoundScore")
	local speed = player:GetAttribute("Speed")
	scoreLabel.Text = "Points : " .. tostring(if type(score) == "number" then score else 0)
	speedLabel.Text = string.format("Vitesse : %.1f", if type(speed) == "number" then speed else Config.Speed.Base)

	for _, rarity in ipairs(Config.Rarities) do
		local count = player:GetAttribute("Pets_" .. rarity.Name)
		petLabels[rarity.Name].Text = string.format("%s : %d", rarity.Name, if type(count) == "number" then count else 0)
	end
end

local rewardToken = 0
local function showRewards(score: number, pulls: number, results: { [string]: number })
	rewardToken += 1
	local token = rewardToken

	if pulls == 0 then
		rewardTitle.Text = "Le trou noir a faim..."
		rewardBody.Text = "Aucun point cette manche.\nLance des objets dedans au prochain Feeding !"
	else
		rewardTitle.Text = string.format("%d points -> %d tirage%s", score, pulls, if pulls > 1 then "s" else "")
		local lines = {}
		for _, rarity in ipairs(Config.Rarities) do
			local count = results[rarity.Name] or 0
			if count > 0 then
				table.insert(lines, string.format('<font color="#%s">+%d %s</font>', rarity.Color:ToHex(), count, rarity.Name))
			end
		end
		rewardBody.Text = table.concat(lines, "\n")
	end

	rewardCard.Visible = true
	rewardCard.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(rewardCard, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(360, 80 + #Config.Rarities * 28),
	}):Play()

	task.delay(5, function()
		if token == rewardToken then
			rewardCard.Visible = false
		end
	end)
end

ReplicatedStorage:GetAttributeChangedSignal("GameState"):Connect(updatePhase)
ReplicatedStorage:GetAttributeChangedSignal("TimeRemaining"):Connect(updatePhase)
player.AttributeChanged:Connect(updateStats)
Remotes.RewardsGranted.OnClientEvent:Connect(showRewards)

updatePhase()
updateStats()
