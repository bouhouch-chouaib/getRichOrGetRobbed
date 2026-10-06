--!strict
-- HUD : toute l'interface du joueur, style "Steal a Brainrot / Steal an Egg" :
-- textes épais à gros contour noir, boutons carrés en dégradé sur la gauche,
-- fenêtres arrondies avec titre qui déborde et croix rouge.
--
-- Données lues depuis des attributs répliqués (ReplicatedStorage et Player).
-- Seul appel serveur : Remotes.BuyUpgrade (le serveur valide le prix).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local ScreenScale = require(script.Parent.ScreenScale)
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
		Hint = if ScreenScale.isTouch()
			then "Touche RAMASSER sur un objet  •  maintiens LANCER pour viser, relâche pour lancer"
			else "[E] ramasser  •  maintiens CLIC GAUCHE pour viser, relâche pour lancer",
		Color = Color3.fromRGB(200, 120, 255),
	},
	Digesting = {
		Title = "LE TROU NOIR DIGÈRE...",
		Hint = "Ferme ta base, entraîne-toi et dépense ton argent dans la boutique !",
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

local formatMoney = NumberFormat.money

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

----------------------------------------------------------------------
-- Fenêtres (popups)
----------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")
-- Tous les éléments sont parentés à "gui", un cadre mis à l'échelle de l'écran (téléphone, tablette, PC).
local gui = ScreenScale.attach(screenGui)

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
-- En bas de l'écran pour ne pas gêner la vue.
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -18)
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
-- Sur tactile, la colonne est collée en haut pour ne pas passer sous le joystick (bas gauche).
leftColumn.AnchorPoint = if ScreenScale.isTouch() then Vector2.new(0, 0) else Vector2.new(0, 0.5)
leftColumn.Position = if ScreenScale.isTouch() then UDim2.new(0, 16, 0, 10) else UDim2.new(0, 16, 0.5, 0)
leftColumn.Size = UDim2.fromOffset(240, 400)
leftColumn.Parent = gui

local moneyLabel = text(leftColumn, "$0", 48, MONEY)
moneyLabel.Size = UDim2.new(1, 0, 0, 52)
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left

local incomeLabel = text(leftColumn, "+$0/s", 24, MONEY)
incomeLabel.Position = UDim2.fromOffset(0, 52)
incomeLabel.Size = UDim2.new(1, 0, 0, 28)
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Ligne de stat d'entraînement : "⚡ VITESSE NV 3" + barre d'XP.
type StatRow = { label: TextLabel, fill: Frame }
local function statRow(y: number, color: Color3): StatRow
	local label = text(leftColumn, "", 20, color)
	label.Position = UDim2.fromOffset(0, y)
	label.Size = UDim2.new(1, 0, 0, 24)
	label.TextXAlignment = Enum.TextXAlignment.Left
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(0, y + 26)
	bar.Size = UDim2.fromOffset(200, 12)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	corner(bar, 6)
	stroke(bar, 2, BLACK, true)
	bar.Parent = leftColumn
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	corner(fill, 6)
	fill.Parent = bar
	return { label = label, fill = fill }
end
local speedRow = statRow(84, Color3.fromRGB(120, 210, 255))
local strengthRow = statRow(130, Color3.fromRGB(255, 150, 80))

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

local shopButton = menuButton("🛒", "BOUTIQUE", 180, Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 140, 20))
local petsButton = menuButton("🐾", "FAMILIERS", 288, Color3.fromRGB(110, 210, 255), Color3.fromRGB(40, 120, 255))

----------------------------------------------------------------------
-- Fenêtre Boutique
----------------------------------------------------------------------

local shopWindow = makeWindow("BOUTIQUE", Vector2.new(560, 440), Color3.fromRGB(255, 215, 80), Color3.fromRGB(255, 130, 30))
local shopList = makeList(shopWindow.content, 10)

local buyButtons: { [string]: TextButton } = {}
local shopLevels: { [string]: TextLabel } = {}
for index, item in ipairs(Config.Shop) do
	local cardFrame = makeCard(shopList, 96, index)

	local name = text(cardFrame, item.Icon .. " " .. item.Name:upper(), 24, Color3.fromRGB(255, 200, 50))
	name.Position = UDim2.fromOffset(14, 8)
	name.Size = UDim2.new(1, -180, 0, 30)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local levelLabel = text(cardFrame, "", 16, Color3.fromRGB(120, 210, 255))
	levelLabel.Name = "Level"
	levelLabel.AnchorPoint = Vector2.new(1, 0)
	levelLabel.Position = UDim2.new(1, -12, 0, 4)
	levelLabel.Size = UDim2.fromOffset(140, 18)
	levelLabel.ZIndex = 2
	shopLevels[item.Id] = levelLabel

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
	buy.Position = UDim2.new(1, -12, 0.5, 8)
	buy.Activated:Connect(function()
		Remotes.BuyUpgrade:FireServer(item.Id)
	end)
	buyButtons[item.Id] = buy
end

----------------------------------------------------------------------
-- Fenêtre Familiers
----------------------------------------------------------------------

local petsWindow = makeWindow("FAMILIERS", Vector2.new(720, 520), Color3.fromRGB(120, 215, 255), Color3.fromRGB(50, 110, 240))

-- Bandeau : places d'équipement, multiplicateur, collection.
local petsHeader = text(petsWindow.content, "", 22)
petsHeader.Size = UDim2.new(1, 0, 0, 28)
petsHeader.Position = UDim2.fromOffset(0, 6)

local petsGrid = Instance.new("ScrollingFrame")
petsGrid.Position = UDim2.fromOffset(0, 40)
petsGrid.Size = UDim2.new(1, 0, 1, -40)
petsGrid.BackgroundTransparency = 1
petsGrid.BorderSizePixel = 0
petsGrid.ScrollBarThickness = 8
petsGrid.ScrollBarImageColor3 = BLACK
petsGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
petsGrid.CanvasSize = UDim2.new()
petsGrid.Parent = petsWindow.content
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(122, 160)
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = petsGrid
local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop = UDim.new(0, 6)
gridPadding.PaddingLeft = UDim.new(0, 6)
gridPadding.Parent = petsGrid

-- Aperçu 3D d'un familier dans un ViewportFrame (silhouette noire si non obtenu).
local function petViewport(parent: Instance, petId: string, silhouette: boolean): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = WHITE
	viewport.Parent = parent
	local model = PetModelBuilder.Build(petId)
	if model then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant:Destroy()
			elseif silhouette and descendant:IsA("BasePart") then
				descendant.Color = Color3.fromRGB(20, 20, 30)
				descendant.Material = Enum.Material.SmoothPlastic
			end
		end
		model:PivotTo(CFrame.new())
		model.Parent = viewport
		local extent = model:GetExtentsSize().Magnitude
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(Vector3.new(0.6, 0.45, -1).Unit * extent * 1.45, Vector3.zero)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
	return viewport
end

type PetCard = {
	frame: Frame,
	viewport: ViewportFrame?,
	owned: boolean,
	count: TextLabel,
	badge: TextLabel,
	name: TextLabel,
}

local petCards: { [string]: PetCard } = {}

local function equippedList(): { string }
	local list = {}
	local equipped = player:GetAttribute("Equipped")
	if type(equipped) == "string" then
		for petId in string.gmatch(equipped, "[^,]+") do
			table.insert(list, petId)
		end
	end
	return list
end

for order, entry in ipairs(PetCatalog.List) do
	local rarityIndex = Config.RarityIndex[entry.Rarity]
	local rarity = Config.Rarities[rarityIndex]

	local button = Instance.new("TextButton")
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = WHITE
	button.LayoutOrder = rarityIndex * 100 + order
	corner(button, 14)
	stroke(button, 3, BLACK, true)
	gradient(button, rarity.Color:Lerp(WHITE, 0.45), rarity.Color)
	button.Parent = petsGrid
	bounce(button)

	local name = text(button, "???", 15)
	name.Position = UDim2.new(0, 4, 1, -44)
	name.Size = UDim2.new(1, -8, 0, 22)
	name.TextScaled = true

	local rarityLabel = text(button, rarity.Name:upper(), 14, rarity.Color:Lerp(WHITE, 0.3))
	rarityLabel.Position = UDim2.new(0, 4, 1, -22)
	rarityLabel.Size = UDim2.new(1, -8, 0, 18)

	local count = text(button, "", 20)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -6, 0, 2)
	count.Size = UDim2.fromOffset(60, 24)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.ZIndex = 2

	local badge = text(button, "ÉQUIPÉ", 16, Color3.fromRGB(120, 255, 90))
	badge.Position = UDim2.fromOffset(6, 4)
	badge.Size = UDim2.fromOffset(70, 20)
	badge.TextXAlignment = Enum.TextXAlignment.Left
	badge.ZIndex = 2
	badge.Visible = false

	local card: PetCard = { frame = button :: any, viewport = nil, owned = false, count = count, badge = badge, name = name }
	petCards[entry.Id] = card

	button.Activated:Connect(function()
		if not card.owned then
			Toast.show("PAS ENCORE OBTENU !", Color3.fromRGB(255, 90, 90))
			return
		end
		local list = equippedList()
		local equippedCount = 0
		for _, id in ipairs(list) do
			if id == entry.Id then
				equippedCount += 1
			end
		end
		local owned = numberAttribute("Pet_" .. entry.Id)
		local slots = numberAttribute("EquipSlots")
		if equippedCount < owned and #list < slots then
			Remotes.EquipPet:FireServer(entry.Id, true)
		elseif equippedCount > 0 then
			Remotes.EquipPet:FireServer(entry.Id, false)
		else
			Toast.show("PLUS DE PLACE ! DÉSÉQUIPE UN FAMILIER", Color3.fromRGB(255, 90, 90))
		end
	end)
end

local function updatePets()
	local list = equippedList()
	local collected = 0
	for _, entry in ipairs(PetCatalog.List) do
		local card = petCards[entry.Id]
		local owned = numberAttribute("Pet_" .. entry.Id)
		if owned > 0 then
			collected += 1
		end
		local nowOwned = owned > 0
		if nowOwned ~= card.owned or card.viewport == nil then
			card.owned = nowOwned
			if card.viewport then
				card.viewport:Destroy()
			end
			local viewport = petViewport(card.frame, entry.Id, not nowOwned)
			viewport.Position = UDim2.fromOffset(6, 22)
			viewport.Size = UDim2.new(1, -12, 1, -68)
			card.viewport = viewport
		end
		card.name.Text = if nowOwned then entry.Name else "???"
		card.count.Text = if nowOwned then "x" .. owned else ""
		card.badge.Visible = table.find(list, entry.Id) ~= nil
	end
	local multiplier = player:GetAttribute("Multiplier")
	petsHeader.Text = string.format(
		"ÉQUIPÉS %d/%d   •   POINTS x%.2f   •   COLLECTION %d/%d",
		#list,
		numberAttribute("EquipSlots"),
		if type(multiplier) == "number" then multiplier else 1,
		collected,
		#PetCatalog.List
	)
end

shopButton.Activated:Connect(shopWindow.toggle)
petsButton.Activated:Connect(petsWindow.toggle)

----------------------------------------------------------------------
-- Fenêtre Fusion
----------------------------------------------------------------------

local fusionWindow = makeWindow("FUSION", Vector2.new(640, 520), Color3.fromRGB(235, 150, 255), Color3.fromRGB(120, 40, 210))

local fusionInfo = text(fusionWindow.content, string.format("%d FAMILIERS DE MÊME RARETÉ = 1 DE LA RARETÉ AU-DESSUS", Config.Fusion.Count), 18)
fusionInfo.Size = UDim2.new(1, 0, 0, 24)
fusionInfo.Position = UDim2.fromOffset(0, 6)

local fusionList = makeList(fusionWindow.content, 8)
fusionList.Position = UDim2.fromOffset(0, 34)
fusionList.Size = UDim2.new(1, -170, 1, -34)

-- Aperçu du dernier familier obtenu par fusion.
local resultCard = makeCard(fusionWindow.content, 0, 0)
resultCard.Size = UDim2.fromOffset(156, 210)
resultCard.AnchorPoint = Vector2.new(1, 0)
resultCard.Position = UDim2.new(1, 0, 0, 40)
local resultTitle = text(resultCard, "RÉSULTAT", 18, Color3.fromRGB(255, 220, 60))
resultTitle.Size = UDim2.new(1, 0, 0, 24)
resultTitle.Position = UDim2.fromOffset(0, 4)
local resultName = text(resultCard, "?", 16)
resultName.Size = UDim2.new(1, -8, 0, 40)
resultName.Position = UDim2.new(0, 4, 1, -44)
resultName.TextWrapped = true
local resultViewport: ViewportFrame? = nil

type FusionRow = { rarityIndex: number, count: TextLabel, button: TextButton }
local fusionRows: { FusionRow } = {}

for rarityIndex = 1, Config.Fusion.MaxFromRarity do
	local from = Config.Rarities[rarityIndex]
	local to = Config.Rarities[rarityIndex + 1]
	local cardFrame = makeCard(fusionList, 64, rarityIndex)
	cardFrame.BackgroundColor3 = WHITE
	gradient(cardFrame, from.Color:Lerp(WHITE, 0.4), to.Color:Lerp(WHITE, 0.2))

	local title = text(cardFrame, string.format("%s → %s", from.Name:upper(), to.Name:upper()), 20)
	title.Position = UDim2.fromOffset(12, 4)
	title.Size = UDim2.new(1, -150, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local count = text(cardFrame, "", 16)
	count.Position = UDim2.fromOffset(12, 34)
	count.Size = UDim2.new(1, -150, 0, 22)
	count.TextXAlignment = Enum.TextXAlignment.Left

	local button = chunkyButton(cardFrame, "", UDim2.fromOffset(130, 48), Color3.fromRGB(120, 240, 90), Color3.fromRGB(40, 170, 40), 20)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -8, 0.5, 0)
	button.Activated:Connect(function()
		Remotes.Fuse:FireServer(rarityIndex)
	end)
	table.insert(fusionRows, { rarityIndex = rarityIndex, count = count, button = button })
end

-- Exemplaires non équipés d'une rareté (calcul identique au serveur).
local function spareOfRarity(rarityId: string): number
	local equipped = equippedList()
	local total = 0
	for _, entry in ipairs(PetCatalog.ByRarity[rarityId] or {}) do
		local owned = numberAttribute("Pet_" .. entry.Id)
		local used = 0
		for _, id in ipairs(equipped) do
			if id == entry.Id then
				used += 1
			end
		end
		total += math.max(0, owned - used)
	end
	return total
end

local function updateFusion(money: number)
	for _, row in ipairs(fusionRows) do
		local rarity = Config.Rarities[row.rarityIndex]
		local spare = spareOfRarity(rarity.Id)
		local cost = Config.Fusion.Costs[row.rarityIndex]
		row.count.Text = string.format("TU EN AS %d / %d (HORS ÉQUIPÉS)", spare, Config.Fusion.Count)
		local caption = row.button:FindFirstChild("Caption") :: TextLabel
		local buttonGradient = row.button:FindFirstChildOfClass("UIGradient") :: UIGradient
		caption.Text = formatMoney(cost)
		if spare >= Config.Fusion.Count and money >= cost then
			buttonGradient.Color = ColorSequence.new(Color3.fromRGB(120, 240, 90), Color3.fromRGB(40, 170, 40))
		else
			buttonGradient.Color = ColorSequence.new(Color3.fromRGB(255, 110, 110), Color3.fromRGB(190, 40, 40))
		end
		row.button:SetAttribute("Ready", spare >= Config.Fusion.Count)
		row.button:SetAttribute("Affordable", money >= cost)
	end
end

for _, row in ipairs(fusionRows) do
	row.button.Activated:Connect(function()
		if not row.button:GetAttribute("Ready") then
			Toast.show(string.format("IL TE FAUT %d FAMILIERS LIBRES DE CETTE RARETÉ !", Config.Fusion.Count), Color3.fromRGB(255, 90, 90))
		elseif not row.button:GetAttribute("Affordable") then
			Toast.show("PAS ASSEZ D'ARGENT !", Color3.fromRGB(255, 90, 90))
		end
	end)
end

Remotes.FusionResult.OnClientEvent:Connect(function(petId: string)
	local entry = PetCatalog.ById[petId]
	if not entry then
		return
	end
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
	if resultViewport then
		resultViewport:Destroy()
	end
	local viewport = petViewport(resultCard, petId, false)
	viewport.Position = UDim2.fromOffset(6, 30)
	viewport.Size = UDim2.new(1, -12, 1, -78)
	resultViewport = viewport
	resultName.Text = entry.Name:upper()
	resultName.TextColor3 = rarity.Color
	local scale = resultCard:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = resultCard
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Toast.show(string.format("FUSION : %s (%s) !", entry.Name:upper(), rarity.Name:upper()), rarity.Color)
end)

----------------------------------------------------------------------
-- Popup de récompenses (fin de manche)
----------------------------------------------------------------------

local rewardWindow = makeWindow("DIGESTION !", Vector2.new(460, 380), Color3.fromRGB(200, 130, 255), Color3.fromRGB(110, 40, 200))
local rewardHeadline = text(rewardWindow.content, "", 28)
rewardHeadline.Size = UDim2.new(1, 0, 0, 36)
rewardHeadline.Position = UDim2.fromOffset(0, 8)
local rewardBody = text(rewardWindow.content, "", 24)
rewardBody.Size = UDim2.new(1, 0, 1, -56)
rewardBody.Position = UDim2.fromOffset(0, 50)
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
		local level = numberAttribute("Upgrade_" .. item.Id)
		local price = Config.GetUpgradePrice(item, level)
		shopLevels[item.Id].Text = if item.MaxLevel > 1 then string.format("NIVEAU %d/%d", level, item.MaxLevel) else ""
		if not price then
			caption.Text = if item.MaxLevel > 1 then "MAX" else "ACQUIS"
			buyGradient.Color = ColorSequence.new(Color3.fromRGB(190, 190, 190), Color3.fromRGB(120, 120, 120))
		elseif money >= price then
			caption.Text = formatMoney(price)
			buyGradient.Color = ColorSequence.new(Color3.fromRGB(120, 240, 90), Color3.fromRGB(40, 170, 40))
		else
			caption.Text = formatMoney(price)
			buyGradient.Color = ColorSequence.new(Color3.fromRGB(255, 110, 110), Color3.fromRGB(190, 40, 40))
		end
	end
end

local function updateStats()
	local money = numberAttribute("Money")
	moneyLabel.Text = formatMoney(money)
	local income = numberAttribute("Income")
	incomeLabel.Text = NumberFormat.perSecond(income)
	for _, row in ipairs({ { stat = "Speed", ui = speedRow, title = "⚡ VITESSE" }, { stat = "Strength", ui = strengthRow, title = "💪 FORCE" } }) do
		local level = numberAttribute(row.stat .. "Level")
		local needed = numberAttribute(row.stat .. "XPNeeded")
		row.ui.label.Text = string.format("%s  NV %d", row.title, level)
		row.ui.fill.Size = UDim2.fromScale(if needed > 0 then math.clamp(numberAttribute(row.stat .. "XP") / needed, 0, 1) else 1, 1)
	end
	pointsLabel.Text = string.format("POINTS : %.1f", numberAttribute("RoundScore"))
	updateShop(money)

	updatePets()
	updateFusion(money)
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
		rewardHeadline.Text = string.format("%.1f POINTS  •  %d TIRAGE%s", score, pulls, if pulls > 1 then "S" else "")
		-- Familiers gagnés, du plus rare au plus commun (6 lignes max).
		local drops = {}
		for petId, count in pairs(results) do
			local entry = PetCatalog.ById[petId]
			if entry then
				table.insert(drops, { entry = entry, count = count, rank = Config.RarityIndex[entry.Rarity] })
			end
		end
		table.sort(drops, function(a, b)
			return a.rank > b.rank
		end)
		local lines = {}
		for index, drop in ipairs(drops) do
			if index > 6 then
				table.insert(lines, string.format("+ %d AUTRES...", #drops - 6))
				break
			end
			local rarity = Config.Rarities[drop.rank]
			table.insert(lines, string.format('<font color="#%s">+%d %s</font>', rarity.Color:ToHex(), drop.count, drop.entry.Name:upper()))
		end
		if money and money > 0 then
			table.insert(lines, string.format('<font color="#%s">+%s</font>', MONEY:ToHex(), formatMoney(money)))
		end
		rewardBody.Text = table.concat(lines, "\n")
	end

	rewardWindow.open()
	task.delay(7, function()
		if token == rewardToken then
			rewardWindow.close()
		end
	end)
end

-- Gros drop d'un joueur du serveur.
Remotes.Announcement.OnClientEvent:Connect(function(playerName: string, petId: string)
	local entry = PetCatalog.ById[petId]
	if not entry then
		return
	end
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
	Toast.show(string.format("%s A OBTENU %s (%s) !", playerName:upper(), entry.Name:upper(), rarity.Name:upper()), rarity.Color)
end)

-- Bâtiments de la map (boutique, machine de fusion) : leur prompt "[E]" ouvre la fenêtre correspondante,
-- qui se ferme toute seule quand le joueur s'éloigne.
local promptWindows: { [string]: Window } = {
	Shop = shopWindow,
	Fusion = fusionWindow,
}
local openedFrom: BasePart? = nil
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	local windowName = prompt:GetAttribute("OpensWindow")
	local window = if type(windowName) == "string" then promptWindows[windowName] else nil
	if window and prompt.Parent and prompt.Parent:IsA("BasePart") then
		window.open()
		openedFrom = prompt.Parent
	end
end)
task.spawn(function()
	while true do
		task.wait(0.5)
		local source = openedFrom
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if source and root and root:IsA("BasePart") and (root.Position - source.Position).Magnitude > 22 then
			openedFrom = nil
			for _, window in pairs(promptWindows) do
				window.close()
			end
		end
	end
end)

ReplicatedStorage:GetAttributeChangedSignal("GameState"):Connect(updatePhase)
ReplicatedStorage:GetAttributeChangedSignal("TimeRemaining"):Connect(updatePhase)
player.AttributeChanged:Connect(updateStats)

-- Confirmation d'achat : le serveur écrit "Upgrade_<Id>" (niveau) quand l'achat est validé.
local STATION_HINTS: { [string]: string } = {
	Treadmill = " : À GAUCHE DE TA BASE !",
	Bench = " : À DROITE DE TA BASE !",
}
for _, item in ipairs(Config.Shop) do
	player:GetAttributeChangedSignal("Upgrade_" .. item.Id):Connect(function()
		local level = numberAttribute("Upgrade_" .. item.Id)
		if level <= 0 then
			return
		end
		local message = if item.MaxLevel > 1 then string.format("%s NIVEAU %d !", item.Name:upper(), level) else item.Name:upper() .. " DÉBLOQUÉ !"
		if level == 1 and STATION_HINTS[item.Id] then
			message = item.Name:upper() .. STATION_HINTS[item.Id]
		end
		Toast.show(message, Color3.fromRGB(110, 240, 70))
	end)
end

-- Passage de niveau d'entraînement.
for _, stat in ipairs({ { id = "Speed", name = "VITESSE" }, { id = "Strength", name = "FORCE" } }) do
	local last = numberAttribute(stat.id .. "Level")
	player:GetAttributeChangedSignal(stat.id .. "Level"):Connect(function()
		local level = numberAttribute(stat.id .. "Level")
		if level > last then
			Toast.show(string.format("%s NIVEAU %d !", stat.name, level), Color3.fromRGB(255, 220, 60))
		end
		last = level
	end)
end

-- Achat refusé faute d'argent : retour immédiat côté client.
for _, item in ipairs(Config.Shop) do
	buyButtons[item.Id].Activated:Connect(function()
		local price = Config.GetUpgradePrice(item, numberAttribute("Upgrade_" .. item.Id))
		if price and numberAttribute("Money") < price then
			Toast.show("PAS ASSEZ D'ARGENT !", Color3.fromRGB(255, 90, 90))
		end
	end)
end
Remotes.RewardsGranted.OnClientEvent:Connect(showRewards)

updatePhase()
updateStats()
