--!strict
-- TradeClient : le côté joueur des échanges de familiers (server/TradeController, Config.Trade).
--   - Bulle [T] « Échanger » sur les autres joueurs (créée ici, localement).
--   - Invitation reçue : ACCEPTER / REFUSER.
--   - Fenêtre ÉCHANGE : à gauche ton offre (6 cases, clic pour retirer) et tes familiers (clic pour ajouter) ; à droite
--     l'offre de l'autre, le revenu de chaque côté et un avertissement si l'échange est très déséquilibré.
--     Double confirmation : PRÊT (les deux) -> offres bloquées -> CONFIRMER après un compte à rebours.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local TRADE = Config.Trade
local player = Players.LocalPlayer
local RED = Color3.fromRGB(255, 90, 90)
local WHITE = Color3.new(1, 1, 1)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Trade"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- le contenu des fenêtres passe devant leur fond
screenGui.Parent = player:WaitForChild("PlayerGui")
local gui = ScreenScale.attach(screenGui)

type Offer = { [string]: number }

local function action(name: string, arg: any?)
	Remotes.TradeAction:FireServer(name, arg)
end

local function petName(petId: string): string
	local entry = PetCatalog.ById[petId]
	return if entry then TextFormat.upper(entry.Name) else petId
end

local function rarityColor(petId: string): Color3
	local entry = PetCatalog.ById[petId]
	return if entry then Config.Rarities[Config.RarityIndex[entry.Rarity] or 1].Color else WHITE
end

local function rarityIndex(petId: string): number
	local entry = PetCatalog.ById[petId]
	return if entry then Config.RarityIndex[entry.Rarity] or 1 else 1
end

-- État local
local phase = "Idle" -- "Idle", "Waiting", "Invited", "Edit", "Confirm"
local other: Player? = nil
local myOffer: Offer = {}
local otherOffer: Offer = {}
local myReady, myConfirmed, otherReady, otherConfirmed = false, false, false, false
local deadline = 0
local confirmAt = 0

----------------------------------------------------------------------
-- Bulles « Échanger »
----------------------------------------------------------------------

local prompts: { [Player]: ProximityPrompt } = {}

local function attachPrompt(target: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	local old = prompts[target]
	if old then
		old:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TradePrompt"
	prompt.ActionText = "Échanger"
	prompt.ObjectText = target.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.T
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonL1
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = TRADE.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, 120) -- sous la bulle « Défier en duel »
	prompt.Triggered:Connect(function()
		action("Request", target)
	end)
	prompt.Parent = root
	prompts[target] = prompt
end

local function watchPlayer(target: Player)
	if target == player then
		return
	end
	target.CharacterAdded:Connect(function(character)
		attachPrompt(target, character)
	end)
	if target.Character then
		task.spawn(attachPrompt, target, target.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, target in ipairs(Players:GetPlayers()) do
	watchPlayer(target)
end
Players.PlayerRemoving:Connect(function(target)
	local prompt = prompts[target]
	if prompt then
		prompt:Destroy()
		prompts[target] = nil
	end
end)

----------------------------------------------------------------------
-- Invitation
----------------------------------------------------------------------

local invite = UiStyle.panel(gui, UDim2.fromOffset(520, 150))
invite.AnchorPoint = Vector2.new(0.5, 0)
invite.Position = UDim2.new(0.5, 0, 0, 350)
invite.BackgroundColor3 = UiStyle.Colors.WindowBody
invite.Visible = false
local inviteText = UiStyle.text(invite, "", 26, UiStyle.Colors.Cyan)
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
-- Fenêtre d'échange
----------------------------------------------------------------------

local window = MenuKit.window(gui, "Échange", Vector2.new(900, 560), UiStyle.Colors.Cyan)
local content = window.content
local COLUMN = 420

local function heading(text: string, x: number, y: number): TextLabel
	local label = UiStyle.text(content, text, 22, WHITE)
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(COLUMN, 26)
	label.TextXAlignment = Enum.TextXAlignment.Left
	return label
end

local myTitle = heading("TON OFFRE", 0, 0)
local otherTitle = heading("SON OFFRE", COLUMN + 28, 0)

-- 6 cases d'une offre : aperçu 3D, nom, quantité.
type Slot = { frame: TextButton, holder: Frame, name: TextLabel, amount: TextLabel, petId: string? }
local function slots(x: number, clickable: boolean): { Slot }
	local list: { Slot } = {}
	for index = 0, TRADE.MaxPets - 1 do
		local frame = Instance.new("TextButton")
		frame.Text = ""
		frame.AutoButtonColor = false
		frame.BackgroundColor3 = UiStyle.Colors.Panel
		frame.Position = UDim2.fromOffset(x + (index % 3) * 140, 30 + (index // 3) * 122)
		frame.Size = UDim2.fromOffset(132, 114)
		UiStyle.corner(frame, 6)
		UiStyle.stroke(frame, 3, Color3.new(0, 0, 0), true)
		frame.Parent = content
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.fromOffset(4, 2)
		holder.Size = UDim2.fromOffset(124, 74)
		holder.Parent = frame
		local name = UiStyle.text(frame, "", 13, WHITE)
		name.Position = UDim2.fromOffset(2, 76)
		name.Size = UDim2.new(1, -4, 0, 34)
		name.TextWrapped = true
		local amount = UiStyle.text(frame, "", 20, UiStyle.Colors.Gold)
		amount.AnchorPoint = Vector2.new(1, 0)
		amount.Position = UDim2.new(1, -4, 0, 2)
		amount.Size = UDim2.fromOffset(40, 24)
		amount.TextXAlignment = Enum.TextXAlignment.Right
		local slot: Slot = { frame = frame, holder = holder, name = name, amount = amount, petId = nil }
		if clickable then
			frame.Activated:Connect(function()
				if slot.petId and phase == "Edit" then
					Sounds.play("UiClick")
					action("Remove", slot.petId)
				end
			end)
		end
		table.insert(list, slot)
	end
	return list
end
local mySlots = slots(0, true)
local otherSlots = slots(COLUMN + 28, false)

local function sortedIds(offer: Offer): { string }
	local list = {}
	for petId in pairs(offer) do
		table.insert(list, petId)
	end
	table.sort(list, function(a, b)
		local ra, rb = rarityIndex(a), rarityIndex(b)
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	return list
end

local function fillSlots(list: { Slot }, offer: Offer)
	local ids = sortedIds(offer)
	for index, slot in ipairs(list) do
		local petId = ids[index]
		if slot.petId ~= petId then
			slot.petId = petId
			for _, child in ipairs(slot.holder:GetChildren()) do
				child:Destroy()
			end
			if petId then
				local viewport = MenuKit.petViewport(slot.holder, petId, false)
				viewport.Size = UDim2.fromScale(1, 1)
			end
		end
		slot.name.Text = if petId then petName(petId) else "VIDE"
		slot.name.TextColor3 = if petId then rarityColor(petId) else Color3.fromRGB(120, 120, 135)
		slot.amount.Text = if petId and offer[petId] > 1 then "x" .. offer[petId] else ""
	end
end

-- Revenu total d'une offre (pour comparer ce qu'on donne et ce qu'on reçoit).
local function value(offer: Offer): number
	local total = 0
	for petId, n in pairs(offer) do
		total += PetCatalog.GetIncome(petId) * n
	end
	return total
end

local myValue = UiStyle.text(content, "", 18, UiStyle.Colors.Money)
myValue.Position = UDim2.fromOffset(0, 276)
myValue.Size = UDim2.fromOffset(COLUMN, 22)
myValue.TextXAlignment = Enum.TextXAlignment.Left
local otherValue = UiStyle.text(content, "", 18, UiStyle.Colors.Money)
otherValue.Position = UDim2.fromOffset(COLUMN + 28, 276)
otherValue.Size = UDim2.fromOffset(COLUMN, 22)
otherValue.TextXAlignment = Enum.TextXAlignment.Left

-- Tes familiers (clic = ajouter à l'offre).
local inventoryTitle = heading("TES FAMILIERS (clique pour en ajouter)", 0, 304)
inventoryTitle.TextSize = 16
local grid = Instance.new("ScrollingFrame")
grid.Position = UDim2.fromOffset(0, 330)
grid.Size = UDim2.new(0, COLUMN, 1, -330)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 8
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.Parent = content
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(96, 96)
layout.CellPadding = UDim2.fromOffset(6, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

type GridCard = { card: TextButton, count: TextLabel }
local gridCards: { [string]: GridCard } = {}
local gridKey = ""

local function refreshGrid()
	local list: { string } = {}
	for _, entry in ipairs(PetCatalog.List) do
		if MenuKit.spare(entry.Id) > 0 then
			table.insert(list, entry.Id)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = rarityIndex(a), rarityIndex(b)
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	local key = table.concat(list, ",")
	if key ~= gridKey then
		gridKey = key
		table.clear(gridCards)
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for order, petId in ipairs(list) do
			local card = Instance.new("TextButton")
			card.Text = ""
			card.LayoutOrder = order
			card.AutoButtonColor = false
			card.BackgroundColor3 = UiStyle.Colors.Panel
			UiStyle.corner(card, 6)
			UiStyle.stroke(card, 3, rarityColor(petId), true)
			card.Parent = grid
			local viewport = MenuKit.petViewport(card, petId, false)
			viewport.Size = UDim2.fromOffset(86, 60)
			viewport.Position = UDim2.fromOffset(5, 2)
			local name = UiStyle.text(card, petName(petId), 11, rarityColor(petId))
			name.Position = UDim2.fromOffset(2, 62)
			name.Size = UDim2.new(1, -4, 0, 30)
			name.TextWrapped = true
			local countLabel = UiStyle.text(card, "", 16, UiStyle.Colors.Gold)
			countLabel.AnchorPoint = Vector2.new(1, 0)
			countLabel.Position = UDim2.new(1, -3, 0, 0)
			countLabel.Size = UDim2.fromOffset(36, 20)
			countLabel.TextXAlignment = Enum.TextXAlignment.Right
			gridCards[petId] = { card = card, count = countLabel }
			card.Activated:Connect(function()
				if phase ~= "Edit" then
					return
				end
				Sounds.play("UiClick")
				action("Add", petId)
			end)
		end
	end
	for petId, entry in pairs(gridCards) do
		local left = MenuKit.spare(petId) - (myOffer[petId] or 0)
		entry.count.Text = "x" .. math.max(0, left)
		entry.card.BackgroundTransparency = if left > 0 then 0 else 0.6
	end
end

-- Colonne de droite, sous l'offre : avertissement, statuts, boutons.
local warning = UiStyle.text(content, "", 18, RED)
warning.Position = UDim2.fromOffset(COLUMN + 28, 304)
warning.Size = UDim2.fromOffset(COLUMN, 44)
warning.TextWrapped = true
local status = UiStyle.text(content, "", 20, WHITE)
status.Position = UDim2.fromOffset(COLUMN + 28, 352)
status.Size = UDim2.fromOffset(COLUMN, 50)
status.TextWrapped = true
local mainButton = UiStyle.button(content, "PRÊT !", UDim2.fromOffset(250, 58), UiStyle.Colors.Green, 26)
mainButton.Position = UDim2.new(0, COLUMN + 28, 1, -64)
local mainCaption = mainButton:FindFirstChild("Caption") :: TextLabel
local secondButton = UiStyle.button(content, "ANNULER", UDim2.fromOffset(150, 58), UiStyle.Colors.Red, 22)
secondButton.Position = UDim2.new(0, COLUMN + 290, 1, -64)
local secondCaption = secondButton:FindFirstChild("Caption") :: TextLabel

local function refreshWindow()
	local name = if other then TextFormat.upper(other.DisplayName) else "?"
	otherTitle.Text = "OFFRE DE " .. name
	myTitle.Text = "TON OFFRE"
	fillSlots(mySlots, myOffer)
	fillSlots(otherSlots, otherOffer)
	local given, received = value(myOffer), value(otherOffer)
	myValue.Text = "Revenu : " .. NumberFormat.perSecond(given)
	otherValue.Text = "Revenu : " .. NumberFormat.perSecond(received)
	warning.Text = if given > 0 and received < given / 3
		then "ATTENTION : tu donnes beaucoup plus que tu ne reçois !"
		else ""
	if phase == "Confirm" then
		status.Text = string.format("OFFRES BLOQUÉES : VÉRIFIE BIEN !\nToi : %s  •  %s : %s",
			if myConfirmed then "CONFIRMÉ" else "à confirmer", name, if otherConfirmed then "CONFIRMÉ" else "à confirmer")
		status.TextColor3 = UiStyle.Colors.Gold
		secondCaption.Text = "MODIFIER"
		UiStyle.setButtonColor(secondButton, UiStyle.Colors.Orange)
	else
		status.Text = string.format("Toi : %s  •  %s : %s", if myReady then "PRÊT" else "pas prêt", name,
			if otherReady then "PRÊT" else "pas prêt")
		status.TextColor3 = WHITE
		mainCaption.Text = if myReady then "PAS PRÊT" else "PRÊT !"
		UiStyle.setButtonColor(mainButton, if myReady then UiStyle.Colors.Orange else UiStyle.Colors.Green)
		secondCaption.Text = "ANNULER"
		UiStyle.setButtonColor(secondButton, UiStyle.Colors.Red)
	end
	refreshGrid()
end

mainButton.Activated:Connect(function()
	if phase == "Edit" then
		action("Ready", not myReady)
	elseif phase == "Confirm" then
		if Workspace:GetServerTimeNow() < confirmAt then
			Sounds.play("Error")
			return
		end
		action("Confirm")
	end
end)
secondButton.Activated:Connect(function()
	if phase == "Confirm" then
		action("Back")
	else
		action("Cancel")
	end
end)

local closingByScript = false
local function closeWindow()
	closingByScript = true
	window.close()
	closingByScript = false
end
-- Fermer la fenêtre (X) = annuler l'échange.
window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not window.frame.Visible and not closingByScript and (phase == "Edit" or phase == "Confirm") then
		action("Cancel")
	end
end)

local function backToIdle()
	phase = "Idle"
	other = nil
	table.clear(myOffer)
	table.clear(otherOffer)
	invite.Visible = false
	closeWindow()
end

RunService.RenderStepped:Connect(function()
	local free = phase == "Idle" and player:GetAttribute("InDuel") == nil and player:GetAttribute("InTrade") == nil
	for target, prompt in pairs(prompts) do
		local enabled = free and target:GetAttribute("InDuel") == nil and target:GetAttribute("InTrade") == nil
		if prompt.Enabled ~= enabled then
			prompt.Enabled = enabled
		end
	end
	if invite.Visible then
		inviteTimer.Text = string.format("%d s pour répondre", math.max(0, math.ceil(deadline - Workspace:GetServerTimeNow())))
	end
	-- Compte à rebours de la deuxième confirmation.
	if phase == "Confirm" then
		local left = math.ceil(confirmAt - Workspace:GetServerTimeNow())
		if myConfirmed then
			mainCaption.Text = "CONFIRMÉ"
			UiStyle.setButtonColor(mainButton, UiStyle.Colors.Cyan)
		elseif left > 0 then
			mainCaption.Text = string.format("CONFIRMER (%d)", left)
			UiStyle.setButtonColor(mainButton, Color3.fromRGB(150, 150, 160))
		else
			mainCaption.Text = "CONFIRMER !"
			UiStyle.setButtonColor(mainButton, UiStyle.Colors.Green)
		end
	end
end)

----------------------------------------------------------------------
-- Événements du serveur
----------------------------------------------------------------------

local CANCEL_MESSAGES: { [string]: string } = {
	Declined = "ÉCHANGE REFUSÉ",
	Timeout = "ÉCHANGE ANNULÉ : TEMPS ÉCOULÉ",
	Busy = "CE JOUEUR EST OCCUPÉ",
	Cooldown = "ATTENDS UN PEU AVANT DE PROPOSER UN AUTRE ÉCHANGE",
	Cancelled = "ÉCHANGE ANNULÉ",
	Left = "L'AUTRE JOUEUR EST PARTI : ÉCHANGE ANNULÉ",
	PetGone = "UN FAMILIER DE L'ÉCHANGE N'EST PLUS DISPONIBLE : ÉCHANGE ANNULÉ",
}
local SOFT_MESSAGES: { [string]: string } = {
	Full = string.format("%d FAMILIERS AU MAXIMUM PAR OFFRE", TRADE.MaxPets),
	NoMore = "TU N'AS PAS D'AUTRE EXEMPLAIRE LIBRE DE CE FAMILIER",
	Empty = "AJOUTE AU MOINS UN FAMILIER À L'ÉCHANGE",
}

local function offerOf(value: any): Offer
	local offer: Offer = {}
	if type(value) == "table" then
		for petId, n in pairs(value) do
			if type(petId) == "string" and type(n) == "number" then
				offer[petId] = n
			end
		end
	end
	return offer
end

Remotes.TradeEvent.OnClientEvent:Connect(function(kind: string, ...: any)
	local args = { ... }
	if kind == "Invite" and typeof(args[1]) == "Instance" and args[1]:IsA("Player") then
		phase = "Invited"
		other = args[1]
		deadline = if type(args[2]) == "number" then args[2] else Workspace:GetServerTimeNow() + TRADE.InviteTime
		inviteText.Text = string.format("%s TE PROPOSE UN ÉCHANGE DE FAMILIERS !", TextFormat.upper(args[1].DisplayName))
		invite.Visible = true
		Sounds.play("WindowOpen")
	elseif kind == "Waiting" and typeof(args[1]) == "Instance" and args[1]:IsA("Player") then
		phase = "Waiting"
		other = args[1]
		Toast.show(string.format("ÉCHANGE PROPOSÉ À %s...", TextFormat.upper(args[1].DisplayName)), UiStyle.Colors.Cyan)
	elseif kind == "Cancelled" and type(args[1]) == "string" then
		local soft = SOFT_MESSAGES[args[1]]
		if soft then
			Toast.show(soft, RED)
			return
		end
		Toast.show(CANCEL_MESSAGES[args[1]] or "ÉCHANGE ANNULÉ", RED)
		backToIdle()
	elseif kind == "Open" and typeof(args[1]) == "Instance" and args[1]:IsA("Player") then
		phase = "Edit"
		other = args[1]
		invite.Visible = false
		gridKey = ""
		window.open()
		refreshWindow()
	elseif kind == "State" then
		myOffer = offerOf(args[1])
		myReady = args[2] == true
		myConfirmed = args[3] == true
		otherOffer = offerOf(args[4])
		otherReady = args[5] == true
		otherConfirmed = args[6] == true
		local newPhase = if args[7] == "Confirm" then "Confirm" else "Edit"
		if newPhase == "Confirm" and phase ~= "Confirm" then
			Sounds.play("Lock")
		end
		phase = newPhase
		confirmAt = if type(args[8]) == "number" then args[8] else 0
		refreshWindow()
	elseif kind == "Done" then
		local received = offerOf(args[1])
		local names = {}
		for petId, n in pairs(received) do
			table.insert(names, petName(petId) .. (if n > 1 then " x" .. n else ""))
		end
		local who = if type(args[3]) == "string" then TextFormat.upper(args[3]) else "?"
		Sounds.play("StealSuccess")
		Toast.show(if #names > 0
			then string.format("ÉCHANGE RÉUSSI AVEC %s ! TU REÇOIS : %s", who, table.concat(names, ", "))
			else string.format("ÉCHANGE RÉUSSI AVEC %s !", who), UiStyle.Colors.Money)
		backToIdle()
	end
end)
