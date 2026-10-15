--!strict
-- PullReveal : ouverture des tirages, en bas au centre de l'écran (Remotes.RewardsGranted, détails de
-- server/PullRewards). Les capsules s'ouvrent une par une (Config.Loot.RevealStep) :
--   - « NOUVEAU ! » (doré) pour un familier jamais découvert ;
--   - « VENDU +$X » (carte grisée) pour un doublon vendu tout de suite (Config.Loot.KeepCopies) ;
--   - au plus Config.Loot.RevealCards capsules (les nouveaux, puis les plus rares) ; les autres sont résumés.
-- Un clic sur la rangée ouvre tout d'un coup. Le grand écran des familiers rares (client/Effects) passe ensuite.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local Icons = require(ReplicatedStorage.Shared.Icons)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local UiStyle = require(script.Parent.UiStyle)

local Eggs = require(ReplicatedStorage.Shared.EggIncubation)
local LOOT = Config.Loot
local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(120, 120, 132)
-- Sur tactile : capsules plus petites et moins nombreuses (la rangée ne doit pas passer sous le joystick).
local TOUCH = ScreenScale.isTouch()
local CARD = if TOUCH then Vector2.new(86, 114) else Vector2.new(100, 132)
local GAP = 8
local MAX_CARDS = if TOUCH then math.min(6, LOOT.RevealCards) else LOOT.RevealCards

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "PullReveal"
gui.ResetOnSpawn = false
gui.DisplayOrder = 7
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(gui)

type Drop = { Id: string, New: boolean, Sold: number?, Egg: boolean? }

local current: GuiObject? = nil
local token = 0

-- Ordre d'affichage : les nouveaux, puis les plus rares, les gardés avant les vendus.
local function pick(drops: { Drop }): { Drop }
	local sorted = table.clone(drops)
	table.sort(sorted, function(a, b)
		if a.New ~= b.New then
			return a.New
		end
		local ra = Config.RarityIndex[PetCatalog.ById[a.Id].Rarity] or 0
		local rb = Config.RarityIndex[PetCatalog.ById[b.Id].Rarity] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a.Sold == nil and b.Sold ~= nil
	end)
	local shown = {}
	for index = 1, math.min(#sorted, MAX_CARDS) do
		shown[index] = sorted[index]
	end
	return shown
end

-- Capsule fermée (cadeau) -> carte du familier.
local function capsule(parent: GuiObject, order: number): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	card.BackgroundColor3 = UiStyle.Colors.WindowBody
	card.LayoutOrder = order
	UiStyle.corner(card, 8)
	UiStyle.stroke(card, 3, Color3.new(0, 0, 0), true)
	card.Parent = parent
	local gift = Icons.image(card, "Gift", UDim2.fromOffset(64, 64), UDim2.fromOffset((CARD.X - 64) / 2, (CARD.Y - 64) / 2))
	gift.Name = "Gift"
	return card
end

local function open(card: Frame, drop: Drop)
	local entry = PetCatalog.ById[drop.Id]
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity] or 1]
	local sold = drop.Sold ~= nil
	local gift = card:FindFirstChild("Gift")
	if gift then
		gift:Destroy()
	end
	local color = if sold then GREY else rarity.Color
	card.BackgroundColor3 = WHITE
	UiStyle.gradient(card, UiStyle.lighter(color, 0.3), UiStyle.darker(color, 0.25))
	local viewport = if drop.Egg then MenuKit.eggViewport(card, entry.Rarity) else MenuKit.petViewport(card, drop.Id, false)
	viewport.Position = UDim2.fromOffset(4, 4)
	viewport.Size = UDim2.fromOffset(CARD.X - 8, CARD.Y - 60)
	viewport.ImageTransparency = if sold then 0.45 else 0
	local name = UiStyle.text(card, TextFormat.upper(if drop.Egg then "ŒUF " .. rarity.Name else entry.Name), 14, WHITE, UiStyle.BODY_FONT)
	name.Position = UDim2.fromOffset(3, CARD.Y - 56)
	name.Size = UDim2.fromOffset(CARD.X - 6, 30)
	name.TextWrapped = true
	name.TextScaled = true
	local tag = UiStyle.text(card, "", 16, WHITE)
	tag.Position = UDim2.fromOffset(2, CARD.Y - 26)
	tag.Size = UDim2.fromOffset(CARD.X - 4, 22)
	tag.TextScaled = true
	if sold then
		tag.Text = "VENDU +" .. NumberFormat.money(drop.Sold :: number)
		tag.TextColor3 = UiStyle.Colors.Money
	elseif drop.Egg then
		tag.Text = "ÉCLOSION · " .. Eggs.Time(Eggs.Duration(entry.Rarity))
	elseif drop.New then
		tag.Text = "NOUVEAU !"
		tag.TextColor3 = UiStyle.Colors.Gold
	else
		tag.Text = TextFormat.upper(rarity.Name)
		tag.TextColor3 = UiStyle.lighter(rarity.Color, 0.45)
	end
	-- Petit saut à l'ouverture.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if drop.New then
		Sounds.play("HoleBonus")
	else
		Sounds.play("Pickup")
	end
end

local function close(frame: GuiObject, myToken: number)
	if myToken ~= token then
		return
	end
	TweenService:Create(frame, TweenInfo.new(0.3), { Position = frame.Position + UDim2.fromOffset(0, 220) }):Play()
	task.delay(0.35, function()
		frame:Destroy()
		if current == frame then
			current = nil
		end
	end)
end

Remotes.RewardsGranted.OnClientEvent:Connect(function(_score: number, pulls: number, _results: any, _money: any, details: any)
	if pulls <= 0 or type(details) ~= "table" or type(details.drops) ~= "table" then
		return
	end
	local drops: { Drop } = {}
	for _, drop in ipairs(details.drops) do
		if type(drop) == "table" and type(drop.Id) == "string" and PetCatalog.ById[drop.Id] then
			table.insert(drops, { Id = drop.Id, New = drop.New == true, Egg = drop.Egg == true, Sold = if type(drop.Sold) == "number" then drop.Sold else nil })
		end
	end
	if #drops == 0 then
		return
	end
	if current then
		current:Destroy()
	end
	token += 1
	local myToken = token
	local shown = pick(drops)
	local extra = #drops - #shown

	local row = Instance.new("TextButton")
	row.Name = "Row"
	row.Text = ""
	row.AutoButtonColor = false
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -ScreenScale.BOTTOM_RESERVED)
	local slots = #shown + (if extra > 0 then 1 else 0)
	row.Size = UDim2.fromOffset(slots * (CARD.X + GAP) - GAP, CARD.Y)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	-- Rangée trop large pour l'écran (téléphone) : réduite.
	local fit = Instance.new("UIScale")
	local width = root.AbsoluteSize.X / math.max(ScreenScale.getScale(), 0.01)
	fit.Scale = math.min(1, (width - 32) / math.max(row.Size.X.Offset, 1))
	fit.Parent = row
	row.Parent = root
	current = row

	local cards: { Frame } = {}
	for index in ipairs(shown) do
		cards[index] = capsule(row, index)
	end
	if extra > 0 then
		local more = Instance.new("Frame")
		more.Size = UDim2.fromOffset(CARD.X, CARD.Y)
		more.BackgroundColor3 = UiStyle.Colors.WindowBody
		more.LayoutOrder = #shown + 1
		UiStyle.corner(more, 8)
		UiStyle.stroke(more, 3, Color3.new(0, 0, 0), true)
		local label = UiStyle.number(more, string.format("+%d\nAUTRES", extra), 24, UiStyle.Colors.Gold)
		label.Size = UDim2.fromScale(1, 1)
		label.Visible = false
		label.Name = "Label"
		more.Parent = row
		cards[#shown + 1] = more
	end

	local opened = 0
	local function openNext()
		opened += 1
		local card = cards[opened]
		if not card then
			return
		end
		local drop = shown[opened]
		if drop then
			open(card, drop)
		else
			local label = card:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				label.Visible = true
			end
		end
	end
	local function openAll()
		while opened < #cards do
			openNext()
		end
	end
	row.Activated:Connect(openAll)

	task.spawn(function()
		task.wait(0.35)
		while opened < #cards and myToken == token do
			openNext()
			task.wait(LOOT.RevealStep)
		end
		task.wait(LOOT.RevealHold)
		close(row, myToken)
	end)
end)
