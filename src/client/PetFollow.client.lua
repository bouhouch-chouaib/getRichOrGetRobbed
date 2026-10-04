--!strict
-- PetFollow : affiche les familiers équipés de TOUS les joueurs, qui les suivent.
-- Rendu 100 % local (aucune réplication réseau) à partir de l'attribut "Equipped" de chaque Player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

local function watch(player: Player)
	player:GetAttributeChangedSignal("Equipped"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clear)
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
end)
