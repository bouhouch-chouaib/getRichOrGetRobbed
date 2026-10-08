--!strict
-- PetFollow : affiche les familiers équipés de TOUS les joueurs, qui les suivent, et le familier volé
-- que porte un voleur dans son dos (avec son nom et le temps restant).
-- Rendu 100 % local (aucune réplication réseau) à partir des attributs "Equipped", "CarryingPet" et
-- "CarryingUntil" de chaque Player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)

-- Positions derrière le joueur selon le nombre de familiers équipés (X, Z).
local SLOTS = {
	Vector2.new(0, 4),
	Vector2.new(-3, 3.5),
	Vector2.new(3, 3.5),
	Vector2.new(-1.5, 6.5),
	Vector2.new(1.5, 6.5),
}
local GROUND_OFFSET = -1.6 -- hauteur par rapport au HumanoidRootPart pour les familiers au sol
local FLOAT_OFFSET = 1.2 -- pour les familiers qui volent
local SMOOTHNESS = 10

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = Workspace

type Follower = { model: Model, float: boolean, current: CFrame? }
local followers: { [Player]: { Follower } } = {}

-- Familier volé porté dans le dos : position par rapport au HumanoidRootPart (derrière les épaules).
local CARRY_OFFSET = CFrame.new(0, 1.2, 1.6)
local CARRY_SCALE = 0.6 -- plus petit que dans la base : un gros familier ne cache pas la vue du voleur
type Carried = { model: Model, timer: TextLabel }
local carried: { [Player]: Carried } = {}

local function clear(player: Player)
	local list = followers[player]
	if list then
		for _, follower in ipairs(list) do
			follower.model:Destroy()
		end
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local equipped = player:GetAttribute("Equipped")
	if type(equipped) ~= "string" or equipped == "" then
		return
	end
	local list = {}
	for petId in string.gmatch(equipped, "[^,]+") do
		local model = PetModelBuilder.Build(petId)
		if model then
			model.Parent = folder
			table.insert(list, { model = model, float = model:GetAttribute("Float") == true, current = nil })
		end
	end
	followers[player] = list
end

local function clearCarried(player: Player)
	local entry = carried[player]
	if entry then
		entry.model:Destroy()
	end
	carried[player] = nil
end

-- Construit le familier volé et son étiquette (nom en couleur de rareté + temps restant).
local function rebuildCarried(player: Player)
	clearCarried(player)
	local petId = player:GetAttribute("CarryingPet")
	if type(petId) ~= "string" then
		return
	end
	local model = PetModelBuilder.Build(petId)
	local entry = PetCatalog.ById[petId]
	local root = model and model.PrimaryPart
	if not model or not entry or not root then
		return
	end
	model:ScaleTo(model:GetScale() * CARRY_SCALE)
	local _, size = model:GetBoundingBox()
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
	local sign = Instance.new("BillboardGui")
	sign.Name = "StolenLabel"
	sign.Adornee = root
	sign.Size = UDim2.fromScale(8, 2.6)
	sign.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.8, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 150
	local function line(text: string, color: Color3, y: number, height: number): TextLabel
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
		return label
	end
	line("🚨 " .. entry.Name:upper(), rarity.Color, 0, 0.55)
	local timer = line("", Color3.fromRGB(255, 90, 90), 0.55, 0.45)
	-- Le voleur lui-même voit son objectif dans la consigne du HUD (l'étiquette serait cachée par le titre).
	sign.Enabled = player ~= Players.LocalPlayer
	sign.Parent = model
	model.Parent = folder
	carried[player] = { model = model, timer = timer }
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Equipped"):Connect(function()
		rebuild(player)
	end)
	player:GetAttributeChangedSignal("CarryingPet"):Connect(function()
		rebuildCarried(player)
	end)
	rebuild(player)
	rebuildCarried(player)
end

Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player: Player)
	clear(player)
	clearCarried(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end

RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	local alpha = math.min(1, dt * SMOOTHNESS)
	for player, list in pairs(followers) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		for index, follower in ipairs(list) do
			if root and root:IsA("BasePart") then
				local slot = SLOTS[(index - 1) % #SLOTS + 1]
				local height = if follower.float then FLOAT_OFFSET + math.sin(now * 2 + index) * 0.4 else GROUND_OFFSET
				-- On garde seulement l'orientation horizontale du joueur.
				local look = root.CFrame.LookVector
				local flat = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
				local target = flat * CFrame.new(slot.X, height, slot.Y)
				local current = follower.current or target
				current = current:Lerp(target, alpha)
				follower.current = current
				follower.model:PivotTo(current)
			end
		end
	end

	local serverNow = Workspace:GetServerTimeNow()
	for player, entry in pairs(carried) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			-- Tourné vers l'arrière, comme s'il était hissé sur le dos.
			entry.model:PivotTo(root.CFrame * CARRY_OFFSET * CFrame.Angles(0, math.pi, 0))
		end
		local untilTime = player:GetAttribute("CarryingUntil")
		if type(untilTime) == "number" then
			entry.timer.Text = string.format("⏱ %d s", math.max(0, math.ceil(untilTime - serverNow)))
		end
	end
end)
