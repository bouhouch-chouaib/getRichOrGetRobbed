--!strict
-- BasePets : les familiers de chaque base s'y baladent librement (style Steal an Egg).
-- Le serveur écrit sur chaque base l'attribut "BasePets" ("id:quantité,...") ; ici, chaque client construit
-- les modèles et les anime localement (aucune réplication réseau). Chaque familier a une façon de bouger
-- selon sa silhouette : marche, sautille, ondule, plane, se balance sur place, tourne sur lui-même.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)

local rng = Random.new()

local VIEW_DISTANCE = 260 -- au-delà, les familiers d'une base ne sont plus animés
local AREA = 22 -- demi-taille de la zone de promenade (la base fait 56 x 56, clôture comprise)
local CRATE_ZONE = 13 -- les coins (cagettes) sont évités

type Style = {
	speed: number,
	minWait: number,
	maxWait: number,
	hover: number, -- hauteur au-dessus du sol
}

local STYLES: { [string]: Style } = {
	Walk = { speed = 5, minWait = 1, maxWait = 4, hover = 0 },
	Hop = { speed = 6, minWait = 0.5, maxWait = 3, hover = 0 },
	Slither = { speed = 3.5, minWait = 1, maxWait = 3, hover = 0 },
	Fly = { speed = 6, minWait = 0.5, maxWait = 2.5, hover = 3 },
	Plant = { speed = 1.5, minWait = 5, maxWait = 12, hover = 0 },
	Spin = { speed = 2.5, minWait = 2, maxWait = 5, hover = 2 },
}

local SPIN_PETS = { OuroborosInfini = true, GaramaMadundung = true, GraineEtoile = true }

local function styleFor(petId: string): string
	if SPIN_PETS[petId] then
		return "Spin"
	end
	local entry = PetCatalog.ById[petId]
	if not entry then
		return "Walk"
	end
	local look = entry.Look
	if look.Float or look.Shape == "Fish" or look.Shape == "Dragon" then
		return "Fly"
	elseif look.Shape == "Serpent" then
		return "Slither"
	elseif look.Shape == "Plant" then
		return "Plant"
	elseif look.Shape == "Blob" or look.Shape == "Object" or look.Shape == "Bird" then
		return "Hop"
	end
	return "Walk"
end

type Wanderer = {
	model: Model,
	style: Style,
	styleName: string,
	position: Vector2, -- position locale dans la base (X, Z)
	target: Vector2,
	heading: number,
	waitUntil: number,
	bottomOffset: number, -- distance pivot -> bas du modèle
	seed: number,
}

type BaseDisplay = {
	base: Model,
	platform: BasePart,
	folder: Folder,
	signature: string,
	pets: { Wanderer },
}

local displays: { [Model]: BaseDisplay } = {}

local folder = Instance.new("Folder")
folder.Name = "BasePets"
folder.Parent = Workspace

local function randomSpot(): Vector2
	for _ = 1, 20 do
		local spot = Vector2.new(rng:NextNumber(-AREA, AREA), rng:NextNumber(-AREA, AREA))
		if not (math.abs(spot.X) > CRATE_ZONE and math.abs(spot.Y) > CRATE_ZONE) then
			return spot
		end
	end
	return Vector2.zero
end

local function addLabel(model: Model, petId: string, count: number, topOffset: number)
	local entry = PetCatalog.ById[petId]
	local root = model.PrimaryPart
	if not entry or not root then
		return
	end
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
	local sign = Instance.new("BillboardGui")
	sign.Name = "PetLabel"
	sign.Adornee = root
	sign.Size = UDim2.fromScale(7, 2.2)
	sign.StudsOffsetWorldSpace = Vector3.new(0, topOffset + 1.4, 0)
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
	sign.Parent = model
end

type PetEntry = { id: string, count: number }

local function rebuild(display: BaseDisplay, petIds: { PetEntry })
	display.folder:ClearAllChildren()
	display.pets = {}
	for _, petEntry in ipairs(petIds) do
		local petId = petEntry.id
		local model = PetModelBuilder.Build(petId)
		if model then
			-- Mesures du modèle à l'origine : bas et haut par rapport à son pivot.
			model:PivotTo(CFrame.new())
			local box, size = model:GetBoundingBox()
			local bottomOffset = -(box.Position.Y - size.Y / 2)
			local topOffset = box.Position.Y + size.Y / 2
			addLabel(model, petId, petEntry.count, topOffset)
			model.Parent = display.folder
			local styleName = styleFor(petId)
			local start = randomSpot()
			table.insert(display.pets, {
				model = model,
				style = STYLES[styleName],
				styleName = styleName,
				position = start,
				target = randomSpot(),
				heading = rng:NextNumber(0, math.pi * 2),
				waitUntil = os.clock() + rng:NextNumber(0, 2),
				bottomOffset = bottomOffset,
				seed = rng:NextNumber(0, 100),
			})
		end
	end
end

local function syncBase(base: Model)
	local display = displays[base]
	if not display then
		local platform = base:FindFirstChild("BasePart")
		if not platform or not platform:IsA("BasePart") then
			return
		end
		local petFolder = Instance.new("Folder")
		petFolder.Name = base.Name
		petFolder.Parent = folder
		display = { base = base, platform = platform, folder = petFolder, signature = "", pets = {} }
		displays[base] = display
	end
	local current = display :: BaseDisplay
	local value = base:GetAttribute("BasePets")
	local signature = if type(value) == "string" then value else ""
	if signature == current.signature then
		return
	end
	current.signature = signature
	local ids = {}
	for chunk in string.gmatch(signature, "[^,]+") do
		local petId, count = string.match(chunk, "^([^:]+):?(%d*)$")
		if petId then
			table.insert(ids, { id = petId, count = tonumber(count) or 1 })
		end
	end
	rebuild(current, ids)
end

local function watchBase(base: Instance)
	if not base:IsA("Model") or not base.Name:match("^Base_%d+$") then
		return
	end
	base:GetAttributeChangedSignal("BasePets"):Connect(function()
		syncBase(base)
	end)
	syncBase(base)
end

-- Déplace un familier et calcule sa pose de l'image.
local function step(pet: Wanderer, dt: number, now: number): CFrame
	local style = pet.style
	local moving = false
	if now >= pet.waitUntil then
		local delta = pet.target - pet.position
		local distance = delta.Magnitude
		if distance < 0.3 then
			pet.target = randomSpot()
			pet.waitUntil = now + rng:NextNumber(style.minWait, style.maxWait)
		else
			moving = true
			local move = math.min(distance, style.speed * dt)
			pet.position += delta.Unit * move
			-- Se tourne progressivement dans la direction de marche.
			local wanted = math.atan2(-delta.X, -delta.Y)
			local diff = (wanted - pet.heading + math.pi) % (math.pi * 2) - math.pi
			pet.heading += diff * math.min(1, dt * 6)
		end
	end

	local t = now + pet.seed
	local height = style.hover
	local yaw = pet.heading
	local roll = 0
	local name = pet.styleName
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
	return CFrame.new(pet.position.X, height + pet.bottomOffset, pet.position.Y) * CFrame.Angles(0, yaw, roll)
end

RunService.RenderStepped:Connect(function(dt: number)
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	for _, display in pairs(displays) do
		local platform = display.platform
		local visible = (platform.Position - camera.CFrame.Position).Magnitude < VIEW_DISTANCE
		if visible and #display.pets > 0 then
			-- Repère du sol de la base : centre du dessus de la plateforme, orienté comme la base.
			local ground = platform.CFrame * CFrame.new(0, platform.Size.Y / 2, 0)
			for _, pet in ipairs(display.pets) do
				pet.model:PivotTo(ground * step(pet, dt, now))
			end
		end
	end
end)

local map = Workspace:WaitForChild("Map")
map.ChildAdded:Connect(watchBase)
for _, child in ipairs(map:GetChildren()) do
	watchBase(child)
end
