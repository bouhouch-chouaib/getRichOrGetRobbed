--!strict
-- Traînée (Vitesse) et aura (Force) gagnées par l'entraînement, construites côté client pour chaque joueur
-- (client/PowerFx). Paliers et réglages : Config.PowerFx.
-- Textures : formes nettes dessinées pour ces effets (assets/fx : flamme, anneau, trait, étoile, ruban), colorées
-- par palier. Un halo doux seul disparaît en plein jour. Aucune pièce Néon : rubans (Trail) et particules.
local Config = require(script.Parent.Config)

local PowerFx = {}
local C = Config.PowerFx
local V = Vector3.new
local RAYS = "rbxassetid://134050472288904" -- UiStyle.Textures.Rays
-- Rechange tant que les textures dessinées ne sont pas envoyées sur Roblox (Config.PowerFx.Textures vide).
local FALLBACK = {
	Flame = "rbxasset://textures/particles/fire_main.dds",
	Ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Streak = "rbxassetid://125220558210100", -- UiStyle.Textures.Glow
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Trail = "",
}

export type Rig = {
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	folder: Folder,
	speedTier: number,
	strengthTier: number,
	attachments: { Attachment },
	trails: { Trail },
	runEmitters: { ParticleEmitter }, -- seulement en courant (traits, étincelles)
	auraEmitters: { ParticleEmitter }, -- tant que l'effet est visible (flammes, sol, braises, rayons)
	burst: { ParticleEmitter }, -- émetteurs qui jaillissent quand on passe un palier
	last: Vector3,
	visible: boolean,
	running: boolean,
	rainbow: boolean,
}

local function localTextures(): boolean
	local ok, wanted = pcall(function()
		return game:GetService("RunService"):IsStudio() and workspace:GetAttribute("PowerFxLocalTextures") == true
	end)
	return ok and wanted == true
end

local function texture(name: string): string
	if localTextures() then
		return "rbxasset://claude_powerfx/" .. name .. ".png"
	end
	local id = (C.Textures :: { [string]: string })[name]
	return if id and id ~= "" then id else FALLBACK[name]
end

local function levelsOf(tiers: { any }): { number }
	local list = {}
	for _, tier in ipairs(tiers) do
		table.insert(list, tier.Level)
	end
	return list
end
local SPEED_LEVELS = levelsOf(C.Speed)
local STRENGTH_LEVELS = levelsOf(C.Strength)

-- Palier atteint (0 = aucun) pour un niveau donné.
local function tierFor(level: number, levels: { number }): number
	local index = 0
	for i, needed in ipairs(levels) do
		if level >= needed then
			index = i
		end
	end
	return index
end

function PowerFx.SpeedTier(level: number): number
	return tierFor(level, SPEED_LEVELS)
end

function PowerFx.StrengthTier(level: number): number
	return tierFor(level, STRENGTH_LEVELS)
end

-- Affiché seulement pour un joueur vivant, visible (pas invisible), assez proche, et pas en vue à la 1re personne.
function PowerFx.CanShow(health: number, invisibleUntil: number, now: number, distance: number, firstPerson: boolean): boolean
	return health > 0 and invisibleUntil <= now and distance <= C.ViewDistance and not firstPerson
end

function PowerFx.IsRunning(horizontalSpeed: number, seated: boolean): boolean
	return horizontalSpeed >= C.RunSpeed and not seated
end

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function attachment(rig: Rig, parent: BasePart, position: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = "PowerFxAttachment"
	a.Position = position
	a.Parent = parent
	table.insert(rig.attachments, a)
	return a
end

local function emitter(parent: Instance, name: string, image: string, glow: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = image
	-- Couleur peinte plus que lumière ajoutée : vérifié en Play, un effet lumineux pâlit jusqu'au blanc sur
	-- l'herbe en plein jour.
	e.LightEmission = glow
	e.LightInfluence = 0
	e.Brightness = 1
	e.Enabled = false
	e.Parent = parent
	return e
end

local function ribbon(rig: Rig, a0: Attachment, a1: Attachment, tier: Config.PowerSpeedTier, body: boolean): Trail
	local t = Instance.new("Trail")
	t.Name = if body then "PowerBodyTrail" else "PowerFootTrail"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Texture = texture("Trail")
	t.TextureMode = Enum.TextureMode.Stretch
	t.Color = ColorSequence.new(tier.Color0, tier.Color1)
	-- Le ruban du corps reste un voile ; les rubans des pieds portent la couleur.
	t.Transparency = if body then seq({ { 0, 0.35 }, { 0.5, 0.65 }, { 1, 1 } }) else seq({ { 0, 0 }, { 0.65, 0.45 }, { 1, 1 } })
	t.WidthScale = seq({ { 0, 1 }, { 1, if body then 0.35 else 0.15 } })
	t.Lifetime = if body then tier.Lifetime * 0.8 else tier.Lifetime
	t.MinLength = 0.1
	t.FaceCamera = not body
	t.LightEmission = C.LightEmission
	t.LightInfluence = 0
	t.Brightness = 1
	t.Enabled = false
	t.Parent = rig.folder
	table.insert(rig.trails, t)
	return t
end

-- Hauteur des pieds sous le centre du HumanoidRootPart (R15 : HipHeight ; R6 : jambes de 2 studs).
local function feetOffset(root: BasePart, humanoid: Humanoid): number
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	return -(root.Size.Y / 2 + legs)
end

function PowerFx.Create(character: Model, speedTier: number, strengthTier: number, rateScale: number): Rig?
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "PowerFx"
	folder.Parent = character
	local rig: Rig = {
		character = character,
		root = root,
		humanoid = humanoid,
		folder = folder,
		speedTier = speedTier,
		strengthTier = strengthTier,
		attachments = {},
		trails = {},
		runEmitters = {},
		auraEmitters = {},
		burst = {},
		last = root.CFrame.Position,
		visible = false,
		running = false,
		rainbow = false,
	}

	-- Volume invisible soudé au corps, des pieds aux épaules, plus large que lui : les flammes naissent sur son
	-- pourtour (nées dedans, le corps les cachait) et les traits de vitesse tout autour.
	local feet = feetOffset(root, humanoid)
	local top = 1.6
	local volume = Instance.new("Part")
	volume.Name = "PowerFxVolume"
	volume.Size = V(4.2, top - feet, 4.2)
	volume.Transparency = 1
	volume.CanCollide = false
	volume.CanTouch = false
	volume.CanQuery = false
	volume.CastShadow = false
	volume.Massless = true
	volume.CFrame = root.CFrame * CFrame.new(0, (top + feet) / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = volume
	weld.Parent = volume
	volume.Parent = folder
	local ground = attachment(rig, root, V(0, feet + 0.1, 0))

	if speedTier > 0 then
		local tier = C.Speed[speedTier]
		rig.rainbow = tier.Rainbow
		for _, names in ipairs({ { "LeftFoot", "Left Leg" }, { "RightFoot", "Right Leg" } }) do
			local foot = character:FindFirstChild(names[1]) or character:FindFirstChild(names[2])
			if foot and foot:IsA("BasePart") then
				local y = -foot.Size.Y * 0.35
				ribbon(rig, attachment(rig, foot, V(-tier.Width / 2, y, 0.1)), attachment(rig, foot, V(tier.Width / 2, y, 0.1)), tier, false)
			end
		end
		if tier.Body then
			-- Derrière le corps (+Z = dos du HumanoidRootPart), des épaules aux hanches.
			ribbon(rig, attachment(rig, root, V(0, 1.5, 0.45)), attachment(rig, root, V(0, -0.9, 0.45)), tier, true)
		end
		if tier.Lines > 0 then
			-- Traits de vent qui filent vers l'arrière autour du coureur.
			local lines = emitter(volume, "PowerSpeedLines", texture("Streak"), 0.3)
			lines.Shape = Enum.ParticleEmitterShape.Box
			lines.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			lines.EmissionDirection = Enum.NormalId.Back
			lines.Orientation = Enum.ParticleOrientation.VelocityParallel
			lines.Speed = NumberRange.new(10, 16)
			lines.Lifetime = NumberRange.new(0.18, 0.28)
			lines.Size = seq({ { 0, 0.9 }, { 1, 0.5 } })
			lines.Transparency = seq({ { 0, 0.2 }, { 1, 1 } })
			lines.Color = ColorSequence.new(Color3.new(1, 1, 1), tier.Color1)
			lines.Rate = tier.Lines * rateScale
			table.insert(rig.runEmitters, lines)
			table.insert(rig.burst, lines)
		end
		if tier.Sparks > 0 then
			local sparks = emitter(ground, "PowerSpeedSparks", texture("Spark"), 0.5)
			sparks.EmissionDirection = Enum.NormalId.Back
			sparks.SpreadAngle = Vector2.new(35, 35)
			sparks.Speed = NumberRange.new(4, 8)
			sparks.Acceleration = V(0, 4, 0)
			sparks.Lifetime = NumberRange.new(0.3, 0.55)
			sparks.Size = seq({ { 0, 0.55 }, { 1, 0 } })
			sparks.Rotation = NumberRange.new(0, 45)
			sparks.Transparency = seq({ { 0, 0 }, { 1, 0.5 } })
			sparks.Color = ColorSequence.new(tier.Color0, tier.Color1)
			sparks.Rate = tier.Sparks * rateScale
			table.insert(rig.runEmitters, sparks)
		end
	end

	if strengthTier > 0 then
		local tier = C.Strength[strengthTier]
		local colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, tier.Core),
			ColorSequenceKeypoint.new(0.35, tier.Edge),
			ColorSequenceKeypoint.new(1, tier.Edge),
		})
		-- Flammes de dessin animé (deux tons) qui montent autour du corps, en couleur presque pleine.
		local wisps = emitter(volume, "PowerWisps", texture("Flame"), 0.1)
		wisps.Shape = Enum.ParticleEmitterShape.Cylinder
		wisps.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		wisps.EmissionDirection = Enum.NormalId.Top
		wisps.Speed = NumberRange.new(1, 2)
		-- Accrochées au corps : vérifié en Play, sinon elles restent semées sur le chemin quand on court.
		wisps.LockedToPart = true
		wisps.Acceleration = V(0, 2.5, 0)
		wisps.Drag = 1
		wisps.Lifetime = NumberRange.new(0.5, 0.85)
		wisps.Size = seq({ { 0, 0.4 }, { 0.25, tier.WispSize * 2.6 }, { 1, 0.3 } })
		wisps.Rotation = NumberRange.new(-12, 12)
		wisps.Transparency = seq({ { 0, 1 }, { 0.12, 0.05 }, { 0.7, 0.35 }, { 1, 1 } })
		wisps.Color = colors
		wisps.Rate = tier.Wisps * rateScale
		table.insert(rig.auraEmitters, wisps)
		table.insert(rig.burst, wisps)
		if tier.Ground > 0 then
			-- Anneau à plat sous les pieds, qui s'élargit et s'efface.
			local ring = emitter(ground, "PowerGround", texture("Ring"), 0.15)
			ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
			ring.EmissionDirection = Enum.NormalId.Top
			ring.Speed = NumberRange.new(0.01)
			ring.LockedToPart = true
			ring.Lifetime = NumberRange.new(1.1)
			ring.Size = seq({ { 0, 1.2 }, { 1, 5.5 } })
			ring.Transparency = seq({ { 0, 0.1 }, { 0.6, 0.5 }, { 1, 1 } })
			ring.Color = ColorSequence.new(tier.Edge)
			ring.Rate = tier.Ground
			table.insert(rig.auraEmitters, ring)
			table.insert(rig.burst, ring)
		end
		if tier.Embers > 0 then
			local embers = emitter(volume, "PowerEmbers", texture("Spark"), 0.5)
			embers.Shape = Enum.ParticleEmitterShape.Cylinder
			embers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			embers.EmissionDirection = Enum.NormalId.Top
			embers.SpreadAngle = Vector2.new(20, 20)
			embers.Speed = NumberRange.new(3, 6)
			embers.VelocityInheritance = 0.85
			embers.Acceleration = V(0, 2, 0)
			embers.Lifetime = NumberRange.new(0.6, 1)
			embers.Size = seq({ { 0, 0.4 }, { 1, 0 } })
			embers.Rotation = NumberRange.new(0, 45)
			embers.RotSpeed = NumberRange.new(-90, 90)
			embers.Color = colors
			embers.Rate = tier.Embers * rateScale
			table.insert(rig.auraEmitters, embers)
		end
		if tier.Rays then
			local rays = emitter(ground, "PowerRays", RAYS, 0.2)
			rays.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
			rays.EmissionDirection = Enum.NormalId.Top
			rays.Speed = NumberRange.new(0.01)
			rays.LockedToPart = true
			rays.Lifetime = NumberRange.new(4)
			rays.Size = seq({ { 0, 7 }, { 1, 8 } })
			rays.Rotation = NumberRange.new(0, 360)
			rays.RotSpeed = NumberRange.new(18, 24)
			rays.Transparency = seq({ { 0, 1 }, { 0.2, 0.35 }, { 0.8, 0.35 }, { 1, 1 } })
			rays.Color = ColorSequence.new(tier.Edge)
			rays.Rate = 0.5
			table.insert(rig.auraEmitters, rays)
		end
	end
	return rig
end

local function rainbowColors(now: number): ColorSequence
	local h = now * 0.2 % 1
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(h, 0.9, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromHSV((h + 0.33) % 1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV((h + 0.66) % 1, 1, 1)),
	})
end

function PowerFx.Update(rig: Rig, now: number, visible: boolean, running: boolean)
	local position = rig.root.CFrame.Position
	local teleported = (position - rig.last).Magnitude > C.TeleportDistance
	rig.last = position
	if visible ~= rig.visible then
		for _, e in ipairs(rig.auraEmitters) do
			e.Enabled = visible
			if not visible then
				e:Clear()
			end
		end
		rig.visible = visible
	end
	local moving = visible and running and not teleported
	if moving ~= rig.running then
		for _, e in ipairs(rig.runEmitters) do
			e.Enabled = moving
		end
		rig.running = moving
	end
	for _, trail in ipairs(rig.trails) do
		trail.Enabled = moving
		-- À l'arrêt, le ruban s'efface tout seul ; caché ou téléporté, il disparaît d'un coup.
		if not visible or teleported then
			trail:Clear()
		end
	end
	if rig.rainbow and visible then
		local colors = rainbowColors(now)
		for _, trail in ipairs(rig.trails) do
			trail.Color = colors
		end
	end
end

-- Jaillissement quand le joueur passe un palier (vu seulement par lui, client/PowerFx).
function PowerFx.Burst(rig: Rig)
	for _, e in ipairs(rig.burst) do
		e:Emit(if e.Name == "PowerGround" then 2 else 24)
	end
end

function PowerFx.Destroy(rig: Rig)
	rig.folder:Destroy()
	for _, a in ipairs(rig.attachments) do
		a:Destroy()
	end
end

return PowerFx
