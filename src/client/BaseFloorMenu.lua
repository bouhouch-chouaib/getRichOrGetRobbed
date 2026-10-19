--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(ReplicatedStorage.Shared.Config)
local Expansion = require(ReplicatedStorage.Shared.BaseExpansion)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MenuKit = require(script.Parent.MenuKit)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)
local BaseFloorMenu = {}
function BaseFloorMenu.create(parent: Instance)
	local window = MenuKit.window(parent, "Étages de base", Vector2.new(600, 410), UiStyle.Colors.Cyan, "Rebirth")
	local content = window.content
	local title = UiStyle.text(content, "", 28)
	title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 38)
	local summary = UiStyle.text(content, "", 20, UiStyle.Colors.Gold)
	summary.Position, summary.Size = UDim2.fromOffset(12, 56), UDim2.new(1, -24, 0, 52)
	summary.TextWrapped = true
	local hint = UiStyle.text(
		content,
		"Un étage par monde atteint. Chaque étage ajoute 10 places et un escalier. Tes étages restent après un Rebirth.",
		17
	)
	hint.Position, hint.Size, hint.TextWrapped = UDim2.fromOffset(16, 120), UDim2.new(1, -32, 0, 60), true
	local cash = UiStyle.button(content, "", UDim2.new(0.5, -18, 0, 56), UiStyle.Colors.Green, 22)
	cash.Position = UDim2.fromOffset(8, 196)
	local robux = UiStyle.button(content, "", UDim2.new(0.5, -18, 0, 56), UiStyle.Colors.Purple, 22)
	robux.Position = UDim2.new(0.5, 10, 0, 196)
	local note = UiStyle.text(content, "", 14, UiStyle.Colors.PanelText)
	note.Position, note.Size, note.TextWrapped = UDim2.fromOffset(12, 266), UDim2.new(1, -24, 0, 38), true
	local product: Config.MonetizationItem? = nil
	for _, item in ipairs(Config.Monetization.Products) do
		if item.Key == "BaseFloor" then
			product = item
		end
	end
	local price = if product then product.Price else 149
	local function refresh()
		local floors = MenuKit.number("BaseFloors")
		local limit = Expansion.Limit(MenuKit.number("Tier"))
		local available = floors < limit
		title.Text = string.format(
			"%d étage%s • %d places",
			floors,
			if floors > 1 then "s" else "",
			MenuKit.number("BaseCapacity")
		)
		summary.Text = if available
			then "Prochain : étage " .. (floors + 1)
			else "Tous les étages disponibles sont construits"
		(cash:FindFirstChild("Caption") :: TextLabel).Text = if available
			then (if MenuKit.number("FloorCredits") > 0
				then "UTILISER MON CRÉDIT"
				else NumberFormat.money(Expansion.Price(floors) or 0))
			else "MONDE SUIVANT"
		(robux:FindFirstChild("Caption") :: TextLabel).Text = if product and product.Id > 0
			then price .. " ROBUX"
			else "ROBUX : BIENTÔT"
		UiStyle.setButtonColor(cash, if available then UiStyle.Colors.Green else Color3.fromRGB(120, 120, 130))
		note.Text = if MenuKit.number("FloorCredits") > 0
			then MenuKit.number("FloorCredits") .. " crédit(s) sauvegardé(s), utilisables avec les prochains mondes."
			else "Les deux boutons achètent le même étage. Prix Robux confirmé dans la fenêtre Roblox."
	end
	cash.Activated:Connect(function()
		Remotes.BaseFloor:FireServer("Cash")
	end)
	robux.Activated:Connect(function()
		Remotes.BaseFloor:FireServer("Robux")
	end)
	Remotes.BaseFloor.OnClientEvent:Connect(function(ok: boolean, message: string)
		Toast.show(message, if ok then UiStyle.Colors.Green else UiStyle.Colors.Red)
		refresh()
	end)
	for _, key in ipairs({ "BaseFloors", "FloorCredits", "BaseCapacity", "Tier", "Money" }) do
		MenuKit.player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	window.onOpen(refresh)
	if product and product.Id > 0 then
		local productId = product.Id
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
			end)
			if ok and info and type(info.PriceInRobux) == "number" then
				price = info.PriceInRobux
				refresh()
			end
		end)
	end
	refresh()
	return { window = window }
end
return BaseFloorMenu
