--!strict
-- FusionMenu : fenêtre MACHINE DE FUSION, sur le modèle de la référence :
--   - Config.Fusion.Count cases « Vide » avec un gros bouton + : on choisit soi-même les familiers (même rareté) ;
--   - des tuyaux relient les cases à la chambre centrale, qui montre ce qu'on va obtenir (rareté au-dessus) ;
--   - bouton du bas : « 3 familiers restants » tant que ce n'est pas plein, puis « FUSIONNER $prix » ;
--   - « Auto » remplit les cases avec les doublons ; petit encart d'explication à la première ouverture.
-- Le serveur valide tout (Remotes.Fuse(rarityIndex, choix) -> server/FusionController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Icons = require(ReplicatedStorage.Shared.Icons)
local MenuKit = require(script.Parent.MenuKit)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local FusionMenu = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local PIPE = Color3.fromRGB(28, 28, 34)
local GREY = Color3.fromRGB(150, 150, 160)
local COUNT = Config.Fusion.Count
local SLOT_WIDTH = 116
local SLOT_GAP = 10

export type Fusion = {
	window: MenuKit.Window,
	refresh: () -> (),
	showResult: (petId: string, egg: boolean?) -> (),
}

function FusionMenu.create(gui: Instance): Fusion
	local window = MenuKit.window(gui, "Machine de fusion", Vector2.new(720, 540), UiStyle.Colors.Purple, "Sparkle")
	local content = window.content
	local width = window.frame.Size.X.Offset - 32

	-- Rafraîchit toute la fenêtre (défini plus bas, appelé par les boutons créés avant).
	local refreshAll: () -> () = function() end
	local slots: { string? } = {}
	for index = 1, COUNT do
		slots[index] = nil
	end

	local function slotRarity(): number?
		for index = 1, COUNT do
			local petId = slots[index]
			local entry = if petId then PetCatalog.ById[petId] else nil
			if entry then
				return Config.RarityIndex[entry.Rarity]
			end
		end
		return nil
	end

	local function filledCount(): number
		local count = 0
		for index = 1, COUNT do
			if slots[index] then
				count += 1
			end
		end
		return count
	end

	-- Exemplaires de ce familier encore libres une fois les cases remplies.
	local function freeLeft(petId: string): number
		local used = 0
		for index = 1, COUNT do
			if slots[index] == petId then
				used += 1
			end
		end
		return MenuKit.spare(petId) - used
	end

	----------------------------------------------------------------------
	-- Textes du haut
	----------------------------------------------------------------------
	local line1 = UiStyle.text(content, string.format("Mets %d familiers de la même rareté dans la machine", COUNT), 22, WHITE, UiStyle.BODY_FONT)
	line1.Size = UDim2.new(1, 0, 0, 26)
	line1.ZIndex = 3
	local line2 = UiStyle.text(content, "Tu obtiens un familier de la rareté au-dessus !", 20, WHITE)
	line2.FontFace = UiStyle.NUMBER_FONT
	line2.Position = UDim2.fromOffset(0, 26)
	line2.Size = UDim2.new(1, 0, 0, 24)
	line2.ZIndex = 3

	----------------------------------------------------------------------
	-- Cases, tuyaux, chambre centrale
	----------------------------------------------------------------------
	local rowWidth = COUNT * SLOT_WIDTH + (COUNT - 1) * SLOT_GAP
	local rowLeft = math.floor((width - rowWidth) / 2)
	local SLOT_TOP = 60
	local SLOT_HEIGHT = 124

	type Slot = { frame: Frame, label: TextLabel, plus: TextButton, remove: TextButton, viewport: ViewportFrame?, shown: string? }
	local slotUis: { Slot } = {}

	local picker: Frame
	local openPicker: () -> ()

	for index = 1, COUNT do
		local frame = UiStyle.panel(content, UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT))
		frame.Position = UDim2.fromOffset(rowLeft + (index - 1) * (SLOT_WIDTH + SLOT_GAP), SLOT_TOP)
		frame.ZIndex = 3
		local label = UiStyle.text(frame, "Vide", 24, WHITE, UiStyle.BODY_FONT)
		label.Position = UDim2.fromOffset(4, 4)
		label.Size = UDim2.new(1, -8, 0, 28)
		label.TextScaled = true
		label.ZIndex = 4
		local plus = UiStyle.button(frame, "+", UDim2.new(1, -20, 0, 66), UiStyle.Colors.Green, 54)
		plus.Position = UDim2.fromOffset(10, 44)
		plus.ZIndex = 4
		plus.Activated:Connect(function()
			openPicker()
		end)
		local remove = UiStyle.button(frame, "X", UDim2.fromOffset(30, 30), UiStyle.Colors.Red, 20)
		remove.AnchorPoint = Vector2.new(1, 1)
		remove.Position = UDim2.new(1, -4, 1, -4)
		remove.ZIndex = 6
		remove.Visible = false
		remove.Activated:Connect(function()
			slots[index] = nil
			refreshAll()
		end)
		slotUis[index] = { frame = frame, label = label, plus = plus, remove = remove, viewport = nil, shown = nil }
	end

	-- Tuyaux : chaque case descend vers un collecteur horizontal, puis un tuyau vers la chambre.
	local CHAMBER_TOP = 236
	local CHAMBER_SIZE = Vector2.new(170, 120)
	local collectorY = SLOT_TOP + SLOT_HEIGHT + 30
	local function pipe(position: UDim2, size: UDim2)
		local part = Instance.new("Frame")
		part.BackgroundColor3 = PIPE
		part.BorderSizePixel = 0
		part.Position = position
		part.Size = size
		part.ZIndex = 2
		UiStyle.stroke(part, 2, Color3.fromRGB(60, 60, 70), true)
		part.Parent = content
	end
	for index = 1, COUNT do
		local x = rowLeft + (index - 1) * (SLOT_WIDTH + SLOT_GAP) + SLOT_WIDTH / 2
		-- Embout vert sous chaque case.
		local cap = Instance.new("Frame")
		cap.BackgroundColor3 = UiStyle.Colors.Green
		cap.BorderSizePixel = 0
		cap.Position = UDim2.fromOffset(x - 26, SLOT_TOP + SLOT_HEIGHT + 2)
		cap.Size = UDim2.fromOffset(52, 10)
		cap.ZIndex = 3
		UiStyle.corner(cap, 5)
		UiStyle.stroke(cap, 2, BLACK, true)
		cap.Parent = content
		pipe(UDim2.fromOffset(x - 7, SLOT_TOP + SLOT_HEIGHT + 10), UDim2.fromOffset(14, collectorY - (SLOT_TOP + SLOT_HEIGHT + 10) + 7))
	end
	local firstX = rowLeft + SLOT_WIDTH / 2
	pipe(UDim2.fromOffset(firstX - 7, collectorY), UDim2.fromOffset(rowWidth - SLOT_WIDTH + 14, 14))
	pipe(UDim2.fromOffset(width / 2 - 9, collectorY), UDim2.fromOffset(18, CHAMBER_TOP - collectorY))

	local chamber = UiStyle.panel(content, UDim2.fromOffset(CHAMBER_SIZE.X, CHAMBER_SIZE.Y))
	chamber.Position = UDim2.fromOffset(width / 2 - CHAMBER_SIZE.X / 2, CHAMBER_TOP)
	chamber.ZIndex = 3
	local chamberGlow = UiStyle.stroke(chamber, 4, UiStyle.Colors.Green, true)
	chamberGlow.Transparency = 0.2
	local chamberScale = Instance.new("UIScale")
	chamberScale.Parent = chamber
	local chamberMark = UiStyle.text(chamber, "?", 70, WHITE)
	chamberMark.Size = UDim2.new(1, 0, 1, -26)
	chamberMark.ZIndex = 4
	local chamberLabel = UiStyle.text(chamber, "", 18, WHITE, UiStyle.BODY_FONT)
	chamberLabel.AnchorPoint = Vector2.new(0, 1)
	chamberLabel.Position = UDim2.new(0, 4, 1, -4)
	chamberLabel.Size = UDim2.new(1, -8, 0, 22)
	chamberLabel.TextScaled = true
	chamberLabel.ZIndex = 5
	local chamberViewport: ViewportFrame? = nil

	----------------------------------------------------------------------
	-- Boutons du bas
	----------------------------------------------------------------------
	local fuseButton = UiStyle.button(content, "", UDim2.fromOffset(330, 54), UiStyle.Colors.Green, 24)
	fuseButton.Position = UDim2.fromOffset(width / 2 - 165, CHAMBER_TOP + CHAMBER_SIZE.Y + 14)
	fuseButton.ZIndex = 3
	local fuseCaption = fuseButton:FindFirstChild("Caption") :: TextLabel
	fuseCaption.FontFace = UiStyle.BODY_FONT

	local autoButton = UiStyle.button(content, "Auto", UDim2.fromOffset(110, 46), UiStyle.Colors.Cyan, 24)
	autoButton.Position = UDim2.fromOffset(rowLeft, CHAMBER_TOP + CHAMBER_SIZE.Y + 18)
	autoButton.ZIndex = 3
	local clearButton = UiStyle.button(content, "Vider", UDim2.fromOffset(110, 46), UiStyle.Colors.Red, 24)
	clearButton.Position = UDim2.fromOffset(rowLeft + rowWidth - 110, CHAMBER_TOP + CHAMBER_SIZE.Y + 18)
	clearButton.ZIndex = 3

	----------------------------------------------------------------------
	-- Sélecteur de familiers (par-dessus le contenu)
	----------------------------------------------------------------------
	picker = UiStyle.panel(content, UDim2.fromScale(1, 1))
	picker.Name = "Picker"
	picker.ZIndex = 10
	picker.Visible = false
	local pickerTitle = UiStyle.text(picker, "Choisis un familier", 26, WHITE, UiStyle.BODY_FONT)
	pickerTitle.Position = UDim2.fromOffset(12, 6)
	pickerTitle.Size = UDim2.new(1, -80, 0, 34)
	pickerTitle.TextXAlignment = Enum.TextXAlignment.Left
	pickerTitle.ZIndex = 11
	local pickerClose = UiStyle.button(picker, "X", UDim2.fromOffset(40, 40), UiStyle.Colors.Red, 26)
	pickerClose.AnchorPoint = Vector2.new(1, 0)
	pickerClose.Position = UDim2.new(1, -6, 0, 4)
	pickerClose.ZIndex = 11
	pickerClose.Activated:Connect(function()
		picker.Visible = false
	end)
	local pickerGrid = Instance.new("ScrollingFrame")
	pickerGrid.BackgroundTransparency = 1
	pickerGrid.BorderSizePixel = 0
	pickerGrid.Position = UDim2.fromOffset(8, 48)
	pickerGrid.Size = UDim2.new(1, -16, 1, -56)
	pickerGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pickerGrid.CanvasSize = UDim2.new()
	pickerGrid.ScrollBarThickness = 6
	pickerGrid.ScrollBarImageColor3 = WHITE
	pickerGrid.ZIndex = 11
	pickerGrid.Parent = picker
	pickerGrid.ScrollingDirection = Enum.ScrollingDirection.Y
	UiStyle.scrollPadding(pickerGrid)
	local pickerLayout = Instance.new("UIGridLayout")
	pickerLayout.CellSize = UDim2.fromOffset(116, 138)
	pickerLayout.CellPadding = UDim2.fromOffset(12, 12)
	pickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pickerLayout.Parent = pickerGrid
	local pickerEmpty = UiStyle.text(picker, "Aucun familier libre à fusionner ici.\nLes familiers équipés ne comptent pas.", 22, WHITE, UiStyle.BODY_FONT)
	pickerEmpty.Position = UDim2.fromOffset(16, 56)
	pickerEmpty.Size = UDim2.new(1, -32, 1, -72)
	pickerEmpty.TextWrapped = true
	pickerEmpty.ZIndex = 11
	pickerEmpty.Visible = false

	local function addToSlot(petId: string)
		for index = 1, COUNT do
			if not slots[index] then
				slots[index] = petId
				break
			end
		end
	end

	local pickerKey = "" -- familiers libres affichés (le sélecteur n'est refait que s'ils changent)
	local function buildPicker()
		local lockNow = slotRarity()
		local keyParts = { tostring(lockNow) }
		for _, entry in ipairs(PetCatalog.List) do
			local left = freeLeft(entry.Id)
			if left > 0 then
				table.insert(keyParts, entry.Id .. "=" .. left)
			end
		end
		local key = table.concat(keyParts, ",")
		if key == pickerKey and #pickerGrid:GetChildren() > 1 then
			return
		end
		pickerKey = key
		for _, child in ipairs(pickerGrid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local lock = slotRarity()
		local shown = 0
		for order, entry in ipairs(PetCatalog.List) do
			local rarityIndex = Config.RarityIndex[entry.Rarity]
			local left = freeLeft(entry.Id)
			if left > 0 and rarityIndex <= Config.Fusion.MaxFromRarity and (lock == nil or lock == rarityIndex) then
				shown += 1
				local rarity = Config.Rarities[rarityIndex]
				local button = Instance.new("TextButton")
				button.Text = ""
				button.AutoButtonColor = false
				button.BackgroundColor3 = WHITE
				button.LayoutOrder = rarityIndex * 1000 + order
				button.ZIndex = 11
				UiStyle.corner(button, 6)
				UiStyle.stroke(button, 3, BLACK, true)
				UiStyle.gradient(button, UiStyle.lighter(rarity.Color, 0.35), rarity.Color)
				button.Parent = pickerGrid
				UiStyle.bounce(button)
				local viewport = MenuKit.petViewport(button, entry.Id, false)
				viewport.Position = UDim2.fromOffset(8, 40)
				viewport.Size = UDim2.new(1, -16, 0, 64)
				viewport.ZIndex = 12
				local name = UiStyle.text(button, entry.Name, 15, WHITE, UiStyle.BODY_FONT)
				name.Position = UDim2.fromOffset(8, 6)
				name.Size = UDim2.new(1, -16, 0, 30)
				name.TextWrapped = true
				name.ZIndex = 13
				local count = UiStyle.text(button, string.format("x%d libre%s", left, if left > 1 then "s" else ""), 14, WHITE)
				count.AnchorPoint = Vector2.new(0, 1)
				count.Position = UDim2.new(0, 8, 1, -8)
				count.Size = UDim2.new(1, -16, 0, 18)
				count.ZIndex = 13
				button.Activated:Connect(function()
					addToSlot(entry.Id)
					if filledCount() >= COUNT then
						picker.Visible = false
					else
						buildPicker()
					end
					refreshAll()
				end)
			end
		end
		pickerEmpty.Visible = shown == 0
	end

	openPicker = function()
		if filledCount() >= COUNT then
			return
		end
		buildPicker()
		picker.Visible = true
	end

	----------------------------------------------------------------------
	-- Encart d'explication (première ouverture de la session)
	----------------------------------------------------------------------
	local helpShown = false
	local help = UiStyle.panel(window.frame, UDim2.fromOffset(250, 200))
	help.AnchorPoint = Vector2.new(1, 0.5)
	help.Position = UDim2.new(0, -14, 0.5, 0)
	help.BackgroundColor3 = UiStyle.Colors.WindowBody
	help.Visible = false
	-- « 5 x [patte] = [étoile] »
	local helpCount = UiStyle.text(help, COUNT .. " x", 40, WHITE)
	helpCount.Position = UDim2.fromOffset(10, 18)
	helpCount.Size = UDim2.fromOffset(70, 64)
	Icons.image(help, "Paw", UDim2.fromOffset(64, 64), UDim2.fromOffset(78, 18))
	local helpEquals = UiStyle.text(help, "=", 44, WHITE)
	helpEquals.Position = UDim2.fromOffset(142, 18)
	helpEquals.Size = UDim2.fromOffset(30, 64)
	Icons.image(help, "Sparkle", UDim2.fromOffset(70, 70), UDim2.fromOffset(172, 14))
	local helpSub = UiStyle.text(help, "5 de la même rareté = 1 plus rare !", 18, WHITE, UiStyle.BODY_FONT)
	helpSub.Position = UDim2.fromOffset(8, 84)
	helpSub.Size = UDim2.new(1, -16, 0, 44)
	helpSub.TextWrapped = true
	local helpOk = UiStyle.button(help, "D'accord !", UDim2.new(1, -60, 0, 46), UiStyle.Colors.Green, 26)
	helpOk.Position = UDim2.new(0, 30, 1, -58)
	helpOk.Activated:Connect(function()
		help.Visible = false
	end)

	----------------------------------------------------------------------
	-- Mise à jour
	----------------------------------------------------------------------
	local function refresh()
		-- Les cases doivent toujours correspondre à des familiers libres (vol, équipement...).
		for index = 1, COUNT do
			local petId = slots[index]
			if petId and freeLeft(petId) < 0 then
				slots[index] = nil
			end
		end

		for index, ui in ipairs(slotUis) do
			local petId = slots[index]
			local entry = if petId then PetCatalog.ById[petId] else nil
			ui.plus.Visible = entry == nil
			ui.remove.Visible = entry ~= nil
			ui.label.Text = if entry then entry.Name else "Vide"
			if ui.shown ~= petId then
				ui.shown = petId
				if ui.viewport then
					ui.viewport:Destroy()
					ui.viewport = nil
				end
				if entry then
					local viewport = MenuKit.petViewport(ui.frame, entry.Id, false)
					viewport.Position = UDim2.fromOffset(6, 32)
					viewport.Size = UDim2.new(1, -12, 1, -38)
					viewport.ZIndex = 5
					ui.viewport = viewport
				end
			end
		end

		local rarityIndex = slotRarity()
		local filled = filledCount()
		if rarityIndex and Config.Rarities[rarityIndex + 1] then
			local target = Config.Rarities[rarityIndex + 1]
			chamberLabel.Text = "> " .. target.Name
			chamberLabel.TextColor3 = UiStyle.lighter(target.Color, 0.2)
			chamberMark.TextColor3 = target.Color
			chamberGlow.Color = target.Color
		else
			chamberLabel.Text = "Résultat"
			chamberLabel.TextColor3 = WHITE
			chamberMark.TextColor3 = WHITE
			chamberGlow.Color = UiStyle.Colors.Green
		end

		if filled < COUNT then
			local missing = COUNT - filled
			fuseCaption.Text = string.format("%d familier%s restant%s", missing, if missing > 1 then "s" else "", if missing > 1 then "s" else "")
			UiStyle.setButtonColor(fuseButton, UiStyle.darker(UiStyle.Colors.Green, 0.25))
		else
			local cost = Config.Fusion.Costs[rarityIndex or 1] or 0
			fuseCaption.Text = "FUSIONNER  " .. NumberFormat.money(cost)
			UiStyle.setButtonColor(fuseButton, if MenuKit.number("Money") >= cost then UiStyle.Colors.Green else UiStyle.Colors.Red)
		end
		UiStyle.setButtonColor(clearButton, if filled > 0 then UiStyle.Colors.Red else GREY)
		if picker.Visible then
			buildPicker()
		end
	end
	refreshAll = refresh

	fuseButton.Activated:Connect(function()
		local filled = filledCount()
		local rarityIndex = slotRarity()
		if filled < COUNT or not rarityIndex then
			openPicker()
			return
		end
		local cost = Config.Fusion.Costs[rarityIndex] or 0
		if MenuKit.number("Money") < cost then
			Toast.show("PAS ASSEZ D'ARGENT : " .. NumberFormat.money(cost), UiStyle.Colors.Red)
			Sounds.play("Error")
			return
		end
		local chosen: { [string]: number } = {}
		for index = 1, COUNT do
			local petId = slots[index]
			if petId then
				chosen[petId] = (chosen[petId] or 0) + 1
			end
		end
		Remotes.Fuse:FireServer(rarityIndex, chosen)
	end)

	-- Auto : remplit les cases vides avec les familiers qui ont le plus d'exemplaires libres.
	autoButton.Activated:Connect(function()
		local lock = slotRarity()
		if not lock then
			-- Rareté la plus basse qui a assez de familiers libres.
			for index = 1, Config.Fusion.MaxFromRarity do
				local total = 0
				for _, entry in ipairs(PetCatalog.ByRarity[Config.Rarities[index].Id] or {}) do
					total += MenuKit.spare(entry.Id)
				end
				if total >= COUNT then
					lock = index
					break
				end
			end
		end
		if not lock then
			Toast.show(string.format("IL TE FAUT %d FAMILIERS LIBRES D'UNE MÊME RARETÉ !", COUNT), UiStyle.Colors.Red)
			Sounds.play("Error")
			return
		end
		local bucket = PetCatalog.ByRarity[Config.Rarities[lock].Id] or {}
		while filledCount() < COUNT do
			local best: string? = nil
			local bestLeft = 0
			for _, entry in ipairs(bucket) do
				local left = freeLeft(entry.Id)
				if left > bestLeft then
					best, bestLeft = entry.Id, left
				end
			end
			if not best then
				Toast.show("PAS ASSEZ DE FAMILIERS LIBRES DE CETTE RARETÉ !", UiStyle.Colors.Red)
				break
			end
			addToSlot(best)
		end
		refresh()
	end)

	clearButton.Activated:Connect(function()
		for index = 1, COUNT do
			slots[index] = nil
		end
		refresh()
	end)

	window.onOpen(function()
		if not helpShown then
			helpShown = true
			help.Visible = true
		end
		picker.Visible = false
		refresh()
	end)

	local function showResult(petId: string, egg: boolean?)
		local entry = PetCatalog.ById[petId]
		if not entry then
			return
		end
		for index = 1, COUNT do
			slots[index] = nil
		end
		refresh()
		if chamberViewport then
			chamberViewport:Destroy()
		end
		local viewport = if egg then MenuKit.eggViewport(chamber, entry.Rarity) else MenuKit.petViewport(chamber, petId, false)
		viewport.Position = UDim2.fromOffset(6, 4)
		viewport.Size = UDim2.new(1, -12, 1, -30)
		viewport.ZIndex = 5
		chamberViewport = viewport
		chamberMark.Visible = false
		local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
		chamberLabel.Text = if egg then "ŒUF " .. rarity.Name else entry.Name
		chamberLabel.TextColor3 = rarity.Color
		chamberGlow.Color = rarity.Color
		chamberScale.Scale = 0.5
		TweenService:Create(chamberScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		-- Après quelques secondes, la chambre redevient « ? ».
		task.delay(4, function()
			if chamberViewport == viewport then
				viewport:Destroy()
				chamberViewport = nil
				chamberMark.Visible = true
				refresh()
			end
		end)
	end

	refresh()
	return { window = window, refresh = refresh, showResult = showResult }
end

return FusionMenu
