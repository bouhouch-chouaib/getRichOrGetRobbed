--!strict
-- Magnet : bouton (et touche G) pour allumer / couper l'aimant de la Boutique ou l'ASPIRATEUR (passe Robux,
-- Config.Vacuum). Avec l'aspirateur allumé : un tourbillon de vent autour du joueur, et chaque objet aspiré vole jusqu'à
-- lui (Remotes.VacuumPull : une copie de l'objet part de sa place, tourne et rapetisse en arrivant).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiStyle = require(script.Parent.UiStyle)
local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local stack = hud:WaitForChild("Root"):WaitForChild("TopStack")
local button = UiStyle.button(stack, "", UDim2.fromOffset(250, 34), UiStyle.Colors.Cyan, 15)
button.Name, button.LayoutOrder = "MagnetToggle", 5
button.Visible = false

local PURPLE = Color3.fromRGB(170, 90, 255)

-- Tourbillon autour du joueur pendant que l'aspirateur marche (particules qui partent du bord vers le centre).
local swirl: Part? = nil
local function setSwirl(on: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not on or not root or not root:IsA("BasePart") then
		if swirl then
			swirl:Destroy()
			swirl = nil
		end
		return
	end
	if swirl and swirl.Parent then
		return
	end
	local part = Instance.new("Part")
	part.Name = "VacuumSwirl"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(1, Config.Vacuum.Radius * 1.4, Config.Vacuum.Radius * 1.4)
	part.Transparency = 1
	part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, true
	part.CFrame = root.CFrame * CFrame.Angles(0, 0, math.pi / 2) - Vector3.new(0, 2.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = part, root
	weld.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 200, 255), PURPLE)
	emitter.LightEmission = 0.8
	emitter.Rate = 40
	emitter.Lifetime = NumberRange.new(0.9, 1.3)
	emitter.Speed = NumberRange.new(14, 20)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Parent = part
	part.Parent = character
	swirl = part
end

local function refresh()
	local vacuum = Perks.HasVacuum(player)
	button.Visible = vacuum or Perks.MagnetLevel(player) > 0
	local enabled = player:GetAttribute("MagnetEnabled") == true
	(button:FindFirstChild("Caption") :: TextLabel).Text = (if vacuum then "ASPIRATEUR : " else "AIMANT : ")
		.. (if enabled then "ACTIF" else "ARRÊT")
		.. (if UserInputService.KeyboardEnabled then " [G]" else "")
	UiStyle.setButtonColor(button, if enabled then (if vacuum then PURPLE else UiStyle.Colors.Green) else UiStyle.Colors.Cyan)
	setSwirl(vacuum and enabled)
end
local function toggle()
	if button.Visible then
		Remotes.SetMagnet:FireServer(player:GetAttribute("MagnetEnabled") ~= true)
	end
end
button.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.G then
		toggle()
	end
end)
for _, attribute in ipairs({ "MagnetEnabled", "Upgrade_Magnet", "Pass_" .. Config.Vacuum.PassKey, "DataLoaded" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
player.CharacterAdded:Connect(function()
	swirl = nil
	task.defer(refresh)
end)
refresh()

-- Objet aspiré : une copie vole de sa place jusqu'au joueur (le vrai objet est déjà dans ses mains).
Remotes.VacuumPull.OnClientEvent:Connect(function(item: Instance, from: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not item:IsA("BasePart") or typeof(from) ~= "Vector3" or not root or not root:IsA("BasePart") then
		return
	end
	local ghost = item:Clone()
	for _, child in ipairs(ghost:GetChildren()) do
		if not child:IsA("SpecialMesh") and not child:IsA("Decal") and not child:IsA("Texture") then
			child:Destroy()
		end
	end
	ghost.Anchored, ghost.CanCollide, ghost.CanTouch, ghost.CanQuery = true, false, false, false
	ghost.CFrame = CFrame.new(from)
	ghost.Parent = Workspace
	local size = ghost.Size
	local start = os.clock()
	local duration = math.clamp((from - root.Position).Magnitude / 60, 0.18, 0.5)
	local connection: RBXScriptConnection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / duration)
		local target = root.Position + Vector3.new(0, 1, 0)
		local eased = t * t
		local pos = from:Lerp(target, eased) + Vector3.new(0, math.sin(t * math.pi) * 3, 0)
		ghost.CFrame = CFrame.new(pos) * CFrame.Angles(t * 8, t * 6, 0)
		ghost.Size = size * (1 - 0.7 * t)
		if t >= 1 then
			connection:Disconnect()
			ghost:Destroy()
		end
	end)
end)
