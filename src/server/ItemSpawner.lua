--!strict
-- ItemSpawner : fait apparaître périodiquement des objets de test au-dessus des bases joueurs.
-- MVP / Greyboxing : Part rouge soumise à la physique, avec un ProximityPrompt "Ramasser".

local ItemSpawner = {}

local SPAWN_INTERVAL = 2
local SPAWN_HEIGHT_OFFSET = 10

-- Récupère toutes les bases (Models nommés "BaseN") parentées à Map.
local function getBases(map: Instance): { Instance }
	local bases = {}
	for _, child in ipairs(map:GetChildren()) do
		if child:IsA("Model") and child.Name:match("^Base%d+$") then
			table.insert(bases, child)
		end
	end
	return bases
end

-- Crée et parente un item de test au-dessus de la base donnée.
local function spawnItem(base: Instance)
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
	item.Position = basePart.Position + Vector3.new(0, SPAWN_HEIGHT_OFFSET, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ramasser"
	prompt.Parent = item

	item.Parent = itemSpawns
end

function ItemSpawner.start()
	task.spawn(function()
		while true do
			task.wait(SPAWN_INTERVAL)

			local map = workspace:FindFirstChild("Map")
			if not map then
				continue
			end

			local bases = getBases(map)
			if #bases == 0 then
				continue
			end

			local base = bases[math.random(1, #bases)]
			spawnItem(base)
		end
	end)
end

return ItemSpawner
