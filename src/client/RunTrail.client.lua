--!strict
-- Traînée de chaque joueur quand il court, de la même forme que dans Steal an Egg (Config.RunTrail) : un ruban blanc
-- accroché à la taille, plus quelques traits de vent fins autour du corps qui ondulent. Un Trail ne laisse rien à
-- l'arrêt ; les traits de vent attendent en plus une vraie course (Wind.MinSpeed). Tout est caché pendant
-- l'invisibilité (attribut "InvisibleUntil") et pour qui a l'Aura astrale achetée (elle a déjà sa traînée).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(RS.Shared.Config)
local Perks = require(RS.Shared.Perks)

local C = Config.RunTrail
local W = C.Wind

type Wind = { trail: Trail, a0: Attachment, a1: Attachment, base: Vector3, phase: number }
type Rig = { character: Model, root: BasePart, trail: Trail, wind: { Wind }, attachments: { Attachment }, last: Vector3 }
local rigs: { [Player]: Rig } = {}

local function attach(root: BasePart, name: string, position: Vector3, list: { Attachment }): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = root
	table.insert(list, a)
	return a
end

local function ribbon(root: BasePart, name: string, a0: Attachment, a1: Attachment): Trail
	local trail = Instance.new("Trail")
	trail.Name = name
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.FaceCamera = true
	trail.MinLength = 0.05
	trail.LightEmission = C.LightEmission
	trail.LightInfluence = 0
	trail.Parent = root
	return trail
end

local function create(character: Model): Rig?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local attachments = {}
	local trail = ribbon(
		root,
		"RunTrail",
		attach(root, "RunTrailLeft", Vector3.new(-C.Width / 2, C.Height, 0.3), attachments),
		attach(root, "RunTrailRight", Vector3.new(C.Width / 2, C.Height, 0.3), attachments)
	)
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.Start),
		ColorSequenceKeypoint.new(0.06, C.Color),
		ColorSequenceKeypoint.new(1, C.Color),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = C.Lifetime
	local wind = {}
	for index, point in ipairs(W.Points) do
		local half = Vector3.new(0, W.Width / 2, 0)
		local a0 = attach(root, "RunWind", point - half, attachments)
		local a1 = attach(root, "RunWind", point + half, attachments)
		local line = ribbon(root, "RunWind", a0, a1)
		line.Color = ColorSequence.new(C.Color)
		line.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, W.Transparency),
			NumberSequenceKeypoint.new(1, 1),
		})
		-- Effilé vers l'arrière, longueurs un peu différentes d'un trait à l'autre.
		line.WidthScale = NumberSequence.new(1, 0.2)
		line.Lifetime = W.Lifetime * (0.8 + 0.1 * (index % 3))
		line.Enabled = false
		table.insert(wind, { trail = line, a0 = a0, a1 = a1, base = point, phase = index * 1.7 })
	end
	return { character = character, root = root, trail = trail, wind = wind, attachments = attachments, last = root.Position }
end

local function clear(player: Player)
	local rig = rigs[player]
	if rig then
		rig.trail:Destroy()
		for _, w in ipairs(rig.wind) do
			w.trail:Destroy()
		end
		for _, a in ipairs(rig.attachments) do
			a:Destroy()
		end
		rigs[player] = nil
	end
end

Players.PlayerRemoving:Connect(clear)

-- Ondulation des traits de vent, à chaque image (sinon ils font des marches d'escalier).
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, rig in pairs(rigs) do
		for _, w in ipairs(rig.wind) do
			if w.trail.Enabled then
				local offset = Vector3.new(0, math.sin(t * 11 + w.phase) * W.Wobble, 0)
				local half = Vector3.new(0, W.Width / 2, 0)
				w.a0.Position = w.base + offset - half
				w.a1.Position = w.base + offset + half
			end
		end
	end
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < C.UpdateInterval then
		return
	end
	elapsed = 0
	local now = Workspace:GetServerTimeNow()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rig: Rig? = rigs[player]
		if rig and (rig.character ~= character or not rig.root:IsDescendantOf(Workspace) or Perks.HasAura(player)) then
			clear(player)
			rig = nil
		end
		if not character or not character:IsDescendantOf(Workspace) or Perks.HasAura(player) then
			continue
		end
		local active = rig or create(character)
		if not active then
			continue
		end
		rigs[player] = active
		local invisible = player:GetAttribute("InvisibleUntil")
		local hidden = type(invisible) == "number" and invisible > now
		local position = active.root.Position
		-- Téléporté (réapparition, grappin...) ou caché : on efface d'un coup.
		local jumped = (position - active.last).Magnitude > C.TeleportDistance
		local velocity = active.root.AssemblyLinearVelocity
		local fast = not hidden and Vector3.new(velocity.X, 0, velocity.Z).Magnitude >= W.MinSpeed
		active.trail.Enabled = not hidden
		if hidden or jumped then
			active.trail:Clear()
		end
		for _, w in ipairs(active.wind) do
			w.trail.Enabled = fast
			if hidden or jumped then
				w.trail:Clear()
			end
		end
		active.last = position
	end
end)
