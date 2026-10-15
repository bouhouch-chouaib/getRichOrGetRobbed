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

function Eggs.Collect(queue: { Egg }, time: number): ({ Egg }, { [string]: number })
	local pending: { Egg }, hatched: { [string]: number } = {}, {}
	for _, egg in ipairs(queue) do
		if egg.readyAt <= time then
			hatched[egg.petId] = (hatched[egg.petId] or 0) + egg.count
		else
			table.insert(pending, egg)
		end
	end
	return pending, hatched
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

-- Eight compact nests in two rows, between the rear pallets, away from the spawn/gate.
function Eggs.Slot(index: number): Vector2
	return Vector2.new(((index - 1) % 4 - 1.5) * 6, -23 + math.floor((index - 1) / 4) * 6)
end

return Eggs
