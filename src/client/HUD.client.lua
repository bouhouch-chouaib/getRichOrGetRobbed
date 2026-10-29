--!strict
-- HUD : l'écran de jeu, disposé comme la référence (docs/DIRECTION_ARTISTIQUE.md §3) :
--   - au milieu à gauche : gros boutons Boutique (vert), Index (cyan), Mondes, Bonus (cadeau du jour, quêtes, codes),
--     Marché (acheter / vendre des familiers) et Rebirth, avec pastilles rouges ;
--   - en bas à gauche : Force, Vitesse et argent en gros chiffres italiques ;
--   - en haut au centre : une pastille horloge de la manche (lune = on nourrit le trou noir, soleil = il digère)
--     + tirages gagnés pendant la manche, et dessous une pile (boost, consigne, carte des tirages) ;
--   - bandeau de phase au milieu, seulement au changement de phase ;
--   - sur tactile : argent, stats et menus en tuiles en haut à gauche (voir « Disposition » plus bas).
-- Les fenêtres sont dans client/ShopMenu, client/IndexMenu et client/FusionMenu (socle client/MenuKit).
-- Ce script relie tout aux attributs répliqués et aux messages du serveur.

local ContentProvider = game:GetService("ContentProvider")
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BonusMenu = require(script.Parent.BonusMenu)
local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Lang = require(ReplicatedStorage.Shared.Lang)
local LootEngine = require(ReplicatedStorage.Shared.LootEngine)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local MarketMenu = require(script.Parent.MarketMenu)
local RebirthMenu = require(script.Parent.RebirthMenu)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local FusionMenu = require(script.Parent.FusionMenu)
local IndexMenu = require(script.Parent.IndexMenu)
local MenuKit = require(script.Parent.MenuKit)
local OffersPanel = require(script.Parent.OffersPanel)
local WorldMenu = require(script.Parent.WorldMenu)
local ScreenScale = require(script.Parent.ScreenScale)
local ShopMenu = require(script.Parent.ShopMenu)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UIJuice = require(script.Parent.UIJuiceController)
local UiStyle = require(script.Parent.UiStyle)

local player = Players.LocalPlayer

local BODY_FONT = UiStyle.BODY_FONT
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local MONEY = UiStyle.Colors.Money
local text = UiStyle.text
local numberAttribute = MenuKit.number

local PHASES = {
	Feeding = {
		Title = "NOURRIS LE TROU NOIR !",
		Clock = "Moon",
		Next = "Sieste",
		-- Consignes courtes, en mots simples (UI_UX_GUIDELINES.md §7 : beaucoup de joueurs lisent à peine).
		Hint = if ScreenScale.isTouch() then "RAMASSE  •  MAINTIENS LANCER, PUIS LÂCHE" else "[E] RAMASSER  •  CLIC : LANCER",
		Color = Color3.fromRGB(200, 120, 255),
	},
	Digesting = {
		Title = "LE TROU NOIR FAIT LA SIESTE",
		Clock = "Sun",
		Next = "Repas",
		Hint = if ScreenScale.isTouch() then "VOLE LES FAMILIERS DES AUTRES !" else "[E] SUR UN FAMILIER : LE VOLER",
		Color = Color3.fromRGB(255, 90, 70),
	},
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")
-- Tous les éléments sont parentés à "gui", un cadre mis à l'échelle de l'écran (téléphone, tablette, PC).
local gui = ScreenScale.attach(screenGui)
local isTouch = ScreenScale.isTouch()

-- Disposition (13 oct. : écran désencombré, surtout sur téléphone ; docs/DIRECTION_ARTISTIQUE.md §3) :
--   - en haut au centre : UNE pastille (horloge + tirages de la manche) et, dessous, une pile qui n'affiche que
--     ce qui sert maintenant (boost de chance, consigne quelques secondes, résultats des tirages) ;
--   - PC : boutons de menu à gauche au milieu, stats et argent en bas à gauche ;
--   - tactile : argent et stats en haut à gauche, menus en tuiles juste dessous (le joystick de Roblox occupe le
--     bas gauche, le bouton de saut le bas droit) ;
--   - le bas du centre (ScreenScale.BOTTOM_RESERVED) reste libre pour la barre d'objets de Roblox.
local HINT_TIME = 6 -- secondes d'affichage de la consigne après chaque changement de phase

----------------------------------------------------------------------
-- Haut : bandeau de phase (seulement au changement de phase)
----------------------------------------------------------------------

local phaseTitle = text(gui, "", 44)
phaseTitle.AnchorPoint = Vector2.new(0.5, 0.5)
phaseTitle.Position = UDim2.fromScale(0.5, 0.3)
phaseTitle.Size = UDim2.fromOffset(760, 60)
phaseTitle.Visible = false
local phaseScale = Instance.new("UIScale")
phaseScale.Parent = phaseTitle

-- Au chargement de la sauvegarde, niveaux et améliorations passent de 0 à leur valeur : pas de message pour ça.
-- On attend que la sauvegarde soit chargée (ou 8 s si elle ne se charge pas, ex. Studio sans accès API).
local hudStarted = os.clock()
local function dataReady(): boolean
	return player:GetAttribute("DataLoaded") == true or os.clock() - hudStarted > 8
end

----------------------------------------------------------------------
-- En haut au centre : la pastille (horloge de la manche + tirages gagnés pendant le Feeding)
----------------------------------------------------------------------

local CLOCK_WIDTH = 300
local PULLS_WIDTH = 160
local clock = UiStyle.panel(gui, UDim2.fromOffset(CLOCK_WIDTH + PULLS_WIDTH, 56))
clock.Name = "Clock"
clock.AnchorPoint = Vector2.new(0.5, 0)
clock.Position = UDim2.new(0.5, 0, 0, 6)
clock.BackgroundColor3 = UiStyle.Colors.WindowBody
local clockIcon = Icons.image(clock, "Moon", UDim2.fromOffset(46, 46), UDim2.fromOffset(6, 5))
local clockNext = text(clock, "", 20, WHITE, BODY_FONT)
clockNext.Position = UDim2.fromOffset(56, 0)
clockNext.Size = UDim2.new(0, 96, 1, 0)
clockNext.TextXAlignment = Enum.TextXAlignment.Left
local clockLabel = UiStyle.number(clock, "", 32, WHITE)
clockLabel.Position = UDim2.fromOffset(150, 0)
clockLabel.Size = UDim2.new(0, CLOCK_WIDTH - 156, 1, 0)
clockLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Tirages de la manche : chaque objet avalé remplit la barre ; pleine = +1 tirage (ouverts à la digestion).
local pullsBox = Instance.new("Frame")
pullsBox.Name = "Pulls"
pullsBox.BackgroundTransparency = 1
pullsBox.Position = UDim2.fromOffset(CLOCK_WIDTH, 0)
pullsBox.Size = UDim2.new(0, PULLS_WIDTH, 1, 0)
pullsBox.Parent = clock
local separator = Instance.new("Frame")
separator.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
separator.BorderSizePixel = 0
separator.Position = UDim2.fromOffset(0, 8)
separator.Size = UDim2.new(0, 3, 1, -16)
separator.Parent = pullsBox
Icons.image(pullsBox, "Gift", UDim2.fromOffset(40, 40), UDim2.fromOffset(8, 4))
local pointsLabel = UiStyle.number(pullsBox, "", 24, UiStyle.Colors.Gold)
pointsLabel.Position = UDim2.fromOffset(50, 4)
pointsLabel.Size = UDim2.new(1, -56, 0, 28)
pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
pointsLabel.TextScaled = true
do
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = pointsLabel
end
local pullBar = Instance.new("Frame")
pullBar.Position = UDim2.fromOffset(52, 36)
pullBar.Size = UDim2.new(1, -62, 0, 10)
pullBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
UiStyle.corner(pullBar, 4)
UiStyle.stroke(pullBar, 2, BLACK, true)
pullBar.Parent = pullsBox
local pullFill = Instance.new("Frame")
pullFill.Size = UDim2.fromScale(0, 1)
pullFill.BackgroundColor3 = UiStyle.Colors.Gold
UiStyle.corner(pullFill, 4)
pullFill.Parent = pullBar

-- « +1 TIRAGE ! » qui s'envole sous la pastille quand la barre se remplit.
local function popPull(count: number)
	local pop = UiStyle.number(gui, string.format("+%d ŒUF%s !", count, if count > 1 then "S" else ""), 28, UiStyle.Colors.Gold)
	pop.AnchorPoint = Vector2.new(0.5, 0)
	pop.Position = UDim2.new(0.5, PULLS_WIDTH, 0, 66)
	pop.Size = UDim2.fromOffset(260, 34)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = pop
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local rise = TweenService:Create(pop, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, PULLS_WIDTH, 0, 40), TextTransparency = 1 })
	task.delay(0.35, function()
		rise:Play()
	end)
	task.delay(1.4, function()
		pop:Destroy()
	end)
	Sounds.play("HoleBonus")
end
local shownPulls = 0

-- Pile sous la pastille : chaque élément n'apparaît que lorsqu'il sert (pas de blocs vides empilés).
-- 26 oct. (retour des testeurs : « on ne voit plus rien ») : UNE seule ligne d'information sous l'horloge à la fois.
-- Ordre : consigne du familier porté, carte des tirages, consigne de phase, trou noir doré (client/GoldenHour),
-- protection (client/Newcomer), objectif
-- (client/NextGoals). Ces deux derniers demandent leur place par l'attribut "Wanted" ; le HUD décide de Visible.
local topStack = Instance.new("Frame")
topStack.Name = "TopStack"
topStack.BackgroundTransparency = 1
topStack.AnchorPoint = Vector2.new(0.5, 0)
topStack.Position = UDim2.new(0.5, 0, 0, 68)
topStack.Size = UDim2.fromOffset(620, 0)
topStack.AutomaticSize = Enum.AutomaticSize.Y
topStack.Parent = gui
do
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = topStack
end

-- Consigne : quelques secondes après chaque changement de phase, et en continu pendant le transport d'un familier.
local hintLabel = text(topStack, "", 18, WHITE, BODY_FONT)
hintLabel.Name = "Hint"
hintLabel.LayoutOrder = 2
hintLabel.Size = UDim2.new(1, 0, 0, 0)
hintLabel.AutomaticSize = Enum.AutomaticSize.Y
hintLabel.TextWrapped = true
hintLabel.Visible = false
local phaseChangedAt = 0

----------------------------------------------------------------------
-- Argent, stats et boutons de menu (PC : à gauche ; tactile : en haut à gauche, en tuiles)
----------------------------------------------------------------------

local STATS_HEIGHT = if isTouch then 100 else 178

local statsColumn = Instance.new("Frame")
statsColumn.Name = "Stats"
statsColumn.BackgroundTransparency = 1
statsColumn.AnchorPoint = if isTouch then Vector2.new(0, 0) else Vector2.new(0, 1)
statsColumn.Position = if isTouch then UDim2.new(0, 16, 0, 12) else UDim2.new(0, 16, 1, -12)
statsColumn.Size = UDim2.fromOffset(300, STATS_HEIGHT)
statsColumn.Parent = gui

local menuColumn = Instance.new("Frame")
menuColumn.Name = "Left"
menuColumn.BackgroundTransparency = 1
menuColumn.AnchorPoint = if isTouch then Vector2.new(0, 0) else Vector2.new(0, 0.5)
-- PC : 6 tuiles carrées 2 par 2 (3 rangées), un peu au-dessus du milieu, pour laisser la place aux stats en bas à
-- gauche même sur un écran bas (630 de haut). Tactile : 3 tuiles par rangée.
menuColumn.Position = if isTouch then UDim2.new(0, 16, 0, STATS_HEIGHT + 20) else UDim2.new(0, 16, 0.5, -105)
menuColumn.Size = if isTouch then UDim2.fromOffset(310, 196) else UDim2.fromOffset(202, 308)
menuColumn.Parent = gui

-- Ligne de stat d'entraînement : icône + « NV 13 » en italique + barre d'XP (plus petite sur tactile).
type StatRow = { label: TextLabel, fill: Frame }
local function statRow(x: number, y: number, icon: string, color: Color3): StatRow
	local iconSize = if isTouch then 30 else 42
	local textSize = if isTouch then 22 else 28
	local barWidth = if isTouch then 96 else 170
	Icons.image(statsColumn, icon, UDim2.fromOffset(iconSize, iconSize), UDim2.fromOffset(x - 2, y - 4))
	local label = UiStyle.number(statsColumn, "", textSize, color)
	label.Position = UDim2.fromOffset(x + iconSize, y)
	label.Size = UDim2.fromOffset(barWidth + 30, textSize + 4)
	label.TextXAlignment = Enum.TextXAlignment.Left
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(x + iconSize + 2, y + textSize + 5)
	bar.Size = UDim2.fromOffset(barWidth, if isTouch then 6 else 10)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	UiStyle.corner(bar, 4)
	UiStyle.stroke(bar, 2, BLACK, true)
	bar.Parent = statsColumn
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	UiStyle.corner(fill, 4)
	fill.Parent = bar
	return { label = label, fill = fill }
end
local strengthRow = if isTouch then statRow(0, 62, "Strength", UiStyle.Colors.Strength) else statRow(0, 0, "Strength", UiStyle.Colors.Strength)
local speedRow = if isTouch then statRow(150, 62, "Speed", UiStyle.Colors.Speed) else statRow(0, 48, "Speed", UiStyle.Colors.Speed)

local MONEY_Y = if isTouch then 0 else 96
Icons.image(statsColumn, "Money", if isTouch then UDim2.fromOffset(46, 46) else UDim2.fromOffset(62, 62), UDim2.fromOffset(-8, MONEY_Y - 2))
local moneyLabel = UiStyle.number(statsColumn, "$0", if isTouch then 38 else 52, MONEY)
moneyLabel.Position = UDim2.fromOffset(if isTouch then 42 else 56, MONEY_Y)
moneyLabel.Size = UDim2.new(1, -48, 0, if isTouch then 42 else 56)
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left

local incomeLabel = UiStyle.number(statsColumn, "+$0/s", if isTouch then 18 else 22, MONEY)
incomeLabel.Position = UDim2.fromOffset(if isTouch then 44 else 52, if isTouch then 40 else 150)
incomeLabel.Size = UDim2.new(1, -52, 0, if isTouch then 20 else 26)
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Bouton de menu (16 oct., façon packs « Studs UI ») : tuile colorée à tenons, grosse icône qui se balance, nom en bas.
-- PC : tuiles carrées 2 par 2 ; tactile : 3 tuiles par rangée. Pastille rouge.
local function menuButton(icon: string, name: string, index: number, color: Color3): (TextButton, TextLabel)
	local tile: TextButton
	if isTouch then
		tile = UiStyle.tile(menuColumn, icon, name, UDim2.fromOffset(92, 92), color, 18)
		tile.Position = UDim2.fromOffset(((index - 1) % 3) * 104, ((index - 1) // 3) * 104)
	else
		tile = UiStyle.tile(menuColumn, icon, name, UDim2.fromOffset(96, 96), color, 20)
		tile.Position = UDim2.fromOffset(((index - 1) % 2) * 106, ((index - 1) // 2) * 106)
	end
	return tile, UiStyle.badge(tile)
end

local shopButton, shopBadge = menuButton("Shop", "Boutique", 1, UiStyle.Colors.Green)
local indexButton, indexBadge = menuButton("Index", "Index", 2, UiStyle.Colors.Cyan)
local worldsButton, worldsBadge = menuButton("Planet", "Mondes", 3, Color3.fromRGB(95, 110, 255))
local bonusButton, bonusBadge = menuButton("Gift", "Bonus", 4, Color3.fromRGB(255, 196, 40))
local marketButton = menuButton("Money", "Marché", 5, Color3.fromRGB(60, 200, 120))
local rebirthButton, rebirthBadge = menuButton("Rebirth", "Rebirth", 6, Color3.fromRGB(170, 90, 255))
-- Rebirth : dégradé arc-en-ciel qui défile (comme la grande tuile « roue » des packs de référence).
do
	local rainbow = rebirthButton:FindFirstChildOfClass("UIGradient")
	if rainbow then
		rainbow.Rotation = 0
		rainbow.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 170, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 220, 70)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 255)),
		})
		TweenService:Create(rainbow, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Offset = Vector2.new(0.25, 0) }):Play()
		rainbow.Offset = Vector2.new(-0.25, 0)
	end
end

-- Inviter des amis (29 oct., Config.Invite) : bouton large sous les tuiles. Un ami qui arrive pour la 1re fois
-- rapporte des œufs aux deux (server/ProgressionController) ; chaque ami présent donne aussi +10 % de revenu.
local inviteButton: TextButton
do
	local tilesHeight = menuColumn.Size.Y.Offset
	local height = if isTouch then 40 else 46
	menuColumn.Size += UDim2.fromOffset(0, height + 10)
	inviteButton = UiStyle.button(menuColumn, "INVITER", UDim2.fromOffset(if isTouch then 300 else 202, height),
		Color3.fromRGB(255, 90, 160), if isTouch then 20 else 22)
	inviteButton.Name = "Invite"
	inviteButton.Position = UDim2.fromOffset(0, tilesHeight + 10)
	-- À droite, la récompense : « +2 » et un œuf (on comprend sans lire).
	local reward = UiStyle.number(inviteButton, "+" .. (Config.Invite.FriendReward.Pulls or 0), if isTouch then 18 else 20, WHITE)
	reward.AnchorPoint = Vector2.new(1, 0.5)
	reward.Position = UDim2.new(1, -(height - 4), 0.5, 0)
	reward.Size = UDim2.fromOffset(34, height - 12)
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward.ZIndex = 3
	Icons.image(inviteButton, "Egg", UDim2.fromOffset(height - 14, height - 14), UDim2.new(1, -(height - 8), 0, 5)).ZIndex = 3
	local caption = inviteButton:FindFirstChild("Caption") :: TextLabel
	caption.Position = UDim2.fromOffset(8, 6)
	caption.Size = UDim2.new(1, -height - 48, 1, -12)
end
local inviting = false
inviteButton.Activated:Connect(function()
	if inviting then
		return
	end
	inviting = true
	local ok, allowed = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and allowed then
		local options = Instance.new("ExperienceInviteOptions")
		local message = "Viens voler des familiers avec moi !"
		options.PromptMessage = if Lang.isFrench() then message else Lang.translate(message)
		pcall(function()
			SocialService:PromptGameInvite(player, options)
		end)
	else
		Sounds.play("Error")
		Toast.show("TU NE PEUX PAS INVITER D'AMIS ICI", UiStyle.Colors.Red)
	end
	inviting = false
end)

-- Ranger les tuiles de menu pour dégager la vue (26 oct.) : une poignée collée à droite des tuiles, « « » les fait
-- glisser hors de l'écran (les offres Robux de droite se cachent aussi), « » » les ramène. Touche M sur PC. Tuiles
-- rangées : la poignée garde la pastille « ! » si une tuile en avait une. Rien n'est sauvegardé (ouvertes à chaque partie).
local menusHidden = false
local MENU_OPEN = menuColumn.Position
local MENU_WIDTH = menuColumn.Size.X.Offset
local MENU_CLOSED = MENU_OPEN - UDim2.fromOffset(MENU_WIDTH + 40, 0)
local HANDLE_SIZE = if isTouch then Vector2.new(48, 92) else Vector2.new(42, 96)
-- En haut à droite des tuiles (PC : la colonne est centrée sur sa hauteur, d'où le décalage d'une demi-hauteur).
local handleTop = if isTouch then MENU_OPEN else MENU_OPEN - UDim2.fromOffset(0, menuColumn.Size.Y.Offset / 2)
local HANDLE_OPEN = handleTop + UDim2.fromOffset(MENU_WIDTH + 6, 0)
local HANDLE_CLOSED = UDim2.new(0, 6, handleTop.Y.Scale, handleTop.Y.Offset)
local menuHandle = UiStyle.button(gui, "«", UDim2.fromOffset(HANDLE_SIZE.X, HANDLE_SIZE.Y), Color3.fromRGB(80, 80, 110), 34, true)
menuHandle.Name = "MenuHandle"
menuHandle.Position = HANDLE_OPEN
UIJuice.button(menuHandle)
local handleCaption = menuHandle:FindFirstChild("Caption") :: TextLabel
local handleBadge = UiStyle.badge(menuHandle)
local function setMenusHidden(hidden: boolean)
	menusHidden = hidden
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Back, if hidden then Enum.EasingDirection.In else Enum.EasingDirection.Out)
	TweenService:Create(menuColumn, info, { Position = if hidden then MENU_CLOSED else MENU_OPEN }):Play()
	TweenService:Create(menuHandle, info, { Position = if hidden then HANDLE_CLOSED else HANDLE_OPEN }):Play()
	handleCaption.Text = if hidden then "»" else "«"
end
menuHandle.Activated:Connect(function()
	setMenusHidden(not menusHidden)
end)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		setMenusHidden(not menusHidden)
	end
end)
-- Pastille de la poignée : seulement tuiles rangées, si une tuile a quelque chose à montrer.
task.spawn(function()
	while menuHandle.Parent do
		local waiting = false
		for _, badge in ipairs({ shopBadge, indexBadge, worldsBadge, bonusBadge, rebirthBadge }) do
			waiting = waiting or badge.Visible
		end
		UiStyle.setBadge(handleBadge, if menusHidden and waiting then "!" else nil)
		task.wait(0.3)
	end
end)

----------------------------------------------------------------------
-- Fenêtres
----------------------------------------------------------------------

local shop = ShopMenu.create(gui, topStack)
local index = IndexMenu.create(gui)
local fusion = FusionMenu.create(gui)
local worlds = WorldMenu.create(gui)
local bonus = BonusMenu.create(gui)
-- Offres Robux à droite (PC seulement : sur tactile, le bouton de saut occupe le bas droit).
local offers = if isTouch then nil else OffersPanel.create(gui)
if offers then
	task.spawn(function()
		while true do
			task.wait(0.2)
			offers.setHidden(MenuKit.anyOpen() or menusHidden)
		end
	end)
end
local rebirth = RebirthMenu.create(gui)
local market = MarketMenu.create(gui)
-- Tant qu'une fenêtre est ouverte, la caméra zoome un peu derrière le flou (UI_UX_GUIDELINES.md §4).
UIJuice.followMenus(MenuKit.anyOpen)

shopButton.Activated:Connect(shop.window.toggle)
indexButton.Activated:Connect(index.window.toggle)
worldsButton.Activated:Connect(worlds.window.toggle)
bonusButton.Activated:Connect(bonus.window.toggle)
rebirthButton.Activated:Connect(rebirth.window.toggle)
marketButton.Activated:Connect(market.window.toggle)

----------------------------------------------------------------------
-- Carte de résultats des tirages (fin de manche)
----------------------------------------------------------------------

-- Petite carte dans la pile du haut. Elle ne ferme aucune fenêtre, disparaît seule (ou au clic). Les familiers
-- s'ouvrent en capsules en bas (client/PullReveal) puis tombent dans la base.
local REWARD_CARD_TIME = 7
local rewardCard = Instance.new("TextButton")
rewardCard.Name = "RewardCard"
rewardCard.LayoutOrder = 3
rewardCard.Size = UDim2.fromOffset(400, 40)
rewardCard.AutomaticSize = Enum.AutomaticSize.Y
rewardCard.BackgroundColor3 = UiStyle.Colors.WindowBody
rewardCard.AutoButtonColor = false
rewardCard.Text = ""
rewardCard.Visible = false
UiStyle.corner(rewardCard, 8)
UiStyle.stroke(rewardCard, 4, BLACK, true)
rewardCard.Parent = topStack
do
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = rewardCard
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = rewardCard
end
local rewardHeadline = text(rewardCard, "", 24, UiStyle.Colors.Gold)
rewardHeadline.Size = UDim2.new(1, 0, 0, 28)
rewardHeadline.LayoutOrder = 1
local rewardBody = text(rewardCard, "", 18)
rewardBody.Size = UDim2.new(1, 0, 0, 0)
rewardBody.AutomaticSize = Enum.AutomaticSize.Y
rewardBody.RichText = true
rewardBody.TextWrapped = true
rewardBody.LayoutOrder = 2
local rewardScale = Instance.new("UIScale")
rewardScale.Parent = rewardCard
rewardCard.Activated:Connect(function()
	rewardCard.Visible = false
end)

----------------------------------------------------------------------
-- Mise à jour
----------------------------------------------------------------------

local function petName(petId: unknown): string
	local entry = if type(petId) == "string" then PetCatalog.ById[petId] else nil
	return if entry then TextFormat.upper(entry.Name) else "LE FAMILIER"
end

local shownState: string? = nil
local function announcePhase(phase: typeof(PHASES.Feeding))
	phaseTitle.Text = phase.Title
	phaseTitle.TextColor3 = phase.Color
	phaseTitle.TextTransparency = 0
	phaseTitle.Visible = true
	phaseScale.Scale = 1.4
	phaseChangedAt = os.clock()
	TweenService:Create(phaseScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local shownAt = phaseChangedAt
	task.delay(2.4, function()
		if phaseChangedAt == shownAt then
			TweenService:Create(phaseTitle, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			task.delay(0.5, function()
				if phaseChangedAt == shownAt then
					phaseTitle.Visible = false
				end
			end)
		end
	end)
end

local function updatePhase()
	local state = ReplicatedStorage:GetAttribute("GameState")
	local remaining = ReplicatedStorage:GetAttribute("TimeRemaining")
	local stateName = if state == "Digesting" then "Digesting" else "Feeding"
	local phase = PHASES[stateName]
	if shownState ~= stateName then
		shownState = stateName
		announcePhase(phase)
	end

	-- Pendant le transport d'un familier, la consigne devient l'objectif + le temps restant.
	local carryingPet = player:GetAttribute("CarryingPet")
	local carryingUntil = player:GetAttribute("CarryingUntil")
	if carryingPet ~= nil and type(carryingUntil) == "number" then
		local left = math.max(0, math.ceil(carryingUntil - Workspace:GetServerTimeNow()))
		hintLabel.Text = if player:GetAttribute("CarryingOwn") == true
			then string.format("JETTE %s DANS LE TROU NOIR, OU RAMÈNE-LE CHEZ TOI  •  %d s", petName(carryingPet), left)
			else string.format("RAMÈNE %s DANS TA BASE, OU JETTE-LE DANS LE TROU !  •  %d s", petName(carryingPet), left)
		hintLabel.TextColor3 = UiStyle.Colors.Gold
		hintLabel.Visible = true
	else
		hintLabel.Text = phase.Hint
		hintLabel.TextColor3 = WHITE
		-- La consigne ne reste que quelques secondes (et laisse la place à la carte des tirages).
		hintLabel.Visible = os.clock() - phaseChangedAt < HINT_TIME and not rewardCard.Visible
	end
	-- Une seule ligne sous l'horloge : le trou noir doré (client/GoldenHour), la protection puis l'objectif, seulement
	-- si la place est libre.
	local taken = hintLabel.Visible or rewardCard.Visible
	for _, name in ipairs({ "GoldenHour", "TheftProtection", "NextGoals" }) do
		local line = topStack:FindFirstChild(name)
		if line and line:IsA("GuiObject") then
			line.Visible = line:GetAttribute("Wanted") == true and not taken
			taken = taken or line.Visible
		end
	end
	-- Les tirages de la manche ne comptent que pendant le Feeding : la pastille rétrécit pendant la digestion.
	local feeding = stateName == "Feeding"
	pullsBox.Visible = feeding
	clock.Size = UDim2.fromOffset(CLOCK_WIDTH + (if feeding then PULLS_WIDTH else 0), 56)

	local seconds = if type(remaining) == "number" then math.max(0, remaining) else 0
	clockIcon.Image = Icons.id(phase.Clock) or ""
	clockNext.Text = phase.Next
	clockLabel.Text = if seconds >= 60 then string.format("dans %d:%02d", seconds // 60, seconds % 60) else string.format("dans %d s", seconds)
	-- Les 10 dernières secondes : en rouge.
	clockLabel.TextColor3 = if seconds <= 10 then Color3.fromRGB(255, 70, 70) else WHITE
end

local function updateStats()
	local money = numberAttribute("Money")
	moneyLabel.Text = NumberFormat.money(money)
	incomeLabel.Text = NumberFormat.perSecond(numberAttribute("Income"))
	for _, row in ipairs({ { stat = "Speed", ui = speedRow }, { stat = "Strength", ui = strengthRow } }) do
		local level = numberAttribute(row.stat .. "Level")
		local needed = numberAttribute(row.stat .. "XPNeeded")
		-- Niveaux donnés par les familiers équipés (shared/PetStats) : « NV 13 +5 ».
		local bonus = numberAttribute(row.stat .. "Bonus")
		row.ui.label.Text = if bonus > 0 then string.format("NV %d +%d", level, bonus) else string.format("NV %d", level)
		row.ui.fill.Size = UDim2.fromScale(if needed > 0 then math.clamp(numberAttribute(row.stat .. "XP") / needed, 0, 1) else 1, 1)
	end
	-- Tirages déjà gagnés cette manche et avancement vers le suivant.
	local score = numberAttribute("RoundScore")
	local pulls, progress = LootEngine.progress(score)
	pointsLabel.Text = string.format("%d ŒUF%s", pulls, if pulls > 1 then "S" else "")
	TweenService:Create(pullFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1) }):Play()
	if pulls > shownPulls and dataReady() and ReplicatedStorage:GetAttribute("GameState") == "Feeding" then
		popPull(pulls - shownPulls)
	end
	shownPulls = pulls

	shop.refresh()
	index.refresh()
	if fusion.window.isOpen() then
		fusion.refresh()
	end
	UiStyle.setBadge(shopBadge, if shop.affordableCount() > 0 then "!" else nil)
	if worlds.window.isOpen() then
		worlds.refresh()
	end
	UiStyle.setBadge(worldsBadge, if worlds.canTravel() then "!" else nil)
	local claimable = MenuKit.claimableCount()
	UiStyle.setBadge(indexBadge, if claimable > 0 then tostring(claimable) else nil)
	if bonus.window.isOpen() then
		bonus.refresh()
	end
	local bonusReady = bonus.claimableCount()
	UiStyle.setBadge(bonusBadge, if bonusReady > 0 then tostring(bonusReady) else nil)
	if rebirth.window.isOpen() then
		rebirth.refresh()
	end
	UiStyle.setBadge(rebirthBadge, if rebirth.canRebirth() then "!" else nil)
end

-- Sauvegarde encore ouverte sur l'ancien serveur (on vient d'en changer) : le serveur attend qu'elle se libère.
player:GetAttributeChangedSignal("SaveWaiting"):Connect(function()
	if player:GetAttribute("SaveWaiting") == true then
		Toast.show("CHARGEMENT DE TA SAUVEGARDE... PATIENTE QUELQUES SECONDES", UiStyle.Colors.Gold)
	else
		Toast.show("SAUVEGARDE CHARGÉE !", MONEY)
	end
end)

-- Vol de familiers : messages pour le voleur (début du transport, puis résultat envoyé par le serveur).
player:GetAttributeChangedSignal("CarryingPet"):Connect(function()
	local petId = player:GetAttribute("CarryingPet")
	if petId ~= nil then
		-- Plus le familier est rare, plus on avance lentement, et jamais plus vite que son propriétaire (Config.Carry).
		local speed = player:GetAttribute("SpeedMultiplier")
		local percent = math.floor((if type(speed) == "number" then speed else 1) * 100 + 0.5)
		local heavy = if percent <= 50 then "TRÈS LOURD" elseif percent <= 75 then "LOURD" else "LÉGER"
		if player:GetAttribute("CarryingOwn") == true then
			Toast.show(string.format("TU PORTES %s  •  %s : VITESSE %d %%", petName(petId), heavy, percent), UiStyle.Colors.Gold)
		else
			Toast.show(string.format("VOLÉ ! %s  •  %s : VITESSE %d %%", petName(petId), heavy, percent), UiStyle.Colors.Gold)
		end
	end
	updatePhase() -- la consigne du bas devient l'objectif (ou redevient normale)
end)

local STEAL_MESSAGES: { [string]: { text: string, color: Color3 } } = {
	Success = { text = "%s EST À TOI !", color = MONEY },
	Home = { text = "%s EST DE RETOUR DANS TA BASE", color = MONEY },
	Dropped = { text = "LÂCHÉ ! %s RENTRE À SA BASE : RATTRAPE-LE !", color = Color3.fromRGB(255, 90, 90) },
	Timeout = { text = "TROP LENT ! %s T'ÉCHAPPE ET RENTRE À SA BASE", color = Color3.fromRGB(255, 90, 90) },
	VictimLeft = { text = "SON MAÎTRE EST PARTI : %s EST À TOI !", color = MONEY },
	Gone = { text = "PLUS LÀ : %s !", color = Color3.fromRGB(255, 90, 90) },
	Recovered = { text = "RATTRAPÉ ! IL A REPRIS %s", color = Color3.fromRGB(255, 90, 90) },
}

Remotes.StealResult.OnClientEvent:Connect(function(outcome: string, petId: string, money: number?, points: number?)
	local message = STEAL_MESSAGES[outcome]
	if outcome == "Sacrificed" then
		Toast.show(string.format("%s DÉVORÉ PAR LE TROU NOIR !  +%s  •  +%d POINTS", petName(petId),
			NumberFormat.money(money or 0), points or 0), UiStyle.Colors.Gold)
	elseif message then
		Toast.show(string.format(message.text, petName(petId)), message.color)
		if outcome == "Success" and (money or 0) > 0 then
			-- Couronne (Config.Crown) : tu as volé le roi du serveur.
			Toast.show("BONUS DU ROI : +" .. NumberFormat.money(money or 0) .. " !", UiStyle.Colors.Gold)
		end
	end
end)

-- Vol de familiers : messages pour la victime, et annonce à tout le serveur des vols rares.
local RECOVER_KEY = if isTouch then "TOUCHE REPRENDRE" else "APPUIE SUR [E]"

Remotes.StealNotice.OnClientEvent:Connect(function(kind: string, thiefName: string, victimName: string, petId: string)
	local thief = TextFormat.upper(thiefName)
	local pet = petName(petId)
	-- Les noms de familiers ont parfois un article ("Le Capybara Zen"), parfois non ("Chat") : tournures neutres.
	if kind == "Started" then
		Toast.show(string.format("ON TE VOLE %s ! RATTRAPE %s ET %s !", pet, thief, RECOVER_KEY), Color3.fromRGB(255, 90, 90))
	elseif kind == "Stolen" then
		Toast.show(string.format("VOLÉ PAR %s : %s !", thief, pet), Color3.fromRGB(255, 90, 90))
	elseif kind == "Recovered" then
		Toast.show(string.format("RÉCUPÉRÉ : %s !", pet), MONEY)
	elseif kind == "Returned" then
		Toast.show(string.format("DE RETOUR DANS TA BASE : %s !", pet), MONEY)
	elseif kind == "Dropped" then
		Toast.show(string.format("%s A LÂCHÉ %s : IL RENTRE À TA BASE, VA LE CHERCHER !", thief, pet), UiStyle.Colors.Gold)
	elseif kind == "Sacrificed" then
		Toast.show(string.format("%s A JETÉ %s DANS LE TROU NOIR !", thief, pet), Color3.fromRGB(255, 90, 90))
	elseif kind == "KeyUsed" then
		Toast.show(string.format("%s A OUVERT TA BASE AVEC UNE CLÉ ! (%d s)", thief, Config.Keys.Duration), Color3.fromRGB(255, 90, 90))
	elseif kind == "KeyOpened" then
		Toast.show(string.format("BASE OUVERTE PENDANT %d s : VOLE VITE !", Config.Keys.Duration), UiStyle.Colors.Gold)
	elseif kind == "Announce" then
		local entry = PetCatalog.ById[petId]
		local rarity = entry and Config.Rarities[Config.RarityIndex[entry.Rarity]]
		Toast.show(string.format("%s A VOLÉ %s À %s !", thief, pet, TextFormat.upper(victimName)), if rarity then rarity.Color else WHITE)
	elseif kind == "FriendStarted" then
		-- Vol chez un ami (Config.Friends) : tu peux le reprendre pour lui.
		Toast.show(string.format("VOL CHEZ TON AMI %s : RATTRAPE %s ET %s !", TextFormat.upper(victimName), thief, RECOVER_KEY),
			Color3.fromRGB(255, 90, 90))
	elseif kind == "Crowned" then
		-- Couronne du plus riche (Config.Crown, server/CrownController).
		if thiefName == player.DisplayName then
			Toast.show("TU ES LE ROI ! ARRÊTE LES VOLEURS : ÇA RAPPORTE !", UiStyle.Colors.Gold)
		else
			Toast.show(string.format("%s EST LE ROI : VOLE-LE POUR UN BONUS !", thief), UiStyle.Colors.Gold)
		end
	elseif kind == "CrownDefended" then
		Toast.show(string.format("%s A ARRÊTÉ %s : IL GARDE SA COURONNE !", TextFormat.upper(victimName), thief), UiStyle.Colors.Gold)
	elseif kind == "AnnounceSacrifice" then
		local entry = PetCatalog.ById[petId]
		local rarity = entry and Config.Rarities[Config.RarityIndex[entry.Rarity]]
		Toast.show(string.format("%s A JETÉ %s DE %s DANS LE TROU NOIR !", thief, pet, TextFormat.upper(victimName)),
			if rarity then rarity.Color else WHITE)
	end
end)

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
-- Résumé des tirages (server/PullRewards) : familiers gagnés (« NOUVEAU » en premier), doublons vendus, argent,
-- et le rang de tirage. Les capsules s'ouvrent en même temps en bas de l'écran (client/PullReveal).
local function showRewards(score: number, pulls: number, results: { [string]: number }, money: number?, details: any?)
	rewardToken += 1
	local token = rewardToken

	if pulls == 0 then
		rewardHeadline.Text = "IL A ENCORE FAIM..."
		rewardBody.Text = "JETTE-LUI DES OBJETS POUR GAGNER DES ŒUFS !"
	else
		local plural = if pulls > 1 then "S" else ""
		rewardHeadline.Text = if score == 0
			then string.format("%d ŒUF%s !", pulls, plural) -- tirages achetés en Robux ou gagnés en duel (un œuf par tirage)
			else string.format("%d ŒUF%s  •  %s POINTS", pulls, plural, (string.gsub(string.format("%.1f", score), "%.", ",")))
		local newIds: { [string]: boolean } = {}
		local soldCount, soldMoney = 0, 0
		local drops = if type(details) == "table" and type(details.drops) == "table" then details.drops else {}
		for _, drop in ipairs(drops) do
			if type(drop) == "table" and type(drop.Id) == "string" then
				if drop.New == true then
					newIds[drop.Id] = true
				end
				if type(drop.Sold) == "number" then
					soldCount += 1
					soldMoney += drop.Sold
				end
			end
		end
		-- Résumé court : les familiers eux-mêmes s'ouvrent en capsules en bas de l'écran (client/PullReveal).
		local newCount, keptCount = 0, 0
		for _, count in pairs(results) do
			keptCount += count
		end
		for _ in pairs(newIds) do
			newCount += 1
		end
		local parts = {}
		if type(details) == "table" and details.eggs and keptCount > 0 then
			table.insert(parts, string.format("%d ŒUF%s DANS TA BASE", keptCount, if keptCount > 1 then "S" else ""))
		elseif newCount > 0 then
			table.insert(parts, string.format('<font color="#FFD23C">%d NOUVEAU%s !</font>', newCount, if newCount > 1 then "X" else ""))
		end
		if not (type(details) == "table" and details.eggs) and keptCount > newCount then
			table.insert(parts, string.format("%d DÉJÀ EU%s", keptCount - newCount, if keptCount - newCount > 1 then "S" else ""))
		end
		if soldCount > 0 then
			table.insert(parts, string.format('%d EN TROP VENDU%s <font color="#%s">+%s</font>', soldCount, if soldCount > 1 then "S" else "",
				MONEY:ToHex(), NumberFormat.money(soldMoney)))
		end
		if money and money > soldMoney then
			table.insert(parts, string.format('<font color="#%s">+%s</font>', MONEY:ToHex(), NumberFormat.money(money - soldMoney)))
		end
		local lines = { table.concat(parts, "  •  ") }
		-- Rang de tirage : ce qui a disparu des tirages, et le prochain palier.
		local total = numberAttribute("TotalPulls")
		local rankIndex = LootEngine.rank(total)
		local nextRank = Config.Loot.Ranks[rankIndex + 1]
		local rankLine = "RANG " .. Config.Loot.Ranks[rankIndex].Name
		local floorIndex = if type(details) == "table" and type(details.floor) == "number" then details.floor else 1
		if floorIndex > 1 then
			rankLine ..= " : ŒUFS " .. TextFormat.upper(Config.Rarities[floorIndex].Name) .. " ET PLUS"
		end
		if nextRank then
			rankLine ..= string.format("  •  %d/%d ŒUFS → %s", total, nextRank.Pulls, nextRank.Name)
		end
		table.insert(lines, '<font color="#9BDCFF">' .. rankLine .. "</font>")
		-- Pitié par palier (Config.Loot.PityPercentile) : la rareté juste au-dessus de ta meilleure (attributs de PullRewards).
		local pityRarity = Config.Rarities[numberAttribute("PityTarget")]
		local pityAt = numberAttribute("PityAt")
		if pityRarity and pityAt > 0 then
			local pityLeft = math.max(1, pityAt - numberAttribute("Pity"))
			table.insert(lines, string.format('<font color="#%s">%s SÛR DANS %d ŒUF%s</font>', pityRarity.Color:ToHex(),
				TextFormat.upper(pityRarity.Name), pityLeft, if pityLeft > 1 then "S" else ""))
		end
		rewardBody.Text = table.concat(lines, "\n")
	end

	rewardCard.Visible = true
	hintLabel.Visible = false
	rewardScale.Scale = 0.6
	TweenService:Create(rewardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(REWARD_CARD_TIME, function()
		if token == rewardToken then
			rewardCard.Visible = false
			updatePhase()
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
	local mutation = if entry.Mutation then Config.Mutations[Config.MutationIndex[entry.Mutation]] else nil
	if mutation then
		Toast.show(string.format("INCROYABLE ! %s A OBTENU %s (%s) !", TextFormat.upper(playerName),
			TextFormat.upper(entry.Name), TextFormat.upper(rarity.Name)), mutation.Color)
		return
	end
	Toast.show(string.format("%s A OBTENU %s (%s) !", TextFormat.upper(playerName), TextFormat.upper(entry.Name), TextFormat.upper(rarity.Name)), rarity.Color)
end)

-- Fusion réussie : la chambre de la machine montre le nouveau familier.
Remotes.FusionResult.OnClientEvent:Connect(function(petId: string, egg: boolean?)
	local entry = PetCatalog.ById[petId]
	if not entry then
		return
	end
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
	fusion.showResult(petId, egg)
	Toast.show(if egg then "FUSION : ŒUF " .. TextFormat.upper(rarity.Name) .. " DANS TA BASE !" else string.format("FUSION : %s (%s) !", TextFormat.upper(entry.Name), TextFormat.upper(rarity.Name)), rarity.Color)
end)

-- Un joueur arrive dans un nouveau monde : grande célébration pour lui, annonce pour les autres.
Remotes.TierReached.OnClientEvent:Connect(function(traveller: Player, tier: number, revisit: boolean?)
	if typeof(traveller) ~= "Instance" or type(tier) ~= "number" then
		return
	end
	local world = Config.GetWorld(tier)
	if traveller == player then
		worlds.window.close()
		WorldMenu.celebrate(gui, tier, revisit == true)
	else
		Toast.show(string.format("%s VOYAGE VERS LE MONDE %s !", TextFormat.upper(traveller.DisplayName), TextFormat.upper(world.Name)), Color3.fromRGB(255, 180, 60))
	end
end)

-- Bonus (server/ProgressionController) : cadeau du jour, quêtes, codes, et Rebirths de tout le serveur.
local function rewardSummary(money: number?, pulls: number?): string
	local parts = {}
	if money and money > 0 then
		table.insert(parts, "+" .. NumberFormat.money(money))
	end
	if pulls and pulls > 0 then
		table.insert(parts, string.format("+%d ŒUF%s", pulls, if pulls > 1 then "S" else ""))
	end
	return table.concat(parts, "  •  ")
end
-- Notifications Roblox (Config.Notifications) : la fenêtre d'accord de Roblox s'ouvre juste après le cadeau du jour
-- (« reviens demain »), une fois par partie. Roblox ne l'affiche qu'aux 13 ans et plus, pas à qui a déjà accepté, et au
-- plus une fois tous les 30 jours.
local notifyAsked = false
local function askNotifications()
	if notifyAsked then
		return
	end
	notifyAsked = true
	task.delay(2.5, function()
		local ok, allowed = pcall(function()
			return ExperienceNotificationService:CanPromptOptInAsync()
		end)
		if ok and allowed then
			pcall(function()
				ExperienceNotificationService:PromptOptIn()
			end)
		end
	end)
end
Remotes.BonusResult.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any)
	if kind == "Daily" then
		Sounds.play("Coins")
		Toast.show(string.format("CADEAU DU JOUR %d : %s !", a, rewardSummary(b, c)), UiStyle.Colors.Gold)
		askNotifications()
	elseif kind == "Quest" then
		Sounds.play("Coins")
		Toast.show("QUÊTE TERMINÉE : " .. rewardSummary(b, c) .. " !", MONEY)
	elseif kind == "Code" then
		if a == true then
			Sounds.play("Coins")
			bonus.codeResult(true, "CODE " .. tostring(b) .. " : " .. rewardSummary(c, d) .. " !")
			Toast.show("CODE " .. tostring(b) .. " : " .. rewardSummary(c, d) .. " !", MONEY)
		else
			Sounds.play("Error")
			bonus.codeResult(false, tostring(b))
		end
	elseif kind == "Invited" then
		Sounds.play("Coins")
		Toast.show(if type(a) == "string" and a ~= ""
			then string.format("%s T'A INVITÉ : %s !", TextFormat.upper(a), rewardSummary(b, c))
			else "CADEAU DE BIENVENUE : " .. rewardSummary(b, c) .. " !", UiStyle.Colors.Gold)
	elseif kind == "Invite" then
		Sounds.play("Coins")
		Toast.show(string.format("%s EST VENU GRÂCE À TOI : %s !", TextFormat.upper(tostring(a)), rewardSummary(b, c)), UiStyle.Colors.Gold)
	elseif kind == "Rebirth" and typeof(a) == "Instance" and type(b) == "number" then
		if a == player then
			MenuKit.closeAll()
			RebirthMenu.celebrate(gui, b)
		else
			Toast.show(string.format("%s A FAIT UN REBIRTH (%d) !", TextFormat.upper((a :: Player).DisplayName), b),
				Color3.fromRGB(190, 130, 255))
		end
	end
	updateStats()
end)

-- Un ami Roblox arrive sur le serveur : bonus de revenu (Config.Friends).
-- Membre du groupe Roblox (Config.Group) : bonus de revenu.
player:GetAttributeChangedSignal("InGroup"):Connect(function()
	if player:GetAttribute("InGroup") == true then
		Toast.show(string.format("MEMBRE DU GROUPE : +%d %% DE REVENU !", math.floor(Config.Group.IncomeBonus * 100 + 0.5)), MONEY)
	end
end)

local lastFriends = numberAttribute("FriendsHere")
player:GetAttributeChangedSignal("FriendsHere"):Connect(function()
	local friends = numberAttribute("FriendsHere")
	if friends > lastFriends then
		local bonusPercent = math.floor(math.min(friends, Config.Friends.MaxFriends) * Config.Friends.BonusPerFriend * 100 + 0.5)
		Toast.show(string.format("UN AMI EST LÀ : +%d %% DE REVENU !", bonusPercent), MONEY)
	end
	lastFriends = friends
end)

-- Cadeau du jour à réclamer : la fenêtre s'ouvre toute seule une fois par session (après le tutoriel).
task.spawn(function()
	local started = os.clock()
	while player:GetAttribute("DataLoaded") ~= true and os.clock() - started < 15 do
		task.wait(0.5)
	end
	task.wait(4)
	while player:GetAttribute("TutorialDone") ~= true do
		task.wait(2)
	end
	if bonus.dailyReady() then
		bonus.openTab(1)
	end
end)

-- Récompenses d'Index accordées.
Remotes.IndexClaimed.OnClientEvent:Connect(function(money: number, count: number)
	local label = if count > 1 then string.format(" (%d FAMILIERS)", count) else ""
	Toast.show("INDEX : +" .. NumberFormat.money(money) .. label .. " !", MONEY)
end)

-- Bâtiments de la map (boutique, machine de fusion) : leur prompt "[E]" ouvre la fenêtre correspondante,
-- qui se ferme toute seule quand le joueur s'éloigne.
local promptWindows: { [string]: MenuKit.Window } = {
	Shop = shop.window,
	Fusion = fusion.window,
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

-- Beaucoup d'attributs changent à la fois (argent chaque seconde, chargement de la sauvegarde) :
-- une seule mise à jour par image.
local statsQueued = false
player.AttributeChanged:Connect(function()
	if statsQueued then
		return
	end
	statsQueued = true
	task.defer(function()
		statsQueued = false
		updateStats()
	end)
end)

-- Confirmation d'achat : le serveur écrit "Upgrade_<Id>" (niveau) quand l'achat est validé.
local STATION_HINTS: { [string]: string } = {
	Treadmill = " : À GAUCHE DE TA BASE !",
	Bench = " : À DROITE DE TA BASE !",
}

for _, item in ipairs(Config.Shop) do
	player:GetAttributeChangedSignal("Upgrade_" .. item.Id):Connect(function()
		local level = numberAttribute("Upgrade_" .. item.Id)
		if level <= 0 or not dataReady() then
			return
		end
		local message = if item.MaxLevel > 1 then string.format("%s NIVEAU %d !", TextFormat.upper(item.Name), level) else TextFormat.upper(item.Name) .. " DÉBLOQUÉ !"
		if level == 1 and STATION_HINTS[item.Id] then
			message = TextFormat.upper(item.Name) .. STATION_HINTS[item.Id]
		end
		Toast.show(message, MONEY)
	end)
end

-- Passage de niveau d'entraînement.
for _, stat in ipairs({ { id = "Speed", name = "VITESSE" }, { id = "Strength", name = "FORCE" } }) do
	local last = numberAttribute(stat.id .. "Level")
	player:GetAttributeChangedSignal(stat.id .. "Level"):Connect(function()
		local level = numberAttribute(stat.id .. "Level")
		if level > last and dataReady() then
			Toast.show(string.format("%s NIVEAU %d !", stat.name, level), UiStyle.Colors.Gold)
		end
		last = level
	end)
end

Remotes.RewardsGranted.OnClientEvent:Connect(showRewards)

-- Les vrais modèles 3D (shared/PetMeshes) viennent d'être chargés : les aperçus sont refaits.
PetModelBuilder.MeshesReady:Connect(index.rebuildViewports)

updatePhase()
updateStats()

-- Les icônes (shared/Icons) sont téléchargées tout de suite : les menus ne s'ouvrent pas avec des trous.
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync(Icons.all())
	end)
end)
