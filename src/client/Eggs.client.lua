--!strict
-- Eggs : les œufs dans la couveuse de chaque base (repères "IncubatingEgg" de server/EggController) et leur éclosion.
--   - Chaque œuf tombe dans SON nid (plusieurs œufs arrivés ensemble tombent l'un après l'autre), se balance, et
--     affiche sa rareté + le temps restant. Les raretés hautes flottent et scintillent.
--   - Montée en tension (Config.Eggs.BuildUp secondes avant l'échéance) : il tremble de plus en plus vite, s'élève,
--     tourne et brille ; les Divins et Sigmas sont entourés d'éclats qui tournent.
--   - Éclosion (Remotes.EggHatched) : de plus en plus spectaculaire avec la rareté (SPECTACLE) — coquille qui éclate,
--     gerbe, ondes de choc, colonne de lumière, rayons, confettis ; pour le propriétaire : secousse, flash, bandeau.
--   - Le familier : s'il fait partie des familiers affichés dans la base, il sort du nid et se promène
--     (client/BasePets) ; sinon il apparaît un instant au-dessus du nid (« +1 NOM ») puis rejoint la collection.
--   - « +N ŒUFS EN ATTENTE » sur le panneau de la couveuse quand les 10 nids sont pleins.
-- Tout est local (aucune requête au serveur) et limité aux œufs proches de la caméra.
local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.EggIncubation)
local Builder = require(ReplicatedStorage.Shared.EggModelBuilder)
local Catalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)

local player = Players.LocalPlayer
local visuals = Instance.new("Folder")
visuals.Name, visuals.Parent = "EggVisuals", Workspace

local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local WHITE = Color3.new(1, 1, 1)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local DROP_HEIGHT = 28
local DROP_TIME = 0.7
local DROP_STAGGER = 0.22 -- secondes entre deux œufs arrivés ensemble
local MAX_BIG_BURSTS = 6 -- éclosions complètes en même temps au plus (les autres : petite gerbe)
local EGG_HEIGHT = 3.6 -- studs, œuf à l'échelle 1 (shared/EggModelBuilder)

-- Plus l'œuf est rare, plus il est gros (1,23 pour un Commun, 1,79 pour un Sigma).
local function eggScale(rank: number): number
	return 1.15 + rank * 0.08
end

-- Ce que fait chaque rareté (index Config.Rarities : 1 = Commun ... 8 = Sigma).
type Spectacle = {
	sparks: number, -- étincelles de la gerbe
	rings: number, -- ondes de choc au sol
	pillar: boolean, -- colonne de lumière
	rays: boolean, -- rayons qui tournent
	confetti: boolean,
	shake: number, -- secousse de la caméra du propriétaire (0 = aucune)
	flash: boolean, -- flash blanc de l'écran du propriétaire
	banner: boolean, -- « ÉCLOSION LÉGENDAIRE ! »
	sound: string,
}
local SPECTACLE: { Spectacle } = {
	{ sparks = 14, rings = 0, pillar = false, rays = false, confetti = false, shake = 0, flash = false, banner = false, sound = "PetArrival" },
	{ sparks = 24, rings = 1, pillar = false, rays = false, confetti = false, shake = 0, flash = false, banner = false, sound = "PetArrival" },
	{ sparks = 40, rings = 1, pillar = false, rays = false, confetti = false, shake = 0, flash = false, banner = false, sound = "HoleBonus" },
	{ sparks = 60, rings = 2, pillar = true, rays = false, confetti = false, shake = 0.25, flash = false, banner = false, sound = "HoleBonus" },
	{ sparks = 80, rings = 2, pillar = true, rays = false, confetti = true, shake = 0.4, flash = false, banner = true, sound = "RareDrop" },
	{ sparks = 100, rings = 3, pillar = true, rays = true, confetti = true, shake = 0.55, flash = true, banner = true, sound = "RareDrop" },
	{ sparks = 130, rings = 3, pillar = true, rays = true, confetti = true, shake = 0.75, flash = true, banner = true, sound = "HoleTierUp" },
	{ sparks = 170, rings = 4, pillar = true, rays = true, confetti = true, shake = 1, flash = true, banner = true, sound = "HoleTierUp" },
}

local function ghost(part: BasePart)
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
end

local function glowPart(size: Vector3, cf: CFrame, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Size, part.CFrame, part.Color = size, cf, color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	ghost(part)
	part.Parent = visuals
	return part
end

----------------------------------------------------------------------
-- Les œufs dans les nids
----------------------------------------------------------------------

type Shown = {
	anchor: BasePart,
	model: Model,
	gui: BillboardGui,
	label: TextLabel,
	timer: TextLabel,
	bar: Frame,
	light: PointLight?,
	sparkles: ParticleEmitter?,
	orbit: { BasePart },
	landAt: number, -- os.clock() de l'atterrissage
	rank: number,
	pivot: CFrame, -- dernière position (l'éclosion part de là)
}
local shown: { [BasePart]: Shown } = {}
local byKey: { [string]: Shown } = {}
local lastDropAt = 0

local function outline(label: TextLabel, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Parent = label
end

local function remove(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local egg = shown[instance]
	if egg then
		egg.model:Destroy()
		for _, piece in ipairs(egg.orbit) do
			piece:Destroy()
		end
		shown[instance] = nil
		if byKey[instance.Name] == egg then
			byKey[instance.Name] = nil
		end
	end
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or shown[instance] or not instance:IsDescendantOf(Workspace) then
		return
	end
	local rarityId = instance:GetAttribute("Rarity")
	if type(rarityId) ~= "string" or not Config.RarityIndex[rarityId] then
		return
	end
	local rank = Config.RarityIndex[rarityId]
	local rarity = Config.Rarities[rank]
	local scale = eggScale(rank)
	local model = Builder.Build(rarityId)
	model:ScaleTo(scale)
	model:PivotTo(instance.CFrame * CF(0, DROP_HEIGHT, 0))
	model.Parent = visuals
	local root = model.PrimaryPart

	-- Étiquette : rareté + temps restant + barre. Taille en studs (elles ne se chevauchent pas, nids à 11 studs).
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee = "Incubation", instance
	gui.Size, gui.StudsOffsetWorldSpace = UDim2.fromScale(8, 3.2), V(0, EGG_HEIGHT * scale + 1.6, 0)
	gui.MaxDistance, gui.LightInfluence = 80, 0
	gui.Parent = instance
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.4)
	label.FontFace, label.TextScaled = Typography.Face, true
	label.TextColor3 = rarity.Color
	label.Text = "ŒUF " .. TextFormat.upper(rarity.Name)
	outline(label, 2)
	label.Parent = gui
	local timer = Instance.new("TextLabel")
	timer.BackgroundTransparency = 1
	timer.Position, timer.Size = UDim2.fromScale(0, 0.4), UDim2.fromScale(1, 0.36)
	timer.FontFace, timer.TextScaled = Typography.Face, true
	timer.TextColor3 = WHITE
	outline(timer, 2)
	timer.Parent = gui
	local track = Instance.new("Frame")
	track.Position, track.Size = UDim2.fromScale(0.15, 0.82), UDim2.fromScale(0.7, 0.13)
	track.BorderSizePixel, track.BackgroundColor3 = 0, Color3.fromRGB(30, 25, 45)
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Thickness = 2
	trackStroke.Parent = track
	track.Parent = gui
	local bar = Instance.new("Frame")
	bar.BorderSizePixel, bar.BackgroundColor3 = 0, rarity.Color
	bar.Size = UDim2.fromScale(0, 1)
	bar.Parent = track

	local light: PointLight? = nil
	local sparkles: ParticleEmitter? = nil
	if root and rank >= 3 then
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range, glow.Shadows = rarity.Color, 0.6, 6, false
		glow.Parent = root
		light = glow
	end
	if root and rank >= 4 then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SPARK
		emitter.Color = ColorSequence.new(rarity.Color, WHITE)
		emitter.Rate, emitter.Lifetime, emitter.Speed = 2 + rank, NumberRange.new(0.7, 1.4), NumberRange.new(0.4, 1.2)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
		emitter.LightEmission, emitter.SpreadAngle = 0.8, Vector2.new(60, 60)
		emitter.Parent = root
		sparkles = emitter
	end
	-- Divin et Sigma : éclats qui tournent autour de l'œuf.
	local orbit: { BasePart } = {}
	if rank >= 7 then
		for index = 1, 6 do
			local piece = glowPart(V(0.45, 0.45, 0.45), instance.CFrame, if index % 2 == 0 then WHITE else rarity.Color, 0.1)
			piece.Name = "Orbit"
			orbit[index] = piece
		end
	end

	-- Plusieurs œufs reçus ensemble : ils tombent l'un après l'autre.
	local clock = os.clock()
	local start = math.max(clock, lastDropAt + DROP_STAGGER)
	lastDropAt = start
	local egg: Shown = {
		anchor = instance,
		model = model,
		gui = gui,
		label = label,
		timer = timer,
		bar = bar,
		light = light,
		sparkles = sparkles,
		orbit = orbit,
		landAt = start + DROP_TIME,
		rank = rank,
		pivot = instance.CFrame,
	}
	shown[instance] = egg
	byKey[instance.Name] = egg
	-- Un œuf qui part dans la machine d'évolution (client/EvolutionMachine le fait voler) quitte son nid tout de suite.
	instance:GetAttributeChangedSignal("Leaving"):Connect(function()
		remove(instance)
	end)
	-- Petit nuage de paille à l'atterrissage, et un « pop » si c'est mon œuf.
	task.delay(start + DROP_TIME - clock, function()
		if shown[instance] ~= egg then
			return
		end
		local puff = Instance.new("Attachment")
		puff.WorldCFrame = instance.CFrame * CF(0, 0.6, 0)
		puff.Parent = Workspace.Terrain
		local dust = Instance.new("ParticleEmitter")
		dust.Texture, dust.Color = SMOKE, ColorSequence.new(Color3.fromRGB(240, 210, 130))
		dust.Rate, dust.Lifetime, dust.Speed = 0, NumberRange.new(0.4, 0.7), NumberRange.new(3, 6)
		dust.SpreadAngle = Vector2.new(80, 10)
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
		dust.Transparency = NumberSequence.new(0.3, 1)
		dust.Parent = puff
		dust:Emit(10)
		Debris:AddItem(puff, 1)
		if instance:GetAttribute("OwnerUserId") == player.UserId then
			Sounds.playAt("PetArrival", instance.Position)
		end
	end)
end

CollectionService:GetInstanceAddedSignal("IncubatingEgg"):Connect(add)
CollectionService:GetInstanceRemovedSignal("IncubatingEgg"):Connect(remove)
for _, instance in ipairs(CollectionService:GetTagged("IncubatingEgg")) do
	add(instance)
end

-- Balancement, chute, montée en tension.
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 / 30 then
		return
	end
	elapsed = 0
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local time, clock = Workspace:GetServerTimeNow(), os.clock()
	for anchor, egg in pairs(shown) do
		if not anchor:IsDescendantOf(Workspace) then
			remove(anchor)
			continue
		end
		local distance = (camera.CFrame.Position - anchor.Position).Magnitude
		local visible = distance <= Config.Eggs.ViewDistance
		egg.gui.Enabled = visible
		if egg.sparkles then
			egg.sparkles.Enabled = visible
		end
		if not visible and clock > egg.landAt then
			continue
		end
		local ready = anchor:GetAttribute("ReadyAt")
		local started = anchor:GetAttribute("StartedAt")
		if type(ready) ~= "number" or type(started) ~= "number" then
			continue
		end
		local remaining = math.max(0, ready - time)
		egg.timer.Text = if remaining > 0 then Eggs.Time(remaining) else "ÉCLOSION !"
		egg.bar.Size = UDim2.fromScale(math.clamp((time - started) / math.max(ready - started, 1), 0, 1), 1)

		local rank = egg.rank
		local buildUp = Config.Eggs.BuildUp[rank] or 3
		local tension = math.clamp(1 - remaining / buildUp, 0, 1)
		local phase = clock * 2 + rank
		-- Chute dans le nid, avec un petit rebond.
		local drop = 0
		if clock < egg.landAt then
			local f = math.clamp(1 - (egg.landAt - clock) / DROP_TIME, 0, 1)
			drop = DROP_HEIGHT * (1 - f * f)
		elseif clock < egg.landAt + 0.3 then
			drop = math.sin((clock - egg.landAt) / 0.3 * math.pi) * 0.6
		end
		local float = if rank >= 4 then 0.15 + math.sin(phase) * 0.12 else 0
		local rise = if rank >= 4 then tension * (0.6 + (rank - 3) * 0.8) else tension * 0.3
		local frequency = 1 + tension * (10 + rank * 2)
		local amplitude = 0.035 + tension * tension * (0.1 + rank * 0.02)
		local rock = math.sin(clock * frequency * 2) * amplitude
		local spin = if rank >= 5 then tension * tension * (rank - 4) * clock * 3 else math.sin(phase * 0.5) * 0.07
		local pivot = anchor.CFrame * CF(0, 0.3 + drop + float + rise, 0) * ANG(0, spin, rock) * ANG(math.cos(clock * frequency * 1.7) * amplitude * 0.6, 0, 0)
		egg.model:PivotTo(pivot)
		egg.pivot = pivot
		if egg.light then
			egg.light.Brightness = 0.6 + tension * (1 + rank * 0.6) + math.sin(clock * 6) * 0.2 * tension
			egg.light.Range = 6 + tension * rank * 1.5
		end
		if egg.sparkles then
			egg.sparkles.Rate = 2 + rank + tension * rank * 8
		end
		for index, piece in ipairs(egg.orbit) do
			local angle = clock * (1 + tension * 5) + index * math.pi / 3
			local radius = (3 - tension * 0.8) * eggScale(egg.rank)
			piece.CFrame = anchor.CFrame * CF(math.cos(angle) * radius, 2.6 + rise + math.sin(angle * 2) * 0.5, math.sin(angle) * radius) * ANG(angle, angle, 0)
		end
	end
end)

----------------------------------------------------------------------
-- « +N ŒUFS EN ATTENTE » sur le panneau de la couveuse
----------------------------------------------------------------------

local function watchBase(base: Instance)
	local folder = base:WaitForChild("Eggs", 30)
	local incubator = base:WaitForChild("Incubator", 30)
	local board = incubator and incubator:FindFirstChild("IncubatorSign")
	if not folder or not board or not board:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee = "Waiting", board
	gui.Size, gui.StudsOffsetWorldSpace = UDim2.fromScale(18, 3), V(0, 4.5, 0)
	gui.MaxDistance, gui.LightInfluence = 120, 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace, label.TextScaled = Typography.Face, true
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	outline(label, 3)
	label.Parent = gui
	gui.Parent = board
	local function refresh()
		local waiting = folder:GetAttribute("Waiting")
		gui.Enabled = type(waiting) == "number" and waiting > 0
		label.Text = string.format("+%d ŒUF%s EN ATTENTE", if type(waiting) == "number" then waiting else 0,
			if type(waiting) == "number" and waiting > 1 then "S" else "")
	end
	folder:GetAttributeChangedSignal("Waiting"):Connect(refresh)
	refresh()
end
task.spawn(function()
	local map = Workspace:WaitForChild("Map")
	for _, child in ipairs(map:GetChildren()) do
		if child:IsA("Model") and child.Name:match("^Base_") then
			task.spawn(watchBase, child)
		end
	end
	map.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") and child.Name:match("^Base_") then
			watchBase(child)
		end
	end)
end)

----------------------------------------------------------------------
-- Effets d'écran du propriétaire : secousse, flash, bandeau
----------------------------------------------------------------------

local shakeUntil, shakeStrength = 0, 0
RunService:BindToRenderStep("EggShake", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	local camera = Workspace.CurrentCamera
	if left <= 0 or not camera then
		return
	end
	local s = shakeStrength * math.min(1, left * 3)
	camera.CFrame *= CF(math.noise(os.clock() * 25, 1) * s, math.noise(os.clock() * 25, 2) * s, 0)
		* ANG(0, 0, math.noise(os.clock() * 25, 3) * s * 0.03)
end)
local function shake(strength: number, duration: number)
	shakeStrength = math.max(if os.clock() < shakeUntil then shakeStrength else 0, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

local screen = Instance.new("ScreenGui")
screen.Name = "EggHatchFx"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 9
screen.Parent = player:WaitForChild("PlayerGui")
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = WHITE
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = screen
local bannerRoot = ScreenScale.attach(screen)
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.32)
banner.Size = UDim2.fromOffset(820, 70)
banner.BackgroundTransparency = 1
banner.FontFace, banner.TextScaled = Typography.Face, true
banner.Visible = false
outline(banner, 4)
banner.Parent = bannerRoot
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
local bannerToken = 0

local function showBanner(text: string, color: Color3)
	bannerToken += 1
	local token = bannerToken
	banner.Text, banner.TextColor3, banner.TextTransparency, banner.Visible = text, color, 0, true
	bannerScale.Scale = 1.6
	TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.2, function()
		if token == bannerToken then
			TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.delay(0.4, function()
				if token == bannerToken then
					banner.Visible = false
				end
			end)
		end
	end)
end

local function screenFlash(strength: number)
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
end

----------------------------------------------------------------------
-- L'éclosion
----------------------------------------------------------------------

local activeBursts = 0

local function emitAt(position: Vector3, texture: string, color: ColorSequence, count: number, speed: NumberRange,
	size: number, lifetime: NumberRange)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture, emitter.Color = texture, color
	emitter.Rate, emitter.Lifetime, emitter.Speed = 0, lifetime, speed
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Drag = 3
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, lifetime.Max + 0.2)
end

-- Onde de choc : un anneau au sol qui s'élargit.
local function ring(ground: CFrame, color: Color3, radius: number, delay: number)
	task.delay(delay, function()
		local part = glowPart(V(0.3, 1, 1), ground * CF(0, 0.3, 0) * ANG(0, 0, math.pi / 2), color, 0.15)
		part.Shape = Enum.PartType.Cylinder
		TweenService:Create(part, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = V(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
		Debris:AddItem(part, 0.6)
	end)
end

-- Colonne de lumière qui monte du nid.
local function pillar(ground: CFrame, color: Color3, rank: number)
	local height = 30 + rank * 12
	local width = 2.5 + rank * 0.6
	local part = glowPart(V(height, width * 0.3, width * 0.3), ground * CF(0, height / 2, 0) * ANG(0, 0, math.pi / 2), color, 0.2)
	part.Shape = Enum.PartType.Cylinder
	local grow = TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = V(height, width, width) })
	grow:Play()
	TweenService:Create(part, TweenInfo.new(1 + rank * 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = V(height, 0.2, 0.2), Transparency = 1 }):Play()
	Debris:AddItem(part, 1.2 + rank * 0.15)
end

-- Rayons qui tournent autour du nid.
local function rays(ground: CFrame, color: Color3, rank: number)
	local pieces: { BasePart } = {}
	local count = if rank >= 8 then 12 else 8
	for index = 1, count do
		local piece = glowPart(V(0.35, 0.35, 10 + rank * 1.5), ground, if index % 2 == 0 then WHITE else color, 0.25)
		pieces[index] = piece
	end
	local start = os.clock()
	local length = 1.4 + rank * 0.1
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		if t >= length then
			connection:Disconnect()
			for _, piece in ipairs(pieces) do
				piece:Destroy()
			end
			return
		end
		for index, piece in ipairs(pieces) do
			local angle = t * 2.5 + index * (2 * math.pi / count)
			local reach = piece.Size.Z / 2 + 1.5
			piece.CFrame = ground * CF(0, 2.2, 0) * ANG(0, angle, 0) * ANG(-0.25, 0, 0) * CF(0, 0, -reach)
			piece.Transparency = 0.25 + 0.75 * (t / length)
		end
	end)
end

-- Le familier apparaît au-dessus du nid quand il n'est pas affiché dans la base : « +1 NOM », puis il rejoint la
-- collection (il s'envole et rapetisse).
local function showcase(petId: string, ground: CFrame, rarityColor: Color3)
	local model = PetModelBuilder.Build(petId)
	local entry = Catalog.ById[petId]
	if not model or not entry then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			ghost(descendant)
		end
	end
	local _, size = PetModelBuilder.BodyBounds(model)
	local full = model:GetScale() * math.min(1, 5 / math.max(size.Y, 0.1))
	model:ScaleTo(full * 0.2)
	model.Parent = visuals
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffsetWorldSpace = UDim2.fromScale(10, 2.4), V(0, 4, 0)
	gui.LightInfluence, gui.MaxDistance = 0, 120
	local adornee = model.PrimaryPart
	if adornee then
		gui.Adornee = adornee
	end
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.6)
	name.FontFace, name.TextScaled = Typography.Face, true
	name.TextColor3, name.Text = rarityColor, "+1 " .. TextFormat.upper(entry.Name)
	outline(name, 3)
	name.Parent = gui
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position, hint.Size = UDim2.fromScale(0, 0.6), UDim2.fromScale(1, 0.4)
	hint.FontFace, hint.TextScaled = Typography.Face, true
	hint.TextColor3, hint.Text = WHITE, "DANS TA COLLECTION"
	outline(hint, 2)
	hint.Parent = gui
	gui.Parent = model
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		if t >= 3.2 or not model.Parent then
			connection:Disconnect()
			model:Destroy()
			return
		end
		local grow = math.clamp(t / 0.35, 0, 1)
		local leave = math.clamp((t - 2.5) / 0.7, 0, 1)
		model:ScaleTo(full * math.max(0.05, (0.2 + 0.8 * grow) * (1 - leave * 0.9)))
		local hop = math.abs(math.sin(math.min(t, 1.2) * math.pi * 1.6)) * 1.6 * (1 - math.min(t, 1.2) / 1.2)
		model:PivotTo(ground * CF(0, 1 + hop + leave * 14, 0) * ANG(0, t * 1.6, 0))
	end)
end

local pendingToast: { string } = {}
local reserveToast = false
local toastColor = WHITE
local toastBest = 0
local function queueToast(name: string, rank: number, color: Color3, reserve: boolean?)
	reserveToast = reserveToast or reserve == true
	table.insert(pendingToast, name)
	if rank > toastBest then
		toastBest, toastColor = rank, color
	end
	if #pendingToast == 1 then
		task.delay(0.5, function()
			local names = pendingToast
			pendingToast, toastBest = {}, 0
			local suffix = if reserveToast then " BASE PLEINE : LES AUTRES RESTENT DANS TON INDEX." else ""
			reserveToast = false
			Toast.show((if #names == 1 then "ÉCLOSION : " .. names[1] .. " !" else string.format("%d FAMILIERS ONT ÉCLOS !", #names)) .. suffix, toastColor)
		end)
	end
end

----------------------------------------------------------------------
-- Mutation secrète (Config.Mutations) : l'œuf éclot comme un œuf normal de sa rareté... puis, une seconde plus tard,
-- tout s'arrête (écran sombre, silence), la caméra vient sur le nid et ça explose aux couleurs de la mutation :
-- colonne de lumière géante, ondes de choc, rayons, confettis, 3 répliques, secousse, et en grand
-- « MUTATION SECRÈTE ! », le nom du familier, « REVENU xN ». Les joueurs proches voient les effets dans le monde.
----------------------------------------------------------------------

local RAINBOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 230, 110)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
})

local revealRoot = Instance.new("Frame")
revealRoot.Name = "MutationReveal"
revealRoot.BackgroundTransparency = 1
revealRoot.Size = UDim2.fromScale(1, 1)
revealRoot.Visible = false
revealRoot.Parent = bannerRoot
local function revealLabel(y: number, height: number, width: number): (TextLabel, UIScale, UIGradient)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromOffset(width, height)
	label.BackgroundTransparency = 1
	label.FontFace, label.TextScaled = Typography.Face, true
	label.TextColor3 = WHITE
	outline(label, 5)
	local scale = Instance.new("UIScale")
	scale.Parent = label
	local gradient = Instance.new("UIGradient")
	gradient.Parent = label
	label.Parent = revealRoot
	return label, scale, gradient
end
local revealTitle, revealTitleScale, revealTitleGradient = revealLabel(0.22, 96, 980)
local revealName, revealNameScale, revealNameGradient = revealLabel(0.36, 64, 900)
local revealIncome, revealIncomeScale, revealIncomeGradient = revealLabel(0.47, 48, 600)
local revealToken = 0

local function popIn(label: TextLabel, scale: UIScale, delay: number)
	task.delay(delay, function()
		label.Visible = true
		label.TextTransparency = 0
		scale.Scale = 2.4
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
end

-- La caméra du propriétaire tourne lentement autour du nid pendant la révélation.
local function focusCamera(center: Vector3, duration: number)
	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom or player:GetAttribute("InDuel") ~= nil then
		return
	end
	local start = os.clock()
	local from = camera.CFrame
	local look = (center - from.Position) * V(1, 0, 1)
	local baseAngle = if look.Magnitude > 0.1 then math.atan2(-look.X, -look.Z) else 0
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("MutationReveal", Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - start
		if t >= duration then
			RunService:UnbindFromRenderStep("MutationReveal")
			camera.CameraType = Enum.CameraType.Custom
			return
		end
		local angle = baseAngle + t * 0.45
		local distance = 20 - math.min(t, 1.2) * 4
		local goal = CFrame.lookAt(center + V(math.sin(angle) * distance, 7, math.cos(angle) * distance), center + V(0, 1.5, 0))
		camera.CFrame = if t < 0.5 then from:Lerp(goal, TweenService:GetValue(t / 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)) else goal
	end)
end

local function mutationReveal(ground: CFrame, center: Vector3, petId: string, mutation: Config.Mutation, mine: boolean, near: boolean)
	local entry = Catalog.ById[petId]
	if not entry then
		return
	end
	local rainbow = mutation.Id == "Rainbow"
	local color = mutation.Color
	local sequence = if rainbow
		then RAINBOW_SEQUENCE
		else ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.5, WHITE),
			ColorSequenceKeypoint.new(1, color),
		})
	local function hue(index: number): Color3
		return if rainbow then Color3.fromHSV((index * 0.13) % 1, 0.8, 1) else (if index % 2 == 0 then WHITE else color)
	end

	-- 1. Le calme avant la tempête : l'écran s'assombrit, la musique se tait.
	task.delay(0.7, function()
		if mine then
			Sounds.duck(6)
			flash.BackgroundColor3 = Color3.new(0, 0, 0)
			flash.BackgroundTransparency = 0.45
			if near then
				focusCamera(center, 5.2)
			end
		end
	end)

	-- 2. L'explosion, puis 3 répliques.
	task.delay(1.15, function()
		if mine then
			flash.BackgroundColor3 = if rainbow then WHITE else color
			screenFlash(0.95)
			shake(1.6, 1.4)
			Sounds.play("HoleTierUp")
			Sounds.play("RareDrop")
		elseif near then
			Sounds.playAt("HoleTierUp", center)
		end
		if not near then
			return
		end
		pillar(ground, color, 12)
		rays(ground, color, 10)
		for index = 1, 8 do
			ring(ground, hue(index), 10 + index * 6, (index - 1) * 0.1)
		end
		emitAt(center, SPARK, sequence, 220, NumberRange.new(16, 32), 0.7, NumberRange.new(1, 2))
		emitAt(center + V(0, 4, 0), SPARK, RAINBOW_SEQUENCE, 160, NumberRange.new(12, 24), 0.6, NumberRange.new(1.4, 2.6))
		for wave = 1, 3 do
			task.delay(wave * 0.8, function()
				emitAt(center + V(0, 2 + wave * 2, 0), SPARK, sequence, 90, NumberRange.new(10, 22), 0.55, NumberRange.new(0.8, 1.6))
				ring(ground, hue(wave + 3), 30 + wave * 8, 0)
				if mine then
					shake(0.6, 0.35)
				end
			end)
		end
	end)

	-- 3. Les textes, l'un après l'autre.
	if not mine then
		return
	end
	revealToken += 1
	local token = revealToken
	task.delay(1.15, function()
		if token ~= revealToken then
			return
		end
		revealTitle.Text = "MUTATION SECRÈTE !"
		revealName.Text = TextFormat.upper(entry.Name)
		revealIncome.Text = string.format("REVENU x%d", mutation.Income)
		for _, gradient in ipairs({ revealTitleGradient, revealNameGradient, revealIncomeGradient }) do
			gradient.Color = sequence
		end
		revealTitle.Visible, revealName.Visible, revealIncome.Visible = false, false, false
		revealRoot.Visible = true
		popIn(revealTitle, revealTitleScale, 0)
		popIn(revealName, revealNameScale, 0.9)
		popIn(revealIncome, revealIncomeScale, 1.7)
		-- Les couleurs défilent sur les textes.
		local start = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if token ~= revealToken or not revealRoot.Visible then
				connection:Disconnect()
				return
			end
			local offset = ((os.clock() - start) * 0.6) % 2 - 1
			for _, gradient in ipairs({ revealTitleGradient, revealNameGradient, revealIncomeGradient }) do
				gradient.Offset = Vector2.new(offset, 0)
			end
		end)
	end)
	task.delay(6.2, function()
		if token ~= revealToken then
			return
		end
		for _, label in ipairs({ revealTitle, revealName, revealIncome }) do
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
		task.delay(0.5, function()
			if token == revealToken then
				revealRoot.Visible = false
				flash.BackgroundColor3 = WHITE
			end
		end)
	end)
end

Remotes.EggHatched.OnClientEvent:Connect(function(ownerId: number, key: string, rarityId: string, cf: CFrame, petId: string, inBase: boolean, reserve: boolean?)
	local rank = Config.RarityIndex[rarityId]
	local entry = Catalog.ById[petId]
	if not rank or not entry or typeof(cf) ~= "CFrame" then
		return
	end
	local rarity = Config.Rarities[rank]
	-- Un familier évolué (machine d'évolution) éclot avec le spectacle des raretés au-dessus. Un familier muté éclot
	-- d'abord comme un familier normal (secret), puis vient la surprise (mutationReveal).
	local stage = Catalog.Stage(petId)
	local mutationId = Catalog.Mutation(petId)
	local mutation = if mutationId then Config.Mutations[Config.MutationIndex[mutationId] or 1] else nil
	local fx = SPECTACLE[math.min(#SPECTACLE, rank + stage - 1)]
	local title = "ÉCLOSION " .. TextFormat.upper(rarity.Name)
		.. (if stage > 1 then " " .. TextFormat.upper(Config.Evolution.Names[stage]) else "") .. " !"
	local bannerColor = rarity.Color
	local mine = ownerId == player.UserId
	if mine and not mutation then
		queueToast(TextFormat.upper(entry.Name), rank, rarity.Color, reserve)
	end

	-- L'œuf affiché devient la coquille qui éclate (il ne sera pas détruit par le repère qui disparaît).
	local egg = byKey[key]
	local shell: Model
	local eggPivot = cf * CF(0, 0.3, 0)
	if egg then
		byKey[key] = nil
		shown[egg.anchor] = nil
		egg.gui:Destroy()
		for _, piece in ipairs(egg.orbit) do
			piece:Destroy()
		end
		shell = egg.model
		eggPivot = egg.pivot
	else
		shell = Builder.Build(rarityId)
		shell:ScaleTo(eggScale(rank))
		shell:PivotTo(eggPivot)
		shell.Parent = visuals
	end
	local camera = Workspace.CurrentCamera
	local near = camera ~= nil and (camera.CFrame.Position - cf.Position).Magnitude <= Config.Eggs.ViewDistance
	if not near then
		shell:Destroy()
		if mine and fx.banner and not mutation then
			showBanner(title, bannerColor)
		end
		if mutation then
			mutationReveal(cf, cf.Position + V(0, 2, 0), petId, mutation, mine, false)
		end
		return
	end
	local big = activeBursts < MAX_BIG_BURSTS
	if big then
		activeBursts += 1
		task.delay(2, function()
			activeBursts -= 1
		end)
	end
	local center = eggPivot.Position + V(0, EGG_HEIGHT * eggScale(rank) / 2, 0)
	if mutation then
		mutationReveal(cf, center, petId, mutation, mine, true)
	end

	-- 1. La coquille éclate : les morceaux partent en tournant et s'effacent.
	local spread = 2 + rank * 0.6
	for _, child in ipairs(shell:GetDescendants()) do
		if child:IsA("BasePart") and child ~= shell.PrimaryPart then
			ghost(child)
			local offset = child.Position - center
			local away = if offset.Magnitude > 0.05 then offset.Unit else V(0, 1, 0)
			local target = CF(child.Position + away * spread + V(0, 1.5 + rank * 0.3, 0))
				* ANG(math.random() * 4 - 2, math.random() * 4 - 2, math.random() * 4 - 2)
			TweenService:Create(child, TweenInfo.new(0.7 + rank * 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = target, Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(shell, 1.3)

	-- 2. Gerbe d'étincelles, éclair de lumière.
	local sparks = if big then fx.sparks else 12
	emitAt(center, SPARK, ColorSequence.new(rarity.Color, WHITE), sparks, NumberRange.new(4 + rank, 8 + rank * 2), 0.35 + rank * 0.04, NumberRange.new(0.5, 1 + rank * 0.1))
	local lightHolder = glowPart(V(0.2, 0.2, 0.2), CF(center), rarity.Color, 1)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = rarity.Color, 3 + rank * 1.5, 10 + rank * 4, false
	light.Parent = lightHolder
	TweenService:Create(light, TweenInfo.new(0.6 + rank * 0.1), { Brightness = 0 }):Play()
	Debris:AddItem(lightHolder, 0.8 + rank * 0.1)
	if mine or (camera.CFrame.Position - cf.Position).Magnitude < 60 then
		Sounds.playAt(fx.sound, center)
	end
	if not big then
		if not inBase then
			showcase(petId, cf, rarity.Color)
		end
		return
	end

	-- 3. Ondes de choc, colonne de lumière, rayons, confettis : de plus en plus avec la rareté.
	for index = 1, fx.rings do
		ring(cf, if index % 2 == 0 then WHITE else rarity.Color, 6 + rank * 2.5 + index * 3, (index - 1) * 0.14)
	end
	if fx.pillar then
		pillar(cf, rarity.Color, rank)
	end
	if fx.rays then
		rays(cf, rarity.Color, rank)
	end
	if fx.confetti then
		local colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarity.Color),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 200)),
		})
		emitAt(center + V(0, 3, 0), SPARK, colors, 30 + rank * 10, NumberRange.new(10, 18 + rank), 0.5, NumberRange.new(1.2, 2.2))
	end
	if rank >= 8 then
		-- Sigma : une deuxième explosion d'étoiles, plus haut, après un court silence.
		task.delay(0.45, function()
			emitAt(center + V(0, 4, 0), SPARK, ColorSequence.new(WHITE, rarity.Color), 120, NumberRange.new(14, 26), 0.6, NumberRange.new(0.8, 1.6))
			ring(cf, WHITE, 40, 0)
		end)
	end

	-- 4. Pour le propriétaire (ou les joueurs tout près) : secousse, flash, bandeau.
	local distance = (camera.CFrame.Position - cf.Position).Magnitude
	if fx.shake > 0 and (mine or distance < 45) then
		shake(fx.shake * (if mine then 1 else 0.5), 0.3 + rank * 0.08)
	end
	if mine and fx.flash then
		screenFlash(0.25 + (rank - 6) * 0.15)
	end
	if mine and fx.banner and not mutation then
		showBanner(title, bannerColor)
	end

	-- 5. Le familier : il sort du nid (client/BasePets) ou s'affiche un instant puis rejoint la collection.
	if not inBase then
		showcase(petId, cf, rarity.Color)
	end
end)
