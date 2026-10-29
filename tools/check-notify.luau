-- Notifications Roblox (shared/NotifyPlan) : quelle notification prévoir au départ d'un joueur, et à quelle heure.
--   lune run tools/check-notify.luau .
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local project = require("@lune/process").args[1] or "."
local cache = {}
local parent = setmetatable({}, { __index = function(_, key) return key end })
local load
load = function(name)
	if cache[name] then
		return cache[name]
	end
	local env = table.clone(r)
	env.script = { Parent = parent }
	env.require = load
	cache[name] = luau.load(fs.readFile(project .. "/src/shared/" .. name .. ".lua"), { environment = env })()
	return cache[name]
end
local Config, Plan = load("Config"), load("NotifyPlan")
local S = Config.Notifications
local DAY = 86400

local today = 20390 -- un jour UTC
local noon = today * DAY + 12 * 3600 -- départ à midi UTC
local claimedToday = { last = today, streak = 2 }

-- 1. Un œuf qui finit dans 30 min : « tes œufs sont prêts » à cette heure-là.
local plan = Plan.Plan({ { readyAt = noon + 1800 } }, claimedToday, noon)
assert(plan.kind == "EggReady" and plan.sendAt == noon + 1800, "œuf dans 30 min")
-- 2. Un œuf prêt dans 2 min : jamais avant MinAway.
plan = Plan.Plan({ { readyAt = noon + 120 }, { readyAt = noon + 5000 } }, claimedToday, noon)
assert(plan.kind == "EggReady" and plan.sendAt == noon + S.MinAway, "œuf presque prêt")
-- 3. Œuf trop lointain ou dans la capsule : le cadeau du jour, 22 h après, jour suivant de la série.
plan = Plan.Plan({ { readyAt = noon + S.EggWindow + 60 }, { readyAt = noon + 600, evolve = {} } }, claimedToday, noon)
assert(plan.kind == "Daily" and plan.sendAt == noon + S.DailyDelay and plan.params.day == "3", "cadeau du jour 3")
-- 4. Parti juste après minuit UTC : pas avant que le cadeau de demain soit réclamable.
local early = today * DAY + 1800
plan = Plan.Plan({}, claimedToday, early)
assert(plan.kind == "Daily" and plan.sendAt == (today + 1) * DAY + 3600, "attend le lendemain")
-- 5. Série cassée (dernier cadeau il y a 3 jours) : jour 1. Cadeau pas pris aujourd'hui : quand même 22 h après.
plan = Plan.Plan({}, { last = today - 3, streak = 5 }, noon)
assert(plan.kind == "Daily" and plan.params.day == "1" and plan.sendAt == noon + S.DailyDelay, "série cassée")
-- 6. Fin de série : après le jour 7, on revient au jour 1.
plan = Plan.Plan({}, { last = today, streak = #Config.Daily.Rewards }, noon)
assert(plan.params.day == "1", "après le jour 7")
-- 7. Rien d'activé tant qu'aucun texte n'est créé (sinon rien ne doit être prévu).
for _, ids in S.Strings do
	assert(type(ids.fr) == "string" and type(ids.en) == "string", "Strings : fr et en")
end
print("check-notify PASS")
