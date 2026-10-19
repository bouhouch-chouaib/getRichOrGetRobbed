--!strict
-- Rafales de gains : apparition avec rebond, dispersion autour du corps, puis fondu.
-- Un pulse serveur est partagé entre les textes : l'effet ne multiplie pas l'XP affichée.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Icons = require(ReplicatedStorage.Shared.Icons)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Typography = require(ReplicatedStorage.Shared.Typography)

local TrainingGainFx = {}
local random = Random.new()
local MAX_DISTANCE = 90
local MAX_PARTICLES = 64
local REMOTE_LIMIT = 48 -- garder des places pour les gains du joueur local
local serial = 0
local waves: { [Player]: number } = {}

type Particle = {
	owner: Player,
	anchor: BasePart,
	gui: BillboardGui,
	holder: Frame,
	scale: UIScale,
	label: TextLabel,
	stroke: UIStroke,
	icon: ImageLabel,
	origin: Vector3,
	right: Vector3,
	spread: number,
	rise: number,
	tilt: number,
	birth: number,
	lifetime: number,
}
local particles: { Particle } = {}

local function remove(index: number)
	particles[index].gui:Destroy()
	table.remove(particles, index)
end

function TrainingGainFx.Clear(target: Player)
	waves[target] = nil
	for index = #particles, 1, -1 do
		if particles[index].owner == target then
			remove(index)
		end
	end
end

local function formatGain(value: number): string
	if value >= 1000 then
		return NumberFormat.short(value)
	end
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function emit(target: Player, character: Model, gain: number, speed: boolean, lane: number, parent: Instance)
	local anchor = character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not anchor or not anchor:IsA("BasePart") or not camera then
		return
	end
	if (camera.CFrame.Position - anchor.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local localPlayer = target == Players.LocalPlayer
	if not localPlayer and #particles >= REMOTE_LIMIT then
		return
	end
	if #particles >= MAX_PARTICLES then
		remove(1)
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local center = if torso and torso:IsA("BasePart") then torso.Position else anchor.Position
	local right = camera.CFrame.RightVector
	local origin = center + right * random:NextNumber(-0.35, 0.35) + Vector3.new(0, random:NextNumber(-0.2, 0.6), 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = "TrainingGainParticle"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(132, 46)
	gui.StudsOffsetWorldSpace = origin - anchor.Position
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = MAX_DISTANCE
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(112, 36)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(0, 2)
	label.Size = UDim2.fromOffset(74, 32)
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Text = "+" .. formatGain(gain)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 1
	Typography.Fit(label, 27, 14)
	label.Parent = holder
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), if speed then Color3.fromRGB(45, 200, 255) else Color3.fromRGB(255, 155, 40))
	shade.Rotation = 90
	shade.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(18, 25, 42)
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = label
	local icon = Icons.image(holder, if speed then "Speed" else "Strength", UDim2.fromOffset(32, 32), UDim2.fromOffset(80, 2))
	icon.ImageTransparency = 1
	gui.Parent = parent
	table.insert(particles, {
		owner = target, anchor = anchor, gui = gui, holder = holder, scale = scale,
		label = label, stroke = stroke, icon = icon,
		origin = origin, right = right,
		spread = lane * random:NextNumber(2.4, 3.7),
		rise = random:NextNumber(3.2, 5.1),
		tilt = lane * random:NextNumber(10, 20),
		birth = os.clock(), lifetime = random:NextNumber(1.15, 1.5),
	})
end

function TrainingGainFx.Burst(target: Player, gain: number, training: string, parent: Instance)
	local character = target.Character
	if not character or gain <= 0 or gain ~= gain or gain == math.huge then
		return
	end
	if training ~= "Treadmill" and training ~= "Bench" then
		return
	end
	serial += 1
	local wave = serial
	waves[target] = wave
	-- Centièmes répartis exactement ; pas six fois le montant du pulse serveur.
	local units = math.floor(gain * 100 + 0.5)
	if units < 1 then
		return
	end
	local count = math.min(if target == Players.LocalPlayer then 6 else 3, units)
	local share = math.floor(units / count)
	local remainder = units - share * count
	for index = 1, count do
		local amount = (share + (if index <= remainder then 1 else 0)) / 100
		-- Alterner gauche/droite évite que les textes d'une même rafale se recouvrent.
		local side = if index % 2 == 0 then 1 else -1
		local lane = side * (0.35 + 0.65 * math.ceil(index / 2) / math.ceil(count / 2))
		task.delay((index - 1) * 0.09, function()
			if waves[target] == wave and target.Character == character and target:GetAttribute("Training") == training and parent.Parent then
				emit(target, character, amount, training == "Treadmill", lane, parent)
			end
		end)
	end
end

-- Une seule boucle pour toutes les particules, avec une durée et un nombre bornés.
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	for index = #particles, 1, -1 do
		local p = particles[index]
		local age = now - p.birth
		if age >= p.lifetime or not p.anchor.Parent or not p.gui.Parent then
			remove(index)
			continue
		end
		local t = age / p.lifetime
		local spread = 1 - (1 - t) ^ 3
		local position = p.origin + p.right * (p.spread * spread) + Vector3.new(0, p.rise * t - 0.7 * t * t, 0)
		-- Laisser les gains derrière soi si le personnage se déplace.
		p.gui.StudsOffsetWorldSpace = position - p.anchor.Position
		local visible = false
		if camera and (camera.CFrame.Position - position).Magnitude <= MAX_DISTANCE then
			local _, onScreen = camera:WorldToViewportPoint(position)
			visible = onScreen
		end
		p.gui.Enabled = visible
		if not visible then
			continue
		end
		local entrance = math.clamp(age / 0.22, 0, 1)
		local back = 1 + 2.70158 * (entrance - 1) ^ 3 + 1.70158 * (entrance - 1) ^ 2
		local exit = math.clamp((t - 0.64) / 0.36, 0, 1)
		local fade = exit * exit * (3 - 2 * exit)
		p.scale.Scale = (0.2 + 0.8 * back) * (1 - 0.3 * fade)
		p.holder.Rotation = p.tilt * (0.25 + 0.75 * t) + math.sin(t * math.pi * 2) * 4
		p.icon.Rotation = -p.tilt * math.sin(t * math.pi)
		local transparency = math.max(1 - math.clamp(age / 0.08, 0, 1), fade)
		p.label.TextTransparency = transparency
		p.stroke.Transparency = transparency
		p.icon.ImageTransparency = transparency
	end
end)

return TrainingGainFx
