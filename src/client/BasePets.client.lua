--!strict
-- BasePets : affiche les familiers qui se baladent dans chaque base (style Steal an Egg).
-- C'est le SERVEUR qui décide (server/BasePetsController) : un repère invisible Base_N.Pets.<PetId> par espèce,
-- avec son trajet en cours dans l'attribut "Walk". Ici, on construit le modèle et on le place à la position
-- calculée avec l'horloge commune (shared/PetWander) : tous les joueurs voient les familiers au même endroit.
-- L'animation (marche, sautille, ondule, plane, se balance, tourne) n'est qu'un effet visuel local ; les familiers
-- refaits en briques ont chacun leur démarche (shared/PetGaits : pas, bonds, roulis, ondulation, envol, roue...).
-- Vol : on crée ici (localement) la bulle [E] "Voler" sur le repère, on déplace le repère sur le familier pour que
-- la bulle le suive, et on ne l'affiche que si le vol est possible (base adverse ouverte, mains libres). Validée, elle
-- envoie Remotes.StealPet ; le serveur revérifie tout (server/StealController).
-- Arrivée d'un nouveau familier (attribut "ArrivedAt" posé par le serveur après un tirage, une fusion ou un vol) :
-- il tombe du ciel, gerbe d'étincelles à la couleur de sa rareté, étiquette "NOUVEAU", rayon de lumière si Légendaire+.

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetGaits = require(ReplicatedStorage.Shared.PetGaits)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local PetSizes = require(ReplicatedStorage.Shared.PetSizes)
local PetWander = require(ReplicatedStorage.Shared.PetWander)
local PowerCap = require(ReplicatedStorage.Shared.PowerCap)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local Sounds = require(script.Parent.Sounds)

-- Au-delà, les familiers d'une base ne sont plus animés (plus court sur téléphone pour les performances).
local VIEW_DISTANCE = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 150 else 260

local player = Players.LocalPlayer

type Shown = {
	anchor: BasePart,
	prompt: ProximityPrompt?,
	model: Model,
	styleName: string,
	style: PetWander.Style,
	gait: PetGaits.Gait?, -- démarche propre au familier (sinon : style de sa silhouette)
	ease: string,
	leg: PetWander.Leg?,
	heading: number,
	bank: number, -- inclinaison dans les virages (démarche)
	bottomOffset: number, -- distance pivot -> bas du modèle
	topOffset: number, -- distance pivot -> haut du modèle (pour l'étiquette)
	centerY: number, -- hauteur du centre du modèle au-dessus du pivot (roue)
	seed: number,
	arrivedAt: number?, -- heure serveur de son arrivée (animation de chute)
	own: boolean, -- dans la base du joueur local (étiquette : revenu plafonné, shared/PowerCap)
}

local DROP_TIME = 0.7 -- durée de la chute (s)
local DROP_HEIGHT = 18 -- hauteur de départ (studs)
local ARRIVAL_WINDOW = 3 -- une arrivée plus ancienne (joueur qui arrive tard) n'est pas rejouée
local NEW_TAG_TIME = 5 -- durée de l'étiquette "NOUVEAU"

type BaseDisplay = {
	base: Model,
	platform: BasePart,
	pets: { [BasePart]: Shown },
}

local displays: { [Model]: BaseDisplay } = {}

local folder = Instance.new("Folder")
folder.Name = "BasePets"
folder.Parent = Workspace

local function setLabel(shown: Shown)
	local old = shown.model:FindFirstChild("PetLabel")
	if old then
		old:Destroy()
	end
	local petId = shown.model.Name
	local entry = PetCatalog.ById[petId]
	local root = shown.model.PrimaryPart
	if not entry or not root then
		return
	end
	local countValue = shown.anchor:GetAttribute("Count")
	local count = if type(countValue) == "number" then countValue else 1
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
	local stage = entry.Stage or 1 -- familier évolué (capsule d'évolution) ou muté : une ligne en plus au-dessus du nom
	local mutation = if entry.Mutation then Config.Mutations[Config.MutationIndex[entry.Mutation]] else nil
	local special = stage > 1 or mutation ~= nil
	-- Chez soi : le revenu réel, plafonné si le familier est trop fort pour soi (Config.PowerCap).
	local selfBest = if shown.own then PowerCap.SelfBestOf(player) else nil
	local capped = shown.own and PowerCap.IsCapped(petId, selfBest)
	local incomeText = NumberFormat.perSecond(if shown.own then PowerCap.Income(petId, selfBest) else PetCatalog.GetIncome(petId))
		.. (if capped then " (BLOQUÉ)" else "")
	local sign = Instance.new("BillboardGui")
	sign.Name = "PetLabel"
	sign.Adornee = root
	sign.Size = UDim2.fromScale(7, if special then 3 else 2.2)
	sign.StudsOffsetWorldSpace = Vector3.new(0, shown.topOffset + 1.4, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 70
	local function line(text: string, color: Color3, y: number, height: number)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.FontFace = Typography.Face
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		local outline = Instance.new("UIStroke")
		outline.Thickness = 2.5
		outline.Parent = label
		label.Parent = sign
	end
	if special then
		local name = TextFormat.upper(PetCatalog.ById[entry.BaseId or petId].Name)
		local tag = (if stage > 1 then string.rep("★", stage) .. " " .. TextFormat.upper(Config.Evolution.Names[stage]) else "")
			.. (if mutation then (if stage > 1 then " " else "") .. TextFormat.upper(mutation.Name) else "")
		line(tag, if mutation then mutation.Color else Color3.fromRGB(255, 214, 70), 0, 0.3)
		line(name .. (if count > 1 then " x" .. count else ""), rarity.Color, 0.3, 0.4)
		line(incomeText, if capped then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(110, 240, 70), 0.7, 0.3)
	else
		line(TextFormat.upper(entry.Name) .. (if count > 1 then " x" .. count else ""), rarity.Color, 0, 0.55)
		line(incomeText, if capped then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(110, 240, 70), 0.55, 0.45)
	end
	sign.Parent = shown.model
end

-- Effets d'arrivée : étiquette "NOUVEAU" tout de suite, puis à l'atterrissage étincelles + flash (+ rayon si rare).
local function playArrival(shown: Shown, arrivedAt: number)
	local now = Workspace:GetServerTimeNow()
	if now - arrivedAt > ARRIVAL_WINDOW then
		return
	end
	local hatched = shown.anchor:GetAttribute("Hatched") == true
	shown.arrivedAt = if hatched then nil else arrivedAt
	local model = shown.model
	local entry = PetCatalog.ById[model.Name]
	local root = model.PrimaryPart
	if not entry or not root then
		return
	end
	local rarityIndex = Config.RarityIndex[entry.Rarity] or 1
	local color = Config.Rarities[rarityIndex].Color

	local tag = Instance.new("BillboardGui")
	tag.Name = "NewTag"
	tag.Adornee = root
	tag.Size = UDim2.fromScale(6, 1.4)
	tag.StudsOffsetWorldSpace = Vector3.new(0, shown.topOffset + 3.8, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Typography.Face
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = if hatched then "ÉCLOSION !" else "NOUVEAU !"
	label.Position = UDim2.fromScale(0.2, 0)
	label.Size = UDim2.fromScale(0.8, 1)
	Icons.image(tag, "Sparkle", UDim2.fromScale(0.2, 1))
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Parent = label
	label.Parent = tag
	tag.Parent = model
	Debris:AddItem(tag, NEW_TAG_TIME)

	task.delay(if hatched then 0 else math.max(0, arrivedAt + DROP_TIME - now), function()
		if not model.Parent then
			return
		end
		-- Point d'impact : pièce invisible temporaire qui porte les étincelles et la lumière.
		local impact = Instance.new("Part")
		impact.Name = "ArrivalEffect"
		impact.Anchored = true
		impact.CanCollide = false
		impact.CanQuery = false
		impact.CanTouch = false
		impact.Transparency = 1
		impact.Size = Vector3.one
		impact.CFrame = CFrame.new(model:GetPivot().Position)
		impact.Parent = folder

		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(color)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(1.2, 0)
		sparks.Lifetime = NumberRange.new(0.6, 1.2)
		sparks.Speed = NumberRange.new(10, 22)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Acceleration = Vector3.new(0, -25, 0)
		sparks.Rate = 0
		sparks.Parent = impact
		sparks:Emit(20 + rarityIndex * 6)
		Sounds.playAt(if rarityIndex >= Config.Loot.AnnounceMinRarity then "RareDrop" else "PetArrival", impact.Position)

		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 16
		light.Brightness = 4
		light.Parent = impact
		TweenService:Create(light, TweenInfo.new(1), { Brightness = 0 }):Play()

		-- Légendaire ou mieux : rayon de lumière qui tombe du ciel sur le familier.
		if rarityIndex >= Config.Loot.AnnounceMinRarity then
			local beam = Instance.new("Part")
			beam.Name = "ArrivalBeam"
			beam.Shape = Enum.PartType.Cylinder
			beam.Material = Enum.Material.Neon
			beam.Color = color
			beam.Anchored = true
			beam.CanCollide = false
			beam.CanQuery = false
			beam.CanTouch = false
			beam.CastShadow = false
			beam.Transparency = 0.25
			beam.Size = Vector3.new(60, 3, 3)
			beam.CFrame = CFrame.new(impact.Position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			beam.Parent = folder
			TweenService:Create(beam, TweenInfo.new(1.6), { Transparency = 1, Size = Vector3.new(60, 0.2, 0.2) }):Play()
			Debris:AddItem(beam, 1.7)
		end
		Debris:AddItem(impact, 1.5)
	end)
end

local function addPet(display: BaseDisplay, anchor: Instance)
	if not anchor:IsA("BasePart") or display.pets[anchor] then
		return
	end
	local petId = anchor:GetAttribute("PetId")
	if type(petId) ~= "string" then
		return
	end
	local model = PetModelBuilder.Build(petId)
	if not model then
		return
	end
	-- Mesures du modèle à l'origine : bas et haut par rapport à son pivot.
	model:PivotTo(CFrame.new())
	local box, size = PetModelBuilder.BodyBounds(model)
	local seedValue = anchor:GetAttribute("Seed")
	local seed = if type(seedValue) == "number" then seedValue else 0
	local styleName = PetWander.styleFor(petId)
	local style, ease = PetWander.styleOf(petId)
	-- Bulle [E] "Voler", propre à ce client : elle suit le familier et prévient le serveur.
	local entry = PetCatalog.ById[petId]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Voler"
	prompt.ObjectText = if entry then entry.Name else petId
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.Steal.HoldDuration
	-- Un géant se vole depuis son flanc, pas seulement depuis son centre.
	prompt.MaxActivationDistance = Config.Steal.PromptDistance + PetSizes.Radius(petId, entry and entry.Rarity) * 0.8
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- RenderStepped l'active si le vol est possible
	prompt.Triggered:Connect(function()
		Remotes.StealPet:FireServer(anchor)
	end)
	prompt.Parent = anchor

	local shown: Shown = {
		anchor = anchor,
		prompt = prompt,
		model = model,
		styleName = styleName,
		style = style,
		gait = PetGaits.For(petId),
		ease = ease,
		leg = PetWander.decode(anchor:GetAttribute("Walk")),
		heading = seed % 7, -- orientation de départ, la même pour tout le monde
		bank = 0,
		bottomOffset = -(box.Position.Y - size.Y / 2),
		topOffset = box.Position.Y + size.Y / 2,
		centerY = box.Position.Y,
		seed = seed,
		own = display.base:GetAttribute("BaseIndex") == player:GetAttribute("BaseIndex"),
	}
	setLabel(shown)
	model.Parent = folder
	display.pets[anchor] = shown

	anchor:GetAttributeChangedSignal("Walk"):Connect(function()
		shown.leg = PetWander.decode(anchor:GetAttribute("Walk"))
	end)
	anchor:GetAttributeChangedSignal("Count"):Connect(function()
		setLabel(shown)
	end)
	local function onArrived()
		local arrivedAt = anchor:GetAttribute("ArrivedAt")
		if type(arrivedAt) == "number" then
			playArrival(shown, arrivedAt)
		end
	end
	anchor:GetAttributeChangedSignal("ArrivedAt"):Connect(onArrived)
	onArrived() -- nouvelle espèce : le repère arrive avec l'attribut déjà posé
end

local function removePet(display: BaseDisplay, anchor: Instance)
	local shown = if anchor:IsA("BasePart") then display.pets[anchor] else nil
	if shown then
		shown.model:Destroy()
		if shown.prompt then
			shown.prompt:Destroy()
		end
		display.pets[anchor :: BasePart] = nil
	end
end

local function watchBase(base: Instance)
	if not base:IsA("Model") or not base.Name:match("^Base_%d+$") then
		return
	end
	task.spawn(function()
		-- WaitForChild : la base peut arriver par morceaux (chargement progressif de la carte).
		local platform = base:WaitForChild("BasePart")
		local pets = base:WaitForChild("Pets")
		if not platform:IsA("BasePart") then
			return
		end
		local display: BaseDisplay = { base = base, platform = platform, pets = {} }
		displays[base] = display
		pets.ChildAdded:Connect(function(anchor)
			addPet(display, anchor)
		end)
		pets.ChildRemoved:Connect(function(anchor)
			removePet(display, anchor)
		end)
		for _, anchor in ipairs(pets:GetChildren()) do
			addPet(display, anchor)
		end
	end)
end

-- Hauteur de chute d'un familier qui vient d'arriver (tombe du ciel, accéléré), 0 ensuite.
local function dropHeight(shown: Shown, now: number): number
	local arrivedAt = shown.arrivedAt
	if arrivedAt then
		local fall = (now - arrivedAt) / DROP_TIME
		if fall < 1 then
			return DROP_HEIGHT * (1 - math.max(0, fall) ^ 2)
		end
		shown.arrivedAt = nil
	end
	return 0
end

-- Démarche propre au familier (shared/PetGaits). Les secousses suivent la distance parcourue (un pas tous les
-- `step` studs, un bond tous les `hopLength`) : les pieds ne glissent pas, quelle que soit la vitesse.
local function gaitPose(shown: Shown, g: PetGaits.Gait, dt: number, now: number): CFrame
	local t = now + shown.seed
	local s = math.clamp((shown.topOffset + shown.bottomOffset) / 6, 0.4, 3) -- taille par rapport à 6 studs
	local position, moving, done, length = Vector2.zero, false, 0, 0
	local direction = Vector2.new(0, -1)
	local leg = shown.leg
	if leg then
		position, moving, done = PetWander.positionAt(leg, now, g.ease)
		local delta = leg.to - leg.from
		length = delta.Magnitude
		if length > 1e-3 then
			direction = delta / length
		end
	end
	local diff = 0
	if moving and length > 1e-3 then
		local wanted = math.atan2(-direction.X, -direction.Y) + (g.sideways or 0) -- le crabe se met de profil
		diff = (wanted - shown.heading + math.pi) % (math.pi * 2) - math.pi
		shown.heading += diff * math.min(1, dt * (g.turn or 6))
	elseif g.spin then
		shown.heading += g.spin * dt
	end
	-- s'incline dans le virage, puis se redresse
	local wantedBank = if g.bank then math.clamp(-diff * g.bank, -0.6, 0.6) else 0
	shown.bank += (wantedBank - shown.bank) * math.min(1, dt * 3)

	local traveled = length * done
	local height = g.hover
	local yaw, pitch, roll = 0, 0, shown.bank
	if g.perch then
		-- ne vole que pour changer de place : décolle, plane, se pose
		height = if moving then g.hover * math.sin(math.pi * done) ^ 0.6 else 0
	end
	if g.float and not (g.perch and not moving) then
		height += math.sin(t * (g.floatRate or 1)) * g.float
	end
	if moving and g.step then
		local phase = traveled / g.step * math.pi
		height += math.abs(math.sin(phase)) * (g.bob or 0) * s
		roll += math.sin(phase) * (g.roll or 0)
		yaw += math.sin(phase) * (g.wiggle or 0)
		pitch += math.sin(phase * 2) * (g.rock or 0)
	end
	if moving and g.hop then
		local hops = math.max(1, math.round(length / (g.hopLength or 2)))
		local f = (done * hops) % 1
		height += math.sin(math.pi * f) * g.hop * s
		pitch += (0.5 - f) * 0.35 -- nez en l'air au départ du bond, vers le bas à l'atterrissage
	elseif g.hop then
		height += math.abs(math.sin(t * 2)) * 0.06 * s -- respire / tremblote sur place
	end
	if moving and g.pounce and done > 0.4 then
		local f = (done - 0.4) / 0.6
		height += math.sin(math.pi * f) * g.pounce * s
		pitch += (0.5 - f) * 0.5
	end
	if moving and g.lean then
		pitch += g.lean
	end
	local offset = Vector2.zero
	if g.sway then
		local envelope = if moving then math.sin(math.pi * done) else 0
		local w = traveled / (g.swayLength or 4) * math.pi * 2
		offset += Vector2.new(-direction.Y, direction.X) * math.sin(w) * g.sway * s * envelope
		yaw += math.cos(w) * envelope * 0.35
	end
	if g.drift then
		offset += Vector2.new(math.sin(t * 0.9) + math.sin(t * 2.3) * 0.4, math.sin(t * 0.7 + 1) + math.sin(t * 1.9) * 0.4)
			* g.drift
	end
	height += dropHeight(shown, now)
	local place = CFrame.new(position.X + offset.X, height + shown.bottomOffset, position.Y + offset.Y)
	if g.wheel then
		-- roule comme une roue : se met de profil le long du trajet et fait un nombre entier de tours (il s'arrête
		-- toujours la tête en haut)
		local radius = math.max(0.5, shown.centerY + shown.bottomOffset)
		local turns = math.max(1, math.round(length / (2 * math.pi * radius)))
		local angle = if moving then done * turns * 2 * math.pi else 0
		return place
			* CFrame.Angles(0, shown.heading + math.pi / 2, 0)
			* CFrame.new(0, shown.centerY, 0)
			* CFrame.Angles(0, 0, -angle)
			* CFrame.new(0, -shown.centerY, 0)
	end
	return place * CFrame.Angles(0, shown.heading + yaw, 0) * CFrame.Angles(pitch, 0, roll)
end

-- Pose du familier à l'instant `now` (horloge serveur), dans le repère du sol de sa base.
local function pose(shown: Shown, dt: number, now: number): CFrame
	local g = shown.gait
	if g then
		return gaitPose(shown, g, dt, now)
	end
	local position, moving = Vector2.zero, false
	local leg = shown.leg
	if leg then
		position, moving = PetWander.positionAt(leg, now)
		if moving then
			-- Se tourne progressivement dans la direction de marche.
			local delta = leg.to - leg.from
			local wanted = math.atan2(-delta.X, -delta.Y)
			local diff = (wanted - shown.heading + math.pi) % (math.pi * 2) - math.pi
			shown.heading += diff * math.min(1, dt * 6)
		end
	end

	local t = now + shown.seed
	-- Arrivée : chute depuis le ciel (accélérée), pour que tout le monde voie le nouveau familier.
	local height = shown.style.hover + dropHeight(shown, now)
	local yaw = shown.heading
	local roll = 0
	local name = shown.styleName
	if name == "Walk" then
		height += if moving then math.abs(math.sin(t * 10)) * 0.25 else 0
		roll = if moving then math.sin(t * 10) * 0.08 else 0
	elseif name == "Hop" then
		height += if moving then math.abs(math.sin(t * 7)) * 1.4 else math.abs(math.sin(t * 2)) * 0.15
	elseif name == "Slither" then
		yaw += math.sin(t * 6) * (if moving then 0.35 else 0.1)
	elseif name == "Fly" then
		height += math.sin(t * 2) * 0.6
		roll = math.sin(t * 1.5) * 0.12
	elseif name == "Plant" then
		roll = if shown.model:GetAttribute("MotionReady") then 0 else math.sin(t * 1.8) * 0.12
	elseif name == "Spin" then
		height += math.sin(t * 1.5) * 0.5
		yaw = if shown.model:GetAttribute("MotionProfile") == "Top" then shown.heading else t * 1.5
	end
	return CFrame.new(position.X, height + shown.bottomOffset, position.Y) * CFrame.Angles(0, yaw, roll)
end

-- Le joueur local peut-il prendre un familier de cette base en ce moment ? Chez lui : le PORTER (pour le jeter dans le
-- trou noir) ; chez un autre : le VOLER. (simple affichage : le serveur revérifie)
local function canTake(base: Model): (boolean, string)
	local own = base:GetAttribute("BaseIndex") == player:GetAttribute("BaseIndex")
	local handsFree = player:GetAttribute("CarryingPet") == nil
		and not (player.Character and player.Character:FindFirstChildOfClass("Tool")) -- arme en main : mains prises
	if own then
		return handsFree, "Porter"
	end
	local ownerName = base:GetAttribute("OwnerName")
	local owner = if type(ownerName) == "string" then Players:FindFirstChild(ownerName) else nil
	local protectedUntil = owner and owner:GetAttribute("NewcomerProtectedUntil")
	if type(protectedUntil) == "number" and protectedUntil > Workspace:GetServerTimeNow() then
		return false, "Protégé"
	end
	-- Bouclier après une grosse perte (Config.StealShield).
	local shieldUntil = owner and owner:GetAttribute("StealShieldUntil")
	if type(shieldUntil) == "number" and shieldUntil > Workspace:GetServerTimeNow() then
		return false, "Protégé"
	end
	if Config.Steal.OnlyDuringDigesting and ReplicatedStorage:GetAttribute("GameState") ~= "Digesting" then
		return false, "Voler"
	end
	return handsFree and base:GetAttribute("Locked") ~= true, "Voler"
end

local NEAR_CHARACTER = 90 -- une base aussi proche du personnage est toujours animée (caméra très reculée)

RunService:BindToRenderStep("BasePetsPlacement", Enum.RenderPriority.Last.Value - 12, function(dt: number)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local now = Workspace:GetServerTimeNow()
	local selfBest = PowerCap.SelfBestOf(player)
	local baseMinValue = player:GetAttribute("BaseMin")
	local baseMin = if type(baseMinValue) == "number" then baseMinValue else 0
	for _, display in pairs(displays) do
		local platform = display.platform
		local ground = PetWander.groundOf(platform)
		local stealable, action = canTake(display.base)
		for _, shown in pairs(display.pets) do
			-- Vol utile : la bulle ne s'affiche que sur un familier qui ferait monter ton revenu (le serveur revérifie).
			local enabled = stealable
			if enabled and action == "Voler" then
				local petId = shown.anchor:GetAttribute("PetId")
				enabled = type(petId) == "string" and PowerCap.IsUseful(petId, selfBest, baseMin)
			end
		local visible = (platform.Position - camera.CFrame.Position).Magnitude < VIEW_DISTANCE
			or (root ~= nil and root:IsA("BasePart") and (platform.Position - root.Position).Magnitude < NEAR_CHARACTER)
			if visible then
				shown.model:PivotTo(ground * pose(shown, dt, now))
				-- Le repère (et sa bulle [E]) suit le familier, chez ce joueur seulement : le serveur ne le déplace jamais.
				shown.anchor.CFrame = CFrame.new(shown.model:GetPivot().Position)
			end
			-- Bulle [E] affichée seulement si le vol est possible (mise à jour même pour les bases lointaines).
			local prompt = shown.prompt
			if prompt and prompt.Enabled ~= enabled then
				prompt.Enabled = enabled
			end
			if prompt and prompt.ActionText ~= action then
				prompt.ActionText = action
			end
		end
	end
end)

-- Les vrais modèles 3D (shared/PetMeshes) viennent d'être chargés : on remplace ceux déjà affichés.
PetModelBuilder.MeshesReady:Connect(function()
	for _, display in pairs(displays) do
		for _, shown in pairs(display.pets) do
			local model = PetModelBuilder.Build(shown.model.Name)
			if model then
				model:PivotTo(CFrame.new())
				local box, size = PetModelBuilder.BodyBounds(model)
				shown.model:Destroy()
				shown.model = model
				shown.bottomOffset = -(box.Position.Y - size.Y / 2)
				shown.topOffset = box.Position.Y + size.Y / 2
				shown.centerY = box.Position.Y
				setLabel(shown)
				model.Parent = folder
			end
		end
	end
end)

local map = Workspace:WaitForChild("Map")
map.ChildAdded:Connect(watchBase)
for _, child in ipairs(map:GetChildren()) do
	watchBase(child)
end
