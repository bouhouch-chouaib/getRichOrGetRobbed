--!strict
-- ItemSpawner : objets à jeter dans le trou noir, posés dans les bases occupées.
--   - À l'arrivée d'un joueur : Config.Items.StarterCount objets au hasard dans sa base.
--   - Pendant le Feeding : un objet toutes les SpawnInterval secondes dans chaque base (max MaxPerBase).
-- Les objets apparaissent sur les 4 palettes de la base, et aussi dans l'arène (objets "sauvages",
-- ramassables par tout le monde et un peu plus précieux en moyenne). Le type (Config.ItemTiers) est tiré au hasard ;
-- l'amélioration "ItemQuality" (affichée "Chance") du propriétaire rend les objets précieux plus fréquents. Chaque objet porte l'attribut "Value" (points rapportés).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseManager = require(script.Parent.BaseManager)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local SessionData = require(script.Parent.SessionData)

local ItemSpawner = {}

local rng = Random.new()

-- Tire un type d'objet selon le niveau de qualité du propriétaire.
local function rollTier(quality: number): Config.ItemTier
	local boost = 1 + quality * Config.Items.QualityBoost
	local total = 0
	local weights = {}
	for index, tier in ipairs(Config.ItemTiers) do
		weights[index] = tier.Weight * boost ^ (index - 1)
		total += weights[index]
	end
	local roll = rng:NextNumber() * total
	for index, weight in ipairs(weights) do
		roll -= weight
		if roll <= 0 then
			return Config.ItemTiers[index]
		end
	end
	return Config.ItemTiers[1]
end

local function createItem(tier: Config.ItemTier, cframe: CFrame): Part
	local item = Instance.new("Part")
	item.Name = "Item"
	item.Shape = tier.Shape
	item.Size = if tier.Shape == Enum.PartType.Block and tier.Id == "Lingot"
		then Vector3.new(tier.Size * 1.4, tier.Size * 0.6, tier.Size * 0.8)
		else Vector3.one * tier.Size
	item.Color = tier.Color
	item.Material = tier.Material
	item.CFrame = cframe * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	item.Anchored = false
	-- Frottement maximal, aucun rebond : l'objet s'arrête là où il tombe (il ne glisse pas jusqu'au trou).
	item.CustomPhysicalProperties = PhysicalProperties.new(2, 2, 0, 100, 100)
	item:SetAttribute("IsItem", true)
	item:SetAttribute("Tier", tier.Id)
	item:SetAttribute("Value", tier.Value)

	if tier.Glow then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Rate = 6
		sparkles.Lifetime = NumberRange.new(0.6, 1)
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.4, 0)
		sparkles.Color = ColorSequence.new(tier.Color)
		sparkles.LightEmission = 1
		sparkles.Parent = item
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ramasser"
	prompt.ObjectText = string.format("%s (+%s)", tier.Name, tostring(tier.Value))
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	-- La bulle est portée par un point d'ancrage que le client garde juste au-dessus de l'objet,
	-- quelle que soit sa rotation (cf. client/ItemPromptAnchors).
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAnchor"
	anchor.Position = Vector3.new(0, item.Size.Y / 2 + 1.5, 0)
	anchor.Parent = item
	prompt.Parent = anchor

	return item
end

local function spawnInBase(base: Model)
	local itemSpawns = base:FindFirstChild("ItemSpawns")
	local spawnPoints = base:FindFirstChild("SpawnPoints")
	if not itemSpawns or not spawnPoints or #itemSpawns:GetChildren() >= Config.Items.MaxPerBase then
		return
	end
	local points = spawnPoints:GetChildren()
	local point = points[rng:NextInteger(1, #points)]
	if not point or not point:IsA("BasePart") then
		return
	end

	local owner = BaseManager.GetOwner(base)
	local quality = if owner then SessionData.GetUpgradeLevel(owner, "ItemQuality") else 0
	-- Petit décalage aléatoire pour ne pas empiler les objets (ils restent sur la palette).
	local offset = CFrame.new(rng:NextNumber(-2.5, 2.5), rng:NextNumber(0, 1.5), rng:NextNumber(-2.5, 2.5))
	local item = createItem(rollTier(quality), point.CFrame * offset)
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

-- Objet sauvage : position au hasard dans l'arène, entre le dôme et les bases.
local function spawnWild()
	local map = Workspace:FindFirstChild("Map")
	local wild = map and map:FindFirstChild("WildItems")
	if not wild or #wild:GetChildren() >= Config.Items.WildMax then
		return
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(Config.Items.WildMinRadius, Config.Items.WildMaxRadius)
	local position = Vector3.new(math.cos(angle) * radius, 6, math.sin(angle) * radius)
	local item = createItem(rollTier(Config.Items.WildQuality), CFrame.new(position))
	item.Parent = wild
	ItemInteraction.Register(item)
end

function ItemSpawner.Init()
	-- Kit de départ : quelques objets pour marquer ses premiers points.
	BaseManager.BaseAssigned:Connect(function(_player: Player, base: Model)
		for _ = 1, Config.Items.StarterCount do
			spawnInBase(base)
		end
	end)
	for _, base in ipairs(BaseManager.GetOccupiedBases()) do
		for _ = 1, Config.Items.StarterCount do
			spawnInBase(base)
		end
	end

	GameLoopManager.ServerEvent.Event:Connect(function(eventName: string, state: string)
		if eventName == "StateChanged" and state == "Feeding" then
			cleanupLooseItems()
		end
	end)

	task.spawn(function()
		local wildTimer = 0
		while true do
			task.wait(Config.Items.SpawnInterval)
			if GameLoopManager.GetState() == "Feeding" then
				for _, base in ipairs(BaseManager.GetOccupiedBases()) do
					spawnInBase(base)
				end
				wildTimer += Config.Items.SpawnInterval
				if wildTimer >= Config.Items.WildInterval then
					wildTimer = 0
					spawnWild()
				end
			end
		end
	end)
end

return ItemSpawner
