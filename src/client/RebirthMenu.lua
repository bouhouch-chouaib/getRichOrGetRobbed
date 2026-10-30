--!strict
-- RebirthMenu : fenêtre REBIRTH (Config.Rebirth, validé par server/ProgressionController -> SessionData.Rebirth).
-- À gauche : ce qu'on gagne (revenu x(1+n) -> x(1+n+1), familiers dans la base), à droite : les deux conditions
-- (monde Config.Rebirth.RequiredTier atteint, argent) avec une barre, l'entraînement plus rapide, ce qu'on garde / perd. Le bouton demande une 2e pression
-- (« SÛR ? ») pour éviter un Rebirth par erreur. Célébration en grand quand c'est fait (RebirthMenu.celebrate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local MenuKit = require(script.Parent.MenuKit)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local RebirthMenu = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GREY = Color3.fromRGB(150, 150, 160)
local PURPLE = Color3.fromRGB(170, 90, 255)
local MONEY = UiStyle.Colors.Money
local RED = UiStyle.Colors.Red

export type Menu = { window: MenuKit.Window, refresh: () -> (), canRebirth: () -> boolean }

local function rebirths(): number
	return MenuKit.number("Rebirths")
end

local function canRebirth(): boolean
	return MenuKit.number("Tier") >= Config.Rebirth.RequiredTier and MenuKit.number("Money") >= Config.GetRebirthPrice(rebirths())
end

local function text(parent: Instance, value: string, size: number, color: Color3, y: number, height: number): TextLabel
	local label = UiStyle.text(parent, value, size, color, UiStyle.BODY_FONT)
	label.Position = UDim2.fromOffset(10, y)
	label.Size = UDim2.new(1, -20, 0, height)
	label.TextWrapped = true
	return label
end

function RebirthMenu.create(gui: Instance): Menu
	local window = MenuKit.window(gui, "Rebirth", Vector2.new(780, 470), PURPLE, "Rebirth")

	-- À gauche : le gain.
	local gain = UiStyle.brightCard(window.content, UDim2.new(0.44, -6, 1, -80), PURPLE)
	local title = text(gain, "", 40, WHITE, 8, 46)
	-- (26 oct.) Resserré : la ligne des cases de la capsule sortait de la carte (300 px de haut).
	Icons.image(gain, "Rebirth", UDim2.fromOffset(56, 56), UDim2.new(0.5, -28, 0, 54))
	text(gain, "TON ARGENT", 22, WHITE, 114, 24)
	local incomeLine = UiStyle.number(gain, "", 34, MONEY)
	incomeLine.Position = UDim2.fromOffset(10, 136)
	incomeLine.Size = UDim2.new(1, -20, 0, 36)
	text(gain, "FAMILIERS DANS TA BASE", 20, WHITE, 176, 22)
	local petsLine = UiStyle.number(gain, "", 30, UiStyle.Colors.Gold)
	petsLine.Position = UDim2.fromOffset(10, 198)
	petsLine.Size = UDim2.new(1, -20, 0, 32)
	text(gain, "CASES DE LA CAPSULE", 20, WHITE, 234, 22)
	local capsuleLine = UiStyle.number(gain, "", 30, UiStyle.Colors.Cyan)
	capsuleLine.Position = UDim2.fromOffset(10, 256)
	capsuleLine.Size = UDim2.new(1, -20, 0, 32)

	-- À droite : conditions, ce qu'on garde et ce qu'on perd.
	local side = UiStyle.panel(window.content, UDim2.new(0.56, -6, 1, -80))
	side.Position = UDim2.new(0.44, 6, 0, 0)
	local worldLine = text(side, "", 22, WHITE, 8, 28)
	worldLine.TextXAlignment = Enum.TextXAlignment.Left
	local moneyLine = text(side, "", 22, WHITE, 40, 28)
	moneyLine.TextXAlignment = Enum.TextXAlignment.Left
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(10, 74)
	bar.Size = UDim2.new(1, -20, 0, 26)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	UiStyle.corner(bar, 6)
	UiStyle.stroke(bar, 3, BLACK, true)
	bar.Parent = side
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = MONEY
	UiStyle.corner(fill, 6)
	fill.Parent = bar
	local percent = UiStyle.number(bar, "", 18, WHITE)
	percent.Size = UDim2.fromScale(1, 1)
	percent.ZIndex = 3
	-- 30 oct. : la Vitesse et la Force repartent de zéro, mais l'entraînement va plus vite à vie.
	local trainingLine = text(side, "", 22, UiStyle.Colors.Cyan, 108, 28)
	trainingLine.TextXAlignment = Enum.TextXAlignment.Left
	local keep = text(side, "TU GARDES : FAMILIERS, ŒUFS, ARMES ET ACHATS ROBUX", 20, MONEY, 142, 56)
	keep.TextXAlignment = Enum.TextXAlignment.Left
	local lose = text(side, "TU PERDS : ARGENT, MONDES, BOUTIQUE, VITESSE ET FORCE", 20,
		Color3.fromRGB(255, 120, 120), 204, 56)
	lose.TextXAlignment = Enum.TextXAlignment.Left

	local button = UiStyle.button(window.content, "REBIRTH !", UDim2.new(1, 0, 0, 66), GREY, 36)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.fromScale(0.5, 1)
	local caption = button:FindFirstChild("Caption") :: TextLabel
	local confirmUntil = 0

	local function refresh()
		local count = rebirths()
		local price = Config.GetRebirthPrice(count)
		local money = MenuKit.number("Money")
		local tierOk = MenuKit.number("Tier") >= Config.Rebirth.RequiredTier
		local worldName = TextFormat.upper(Config.GetWorld(Config.Rebirth.RequiredTier).Name)
		title.Text = string.format("REBIRTH %d", count + 1)
		incomeLine.Text = string.format("x%d  →  x%d", Config.GetRebirthMultiplier(count), Config.GetRebirthMultiplier(count + 1))
		local slots, nextSlots = Config.GetIncomeSlots(count), Config.GetIncomeSlots(count + 1)
		petsLine.Text = if nextSlots > slots then string.format("%d  →  %d", slots, nextSlots) else string.format("%d (MAX)", slots)
		-- Une chambre de plus dans la capsule d'évolution (Config.GetCapsuleSlots) : un œuf de plus qui évolue en même temps.
		local chambers, nextChambers = Config.GetCapsuleSlots(count), Config.GetCapsuleSlots(count + 1)
		capsuleLine.Text = if nextChambers > chambers then string.format("%d  →  %d", chambers, nextChambers)
			else string.format("%d (MAX)", chambers)
		local function factor(value: number): string
			local shown = string.gsub(string.format("%.1f", value), "%.0$", "")
			shown = string.gsub(shown, "%.", ",")
			return "x" .. shown
		end
		trainingLine.Text = string.format("ENTRAÎNEMENT %s  →  %s", factor(Config.GetRebirthTrainingMultiplier(count)),
			factor(Config.GetRebirthTrainingMultiplier(count + 1)))
		worldLine.Text = (if tierOk then "OK  " else "") .. "VA DANS LE MONDE " .. worldName
		worldLine.TextColor3 = if tierOk then MONEY else WHITE
		moneyLine.Text = string.format("IL TE FAUT %s  (TU AS %s)", NumberFormat.money(price), NumberFormat.money(money))
		moneyLine.TextColor3 = if money >= price then MONEY else WHITE
		local progress = math.clamp(money / price, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(progress, 1) }):Play()
		percent.Text = string.format("%d %%", math.floor(progress * 100))
		if not canRebirth() then
			caption.Text = if tierOk then "PAS ENCORE ASSEZ D'ARGENT" else "VA D'ABORD DANS LE MONDE " .. worldName
			UiStyle.setButtonColor(button, GREY)
		elseif os.clock() < confirmUntil then
			caption.Text = "SÛR ? APPUIE ENCORE !"
			UiStyle.setButtonColor(button, RED)
		else
			caption.Text = string.format("REBIRTH ! (ARGENT x%d)", Config.GetRebirthMultiplier(count + 1))
			UiStyle.setButtonColor(button, UiStyle.Colors.Green)
		end
	end

	button.Activated:Connect(function()
		if not canRebirth() then
			Sounds.play("Error")
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Remotes.Bonus:FireServer("Rebirth")
		else
			confirmUntil = os.clock() + 3
			task.delay(3.05, refresh)
		end
		refresh()
	end)
	window.onOpen(refresh)

	return { window = window, refresh = refresh, canRebirth = canRebirth }
end

-- Rebirth réussi : flash violet, grand titre, nouveau revenu.
function RebirthMenu.celebrate(gui: Instance, count: number)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = PURPLE
	flash.BackgroundTransparency = 0
	flash.ZIndex = 50
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	local titleLabel = UiStyle.text(gui, string.format("REBIRTH %d !", count), 90, WHITE)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	titleLabel.Position = UDim2.fromScale(0.5, 0.36)
	titleLabel.Size = UDim2.fromOffset(1000, 110)
	titleLabel.ZIndex = 51
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), PURPLE)
	gradient.Rotation = 90
	gradient.Parent = titleLabel
	local subtitle = UiStyle.number(gui, string.format("ARGENT x%d POUR TOUJOURS !", Config.GetRebirthMultiplier(count)), 44, MONEY)
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.fromScale(0.5, 0.48)
	subtitle.Size = UDim2.fromOffset(800, 54)
	subtitle.ZIndex = 51
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = titleLabel
	TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Sounds.play("HoleTierUp")
	Sounds.play("LevelUp")
	Toast.show("TU REPARS EN PRAIRIE... MAIS TU GAGNES PLUS D'ARGENT POUR TOUJOURS !", UiStyle.Colors.Gold)
	task.delay(3.6, function()
		local fade = TweenInfo.new(0.6)
		for _, label in ipairs({ titleLabel, subtitle }) do
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(4.4, function()
		flash:Destroy()
		titleLabel:Destroy()
		subtitle:Destroy()
	end)
end

return RebirthMenu
