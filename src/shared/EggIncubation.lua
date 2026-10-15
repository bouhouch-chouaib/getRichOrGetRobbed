--!strict
-- Pure incubation rules. Absolute UTC deadlines keep progressing while offline.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local Eggs = {}

export type Egg = { id: string, petId: string, count: number, startedAt: number, readyAt: number }
export type Batch = { count: number, startedAt: number, readyAt: number }

local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function Eggs.Duration(rarity: string): number
	return Config.Eggs.Seconds[rarity] or Config.Eggs.Seconds.Commun
end

function Eggs.Time(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return if s < 60 then string.format("%d s", s) else string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- Merge saved and early-session eggs without duplicating a batch. Old saves have no eggs.
function Eggs.Merge(saved: any, current: { Egg }): { Egg }
	local result: { Egg } = {}
	local seen: { [string]: boolean } = {}
	local function append(source: any)
		if type(source) ~= "table" then
			return
		end
		for _, raw in ipairs(source) do
			if type(raw) ~= "table" or type(raw.id) ~= "string" or seen[raw.id] then
				continue
			end
			local petId = if type(raw.petId) == "string" then Catalog.CurrentId(raw.petId) else nil
			if
				not petId
				or not Catalog.ById[petId]
				or not finite(raw.count)
				or raw.count < 1
				or not finite(raw.startedAt)
				or not finite(raw.readyAt)
				or raw.startedAt < 0
				or raw.readyAt < raw.startedAt
			then
				continue
			end
			seen[raw.id] = true
			table.insert(
				result,
				{
					id = raw.id,
					petId = petId,
					count = math.floor(raw.count),
					startedAt = raw.startedAt,
					readyAt = raw.readyAt,
				}
			)
		end
	end
	append(saved)
	append(current)
	return result
end

function Eggs.Create(petId: string, count: number, time: number, id: string): Egg?
	local pet = Catalog.ById[petId]
	if not pet or not finite(count) or count < 1 then
		return nil
	end
	return {
		id = id,
		petId = petId,
		count = math.floor(count),
		startedAt = time,
		readyAt = time + Eggs.Duration(pet.Rarity),
	}
end

-- Sépare les œufs prêts : (en attente, familiers éclos petId -> quantité, liste des lots éclos).
function Eggs.Collect(queue: { Egg }, time: number): ({ Egg }, { [string]: number }, { Egg })
	local pending: { Egg }, hatched: { [string]: number }, done: { Egg } = {}, {}, {}
	for _, egg in ipairs(queue) do
		if egg.readyAt <= time then
			hatched[egg.petId] = (hatched[egg.petId] or 0) + egg.count
			table.insert(done, egg)
		else
			table.insert(pending, egg)
		end
	end
	return pending, hatched, done
end

-- Un exemplaire d'un lot : chaque œuf a son propre nid (server/EggController). La clé reste la même jusqu'à
-- l'éclosion.
function Eggs.UnitKey(egg: Egg, index: number): string
	return egg.id .. "#" .. index
end

-- Les œufs dans l'ordre d'éclosion (les plus proches d'abord), un par exemplaire.
export type Unit = { key: string, petId: string, startedAt: number, readyAt: number }
function Eggs.Units(queue: { Egg }): { Unit }
	local sorted = table.clone(queue)
	table.sort(sorted, function(a, b)
		if a.readyAt ~= b.readyAt then
			return a.readyAt < b.readyAt
		end
		return a.id < b.id
	end)
	local units: { Unit } = {}
	for _, egg in ipairs(sorted) do
		for index = 1, egg.count do
			table.insert(units, { key = Eggs.UnitKey(egg, index), petId = egg.petId, startedAt = egg.startedAt, readyAt = egg.readyAt })
		end
	end
	return units
end

function Eggs.Owned(pets: { [string]: number }, queue: { Egg }): { [string]: number }
	local result = table.clone(pets)
	for _, egg in ipairs(queue) do
		result[egg.petId] = (result[egg.petId] or 0) + egg.count
	end
	return result
end

function Eggs.Summary(queue: { Egg }): { [string]: Batch }
	local result: { [string]: Batch } = {}
	for _, egg in ipairs(queue) do
		local rarity = Catalog.ById[egg.petId].Rarity
		local batch = result[rarity]
		if batch then
			batch.count += egg.count
			if egg.readyAt < batch.readyAt then
				batch.startedAt, batch.readyAt = egg.startedAt, egg.readyAt
			end
		else
			result[rarity] = { count = egg.count, startedAt = egg.startedAt, readyAt = egg.readyAt }
		end
	end
	return result
end

return Eggs
