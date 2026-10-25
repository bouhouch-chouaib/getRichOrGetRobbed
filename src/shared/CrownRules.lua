--!strict
-- CrownRules : règles pures de la couronne du plus riche (Config.Crown, ECONOMY_REPORT.md règle 9), testables hors
-- Studio (tools/check-steal-rules.luau). Utilisées par server/CrownController.

local Config = require(script.Parent.Config)

local CrownRules = {}

export type Entry = { id: number, income: number }
export type DefenseLog = { { at: number, thief: number } }

-- Qui porte la couronne : le plus gros revenu, s'il y a assez de joueurs. Le roi actuel la garde tant que personne ne le
-- dépasse de Config.Crown.Hysteresis. Renvoie l'id du roi, ou nil.
function CrownRules.Pick(entries: { Entry }, currentId: number?): number?
	local crown = Config.Crown
	if #entries < crown.MinPlayers then
		return nil
	end
	local best: Entry? = nil
	local current: Entry? = nil
	for _, entry in ipairs(entries) do
		if not best or entry.income > best.income then
			best = entry
		end
		if entry.id == currentId then
			current = entry
		end
	end
	if not best or best.income <= 0 then
		return nil
	end
	if current and current.income > 0 and best.income <= current.income * (1 + crown.Hysteresis) then
		return current.id
	end
	return best.id
end

-- La défense contre ce voleur est-elle récompensée ? (au plus MaxDefenseRewardsPerHour par heure, une fois par voleur
-- toutes les DefenseCooldown secondes). log = défenses déjà récompensées.
function CrownRules.CanReward(log: DefenseLog, thiefId: number, now: number): boolean
	local crown = Config.Crown
	local lastHour = 0
	for _, entry in ipairs(log) do
		if now - entry.at < 3600 then
			lastHour += 1
		end
		if entry.thief == thiefId and now - entry.at < crown.DefenseCooldown then
			return false
		end
	end
	return lastHour < crown.MaxDefenseRewardsPerHour
end

return CrownRules
