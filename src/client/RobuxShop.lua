--!strict
-- RobuxShop : contenu Robux de la Boutique (catalogue Config.Monetization, effets shared/Perks, achats traités
-- par server/MonetizationController). Depuis le 13 oct., plus de bouton ni de fenêtre à part (l'écran était trop
-- chargé, surtout sur téléphone) : client/ShopMenu l'affiche dans ses onglets Passes R$ / Produits R$ / Chances.
--   - Grandes cartes vives qui défilent. L'onglet Chances donne les CHANCES EXACTES d'un tirage acheté (règle
--     Roblox : les probabilités des objets aléatoires payants doivent être affichées avant l'achat).
--   - Un objet dont l'Id vaut 0 (pas encore créé sur Roblox) est affiché "Bientôt".
--   - Boost de chance serveur : petit bandeau sous l'horloge avec le temps restant + annonce à tous à l'achat.
--   - Pays où les objets aléatoires payants sont interdits (PolicyService) : les tirages Robux et leurs chances
--     sont cachés. Ils restent cachés tant que la réponse de Roblox n'est pas arrivée (ou si elle échoue).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LootEngine = require(ReplicatedStorage.Shared.LootEngine)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Icons = require(ReplicatedStorage.Shared.Icons)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local MenuKit = require(script.Parent.MenuKit)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local M = Config.Monetization
local player = Players.LocalPlayer
local auraProductId = 0
for _, product in ipairs(M.Products) do
	if product.Key == "AstralAura" then auraProductId = product.Id end
end

local BODY_FONT = UiStyle.BODY_FONT
local WHITE = Color3.new(1, 1, 1)
local GOLD = UiStyle.Colors.Gold
local ROBUX_PURPLE = Color3.fromRGB(200, 40, 240)
local CARD_WIDTH = 214
local CARD_COLORS = {
	Color3.fromRGB(255, 190, 30),
	Color3.fromRGB(170, 80, 255),
	Color3.fromRGB(240, 70, 90),
	Color3.fromRGB(50, 165, 255),
	Color3.fromRGB(70, 210, 60),
}

local RobuxShop = {}

export type Panel = {
	show: (index: number) -> (), -- 0 = rien, 1 = passes, 2 = produits, 3 = chances
	refresh: () -> (),
}

-- content : zone de contenu de la fenêtre Boutique ; cardHeight : hauteur des cartes ;
-- topStack : pile du haut du HUD (bandeau du boost de chance serveur, juste sous l'horloge).
function RobuxShop.create(content: Frame, cardHeight: number, topStack: Frame): Panel
	-- Bandeau du boost de chance serveur (discret, seulement pendant le boost).
	local boostBanner = UiStyle.text(topStack, "", 20, Color3.fromRGB(150, 255, 120))
	boostBanner.Name = "LuckBoost"
	boostBanner.LayoutOrder = 1
	boostBanner.Size = UDim2.fromOffset(300, 24)
	boostBanner.Visible = false

	local function cardRow(): ScrollingFrame
		local row = Instance.new("ScrollingFrame")
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.fromScale(1, 1)
		row.ScrollingDirection = Enum.ScrollingDirection.X
		row.AutomaticCanvasSize = Enum.AutomaticSize.X
		row.CanvasSize = UDim2.new()
		row.ScrollBarThickness = 8
		row.ScrollBarImageColor3 = WHITE
		row.ZIndex = 2
		row.Visible = false
		row.Parent = content
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 12)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
		UiStyle.scrollPadding(row)
		return row
	end

	local passRow = cardRow()
	local productRow = cardRow()

	-- Onglet « Chances » : les probabilités exactes d'un tirage acheté.
	local oddsPanel = UiStyle.panel(content, UDim2.fromScale(1, 1))
	oddsPanel.ZIndex = 2
	oddsPanel.Visible = false
	local oddsTitle = UiStyle.text(oddsPanel, "Chances par tirage acheté", 26, WHITE, BODY_FONT)
	oddsTitle.Position = UDim2.fromOffset(14, 8)
	oddsTitle.Size = UDim2.new(1, -28, 0, 32)
	oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
	oddsTitle.ZIndex = 3
	local oddsLabel = UiStyle.text(oddsPanel, "", 20, WHITE, BODY_FONT)
	oddsLabel.Position = UDim2.fromOffset(14, 46)
	oddsLabel.Size = UDim2.new(1, -28, 1, -56)
	oddsLabel.RichText = true
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
	oddsLabel.TextYAlignment = Enum.TextYAlignment.Top
	oddsLabel.TextWrapped = true
	oddsLabel.LineHeight = 1.12
	oddsLabel.ZIndex = 3

	-- Tout ce qui concerne les objets aléatoires payants (tirages Robux et leurs chances) : caché par défaut.
	local randomAllowed = false
	local randomItemParts: { GuiObject } = {}
	local function randomItem(object: GuiObject)
		object.Visible = false
		table.insert(randomItemParts, object)
	end

	type Row = { item: Config.MonetizationItem, isPass: boolean, buy: TextButton, price: number }
	local rows: { Row } = {}

	local auraPending = false
	local function rowFor(item: Config.MonetizationItem, isPass: boolean, order: number)
		local color = CARD_COLORS[(order - 1) % #CARD_COLORS + 1]
		local card = UiStyle.brightCard(if isPass then passRow else productRow, UDim2.fromOffset(CARD_WIDTH, cardHeight), color)
		card.LayoutOrder = order
		if item.Pulls then
			randomItem(card)
		end
		local name = UiStyle.text(card, item.Name, 24, WHITE)
		name.Position = UDim2.fromOffset(12, 8)
		name.Size = UDim2.new(1, -24, 0, 30)
		name.TextScaled = true
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 24
		nameLimit.Parent = name
		local kind = UiStyle.text(card, if isPass or item.Key == "AstralAura" then "Pour toujours" else "Achat", 18, WHITE, BODY_FONT)
		kind.Position = UDim2.fromOffset(12, 44)
		kind.Size = UDim2.new(1, -24, 0, 22)
		Icons.image(card, item.Icon, UDim2.new(1, -60, 0, 116), UDim2.fromOffset(30, 72))
		local descriptionBox = Instance.new("Frame")
		descriptionBox.BackgroundColor3 = Color3.new(0, 0, 0)
		descriptionBox.BackgroundTransparency = 0.55
		descriptionBox.BorderSizePixel = 0
		descriptionBox.Position = UDim2.new(0, 10, 1, -150)
		descriptionBox.Size = UDim2.new(1, -20, 0, 84)
		UiStyle.corner(descriptionBox, 6)
		descriptionBox.Parent = card
		local description = Instance.new("TextLabel")
		description.BackgroundTransparency = 1
		description.Position = UDim2.fromOffset(8, 6)
		description.Size = UDim2.new(1, -16, 1, -12)
		description.FontFace = BODY_FONT
		description.Text = item.Description
		description.TextColor3 = WHITE
		description.TextScaled = true
		description.TextWrapped = true
		local descriptionLimit = Instance.new("UITextSizeConstraint")
		descriptionLimit.MaxTextSize = 17
		descriptionLimit.Parent = description
		description.Parent = descriptionBox
		-- Bouton violet façon « prix en Robux » de la référence.
		local buy = UiStyle.button(card, "", UDim2.new(1, -20, 0, 52), ROBUX_PURPLE, 28)
		buy.Position = UDim2.new(0, 10, 1, -58)
		local row: Row = { item = item, isPass = isPass, buy = buy, price = item.Price }
		table.insert(rows, row)

		buy.Activated:Connect(function()
			if item.Id == 0 or (isPass and Perks.HasPass(player, item.Key)) or (item.Key == "AstralAura" and (Perks.HasAura(player) or auraPending or player:GetAttribute("DataLoaded") ~= true)) then
				return
			end
			if item.Key == "BaseFloor" then
				Remotes.BaseFloor:FireServer("Robux")
			elseif isPass then
				MarketplaceService:PromptGamePassPurchase(player, item.Id)
			else
				if item.Key == "AstralAura" then auraPending = true end
				local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, item.Id) end)
				if not ok then
					if item.Key == "AstralAura" then auraPending = false end
					Toast.show("L’achat n’a pas pu s’ouvrir. Réessaie.", GOLD)
				end
			end
		end)

		-- Vrai prix lu sur Roblox (le prix du Config n'est qu'une valeur par défaut).
		if item.Id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(item.Id, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
				end)
				if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
					row.price = info.PriceInRobux
				end
			end)
		end
	end

	for order, pass in ipairs(M.GamePasses) do
		rowFor(pass, true, order)
	end
	for order, product in ipairs(M.Products) do
		rowFor(product, false, order)
	end

	local shown = 0
	local function show(index: number)
		shown = index
		passRow.Visible = index == 1
		productRow.Visible = index == 2
		-- Pays où les objets aléatoires payants sont interdits : pas de chances à afficher (rien à acheter).
		oddsPanel.Visible = index == 3 and randomAllowed
	end

	-- Règle Roblox : pas d'objets aléatoires payants là où la loi les interdit (ex. Belgique, Pays-Bas).
	task.spawn(function()
		local ok, policy = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(policy) == "table" and policy.ArePaidRandomItemsRestricted == false then
			randomAllowed = true
			for _, object in ipairs(randomItemParts) do
				object.Visible = true
			end
			show(shown)
		end
	end)

	local function formatPercent(probability: number): string
		local percent = probability * 100
		if percent >= 1 then
			return string.format("%.1f %%", percent)
		end
		return string.format("%.2f %%", percent)
	end

	local function refresh()
		for _, row in ipairs(rows) do
			local owned = (row.isPass and Perks.HasPass(player, row.item.Key)) or (row.item.Key == "AstralAura" and Perks.HasAura(player))
			local caption = row.buy:FindFirstChild("Caption") :: TextLabel
			if row.item.Id == 0 then
				caption.Text = "Bientôt"
				UiStyle.setButtonColor(row.buy, Color3.fromRGB(150, 150, 160))
			elseif owned then
				caption.Text = "Possédé"
				UiStyle.setButtonColor(row.buy, UiStyle.Colors.Cyan)
			elseif row.item.Key == "AstralAura" and (auraPending or player:GetAttribute("DataLoaded") ~= true) then
				caption.Text = if auraPending then "Validation…" else "Chargement…"
				UiStyle.setButtonColor(row.buy, Color3.fromRGB(150, 150, 160))
			else
				caption.Text = "R$ " .. row.price
				UiStyle.setButtonColor(row.buy, ROBUX_PURPLE)
			end
		end
		-- Chances exactes pour CE joueur : chance des tirages achetés + bonus, et sa rareté plancher (rang de tirage).
		local odds = LootEngine.odds(M.PullLuck + Perks.LuckBonus(player), MenuKit.pullFloor())
		local lines = {}
		for index, rarity in ipairs(Config.Rarities) do
			table.insert(lines, string.format('<font color="#%s">%s</font> : %s', rarity.Color:ToHex(), TextFormat.upper(rarity.Name), formatPercent(odds[index])))
		end
		table.insert(lines, string.format(
			'<font size="15">Dans une rareté, un familier que tu n\'as pas encore a %d fois plus de chances que ceux que tu as déjà. Garantie : un Épique ou mieux au plus tard au %de tirage sans en avoir eu. Ton rang de tirage retire les petites raretés dont tu as découvert tous les familiers. Au-delà de %d exemplaires d\'un familier, les suivants sont vendus automatiquement.</font>',
			Config.Loot.NewPetWeight,
			Config.Loot.PityPulls,
			Config.Loot.KeepCopies
		))
		oddsLabel.Text = table.concat(lines, "\n")
	end


	----------------------------------------------------------------------
	-- Passes obtenus, boost de chance serveur
	----------------------------------------------------------------------

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
		if userId == player.UserId and productId == auraProductId and not purchased then auraPending = false; refresh() end
	end)
	player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
	player:GetAttributeChangedSignal("Upgrade_" .. Config.PlayerAura.UnlockId):Connect(function()
		auraPending = false
		refresh()
	end)
	local started = os.clock()
	for _, pass in ipairs(M.GamePasses) do
		player:GetAttributeChangedSignal("Pass_" .. pass.Key):Connect(function()
			refresh()
			-- Pas de message au chargement (passes déjà possédés) : seulement pour un achat en cours de partie.
			if player:GetAttribute("Pass_" .. pass.Key) == true and os.clock() - started > 10 then
				Sounds.play("Purchase")
				Toast.show(string.format("MERCI ! %s ACTIVÉ !", pass.Name), GOLD)
			end
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
			if shown > 0 then
				refresh() -- les chances changent quand le boost commence ou finit
			end
			task.wait(0.5)
		end
	end)

	refresh()
	return { show = show, refresh = refresh }
end

return RobuxShop
