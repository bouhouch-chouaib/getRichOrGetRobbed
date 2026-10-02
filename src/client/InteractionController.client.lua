--!strict
-- InteractionController : tenir et lancer un objet.
--   [E] sur un objet -> le serveur valide et répond ItemGrabbed -> on soude l'objet à la main.
--   Clic gauche maintenu -> charge (ralentissement + zoom + arc de prédiction).
--   Relâchement -> on détruit le weld, on réactive les collisions et on propulse via ApplyImpulse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local THROW = Config.Throw
local DOT_COUNT = 20
local DOT_STEP = 0.08 -- secondes simulées entre deux points de l'arc

local player = Players.LocalPlayer

local heldItem: BasePart? = nil
local heldWeld: WeldConstraint? = nil
local heldConnections: { RBXScriptConnection } = {}
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

local function notify(text: string)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = "Get Rich Or Get Robbed", Text = text, Duration = 2 })
	end)
end

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
	return direction * (THROW.MinSpeed + (THROW.MaxSpeed - THROW.MinSpeed) * ratio)
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
		humanoid.WalkSpeed = if type(speed) == "number" then speed else Config.Speed.Base
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
	local item = heldItem
	if not isCharging or not item then
		return
	end

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
-- Tenir / lâcher / lancer
----------------------------------------------------------------------

-- Oublie l'objet tenu (sans le propulser).
local function releaseLocal()
	stopCharging()
	for _, connection in ipairs(heldConnections) do
		connection:Disconnect()
	end
	heldConnections = {}
	if heldWeld then
		heldWeld:Destroy()
	end
	local item = heldItem
	if item and item.Parent then
		item.CanCollide = true
		item.Massless = false
	end
	heldItem = nil
	heldWeld = nil
end

local function grab(item: BasePart)
	local character = player.Character
	local hand = character and getHand(character)
	if not hand then
		return
	end
	releaseLocal()

	item.CanCollide = false
	item.Massless = true
	item.CFrame = hand.CFrame * CFrame.new(0, -1.5, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = item
	weld.Part1 = hand
	weld.Parent = item

	heldItem = item
	heldWeld = weld

	-- Le serveur efface "Holder" quand il force le lâcher (KO, mort) : on suit.
	table.insert(heldConnections, item:GetAttributeChangedSignal("Holder"):Connect(function()
		if item:GetAttribute("Holder") ~= player.Name then
			releaseLocal()
		end
	end))
	table.insert(heldConnections, item.AncestryChanged:Connect(function()
		if not item:IsDescendantOf(Workspace) then
			releaseLocal()
		end
	end))
end

local function throw()
	local item = heldItem
	if not item then
		return
	end
	local velocity = throwVelocity(chargeRatio())

	releaseLocal()
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
	releaseLocal()
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
	if heldItem then
		startCharging()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not isCharging then
		return
	end
	if isOnOwnBase() then
		stopCharging()
		notify("Sors de ta base pour lancer !")
		return
	end
	throw()
end)

RunService.RenderStepped:Connect(updateTrajectory)

player.CharacterAdded:Connect(function()
	releaseLocal()
end)
