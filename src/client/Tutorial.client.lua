--!strict
-- Tutoriel : 3 étapes guidées pour un nouveau joueur (affiché une seule fois : attribut "TutorialDone",
-- enregistré dans la sauvegarde via Remotes.TutorialDone).
--   1. Ramasser un objet       -> flèche sur l'objet le plus proche
--   2. Le lancer dans le trou  -> flèche sur le trou noir (ou sur un objet si on n'en tient plus)
--   3. Voir ses familiers      -> flèche sur sa base, jusqu'aux tirages de la digestion
-- Guidage : panneau en bas de l'écran, gros "⬇" au-dessus de la cible, rayon doré entre le joueur et la cible.
-- Bouton PASSER pour ceux qui connaissent déjà le jeu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 220, 60)
local TOUCH = ScreenScale.isTouch()

type Step = { title: string, hint: string }
local STEPS: { Step } = {
	{
		title = "ÉTAPE 1/3 : RAMASSE UN OBJET",
		hint = if TOUCH then "Approche-toi d'un objet et touche RAMASSER" else "Approche-toi d'un objet et appuie sur [E]",
	},
	{
		title = "ÉTAPE 2/3 : LANCE-LE DANS LE TROU NOIR !",
		hint = if TOUCH
			then "Sors de ta base, approche-toi du trou, maintiens LANCER pour viser puis relâche"
			else "Sors de ta base, approche-toi du trou, maintiens CLIC GAUCHE pour viser puis relâche",
	},
	{
		title = "ÉTAPE 3/3 : TES FAMILIERS ARRIVENT !",
		hint = "Pendant la digestion, le trou noir te donne des familiers : regarde-les tomber dans ta base !",
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
panel.Position = UDim2.new(0.5, 0, 1, -52)
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

local function label(font: Enum.Font, size: number, y: number, height: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(16, y)
	text.Size = UDim2.new(1, -130, 0, height)
	text.Font = font
	text.TextSize = size
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	local outline = Instance.new("UIStroke")
	outline.Thickness = math.max(1.5, size / 12)
	outline.Parent = text
	text.Parent = panel
	return text
end
local titleLabel = label(Enum.Font.LuckiestGuy, 26, 8, 30)
local hintLabel = label(Enum.Font.FredokaOne, 16, 40, 32)

local skipButton = Instance.new("TextButton")
skipButton.Name = "Skip"
skipButton.AnchorPoint = Vector2.new(1, 0.5)
skipButton.Position = UDim2.new(1, -12, 0.5, 0)
skipButton.Size = UDim2.fromOffset(100, 40)
skipButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
skipButton.Font = Enum.Font.LuckiestGuy
skipButton.TextSize = 20
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
	arrow.Font = Enum.Font.LuckiestGuy
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
	Remotes.TutorialDone:FireServer()
	if skipped then
		Toast.show("TUTORIEL PASSÉ", Color3.fromRGB(200, 200, 200))
	else
		Sounds.play("LevelUp")
		Toast.show("BRAVO ! PENDANT LA DIGESTION, VOLE LES FAMILIERS DES BASES OUVERTES !", GOLD)
	end
end

skipButton.Activated:Connect(function()
	finish(true)
end)

-- Étape 1 -> 2 : un objet ramassé.
Remotes.ItemGrabbed.OnClientEvent:Connect(function()
	if step == 1 then
		showStep(2)
	end
end)

-- Étape 1/2 -> 3 : des points marqués (objet avalé par le trou noir).
local lastScore = player:GetAttribute("RoundScore")
player:GetAttributeChangedSignal("RoundScore"):Connect(function()
	local score = player:GetAttribute("RoundScore")
	local previous = if type(lastScore) == "number" then lastScore else 0
	lastScore = score
	if type(score) == "number" and score > previous and (step == 1 or step == 2) then
		showStep(3)
	end
end)

-- Étape 3 -> fin : les tirages sont tombés (on laisse le temps de voir l'ouverture / la carte).
Remotes.RewardsGranted.OnClientEvent:Connect(function(_score: number, pulls: number)
	if step == 3 and pulls > 0 then
		task.delay(3, function()
			finish(false)
		end)
	end
end)

-- Terminé ailleurs (autre appareil) : on arrête.
player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
	if player:GetAttribute("TutorialDone") == true and step ~= 0 then
		stop()
	end
end)

-- Position de la flèche et du rayon à chaque image.
RunService.RenderStepped:Connect(function()
	if step == 0 then
		return
	end
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

	local goal: Vector3? = nil
	if step == 1 or (step == 2 and not isHolding()) then
		local item = nearestItem(rootPart.Position)
		goal = if item then item + Vector3.new(0, 2.5, 0) else nil
	elseif step == 2 then
		goal = HOLE
	else
		local base = myBase()
		local platform = base and base:FindFirstChild("BasePart")
		goal = if platform and platform:IsA("BasePart") then platform.Position + Vector3.new(0, 5, 0) else nil
	end

	-- Étape 2 pendant la digestion : le trou ne mange pas, on prévient.
	if step == 2 then
		local digesting = ReplicatedStorage:GetAttribute("GameState") == "Digesting"
		hintLabel.Text = if digesting
			then "Le trou noir digère... attends qu'il ait de nouveau faim (chrono en haut) !"
			elseif isHolding() then STEPS[2].hint
			else STEPS[1].hint .. ", puis lance-le dans le trou noir !"
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
	local started = os.clock()
	while player:GetAttribute("DataLoaded") ~= true and os.clock() - started < 8 do
		task.wait(0.25)
	end
	if player:GetAttribute("TutorialDone") == true then
		return
	end
	task.wait(1.5) -- laisse le joueur apparaître et le HUD se mettre en place
	if player:GetAttribute("TutorialDone") ~= true then
		showStep(if isHolding() then 2 else 1)
	end
end)
