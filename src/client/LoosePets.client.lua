--!strict
-- LoosePets : les familiers LÂCHÉS (porteur frappé, éjecté, trop lent...) qui rentrent à pied vers la base de leur
-- propriétaire. Le serveur (server/StealController) pose un repère invisible Workspace.Map.LoosePets.<PetId> avec son
-- trajet (attributs Path, PathStart, PathSpeed : shared/PetPath) ; ici on construit le modèle et on le fait marcher
-- au même endroit pour tout le monde (horloge commune). Bulle [E] locale : « Reprendre » pour son propriétaire,
-- « Voler » pour les autres -> Remotes.PickLoosePet (le serveur revérifie tout).

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local PetPath = require(ReplicatedStorage.Shared.PetPath)
local PetSizes = require(ReplicatedStorage.Shared.PetSizes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)

local player = Players.LocalPlayer

type Walker = {
	anchor: BasePart,
	model: Model,
	prompt: ProximityPrompt,
	points: { Vector3 },
	start: number,
	speed: number,
	bottom: number,
	mine: boolean,
}

local walkers: { [Instance]: Walker } = {}

local folder = Instance.new("Folder")
folder.Name = "LoosePets"
folder.Parent = Workspace

local function line(sign: BillboardGui, text: string, color: Color3, y: number, height: number)
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

local function add(anchor: Instance)
	if not anchor:IsA("BasePart") or walkers[anchor] then
		return
	end
	local petId = anchor:GetAttribute("PetId")
	local entry = if type(petId) == "string" then PetCatalog.ById[petId] else nil
	local model = if type(petId) == "string" then PetModelBuilder.Build(petId) else nil
	local root = model and model.PrimaryPart
	if not entry or not model or not root or type(petId) ~= "string" then
		return
	end
	model:PivotTo(CFrame.new())
	local box, size = PetModelBuilder.BodyBounds(model)
	local mine = anchor:GetAttribute("OwnerUserId") == player.UserId
	local ownerName = anchor:GetAttribute("OwnerName")
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity] or 1]

	-- Étiquette : nom (couleur de rareté) + où il va. Visible de loin : c'est une cible à rattraper.
	local sign = Instance.new("BillboardGui")
	sign.Name = "LooseLabel"
	sign.Adornee = root
	sign.Size = UDim2.fromScale(9, 2.6)
	sign.StudsOffsetWorldSpace = Vector3.new(0, box.Position.Y + size.Y / 2 + 1.8, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 220
	line(sign, TextFormat.upper(entry.Name), rarity.Color, 0, 0.55)
	line(sign, if mine then "IL RENTRE CHEZ TOI : REPRENDS-LE !"
		else string.format("RENTRE CHEZ %s", TextFormat.upper(if type(ownerName) == "string" then ownerName else "?")),
		if mine then Color3.fromRGB(110, 240, 70) else Color3.fromRGB(255, 200, 60), 0.55, 0.45)
	sign.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickPrompt"
	prompt.ActionText = if mine then "Reprendre" else "Voler"
	prompt.ObjectText = entry.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.Steal.HoldDuration
	prompt.MaxActivationDistance = Config.Steal.PromptDistance + PetSizes.Radius(petId, entry.Rarity) * 0.8
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		Remotes.PickLoosePet:FireServer(anchor)
	end)
	prompt.Parent = anchor

	local start = anchor:GetAttribute("PathStart")
	local speed = anchor:GetAttribute("PathSpeed")
	model.Parent = folder
	walkers[anchor] = {
		anchor = anchor,
		model = model,
		prompt = prompt,
		points = PetPath.decode(anchor:GetAttribute("Path")),
		start = if type(start) == "number" then start else Workspace:GetServerTimeNow(),
		speed = if type(speed) == "number" then speed else Config.Carry.WalkHomeSpeed,
		bottom = -(box.Position.Y - size.Y / 2),
		mine = mine,
	}
end

local function remove(anchor: Instance)
	local walker = walkers[anchor]
	if walker then
		walker.model:Destroy()
		walkers[anchor] = nil
	end
end

task.spawn(function()
	local map = Workspace:WaitForChild("Map")
	local loose = map:WaitForChild("LoosePets")
	loose.ChildAdded:Connect(add)
	loose.ChildRemoved:Connect(remove)
	for _, anchor in ipairs(loose:GetChildren()) do
		add(anchor)
	end
end)

RunService:BindToRenderStep("LoosePetsPlacement", Enum.RenderPriority.Last.Value - 11, function()
	local now = Workspace:GetServerTimeNow()
	local t = os.clock()
	local handsFree = player:GetAttribute("CarryingPet") == nil
		and not (player.Character and player.Character:FindFirstChildOfClass("Tool"))
	for _, walker in pairs(walkers) do
		local position, direction, done = PetPath.at(walker.points, (now - walker.start) * walker.speed)
		local flat = Vector3.new(direction.X, 0, direction.Z)
		local look = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
		-- Petits pas pressés : il se dandine en rentrant.
		local hop = if done then 0 else math.abs(math.sin(t * 9)) * 0.35
		local roll = if done then 0 else math.sin(t * 9) * 0.08
		local base = CFrame.lookAt(position, position + look) -- l'avant des modèles est -Z : il regarde où il va
		walker.model:PivotTo(base * CFrame.new(0, walker.bottom + hop, 0) * CFrame.Angles(0, 0, roll))
		walker.anchor.CFrame = CFrame.new(walker.model:GetPivot().Position)
		local ownerId = walker.anchor:GetAttribute("OwnerUserId")
		local owner = if type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
		local protectedUntil = owner and owner:GetAttribute("NewcomerProtectedUntil")
		local protected = not walker.mine and type(protectedUntil) == "number" and protectedUntil > now
		local enabled = handsFree and not protected
		if walker.prompt.Enabled ~= enabled then
			walker.prompt.Enabled = enabled
		end
	end
end)
