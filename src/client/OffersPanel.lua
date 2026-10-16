--!strict
-- OffersPanel : colonne d'offres Robux à droite de l'écran (16 oct., comme dans les packs « Studs UI ») : 3 cases,
-- chacune une grosse icône sur des rayons qui tournent, son nom et une pastille de prix. Toutes les 9 s, les cases
-- glissent vers la droite et reviennent avec d'autres offres. Un clic ouvre l'achat Roblox. Les passes déjà possédés
-- et ceux pas encore créés (Id = 0) ne sont pas proposés. Cachée quand une fenêtre est ouverte (MenuKit) et sur
-- tactile (pas la place à côté du bouton de saut).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Perks = require(ReplicatedStorage.Shared.Perks)
local UiStyle = require(script.Parent.UiStyle)

local OffersPanel = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local CELL = 112
local ROTATE_EVERY = 9

-- Offres mises en avant (dans cet ordre), avec la couleur de leurs rayons.
local FEATURED: { { key: string, color: Color3 } } = {
	{ key = "DoubleMoney", color = Color3.fromRGB(110, 240, 70) },
	{ key = "LuckyLuck", color = Color3.fromRGB(80, 230, 120) },
	{ key = "VIP", color = Color3.fromRGB(255, 205, 50) },
	{ key = "ServerLuck", color = Color3.fromRGB(255, 120, 230) },
	{ key = "EquipPlus2", color = Color3.fromRGB(255, 160, 60) },
	{ key = "AutoMagnet", color = Color3.fromRGB(255, 90, 90) },
	{ key = "ExtraBackpack", color = Color3.fromRGB(255, 140, 60) },
}

type Item = Config.MonetizationItem
local function find(key: string): (Item?, boolean)
	for _, pass in ipairs(Config.Monetization.GamePasses) do
		if pass.Key == key then
			return pass, true
		end
	end
	for _, product in ipairs(Config.Monetization.Products) do
		if product.Key == key then
			return product, false
		end
	end
	return nil, false
end

-- Offres qu'on peut encore acheter.
type Offer = { item: Item, isPass: boolean, color: Color3 }
local function available(): { Offer }
	local list: { Offer } = {}
	for _, featured in ipairs(FEATURED) do
		local item, isPass = find(featured.key)
		if item and item.Id ~= 0 and not (isPass and Perks.HasPass(player, item.Key)) then
			local offer: Offer = { item = item, isPass = isPass == true, color = featured.color }
			table.insert(list, offer)
		end
	end
	return list
end

export type Panel = { frame: Frame, setHidden: (hidden: boolean) -> () }

function OffersPanel.create(gui: Instance): Panel
	local column = Instance.new("Frame")
	column.Name = "Offers"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(1, 0.5)
	column.Position = UDim2.new(1, -20, 0.5, -20)
	column.Size = UDim2.fromOffset(CELL, CELL * 3 + 20)
	column.Parent = gui

	type Cell = { button: TextButton, icon: ImageLabel, rays: ImageLabel, name: TextLabel, price: TextLabel, offer: Offer? }
	local cells: { Cell } = {}
	for index = 1, 3 do
		local button = Instance.new("TextButton")
		button.Name = "Offer" .. index
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Size = UDim2.fromOffset(CELL, CELL)
		button.Position = UDim2.fromOffset(0, (index - 1) * (CELL + 10))
		button.Parent = column
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = button
		local rays = UiStyle.rays(holder, WHITE, CELL * 1.25, 35)
		local icon = Icons.image(button, "Gift", UDim2.fromOffset(CELL * 0.7, CELL * 0.7))
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.42)
		icon.ZIndex = 3
		UiStyle.sway(icon, 7)
		local name = UiStyle.text(button, "", 18, WHITE, UiStyle.TITLE_FONT)
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -18)
		name.Size = UDim2.new(1, 10, 0, 22)
		name.TextScaled = true
		name.ZIndex = 4
		-- Pastille de prix verte (« R$ 399 »).
		local price = UiStyle.number(button, "", 16, WHITE)
		price.AnchorPoint = Vector2.new(0.5, 1)
		price.Position = UDim2.new(0.5, 0, 1, 4)
		price.Size = UDim2.fromOffset(78, 24)
		price.BackgroundTransparency = 0
		price.BackgroundColor3 = WHITE
		price.ZIndex = 4
		UiStyle.corner(price, 12)
		UiStyle.gradient(price, Color3.fromRGB(120, 235, 80), Color3.fromRGB(40, 160, 40))
		UiStyle.stroke(price, 2.5, Color3.new(0, 0, 0), true)
		local scale = Instance.new("UIScale")
		scale.Parent = button
		button.MouseEnter:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.1 }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end)
		local cell: Cell = { button = button, icon = icon, rays = rays, name = name, price = price, offer = nil }
		button.Activated:Connect(function()
			local offer = cell.offer
			if not offer then
				return
			end
			if offer.isPass then
				MarketplaceService:PromptGamePassPurchase(player, offer.item.Id)
			else
				pcall(function()
					MarketplaceService:PromptProductPurchase(player, offer.item.Id)
				end)
			end
		end)
		cells[index] = cell
	end

	local start = 0
	local function fill()
		local list = available()
		for index, cell in ipairs(cells) do
			local offer = if #list > 0 then list[(start + index - 1) % #list + 1] else nil
			cell.offer = offer
			cell.button.Visible = offer ~= nil and index <= #list
			if offer then
				cell.icon.Image = Icons.id(offer.item.Icon) or ""
				cell.rays.ImageColor3 = offer.color
				cell.name.Text = offer.item.Name
				cell.price.Text = "R$ " .. tostring(offer.item.Price)
			end
		end
	end

	local hidden = false
	local function slide(out: boolean, delay: number, cell: Cell)
		task.delay(delay, function()
			TweenService:Create(cell.button, TweenInfo.new(0.3, if out then Enum.EasingStyle.Quad else Enum.EasingStyle.Back,
				if out then Enum.EasingDirection.In else Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(if out then CELL + 40 else 0, cell.button.Position.Y.Offset) }):Play()
		end)
	end

	fill()
	task.spawn(function()
		while true do
			task.wait(ROTATE_EVERY)
			if hidden then
				continue
			end
			for index, cell in ipairs(cells) do
				slide(true, (index - 1) * 0.08, cell)
			end
			task.wait(0.55)
			start += 3
			fill()
			for index, cell in ipairs(cells) do
				slide(false, (index - 1) * 0.08, cell)
			end
		end
	end)
	-- Un passe vient d'être acheté : il disparaît des offres.
	player.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, 5) == "Pass_" then
			fill()
		end
	end)

	return {
		frame = column,
		setHidden = function(value: boolean)
			if value == hidden then
				return
			end
			hidden = value
			TweenService:Create(column, TweenInfo.new(0.25, Enum.EasingStyle.Quad),
				{ Position = UDim2.new(1, if value then CELL + 40 else -20, 0.5, -20) }):Play()
		end,
	}
end

return OffersPanel
