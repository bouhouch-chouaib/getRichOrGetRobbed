--!strict
-- PetWander : promenade des familiers dans les bases, partagée serveur / client.
-- Le SERVEUR choisit les trajets (BasePetsController) et les écrit dans l'attribut "Walk" du repère de chaque familier ;
-- les CLIENTS calculent la position à l'instant voulu avec l'horloge commune (workspace:GetServerTimeNow()).
-- Tout le monde voit donc les familiers au même endroit, sans déplacer de pièce par le réseau à chaque image.
-- Coordonnées "locales" : (X, Z) en studs sur le dessus de la plateforme de la base, (0, 0) = centre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)

local PetWander = {}

PetWander.AREA = 22 -- demi-taille de la zone de promenade (la base fait 56 x 56, clôture comprise)
local CRATE_ZONE = 13 -- les coins (palettes à objets) sont évités

export type Style = {
	speed: number, -- studs / s
	minWait: number, -- pause entre deux trajets (s)
	maxWait: number,
	hover: number, -- hauteur au-dessus du sol (affichage)
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

-- Un point au hasard dans la zone de promenade (hors des coins).
function PetWander.randomSpot(rng: Random): Vector2
	local area = PetWander.AREA
	for _ = 1, 20 do
		local spot = Vector2.new(rng:NextNumber(-area, area), rng:NextNumber(-area, area))
		if not (math.abs(spot.X) > CRATE_ZONE and math.abs(spot.Y) > CRATE_ZONE) then
			return spot
		end
	end
	return Vector2.zero
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

-- Position locale à l'instant `now`, et true si le familier est en train de marcher.
function PetWander.positionAt(leg: Leg, now: number): (Vector2, boolean)
	if leg.duration <= 0 then
		return leg.to, false
	end
	local alpha = (now - leg.start) / leg.duration
	if alpha <= 0 then
		return leg.from, false
	elseif alpha >= 1 then
		return leg.to, false
	end
	return leg.from:Lerp(leg.to, alpha), true
end

-- Repère du sol d'une base : centre du dessus de sa plateforme, orienté comme la base.
function PetWander.groundOf(platform: BasePart): CFrame
	return platform.CFrame * CFrame.new(0, platform.Size.Y / 2, 0)
end

return PetWander
