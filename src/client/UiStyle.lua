--!strict
-- UiStyle : briques d'interface communes, style « Steal an Egg » (docs/DIRECTION_ARTISTIQUE.md §3) :
--   - fenêtres au fond sombre couvert de tenons, en-tête coloré (couleur = fonction) avec deux rayures claires,
--     croix rouge carrée, gros contour noir ;
--   - boutons en dégradé, coins peu arrondis, contour noir épais, texte blanc à contour noir ;
--   - chiffres (argent, vitesse) en italique très gras.
-- Utilisé par client/HUD et client/RobuxShop.

local TweenService = game:GetService("TweenService")

local UiStyle = {}

UiStyle.TITLE_FONT = Enum.Font.LuckiestGuy
UiStyle.BODY_FONT = Enum.Font.FredokaOne
-- Montserrat Black Italic : les gros chiffres du HUD.
UiStyle.NUMBER_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

-- Palette relevée sur les captures de référence.
UiStyle.Colors = {
	WindowBody = Color3.fromRGB(47, 46, 62),
	WindowStud = Color3.fromRGB(60, 59, 78),
	Panel = Color3.fromRGB(34, 33, 46),
	PanelText = Color3.fromRGB(220, 220, 235),
	Green = Color3.fromRGB(110, 235, 40),
	Purple = Color3.fromRGB(168, 40, 252),
	Cyan = Color3.fromRGB(54, 204, 254),
	Orange = Color3.fromRGB(255, 160, 40),
	Gold = Color3.fromRGB(255, 205, 50),
	Red = Color3.fromRGB(232, 30, 36),
	Money = Color3.fromRGB(110, 240, 70),
	Speed = Color3.fromRGB(60, 190, 255),
	Strength = Color3.fromRGB(255, 150, 60),
}

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(WHITE, amount)
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(BLACK, amount)
end

UiStyle.lighter = lighter
UiStyle.darker = darker

function UiStyle.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function UiStyle.stroke(parent: Instance, thickness: number, color: Color3?, border: boolean?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or BLACK
	s.ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

function UiStyle.gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- Dégradé d'un bouton à partir d'une seule couleur (haut plus clair, bas plus sombre).
function UiStyle.buttonColors(color: Color3): ColorSequence
	return ColorSequence.new(lighter(color, 0.25), darker(color, 0.2))
end

-- Texte cartoon : police épaisse + contour noir.
function UiStyle.text(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextSize = size
	label.Font = font or UiStyle.TITLE_FONT
	label.TextColor3 = color or WHITE
	UiStyle.stroke(label, math.max(1.5, size / 12))
	label.Parent = parent
	return label
end

-- Gros chiffre italique (argent, vitesse...).
function UiStyle.number(parent: Instance, value: string, size: number, color: Color3): TextLabel
	local label = UiStyle.text(parent, value, size, color)
	label.FontFace = UiStyle.NUMBER_FONT
	return label
end

-- Petit effet "rebond" au survol et au clic.
function UiStyle.bounce(button: GuiButton)
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

-- Tenons en relief sur un fond (grille de petits carrés arrondis). `spacing` en pixels, `transparency` des tenons.
-- La grille est créée pour la taille en pixels du parent (Size.Offset) : à appeler sur des cadres de taille fixe.
function UiStyle.studs(parent: GuiObject, color: Color3, spacing: number, transparency: number?)
	local layer = Instance.new("Frame")
	layer.Name = "Studs"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ClipsDescendants = true
	layer.ZIndex = 0 -- toujours au fond (les enfants d'un cadre sont dessinés par-dessus lui)
	local stud = math.floor(spacing * 0.5)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(stud, stud)
	grid.CellPadding = UDim2.fromOffset(spacing - stud, spacing - stud)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = layer
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, math.floor((spacing - stud) / 2))
	padding.Parent = layer
	local width = math.max(parent.Size.X.Offset, parent.AbsoluteSize.X)
	local height = math.max(parent.Size.Y.Offset, parent.AbsoluteSize.Y)
	if width <= 0 or height <= 0 then
		width, height = 600, 400
	end
	local count = math.ceil(width / spacing) * math.ceil(height / spacing)
	for _ = 1, math.min(count, 700) do
		local dot = Instance.new("Frame")
		dot.BackgroundColor3 = color
		dot.BackgroundTransparency = transparency or 0
		dot.BorderSizePixel = 0
		dot.ZIndex = 0
		UiStyle.corner(dot, math.max(2, stud // 4))
		dot.Parent = layer
	end
	layer.Parent = parent
end

-- Rayons de soleil (fond des cartes de la référence) : fins rayons blancs qui partent du centre.
function UiStyle.sunburst(parent: GuiObject, center: Vector2?)
	local layer = Instance.new("Frame")
	layer.Name = "Sunburst"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ClipsDescendants = true
	layer.ZIndex = 0 -- toujours au fond (les enfants d'un cadre sont dessinés par-dessus lui)
	local origin = center or Vector2.new(0.5, 0.45)
	for index = 0, 11 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(origin.X, origin.Y)
		ray.Size = UDim2.new(0, 26, 2.2, 0)
		ray.Rotation = index * 15
		ray.BackgroundColor3 = WHITE
		ray.BorderSizePixel = 0
		ray.ZIndex = 0
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		ray.Parent = layer
	end
	layer.Parent = parent
end

-- Carte vive (boutique, index) : couleur pleine en dégradé, rayons de soleil, tenons clairs, gros contour noir.
function UiStyle.brightCard(parent: Instance, size: UDim2, color: Color3): Frame
	local card = Instance.new("Frame")
	card.Size = size
	card.BackgroundColor3 = WHITE
	card.BorderSizePixel = 0
	UiStyle.corner(card, 6)
	UiStyle.stroke(card, 4, BLACK, true)
	UiStyle.gradient(card, lighter(color, 0.35), darker(color, 0.05))
	card.Parent = parent
	UiStyle.sunburst(card)
	UiStyle.studs(card, WHITE, 26, 0.86)
	return card
end

-- Bouton épais en dégradé avec contour noir (le texte est l'enfant "Caption").
function UiStyle.button(parent: Instance, label: string, size: UDim2, color: Color3, textSize: number): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = WHITE
	button.AutoButtonColor = false
	button.Text = ""
	UiStyle.corner(button, 6)
	UiStyle.stroke(button, 3, BLACK, true)
	local shade = UiStyle.gradient(button, WHITE, WHITE)
	shade.Color = UiStyle.buttonColors(color)
	button.Parent = parent

	-- Reflet clair sur le haut du bouton.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.78
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 4, 0, 3)
	shine.Size = UDim2.new(1, -8, 0.36, 0)
	UiStyle.corner(shine, 4)
	shine.Parent = button

	local caption = UiStyle.text(button, label, textSize)
	caption.Name = "Caption"
	caption.Size = UDim2.fromScale(1, 1)
	caption.ZIndex = 2

	UiStyle.bounce(button)
	return button
end

-- Change la couleur d'un bouton créé par UiStyle.button.
function UiStyle.setButtonColor(button: GuiObject, color: Color3)
	local shade = button:FindFirstChildOfClass("UIGradient")
	if shade then
		shade.Color = UiStyle.buttonColors(color)
	end
end

-- Pastille rouge de notification (coin haut droit d'un bouton). Texte vide = cachée.
function UiStyle.badge(parent: GuiObject): TextLabel
	local badge = UiStyle.text(parent, "", 20)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.fromOffset(32, 32)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = UiStyle.Colors.Red
	badge.ZIndex = 5
	badge.Visible = false
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = badge
	-- Bordure noire du rond (le contour du texte reste celui créé par UiStyle.text).
	local ring = UiStyle.stroke(badge, 3, BLACK, true)
	ring.Name = "Ring"
	return badge
end

function UiStyle.setBadge(badge: TextLabel, value: string?)
	badge.Visible = value ~= nil and value ~= ""
	badge.Text = value or ""
end

export type Window = {
	frame: Frame,
	header: Frame,
	content: Frame,
	closeButton: TextButton,
	scale: UIScale,
}

local HEADER_HEIGHT = 64

-- Fenêtre façon Steal an Egg. headerColor = couleur de la fonction (vert vente, violet machines, cyan collection...).
function UiStyle.window(parent: Instance, title: string, size: Vector2, headerColor: Color3): Window
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.52)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = UiStyle.Colors.WindowBody
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 5 -- au-dessus du reste du HUD (carte des tirages, points)
	UiStyle.corner(frame, 8)
	UiStyle.stroke(frame, 5, BLACK, true)
	frame.Parent = parent
	UiStyle.studs(frame, UiStyle.Colors.WindowStud, 28)

	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.BackgroundColor3 = WHITE
	header.BorderSizePixel = 0
	header.ZIndex = 2
	UiStyle.corner(header, 8)
	UiStyle.stroke(header, 4, BLACK, true)
	UiStyle.gradient(header, lighter(headerColor, 0.2), darker(headerColor, 0.12))
	header.Parent = frame
	UiStyle.studs(header, WHITE, 26, 0.85)

	-- Deux rayures claires en diagonale (dégradé de transparence à bords francs).
	local stripes = Instance.new("Frame")
	stripes.Name = "Stripes"
	stripes.Size = UDim2.fromScale(1, 1)
	stripes.BackgroundColor3 = WHITE
	stripes.BorderSizePixel = 0
	stripes.ZIndex = 2
	UiStyle.corner(stripes, 8)
	local bands = Instance.new("UIGradient")
	bands.Rotation = -65
	bands.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.54, 1),
		NumberSequenceKeypoint.new(0.541, 0.72),
		NumberSequenceKeypoint.new(0.6, 0.72),
		NumberSequenceKeypoint.new(0.601, 1),
		NumberSequenceKeypoint.new(0.64, 1),
		NumberSequenceKeypoint.new(0.641, 0.78),
		NumberSequenceKeypoint.new(0.67, 0.78),
		NumberSequenceKeypoint.new(0.671, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	bands.Parent = stripes
	stripes.Parent = header

	local titleLabel = UiStyle.text(header, title, 38, WHITE, UiStyle.BODY_FONT)
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(22, 0)
	titleLabel.Size = UDim2.new(1, -110, 1, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 3

	local closeButton = UiStyle.button(header, "X", UDim2.fromOffset(50, 50), UiStyle.Colors.Red, 34)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -8, 0.5, 0)
	closeButton.ZIndex = 3

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(16, HEADER_HEIGHT + 10)
	content.Size = UDim2.new(1, -32, 1, -(HEADER_HEIGHT + 24))
	content.ZIndex = 2
	content.Parent = frame

	return { frame = frame, header = header, content = content, closeButton = closeButton, scale = scale }
end

-- Panneau sombre à contour noir (une ligne de boutique, une case...).
function UiStyle.panel(parent: Instance, size: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Size = size
	panel.BackgroundColor3 = UiStyle.Colors.Panel
	panel.BorderSizePixel = 0
	UiStyle.corner(panel, 6)
	UiStyle.stroke(panel, 3, BLACK, true)
	panel.Parent = parent
	return panel
end

return UiStyle
