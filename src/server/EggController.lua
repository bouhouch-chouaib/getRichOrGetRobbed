--!strict
-- Only this server clock can hatch rewards. Eggs never enter the pet inventory before their deadline.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.EggIncubation)
local Catalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetSizes = require(ReplicatedStorage.Shared.PetSizes)
local PetWander = require(ReplicatedStorage.Shared.PetWander)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local BasePets = require(script.Parent.BasePetsController)
local SessionData = require(script.Parent.SessionData)
local EggController = {}

function EggController.Init(bases: { Model })
	local folders: { [Model]: Folder } = {}
	for _, base in ipairs(bases) do
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "Eggs", base
		folders[base] = folder
	end
	local function tickBase(base: Model)
		local folder = folders[base]
		local player = BaseManager.GetOwner(base)
		if not player then
			folder:ClearAllChildren()
			return
		end
		if not SessionData.IsLoaded(player) then
			return
		end
		local platform = base:FindFirstChild("BasePart")
		if not platform or not platform:IsA("BasePart") then
			return
		end
		local ground = PetWander.groundOf(platform)
		local hatched = SessionData.HatchEggs(player, os.time())
		local byRarity: { [string]: { [string]: number } } = {}
		local ids: { string }, spots: { [string]: Vector2 } = {}, {}
		for petId, count in pairs(hatched) do
			local rarity = Catalog.ById[petId].Rarity
			local batch = byRarity[rarity] or {}
			batch[petId] = count
			byRarity[rarity] = batch
			table.insert(ids, petId)
			local slot = Eggs.Slot(Config.RarityIndex[rarity])
			-- Giant pets emerge toward the inside of the nest, clear of the back fence.
			local area = math.max(2, PetWander.AREA - math.max(0, PetSizes.Radius(petId, rarity) - 4))
			spots[petId] = Vector2.new(math.clamp(slot.X, -area, area), math.clamp(slot.Y, -area, area))
		end
		-- Data is already committed in memory; visuals cannot prevent or repeat a hatch.
		if #ids > 0 then
			BasePets.Celebrate(player, ids, spots)
			for rarity, pets in pairs(byRarity) do
				local slot = Eggs.Slot(Config.RarityIndex[rarity])
				Remotes.EggHatched:FireAllClients(player.UserId, rarity, ground * CFrame.new(slot.X, 0, slot.Y), pets)
			end
			-- One announcement for the rarest hatch, avoiding a burst of offline notifications.
			table.sort(ids, function(a, b)
				return Config.RarityIndex[Catalog.ById[a].Rarity] > Config.RarityIndex[Catalog.ById[b].Rarity]
			end)
			if Config.RarityIndex[Catalog.ById[ids[1]].Rarity] >= Config.Loot.AnnounceMinRarity then
				Remotes.Announcement:FireAllClients(player.DisplayName, ids[1])
			end
		end
		local summary = Eggs.Summary(SessionData.GetEggs(player))
		for rank, rarity in ipairs(Config.Rarities) do
			local batch = summary[rarity.Id]
			local old = folder:FindFirstChild(rarity.Id)
			if not batch then
				if old then
					old:Destroy()
				end
				continue
			end
			local anchor: BasePart
			if old and old:IsA("BasePart") then
				anchor = old
			else
				anchor = Instance.new("Part")
				anchor.Name = rarity.Id
				anchor.Size = Vector3.one
				anchor.Transparency = 1
				anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
				local slot = Eggs.Slot(rank)
				anchor.CFrame = ground * CFrame.new(slot.X, 0, slot.Y)
				anchor:SetAttribute("Rarity", rarity.Id)
				anchor:SetAttribute("OwnerUserId", player.UserId)
			end
			anchor:SetAttribute("Count", batch.count)
			anchor:SetAttribute("StartedAt", batch.startedAt)
			anchor:SetAttribute("ReadyAt", batch.readyAt)
			anchor.Parent = folder
			CollectionService:AddTag(anchor, "IncubatingEgg")
		end
	end
	task.spawn(function()
		while true do
			for _, base in ipairs(bases) do
				local ok, err = pcall(function(): any
					tickBase(base)
					return nil
				end)
				if not ok then
					warn("[EggController] " .. tostring(err))
				end
			end
			task.wait(1)
		end
	end)
end

return EggController
