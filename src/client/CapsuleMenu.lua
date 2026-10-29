--!strict
-- CapsuleMenu : menu de la capsule d'évolution (26 oct. 2026), ouvert par [E] devant la capsule (client/EvolutionMachine).
-- Pensé pour les enfants qui lisent peu (dataset_and_pipeline/UI_UX_GUIDELINES.md §7) : des images d'abord, des mots
-- courts et simples, une seule action par bouton.
--   - COMMENT ÇA MARCHE : 3 images (un œuf » un chrono » ★★★) avec « METS UN ŒUF », « ATTENDS », « IL DEVIENT PLUS
--     FORT ! » ; les chances de SA capsule ; le « ? » donne l'explication complète pour ceux qui lisent.
--   - TA CAPSULE : une case par chambre (+1 par Rebirth). Vide : « METS UN ŒUF » (la page descend jusqu'aux œufs).
--     Occupée : l'œuf, ses étoiles, « PRÊT DANS 1:23 » avec une barre, puis « ESSAI ★★ DANS 4:10 » et sa chance,
--     ou « AU MAXIMUM ! » / « IL NE GRANDIRA PLUS » ; gros bouton OUVRIR (ferme le menu pour voir l'éclosion).
--   - TES ŒUFS : les œufs de la couveuse, du plus rare au moins rare, avec leur temps et un bouton METTRE.
--   - 29 oct. : pastille violette « R$ » en haut à droite d'une case ou d'un œuf qui attend : ACCÉLÉRER en Robux (prix
--     selon le temps qui reste, server/SpeedUpController). La case de la capsule tire au sort : pas proposé là où les
--     objets aléatoires payants sont interdits (PolicyService).
-- Le serveur revérifie tout (Remotes.Evolution « Insert » / « Hatch » + id de la chambre, server/EggController ;
-- état des chambres : attribut « ChamberList » de la capsule). Il faut être devant la capsule : le menu se ferme quand
-- on s'éloigne.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.EggIncubation)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local MenuKit = require(script.Parent.MenuKit)
local ShopKit = require(script.Parent.ShopKit)
local Toast = require(script.Parent.Toast)
local UIJuice = require(script.Parent.UIJuiceController)
local UiStyle = require(script.Parent.UiStyle)

local CapsuleMenu = {}

local EVOLUTION = Config.Evolution
local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GREY = Color3.fromRGB(150, 150, 160)
local GOLD = Color3.fromRGB(255, 214, 70)
local PURPLE = Color3.fromRGB(170, 90, 240)
local EMPTY_COLOR = Color3.fromRGB(110, 90, 160)
local K = ShopKit.K
local TOUCH = ShopKit.TOUCH
local STEPS_HEIGHT = if TOUCH then 250 else 206
local CHAMBER_HEIGHT = if TOUCH then 352 else 306
local EGG_HEIGHT = if TOUCH then 330 else 280
local PICTURE = if TOUCH then 104 else 96

-- Accélérer en Robux (client/SpeedUp) : le texte du prix pour une attente de `left` secondes, nil si rien à proposer.
local function speedText(left: number): string?
	if left < Config.SpeedUp.MinSeconds then
		return nil
	end
	local saved = player:GetAttribute("SpeedUps")
	if type(saved) == "number" and saved > 0 then
		return "GRATUIT"
	end
	local product = Config.GetSpeedUpProduct(left)
	return if product then string.format("%d R$", product.Price) else nil
end

-- L'essai de la capsule est tiré au sort : son accélération n'est proposée que si la politique du joueur le permet.
local capsuleSpeedAllowed = false
task.spawn(function()
	local ok, policy = pcall(function(): any
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	capsuleSpeedAllowed = ok and type(policy) == "table" and policy.ArePaidRandomItemsRestricted == false
end)

-- Pastille « ACCÉLÉRER » en haut à droite d'une carte (icône vitesse + prix), cachée tant qu'il n'y a rien à proposer.
local function speedPill(body: Frame, kind: string, eggId: string): TextButton
	local pill = UiStyle.button(body, "", UDim2.fromOffset(math.floor(140 * K), math.floor(40 * K)), PURPLE, 17, true)
	pill.Name = "SpeedUp"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -8, 0, 8)
	pill.ZIndex = 6
	pill.Visible = false
	local side = math.floor(28 * K)
	local icon = Icons.image(pill, "Speed", UDim2.fromOffset(side, side), UDim2.new(0, 6, 0.5, -side / 2))
	icon.ZIndex = 3
	local caption = pill:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		caption.Position = UDim2.new(0, side + 8, 0, 4)
		caption.Size = UDim2.new(1, -(side + 14), 1, -8)
	end
	pill.Activated:Connect(function()
		Remotes.SpeedUp:FireServer(kind, eggId)
	end)
	return pill
end

local function setSpeed(pill: TextButton?, left: number, allowed: boolean)
	if not pill then
		return
	end
	local text = if allowed then speedText(left) else nil
	pill.Visible = text ~= nil
	local caption = pill:FindFirstChild("Caption")
	if text and caption and caption:IsA("TextLabel") and caption.Text ~= text then
		caption.Text = text
	end
end

local function percent(value: number): number
	return math.floor(value * 100 + 0.5)
end

local function rarityOf(id: string): Config.Rarity
	return Config.Rarities[Config.RarityIndex[id] or 1]
end

type Chamber = {
	id: string,
	rarity: string,
	stage: number,
	startedAt: number,
	readyAt: number,
	nextAt: number?,
	done: boolean,
}

-- Chambres occupées, lues sur la capsule (server/EggController : attribut « ChamberList »).
local function readChambers(machine: BasePart): { Chamber }
	local list: { Chamber } = {}
	local raw = machine:GetAttribute("ChamberList")
	if type(raw) ~= "string" then
		return list
	end
	for row in string.gmatch(raw, "[^;]+") do
		local fields = string.split(row, "|")
		if #fields >= 7 then
			table.insert(list, {
				id = fields[1],
				rarity = fields[2],
				stage = tonumber(fields[3]) or 1,
				startedAt = tonumber(fields[4]) or 0,
				readyAt = tonumber(fields[5]) or 0,
				nextAt = tonumber(fields[6]),
				done = fields[7] == "1",
			})
		end
	end
	return list
end

type NestEgg = { key: string, rarity: string, startedAt: number, readyAt: number }

-- Œufs de la couveuse (nids de la base) qu'on peut encore mettre dans la capsule : les plus rares d'abord.
local function readNestEggs(machine: BasePart): { NestEgg }
	local list: { NestEgg } = {}
	local capsule = machine.Parent
	local base = capsule and capsule.Parent
	local folder = base and base:FindFirstChild("Eggs")
	local now = Workspace:GetServerTimeNow()
	if folder then
		for _, anchor in ipairs(folder:GetChildren()) do
			local rarity, startedAt, readyAt = anchor:GetAttribute("Rarity"), anchor:GetAttribute("StartedAt"), anchor:GetAttribute("ReadyAt")
			if anchor:IsA("BasePart") and type(rarity) == "string" and type(readyAt) == "number" and readyAt > now
				and anchor:GetAttribute("Leaving") ~= true then
				table.insert(list, {
					key = anchor.Name,
					rarity = rarity,
					startedAt = if type(startedAt) == "number" then startedAt else readyAt - Eggs.Duration(rarity),
					readyAt = readyAt,
				})
			end
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = Config.RarityIndex[a.rarity] or 0, Config.RarityIndex[b.rarity] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a.readyAt < b.readyAt
	end)
	return list
end

-- Petite image d'œuf en 3D (un ViewportFrame) dans `parent`, centrée en haut.
local function eggPicture(parent: Instance, rarity: string, side: number, y: number): ViewportFrame
	local viewport = MenuKit.eggViewport(parent, rarity)
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = UDim2.new(0.5, 0, 0, y)
	viewport.Size = UDim2.fromOffset(side, side)
	viewport.ZIndex = 4
	return viewport
end

export type Menu = { window: MenuKit.Window, open: (machine: BasePart) -> () }

function CapsuleMenu.create(parent: Instance): Menu
	local window = MenuKit.window(parent, "Capsule", ShopKit.WINDOW, PURPLE, "Egg")
	local machine: BasePart? = nil

	local fxLayer = Instance.new("Frame")
	fxLayer.Name = "Fx"
	fxLayer.BackgroundTransparency = 1
	fxLayer.Size = UDim2.fromScale(1, 1)
	fxLayer.ZIndex = 20
	fxLayer.Parent = window.frame

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
		pagePadding.PaddingLeft = UDim.new(0, 14)
		pagePadding.PaddingTop = UDim.new(0, 12)
		pagePadding.PaddingBottom = UDim.new(0, 16)
	end

	local function tier(): number
		local value = if machine then machine:GetAttribute("CapsuleTier") else nil
		return if type(value) == "number" then value else 1
	end

	-- Comment ça marche ---------------------------------------------------------

	local howSection = ShopKit.section(scroll, 1, "Comment ça marche", "L'œuf devient plus fort", "Egg", PURPLE, "", 1, STEPS_HEIGHT)
	local howCard = ShopKit.card(howSection.grid, PURPLE, 1)
	local howBody = howCard.body
	ShopKit.info(howBody, function()
		return "Mets un œuf dans la capsule. Il reste au chaud : il ne sort plus tout seul.\n"
			.. "Quand son temps est fini, la capsule essaie de le faire grandir : ★★ (il gagne " .. EVOLUTION.IncomeMultiplier[2]
			.. " fois plus d'argent), puis ★★★ (" .. EVOLUTION.IncomeMultiplier[3] .. " fois plus). C'est de la chance : parfois ça rate.\n"
			.. "Tu l'ouvres quand tu veux avec OUVRIR. Plus tu attends, plus il peut grandir !"
	end)
	-- Trois images, reliées par des flèches.
	local steps = Instance.new("Frame")
	steps.BackgroundTransparency = 1
	steps.Position = UDim2.fromOffset(12, 10)
	steps.Size = UDim2.new(1, -24 - math.floor(40 * K), 0, PICTURE + math.floor(34 * K) + 6)
	steps.Parent = howBody
	local captions = { "METS UN ŒUF", "ATTENDS", "IL DEVIENT PLUS FORT !" }
	for index = 1, 3 do
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.Position = UDim2.new((index - 1) / 3, 0, 0, 0)
		cell.Size = UDim2.new(1 / 3, 0, 1, 0)
		cell.Parent = steps
		local picture = Instance.new("Frame")
		picture.BackgroundTransparency = 1
		picture.AnchorPoint = Vector2.new(0.5, 0)
		picture.Position = UDim2.fromScale(0.5, 0)
		picture.Size = UDim2.fromOffset(PICTURE, PICTURE)
		picture.ZIndex = 3
		picture.Parent = cell
		if index == 1 then
			local egg = MenuKit.eggViewport(picture, "Rare")
			egg.Size = UDim2.fromScale(1, 1)
			egg.ZIndex = 4
		elseif index == 2 then
			-- Un chrono : un rond sombre avec un temps qui défile.
			local clock = ShopKit.label(picture, "0:30", 30)
			clock.BackgroundTransparency = 0
			clock.BackgroundColor3 = UiStyle.Colors.Panel
			clock.Size = UDim2.fromScale(1, 1)
			clock.ZIndex = 4
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = clock
			UiStyle.stroke(clock, 4, GOLD, true)
			task.spawn(function()
				local seconds = 30
				while clock.Parent do
					task.wait(0.4)
					seconds = if seconds <= 0 then 30 else seconds - 1
					clock.Text = Eggs.Time(seconds)
				end
			end)
		else
			local crown = Icons.image(picture, "Crown", UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0))
			crown.ZIndex = 4
			UiStyle.sway(crown, 6)
			local gold = ShopKit.label(picture, "★★★", 26, GOLD)
			gold.AnchorPoint = Vector2.new(0.5, 1)
			gold.Position = UDim2.new(0.5, 0, 1, 4)
			gold.Size = UDim2.new(1.2, 0, 0, math.floor(28 * K))
			gold.ZIndex = 5
		end
		local caption = ShopKit.label(cell, captions[index], 22)
		caption.AnchorPoint = Vector2.new(0.5, 1)
		caption.Position = UDim2.fromScale(0.5, 1)
		caption.Size = UDim2.new(1, -12, 0, math.floor(34 * K))
		caption.ZIndex = 3
		if index < 3 then
			local arrow = ShopKit.label(cell, "»", 64, GOLD)
			arrow.AnchorPoint = Vector2.new(0.5, 0.5)
			arrow.Position = UDim2.new(1, 0, 0, PICTURE / 2)
			arrow.Size = UDim2.fromOffset(math.floor(50 * K), math.floor(60 * K))
			arrow.ZIndex = 4
		end
	end
	-- Les chances de SA capsule (elle s'améliore avec les mondes).
	local chancesRow = Instance.new("Frame")
	chancesRow.BackgroundTransparency = 1
	chancesRow.AnchorPoint = Vector2.new(0, 1)
	chancesRow.Position = UDim2.new(0, 12, 1, -10)
	chancesRow.Size = UDim2.new(1, -24, 0, math.floor(32 * K))
	chancesRow.Parent = howBody
	local chanceTexts: { TextLabel } = {}
	for slot = 0, 2 do
		local chip, text = ShopKit.chip(chancesRow, 18)
		chip.Position = UDim2.new(slot / 3, if slot > 0 then 4 else 0, 0, 0)
		chip.Size = UDim2.new(1 / 3, -6, 1, 0)
		text.TextColor3 = GOLD
		table.insert(chanceTexts, text)
	end

	-- Ta capsule (chambres) ---------------------------------------------------------

	local chamberSection = ShopKit.section(scroll, 2, "Ta capsule", "Un œuf par case", "Sparkle", Color3.fromRGB(120, 70, 210), "", ShopKit.COLUMNS, CHAMBER_HEIGHT)
	local eggSection = ShopKit.section(scroll, 3, "Tes œufs", "Choisis un œuf à mettre", "Egg", Color3.fromRGB(255, 150, 40), "", ShopKit.COLUMNS, EGG_HEIGHT)

	-- Fait descendre la page jusqu'à une section.
	local function scrollTo(section: ShopKit.Section)
		local ratio = scroll.AbsoluteWindowSize.Y / math.max(1, scroll.AbsoluteSize.Y)
		local y = (section.frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y) * ratio + scroll.CanvasPosition.Y - 10
		local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
		TweenService:Create(scroll, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ CanvasPosition = Vector2.new(0, math.clamp(y, 0, maxY)) }):Play()
	end

	type ChamberUi = { chamber: Chamber?, body: Frame, status: TextLabel?, gauge: ShopKit.Gauge?, button: TextButton, speed: TextButton? }
	local chamberUis: { ChamberUi } = {}
	local chamberKey = ""

	type EggUi = { egg: NestEgg, body: Frame, gauge: ShopKit.Gauge, button: TextButton, speed: TextButton? }
	local eggUis: { EggUi } = {}
	local eggKey = ""
	local eggCards: { Frame } = {}
	local emptyEggs: Frame? = nil

	local function freeChambers(): number
		local total = if machine then machine:GetAttribute("Chambers") else nil
		local used = if machine then #readChambers(machine) else 0
		return (if type(total) == "number" then total else EVOLUTION.Slots) - used
	end

	local function buildChambers(list: { Chamber }, total: number)
		for _, ui in ipairs(chamberUis) do
			local holder = ui.body.Parent
			if holder then
				holder:Destroy()
			end
		end
		table.clear(chamberUis)
		for slot = 1, math.max(total, #list) do
			local chamber = list[slot]
			local color = if chamber then rarityOf(chamber.rarity).Color else EMPTY_COLOR
			local card = ShopKit.card(chamberSection.grid, color, slot)
			local body = card.body
			local number = ShopKit.label(body, tostring(slot), 22)
			number.BackgroundTransparency = 0
			number.BackgroundColor3 = UiStyle.Colors.Panel
			number.Position = UDim2.fromOffset(10, 10)
			number.Size = UDim2.fromOffset(math.floor(34 * K), math.floor(34 * K))
			number.ZIndex = 5
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = number
			UiStyle.stroke(number, 3, BLACK, true)
			local button = ShopKit.buyButton(body, UiStyle.Colors.Green)
			if not chamber then
				-- Case vide : un œuf transparent et un gros « + ».
				local ghost = Icons.image(body, "Egg", UDim2.fromOffset(PICTURE + 10, PICTURE + 10))
				ghost.AnchorPoint = Vector2.new(0.5, 0)
				ghost.Position = UDim2.new(0.5, 0, 0, 16)
				ghost.ImageTransparency = 0.6
				ghost.ZIndex = 3
				local plus = ShopKit.label(body, "+", 70, WHITE)
				plus.AnchorPoint = Vector2.new(0.5, 0)
				plus.Position = UDim2.new(0.5, 0, 0, 16 + PICTURE / 4)
				plus.Size = UDim2.fromOffset(80, PICTURE / 2 + 10)
				plus.ZIndex = 4
				local empty = ShopKit.label(body, "CASE VIDE", 24)
				empty.Position = UDim2.fromOffset(12, PICTURE + 36)
				empty.Size = UDim2.new(1, -24, 0, math.floor(30 * K))
				empty.ZIndex = 3
				ShopKit.setButton(button, "METS UN ŒUF", UiStyle.Colors.Green)
				button.Activated:Connect(function()
					scrollTo(eggSection)
					for _, eggCard in ipairs(eggCards) do
						UIJuice.pop(eggCard, 0.08)
					end
				end)
				table.insert(chamberUis, { chamber = nil, body = body, button = button })
			else
				eggPicture(body, chamber.rarity, PICTURE, 12)
				local y = 12 + PICTURE + 2
				-- Seulement des étoiles pleines et dorées : un enfant les compte (★☆☆ en petit ressemblait à ☆☆☆).
				local starLabel = ShopKit.label(body, string.rep("★", chamber.stage), 34, GOLD)
				starLabel.Position = UDim2.fromOffset(12, y)
				starLabel.Size = UDim2.new(1, -24, 0, math.floor(34 * K))
				starLabel.ZIndex = 3
				y += math.floor(34 * K)
				local status = ShopKit.label(body, "", 20)
				status.Position = UDim2.fromOffset(12, y)
				status.Size = UDim2.new(1, -24, 0, math.floor(26 * K))
				status.ZIndex = 3
				y += math.floor(26 * K) + 4
				local gauge = ShopKit.gauge(body, GOLD)
				gauge.frame.Position = UDim2.fromOffset(14, y)
				gauge.frame.Size = UDim2.new(1, -28, 0, math.floor(26 * K))
				local chamberId = chamber.id
				button.Activated:Connect(function()
					local current: Chamber? = nil
					for _, item in ipairs(if machine then readChambers(machine) else {}) do
						if item.id == chamberId then
							current = item
						end
					end
					if not current then
						return
					end
					local left = current.readyAt - Workspace:GetServerTimeNow()
					if left > 0 then
						UIJuice.denied(body)
						Toast.show("PAS ENCORE ! ATTENDS " .. Eggs.Time(left), Color3.fromRGB(255, 140, 140))
						return
					end
					Remotes.Evolution:FireServer("Hatch", chamberId)
					window.close() -- l'éclosion se joue au-dessus de la capsule : on la regarde
				end)
				local speed = speedPill(body, "Capsule", chamberId)
				table.insert(chamberUis, { chamber = chamber, body = body, status = status, gauge = gauge, button = button, speed = speed })
			end
		end
	end

	local function buildEggs(list: { NestEgg })
		for _, ui in ipairs(eggUis) do
			local holder = ui.body.Parent
			if holder then
				holder:Destroy()
			end
		end
		table.clear(eggUis)
		table.clear(eggCards)
		local placeholder = emptyEggs
		if placeholder then
			local holder = placeholder.Parent
			if holder then
				holder:Destroy()
			end
			emptyEggs = nil
		end
		if #list == 0 then
			-- Pas d'œuf : on dit simplement comment en avoir.
			local card = ShopKit.card(eggSection.grid, Color3.fromRGB(255, 150, 40), 1)
			local icon = Icons.image(card.body, "Vortex", UDim2.fromOffset(PICTURE, PICTURE))
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 16)
			icon.ZIndex = 3
			UiStyle.spin(icon, 30)
			local title = ShopKit.label(card.body, "PAS D'ŒUF", 26)
			title.Position = UDim2.fromOffset(12, PICTURE + 26)
			title.Size = UDim2.new(1, -24, 0, math.floor(32 * K))
			title.ZIndex = 3
			local tip = ShopKit.label(card.body, "JETTE DES OBJETS DANS LE TROU NOIR !", 20)
			tip.TextWrapped = true
			tip.Position = UDim2.fromOffset(12, PICTURE + 30 + math.floor(32 * K))
			tip.Size = UDim2.new(1, -24, 0, math.floor(56 * K))
			tip.ZIndex = 3
			emptyEggs = card.body
			return
		end
		for order, egg in ipairs(list) do
			local rarity = rarityOf(egg.rarity)
			local card = ShopKit.card(eggSection.grid, rarity.Color, order)
			local body = card.body
			eggPicture(body, egg.rarity, PICTURE, 12)
			local y = 12 + PICTURE + 2
			local name = ShopKit.label(body, "ŒUF " .. TextFormat.upper(rarity.Name), 24)
			name.Position = UDim2.fromOffset(12, y)
			name.Size = UDim2.new(1, -24, 0, math.floor(30 * K))
			name.ZIndex = 3
			y += math.floor(30 * K) + 4
			local gauge = ShopKit.gauge(body, UiStyle.Colors.Cyan)
			gauge.frame.Position = UDim2.fromOffset(14, y)
			gauge.frame.Size = UDim2.new(1, -28, 0, math.floor(26 * K))
			local button = ShopKit.buyButton(body, UiStyle.Colors.Green)
			ShopKit.setButton(button, "METTRE", UiStyle.Colors.Green)
			local eggKeyName = egg.key
			button.Activated:Connect(function()
				if freeChambers() <= 0 then
					UIJuice.denied(body)
					Toast.show("TA CAPSULE EST PLEINE ! OUVRE UN ŒUF D'ABORD", Color3.fromRGB(255, 140, 140))
					return
				end
				UIJuice.purchased(body, button, fxLayer)
				Remotes.Evolution:FireServer("Insert", eggKeyName)
			end)
			local eggId = string.match(eggKeyName, "^(.-)#%d+$")
			local speed = if eggId then speedPill(body, "Nest", eggId) else nil
			table.insert(eggUis, { egg = egg, body = body, gauge = gauge, button = button, speed = speed })
			table.insert(eggCards, body)
		end
	end

	-- Mise à jour (fenêtre ouverte) : les cases sont refaites quand le contenu change, les temps à chaque passage.
	local function refresh()
		local part = machine
		if not part then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local level = tier()
		local weights = Eggs.MaxStageWeights(level)
		local total = 0
		for _, weight in ipairs(weights) do
			total += weight
		end
		chanceTexts[1].Text = "★★  " .. percent(Eggs.StageChance(1, level)) .. " %"
		chanceTexts[2].Text = "★★★  " .. percent(weights[#weights] / math.max(total, 1)) .. " %"
		local faster = percent(EVOLUTION.SpeedPerTier * (level - 1))
		chanceTexts[3].Text = if faster > 0 then "+" .. faster .. " % PLUS VITE" else "CAPSULE " .. TextFormat.upper(Config.GetWorld(level).Name)

		local list = readChambers(part)
		local slots = part:GetAttribute("Chambers")
		local count = if type(slots) == "number" then slots else EVOLUTION.Slots
		local signature = tostring(count)
		for _, chamber in ipairs(list) do
			signature ..= ";" .. chamber.id .. chamber.stage .. (if chamber.done then "d" else "")
		end
		if signature ~= chamberKey then
			chamberKey = signature
			buildChambers(list, count)
		end
		for _, ui in ipairs(chamberUis) do
			local chamber = ui.chamber
			local status, gauge = ui.status, ui.gauge
			if chamber and status and gauge then
				-- Accélérer : jusqu'à la prochaine tentative (ou la fin de l'incubation s'il n'évoluera plus).
				local target = if not chamber.done and chamber.nextAt then math.max(chamber.readyAt, chamber.nextAt) else chamber.readyAt
				setSpeed(ui.speed, target - now, capsuleSpeedAllowed)
				local left = chamber.readyAt - now
				if left > 0 then
					status.Text = "PRÊT DANS " .. Eggs.Time(left)
					status.TextColor3 = WHITE
					local length = math.max(1, chamber.readyAt - chamber.startedAt)
					ShopKit.setGauge(gauge, 1 - left / length, Eggs.Time(left))
					ShopKit.setButton(ui.button, "ATTENDS", GREY)
				elseif chamber.done then
					local best = chamber.stage >= #EVOLUTION.Names
					status.Text = if best then "AU MAXIMUM !" else "IL NE GRANDIRA PLUS"
					status.TextColor3 = if best then GOLD else Color3.fromRGB(255, 170, 170)
					ShopKit.setGauge(gauge, 1, string.rep("★", chamber.stage))
					ShopKit.setButton(ui.button, "OUVRIR !", UiStyle.Colors.Green)
				else
					local nextAt = chamber.nextAt or now
					local chance = percent(Eggs.StageChance(chamber.stage, level))
					status.Text = "ESSAI " .. string.rep("★", chamber.stage + 1) .. " DANS " .. Eggs.Time(nextAt - now)
					status.TextColor3 = WHITE
					ShopKit.setGauge(gauge, chance / 100, "CHANCE " .. chance .. " %")
					ShopKit.setButton(ui.button, "OUVRIR", UiStyle.Colors.Green)
				end
			end
		end

		local eggs = readNestEggs(part)
		local keys = {}
		for _, egg in ipairs(eggs) do
			table.insert(keys, egg.key)
		end
		local eggSignature = table.concat(keys, ",")
		if eggSignature ~= eggKey then
			eggKey = eggSignature
			buildEggs(eggs)
		end
		local free = freeChambers() > 0
		for _, ui in ipairs(eggUis) do
			local left = ui.egg.readyAt - now
			local length = math.max(1, ui.egg.readyAt - ui.egg.startedAt)
			ShopKit.setGauge(ui.gauge, 1 - left / length, "ÉCLOT DANS " .. Eggs.Time(left))
			setSpeed(ui.speed, left, true)
			ShopKit.setButton(ui.button, if free then "METTRE" else "PLEIN", if free then UiStyle.Colors.Green else GREY)
		end
	end

	-- Tant que la fenêtre est ouverte : temps qui défilent ; elle se ferme si on s'éloigne de la capsule.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		if not window.isOpen() then
			return
		end
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local part = machine
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if part and root and root:IsA("BasePart") and (root.Position - part.Position).Magnitude > EVOLUTION.UseDistance + 4 then
			window.close()
			return
		end
		refresh()
	end)

	return {
		window = window,
		open = function(part: BasePart)
			machine = part
			chamberKey, eggKey = "", ""
			refresh()
			scroll.CanvasPosition = Vector2.zero
			window.open()
		end,
	}
end

return CapsuleMenu
