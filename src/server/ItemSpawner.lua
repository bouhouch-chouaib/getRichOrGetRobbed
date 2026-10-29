--!strict
-- ItemSpawner : objets à jeter dans le trou noir, posés dans les bacs des bases occupées.
--   - À l'arrivée d'un joueur : Config.Items.StarterCount objets au hasard dans ses bacs.
--   - Pendant le Feeding : un objet toutes les SpawnInterval secondes dans chaque base (max MaxPerBase).
-- Les objets tombent dans les 2 bacs posés dehors devant la base (shared/BaseLayout.Bins, le moins rempli
-- d'abord), et aussi dans l'arène (objets "sauvages", ramassables par tout le monde et un peu plus précieux en moyenne).
-- Le rang (Config.ItemTiers) est tiré au hasard ; l'amélioration "ItemQuality" (affichée "Chance") du propriétaire rend
-- les objets précieux plus fréquents. L'objet lui-même vient du monde du propriétaire (Config.WorldItems : modèle en
-- briques ArtModels.Items.<Monde>.<Id>, points = valeur du rang x Points du monde). Attributs : "Value" (points
-- rapportés), "Tier" (rang), "World", "ItemId", "PointsBoost" (bonus du monde, retiré par la jauge du trou noir).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BaseLayout = require(ReplicatedStorage.Shared.BaseLayout)
local Config = require(ReplicatedStorage.Shared.Config)
local BaseManager = require(script.Parent.BaseManager)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local SessionData = require(script.Parent.SessionData)

local ItemSpawner = {}

local rng = Random.new()

-- Tire un rang d'objet (index dans Config.ItemTiers) selon le niveau de qualité du propriétaire.
local function rollRank(quality: number): number
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
			return index
		end
	end
	return 1
end

-- Modèle en briques d'un objet (ArtModels.Items.<Monde>.<Id>, fichier du jeu), nil s'il manque.
local function template(worldId: string, itemId: string): MeshPart?
	local art = ReplicatedStorage:FindFirstChild("ArtModels")
	local items = art and art:FindFirstChild("Items")
	local folder = items and items:FindFirstChild(worldId)
	local found = folder and folder:FindFirstChild(itemId)
	return if found and found:IsA("MeshPart") then found else nil
end

-- Points affichés dans la bulle : 0.25, 1.2, 36 (sans zéros inutiles).
local function formatPoints(value: number): string
	local text = string.format("%.2f", value)
	text = (string.gsub(text, "0+$", ""))
	return (string.gsub(text, "%.$", ""))
end

-- Un objet du rang `rank` venu du monde `world` (index de Config.Worlds). look = un autre modèle (objets crachés par
-- le trou noir : roche de lave, météorite), avec ses propres points.
type Look = { World: string, Id: string, Name: string, Value: number }
local function createItem(rank: number, world: number, cframe: CFrame, look: Look?): BasePart
	local tier = Config.ItemTiers[rank] or Config.ItemTiers[1]
	local worldDef = Config.Worlds[world] or Config.Worlds[1]
	local set = Config.WorldItems[worldDef.Id] or Config.WorldItems.Prairie
	local entry = set.Items[rank] or set.Items[1]
	local worldId, itemId, name = worldDef.Id, entry.Id, entry.Name
	local value, boost = tier.Value * set.Points, set.Points
	if look then
		worldId, itemId, name, value, boost = look.World, look.Id, look.Name, look.Value, 1
	end
	local yaw = CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	local source = template(worldId, itemId)
	local item: BasePart
	if source then
		-- Le modèle garde l'orientation de son import (posé debout) ; on le tourne seulement autour de la verticale.
		item = source:Clone()
		item.CFrame = cframe * yaw * source.CFrame.Rotation
	else
		-- Objet de secours en blocs tant que le modèle du monde n'est pas dans ArtModels.Items.
		local block = Instance.new("Part")
		block.Shape = tier.Shape
		block.Size = if tier.Id == "Lingot" then Vector3.new(tier.Size * 1.4, tier.Size * 0.6, tier.Size * 0.8) else Vector3.one * tier.Size
		block.Color = tier.Color
		block.Material = tier.Material
		block.CFrame = cframe * yaw
		item = block
	end
	item.Name = "Item"
	item.Anchored = false
	item.CanCollide = true
	item.CanQuery = true
	item.CanTouch = true
	item.Massless = false
	-- Frottement maximal, aucun rebond : l'objet s'arrête là où il tombe (il ne glisse pas jusqu'au trou).
	item.CustomPhysicalProperties = PhysicalProperties.new(2, 2, 0, 100, 100)
	item:SetAttribute("IsItem", true)
	item:SetAttribute("Tier", tier.Id)
	item:SetAttribute("Value", value)
	item:SetAttribute("World", worldId)
	item:SetAttribute("ItemId", itemId)
	item:SetAttribute("PointsBoost", boost)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ramasser"
	prompt.ObjectText = string.format("%s (+%s)", name, formatPoints(value))
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

-- Le point d'apparition du bac le moins rempli (à égalité, au hasard).
local BIN_REACH = BaseLayout.BIN_SIZE.Z / 2 + 1
local function emptiestPoint(points: { Instance }, items: { Instance }): BasePart?
	local best: BasePart? = nil
	local bestCount = math.huge
	for _, point in ipairs(points) do
		if point:IsA("BasePart") then
			local count = 0
			for _, item in ipairs(items) do
				if item:IsA("BasePart") and ((item.Position - point.Position) * Vector3.new(1, 0, 1)).Magnitude < BIN_REACH then
					count += 1
				end
			end
			if count < bestCount or (count == bestCount and rng:NextNumber() < 0.5) then
				best, bestCount = point, count
			end
		end
	end
	return best
end

local function spawnInBase(base: Model)
	local itemSpawns = base:FindFirstChild("ItemSpawns")
	local spawnPoints = base:FindFirstChild("SpawnPoints")
	if not itemSpawns or not spawnPoints or #itemSpawns:GetChildren() >= Config.Items.MaxPerBase then
		return
	end
	local point = emptiestPoint(spawnPoints:GetChildren(), itemSpawns:GetChildren())
	if not point then
		return
	end

	local owner = BaseManager.GetOwner(base)
	local quality = if owner then SessionData.GetUpgradeLevel(owner, "ItemQuality") else 0
	local world = if owner then SessionData.GetWorld(owner) else 1
	-- Place libre dans le bac : parmi quelques essais, le point le plus loin des objets déjà dedans (deux objets qui
	-- apparaissent l'un dans l'autre s'éjectent et peuvent sauter par-dessus le rebord).
	local spread = BaseLayout.BIN_SIZE / 2 - Vector3.new(1.5, 0, 1.8)
	local offset, bestGap = CFrame.new(), -1
	for _ = 1, 8 do
		local candidate = CFrame.new(rng:NextNumber(-spread.X, spread.X), rng:NextNumber(0, 0.5), rng:NextNumber(-spread.Z, spread.Z))
		local at = (point.CFrame * candidate).Position
		local gap = math.huge
		for _, other in ipairs(itemSpawns:GetChildren()) do
			if other:IsA("BasePart") then
				gap = math.min(gap, ((other.Position - at) * Vector3.new(1, 0, 1)).Magnitude)
			end
		end
		if gap > bestGap then
			offset, bestGap = candidate, gap
		end
	end
	local item = createItem(rollRank(quality), world, point.CFrame * offset)
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
	-- L'arène est partagée : l'objet vient du monde d'un joueur du serveur tiré au hasard.
	local players = Players:GetPlayers()
	local world = if #players > 0 then SessionData.GetWorld(players[rng:NextInteger(1, #players)]) else 1
	local item = createItem(rollRank(Config.Items.WildQuality), world, CFrame.new(position))
	item.Parent = wild
	ItemInteraction.Register(item)
end

-- Objet spécial projeté par le trou noir (server/BlackholeTiers) : "Lava" = roche de lave du Volcan (valeur du rang
-- x Lava.ValueMultiplier), "Meteor" = météorite d'or du Cosmos tombée du ciel (Gravity.MeteorValue). Il part de
-- `position` à la vitesse `velocity` et devient un objet sauvage.
function ItemSpawner.SpawnSpecial(kind: string, position: Vector3, velocity: Vector3): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local wild = map and map:FindFirstChild("WildItems")
	if not wild or #wild:GetChildren() >= Config.Items.WildMax + 15 then
		return nil
	end
	local rank = if kind == "Meteor" then #Config.ItemTiers else rollRank(Config.Items.WildQuality)
	local look: Look = if kind == "Lava"
		then { World = "Volcan", Id = "RocheDeLave", Name = "Roche de lave", Value = Config.ItemTiers[rank].Value * Config.Blackhole.Lava.ValueMultiplier }
		else { World = "Cosmos", Id = "Meteorite", Name = "Météorite", Value = Config.Blackhole.Gravity.MeteorValue }
	local item = createItem(rank, 1, CFrame.new(position), look)
	if kind == "Lava" and item:IsA("Part") then
		-- objet de secours (pas de modèle) : un bloc orange, sans néon
		item.Shape = Enum.PartType.Block
		item.Size = Vector3.new(2.6, 2.2, 2.4)
		item.Color = Color3.fromRGB(255, 110, 30)
		item.Material = Enum.Material.SmoothPlastic
	end
	item:SetAttribute("Special", kind)
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "Trail"
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Rate = 30
	fire.Lifetime = NumberRange.new(0.4, 0.8)
	fire.Speed = NumberRange.new(1, 3)
	fire.Size = NumberSequence.new(1.6, 0)
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
	fire.LightEmission = 1
	fire.Parent = item
	-- Les flammes s'éteignent une fois posé (il reste une lueur).
	task.delay(4, function()
		if fire.Parent then
			fire.Rate = 4
		end
	end)
	item.Parent = wild
	item.AssemblyLinearVelocity = velocity
	ItemInteraction.Register(item)
	return item
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
