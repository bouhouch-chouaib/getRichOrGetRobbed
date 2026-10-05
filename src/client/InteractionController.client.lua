--!strict
-- InteractionController : tenir et lancer des objets.
--   [E] sur un objet -> le serveur valide et répond ItemGrabbed -> on soude l'objet à la main
--   (ou dans le dos si la main est déjà prise : sac à dos).
--   Clic gauche maintenu -> charge (ralentissement + zoom + arc de prédiction).
--   Relâchement -> on détruit le weld, on réactive les collisions et on propulse via ApplyImpulse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toast = require(script.Parent.Toast)

local THROW = Config.Throw
local DOT_COUNT = 20
local DOT_STEP = 0.08 -- secondes simulées entre deux points de l'arc

local player = Players.LocalPlayer

type Held = { item: BasePart, weld: WeldConstraint?, connections: { RBXScriptConnection } }
local stack: { Held } = {} -- objets portés : stack[1] en main, les autres dans le dos
local isCharging = false
local chargeStart = 0

----------------------------------------------------------------------
-- Arc de prédiction (local au client)
----------------------------------------------------------------------

local trajectory = Instance.new("Folder")
trajectory.Name = "Trajectory"
trajectory.Parent = Workspace

local dots: { Part } = {}
for index = 1, DOT_COUNT do
	local dot = Instance.new("Part")
	dot.Name = "Dot"
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.one * 0.5
	dot.Material = Enum.Material.Neon
	dot.Color = Color3.fromRGB(255, 255, 255)
	dot.Anchored = true
	dot.CanCollide = false
	dot.CanQuery = false
	dot.CanTouch = false
	dot.Transparency = 1
	dot.Parent = trajectory
	dots[index] = dot
end

local marker = Instance.new("Part")
marker.Name = "TargetMarker"
marker.Shape = Enum.PartType.Cylinder
marker.Size = Vector3.new(0.2, 5, 5)
marker.Material = Enum.Material.Neon
marker.Color = Color3.fromRGB(255, 60, 60)
marker.Anchored = true
marker.CanCollide = false
marker.CanQuery = false
marker.CanTouch = false
marker.Transparency = 1
marker.Parent = trajectory

local function hideTrajectory()
	for _, dot in ipairs(dots) do
		dot.Transparency = 1
	end
	marker.Transparency = 1
end

----------------------------------------------------------------------
-- Utilitaires
----------------------------------------------------------------------

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getHand(character: Model): BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

local function chargeRatio(): number
	return math.clamp((os.clock() - chargeStart) / THROW.MaxChargeTime, 0, 1)
end

local function throwVelocity(ratio: number): Vector3
	local camera = Workspace.CurrentCamera
	local direction = (camera.CFrame.LookVector + Vector3.new(0, THROW.UpBias, 0)).Unit
	-- La vitesse max dépend de la Force du joueur (attribut "ThrowPower" calculé par le serveur).
	local power = player:GetAttribute("ThrowPower")
	local maxSpeed = if type(power) == "number" then power else Config.Training.Strength.Base
	return direction * maxSpeed * (THROW.MinRatio + (1 - THROW.MinRatio) * ratio)
end

local function isOnOwnBase(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local index = player:GetAttribute("BaseIndex")
	local map = Workspace:FindFirstChild("Map")
	local base = map and index and map:FindFirstChild("Base_" .. tostring(index))
	local platform = base and base:FindFirstChild("BasePart")
	if not root or not root:IsA("BasePart") or not platform or not platform:IsA("BasePart") then
		return false
	end
	local localPosition = platform.CFrame:PointToObjectSpace(root.Position)
	local half = platform.Size / 2
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y < 30
end

----------------------------------------------------------------------
-- Charge
----------------------------------------------------------------------

local function stopCharging()
	if not isCharging then
		return
	end
	isCharging = false
	hideTrajectory()

	local humanoid = getHumanoid()
	if humanoid then
		local speed = player:GetAttribute("Speed")
		humanoid.WalkSpeed = if type(speed) == "number" then speed else Config.Training.Speed.Base
	end
	TweenService:Create(Workspace.CurrentCamera, TweenInfo.new(0.2), { FieldOfView = THROW.DefaultFov }):Play()
end

local function startCharging()
	isCharging = true
	chargeStart = os.clock()

	local humanoid = getHumanoid()
	if humanoid then
		humanoid.WalkSpeed = THROW.ChargeWalkSpeed
	end
	TweenService:Create(Workspace.CurrentCamera, TweenInfo.new(THROW.MaxChargeTime), { FieldOfView = THROW.ChargeFov }):Play()
end

local function updateTrajectory()
	local entry = stack[1]
	if not isCharging or not entry then
		return
	end
	local item = entry.item

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, item, trajectory }

	local origin = item.Position
	local velocity = throwVelocity(chargeRatio())
	local gravity = Vector3.new(0, -Workspace.Gravity, 0)
	local previous = origin

	hideTrajectory()
	for index = 1, DOT_COUNT do
		local t = index * DOT_STEP
		local point = origin + velocity * t + 0.5 * gravity * t * t
		local hit = Workspace:Raycast(previous, point - previous, params)
		if hit then
			marker.CFrame = CFrame.new(hit.Position) * CFrame.Angles(0, 0, math.pi / 2)
			marker.Transparency = 0.2
			break
		end
		dots[index].Position = point
		dots[index].Transparency = 0.2
		previous = point
	end
end

----------------------------------------------------------------------
-- Tenir / lâcher / lancer (pile : stack[1] en main, les suivants dans le dos)
----------------------------------------------------------------------

local function getTorso(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	return nil
end

-- Soude chaque objet à sa place : le premier dans la main, les autres empilés dans le dos.
local function relayout()
	local character = player.Character
	if not character then
		return
	end
	local hand = getHand(character)
	local torso = getTorso(character)
	for index, entry in ipairs(stack) do
		local anchor = if index == 1 then hand else torso
		if anchor then
			if entry.weld then
				entry.weld:Destroy()
			end
			entry.item.CFrame = if index == 1
				then anchor.CFrame * CFrame.new(0, -1.5, 0)
				else anchor.CFrame * CFrame.new(0, (index - 2) * 2.4 - 0.3, 1.8)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = entry.item
			weld.Part1 = anchor
			weld.Parent = entry.item
			entry.weld = weld
		end
	end
end

-- Retire un objet de la pile (sans le propulser) et lui rend la physique normale.
local function removeEntry(entry: Held)
	local index = table.find(stack, entry)
	if not index then
		return
	end
	table.remove(stack, index)
	for _, connection in ipairs(entry.connections) do
		connection:Disconnect()
	end
	if entry.weld then
		entry.weld:Destroy()
		entry.weld = nil
	end
	if entry.item.Parent then
		entry.item.CanCollide = true
		entry.item.Massless = false
	end
	if #stack == 0 then
		stopCharging()
	end
	relayout()
end

local function releaseAll()
	while #stack > 0 do
		removeEntry(stack[1])
	end
end

local function grab(item: BasePart)
	item.CanCollide = false
	item.Massless = true

	local entry: Held = { item = item, weld = nil, connections = {} }
	-- Le serveur efface "Holder" quand il force le lâcher (KO, mort) : on suit.
	table.insert(entry.connections, item:GetAttributeChangedSignal("Holder"):Connect(function()
		if item:GetAttribute("Holder") ~= player.Name then
			removeEntry(entry)
		end
	end))
	table.insert(entry.connections, item.AncestryChanged:Connect(function()
		if not item:IsDescendantOf(Workspace) then
			removeEntry(entry)
		end
	end))
	table.insert(stack, entry)
	relayout()
end

local function throw()
	local entry = stack[1]
	if not entry then
		return
	end
	local item = entry.item
	local velocity = throwVelocity(chargeRatio())

	stopCharging()
	removeEntry(entry) -- l'objet suivant passe automatiquement dans la main
	Remotes.ThrowItem:FireServer(item)
	-- Après la destruction du weld, l'item est seul dans son assemblage : GetMass() = sa masse.
	item:ApplyImpulse(velocity * item:GetMass())
end

----------------------------------------------------------------------
-- Connexions
----------------------------------------------------------------------

Remotes.ItemGrabbed.OnClientEvent:Connect(function(item: Instance)
	if item:IsA("BasePart") then
		grab(item)
	end
end)

Remotes.Knockback.OnClientEvent:Connect(function(velocity: Vector3)
	releaseAll()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
		root:ApplyImpulse(velocity * root.AssemblyMass)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if #stack > 0 then
		startCharging()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not isCharging then
		return
	end
	if isOnOwnBase() then
		stopCharging()
		Toast.show("SORS DE TA BASE POUR LANCER !", Color3.fromRGB(255, 90, 90))
		return
	end
	throw()
end)

RunService.RenderStepped:Connect(updateTrajectory)

player.CharacterAdded:Connect(function()
	releaseAll()
end)
