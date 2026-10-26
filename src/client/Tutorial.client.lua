--!strict
-- Tutoriel : 4 étapes guidées pour un nouveau joueur (affiché une seule fois : attribut "TutorialDone",
-- enregistré dans la sauvegarde via Remotes.TutorialDone). Avant la 1re étape, un écran « DEVIENS LE PLUS RICHE ! »
-- montre le but du jeu en 4 images (bouton JOUER).
--   1. Ramasser un objet       -> flèche sur l'objet le plus proche
--   2. Le lancer dans le trou  -> flèche sur le trou noir (ou sur un objet si on n'en tient plus)
--   3. Recevoir un œuf         -> retour vers la base
--   4. Voir son éclosion       -> flèche sur son œuf, jusqu’au vrai familier
-- Guidage : panneau en bas de l'écran (grosse image de l'étape + phrase courte), gros "⬇" au-dessus de la cible,
-- rayon doré entre le joueur et la cible.
-- Bouton PASSER pour ceux qui connaissent déjà le jeu.

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BaseLayout = require(ReplicatedStorage.Shared.BaseLayout)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 220, 60)
local TOUCH = ScreenScale.isTouch()

-- 26 oct. (UI_UX_GUIDELINES.md §7) : une grosse image par étape et des phrases courtes en MAJUSCULES (les premières
-- lettres qu'apprennent les enfants) ; la flèche et le rayon doré montrent où aller, sans avoir à lire.
type Step = { title: string, hint: string, icon: string }
local STEPS: { Step } = {
	{
		title = "RAMASSE UN OBJET",
		hint = if TOUCH then "VA PRÈS D'UN OBJET ET TOUCHE RAMASSER" else "VA PRÈS D'UN OBJET ET APPUIE SUR E",
		icon = "Gem",
	},
	{
		title = "JETTE-LE DANS LE TROU NOIR !",
		hint = if TOUCH then "SUIS LA FLÈCHE. MAINTIENS LANCER, PUIS LÂCHE" else "SUIS LA FLÈCHE. MAINTIENS LE CLIC, PUIS LÂCHE",
		icon = "Vortex",
	},
	{
		title = "TU VAS GAGNER UN ŒUF !",
		hint = "RETOURNE DANS TA BASE",
		icon = "Egg",
	},
	{
		title = "TON ŒUF VA ÉCLORE",
		hint = "SUIS LA FLÈCHE ET ATTENDS",
		icon = "Paw",
	},
}

----------------------------------------------------------------------
-- Interface : panneau en bas de l'écran
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(gui)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 1)
-- Au-dessus des boutons d'action et des capsules de tirage (client/PullReveal).
panel.Position = UDim2.new(0.5, 0, 1, -(ScreenScale.BOTTOM_RESERVED + 140))
panel.Size = UDim2.fromOffset(720, 100)
panel.BackgroundColor3 = Color3.new(1, 1, 1)
panel.Parent = root
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 16)
	round.Parent = panel
	local border = Instance.new("UIStroke")
	border.Thickness = 4
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = panel
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(240, 110, 20))
	shade.Rotation = 90
	shade.Parent = panel
end
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

-- Grosse image de l'étape à gauche (ce qu'il faut faire, sans lire), avec son numéro « 1/4 » dans un rond.
local ICON_SIZE = 84
local stepIcon = Icons.image(panel, "Gem", UDim2.fromOffset(ICON_SIZE, ICON_SIZE))
stepIcon.AnchorPoint = Vector2.new(0, 0.5)
stepIcon.Position = UDim2.new(0, 10, 0.5, -4)
stepIcon.Rotation = -8
stepIcon.ZIndex = 3
local stepNumber = Instance.new("TextLabel")
stepNumber.Name = "StepNumber"
stepNumber.AnchorPoint = Vector2.new(0.5, 0.5)
stepNumber.Position = UDim2.fromOffset(16, 12)
stepNumber.Size = UDim2.fromOffset(40, 28)
stepNumber.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
stepNumber.FontFace = Typography.Face
stepNumber.TextColor3 = Color3.new(1, 1, 1)
stepNumber.TextScaled = true
stepNumber.ZIndex = 4
stepNumber.Parent = panel
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = stepNumber
	local border = Instance.new("UIStroke")
	border.Thickness = 2
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = stepNumber
end
local TEXT_LEFT = ICON_SIZE + 22

local function label(font: Font, size: number, y: number, height: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(TEXT_LEFT, y)
	text.Size = UDim2.new(1, -TEXT_LEFT - 124, 0, height)
	text.FontFace = font
	text.TextSize = size
	Typography.Fit(text, size, 14)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	local outline = Instance.new("UIStroke")
	outline.Thickness = math.max(1.5, size / 12)
	outline.Parent = text
	text.Parent = panel
	return text
end
local titleLabel = label(Typography.Face, 30, 8, 36)
local hintLabel = label(Typography.Face, 20, 48, 34)

local function setIcon(name: string)
	stepIcon.Image = Icons.id(name) or ""
end

local skipButton = Instance.new("TextButton")
skipButton.Name = "Skip"
skipButton.AnchorPoint = Vector2.new(1, 0.5)
skipButton.Position = UDim2.new(1, -12, 0.5, 0)
skipButton.Size = UDim2.fromOffset(100, 40)
skipButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
skipButton.FontFace = Typography.Face
skipButton.TextSize = 18
Typography.Fit(skipButton, 18)
skipButton.TextColor3 = Color3.new(1, 1, 1)
skipButton.Text = "PASSER"
skipButton.Parent = panel
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 10)
	round.Parent = skipButton
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = skipButton
end

----------------------------------------------------------------------
-- Guidage dans le monde : "⬇" au-dessus de la cible + rayon doré depuis le joueur
----------------------------------------------------------------------

local target = Instance.new("Attachment")
target.Name = "TutorialTarget"
target.Parent = Workspace.Terrain

local marker = Instance.new("BillboardGui")
marker.Name = "TutorialArrow"
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
beam.Name = "TutorialBeam"
beam.Color = ColorSequence.new(GOLD)
beam.Transparency = NumberSequence.new(0.35)
beam.Width0 = 0.5
beam.Width1 = 0.5
beam.FaceCamera = true
beam.LightEmission = 1
beam.Segments = 1
beam.Attachment1 = target
beam.Enabled = false
beam.Parent = Workspace.Terrain

local playerPoint: Attachment? = nil

----------------------------------------------------------------------
-- Cibles
----------------------------------------------------------------------

local HOLE = Vector3.new(0, 6, 0)

local function getRoot(): BasePart?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return if rootPart and rootPart:IsA("BasePart") then rootPart else nil
end

local function myBase(): Model?
	local map = Workspace:FindFirstChild("Map")
	local index = player:GetAttribute("BaseIndex")
	local base = map and index and map:FindFirstChild("Base_" .. tostring(index))
	return if base and base:IsA("Model") then base else nil
end

-- Le joueur tient-il un objet ? (le serveur écrit son nom dans l'attribut "Holder" des objets portés)
local function isHolding(): boolean
	local map = Workspace:FindFirstChild("Map")
	local loose = map and map:FindFirstChild("LooseItems")
	if loose then
		for _, item in ipairs(loose:GetChildren()) do
			if item:GetAttribute("Holder") == player.Name then
				return true
			end
		end
	end
	return false
end

-- L'objet ramassable le plus proche (dans sa base, par terre ou dans l'arène).
local function nearestItem(origin: Vector3): Vector3?
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	local folders: { Instance } = {}
	local base = myBase()
	local spawns = base and base:FindFirstChild("ItemSpawns")
	if spawns then
		table.insert(folders, spawns)
	end
	for _, name in ipairs({ "LooseItems", "WildItems" }) do
		local folder = map:FindFirstChild(name)
		if folder then
			table.insert(folders, folder)
		end
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, folder in ipairs(folders) do
		for _, item in ipairs(folder:GetChildren()) do
			if item:IsA("BasePart") and not item:GetAttribute("Holder") and not item:GetAttribute("Consumed") then
				local distance = (item.Position - origin).Magnitude
				if distance < bestDistance then
					best, bestDistance = item.Position, distance
				end
			end
		end
	end
	return best
end

----------------------------------------------------------------------
-- Déroulement
----------------------------------------------------------------------

local step = 0 -- 0 = tutoriel inactif

local function showStep(index: number)
	step = index
	local info = STEPS[index]
	titleLabel.Text = info.title
	hintLabel.Text = info.hint
	stepNumber.Text = index .. "/" .. #STEPS
	setIcon(info.icon)
	gui.Enabled = true
	panelScale.Scale = 0.7
	TweenService:Create(panelScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if index > 1 then
		Sounds.play("Score")
	end
end

local function stop()
	step = 0
	gui.Enabled = false
	marker.Enabled = false
	beam.Enabled = false
	if playerPoint then
		playerPoint:Destroy()
		playerPoint = nil
	end
end

local function finish(skipped: boolean)
	if step == 0 then
		return
	end
	stop()
	Remotes.TutorialDone:FireServer(skipped)
	if skipped then
		Toast.show("TUTORIEL PASSÉ", Color3.fromRGB(200, 200, 200))
	else
		Sounds.play("LevelUp")
		Toast.show("BRAVO ! OUVRE L’INDEX : UN CADEAU T’ATTEND !", GOLD)
	end
end

skipButton.Activated:Connect(function()
	finish(true)
end)

-- Reprendre les vrais jalons du serveur après reconnexion. Recevoir un œuf
-- ne termine plus le tutoriel : il faut qu'un familier ait réellement éclos.
local finishing = false
local function updateProgress()
	if step == 0 then
		return
	end
	local nextStep = 1
	if player:GetAttribute("Onboarding_Scored") == true then
		if player:GetAttribute("Onboarding_Hatched") == true then
			if not finishing then
				finishing = true
				task.delay(3, function()
					finish(false)
				end) -- laisser voir l'éclosion
			end
			return
		end
		local eggCount = player:GetAttribute("EggCount")
		nextStep = if player:GetAttribute("Onboarding_EggReceived") == true
				or (type(eggCount) == "number" and eggCount > 0)
			then 4
			else 3
	elseif player:GetAttribute("Onboarding_Pickup") == true or isHolding() then
		nextStep = 2
	end
	if nextStep ~= step then
		showStep(nextStep)
	end
end
for _, key in ipairs({ "Pickup", "Scored", "EggReceived", "Hatched" }) do
	player:GetAttributeChangedSignal("Onboarding_" .. key):Connect(updateProgress)
end
player:GetAttributeChangedSignal("EggCount"):Connect(updateProgress)

-- Terminé ailleurs (autre appareil) : on arrête.
player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
	if player:GetAttribute("TutorialDone") == true and step ~= 0 then
		stop()
	end
end)

local function eggGoal(): Vector3?
	local base = myBase()
	local folder = base and base:FindFirstChild("Eggs")
	local eggs: { Instance } = if folder then folder:GetChildren() else {}
	local earliest: BasePart? = nil
	local earliestTime = math.huge
	for _, egg in ipairs(eggs) do
		local readyAt = egg:GetAttribute("ReadyAt")
		if egg:IsA("BasePart") and type(readyAt) == "number" and readyAt < earliestTime then
			earliest, earliestTime = egg, readyAt
		end
	end
	local capsule = base and base:FindFirstChild("EvolutionCapsule")
	local machine = capsule and capsule:FindFirstChild("EvolutionMachine")
	if earliest then
		return earliest.Position + Vector3.new(0, 3, 0)
	elseif machine and machine:IsA("BasePart") and machine:GetAttribute("Occupied") == true then
		return machine.Position + Vector3.new(0, 3, 0)
	else
		local platform = base and base:FindFirstChild("BasePart")
		return if platform and platform:IsA("BasePart")
			then platform.CFrame:PointToWorldSpace(
				Vector3.new(0, platform.Size.Y / 2 + 3, BaseLayout.IncubatorCenter.Y)
			)
			else nil
	end
end

-- Position de la flèche et du rayon à chaque image.
RunService.RenderStepped:Connect(function()
	if step == 0 then
		if gui.Enabled then
			gui.Enabled = false -- réaffiché par erreur ailleurs alors que le tutoriel est fini
		end
		return
	end
	-- Une fenêtre ouverte (Index, Boutique...) : le panneau s'efface pour ne pas la cacher.
	panel.Visible = not MenuKit.anyOpen()
	local rootPart = getRoot()
	if not rootPart then
		marker.Enabled = false
		beam.Enabled = false
		return
	end
	if not playerPoint or playerPoint.Parent ~= rootPart then
		if playerPoint then
			playerPoint:Destroy()
		end
		local point = Instance.new("Attachment")
		point.Name = "TutorialFrom"
		point.Parent = rootPart
		playerPoint = point
		beam.Attachment0 = point
	end

	local digesting = ReplicatedStorage:GetAttribute("GameState") == "Digesting"
	local starterPending = player:GetAttribute("StarterEggGiven") == true
		and player:GetAttribute("StarterBonusPaid") ~= true
	local goal: Vector3? = nil
	if step == 2 and digesting and starterPending then
		goal = eggGoal() -- pendant la fermeture du trou, découvrir sa première récompense
	elseif step == 2 and digesting and player:GetAttribute("StarterBonusPaid") == true then
		goal = nil -- consigne d'achat dans le HUD ; ne pas envoyer le joueur contre le dôme
	elseif step == 1 or (step == 2 and not isHolding()) then
		local item = nearestItem(rootPart.Position)
		goal = if item then item + Vector3.new(0, 2.5, 0) else nil
	elseif step == 2 then
		goal = HOLE
	else
		goal = eggGoal()
	end

	-- Étape 2 pendant la digestion : le trou ne mange pas, on prévient.
	if step == 2 then
		local buyFirst = digesting and player:GetAttribute("StarterBonusPaid") == true
			and player:GetAttribute("Onboarding_Upgraded") ~= true
		titleLabel.Text = if digesting and starterPending then "TON ŒUF CADEAU T’ATTEND !"
			elseif buyFirst then "ACHÈTE UN TAPIS DE COURSE !"
			elseif digesting then "LE TROU NOIR FAIT LA SIESTE"
			else STEPS[2].title
		hintLabel.Text = if digesting and starterPending then "SUIS LA FLÈCHE JUSQU’À TON ŒUF"
			elseif buyFirst then "OUVRE LA BOUTIQUE : LE PANIER À GAUCHE"
			elseif digesting then "ENTRAÎNE-TOI EN ATTENDANT LE REPAS"
			elseif isHolding() then STEPS[2].hint
			else "RAMASSE UN OBJET, PUIS JETTE-LE DANS LE TROU"
		setIcon(if digesting and starterPending then "Egg" elseif buyFirst then "Shop" elseif digesting then "Sun" else STEPS[2].icon)
	end

	if step == 4 then
		local hatchAt = player:GetAttribute("NextHatchAt")
		local countdown = if type(hatchAt) == "number" and hatchAt < math.huge
			then math.max(0, math.ceil(hatchAt - Workspace:GetServerTimeNow()))
			else 0
		hintLabel.Text = if countdown > 0
			then string.format("IL ÉCLOT DANS %d S ! SUIS LA FLÈCHE", countdown)
			elseif hatchAt == math.huge then "IL EST DANS LA CAPSULE : OUVRE-LA QUAND IL EST PRÊT"
			else STEPS[4].hint
	end

	if goal then
		target.WorldPosition = goal + Vector3.new(0, 1 + math.sin(os.clock() * 4) * 0.6, 0)
		marker.Enabled = true
		beam.Enabled = true
	else
		marker.Enabled = false
		beam.Enabled = false
	end
end)

----------------------------------------------------------------------
-- But du jeu : un écran avant la 1re étape (26 oct., retour des testeurs : « on ne comprend pas le but »).
-- 4 grosses images dans l'ordre de la boucle, une phrase courte sous chacune, un seul bouton JOUER.
----------------------------------------------------------------------

type GoalStep = { icon: string, text: string }
local GOAL_STEPS: { GoalStep } = {
	{ icon = "Vortex", text = "JETTE DES OBJETS DANS LE TROU NOIR" },
	{ icon = "Egg", text = "TU GAGNES DES ŒUFS" },
	{ icon = "Money", text = "TES FAMILIERS RAPPORTENT DE L'ARGENT" },
	{ icon = "Glove", text = "VOLE CEUX DES AUTRES\u{00A0}!" }, -- espace insécable : le « ! » ne part pas seul à la ligne
}

local function outlined(parent: Instance, value: string, size: number, minSize: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.FontFace = Typography.Face
	item.TextSize = size
	Typography.Fit(item, size, minSize)
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextWrapped = true
	item.Text = value
	local outline = Instance.new("UIStroke")
	outline.Thickness = math.max(1.5, size / 12)
	outline.Parent = item
	item.Parent = parent
	return item
end

local goalGui = Instance.new("ScreenGui")
goalGui.Name = "GameGoal"
goalGui.ResetOnSpawn = false
goalGui.DisplayOrder = 6
goalGui.Enabled = false
goalGui.Parent = player:WaitForChild("PlayerGui")
local goalRoot = ScreenScale.attach(goalGui)

local dim = Instance.new("Frame")
dim.Name = "Dim"
-- Déborde vers le haut : couvre aussi la bande de la barre Roblox (les ScreenGui commencent en dessous).
dim.Position = UDim2.fromOffset(0, -200)
dim.Size = UDim2.new(1, 0, 1, 200)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.4
dim.BorderSizePixel = 0
dim.Parent = goalRoot

local goalCard = Instance.new("Frame")
goalCard.Name = "Card"
goalCard.AnchorPoint = Vector2.new(0.5, 0.5)
goalCard.Position = UDim2.fromScale(0.5, 0.5)
goalCard.Size = UDim2.fromOffset(920, 440)
goalCard.BackgroundColor3 = Color3.new(1, 1, 1)
goalCard.Parent = goalRoot
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 20)
	round.Parent = goalCard
	local border = Instance.new("UIStroke")
	border.Thickness = 5
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = goalCard
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(240, 110, 20))
	shade.Rotation = 90
	shade.Parent = goalCard
end
local goalScale = Instance.new("UIScale")
goalScale.Parent = goalCard

local goalTitle = outlined(goalCard, "DEVIENS LE PLUS RICHE\u{00A0}!", 48, 28)
goalTitle.AnchorPoint = Vector2.new(0.5, 0)
goalTitle.Position = UDim2.new(0.5, 0, 0, 16)
goalTitle.Size = UDim2.new(1, -40, 0, 60)

local goalRow = Instance.new("Frame")
goalRow.Name = "Steps"
goalRow.BackgroundTransparency = 1
goalRow.AnchorPoint = Vector2.new(0.5, 0)
goalRow.Position = UDim2.new(0.5, 0, 0, 88)
goalRow.Size = UDim2.new(1, -36, 0, 236)
goalRow.Parent = goalCard
do
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = goalRow
end

local goalScales: { UIScale } = {}
for index, info in ipairs(GOAL_STEPS) do
	if index > 1 then
		local arrowLabel = outlined(goalRow, ">", 44, 30)
		arrowLabel.LayoutOrder = index * 2 - 1
		arrowLabel.Size = UDim2.fromOffset(30, 60)
	end
	local cell = Instance.new("Frame")
	cell.Name = "Step" .. index
	cell.LayoutOrder = index * 2
	cell.Size = UDim2.fromOffset(196, 232)
	cell.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
	cell.BackgroundTransparency = 0.15
	cell.Parent = goalRow
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 14)
	round.Parent = cell
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = cell
	local cellScale = Instance.new("UIScale")
	cellScale.Parent = cell
	table.insert(goalScales, cellScale)
	local image = Icons.image(cell, info.icon, UDim2.fromOffset(112, 112))
	image.AnchorPoint = Vector2.new(0.5, 0)
	image.Position = UDim2.new(0.5, 0, 0, 14)
	local number = outlined(cell, tostring(index), 26, 20)
	number.Position = UDim2.fromOffset(8, 4)
	number.Size = UDim2.fromOffset(30, 32)
	number.TextColor3 = GOLD
	local caption = outlined(cell, info.text, 21, 14)
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.new(0.5, 0, 0, 132)
	caption.Size = UDim2.new(1, -16, 0, 90)
	caption.TextYAlignment = Enum.TextYAlignment.Top
end

local playButton = Instance.new("TextButton")
playButton.Name = "Play"
playButton.AnchorPoint = Vector2.new(0.5, 1)
playButton.Position = UDim2.new(0.5, 0, 1, -18)
playButton.Size = UDim2.fromOffset(260, 70)
playButton.BackgroundColor3 = Color3.fromRGB(80, 210, 70)
playButton.AutoButtonColor = true
playButton.FontFace = Typography.Face
playButton.TextSize = 38
Typography.Fit(playButton, 38, 24)
playButton.TextColor3 = Color3.new(1, 1, 1)
playButton.Text = "JOUER !"
playButton.Parent = goalCard
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 16)
	round.Parent = playButton
	local border = Instance.new("UIStroke")
	border.Thickness = 4
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = playButton
	local textOutline = Instance.new("UIStroke")
	textOutline.Thickness = 3
	textOutline.Parent = playButton
end

-- Montre le but du jeu, puis appelle onPlay quand le joueur appuie sur JOUER.
local goalOpen = false
local function showGoal(onPlay: () -> ())
	goalOpen = true
	goalGui.Enabled = true
	goalScale.Scale = 0.7
	TweenService:Create(goalScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	for index, cellScale in ipairs(goalScales) do
		cellScale.Scale = 0
		task.delay(0.25 + index * 0.18, function()
			if goalOpen then -- les images apparaissent l'une après l'autre (sauf si JOUER a déjà été pressé)
				TweenService:Create(cellScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end)
	end
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = playButton
	end
	local connection: RBXScriptConnection? = nil
	connection = playButton.Activated:Connect(function()
		if connection then
			connection:Disconnect()
		end
		goalOpen = false
		goalGui.Enabled = false
		if GuiService.SelectedObject == playButton then
			GuiService.SelectedObject = nil
		end
		onPlay()
	end)
end

-- Démarrage : seulement quand la sauvegarde est connue (sinon un ancien joueur le verrait une seconde).
task.spawn(function()
	while player.Parent and player:GetAttribute("DataLoaded") ~= true do
		task.wait(0.25)
	end
	if not player.Parent or player:GetAttribute("TutorialDone") == true then
		return
	end
	task.wait(1.5) -- laisse le joueur apparaître et le HUD se mettre en place
	if player:GetAttribute("TutorialDone") ~= true then
		showGoal(function()
			if player:GetAttribute("TutorialDone") ~= true then
				showStep(1)
				updateProgress()
			end
		end)
	end
end)
