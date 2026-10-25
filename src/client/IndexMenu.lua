--!strict
-- IndexMenu : fenêtre INDEX (collection des familiers), sur le modèle de l'index de la référence :
--   - onglets à droite = les raretés (pastille = récompenses qui attendent dans cette rareté) ;
--   - à gauche, la carte de la rareté ; au centre, la grille des familiers (silhouette « ??? » tant qu'il
--     n'est pas découvert) et la barre « 3/9 » ; à droite, le familier choisi (3D, revenu, stats données
--     une fois équipé, ÉQUIPER) et sa récompense (RÉCLAMER) ; en bas, « RÉCLAMER TOUT (n) ! ».
-- Récompenses : Config.Index, validées par le serveur (Remotes.ClaimIndex -> SessionData.ClaimIndex).
-- Formes évoluées (capsule d'évolution, Config.Evolution) : onglets ★ / ★★ / ★★★ sur la fiche du familier (aperçu, revenu,
-- stats, équiper, récompense de chaque forme), étoiles sur la case quand on en possède une, compteur « Évolutions ».
-- Les mutations (Config.Mutations) sont secrètes : elles n'apparaissent pas dans l'Index et n'y ont pas de récompense.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local PetStats = require(ReplicatedStorage.Shared.PetStats)
local PowerCap = require(ReplicatedStorage.Shared.PowerCap)
local player = game:GetService("Players").LocalPlayer
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Icons = require(ReplicatedStorage.Shared.Icons)
local MenuKit = require(script.Parent.MenuKit)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local IndexMenu = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GREY = Color3.fromRGB(150, 150, 160)
local REWARD_GREEN = Color3.fromRGB(24, 74, 36)

type Cell = { entry: PetCatalog.Pet, button: TextButton, viewport: ViewportFrame?, shownDiscovered: boolean? }

export type Index = {
	window: MenuKit.Window,
	refresh: () -> (),
	rebuildViewports: () -> (),
}

function IndexMenu.create(gui: Instance): Index
	local window = MenuKit.window(gui, "Index des familiers", Vector2.new(860, 560), UiStyle.Colors.Cyan, "Index")
	local content = window.content

	local rarityIndex = 1
	local selectedId: string? = nil
	local cells: { Cell } = {}

	----------------------------------------------------------------------
	-- Carte de la rareté (gauche)
	----------------------------------------------------------------------
	local rarityCard: Frame? = nil
	local collectionLabel: TextLabel? = nil

	local function buildRarityCard()
		if rarityCard then
			rarityCard:Destroy()
		end
		local rarity = Config.Rarities[rarityIndex]
		local card = UiStyle.brightCard(content, UDim2.fromOffset(150, 340), rarity.Color)
		card.ZIndex = 2
		local name = UiStyle.text(card, rarity.Name, 30, WHITE, UiStyle.BODY_FONT)
		name.Position = UDim2.fromOffset(10, 10)
		name.Size = UDim2.new(1, -20, 0, 36)
		name.TextWrapped = true
		-- Emblème de la rareté (shared/Icons : pousse, trèfle, goutte, orbe, flamme, fleur, étoile, couronne).
		Icons.image(card, rarity.Id, UDim2.new(1, -30, 0, 120), UDim2.fromOffset(15, 56))
		local bonus = UiStyle.text(card, string.format("Points x%s", tostring(rarity.Multiplier)), 18, WHITE, UiStyle.BODY_FONT)
		bonus.Position = UDim2.fromOffset(4, 196)
		bonus.Size = UDim2.new(1, -8, 0, 24)
		local income = UiStyle.number(card, NumberFormat.perSecond(rarity.Income), 22, UiStyle.Colors.Money)
		income.Position = UDim2.fromOffset(4, 222)
		income.Size = UDim2.new(1, -8, 0, 28)
		local total = UiStyle.text(card, "", 16, WHITE, UiStyle.BODY_FONT)
		total.Position = UDim2.new(0, 10, 1, -76)
		total.Size = UDim2.new(1, -20, 0, 64)
		total.TextWrapped = true
		collectionLabel = total
		rarityCard = card
	end

	----------------------------------------------------------------------
	-- Grille + barre de progression (centre)
	----------------------------------------------------------------------
	local gridBox = UiStyle.panel(content, UDim2.fromOffset(434, 340))
	gridBox.Position = UDim2.fromOffset(160, 0)
	gridBox.ZIndex = 2
	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(4, 4)
	grid.Size = UDim2.new(1, -8, 1, -8)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = WHITE
	grid.ZIndex = 2
	grid.Parent = gridBox
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(126, 150)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	UiStyle.scrollPadding(grid)

	local progress = UiStyle.panel(content, UDim2.fromOffset(434, 44))
	progress.Position = UDim2.fromOffset(160, 352)
	progress.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
	progress.ZIndex = 2
	local progressFill = Instance.new("Frame")
	progressFill.BackgroundColor3 = WHITE
	progressFill.BorderSizePixel = 0
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.ZIndex = 2
	UiStyle.corner(progressFill, 6)
	UiStyle.gradient(progressFill, Color3.fromRGB(120, 255, 80), Color3.fromRGB(40, 190, 40))
	progressFill.Parent = progress
	local progressText = UiStyle.number(progress, "0/0", 32, WHITE)
	progressText.Size = UDim2.fromScale(1, 1)
	progressText.ZIndex = 3

	-- Bandeau du bas : tout réclamer.
	local claimAll = UiStyle.button(content, "", UDim2.fromOffset(594, 56), UiStyle.Colors.Cyan, 1)
	claimAll.Position = UDim2.fromOffset(0, 408)
	local claimAllIcon = Icons.image(claimAll, "Index", UDim2.fromOffset(44, 44), UDim2.fromOffset(10, 6))
	claimAllIcon.ZIndex = 2
	local claimAllText = UiStyle.text(claimAll, "", 34, WHITE)
	claimAllText.Position = UDim2.fromOffset(64, 6)
	claimAllText.Size = UDim2.new(1, -76, 1, -12)
	claimAllText.ZIndex = 2
	claimAll.Activated:Connect(function()
		if MenuKit.claimableCount() > 0 then
			Remotes.ClaimIndex:FireServer()
		else
			Toast.show("RIEN À RÉCLAMER : DÉCOUVRE DE NOUVEAUX FAMILIERS !", UiStyle.Colors.Red)
			Sounds.play("Error")
		end
	end)

	----------------------------------------------------------------------
	-- Détail du familier choisi + récompense (droite)
	----------------------------------------------------------------------
	local detail = UiStyle.panel(content, UDim2.fromOffset(226, 300))
	detail.Position = UDim2.fromOffset(602, 0)
	detail.ZIndex = 2
	local relief = detail:FindFirstChildOfClass("UIGradient")
	if relief then
		relief:Destroy() -- remplacé par le dégradé de la rareté
	end
	local detailGradient = UiStyle.gradient(detail, WHITE, WHITE)
	detail.BackgroundColor3 = WHITE
	local detailViewport: ViewportFrame? = nil
	-- Forme affichée : 1 = normale, 2 = Évolué, 3 = Ultime (PetCatalog.Variant).
	local selectedStage = 1
	local selectedMutation: string? = nil -- toujours nil : les mutations sont secrètes
	local STAGES = #Config.Evolution.Names
	local GOLD = Color3.fromRGB(255, 214, 70)
	local function formOf(petId: string, stage: number, mutation: string?): string
		return PetCatalog.Compose(petId, stage, mutation)
	end
	local formButtons: { TextButton } = {}
	local refreshDetail: () -> ()
	for stage = 1, STAGES do
		local width = (226 - 16 - (STAGES - 1) * 8) / STAGES
		local button = UiStyle.button(detail, string.rep("★", stage), UDim2.fromOffset(width, 28), GREY, 16)
		button.Position = UDim2.fromOffset(8 + (stage - 1) * (width + 8), 8)
		button.ZIndex = 4
		button.Activated:Connect(function()
			selectedStage = stage
			refreshDetail()
		end)
		formButtons[stage] = button
	end
	local detailKey: string? = nil -- familier + découvert/non affiché (évite de refaire l'aperçu 3D à chaque seconde)
	local detailName = UiStyle.text(detail, "", 26, WHITE, UiStyle.BODY_FONT)
	detailName.Position = UDim2.fromOffset(10, 126)
	detailName.Size = UDim2.new(1, -20, 0, 30)
	detailName.TextWrapped = true
	detailName.ZIndex = 3
	local detailRarity = UiStyle.text(detail, "", 22, WHITE, UiStyle.BODY_FONT)
	detailRarity.Position = UDim2.fromOffset(10, 160)
	detailRarity.Size = UDim2.new(1, -20, 0, 22)
	detailRarity.ZIndex = 3
	local detailIncome = UiStyle.number(detail, "", 24, UiStyle.Colors.Money)
	detailIncome.Position = UDim2.fromOffset(10, 188)
	detailIncome.Size = UDim2.new(1, -20, 0, 26)
	detailIncome.ZIndex = 3
	-- Stats données quand il est équipé (shared/PetStats) : icône + « +3 » pour la Vitesse et la Force.
	local function statChip(icon: string, x: number, color: Color3): TextLabel
		local image = Icons.image(detail, icon, UDim2.fromOffset(28, 28), UDim2.fromOffset(x, 220))
		image.ZIndex = 3
		local label = UiStyle.number(detail, "", 24, color)
		label.Position = UDim2.fromOffset(x + 32, 220)
		label.Size = UDim2.fromOffset(64, 28)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 3
		return label
	end
	local detailSpeed = statChip("Speed", 14, UiStyle.Colors.Speed)
	local detailStrength = statChip("Strength", 116, UiStyle.Colors.Strength)
	local equipButton = UiStyle.button(detail, "", UDim2.new(0.5, -11, 0, 36), UiStyle.Colors.Cyan, 18)
	equipButton.Position = UDim2.new(0, 8, 1, -44)
	equipButton.ZIndex = 3
	-- Base (shared/PetRoster) : le mettre dans la base ou l'en retirer ; l'étiquette dit où il est.
	local baseButton = UiStyle.button(detail, "", UDim2.new(0.5, -11, 0, 36), UiStyle.Colors.Green, 18)
	baseButton.AnchorPoint = Vector2.new(1, 0)
	baseButton.Position = UDim2.new(1, -8, 1, -44)
	baseButton.ZIndex = 3
	local whereChip = UiStyle.text(detail, "", 14, WHITE, UiStyle.BODY_FONT)
	whereChip.AnchorPoint = Vector2.new(0.5, 0)
	whereChip.Position = UDim2.new(0.5, 0, 0, 106)
	whereChip.Size = UDim2.fromOffset(150, 20)
	whereChip.BackgroundTransparency = 0
	whereChip.BackgroundColor3 = GREY
	whereChip.ZIndex = 5
	UiStyle.corner(whereChip, 6)
	UiStyle.stroke(whereChip, 2, Color3.new(0, 0, 0), true)

	local rewardBox = UiStyle.panel(content, UDim2.fromOffset(226, 152))
	rewardBox.Position = UDim2.fromOffset(602, 312)
	rewardBox.BackgroundColor3 = REWARD_GREEN
	rewardBox.ZIndex = 2
	local rewardStroke = rewardBox:FindFirstChildOfClass("UIStroke")
	if rewardStroke then
		rewardStroke.Color = Color3.fromRGB(60, 220, 80)
	end
	local rewardTitle = UiStyle.text(rewardBox, "Récompense :", 22, WHITE, UiStyle.BODY_FONT)
	rewardTitle.Position = UDim2.fromOffset(10, 8)
	rewardTitle.Size = UDim2.new(1, -20, 0, 26)
	rewardTitle.TextXAlignment = Enum.TextXAlignment.Left
	rewardTitle.ZIndex = 3
	local rewardChip = UiStyle.panel(rewardBox, UDim2.new(1, -20, 0, 52))
	rewardChip.Position = UDim2.fromOffset(10, 40)
	rewardChip.ZIndex = 3
	local rewardIcon = Icons.image(rewardChip, "Money", UDim2.fromOffset(46, 46), UDim2.fromOffset(4, 3))
	rewardIcon.ZIndex = 4
	local rewardAmount = UiStyle.number(rewardChip, "", 28, UiStyle.Colors.Money)
	rewardAmount.Position = UDim2.fromOffset(58, 6)
	rewardAmount.Size = UDim2.new(1, -68, 1, -12)
	rewardAmount.ZIndex = 3
	local claimButton = UiStyle.button(rewardBox, "", UDim2.new(1, -20, 0, 40), UiStyle.Colors.Green, 26)
	claimButton.Position = UDim2.fromOffset(10, 104)
	claimButton.ZIndex = 3

	local function canClaim(petId: string, claimed: { [string]: boolean }): boolean
		return not claimed[petId] and MenuKit.number("Pet_" .. petId) > 0 and not PetCatalog.Mutation(petId)
	end

	-- Une forme évoluée / mutée est « connue » si on l'a (ou si sa récompense a été réclamée) ; la forme normale suit l'espèce.
	local function formKnown(petId: string, stage: number, claimed: { [string]: boolean }, mutation: string?): boolean
		if stage <= 1 and not mutation then
			return MenuKit.discovered(petId, claimed)
		end
		local form = formOf(petId, stage, mutation)
		return MenuKit.number("Pet_" .. form) > 0 or claimed[form] == true
	end

	-- Récompenses qui attendent pour cette espèce, toutes formes comprises.
	local function waitingFor(petId: string, claimed: { [string]: boolean }): number
		local count = 0
		for _, formId in ipairs(PetCatalog.FormsOf[petId] or { petId }) do
			if canClaim(formId, claimed) then
				count += 1
			end
		end
		return count
	end

	local function equippedCount(petId: string): number
		local count = 0
		for _, id in ipairs(MenuKit.equipped()) do
			if id == petId then
				count += 1
			end
		end
		return count
	end

	refreshDetail = function()
		local speciesId = selectedId
		if not speciesId or not PetCatalog.ById[speciesId] then
			return
		end
		local claimed = MenuKit.claimed()
		-- Onglets de forme : couleur si on la possède, gris sinon, contour blanc sur celle affichée.
		for stage, button in ipairs(formButtons) do
			local owned = MenuKit.number("Pet_" .. formOf(speciesId, stage, selectedMutation)) > 0
			UiStyle.setButtonColor(button, if stage == selectedStage then GOLD elseif owned then UiStyle.Colors.Cyan else GREY)
		end
		local petId = formOf(speciesId, selectedStage, selectedMutation)
		local entry = PetCatalog.ById[petId]
		local known = formKnown(speciesId, selectedStage, claimed, selectedMutation)
		local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
		detailGradient.Color = ColorSequence.new(UiStyle.lighter(rarity.Color, 0.25), UiStyle.darker(rarity.Color, 0.35))
		local key = petId .. (if known then "+" else "-")
		if key ~= detailKey or not detailViewport then
			detailKey = key
			if detailViewport then
				detailViewport:Destroy()
			end
			local viewport = MenuKit.petViewport(detail, petId, not known)
			viewport.Position = UDim2.fromOffset(8, 42)
			viewport.Size = UDim2.new(1, -16, 0, 78)
			viewport.ZIndex = 3
			detailViewport = viewport
		end
		detailName.Text = if known then entry.Name else "???"
		-- Exclusif d'un monde : il ne sort des tirages que dans ce monde.
		detailRarity.Text = if entry.World
			then rarity.Name .. "  •  EXCLUSIF " .. TextFormat.upper(Config.Worlds[Config.WorldIndex[entry.World] or 1].Name)
			else rarity.Name
		detailRarity.TextColor3 = UiStyle.lighter(rarity.Color, 0.4)
		-- Trop fort pour toi (Config.PowerCap) : il rapporte bridé tant que tu n'as pas obtenu toi-même la rareté du dessous.
		local selfBest = PowerCap.SelfBestOf(player)
		local unlock = PowerCap.UnlockRarity(petId, selfBest)
		detailIncome.Text = if not known then "???"
			elseif unlock then NumberFormat.perSecond(PowerCap.Income(petId, selfBest)) .. " (BRIDÉ : "
				.. NumberFormat.perSecond(PetCatalog.GetIncome(petId)) .. " avec un " .. Config.Rarities[unlock].Name
				.. " à toi)"
			else NumberFormat.perSecond(PetCatalog.GetIncome(petId))
		local stats = PetStats.Of(petId)
		detailSpeed.Text = if known then "+" .. stats.Speed else "?"
		detailStrength.Text = if known then "+" .. stats.Strength else "?"

		local owned = MenuKit.number("Pet_" .. petId)
		local caption = equipButton:FindFirstChild("Caption") :: TextLabel
		if owned <= 0 then
			caption.Text = if known then "Plus à toi" else "Pas découvert"
			UiStyle.setButtonColor(equipButton, GREY)
		elseif equippedCount(petId) > 0 then
			caption.Text = "Déséquiper"
			UiStyle.setButtonColor(equipButton, UiStyle.Colors.Red)
		else
			caption.Text = string.format("Équiper (x%d)", owned)
			UiStyle.setButtonColor(equipButton, UiStyle.Colors.Cyan)
		end
		local baseCaption = baseButton:FindFirstChild("Caption") :: TextLabel
		local inBase = MenuKit.inBase()[petId] == true
		local onlyEquipped = owned > 0 and equippedCount(petId) >= owned
		whereChip.Visible = owned > 0
		if owned <= 0 then
			baseButton.Visible = false
		elseif onlyEquipped then
			baseButton.Visible = false
			whereChip.Text = "ÉQUIPÉ (TE SUIT)"
			whereChip.BackgroundColor3 = UiStyle.Colors.Cyan
		elseif inBase then
			baseButton.Visible = true
			baseCaption.Text = "Retirer"
			UiStyle.setButtonColor(baseButton, UiStyle.Colors.Orange)
			whereChip.Text = "DANS TA BASE"
			whereChip.BackgroundColor3 = UiStyle.Colors.Green
		else
			baseButton.Visible = true
			baseCaption.Text = "Dans la base"
			UiStyle.setButtonColor(baseButton, UiStyle.Colors.Green)
			whereChip.Text = "EN RÉSERVE"
			whereChip.BackgroundColor3 = UiStyle.Colors.Orange
		end

		rewardAmount.Text = if known then NumberFormat.money(Config.GetIndexReward(petId, PowerCap.Max(selfBest))) else "???"
		local claimCaption = claimButton:FindFirstChild("Caption") :: TextLabel
		if canClaim(petId, claimed) then
			claimCaption.Text = "RÉCLAMER !"
			UiStyle.setButtonColor(claimButton, UiStyle.Colors.Green)
		elseif claimed[petId] then
			claimCaption.Text = "RÉCLAMÉ"
			UiStyle.setButtonColor(claimButton, GREY)
		else
			claimCaption.Text = "À DÉCOUVRIR"
			UiStyle.setButtonColor(claimButton, GREY)
		end
	end

	equipButton.Activated:Connect(function()
		local petId = if selectedId then formOf(selectedId, selectedStage, selectedMutation) else nil
		if not petId then
			return
		end
		local owned = MenuKit.number("Pet_" .. petId)
		if owned <= 0 then
			Toast.show("PAS ENCORE À TOI !", UiStyle.Colors.Red)
			Sounds.play("Error")
			return
		end
		local list = MenuKit.equipped()
		if equippedCount(petId) > 0 then
			Remotes.EquipPet:FireServer(petId, false)
		elseif #list < MenuKit.number("EquipSlots") then
			Remotes.EquipPet:FireServer(petId, true)
			-- Seuls les familiers de la base rapportent : on le rappelle au joueur.
			local stats = PetStats.Of(petId)
			Toast.show(
				string.format("ÉQUIPÉ ! +%d VITESSE, +%d FORCE, MAIS IL NE RAPPORTE PLUS D'ARGENT", stats.Speed, stats.Strength),
				UiStyle.Colors.Gold
			)
		else
			Toast.show("PLUS DE PLACE ! DÉSÉQUIPE UN FAMILIER", UiStyle.Colors.Red)
			Sounds.play("Error")
		end
	end)

	baseButton.Activated:Connect(function()
		local petId = if selectedId then formOf(selectedId, selectedStage, selectedMutation) else nil
		if not petId or MenuKit.number("Pet_" .. petId) <= 0 then
			return
		end
		Remotes.BasePick:FireServer(petId, not (MenuKit.inBase()[petId] == true))
	end)
	Remotes.BasePick.OnClientEvent:Connect(function(ok: boolean, reason: string?, petId: string)
		local entry = PetCatalog.ById[petId]
		local name = if entry then TextFormat.upper(entry.Name) else "LE FAMILIER"
		if ok then
			Sounds.play("UiClick")
			Toast.show(if MenuKit.inBase()[petId] == true
				then name .. " RETOURNE EN RÉSERVE"
				else name .. " ARRIVE DANS TA BASE !", UiStyle.Colors.Gold)
		elseif reason == "Full" then
			Sounds.play("Error")
			Toast.show("BASE PLEINE : RETIRE D'ABORD UN FAMILIER QUE TU AS PLACÉ", UiStyle.Colors.Red)
		end
	end)

	claimButton.Activated:Connect(function()
		local petId = if selectedId then formOf(selectedId, selectedStage, selectedMutation) else nil
		if petId and canClaim(petId, MenuKit.claimed()) then
			Remotes.ClaimIndex:FireServer(petId)
		end
	end)

	----------------------------------------------------------------------
	-- Cases de la grille
	----------------------------------------------------------------------
	local function refreshCells()
		local claimed = MenuKit.claimed()
		local equipped = MenuKit.equipped()
		local found = 0
		for _, cell in ipairs(cells) do
			local entry = cell.entry
			local known = MenuKit.discovered(entry.Id, claimed)
			if known then
				found += 1
			end
			if cell.shownDiscovered ~= known or cell.viewport == nil then
				cell.shownDiscovered = known
				if cell.viewport then
					cell.viewport:Destroy()
				end
				local viewport = MenuKit.petViewport(cell.button, entry.Id, not known)
				viewport.Position = UDim2.fromOffset(6, 42)
				viewport.Size = UDim2.new(1, -12, 0, 56)
				viewport.ZIndex = 3
				cell.viewport = viewport
			end
			local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
			local shade = cell.button:FindFirstChildOfClass("UIGradient")
			if shade then
				shade.Color = if known
					then ColorSequence.new(UiStyle.lighter(rarity.Color, 0.35), rarity.Color)
					else ColorSequence.new(UiStyle.darker(rarity.Color, 0.35), UiStyle.darker(rarity.Color, 0.6))
			end
			local border = cell.button:FindFirstChild("Border")
			if border and border:IsA("UIStroke") then
				border.Color = if entry.Id == selectedId then WHITE else BLACK
			end
			local name = cell.button:FindFirstChild("PetName")
			if name and name:IsA("TextLabel") then
				name.Text = if known then entry.Name else "???"
			end
			local count = cell.button:FindFirstChild("Count")
			if count and count:IsA("TextLabel") then
				local owned = MenuKit.number("Pet_" .. entry.Id)
				count.Text = if owned > 0 then "x" .. owned else ""
			end
			local tag = cell.button:FindFirstChild("Equipped")
			local anyEquipped = false
			local best = 1
			for _, formId in ipairs(PetCatalog.FormsOf[entry.Id] or { entry.Id }) do
				if table.find(equipped, formId) then
					anyEquipped = true
				end
				local form = PetCatalog.ById[formId]
				if not form.Mutation and MenuKit.number("Pet_" .. formId) > 0 then
					best = math.max(best, form.Stage or 1)
				end
			end
			-- Où sont les familiers de cette espèce : ÉQUIPÉ (te suit), BASE (rapporte) ou RÉSERVE (ne rapporte pas).
			local anyInBase, anyOwned = false, false
			local inBaseNow = MenuKit.inBase()
			for _, formId in ipairs(PetCatalog.FormsOf[entry.Id] or { entry.Id }) do
				if MenuKit.number("Pet_" .. formId) > 0 then
					anyOwned = true
					if inBaseNow[formId] then
						anyInBase = true
					end
				end
			end
			if tag and tag:IsA("TextLabel") then
				tag.Visible = anyOwned
				tag.Text = if anyInBase then "BASE" elseif anyEquipped then "ÉQUIPÉ" else "RÉSERVE"
				tag.TextColor3 = if anyInBase
					then Color3.fromRGB(140, 255, 100)
					elseif anyEquipped then Color3.fromRGB(120, 220, 255)
					else Color3.fromRGB(255, 180, 80)
			end
			local stars = cell.button:FindFirstChild("Stars")
			if stars and stars:IsA("TextLabel") then
				stars.Text = if best > 1 then string.rep("★", best) else ""
			end
			local badge = cell.button:FindFirstChild("Badge")
			if badge and badge:IsA("TextLabel") then
				UiStyle.setBadge(badge, if waitingFor(entry.Id, claimed) > 0 then "!" else nil)
			end
		end
		local total = #cells
		progressFill.Size = UDim2.fromScale(if total > 0 then found / total else 0, 1)
		progressText.Text = string.format("%d/%d", found, total)
	end

	local function select(petId: string)
		selectedId = petId
		selectedStage = 1
		selectedMutation = nil
		refreshCells()
		refreshDetail()
	end

	local function buildGrid()
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(cells)
		local rarity = Config.Rarities[rarityIndex]
		local claimed = MenuKit.claimed()
		local firstKnown: string? = nil
		for order, entry in ipairs(PetCatalog.ByRarity[rarity.Id] or {}) do
			local button = Instance.new("TextButton")
			button.Name = entry.Id
			button.Text = ""
			button.AutoButtonColor = false
			button.BackgroundColor3 = WHITE
			button.LayoutOrder = order
			button.ZIndex = 2
			UiStyle.corner(button, 6)
			local border = UiStyle.stroke(button, 3, BLACK, true)
			border.Name = "Border"
			UiStyle.gradient(button, rarity.Color, rarity.Color)
			button.Parent = grid
			UiStyle.bounce(button)

			local name = UiStyle.text(button, "???", 16, WHITE, UiStyle.BODY_FONT)
			name.Name = "PetName"
			name.Position = UDim2.fromOffset(8, 6)
			name.Size = UDim2.new(1, -16, 0, 32)
			name.TextWrapped = true
			name.ZIndex = 4
			if entry.World then
				-- Pastille du monde : ce familier ne sort des tirages que là-bas.
				local world = UiStyle.text(button, TextFormat.upper(Config.Worlds[Config.WorldIndex[entry.World] or 1].Name), 12,
					Color3.fromRGB(255, 225, 120), UiStyle.BODY_FONT)
				world.Name = "World"
				world.Position = UDim2.fromOffset(6, 36)
				world.Size = UDim2.new(1, -12, 0, 14)
				world.TextScaled = true
				world.ZIndex = 4
			end
			local count = UiStyle.text(button, "", 16, WHITE)
			count.Name = "Count"
			count.AnchorPoint = Vector2.new(1, 1)
			count.Position = UDim2.new(1, -8, 1, -6)
			count.Size = UDim2.fromOffset(40, 18)
			count.TextXAlignment = Enum.TextXAlignment.Right
			count.ZIndex = 4
			local tag = UiStyle.text(button, "ÉQUIPÉ", 13, Color3.fromRGB(140, 255, 100))
			tag.Name = "Equipped"
			tag.AnchorPoint = Vector2.new(0, 1)
			tag.Position = UDim2.new(0, 6, 1, -6)
			tag.Size = UDim2.new(1, -48, 0, 15)
			tag.TextXAlignment = Enum.TextXAlignment.Left
			tag.TextScaled = true
			tag.ZIndex = 4
			tag.Visible = false
			local stars = UiStyle.text(button, "", 15, GOLD)
			stars.Name = "Stars"
			stars.AnchorPoint = Vector2.new(0.5, 0)
			stars.Position = UDim2.new(0.5, -12, 0, 102)
			stars.Size = UDim2.fromOffset(60, 14)
			stars.ZIndex = 5
			local badge = UiStyle.badge(button)
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, -7, 0, 100)
			badge.Size = UDim2.fromOffset(20, 20)

			button.Activated:Connect(function()
				select(entry.Id)
			end)
			table.insert(cells, { entry = entry, button = button, viewport = nil, shownDiscovered = nil })
			if not firstKnown and MenuKit.discovered(entry.Id, claimed) then
				firstKnown = entry.Id
			end
		end
		grid.CanvasPosition = Vector2.zero
		local list = PetCatalog.ByRarity[rarity.Id] or {}
		selectedId = firstKnown or (if #list > 0 then list[1].Id else nil)
		refreshCells()
		refreshDetail()
	end

	----------------------------------------------------------------------
	-- Onglets de rareté
	----------------------------------------------------------------------
	local tabList: { MenuKit.Tab } = {}
	for _, rarity in ipairs(Config.Rarities) do
		table.insert(tabList, { label = rarity.Name, color = rarity.Color, icon = rarity.Id })
	end
	local tabs = MenuKit.sideTabs(window, tabList, function(index: number)
		rarityIndex = index
		buildRarityCard()
		buildGrid()
	end)

	local function refresh()
		local claimed = MenuKit.claimed()
		local discoveredTotal = 0
		local evolvedTotal = 0
		for index, rarity in ipairs(Config.Rarities) do
			local waiting = 0
			for _, entry in ipairs(PetCatalog.ByRarity[rarity.Id] or {}) do
				if MenuKit.discovered(entry.Id, claimed) then
					discoveredTotal += 1
				end
				for stage = 2, STAGES do
					if formKnown(entry.Id, stage, claimed) then
						evolvedTotal += 1
					end
				end
				waiting += waitingFor(entry.Id, claimed)
			end
			tabs.setBadge(index, if waiting > 0 then tostring(waiting) else nil)
		end
		local claimable = MenuKit.claimableCount()
		claimAllText.Text = if claimable > 0 then string.format("RÉCLAMER TOUT (%d) !", claimable) else "TOUT EST RÉCLAMÉ"
		UiStyle.setButtonColor(claimAll, if claimable > 0 then UiStyle.Colors.Cyan else GREY)
		if collectionLabel then
			local multiplier = MenuKit.player:GetAttribute("Multiplier")
			collectionLabel.Text = string.format(
				"Collection %d/%d\nÉvolutions %d/%d\nÉquipés %d/%d • x%.2f",
				discoveredTotal,
				#PetCatalog.List,
				evolvedTotal,
				#PetCatalog.List * (STAGES - 1),
				#MenuKit.equipped(),
				MenuKit.number("EquipSlots"),
				if type(multiplier) == "number" then multiplier else 1
			)
		end
		if window.isOpen() then
			refreshCells()
			refreshDetail()
		end
	end

	-- Construit à l'ouverture (les aperçus 3D ne coûtent rien tant que la fenêtre est fermée).
	local built = false
	window.onOpen(function()
		if not built then
			built = true
			tabs.select(1)
		end
		refresh()
	end)

	return {
		window = window,
		refresh = refresh,
		-- Les vrais modèles 3D viennent d'arriver : les aperçus sont refaits.
		rebuildViewports = function()
			detailKey = nil
			for _, cell in ipairs(cells) do
				if cell.viewport then
					cell.viewport:Destroy()
					cell.viewport = nil
				end
			end
			if window.isOpen() then
				refreshCells()
				refreshDetail()
			end
		end,
	}
end

return IndexMenu
