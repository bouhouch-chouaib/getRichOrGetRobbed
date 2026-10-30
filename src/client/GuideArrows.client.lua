--!strict
-- GuideArrows : après le tutoriel, on guide le joueur au bon moment, sans qu'il ait à lire beaucoup
-- (dataset_and_pipeline/UI_UX_GUIDELINES.md §7).
--
-- 30 oct. : paliers (« milestones »). Quand le joueur atteint un palier (assez d'argent pour le banc, premier œuf,
-- premier familier, assez pour une batte, un monde, un Rebirth...), on montre UNE fois (champ sauvegardé `guides`,
-- attribut GuidesSeen, Remotes.GuideSeen) :
--   1. une carte : une icône et une phrase, POPUP_TIME secondes (ou jusqu'au bouton OK) ;
--   2. une traînée de flèches dorées au sol + un rayon (Beam) entre le joueur et l'endroit exact, jusqu'à ce qu'il y
--      arrive (ARRIVED studs) ou ARROW_TIME secondes au plus. Les paliers sans endroit (équiper, monde, Rebirth) n'ont
--      que la carte.
-- Entre deux paliers, les anciennes indications restent, tant que leur condition tient (rien de sauvegardé) :
--   - ACHÈTE TON TAPIS DE COURSE : il peut payer le premier tapis et ne l'a pas ;
--   - LA CAPSULE : il débute (moins de MAX_PULLS tirages), il a un œuf dans la couveuse et sa capsule est vide
--     (CAPSULE_TIME secondes au plus par partie).
-- Rien pendant le tutoriel ni quand une fenêtre est ouverte.

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local UiStyle = require(script.Parent.UiStyle)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 220, 60)
local MAX_PULLS = 100
local CAPSULE_TIME = 25
local ARRIVED = 10
local POPUP_TIME = 8 -- secondes de la carte d'un palier (un jeune joueur doit avoir le temps de la lire)
local ARROW_TIME = 60 -- secondes au plus de la traînée de flèches d'un palier
local CHECK_EVERY = 0.5 -- secondes entre deux vérifications des paliers
local CHEVRONS = 12 -- flèches au sol, tous les CHEVRON_GAP studs à partir du joueur
local CHEVRON_GAP = 4

local shopItems: { [string]: Config.ShopItem } = {}
for _, item in ipairs(Config.Shop) do
	shopItems[item.Id] = item
end

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function upgradePrice(id: string): number?
	local item = shopItems[id]
	return if item then Config.GetUpgradePrice(item, number("Upgrade_" .. id)) else nil
end

----------------------------------------------------------------------
-- Bandeau en bas de l'écran (anciennes indications) : une image et une phrase courte
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "GuideArrows"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(gui)

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 1)
banner.Position = UDim2.new(0.5, 0, 1, -(ScreenScale.BOTTOM_RESERVED + 140))
banner.Size = UDim2.fromOffset(560, 76)
banner.BackgroundColor3 = Color3.new(1, 1, 1)
banner.Parent = root
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 16)
	round.Parent = banner
	local border = Instance.new("UIStroke")
	border.Thickness = 4
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = banner
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(240, 110, 20))
	shade.Rotation = 90
	shade.Parent = banner
end
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
local bannerIcon = Icons.image(banner, "Egg", UDim2.fromOffset(64, 64))
bannerIcon.AnchorPoint = Vector2.new(0, 0.5)
bannerIcon.Position = UDim2.new(0, 10, 0.5, -2)
bannerIcon.Rotation = -8
local bannerText = Instance.new("TextLabel")
bannerText.BackgroundTransparency = 1
bannerText.Position = UDim2.fromOffset(84, 8)
bannerText.Size = UDim2.new(1, -96, 1, -16)
bannerText.FontFace = Typography.Face
bannerText.TextColor3 = Color3.new(1, 1, 1)
bannerText.TextXAlignment = Enum.TextXAlignment.Left
bannerText.TextWrapped = true
bannerText.TextSize = 26
Typography.Fit(bannerText, 26, 14)
do
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Parent = bannerText
end
bannerText.Parent = banner

----------------------------------------------------------------------
-- Carte d'un palier : icône + une phrase + OK (POPUP_TIME secondes, jauge qui se vide)
----------------------------------------------------------------------

local popupGui = Instance.new("ScreenGui")
popupGui.Name = "GuidePopup"
popupGui.ResetOnSpawn = false
popupGui.DisplayOrder = 12
popupGui.Enabled = false
popupGui.Parent = player:WaitForChild("PlayerGui")
local popupRoot = ScreenScale.attach(popupGui)

local popup = Instance.new("Frame")
popup.Name = "Popup"
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.fromScale(0.5, 0.27)
popup.Size = UDim2.fromOffset(640, 126)
popup.BackgroundColor3 = Color3.new(1, 1, 1)
popup.Parent = popupRoot
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 18)
	round.Parent = popup
	local border = Instance.new("UIStroke")
	border.Thickness = 5
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = popup
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(120, 70, 230), Color3.fromRGB(70, 36, 160))
	shade.Rotation = 90
	shade.Parent = popup
end
local popupScale = Instance.new("UIScale")
popupScale.Parent = popup
local popupIcon = Icons.image(popup, "Egg", UDim2.fromOffset(92, 92))
popupIcon.AnchorPoint = Vector2.new(0, 0.5)
popupIcon.Position = UDim2.new(0, 12, 0.5, -4)
popupIcon.Rotation = -8
local popupText = Instance.new("TextLabel")
popupText.BackgroundTransparency = 1
popupText.Position = UDim2.fromOffset(116, 10)
popupText.Size = UDim2.new(1, -250, 1, -30)
popupText.FontFace = Typography.Face
popupText.TextColor3 = Color3.new(1, 1, 1)
popupText.TextXAlignment = Enum.TextXAlignment.Left
popupText.TextWrapped = true
popupText.TextSize = 28
Typography.Fit(popupText, 28, 14)
do
	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Parent = popupText
end
popupText.Parent = popup
local okButton = UiStyle.button(popup, "OK", UDim2.fromOffset(104, 62), UiStyle.Colors.Green, 30)
okButton.AnchorPoint = Vector2.new(1, 0.5)
okButton.Position = UDim2.new(1, -14, 0.5, -4)
-- Jauge du temps qui reste, en bas de la carte.
local timer = Instance.new("Frame")
timer.AnchorPoint = Vector2.new(0, 1)
timer.Position = UDim2.new(0, 18, 1, -8)
timer.Size = UDim2.new(1, -36, 0, 6)
timer.BackgroundColor3 = GOLD
timer.BorderSizePixel = 0
timer.Parent = popup
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = timer
end

local popupUntil = 0
local function closePopup()
	popupUntil = 0
	popupGui.Enabled = false
end
okButton.Activated:Connect(function()
	Sounds.play("UiClick")
	closePopup()
end)

local function showPopup(text: string, icon: string)
	popupText.Text = text
	popupIcon.Image = Icons.id(icon) or ""
	popupUntil = os.clock() + POPUP_TIME
	popupGui.Enabled = true
	popupScale.Scale = 0.5
	TweenService:Create(popupScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	timer.Size = UDim2.new(1, -36, 0, 6)
	TweenService:Create(timer, TweenInfo.new(POPUP_TIME, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 6) }):Play()
	Sounds.play("Score")
end

----------------------------------------------------------------------
-- Flèche au-dessus de la cible + rayon doré depuis le joueur + traînée de flèches au sol
----------------------------------------------------------------------

local target = Instance.new("Attachment")
target.Name = "GuideTarget"
target.Parent = Workspace.Terrain
local marker = Instance.new("BillboardGui")
marker.Name = "GuideArrow"
marker.Size = UDim2.fromOffset(80, 80)
marker.AlwaysOnTop = true
marker.LightInfluence = 0
marker.Adornee = target
marker.Enabled = false
marker.Parent = target
do
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.FontFace = Typography.Face
	arrow.TextScaled = true
	arrow.TextColor3 = GOLD
	arrow.Text = "⬇"
	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Parent = arrow
	arrow.Parent = marker
end
local beam = Instance.new("Beam")
beam.Name = "GuideBeam"
beam.Color = ColorSequence.new(GOLD)
beam.Transparency = NumberSequence.new(0.35)
beam.Width0, beam.Width1 = 0.5, 0.5
beam.FaceCamera = true
beam.LightEmission = 1
beam.Segments = 1
beam.Attachment1 = target
beam.Enabled = false
beam.Parent = Workspace.Terrain
local playerPoint: Attachment? = nil

-- Traînée au sol : des chevrons « > » dorés (deux barres chacun) qui avancent vers la cible. Pièces locales sous la
-- caméra (seul ce joueur les voit), sans collision.
local trail = Instance.new("Model")
trail.Name = "GuideTrail"
type Chevron = { left: Part, right: Part }
local chevrons: { Chevron } = {}
local function bar(): Part
	local part = Instance.new("Part")
	part.Name = "GuideChevron"
	part.Size = Vector3.new(0.45, 0.12, 1.7)
	part.Color = GOLD
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.CastShadow = false
	part.Parent = trail
	return part
end
for _ = 1, CHEVRONS do
	table.insert(chevrons, { left = bar(), right = bar() })
end
trail.Parent = Workspace.CurrentCamera

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hideTrail()
	for _, chevron in ipairs(chevrons) do
		chevron.left.Transparency, chevron.right.Transparency = 1, 1
	end
end

-- Pose les chevrons entre le pied du joueur et la cible (vue de haut), au ras du sol, en mouvement vers la cible.
local function drawTrail(rootPart: BasePart, goal: Vector3)
	local from = rootPart.Position
	local flat = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
	local distance = flat.Magnitude
	if distance < 1 then
		hideTrail()
		return
	end
	local dir = flat / distance
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local character = player.Character
	rayParams.FilterDescendantsInstances = if character then { character, trail } else { trail }
	local shift = (os.clock() * 6) % CHEVRON_GAP
	for index, chevron in ipairs(chevrons) do
		local along = 3 + (index - 1) * CHEVRON_GAP + shift
		if along > distance - 2 then
			chevron.left.Transparency, chevron.right.Transparency = 1, 1
			continue
		end
		local point = from + dir * along
		local hit = Workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), rayParams)
		local y = if hit then hit.Position.Y + 0.12 else from.Y - 2.9
		local tip = Vector3.new(point.X, y, point.Z)
		-- Plus pâle au début et au bout de la traînée.
		local fade = math.max(0.15, 1 - math.min(along / 8, 1, (CHEVRONS * CHEVRON_GAP - along) / 8))
		for _, arm in ipairs({ { part = chevron.left, sign = 1 }, { part = chevron.right, sign = -1 } }) do
			local armDir = (-dir + side * arm.sign).Unit
			local center = tip + armDir * 0.75
			arm.part.CFrame = CFrame.lookAt(center, center + armDir)
			arm.part.Transparency = fade
		end
	end
end

----------------------------------------------------------------------
-- Où aller
----------------------------------------------------------------------

local function myBase(): Instance?
	local map = Workspace:FindFirstChild("Map")
	local index = player:GetAttribute("BaseIndex")
	return if map and type(index) == "number" then map:FindFirstChild("Base_" .. index) else nil
end

local function zoneOf(base: Instance, station: string): Vector3?
	local model = base:FindFirstChild(station)
	local zone = model and model:FindFirstChild("Zone")
	return if zone and zone:IsA("BasePart") then zone.Position + Vector3.new(0, 7, 0) else nil
end

local function machineOf(base: Instance): BasePart?
	local capsule = base:FindFirstChild("EvolutionCapsule")
	local machine = capsule and capsule:FindFirstChild("EvolutionMachine")
	return if machine and machine:IsA("BasePart") then machine else nil
end

local function incubatorOf(base: Instance): Vector3?
	local incubator = base:FindFirstChild("Incubator")
	local sign = incubator and incubator:FindFirstChild("IncubatorSign")
	return if sign and sign:IsA("BasePart") then sign.Position + Vector3.new(0, 4, 0) else nil
end

-- La boutique la plus proche (kiosques entre les bases, server/MapGenerator).
local function nearestShop(from: Vector3): Vector3?
	local map = Workspace:FindFirstChild("Map")
	local kiosks = map and map:FindFirstChild("Kiosks")
	local best: Vector3? = nil
	for _, kiosk in ipairs(if kiosks then kiosks:GetChildren() else {}) do
		local shop = kiosk:FindFirstChild("Shop")
		if shop and shop:IsA("Model") then
			local position = shop:GetPivot().Position + Vector3.new(0, 9, 0)
			if not best or (position - from).Magnitude < (best - from).Magnitude then
				best = position
			end
		end
	end
	return best
end

local function hasPet(): boolean
	for name, value in pairs(player:GetAttributes()) do
		if string.sub(name, 1, 4) == "Pet_" and type(value) == "number" and value > 0 then
			return true
		end
	end
	return false
end

type Guide = { id: string, text: string, icon: string, position: Vector3? }
type Milestone = { id: string, text: string, icon: string, check: (base: Instance) -> boolean, place: ((base: Instance) -> Vector3?)? }

local function canPay(price: number?): boolean
	return price ~= nil and number("Money") >= price
end

-- Les paliers, dans l'ordre où on les montre (un à la fois). id : lettres seulement (gardé dans la sauvegarde).
local MILESTONES: { Milestone } = {
	{
		id = "Treadmill", icon = "Treadmill", text = "ACHÈTE TON TAPIS DE COURSE : TU IRAS PLUS VITE !",
		check = function()
			return number("Upgrade_Treadmill") == 0 and canPay(upgradePrice("Treadmill"))
		end,
		place = function(base)
			return zoneOf(base, "Treadmill")
		end,
	},
	{
		id = "Bench", icon = "Bench", text = "ACHÈTE TON BANC DE MUSCU : TU LANCERAS PLUS LOIN !",
		check = function()
			return number("Upgrade_Bench") == 0 and number("Upgrade_Treadmill") > 0 and canPay(upgradePrice("Bench"))
		end,
		place = function(base)
			return zoneOf(base, "Bench")
		end,
	},
	{
		id = "Incubator", icon = "Egg",
		text = string.format("TES ŒUFS CHAUFFENT DANS LA COUVEUSE : %d À LA FOIS !", Config.Eggs.Slots),
		check = function()
			return number("EggCount") > 0
		end,
		place = incubatorOf,
	},
	{
		id = "Equip", icon = "Index", text = "OUVRE L'INDEX ET APPUIE SUR ÉQUIPER : TON FAMILIER TE SUIT ET TE REND PLUS FORT !",
		check = function()
			local equipped = player:GetAttribute("Equipped")
			return (equipped == nil or equipped == "") and hasPet()
		end,
	},
	{
		id = "Capsule", icon = "Egg", text = "METS UN ŒUF DANS LA CAPSULE : IL PEUT DEVENIR ÉVOLUÉ OU ULTIME !",
		check = function(base)
			local machine = machineOf(base)
			local used = machine and machine:GetAttribute("ChambersUsed")
			return machine ~= nil and machine:GetAttribute("OwnerUserId") == player.UserId and not (type(used) == "number" and used > 0)
				and number("EggCount") > 0 and number("TotalPulls") >= 3
		end,
		place = function(base)
			local machine = machineOf(base)
			return if machine then machine.Position + Vector3.new(0, 8, 0) else nil
		end,
	},
	{
		id = "Upgrade", icon = "Treadmill", text = "AMÉLIORE TON TAPIS ET TON BANC : PLEIN DE PETITS NIVEAUX !",
		check = function()
			return number("Upgrade_Treadmill") > 0 and number("Upgrade_Bench") > 0
				and canPay(upgradePrice("Treadmill")) and canPay(upgradePrice("Bench"))
		end,
		place = function(base)
			return zoneOf(base, "Treadmill")
		end,
	},
	{
		id = "Combat", icon = "Bat", text = "ACHÈTE UNE BATTE À LA BOUTIQUE : FRAPPE LES VOLEURS !",
		check = function()
			return number("Upgrade_WeaponBat") == 0 and canPay(upgradePrice("WeaponBat"))
		end,
		place = function()
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			return if rootPart and rootPart:IsA("BasePart") then nearestShop(rootPart.Position) else nil
		end,
	},
	{
		id = "EggSlots", icon = "Egg", text = "ACHÈTE UNE PLACE DE COUVEUSE : PLUS D'ŒUFS EN MÊME TEMPS !",
		check = function(base)
			local folder = base:FindFirstChild("Eggs")
			local waiting = folder and folder:GetAttribute("Waiting")
			return type(waiting) == "number" and waiting > 0 and canPay(upgradePrice("EggSlots"))
		end,
		place = function()
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			return if rootPart and rootPart:IsA("BasePart") then nearestShop(rootPart.Position) else nil
		end,
	},
	{
		id = "World", icon = "Planet", text = "UN NOUVEAU MONDE T'ATTEND : OUVRE LE MENU MONDES !",
		check = function()
			local nextWorld = Config.Worlds[math.max(1, number("Tier")) + 1]
			return nextWorld ~= nil and number("Rebirths") >= Config.GetWorldRebirths(nextWorld) and canPay(nextWorld.Price)
		end,
	},
	{
		id = "Rebirth", icon = "Rebirth", text = "TU PEUX FAIRE UN REBIRTH : ARGENT x2 ET ENTRAÎNEMENT x1,5 POUR TOUJOURS !",
		check = function()
			return number("Rebirths") == 0 and number("Tier") >= Config.Rebirth.RequiredTier
				and canPay(Config.GetRebirthPrice(0))
		end,
	},
}

local function seen(id: string): boolean
	local list = player:GetAttribute("GuidesSeen")
	return type(list) == "string" and table.find(string.split(list, ","), id) ~= nil
end

-- Palier en cours : sa carte, puis sa traînée jusqu'à l'arrivée.
type Active = { milestone: Milestone, since: number, done: boolean }
local active: Active? = nil
local shownLocally: { [string]: boolean } = {} -- en attendant que le serveur l'ait noté

local function nextMilestone(base: Instance): Milestone?
	for _, milestone in ipairs(MILESTONES) do
		if not shownLocally[milestone.id] and not seen(milestone.id) and milestone.check(base) then
			return milestone
		end
	end
	return nil
end

-- Anciennes indications (sans sauvegarde) : le premier tapis, la capsule d'un débutant.
local capsuleShown = 0 -- secondes déjà montrées pendant cette partie

local function treadmillGuide(base: Instance): Guide?
	if number("Upgrade_Treadmill") > 0 or not canPay(upgradePrice("Treadmill")) then
		return nil
	end
	local position = zoneOf(base, "Treadmill")
	return if position then { id = "Treadmill", text = "ACHÈTE TON TAPIS DE COURSE : TU IRAS PLUS VITE !", icon = "Treadmill",
		position = position } else nil
end

local function capsuleGuide(base: Instance): Guide?
	if capsuleShown >= CAPSULE_TIME or number("TotalPulls") >= MAX_PULLS then
		return nil
	end
	local machine = machineOf(base)
	if not machine or machine:GetAttribute("OwnerUserId") ~= player.UserId then
		return nil
	end
	local used = machine:GetAttribute("ChambersUsed")
	if type(used) == "number" and used > 0 then
		return nil
	end
	local folder = base:FindFirstChild("Eggs")
	local now = Workspace:GetServerTimeNow()
	local hasEgg = false
	for _, anchor in ipairs(if folder then folder:GetChildren() else {}) do
		local readyAt = anchor:GetAttribute("ReadyAt")
		if type(readyAt) == "number" and readyAt > now + 20 and anchor:GetAttribute("Leaving") ~= true then
			hasEgg = true
			break
		end
	end
	if not hasEgg then
		return nil
	end
	return { id = "Capsule", text = "METS UN ŒUF DANS LA CAPSULE : IL DEVIENT PLUS FORT !", icon = "Egg",
		position = machine.Position + Vector3.new(0, 8, 0) }
end

----------------------------------------------------------------------
-- Chaque image
----------------------------------------------------------------------

local shownId: string? = nil

local function hideArrows()
	marker.Enabled = false
	beam.Enabled = false
	hideTrail()
end

local function hide()
	gui.Enabled = false
	hideArrows()
	shownId = nil
end

local lastCheck = 0

RunService.RenderStepped:Connect(function(dt: number)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local base = myBase()
	if os.clock() > popupUntil and popupGui.Enabled then
		closePopup()
	end
	-- Pendant le tutoriel (il a ses propres flèches) ou une fenêtre ouverte : rien.
	if player:GetAttribute("TutorialDone") ~= true or player:GetAttribute("DataLoaded") ~= true or MenuKit.anyOpen()
		or not base or not (rootPart and rootPart:IsA("BasePart")) then
		hide()
		closePopup()
		return
	end

	-- 1. Un nouveau palier ? (vérifié deux fois par seconde)
	local clock = os.clock()
	if not active and clock - lastCheck >= CHECK_EVERY then
		lastCheck = clock
		local milestone = nextMilestone(base)
		if milestone then
			active = { milestone = milestone, since = clock, done = false }
			shownLocally[milestone.id] = true
			Remotes.GuideSeen:FireServer(milestone.id)
			showPopup(milestone.text, milestone.icon)
		end
	end

	-- 2. Où montrer : le palier en cours (sa traînée), sinon les anciennes indications.
	local guide: Guide? = nil
	local current = active
	if current then
		local place = current.milestone.place
		local position = if place then place(base) else nil
		local arrived = position ~= nil and (rootPart.Position - position).Magnitude < ARRIVED
		if arrived or clock - current.since > ARROW_TIME or (position == nil and clock > popupUntil) then
			active = nil
		elseif position then
			guide = { id = current.milestone.id, text = current.milestone.text, icon = current.milestone.icon, position = position }
		end
	end
	local fromMilestone = guide ~= nil
	if not guide and not active then -- pendant un palier sans endroit (équiper, monde...), pas d'autre flèche
		guide = treadmillGuide(base) or capsuleGuide(base)
	end
	local position = guide and guide.position
	if not guide or not position or (rootPart.Position - position).Magnitude < ARRIVED then
		hide()
		return
	end
	if guide.id == "Capsule" and not fromMilestone then
		capsuleShown += dt
	end
	if not playerPoint or playerPoint.Parent ~= rootPart then
		if playerPoint then
			playerPoint:Destroy()
		end
		local point = Instance.new("Attachment")
		point.Name = "GuideFrom"
		point.Parent = rootPart
		playerPoint = point
		beam.Attachment0 = point
	end
	-- Le bandeau du bas seulement quand la carte du palier n'est plus là (pas deux fois la même phrase).
	local showBanner = not popupGui.Enabled
	if showBanner and shownId ~= guide.id then
		-- Nouvelle indication : le bandeau arrive en grossissant, avec un petit son.
		shownId = guide.id
		bannerText.Text = guide.text
		bannerIcon.Image = Icons.id(guide.icon) or ""
		bannerScale.Scale = 0.7
		TweenService:Create(bannerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if not fromMilestone then
			Sounds.play("Score")
		end
	end
	gui.Enabled = showBanner
	target.WorldPosition = position + Vector3.new(0, 1 + math.sin(os.clock() * 4) * 0.6, 0)
	marker.Enabled = true
	beam.Enabled = true
	drawTrail(rootPart, position)
end)
