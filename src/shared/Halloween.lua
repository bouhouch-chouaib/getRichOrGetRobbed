--!strict
-- Halloween : dates de l'événement et heure hantée (Config.Halloween). Serveur (bonbons, citrouilles, chaudron) et client
-- (bouton BONBONS, ligne de l'heure hantée, ambiance) lisent la même heure que le trou noir doré (shared/GoldenHour).

local Config = require(script.Parent.Config)
local GoldenHour = require(script.Parent.GoldenHour)

local Halloween = {}

local SETTINGS = Config.Halloween

Halloween.Now = GoldenHour.Now

-- L'événement est-il en cours ? Dans Studio, l'attribut DebugHalloween (true / false) le force.
function Halloween.Active(now: number): boolean
	if game:GetService("RunService"):IsStudio() then
		local forced = workspace:GetAttribute("DebugHalloween")
		if type(forced) == "boolean" then
			return forced
		end
	end
	return now >= SETTINGS.Start and now < SETTINGS.End
end

-- Secondes avant la fin de l'événement (0 s'il est fini).
function Halloween.Left(now: number): number
	return math.max(0, SETTINGS.End - now)
end

-- Heure hantée : (active, secondes) = secondes qui restent si elle est active, sinon secondes avant la prochaine.
function Halloween.HauntedState(now: number): (boolean, number)
	local haunted = SETTINGS.HauntedHour
	local length = haunted.Minutes * 60
	local inHour = (now - haunted.Offset) % 3600
	if inHour < length then
		return true, length - inHour
	end
	return false, 3600 - inHour
end

-- Multiplicateur des bonbons à cet instant (1 hors de l'heure hantée).
function Halloween.CandyMultiplier(now: number): number
	local active = Halloween.HauntedState(now)
	return if active then SETTINGS.HauntedHour.CandyMultiplier else 1
end

-- Tire le familier d'un œuf Citrouille (roll entre 0 et 1) selon Config.Halloween.Chances (en %).
function Halloween.Roll(roll: number): string
	local total = 0
	for _, petId in ipairs(SETTINGS.Order) do
		total += SETTINGS.Chances[petId] or 0
	end
	local target = roll * total
	for _, petId in ipairs(SETTINGS.Order) do
		target -= SETTINGS.Chances[petId] or 0
		if target < 0 then
			return petId
		end
	end
	return SETTINGS.Order[#SETTINGS.Order]
end

return Halloween
