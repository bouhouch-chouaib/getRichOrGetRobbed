--!strict
-- DuelFx : ce que TOUT LE MONDE voit d'un duel de familiers (server/DuelController) : l'arène en blocs à tenons qui
-- flotte au-dessus du trou noir (île volante vue d'en bas), les deux familiers face à face avec leur barre de vie, les
-- coups (élan, recul, chiffres de dégâts, coups critiques), le K.O., puis la roue des récompenses en 3D qui tourne.
-- Rendu 100 % local d'après le modèle Workspace.Duels.Duel_N (attributs Center, PlayerA/B, PetA/B, HpA/B, MaxA/B,
-- Winner, SpinIndex) et les événements Remotes.DuelEvent ("Hit", "End", "Spin").

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local Sounds = require(script.Parent.Sounds)

local DUEL = Config.Duel
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB

-- Palette de l'arène (couleurs franches, tenons partout, néon seulement pour les effets).
local FLOOR_A, FLOOR_B = rgb(130, 80, 230), rgb(108, 62, 200)
local WALL_A, WALL_B, WALL_TOP = rgb(255, 190, 50), rgb(236, 162, 34), rgb(255, 255, 255)
local ROCK_A, ROCK_B = rgb(96, 74, 140), rgb(78, 58, 118)
local SIDE_COLORS = { A = rgb(255, 80, 80), B = rgb(70, 160, 255) }
local PET_SPOT, PLAYER_SPOT = 11, 30
local WHEEL_RADIUS = 9
local MIN_PET_HEIGHT, MAX_PET_HEIGHT = 6, 10 -- dans l'arène, tous les familiers sont bien visibles

local folder = Instance.new("Folder")
folder.Name = "DuelFx"
folder.Parent = Workspace

local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, neon: boolean?, wedge: boolean?): BasePart
	local p: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = not neon
	if neon then
		p.Material = Enum.Material.Neon
	else
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Studs
		p.FrontSurface = Enum.SurfaceType.Studs
		p.BackSurface = Enum.SurfaceType.Studs
		p.LeftSurface = Enum.SurfaceType.Studs
		p.RightSurface = Enum.SurfaceType.Studs
	end
	p.Parent = parent
	return p
end

local function textLabel(parent: Instance, text: string, color: Color3, y: number, height: number, stroke: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.FontFace = Typography.Face
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	local outline = Instance.new("UIStroke")
	outline.Thickness = stroke or 3
	outline.Parent = label
	label.Parent = parent
	return label
end

----------------------------------------------------------------------
-- Arène
----------------------------------------------------------------------

local function buildArena(parent: Model, c: Vector3)
	-- Sol en damier (dessus à la hauteur du centre).
	for ix = 0, 7 do
		for iz = 0, 4 do
			local x = c.X - 36 + 4.5 + ix * 9
			local z = c.Z - 20 + 4 + iz * 8
			block(parent, V(9, 3, 8), CF(x, c.Y - 1.5, z), if (ix + iz) % 2 == 0 then FLOOR_A else FLOOR_B)
		end
	end
	-- Muret doré en damier tout autour, chapeau blanc (comme les murs de l'arène du jeu).
	local function wallRun(from: Vector3, to: Vector3, count: number)
		for i = 0, count - 1 do
			local p = from:Lerp(to, (i + 0.5) / count)
			local length = (to - from).Magnitude / count
			local look = CFrame.lookAt(p, p + (to - from).Unit)
			block(parent, V(2, 1.6, length), look * CF(0, 0.8, 0), if i % 2 == 0 then WALL_A else WALL_B)
			block(parent, V(2.4, 0.5, length), look * CF(0, 1.85, 0), WALL_TOP)
		end
	end
	local y = c.Y
	wallRun(V(c.X - 37, y, c.Z - 21), V(c.X + 37, y, c.Z - 21), 8)
	wallRun(V(c.X - 37, y, c.Z + 21), V(c.X + 37, y, c.Z + 21), 8)
	wallRun(V(c.X - 37, y, c.Z - 21), V(c.X - 37, y, c.Z + 21), 5)
	wallRun(V(c.X + 37, y, c.Z - 21), V(c.X + 37, y, c.Z + 21), 5)
	-- Piliers d'angle avec une flamme.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local base = V(c.X + sx * 37, y, c.Z + sz * 21)
			block(parent, V(4, 7, 4), CF(base + V(0, 3.5, 0)), FLOOR_B)
			block(parent, V(4.8, 1, 4.8), CF(base + V(0, 7.5, 0)), WALL_A)
			local flame = block(parent, V(2, 2, 2), CF(base + V(0, 9, 0)), rgb(255, 150, 40), true)
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 6
			fire.Parent = flame
		end
	end
	-- Estrades des deux joueurs (rouge / bleu) avec un cercle lumineux au sol.
	for _, label in ipairs({ "A", "B" }) do
		local sign = if label == "A" then -1 else 1
		local pad = V(c.X + sign * PLAYER_SPOT, y, c.Z)
		block(parent, V(7, 0.6, 7), CF(pad + V(0, 0.3, 0)), SIDE_COLORS[label])
		for i = 0, 11 do
			local a = i * math.pi / 6
			block(parent, V(1.7, 0.2, 0.4), CF(pad + V(0, 0.7, 0)) * ANG(0, a, 0) * CF(0, 0, -3.1), SIDE_COLORS[label], true)
		end
	end
	-- Dessous : île volante en rochers à tenons (c'est ce que voient les joueurs d'en bas).
	block(parent, V(66, 5, 36), CF(c + V(0, -5.5, 0)), ROCK_A)
	block(parent, V(46, 6, 26), CF(c + V(0, -11, 0)), ROCK_B)
	block(parent, V(26, 6, 14), CF(c + V(0, -17, 0)), ROCK_A)
	block(parent, V(10, 6, 6), CF(c + V(0, -23, 0)), ROCK_B)
end

----------------------------------------------------------------------
-- Roue (verticale, au fond de l'arène, face aux joueurs)
----------------------------------------------------------------------

type Wheel = { model: Model, pivot: CFrame, angle: number, from: number, to: number, start: number, spinning: boolean }

local function sectorAngle(index: number): number
	return (index - 1) * math.pi * 2 / #DUEL.Wheel
end

local function buildWheel(parent: Model, c: Vector3): Wheel
	local center = c + V(0, 13, -17)
	local pivot = CF(center) -- X = droite, Y = haut, Z = vers les joueurs
	local model = Instance.new("Model")
	model.Name = "Wheel"
	local count = #DUEL.Wheel
	local half = math.pi / count
	local width = WHEEL_RADIUS * math.tan(half)
	local n = pivot.LookVector * -1 -- normale vers l'avant (+Z)
	for index, slot in ipairs(DUEL.Wheel) do
		local a = sectorAngle(index)
		local u = pivot.UpVector * math.cos(a) + pivot.RightVector * math.sin(a)
		local t = pivot.UpVector * math.cos(a + math.pi / 2) + pivot.RightVector * math.sin(a + math.pi / 2)
		local edge = center + u * WHEEL_RADIUS
		-- Deux demi-triangles (WedgePart) par case : sommet au centre, base sur le bord.
		for _, s in ipairs({ -1, 1 }) do
			local y = -u
			local z = t * -s
			local x = y:Cross(z)
			local position = edge + y * (WHEEL_RADIUS / 2) + t * (s * width / 2)
			block(model, V(0.8, WHEEL_RADIUS, width), CFrame.fromMatrix(position, x, y, z), slot.Color, false, true)
		end
		-- Étiquette de la case, écrite du centre vers le bord.
		local plateZ = -n
		local plateX = u
		local plateY = plateZ:Cross(plateX)
		if plateY:Dot(pivot.UpVector) < -0.01 then
			-- Moitié droite : on retourne l'étiquette pour qu'elle ne soit pas à l'envers.
			plateX = -u
			plateY = plateZ:Cross(plateX)
		end
		local plate = block(model, V(WHEEL_RADIUS * 0.72, 2, 0.1), CFrame.fromMatrix(center + u * WHEEL_RADIUS * 0.56 + n * 0.5,
			plateX, plateY, plateZ), Color3.new(), false)
		plate.Transparency = 1
		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Front
		surface.LightInfluence = 0
		surface.PixelsPerStud = 40
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.Parent = plate
		textLabel(surface, slot.Label, Color3.new(1, 1, 1), 0, 1, 4)
	end
	-- Bord doré et moyeu.
	for i = 0, 15 do
		local a = i * math.pi / 8
		local u = pivot.UpVector * math.cos(a) + pivot.RightVector * math.sin(a)
		block(model, V(1.2, 1.2, 1.2), CF(center + u * (WHEEL_RADIUS + 0.4) + n * 0.2), if i % 2 == 0 then WALL_A else WALL_TOP)
	end
	block(model, V(2.4, 2.4, 1.4), CF(center + n * 0.4), WALL_A)
	model.WorldPivot = pivot
	model.Parent = parent
	-- Support et flèche (fixes) : la case qui s'arrête sous la flèche est gagnée.
	block(parent, V(2, 13, 1.6), CF(c + V(0, 6.5, -17.8)), FLOOR_B)
	block(parent, V(1.6, 2.6, 2.4), CF(center + V(0, WHEEL_RADIUS + 2.2, 0.6)) * ANG(math.pi / 2, 0, 0), rgb(232, 30, 36), false, true)
	return { model = model, pivot = pivot, angle = 0, from = 0, to = 0, start = 0, spinning = false }
end

----------------------------------------------------------------------
-- Familiers et barres de vie
----------------------------------------------------------------------

type Fighter = {
	model: Model,
	home: CFrame, -- position de repos (face à l'adversaire)
	toward: Vector3, -- direction de l'adversaire
	lunge: number, -- élan en cours (0 à 1)
	shake: number,
	fill: Frame,
	hpText: TextLabel,
	ko: boolean,
	winner: boolean,
}

type Arena = {
	duel: Model,
	root: Model,
	center: Vector3,
	fighters: { [string]: Fighter },
	wheel: Wheel,
}

local arenas: { [Instance]: Arena } = {}

local function buildFighter(arena: Model, c: Vector3, duel: Model, label: string, sign: number): Fighter?
	local petId = duel:GetAttribute("Pet" .. label)
	local model = if type(petId) == "string" then PetModelBuilder.Build(petId) else nil
	local entry = if type(petId) == "string" then PetCatalog.ById[petId] else nil
	local primary = model and model.PrimaryPart
	if not model or not entry or not primary then
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") and d:GetAttribute("Aura") then
			d.Rate *= 0.5
		end
	end
	model:PivotTo(CFrame.identity)
	local _, size = PetModelBuilder.BodyBounds(model)
	local wanted = math.clamp(size.Y, MIN_PET_HEIGHT, MAX_PET_HEIGHT)
	if math.abs(wanted - size.Y) > 0.01 then
		model:ScaleTo(model:GetScale() * wanted / size.Y)
	end
	local box, body = PetModelBuilder.BodyBounds(model)
	local spot = V(c.X + sign * PET_SPOT, c.Y - (box.Position.Y - body.Y / 2), c.Z)
	local toward = V(-sign, 0, 0)
	local home = CFrame.lookAt(spot, spot + toward) -- l'avant des modèles est -Z
	model:PivotTo(home)
	model.Parent = arena

	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity] or 1]
	local sign2 = Instance.new("BillboardGui")
	sign2.Name = "DuelBar"
	sign2.Adornee = primary
	sign2.Size = UDim2.fromScale(10, 3.4)
	sign2.StudsOffsetWorldSpace = V(0, box.Position.Y + body.Y / 2 + 2.6, 0)
	sign2.LightInfluence = 0
	sign2.MaxDistance = 400
	local player = duel:GetAttribute("Player" .. label)
	textLabel(sign2, TextFormat.upper(if type(player) == "string" then player else "?"), SIDE_COLORS[label], 0, 0.26, 2)
	textLabel(sign2, TextFormat.upper(entry.Name), rarity.Color, 0.26, 0.32)
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0.05, 0.62)
	bar.Size = UDim2.fromScale(0.9, 0.34)
	bar.BackgroundColor3 = rgb(30, 26, 40)
	bar.Parent = sign2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Thickness = 3
	barStroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = rgb(110, 235, 40)
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill
	local hpText = textLabel(bar, "", Color3.new(1, 1, 1), 0, 1, 2)
	hpText.ZIndex = 2
	sign2.Parent = model
	return {
		model = model,
		home = home,
		toward = toward,
		lunge = 0,
		shake = 0,
		fill = fill,
		hpText = hpText,
		ko = false,
		winner = false,
	}
end

local function refreshBars(arena: Arena)
	for label, fighter in pairs(arena.fighters) do
		local hp = arena.duel:GetAttribute("Hp" .. label)
		local max = arena.duel:GetAttribute("Max" .. label)
		if type(hp) == "number" and type(max) == "number" and max > 0 then
			local f = math.clamp(hp / max, 0, 1)
			TweenService:Create(fighter.fill, TweenInfo.new(0.25), {
				Size = UDim2.fromScale(math.max(f, 0.001), 1),
				BackgroundColor3 = rgb(235, 60, 50):Lerp(rgb(110, 235, 40), f),
			}):Play()
			fighter.hpText.Text = string.format("%d / %d", hp, max)
		end
	end
end

local function popDamage(position: Vector3, text: string, color: Color3, big: boolean)
	local holder = block(folder, V(1, 1, 1), CF(position), Color3.new(), false)
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(if big then 9 else 6, if big then 3 else 2.2)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = holder
	local label = textLabel(gui, text, color, 0, 1, 3)
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { StudsOffset = V(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	Debris:AddItem(holder, 1)
end

local function burst(position: Vector3, color: Color3, count: number)
	local holder = block(folder, V(1, 1, 1), CF(position), Color3.new(), false)
	holder.Transparency = 1
	local fx = Instance.new("ParticleEmitter")
	fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fx.Color = ColorSequence.new(color)
	fx.Rate = 0
	fx.Speed = NumberRange.new(10, 22)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Lifetime = NumberRange.new(0.5, 1)
	fx.Size = NumberSequence.new(1.2, 0)
	fx.LightEmission = 1
	fx.Parent = holder
	fx:Emit(count)
	Debris:AddItem(holder, 1.5)
end

----------------------------------------------------------------------
-- Cycle de vie d'une arène
----------------------------------------------------------------------

local function add(duel: Instance)
	if not duel:IsA("Model") or arenas[duel] then
		return
	end
	local center = duel:GetAttribute("Center")
	if typeof(center) ~= "Vector3" then
		return
	end
	local root = Instance.new("Model")
	root.Name = duel.Name
	root.Parent = folder
	buildArena(root, center)
	local wheel = buildWheel(root, center)
	local arena: Arena = { duel = duel, root = root, center = center, fighters = {}, wheel = wheel }
	for _, label in ipairs({ "A", "B" }) do
		local fighter = buildFighter(root, center, duel, label, if label == "A" then -1 else 1)
		if fighter then
			arena.fighters[label] = fighter
		end
	end
	-- Panneau au-dessus de la roue : « A  VS  B ».
	local banner = Instance.new("BillboardGui")
	banner.Size = UDim2.fromScale(34, 5)
	banner.StudsOffsetWorldSpace = V(0, 0, 0)
	banner.LightInfluence = 0
	banner.MaxDistance = 600
	local anchor = block(root, V(1, 1, 1), CF(center + V(0, 27, -17)), Color3.new(), false)
	anchor.Transparency = 1
	banner.Adornee = anchor
	banner.Parent = anchor
	local a, b = duel:GetAttribute("PlayerA"), duel:GetAttribute("PlayerB")
	textLabel(banner, string.format("%s  VS  %s", TextFormat.upper(if type(a) == "string" then a else "?"),
		TextFormat.upper(if type(b) == "string" then b else "?")), Config.Rarities[8].Color, 0, 1, 4)
	arenas[duel] = arena
	refreshBars(arena)
	duel:GetAttributeChangedSignal("HpA"):Connect(function()
		refreshBars(arena)
	end)
	duel:GetAttributeChangedSignal("HpB"):Connect(function()
		refreshBars(arena)
	end)
end

local function remove(duel: Instance)
	local arena = arenas[duel]
	if arena then
		arena.root:Destroy()
		arenas[duel] = nil
	end
end

local duels = Workspace:WaitForChild("Duels")
duels.ChildAdded:Connect(add)
duels.ChildRemoved:Connect(remove)
for _, duel in ipairs(duels:GetChildren()) do
	add(duel)
end

Remotes.DuelEvent.OnClientEvent:Connect(function(kind: string, duel: any, a: any, b: any, c: any)
	if typeof(duel) ~= "Instance" then
		return
	end
	local arena = arenas[duel]
	if not arena then
		return
	end
	if kind == "Hit" and type(a) == "string" then
		local attacker = arena.fighters[a]
		local target = arena.fighters[if a == "A" then "B" else "A"]
		if attacker then
			attacker.lunge = 1
		end
		if target then
			task.delay(0.12, function()
				target.shake = 1
				local position = target.model:GetPivot().Position + V(0, 3, 0)
				local damage = if type(b) == "number" then b else 0
				if c == true then
					popDamage(position, string.format("-%d  CRITIQUE !", damage), rgb(255, 205, 50), true)
					burst(position, rgb(255, 205, 50), 30)
					Sounds.playAt("Knockback", position)
				else
					popDamage(position, string.format("-%d", damage), rgb(255, 80, 80), false)
					burst(position, Color3.new(1, 1, 1), 10)
					Sounds.playAt("BatHit", position)
				end
				local flash = Instance.new("Highlight")
				flash.FillColor = Color3.new(1, 1, 1)
				flash.FillTransparency = 0.2
				flash.OutlineTransparency = 1
				flash.Parent = target.model
				Debris:AddItem(flash, 0.12)
			end)
		end
	elseif kind == "End" and type(a) == "string" then
		local winner = arena.fighters[a]
		local loser = arena.fighters[if a == "A" then "B" else "A"]
		if loser then
			loser.ko = true
		end
		if winner then
			winner.winner = true
			burst(winner.model:GetPivot().Position + V(0, 4, 0), SIDE_COLORS[a], 60)
		end
	elseif kind == "Spin" and type(a) == "number" then
		local wheel = arena.wheel
		local target = sectorAngle(a)
		local turns = 5 * math.pi * 2
		wheel.from = wheel.angle
		wheel.to = wheel.angle + turns + ((target - wheel.angle) % (math.pi * 2))
		wheel.start = os.clock()
		wheel.spinning = true
	end
end)

local lastTick: { [Wheel]: number } = {}
RunService:BindToRenderStep("DuelPetPlacement", Enum.RenderPriority.Last.Value - 9, function(dt: number)
	local t = os.clock()
	for _, arena in pairs(arenas) do
		for _, fighter in pairs(arena.fighters) do
			fighter.lunge = math.max(0, fighter.lunge - dt * 3.5)
			fighter.shake = math.max(0, fighter.shake - dt * 4)
			local forward = math.sin(fighter.lunge * math.pi) * 4
			local jitter = fighter.shake * math.sin(t * 60) * 0.5
			local cf = fighter.home + fighter.toward * forward + V(0, 0, jitter)
			if fighter.ko then
				cf = fighter.home * CF(0, -0.5, 0) * ANG(0, 0, math.rad(80))
			elseif fighter.winner then
				cf = cf + V(0, math.abs(math.sin(t * 6)) * 2, 0)
			else
				cf = cf + V(0, math.abs(math.sin(t * 3)) * 0.3, 0) -- respire
			end
			fighter.model:PivotTo(cf)
		end
		local wheel = arena.wheel
		if wheel.spinning then
			local f = math.clamp((t - wheel.start) / DUEL.SpinTime, 0, 1)
			local eased = 1 - (1 - f) ^ 3
			wheel.angle = wheel.from + (wheel.to - wheel.from) * eased
			wheel.model:PivotTo(wheel.pivot * ANG(0, 0, wheel.angle))
			-- Petit « tic » à chaque case qui passe sous la flèche.
			local sector = math.floor(wheel.angle / (math.pi * 2 / #DUEL.Wheel))
			if sector ~= lastTick[wheel] then
				lastTick[wheel] = sector
				Sounds.playAt("Tick", wheel.pivot.Position)
			end
			if f >= 1 then
				wheel.spinning = false
				burst(wheel.pivot.Position + V(0, WHEEL_RADIUS, 1), rgb(255, 205, 50), 50)
			end
		end
	end
end)
