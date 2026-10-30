--!strict
-- ShopMenu : fenêtre BOUTIQUE en une seule page qui défile de haut en bas (refaite le 26 oct. 2026, phase 1.8 ;
-- règles et audit de l'ancienne version : dataset_and_pipeline/UI_UX_GUIDELINES.md) :
--   - en-tête : l'argent du joueur (compteur qui défile) ; dessous, une pastille par section : un clic fait glisser la
--     page jusqu'à la section, la pastille de la section visible s'allume, « ! » = un achat possible dans la section ;
--   - À LA UNE : l'amélioration conseillée (la moins chère qu'on peut s'offrir, sinon la moins chère) et l'offre Robux
--     exclusive (client/RobuxShop) ;
--   - Entraînement, Bonus, Combat : cartes d'amélioration (grosse icône, jauge de niveau, effet « actuel » » « suivant »,
--     énorme bouton de prix, « ? » pour la description complète) ;
--   - Passes R$, Produits R$, Chances (client/RobuxShop).
-- Briques : client/ShopKit ; effets : client/UIJuiceController (carte qui saute et pièces à l'achat, secousse et éclair
-- rouge s'il manque de l'argent). Le serveur valide chaque achat (Remotes.BuyUpgrade, server/EconomyController ; Robux :
-- server/MonetizationController) : rien n'a changé côté serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MenuKit = require(script.Parent.MenuKit)
local RobuxShop = require(script.Parent.RobuxShop)
local ShopKit = require(script.Parent.ShopKit)
local Toast = require(script.Parent.Toast)
local UIJuice = require(script.Parent.UIJuiceController)
local UiStyle = require(script.Parent.UiStyle)

local ShopMenu = {}

local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(150, 150, 160)
local K = ShopKit.K

type Category = { title: string, subtitle: string, pill: string, icon: string, color: Color3, ids: { string } }

local CATEGORIES: { Category } = {
	{ title = "Entraînement", subtitle = "Plus vite, plus fort", pill = "SPORT", icon = "Treadmill", color = UiStyle.Colors.Speed, ids = { "Treadmill", "Bench" } },
	{ title = "Bonus", subtitle = "Plus d'objets, plus de place", pill = "BONUS", icon = "Clover", color = UiStyle.Colors.Green, ids = { "EggSlots", "ItemQuality", "Backpack", "Magnet", "LongLock" } },
	{ title = "Combat", subtitle = "Arrête les voleurs", pill = "COMBAT", icon = "Bat", color = Color3.fromRGB(240, 70, 90), ids = { "WeaponBat", "WeaponGrapple", "PowerInvisible" } },
}

-- Couleur de chaque carte (UI_UX_GUIDELINES.md §2.1 : cyan = vitesse, orange = force, rouge = combat...).
local CARD_COLORS: { [string]: Color3 } = {
	Treadmill = UiStyle.Colors.Speed,
	Bench = UiStyle.Colors.Strength,
	ItemQuality = Color3.fromRGB(70, 210, 60),
	Backpack = Color3.fromRGB(40, 190, 150),
	Magnet = Color3.fromRGB(150, 210, 40),
	LongLock = Color3.fromRGB(150, 80, 255),
	EggSlots = Color3.fromRGB(255, 170, 40),
	WeaponBat = Color3.fromRGB(230, 100, 50),
	WeaponGrapple = Color3.fromRGB(235, 60, 90),
	PowerInvisible = Color3.fromRGB(150, 90, 240),
}

-- Phrase courte sous l'effet (la description complète est dans le « ? »).
local SHORT: { [string]: string } = {
	Treadmill = "Cours dessus : + vitesse",
	Bench = "Allonge-toi dessus : + force",
	ItemQuality = "Objets précieux plus fréquents",
	Backpack = "Porte plus d'objets à la fois",
	Magnet = "Les objets sautent vers toi",
	LongLock = "Ta base reste fermée plus longtemps",
	EggSlots = "Plus d'œufs chauffent en même temps",
	WeaponBat = "Fais tout lâcher à un voleur",
	WeaponGrapple = "Ramène un joueur jusqu'à toi",
	PowerInvisible = string.format("%d s presque invisible", Config.Weapons.Invisibility.Duration),
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

-- Effet de l'amélioration au niveau donné (texte court de l'encart), lu dans Config.
local function effectAt(id: string, level: number): string?
	if id == "Treadmill" or id == "Bench" then
		return "x" .. NumberFormat.short(if level > 0 then Config.GetStationRate(level) else 0) .. " XP"
	elseif id == "ItemQuality" then
		return "Rares +" .. math.floor(level * Config.Items.QualityBoost * 100 + 0.5) .. " %"
	elseif id == "Backpack" then
		local count = 1 + level
		return count .. " objet" .. (if count > 1 then "s" else "")
	elseif id == "Magnet" then
		return if level > 0 then "Portée " .. Config.Magnet.Radius[math.min(level, #Config.Magnet.Radius)] .. " studs" else "Aucun aimant"
	elseif id == "LongLock" then
		return "Verrou " .. Config.GetLockDuration(level > 0, 0) .. " s"
	elseif id == "EggSlots" then
		return Config.GetEggSlots(level) .. " places"
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
	return now .. "  »  " .. (effectAt(item.Id, level + 1) or "")
end

type UpgradeCard = {
	card: ShopKit.Card,
	item: Config.ShopItem?,
	icon: ImageLabel,
	name: TextLabel,
	gauge: ShopKit.Gauge,
	effect: TextLabel,
	short: TextLabel?,
	buy: TextButton,
	level: number, -- niveau affiché (la jauge s'anime quand il monte)
}

export type Shop = {
	window: MenuKit.Window,
	refresh: () -> (),
	affordableCount: () -> number,
}

-- topStack : pile du haut du HUD (le bandeau du boost de chance serveur y apparaît).
function ShopMenu.create(gui: Instance, topStack: Frame): Shop
	local window = MenuKit.window(gui, "Boutique", ShopKit.WINDOW, UiStyle.Colors.Green, "Shop")

	-- Calque des effets (pièces qui jaillissent) : au-dessus de tout, il ne coupe rien et ne bloque pas les clics.
	local fxLayer = Instance.new("Frame")
	fxLayer.Name = "Fx"
	fxLayer.BackgroundTransparency = 1
	fxLayer.Size = UDim2.fromScale(1, 1)
	fxLayer.ZIndex = 20
	fxLayer.Parent = window.frame

	-- Argent du joueur dans l'en-tête, à gauche de la croix (il défile après un achat).
	local moneyChip = ShopKit.moneyChip(window.header, function()
		return MenuKit.number("Money")
	end)

	-- La page qui défile, sous les pastilles.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Page"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, ShopKit.PILL_HEIGHT + 8)
	scroll.Size = UDim2.new(1, 0, 1, -(ShopKit.PILL_HEIGHT + 8))
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = if ShopKit.TOUCH then 12 else 10
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

	-- Cartes d'amélioration ------------------------------------------------

	local cards: { UpgradeCard } = {}
	local pending: { [string]: UpgradeCard } = {} -- carte qui a demandé l'achat (pour l'effet quand le serveur valide)

	-- wide = carte large d'À la une (icône à gauche) ; sinon carte haute d'une grille.
	local function makeCard(grid: Instance, order: number, color: Color3, wide: boolean): UpgradeCard
		local card = ShopKit.card(grid, color, order)
		local body = card.body
		local glow = UiStyle.lighter(color, 0.3)
		local icon: ImageLabel, name: TextLabel, gauge: ShopKit.Gauge, chip: Frame, effect: TextLabel, buy: TextButton
		local short: TextLabel? = nil
		if wide then
			local iconZone = ShopKit.WIDE_ICON
			icon = ShopKit.icon(body, "Shop", iconZone, UDim2.new(0, iconZone / 2 + 16, 0.5, 4), glow)
			local left = iconZone + 30
			name = ShopKit.label(body, "", 28)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Position = UDim2.fromOffset(left, math.floor(28 * K))
			name.Size = UDim2.new(1, -left - math.floor(40 * K) - 22, 0, math.floor(34 * K)) -- laisse la place au « ? »
			gauge = ShopKit.gauge(body, color)
			gauge.frame.Position = UDim2.fromOffset(left, math.floor(66 * K))
			gauge.frame.Size = UDim2.new(1, -left - 14, 0, math.floor(26 * K))
			chip, effect = ShopKit.chip(body, 20)
			chip.Position = UDim2.fromOffset(left, math.floor(98 * K))
			chip.Size = UDim2.new(1, -left - 14, 0, math.floor(34 * K))
			buy = ShopKit.buyButton(body, UiStyle.Colors.Green, "Money")
			buy.AnchorPoint = Vector2.new(1, 1)
			buy.Position = UDim2.new(1, -14, 1, -12)
			buy.Size = UDim2.new(1, -left - 14, 0, ShopKit.BUTTON_HEIGHT)
		else
			local iconSize = ShopKit.ICON
			icon = ShopKit.icon(body, "Shop", iconSize, UDim2.new(0.5, 0, 0, 14 + iconSize / 2), glow)
			local y = 14 + iconSize + 10
			name = ShopKit.label(body, "", 28)
			name.Position = UDim2.fromOffset(12, y)
			name.Size = UDim2.new(1, -24, 0, math.floor(30 * K))
			y += math.floor(30 * K) + 4
			gauge = ShopKit.gauge(body, color)
			gauge.frame.Position = UDim2.fromOffset(14, y)
			gauge.frame.Size = UDim2.new(1, -28, 0, math.floor(28 * K))
			y += math.floor(28 * K) + 8
			chip, effect = ShopKit.chip(body, 20)
			chip.Position = UDim2.fromOffset(12, y)
			chip.Size = UDim2.new(1, -24, 0, math.floor(34 * K))
			y += math.floor(34 * K) + 4
			if ShopKit.SHORT_TEXT then
				-- Deux lignes au plus, au-dessus du bouton de prix.
				local line = ShopKit.label(body, "", 17)
				line.TextWrapped = true
				line.Position = UDim2.fromOffset(12, y)
				line.Size = UDim2.new(1, -24, 0, ShopKit.CARD_HEIGHT - ShopKit.BUTTON_HEIGHT - 18 - y)
				line.ZIndex = 3
				short = line
			end
			buy = ShopKit.buyButton(body, UiStyle.Colors.Green, "Money")
		end
		name.ZIndex = 3
		local ui: UpgradeCard = {
			card = card,
			item = nil,
			icon = icon,
			name = name,
			gauge = gauge,
			effect = effect,
			short = short,
			buy = buy,
			level = -1,
		}
		ShopKit.info(body, function()
			local item = ui.item
			return if item then item.Description else ""
		end)

		buy.Activated:Connect(function()
			local item = ui.item
			if not item then
				return
			end
			local price = Config.GetUpgradePrice(item, MenuKit.number("Upgrade_" .. item.Id))
			if not price then
				UIJuice.pop(body, 0.04)
				return
			end
			local money = MenuKit.number("Money")
			if money < price then
				UIJuice.denied(body)
				Toast.show("IL TE MANQUE " .. NumberFormat.money(price - money) .. " !", UiStyle.Colors.Red)
				return
			end
			pending[item.Id] = ui
			Remotes.BuyUpgrade:FireServer(item.Id)
		end)
		return ui
	end

	-- Affiche `item` sur la carte (la carte conseillée change d'amélioration).
	local function show(ui: UpgradeCard, item: Config.ShopItem, money: number)
		if ui.item ~= item then
			ui.item = item
			ui.icon.Image = Icons.id(item.Icon) or ""
			ui.name.Text = item.Name
			ui.level = -1
			local line = ui.short
			if line then
				line.Text = SHORT[item.Id] or ""
			end
		end
		local level = MenuKit.number("Upgrade_" .. item.Id)
		local ratio = if item.MaxLevel > 1 then level / item.MaxLevel elseif level > 0 then 1 else 0
		local text = if item.MaxLevel > 1 then string.format("NIV %d / %d", level, item.MaxLevel) elseif level > 0 then "ACQUIS !" else "ACHAT UNIQUE"
		ShopKit.setGauge(ui.gauge, ratio, text, ui.level >= 0 and level ~= ui.level)
		ui.level = level
		ui.effect.Text = effectText(item, level)
		local price = Config.GetUpgradePrice(item, level)
		if not price then
			ShopKit.setButton(ui.buy, if item.MaxLevel > 1 then "MAX !" else "ACQUIS", GREY)
		else
			ShopKit.setButton(ui.buy, NumberFormat.money(price), if money >= price then UiStyle.Colors.Green else UiStyle.Colors.Red)
		end
	end

	-- Conseillée : la moins chère de celles qu'on peut s'offrir, sinon la moins chère de toutes.
	local function recommended(money: number): Config.ShopItem
		local best: Config.ShopItem? = nil
		local bestPrice = math.huge
		local bestAffordable = false
		for _, item in ipairs(Config.Shop) do
			local price = Config.GetUpgradePrice(item, MenuKit.number("Upgrade_" .. item.Id))
			if price then
				local affordable = money >= price
				if best == nil or (affordable and not bestAffordable) or (affordable == bestAffordable and price < bestPrice) then
					best, bestPrice, bestAffordable = item, price, affordable
				end
			end
		end
		return best or Config.Shop[1]
	end

	-- Sections ---------------------------------------------------------------

	local sections: { ShopKit.Section } = {}
	local featuredSection = ShopKit.section(scroll, 1, "À la une", "Pour toi, maintenant", "Trophy", UiStyle.Colors.Gold, "TOP", 2, ShopKit.WIDE_HEIGHT)
	table.insert(sections, featuredSection)
	local featuredCard = makeCard(featuredSection.grid, 1, UiStyle.Colors.Green, true)
	ShopKit.ribbon(featuredCard.card.body, "CONSEILLÉ", UiStyle.Colors.Green)

	local categorySections: { ShopKit.Section } = {}
	for index, category in ipairs(CATEGORIES) do
		local section = ShopKit.section(scroll, index + 1, category.title, category.subtitle, category.icon, category.color, category.pill, ShopKit.COLUMNS)
		table.insert(sections, section)
		table.insert(categorySections, section)
		for order, id in ipairs(category.ids) do
			local item = itemsById[id]
			if item then
				local ui = makeCard(section.grid, order, CARD_COLORS[id] or category.color, false)
				show(ui, item, MenuKit.number("Money"))
				table.insert(cards, ui)
			end
		end
	end

	-- Défilement vers une section (pastilles) ; la pastille de la section visible s'allume.
	local pills: ShopKit.Pills
	local lockUntil = 0
	-- Position d'une section dans la page, dans les unités de CanvasPosition (justes quelle que soit l'échelle).
	local function sectionOffset(section: ShopKit.Section): number
		local ratio = scroll.AbsoluteWindowSize.Y / math.max(1, scroll.AbsoluteSize.Y)
		return (section.frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y) * ratio + scroll.CanvasPosition.Y - 10
	end
	local function maxScroll(): number
		return math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
	end
	local function scrollTo(index: number, instant: boolean?)
		local section = sections[index]
		if not section or not section.frame.Visible then
			return
		end
		local target = Vector2.new(0, math.clamp(sectionOffset(section), 0, maxScroll()))
		pills.setActive(index)
		lockUntil = os.clock() + 0.6
		if instant then
			scroll.CanvasPosition = target
		else
			TweenService:Create(scroll, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { CanvasPosition = target }):Play()
		end
	end

	local robux = RobuxShop.create({
		scroll = scroll,
		order = #sections + 1,
		topStack = topStack,
		fxLayer = fxLayer,
		isOpen = window.isOpen,
		showOdds = function()
			scrollTo(#sections)
		end,
	})
	robux.featured(featuredSection.grid, 2)
	for _, section in ipairs(robux.sections) do
		table.insert(sections, section)
	end

	pills = ShopKit.pills(window.content, sections, function(index: number)
		scrollTo(index)
	end)
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if os.clock() < lockUntil then
			return
		end
		local y = scroll.CanvasPosition.Y
		local active = 1
		if y >= maxScroll() - 4 and maxScroll() > 0 then
			-- Tout en bas : la dernière section visible.
			for index, section in ipairs(sections) do
				if section.frame.Visible then
					active = index
				end
			end
		else
			for index, section in ipairs(sections) do
				if section.frame.Visible and sectionOffset(section) <= y + 40 then
					active = index
				end
			end
		end
		pills.setActive(active)
	end)

	-- Mise à jour --------------------------------------------------------------

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
		moneyChip.update(window.isOpen())
		show(featuredCard, recommended(money), money)
		for _, ui in ipairs(cards) do
			local item = ui.item
			if item then
				show(ui, item, money)
			end
		end
		for index, category in ipairs(CATEGORIES) do
			pills.setBadge(index + 1, if affordableIn(category) > 0 then "!" else nil)
		end
		for index, section in ipairs(sections) do
			pills.setVisible(index, section.frame.Visible)
		end
	end

	-- Achat validé par le serveur (le niveau monte) : la carte qui l'a demandé saute, des pièces jaillissent du bouton.
	-- Le son « caisse » et le bandeau viennent déjà de client/SoundController et client/HUD.
	for _, item in ipairs(Config.Shop) do
		local last = MenuKit.number("Upgrade_" .. item.Id)
		MenuKit.player:GetAttributeChangedSignal("Upgrade_" .. item.Id):Connect(function()
			local level = MenuKit.number("Upgrade_" .. item.Id)
			local ui = pending[item.Id]
			pending[item.Id] = nil
			if level > last and ui and window.isOpen() then
				UIJuice.purchased(ui.card.body, ui.buy, fxLayer)
			end
			last = level
			refresh()
		end)
	end

	window.onOpen(function()
		moneyChip.reset()
		refresh()
		robux.refresh()
		if MenuKit.player:GetAttribute("StarterBonusPaid") == true and MenuKit.player:GetAttribute("Onboarding_Upgraded") ~= true then
			scrollTo(1, true) -- la carte conseillée = le tapis ou le banc, achetables avec la prime de départ
		end
	end)
	refresh()

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
