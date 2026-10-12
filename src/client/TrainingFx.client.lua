--!strict
-- TrainingFx : ce qu'on voit pendant l'entraînement (server/TrainingController bloque le joueur sur la station et
-- écrit l'attribut "Training" = "Treadmill" ou "Bench").
--   - Tapis : animation de course de Roblox jouée en boucle sur son propre personnage (donc vue par tout le monde).
--   - Banc : développé couché animé ICI pour chaque joueur allongé (bras qui poussent, barre qui suit les mains,
--     grognement d'effort à chaque poussée). Chaque client anime tout le monde : c'est pareil pour tous.
--   - "+X 👟" / "+X 💪" qui s'envolent au-dessus de la tête à chaque seconde (attributs "TrainingGain" / "TrainingPulse").
--   - Pour descendre : sauter, ou bouton ARRÊTER (Remotes.StopTraining).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Joints = require(script.Parent.Joints)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)

local TRAINING = Config.Training
local DEFAULT_RUN = "rbxassetid://913376220" -- course R15 de Roblox (si le script Animate n'en donne pas)
local POPUP_DISTANCE = 90

local player = Players.LocalPlayer

-- Plus la station est haute en niveau, plus on court / pousse vite.
local function animSpeed(target: Player, upgrade: string): number
	local level = target:GetAttribute("Upgrade_" .. upgrade)
	return 1 + TRAINING.AnimSpeedPerLevel * math.max((if type(level) == "number" then level else 1) - 1, 0)
end

----------------------------------------------------------------------
-- Bouton ARRÊTER + saut
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TrainingFx"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(gui)

local stopButton = Instance.new("TextButton")
stopButton.Name = "Stop"
stopButton.AnchorPoint = Vector2.new(0.5, 1)
stopButton.Position = UDim2.new(0.5, 0, 1, -70)
stopButton.Size = UDim2.fromOffset(220, 60)
stopButton.BackgroundColor3 = Color3.new(1, 1, 1)
stopButton.AutoButtonColor = false
stopButton.Font = Enum.Font.LuckiestGuy
stopButton.Text = "⏹ ARRÊTER"
stopButton.TextSize = 28
stopButton.TextColor3 = Color3.new(1, 1, 1)
stopButton.Visible = false
stopButton.Parent = root
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = stopButton
	local border = Instance.new("UIStroke")
	border.Thickness = 4
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = stopButton
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Parent = stopButton
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 110, 110), Color3.fromRGB(200, 40, 40))
	shade.Rotation = 90
	shade.Parent = stopButton
end

local stopSent = 0
local function requestStop()
	if player:GetAttribute("Training") ~= nil and os.clock() - stopSent > 0.5 then
		stopSent = os.clock()
		Remotes.StopTraining:FireServer()
	end
end
stopButton.Activated:Connect(requestStop)
UserInputService.JumpRequest:Connect(requestStop)

----------------------------------------------------------------------
-- Tapis : animation de course (personnage du joueur local seulement, elle est répliquée)
----------------------------------------------------------------------

local runTrack: AnimationTrack? = nil

local function runAnimationId(character: Model): string
	local animate = character:FindFirstChild("Animate")
	local run = animate and animate:FindFirstChild("run")
	local anim = run and run:FindFirstChildOfClass("Animation")
	return if anim and anim.AnimationId ~= "" then anim.AnimationId else DEFAULT_RUN
end

local function updateLocalTraining()
	local training = player:GetAttribute("Training")
	stopButton.Visible = training ~= nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- Allongé sur le banc : le personnage ne doit pas essayer de se relever.
	if humanoid then
		humanoid.PlatformStand = training == "Bench"
	end
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if training == "Treadmill" and character and animator then
		if not runTrack then
			local animation = Instance.new("Animation")
			animation.AnimationId = runAnimationId(character)
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.2)
			track:AdjustSpeed(TRAINING.RunAnimSpeed * animSpeed(player, "Treadmill"))
			runTrack = track
		end
	elseif runTrack then
		runTrack:Stop(0.2)
		runTrack = nil
	end
end

player:GetAttributeChangedSignal("Training"):Connect(updateLocalTraining)
player.CharacterAdded:Connect(function()
	runTrack = nil
	updateLocalTraining()
end)

----------------------------------------------------------------------
-- "+X" qui s'envolent au-dessus de la tête (tous les joueurs)
----------------------------------------------------------------------

local function formatGain(value: number): string
	if value >= 10 then
		return tostring(math.floor(value + 0.5))
	end
	return (string.format("%.1f", value):gsub("%.0$", ""))
end

local function popup(target: Player)
	local character = target.Character
	local head = character and character:FindFirstChild("Head")
	local gain = target:GetAttribute("TrainingGain")
	local training = target:GetAttribute("Training")
	if not head or not head:IsA("BasePart") or type(gain) ~= "number" or training == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - head.Position).Magnitude > POPUP_DISTANCE then
		return
	end
	local isSpeed = training == "Treadmill"
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(160, 50)
	billboard.StudsOffsetWorldSpace = Vector3.new(math.random(-15, 15) / 10, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = "+" .. formatGain(gain) .. (if isSpeed then " 👟" else " 💪")
	label.TextColor3 = if isSpeed then Color3.fromRGB(120, 230, 255) else Color3.fromRGB(255, 170, 60)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = label
	label.Parent = billboard
	billboard.Parent = gui

	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	task.delay(1.2, function()
		billboard:Destroy()
	end)
end

----------------------------------------------------------------------
-- Banc : développé couché (animé ici pour chaque joueur allongé)
----------------------------------------------------------------------

type Lifter = {
	player: Player,
	start: number,
	lastRep: number,
	bar: BasePart?,
	plates: { BasePart },
	barHome: CFrame?, -- position d'origine de la barre (remise en place à la fin)
	plateHomes: { CFrame },
	plateOffsets: { CFrame }, -- place de chaque disque par rapport à la barre
}

local lifters: { [Player]: Lifter } = {}

local function benchOf(target: Player): Model?
	local map = Workspace:FindFirstChild("Map")
	local base = map and map:FindFirstChild("Base_" .. tostring(target:GetAttribute("BaseIndex")))
	local bench = base and base:FindFirstChild("Bench")
	return if bench and bench:IsA("Model") then bench else nil
end

local function startLifter(target: Player)
	if lifters[target] then
		return
	end
	local lifter: Lifter = { player = target, start = os.clock(), lastRep = 0, bar = nil, plates = {}, barHome = nil, plateHomes = {}, plateOffsets = {} }
	local bench = benchOf(target)
	if bench then
		local bar = bench:FindFirstChild("Bar")
		if bar and bar:IsA("BasePart") then
			lifter.bar = bar
			lifter.barHome = bar.CFrame
		end
		for _, child in ipairs(bench:GetChildren()) do
			if child.Name == "Plate" and child:IsA("BasePart") then
				table.insert(lifter.plates, child)
				table.insert(lifter.plateHomes, child.CFrame)
				table.insert(lifter.plateOffsets, if lifter.barHome then lifter.barHome:ToObjectSpace(child.CFrame) else CFrame.new())
			end
		end
	end
	lifters[target] = lifter
end

local function stopLifter(target: Player)
	local lifter = lifters[target]
	if not lifter then
		return
	end
	lifters[target] = nil
	if lifter.bar and lifter.barHome then
		lifter.bar.CFrame = lifter.barHome
	end
	for index, plate in ipairs(lifter.plates) do
		plate.CFrame = lifter.plateHomes[index]
	end
	-- Les articulations reprennent les animations normales d'elles-mêmes (Transform est réécrit à chaque image).
end

local motor = Joints.get


-- Après les animations de Roblox (Stepped) : on impose la pose du développé couché.
RunService.Stepped:Connect(function()
	local now = os.clock()
	for target, lifter in pairs(lifters) do
		local character = target.Character
		if not character then
			continue
		end
		-- push : 0 = barre sur la poitrine, 1 = bras tendus.
		local repTime = TRAINING.BenchRepTime / animSpeed(target, "Bench")
		local phase = ((now - lifter.start) / repTime) % 1
		local push = 0.5 - 0.5 * math.cos(phase * math.pi * 2)

		-- Bras vers le ciel (l'avant du personnage allongé), coudes pliés quand la barre descend.
		local shoulderAngle = math.rad(75 + 15 * push)
		local elbowAngle = math.rad(95 * (1 - push))
		for _, side in ipairs({ "Right", "Left" }) do
			local shoulder = motor(character, side .. "UpperArm", side .. "Shoulder")
			local elbow = motor(character, side .. "LowerArm", side .. "Elbow")
			if shoulder then
				shoulder.Transform = CFrame.Angles(shoulderAngle, 0, 0)
			end
			if elbow then
				elbow.Transform = CFrame.Angles(elbowAngle, 0, 0)
			end
			-- Jambes légèrement pliées, posées sur le banc.
			local hip = motor(character, side .. "UpperLeg", side .. "Hip")
			local knee = motor(character, side .. "LowerLeg", side .. "Knee")
			if hip then
				hip.Transform = CFrame.Angles(math.rad(10), 0, 0)
			end
			if knee then
				knee.Transform = CFrame.Angles(math.rad(-20), 0, 0)
			end
		end

		-- La barre suit les mains (ou monte et descend toute seule si le personnage n'a pas de mains R15).
		local bar = lifter.bar
		if bar and lifter.barHome then
			local rightHand = character:FindFirstChild("RightHand")
			local leftHand = character:FindFirstChild("LeftHand")
			local position: Vector3
			if rightHand and leftHand and rightHand:IsA("BasePart") and leftHand:IsA("BasePart") then
				position = (rightHand.Position + leftHand.Position) / 2 + Vector3.new(0, 0.25, 0)
			else
				position = lifter.barHome.Position - Vector3.new(0, 1.2 * (1 - push), 0)
			end
			local rotation = lifter.barHome - lifter.barHome.Position
			bar.CFrame = CFrame.new(position) * rotation
			for index, plate in ipairs(lifter.plates) do
				plate.CFrame = bar.CFrame * lifter.plateOffsets[index]
			end
		end

		-- Grognement d'effort au début de chaque poussée.
		local rep = math.floor((now - lifter.start) / repTime + 0.5)
		if rep > lifter.lastRep then
			lifter.lastRep = rep
			local head = character:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				Sounds.playAt("Effort", head.Position)
			end
		end
	end
end)

----------------------------------------------------------------------
-- Suivi de tous les joueurs
----------------------------------------------------------------------

local function watch(target: Player)
	local function onTraining()
		if target:GetAttribute("Training") == "Bench" then
			startLifter(target)
		else
			stopLifter(target)
		end
	end
	target:GetAttributeChangedSignal("Training"):Connect(onTraining)
	target:GetAttributeChangedSignal("TrainingPulse"):Connect(function()
		popup(target)
	end)
	onTraining()
end

Players.PlayerAdded:Connect(watch)
for _, other in ipairs(Players:GetPlayers()) do
	watch(other)
end
Players.PlayerRemoving:Connect(stopLifter)
updateLocalTraining()
