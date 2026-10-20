--!strict
-- Tutoriel : 4 étapes guidées pour un nouveau joueur (affiché une seule fois : attribut "TutorialDone",
-- enregistré dans la sauvegarde via Remotes.TutorialDone).
--   1. Ramasser un objet       -> flèche sur l'objet le plus proche
--   2. Le lancer dans le trou  -> flèche sur le trou noir (ou sur un objet si on n'en tient plus)
--   3. Recevoir un œuf         -> retour vers la base
--   4. Voir son éclosion       -> flèche sur son œuf, jusqu’au vrai familier
-- Guidage : panneau en bas de l'écran, gros "⬇" au-dessus de la cible, rayon doré entre le joueur et la cible.
-- Bouton PASSER pour ceux qui connaissent déjà le jeu.

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BaseLayout = require(ReplicatedStorage.Shared.BaseLayout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 220, 60)
local TOUCH = ScreenScale.isTouch()

type Step = { title: string, hint: string }
local STEPS: { Step } = {
	{
		title = "ÉTAPE 1/4 : RAMASSE UN OBJET",
		hint = if TOUCH
			then "Approche-toi d'un objet et touche RAMASSER"
			else "Approche-toi d'un objet et appuie sur [E]",
	},
	{
		title = "ÉTAPE 2/4 : LANCE-LE DANS LE TROU NOIR !",
		hint = if TOUCH
			then "Sors de ta base, approche-toi du trou, maintiens LANCER pour viser puis relâche"
			else "Sors de ta base, approche-toi du trou, maintiens CLIC GAUCHE pour viser puis relâche",
	},
	{
		title = "ÉTAPE 3/4 : TON PREMIER ŒUF !",
		hint = "Reviens dans ta base : tes points te donnent des œufs quand le trou noir commence à digérer.",
	},
	{
		title = "ÉTAPE 4/4 : FAIS ÉCLORE TON ŒUF",
		hint = "Retrouve ton œuf dans la couveuse au fond de ta base. Il éclot tout seul à la fin du compte à rebours !",
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
panel.Size = UDim2.fromOffset(660, 78)
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

local function label(font: Font, size: number, y: number, height: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(16, y)
	text.Size = UDim2.new(1, -130, 0, height)
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
local titleLabel = label(Typography.Face, 26, 8, 30)
local hintLabel = label(Typography.Face, 16, 40, 32)

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
		Toast.show("TON FAMILIER RAPPORTE DE L’ARGENT ! OUVRE L’INDEX POUR RÉCLAMER SA RÉCOMPENSE.", GOLD)
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
		titleLabel.Text = if digesting and starterPending then "TON ŒUF DE DÉPART T’ATTEND !" else STEPS[2].title
		hintLabel.Text = if digesting and starterPending
			then "Rejoins ta couveuse : ton œuf offert éclot bientôt et finance ta première amélioration !"
			elseif digesting and player:GetAttribute("StarterBonusPaid") == true and player:GetAttribute(
				"Onboarding_Upgraded"
			) ~= true then "Ouvre BOUTIQUE : utilise ta prime pour acheter un tapis de course ou un banc de muscu."
			elseif digesting then "Entraîne-toi ou prépare ton prochain lancer pendant la digestion (chrono en haut)."
			elseif isHolding() then STEPS[2].hint
			else STEPS[1].hint .. ", puis lance-le dans le trou noir !"
	end

	if step == 4 then
		local hatchAt = player:GetAttribute("NextHatchAt")
		local countdown = if type(hatchAt) == "number" and hatchAt < math.huge
			then math.max(0, math.ceil(hatchAt - Workspace:GetServerTimeNow()))
			else 0
		hintLabel.Text = if countdown > 0
			then string.format(
				"Ton œuf éclot dans %d s ! Rejoins la couveuse ; tu peux continuer à jouer pendant l’attente.",
				countdown
			)
			elseif
				hatchAt == math.huge
			then "Ton œuf est dans la capsule d’évolution : il finit son incubation, puis tu pourras l’ouvrir pour découvrir ton familier !"
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
		showStep(1)
		updateProgress()
	end
end)
