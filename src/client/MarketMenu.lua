--!strict
-- MarketMenu : fenêtre MARCHÉ, acheter et vendre des familiers aux joueurs du serveur (server/MarketController décide
-- de tout, Config.Market). Trois onglets :
--   « Acheter »    : les ventes des autres joueurs (aperçu 3D, rareté, revenu, vendeur, prix, bouton ACHETER) ;
--   « Vendre »     : choisir un de ses familiers libres, taper un prix (proposé : 10 min de son revenu), METTRE EN VENTE ;
--   « Mes ventes » : ses ventes en cours, bouton RETIRER.
-- La liste arrive par Remotes.MarketUpdate ; les réponses (ACHETÉ, VENDU...) par Remotes.Market (Toast).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MenuKit = require(script.Parent.MenuKit)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local MarketMenu = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GREY = Color3.fromRGB(150, 150, 160)
local MONEY = UiStyle.Colors.Money
local HEADER = Color3.fromRGB(60, 200, 120)

export type Listing = { id: string, seller: number, sellerName: string, petId: string, price: number, available: boolean }
export type Menu = { window: MenuKit.Window }

local function rarityOf(petId: string): Config.Rarity?
	local entry = PetCatalog.ById[petId]
	return if entry then Config.Rarities[Config.RarityIndex[entry.Rarity]] else nil
end

-- « 1.5K », « 2m », « $3 B », « 1e6 » -> nombre (nil si illisible).
local MULTIPLIERS: { [string]: number } = { [""] = 1, k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21,
	sp = 1e24, oc = 1e27, no = 1e30 }
local function parsePrice(text: string): number?
	local clean = string.lower((string.gsub(text, "[%s%$,]", "")))
	local direct = tonumber(clean)
	if direct then
		return direct
	end
	local digits, suffix = string.match(clean, "^([%d%.]+)(%a*)$")
	local value = digits and tonumber(digits)
	local multiplier = suffix and MULTIPLIERS[suffix]
	return if value and multiplier then value * multiplier else nil
end

local function suggestedPrice(petId: string): number
	return math.max(Config.Market.MinSuggested, math.floor(PetCatalog.GetIncome(petId) * Config.Market.SuggestedSeconds))
end

local function clear(parent: Instance)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function label(parent: Instance, value: string, size: number, color: Color3?, position: UDim2, frameSize: UDim2): TextLabel
	local text = UiStyle.text(parent, value, size, color, UiStyle.BODY_FONT)
	text.Position = position
	text.Size = frameSize
	return text
end

local function scroller(parent: Instance, position: UDim2, size: UDim2, cell: Vector2): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = position
	scroll.Size = size
	scroll.ScrollBarThickness = 8
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 2
	scroll.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	UiStyle.scrollPadding(scroll)
	return scroll
end

-- Carte d'un familier : couleur de sa rareté, aperçu 3D, nom, rareté, revenu.
local function petCard(parent: Instance, petId: string, order: number): Frame
	local entry = PetCatalog.ById[petId]
	local rarity = rarityOf(petId)
	local card = UiStyle.brightCard(parent, UDim2.fromOffset(100, 100), if rarity then rarity.Color else GREY)
	card.LayoutOrder = order
	local viewport = MenuKit.petViewport(card, petId, false)
	viewport.Position = UDim2.fromOffset(6, 4)
	viewport.Size = UDim2.new(1, -12, 0, 96)
	viewport.ZIndex = 3
	local name = UiStyle.text(card, if entry then entry.Name else petId, 18, WHITE, UiStyle.BODY_FONT)
	name.Position = UDim2.fromOffset(6, 100)
	name.Size = UDim2.new(1, -12, 0, 22)
	name.TextScaled = true
	name.ZIndex = 4
	local rarityText = UiStyle.text(card, if rarity then string.upper(rarity.Name) else "", 14, WHITE, UiStyle.BODY_FONT)
	rarityText.Position = UDim2.fromOffset(6, 122)
	rarityText.Size = UDim2.new(1, -12, 0, 16)
	rarityText.ZIndex = 4
	local income = UiStyle.number(card, NumberFormat.perSecond(PetCatalog.GetIncome(petId)), 16, MONEY)
	income.Position = UDim2.fromOffset(6, 138)
	income.Size = UDim2.new(1, -12, 0, 18)
	income.ZIndex = 4
	return card
end

function MarketMenu.create(gui: Instance): Menu
	local window = MenuKit.window(gui, "Marché", Vector2.new(820, 500), HEADER, "Money")
	local pages: { Frame } = {}
	for index = 1, 3 do
		local page = Instance.new("Frame")
		page.Name = "Page" .. index
		page.BackgroundTransparency = 1
		page.Size = UDim2.fromScale(1, 1)
		page.Visible = index == 1
		page.ZIndex = 2
		page.Parent = window.content
		pages[index] = page
	end

	local listings: { Listing } = {}

	------------------------------------------------------------------
	-- Acheter
	------------------------------------------------------------------
	local buyPage = pages[1]
	label(buyPage, "FAMILIERS À ACHETER", 24, WHITE, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 30))
	local buyGrid = scroller(buyPage, UDim2.fromOffset(0, 36), UDim2.new(1, 0, 1, -36), Vector2.new(180, 250))
	local buyEmpty = label(buyPage, "PERSONNE NE VEND RIEN POUR L'INSTANT.\nVENDS LES TIENS DANS « VENDRE » !",
		22, GREY, UDim2.fromOffset(0, 150), UDim2.new(1, 0, 0, 60))
	buyEmpty.TextWrapped = true
	local buySignature = ""

	local function rebuildBuy()
		local signature = ""
		local others: { Listing } = {}
		for _, listing in ipairs(listings) do
			if listing.seller ~= player.UserId then
				table.insert(others, listing)
				signature ..= listing.id .. (if listing.available then "+" else "-") .. ";"
			end
		end
		buyEmpty.Visible = #others == 0
		if signature == buySignature then
			-- Seul l'argent a pu changer : la couleur des boutons suit.
			for _, card in ipairs(buyGrid:GetChildren()) do
				local button = card:FindFirstChild("Buy")
				local price = card:GetAttribute("Price")
				if button and button:IsA("TextButton") and type(price) == "number" and card:GetAttribute("Available") == true then
					UiStyle.setButtonColor(button, if MenuKit.number("Money") >= price then UiStyle.Colors.Green else GREY)
				end
			end
			return
		end
		buySignature = signature
		clear(buyGrid)
		-- Les plus chers d'abord.
		table.sort(others, function(a, b)
			return a.price > b.price
		end)
		for order, listing in ipairs(others) do
			local card = petCard(buyGrid, listing.petId, order)
			card:SetAttribute("Price", listing.price)
			card:SetAttribute("Available", listing.available)
			local seller = UiStyle.text(card, "par " .. listing.sellerName, 14, WHITE, UiStyle.BODY_FONT)
			seller.Position = UDim2.fromOffset(6, 158)
			seller.Size = UDim2.new(1, -12, 0, 18)
			seller.TextScaled = true
			seller.ZIndex = 4
			local price = UiStyle.number(card, NumberFormat.money(listing.price), 24, UiStyle.Colors.Gold)
			price.Position = UDim2.fromOffset(6, 176)
			price.Size = UDim2.new(1, -12, 0, 26)
			price.ZIndex = 4
			local canPay = MenuKit.number("Money") >= listing.price
			local button = UiStyle.button(card, if listing.available then "ACHETER" else "DÉJÀ PRIS",
				UDim2.new(1, -16, 0, 36), if listing.available and canPay then UiStyle.Colors.Green else GREY,
				if listing.available then 20 else 15)
			button.Name = "Buy"
			button.Position = UDim2.new(0, 8, 1, -44)
			button.ZIndex = 5
			button.Activated:Connect(function()
				if not listing.available then
					Sounds.play("Error")
					Toast.show("IL N'EST PLUS À VENDRE", UiStyle.Colors.Red)
				elseif MenuKit.number("Money") < listing.price then
					Sounds.play("Error")
					Toast.show("IL TE MANQUE " .. NumberFormat.money(listing.price - MenuKit.number("Money")) .. " !", UiStyle.Colors.Red)
				else
					Remotes.Market:FireServer("Buy", listing.id)
				end
			end)
		end
	end

	------------------------------------------------------------------
	-- Vendre
	------------------------------------------------------------------
	local sellPage = pages[2]
	label(sellPage, "CHOISIS UN FAMILIER À VENDRE", 24, WHITE, UDim2.fromOffset(0, 0), UDim2.new(0, 470, 0, 30))
	local sellGrid = scroller(sellPage, UDim2.fromOffset(0, 36), UDim2.new(1, -290, 1, -36), Vector2.new(140, 168))
	local sellEmpty = label(sellPage, "PAS DE FAMILIER À VENDRE.\nCEUX QUI TE SUIVENT NE SE VENDENT PAS.", 20, GREY,
		UDim2.fromOffset(0, 150), UDim2.new(1, -290, 0, 60))
	sellEmpty.TextWrapped = true

	local side = UiStyle.panel(sellPage, UDim2.new(0, 274, 1, 0))
	side.AnchorPoint = Vector2.new(1, 0)
	side.Position = UDim2.fromScale(1, 0)
	side.ZIndex = 2
	local preview = Instance.new("Frame")
	preview.BackgroundTransparency = 1
	preview.Position = UDim2.fromOffset(12, 6)
	preview.Size = UDim2.new(1, -24, 0, 92)
	preview.ZIndex = 3
	preview.Parent = side
	local sideName = label(side, "CHOISIS UN FAMILIER", 22, WHITE, UDim2.fromOffset(10, 98), UDim2.new(1, -20, 0, 24))
	sideName.TextScaled = true
	sideName.ZIndex = 3
	local sideIncome = UiStyle.number(side, "", 18, MONEY)
	sideIncome.Position = UDim2.fromOffset(10, 122)
	sideIncome.Size = UDim2.new(1, -20, 0, 20)
	sideIncome.ZIndex = 3
	local priceTitle = label(side, "TON PRIX", 18, UiStyle.Colors.Gold, UDim2.fromOffset(10, 144), UDim2.new(1, -20, 0, 20))
	priceTitle.ZIndex = 3
	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(14, 166)
	box.Size = UDim2.new(1, -28, 0, 44)
	box.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	box.ClearTextOnFocus = false
	box.PlaceholderText = "ex : 25K, 3M, 1.5B"
	box.PlaceholderColor3 = GREY
	box.Text = ""
	box.TextColor3 = Color3.fromRGB(30, 30, 40)
	box.FontFace = UiStyle.NUMBER_FONT
	box.TextSize = 28
	box.ZIndex = 3
	UiStyle.corner(box, 8)
	UiStyle.stroke(box, 4, BLACK, true)
	box.Parent = side
	local priceHint = label(side, "", 16, GREY, UDim2.fromOffset(10, 214), UDim2.new(1, -20, 0, 50))
	priceHint.TextWrapped = true
	priceHint.ZIndex = 3
	local sellButton = UiStyle.button(side, "VENDRE", UDim2.new(1, -24, 0, 50), GREY, 26)
	sellButton.Position = UDim2.new(0, 12, 1, -94)
	sellButton.ZIndex = 4
	local slotsText = label(side, "", 16, WHITE, UDim2.new(0, 10, 1, -40), UDim2.new(1, -20, 0, 30))
	slotsText.TextWrapped = true
	slotsText.ZIndex = 3

	local selected: string? = nil
	local sellSignature = ""

	local function myListings(): { Listing }
		local mine = {}
		for _, listing in ipairs(listings) do
			if listing.seller == player.UserId then
				table.insert(mine, listing)
			end
		end
		return mine
	end

	-- Exemplaires encore vendables (libres moins ceux déjà en vente).
	local function sellable(petId: string): number
		local listed = 0
		for _, listing in ipairs(myListings()) do
			if listing.petId == petId then
				listed += 1
			end
		end
		return MenuKit.spare(petId) - listed
	end

	local function refreshSide()
		local mine = #myListings()
		slotsText.Text = string.format("EN VENTE : %d / %d", mine, Config.Market.MaxListings)
		clear(preview)
		if not selected or sellable(selected) <= 0 then
			selected = nil
			sideName.Text = "CHOISIS UN FAMILIER"
			sideIncome.Text = ""
			priceHint.Text = "TU LE GARDES JUSQU'À LA VENTE"
			UiStyle.setButtonColor(sellButton, GREY)
			return
		end
		local petId = selected :: string
		local entry = PetCatalog.ById[petId]
		local viewport = MenuKit.petViewport(preview, petId, false)
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.ZIndex = 3
		sideName.Text = if entry then entry.Name else petId
		sideIncome.Text = NumberFormat.perSecond(PetCatalog.GetIncome(petId))
		priceHint.Text = "BON PRIX : " .. NumberFormat.money(suggestedPrice(petId)) .. "  •  MAX "
			.. NumberFormat.money(Config.GetMarketMaxPrice(PetCatalog.GetIncome(petId)))
		UiStyle.setButtonColor(sellButton, if mine < Config.Market.MaxListings then UiStyle.Colors.Green else GREY)
	end

	local function rebuildSell()
		local owned: { string } = {}
		local signature = ""
		for _, entry in ipairs(PetCatalog.Everything) do
			local count = sellable(entry.Id)
			if count > 0 then
				table.insert(owned, entry.Id)
				signature ..= entry.Id .. "x" .. count .. ";"
			end
		end
		signature ..= "|" .. (selected or "")
		sellEmpty.Visible = #owned == 0
		if signature ~= sellSignature then
			sellSignature = signature
			clear(sellGrid)
			-- Les plus rentables d'abord.
			table.sort(owned, function(a, b)
				return PetCatalog.GetIncome(a) > PetCatalog.GetIncome(b)
			end)
			for order, petId in ipairs(owned) do
				local card = petCard(sellGrid, petId, order)
				local stroke = card:FindFirstChildOfClass("UIStroke")
				if stroke and petId == selected then
					stroke.Color = WHITE
					stroke.Thickness = 5
				end
				local count = UiStyle.number(card, "x" .. sellable(petId), 18, WHITE)
				count.AnchorPoint = Vector2.new(1, 0)
				count.Position = UDim2.new(1, -6, 0, 4)
				count.Size = UDim2.fromOffset(50, 20)
				count.TextXAlignment = Enum.TextXAlignment.Right
				count.ZIndex = 5
				local hit = Instance.new("TextButton")
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Size = UDim2.fromScale(1, 1)
				hit.ZIndex = 6
				hit.Parent = card
				hit.Activated:Connect(function()
					Sounds.play("UiClick")
					selected = petId
					box.Text = NumberFormat.short(suggestedPrice(petId))
					rebuildSell()
				end)
			end
		end
		refreshSide()
	end

	sellButton.Activated:Connect(function()
		if not selected then
			Sounds.play("Error")
			return
		end
		local price = parsePrice(box.Text)
		if not price or price < Config.Market.MinPrice or price > Config.Market.MaxPrice then
			Sounds.play("Error")
			Toast.show("CE PRIX NE MARCHE PAS (EX : 25K, 3M)", UiStyle.Colors.Red)
			return
		end
		Remotes.Market:FireServer("List", selected, math.floor(price))
	end)

	------------------------------------------------------------------
	-- Mes ventes
	------------------------------------------------------------------
	local minePage = pages[3]
	label(minePage, "TES FAMILIERS EN VENTE", 24, WHITE, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 30))
	local mineList = Instance.new("Frame")
	mineList.BackgroundTransparency = 1
	mineList.Position = UDim2.fromOffset(0, 40)
	mineList.Size = UDim2.new(1, 0, 1, -80)
	mineList.ZIndex = 2
	mineList.Parent = minePage
	local mineLayout = Instance.new("UIListLayout")
	mineLayout.Padding = UDim.new(0, 10)
	mineLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mineLayout.Parent = mineList
	local mineEmpty = label(minePage, "TU NE VENDS RIEN", 22, GREY, UDim2.fromOffset(0, 150), UDim2.new(1, 0, 0, 30))
	label(minePage, "SI TU QUITTES LE JEU, TES VENTES S'ARRÊTENT", 16, GREY,
		UDim2.new(0, 0, 1, -30), UDim2.new(1, 0, 0, 24))
	local mineSignature = ""

	local function rebuildMine()
		local mine = myListings()
		local signature = ""
		for _, listing in ipairs(mine) do
			signature ..= listing.id .. (if listing.available then "+" else "-") .. ";"
		end
		mineEmpty.Visible = #mine == 0
		if signature == mineSignature then
			return
		end
		mineSignature = signature
		clear(mineList)
		for order, listing in ipairs(mine) do
			local entry = PetCatalog.ById[listing.petId]
			local rarity = rarityOf(listing.petId)
			local row = UiStyle.panel(mineList, UDim2.new(1, 0, 0, 100))
			row.LayoutOrder = order
			row.ZIndex = 2
			if rarity then
				row.BackgroundColor3 = rarity.Color:Lerp(UiStyle.Colors.Panel, 0.55)
			end
			local viewport = MenuKit.petViewport(row, listing.petId, false)
			viewport.Position = UDim2.fromOffset(10, 4)
			viewport.Size = UDim2.fromOffset(92, 92)
			viewport.ZIndex = 3
			local name = label(row, if entry then entry.Name else listing.petId, 24, WHITE, UDim2.fromOffset(112, 12), UDim2.new(1, -330, 0, 30))
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextScaled = true
			name.ZIndex = 3
			local price = UiStyle.number(row, NumberFormat.money(listing.price), 26, UiStyle.Colors.Gold)
			price.Position = UDim2.fromOffset(112, 46)
			price.Size = UDim2.fromOffset(200, 30)
			price.TextXAlignment = Enum.TextXAlignment.Left
			price.ZIndex = 3
			local state = label(row, if listing.available then "EN VENTE" else "BLOQUÉE", 16,
				if listing.available then MONEY else UiStyle.Colors.Orange, UDim2.fromOffset(112, 76), UDim2.new(1, -330, 0, 20))
			state.TextXAlignment = Enum.TextXAlignment.Left
			state.ZIndex = 3
			local cancel = UiStyle.button(row, "RETIRER", UDim2.fromOffset(170, 56), UiStyle.Colors.Red, 24)
			cancel.AnchorPoint = Vector2.new(1, 0.5)
			cancel.Position = UDim2.new(1, -16, 0.5, 0)
			cancel.ZIndex = 4
			cancel.Activated:Connect(function()
				Remotes.Market:FireServer("Cancel", listing.id)
			end)
		end
	end

	------------------------------------------------------------------

	local tabs: MenuKit.Tabs
	local function refresh()
		if not window.isOpen() then
			return
		end
		local page = tabs.selected()
		if page == 1 then
			rebuildBuy()
		elseif page == 2 then
			rebuildSell()
		else
			rebuildMine()
		end
		local others = 0
		for _, listing in ipairs(listings) do
			if listing.seller ~= player.UserId then
				others += 1
			end
		end
		tabs.setBadge(1, if others > 0 then tostring(others) else nil)
		local mine = #myListings()
		tabs.setBadge(3, if mine > 0 then tostring(mine) else nil)
	end

	tabs = MenuKit.sideTabs(window, {
		{ label = "Acheter", color = Color3.fromRGB(110, 200, 90), icon = "Shop" },
		{ label = "Vendre", color = UiStyle.Colors.Gold, icon = "Money" },
		{ label = "Mes ventes", color = Color3.fromRGB(90, 170, 255), icon = "Paw" },
	}, function(index: number)
		for pageIndex, page in ipairs(pages) do
			page.Visible = pageIndex == index
		end
		refresh()
	end)

	Remotes.MarketUpdate.OnClientEvent:Connect(function(list: unknown)
		if type(list) ~= "table" then
			return
		end
		local clean: { Listing } = {}
		for _, raw in ipairs(list :: { any }) do
			if type(raw) == "table" and type(raw.id) == "string" and type(raw.petId) == "string"
				and PetCatalog.ById[raw.petId] and type(raw.price) == "number" then
				table.insert(clean, {
					id = raw.id,
					seller = tonumber(raw.seller) or 0,
					sellerName = tostring(raw.sellerName),
					petId = raw.petId,
					price = raw.price,
					available = raw.available == true,
				})
			end
		end
		listings = clean
		refresh()
	end)
	Remotes.Market.OnClientEvent:Connect(function(ok: boolean, message: string)
		Sounds.play(if ok then "UiClick" else "Error")
		Toast.show(message, if ok then UiStyle.Colors.Gold else UiStyle.Colors.Red)
		if ok and tabs.selected() == 2 then
			selected = nil
			box.Text = ""
		end
		refresh()
	end)
	for _, attribute in ipairs({ "Money", "Equipped" }) do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	window.onOpen(function()
		Remotes.Market:FireServer("Refresh")
		refresh()
	end)

	return { window = window }
end

return MarketMenu
