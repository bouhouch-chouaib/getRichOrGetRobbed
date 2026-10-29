--!strict
-- HalloweenController : l'événement Halloween 2026 (Config.Halloween, shared/Halloween). Rien ne se passe hors des dates.
--   - Bonbons : OnScored (appelé par server/BlackholeController pour chaque objet avalé qui rapporte des points) donne
--     CandyPerItem bonbons, ou ceux d'une citrouille (attribut "Candy"), x2 pendant l'heure hantée.
--   - Citrouilles sauvages : pendant le Feeding, une toutes les Pumpkin.Interval secondes dans l'arène (Pumpkin.Max au
--     plus), objets comme les autres (server/ItemSpawner.SpawnSpecial "Pumpkin").
--   - Chaudron : Remotes.Halloween("Buy") achète un œuf Citrouille (EggPrice bonbons) ; le familier est tiré ici
--     (Config.Halloween.Chances) puis donné comme un tirage gratuit (PullRewards.GrantChosen : œuf dans la couveuse,
--     mutation secrète possible, doublons vendus). Badge « Halloween 2026 » au premier.
--   - Décor (Workspace.HalloweenDecor) : chaudron dans l'arène, citrouilles sculptées autour du trou noir et à l'entrée
--     de chaque base, tombes dans l'arène. Modèles ArtModels.Halloween.<Chaudron | Lanterne | Tombe> s'ils existent
--     (Blender, fichier du jeu), sinon en blocs. Posé au début de l'événement, retiré à la fin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Halloween = require(ReplicatedStorage.Shared.Halloween)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BadgeController = require(script.Parent.BadgeController)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemSpawner = require(script.Parent.ItemSpawner)
local PullRewards = require(script.Parent.PullRewards)
local SessionData = require(script.Parent.SessionData)

local HalloweenController = {}

local SETTINGS = Config.Halloween
local ARENA = Config.Arena
local rng = Random.new()
local lastRequest: { [Player]: number } = {}

local ORANGE = Color3.fromRGB(255, 128, 24)
local FACE = Color3.fromRGB(255, 214, 90)
local STEM = Color3.fromRGB(86, 104, 40)
local IRON = Color3.fromRGB(42, 40, 50)
local POTION = Color3.fromRGB(120, 226, 74)
local STONE = Color3.fromRGB(128, 128, 140)

local function active(): boolean
	return Halloween.Active(Halloween.Now())
end

----------------------------------------------------------------------
-- Bonbons
----------------------------------------------------------------------

-- Un objet lancé par owner vient d'être avalé et lui rapporte des points.
function HalloweenController.OnScored(owner: Player, item: BasePart)
	local now = Halloween.Now()
	if not Halloween.Active(now) then
		return
	end
	local candy = item:GetAttribute("Candy")
	local amount = (if type(candy) == "number" then candy else SETTINGS.CandyPerItem) * Halloween.CandyMultiplier(now)
	SessionData.AddCandy(owner, amount)
end

local function spawnPumpkin()
	local map = Workspace:FindFirstChild("Map")
	local wild = map and map:FindFirstChild("WildItems")
	if not wild then
		return
	end
	local count = 0
	for _, child in ipairs(wild:GetChildren()) do
		if child:GetAttribute("Special") == "Pumpkin" then
			count += 1
		end
	end
	if count >= SETTINGS.Pumpkin.Max then
		return
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(Config.Items.WildMinRadius, Config.Items.WildMaxRadius)
	ItemSpawner.SpawnSpecial("Pumpkin", Vector3.new(math.cos(angle) * radius, 6, math.sin(angle) * radius), Vector3.zero)
end

----------------------------------------------------------------------
-- Chaudron : œuf Citrouille
----------------------------------------------------------------------

local function buy(player: Player)
	if not active() or not SessionData.IsLoaded(player) then
		return
	end
	if not SessionData.SpendCandy(player, SETTINGS.EggPrice) then
		Remotes.Halloween:FireClient(player, "NoCandy")
		return
	end
	local petId = Halloween.Roll(rng:NextNumber())
	PullRewards.GrantChosen(player, { petId })
	Remotes.Halloween:FireClient(player, "Bought", petId)
	BadgeController.Award(player, SETTINGS.Badge)
	print(string.format("[Halloween] %s : œuf Citrouille -> %s (%d bonbons restants)", player.Name, petId, SessionData.GetCandy(player)))
end

----------------------------------------------------------------------
-- Décor
----------------------------------------------------------------------

local function block(model: Model, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function light(parent: BasePart, color: Color3, brightness: number, range: number)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Brightness, glow.Range, glow.Shadows = color, brightness, range, false
	glow.Parent = parent
end

-- Modèle fait dans Blender (ArtModels.Halloween.<name>), mis à la hauteur voulue ; nil s'il manque.
local function art(name: string, height: number): Model?
	local folder = ReplicatedStorage:FindFirstChild("ArtModels")
	folder = folder and folder:FindFirstChild("Halloween")
	local source = folder and folder:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return nil
	end
	local model = source:Clone()
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * height / math.max(size.Y, 0.1))
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		end
	end
	return model
end

-- Pose un modèle par le bas : at = point au sol, face avant (-Z) tournée vers `facing`.
local function place(model: Model, at: Vector3, facing: Vector3)
	local _, size = model:GetBoundingBox()
	local look = Vector3.new(facing.X - at.X, 0, facing.Z - at.Z)
	local rotation = if look.Magnitude > 0.01 then CFrame.lookAt(Vector3.zero, look) else CFrame.new()
	model:PivotTo(CFrame.new(at + Vector3.new(0, size.Y / 2, 0)) * rotation)
end

-- Citrouille sculptée (en blocs, comme le reste de la carte), visage vers -Z, lumière orange à l'intérieur.
local function lantern(scale: number): Model
	local found = art("Lanterne", 4 * scale)
	if found then
		local glowing = found:FindFirstChildWhichIsA("BasePart", true)
		if glowing then
			light(glowing, Color3.fromRGB(255, 150, 50), 1.2, 12 * scale)
		end
		return found
	end
	local model = Instance.new("Model")
	model.Name = "Lanterne"
	local s = scale
	local body = block(model, Vector3.new(4, 3.2, 4) * s, CFrame.new(0, 1.6 * s, 0), ORANGE)
	block(model, Vector3.new(4.6, 2.6, 3.2) * s, CFrame.new(0, 1.6 * s, 0), ORANGE)
	block(model, Vector3.new(3.2, 2.6, 4.6) * s, CFrame.new(0, 1.6 * s, 0), ORANGE)
	block(model, Vector3.new(0.6, 0.9, 0.6) * s, CFrame.new(0, 3.6 * s, 0) * CFrame.Angles(0, 0, 0.2), STEM)
	-- Visage : deux yeux, un nez, une bouche à dents (blocs clairs, sans néon : la lumière vient de la PointLight).
	for _, x in ipairs({ -0.85, 0.85 }) do
		block(model, Vector3.new(0.8, 0.7, 0.2) * s, CFrame.new(x * s, 2.25 * s, -2.32 * s), FACE)
	end
	block(model, Vector3.new(0.4, 0.4, 0.2) * s, CFrame.new(0, 1.7 * s, -2.32 * s), FACE)
	block(model, Vector3.new(2.4, 0.5, 0.2) * s, CFrame.new(0, 1.05 * s, -2.32 * s), FACE)
	for _, x in ipairs({ -0.6, 0.6 }) do
		block(model, Vector3.new(0.4, 0.3, 0.2) * s, CFrame.new(x * s, 1.4 * s, -2.32 * s), FACE)
	end
	light(body, Color3.fromRGB(255, 150, 50), 1.2, 12 * s)
	model.PrimaryPart = body
	return model
end

local function tombstone(): Model
	local found = art("Tombe", 3.4)
	if found then
		return found
	end
	local model = Instance.new("Model")
	model.Name = "Tombe"
	local base = block(model, Vector3.new(2.8, 0.4, 1.6), CFrame.new(0, 0.2, 0), Color3.fromRGB(90, 90, 100), Enum.Material.Slate)
	block(model, Vector3.new(2.2, 2.4, 0.6), CFrame.new(0, 1.6, 0), STONE, Enum.Material.Slate)
	block(model, Vector3.new(1.6, 0.5, 0.6), CFrame.new(0, 3.05, 0), STONE, Enum.Material.Slate)
	block(model, Vector3.new(1.2, 0.2, 0.1), CFrame.new(0, 2, -0.33), Color3.fromRGB(70, 70, 80))
	block(model, Vector3.new(0.2, 0.9, 0.1), CFrame.new(0, 2.05, -0.33), Color3.fromRGB(70, 70, 80))
	model.PrimaryPart = base
	return model
end

-- Le chaudron du marchand d'œufs Citrouille, avec sa bulle [E] (le client ouvre client/HalloweenMenu).
local function cauldron(): Model
	local model = art("Chaudron", 7) or Instance.new("Model")
	if not model.PrimaryPart and #model:GetChildren() == 0 then
		model.Name = "Chaudron"
		for _, yaw in ipairs({ 0, math.pi / 4 }) do
			local turn = CFrame.Angles(0, yaw, 0)
			block(model, Vector3.new(9, 4.6, 6.4), CFrame.new(0, 3.1, 0) * turn, IRON, Enum.Material.Metal)
			block(model, Vector3.new(6.4, 4.6, 9), CFrame.new(0, 3.1, 0) * turn, IRON, Enum.Material.Metal)
			block(model, Vector3.new(9.6, 0.7, 7), CFrame.new(0, 5.6, 0) * turn, IRON, Enum.Material.Metal)
			block(model, Vector3.new(7, 0.7, 9.6), CFrame.new(0, 5.6, 0) * turn, IRON, Enum.Material.Metal)
			block(model, Vector3.new(8.2, 0.3, 5.8), CFrame.new(0, 5.5, 0) * turn, POTION)
			block(model, Vector3.new(5.8, 0.3, 8.2), CFrame.new(0, 5.5, 0) * turn, POTION)
		end
		for index = 0, 2 do
			local angle = index * math.pi * 2 / 3
			block(model, Vector3.new(1.2, 1.2, 1.2), CFrame.new(math.cos(angle) * 3, 0.6, math.sin(angle) * 3), IRON, Enum.Material.Metal)
		end
		-- Bulles de potion (blocs) et une louche.
		for _, spot in ipairs({ Vector3.new(-1.5, 5.9, 0.8), Vector3.new(1.2, 6, -1), Vector3.new(0.3, 5.8, 1.9) }) do
			block(model, Vector3.new(0.9, 0.9, 0.9), CFrame.new(spot), Color3.fromRGB(170, 245, 120))
		end
		block(model, Vector3.new(0.4, 6, 0.4), CFrame.new(2.2, 7, 1) * CFrame.Angles(0.3, 0, -0.35), Color3.fromRGB(120, 80, 45), Enum.Material.Wood)
		local _, size = model:GetBoundingBox()
		local root = block(model, size, model:GetBoundingBox(), IRON)
		root.Name = "Root"
		root.Transparency = 1
		model.PrimaryPart = root
	end
	local _, size = model:GetBoundingBox()
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = size
	hitbox.CFrame = model:GetBoundingBox()
	hitbox.Transparency = 1
	hitbox.Anchored, hitbox.CanCollide, hitbox.CanQuery, hitbox.CanTouch = true, true, true, false
	hitbox.Parent = model
	light(hitbox, POTION, 1, 16)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CauldronPrompt"
	prompt.ActionText = "Ouvrir"
	prompt.ObjectText = "Chaudron d'Halloween"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = hitbox
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(260, 60)
	sign.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 3, 0)
	sign.MaxDistance = 140
	sign.AlwaysOnTop = false
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = "ŒUFS CITROUILLE"
	text.TextScaled = true
	text.TextColor3 = ORANGE
	text.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = text
	text.Parent = sign
	sign.Parent = hitbox
	return model
end

local function polar(angle: number, radius: number): Vector3
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function buildDecor(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "HalloweenDecor"
	local function add(model: Model, at: Vector3, facing: Vector3)
		place(model, at, facing)
		model.Parent = folder
	end
	-- Le trou noir devient un chaudron de citrouilles : 12 lanternes sur son bord, le visage vers l'arène.
	for index = 0, 11 do
		local angle = (index + 0.5) * math.pi * 2 / 12
		local at = polar(angle, ARENA.HoleRadius + 7)
		add(lantern(1), at, at * 2)
	end
	-- Une citrouille de chaque côté de l'entrée des 8 bases, visage vers le trou noir.
	local step = math.pi * 2 / ARENA.BaseCount
	local front = ARENA.BaseRingRadius - ARENA.BaseSize.Z / 2 - 4
	for index = 0, ARENA.BaseCount - 1 do
		local angle = index * step
		local axis, across = polar(angle, 1), polar(angle + math.pi / 2, 1)
		for _, side in ipairs({ -12, 12 }) do
			add(lantern(0.8), axis * front + across * side, Vector3.zero)
		end
		-- Dans l'arène, entre deux chemins : une tombe et une petite citrouille.
		local between = angle + step / 2
		add(tombstone(), polar(between - 0.05, 112), Vector3.zero)
		add(lantern(0.6), polar(between + 0.06, 126), Vector3.zero)
	end
	local spot = polar(math.rad(SETTINGS.Cauldron.Angle), SETTINGS.Cauldron.Radius)
	add(cauldron(), spot, Vector3.zero)
	folder.Parent = Workspace
	return folder
end

----------------------------------------------------------------------

function HalloweenController.Init()
	Remotes.Halloween.OnServerEvent:Connect(function(player: Player, action: unknown)
		local now = os.clock()
		if (lastRequest[player] or 0) > now then
			return
		end
		lastRequest[player] = now + 0.4
		if action == "Buy" then
			buy(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)

	task.spawn(function()
		local decor: Folder? = nil
		local pumpkinTimer = 0
		while true do
			task.wait(1)
			local on = active()
			if on and not decor then
				decor = buildDecor()
			elseif not on and decor then
				decor:Destroy()
				decor = nil
			end
			Workspace:SetAttribute("Halloween", on)
			if on and GameLoopManager.GetState() == "Feeding" then
				pumpkinTimer += 1
				if pumpkinTimer >= SETTINGS.Pumpkin.Interval then
					pumpkinTimer = 0
					spawnPumpkin()
				end
			end
		end
	end)
end

return HalloweenController
