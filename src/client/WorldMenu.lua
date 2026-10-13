--!strict
-- WorldMenu : fenêtre MONDES. Les 7 mondes (Config.Worlds) en grandes cartes qui défilent, comme la boutique :
-- nom, numéro, aperçu du paysage (sol, mur, crête aux couleurs du monde, shared/Worlds), bonus de revenu, et
--   « TU ES ICI » (monde actuel), « Y ALLER » (déjà visité : retour gratuit, Remotes.GoToWorld), bouton
--   « VOYAGER $prix » (monde suivant), « VERROUILLÉ » (après). Le bonus de revenu reste celui du monde le plus loin.
-- Le voyage est validé par le serveur (Remotes.BuyTier / GoToWorld -> server/TierController).
-- Arrivée (Remotes.TierReached) : flash, grand titre du monde, son ; annonce chez les autres joueurs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local Worlds = require(ReplicatedStorage.Shared.Worlds)
local MenuKit = require(script.Parent.MenuKit)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local WorldMenu = {}

local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(150, 150, 160)
local CARD_WIDTH = 214
local PRAIRIE = Worlds.Looks.Prairie

local player = Players.LocalPlayer

-- Monde le plus loin débloqué (bonus de revenu).
local function tier(): number
	local value = player:GetAttribute("Tier")
	return if type(value) == "number" then value else 1
end

-- Monde où le joueur se trouve (on peut revenir dans un monde déjà visité).
local function currentWorld(): number
	local value = player:GetAttribute("World")
	return if type(value) == "number" then value else tier()
end

local function lookOf(index: number): Worlds.Look
	return Worlds.Looks[Config.Worlds[index].Id] or PRAIRIE
end

-- Couleurs de la Prairie (MapGenerator) pour les rôles que les autres mondes repeignent.
local PRAIRIE_COLORS: { [string]: Color3 } = {
	GrassA = Color3.fromRGB(150, 228, 58),
	WallA = Color3.fromRGB(202, 145, 86),
	WallTop = Color3.fromRGB(110, 214, 42),
	PathA = Color3.fromRGB(246, 214, 128),
}

local function swatch(look: Worlds.Look, role: string): Color3
	return look.Palette[role] or PRAIRIE_COLORS[role] or WHITE
end

type Card = { index: number, status: TextLabel, button: TextButton }

export type Menu = { window: MenuKit.Window, refresh: () -> (), canTravel: () -> boolean }

-- Petit paysage du monde : ciel (couleur de l'air), mur avec sa crête, sol en damier.
local function landscape(parent: Instance, look: Worlds.Look)
	local frame = Instance.new("Frame")
	frame.Name = "Landscape"
	frame.Position = UDim2.fromOffset(12, 64)
	frame.Size = UDim2.new(1, -24, 0, 104)
	frame.BackgroundColor3 = look.Ambience.AirColor
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	UiStyle.corner(frame, 6)
	UiStyle.stroke(frame, 3, Color3.new(0, 0, 0), true)
	frame.Parent = parent
	local wall = Instance.new("Frame")
	wall.BorderSizePixel = 0
	wall.BackgroundColor3 = swatch(look, "WallA")
	wall.Position = UDim2.fromScale(0, 0.35)
	wall.Size = UDim2.fromScale(1, 0.3)
	wall.Parent = frame
	local top = Instance.new("Frame")
	top.BorderSizePixel = 0
	top.BackgroundColor3 = swatch(look, "WallTop")
	top.Position = UDim2.fromScale(0, 0.3)
	top.Size = UDim2.fromScale(1, 0.07)
	top.Parent = frame
	for index = 0, 5 do
		local tile = Instance.new("Frame")
		tile.BorderSizePixel = 0
		tile.BackgroundColor3 = if index % 2 == 0 then swatch(look, "GrassA") else swatch(look, "PathA")
		tile.Position = UDim2.fromScale(index / 6, 0.65)
		tile.Size = UDim2.fromScale(1 / 6 + 0.002, 0.35)
		tile.Parent = frame
	end
end

function WorldMenu.create(gui: Instance): Menu
	local window = MenuKit.window(gui, "Mondes", Vector2.new(800, 480), Color3.fromRGB(255, 150, 40))

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
	row.Parent = window.content
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

	local cardHeight = window.frame.Size.Y.Offset + window.content.Size.Y.Offset - 18
	local cards: { Card } = {}

	for index, world in ipairs(Config.Worlds) do
		local look = lookOf(index)
		local card = UiStyle.brightCard(row, UDim2.fromOffset(CARD_WIDTH, cardHeight), look.Accent)
		card.LayoutOrder = index
		local name = UiStyle.text(card, world.Name, 30, WHITE, UiStyle.BODY_FONT)
		name.Position = UDim2.fromOffset(6, 8)
		name.Size = UDim2.new(1, -12, 0, 32)
		local number = UiStyle.text(card, "Monde " .. index, 18, WHITE, UiStyle.BODY_FONT)
		number.Position = UDim2.fromOffset(6, 38)
		number.Size = UDim2.new(1, -12, 0, 22)
		landscape(card, look)
		local bonusBox = Instance.new("Frame")
		bonusBox.BackgroundColor3 = Color3.new(0, 0, 0)
		bonusBox.BackgroundTransparency = 0.55
		bonusBox.BorderSizePixel = 0
		bonusBox.Position = UDim2.new(0, 10, 1, -160)
		bonusBox.Size = UDim2.new(1, -20, 0, 56)
		UiStyle.corner(bonusBox, 6)
		bonusBox.Parent = card
		local bonus = UiStyle.number(bonusBox, "Revenu x" .. tostring(world.IncomeMultiplier), 26, UiStyle.Colors.Money)
		bonus.Size = UDim2.fromScale(1, 1)
		local status = UiStyle.text(card, "", 20, WHITE, UiStyle.BODY_FONT)
		status.Position = UDim2.new(0, 10, 1, -96)
		status.Size = UDim2.new(1, -20, 0, 30)
		local button = UiStyle.button(card, "", UDim2.new(1, -20, 0, 52), UiStyle.Colors.Green, 26)
		button.Position = UDim2.new(0, 10, 1, -60)
		local caption = button:FindFirstChild("Caption")
		if caption and caption:IsA("TextLabel") then
			caption.FontFace = UiStyle.NUMBER_FONT
		end
		button.Activated:Connect(function()
			if index <= tier() and index ~= currentWorld() then
				Sounds.play("UiClick")
				Remotes.GoToWorld:FireServer(index)
				return
			end
			if index ~= tier() + 1 then
				return
			end
			if MenuKit.number("Money") < world.Price then
				Sounds.play("Error")
				Toast.show("PAS ASSEZ D'ARGENT : " .. NumberFormat.money(world.Price), UiStyle.Colors.Red)
				return
			end
			Remotes.BuyTier:FireServer()
		end)
		table.insert(cards, { index = index, status = status, button = button })
	end

	local function refresh()
		local current = tier()
		local here = currentWorld()
		local money = MenuKit.number("Money")
		for _, card in ipairs(cards) do
			local world = Config.Worlds[card.index]
			local caption = card.button:FindFirstChild("Caption") :: TextLabel
			card.button.Visible = true
			if card.index == here then
				card.status.Text = "TU ES ICI"
				caption.Text = "ACTUEL"
				UiStyle.setButtonColor(card.button, UiStyle.Colors.Cyan)
			elseif card.index <= current then
				card.status.Text = "DÉJÀ VISITÉ"
				caption.Text = "Y ALLER"
				UiStyle.setButtonColor(card.button, UiStyle.Colors.Green)
			elseif card.index == current + 1 then
				card.status.Text = "VOYAGER POUR"
				caption.Text = NumberFormat.money(world.Price)
				UiStyle.setButtonColor(card.button, if money >= world.Price then UiStyle.Colors.Green else UiStyle.Colors.Red)
			else
				card.status.Text = "VERROUILLÉ"
				caption.Text = NumberFormat.money(world.Price)
				UiStyle.setButtonColor(card.button, GREY)
			end
		end
	end

	window.onOpen(function()
		refresh()
		-- Montre directement le monde actuel et le suivant.
		row.CanvasPosition = Vector2.new(math.max(0, (currentWorld() - 1) * (CARD_WIDTH + 12) - 20), 0)
	end)

	return {
		window = window,
		refresh = refresh,
		canTravel = function()
			local nextWorld = Config.Worlds[tier() + 1]
			return nextWorld ~= nil and MenuKit.number("Money") >= nextWorld.Price
		end,
	}
end

----------------------------------------------------------------------
-- Arrivée dans un nouveau monde
----------------------------------------------------------------------

-- revisit = retour dans un monde déjà visité : pas de nouveau bonus de revenu, juste « DE RETOUR ».
function WorldMenu.celebrate(gui: Instance, index: number, revisit: boolean?)
	local world = Config.GetWorld(index)
	local look = Worlds.Looks[world.Id] or PRAIRIE
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 0
	flash.ZIndex = 50
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()

	local title = UiStyle.text(gui, string.format("MONDE %d : %s", index, TextFormat.upper(world.Name)), 72, look.Accent)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.38)
	title.Size = UDim2.fromOffset(1100, 90)
	title.ZIndex = 51
	local subtitle = UiStyle.number(gui, if revisit then "De retour !" else "Revenu x" .. tostring(world.IncomeMultiplier) .. " !", 40,
		UiStyle.Colors.Money)
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.fromScale(0.5, 0.48)
	subtitle.Size = UDim2.fromOffset(700, 50)
	subtitle.ZIndex = 51
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = title
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Sounds.play("RareDrop")
	task.delay(3.2, function()
		local fade = TweenInfo.new(0.6)
		for _, label in ipairs({ title, subtitle }) do
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(4, function()
		flash:Destroy()
		title:Destroy()
		subtitle:Destroy()
	end)
end

return WorldMenu
