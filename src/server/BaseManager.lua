--!strict
-- BaseManager : attribue une base libre à chaque joueur et le fait apparaître dessus.
-- Écrit l'attribut "BaseIndex" sur le Player et "OwnerName" sur la base.

local Players = game:GetService("Players")

local BaseManager = {}

local bases: { Model } = {}
local owners: { [Model]: Player } = {}

local function getSpawn(base: Model): SpawnLocation?
	local spawn = base:FindFirstChild("SpawnLocation")
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn
	end
	return nil
end

local function setSign(base: Model, text: string)
	local sign = base:FindFirstChild("OwnerSign")
	local label = sign and sign:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

function BaseManager.GetBase(player: Player): Model?
	for base, owner in pairs(owners) do
		if owner == player then
			return base
		end
	end
	return nil
end

function BaseManager.GetOwner(base: Model): Player?
	return owners[base]
end

function BaseManager.GetOccupiedBases(): { Model }
	local result = {}
	for _, base in ipairs(bases) do
		if owners[base] then
			table.insert(result, base)
		end
	end
	return result
end

-- Téléporte le personnage sur sa base s'il est apparu ailleurs (premier spawn).
local function onCharacterAdded(player: Player, character: Model)
	local base = BaseManager.GetBase(player)
	local spawn = base and getSpawn(base)
	if not spawn then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root and root:IsA("BasePart") and (root.Position - spawn.Position).Magnitude > 20 then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

local function onPlayerAdded(player: Player)
	for _, base in ipairs(bases) do
		if not owners[base] then
			owners[base] = player
			base:SetAttribute("OwnerName", player.Name)
			player:SetAttribute("BaseIndex", base:GetAttribute("BaseIndex"))
			local spawn = getSpawn(base)
			if spawn then
				player.RespawnLocation = spawn
			end
			setSign(base, player.DisplayName)
			break
		end
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local base = BaseManager.GetBase(player)
	if base then
		owners[base] = nil
		base:SetAttribute("OwnerName", nil)
		setSign(base, "Base libre")
		-- Les objets restés dans une base vide disparaissent.
		local itemSpawns = base:FindFirstChild("ItemSpawns")
		if itemSpawns then
			itemSpawns:ClearAllChildren()
		end
	end
end

function BaseManager.Init(generatedBases: { Model })
	bases = generatedBases
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

return BaseManager
