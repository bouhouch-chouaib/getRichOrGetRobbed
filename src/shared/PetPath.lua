--!strict
-- PetPath : trajet d'un familier lâché qui rentre à pied dans sa base (server/StealController -> client/LoosePets).
-- Le SERVEUR calcule une fois la liste de points (contournement du trou noir par un arc, puis entrée de la base) et la
-- publie en attribut ("Path", "PathStart", "PathSpeed") ; chacun calcule la position à l'instant voulu avec l'horloge
-- commune (workspace:GetServerTimeNow()) : tout le monde voit le familier au même endroit, sans réseau à chaque image.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PetPath = {}

local ARENA = Config.Arena
local RING_MIN = ARENA.DomeRadius + 6 -- jamais plus près du trou (ni dans le dôme)
local RING_MAX = ARENA.BaseRingRadius - ARENA.BaseSize.X / 2 - 12 -- l'allée entre le trou et les bases
local ARC_STEP = math.rad(12)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function onRing(angle: number, radius: number, y: number): Vector3
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

-- Points du trajet de `from` jusqu'au centre de la base (`home` = position du dessus de sa plateforme).
function PetPath.build(from: Vector3, home: Vector3): { Vector3 }
	local points = { from }
	local start = flat(from)
	local radius = math.clamp(start.Magnitude, RING_MIN, RING_MAX)
	local angle = math.atan2(start.Z, start.X)
	local target = math.atan2(home.Z, home.X)
	-- 1. Rejoindre l'allée (s'éloigner du trou, ou sortir d'une autre base).
	if math.abs(start.Magnitude - radius) > 1 then
		table.insert(points, onRing(angle, radius, 0))
	end
	-- 2. Tourner autour du trou par le plus court chemin, en arc.
	local delta = (target - angle + math.pi) % (2 * math.pi) - math.pi
	local steps = math.floor(math.abs(delta) / ARC_STEP)
	for i = 1, steps do
		table.insert(points, onRing(angle + delta * i / (steps + 1), radius, 0))
	end
	-- 3. Devant l'entrée de la base (côté trou), puis au centre de la base.
	table.insert(points, onRing(target, RING_MAX, 0))
	table.insert(points, home)
	return points
end

function PetPath.encode(points: { Vector3 }): string
	local parts = table.create(#points)
	for i, p in ipairs(points) do
		parts[i] = string.format("%.1f,%.1f,%.1f", p.X, p.Y, p.Z)
	end
	return table.concat(parts, ";")
end

function PetPath.decode(value: unknown): { Vector3 }
	local points = {}
	if type(value) ~= "string" then
		return points
	end
	for x, y, z in string.gmatch(value, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		local px, py, pz = tonumber(x), tonumber(y), tonumber(z)
		if px and py and pz then
			table.insert(points, Vector3.new(px, py, pz))
		end
	end
	return points
end

function PetPath.length(points: { Vector3 }): number
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	return total
end

-- Position et direction après `distance` studs de marche ; done = arrivé au bout.
function PetPath.at(points: { Vector3 }, distance: number): (Vector3, Vector3, boolean)
	if #points == 0 then
		return Vector3.zero, Vector3.zAxis, true
	end
	local left = math.max(0, distance)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local segment = (b - a).Magnitude
		if left <= segment and segment > 0 then
			local direction = (b - a) / segment
			return a + direction * left, direction, false
		end
		left -= segment
	end
	local last = points[#points]
	local before = if #points >= 2 then points[#points - 1] else last - Vector3.zAxis
	local direction = if (last - before).Magnitude > 0 then (last - before).Unit else Vector3.zAxis
	return last, direction, true
end

return PetPath
