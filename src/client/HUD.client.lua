--!strict
-- HUD : l'écran de jeu, disposé comme la référence (docs/DIRECTION_ARTISTIQUE.md §3) :
--   - au milieu à gauche : gros boutons Boutique (vert) et Index (cyan) avec pastilles rouges ;
--   - en bas à gauche : Force, Vitesse et argent en gros chiffres italiques ;
--   - en bas à droite : l'horloge de la manche (lune = on nourrit le trou noir, soleil = il digère) ;
--   - en haut : bandeau de phase qui apparaît à chaque changement, points de la manche, carte des tirages ;
--   - en bas au centre : la consigne.
-- Les fenêtres sont dans client/ShopMenu, client/IndexMenu et client/FusionMenu (socle client/MenuKit).
-- Ce script relie tout aux attributs répliqués et aux messages du serveur.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local FusionMenu = require(script.Parent.FusionMenu)
local IndexMenu = require(script.Parent.IndexMenu)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local ShopMenu = require(script.Parent.ShopMenu)
local Toast = require(script.Parent.Toast)
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
		Next = "Digestion",
		Hint = if ScreenScale.isTouch()
			then "Touche RAMASSER sur un objet  •  maintiens LANCER pour viser  •  VOLE les familiers des bases ouvertes !"
			else "[E] ramasser  •  maintiens CLIC GAUCHE pour viser, relâche pour lancer  •  [E] sur un familier adverse pour le VOLER",
		Color = Color3.fromRGB(200, 120, 255),
	},
	Digesting = {
		Title = "LE TROU NOIR DIGÈRE...",
		Clock = "Sun",
		Next = "Repas",
		Hint = if ScreenScale.isTouch()
			then "Touche VOLER sur un familier d'une base ouverte  •  ferme ta base pour protéger les tiens !"
			else "Maintiens [E] sur un familier d'une base ouverte pour le VOLER  •  frappe les voleurs avec une arme (BOUTIQUE) !",
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

----------------------------------------------------------------------
-- Haut : bandeau de phase, points de la manche
----------------------------------------------------------------------

-- Bandeau : grand à chaque changement de phase, puis il remonte et rapetisse en titre discret.
local phaseTitle = text(gui, "", 44)
phaseTitle.AnchorPoint = Vector2.new(0.5, 0)
phaseTitle.Position = UDim2.new(0.5, 0, 0, 8)
phaseTitle.Size = UDim2.fromOffset(760, 50)
local phaseScale = Instance.new("UIScale")
phaseScale.Scale = 0.7
phaseScale.Parent = phaseTitle

local pointsPill = UiStyle.panel(gui, UDim2.fromOffset(230, 44))
pointsPill.AnchorPoint = Vector2.new(0.5, 0)
pointsPill.Position = UDim2.new(0.5, 0, 0, 62)
pointsPill.BackgroundColor3 = UiStyle.Colors.WindowBody
local pointsLabel = UiStyle.number(pointsPill, "", 28, UiStyle.Colors.Gold)
pointsLabel.Size = UDim2.fromScale(1, 1)

local hintLabel = text(gui, "", 18, WHITE, BODY_FONT)
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -18)
hintLabel.Size = UDim2.fromOffset(760, 24)

----------------------------------------------------------------------
-- Bas à droite : horloge de la manche
----------------------------------------------------------------------

local clock = Instance.new("Frame")
clock.Name = "Clock"
clock.BackgroundTransparency = 1
clock.AnchorPoint = Vector2.new(1, 1)
clock.Position = UDim2.new(1, -16, 1, -10)
clock.Size = UDim2.fromOffset(300, 80)
clock.Parent = gui
local clockIcon = Icons.image(clock, "Moon", UDim2.fromOffset(62, 62), UDim2.fromOffset(0, 16))
local clockNext = text(clock, "", 20, WHITE, BODY_FONT)
clockNext.Position = UDim2.fromOffset(64, 0)
clockNext.Size = UDim2.new(1, -64, 0, 24)
clockNext.TextXAlignment = Enum.TextXAlignment.Left
local clockLabel = UiStyle.number(clock, "", 40, WHITE)
clockLabel.Position = UDim2.fromOffset(64, 24)
clockLabel.Size = UDim2.new(1, -64, 0, 50)
clockLabel.TextXAlignment = Enum.TextXAlignment.Left

----------------------------------------------------------------------
-- Gauche : boutons de menu, stats et argent
----------------------------------------------------------------------

-- Sur tactile, tout est collé en haut à gauche (le joystick occupe le bas gauche).
local STATS_HEIGHT = 178

local statsColumn = Instance.new("Frame")
statsColumn.Name = "Stats"
statsColumn.BackgroundTransparency = 1
statsColumn.AnchorPoint = if isTouch then Vector2.new(0, 0) else Vector2.new(0, 1)
statsColumn.Position = if isTouch then UDim2.new(0, 16, 0, 10) else UDim2.new(0, 16, 1, -12)
statsColumn.Size = UDim2.fromOffset(260, STATS_HEIGHT)
statsColumn.Parent = gui

local menuColumn = Instance.new("Frame")
menuColumn.Name = "Left"
menuColumn.BackgroundTransparency = 1
menuColumn.AnchorPoint = if isTouch then Vector2.new(0, 0) else Vector2.new(0, 0.5)
menuColumn.Position = if isTouch then UDim2.new(0, 16, 0, STATS_HEIGHT + 20) else UDim2.new(0, 16, 0.5, -30)
menuColumn.Size = UDim2.fromOffset(220, 170)
menuColumn.Parent = gui

-- Ligne de stat d'entraînement : icône + « NV 13 » en italique + barre d'XP.
type StatRow = { label: TextLabel, fill: Frame }
local function statRow(y: number, icon: string, color: Color3): StatRow
	Icons.image(statsColumn, icon, UDim2.fromOffset(42, 42), UDim2.fromOffset(-2, y - 4))
	local label = UiStyle.number(statsColumn, "", 28, color)
	label.Position = UDim2.fromOffset(42, y)
	label.Size = UDim2.new(1, -42, 0, 32)
	label.TextXAlignment = Enum.TextXAlignment.Left
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(44, y + 33)
	bar.Size = UDim2.fromOffset(170, 10)
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
local strengthRow = statRow(0, "Strength", UiStyle.Colors.Strength)
local speedRow = statRow(48, "Speed", UiStyle.Colors.Speed)

Icons.image(statsColumn, "Money", UDim2.fromOffset(54, 54), UDim2.fromOffset(-4, 98))
local moneyLabel = UiStyle.number(statsColumn, "$0", 50, MONEY)
moneyLabel.Position = UDim2.fromOffset(48, 96)
moneyLabel.Size = UDim2.new(1, 0, 0, 56)
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left

local incomeLabel = UiStyle.number(statsColumn, "+$0/s", 22, MONEY)
incomeLabel.Position = UDim2.fromOffset(52, 150)
incomeLabel.Size = UDim2.new(1, -52, 0, 26)
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Gros bouton de menu : icône + nom, pastille rouge de notification.
local function menuButton(icon: string, name: string, y: number, color: Color3): (TextButton, TextLabel)
	local button = UiStyle.button(menuColumn, "", UDim2.fromOffset(210, 70), color, 1)
	button.Position = UDim2.fromOffset(0, y)
	local iconImage = Icons.image(button, icon, UDim2.fromOffset(62, 62), UDim2.fromOffset(2, 4))
	iconImage.ZIndex = 2
	local nameLabel = text(button, name, 32, WHITE, BODY_FONT)
	nameLabel.Position = UDim2.fromOffset(60, 0)
	nameLabel.Size = UDim2.new(1, -66, 1, 0)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 2
	return button, UiStyle.badge(button)
end

local shopButton, shopBadge = menuButton("Shop", "Boutique", 0, UiStyle.Colors.Green)
local indexButton, indexBadge = menuButton("Index", "Index", 88, UiStyle.Colors.Cyan)

----------------------------------------------------------------------
-- Fenêtres
----------------------------------------------------------------------

local shop = ShopMenu.create(gui)
local index = IndexMenu.create(gui)
local fusion = FusionMenu.create(gui)

shopButton.Activated:Connect(shop.window.toggle)
indexButton.Activated:Connect(index.window.toggle)

----------------------------------------------------------------------
-- Carte de résultats des tirages (fin de manche)
----------------------------------------------------------------------

-- Petite carte sous le bandeau (à la place des points, cachés pendant la digestion). Elle ne ferme aucune
-- fenêtre, glisse puis disparaît seule (ou au clic). Les familiers, eux, tombent dans la base.
local REWARD_CARD_TIME = 5
local rewardCard = Instance.new("TextButton")
rewardCard.Name = "RewardCard"
rewardCard.AnchorPoint = Vector2.new(0.5, 0)
rewardCard.Position = UDim2.new(0.5, 0, 0, 62)
rewardCard.Size = UDim2.fromOffset(380, 60)
rewardCard.AutomaticSize = Enum.AutomaticSize.Y
rewardCard.BackgroundColor3 = UiStyle.Colors.WindowBody
rewardCard.AutoButtonColor = false
rewardCard.Text = ""
rewardCard.Visible = false
UiStyle.corner(rewardCard, 8)
UiStyle.stroke(rewardCard, 4, BLACK, true)
rewardCard.Parent = gui
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
local rewardBody = text(rewardCard, "", 20)
rewardBody.Size = UDim2.new(1, 0, 0, 0)
rewardBody.AutomaticSize = Enum.AutomaticSize.Y
rewardBody.RichText = true
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
	phaseScale.Scale = 1.5
	TweenService:Create(phaseScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1.2 }):Play()
	task.delay(2.2, function()
		if phaseTitle.Text == phase.Title then
			TweenService:Create(phaseScale, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Scale = 0.7 }):Play()
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

	-- Pendant le transport d'un familier volé, la consigne devient l'objectif + le temps restant.
	local carryingPet = player:GetAttribute("CarryingPet")
	local carryingUntil = player:GetAttribute("CarryingUntil")
	if carryingPet ~= nil and type(carryingUntil) == "number" then
		local left = math.max(0, math.ceil(carryingUntil - Workspace:GetServerTimeNow()))
		hintLabel.Text = string.format("RAMÈNE %s DANS TA BASE !  %d s", petName(carryingPet), left)
		hintLabel.TextColor3 = UiStyle.Colors.Gold
	else
		hintLabel.Text = phase.Hint
		hintLabel.TextColor3 = WHITE
	end
	pointsPill.Visible = stateName == "Feeding" and not rewardCard.Visible

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
		row.ui.label.Text = string.format("NV %d", level)
		row.ui.fill.Size = UDim2.fromScale(if needed > 0 then math.clamp(numberAttribute(row.stat .. "XP") / needed, 0, 1) else 1, 1)
	end
	pointsLabel.Text = string.format("POINTS  %.1f", numberAttribute("RoundScore"))

	shop.refresh()
	index.refresh()
	if fusion.window.isOpen() then
		fusion.refresh()
	end
	UiStyle.setBadge(shopBadge, if shop.affordableCount() > 0 then "!" else nil)
	local claimable = MenuKit.claimableCount()
	UiStyle.setBadge(indexBadge, if claimable > 0 then tostring(claimable) else nil)
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
		Toast.show(string.format("VOLÉ ! RAMÈNE %s DANS TA BASE !", petName(petId)), UiStyle.Colors.Gold)
	end
	updatePhase() -- la consigne du bas devient l'objectif (ou redevient normale)
end)

local STEAL_MESSAGES: { [string]: { text: string, color: Color3 } } = {
	Success = { text = "%s EST À TOI !", color = MONEY },
	KO = { text = "LÂCHÉ ! RETOUR À SA BASE : %s", color = Color3.fromRGB(255, 90, 90) },
	Timeout = { text = "TROP LENT ! RETOUR À SA BASE : %s", color = Color3.fromRGB(255, 90, 90) },
	VictimLeft = { text = "SON PROPRIÉTAIRE A FUI : %s EST À TOI !", color = MONEY },
	Gone = { text = "PLUS LÀ : %s !", color = Color3.fromRGB(255, 90, 90) },
	Recovered = { text = "RATTRAPÉ ! SON PROPRIÉTAIRE A REPRIS : %s", color = Color3.fromRGB(255, 90, 90) },
}

Remotes.StealResult.OnClientEvent:Connect(function(outcome: string, petId: string)
	local message = STEAL_MESSAGES[outcome]
	if message then
		Toast.show(string.format(message.text, petName(petId)), message.color)
	end
end)

-- Vol de familiers : messages pour la victime, et annonce à tout le serveur des vols rares.
local RECOVER_KEY = if isTouch then "TOUCHE REPRENDRE" else "APPUIE SUR [E]"

Remotes.StealNotice.OnClientEvent:Connect(function(kind: string, thiefName: string, victimName: string, petId: string)
	local thief = TextFormat.upper(thiefName)
	local pet = petName(petId)
	-- Les noms de familiers ont parfois un article ("Le Capybara Zen"), parfois non ("Chat") : tournures neutres.
	if kind == "Started" then
		Toast.show(string.format("VOL EN COURS : %s ! RATTRAPE %s ET %s !", pet, thief, RECOVER_KEY), Color3.fromRGB(255, 90, 90))
	elseif kind == "Stolen" then
		Toast.show(string.format("VOLÉ PAR %s : %s !", thief, pet), Color3.fromRGB(255, 90, 90))
	elseif kind == "Recovered" then
		Toast.show(string.format("RÉCUPÉRÉ : %s !", pet), MONEY)
	elseif kind == "Returned" then
		Toast.show(string.format("DE RETOUR DANS TA BASE : %s !", pet), MONEY)
	elseif kind == "KeyUsed" then
		Toast.show(string.format("%s A OUVERT TA BASE AVEC UNE CLÉ ! (%d s)", thief, Config.Keys.Duration), Color3.fromRGB(255, 90, 90))
	elseif kind == "KeyOpened" then
		Toast.show(string.format("BASE OUVERTE PENDANT %d s : VOLE VITE !", Config.Keys.Duration), UiStyle.Colors.Gold)
	elseif kind == "Announce" then
		local entry = PetCatalog.ById[petId]
		local rarity = entry and Config.Rarities[Config.RarityIndex[entry.Rarity]]
		Toast.show(string.format("%s A VOLÉ %s À %s !", thief, pet, TextFormat.upper(victimName)), if rarity then rarity.Color else WHITE)
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
local function showRewards(score: number, pulls: number, results: { [string]: number }, money: number?)
	rewardToken += 1
	local token = rewardToken

	if pulls == 0 then
		rewardHeadline.Text = "IL A ENCORE FAIM..."
		rewardBody.Text = "0 POINT CETTE MANCHE"
	else
		local plural = if pulls > 1 then "S" else ""
		rewardHeadline.Text = if score == 0
			then string.format("%d TIRAGE%s !", pulls, plural) -- tirages achetés en Robux (pas de points de manche)
			else string.format("%.1f POINTS  •  %d TIRAGE%s", score, pulls, plural)
		-- Familiers gagnés, du plus rare au plus commun (4 lignes max).
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
		for order, drop in ipairs(drops) do
			if order > 4 then
				table.insert(lines, string.format("+ %d AUTRES...", #drops - 4))
				break
			end
			local rarity = Config.Rarities[drop.rank]
			table.insert(lines, string.format('<font color="#%s">+%d %s</font>', rarity.Color:ToHex(), drop.count, TextFormat.upper(drop.entry.Name)))
		end
		if money and money > 0 then
			table.insert(lines, string.format('<font color="#%s">+%s</font>', MONEY:ToHex(), NumberFormat.money(money)))
		end
		rewardBody.Text = table.concat(lines, "\n")
	end

	rewardCard.Visible = true
	pointsPill.Visible = false
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
	Toast.show(string.format("%s A OBTENU %s (%s) !", TextFormat.upper(playerName), TextFormat.upper(entry.Name), TextFormat.upper(rarity.Name)), rarity.Color)
end)

-- Fusion réussie : la chambre de la machine montre le nouveau familier.
Remotes.FusionResult.OnClientEvent:Connect(function(petId: string)
	local entry = PetCatalog.ById[petId]
	if not entry then
		return
	end
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
	fusion.showResult(petId)
	Toast.show(string.format("FUSION : %s (%s) !", TextFormat.upper(entry.Name), TextFormat.upper(rarity.Name)), rarity.Color)
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
-- Au chargement de la sauvegarde, niveaux et améliorations passent de 0 à leur valeur : pas de message pour ça.
-- On attend que la sauvegarde soit chargée (ou 8 s si elle ne se charge pas, ex. Studio sans accès API).
local hudStarted = os.clock()
local function dataReady(): boolean
	return player:GetAttribute("DataLoaded") == true or os.clock() - hudStarted > 8
end

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
