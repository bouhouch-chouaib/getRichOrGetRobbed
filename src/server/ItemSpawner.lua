-- ItemSpawner : fait apparaître périodiquement des objets de test au-dessus des bases joueurs.
-- MVP / Greyboxing : Part rouge soumise à la physique, avec un ProximityPrompt "Ramasser".

local ItemSpawner = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameLoopManager = require(ReplicatedStorage.Shared.GameLoopManager)

local SPAWN_HEIGHT_OFFSET = 10

-- Récupère toutes les bases (Models nommés "BaseN") parentées à Map.
local function getBases(map)
	local bases = {}
	for _, child in ipairs(map:GetChildren()) do
		if child:IsA("Model") and child.Name:match("^Base%d+$") then
			table.insert(bases, child)
		end
	end
	return bases
end

-- Offsets des 4 coins d'une base (50x50, marge de 5 studs avec les murs).
local CORNER_OFFSETS = {
	Vector3.new(-20, 0, -20),
	Vector3.new(20, 0, -20),
	Vector3.new(-20, 0, 20),
	Vector3.new(20, 0, 20),
}

-- Crée et parente un item de test au-dessus de la base donnée.
local function spawnItem(base, offset)
	local basePart = base:FindFirstChild("BasePart")
	if not basePart or not basePart:IsA("BasePart") then
		return
	end

	local itemSpawns = base:FindFirstChild("ItemSpawns")
	if not itemSpawns then
		return
	end

	local item = Instance.new("Part")
	item.Name = "Item"
	item.Size = Vector3.new(2, 2, 2)
	item.Color = Color3.fromRGB(255, 0, 0)
	item.Anchored = false
	item.CanCollide = true
	item.Position = basePart.Position + Vector3.new(offset.X, SPAWN_HEIGHT_OFFSET, offset.Z)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ramasser"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 15
	prompt.Parent = item

	item.Parent = itemSpawns
end

function ItemSpawner.start()
	-- Synchronise l'apparition des objets avec la phase de Feeding.
	GameLoopManager.ServerEvent.Event:Connect(function(eventName, state)
		if eventName == "StateChanged" and state == "Feeding" then
			local map = workspace:FindFirstChild("Map")
			if map then
				for _, base in ipairs(getBases(map)) do
					for _, offset in ipairs(CORNER_OFFSETS) do
						spawnItem(base, offset)
					end
				end
			end
		end
	end)

	-- Premier spawn au cas où le serveur démarre directement en phase Feeding.
	if GameLoopManager.GetState() == "Feeding" then
		local map = workspace:FindFirstChild("Map")
		if map then
			for _, base in ipairs(getBases(map)) do
				for _, offset in ipairs(CORNER_OFFSETS) do
					spawnItem(base, offset)
				end
			end
		end
	end
end

return ItemSpawner
