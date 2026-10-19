--!strict
-- UiStyle : briques d'interface communes (refaites le 16 oct. 2026 d'après les packs « Studs UI », voir
-- docs/DIRECTION_ARTISTIQUE.md §3) :
--   - fenêtres : ombre douce, corps sombre couvert de tenons en relief (texture Stud), liseré clair intérieur, gros
--     contour noir ; en-tête coloré (couleur = fonction) avec éclats de lumière en diagonale, tenons, bande d'ombre,
--     titre à ombre portée, grosse icône penchée qui déborde en haut à gauche, croix rouge ;
--   - boutons « 3D » : dégradé, reflet en haut, lèvre sombre en bas, contour noir épais, reflet qui balaie au survol,
--     reste dans sa case au survol, s'écrase au clic ;
--   - cartes vives : dégradé, rayons de soleil, tenons clairs ;
--   - pastilles rouges qui pulsent ;
--   - textes Montserrat Black, contours adaptés à la taille et couleurs selon leur fonction.
-- Textures dessinées par tools/icons/make_ui_textures.py (assets/ui), en blanc pour être teintées (ImageColor3).
-- Utilisé par tous les menus (client/MenuKit, HUD, ShopMenu, IndexMenu...).

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Icons = require(ReplicatedStorage.Shared.Icons)
local Sounds = require(script.Parent.Sounds)

local UiStyle = {}

-- Même famille et même graisse que les textes dans le monde.
UiStyle.TITLE_FONT = Typography.Face
UiStyle.BODY_FONT = Typography.Face
UiStyle.NUMBER_FONT = Typography.Face

-- Textures (assets/ui, envoyées sur Roblox le 16 oct. 2026).
UiStyle.Textures = {
	Stud = "rbxassetid://116196745508368",
	Shards = "rbxassetid://98048119394956",
	Rays = "rbxassetid://134050472288904",
	Glow = "rbxassetid://125220558210100",
	Shadow = "rbxassetid://88346763271278",
	Shine = "rbxassetid://119343308848311",
}
local TEX = UiStyle.Textures

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

-- Palette relevée sur les captures de référence.
UiStyle.Colors = {
	WindowBody = Color3.fromRGB(44, 44, 62),
	WindowStud = Color3.fromRGB(96, 96, 128),
	Panel = Color3.fromRGB(31, 31, 45),
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
	s.LineJoinMode = Enum.LineJoinMode.Round
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

-- Dégradé d'un bouton à partir d'une seule couleur : haut clair, milieu franc, bas plus sombre (volume).
function UiStyle.buttonColors(color: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, lighter(color, 0.38)),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, darker(color, 0.22)),
	})
end

-- Texte cartoon : police épaisse + contour noir arrondi.
function UiStyle.text(parent: Instance, value: string, size: number, color: Color3?, font: Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextSize = size
	label.FontFace = font or UiStyle.TITLE_FONT
	label.TextColor3 = color or WHITE
	UiStyle.stroke(label, Typography.StrokeSize(size))
	label.Parent = parent
	-- L'appelant fixe d'abord la taille, le retour à la ligne et l'AutomaticSize.
	task.defer(function()
		if label.Parent and not label.TextScaled then
			Typography.Fit(label, label.TextSize)
		end
	end)
	return label
end

-- Chiffres droits très gras (argent, vitesse...), cohérents avec les titres.
function UiStyle.number(parent: Instance, value: string, size: number, color: Color3): TextLabel
	local label = UiStyle.text(parent, value, size, color)
	label.FontFace = UiStyle.NUMBER_FONT
	return label
end

----------------------------------------------------------------------
-- Animations partagées (une seule boucle pour tout l'écran)
----------------------------------------------------------------------

-- Rayons qui tournent lentement, icônes qui se balancent : on les anime tant qu'ils sont visibles à l'écran.
local spinners: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any
local swayers: { [GuiObject]: { base: number, amount: number, phase: number } } = setmetatable({}, { __mode = "k" }) :: any

RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	for object, speed in pairs(spinners) do
		if object.Parent and object.Visible then
			object.Rotation = (object.Rotation + speed * dt) % 360
		end
	end
	for object, sway in pairs(swayers) do
		if object.Parent and object.Visible then
			object.Rotation = sway.base + math.sin(now * 2.2 + sway.phase) * sway.amount
		end
	end
end)

-- Fait tourner un objet (degrés par seconde).
function UiStyle.spin(object: GuiObject, speed: number)
	spinners[object] = speed
end

-- Balancement doux (icônes des menus).
function UiStyle.sway(object: GuiObject, amount: number)
	swayers[object] = { base = object.Rotation, amount = amount, phase = math.random() * math.pi * 2 }
end

-- Reflet en diagonale qui traverse un bouton au survol. C'est un dégradé posé sur un cadre de la taille du bouton,
-- aux mêmes coins arrondis : il reste toujours DANS le bouton, même penché (ClipsDescendants ne coupe plus rien dès
-- qu'un objet est tourné : un reflet qui se déplace dépassait du bouton).
function UiStyle.addSweep(button: GuiObject, radius: number)
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BackgroundColor3 = WHITE
	sweep.BorderSizePixel = 0
	sweep.Size = UDim2.fromScale(1, 1)
	sweep.ZIndex = button.ZIndex
	UiStyle.corner(sweep, radius)
	local band = Instance.new("UIGradient")
	band.Rotation = 20
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.38, 1),
		NumberSequenceKeypoint.new(0.45, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.55, 0.6),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(0.66, 1),
		NumberSequenceKeypoint.new(0.69, 0.7),
		NumberSequenceKeypoint.new(0.72, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Offset = Vector2.new(-1.2, 0)
	band.Parent = sweep
	sweep.Parent = button
end

-- Fait passer le reflet (UiStyle.addSweep) d'un bord à l'autre.
function UiStyle.sweep(button: GuiObject)
	local sweep = button:FindFirstChild("Sweep")
	local band = sweep and sweep:FindFirstChildOfClass("UIGradient")
	if band then
		band.Offset = Vector2.new(-1.2, 0)
		TweenService:Create(band, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Offset = Vector2.new(1.2, 0) }):Play()
	end
end

-- Petit effet au survol (reflet qui balaie, sans déborder sur les voisins) et au clic (s'écrase), avec le son de clic.
function UiStyle.bounce(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	-- Keep every button inside its allocated cell, including during hover.
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		UiStyle.sweep(button)
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		TweenService:Create(button, TweenInfo.new(0.12), { Rotation = 0 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.9 }):Play()
	end)
	button.Activated:Connect(function()
		Sounds.play("UiClick")
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end)
end

----------------------------------------------------------------------
-- Fonds
----------------------------------------------------------------------

-- Tenons en relief sur un fond : une texture répétée (teinte `color`). `spacing` = pas en pixels, `transparency` des
-- tenons. Toujours au fond (ZIndex 0).
function UiStyle.studs(parent: GuiObject, color: Color3, spacing: number, transparency: number?)
	local layer = Instance.new("ImageLabel")
	layer.Name = "Studs"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Image = TEX.Stud
	layer.ImageColor3 = color
	layer.ImageTransparency = transparency or 0
	layer.ScaleType = Enum.ScaleType.Tile
	layer.TileSize = UDim2.fromOffset(spacing, spacing)
	layer.ZIndex = 0
	layer.Parent = parent
end

-- Rayons de soleil derrière le contenu d'une carte (tournent lentement).
function UiStyle.sunburst(parent: GuiObject, center: Vector2?)
	local layer = Instance.new("Frame")
	layer.Name = "Sunburst"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ClipsDescendants = true
	layer.ZIndex = 0
	local origin = center or Vector2.new(0.5, 0.45)
	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(origin.X, origin.Y)
	rays.Size = UDim2.fromScale(1.6, 1.6)
	rays.SizeConstraint = Enum.SizeConstraint.RelativeXX
	rays.Image = TEX.Rays
	rays.ImageTransparency = 0.55
	rays.ZIndex = 0
	rays.Parent = layer
	UiStyle.spin(rays, 10)
	layer.Parent = parent
end

-- Rayons + halo derrière un objet mis en avant (offre, récompense) : `size` en pixels, centré sur `parent`.
function UiStyle.rays(parent: GuiObject, color: Color3, size: number, speed: number?): ImageLabel
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(size * 0.8, size * 0.8)
	glow.Image = TEX.Glow
	glow.ImageColor3 = color
	glow.ImageTransparency = 0.25
	glow.ZIndex = parent.ZIndex
	glow.Parent = parent
	local rays = Instance.new("ImageLabel")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(size, size)
	rays.Image = TEX.Rays
	rays.ImageColor3 = lighter(color, 0.4)
	rays.ImageTransparency = 0.05
	rays.ZIndex = parent.ZIndex
	rays.Parent = parent
	UiStyle.spin(rays, speed or 40)
	return rays
end

-- Éclats de lumière en diagonale (en-têtes, cartes).
function UiStyle.shards(parent: GuiObject, transparency: number?)
	local shards = Instance.new("ImageLabel")
	shards.Name = "Shards"
	shards.BackgroundTransparency = 1
	shards.Size = UDim2.fromScale(1, 1)
	shards.Image = TEX.Shards
	shards.ImageTransparency = transparency or 0
	shards.ScaleType = Enum.ScaleType.Stretch
	shards.ZIndex = parent.ZIndex
	shards.Parent = parent
end

-- Carte vive (boutique, index) : couleur pleine en dégradé, rayons de soleil, tenons clairs, gros contour noir.
-- Space for borders and scrollbars around a scrolling collection.
function UiStyle.scrollPadding(scroll: ScrollingFrame)
	local padding = scroll:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, if scroll.ScrollingDirection == Enum.ScrollingDirection.Y then 16 else 8)
	padding.PaddingBottom = UDim.new(0, if scroll.ScrollingDirection == Enum.ScrollingDirection.X then 18 else 8)
	padding.Parent = scroll
end

function UiStyle.brightCard(parent: Instance, size: UDim2, color: Color3): Frame
	local card = Instance.new("Frame")
	card.Size = size
	card.BackgroundColor3 = WHITE
	card.BorderSizePixel = 0
	UiStyle.corner(card, 8)
	UiStyle.stroke(card, 4, BLACK, true)
	UiStyle.gradient(card, lighter(color, 0.4), darker(color, 0.08))
	card.Parent = parent
	UiStyle.sunburst(card)
	UiStyle.studs(card, WHITE, 26, 0.9)
	-- Liseré clair à l'intérieur du contour (relief).
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.BackgroundTransparency = 1
	rim.Position = UDim2.fromOffset(3, 3)
	rim.Size = UDim2.new(1, -6, 1, -6)
	rim.ZIndex = 0
	UiStyle.corner(rim, 6)
	local rimStroke = UiStyle.stroke(rim, 2, WHITE, true)
	rimStroke.Transparency = 0.6
	rim.Parent = card
	return card
end

----------------------------------------------------------------------
-- Boutons
----------------------------------------------------------------------

-- Bouton épais en relief avec contour noir (le texte est l'enfant "Caption", le contour l'enfant UIStroke).
function UiStyle.button(parent: Instance, label: string, size: UDim2, color: Color3, textSize: number): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = WHITE
	button.AutoButtonColor = false
	button.Text = ""
	UiStyle.corner(button, 8)
	UiStyle.stroke(button, 3, BLACK, true)
	local shade = UiStyle.gradient(button, WHITE, WHITE)
	shade.Color = UiStyle.buttonColors(color)
	button.Parent = parent

	-- Reflet clair sur le haut, lèvre sombre en bas (effet bouton qu'on peut enfoncer).
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.72
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 4, 0, 3)
	shine.Size = UDim2.new(1, -8, 0.34, 0)
	UiStyle.corner(shine, 5)
	shine.Parent = button
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BackgroundColor3 = BLACK
	lip.BackgroundTransparency = 0.78
	lip.BorderSizePixel = 0
	lip.AnchorPoint = Vector2.new(0, 1)
	lip.Position = UDim2.fromScale(0, 1)
	lip.Size = UDim2.new(1, 0, 0, math.clamp(math.floor((if size.Y.Offset > 0 then size.Y.Offset else 40) * 0.16), 3, 8))
	UiStyle.corner(lip, 8)
	lip.Parent = button

	UiStyle.addSweep(button, 8)

	local caption = UiStyle.text(button, label, textSize)
	caption.Name = "Caption"
	local insetY = if size.Y.Offset > 0 and size.Y.Offset <= 30 then 3 else 6
	local insetX = if size.X.Offset > 0 and size.X.Offset <= 44 then 5 else 12
	caption.Position = UDim2.fromOffset(insetX, insetY)
	caption.Size = UDim2.new(1, -2 * insetX, 1, -2 * insetY)
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

-- Tuile de menu (HUD) : bouton coloré carré ou large, tenons clairs, grosse icône qui se balance, nom en bas.
function UiStyle.tile(parent: Instance, icon: string, label: string, size: UDim2, color: Color3, textSize: number): TextButton
	local tile = UiStyle.button(parent, "", size, color, 1)
	local studs = Instance.new("Frame")
	studs.Name = "StudLayer"
	studs.BackgroundTransparency = 1
	studs.Size = UDim2.fromScale(1, 1)
	studs.ClipsDescendants = true
	studs.Parent = tile
	UiStyle.studs(studs, WHITE, 18, 0.86)
	local wide = size.X.Offset > size.Y.Offset * 1.4
	local iconSize = if wide then size.Y.Offset * 1.05 else size.Y.Offset * 0.78
	local image = Icons.image(tile, icon, UDim2.fromOffset(iconSize, iconSize))
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = if wide then UDim2.new(0, iconSize * 0.42, 0.42, 0) else UDim2.new(0.5, 0, 0.4, 0)
	image.Rotation = -6
	image.ZIndex = 3
	UiStyle.sway(image, 5)
	local name = UiStyle.text(tile, label, textSize, WHITE, UiStyle.TITLE_FONT)
	name.Name = "Label"
	name.ZIndex = 4
	if wide then
		name.Position = UDim2.new(0, iconSize * 0.8, 0, 0)
		name.Size = UDim2.new(1, -iconSize * 0.8 - 6, 1, 0)
	else
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -3)
		name.Size = UDim2.new(1, -6, 0, textSize + 4)
	end
	name.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = textSize
	limit.Parent = name
	return tile
end

-- Pastille rouge de notification (coin haut droit d'un bouton), qui pulse. Texte vide = cachée.
function UiStyle.badge(parent: GuiObject): TextLabel
	local badge = UiStyle.text(parent, "", 20)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.fromOffset(32, 32)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = UiStyle.Colors.Red
	badge.ZIndex = 6
	badge.Visible = false
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = badge
	UiStyle.gradient(badge, Color3.fromRGB(255, 90, 90), Color3.fromRGB(200, 10, 20))
	-- Bordure noire du rond (le contour du texte reste celui créé par UiStyle.text).
	local ring = UiStyle.stroke(badge, 3, BLACK, true)
	ring.Name = "Ring"
	local pulse = Instance.new("UIScale")
	pulse.Parent = badge
	TweenService:Create(pulse, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.15 }):Play()
	return badge
end

function UiStyle.setBadge(badge: TextLabel, value: string?)
	badge.Visible = value ~= nil and value ~= ""
	badge.Text = value or ""
end

----------------------------------------------------------------------
-- Fenêtres
----------------------------------------------------------------------

export type Window = {
	frame: Frame,
	header: Frame,
	content: Frame,
	closeButton: TextButton,
	scale: UIScale,
	icon: ImageLabel?,
}

local HEADER_HEIGHT = 64

-- Fenêtre façon packs « Studs UI ». headerColor = couleur de la fonction (vert vente, violet machines, cyan
-- collection...). icon = nom d'icône (shared/Icons) affichée en grand, penchée, en haut à gauche.
-- `frame` est un support transparent (taille de la fenêtre) : ombre, corps, en-tête et contenu sont ses enfants.
function UiStyle.window(parent: Instance, title: string, size: Vector2, headerColor: Color3, icon: string?): Window
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.52)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.ZIndex = 5 -- au-dessus du reste du HUD (carte des tirages, points)
	frame.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Parent = frame

	-- Ombre douce sous la fenêtre (image 9-slice qui dépasse un peu).
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Image = TEX.Shadow
	shadow.ImageTransparency = 0.25
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(64, 64, 192, 192)
	shadow.Position = UDim2.fromOffset(-30, -22)
	shadow.Size = UDim2.new(1, 60, 1, 60)
	shadow.ZIndex = 0
	shadow.Parent = frame

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = UiStyle.Colors.WindowBody
	body.BorderSizePixel = 0
	body.ZIndex = 1
	UiStyle.corner(body, 10)
	UiStyle.stroke(body, 5, BLACK, true)
	UiStyle.gradient(body, WHITE, Color3.fromRGB(170, 170, 180)) -- ombrage par-dessus la couleur du corps
	body.Parent = frame
	UiStyle.studs(body, UiStyle.Colors.WindowStud, 30, 0.45)
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.BackgroundTransparency = 1
	rim.Position = UDim2.fromOffset(4, 4)
	rim.Size = UDim2.new(1, -8, 1, -8)
	rim.ZIndex = 1
	UiStyle.corner(rim, 8)
	local rimStroke = UiStyle.stroke(rim, 2, WHITE, true)
	rimStroke.Transparency = 0.88
	rim.Parent = body

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.BackgroundColor3 = WHITE
	header.BorderSizePixel = 0
	header.ZIndex = 2
	header.ClipsDescendants = false
	UiStyle.corner(header, 10)
	UiStyle.stroke(header, 4, BLACK, true)
	UiStyle.gradient(header, lighter(headerColor, 0.3), darker(headerColor, 0.15))
	header.Parent = frame
	-- Décor de l'en-tête, coupé à ses bords : tenons clairs, éclats de lumière, bande d'ombre en bas.
	local deco = Instance.new("Frame")
	deco.Name = "Deco"
	deco.BackgroundTransparency = 1
	deco.Size = UDim2.fromScale(1, 1)
	deco.ClipsDescendants = true
	deco.ZIndex = 2
	deco.Parent = header
	UiStyle.studs(deco, WHITE, 24, 0.82)
	UiStyle.shards(deco, 0.1)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundColor3 = BLACK
	band.BackgroundTransparency = 0.75
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0, 1)
	band.Position = UDim2.fromScale(0, 1)
	band.Size = UDim2.new(1, 0, 0, 8)
	band.ZIndex = 2
	band.Parent = deco

	local titleX = if icon then 92 else 22
	local titleShadow = UiStyle.text(header, title, 40, BLACK, UiStyle.BODY_FONT)
	titleShadow.Name = "TitleShadow"
	titleShadow.Position = UDim2.fromOffset(titleX + 2, 3)
	titleShadow.Size = UDim2.new(1, -titleX - 90, 1, 0)
	titleShadow.TextXAlignment = Enum.TextXAlignment.Left
	titleShadow.TextTransparency = 0.55
	titleShadow.ZIndex = 3
	local shadowStroke = titleShadow:FindFirstChildOfClass("UIStroke")
	if shadowStroke then
		shadowStroke.Transparency = 0.55
	end
	local titleLabel = UiStyle.text(header, title, 40, WHITE, UiStyle.BODY_FONT)
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(titleX, 0)
	titleLabel.Size = UDim2.new(1, -titleX - 90, 1, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 3
	for _, label in ipairs({ titleLabel, titleShadow }) do
		label.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 40
		limit.Parent = label
	end

	local closeButton = UiStyle.button(header, "X", UDim2.fromOffset(52, 52), UiStyle.Colors.Red, 34)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -8, 0.5, 0)
	closeButton.ZIndex = 3

	local iconImage: ImageLabel? = nil
	if icon then
		local image = Icons.image(frame, icon, UDim2.fromOffset(96, 96))
		image.Name = "HeaderIcon"
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromOffset(40, 22)
		image.Rotation = -10
		image.ZIndex = 4
		iconImage = image
	end

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(16, HEADER_HEIGHT + 12)
	content.Size = UDim2.new(1, -32, 1, -(HEADER_HEIGHT + 26))
	content.ZIndex = 2
	content.Parent = frame

	return { frame = frame, header = header, content = content, closeButton = closeButton, scale = scale, icon = iconImage }
end

-- Panneau sombre à contour noir (une ligne de boutique, une case...), léger relief.
function UiStyle.panel(parent: Instance, size: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Size = size
	panel.BackgroundColor3 = UiStyle.Colors.Panel
	panel.BorderSizePixel = 0
	UiStyle.corner(panel, 8)
	UiStyle.stroke(panel, 3, BLACK, true)
	-- Ombrage par-dessus la couleur (un menu peut changer BackgroundColor3 : le relief reste).
	UiStyle.gradient(panel, WHITE, Color3.fromRGB(175, 175, 185))
	panel.Parent = parent
	return panel
end

return UiStyle
