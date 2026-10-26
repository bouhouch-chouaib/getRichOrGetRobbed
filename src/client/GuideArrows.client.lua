--!strict
-- GuideArrows : après le tutoriel, la même flèche dorée (et son rayon) montre où aller quand un nouveau joueur pourrait
-- rater quelque chose d'important, sans qu'il ait à lire (dataset_and_pipeline/UI_UX_GUIDELINES.md §7) :
--   1. ACHÈTE TON TAPIS DE COURSE : il peut payer le premier tapis et ne l'a pas -> flèche sur le panneau d'achat du tapis
--      de sa base (client/UpgradeSigns) ;
--   2. LA CAPSULE : il débute (moins de MAX_PULLS tirages), il a un œuf dans la couveuse et sa capsule est vide -> flèche
--      sur la capsule, CAPSULE_TIME secondes au plus par partie (certains préfèrent laisser éclore leurs œufs).
-- Rien n'est sauvegardé : ce sont les conditions (tapis acheté, capsule utilisée, expérience) qui arrêtent les flèches.
-- Rien pendant le tutoriel, quand une fenêtre est ouverte, ni une fois arrivé (à moins de ARRIVED studs).

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 220, 60)
local MAX_PULLS = 100
local CAPSULE_TIME = 25
local ARRIVED = 10

local treadmillItem: Config.ShopItem? = nil
for _, item in ipairs(Config.Shop) do
	if item.Id == "Treadmill" then
		treadmillItem = item
	end
end

----------------------------------------------------------------------
-- Bandeau en bas de l'écran : une image et une phrase courte
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
-- Flèche au-dessus de la cible + rayon doré depuis le joueur (comme le tutoriel)
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

----------------------------------------------------------------------
-- Où aller
----------------------------------------------------------------------

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function myBase(): Instance?
	local map = Workspace:FindFirstChild("Map")
	local index = player:GetAttribute("BaseIndex")
	return if map and type(index) == "number" then map:FindFirstChild("Base_" .. index) else nil
end

type Guide = { id: string, text: string, icon: string, position: Vector3 }

-- Le premier tapis : on peut le payer et on ne l'a pas.
local function treadmillGuide(base: Instance): Guide?
	local item = treadmillItem
	if not item or number("Upgrade_Treadmill") > 0 then
		return nil
	end
	local price = Config.GetUpgradePrice(item, 0)
	if not price or number("Money") < price then
		return nil
	end
	local model = base:FindFirstChild("Treadmill")
	local sign = model and model:FindFirstChild("UpgradeSign")
	local board = sign and sign:FindFirstChild("Board")
	if not (board and board:IsA("BasePart")) then
		return nil
	end
	return { id = "Treadmill", text = "ACHÈTE TON TAPIS DE COURSE : TU IRAS PLUS VITE !", icon = "Treadmill",
		position = board.Position + Vector3.new(0, 4, 0) }
end

local capsuleShown = 0 -- secondes déjà montrées pendant cette partie

-- La capsule : un débutant a un œuf dans la couveuse et sa capsule est vide.
local function capsuleGuide(base: Instance): Guide?
	if capsuleShown >= CAPSULE_TIME or number("TotalPulls") >= MAX_PULLS then
		return nil
	end
	local capsule = base:FindFirstChild("EvolutionCapsule")
	local machine = capsule and capsule:FindFirstChild("EvolutionMachine")
	if not (machine and machine:IsA("BasePart")) or machine:GetAttribute("OwnerUserId") ~= player.UserId then
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

local function hide()
	gui.Enabled = false
	marker.Enabled = false
	beam.Enabled = false
	shownId = nil
end

RunService.RenderStepped:Connect(function(dt: number)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local base = myBase()
	-- Pendant le tutoriel (il a ses propres flèches) ou une fenêtre ouverte : rien.
	if player:GetAttribute("TutorialDone") ~= true or MenuKit.anyOpen() or not base
		or not (rootPart and rootPart:IsA("BasePart")) then
		hide()
		return
	end
	local guide = treadmillGuide(base) or capsuleGuide(base)
	if not guide or (rootPart.Position - guide.position).Magnitude < ARRIVED then
		hide()
		return
	end
	if guide.id == "Capsule" then
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
	if shownId ~= guide.id then
		-- Nouvelle indication : le bandeau arrive en grossissant, avec un petit son.
		shownId = guide.id
		bannerText.Text = guide.text
		bannerIcon.Image = Icons.id(guide.icon) or ""
		bannerScale.Scale = 0.7
		TweenService:Create(bannerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Sounds.play("Score")
	end
	gui.Enabled = true
	target.WorldPosition = guide.position + Vector3.new(0, 1 + math.sin(os.clock() * 4) * 0.6, 0)
	marker.Enabled = true
	beam.Enabled = true
end)
