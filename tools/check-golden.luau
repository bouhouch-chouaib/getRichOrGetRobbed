-- Trou noir doré (shared/GoldenHour) : actif les premières minutes de chaque heure UTC, points multipliés.
--   lune run tools/check-golden.luau .
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
local Config, Golden = load("Config"), load("GoldenHour")
local S = Config.GoldenHour
local hour = 1761742800 -- une heure pile (UTC)

local active, seconds = Golden.State(hour)
assert(active and seconds == S.Minutes * 60, "actif à l'heure pile")
active, seconds = Golden.State(hour + 90.5)
assert(active and math.abs(seconds - (S.Minutes * 60 - 90.5)) < 1e-6, "temps restant")
active, seconds = Golden.State(hour + S.Minutes * 60)
assert(not active and seconds == 3600 - S.Minutes * 60, "fini après Minutes")
active, seconds = Golden.State(hour + 3600 - 45)
assert(not active and seconds == 45, "45 s avant le suivant")
assert(Golden.Multiplier(hour + 10) == S.PointsMultiplier and Golden.Multiplier(hour + 1800) == 1, "multiplicateur")
assert(S.WarnSeconds < 3600 - S.Minutes * 60, "le compte à rebours ne chevauche pas le trou doré")
print("check-golden PASS")
