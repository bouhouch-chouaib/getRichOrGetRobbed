--!strict
-- ItemSpawner : fait apparaître des objets géométriques dans les bases occupées pendant le Feeding.
-- Au début du Feeding : remplit chaque base. Ensuite : un objet toutes les SpawnInterval secondes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseManager = require(script.Parent.BaseManager)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)

local ItemSpawner = {}

local SHAPES = { Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder }
local rng = Random.new()

local function createItem(cframe: CFrame): Part
	local item = Instance.new("Part")
	item.Name = "Item"
	item.Shape = SHAPES[rng:NextInteger(1, #SHAPES)]
	item.Size = Vector3.one * Config.Items.Size
	item.Color = Config.ItemColors[rng:NextInteger(1, #Config.ItemColors)]
	item.Material = Enum.Material.Neon
	item.CFrame = cframe * CFrame.Angles(rng:NextNumber() * math.pi, rng:NextNumber() * math.pi, 0)
	item.Anchored = false
	item:SetAttribute("IsItem", true)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ramasser"
	prompt.ObjectText = "Objet"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = item

	return item
end

-- pointIndex : coin précis à utiliser (sinon un coin au hasard).
local function spawnInBase(base: Model, pointIndex: number?)
	local itemSpawns = base:FindFirstChild("ItemSpawns")
	local spawnPoints = base:FindFirstChild("SpawnPoints")
	if not itemSpawns or not spawnPoints or #itemSpawns:GetChildren() >= Config.Items.MaxPerBase then
		return
	end

	local points = spawnPoints:GetChildren()
	local point = points[pointIndex or rng:NextInteger(1, #points)]
	if not point or not point:IsA("BasePart") then
		return
	end

	local item = createItem(point.CFrame)
	item.Parent = itemSpawns
	ItemInteraction.Register(item)
end

-- Évite l'accumulation infinie d'objets abandonnés sur la map.
local function cleanupLooseItems()
	local map = Workspace:FindFirstChild("Map")
	local loose = map and map:FindFirstChild("LooseItems")
	if not loose then
		return
	end
	local items = loose:GetChildren()
	local excess = #items - Config.Items.MaxLooseItems
	for _, item in ipairs(items) do
		if excess <= 0 then
			break
		end
		if item:IsA("BasePart") and not ItemInteraction.IsHeld(item) then
			item:Destroy()
			excess -= 1
		end
	end
end

-- Pose un objet sur chaque coin de la base.
local function fillBase(base: Model)
	for index = 1, Config.Items.InitialPerBase do
		spawnInBase(base, (index - 1) % 4 + 1)
	end
end

local function isEmpty(base: Model): boolean
	local itemSpawns = base:FindFirstChild("ItemSpawns")
	return itemSpawns ~= nil and #itemSpawns:GetChildren() == 0
end

function ItemSpawner.Init()
	GameLoopManager.ServerEvent.Event:Connect(function(eventName: string, state: string)
		if eventName == "StateChanged" and state == "Feeding" then
			cleanupLooseItems()
			for _, base in ipairs(BaseManager.GetOccupiedBases()) do
				fillBase(base)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Items.SpawnInterval)
			if GameLoopManager.GetState() == "Feeding" then
				for _, base in ipairs(BaseManager.GetOccupiedBases()) do
					-- Base vidée (ou joueur arrivé en cours de manche) : on la remplit d'un coup.
					if isEmpty(base) then
						fillBase(base)
					else
						spawnInBase(base)
					end
				end
			end
		end
	end)
end

return ItemSpawner
