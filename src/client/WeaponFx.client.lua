--!strict
-- WeaponFx : ce qu'on voit quand quelqu'un utilise une arme (server/WeaponController envoie Remotes.WeaponFx à tous).
--   ("Swing", attaquant, weaponId) : le geste de l'attaquant, animé ICI pour tout le monde (bras, coude, torse) —
--     revers pour la claque, coup par-dessus la tête pour la poêle, bâton frappé au sol pour l'onde — avec une
--     traînée blanche derrière l'arme.
--   ("Hit", victime, weaponId) : onomatopée de BD ("PAF !"), gerbe d'étoiles et étoiles qui tournent au-dessus de la
--     tête pendant le KO. (La victime elle-même tourne dans les airs : client/InteractionController.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Joints = require(script.Parent.Joints)

local WEAPONS = Config.Weapons.List
local player = Players.LocalPlayer

local effectsGui = Instance.new("ScreenGui")
effectsGui.Name = "WeaponFx"
effectsGui.ResetOnSpawn = false
effectsGui.Parent = player:WaitForChild("PlayerGui")

----------------------------------------------------------------------
-- Gestes (images clés : t de 0 à 1, angles en degrés)
--   pitch : bras levé vers l'avant (90 = tendu devant, 180 = au-dessus de la tête)
--   yaw   : bras vers l'extérieur (< 0) ou en travers du corps (> 0)
--   elbow : coude plié ; waist : rotation du torse
----------------------------------------------------------------------

type Key = { t: number, pitch: number, yaw: number, elbow: number, waist: number }

local SWINGS: { [string]: { Key } } = {
	Slap = {
		{ t = 0, pitch = 90, yaw = 0, elbow = 0, waist = 0 },
		{ t = 0.4, pitch = 100, yaw = -80, elbow = 40, waist = -25 },
		{ t = 0.55, pitch = 85, yaw = 75, elbow = 0, waist = 30 },
		{ t = 1, pitch = 90, yaw = 0, elbow = 0, waist = 0 },
	},
	Smash = {
		{ t = 0, pitch = 90, yaw = 0, elbow = 0, waist = 0 },
		{ t = 0.45, pitch = 175, yaw = -10, elbow = 50, waist = -10 },
		{ t = 0.6, pitch = 35, yaw = 10, elbow = 0, waist = 15 },
		{ t = 1, pitch = 90, yaw = 0, elbow = 0, waist = 0 },
	},
	Slam = {
		{ t = 0, pitch = 90, yaw = 0, elbow = 0, waist = 0 },
		{ t = 0.5, pitch = 180, yaw = 0, elbow = 30, waist = 0 },
		{ t = 0.65, pitch = 15, yaw = 0, elbow = 0, waist = 0 },
		{ t = 1, pitch = 90, yaw = 0, elbow = 0, waist = 0 },
	},
}

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

local function sample(keys: { Key }, t: number): Key
	for index = 1, #keys - 1 do
		local a, b = keys[index], keys[index + 1]
		if t <= b.t then
			local k = smooth(math.clamp((t - a.t) / math.max(b.t - a.t, 1e-3), 0, 1))
			return {
				t = t,
				pitch = a.pitch + (b.pitch - a.pitch) * k,
				yaw = a.yaw + (b.yaw - a.yaw) * k,
				elbow = a.elbow + (b.elbow - a.elbow) * k,
				waist = a.waist + (b.waist - a.waist) * k,
			}
		end
	end
	return keys[#keys]
end

type Swing = { character: Model, keys: { Key }, start: number, duration: number, trail: Trail? }
local swings: { [Model]: Swing } = {}

-- Traînée blanche derrière l'arme tenue (créée localement, détruite à la fin du geste).
local function addTrail(character: Model): Trail?
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return nil
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, 0)
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 3, 0)
	a1.Parent = handle
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.18
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.FaceCamera = true
	trail.Parent = handle
	trail.Destroying:Once(function()
		a0:Destroy()
		a1:Destroy()
	end)
	return trail
end

local function playSwing(attacker: Player, weaponId: string)
	local def = WEAPONS[weaponId]
	local character = attacker.Character
	if not def or not character then
		return
	end
	local old = swings[character]
	if old and old.trail then
		old.trail:Destroy()
	end
	swings[character] = {
		character = character,
		keys = SWINGS[def.Swing] or SWINGS.Slap,
		start = os.clock(),
		duration = def.SwingTime,
		trail = addTrail(character),
	}
end

RunService.Stepped:Connect(function()
	local now = os.clock()
	for character, swing in pairs(swings) do
		local t = (now - swing.start) / swing.duration
		if t >= 1 or not character.Parent then
			swings[character] = nil
			if swing.trail then
				swing.trail:Destroy()
			end
			continue
		end
		local pose = sample(swing.keys, t)
		local shoulder = Joints.get(character, "RightUpperArm", "RightShoulder")
		if shoulder then
			shoulder.Transform = CFrame.Angles(0, math.rad(pose.yaw), 0) * CFrame.Angles(math.rad(pose.pitch), 0, 0)
		end
		local elbow = Joints.get(character, "RightLowerArm", "RightElbow")
		if elbow then
			elbow.Transform = CFrame.Angles(math.rad(pose.elbow), 0, 0)
		end
		local waist = Joints.get(character, "UpperTorso", "Waist")
		if waist then
			waist.Transform = CFrame.Angles(0, math.rad(pose.waist), 0)
		end
	end
end)

----------------------------------------------------------------------
-- Impact sur la victime
----------------------------------------------------------------------

local WORD_COLORS = { Color3.fromRGB(255, 230, 60), Color3.fromRGB(255, 120, 60), Color3.fromRGB(120, 230, 255) }

local function comicWord(head: BasePart, word: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(220, 90)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.2, 0.2)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = word
	label.TextColor3 = WORD_COLORS[math.random(1, #WORD_COLORS)]
	label.Rotation = math.random(-15, 15)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Parent = label
	label.Parent = billboard
	billboard.Parent = effectsGui

	TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
	task.delay(0.45, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(billboard, fade, { StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 1.5, 0) }):Play()
	end)
	task.delay(0.9, function()
		billboard:Destroy()
	end)
end

local function starBurst(root: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120))
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(12, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(1.2, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(24)
	task.delay(1, function()
		attachment:Destroy()
	end)
end

-- Étoiles qui tournent au-dessus de la tête pendant le KO.
local function dizzy(head: BasePart, duration: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(90, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	local stars: { ImageLabel } = {}
	for index = 1, 3 do
		local star = Icons.image(billboard, "Sparkle", UDim2.fromOffset(if index == 2 then 30 else 24, if index == 2 then 30 else 24))
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		stars[index] = star
	end
	billboard.Parent = effectsGui
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		if elapsed > duration or not head.Parent then
			connection:Disconnect()
			billboard:Destroy()
			return
		end
		for index, star in ipairs(stars) do
			local angle = elapsed * 6 + index * (math.pi * 2 / 3)
			star.Position = UDim2.new(0.5, math.cos(angle) * 32, 0.5, math.sin(angle) * 9)
		end
	end)
end

local function playHit(victim: Player, weaponId: string)
	local def = WEAPONS[weaponId]
	local character = victim.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not def or not head or not head:IsA("BasePart") then
		return
	end
	comicWord(head, def.Word)
	if root and root:IsA("BasePart") then
		starBurst(root)
	end
	dizzy(head, def.Stun + 0.6)
end

Remotes.WeaponFx.OnClientEvent:Connect(function(kind: string, target: Player, weaponId: string)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or type(weaponId) ~= "string" then
		return
	end
	if kind == "Swing" then
		playSwing(target, weaponId)
	elseif kind == "Hit" then
		playHit(target, weaponId)
	end
end)
