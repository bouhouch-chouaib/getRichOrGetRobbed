-- ItemSpawner : fait apparaître périodiquement des objets de test au-dessus des bases joueurs.
-- MVP / Greyboxing : Part rouge soumise à la physique, avec un ProximityPrompt "Ramasser".

local ItemSpawner = {}

local SPAWN_INTERVAL = 60
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

-- Crée et parente un item de test au-dessus de la base donnée.
local function spawnItem(base)
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
	local randomX = math.random(-20, 20)
	local randomZ = math.random(-20, 20)
	item.Position = basePart.Position + Vector3.new(randomX, SPAWN_HEIGHT_OFFSET, randomZ)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ramasser"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 15
	prompt.Parent = item

	item.Parent = itemSpawns
end

function ItemSpawner.start()
	task.spawn(function()
		-- Stock initial : 5 items par base au lancement.
		local map = workspace:FindFirstChild("Map")
		if map then
			local bases = getBases(map)
			for _, base in ipairs(bases) do
				for _ = 1, 5 do
					spawnItem(base)
				end
			end
		end

		while true do
			task.wait(SPAWN_INTERVAL)

			local currentMap = workspace:FindFirstChild("Map")
			if currentMap then
				local bases = getBases(currentMap)
				for _, base in ipairs(bases) do
					spawnItem(base)
				end
			end
		end
	end)
end

return ItemSpawner
