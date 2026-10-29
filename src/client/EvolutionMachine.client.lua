--!strict
-- EvolutionMachine : la capsule d'évolution de chaque base, un cylindre de stase dehors derrière la base (état publié
-- par server/EggController sur la pièce Base_N.EvolutionCapsule.EvolutionMachine, règles dans Config.Evolution).
--   - Dans le cylindre : l'œuf en stase qui flotte et tourne dans une brume froide, plus gros et plus lumineux à
--     chaque stade ; les anneaux lumineux pulsent quand la capsule est occupée.
--   - Panneau au-dessus, en mots simples (26 oct., UI_UX_GUIDELINES.md §7) : « PRÊT DANS 1:23 » (le temps normal de
--     l'œuf, on ne peut pas l'ouvrir avant), puis « ESSAI ★★ DANS 4:10 » + « CHANCE 60 % » (tirage au sort montré
--     « ESSAI... » puis BRAVO / RATÉ). Stade : ★☆☆ NORMAL / ★★☆ ÉVOLUÉ / ★★★ ULTIME.
--   - Bulle [E] « Ouvrir » pour le propriétaire : toujours le menu de la capsule (client/CapsuleMenu : comment ça
--     marche, ses cases, ses œufs, METTRE / OUVRIR). Le serveur revérifie tout (Remotes.Evolution).
--   - La capsule suit le niveau du propriétaire (monde le plus loin, attribut CapsuleTier) : de plus en plus grande et
--     épique, au thème de son monde (client/CapsuleDecor), avec son bonus (Config.Evolution.SpeedPerTier...).
--   - Effets : l'œuf choisi vole de son nid à la machine ; gerbe et message à chaque évolution ; nuage gris quand
--     il a atteint sa limite. L'éclosion elle-même est jouée par client/Eggs.
local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
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
local CapsuleDecor = require(script.Parent.CapsuleDecor)
local CapsuleMenu = require(script.Parent.CapsuleMenu)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)

local EVOLUTION = Config.Evolution
local player = Players.LocalPlayer
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 214, 70)
-- Clavier : les panneaux disent « [E] » ; au doigt et à la manette, la bulle montre déjà quoi toucher.
local KEYS = not ScreenScale.isTouch() and not ScreenScale.isConsole()
local PURPLE = Color3.fromRGB(170, 90, 240)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local STAGE_NAMES = { "NORMAL", "ÉVOLUÉ", "ULTIME" } -- (mots simples des panneaux : UI_UX_GUIDELINES.md §7)

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

-- Bonus de la capsule à ce niveau : chances d'aller jusqu'à Ultime (%) et tentatives plus tôt (%).
local function tierBonus(tier: number): (number, number)
	local weights = Eggs.MaxStageWeights(tier)
	local total = 0
	for _, weight in ipairs(weights) do
		total += weight
	end
	local ultime = math.floor(weights[#weights] / math.max(total, 1) * 100 + 0.5)
	local faster = math.floor(EVOLUTION.SpeedPerTier * (tier - 1) * 100 + 0.5)
	return ultime, faster
end

local function stageColor(rarityId: string, stage: number): Color3
	local rarity = Config.Rarities[Config.RarityIndex[rarityId] or 1]
	return if stage >= 3 then GOLD elseif stage == 2 then rarity.Color:Lerp(WHITE, 0.45) else rarity.Color
end

----------------------------------------------------------------------
-- Menu de la capsule (client/CapsuleMenu) : [E] devant sa capsule l'ouvre
----------------------------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "EvolutionMachine"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 4
screen.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(screen)
local menu = CapsuleMenu.create(root)

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
	hint: TextLabel, -- étape / ce qui va se passer ensuite
	prompt: ProximityPrompt?,
	rings: { BasePart }, -- anneaux lumineux du cylindre (ils pulsent quand la capsule est occupée)
	mist: ParticleEmitter, -- brume froide dans le cylindre
	capsule: Model,
	decor: CapsuleDecor.Decor?,
	decorTier: number?,
}
local machines: { Machine } = {}
local rolling: { [number]: number } = {} -- propriétaire -> fin du tirage au sort affiché (os.clock)
local EGG_HEIGHT = 5.2 -- studs au-dessus du socle : le milieu du cylindre de verre

-- Ce que fait [E] sur la capsule (plusieurs chambres, +1 par Rebirth) : ouvrir l'œuf montré s'il n'évoluera plus, sinon
-- en mettre un autre s'il reste une chambre, sinon ouvrir l'œuf montré dès que son incubation est finie.
local function machineAction(machine: Machine): string
	local part = machine.part
	local occupied = part:GetAttribute("Occupied") == true
	local readyAt = part:GetAttribute("ReadyAt")
	local openable = occupied and not (type(readyAt) == "number" and readyAt > Workspace:GetServerTimeNow())
	local chambers, used = part:GetAttribute("Chambers"), part:GetAttribute("ChambersUsed")
	local free = if type(chambers) == "number" and type(used) == "number" then used < chambers else not occupied
	if openable and part:GetAttribute("Done") == true then
		return "Hatch"
	elseif free then
		return "Insert"
	elseif openable then
		return "Hatch"
	end
	return "Wait"
end

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
		created.ActionText = "Ouvrir"
		created.KeyboardKeyCode = Enum.KeyCode.E
		created.MaxActivationDistance = EVOLUTION.UseDistance
		created.RequiresLineOfSight = false
		created.HoldDuration = 0
		created.Parent = machine.part
		-- Une seule action, toujours la même : le menu de la capsule (client/CapsuleMenu) montre tout et explique.
		created.Triggered:Connect(function()
			menu.open(machine.part)
		end)
		machine.prompt = created
		prompt = created
	end
	local action = machineAction(machine)
	prompt.ObjectText = if action == "Hatch" then "Capsule : œuf prêt !" elseif action == "Insert" then "Capsule : mets un œuf" else "Capsule"
end

-- Niveau de la capsule (monde le plus loin de son propriétaire) : taille, couleur et décor.
local function applyTier(machine: Machine)
	local owned = machine.part:GetAttribute("OwnerUserId") ~= nil
	local rawTier = machine.part:GetAttribute("CapsuleTier")
	local tier = if owned and type(rawTier) == "number" then rawTier else 1
	if machine.decorTier == tier then
		return
	end
	machine.decorTier = tier
	if machine.decor then
		machine.decor.folder:Destroy()
	end
	machine.capsule:ScaleTo(CapsuleDecor.Scale(tier))
	local accent = CapsuleDecor.Accent(tier)
	for _, child in ipairs(machine.capsule:GetChildren()) do
		if child:IsA("BasePart") and (child.Name == "Foot" or child.Name == "EmitterTip"
			or (child.Name == "ConsoleButton" and child.Color.R < 0.9)) then
			child.Color = accent
		end
	end
	machine.decor = CapsuleDecor.Build(machine.part, tier, visuals)
end

local function addMachine(part: BasePart, capsule: Model)
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
	gui.Size = UDim2.fromScale(13, 5.8)
	gui.StudsOffsetWorldSpace = V(0, 21, 0)
	gui.LightInfluence, gui.MaxDistance = 0, 110
	local function line(y: number, height: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position, label.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, height)
		label.FontFace, label.TextScaled = Typography.Face, true
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
		title = line(0, 0.24, Color3.fromRGB(220, 180, 255)),
		stageLabel = line(0.24, 0.24, GOLD),
		status = line(0.5, 0.28, WHITE),
		hint = line(0.79, 0.21, Color3.fromRGB(210, 210, 225)),
		prompt = nil,
		rings = rings,
		mist = mist,
		capsule = capsule,
		decor = nil,
		decorTier = nil,
	}
	gui.Parent = part
	table.insert(machines, machine)
	for _, name in ipairs({ "OwnerUserId", "Occupied", "ReadyAt" }) do
		part:GetAttributeChangedSignal(name):Connect(function()
			refreshPrompt(machine)
		end)
	end
	for _, name in ipairs({ "OwnerUserId", "CapsuleTier" }) do
		part:GetAttributeChangedSignal(name):Connect(function()
			applyTier(machine)
		end)
	end
	refreshPrompt(machine)
	applyTier(machine)
end

task.spawn(function()
	local map = Workspace:WaitForChild("Map")
	local function watch(base: Instance)
		local capsule = base:WaitForChild("EvolutionCapsule", 30)
		local part = capsule and capsule:WaitForChild("EvolutionMachine", 30)
		if part and part:IsA("BasePart") and capsule and capsule:IsA("Model") then
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
		local decor = machine.decor
		local scale = if decor then decor.scale else 1
		local accent = if decor then decor.accent else PURPLE
		if decor and near then
			decor.update(clock)
		end
		machine.gui.StudsOffsetWorldSpace = V(0, 21 * scale + (if (machine.decorTier or 1) >= 7 then 4 else 0), 0)
		if not occupied or type(rarityId) ~= "string" or type(stage) ~= "number" then
			if machine.egg then
				machine.egg:Destroy()
				machine.egg, machine.eggKey = nil, nil
			end
			machine.light.Brightness = 0
			machine.mist.Rate = 0
			for _, band in ipairs(machine.rings) do
				band.Color = accent
				band.Transparency = 0.45
			end
			local mine = part:GetAttribute("OwnerUserId") == player.UserId
			local tier = machine.decorTier or 1
			local ultime, faster = tierBonus(tier)
			machine.title.Text = "CAPSULE " .. TextFormat.upper(Config.Worlds[math.clamp(tier, 1, #Config.Worlds)].Name)
			machine.title.TextColor3 = accent
			machine.stageLabel.Text = string.format("★★ %d %%  •  ★★★ %d %%", math.floor(Eggs.StageChance(1, tier) * 100 + 0.5), ultime)
				.. (if faster > 0 then string.format("  •  %d %% PLUS RAPIDE", faster) else "")
			machine.stageLabel.TextColor3 = GOLD
			machine.status.Text = if mine then (if KEYS then "[E] METS UN ŒUF ICI" else "METS UN ŒUF ICI") else ""
			machine.status.TextColor3 = WHITE
			machine.hint.Text = "IL DEVIENT PLUS FORT : ★★ PUIS ★★★"
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
			egg:ScaleTo((1.25 + stage * 0.18) * scale)
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
			egg:PivotTo(part.CFrame * CF(0, part.Size.Y / 2 + (EGG_HEIGHT - 2.5 + hover) * scale, 0) * ANG(0, clock * (0.6 + stage * 0.4), 0))
		end
		machine.light.Color = color
		machine.light.Brightness = 1 + stage * 0.8 + (machine.decorTier or 1) * 0.25 + math.sin(clock * 3) * 0.3
		machine.light.Range = 14 + (machine.decorTier or 1) * 2
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
		local readyAt = part:GetAttribute("ReadyAt")
		local ownerId = part:GetAttribute("OwnerUserId")
		local tier = machine.decorTier or 1
		local chance = math.floor(Eggs.StageChance(stage, tier) * 100 + 0.5)
		if type(ownerId) == "number" and (rolling[ownerId] or 0) > clock then
			-- Tirage au sort en cours (le résultat s'affiche ensuite) : le panneau clignote.
			machine.status.Text = "ESSAI..."
			machine.status.TextColor3 = if math.floor(clock * 8) % 2 == 0 then GOLD else WHITE
			machine.hint.Text = string.format("%s ?  CHANCE %d %%", stars(math.min(stage + 1, #EVOLUTION.Names)), chance)
		elseif type(readyAt) == "number" and readyAt > now then
			machine.status.Text = "PRÊT DANS " .. Eggs.Time(readyAt - now)
			machine.status.TextColor3 = WHITE
			machine.hint.Text = string.format("PUIS ESSAI %s  •  CHANCE %d %%", stars(stage + 1), chance)
		elseif part:GetAttribute("Done") == true then
			machine.status.Text = if stage >= #EVOLUTION.Names
				then (if KEYS then "AU MAXIMUM !  [E] OUVRIR" else "AU MAXIMUM !  OUVRE-LE")
				else (if KEYS then "IL NE GRANDIRA PLUS  •  [E] OUVRIR" else "IL NE GRANDIRA PLUS  •  OUVRE-LE")
			machine.status.TextColor3 = if stage >= #EVOLUTION.Names then GOLD else Color3.fromRGB(255, 120, 120)
			machine.hint.Text = if stage >= #EVOLUTION.Names then "LE PLUS FORT POSSIBLE !"
				else "IL RESTE " .. stars(stage)
		elseif type(nextAt) == "number" then
			machine.status.Text = string.format("ESSAI %s DANS %s", stars(stage + 1), Eggs.Time(nextAt - now))
			machine.status.TextColor3 = WHITE
			machine.hint.Text = string.format(if KEYS then "CHANCE %d %%  •  [E] POUR L'OUVRIR" else "CHANCE %d %%  •  TU PEUX L'OUVRIR", chance)
		end
		-- Chambres (+1 par Rebirth) : plusieurs œufs évoluent en même temps ; la capsule montre le plus avancé.
		local chambers, used = part:GetAttribute("Chambers"), part:GetAttribute("ChambersUsed")
		if type(chambers) == "number" and chambers > 1 and type(used) == "number" then
			machine.title.Text ..= string.format("  •  CASES %d/%d", used, chambers)
		end
		if machine.prompt then
			refreshPrompt(machine)
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

-- Résultat d'une tentative, après le suspense : gerbe et message, ou nuage gris si elle a raté (l'œuf garde son stade
-- et reste dans la capsule jusqu'à ce que le joueur l'ouvre).
local ROLL_TIME = 1.6
local function showResult(ownerId: number, kind: string, stage: number, cf: CFrame, rarityId: string)
	local mine = ownerId == player.UserId
	local eggSpot = cf * CF(0, EGG_HEIGHT, 0)
	if kind == "Evolved" then
		local color = stageColor(rarityId, stage)
		burst(eggSpot.Position, color, 50 + stage * 30, SPARK, 14)
		ring(cf * CF(0, 0.2, 0), color, 10 + stage * 4)
		ring(cf * CF(0, 0.2, 0), WHITE, 6 + stage * 3)
		if mine then
			Sounds.play("RareDrop")
			Toast.show(string.format("BRAVO ! TON ŒUF EST %s %s !", stars(stage), STAGE_NAMES[stage]), color)
		else
			Sounds.playAt("HoleBonus", eggSpot.Position)
		end
	else
		burst(eggSpot.Position, Color3.fromRGB(150, 150, 160), 20, SMOKE, 5)
		if mine then
			Sounds.play("Error")
			Toast.show(string.format("RATÉ ! IL RESTE %s. OUVRE-LE QUAND TU VEUX", stars(stage)),
				Color3.fromRGB(255, 140, 140))
		end
	end
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
			Toast.show("ŒUF DANS LA CAPSULE ! ATTENDS, IL VA GRANDIR", PURPLE)
		end
	elseif kind == "Evolved" or kind == "Maxed" then
		-- Suspense : le panneau montre le tirage au sort (« TENTATIVE EN COURS... »), puis le résultat.
		rolling[ownerId] = os.clock() + ROLL_TIME
		if mine then
			Sounds.play("UiClick")
		end
		task.delay(ROLL_TIME, function()
			showResult(ownerId, kind, stage, cf, rarityId)
		end)
	end
end)
