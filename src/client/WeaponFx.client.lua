--!strict
-- WeaponFx : tout ce qu'on voit et entend des deux armes (server/WeaponController décide, ce script anime).
--   BATTE
--     - Batte en main : posée sur l'épaule.
--     - ("Swing", attaquant) : grand coup à deux mains (élan en arrière, torse qui pivote, coup, accompagnement,
--       retour), traînée blanche derrière la batte. Animé ici pour tout le monde.
--     - ("Hit", victime, _, attaquant) : micro-pause du geste à l'impact (le coup « porte »), flash, onomatopée,
--       gerbe d'étoiles, étoiles qui tournent pendant le KO, coup de zoom pour l'attaquant.
--       (La victime part en vrille : client/InteractionController ; secousse : client/Effects.)
--   GRAPPIN
--     - Grappin en main : bras tendu vers la visée, viseur, le joueur qui serait attrapé est entouré (même règles que
--       le serveur : cône, portée, pas de mur, pas dans sa propre base). Clic -> Remotes.UseGrapple(direction).
--     - ("Grapple", tireur, _, point, victime?) : le crochet part du canon avec sa corde, accroche la victime, la
--       suit pendant qu'elle est ramenée, puis revient dans le canon. Raté : il va jusqu'au point et revient.
--     - Remotes.Grappled (pour la victime) : ce client ramène son propre personnage devant le tireur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Joints = require(script.Parent.Joints)
local Sounds = require(script.Parent.Sounds)

local BAT = Config.Weapons.Bat
local GRAPPLE = Config.Weapons.Grapple
local BAT_ID = "WeaponBat"
local GRAPPLE_ID = "WeaponGrapple"
local WHITE = Color3.new(1, 1, 1)
local ROPE = Color3.fromRGB(120, 80, 48)
local STEEL = Color3.fromRGB(200, 205, 215)

local player = Players.LocalPlayer

local effectsGui = Instance.new("ScreenGui")
effectsGui.Name = "WeaponFx"
effectsGui.ResetOnSpawn = false
effectsGui.Parent = player:WaitForChild("PlayerGui")

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function heldTool(character: Model?, weaponId: string): Tool?
	local tool = character and character:FindFirstChildOfClass("Tool")
	return if tool and tool:GetAttribute("WeaponId") == weaponId then tool else nil
end

----------------------------------------------------------------------
-- Poses (angles en degrés)
--   pitch : bras levé vers l'avant (90 = tendu devant, 180 = au-dessus de la tête)
--   yaw   : direction du bras (> 0 vers la gauche du personnage, < 0 vers la droite)
--   elbow : coude plié ; waist : rotation du torse
----------------------------------------------------------------------

type Pose = { rPitch: number, rYaw: number, rElbow: number, lPitch: number, lYaw: number, lElbow: number, waist: number }
type Key = { t: number, pose: Pose }

local function pose(rPitch: number, rYaw: number, rElbow: number, lPitch: number, lYaw: number, lElbow: number, waist: number): Pose
	return { rPitch = rPitch, rYaw = rYaw, rElbow = rElbow, lPitch = lPitch, lYaw = lYaw, lElbow = lElbow, waist = waist }
end

-- Batte posée sur l'épaule droite.
local BAT_REST = pose(45, -25, 160, 20, 10, 20, 0)

-- Grand coup à deux mains : élan à droite en arrière, coup qui balaie devant, accompagnement à gauche.
local BAT_SWING: { Key } = {
	{ t = 0, pose = BAT_REST },
	{ t = 0.3, pose = pose(95, -130, 20, 90, -110, 40, -50) }, -- élan : batte loin en arrière à droite, torse tourné
	{ t = 0.45, pose = pose(92, 0, 5, 92, 10, 15, 10) }, -- impact : bras tendus devant
	{ t = 0.6, pose = pose(85, 110, 15, 80, 115, 25, 55) }, -- accompagnement
	{ t = 1, pose = BAT_REST },
}

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

local function lerpPose(a: Pose, b: Pose, k: number): Pose
	return pose(
		a.rPitch + (b.rPitch - a.rPitch) * k,
		a.rYaw + (b.rYaw - a.rYaw) * k,
		a.rElbow + (b.rElbow - a.rElbow) * k,
		a.lPitch + (b.lPitch - a.lPitch) * k,
		a.lYaw + (b.lYaw - a.lYaw) * k,
		a.lElbow + (b.lElbow - a.lElbow) * k,
		a.waist + (b.waist - a.waist) * k
	)
end

local function sample(keys: { Key }, t: number): Pose
	for index = 1, #keys - 1 do
		local a, b = keys[index], keys[index + 1]
		if t <= b.t then
			-- L'élan démarre doucement, le coup part sec (pas d'adoucissement sur la frappe).
			local raw = math.clamp((t - a.t) / math.max(b.t - a.t, 1e-3), 0, 1)
			local k = if index == 2 then raw * raw else smooth(raw)
			return lerpPose(a.pose, b.pose, k)
		end
	end
	return keys[#keys].pose
end

local function apply(character: Model, p: Pose, withLeft: boolean)
	local rShoulder = Joints.get(character, "RightUpperArm", "RightShoulder")
	if rShoulder then
		rShoulder.Transform = CFrame.Angles(0, math.rad(p.rYaw), 0) * CFrame.Angles(math.rad(p.rPitch), 0, 0)
	end
	local rElbow = Joints.get(character, "RightLowerArm", "RightElbow")
	if rElbow then
		rElbow.Transform = CFrame.Angles(math.rad(p.rElbow), 0, 0)
	end
	if withLeft then
		local lShoulder = Joints.get(character, "LeftUpperArm", "LeftShoulder")
		if lShoulder then
			lShoulder.Transform = CFrame.Angles(0, math.rad(p.lYaw), 0) * CFrame.Angles(math.rad(p.lPitch), 0, 0)
		end
		local lElbow = Joints.get(character, "LeftLowerArm", "LeftElbow")
		if lElbow then
			lElbow.Transform = CFrame.Angles(math.rad(p.lElbow), 0, 0)
		end
	end
	local waist = Joints.get(character, "UpperTorso", "Waist")
	if waist and p.waist ~= 0 then
		waist.Transform = CFrame.Angles(0, math.rad(p.waist), 0)
	end
end

----------------------------------------------------------------------
-- Batte : coup
----------------------------------------------------------------------

type Swing = { start: number, trail: Trail? }
local swings: { [Model]: Swing } = {}
local recoils: { [Model]: number } = {} -- grappin : heure du tir (recul du bras)

-- Traînée derrière la batte (créée une fois par batte, allumée pendant le coup).
local function batTrail(tool: Tool): Trail?
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return nil
	end
	local existing = handle:FindFirstChild("SwingTrail")
	if existing and existing:IsA("Trail") then
		return existing
	end
	local a0 = handle:FindFirstChild("TrailBottom")
	local a1 = handle:FindFirstChild("TrailTop")
	if not a0 or not a1 or not a0:IsA("Attachment") or not a1:IsA("Attachment") then
		return nil
	end
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.16
	trail.LightEmission = 0.7
	trail.Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 230, 150))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = handle
	return trail
end

local function playSwing(attacker: Player)
	local character = attacker.Character
	local tool = heldTool(character, BAT_ID)
	if not character or not tool then
		return
	end
	local trail = batTrail(tool)
	if trail then
		trail.Enabled = true
	end
	swings[character] = { start = os.clock(), trail = trail }
end

-- Réglage des gestes : l'attribut Workspace "WeaponFxSlowMotion" (ex. 10) ralentit le coup de batte pour le regarder.
local function swingDuration(): number
	local slow = Workspace:GetAttribute("WeaponFxSlowMotion")
	return BAT.SwingTime * (if type(slow) == "number" and slow > 0 then slow else 1)
end

RunService.Stepped:Connect(function()
	local now = os.clock()
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if not character then
			continue
		end
		local swing = swings[character]
		if swing then
			local t = (now - swing.start) / swingDuration()
			if t >= 1 then
				swings[character] = nil
				if swing.trail then
					swing.trail.Enabled = false
				end
			else
				-- La traînée ne brille que pendant la frappe elle-même.
				if swing.trail then
					swing.trail.Enabled = t > 0.32 and t < 0.66
				end
				apply(character, sample(BAT_SWING, math.max(t, 0)), true)
				continue
			end
		end
		if heldTool(character, BAT_ID) then
			apply(character, BAT_REST, false)
		elseif heldTool(character, GRAPPLE_ID) then
			-- Bras tendu vers la visée, avec un recul quand le crochet part.
			local fired = recoils[character]
			local kick = if fired then math.max(0, 1 - (now - fired) / 0.3) else 0
			apply(character, pose(92 + kick * 30, 0, kick * 25, 0, 0, 0, 0), false)
		end
	end
end)

----------------------------------------------------------------------
-- Batte : impact
----------------------------------------------------------------------

local WORD_COLORS = { Color3.fromRGB(255, 230, 60), Color3.fromRGB(255, 120, 60), Color3.fromRGB(120, 230, 255) }

local function comicWord(head: BasePart, word: string, color: Color3?)
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(240, 96)
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
	label.TextColor3 = color or WORD_COLORS[math.random(1, #WORD_COLORS)]
	label.Rotation = math.random(-15, 15)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Parent = label
	label.Parent = billboard
	billboard.Parent = effectsGui
	TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
	task.delay(0.5, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(billboard, fade, { StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 1.5, 0) }):Play()
	end)
	task.delay(0.95, function()
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
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(1.3, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(28)
	task.delay(1, function()
		attachment:Destroy()
	end)
end

-- Flash blanc qui gonfle et s'efface au point d'impact.
local function impactFlash(position: Vector3)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 1.5
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = WHITE
	flash.Transparency = 0.1
	flash.Parent = Workspace
	local tween = TweenService:Create(flash, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 7, Transparency = 1 })
	tween.Completed:Once(function()
		flash:Destroy()
	end)
	tween:Play()
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

-- Petit coup de zoom de la caméra (l'attaquant « sent » son coup).
local function cameraPunch(amount: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local base = camera.FieldOfView
	camera.FieldOfView = base - amount
	TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base }):Play()
end

local function playHit(victim: Player, attacker: Player?)
	local character = victim.Character
	local head = character and character:FindFirstChild("Head")
	local root = rootOf(character)
	if not head or not head:IsA("BasePart") then
		return
	end
	-- Micro-pause du geste de l'attaquant : le coup « porte ».
	local attackerCharacter = attacker and attacker.Character
	local swing = attackerCharacter and swings[attackerCharacter]
	if swing then
		swing.start += 0.07
	end
	if attacker == player then
		cameraPunch(6)
	end
	comicWord(head, BAT.Word)
	if root then
		starBurst(root)
		impactFlash(root.Position)
	end
	dizzy(head, BAT.Stun + 0.6)
end

----------------------------------------------------------------------
-- Grappin : crochet et corde
----------------------------------------------------------------------

local function setClawHidden(tool: Tool, hidden: boolean)
	local claw = tool:FindFirstChild("Claw")
	if not claw then
		return
	end
	for _, part in ipairs(claw:GetDescendants()) do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- Copie volante du crochet (boule + trois griffes), pointée vers l'avant (-Z).
local function makeFlyingClaw(): (Model, Attachment)
	local model = Instance.new("Model")
	model.Name = "GrappleHook"
	local function part(size: Vector3, shape: Enum.PartType): Part
		local p = Instance.new("Part")
		p.Size = size
		p.Shape = shape
		p.Color = STEEL
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
		return p
	end
	local hub = part(Vector3.one * 0.5, Enum.PartType.Ball)
	hub.Name = "Hub"
	model.PrimaryPart = hub
	for index = 0, 2 do
		local prong = part(Vector3.new(0.16, 0.16, 0.7), Enum.PartType.Block)
		prong:SetAttribute("Offset", CFrame.Angles(0, 0, index * math.pi * 2 / 3) * CFrame.new(0, 0.22, -0.28) * CFrame.Angles(math.rad(35), 0, 0))
	end
	local anchor = Instance.new("Attachment")
	anchor.Parent = hub
	model.Parent = Workspace
	return model, anchor
end

local function placeClaw(model: Model, cframe: CFrame)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset")
			child.CFrame = if typeof(offset) == "CFrame" then cframe * offset else cframe
		end
	end
end

local function playGrapple(shooter: Player, point: Vector3, victim: Player?)
	local character = shooter.Character
	local tool = heldTool(character, GRAPPLE_ID)
	local handle = tool and tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	if not character or not tool or not muzzle or not muzzle:IsA("Attachment") then
		return
	end
	recoils[character] = os.clock()
	setClawHidden(tool, true)
	local claw, anchor = makeFlyingClaw()
	local rope = Instance.new("Beam")
	rope.Attachment0 = muzzle
	rope.Attachment1 = anchor
	rope.Color = ColorSequence.new(ROPE)
	rope.Width0 = 0.16
	rope.Width1 = 0.16
	rope.Segments = 16
	rope.FaceCamera = true
	rope.LightInfluence = 1
	rope.Parent = claw

	local victimRoot = if victim then rootOf(victim.Character) else nil
	local function target(): Vector3
		return if victimRoot and victimRoot.Parent then victimRoot.Position else point
	end
	local flight = math.max((target() - muzzle.WorldPosition).Magnitude / GRAPPLE.HookSpeed, 0.06)
	local start = os.clock()
	local phase = "fly"
	local holdUntil = 0
	local reel: Sound? = nil
	local retractFrom = Vector3.zero

	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local from = muzzle.WorldPosition
		if not muzzle.Parent then
			phase = "done"
		end
		if phase == "fly" then
			local alpha = math.clamp((now - start) / flight, 0, 1)
			local position = from:Lerp(target(), alpha)
			placeClaw(claw, CFrame.lookAt(position, target() + (target() - from).Unit))
			-- La corde se tend en vol (petite ondulation au départ).
			rope.CurveSize0 = (1 - alpha) * 1.2
			rope.CurveSize1 = -(1 - alpha) * 1.2
			if alpha >= 1 then
				if victimRoot then
					phase = "pull"
					holdUntil = now + GRAPPLE.PullTime
					local victimHead = victim and victim.Character and victim.Character:FindFirstChild("Head")
					if victimHead and victimHead:IsA("BasePart") then
						comicWord(victimHead, "CHOPÉ !", Color3.fromRGB(120, 230, 255))
					end
					if shooter == player then
						cameraPunch(4)
					end
					reel = Instance.new("Sound")
					local def = Config.Sounds.Effects.GrappleReel
					local sound = reel :: Sound
					sound.SoundId = "rbxassetid://" .. def.Id
					sound.Volume = def.Volume or 1
					sound.PlaybackSpeed = def.Pitch or 1
					sound.Looped = true
					sound.RollOffMaxDistance = 120
					sound.Parent = handle
					sound:Play()
				else
					phase = "hold"
					holdUntil = now + 0.12
				end
			end
		elseif phase == "pull" then
			local position = target()
			placeClaw(claw, CFrame.lookAt(position, position + (position - from).Unit))
			rope.CurveSize0 = 0
			rope.CurveSize1 = 0
			local close = (position - from).Magnitude < GRAPPLE.StopDistance + 3
			if now >= holdUntil or close then
				phase = "retract"
				retractFrom = position
				start = now
			end
		elseif phase == "hold" then
			if now >= holdUntil then
				phase = "retract"
				retractFrom = point
				start = now
			end
		elseif phase == "retract" then
			local alpha = math.clamp((now - start) / 0.18, 0, 1)
			local position = retractFrom:Lerp(from, smooth(alpha))
			placeClaw(claw, CFrame.lookAt(position, position + (retractFrom - from).Unit))
			if alpha >= 1 then
				phase = "done"
			end
		end
		if phase == "done" then
			connection:Disconnect()
			claw:Destroy()
			if reel then
				reel:Destroy()
			end
			if tool.Parent then
				setClawHidden(tool, false)
			end
		end
	end)
end

----------------------------------------------------------------------
-- Grappin : traction de la victime (ce client tire son propre personnage)
----------------------------------------------------------------------

local pullToken = 0
Remotes.Grappled.OnClientEvent:Connect(function(shooter: Player, duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(character)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") or type(duration) ~= "number" or not humanoid or not root then
		return
	end
	pullToken += 1
	local token = pullToken
	humanoid.PlatformStand = true
	cameraPunch(5)
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local shooterRoot = rootOf(shooter.Character)
		local elapsed = os.clock() - start
		if token ~= pullToken or not shooterRoot or not root.Parent or elapsed > duration then
			connection:Disconnect()
			if token == pullToken and humanoid.Parent then
				root.AssemblyLinearVelocity = root.AssemblyLinearVelocity * 0.2
				humanoid.PlatformStand = false
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			return
		end
		local flat = Vector3.new(root.Position.X - shooterRoot.Position.X, 0, root.Position.Z - shooterRoot.Position.Z)
		local away = if flat.Magnitude > 0.1 then flat.Unit else shooterRoot.CFrame.LookVector
		local goal = shooterRoot.Position + away * GRAPPLE.StopDistance
		local delta = goal - root.Position
		if delta.Magnitude < 2 then
			pullToken += 1 -- arrivé : on relâche tout de suite
			root.AssemblyLinearVelocity = Vector3.zero
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			connection:Disconnect()
			return
		end
		local speed = math.min(GRAPPLE.PullSpeed, delta.Magnitude * 10)
		-- Petit saut au début pour décoller du sol, puis vol en ligne droite vers le tireur.
		local lift = if elapsed < 0.2 then 22 else math.clamp(delta.Y * 6, -10, 18) + 4
		root.AssemblyLinearVelocity = Vector3.new(delta.Unit.X * speed, lift, delta.Unit.Z * speed)
	end)
end)

----------------------------------------------------------------------
-- Grappin : visée et tir (joueur local)
----------------------------------------------------------------------

local mouse = player:GetMouse()
local highlight = Instance.new("Highlight")
highlight.Name = "GrappleTarget"
highlight.FillColor = Color3.fromRGB(70, 170, 255)
highlight.FillTransparency = 0.6
highlight.OutlineColor = WHITE
highlight.OutlineTransparency = 0
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled = false
highlight.Parent = effectsGui

local function inOwnBase(other: Player, position: Vector3): boolean
	local index = other:GetAttribute("BaseIndex")
	local map = Workspace:FindFirstChild("Map")
	local base = map and type(index) == "number" and map:FindFirstChild("Base_" .. index)
	local platform = base and base:FindFirstChild("BasePart")
	if not platform or not platform:IsA("BasePart") then
		return false
	end
	local localPosition = platform.CFrame:PointToObjectSpace(position)
	local half = platform.Size / 2 + Vector3.new(1.5, 0, 1.5)
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y > -3 and localPosition.Y < 25
end

local function aimDirection(head: BasePart): Vector3
	local offset = mouse.Hit.Position - head.Position
	if offset.Magnitude < 1 then
		local camera = Workspace.CurrentCamera
		return if camera then camera.CFrame.LookVector else head.CFrame.LookVector
	end
	return offset.Unit
end

-- Même choix que le serveur (server/WeaponController.onUseGrapple).
local function findTarget(head: BasePart, aim: Vector3): Player?
	local cone = math.cos(math.rad(GRAPPLE.AimCone))
	local best: Player? = nil
	local bestScore = -math.huge
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = rootOf(other.Character)
		local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
		if other ~= player and otherRoot and humanoid and humanoid.Health > 0 then
			local offset = otherRoot.Position - head.Position
			local distance = offset.Magnitude
			local dot = if distance > 0 then aim:Dot(offset.Unit) else -1
			if distance <= GRAPPLE.Range and dot >= cone and not inOwnBase(other, otherRoot.Position) then
				params.FilterDescendantsInstances = { player.Character :: Model, other.Character :: Model }
				local score = dot - distance / 1000
				if score > bestScore and not Workspace:Raycast(head.Position, offset, params) then
					best = other
					bestScore = score
				end
			end
		end
	end
	return best
end

local DEFAULT_ICON = ""
local CROSSHAIR = "rbxasset://textures/GunCursor.png"
local equippedGrapple: Tool? = nil

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local tool = heldTool(character, GRAPPLE_ID)
	local head = character and character:FindFirstChild("Head")
	if tool ~= equippedGrapple then
		equippedGrapple = tool
		mouse.Icon = if tool then CROSSHAIR else DEFAULT_ICON
	end
	if not tool or not head or not head:IsA("BasePart") or not tool.Enabled then
		highlight.Enabled = false
		return
	end
	local target = findTarget(head, aimDirection(head))
	highlight.Adornee = if target then target.Character else nil
	highlight.Enabled = target ~= nil
end)

local function watchTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("WeaponId") ~= GRAPPLE_ID or tool:GetAttribute("GrappleWired") then
		return
	end
	tool:SetAttribute("GrappleWired", true)
	tool.Activated:Connect(function()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not tool.Enabled or not head or not head:IsA("BasePart") then
			if not tool.Enabled then
				Sounds.play("Error")
			end
			return
		end
		Remotes.UseGrapple:FireServer(aimDirection(head))
	end)
end

local function watchContainer(container: Instance)
	container.ChildAdded:Connect(watchTool)
	for _, child in ipairs(container:GetChildren()) do
		watchTool(child)
	end
end

player.CharacterAdded:Connect(watchContainer)
if player.Character then
	watchContainer(player.Character)
end
task.spawn(function()
	watchContainer(player:WaitForChild("Backpack"))
end)
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		watchContainer(child)
	end
end)

----------------------------------------------------------------------
-- Réception des effets
----------------------------------------------------------------------

Remotes.WeaponFx.OnClientEvent:Connect(function(kind: string, target: Player, weaponId: string, extra: unknown, extra2: unknown)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or type(weaponId) ~= "string" then
		return
	end
	if kind == "Swing" then
		playSwing(target)
	elseif kind == "Hit" then
		local attacker = if typeof(extra) == "Instance" and (extra :: Instance):IsA("Player") then extra :: Player else nil
		playHit(target, attacker)
	elseif kind == "Grapple" and typeof(extra) == "Vector3" then
		local victim = if typeof(extra2) == "Instance" and (extra2 :: Instance):IsA("Player") then extra2 :: Player else nil
		playGrapple(target, extra :: Vector3, victim)
	end
end)
