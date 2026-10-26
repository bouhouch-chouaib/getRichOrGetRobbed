--!strict
-- RobuxShop : partie Robux de la Boutique en une page (client/ShopMenu, refaite le 26 oct. 2026, voir
-- dataset_and_pipeline/UI_UX_GUIDELINES.md ; catalogue Config.Monetization, effets shared/Perks, achats traités par
-- server/MonetizationController) :
--   - carte « EXCLUSIF » d'À la une : le premier passe pas encore possédé (2X ARGENT d'abord), sinon le boost serveur ;
--   - sections Passes R$ et Produits R$ : cartes dorées (grosse icône, ruban, phrase courte, « ? » pour la description
--     complète, gros bouton « R$ prix ») ; un objet dont l'Id vaut 0 (pas encore créé sur Roblox) est « BIENTÔT » ;
--   - section Chances : les CHANCES EXACTES d'un tirage acheté (règle Roblox : les probabilités des objets aléatoires
--     payants doivent être affichées avant l'achat) ; chaque carte de tirage a un bouton « CHANCES » qui y mène ;
--   - pays où les objets aléatoires payants sont interdits (PolicyService) : les tirages Robux et leurs chances sont
--     cachés, tant que la réponse de Roblox n'est pas arrivée (ou si elle échoue) ;
--   - boost de chance serveur : petit bandeau sous l'horloge avec le temps restant + annonce à tous à l'achat.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local LootEngine = require(ReplicatedStorage.Shared.LootEngine)
local Perks = require(ReplicatedStorage.Shared.Perks)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local MenuKit = require(script.Parent.MenuKit)
local ShopKit = require(script.Parent.ShopKit)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UIJuice = require(script.Parent.UIJuiceController)
local UiStyle = require(script.Parent.UiStyle)

local M = Config.Monetization
local player = Players.LocalPlayer
local auraProductId = 0
for _, product in ipairs(M.Products) do
	if product.Key == "AstralAura" then
		auraProductId = product.Id
	end
end

local WHITE = Color3.new(1, 1, 1)
local GOLD = UiStyle.Colors.Gold
local GREY = Color3.fromRGB(150, 150, 160)
local PRODUCT_PURPLE = Color3.fromRGB(200, 40, 240)
local K = ShopKit.K
local CARD_COLORS = {
	Color3.fromRGB(255, 190, 30),
	Color3.fromRGB(170, 80, 255),
	Color3.fromRGB(240, 70, 90),
	Color3.fromRGB(50, 165, 255),
	Color3.fromRGB(70, 210, 60),
}

-- Rubans (courts et vrais, UI_UX_GUIDELINES.md §2.2).
local RIBBONS: { [string]: string } = {
	DoubleMoney = string.format("x%d ARGENT", M.DoubleMoneyMultiplier),
	VIP = string.format("+%d %%", math.floor((M.VipMoneyMultiplier - 1) * 100 + 0.5)),
	EquipPlus2 = string.format("+%d ÉQUIPÉS", M.ExtraEquipSlots),
	ServerLuck = "TOUT LE SERVEUR",
	Pull10 = "x10",
}

-- Phrase courte sur la carte (la description complète est dans le « ? »).
local SHORT: { [string]: string } = {
	DoubleMoney = string.format("Tout ton argent x%d, pour toujours", M.DoubleMoneyMultiplier),
	VIP = string.format("+%d %% d'argent, verrou +%d s", math.floor((M.VipMoneyMultiplier - 1) * 100 + 0.5), M.VipLockBonus),
	Vacuum = "Aspire tous les objets autour de toi",
	ExtraBackpack = string.format("Porte %d objet de plus", M.ExtraBackpack),
	EquipPlus2 = string.format("Équipe %d familiers de plus", M.ExtraEquipSlots),
	LuckyLuck = "Meilleure chance à tous tes tirages",
	AstralAura = "Cristaux et traînée de lumière, pour toujours",
	ServerLuck = string.format("Chance x2 pour tout le serveur, %d min", M.ServerLuckDuration // 60),
	Pull1 = "1 œuf de familier",
	Key1 = "Ouvre une base fermée",
	Pull10 = "10 œufs de familiers",
}

-- Ordre de la carte « EXCLUSIF » d'À la une.
local FEATURED_ORDER = { "DoubleMoney", "VIP", "LuckyLuck", "Vacuum", "EquipPlus2", "ExtraBackpack", "ServerLuck" }

local RobuxShop = {}

export type Options = {
	scroll: ScrollingFrame, -- la page de la Boutique
	order: number, -- LayoutOrder de la première section Robux
	topStack: Frame, -- pile du haut du HUD (bandeau du boost de chance serveur, juste sous l'horloge)
	fxLayer: GuiObject, -- calque des pièces qui jaillissent (client/UIJuiceController)
	isOpen: () -> boolean,
	showOdds: () -> (), -- fait défiler la page jusqu'aux chances
}

export type Panel = {
	sections: { ShopKit.Section }, -- Passes R$, Produits R$, Chances (dans l'ordre de la page)
	featured: (grid: Instance, order: number) -> (),
	refresh: () -> (),
}

type Item = Config.MonetizationItem

local function find(key: string): (Item?, boolean)
	for _, pass in ipairs(M.GamePasses) do
		if pass.Key == key then
			return pass, true
		end
	end
	for _, product in ipairs(M.Products) do
		if product.Key == key then
			return product, false
		end
	end
	return nil, false
end

function RobuxShop.create(options: Options): Panel
	local scroll = options.scroll

	-- Bandeau du boost de chance serveur (discret, seulement pendant le boost).
	local boostBanner = UiStyle.text(options.topStack, "", 20, Color3.fromRGB(150, 255, 120))
	boostBanner.Name = "LuckBoost"
	boostBanner.LayoutOrder = 1
	boostBanner.Size = UDim2.fromOffset(300, 24)
	boostBanner.Visible = false

	local passes = ShopKit.section(scroll, options.order, "Passes R$", "Pour toujours", "Crown", GOLD, "PASSES", ShopKit.COLUMNS)
	local products = ShopKit.section(scroll, options.order + 1, "Produits R$", "Tirages, clés, boosts", "Gift", PRODUCT_PURPLE, "EXTRAS", ShopKit.COLUMNS)
	local odds = ShopKit.section(scroll, options.order + 2, "Chances", "Pour un œuf acheté", "Dice", Color3.fromRGB(120, 120, 150), "CHANCES")

	-- Tout ce qui concerne les objets aléatoires payants (tirages Robux et leurs chances) : caché par défaut.
	local randomItemParts: { GuiObject } = { odds.frame }
	odds.frame.Visible = false
	local function randomItem(object: GuiObject)
		object.Visible = false
		table.insert(randomItemParts, object)
	end

	-- Prix lus sur Roblox (celui du Config n'est qu'une valeur par défaut).
	local prices: { [string]: number } = {}
	local function priceOf(item: Item): number
		return prices[item.Key] or item.Price
	end
	local function fetchPrice(item: Item, isPass: boolean)
		if item.Id == 0 or prices[item.Key] then
			return
		end
		prices[item.Key] = item.Price
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(item.Id, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				prices[item.Key] = info.PriceInRobux
			end
		end)
	end

	local auraPending = false
	local function owned(item: Item, isPass: boolean): boolean
		return (isPass and Perks.HasPass(player, item.Key)) or (item.Key == "AstralAura" and Perks.HasAura(player))
	end

	local function purchase(item: Item, isPass: boolean)
		if item.Id == 0 or owned(item, isPass) or (item.Key == "AstralAura" and (auraPending or player:GetAttribute("DataLoaded") ~= true)) then
			return
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.Id)
		else
			if item.Key == "AstralAura" then
				auraPending = true
			end
			local ok = pcall(function()
				MarketplaceService:PromptProductPurchase(player, item.Id)
			end)
			if not ok then
				if item.Key == "AstralAura" then
					auraPending = false
				end
				Toast.show("L’achat n’a pas pu s’ouvrir. Réessaie.", GOLD)
			end
		end
	end

	-- Texte et couleur du bouton d'achat d'un objet.
	local function buttonState(item: Item, isPass: boolean): (string, Color3)
		if item.Id == 0 then
			return "BIENTÔT", GREY
		elseif owned(item, isPass) then
			return "POSSÉDÉ", GREY
		elseif item.Key == "AstralAura" and (auraPending or player:GetAttribute("DataLoaded") ~= true) then
			return if auraPending then "VALIDATION…" else "CHARGEMENT…", GREY
		end
		return "R$ " .. priceOf(item), GOLD
	end

	type Row = { item: Item, isPass: boolean, body: Frame, buy: TextButton }
	local rows: { Row } = {}

	local function makeCard(grid: Instance, item: Item, isPass: boolean, order: number)
		fetchPrice(item, isPass)
		local color = CARD_COLORS[(order - 1) % #CARD_COLORS + 1]
		local card = ShopKit.card(grid, color, order)
		local body = card.body
		if item.Pulls then
			randomItem(card.holder)
		end
		local iconSize = ShopKit.ICON
		ShopKit.icon(body, item.Icon, iconSize, UDim2.new(0.5, 0, 0, 14 + iconSize / 2), UiStyle.lighter(color, 0.3))
		local ribbon = RIBBONS[item.Key]
		if ribbon then
			ShopKit.ribbon(body, ribbon, GOLD)
		end
		ShopKit.info(body, function()
			return item.Description
		end)

		local y = 14 + iconSize + 10
		local name = ShopKit.label(body, item.Name, 26)
		name.Position = UDim2.fromOffset(12, y)
		name.Size = UDim2.new(1, -24, 0, math.floor(32 * K))
		name.ZIndex = 3
		y += math.floor(32 * K) + 4
		local tagHeight = math.floor(30 * K)
		if item.Pulls then
			-- Tirage : un bouton mène aux chances exactes (dernière section).
			local link = UiStyle.button(body, "VOIR LES CHANCES", UDim2.new(1, -28, 0, tagHeight), Color3.fromRGB(110, 110, 140), math.floor(18 * K), true)
			link.Position = UDim2.fromOffset(14, y)
			link.ZIndex = 4
			UIJuice.button(link)
			link.Activated:Connect(options.showOdds)
		else
			local chip, kind = ShopKit.chip(body, 18)
			chip.Position = UDim2.fromOffset(14, y)
			chip.Size = UDim2.new(1, -28, 0, tagHeight)
			kind.Text = if isPass or item.Key == "AstralAura" then "POUR TOUJOURS" else "ACHAT"
		end
		y += tagHeight + 8
		local short = ShopKit.label(body, SHORT[item.Key] or item.Description, 18)
		short.TextWrapped = true
		short.Position = UDim2.fromOffset(12, y)
		short.Size = UDim2.new(1, -24, 0, math.max(20, ShopKit.CARD_HEIGHT - ShopKit.BUTTON_HEIGHT - 22 - y))
		short.ZIndex = 3

		local buy = ShopKit.buyButton(body, GOLD)
		buy.Activated:Connect(function()
			if item.Id == 0 or owned(item, isPass) then
				UIJuice.pop(body, 0.04)
				return
			end
			purchase(item, isPass)
		end)
		table.insert(rows, { item = item, isPass = isPass, body = body, buy = buy })
	end

	for order, pass in ipairs(M.GamePasses) do
		makeCard(passes.grid, pass, true, order)
	end
	for order, product in ipairs(M.Products) do
		makeCard(products.grid, product, false, order)
	end

	-- Chances exactes (texte riche qui grandit avec son contenu).
	local oddsPanel = UiStyle.panel(odds.grid, UDim2.fromScale(1, 0))
	oddsPanel.AutomaticSize = Enum.AutomaticSize.Y
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = oddsPanel
	local oddsLabel = UiStyle.text(oddsPanel, "", math.floor(22 * K), WHITE)
	oddsLabel.Size = UDim2.fromScale(1, 0)
	oddsLabel.AutomaticSize = Enum.AutomaticSize.Y
	oddsLabel.RichText = true
	oddsLabel.TextWrapped = true
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
	oddsLabel.TextYAlignment = Enum.TextYAlignment.Top
	oddsLabel.LineHeight = 1.15
	oddsLabel.ZIndex = 3

	-- Carte « EXCLUSIF » d'À la une (large : icône à gauche, le reste à droite).
	local featuredUi: { icon: ImageLabel, name: TextLabel, short: TextLabel, ribbon: TextLabel, buy: TextButton, body: Frame }? = nil
	local featuredItem: Item? = nil
	local featuredIsPass = false
	local function pickFeatured(): (Item?, boolean)
		for _, key in ipairs(FEATURED_ORDER) do
			local item, isPass = find(key)
			if item and item.Id ~= 0 and not owned(item, isPass) then
				return item, isPass
			end
		end
		return find("ServerLuck")
	end

	local function featured(grid: Instance, order: number)
		local card = ShopKit.card(grid, GOLD, order)
		local body = card.body
		local iconZone = ShopKit.WIDE_ICON
		local icon = ShopKit.icon(body, "Crown", iconZone, UDim2.new(0, iconZone / 2 + 16, 0.5, 4), Color3.fromRGB(255, 240, 150))
		local _, ribbon = ShopKit.ribbon(body, "EXCLUSIF", Color3.fromRGB(255, 120, 40))
		local left = iconZone + 30
		local name = ShopKit.label(body, "", 28)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(left, math.floor(28 * K))
		name.Size = UDim2.new(1, -left - 14, 0, math.floor(34 * K))
		name.ZIndex = 3
		local short = ShopKit.label(body, "", 20)
		short.TextWrapped = true
		short.TextXAlignment = Enum.TextXAlignment.Left
		short.Position = UDim2.fromOffset(left, math.floor(66 * K))
		short.Size = UDim2.new(1, -left - 14, 0, math.floor(58 * K))
		short.ZIndex = 3
		local buy = ShopKit.buyButton(body, GOLD)
		buy.AnchorPoint = Vector2.new(1, 1)
		buy.Position = UDim2.new(1, -14, 1, -12)
		buy.Size = UDim2.new(1, -left - 14, 0, ShopKit.BUTTON_HEIGHT)
		buy.Activated:Connect(function()
			local item = featuredItem
			if item then
				purchase(item, featuredIsPass)
			end
		end)
		featuredUi = { icon = icon, name = name, short = short, ribbon = ribbon, buy = buy, body = body }
	end

	local function formatPercent(probability: number): string
		local percent = probability * 100
		if percent >= 1 then
			return string.format("%.1f %%", percent)
		end
		return string.format("%.2f %%", percent)
	end

	local function refresh()
		for _, row in ipairs(rows) do
			local text, color = buttonState(row.item, row.isPass)
			ShopKit.setButton(row.buy, text, color)
		end
		local ui = featuredUi
		if ui then
			local item, isPass = pickFeatured()
			if item then
				fetchPrice(item, isPass)
				featuredItem, featuredIsPass = item, isPass
				ui.icon.Image = Icons.id(item.Icon) or ""
				ui.name.Text = item.Name
				ui.short.Text = SHORT[item.Key] or item.Description
				local text, color = buttonState(item, isPass)
				ShopKit.setButton(ui.buy, text, color)
			end
		end
		-- Chances exactes pour CE joueur : chance des tirages achetés + bonus, et sa rareté plancher (rang de tirage).
		local tier = player:GetAttribute("Tier")
		local chances = LootEngine.odds(M.PullLuck + Perks.LuckBonus(player), MenuKit.pullFloor(), if type(tier) == "number" then tier else 1)
		local lines = {}
		for index, rarity in ipairs(Config.Rarities) do
			table.insert(lines, string.format('<font color="#%s">%s</font> : %s', rarity.Color:ToHex(), TextFormat.upper(rarity.Name), formatPercent(chances[index])))
		end
		table.insert(lines, string.format(
			'<font size="%d">Dans une rareté, un familier que tu n\'as pas encore a %d fois plus de chances que ceux que tu as déjà. Garantie : la rareté juste au-dessus de ta meilleure arrive au plus tard au tirage où %d joueurs sur 10 l\'auraient déjà eue (le compte à rebours s\'affiche après chaque tirage). Ton rang de tirage retire les petites raretés dont tu as découvert tous les familiers. Au-delà de %d exemplaires d\'un familier, les suivants sont vendus automatiquement. Dans chaque monde après la Prairie, ses familiers exclusifs peuvent aussi sortir (dans leur rareté).</font>',
			math.floor(18 * K),
			Config.Loot.NewPetWeight,
			math.floor(Config.Loot.PityPercentile * 10 + 0.5),
			Config.Loot.KeepCopies
		))
		oddsLabel.Text = table.concat(lines, "\n")
	end

	-- Règle Roblox : pas d'objets aléatoires payants là où la loi les interdit (ex. Belgique, Pays-Bas).
	task.spawn(function()
		local ok, policy = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(policy) == "table" and policy.ArePaidRandomItemsRestricted == false then
			for _, object in ipairs(randomItemParts) do
				object.Visible = true
			end
		end
	end)

	----------------------------------------------------------------------
	-- Passes obtenus, boost de chance serveur
	----------------------------------------------------------------------

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
		if userId == player.UserId and productId == auraProductId and not purchased then
			auraPending = false
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
	player:GetAttributeChangedSignal("Upgrade_" .. Config.PlayerAura.UnlockId):Connect(function()
		auraPending = false
		refresh()
	end)
	local started = os.clock()
	for _, pass in ipairs(M.GamePasses) do
		player:GetAttributeChangedSignal("Pass_" .. pass.Key):Connect(function()
			-- Pas de message au chargement (passes déjà possédés) : seulement pour un achat en cours de partie.
			if player:GetAttribute("Pass_" .. pass.Key) == true and os.clock() - started > 10 then
				Sounds.play("Purchase")
				Toast.show(string.format("MERCI ! %s ACTIVÉ !", pass.Name), GOLD)
				if options.isOpen() then
					for _, row in ipairs(rows) do
						if row.item.Key == pass.Key then
							UIJuice.purchased(row.body, row.buy, options.fxLayer)
						end
					end
					local ui = featuredUi
					if ui and featuredItem and featuredItem.Key == pass.Key then
						UIJuice.purchased(ui.body, ui.buy, options.fxLayer)
					end
				end
			end
			refresh()
		end)
	end

	ReplicatedStorage:GetAttributeChangedSignal("LuckBoostAt"):Connect(function()
		local by = ReplicatedStorage:GetAttribute("LuckBoostBy")
		Sounds.play("RareDrop")
		Toast.show(string.format("%s OFFRE UN BOOST DE CHANCE x2 À TOUT LE SERVEUR !", TextFormat.upper(tostring(by))), Color3.fromRGB(150, 255, 120))
	end)

	task.spawn(function()
		while true do
			local remaining = Perks.ServerLuckRemaining()
			boostBanner.Visible = remaining > 0
			if remaining > 0 then
				boostBanner.Text = string.format("CHANCE x2 : %d:%02d", remaining // 60, math.floor(remaining % 60))
			end
			if options.isOpen() then
				refresh() -- les chances changent quand le boost commence ou finit ; les vrais prix arrivent de Roblox
			end
			task.wait(0.5)
		end
	end)

	return {
		sections = { passes, products, odds },
		featured = function(grid: Instance, order: number)
			featured(grid, order)
			refresh()
		end,
		refresh = refresh,
	}
end

return RobuxShop
