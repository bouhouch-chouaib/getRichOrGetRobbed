--!strict
-- Client-created cosmetics. Ownership comes from the server's saved Upgrade_AstralAura attribute.
local Config = require(script.Parent.Config)
local Aura = {}
local C = Config.PlayerAura
local CF, V = CFrame.new, Vector3.new
export type Rig = {
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	folder: Folder,
	attachments: { Attachment },
	particles: { ParticleEmitter },
	trails: { Trail },
	shards: { BasePart },
	light: PointLight,
	last: Vector3,
	visible: boolean,
	running: boolean,
}

function Aura.CanShow(
	owned: boolean,
	health: number,
	invisibleUntil: number,
	now: number,
	distance: number,
	firstPerson: boolean
): boolean
	return owned and health > 0 and invisibleUntil <= now and distance <= C.ViewDistance and not firstPerson
end

function Aura.IsRunning(speed: number, grounded: boolean, seated: boolean): boolean
	return speed >= C.RunSpeed and grounded and not seated
end

local function attachment(parent: BasePart, position: Vector3, list: { Attachment }): Attachment
	local a = Instance.new("Attachment")
	a.Name = "AstralAuraAttachment"
	a.Position = position
	a.Parent = parent
	table.insert(list, a)
	return a
end

function Aura.Create(character: Model): Rig?
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "AstralAura"
	folder.Parent = character
	local rig: Rig = {
		character = character,
		root = root,
		humanoid = humanoid,
		folder = folder,
		attachments = {},
		particles = {},
		trails = {},
		shards = {},
		light = Instance.new("PointLight"),
		last = root.CFrame.Position,
		visible = false,
		running = false,
	}
	local center = attachment(root, V(0, 0, 0), rig.attachments)
	local glow = Instance.new("ParticleEmitter")
	glow.Name = "AstralMotes"
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Color = ColorSequence.new(C.Primary, C.Secondary)
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Rate = 12
	glow.Lifetime = NumberRange.new(0.7, 1.25)
	glow.Speed = NumberRange.new(0.6, 1.7)
	glow.Acceleration = V(0, 1.2, 0)
	glow.SpreadAngle = Vector2.new(180, 180)
	glow.Rotation = NumberRange.new(-180, 180)
	glow.RotSpeed = NumberRange.new(-50, 50)
	glow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.32),
		NumberSequenceKeypoint.new(1, 0),
	})
	glow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	glow.Enabled = false
	glow.Parent = center
	table.insert(rig.particles, glow)
	rig.light.Color = C.Primary
	rig.light.Range = 7
	rig.light.Brightness = 0.7
	rig.light.Shadows = false
	rig.light.Enabled = false
	rig.light.Parent = center
	local function trail(parent: BasePart, position: Vector3, width: number, color: Color3)
		local ribbon = Instance.new("Trail")
		ribbon.Name = "AstralRunTrail"
		ribbon.Attachment0 = attachment(parent, position - V(width / 2, 0, 0), rig.attachments)
		ribbon.Attachment1 = attachment(parent, position + V(width / 2, 0, 0), rig.attachments)
		ribbon.Color = ColorSequence.new(color, C.Secondary)
		ribbon.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.55, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		ribbon.WidthScale = NumberSequence.new(1, 0)
		ribbon.Lifetime = C.TrailLifetime
		ribbon.MinLength = 0.08
		ribbon.FaceCamera = true
		ribbon.LightEmission = 1
		ribbon.LightInfluence = 0
		ribbon.Enabled = false
		ribbon.Parent = folder
		table.insert(rig.trails, ribbon)
	end
	trail(root, V(0, 0.1, root.Size.Z / 2 + 0.1), root.Size.X * 0.7, C.Primary)
	for _, names in ipairs({ { "LeftFoot", "Left Leg" }, { "RightFoot", "Right Leg" } }) do
		local foot = character:FindFirstChild(names[1]) or character:FindFirstChild(names[2])
		if foot and foot:IsA("BasePart") then
			trail(foot, V(0, -foot.Size.Y * 0.35, 0.1), foot.Size.X * 0.45, C.Secondary)
		end
	end
	for index = 1, 6 do
		local shard = Instance.new("Part")
		shard.Name = "AstralCrystal"
		shard.Size = V(0.16, 0.3, 0.16)
		shard.Color = if index % 2 == 0 then C.Primary else C.Secondary
		shard.Material = Enum.Material.Neon
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanTouch = false
		shard.CanQuery = false
		shard.CastShadow = false
		shard.Massless = true
		shard.Transparency = 1
		shard.CFrame = root.CFrame
		shard.Parent = folder
		table.insert(rig.shards, shard)
	end
	return rig
end

function Aura.Update(rig: Rig, now: number, visible: boolean, running: boolean)
	local position = rig.root.CFrame.Position
	local teleported = (position - rig.last).Magnitude > C.TeleportDistance
	rig.last = position
	if visible ~= rig.visible then
		for _, particle in ipairs(rig.particles) do
			particle.Enabled = visible
			if not visible then
				particle:Clear()
			end
		end
		rig.light.Enabled = visible
		for _, shard in ipairs(rig.shards) do
			shard.Transparency = if visible then 0.12 else 1
		end
		rig.visible = visible
	end
	local leaveTrail = visible and running and not teleported
	for _, trail in ipairs(rig.trails) do
		trail.Enabled = leaveTrail
		-- Stopping lets the short ribbon fade naturally. Hiding/teleporting clears it immediately.
		if not visible or teleported then
			trail:Clear()
		end
	end
	rig.running = leaveTrail
	if not visible then
		return
	end
	local radius = rig.root.Size.X * 0.5 + 0.6
	local phase = now * 1.5
	for index, shard in ipairs(rig.shards) do
		local angle = phase + (index - 1) * math.pi / 3
		shard.CFrame = rig.root.CFrame
			* CF(math.cos(angle) * radius, math.sin(angle * 2 + now) * 0.85, math.sin(angle) * radius)
			* CFrame.Angles(0, -angle, math.pi / 4 + math.sin(now * 2 + index) * 0.12)
	end
	rig.light.Brightness = 0.55 + math.sin(now * 2) * 0.15
end

function Aura.Destroy(rig: Rig)
	rig.folder:Destroy()
	for _, a in ipairs(rig.attachments) do
		a:Destroy()
	end
end

return Aura
