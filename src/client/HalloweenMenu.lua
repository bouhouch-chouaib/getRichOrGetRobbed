--!strict
-- HalloweenMenu : le chaudron d'Halloween 2026 (Config.Halloween), ouvert par le bouton BONBONS du HUD ou par [E] devant
-- le chaudron de l'arène (client/HUD). Pensé pour jouer sans lire (UI_UX_GUIDELINES.md §7) :
--   - à gauche : l'œuf Citrouille en 3D, « TU AS 120 », gros bouton OUVRIR avec son prix, la fin de l'événement ;
--   - à droite : comment gagner des bonbons (3 images) puis les 5 familiers limités, avec leurs chances (silhouette
--     tant qu'on ne l'a pas eu).
-- Le serveur revérifie tout (Remotes.Halloween "Buy", server/HalloweenController) ; l'œuf arrive dans la couveuse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Halloween = require(ReplicatedStorage.Shared.Halloween)
local Icons = require(ReplicatedStorage.Shared.Icons)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local MenuKit = require(script.Parent.MenuKit)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UIJuice = require(script.Parent.UIJuiceController)
local UiStyle = require(script.Parent.UiStyle)

local HalloweenMenu = {}

export type Menu = { window: MenuKit.Window, refresh: () -> () }

local SETTINGS = Config.Halloween
local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local ORANGE = Color3.fromRGB(255, 128, 24)
local HEADER = Color3.fromRGB(255, 120, 20)
local GREY = Color3.fromRGB(120, 120, 135)

local function card(parent: Instance, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = UiStyle.Colors.Panel
	frame.Position = position
	frame.Size = size
	UiStyle.corner(frame, 10)
	UiStyle.stroke(frame, 3, Color3.new(0, 0, 0), true)
	frame.Parent = parent
	return frame
end

local function label(parent: Instance, value: string, size: number, color: Color3, position: UDim2, frameSize: UDim2): TextLabel
	local text = UiStyle.text(parent, value, size, color)
	text.Position = position
	text.Size = frameSize
	text.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = text
	return text
end

-- Œuf Citrouille en 3D (shared/EggModelBuilder), qui tourne doucement.
local function eggViewport(parent: Instance): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = WHITE
	viewport.Parent = parent
	local model = require(ReplicatedStorage.Shared.EggModelBuilder).Build("Rare", "Citrouille")
	model.Parent = viewport
	local box, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0.3, 0.25, -1).Unit * size.Magnitude * 1.05, box.Position)
	camera.Parent, viewport.CurrentCamera = viewport, camera
	task.spawn(function()
		local pivot = model:GetPivot()
		local angle = 0
		while viewport.Parent do
			angle += 0.03
			model:PivotTo(pivot * CFrame.Angles(0, math.sin(angle) * 0.5, 0))
			task.wait(1 / 30)
		end
	end)
	return viewport
end

local function timeLeft(): string
	local left = Halloween.Left(Halloween.Now())
	local days, hours, minutes = left // 86400, (left % 86400) // 3600, (left % 3600) // 60
	if days >= 1 then
		return string.format("FINI DANS %d J %02d H", days, hours)
	end
	return string.format("FINI DANS %d H %02d MIN", hours, minutes)
end

function HalloweenMenu.create(gui: Instance): Menu
	local window = MenuKit.window(gui, "Halloween", Vector2.new(820, 470), HEADER, "Ghost")
	local content = window.content

	------------------------------------------------------------------
	-- À gauche : l'œuf Citrouille et le bouton OUVRIR
	------------------------------------------------------------------
	local left = card(content, UDim2.fromScale(0, 0), UDim2.new(0.36, -6, 1, 0))
	label(left, "ŒUF CITROUILLE", 26, ORANGE, UDim2.new(0, 8, 0, 8), UDim2.new(1, -16, 0, 30))
	local egg = eggViewport(left)
	egg.Position = UDim2.new(0, 10, 0, 42)
	egg.Size = UDim2.new(1, -20, 0, 170)
	local owned = label(left, "", 24, WHITE, UDim2.new(0, 8, 0, 218), UDim2.new(1, -16, 0, 30))
	local buyButton = UiStyle.button(left, "", UDim2.new(1, -24, 0, 62), UiStyle.Colors.Green, 26)
	buyButton.Position = UDim2.new(0, 12, 0, 256)
	UIJuice.button(buyButton)
	local buyCaption = buyButton:FindFirstChild("Caption") :: TextLabel
	local ends = label(left, "", 18, UiStyle.Colors.PanelText, UDim2.new(0, 8, 1, -34), UDim2.new(1, -16, 0, 24))

	------------------------------------------------------------------
	-- À droite : gagner des bonbons, puis les 5 familiers limités
	------------------------------------------------------------------
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(0.36, 6, 0, 0)
	right.Size = UDim2.new(0.64, -6, 1, 0)
	right.Parent = content
	label(right, "GAGNE DES BONBONS", 24, WHITE, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 28))
	local ways = {
		{ icon = "Vortex", text = "OBJET DANS LE TROU", value = "+" .. SETTINGS.CandyPerItem },
		{ icon = "Pumpkin", text = "CITROUILLE DANS LE TROU", value = "+" .. SETTINGS.Pumpkin.Candy },
		{ icon = "Moon", text = "HEURE HANTÉE", value = "x" .. SETTINGS.HauntedHour.CandyMultiplier },
	}
	for index, way in ipairs(ways) do
		local box = card(right, UDim2.new((index - 1) / 3, 3, 0, 32), UDim2.new(1 / 3, -6, 0, 108))
		if way.icon == "Pumpkin" then
			local pumpkin = UiStyle.text(box, "🎃", 40, WHITE)
			pumpkin.Position = UDim2.new(0, 6, 0, 6)
			pumpkin.Size = UDim2.fromOffset(52, 52)
		else
			Icons.image(box, way.icon, UDim2.fromOffset(52, 52), UDim2.fromOffset(6, 6))
		end
		local value = UiStyle.number(box, way.value, 34, ORANGE)
		value.Position = UDim2.new(0, 62, 0, 10)
		value.Size = UDim2.new(1, -68, 0, 44)
		value.TextXAlignment = Enum.TextXAlignment.Left
		label(box, way.text, 16, WHITE, UDim2.new(0, 6, 0, 62), UDim2.new(1, -12, 0, 40)).TextWrapped = true
	end

	label(right, "5 FAMILIERS LIMITÉS !", 24, ORANGE, UDim2.fromOffset(0, 150), UDim2.new(1, 0, 0, 28))
	type PetCard = { petId: string, holder: Frame, name: TextLabel, viewport: ViewportFrame?, known: boolean? }
	local cards: { PetCard } = {}
	local total = 0
	for _, petId in ipairs(SETTINGS.Order) do
		total += SETTINGS.Chances[petId] or 0
	end
	for index, petId in ipairs(SETTINGS.Order) do
		local entry = PetCatalog.ById[petId]
		local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity] or 1]
		local holder = card(right, UDim2.new((index - 1) / 5, 3, 0, 184), UDim2.new(1 / 5, -6, 1, -184))
		UiStyle.stroke(holder, 3, rarity.Color, true)
		local name = label(holder, "???", 15, WHITE, UDim2.new(0, 4, 0, 126), UDim2.new(1, -8, 0, 36))
		name.TextWrapped = true
		label(holder, TextFormat.upper(rarity.Name), 15, UiStyle.lighter(rarity.Color, 0.3), UDim2.new(0, 4, 0, 162), UDim2.new(1, -8, 0, 20))
		local chance = (SETTINGS.Chances[petId] or 0) / math.max(total, 1) * 100
		local chanceText = UiStyle.number(holder, (string.gsub(string.format("%g %%", chance), "%.", ",")), 22, WHITE)
		chanceText.Position = UDim2.new(0, 4, 0, 186)
		chanceText.Size = UDim2.new(1, -8, 0, 26)
		table.insert(cards, { petId = petId, holder = holder, name = name })
	end

	local function refreshPets()
		local claimed = MenuKit.claimed()
		for _, entry in ipairs(cards) do
			local known = MenuKit.discovered(entry.petId, claimed)
			if entry.known == known and entry.viewport then
				continue
			end
			entry.known = known
			if entry.viewport then
				entry.viewport:Destroy()
			end
			local viewport = MenuKit.petViewport(entry.holder, entry.petId, not known)
			viewport.Position = UDim2.fromOffset(4, 6)
			viewport.Size = UDim2.new(1, -8, 0, 118)
			entry.viewport = viewport
			entry.name.Text = if known then TextFormat.upper(PetCatalog.ById[entry.petId].Name) else "???"
		end
	end

	local function refresh()
		local candy = MenuKit.number("Candy")
		local enough = candy >= SETTINGS.EggPrice
		owned.Text = string.format("TU AS %d BONBONS", candy)
		buyCaption.Text = string.format("OUVRIR : %d 🍬", SETTINGS.EggPrice)
		UiStyle.setButtonColor(buyButton, if enough then UiStyle.Colors.Green else GREY)
		ends.Text = timeLeft()
		if window.isOpen() then
			refreshPets()
		end
	end

	buyButton.Activated:Connect(function()
		if not Halloween.Active(Halloween.Now()) then
			Sounds.play("Error")
			Toast.show("HALLOWEEN EST FINI !", UiStyle.Colors.Red)
			return
		end
		local missing = SETTINGS.EggPrice - MenuKit.number("Candy")
		if missing > 0 then
			Sounds.play("Error")
			Toast.show(string.format("IL TE MANQUE %d BONBONS !", missing), UiStyle.Colors.Red)
			return
		end
		Remotes.Halloween:FireServer("Buy")
		window.close() -- l'œuf s'ouvre en bas de l'écran puis tombe dans la couveuse (client/PullReveal)
	end)
	Remotes.Halloween.OnClientEvent:Connect(function(kind: string)
		if kind == "NoCandy" then
			Sounds.play("Error")
			Toast.show("PAS ASSEZ DE BONBONS !", UiStyle.Colors.Red)
		end
	end)

	window.onOpen(refresh)
	player:GetAttributeChangedSignal("Candy"):Connect(refresh)
	player:GetAttributeChangedSignal("IndexClaimed"):Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(30)
			if window.isOpen() then
				ends.Text = timeLeft()
			end
		end
	end)
	refresh()
	return { window = window, refresh = refresh }
end

return HalloweenMenu
