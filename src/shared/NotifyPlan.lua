--!strict
-- NotifyPlan : quelle notification prévoir pour un joueur qui quitte le jeu, et à quelle heure (Config.Notifications).
-- Sans état ni service Roblox (testé par tools/check-notify.luau) ; server/Notifications s'occupe de l'envoi.

local Config = require(script.Parent.Config)

local NotifyPlan = {}

export type Plan = { kind: string, sendAt: number, params: { [string]: string } }
type EggLike = { readyAt: number, evolve: any? }

local DAY = 86400

-- Jour de la série du cadeau du jour qu'on pourra réclamer le jour `today` (même règle que
-- ProgressionController.DailyDay) : nil si déjà réclamé ce jour-là.
function NotifyPlan.DailyDay(last: number, streak: number, today: number): number?
	if today <= last then
		return nil
	end
	if today == last + 1 and streak > 0 then
		return streak % #Config.Daily.Rewards + 1
	end
	return 1
end

-- eggs : œufs en incubation (sauvegarde) ; daily : { last, streak } du cadeau du jour ; leftAt : os.time() du départ.
function NotifyPlan.Plan(eggs: { EggLike }, daily: { last: number, streak: number }, leftAt: number): Plan?
	local settings = Config.Notifications
	local earliest = leftAt + settings.MinAway
	-- 1. Un œuf (hors capsule) qui finit pendant l'absence, pas trop tard.
	local eggAt: number? = nil
	for _, egg in eggs do
		if not egg.evolve and egg.readyAt > leftAt and egg.readyAt <= leftAt + settings.EggWindow then
			eggAt = math.min(eggAt or math.huge, egg.readyAt)
		end
	end
	if eggAt then
		return { kind = "EggReady", sendAt = math.max(eggAt, earliest), params = {} }
	end
	-- 2. Le cadeau du jour, vers la même heure le lendemain (et jamais avant qu'il soit réclamable).
	local sendAt = math.max(leftAt + settings.DailyDelay, (daily.last + 1) * DAY + 3600, earliest)
	local day = NotifyPlan.DailyDay(daily.last, daily.streak, math.floor(sendAt / DAY))
	if day then
		return { kind = "Daily", sendAt = sendAt, params = { day = tostring(day) } }
	end
	return nil
end

return NotifyPlan
