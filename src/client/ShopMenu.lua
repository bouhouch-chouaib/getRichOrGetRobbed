--!strict
-- ShopMenu : fenêtre BOUTIQUE (améliorations de Config.Shop), sur le modèle des boutiques de la référence :
-- en-tête vert, rangée de grandes cartes colorées qui défile de gauche à droite (rayons de soleil, tenons),
-- chaque carte = nom, niveau, grosse icône, description, effet « actuel ➜ suivant », bouton de prix.
-- Onglets à droite : Entraînement / Bonus / Combat (pastille « ! » quand un achat est possible), puis le contenu
-- Robux (client/RobuxShop) : Passes R$ / Produits R$ / Chances (plus de bouton Robux à part sur l'écran).
-- Le serveur valide chaque achat (Remotes.BuyUpgrade, MonetizationController pour les Robux).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Icons = require(ReplicatedStorage.Shared.Icons)
local MenuKit = require(script.Parent.MenuKit)
local RobuxShop = require(script.Parent.RobuxShop)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local ShopMenu = {}

local WHITE = Color3.new(1, 1, 1)
local CHIP = Color3.fromRGB(70, 70, 82)
local GREY = Color3.fromRGB(150, 150, 160)
local CARD_WIDTH = 214

type Category = { label: string, icon: string, color: Color3, ids: { string } }

local CATEGORIES: { Category } = {
	{ label = "Entraînement", icon = "Treadmill", color = UiStyle.Colors.Cyan, ids = { "Treadmill", "Bench" } },
	{ label = "Bonus", icon = "Clover", color = UiStyle.Colors.Green, ids = { "ItemQuality", "Backpack", "Magnet", "LongLock" } },
	{ label = "Combat", icon = "Bat", color = Color3.fromRGB(240, 70, 90), ids = { "WeaponBat", "WeaponGrapple", "PowerInvisible" } },
}

-- Couleur de chaque carte.
local CARD_COLORS: { [string]: Color3 } = {
	Treadmill = Color3.fromRGB(50, 165, 255),
	Bench = Color3.fromRGB(255, 140, 40),
	ItemQuality = Color3.fromRGB(70, 210, 60),
	Backpack = Color3.fromRGB(235, 70, 70),
	LongLock = Color3.fromRGB(150, 80, 255),
	Magnet = Color3.fromRGB(255, 80, 120),
	WeaponBat = Color3.fromRGB(230, 130, 50),
	WeaponGrapple = Color3.fromRGB(70, 170, 255),
	PowerInvisible = Color3.fromRGB(150, 90, 240),
}

local itemsById: { [string]: Config.ShopItem } = {}
for _, item in ipairs(Config.Shop) do
	itemsById[item.Id] = item
end
-- Une amélioration ajoutée plus tard dans Config.Shop sans catégorie va dans « Bonus ».
do
	local listed: { [string]: boolean } = {}
	for _, category in ipairs(CATEGORIES) do
		for _, id in ipairs(category.ids) do
			listed[id] = true
		end
	end
	for _, item in ipairs(Config.Shop) do
		if not listed[item.Id] then
			table.insert(CATEGORIES[2].ids, item.Id)
		end
	end
end

-- Effet de l'amélioration au niveau donné (texte court de la puce).
local function effectAt(id: string, level: number): string?
	if id == "Treadmill" or id == "Bench" then
		return "x" .. NumberFormat.short(if level > 0 then Config.GetStationRate(level) else 0) .. " XP"
	elseif id == "ItemQuality" then
		return "+" .. level * 50 .. " % chance"
	elseif id == "Backpack" then
		local count = 1 + level
		return count .. " objet" .. (if count > 1 then "s" else "")
	elseif id == "Magnet" then
		return if level > 0 then "Portée " .. Config.Magnet.Radius[math.min(level, #Config.Magnet.Radius)] .. " studs" else "Aucun aimant"
	elseif id == "LongLock" then
		return "Verrou " .. Config.GetLockDuration(level > 0, 0) .. " s"
	end
	return nil
end

local function effectText(item: Config.ShopItem, level: number): string
	local now = effectAt(item.Id, level)
	if not now then
		return if level > 0 then "Dans ton inventaire" elseif item.Id:sub(1, 5) == "Power" then "Pouvoir" else "Arme de combat"
	end
	if level >= item.MaxLevel then
		return now
	end
	return now .. "  >  " .. (effectAt(item.Id, level + 1) or "")
end

type Card = { item: Config.ShopItem, level: TextLabel, effect: TextLabel, buy: TextButton }

export type Shop = {
	window: MenuKit.Window,
	refresh: () -> (),
	affordableCount: () -> number,
}

-- topStack : pile du haut du HUD (le bandeau du boost de chance serveur y apparaît).
function ShopMenu.create(gui: Instance, topStack: Frame): Shop
	local window = MenuKit.window(gui, "Boutique", Vector2.new(740, 480), UiStyle.Colors.Green, "Shop")

	local row = Instance.new("ScrollingFrame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = UDim2.fromScale(1, 1)
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.ScrollBarThickness = 8
	row.ScrollBarImageColor3 = WHITE
	row.ZIndex = 2
	row.Parent = window.content
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	UiStyle.scrollPadding(row)

	local cards: { Card } = {}
	-- Hauteur de la zone de contenu (taille de la fenêtre moins en-tête et marges), moins la barre de défilement.
	local cardHeight = window.frame.Size.Y.Offset + window.content.Size.Y.Offset - 28

	local function makeCard(item: Config.ShopItem, order: number): Card
		local color = CARD_COLORS[item.Id] or UiStyle.Colors.Green
		local card = UiStyle.brightCard(row, UDim2.fromOffset(CARD_WIDTH, cardHeight), color)
		card.LayoutOrder = order

		local name = UiStyle.text(card, item.Name, 26, WHITE, UiStyle.BODY_FONT)
		name.Position = UDim2.fromOffset(12, 8)
		name.Size = UDim2.new(1, -24, 0, 30)
		name.TextScaled = true
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 26
		nameLimit.Parent = name

		local level = UiStyle.text(card, "", 18, WHITE, UiStyle.BODY_FONT)
		level.Position = UDim2.fromOffset(12, 42)
		level.Size = UDim2.new(1, -24, 0, 22)

		Icons.image(card, item.Icon, UDim2.new(1, -60, 0, 106), UDim2.fromOffset(30, 70))

		local descriptionBox = Instance.new("Frame")
		descriptionBox.BackgroundColor3 = Color3.new(0, 0, 0)
		descriptionBox.BackgroundTransparency = 0.55
		descriptionBox.BorderSizePixel = 0
		descriptionBox.Position = UDim2.new(0, 10, 1, -176)
		descriptionBox.Size = UDim2.new(1, -20, 0, 68)
		UiStyle.corner(descriptionBox, 6)
		descriptionBox.Parent = card
		local description = Instance.new("TextLabel")
		description.BackgroundTransparency = 1
		description.Position = UDim2.fromOffset(8, 6)
		description.Size = UDim2.new(1, -16, 1, -12)
		description.FontFace = UiStyle.BODY_FONT
		description.Text = item.Description
		description.TextColor3 = WHITE
		description.TextScaled = true
		description.TextWrapped = true
		local descriptionLimit = Instance.new("UITextSizeConstraint")
		descriptionLimit.MaxTextSize = 14
		descriptionLimit.Parent = description
		description.Parent = descriptionBox

		local chip = Instance.new("Frame")
		chip.BackgroundColor3 = CHIP
		chip.BorderSizePixel = 0
		chip.Position = UDim2.new(0, 10, 1, -100)
		chip.Size = UDim2.new(1, -20, 0, 36)
		UiStyle.corner(chip, 6)
		UiStyle.stroke(chip, 3, Color3.new(0, 0, 0), true)
		chip.Parent = card
		local effect = UiStyle.text(chip, "", 20, WHITE, UiStyle.BODY_FONT)
		effect.Size = UDim2.new(1, -16, 1, -10)
		effect.Position = UDim2.fromOffset(8, 5)
		effect.TextScaled = true
		local effectLimit = Instance.new("UITextSizeConstraint")
		effectLimit.MaxTextSize = 20
		effectLimit.Parent = effect

		local buy = UiStyle.button(card, "", UDim2.new(1, -20, 0, 50), UiStyle.Colors.Green, 30)
		buy.Position = UDim2.new(0, 10, 1, -56)
		local caption = buy:FindFirstChild("Caption")
		if caption and caption:IsA("TextLabel") then
			caption.FontFace = UiStyle.NUMBER_FONT
		end
		buy.Activated:Connect(function()
			local price = Config.GetUpgradePrice(item, MenuKit.number("Upgrade_" .. item.Id))
			if not price then
				return
			end
			if MenuKit.number("Money") < price then
				Toast.show("PAS ASSEZ D'ARGENT !", UiStyle.Colors.Red)
				Sounds.play("Error")
				return
			end
			Remotes.BuyUpgrade:FireServer(item.Id)
		end)
		return { item = item, level = level, effect = effect, buy = buy }
	end

	local tabs: MenuKit.Tabs
	local function affordableIn(category: Category): number
		local money = MenuKit.number("Money")
		local count = 0
		for _, id in ipairs(category.ids) do
			local item = itemsById[id]
			local price = item and Config.GetUpgradePrice(item, MenuKit.number("Upgrade_" .. id))
			if price and money >= price then
				count += 1
			end
		end
		return count
	end

	local function refresh()
		local money = MenuKit.number("Money")
		for _, card in ipairs(cards) do
			local item = card.item
			local level = MenuKit.number("Upgrade_" .. item.Id)
			local price = Config.GetUpgradePrice(item, level)
			card.level.Text = if item.MaxLevel > 1 then string.format("Niveau %d / %d", level, item.MaxLevel) elseif level > 0 then "Acquis !" else "Achat unique"
			card.effect.Text = effectText(item, level)
			local caption = card.buy:FindFirstChild("Caption") :: TextLabel
			if not price then
				caption.Text = if item.MaxLevel > 1 then "MAX !" else "ACQUIS"
				UiStyle.setButtonColor(card.buy, GREY)
			else
				caption.Text = NumberFormat.money(price)
				UiStyle.setButtonColor(card.buy, if money >= price then UiStyle.Colors.Green else UiStyle.Colors.Red)
			end
		end
		if tabs then
			for index, category in ipairs(CATEGORIES) do
				tabs.setBadge(index, if affordableIn(category) > 0 then "!" else nil)
			end
		end
	end

	-- Onglets Robux, après les catégories d'améliorations.
	local robux = RobuxShop.create(window.content, cardHeight, topStack)

	local function showCategory(index: number)
		row.Visible = index <= #CATEGORIES
		robux.show(math.max(0, index - #CATEGORIES))
		if index > #CATEGORIES then
			robux.refresh()
			return
		end
		for _, child in ipairs(row:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(cards)
		for order, id in ipairs(CATEGORIES[index].ids) do
			local item = itemsById[id]
			if item then
				table.insert(cards, makeCard(item, order))
			end
		end
		row.CanvasPosition = Vector2.zero
		refresh()
	end

	local tabList: { MenuKit.Tab } = {}
	for _, category in ipairs(CATEGORIES) do
		table.insert(tabList, { label = category.label, color = category.color, icon = category.icon })
	end
	table.insert(tabList, { label = "Passes R$", color = UiStyle.Colors.Gold, icon = "Crown" })
	table.insert(tabList, { label = "Produits R$", color = Color3.fromRGB(200, 40, 240), icon = "Gift" })
	table.insert(tabList, { label = "Chances", color = Color3.fromRGB(120, 120, 140), icon = "Dice" })
	tabs = MenuKit.sideTabs(window, tabList, showCategory)
	showCategory(1)
	window.onOpen(function()
		if MenuKit.player:GetAttribute("StarterBonusPaid") == true and MenuKit.player:GetAttribute("Onboarding_Upgraded") ~= true then
			tabs.select(1) -- les deux premières stations sont achetables avec la prime de départ
		end
		robux.refresh()
	end)

	return {
		window = window,
		refresh = refresh,
		affordableCount = function()
			local total = 0
			for _, category in ipairs(CATEGORIES) do
				total += affordableIn(category)
			end
			return total
		end,
	}
end

return ShopMenu
