--!strict
-- Standalone visual review place. No remotes, inventory grants, economy or DataStore.
local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Catalog = require(RS.Shared.PetCatalog)
local Builder = require(RS.Shared.PetModelBuilder)
local Config = require(RS.Shared.Config)
local camera = workspace.CurrentCamera
if not camera then
	return
end
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 42
local gui = Instance.new("ScreenGui")
gui.Name = "PetGallery"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -24, 0, 82)
label.Position = UDim2.fromOffset(12, 12)
label.BackgroundTransparency = 0.15
label.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 22
label.FontFace = Typography.Face
label.TextWrapped = true
label.Parent = gui
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -20)
bar.Size = UDim2.fromOffset(844, 56)
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 8)
layout.Parent = bar
local selected = 1
local shown: Model? = nil
local spin = true
local aura = true
local animate = true
local walking = false
local yaw = 0.55
local focus = Vector3.zero
local distance = 18
local function show()
	if shown then
		shown:Destroy()
	end
	local e = Catalog.List[selected]
	local m = Builder.Build(e.Id)
	if not m then
		return
	end
	shown = m
	local box, size = Builder.BodyBounds(m)
	local hover = if m:GetAttribute("MotionFlying") then 0.7 else 0.04
	m:PivotTo(CFrame.new(0, size.Y / 2 - box.Position.Y + hover, 0))
	focus = Vector3.new(0, size.Y * 0.5 + hover, 0)
	distance = math.max(size.Magnitude * 1.25, 8)
	m:SetAttribute("AuraHidden", not aura)
	m:SetAttribute("MotionPaused", not animate)
	m:SetAttribute("MotionSpeed", if walking then 4 else 0)
	for _, q in ipairs(m:GetDescendants()) do
		if q:IsA("BasePart") and q:GetAttribute("Aura") and not aura then
			q.Transparency = 1
		end
	end
	m.Parent = workspace
	label.Text = string.format("%02d / 75   ·   %s\n%s   ·   %s", selected, e.Name, e.Category, e.Rarity)
	label.TextColor3 = Config.Rarities[Config.RarityIndex[e.Rarity]].Color
end
local function nextPet(delta: number)
	selected = (selected - 1 + delta) % #Catalog.List + 1
	show()
end
local function button(text: string, callback: () -> ())
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(134, 50)
	b.Text = text
	b.TextSize = 17
	b.FontFace = Typography.Face
	b.BackgroundColor3 = Color3.fromRGB(42, 58, 82)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = bar
	b.Activated:Connect(callback)
	return b
end
button("← Précédent", function()
	nextPet(-1)
end)
button("Suivant →", function()
	nextPet(1)
end)
local spinButton: TextButton
spinButton = button("Rotation : oui", function()
	spin = not spin
	spinButton.Text = if spin then "Rotation : oui" else "Rotation : non"
end)
local auraButton: TextButton
auraButton = button("Auras : oui", function()
	aura = not aura
	auraButton.Text = if aura then "Auras : oui" else "Auras : non"
	show()
end)
local motionButton: TextButton
motionButton = button("Anim. : oui", function()
	animate = not animate
	motionButton.Text = if animate then "Anim. : oui" else "Anim. : non"
	if shown then
		shown:SetAttribute("MotionPaused", not animate)
	end
end)
local walkButton: TextButton
walkButton = button("Au repos", function()
	walking = not walking
	walkButton.Text = if walking then "En marche" else "Au repos"
	if shown then
		shown:SetAttribute("MotionSpeed", if walking then 4 else 0)
	end
end)
UIS.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Right then
		nextPet(1)
	elseif input.KeyCode == Enum.KeyCode.Left then
		nextPet(-1)
	end
end)
local function resize()
	local scale = bar:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = math.min(1, camera.ViewportSize.X / 874)
	scale.Parent = bar
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
resize()
RunService:BindToRenderStep("PetGalleryCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if spin then
		yaw += dt * 0.23
	end
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(math.sin(yaw), 0.38, -math.cos(yaw)).Unit * distance, focus)
end)
show()
