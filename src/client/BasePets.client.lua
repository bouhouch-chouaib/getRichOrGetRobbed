--!strict
-- BasePets : affiche les familiers qui se baladent dans chaque base (style Steal an Egg).
-- C'est le SERVEUR qui décide (server/BasePetsController) : un repère invisible Base_N.Pets.<PetId> par espèce,
-- avec son trajet en cours dans l'attribut "Walk". Ici, on construit le modèle et on le place à la position
-- calculée avec l'horloge commune (shared/PetWander) : tous les joueurs voient les familiers au même endroit.
-- L'animation (marche, sautille, ondule, plane, se balance, tourne) n'est qu'un effet visuel local.
-- Vol : on déplace aussi (localement) le repère sur le familier pour que sa bulle [E] "Voler" le suive, et on
-- n'affiche la bulle que si le vol est possible (digestion, base adverse ouverte, mains libres). Le serveur revérifie tout.
-- Arrivée d'un nouveau familier (attribut "ArrivedAt" posé par le serveur après un tirage, une fusion ou un vol) :
-- il tombe du ciel, gerbe d'étincelles à la couleur de sa rareté, étiquette "NOUVEAU", rayon de lumière si Légendaire+.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local PetWander = require(ReplicatedStorage.Shared.PetWander)
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
	leg: PetWander.Leg?,
	heading: number,
	bottomOffset: number, -- distance pivot -> bas du modèle
	topOffset: number, -- distance pivot -> haut du modèle (pour l'étiquette)
	seed: number,
	arrivedAt: number?, -- heure serveur de son arrivée (animation de chute)
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
	local sign = Instance.new("BillboardGui")
	sign.Name = "PetLabel"
	sign.Adornee = root
	sign.Size = UDim2.fromScale(7, 2.2)
	sign.StudsOffsetWorldSpace = Vector3.new(0, shown.topOffset + 1.4, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 70
	local function line(text: string, color: Color3, y: number, height: number)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		local outline = Instance.new("UIStroke")
		outline.Thickness = 2.5
		outline.Parent = label
		label.Parent = sign
	end
	line(entry.Name:upper() .. (if count > 1 then " x" .. count else ""), rarity.Color, 0, 0.55)
	line(NumberFormat.perSecond(PetCatalog.GetIncome(petId)), Color3.fromRGB(110, 240, 70), 0.55, 0.45)
	sign.Parent = shown.model
end

-- Effets d'arrivée : étiquette "NOUVEAU" tout de suite, puis à l'atterrissage étincelles + flash (+ rayon si rare).
local function playArrival(shown: Shown, arrivedAt: number)
	local now = Workspace:GetServerTimeNow()
	if now - arrivedAt > ARRIVAL_WINDOW then
		return
	end
	shown.arrivedAt = arrivedAt
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
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = "✨ NOUVEAU ✨"
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Parent = label
	label.Parent = tag
	tag.Parent = model
	Debris:AddItem(tag, NEW_TAG_TIME)

	task.delay(math.max(0, arrivedAt + DROP_TIME - now), function()
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
	local box, size = model:GetBoundingBox()
	local seedValue = anchor:GetAttribute("Seed")
	local seed = if type(seedValue) == "number" then seedValue else 0
	local styleName = PetWander.styleFor(petId)
	local shown: Shown = {
		anchor = anchor,
		prompt = nil, -- trouvée dans RenderStepped (elle peut arriver du serveur juste après le repère)
		model = model,
		styleName = styleName,
		style = PetWander.STYLES[styleName],
		leg = PetWander.decode(anchor:GetAttribute("Walk")),
		heading = seed % 7, -- orientation de départ, la même pour tout le monde
		bottomOffset = -(box.Position.Y - size.Y / 2),
		topOffset = box.Position.Y + size.Y / 2,
		seed = seed,
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

-- Pose du familier à l'instant `now` (horloge serveur), dans le repère du sol de sa base.
local function pose(shown: Shown, dt: number, now: number): CFrame
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
	local height = shown.style.hover
	-- Arrivée : chute depuis le ciel (accélérée), pour que tout le monde voie le nouveau familier.
	local arrivedAt = shown.arrivedAt
	if arrivedAt then
		local fall = (now - arrivedAt) / DROP_TIME
		if fall < 1 then
			height += DROP_HEIGHT * (1 - math.max(0, fall) ^ 2)
		else
			shown.arrivedAt = nil
		end
	end
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
		roll = math.sin(t * 1.8) * 0.12
	elseif name == "Spin" then
		height += math.sin(t * 1.5) * 0.5
		yaw = t * 1.5
	end
	return CFrame.new(position.X, height + shown.bottomOffset, position.Y) * CFrame.Angles(0, yaw, roll)
end

-- Le joueur local peut-il voler dans cette base en ce moment ? (simple affichage : le serveur revérifie)
local function canSteal(base: Model): boolean
	if Config.Steal.OnlyDuringDigesting and ReplicatedStorage:GetAttribute("GameState") ~= "Digesting" then
		return false
	end
	return base:GetAttribute("BaseIndex") ~= player:GetAttribute("BaseIndex")
		and base:GetAttribute("Locked") ~= true
		and player:GetAttribute("CarryingPet") == nil
end

local NEAR_CHARACTER = 90 -- une base aussi proche du personnage est toujours animée (caméra très reculée)

RunService.RenderStepped:Connect(function(dt: number)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local now = Workspace:GetServerTimeNow()
	for _, display in pairs(displays) do
		local platform = display.platform
		local visible = (platform.Position - camera.CFrame.Position).Magnitude < VIEW_DISTANCE
			or (root ~= nil and root:IsA("BasePart") and (platform.Position - root.Position).Magnitude < NEAR_CHARACTER)
		local ground = PetWander.groundOf(platform)
		local stealable = canSteal(display.base)
		for _, shown in pairs(display.pets) do
			if visible then
				shown.model:PivotTo(ground * pose(shown, dt, now))
				-- Le repère (et sa bulle [E]) suit le familier, chez ce joueur seulement : le serveur ne le déplace jamais.
				shown.anchor.CFrame = CFrame.new(shown.model:GetPivot().Position)
			end
			-- Bulle [E] affichée seulement si le vol est possible (mise à jour même pour les bases lointaines).
			local prompt = shown.prompt
			if not prompt then
				prompt = shown.anchor:FindFirstChildOfClass("ProximityPrompt")
				shown.prompt = prompt
			end
			if prompt and prompt.Enabled ~= stealable then
				prompt.Enabled = stealable
			end
		end
	end
end)

local map = Workspace:WaitForChild("Map")
map.ChildAdded:Connect(watchBase)
for _, child in ipairs(map:GetChildren()) do
	watchBase(child)
end
