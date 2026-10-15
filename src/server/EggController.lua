--!strict
-- EggController : les œufs de chaque base, au rythme de l'horloge du SERVEUR (aucun client ne peut faire éclore).
--   - Chaque œuf (un exemplaire d'un lot) a SON nid dans la couveuse au fond de la base (shared/BaseLayout,
--     12 nids). Les 12 premiers à éclore sont posés ; les suivants attendent qu'un nid se libère (attribut
--     "Waiting" du dossier Base_N.Eggs, affiché « +N ŒUFS » par client/Eggs).
--   - Un nid garde son œuf jusqu'à l'éclosion : l'arrivée de nouveaux œufs ne déplace pas les anciens.
--   - Repère invisible Base_N.Eggs.<clé> (tag "IncubatingEgg") : Rarity, OwnerUserId, StartedAt, ReadyAt, Nest.
--     Le familier reste secret jusqu'à l'éclosion (seule la rareté est visible).
--   - À l'échéance : les œufs deviennent des familiers (SessionData.HatchEggs, sans attente), le familier sort de son
--     nid s'il fait partie des familiers affichés dans la base (BasePetsController.Celebrate), puis un
--     Remotes.EggHatched par œuf : client/Eggs joue l'éclosion, de plus en plus spectaculaire avec la rareté.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseLayout = require(ReplicatedStorage.Shared.BaseLayout)
local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.EggIncubation)
local Catalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetWander = require(ReplicatedStorage.Shared.PetWander)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local BasePets = require(script.Parent.BasePetsController)
local SessionData = require(script.Parent.SessionData)
local EggController = {}

-- Par base : quel œuf occupe quel nid.
type Nests = { byKey: { [string]: number }, byNest: { [number]: string } }
type Event = { key: string, petId: string, nest: number? }

local MAX_EVENTS = 24 -- éclosions jouées en même temps au plus (retour après une longue absence)

local function nestCFrame(ground: CFrame, nest: number): CFrame
	local spot = BaseLayout.Nest(nest)
	return ground * CFrame.new(spot.X, 0, spot.Y)
end

local function rank(petId: string): number
	return Config.RarityIndex[Catalog.ById[petId].Rarity] or 1
end

function EggController.Init(bases: { Model })
	local folders: { [Model]: Folder } = {}
	local nests: { [Model]: Nests } = {}
	for _, base in ipairs(bases) do
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "Eggs", base
		folders[base] = folder
		nests[base] = { byKey = {}, byNest = {} }
	end

	local function tickBase(base: Model)
		local folder = folders[base]
		local state = nests[base]
		local player = BaseManager.GetOwner(base)
		if not player then
			if next(state.byKey) or #folder:GetChildren() > 0 then
				folder:ClearAllChildren()
				folder:SetAttribute("Waiting", nil)
				nests[base] = { byKey = {}, byNest = {} }
			end
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

		-- 1. Éclosions (les données sont déjà à jour en mémoire : l'affichage ne peut ni empêcher ni rejouer une éclosion).
		local hatched, done = SessionData.HatchEggs(player, os.time())
		if #done > 0 then
			local events: { Event } = {}
			local spots: { [string]: Vector2 } = {}
			local ids: { string } = {}
			for _, egg in ipairs(done) do
				for index = 1, egg.count do
					local key = Eggs.UnitKey(egg, index)
					local nest = state.byKey[key]
					if nest then
						state.byKey[key] = nil
						state.byNest[nest] = nil
						-- Le familier sort de son nid (le premier œuf de cette espèce s'il y en a plusieurs).
						if not spots[egg.petId] then
							spots[egg.petId] = BaseLayout.Nest(nest)
						end
					end
					table.insert(events, { key = key, petId = egg.petId, nest = nest })
				end
			end
			for petId in pairs(hatched) do
				table.insert(ids, petId)
			end
			BasePets.Celebrate(player, ids, spots)
			-- Les œufs posés d'abord (leur éclosion se voit), puis les plus rares.
			table.sort(events, function(a, b)
				if (a.nest ~= nil) ~= (b.nest ~= nil) then
					return a.nest ~= nil
				end
				return rank(a.petId) > rank(b.petId)
			end)
			local walked: { [string]: boolean } = {}
			for order, event in ipairs(events) do
				if order > MAX_EVENTS then
					break
				end
				local nest = event.nest
				-- Sans nid (œufs en attente éclos pendant une absence) : au milieu de la couveuse.
				local cf = if nest
					then nestCFrame(ground, nest)
					else ground * CFrame.new(BaseLayout.IncubatorCenter.X, 0, BaseLayout.IncubatorCenter.Y)
				-- « Dans la base » : ce familier sort du nid et va se promener (un seul par espèce).
				local inBase = nest ~= nil and not walked[event.petId] and BasePets.IsShown(player, event.petId)
				if inBase then
					walked[event.petId] = true
				end
				Remotes.EggHatched:FireAllClients(player.UserId, event.key, Catalog.ById[event.petId].Rarity, cf, event.petId, inBase)
			end
			-- Une seule annonce pour le plus rare (pas de rafale au retour d'une absence).
			table.sort(ids, function(a, b)
				return rank(a) > rank(b)
			end)
			if rank(ids[1]) >= Config.Loot.AnnounceMinRarity then
				Remotes.Announcement:FireAllClients(player.DisplayName, ids[1])
			end
		end

		-- 2. Les nids : chaque œuf garde le sien, les nouveaux prennent les nids libres dans l'ordre d'éclosion.
		local units = Eggs.Units(SessionData.GetEggs(player))
		local pending: { [string]: Eggs.Unit } = {}
		for _, unit in ipairs(units) do
			pending[unit.key] = unit
		end
		for key, nest in pairs(state.byKey) do
			if not pending[key] then
				state.byKey[key] = nil
				state.byNest[nest] = nil
			end
		end
		local waiting = 0
		for _, unit in ipairs(units) do
			if not state.byKey[unit.key] then
				local free: number? = nil
				for nest = 1, BaseLayout.MAX_NESTS do
					if not state.byNest[nest] then
						free = nest
						break
					end
				end
				if free then
					state.byKey[unit.key] = free
					state.byNest[free] = unit.key
				else
					waiting += 1
				end
			end
		end
		folder:SetAttribute("Waiting", if waiting > 0 then waiting else nil)

		-- 3. Les repères : un par œuf posé.
		for _, child in ipairs(folder:GetChildren()) do
			if not state.byKey[child.Name] then
				child:Destroy()
			end
		end
		for key, nest in pairs(state.byKey) do
			local unit = pending[key]
			if not unit or folder:FindFirstChild(key) then
				continue
			end
			local anchor = Instance.new("Part")
			anchor.Name = key
			anchor.Size = Vector3.one
			anchor.Transparency = 1
			anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
			anchor.CFrame = nestCFrame(ground, nest)
			anchor:SetAttribute("Rarity", Catalog.ById[unit.petId].Rarity)
			anchor:SetAttribute("OwnerUserId", player.UserId)
			anchor:SetAttribute("StartedAt", unit.startedAt)
			anchor:SetAttribute("ReadyAt", unit.readyAt)
			anchor:SetAttribute("Nest", nest)
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
