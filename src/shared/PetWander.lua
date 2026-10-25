--!strict
-- PetWander : promenade des familiers dans les bases, partagée serveur / client.
-- Le SERVEUR choisit les trajets (BasePetsController) et les écrit dans l'attribut "Walk" du repère de chaque familier ;
-- les CLIENTS calculent la position à l'instant voulu avec l'horloge commune (workspace:GetServerTimeNow()).
-- Tout le monde voit donc les familiers au même endroit, sans déplacer de pièce par le réseau à chaque image.
-- Coordonnées "locales" : (X, Z) en studs sur le dessus de la plateforme de la base, (0, 0) = centre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseLayout = require(ReplicatedStorage.Shared.BaseLayout)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetGaits = require(ReplicatedStorage.Shared.PetGaits)
local PetSizes = require(ReplicatedStorage.Shared.PetSizes)

local PetWander = {}

-- Zone de promenade : la prairie au milieu de la base (shared/BaseLayout), entre les palettes de l'avant et la
-- couveuse du fond.
local ZONE_CENTER = BaseLayout.PetZoneCenter
local ZONE_HALF = BaseLayout.PetZoneHalf

export type Style = {
	speed: number, -- studs / s
	minWait: number, -- pause entre deux trajets (s)
	maxWait: number,
	hover: number, -- hauteur au-dessus du sol (affichage)
	roam: number?, -- longueur maximale d'un trajet (studs) ; sinon n'importe où dans la prairie
}

PetWander.STYLES = {
	Walk = { speed = 5, minWait = 1, maxWait = 4, hover = 0 },
	Hop = { speed = 6, minWait = 0.5, maxWait = 3, hover = 0 },
	Slither = { speed = 3.5, minWait = 1, maxWait = 3, hover = 0 },
	Fly = { speed = 6, minWait = 0.5, maxWait = 2.5, hover = 3 },
	Plant = { speed = 1.5, minWait = 5, maxWait = 12, hover = 0 },
	Spin = { speed = 2.5, minWait = 2, maxWait = 5, hover = 2 },
} :: { [string]: Style }

local SPIN_PETS = { OuroborosInfini = true, ToupieTrouDeVer = true, GraineEtoile = true }

-- Façon de bouger selon la silhouette : marche, sautille, ondule, plane, se balance sur place, tourne sur lui-même.
function PetWander.styleFor(petId: string): string
	if SPIN_PETS[petId] then
		return "Spin"
	end
	local entry = PetCatalog.ById[petId]
	if not entry then
		return "Walk"
	end
	local look = entry.Look
	if look.Float or look.Shape == "Fish" or look.Shape == "Dragon" then
		return "Fly"
	elseif look.Shape == "Serpent" then
		return "Slither"
	elseif look.Shape == "Plant" then
		return "Plant"
	elseif look.Shape == "Blob" or look.Shape == "Object" or look.Shape == "Bird" then
		return "Hop"
	end
	return "Walk"
end

-- Rythme des trajets d'un familier : sa fiche de démarche (shared/PetGaits) s'il en a une, sinon le style de sa
-- silhouette. ease = accélération le long du trajet (voir PetWander.positionAt).
function PetWander.styleOf(petId: string): (Style, string)
	local g = PetGaits.For(petId)
	if g then
		return { speed = g.speed, minWait = g.minWait, maxWait = g.maxWait, hover = g.hover, roam = g.roam }, g.ease
	end
	return PetWander.STYLES[PetWander.styleFor(petId)], "Linear"
end

-- Un point au hasard dans la prairie. Avec petId, les grands familiers (shared/PetSizes) restent plus près du
-- centre pour ne pas déborder sur la clôture, les palettes ou la couveuse.
function PetWander.randomSpot(rng: Random, petId: string?): Vector2
	local margin = 0
	if petId then
		local entry = PetCatalog.ById[petId]
		margin = math.max(0, PetSizes.Radius(petId, entry and entry.Rarity) - 4)
	end
	local halfX = math.max(2, ZONE_HALF.X - margin)
	local halfZ = math.max(2, ZONE_HALF.Y - margin)
	return ZONE_CENTER + Vector2.new(rng:NextNumber(-halfX, halfX), rng:NextNumber(-halfZ, halfZ))
end

-- Un point pas trop loin de `from` (entre 40 % et 100 % de `roam` studs), dans la prairie : petits trajets des
-- familiers casaniers (shared/PetGaits « roam »).
function PetWander.nearbySpot(rng: Random, petId: string, from: Vector2, roam: number): Vector2
	local entry = PetCatalog.ById[petId]
	local margin = math.max(0, PetSizes.Radius(petId, entry and entry.Rarity) - 4)
	local halfX = math.max(2, ZONE_HALF.X - margin)
	local halfZ = math.max(2, ZONE_HALF.Y - margin)
	local angle = rng:NextNumber(0, math.pi * 2)
	local spot = from + Vector2.new(math.cos(angle), math.sin(angle)) * rng:NextNumber(roam * 0.4, roam)
	return Vector2.new(
		math.clamp(spot.X, ZONE_CENTER.X - halfX, ZONE_CENTER.X + halfX),
		math.clamp(spot.Y, ZONE_CENTER.Y - halfZ, ZONE_CENTER.Y + halfZ)
	)
end

-- Un trajet : de `from` à `to`, départ à `start` (horloge serveur), pendant `duration` secondes.
export type Leg = {
	from: Vector2,
	to: Vector2,
	start: number,
	duration: number,
}

function PetWander.encode(leg: Leg): string
	return string.format("%.2f,%.2f,%.2f,%.2f,%.3f,%.3f", leg.from.X, leg.from.Y, leg.to.X, leg.to.Y, leg.start, leg.duration)
end

function PetWander.decode(value: unknown): Leg?
	if type(value) ~= "string" then
		return nil
	end
	local fx, fz, tx, tz, start, duration = string.match(value, "^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$")
	local numbers = { tonumber(fx), tonumber(fz), tonumber(tx), tonumber(tz), tonumber(start), tonumber(duration) }
	for index = 1, 6 do
		if numbers[index] == nil then
			return nil
		end
	end
	return {
		from = Vector2.new(numbers[1] :: number, numbers[2] :: number),
		to = Vector2.new(numbers[3] :: number, numbers[4] :: number),
		start = numbers[5] :: number,
		duration = numbers[6] :: number,
	}
end

-- Part du trajet faite quand `a` (0 à 1) du temps est passé. "Smooth" : démarre et freine en douceur ; "Dash" : part
-- comme une flèche et freine ; "Pounce" : s'approche lentement (40 % du chemin en 70 % du temps) puis bondit ;
-- "Pulse" : avance par poussées (une tous les 2 studs), comme un poulpe.
local POUNCE_AT = 0.7
PetWander.POUNCE_AT = POUNCE_AT
local function eased(ease: string?, a: number, length: number): number
	if ease == "Smooth" then
		return a * a * (3 - 2 * a)
	elseif ease == "Dash" then
		return 1 - (1 - a) ^ 2
	elseif ease == "Pounce" then
		return if a < POUNCE_AT then 0.4 * a / POUNCE_AT else 0.4 + 0.6 * (a - POUNCE_AT) / (1 - POUNCE_AT)
	elseif ease == "Pulse" then
		local n = math.max(1, math.round(length / 2))
		return a + math.sin(2 * math.pi * n * a) / (2 * math.pi * n) * 0.9
	end
	return a
end

-- Position locale à l'instant `now`, true si le familier est en train de marcher, et la part du trajet faite (0 à 1).
-- ease : accélération propre au familier (PetWander.styleOf), la même chez le serveur et chez les clients.
function PetWander.positionAt(leg: Leg, now: number, ease: string?): (Vector2, boolean, number)
	if leg.duration <= 0 then
		return leg.to, false, 1
	end
	local a = (now - leg.start) / leg.duration
	if a <= 0 then
		return leg.from, false, 0
	elseif a >= 1 then
		return leg.to, false, 1
	end
	local done = eased(ease, a, (leg.to - leg.from).Magnitude)
	return leg.from:Lerp(leg.to, done), true, done
end

-- Repère du sol d'une base : centre du dessus de sa plateforme, orienté comme la base.
function PetWander.groundOf(platform: BasePart): CFrame
	return platform.CFrame * CFrame.new(0, platform.Size.Y / 2, 0)
end

return PetWander
