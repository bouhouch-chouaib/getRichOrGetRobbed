--!strict
-- RobuxShop : boutique Robux (catalogue Config.Monetization, effets shared/Perks, achats traités par
-- server/MonetizationController).
--   - Bouton carré "⭐ Robux" à droite de l'écran -> fenêtre construite comme la Boutique (client/ShopMenu) :
--     grandes cartes vives qui défilent, onglets à droite Passes / Produits / Chances. L'onglet Chances donne les
--     CHANCES EXACTES d'un tirage acheté (règle Roblox : les probabilités des objets aléatoires payants doivent être
--     affichées avant l'achat).
--   - Un objet dont l'Id vaut 0 (pas encore créé sur Roblox) est affiché "Bientôt".
--   - Boost de chance serveur : bandeau avec le temps restant + annonce à tous au moment de l'achat.
--   - Pays où les objets aléatoires payants sont interdits (PolicyService) : les tirages Robux et leurs chances
--     sont cachés. Ils restent cachés tant que la réponse de Roblox n'est pas arrivée (ou si elle échoue).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LootEngine = require(ReplicatedStorage.Shared.LootEngine)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Icons = require(ReplicatedStorage.Shared.Icons)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local M = Config.Monetization
local player = Players.LocalPlayer

local BODY_FONT = UiStyle.BODY_FONT
local WHITE = Color3.new(1, 1, 1)
local GOLD = UiStyle.Colors.Gold
local ROBUX_PURPLE = Color3.fromRGB(200, 40, 240)
local WINDOW_SIZE = Vector2.new(760, 480)
local CARD_WIDTH = 214
local CARD_COLORS = {
	Color3.fromRGB(255, 190, 30),
	Color3.fromRGB(170, 80, 255),
	Color3.fromRGB(240, 70, 90),
	Color3.fromRGB(50, 165, 255),
	Color3.fromRGB(70, 210, 60),
}

----------------------------------------------------------------------
-- Interface
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "RobuxShop"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- comme le HUD : les textes des boutons (client/UiStyle) restent devant
gui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(gui)

-- Bouton carré à droite de l'écran (comme les boutons colorés de la référence).
local openButton = UiStyle.button(root, "", UDim2.fromOffset(90, 90), GOLD, 1)
openButton.Name = "OpenRobuxShop"
openButton.AnchorPoint = Vector2.new(1, 0.5)
openButton.Position = UDim2.new(1, -14, 0.42, 0)
do
	local gem = Icons.image(openButton, "Robux", UDim2.new(0.7, 0, 0.6, 0), UDim2.fromScale(0.15, 0.02))
	gem.ZIndex = 2
	local label = UiStyle.text(openButton, "Robux", 22, WHITE, BODY_FONT)
	label.Position = UDim2.fromScale(0, 0.58)
	label.Size = UDim2.new(1, 0, 0.38, 0)
	label.ZIndex = 2
end

-- Bandeau du boost de chance serveur (au-dessus du bouton).
local boostBanner = UiStyle.text(root, "", 22, Color3.fromRGB(150, 255, 120))
boostBanner.Name = "LuckBoost"
boostBanner.AnchorPoint = Vector2.new(1, 1)
boostBanner.Position = UDim2.new(1, -14, 0.42, -54)
boostBanner.Size = UDim2.fromOffset(300, 30)
boostBanner.TextXAlignment = Enum.TextXAlignment.Right
boostBanner.Visible = false

local shopWindow = MenuKit.window(root, "Boutique Robux", WINDOW_SIZE, GOLD)
-- Hauteur de la zone de contenu, moins la barre de défilement.
local cardHeight = WINDOW_SIZE.Y + shopWindow.content.Size.Y.Offset - 18

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
	row.Parent = shopWindow.content
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = row
	return row
end

local passRow = cardRow()
local productRow = cardRow()

-- Onglet « Chances » : les probabilités exactes d'un tirage acheté.
local oddsPanel = UiStyle.panel(shopWindow.content, UDim2.fromScale(1, 1))
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

local function rowFor(item: Config.MonetizationItem, isPass: boolean, order: number)
	local color = CARD_COLORS[(order - 1) % #CARD_COLORS + 1]
	local card = UiStyle.brightCard(if isPass then passRow else productRow, UDim2.fromOffset(CARD_WIDTH, cardHeight), color)
	card.LayoutOrder = order
	if item.Pulls then
		randomItem(card)
	end
	local name = UiStyle.text(card, item.Name, 24, WHITE)
	name.Position = UDim2.fromOffset(6, 10)
	name.Size = UDim2.new(1, -12, 0, 30)
	name.TextScaled = true
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 24
	nameLimit.Parent = name
	local kind = UiStyle.text(card, if isPass then "Pour toujours" else "Achat", 18, WHITE, BODY_FONT)
	kind.Position = UDim2.fromOffset(6, 40)
	kind.Size = UDim2.new(1, -12, 0, 22)
	Icons.image(card, item.Icon, UDim2.new(1, -60, 0, 116), UDim2.fromOffset(30, 66))
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
	description.Position = UDim2.fromOffset(6, 4)
	description.Size = UDim2.new(1, -12, 1, -8)
	description.Font = BODY_FONT
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
		if item.Id == 0 or (isPass and Perks.HasPass(player, item.Key)) then
			return
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.Id)
		else
			MarketplaceService:PromptProductPurchase(player, item.Id)
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

local tabs = MenuKit.sideTabs(shopWindow, {
	{ label = "Passes", color = GOLD },
	{ label = "Produits", color = ROBUX_PURPLE },
	{ label = "Chances", color = UiStyle.Colors.Cyan },
}, function(index: number)
	passRow.Visible = index == 1
	productRow.Visible = index == 2
	-- Pays où les objets aléatoires payants sont interdits : pas de chances à afficher (rien à acheter).
	oddsPanel.Visible = index == 3 and randomAllowed
end)
tabs.select(1)

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
		tabs.select(tabs.selected())
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
		local owned = row.isPass and Perks.HasPass(player, row.item.Key)
		local caption = row.buy:FindFirstChild("Caption") :: TextLabel
		if row.item.Id == 0 then
			caption.Text = "Bientôt"
			UiStyle.setButtonColor(row.buy, Color3.fromRGB(150, 150, 160))
		elseif owned then
			caption.Text = "Possédé"
			UiStyle.setButtonColor(row.buy, UiStyle.Colors.Cyan)
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

shopWindow.onOpen(refresh)
openButton.Activated:Connect(shopWindow.toggle)

----------------------------------------------------------------------
-- Passes obtenus, boost de chance serveur
----------------------------------------------------------------------

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
		if shopWindow.isOpen() then
			refresh() -- les chances changent quand le boost commence ou finit
		end
		task.wait(0.5)
	end
end)
