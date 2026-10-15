--!strict
-- EvolutionMachine : la capsule d'évolution de chaque base, un cylindre de stase dehors derrière la base (état publié
-- par server/EggController sur la pièce Base_N.EvolutionCapsule.EvolutionMachine, règles dans Config.Evolution).
--   - Dans le cylindre : l'œuf en stase qui flotte et tourne dans une brume froide, plus gros et plus lumineux à
--     chaque stade ; les anneaux lumineux pulsent quand la capsule est occupée.
--   - Panneau au-dessus : stade (★☆☆ NORMAL / ★★☆ ÉVOLUÉ / ★★★ ULTIME), temps avant la prochaine tentative, ou
--     « IL N'ÉVOLUERA PLUS » quand l'œuf a atteint sa limite (secrète, tirée au hasard).
--   - Bulle [E] pour le propriétaire : « Mettre un œuf » (fenêtre de choix parmi ses œufs en couveuse) ou
--     « Faire éclore » (à maintenir). Le serveur revérifie tout (Remotes.Evolution).
--   - Effets : l'œuf choisi vole de son nid à la machine ; gerbe et message à chaque évolution ; nuage gris quand
--     il a atteint sa limite. L'éclosion elle-même est jouée par client/Eggs.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.EggIncubation)
local Builder = require(ReplicatedStorage.Shared.EggModelBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local EVOLUTION = Config.Evolution
local player = Players.LocalPlayer
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 214, 70)
local PURPLE = Color3.fromRGB(170, 90, 240)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local STAGE_NAMES = { "NORMAL", "ÉVOLUÉ", "ULTIME" }

local visuals = Instance.new("Folder")
visuals.Name, visuals.Parent = "EvolutionVisuals", Workspace

local function outline(label: TextLabel, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Parent = label
end

local function stars(stage: number): string
	return string.rep("★", stage) .. string.rep("☆", #EVOLUTION.Names - stage)
end

local function stageColor(rarityId: string, stage: number): Color3
	local rarity = Config.Rarities[Config.RarityIndex[rarityId] or 1]
	return if stage >= 3 then GOLD elseif stage == 2 then rarity.Color:Lerp(WHITE, 0.45) else rarity.Color
end

----------------------------------------------------------------------
-- Fenêtre : choisir l'œuf à mettre dans la machine
----------------------------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "EvolutionMachine"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 4
screen.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(screen)
local window = MenuKit.window(root, "Capsule d'évolution", Vector2.new(780, 440), PURPLE)
local explain = UiStyle.text(window.content, "", 17, WHITE, UiStyle.BODY_FONT)
explain.Size = UDim2.new(1, 0, 0, 66)
explain.TextWrapped = true
explain.TextYAlignment = Enum.TextYAlignment.Top
explain.ZIndex = 3
explain.Text = "Choisis un œuf : il n'éclora plus tout seul. Plus il reste en stase dans la capsule, plus le familier qui en sortira "
	.. "peut être ÉVOLUÉ (revenu x" .. EVOLUTION.IncomeMultiplier[2] .. ") puis ULTIME (x" .. EVOLUTION.IncomeMultiplier[3]
	.. "). Mais chaque œuf a sa limite, et c'est la chance qui décide ! Tu l'ouvres quand tu veux."
local row = Instance.new("ScrollingFrame")
row.BackgroundTransparency = 1
row.BorderSizePixel = 0
row.Position = UDim2.fromOffset(0, 74)
row.Size = UDim2.new(1, 0, 1, -74)
row.ScrollingDirection = Enum.ScrollingDirection.X
row.AutomaticCanvasSize = Enum.AutomaticSize.X
row.CanvasSize = UDim2.new()
row.ScrollBarThickness = 8
row.ZIndex = 3
row.Parent = window.content
do
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
end
local empty = UiStyle.text(window.content, "Tu n'as aucun œuf en couveuse. Nourris le trou noir pour en gagner !", 22, WHITE, UiStyle.BODY_FONT)
empty.Position = UDim2.fromOffset(0, 140)
empty.Size = UDim2.new(1, 0, 0, 60)
empty.TextWrapped = true
empty.ZIndex = 3

local function myBase(): Model?
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	for _, base in ipairs(map:GetChildren()) do
		local capsule = base:FindFirstChild("EvolutionCapsule")
		local machine = capsule and capsule:FindFirstChild("EvolutionMachine")
		if base:IsA("Model") and machine and machine:GetAttribute("OwnerUserId") == player.UserId then
			return base
		end
	end
	return nil
end

local function openPicker()
	for _, child in ipairs(row:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local base = myBase()
	local folder = base and base:FindFirstChild("Eggs")
	local anchors: { BasePart } = {}
	if folder then
		for _, anchor in ipairs(folder:GetChildren()) do
			if anchor:IsA("BasePart") and type(anchor:GetAttribute("ReadyAt")) == "number" then
				table.insert(anchors, anchor)
			end
		end
	end
	-- Les plus rares d'abord (ce sont eux qu'on a envie de faire évoluer).
	table.sort(anchors, function(a, b)
		local ra = Config.RarityIndex[a:GetAttribute("Rarity") :: string] or 0
		local rb = Config.RarityIndex[b:GetAttribute("Rarity") :: string] or 0
		if ra ~= rb then
			return ra > rb
		end
		return (a:GetAttribute("ReadyAt") :: number) < (b:GetAttribute("ReadyAt") :: number)
	end)
	empty.Visible = #anchors == 0
	for order, anchor in ipairs(anchors) do
		local rarityId = anchor:GetAttribute("Rarity") :: string
		local rarity = Config.Rarities[Config.RarityIndex[rarityId] or 1]
		local card = UiStyle.brightCard(row, UDim2.fromOffset(160, 300), rarity.Color)
		card.LayoutOrder = order
		card.ZIndex = 3
		local viewport = MenuKit.eggViewport(card, rarityId)
		viewport.Position = UDim2.fromOffset(10, 8)
		viewport.Size = UDim2.fromOffset(140, 140)
		viewport.ZIndex = 4
		local name = UiStyle.text(card, "ŒUF " .. TextFormat.upper(rarity.Name), 20, WHITE, UiStyle.BODY_FONT)
		name.Position = UDim2.fromOffset(4, 152)
		name.Size = UDim2.new(1, -8, 0, 26)
		name.TextScaled = true
		name.ZIndex = 4
		local left = math.max(0, (anchor:GetAttribute("ReadyAt") :: number) - Workspace:GetServerTimeNow())
		local time = UiStyle.text(card, "éclot dans " .. Eggs.Time(left), 16, WHITE, UiStyle.BODY_FONT)
		time.Position = UDim2.fromOffset(4, 180)
		time.Size = UDim2.new(1, -8, 0, 22)
		time.ZIndex = 4
		local chance = UiStyle.text(card, "1re évolution vers " .. Eggs.Time(Eggs.Duration(rarityId) * EVOLUTION.StageTimeFactor[1]), 14, GOLD, UiStyle.BODY_FONT)
		chance.Position = UDim2.fromOffset(4, 204)
		chance.Size = UDim2.new(1, -8, 0, 36)
		chance.TextWrapped = true
		chance.ZIndex = 4
		local put = UiStyle.button(card, "METTRE", UDim2.new(1, -20, 0, 48), UiStyle.Colors.Green, 26)
		put.Position = UDim2.new(0, 10, 1, -56)
		put.ZIndex = 4
		put.Activated:Connect(function()
			Remotes.Evolution:FireServer("Insert", anchor.Name)
			window.close()
		end)
	end
	window.open()
end

----------------------------------------------------------------------
-- Les machines : œuf sous la cloche, panneau, bulle [E]
----------------------------------------------------------------------

type Machine = {
	part: BasePart,
	egg: Model?,
	eggKey: string?, -- rareté + stade de l'œuf affiché (on le refait quand ça change)
	light: PointLight,
	gui: BillboardGui,
	title: TextLabel,
	stageLabel: TextLabel,
	status: TextLabel,
	prompt: ProximityPrompt?,
	rings: { BasePart }, -- anneaux lumineux du cylindre (ils pulsent quand la capsule est occupée)
	mist: ParticleEmitter, -- brume froide dans le cylindre
}
local machines: { Machine } = {}
local EGG_HEIGHT = 5.2 -- studs au-dessus du socle : le milieu du cylindre de verre

local function refreshPrompt(machine: Machine)
	local mine = machine.part:GetAttribute("OwnerUserId") == player.UserId
	if not mine then
		if machine.prompt then
			machine.prompt:Destroy()
			machine.prompt = nil
		end
		return
	end
	local prompt: ProximityPrompt
	if machine.prompt then
		prompt = machine.prompt
	else
		local created = Instance.new("ProximityPrompt")
		created.Name = "EvolutionPrompt"
		created.ObjectText = "Capsule d'évolution"
		created.KeyboardKeyCode = Enum.KeyCode.E
		created.MaxActivationDistance = EVOLUTION.UseDistance
		created.RequiresLineOfSight = false
		created.Parent = machine.part
		created.Triggered:Connect(function()
			if machine.part:GetAttribute("Occupied") == true then
				Remotes.Evolution:FireServer("Hatch")
			else
				openPicker()
			end
		end)
		machine.prompt = created
		prompt = created
	end
	local occupied = machine.part:GetAttribute("Occupied") == true
	prompt.ActionText = if occupied then "Faire éclore" else "Mettre un œuf"
	prompt.HoldDuration = if occupied then 1.2 else 0 -- ouvrir l'œuf se confirme en maintenant la touche
end

local function addMachine(part: BasePart, capsule: Instance)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Shadows = 14, 0, PURPLE, false
	light.Parent = part
	local rings: { BasePart } = {}
	for _, child in ipairs(capsule:GetChildren()) do
		if child:IsA("BasePart") and child.Name:match("^StasisRing") then
			table.insert(rings, child)
		end
	end
	local mistHolder = Instance.new("Attachment")
	mistHolder.Position = V(0, part.Size.Y / 2 + 0.5, 0)
	mistHolder.Parent = part
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = SMOKE
	mist.Color = ColorSequence.new(Color3.fromRGB(200, 245, 255))
	mist.Rate = 0
	mist.Lifetime = NumberRange.new(2, 3)
	mist.Speed = NumberRange.new(0.8, 1.6)
	mist.SpreadAngle = Vector2.new(25, 25)
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.6) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Parent = mistHolder
	local gui = Instance.new("BillboardGui")
	gui.Name = "EvolutionStatus"
	gui.Adornee = part
	gui.Size = UDim2.fromScale(12, 4.6)
	gui.StudsOffsetWorldSpace = V(0, 21, 0)
	gui.LightInfluence, gui.MaxDistance = 0, 110
	local function line(y: number, height: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position, label.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, height)
		label.Font, label.TextScaled = Enum.Font.LuckiestGuy, true
		label.TextColor3 = color
		label.TextWrapped = true
		outline(label, 2.5)
		label.Parent = gui
		return label
	end
	local machine: Machine = {
		part = part,
		egg = nil,
		eggKey = nil,
		light = light,
		gui = gui,
		title = line(0, 0.3, Color3.fromRGB(220, 180, 255)),
		stageLabel = line(0.3, 0.32, GOLD),
		status = line(0.62, 0.38, WHITE),
		prompt = nil,
		rings = rings,
		mist = mist,
	}
	gui.Parent = part
	table.insert(machines, machine)
	for _, name in ipairs({ "OwnerUserId", "Occupied" }) do
		part:GetAttributeChangedSignal(name):Connect(function()
			refreshPrompt(machine)
		end)
	end
	refreshPrompt(machine)
end

task.spawn(function()
	local map = Workspace:WaitForChild("Map")
	local function watch(base: Instance)
		local capsule = base:WaitForChild("EvolutionCapsule", 30)
		local part = capsule and capsule:WaitForChild("EvolutionMachine", 30)
		if part and part:IsA("BasePart") and capsule then
			addMachine(part, capsule)
		end
	end
	for _, child in ipairs(map:GetChildren()) do
		if child:IsA("Model") and child.Name:match("^Base_") then
			task.spawn(watch, child)
		end
	end
end)

-- Chaque image : l'œuf sous la cloche, la lumière, le panneau.
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 / 30 then
		return
	end
	elapsed = 0
	local camera = Workspace.CurrentCamera
	local clock, now = os.clock(), Workspace:GetServerTimeNow()
	for _, machine in ipairs(machines) do
		local part = machine.part
		local occupied = part:GetAttribute("Occupied") == true
		local rarityId = part:GetAttribute("Rarity")
		local stage = part:GetAttribute("Stage")
		local near = camera ~= nil and (camera.CFrame.Position - part.Position).Magnitude < 160
		if not occupied or type(rarityId) ~= "string" or type(stage) ~= "number" then
			if machine.egg then
				machine.egg:Destroy()
				machine.egg, machine.eggKey = nil, nil
			end
			machine.light.Brightness = 0
			machine.mist.Rate = 0
			for _, band in ipairs(machine.rings) do
				band.Transparency = 0.6
			end
			local mine = part:GetAttribute("OwnerUserId") == player.UserId
			machine.title.Text = "ÉVOLUTION"
			machine.stageLabel.Text = ""
			machine.status.Text = if mine then "[E] METS UN ŒUF POUR LE FAIRE ÉVOLUER" else ""
			machine.gui.Enabled = part:GetAttribute("OwnerUserId") ~= nil
			continue
		end
		machine.gui.Enabled = true
		local color = stageColor(rarityId, stage)
		local key = rarityId .. "#" .. stage
		if machine.eggKey ~= key and near then
			if machine.egg then
				machine.egg:Destroy()
			end
			local egg = Builder.Build(rarityId)
			egg:ScaleTo(1.25 + stage * 0.18)
			for _, piece in ipairs(egg:GetDescendants()) do
				if piece:IsA("BasePart") then
					piece.Anchored, piece.CanCollide, piece.CanQuery, piece.CanTouch = true, false, false, false
				end
			end
			if stage >= 2 and egg.PrimaryPart then
				local sparkles = Instance.new("ParticleEmitter")
				sparkles.Texture, sparkles.Color = SPARK, ColorSequence.new(color, WHITE)
				sparkles.Rate = stage * 6
				sparkles.Lifetime, sparkles.Speed = NumberRange.new(0.6, 1.2), NumberRange.new(0.5, 1.5)
				sparkles.SpreadAngle = Vector2.new(180, 180)
				sparkles.LightEmission = 1
				sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
				sparkles.Parent = egg.PrimaryPart
			end
			egg.Parent = visuals
			machine.egg, machine.eggKey = egg, key
		end
		local egg = machine.egg
		if egg then
			local hover = 0.6 + math.sin(clock * 2) * 0.25
			egg:PivotTo(part.CFrame * CF(0, part.Size.Y / 2 + EGG_HEIGHT - 2.5 + hover, 0) * ANG(0, clock * (0.6 + stage * 0.4), 0))
		end
		machine.light.Color = color
		machine.light.Brightness = 1 + stage * 0.8 + math.sin(clock * 3) * 0.3
		machine.mist.Rate = 4 + stage * 2
		for index, band in ipairs(machine.rings) do
			band.Color = color
			band.Transparency = 0.15 + 0.3 * (0.5 + 0.5 * math.sin(clock * 3 - index * 0.9)) -- une vague qui monte
		end
		local rarity = Config.Rarities[Config.RarityIndex[rarityId] or 1]
		machine.title.Text = "ŒUF " .. TextFormat.upper(rarity.Name)
		machine.title.TextColor3 = rarity.Color
		machine.stageLabel.Text = stars(stage) .. "  " .. STAGE_NAMES[stage]
		machine.stageLabel.TextColor3 = color
		local nextAt = part:GetAttribute("NextAt")
		if part:GetAttribute("Done") == true then
			machine.status.Text = if stage >= #EVOLUTION.Names
				then "ÉVOLUTION MAXIMALE !  [E] FAIRE ÉCLORE"
				else "IL N'ÉVOLUERA PLUS  •  [E] FAIRE ÉCLORE"
			machine.status.TextColor3 = if stage >= #EVOLUTION.Names then GOLD else Color3.fromRGB(255, 120, 120)
		elseif type(nextAt) == "number" then
			machine.status.Text = "TENTATIVE D'ÉVOLUTION DANS " .. Eggs.Time(nextAt - now)
			machine.status.TextColor3 = WHITE
		end
	end
end)

----------------------------------------------------------------------
-- Effets : l'œuf qui vole jusqu'à la machine, les évolutions
----------------------------------------------------------------------

local function burst(position: Vector3, color: Color3, count: number, texture: string, speed: number)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture, emitter.Color = texture, ColorSequence.new(color, WHITE)
	emitter.Rate, emitter.Lifetime, emitter.Speed = 0, NumberRange.new(0.6, 1.2), NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = if texture == SPARK then 1 else 0
	emitter.Drag = 2
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 1.5)
end

local function ring(cf: CFrame, color: Color3, radius: number)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = V(0.3, 1, 1)
	part.CFrame = cf * ANG(0, 0, math.pi / 2)
	part.Color, part.Material, part.Transparency = color, Enum.Material.Neon, 0.15
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Parent = visuals
	TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = V(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(part, 0.7)
end

Remotes.Evolution.OnClientEvent:Connect(function(ownerId: number, kind: string, stage: number, cf: CFrame, rarityId: string, key: string?)
	if typeof(cf) ~= "CFrame" or type(rarityId) ~= "string" then
		return
	end
	local mine = ownerId == player.UserId
	local eggSpot = cf * CF(0, EGG_HEIGHT, 0)
	if kind == "Inserted" then
		-- L'œuf quitte son nid et vole jusqu'à la machine.
		local map = Workspace:FindFirstChild("Map")
		local from: CFrame? = nil
		if map and type(key) == "string" then
			for _, base in ipairs(map:GetChildren()) do
				local folder = base:FindFirstChild("Eggs")
				local anchor = folder and folder:FindFirstChild(key)
				if anchor and anchor:IsA("BasePart") then
					from = anchor.CFrame
					anchor:SetAttribute("Leaving", true) -- client/Eggs retire l'œuf du nid
				end
			end
		end
		if from then
			local flying = Builder.Build(rarityId)
			flying:ScaleTo(1.3)
			flying:PivotTo(from)
			flying.Parent = visuals
			local start = os.clock()
			local connection: RBXScriptConnection
			connection = RunService.Heartbeat:Connect(function()
				local t = math.clamp((os.clock() - start) / 0.9, 0, 1)
				local position = from.Position:Lerp(eggSpot.Position, t) + V(0, math.sin(t * math.pi) * 8, 0)
				flying:PivotTo(CF(position) * ANG(0, t * 8, 0))
				if t >= 1 then
					connection:Disconnect()
					flying:Destroy()
					burst(eggSpot.Position, PURPLE, 25, SPARK, 8)
				end
			end)
		end
		if mine then
			Sounds.play("Purchase")
			Toast.show("ŒUF EN STASE DANS LA CAPSULE : IL VA TENTER D'ÉVOLUER !", PURPLE)
		end
	elseif kind == "Evolved" then
		local color = stageColor(rarityId, stage)
		burst(eggSpot.Position, color, 50 + stage * 30, SPARK, 14)
		ring(cf * CF(0, 0.2, 0), color, 10 + stage * 4)
		ring(cf * CF(0, 0.2, 0), WHITE, 6 + stage * 3)
		if mine then
			Sounds.play("RareDrop")
			Toast.show(string.format("TON ŒUF A ÉVOLUÉ : %s %s !", stars(stage), STAGE_NAMES[stage]), color)
		else
			Sounds.playAt("HoleBonus", eggSpot.Position)
		end
	elseif kind == "Maxed" then
		-- Limite atteinte : petit nuage gris, l'œuf reste dans la machine jusqu'à ce que le joueur l'ouvre.
		burst(eggSpot.Position, Color3.fromRGB(150, 150, 160), 20, SMOKE, 5)
		if mine then
			Sounds.play("Error")
			Toast.show("CET ŒUF A ATTEINT SA LIMITE : IL N'ÉVOLUERA PLUS. OUVRE-LE QUAND TU VEUX !", Color3.fromRGB(255, 140, 140))
		end
	end
end)
