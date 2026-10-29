--!strict
-- Pure incubation rules. Absolute UTC deadlines keep progressing while offline.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local Eggs = {}

-- evolve : l'œuf est dans la machine d'évolution (Config.Evolution) — il n'éclot plus tout seul.
--   stage = stade actuel (1 à 3), nextAt = prochaine tentative (UTC), done = il n'évoluera plus (tentative ratée ou
--   stade Ultime). 20 oct. : il finit d'abord son incubation normale (readyAt : on ne peut pas l'ouvrir avant), puis
--   chaque tentative est un tirage au sort visible (Eggs.StageChance). maxStage n'est plus utilisé (gardé pour les
--   anciennes sauvegardes).
export type Evolve = { stage: number, maxStage: number, nextAt: number, done: boolean }
export type Egg = { id: string, petId: string, count: number, startedAt: number, readyAt: number, evolve: Evolve? }
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
			local evolve: Evolve? = nil
			local e = raw.evolve
			if type(e) == "table" and finite(e.stage) and finite(e.maxStage) and finite(e.nextAt) then
				local stages = #Config.Evolution.Names
				evolve = {
					stage = math.clamp(math.floor(e.stage), 1, stages),
					maxStage = math.clamp(math.floor(e.maxStage), 1, stages),
					nextAt = e.nextAt,
					done = e.done == true,
				}
			end
			table.insert(
				result,
				{
					id = raw.id,
					petId = petId,
					count = math.floor(raw.count),
					startedAt = raw.startedAt,
					readyAt = raw.readyAt,
					evolve = evolve,
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
		if egg.readyAt <= time and not egg.evolve then -- dans la machine : c'est le joueur qui décide
			hatched[egg.petId] = (hatched[egg.petId] or 0) + egg.count
			table.insert(done, egg)
		else
			table.insert(pending, egg)
		end
	end
	return pending, hatched, done
end

-- Attente avant la tentative d'évolution suivante (depuis le stade `stage`), avec un peu de hasard. tier = niveau du
-- joueur (monde le plus loin) : plus il est haut, plus la capsule va vite (Config.Evolution.SpeedPerTier).
function Eggs.EvolveDelay(rarity: string, stage: number, roll: number, tier: number?): number
	local factor = Config.Evolution.StageTimeFactor[stage] or Config.Evolution.StageTimeFactor[1]
	local jitter = 1 + (roll * 2 - 1) * Config.Evolution.TimeJitter
	local speed = 1 - Config.Evolution.SpeedPerTier * (math.max(1, tier or 1) - 1)
	return Eggs.Duration(rarity) * factor * jitter * math.max(0.2, speed)
end

-- Chances (poids) de chaque stade maximum pour une capsule de ce niveau.
function Eggs.MaxStageWeights(tier: number?): { number }
	local weights = table.clone(Config.Evolution.MaxStageWeights)
	local shift = math.min(weights[1], Config.Evolution.UltimeWeightPerTier * (math.max(1, tier or 1) - 1))
	weights[1] -= shift
	weights[#weights] += shift
	return weights
end

-- Plafond secret d'un œuf qui entre dans la machine (roll entre 0 et 1).
function Eggs.RollMaxStage(roll: number, tier: number?): number
	local weights = Eggs.MaxStageWeights(tier)
	local total = 0
	for _, weight in ipairs(weights) do
		total += weight
	end
	local pick = roll * total
	for stage, weight in ipairs(weights) do
		pick -= weight
		if pick < 0 then
			return stage
		end
	end
	return #weights
end

-- Chance (0 à 1) que la tentative depuis le stade `stage` réussisse, pour une capsule de ce niveau. Mêmes chances
-- au total qu'avant (MaxStageWeights) : Évolué 60 %, puis Ultime 30 % de ceux-là (18 % au total) en Prairie.
function Eggs.StageChance(stage: number, tier: number?): number
	local weights = Eggs.MaxStageWeights(tier)
	local above, from = 0, 0
	for index, weight in ipairs(weights) do
		if index > stage then
			above += weight
		end
		if index >= stage then
			from += weight
		end
	end
	return if from > 0 then above / from else 0
end

-- Première tentative d'un œuf qui entre dans la capsule : après la fin de son incubation normale.
function Eggs.FirstAttemptAt(egg: Egg, time: number, roll: number, tier: number?): number
	return math.max(time, egg.readyAt) + Eggs.EvolveDelay(Catalog.ById[egg.petId].Rarity, 1, roll, tier)
end

-- L'œuf de la capsule peut-il être ouvert ? Seulement une fois son incubation normale terminée.
function Eggs.CanOpen(egg: Egg, time: number): boolean
	return time >= egg.readyAt
end

-- Accélérer en Robux (Config.SpeedUp) : ce qu'il reste à attendre pour cet œuf, en secondes. Couveuse : son éclosion ;
-- capsule : sa prochaine tentative d'évolution (ou la fin de son incubation s'il n'évoluera plus). 0 : rien à attendre.
function Eggs.WaitLeft(egg: Egg, time: number): number
	local evolve = egg.evolve
	local target = if evolve and not evolve.done then math.max(egg.readyAt, evolve.nextAt) else egg.readyAt
	return math.max(0, target - time)
end

-- Accélère l'œuf : celui de la couveuse éclot au prochain tour ; celui de la capsule finit son incubation et tente sa
-- prochaine évolution tout de suite (le tirage au sort, lui, ne change pas).
function Eggs.SpeedUp(egg: Egg, time: number)
	egg.readyAt = math.max(egg.startedAt, math.min(egg.readyAt, time))
	local evolve = egg.evolve
	if evolve and not evolve.done then
		evolve.nextAt = math.min(evolve.nextAt, time)
	end
end

-- Une tentative d'évolution si c'est l'heure : "Evolved" (stade +1), "Maxed" (ratée : il n'évoluera plus) ou nil.
-- roll (0 à 1) décide de la réussite (Eggs.StageChance).
function Eggs.TryEvolve(egg: Egg, time: number, roll: number, tier: number?): string?
	local evolve = egg.evolve
	if not evolve or evolve.done or time < evolve.nextAt then
		return nil
	end
	local stages = #Config.Evolution.Names
	if evolve.stage < stages and roll < Eggs.StageChance(evolve.stage, tier) then
		evolve.stage += 1
		if evolve.stage >= stages then
			evolve.done = true -- Ultime : rien au-dessus
		else
			evolve.nextAt = time + Eggs.EvolveDelay(Catalog.ById[egg.petId].Rarity, evolve.stage, (roll * 7.31) % 1, tier)
		end
		return "Evolved"
	end
	evolve.done = true
	return "Maxed"
end

-- Un exemplaire d'un lot : chaque œuf a son propre nid (server/EggController). La clé reste la même jusqu'à
-- l'éclosion.
function Eggs.UnitKey(egg: Egg, index: number): string
	return egg.id .. "#" .. index
end

-- Les œufs dans l'ordre d'éclosion (les plus proches d'abord), un par exemplaire.
export type Unit = { key: string, petId: string, startedAt: number, readyAt: number }
function Eggs.Units(queue: { Egg }): { Unit }
	local sorted = {}
	for _, egg in ipairs(queue) do
		if not egg.evolve then -- l'œuf de la machine d'évolution n'a pas de nid
			table.insert(sorted, egg)
		end
	end
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
