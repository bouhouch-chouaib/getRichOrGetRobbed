--!strict
-- DuelClient : le côté joueur des duels de familiers (server/DuelController, Config.Duel).
--   - Bulle [F] « Défier en duel » sur les autres joueurs (créée ici, localement).
--   - Invitation reçue : ACCEPTER / REFUSER.
--   - Fenêtre DUEL DE FAMILIERS : on choisit un de ses familiers (raretés proches de celui de l'adversaire), on voit le
--     choix de l'autre et ses PV / attaque, puis PRÊT (les deux doivent valider ; changer de familier annule).
--   - Combat : caméra sur l'arène, gros bouton « ENCOURAGE ! » (ou clic n'importe où) qui augmente les dégâts.
--   - Résultat, roue (animée par client/DuelFx) et récompense ; messages pour tout le serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DuelStats = require(ReplicatedStorage.Shared.DuelStats)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local DUEL = Config.Duel
local player = Players.LocalPlayer
local RED = Color3.fromRGB(255, 90, 90)
local WHITE = Color3.new(1, 1, 1)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Duel"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- comme le HUD : le contenu des fenêtres passe devant leur fond
screenGui.Parent = player:WaitForChild("PlayerGui")
local gui = ScreenScale.attach(screenGui)

local function petName(petId: string?): string
	local entry = if petId then PetCatalog.ById[petId] else nil
	return if entry then TextFormat.upper(entry.Name) else "?"
end

local function rarityColor(petId: string): Color3
	local entry = PetCatalog.ById[petId]
	return if entry then Config.Rarities[Config.RarityIndex[entry.Rarity] or 1].Color else WHITE
end

local function action(name: string, arg: any?)
	Remotes.DuelAction:FireServer(name, arg)
end

-- État local
local phase = "Idle" -- "Idle", "Waiting", "Invited", "Pick", "Fight", "After"
local opponent: Player? = nil
local myPick: string? = nil
local myReady = false
local otherPick: string? = nil
local otherReady = false
local deadline = 0

----------------------------------------------------------------------
-- Bulles « Défier » sur les autres joueurs
----------------------------------------------------------------------

local prompts: { [Player]: ProximityPrompt } = {}

local function attachPrompt(other: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	local old = prompts[other]
	if old then
		old:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DuelPrompt"
	prompt.ActionText = "Défier en duel"
	prompt.ObjectText = other.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = DUEL.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, 60) -- sous la bulle « Reprendre » éventuelle
	prompt.Triggered:Connect(function()
		action("Request", other)
	end)
	prompt.Parent = root
	prompts[other] = prompt
end

local function watchPlayer(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(character)
		attachPrompt(other, character)
	end)
	if other.Character then
		task.spawn(attachPrompt, other, other.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in ipairs(Players:GetPlayers()) do
	watchPlayer(other)
end
Players.PlayerRemoving:Connect(function(other)
	local prompt = prompts[other]
	if prompt then
		prompt:Destroy()
		prompts[other] = nil
	end
end)

----------------------------------------------------------------------
-- Invitation
----------------------------------------------------------------------

local invite = UiStyle.panel(gui, UDim2.fromOffset(520, 150))
invite.AnchorPoint = Vector2.new(0.5, 0)
invite.Position = UDim2.new(0.5, 0, 0, 190)
invite.BackgroundColor3 = UiStyle.Colors.WindowBody
invite.Visible = false
local inviteText = UiStyle.text(invite, "", 26, UiStyle.Colors.Orange)
inviteText.Position = UDim2.fromOffset(12, 8)
inviteText.Size = UDim2.new(1, -24, 0, 60)
inviteText.TextWrapped = true
local inviteTimer = UiStyle.text(invite, "", 18, WHITE)
inviteTimer.Position = UDim2.fromOffset(12, 64)
inviteTimer.Size = UDim2.new(1, -24, 0, 20)
local acceptButton = UiStyle.button(invite, "ACCEPTER", UDim2.fromOffset(220, 48), UiStyle.Colors.Green, 26)
acceptButton.Position = UDim2.fromOffset(28, 92)
local declineButton = UiStyle.button(invite, "REFUSER", UDim2.fromOffset(220, 48), UiStyle.Colors.Red, 26)
declineButton.Position = UDim2.new(1, -248, 0, 92)
acceptButton.Activated:Connect(function()
	invite.Visible = false
	action("Answer", true)
end)
declineButton.Activated:Connect(function()
	invite.Visible = false
	action("Answer", false)
	phase = "Idle"
end)

----------------------------------------------------------------------
-- Fenêtre de choix
----------------------------------------------------------------------

local window = MenuKit.window(gui, "Duel de familiers", Vector2.new(860, 540), UiStyle.Colors.Orange)
local content = window.content

local grid = Instance.new("ScrollingFrame")
grid.Size = UDim2.new(0, 470, 1, -70)
grid.Position = UDim2.fromOffset(0, 0)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 8
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.Parent = content
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(108, 136)
layout.CellPadding = UDim2.fromOffset(8, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

local rules = UiStyle.text(content, "Une rareté d'écart au maximum. Le gagnant tourne la roue : 1 case sur 8 = il repart avec ton familier !", 16, UiStyle.Colors.Gold)
rules.Position = UDim2.new(0, 0, 1, -64)
rules.Size = UDim2.new(0, 470, 0, 40)
rules.TextWrapped = true

-- Colonne de droite : les deux familiers choisis.
type Card = { frame: Frame, head: TextLabel, holder: Frame, name: TextLabel, stats: TextLabel, status: TextLabel }
local function sideCard(title: string, y: number): Card
	local frame = UiStyle.panel(content, UDim2.fromOffset(330, 190))
	frame.Position = UDim2.fromOffset(490, y)
	local head = UiStyle.text(frame, title, 22, WHITE)
	head.Position = UDim2.fromOffset(10, 4)
	head.Size = UDim2.new(1, -20, 0, 28)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(8, 34)
	holder.Size = UDim2.fromOffset(140, 140)
	holder.Parent = frame
	local name = UiStyle.text(frame, "?", 20, WHITE)
	name.Position = UDim2.fromOffset(156, 40)
	name.Size = UDim2.new(1, -164, 0, 50)
	name.TextWrapped = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	local stats = UiStyle.text(frame, "", 18, UiStyle.Colors.Gold)
	stats.Position = UDim2.fromOffset(156, 96)
	stats.Size = UDim2.new(1, -164, 0, 26)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	local status = UiStyle.text(frame, "", 20, WHITE)
	status.Position = UDim2.fromOffset(156, 132)
	status.Size = UDim2.new(1, -164, 0, 30)
	status.TextXAlignment = Enum.TextXAlignment.Left
	return { frame = frame, head = head, holder = holder, name = name, stats = stats, status = status }
end
local myCard = sideCard("TOI", 0)
local otherCard = sideCard("ADVERSAIRE", 200)
local timerLabel = UiStyle.text(content, "", 18, WHITE)
timerLabel.Position = UDim2.fromOffset(490, 396)
timerLabel.Size = UDim2.fromOffset(330, 22)
local readyButton = UiStyle.button(content, "PRÊT !", UDim2.fromOffset(200, 54), UiStyle.Colors.Green, 28)
readyButton.Position = UDim2.new(0, 490, 1, -62)
local readyCaption = readyButton:FindFirstChild("Caption") :: TextLabel
local cancelButton = UiStyle.button(content, "ANNULER", UDim2.fromOffset(120, 54), UiStyle.Colors.Red, 22)
cancelButton.Position = UDim2.new(0, 700, 1, -62)

local shownPets: { [Card]: string? } = {}
local function showPet(card: Card, petId: string?, ready: boolean, mine: boolean)
	if shownPets[card] ~= petId then
		shownPets[card] = petId
		for _, child in ipairs(card.holder:GetChildren()) do
			child:Destroy()
		end
		if petId then
			local viewport = MenuKit.petViewport(card.holder, petId, false)
			viewport.Size = UDim2.fromScale(1, 1)
		end
	end
	if petId then
		local hp, attack = DuelStats.of(petId)
		card.name.Text = petName(petId)
		card.name.TextColor3 = rarityColor(petId)
		card.stats.Text = string.format("PV %d  •  ATT %d", hp, attack)
	else
		card.name.Text = if mine then "CHOISIS UN FAMILIER" else "IL CHOISIT..."
		card.name.TextColor3 = WHITE
		card.stats.Text = ""
	end
	card.status.Text = if ready then "PRÊT !" else "PAS PRÊT"
	card.status.TextColor3 = if ready then UiStyle.Colors.Green else RED
end

-- Les cartes sont construites une seule fois par liste de familiers (les aperçus 3D ne clignotent pas) ;
-- à chaque changement, seul leur style est mis à jour (choisie, compatible ou grisée).
type GridCard = { card: TextButton, viewport: ViewportFrame, name: TextLabel }
local gridCards: { [string]: GridCard } = {}
local gridKey = ""

local function styleGrid()
	for petId, entry in pairs(gridCards) do
		local allowed = otherPick == nil or DuelStats.compatible(petId, otherPick)
		entry.card.BackgroundColor3 = if petId == myPick then UiStyle.Colors.Orange else UiStyle.Colors.Panel
		entry.card.BackgroundTransparency = if allowed then 0 else 0.5
		entry.viewport.ImageTransparency = if allowed then 0 else 0.6
		entry.name.TextTransparency = if allowed then 0 else 0.5
	end
end

local function refreshGrid()
	local list: { string } = {}
	-- Everything : les espèces et leurs formes évoluées (machine d'évolution).
	for _, entry in ipairs(PetCatalog.Everything) do
		if MenuKit.spare(entry.Id) > 0 then
			table.insert(list, entry.Id)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = DuelStats.rarity(a), DuelStats.rarity(b)
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	local key = table.concat(list, ",")
	if key == gridKey then
		styleGrid()
		return
	end
	gridKey = key
	table.clear(gridCards)
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #list == 0 then
		local empty = UiStyle.text(grid, "Tu n'as aucun familier dans ta base (un familier équipé ne peut pas combattre).", 20, WHITE)
		empty.Size = UDim2.fromOffset(440, 80)
		empty.TextWrapped = true
		return
	end
	for order, petId in ipairs(list) do
		local card = Instance.new("TextButton")
		card.Text = ""
		card.LayoutOrder = order
		card.AutoButtonColor = false
		UiStyle.corner(card, 6)
		UiStyle.stroke(card, 3, rarityColor(petId), true)
		card.Parent = grid
		local viewport = MenuKit.petViewport(card, petId, false)
		viewport.Size = UDim2.fromOffset(96, 84)
		viewport.Position = UDim2.fromOffset(6, 4)
		local name = UiStyle.text(card, petName(petId), 13, rarityColor(petId))
		name.Position = UDim2.fromOffset(2, 88)
		name.Size = UDim2.new(1, -4, 0, 26)
		name.TextWrapped = true
		local hp, attack = DuelStats.of(petId)
		local stats = UiStyle.text(card, string.format("PV %d  ATT %d", hp, attack), 12, WHITE)
		stats.Position = UDim2.fromOffset(2, 114)
		stats.Size = UDim2.new(1, -4, 0, 18)
		gridCards[petId] = { card = card, viewport = viewport, name = name }
		card.Activated:Connect(function()
			if otherPick == nil or DuelStats.compatible(petId, otherPick) then
				Sounds.play("UiClick")
				action("Pick", petId)
			else
				Toast.show("RARETÉ TROP ÉLOIGNÉE DE SON FAMILIER (1 RARETÉ D'ÉCART MAX)", RED)
			end
		end)
	end
	styleGrid()
end

local function refreshWindow()
	showPet(myCard, myPick, myReady, true)
	showPet(otherCard, otherPick, otherReady, false)
	local other = opponent
	otherCard.head.Text = if other then TextFormat.upper(other.DisplayName) else "ADVERSAIRE"
	readyCaption.Text = if myReady then "ANNULER PRÊT" else "PRÊT !"
	refreshGrid()
end

readyButton.Activated:Connect(function()
	if not myPick or not otherPick then
		Toast.show(if myPick then "ATTENDS LE CHOIX DE TON ADVERSAIRE" else "CHOISIS D'ABORD UN FAMILIER", UiStyle.Colors.Gold)
		return
	end
	action("Ready", not myReady)
end)

local closingByScript = false
local function closeWindow()
	closingByScript = true
	window.close()
	closingByScript = false
end
cancelButton.Activated:Connect(function()
	action("Cancel")
end)
-- Fermer la fenêtre (X) pendant le choix = annuler le duel.
window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not window.frame.Visible and not closingByScript and phase == "Pick" then
		action("Cancel")
	end
end)

----------------------------------------------------------------------
-- Combat : caméra et encouragements
----------------------------------------------------------------------

local cheerButton = UiStyle.button(gui, "ENCOURAGE TON FAMILIER !", UDim2.fromOffset(420, 70), UiStyle.Colors.Orange, 30)
cheerButton.AnchorPoint = Vector2.new(0.5, 1)
cheerButton.Position = UDim2.new(0.5, 0, 1, -ScreenScale.BOTTOM_RESERVED)
cheerButton.Visible = false
local cheerHint = UiStyle.text(cheerButton, "Clique vite : chaque clic augmente ses dégâts !", 16, UiStyle.Colors.Gold)
cheerHint.AnchorPoint = Vector2.new(0.5, 0)
cheerHint.Position = UDim2.new(0.5, 0, 1, 4)
cheerHint.Size = UDim2.new(1.4, 0, 0, 22)
local cheerScale = Instance.new("UIScale")
cheerScale.Parent = cheerButton

local banner = UiStyle.text(gui, "", 64, WHITE)
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.35)
banner.Size = UDim2.fromOffset(900, 90)
banner.Visible = false
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner

local function showBanner(text: string, color: Color3, hold: number)
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	bannerScale.Scale = 0.3
	TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local shown = text
	task.delay(hold, function()
		if banner.Text == shown then
			banner.Visible = false
		end
	end)
end

local lastCheer = 0
local function cheer()
	if phase ~= "Fight" then
		return
	end
	local t = os.clock()
	if t - lastCheer < 1 / 12 then
		return
	end
	lastCheer = t
	action("Cheer")
	cheerScale.Scale = 1.12
	TweenService:Create(cheerScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
end
cheerButton.Activated:Connect(cheer)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		cheer()
	end
end)

local arenaCenter: Vector3? = nil
local mySide = "A"
RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	local center = arenaCenter
	if center and camera and (phase == "Fight" or phase == "After") then
		camera.CameraType = Enum.CameraType.Scriptable
		-- Vue de face : les deux familiers, la roue derrière ; légèrement du côté du joueur.
		local side = if mySide == "A" then -1 else 1
		camera.CFrame = CFrame.lookAt(center + Vector3.new(side * 5, 10, 31), center + Vector3.new(0, 7, -6))
	end
	-- Bulles « Défier » : seulement si on est libre et l'autre aussi.
	local free = phase == "Idle" and player:GetAttribute("CarryingPet") == nil and player:GetAttribute("InDuel") == nil
		and player:GetAttribute("InTrade") == nil
	for other, prompt in pairs(prompts) do
		local enabled = free and other:GetAttribute("InDuel") == nil and other:GetAttribute("InTrade") == nil
		if prompt.Enabled ~= enabled then
			prompt.Enabled = enabled
		end
	end
	if invite.Visible then
		inviteTimer.Text = string.format("%d s pour répondre", math.max(0, math.ceil(deadline - Workspace:GetServerTimeNow())))
	end
	if window.isOpen() then
		timerLabel.Text = string.format("Temps pour choisir : %d s", math.max(0, math.ceil(deadline - Workspace:GetServerTimeNow())))
	end
end)

-- Pendant le duel, le HUD (argent, boutons, horloge) est caché : on voit l'arène et la roue en entier.
local function setHudVisible(visible: boolean)
	for _, name in ipairs({ "HUD", "Tutorial" }) do
		local hud = player.PlayerGui:FindFirstChild(name)
		if hud and hud:IsA("ScreenGui") then
			hud.Enabled = visible
		end
	end
end

local function backToNormal()
	setHudVisible(true)
	phase = "Idle"
	opponent = nil
	myPick, otherPick, myReady, otherReady = nil, nil, false, false
	arenaCenter = nil
	cheerButton.Visible = false
	invite.Visible = false
	closeWindow()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- Le serveur remet le joueur à sa place à la fin : on rend la caméra.
player:GetAttributeChangedSignal("InDuel"):Connect(function()
	if player:GetAttribute("InDuel") == nil and (phase == "Fight" or phase == "After") then
		task.delay(0.1, backToNormal)
	end
end)

----------------------------------------------------------------------
-- Événements du serveur
----------------------------------------------------------------------

local CANCEL_MESSAGES: { [string]: string } = {
	Declined = "DUEL REFUSÉ",
	Timeout = "DUEL ANNULÉ : TEMPS ÉCOULÉ",
	Busy = "CE JOUEUR EST OCCUPÉ",
	Cooldown = "ATTENDS UN PEU AVANT DE DÉFIER À NOUVEAU",
	ArenaFull = "TOUTES LES ARÈNES SONT PRISES, RÉESSAIE DANS UN INSTANT",
	PetGone = "UN DES FAMILIERS N'EST PLUS DISPONIBLE",
	Cancelled = "DUEL ANNULÉ",
	Left = "L'ADVERSAIRE EST PARTI",
}

Remotes.DuelEvent.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any, e: any)
	if kind == "Invite" and typeof(a) == "Instance" and a:IsA("Player") then
		phase = "Invited"
		opponent = a
		deadline = if type(b) == "number" then b else Workspace:GetServerTimeNow() + DUEL.InviteTime
		inviteText.Text = string.format("%s TE DÉFIE EN DUEL DE FAMILIERS !", TextFormat.upper(a.DisplayName))
		invite.Visible = true
		Sounds.play("WindowOpen")
	elseif kind == "Waiting" and typeof(a) == "Instance" and a:IsA("Player") then
		phase = "Waiting"
		opponent = a
		Toast.show(string.format("DÉFI ENVOYÉ À %s...", TextFormat.upper(a.DisplayName)), UiStyle.Colors.Gold)
	elseif kind == "Cancelled" and type(a) == "string" then
		if a == "RarityGap" then
			Toast.show("RARETÉ TROP ÉLOIGNÉE DE SON FAMILIER (1 RARETÉ D'ÉCART MAX)", RED)
			return
		end
		Toast.show(CANCEL_MESSAGES[a] or "DUEL ANNULÉ", RED)
		if phase ~= "Fight" and phase ~= "After" then
			backToNormal()
		end
	elseif kind == "Pick" and typeof(a) == "Instance" and a:IsA("Player") then
		phase = "Pick"
		gridKey = "" -- liste de familiers relue à chaque nouveau duel
		opponent = a
		invite.Visible = false
		deadline = if type(b) == "number" then b else Workspace:GetServerTimeNow() + DUEL.PickTime
		myPick, otherPick, myReady, otherReady = nil, nil, false, false
		window.open()
		refreshWindow()
	elseif kind == "State" then
		myPick = if type(a) == "string" then a else nil
		myReady = b == true
		otherPick = if type(c) == "string" then c else nil
		otherReady = d == true
		if type(e) == "number" then
			deadline = e
		end
		refreshWindow()
	elseif kind == "Start" and typeof(a) == "Instance" then
		phase = "Fight"
		mySide = if b == "B" then "B" else "A"
		local center = a:GetAttribute("Center")
		arenaCenter = if typeof(center) == "Vector3" then center else nil
		closeWindow()
		setHudVisible(false)
		cheerButton.Visible = true
		Sounds.play("PhaseFeeding")
		showBanner("3", WHITE, 0.8)
		task.delay(0.8, function()
			showBanner("2", WHITE, 0.8)
		end)
		task.delay(1.6, function()
			showBanner("1", WHITE, 0.8)
		end)
		task.delay(2.4, function()
			showBanner("COMBAT !", UiStyle.Colors.Orange, 1)
		end)
	elseif kind == "Announce" and type(a) == "string" and type(b) == "string" then
		if phase ~= "Fight" then
			Toast.show(string.format("DUEL AU-DESSUS DU TROU NOIR : %s CONTRE %s !", TextFormat.upper(a), TextFormat.upper(b)),
				UiStyle.Colors.Orange)
		end
	elseif kind == "Won" then
		phase = "After"
		cheerButton.Visible = false
		Sounds.play("StealSuccess")
		showBanner("VICTOIRE ! TOURNE LA ROUE !", UiStyle.Colors.Gold, 3)
	elseif kind == "Lost" then
		phase = "After"
		cheerButton.Visible = false
		Sounds.play("StealFail")
		showBanner("DÉFAITE...", RED, 2.5)
	elseif kind == "Reward" and type(b) == "string" then
		Sounds.play("Coins")
		showBanner(b, UiStyle.Colors.Gold, 3)
	elseif kind == "PetWon" and type(a) == "string" and type(b) == "string" and type(c) == "string" then
		Sounds.play("RareDrop")
		Toast.show(string.format("%s A GAGNÉ %s DE %s EN DUEL !", TextFormat.upper(a), petName(c), TextFormat.upper(b)),
			rarityColor(c))
	end
end)
