--!strict
-- HUD : toute l'interface du joueur, style "Steal a Brainrot / Steal an Egg" :
-- textes épais à gros contour noir, boutons carrés en dégradé sur la gauche,
-- fenêtres arrondies avec titre qui déborde et croix rouge.
--
-- Données lues depuis des attributs répliqués (ReplicatedStorage et Player).
-- Seul appel serveur : Remotes.BuyUpgrade (le serveur valide le prix).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toast = require(script.Parent.Toast)

local player = Players.LocalPlayer

local TITLE_FONT = Enum.Font.LuckiestGuy
local BODY_FONT = Enum.Font.FredokaOne
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local MONEY = Color3.fromRGB(110, 240, 70)

local PHASES = {
	Feeding = {
		Title = "NOURRIS LE TROU NOIR !",
		Hint = "[E] ramasser  •  maintiens CLIC GAUCHE pour viser, relâche pour lancer",
		Color = Color3.fromRGB(200, 120, 255),
	},
	Digesting = {
		Title = "LE TROU NOIR DIGÈRE...",
		Hint = "Ferme ta base et dépense ton argent dans la boutique !",
		Color = Color3.fromRGB(255, 90, 70),
	},
}

----------------------------------------------------------------------
-- Briques de style
----------------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3?, border: boolean?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or BLACK
	s.ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
end

-- Texte cartoon : police épaisse + contour noir.
local function text(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextSize = size
	label.Font = font or TITLE_FONT
	label.TextColor3 = color or WHITE
	stroke(label, math.max(1.5, size / 12))
	label.Parent = parent
	return label
end

-- Petit effet "rebond" au clic sur un bouton.
local function bounce(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
	end)
end

-- Bouton épais en dégradé avec contour noir.
local function chunkyButton(parent: Instance, label: string, size: UDim2, top: Color3, bottom: Color3, textSize: number): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = WHITE
	button.AutoButtonColor = false
	button.Text = ""
	corner(button, 12)
	stroke(button, 3, BLACK, true)
	gradient(button, top, bottom)
	button.Parent = parent

	local caption = text(button, label, textSize)
	caption.Name = "Caption"
	caption.Size = UDim2.fromScale(1, 1)

	bounce(button)
	return button
end

local function formatMoney(value: number): string
	local digits = tostring(math.floor(value))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

----------------------------------------------------------------------
-- Fenêtres (popups)
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

type Window = {
	frame: Frame,
	content: Frame,
	open: () -> (),
	close: () -> (),
	toggle: () -> (),
}

local openWindow: Window? = nil

local function makeWindow(title: string, size: Vector2, top: Color3, bottom: Color3): Window
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.52)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = WHITE
	frame.Visible = false
	corner(frame, 18)
	stroke(frame, 5, BLACK, true)
	gradient(frame, top, bottom)
	frame.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Parent = frame

	-- Titre qui déborde du haut de la fenêtre.
	local titleLabel = text(frame, title, 46, WHITE)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	titleLabel.Position = UDim2.new(0.5, 0, 0, 4)
	titleLabel.Size = UDim2.new(1, 0, 0, 56)
	titleLabel.ZIndex = 3

	local closeButton = chunkyButton(frame, "X", UDim2.fromOffset(50, 50), Color3.fromRGB(255, 90, 90), Color3.fromRGB(200, 30, 30), 30)
	closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
	closeButton.Position = UDim2.new(1, -6, 0, 6)
	closeButton.ZIndex = 3

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(18, 44)
	content.Size = UDim2.new(1, -36, 1, -60)
	content.Parent = frame

	local window: Window
	window = {
		frame = frame,
		content = content,
		open = function()
			if openWindow and openWindow ~= window then
				openWindow.close()
			end
			openWindow = window
			frame.Visible = true
			scale.Scale = 0.6
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end,
		close = function()
			if openWindow == window then
				openWindow = nil
			end
			frame.Visible = false
		end,
		toggle = function()
			if frame.Visible then
				window.close()
			else
				window.open()
			end
		end,
	}
	closeButton.Activated:Connect(window.close)
	return window
end

-- Liste défilante verticale pour le contenu d'une fenêtre.
local function makeList(parent: Instance, padding: number): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = BLACK
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = list
	list.Parent = parent
	return list
end

-- Carte claire avec contour noir (une ligne de boutique ou de familier).
local function makeCard(parent: Instance, height: number, order: number): Frame
	local cardFrame = Instance.new("Frame")
	cardFrame.Size = UDim2.new(1, 0, 0, height)
	cardFrame.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
	cardFrame.LayoutOrder = order
	corner(cardFrame, 14)
	stroke(cardFrame, 3, BLACK, true)
	cardFrame.Parent = parent
	return cardFrame
end

----------------------------------------------------------------------
-- Haut de l'écran : phase, chrono, consigne, points de la manche
----------------------------------------------------------------------

local phaseTitle = text(gui, "", 40)
phaseTitle.AnchorPoint = Vector2.new(0.5, 0)
phaseTitle.Position = UDim2.new(0.5, 0, 0, 6)
phaseTitle.Size = UDim2.fromOffset(700, 44)

local timerLabel = text(gui, "0:00", 54)
timerLabel.AnchorPoint = Vector2.new(0.5, 0)
timerLabel.Position = UDim2.new(0.5, 0, 0, 50)
timerLabel.Size = UDim2.fromOffset(300, 56)

local hintLabel = text(gui, "", 18, WHITE, BODY_FONT)
hintLabel.AnchorPoint = Vector2.new(0.5, 0)
hintLabel.Position = UDim2.new(0.5, 0, 0, 108)
hintLabel.Size = UDim2.fromOffset(760, 24)

local pointsLabel = text(gui, "", 30, Color3.fromRGB(255, 220, 60))
pointsLabel.AnchorPoint = Vector2.new(0.5, 0)
pointsLabel.Position = UDim2.new(0.5, 0, 0, 136)
pointsLabel.Size = UDim2.fromOffset(400, 34)

----------------------------------------------------------------------
-- Gauche : argent + boutons de menu
----------------------------------------------------------------------

local leftColumn = Instance.new("Frame")
leftColumn.Name = "Left"
leftColumn.BackgroundTransparency = 1
leftColumn.AnchorPoint = Vector2.new(0, 0.5)
leftColumn.Position = UDim2.new(0, 16, 0.5, 0)
leftColumn.Size = UDim2.fromOffset(240, 360)
leftColumn.Parent = gui

local moneyLabel = text(leftColumn, "$0", 48, MONEY)
moneyLabel.Size = UDim2.new(1, 0, 0, 52)
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left

local incomeLabel = text(leftColumn, "+$0/s", 24, MONEY)
incomeLabel.Position = UDim2.fromOffset(0, 52)
incomeLabel.Size = UDim2.new(1, 0, 0, 28)
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left

local speedLabel = text(leftColumn, "", 22, Color3.fromRGB(120, 210, 255))
speedLabel.Position = UDim2.fromOffset(0, 82)
speedLabel.Size = UDim2.new(1, 0, 0, 26)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Bouton de menu carré : grosse icône + nom en dessous.
local function menuButton(icon: string, name: string, y: number, top: Color3, bottom: Color3): TextButton
	local button = chunkyButton(leftColumn, "", UDim2.fromOffset(96, 96), top, bottom, 1)
	button.Position = UDim2.fromOffset(0, y)
	local iconLabel = text(button, icon, 46)
	iconLabel.Size = UDim2.new(1, 0, 0.72, 0)
	iconLabel.Position = UDim2.fromScale(0, 0.04)
	local nameLabel = text(button, name, 18)
	nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
	nameLabel.Position = UDim2.fromScale(0, 0.68)
	return button
end

local shopButton = menuButton("🛒", "BOUTIQUE", 124, Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 140, 20))
local petsButton = menuButton("🐾", "FAMILIERS", 232, Color3.fromRGB(110, 210, 255), Color3.fromRGB(40, 120, 255))

----------------------------------------------------------------------
-- Fenêtre Boutique
----------------------------------------------------------------------

local shopWindow = makeWindow("BOUTIQUE", Vector2.new(560, 440), Color3.fromRGB(255, 215, 80), Color3.fromRGB(255, 130, 30))
local shopList = makeList(shopWindow.content, 10)

local buyButtons: { [string]: TextButton } = {}
for index, item in ipairs(Config.Shop) do
	local cardFrame = makeCard(shopList, 96, index)

	local name = text(cardFrame, item.Name:upper(), 26, Color3.fromRGB(255, 200, 50))
	name.Position = UDim2.fromOffset(14, 8)
	name.Size = UDim2.new(1, -180, 0, 30)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local description = Instance.new("TextLabel")
	description.BackgroundTransparency = 1
	description.Font = BODY_FONT
	description.TextSize = 16
	description.TextColor3 = Color3.fromRGB(60, 50, 40)
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.Text = item.Description
	description.Position = UDim2.fromOffset(14, 42)
	description.Size = UDim2.new(1, -180, 0, 46)
	description.Parent = cardFrame

	local buy = chunkyButton(cardFrame, "", UDim2.fromOffset(140, 56), Color3.fromRGB(120, 240, 90), Color3.fromRGB(40, 170, 40), 26)
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -12, 0.5, 0)
	buy.Activated:Connect(function()
		Remotes.BuyUpgrade:FireServer(item.Id)
	end)
	buyButtons[item.Id] = buy
end

----------------------------------------------------------------------
-- Fenêtre Familiers
----------------------------------------------------------------------

local petsWindow = makeWindow("FAMILIERS", Vector2.new(480, 420), Color3.fromRGB(120, 215, 255), Color3.fromRGB(50, 110, 240))
local petsList = makeList(petsWindow.content, 10)

local petCounts: { [string]: TextLabel } = {}
for index, rarity in ipairs(Config.Rarities) do
	local cardFrame = makeCard(petsList, 70, index)
	cardFrame.BackgroundColor3 = WHITE
	gradient(cardFrame, rarity.Color:Lerp(WHITE, 0.35), rarity.Color)

	local name = text(cardFrame, rarity.Name:upper(), 30)
	name.Position = UDim2.fromOffset(16, 6)
	name.Size = UDim2.new(0.6, 0, 0, 34)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local income = text(cardFrame, string.format("+$%d/s chacun", Config.Economy.PetIncome[rarity.Name] or 0), 18, MONEY)
	income.Position = UDim2.fromOffset(16, 40)
	income.Size = UDim2.new(0.6, 0, 0, 22)
	income.TextXAlignment = Enum.TextXAlignment.Left

	local count = text(cardFrame, "x0", 40)
	count.AnchorPoint = Vector2.new(1, 0.5)
	count.Position = UDim2.new(1, -16, 0.5, 0)
	count.Size = UDim2.fromOffset(140, 44)
	count.TextXAlignment = Enum.TextXAlignment.Right
	petCounts[rarity.Name] = count
end

shopButton.Activated:Connect(shopWindow.toggle)
petsButton.Activated:Connect(petsWindow.toggle)

----------------------------------------------------------------------
-- Popup de récompenses (fin de manche)
----------------------------------------------------------------------

local rewardWindow = makeWindow("DIGESTION !", Vector2.new(420, 300), Color3.fromRGB(200, 130, 255), Color3.fromRGB(110, 40, 200))
local rewardHeadline = text(rewardWindow.content, "", 28)
rewardHeadline.Size = UDim2.new(1, 0, 0, 36)
rewardHeadline.Position = UDim2.fromOffset(0, 8)
local rewardBody = text(rewardWindow.content, "", 28)
rewardBody.Size = UDim2.new(1, 0, 1, -56)
rewardBody.Position = UDim2.fromOffset(0, 50)
rewardBody.RichText = true
rewardBody.TextYAlignment = Enum.TextYAlignment.Top

----------------------------------------------------------------------
-- Mise à jour
----------------------------------------------------------------------

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function updatePhase()
	local state = ReplicatedStorage:GetAttribute("GameState")
	local remaining = ReplicatedStorage:GetAttribute("TimeRemaining")
	local phase = if state == "Digesting" then PHASES.Digesting else PHASES.Feeding

	phaseTitle.Text = phase.Title
	phaseTitle.TextColor3 = phase.Color
	hintLabel.Text = phase.Hint
	pointsLabel.Visible = state ~= "Digesting"

	local seconds = if type(remaining) == "number" then math.max(0, remaining) else 0
	timerLabel.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
	-- Les 10 dernières secondes clignotent en rouge.
	timerLabel.TextColor3 = if seconds <= 10 and seconds % 2 == 0 then Color3.fromRGB(255, 70, 70) else WHITE
end

local function updateShop(money: number)
	for _, item in ipairs(Config.Shop) do
		local buy = buyButtons[item.Id]
		local caption = buy:FindFirstChild("Caption") :: TextLabel
		local buyGradient = buy:FindFirstChildOfClass("UIGradient") :: UIGradient
		if player:GetAttribute("Unlock_" .. item.Id) then
			caption.Text = "ACQUIS"
			buyGradient.Color = ColorSequence.new(Color3.fromRGB(190, 190, 190), Color3.fromRGB(120, 120, 120))
		elseif money >= item.Price then
			caption.Text = formatMoney(item.Price)
			buyGradient.Color = ColorSequence.new(Color3.fromRGB(120, 240, 90), Color3.fromRGB(40, 170, 40))
		else
			caption.Text = formatMoney(item.Price)
			buyGradient.Color = ColorSequence.new(Color3.fromRGB(255, 110, 110), Color3.fromRGB(190, 40, 40))
		end
	end
end

local function updateStats()
	local money = numberAttribute("Money")
	moneyLabel.Text = formatMoney(money)
	incomeLabel.Text = string.format("+%s/s", formatMoney(numberAttribute("Income")))
	speedLabel.Text = string.format("⚡ VITESSE %.1f", if player:GetAttribute("Speed") then numberAttribute("Speed") else Config.Speed.Base)
	pointsLabel.Text = string.format("POINTS : %d", numberAttribute("RoundScore"))
	updateShop(money)

	for _, rarity in ipairs(Config.Rarities) do
		petCounts[rarity.Name].Text = "x" .. numberAttribute("Pets_" .. rarity.Name)
	end
end

-- Petit "pop" du compteur d'argent quand il augmente.
local lastMoney = numberAttribute("Money")
local moneyScale = Instance.new("UIScale")
moneyScale.Parent = moneyLabel
player:GetAttributeChangedSignal("Money"):Connect(function()
	local money = numberAttribute("Money")
	if money > lastMoney then
		moneyScale.Scale = 1.15
		TweenService:Create(moneyScale, TweenInfo.new(0.2), { Scale = 1 }):Play()
	end
	lastMoney = money
end)

local rewardToken = 0
local function showRewards(score: number, pulls: number, results: { [string]: number }, money: number?)
	rewardToken += 1
	local token = rewardToken

	if pulls == 0 then
		rewardHeadline.Text = "IL A ENCORE FAIM..."
		rewardBody.Text = "0 POINT CETTE MANCHE"
	else
		rewardHeadline.Text = string.format("%d POINTS  •  %d TIRAGE%s", score, pulls, if pulls > 1 then "S" else "")
		local lines = {}
		for _, rarity in ipairs(Config.Rarities) do
			local count = results[rarity.Name] or 0
			if count > 0 then
				table.insert(lines, string.format('<font color="#%s">+%d %s</font>', rarity.Color:ToHex(), count, rarity.Name:upper()))
			end
		end
		if money and money > 0 then
			table.insert(lines, string.format('<font color="#%s">+%s</font>', MONEY:ToHex(), formatMoney(money)))
		end
		rewardBody.Text = table.concat(lines, "\n")
	end

	rewardWindow.open()
	task.delay(6, function()
		if token == rewardToken then
			rewardWindow.close()
		end
	end)
end

ReplicatedStorage:GetAttributeChangedSignal("GameState"):Connect(updatePhase)
ReplicatedStorage:GetAttributeChangedSignal("TimeRemaining"):Connect(updatePhase)
player.AttributeChanged:Connect(updateStats)

-- Confirmation d'achat : le serveur écrit "Unlock_<Id>" quand l'achat est validé.
for _, item in ipairs(Config.Shop) do
	player:GetAttributeChangedSignal("Unlock_" .. item.Id):Connect(function()
		if player:GetAttribute("Unlock_" .. item.Id) then
			Toast.show(item.Name:upper() .. " DÉBLOQUÉ !", Color3.fromRGB(110, 240, 70))
		end
	end)
end

-- Achat refusé faute d'argent : retour immédiat côté client.
for _, item in ipairs(Config.Shop) do
	buyButtons[item.Id].Activated:Connect(function()
		if not player:GetAttribute("Unlock_" .. item.Id) and numberAttribute("Money") < item.Price then
			Toast.show("PAS ASSEZ D'ARGENT !", Color3.fromRGB(255, 90, 90))
		end
	end)
end
Remotes.RewardsGranted.OnClientEvent:Connect(showRewards)

updatePhase()
updateStats()
