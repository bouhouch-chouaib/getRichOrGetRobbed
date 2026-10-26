--!strict
-- ShopKit : briques de la Boutique en une page (client/ShopMenu, client/RobuxShop), d'après
-- dataset_and_pipeline/UI_UX_GUIDELINES.md : tailles au doigt, section (bandeau + grille de cartes), carte (support
-- fixe dans la grille + corps qu'on peut secouer / faire sauter), icône sur rayons, ruban, jauge de niveau, gros bouton
-- de prix, encart « ? » de description, rangée de pastilles de navigation, textes qui ne débordent pas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icons = require(ReplicatedStorage.Shared.Icons)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local ScreenScale = require(script.Parent.ScreenScale)
local UIJuice = require(script.Parent.UIJuiceController)
local UiStyle = require(script.Parent.UiStyle)

local ShopKit = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CHIP = Color3.fromRGB(28, 28, 42)

-- Au doigt (UI_UX_GUIDELINES.md §3) : fenêtre un peu plus petite (donc moins réduite sur un téléphone), textes x1,3,
-- deux colonnes, boutons de 76 px virtuels (≈ 44 pt sur un téléphone de 390 pt de haut).
local TOUCH = ScreenScale.isTouch()
ShopKit.TOUCH = TOUCH
ShopKit.K = if TOUCH then 1.3 else 1
ShopKit.WINDOW = if TOUCH then Vector2.new(860, 540) else Vector2.new(920, 580)
ShopKit.COLUMNS = if TOUCH then 2 else 3
ShopKit.GAP = 14
ShopKit.PILL_HEIGHT = if TOUCH then 72 else 60
ShopKit.BUTTON_HEIGHT = if TOUCH then 76 else 56
ShopKit.ICON = if TOUCH then 96 else 92
ShopKit.CARD_HEIGHT = if TOUCH then 352 else 340
ShopKit.WIDE_HEIGHT = if TOUCH then 270 else 206 -- cartes « À la une »
ShopKit.WIDE_ICON = math.floor(ShopKit.WIDE_HEIGHT * (if TOUCH then 0.46 else 0.62)) -- au doigt : plus de place au texte
ShopKit.SHORT_TEXT = not TOUCH -- au doigt, la phrase courte passe dans l'encart « ? » (pas la place)
local K = ShopKit.K
-- Taille minimale en VRAIS pixels de l'écran (UITextSizeConstraint compte après la mise à l'échelle, vu dans Studio) :
-- le plancher de lisibilité, pas plus (au-dessus, un texte trop long déborderait sur un petit écran).
local MIN_TEXT = if TOUCH then 12 else 11

-- Texte cartoon qui ne déborde jamais : il rétrécit jusqu'à MIN_TEXT pour tenir dans sa case.
function ShopKit.label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local maximum = math.floor(size * K)
	local label = UiStyle.text(parent, text, maximum, color or WHITE)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maximum
	limit.MinTextSize = math.min(maximum, MIN_TEXT)
	limit.Parent = label
	return label
end

----------------------------------------------------------------------
-- Sections
----------------------------------------------------------------------

export type Section = {
	frame: Frame,
	grid: Frame,
	color: Color3,
	icon: string,
	pill: string, -- mot court de la pastille de navigation
}

-- Section de la page : bandeau (couleur, tenons, icône qui déborde, titre, sous-titre) puis une grille de `columns`
-- colonnes de cartes de hauteur `cellHeight` (sans colonnes : une liste verticale).
function ShopKit.section(scroll: ScrollingFrame, order: number, title: string, subtitle: string, icon: string,
	color: Color3, pill: string, columns: number?, cellHeight: number?): Section
	local frame = Instance.new("Frame")
	frame.Name = "Section" .. order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = scroll
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local bandHeight = math.floor(52 * K)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.LayoutOrder = 1
	band.BackgroundColor3 = WHITE
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0, bandHeight)
	UiStyle.corner(band, 10)
	UiStyle.stroke(band, 3, BLACK, true)
	UiStyle.gradient(band, UiStyle.lighter(color, 0.25), UiStyle.darker(color, 0.25))
	band.Parent = frame
	local deco = Instance.new("Frame")
	deco.BackgroundTransparency = 1
	deco.Size = UDim2.fromScale(1, 1)
	deco.ClipsDescendants = true
	deco.Parent = band
	UiStyle.studs(deco, WHITE, 20, 0.85)
	local image = Icons.image(band, icon, UDim2.fromOffset(bandHeight * 1.2, bandHeight * 1.2))
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.new(0, bandHeight * 0.65, 0.5, -3)
	image.Rotation = -8
	image.ZIndex = 3
	local titleLabel = ShopKit.label(band, title, 30)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Position = UDim2.fromOffset(bandHeight * 1.35, 4)
	titleLabel.Size = UDim2.new(0.5, -bandHeight, 1, -8)
	titleLabel.ZIndex = 3
	local subtitleLabel = ShopKit.label(band, subtitle, 18)
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Right
	subtitleLabel.AnchorPoint = Vector2.new(1, 0.5)
	subtitleLabel.Position = UDim2.new(1, -14, 0.5, 0)
	subtitleLabel.Size = UDim2.new(0.5, -14, 0, math.floor(26 * K))
	subtitleLabel.ZIndex = 3
	subtitleLabel.Visible = not TOUCH -- au doigt, le bandeau est trop court : il chevaucherait le titre

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.LayoutOrder = 2
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = frame
	if columns then
		local layout = Instance.new("UIGridLayout")
		layout.CellPadding = UDim2.fromOffset(ShopKit.GAP, ShopKit.GAP)
		layout.CellSize = UDim2.new(1 / columns, -math.ceil(ShopKit.GAP * (columns - 1) / columns), 0, cellHeight or ShopKit.CARD_HEIGHT)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
	else
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, ShopKit.GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
	end
	return { frame = frame, grid = grid, color = color, icon = icon, pill = pill }
end

----------------------------------------------------------------------
-- Cartes
----------------------------------------------------------------------

export type Card = { holder: Frame, body: Frame }

-- Carte vive dans une grille : `holder` est placé par la grille, `body` (la carte visible) peut bouger dedans.
function ShopKit.card(grid: Instance, color: Color3, order: number): Card
	local holder = Instance.new("Frame")
	holder.Name = "Card" .. order
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = grid
	local body = UiStyle.brightCard(holder, UDim2.fromScale(1, 1), color)
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	return { holder = holder, body = body }
end

-- Grosse icône sur des rayons qui tournent (couleur `glow`), centrée sur `position`.
function ShopKit.icon(parent: Instance, name: string, side: number, position: UDim2, glow: Color3): ImageLabel
	local holder = Instance.new("Frame")
	holder.Name = "IconHolder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(side, side)
	holder.ZIndex = 2
	holder.Parent = parent
	UiStyle.rays(holder, glow, side * 1.3, 25)
	local image = Icons.image(holder, name, UDim2.fromScale(1, 1))
	image.ZIndex = 4
	image.Rotation = -6
	UiStyle.sway(image, 4)
	return image
end

-- Ruban penché qui chevauche le coin haut gauche d'une carte (« CONSEILLÉ », « EXCLUSIF »...).
function ShopKit.ribbon(parent: Instance, text: string, color: Color3): (Frame, TextLabel)
	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.BackgroundColor3 = WHITE
	ribbon.BorderSizePixel = 0
	ribbon.AnchorPoint = Vector2.new(0, 0.5)
	ribbon.Position = UDim2.fromOffset(-10, 4)
	ribbon.Size = UDim2.fromOffset(math.floor(150 * K), math.floor(30 * K))
	ribbon.Rotation = -5
	ribbon.ZIndex = 9
	UiStyle.corner(ribbon, 8)
	UiStyle.stroke(ribbon, 3, BLACK, true)
	UiStyle.gradient(ribbon, UiStyle.lighter(color, 0.3), UiStyle.darker(color, 0.15))
	ribbon.Parent = parent
	local caption = ShopKit.label(ribbon, text, 18)
	caption.Position = UDim2.fromOffset(6, 2)
	caption.Size = UDim2.new(1, -12, 1, -4)
	caption.ZIndex = 10
	return ribbon, caption
end

-- Encart sombre à coins arrondis (effet de l'amélioration, prix au mètre...) avec un texte centré.
function ShopKit.chip(parent: Instance, textSize: number): (Frame, TextLabel)
	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.BackgroundColor3 = CHIP
	chip.BackgroundTransparency = 0.15
	chip.BorderSizePixel = 0
	chip.ZIndex = 3
	UiStyle.corner(chip, 8)
	UiStyle.stroke(chip, 3, BLACK, true)
	chip.Parent = parent
	local text = ShopKit.label(chip, "", textSize)
	text.Position = UDim2.fromOffset(8, 3)
	text.Size = UDim2.new(1, -16, 1, -6)
	text.ZIndex = 4
	return chip, text
end

export type Gauge = { frame: Frame, fill: Frame, text: TextLabel }

-- Jauge de niveau : barre sombre, remplissage de la couleur, texte « NIV 3 / 25 » par-dessus.
function ShopKit.gauge(parent: Instance, color: Color3): Gauge
	local frame = Instance.new("Frame")
	frame.Name = "Gauge"
	frame.BackgroundColor3 = CHIP
	frame.BorderSizePixel = 0
	frame.ZIndex = 3
	UiStyle.corner(frame, 8)
	UiStyle.stroke(frame, 3, BLACK, true)
	frame.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = WHITE
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 4
	UiStyle.corner(fill, 8)
	UiStyle.gradient(fill, UiStyle.lighter(color, 0.45), color)
	fill.Parent = frame
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.7
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(4, 2)
	shine.Size = UDim2.new(1, -8, 0.35, 0)
	shine.ZIndex = 5
	UiStyle.corner(shine, 4)
	shine.Parent = fill
	local text = ShopKit.label(frame, "", 18)
	text.Position = UDim2.fromOffset(6, 2)
	text.Size = UDim2.new(1, -12, 1, -4)
	text.ZIndex = 6
	return { frame = frame, fill = fill, text = text }
end

function ShopKit.setGauge(gauge: Gauge, ratio: number, text: string, animate: boolean?)
	gauge.text.Text = text
	local target = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	gauge.fill.Visible = ratio > 0
	if animate then
		TweenService:Create(gauge.fill, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = target }):Play()
	else
		gauge.fill.Size = target
	end
end

-- Énorme bouton de prix en bas de la carte, icône à gauche (pièce, couronne...). Effets : client/UIJuiceController.
function ShopKit.buyButton(parent: Instance, color: Color3, icon: string?): TextButton
	local height = ShopKit.BUTTON_HEIGHT
	local button = UiStyle.button(parent, "", UDim2.new(1, -24, 0, height), color, math.floor(30 * K), true)
	button.Name = "Buy"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -12)
	button.ZIndex = 5
	UIJuice.button(button)
	local caption = button:FindFirstChild("Caption") :: TextLabel
	caption.FontFace = UiStyle.NUMBER_FONT
	if icon then
		local side = math.floor(height * 0.72)
		local image = Icons.image(button, icon, UDim2.fromOffset(side, side))
		image.Name = "PriceIcon"
		image.AnchorPoint = Vector2.new(0, 0.5)
		image.Position = UDim2.new(0, 8, 0.5, -2)
		image.ZIndex = 3
		caption.Position = UDim2.fromOffset(side + 12, 6)
		caption.Size = UDim2.new(1, -(side + 22), 1, -12)
	end
	return button
end

function ShopKit.setButton(button: TextButton, text: string, color: Color3)
	local caption = button:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		caption.Text = text
	end
	UiStyle.setButtonColor(button, color)
end

-- Bouton « ? » en haut à droite d'une carte : montre / cache la description complète par-dessus la carte (au-dessus
-- du bouton de prix, qui reste touchable). getText() est relu à chaque ouverture.
function ShopKit.info(body: Frame, getText: () -> string): Frame
	local side = math.floor(40 * K)
	local button = UiStyle.button(body, "?", UDim2.fromOffset(side, side), Color3.fromRGB(95, 95, 130), math.floor(26 * K), true)
	button.Name = "InfoButton"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -8, 0, 8)
	button.ZIndex = 9
	UIJuice.button(button)
	local overlay = Instance.new("Frame")
	overlay.Name = "Info"
	overlay.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
	overlay.BackgroundTransparency = 0.06
	overlay.BorderSizePixel = 0
	overlay.Position = UDim2.fromOffset(8, 8)
	overlay.Size = UDim2.new(1, -16, 1, -(ShopKit.BUTTON_HEIGHT + 30))
	overlay.ZIndex = 8
	overlay.Visible = false
	UiStyle.corner(overlay, 8)
	overlay.Parent = body
	local text = ShopKit.label(overlay, "", 18)
	text.TextWrapped = true
	text.Position = UDim2.fromOffset(10, side + 4)
	text.Size = UDim2.new(1, -20, 1, -(side + 12))
	text.ZIndex = 9
	button.Activated:Connect(function()
		overlay.Visible = not overlay.Visible
		if overlay.Visible then
			text.Text = getText()
		end
		UIJuice.pop(body, 0.04)
	end)
	return overlay
end

----------------------------------------------------------------------
-- Argent dans l'en-tête
----------------------------------------------------------------------

export type MoneyChip = {
	frame: Frame,
	update: (open: boolean) -> (), -- à appeler quand l'argent a pu changer
	reset: () -> (), -- à l'ouverture : affiche le montant exact, sans défilement
}

local function formatMoney(value: number): string
	return NumberFormat.money(math.floor(value + 0.5))
end

-- Argent du joueur dans l'en-tête d'une fenêtre, à gauche de la croix. Fenêtre ouverte, il défile jusqu'au nouveau
-- montant (UIJuiceController.countTo) et saute un peu quand il baisse (achat, voyage).
function ShopKit.moneyChip(header: Frame, getMoney: () -> number): MoneyChip
	local chip = Instance.new("Frame")
	chip.Name = "Money"
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -66, 0.5, 0)
	chip.Size = UDim2.fromOffset(math.floor(230 * K), 44)
	chip.BackgroundColor3 = CHIP
	chip.BackgroundTransparency = 0.15
	chip.BorderSizePixel = 0
	chip.ZIndex = 4
	UiStyle.corner(chip, 10)
	UiStyle.stroke(chip, 3, BLACK, true)
	chip.Parent = header
	local icon = Icons.image(chip, "Money", UDim2.fromOffset(52, 52))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0, 14, 0.5, 0)
	icon.Rotation = -10
	icon.ZIndex = 6
	local shown = getMoney()
	local label = UiStyle.number(chip, formatMoney(shown), 30, UiStyle.Colors.Money)
	label.Position = UDim2.fromOffset(44, 4)
	label.Size = UDim2.new(1, -54, 1, -8)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	label.ZIndex = 5
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 30
	limit.Parent = label
	return {
		frame = chip,
		update = function(open: boolean)
			local money = getMoney()
			if money == shown then
				return
			end
			if open then
				UIJuice.countTo(label, shown, money, formatMoney, 0.5)
				if money < shown then
					UIJuice.pop(chip, 0.08)
				end
			else
				label.Text = formatMoney(money)
			end
			shown = money
		end,
		reset = function()
			shown = getMoney()
			label.Text = formatMoney(shown)
		end,
	}
end

----------------------------------------------------------------------
-- Pastilles de navigation
----------------------------------------------------------------------

export type Pills = {
	frame: Frame,
	setActive: (index: number) -> (),
	setBadge: (index: number, value: string?) -> (),
	setVisible: (index: number, visible: boolean) -> (),
}

-- Une pastille par section (icône d'abord ; son mot à côté sur PC, l'icône seule au doigt). onClick(index).
function ShopKit.pills(parent: Instance, sections: { Section }, onClick: (index: number) -> ()): Pills
	local bar = Instance.new("Frame")
	bar.Name = "Pills"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, ShopKit.PILL_HEIGHT)
	bar.ZIndex = 3
	bar.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = bar

	local count = #sections
	local buttons: { TextButton } = {}
	local badges: { TextLabel } = {}
	-- Largeur selon le mot : « CHANCES » a plus de place que « TOP ».
	local weights: { number } = {}
	local total = 0
	for index, section in ipairs(sections) do
		weights[index] = if TOUCH then 1 else 3 + (utf8.len(section.pill) or #section.pill)
		total += weights[index]
	end
	for index, section in ipairs(sections) do
		local pill = UiStyle.button(bar, if TOUCH then "" else section.pill,
			UDim2.new(weights[index] / total, -math.ceil(8 * (count - 1) / count), 1, -6), section.color, math.floor(20 * K), true)
		pill.Name = "Pill" .. index
		pill.LayoutOrder = index
		pill.ZIndex = 3
		UIJuice.button(pill)
		-- Icône en haut, mot en dessous sur toute la largeur (au doigt : l'icône seule, plus grande).
		local side = math.floor(ShopKit.PILL_HEIGHT * (if TOUCH then 0.78 else 0.56))
		local image = Icons.image(pill, section.icon, UDim2.fromOffset(side, side))
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = if TOUCH then UDim2.fromScale(0.5, 0.5) else UDim2.new(0.5, 0, 0, side / 2 + 2)
		image.ZIndex = 4
		local caption = pill:FindFirstChild("Caption") :: TextLabel
		caption.AnchorPoint = Vector2.new(0, 1)
		caption.Position = UDim2.new(0, 4, 1, -3)
		caption.Size = UDim2.new(1, -8, 0, ShopKit.PILL_HEIGHT - side - 6)
		caption.TextScaled = true -- (UiStyle.text ne pose alors pas sa limite de 12 px : le mot peut rétrécir un peu plus)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 18
		limit.MinTextSize = 9
		limit.Parent = caption
		local badge = UiStyle.badge(pill)
		badge.Size = UDim2.fromOffset(24, 24)
		badge.Position = UDim2.new(1, -8, 0, 3)
		buttons[index] = pill
		badges[index] = badge
		pill.Activated:Connect(function()
			onClick(index)
		end)
	end

	local function setActive(active: number)
		for index, pill in ipairs(buttons) do
			local on = index == active
			local color = sections[index].color
			UiStyle.setButtonColor(pill, if on then color else color:Lerp(Color3.fromRGB(60, 60, 80), 0.5))
			local border = pill:FindFirstChildOfClass("UIStroke")
			if border then
				border.Color = if on then WHITE else BLACK
				border.Thickness = if on then 4 else 3
			end
		end
	end
	setActive(1)

	return {
		frame = bar,
		setActive = setActive,
		setBadge = function(index: number, value: string?)
			if badges[index] then
				UiStyle.setBadge(badges[index], value)
			end
		end,
		setVisible = function(index: number, visible: boolean)
			if buttons[index] then
				buttons[index].Visible = visible
			end
		end,
	}
end

return ShopKit
