--!strict
-- GoldenHour : le trou noir doré des premières minutes de chaque heure (Config.GoldenHour). Serveur (points) et client
-- (compte à rebours) lisent la même heure : celle du serveur Roblox (Workspace:GetServerTimeNow), en UTC.

local Config = require(script.Parent.Config)

local GoldenHour = {}

-- Heure utilisée par le jeu ; dans Studio, l'attribut DebugGoldenShift (secondes) l'avance pour tester.
function GoldenHour.Now(): number
	local now = workspace:GetServerTimeNow()
	if game:GetService("RunService"):IsStudio() then
		local shift = workspace:GetAttribute("DebugGoldenShift")
		if type(shift) == "number" then
			now += shift
		end
	end
	return now
end

-- (actif, secondes) : secondes qui restent s'il est actif, sinon secondes avant le prochain.
function GoldenHour.State(now: number): (boolean, number)
	local length = Config.GoldenHour.Minutes * 60
	local inHour = now % 3600
	if inHour < length then
		return true, length - inHour
	end
	return false, 3600 - inHour
end

-- Multiplicateur des points à cet instant (1 en dehors du trou noir doré).
function GoldenHour.Multiplier(now: number): number
	local active = GoldenHour.State(now)
	return if active then Config.GoldenHour.PointsMultiplier else 1
end

return GoldenHour
