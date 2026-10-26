--!strict
-- WorldMenu : fenêtre MONDES en une page qui défile de haut en bas (refaite le 26 oct. 2026 avec les règles de
-- dataset_and_pipeline/UI_UX_GUIDELINES.md ; briques client/ShopKit, effets client/UIJuiceController) :
--   - en-tête : l'argent du joueur (compteur qui défile) ;
--   - PROCHAIN MONDE : grande carte du monde à débloquer (paysage, ce qu'on y gagne, jauge argent / prix, « IL TE
--     MANQUE ... », gros bouton VOYAGER) ; cachée quand tous les mondes sont débloqués ;
--   - LES 7 MONDES : une large carte par monde (aperçu du monde, numéro, revenu, tirages, ses familiers
--     exclusifs en aperçu 3D, en silhouette tant qu'ils ne sont pas découverts) et son bouton : ACTUEL (tu es ici),
--     Y ALLER (déjà visité : retour gratuit, Remotes.GoToWorld), VOYAGER $prix (le suivant), VERROUILLÉ (après, voilé
--     avec un cadenas). Le bonus de revenu reste celui du monde le plus loin atteint.
-- Aperçu du monde : petite scène 3D faite de ses décors (Worlds.Looks.*.Preview, ReplicatedStorage.ArtModels.Map) et de
--   son familier le plus rare, devant son ciel. Déjà visité : en couleurs, bien éclairé. Inconnu : silhouettes noires
--   sur un horizon qui rougeoie à la couleur du monde, brume, « ? » qui pulse (le cadenas du voile le remplace pour les
--   mondes après le suivant). Sans les décors (pas encore importés) : le petit paysage en aplats.
-- Le voyage est validé par le serveur (Remotes.BuyTier / GoToWorld -> server/TierController) ; pas assez d'argent :
-- secousse, éclair rouge, « IL TE MANQUE ... ».
-- Arrivée (Remotes.TierReached) : flash, grand titre du monde, son ; annonce chez les autres joueurs.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local Worlds = require(ReplicatedStorage.Shared.Worlds)
local MenuKit = require(script.Parent.MenuKit)
local ShopKit = require(script.Parent.ShopKit)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UIJuice = require(script.Parent.UIJuiceController)
local UiStyle = require(script.Parent.UiStyle)

local WorldMenu = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GREY = Color3.fromRGB(150, 150, 160)
local ORANGE = Color3.fromRGB(255, 150, 40)
local PRAIRIE = Worlds.Looks.Prairie
local K = ShopKit.K
local TOUCH = ShopKit.TOUCH
-- Une large carte par monde (une seule colonne) ; au doigt, plus haute et avec un paysage plus étroit.
local ROW_HEIGHT = if TOUCH then 236 else 178
local FEATURED_HEIGHT = if TOUCH then 280 else 222
local LAND_WIDTH = if TOUCH then 170 else 230
local BUTTON_WIDTH = math.floor(210 * K)

local player = Players.LocalPlayer

-- Monde le plus loin débloqué (bonus de revenu).
local function tier(): number
	local value = player:GetAttribute("Tier")
	return if type(value) == "number" then value else 1
end

-- Monde où le joueur se trouve (on peut revenir dans un monde déjà visité).
local function currentWorld(): number
	local value = player:GetAttribute("World")
	return if type(value) == "number" then value else tier()
end

local function lookOf(index: number): Worlds.Look
	return Worlds.Looks[Config.Worlds[index].Id] or PRAIRIE
end

-- Couleurs de la Prairie (MapGenerator) pour les rôles que les autres mondes repeignent.
local PRAIRIE_COLORS: { [string]: Color3 } = {
	GrassA = Color3.fromRGB(150, 228, 58),
	WallA = Color3.fromRGB(202, 145, 86),
	WallTop = Color3.fromRGB(110, 214, 42),
	PathA = Color3.fromRGB(246, 214, 128),
}

local function swatch(look: Worlds.Look, role: string): Color3
	return look.Palette[role] or PRAIRIE_COLORS[role] or WHITE
end

-- Ce que donnent les tirages du monde (Config.Worlds[].RarityBoost).
local function luckText(world: Config.WorldDef): string
	local boost = world.RarityBoost or 1
	if boost <= 1 then
		return "Tirages normaux"
	end
	return "Tirages +" .. math.floor((boost - 1) * 100 + 0.5) .. " %"
end

-- Petit paysage en aplats (si les décors du monde ne sont pas dans le jeu) : ciel (couleur de l'air), mur avec sa
-- crête, sol en damier.
local function flatLandscape(holder: Frame, look: Worlds.Look)
	holder.BackgroundColor3 = look.Ambience.AirColor
	local wall = Instance.new("Frame")
	wall.BorderSizePixel = 0
	wall.BackgroundColor3 = swatch(look, "WallA")
	wall.Position = UDim2.fromScale(0, 0.35)
	wall.Size = UDim2.fromScale(1, 0.3)
	wall.ZIndex = holder.ZIndex
	wall.Parent = holder
	local top = Instance.new("Frame")
	top.BorderSizePixel = 0
	top.BackgroundColor3 = swatch(look, "WallTop")
	top.Position = UDim2.fromScale(0, 0.3)
	top.Size = UDim2.fromScale(1, 0.07)
	top.ZIndex = holder.ZIndex
	top.Parent = holder
	for index = 0, 5 do
		local tile = Instance.new("Frame")
		tile.BorderSizePixel = 0
		tile.BackgroundColor3 = if index % 2 == 0 then swatch(look, "GrassA") else swatch(look, "PathA")
		tile.Position = UDim2.fromScale(index / 6, 0.65)
		tile.Size = UDim2.fromScale(1 / 6 + 0.002, 0.35)
		tile.ZIndex = holder.ZIndex
		tile.Parent = holder
	end
end

-- Familier vedette : l'exclusif le plus rare du monde (la Prairie n'en a pas : le chien saucisse).
local function showcasePet(worldId: string): string
	local best, bestRank = "ChienSaucisse", 0
	for _, entry in ipairs(PetCatalog.ByWorld[worldId] or {}) do
		local rank = Config.RarityIndex[entry.Rarity] or 0
		if rank > bestRank then
			best, bestRank = entry.Id, rank
		end
	end
	return best
end

-- Copie d'un décor de ArtModels.Map posée au sol (pivot au centre de la pièce, devant vers -Z).
local function placeDecor(scene: Model, library: Instance, name: string, x: number, z: number, scale: number, yaw: number): boolean
	local source = library:FindFirstChild(name)
	if not (source and source:IsA("BasePart")) then
		return false
	end
	local part = source:Clone()
	part.Anchored = true
	part.Size *= scale
	part.CFrame = CFrame.new(x, part.Size.Y / 2, z) * CFrame.Angles(0, math.rad(yaw), 0)
	part.Parent = scene
	return true
end

local function slab(scene: Model, size: Vector3, position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = scene
end

-- Ciel : `top` en haut, `horizon` à la hauteur de l'horizon de la scène (~60 % de l'image), `low` dessous.
local function skyGradient(frame: Frame, top: Color3, horizon: Color3, low: Color3)
	frame.BackgroundColor3 = WHITE
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.6, horizon),
		ColorSequenceKeypoint.new(1, low),
	})
	gradient.Parent = frame
end

-- Aperçu du monde `index` dans `holder` (vidé d'abord) ; known = le joueur y est déjà allé ; mark = « ? » qui pulse
-- sur un monde inconnu (pas quand le voile et son cadenas le couvrent).
local function landscape(holder: Frame, index: number, known: boolean, mark: boolean)
	holder:ClearAllChildren()
	holder.BackgroundColor3 = BLACK
	UiStyle.corner(holder, 8)
	UiStyle.stroke(holder, 3, BLACK, true)
	local look = lookOf(index)
	local preview = look.Preview
	local accent = look.Accent
	local z = holder.ZIndex

	local sky = Instance.new("Frame")
	sky.Name = "Sky"
	sky.BorderSizePixel = 0
	sky.Size = UDim2.fromScale(1, 1)
	sky.ZIndex = z
	sky.Parent = holder

	local artModels = ReplicatedStorage:FindFirstChild("ArtModels")
	local library = artModels and artModels:FindFirstChild("Map")
	local scene = Instance.new("Model")
	local built = false
	if preview and library then
		built = placeDecor(scene, library, preview.Gate, 0, 6, 1, 0)
		placeDecor(scene, library, preview.Back, -20, 36, 0.85, 4)
		placeDecor(scene, library, preview.Back, 20, 38, 0.85, -6)
		if preview.Sides[1] then
			placeDecor(scene, library, preview.Sides[1], -17, 1, 1, 20)
		end
		if preview.Sides[2] then
			placeDecor(scene, library, preview.Sides[2], 17, 1, 1, -25)
		end
		slab(scene, Vector3.new(110, 1, 70), Vector3.new(0, -0.5, 12), swatch(look, "GrassA"))
		slab(scene, Vector3.new(9, 0.2, 34), Vector3.new(0, 0.1, -12), swatch(look, "PathA"))
		local pet = PetModelBuilder.Build(showcasePet(Config.Worlds[index].Id))
		if pet then
			MenuKit.cleanPetModel(pet)
			local _, bodySize = PetModelBuilder.BodyBounds(pet)
			pet:ScaleTo(pet:GetScale() * (8 / math.max(bodySize.Y, bodySize.X * 0.6, 0.5)))
			pet:PivotTo(CFrame.new(7, 0, -10) * CFrame.Angles(0, math.rad(-25), 0))
			local box, size = pet:GetBoundingBox()
			pet:PivotTo(pet:GetPivot() + Vector3.new(0, size.Y / 2 - box.Position.Y, 0))
			pet.Parent = scene
		end
	end

	if built and preview then
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "Scene"
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.ZIndex = z
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 15, -66), Vector3.new(0, 11, 8))
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		scene.Parent = viewport
		viewport.Parent = holder
		task.spawn(function()
			-- Un ViewportFrame ne se redessine pas quand un maillage finit de charger (vu en jeu : la Prairie restait
			-- vide) : on attend les décors puis on bouge la caméra d'un cheveu.
			pcall(function()
				ContentProvider:PreloadAsync({ scene })
			end)
			if camera.Parent then
				camera.CFrame *= CFrame.new(0.001, 0, 0)
			end
		end)
		if known then
			skyGradient(sky, preview.SkyTop, preview.SkyHorizon, preview.SkyHorizon)
			viewport.Ambient = Color3.fromRGB(175, 175, 180)
			viewport.LightColor = Color3.fromRGB(255, 250, 240)
			viewport.LightDirection = Vector3.new(0.35, -1, 0.6)
		else
			-- L'horizon rougeoie à la couleur du monde : les silhouettes se découpent dessus.
			MenuKit.silhouette(scene)
			skyGradient(sky, Color3.fromRGB(8, 6, 16), accent:Lerp(BLACK, 0.05), accent:Lerp(BLACK, 0.55))
			viewport.Ambient = accent:Lerp(BLACK, 0.85)
			viewport.LightColor = accent:Lerp(WHITE, 0.3)
			viewport.LightDirection = Vector3.new(0.3, -0.35, -1)
		end
	else
		scene:Destroy()
		flatLandscape(sky, look)
	end

	if preview and preview.Stars then
		local random = Random.new(index * 97)
		for _ = 1, 16 do
			local star = Instance.new("Frame")
			star.BorderSizePixel = 0
			star.BackgroundColor3 = WHITE
			star.BackgroundTransparency = random:NextNumber(0.1, 0.5)
			local size = random:NextInteger(2, 3)
			star.Size = UDim2.fromOffset(size, size)
			star.Position = UDim2.fromScale(random:NextNumber(0.02, 0.96), random:NextNumber(0.03, 0.4))
			star.ZIndex = z
			star.Parent = sky
		end
	end

	if not known then
		-- Brume sombre en bas et grand « ? » qui pulse.
		local fog = Instance.new("Frame")
		fog.Name = "Fog"
		fog.BorderSizePixel = 0
		fog.BackgroundColor3 = BLACK
		fog.Size = UDim2.fromScale(1, 1)
		fog.ZIndex = z
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 0.85),
			NumberSequenceKeypoint.new(1, 0.25),
		})
		fade.Parent = fog
		fog.Parent = holder
		if mark then
			local question = UiStyle.text(holder, "?", 64, accent:Lerp(WHITE, 0.35), UiStyle.NUMBER_FONT)
			question.Name = "Mystery"
			question.AnchorPoint = Vector2.new(0.5, 0.5)
			question.Position = UDim2.fromScale(0.5, 0.42)
			question.Size = UDim2.fromOffset(80, 80)
			question.ZIndex = z + 1
			local pulse = Instance.new("UIScale")
			pulse.Parent = question
			TweenService:Create(pulse, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.18 }):Play()
		end
	end
end

local function landscapeHolder(parent: Instance, width: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Landscape"
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.Position = UDim2.fromOffset(12, 12)
	holder.Size = UDim2.new(0, width, 1, -24)
	holder.ZIndex = 2
	holder.Parent = parent
	return holder
end

-- Recolore une carte vive (UiStyle.brightCard) : son dégradé est son UIGradient direct.
local function recolor(body: Frame, color: Color3)
	local shade = body:FindFirstChildOfClass("UIGradient")
	if shade then
		shade.Color = ColorSequence.new(UiStyle.lighter(color, 0.4), UiStyle.darker(color, 0.08))
	end
end

type Cell = { petId: string, holder: Frame, viewport: ViewportFrame?, known: boolean? }

type Row = {
	index: number,
	body: Frame,
	land: Frame, -- aperçu du monde
	shown: string?, -- état de l'aperçu affiché (« connu », « mystère », « verrouillé »)
	status: TextLabel,
	button: TextButton,
	here: Frame, -- ruban « TU ES ICI »
	veil: Frame, -- voile + cadenas des mondes pas encore accessibles
	count: TextLabel, -- « FAMILIERS EXCLUSIFS 2 / 5 »
	cells: { Cell },
}

export type Menu = { window: MenuKit.Window, refresh: () -> (), canTravel: () -> boolean }

function WorldMenu.create(gui: Instance): Menu
	local window = MenuKit.window(gui, "Mondes", ShopKit.WINDOW, ORANGE, "Planet")
	local moneyChip = ShopKit.moneyChip(window.header, function()
		return MenuKit.number("Money")
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Page"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = if TOUCH then 12 else 10
	scroll.ScrollBarImageColor3 = WHITE
	scroll.ZIndex = 2
	scroll.Parent = window.content
	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Padding = UDim.new(0, 22)
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Parent = scroll
	UiStyle.scrollPadding(scroll)
	local pagePadding = scroll:FindFirstChildOfClass("UIPadding")
	if pagePadding then
		pagePadding.PaddingLeft = UDim.new(0, 14) -- les rubans dépassent un peu à gauche des cartes
		pagePadding.PaddingTop = UDim.new(0, 12)
		pagePadding.PaddingBottom = UDim.new(0, 16)
	end

	-- Voyage vers le monde suivant (le serveur revérifie le prix).
	local function travel(body: GuiObject)
		local nextWorld = Config.Worlds[tier() + 1]
		if not nextWorld then
			return
		end
		local money = MenuKit.number("Money")
		if money < nextWorld.Price then
			UIJuice.denied(body)
			Toast.show("IL TE MANQUE " .. NumberFormat.money(nextWorld.Price - money) .. " !", UiStyle.Colors.Red)
			return
		end
		Remotes.BuyTier:FireServer()
	end

	-- Prochain monde ----------------------------------------------------------

	local featuredSection = ShopKit.section(scroll, 1, "Prochain monde", "Plus de revenu, de nouveaux familiers", "Planet", ORANGE, "", 1, FEATURED_HEIGHT)
	local featuredCard = ShopKit.card(featuredSection.grid, PRAIRIE.Accent, 1)
	local featuredBody = featuredCard.body
	local featuredLand = landscapeHolder(featuredBody, math.floor(LAND_WIDTH * 1.15))
	local _, featuredRibbon = ShopKit.ribbon(featuredBody, "", UiStyle.Colors.Gold)
	local fLeft = 12 + featuredLand.Size.X.Offset + 16
	local fy = 10
	local featuredName = ShopKit.label(featuredBody, "", 36)
	featuredName.TextXAlignment = Enum.TextXAlignment.Left
	featuredName.Position = UDim2.fromOffset(fLeft, fy)
	featuredName.Size = UDim2.new(1, -fLeft - 14, 0, math.floor(36 * K))
	featuredName.ZIndex = 3
	fy += math.floor(36 * K) + 6
	local gains = Instance.new("Frame")
	gains.BackgroundTransparency = 1
	gains.Position = UDim2.fromOffset(fLeft, fy)
	gains.Size = UDim2.new(1, -fLeft - 14, 0, math.floor(32 * K))
	gains.Parent = featuredBody
	local gainTexts: { TextLabel } = {}
	for slot = 0, 2 do
		local chip, text = ShopKit.chip(gains, 18)
		chip.Position = UDim2.new(slot / 3, if slot > 0 then 4 else 0, 0, 0)
		chip.Size = UDim2.new(1 / 3, -6, 1, 0)
		table.insert(gainTexts, text)
	end
	gainTexts[1].TextColor3 = UiStyle.Colors.Money
	fy += math.floor(32 * K) + 8
	local featuredGauge = ShopKit.gauge(featuredBody, UiStyle.Colors.Money)
	featuredGauge.frame.Position = UDim2.fromOffset(fLeft, fy)
	featuredGauge.frame.Size = UDim2.new(1, -fLeft - 14, 0, math.floor(30 * K))
	local featuredMissing = ShopKit.label(featuredBody, "", 22)
	featuredMissing.TextXAlignment = Enum.TextXAlignment.Left
	featuredMissing.AnchorPoint = Vector2.new(0, 1)
	featuredMissing.Position = UDim2.new(0, fLeft, 1, -16)
	featuredMissing.Size = UDim2.new(1, -fLeft - BUTTON_WIDTH - 28, 0, ShopKit.BUTTON_HEIGHT - 8)
	featuredMissing.TextWrapped = true
	featuredMissing.ZIndex = 3
	local featuredButton = ShopKit.buyButton(featuredBody, UiStyle.Colors.Green, "Planet")
	featuredButton.AnchorPoint = Vector2.new(1, 1)
	featuredButton.Position = UDim2.new(1, -12, 1, -12)
	featuredButton.Size = UDim2.fromOffset(BUTTON_WIDTH, ShopKit.BUTTON_HEIGHT)
	featuredButton.Activated:Connect(function()
		travel(featuredBody)
	end)
	local featuredIndex = 0

	-- Les 7 mondes ----------------------------------------------------------

	local listSection = ShopKit.section(scroll, 2, "Les " .. #Config.Worlds .. " mondes", "Le revenu suit le monde le plus loin", "Planet", ORANGE, "", 1, ROW_HEIGHT)
	local rows: { Row } = {}
	local left = 12 + LAND_WIDTH + 14
	local middle = -(left + BUTTON_WIDTH + 24) -- largeur de la colonne du milieu (en plus de 100 %)

	for index, world in ipairs(Config.Worlds) do
		local look = lookOf(index)
		local card = ShopKit.card(listSection.grid, look.Accent, index)
		local body = card.body
		local land = landscapeHolder(body, LAND_WIDTH)
		-- Numéro du monde en pastille ronde sur le paysage.
		local number = ShopKit.label(body, tostring(index), 24)
		number.BackgroundTransparency = 0
		number.BackgroundColor3 = UiStyle.Colors.Panel
		number.Position = UDim2.fromOffset(20, 20)
		number.Size = UDim2.fromOffset(math.floor(38 * K), math.floor(38 * K))
		number.ZIndex = 4
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = number
		UiStyle.stroke(number, 3, BLACK, true)

		local name = ShopKit.label(body, world.Name, 32)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(left, 8)
		name.Size = UDim2.new(1, middle, 0, math.floor(36 * K))
		name.ZIndex = 3
		local y = 8 + math.floor(36 * K) + 4
		local chips = Instance.new("Frame")
		chips.BackgroundTransparency = 1
		chips.Position = UDim2.fromOffset(left, y)
		chips.Size = UDim2.new(1, middle, 0, math.floor(30 * K))
		chips.Parent = body
		local income, incomeText = ShopKit.chip(chips, 18)
		income.Size = UDim2.new(0.5, -4, 1, 0)
		incomeText.Text = "Revenu x" .. tostring(world.IncomeMultiplier)
		incomeText.TextColor3 = UiStyle.Colors.Money
		local luck, luckLabel = ShopKit.chip(chips, 18)
		luck.Position = UDim2.new(0.5, 4, 0, 0)
		luck.Size = UDim2.new(0.5, -4, 1, 0)
		luckLabel.Text = luckText(world)
		y += math.floor(30 * K) + 6
		local count = ShopKit.label(body, "FAMILIERS DE BASE", 16)
		count.TextXAlignment = Enum.TextXAlignment.Left
		count.Position = UDim2.fromOffset(left, y)
		count.Size = UDim2.new(1, middle, 0, math.floor(20 * K))
		count.ZIndex = 3
		y += math.floor(20 * K) + 2

		-- Familiers exclusifs : une case carrée par familier (aperçu 3D créé à la première ouverture).
		local strip = Instance.new("Frame")
		strip.Name = "Pets"
		strip.BackgroundTransparency = 1
		strip.Position = UDim2.fromOffset(left, y)
		strip.Size = UDim2.new(1, middle, 1, -y - 12)
		strip.Parent = body
		local stripLayout = Instance.new("UIListLayout")
		stripLayout.FillDirection = Enum.FillDirection.Horizontal
		stripLayout.Padding = UDim.new(0, 5)
		stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
		stripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		stripLayout.Parent = strip
		local cells: { Cell } = {}
		local exclusives = PetCatalog.ByWorld[world.Id] or {}
		local share = 1 / math.max(5, #exclusives) -- le Volcan en a 6 (Cerbère Infernal)
		for order, entry in ipairs(exclusives) do
			local holder = Instance.new("Frame")
			holder.Name = "Pet" .. order
			holder.LayoutOrder = order
			holder.BackgroundColor3 = UiStyle.Colors.Panel
			holder.BackgroundTransparency = 0.25
			holder.BorderSizePixel = 0
			holder.Size = UDim2.new(share, -4, 1, 0)
			holder.ZIndex = 3
			UiStyle.corner(holder, 8)
			UiStyle.stroke(holder, 2, BLACK, true)
			local square = Instance.new("UIAspectRatioConstraint")
			square.AspectRatio = 1
			square.Parent = holder
			holder.Parent = strip
			table.insert(cells, { petId = entry.Id, holder = holder })
		end

		local status = ShopKit.label(body, "", 20)
		status.AnchorPoint = Vector2.new(1, 1)
		status.Position = UDim2.new(1, -12, 1, -(ShopKit.BUTTON_HEIGHT + 18))
		status.Size = UDim2.fromOffset(BUTTON_WIDTH, math.floor(26 * K))
		status.ZIndex = 3
		local button = ShopKit.buyButton(body, UiStyle.Colors.Green, "Planet")
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -12, 1, -12)
		button.Size = UDim2.fromOffset(BUTTON_WIDTH, ShopKit.BUTTON_HEIGHT)
		local here = ShopKit.ribbon(body, "TU ES ICI", UiStyle.Colors.Cyan)
		here.Visible = false

		-- Monde pas encore accessible : voile sombre et cadenas (le bouton gris reste lisible à droite).
		local veil = Instance.new("Frame")
		veil.Name = "Locked"
		veil.BackgroundColor3 = BLACK
		veil.BackgroundTransparency = 0.45
		veil.BorderSizePixel = 0
		veil.Size = UDim2.new(1, -(BUTTON_WIDTH + 20), 1, 0)
		veil.ZIndex = 7
		veil.Visible = false
		UiStyle.corner(veil, 8)
		veil.Parent = body
		local lockIcon = Icons.image(veil, "Lock", UDim2.fromOffset(math.floor(64 * K), math.floor(64 * K)))
		lockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		lockIcon.Position = UDim2.new(0, 12 + LAND_WIDTH / 2, 0.5, 0)
		lockIcon.ZIndex = 8

		button.Activated:Connect(function()
			local current = tier()
			if index == currentWorld() then
				UIJuice.pop(body, 0.04)
			elseif index <= current then
				Remotes.GoToWorld:FireServer(index)
			elseif index == current + 1 then
				travel(body)
			else
				UIJuice.denied(body)
				Toast.show("DÉBLOQUE D'ABORD : " .. TextFormat.upper(Config.Worlds[current + 1].Name), UiStyle.Colors.Red)
			end
		end)

		table.insert(rows, {
			index = index,
			body = body,
			land = land,
			status = status,
			button = button,
			here = here,
			veil = veil,
			count = count,
			cells = cells,
		})
	end

	-- Aperçus 3D des familiers exclusifs : créés à la première ouverture (petit à petit), refaits quand un familier
	-- est découvert (la silhouette laisse place au familier).
	local built = false
	local building = false
	local function updatePets(build: boolean, spread: boolean)
		local claimed = MenuKit.claimed()
		for _, row in ipairs(rows) do
			local found = 0
			for _, cell in ipairs(row.cells) do
				local known = MenuKit.discovered(cell.petId, claimed)
				if known then
					found += 1
				end
				if build and (cell.viewport == nil or cell.known ~= known) then
					local old = cell.viewport
					if old then
						old:Destroy()
					end
					local viewport = MenuKit.petViewport(cell.holder, cell.petId, not known)
					viewport.Size = UDim2.fromScale(1, 1)
					viewport.ZIndex = 4
					cell.viewport = viewport
					cell.known = known
					if spread then
						task.wait()
					end
				end
			end
			if #row.cells > 0 then
				row.count.Text = string.format("FAMILIERS EXCLUSIFS  %d / %d", found, #row.cells)
			end
		end
	end

	local function refresh()
		moneyChip.update(window.isOpen())
		local current = tier()
		local here = currentWorld()
		local money = MenuKit.number("Money")
		for _, row in ipairs(rows) do
			local world = Config.Worlds[row.index]
			row.here.Visible = row.index == here
			row.veil.Visible = row.index > current + 1
			local state = if row.index <= current then "known" elseif row.index == current + 1 then "mystery" else "locked"
			if row.shown ~= state then
				row.shown = state
				landscape(row.land, row.index, state == "known", state == "mystery")
			end
			if row.index == here then
				row.status.Text = "TU ES ICI"
				ShopKit.setButton(row.button, "ACTUEL", UiStyle.Colors.Cyan)
			elseif row.index <= current then
				row.status.Text = "DÉJÀ VISITÉ"
				ShopKit.setButton(row.button, "Y ALLER", UiStyle.Colors.Green)
			elseif row.index == current + 1 then
				row.status.Text = "VOYAGER POUR"
				ShopKit.setButton(row.button, NumberFormat.money(world.Price), if money >= world.Price then UiStyle.Colors.Green else UiStyle.Colors.Red)
			else
				row.status.Text = "VERROUILLÉ"
				ShopKit.setButton(row.button, NumberFormat.money(world.Price), GREY)
			end
		end

		-- Prochain monde : rien au-delà du dernier.
		local nextIndex = current + 1
		local nextWorld = Config.Worlds[nextIndex]
		featuredSection.frame.Visible = nextWorld ~= nil
		if nextWorld then
			if featuredIndex ~= nextIndex then
				featuredIndex = nextIndex
				local look = lookOf(nextIndex)
				landscape(featuredLand, nextIndex, false, true)
				recolor(featuredBody, look.Accent)
				featuredRibbon.Text = "MONDE " .. nextIndex
				featuredName.Text = nextWorld.Name
				gainTexts[1].Text = "Revenu x" .. tostring(nextWorld.IncomeMultiplier)
				gainTexts[2].Text = luckText(nextWorld)
				local exclusives = #(PetCatalog.ByWorld[nextWorld.Id] or {})
				gainTexts[3].Text = if exclusives > 0 then exclusives .. " exclusifs" else "Familiers de base"
			end
			ShopKit.setGauge(featuredGauge, money / nextWorld.Price, NumberFormat.money(money) .. " / " .. NumberFormat.money(nextWorld.Price))
			local affordable = money >= nextWorld.Price
			featuredMissing.Text = if affordable then "TU PEUX Y ALLER !" else "IL TE MANQUE " .. NumberFormat.money(nextWorld.Price - money)
			featuredMissing.TextColor3 = if affordable then UiStyle.Colors.Money else WHITE
			ShopKit.setButton(featuredButton, NumberFormat.money(nextWorld.Price), if affordable then UiStyle.Colors.Green else UiStyle.Colors.Red)
		end

		updatePets(built and not building, false)
	end

	window.onOpen(function()
		moneyChip.reset()
		refresh()
		scroll.CanvasPosition = Vector2.zero
		if not built then
			built, building = true, true
			updatePets(true, true)
			building = false
		end
	end)
	refresh()

	return {
		window = window,
		refresh = refresh,
		canTravel = function()
			local nextWorld = Config.Worlds[tier() + 1]
			return nextWorld ~= nil and MenuKit.number("Money") >= nextWorld.Price
		end,
	}
end

----------------------------------------------------------------------
-- Arrivée dans un nouveau monde
----------------------------------------------------------------------

-- revisit = retour dans un monde déjà visité : pas de nouveau bonus de revenu, juste « DE RETOUR ».
function WorldMenu.celebrate(gui: Instance, index: number, revisit: boolean?)
	local world = Config.GetWorld(index)
	local look = Worlds.Looks[world.Id] or PRAIRIE
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 0
	flash.ZIndex = 50
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()

	local title = UiStyle.text(gui, string.format("MONDE %d : %s", index, TextFormat.upper(world.Name)), 72, look.Accent)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.38)
	title.Size = UDim2.fromOffset(1100, 90)
	title.ZIndex = 51
	local subtitle = UiStyle.number(gui, if revisit then "De retour !" else "Revenu x" .. tostring(world.IncomeMultiplier) .. " !", 40,
		UiStyle.Colors.Money)
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.fromScale(0.5, 0.48)
	subtitle.Size = UDim2.fromOffset(700, 50)
	subtitle.ZIndex = 51
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = title
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Sounds.play("RareDrop")
	task.delay(3.2, function()
		local fade = TweenInfo.new(0.6)
		for _, label in ipairs({ title, subtitle }) do
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(4, function()
		flash:Destroy()
		title:Destroy()
		subtitle:Destroy()
	end)
end

return WorldMenu
