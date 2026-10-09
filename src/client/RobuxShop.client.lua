--!strict
-- RobuxShop : boutique Robux (catalogue Config.Monetization, effets shared/Perks, achats traités par
-- server/MonetizationController).
--   - Bouton "⭐ ROBUX" à droite de l'écran -> fenêtre : passes, produits, et les CHANCES EXACTES d'un tirage acheté
--     (règle Roblox : les probabilités des objets aléatoires payants doivent être affichées avant l'achat).
--   - Un objet dont l'Id vaut 0 (pas encore créé sur Roblox) est affiché "BIENTÔT".
--   - Boost de chance serveur : bandeau avec le temps restant + annonce à tous au moment de l'achat.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local LootEngine = require(ReplicatedStorage.Shared.LootEngine)
local Perks = require(ReplicatedStorage.Shared.Perks)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)

local M = Config.Monetization
local player = Players.LocalPlayer

local TITLE_FONT = Enum.Font.LuckiestGuy
local BODY_FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 215, 60)

----------------------------------------------------------------------
-- Petits outils de style (mêmes codes que le HUD : contours noirs, dégradés)
----------------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, border: boolean?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = BLACK
	s.ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
end

local function text(parent: Instance, value: string, size: number, font: Enum.Font?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextSize = size
	label.Font = font or TITLE_FONT
	label.TextColor3 = color or WHITE
	stroke(label, math.max(1.5, size / 12))
	label.Parent = parent
	return label
end

local function button(parent: Instance, label: string, size: UDim2, top: Color3, bottom: Color3, textSize: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = WHITE
	b.AutoButtonColor = false
	b.Font = TITLE_FONT
	b.Text = label
	b.TextSize = textSize
	b.TextColor3 = WHITE
	corner(b, 12)
	stroke(b, 3, true)
	gradient(b, top, bottom)
	local textOutline = Instance.new("UIStroke")
	textOutline.Thickness = 2
	textOutline.Parent = b
	b.Parent = parent
	return b
end

----------------------------------------------------------------------
-- Interface
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "RobuxShop"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(gui)

local openButton = button(root, "⭐\nROBUX", UDim2.fromOffset(96, 96), Color3.fromRGB(255, 225, 90), Color3.fromRGB(240, 150, 20), 24)
openButton.Name = "OpenRobuxShop"
openButton.AnchorPoint = Vector2.new(1, 0.5)
openButton.Position = UDim2.new(1, -14, 0.42, 0)

-- Bandeau du boost de chance serveur (au-dessus du bouton).
local boostBanner = text(root, "", 22, TITLE_FONT, Color3.fromRGB(150, 255, 120))
boostBanner.Name = "LuckBoost"
boostBanner.AnchorPoint = Vector2.new(1, 1)
boostBanner.Position = UDim2.new(1, -14, 0.42, -56)
boostBanner.Size = UDim2.fromOffset(300, 30)
boostBanner.TextXAlignment = Enum.TextXAlignment.Right
boostBanner.Visible = false

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.52)
window.Size = UDim2.fromOffset(640, 560)
window.BackgroundColor3 = WHITE
window.Visible = false
corner(window, 18)
stroke(window, 5, true)
gradient(window, Color3.fromRGB(255, 200, 70), Color3.fromRGB(220, 110, 20))
window.Parent = root
local windowScale = Instance.new("UIScale")
windowScale.Parent = window

local title = text(window, "BOUTIQUE ROBUX", 44)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.new(0.5, 0, 0, 4)
title.Size = UDim2.new(1, 0, 0, 56)
title.ZIndex = 3

local closeButton = button(window, "X", UDim2.fromOffset(50, 50), Color3.fromRGB(255, 90, 90), Color3.fromRGB(200, 30, 30), 30)
closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
closeButton.Position = UDim2.new(1, -6, 0, 6)
closeButton.ZIndex = 3

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(16, 46)
list.Size = UDim2.new(1, -32, 1, -62)
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.BorderSizePixel = 0
list.Parent = window
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function section(label: string)
	local header = text(list, label, 26)
	header.Size = UDim2.new(1, -12, 0, 32)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = nextOrder()
end

type Row = { item: Config.MonetizationItem, isPass: boolean, buy: TextButton, price: number }
local rows: { Row } = {}

local function rowFor(item: Config.MonetizationItem, isPass: boolean)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -12, 0, 78)
	frame.BackgroundColor3 = Color3.fromRGB(40, 25, 60)
	frame.BackgroundTransparency = 0.35
	frame.LayoutOrder = nextOrder()
	corner(frame, 12)
	frame.Parent = list
	local name = text(frame, item.Icon .. " " .. item.Name, 24)
	name.Position = UDim2.fromOffset(12, 6)
	name.Size = UDim2.new(1, -170, 0, 30)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local description = text(frame, item.Description, 15, BODY_FONT)
	description.Position = UDim2.fromOffset(12, 38)
	description.Size = UDim2.new(1, -170, 0, 34)
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.TextWrapped = true
	local buy = button(frame, "", UDim2.fromOffset(140, 48), Color3.fromRGB(110, 240, 70), Color3.fromRGB(40, 160, 30), 22)
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -12, 0.5, 0)
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

section("PASSES (POUR TOUJOURS)")
for _, pass in ipairs(M.GamePasses) do
	rowFor(pass, true)
end
section("PRODUITS")
for _, product in ipairs(M.Products) do
	rowFor(product, false)
end

-- Chances exactes d'un tirage acheté, avec la chance réelle du joueur (passe Chance Chanceuse, boost serveur).
section("CHANCES PAR TIRAGE ACHETÉ")
local oddsLabel = text(list, "", 18, BODY_FONT)
oddsLabel.Size = UDim2.new(1, -12, 0, 0)
oddsLabel.AutomaticSize = Enum.AutomaticSize.Y
oddsLabel.RichText = true
oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
oddsLabel.TextYAlignment = Enum.TextYAlignment.Top
oddsLabel.TextWrapped = true
oddsLabel.LayoutOrder = nextOrder()

local function formatPercent(probability: number): string
	local percent = probability * 100
	if percent >= 1 then
		return string.format("%.1f %%", percent)
	end
	return string.format("%.2f %%", percent)
end

local BUYABLE = ColorSequence.new(Color3.fromRGB(110, 240, 70), Color3.fromRGB(40, 160, 30))
local UNAVAILABLE = ColorSequence.new(Color3.fromRGB(170, 170, 175), Color3.fromRGB(110, 110, 115))
local OWNED = ColorSequence.new(Color3.fromRGB(90, 200, 255), Color3.fromRGB(30, 110, 200))

local function refresh()
	for _, row in ipairs(rows) do
		local owned = row.isPass and Perks.HasPass(player, row.item.Key)
		local shade = row.buy:FindFirstChildOfClass("UIGradient")
		if row.item.Id == 0 then
			row.buy.Text = "BIENTÔT"
		elseif owned then
			row.buy.Text = "POSSÉDÉ ✅"
		else
			row.buy.Text = "R$ " .. row.price
		end
		if shade then
			shade.Color = if row.item.Id == 0 then UNAVAILABLE elseif owned then OWNED else BUYABLE
		end
	end
	local odds = LootEngine.odds(M.PullLuck + Perks.LuckBonus(player))
	local lines = {}
	for index, rarity in ipairs(Config.Rarities) do
		table.insert(lines, string.format('<font color="#%s">%s</font> : %s', rarity.Color:ToHex(), TextFormat.upper(rarity.Name), formatPercent(odds[index])))
	end
	table.insert(lines, string.format(
		'<font size="14">Chaque familier d\'une rareté a la même chance. Garantie : un Épique ou mieux au plus tard au %de tirage sans en avoir eu.</font>',
		Config.Loot.PityPulls
	))
	oddsLabel.Text = table.concat(lines, "\n")
end

local function open()
	refresh()
	window.Visible = true
	windowScale.Scale = 0.6
	TweenService:Create(windowScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

openButton.Activated:Connect(function()
	if window.Visible then
		window.Visible = false
	else
		open()
	end
end)
closeButton.Activated:Connect(function()
	window.Visible = false
end)

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
	Toast.show(string.format("🌟 %s OFFRE UN BOOST DE CHANCE x2 À TOUT LE SERVEUR !", TextFormat.upper(tostring(by))), Color3.fromRGB(150, 255, 120))
end)

task.spawn(function()
	while true do
		local remaining = Perks.ServerLuckRemaining()
		boostBanner.Visible = remaining > 0
		if remaining > 0 then
			boostBanner.Text = string.format("🌟 CHANCE x2 : %d:%02d", remaining // 60, math.floor(remaining % 60))
		end
		if window.Visible then
			refresh() -- les chances changent quand le boost commence ou finit
		end
		task.wait(0.5)
	end
end)
