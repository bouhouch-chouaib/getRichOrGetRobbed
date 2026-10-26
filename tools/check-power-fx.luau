-- Test hors Studio de la traînée (Vitesse) et de l'aura (Force) d'entraînement (shared/PowerFx, Config.PowerFx) :
-- paliers rangés et atteignables, bon palier pour un niveau, règles d'affichage, et ce que construit chaque palier
-- sur un personnage R15 fabriqué pour le test.
--
--   lune run tools/check-power-fx.luau .
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local process = require("@lune/process")
local project = process.args[1] or "."

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
	env.game = { GetService = function() return {} end }
	cache[name] = luau.load(fs.readFile(project .. "/src/shared/" .. name .. ".lua"), { environment = env })()
	return cache[name]
end
local Config = load("Config")
local PowerFx = load("PowerFx")
local C = Config.PowerFx
local Instance, Vector3 = r.Instance, r.Vector3
-- Méthodes de Studio absentes de Lune : sans effet ici (on vérifie les réglages, pas le rendu).
for _, class in ipairs({ "ParticleEmitter", "Trail" }) do
	r.implementMethod(class, "Clear", function() end)
end
r.implementMethod("ParticleEmitter", "Emit", function() end)

-- Paliers : 6 par stat, niveaux qui montent, noms présents.
for _, tiers in ipairs({ C.Speed, C.Strength }) do
	assert(#tiers == 6, "6 paliers attendus")
	for i, tier in ipairs(tiers) do
		assert(#tier.Name > 0, "palier sans nom")
		assert(i == 1 or tier.Level > tiers[i - 1].Level, "niveaux pas rangés : " .. tier.Name)
	end
end
-- Atteignables : l'avant-dernier par l'entraînement seul, le dernier avec les familiers (+MaxLevels).
local maxTrained = Config.Training.Speed.MaxLevel
local maxWithPets = maxTrained + Config.Pets.EquipBonus.MaxLevels
assert(C.Speed[5].Level <= maxTrained and C.Strength[5].Level <= maxTrained, "palier 5 hors de portée sans familier")
assert(C.Speed[6].Level <= maxWithPets and C.Strength[6].Level <= maxWithPets, "dernier palier hors de portée")
assert(C.Speed[6].Level > maxTrained, "le dernier palier doit demander des familiers")

-- Palier d'un niveau.
for level, expected in pairs({ [0] = 0, [9] = 0, [10] = 1, [19] = 1, [20] = 2, [30] = 3, [44] = 3, [45] = 4, [60] = 5, [75] = 6, [90] = 6 }) do
	assert(PowerFx.SpeedTier(level) == expected, ("Vitesse niveau %d : palier %d attendu, %d obtenu"):format(level, expected, PowerFx.SpeedTier(level)))
	assert(PowerFx.StrengthTier(level) == expected, ("Force niveau %d : palier %d attendu"):format(level, expected))
end

-- Affichage : vivant, pas invisible, assez près, pas à la 1re personne.
assert(PowerFx.CanShow(100, 0, 50, 30, false), "joueur normal : visible")
assert(not PowerFx.CanShow(0, 0, 50, 30, false), "mort : caché")
assert(not PowerFx.CanShow(100, 60, 50, 30, false), "invisible jusqu'à 60 : caché à 50")
assert(PowerFx.CanShow(100, 40, 50, 30, false), "invisibilité finie : visible")
assert(not PowerFx.CanShow(100, 0, 50, C.ViewDistance + 1, false), "trop loin : caché")
assert(not PowerFx.CanShow(100, 0, 50, 5, true), "1re personne : caché")
assert(PowerFx.IsRunning(C.RunSpeed, false) and not PowerFx.IsRunning(C.RunSpeed - 1, false), "seuil de course")
assert(not PowerFx.IsRunning(40, true), "assis : pas de traînée")

-- Personnage R15 minimal.
local function character(): any
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Parent = model
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = Instance.new("Part")
		foot.Name = name
		foot.Size = Vector3.new(0.8, 0.4, 1)
		foot.Parent = model
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = r.Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	return model
end

local function count(rig: any)
	return #rig.trails, #rig.runEmitters + #rig.auraEmitters
end

-- Palier 1 partout : 2 rubans aux pieds, flammes seules.
local low = PowerFx.Create(character(), 1, 1, 1)
local trails, emitters = count(low)
assert(trails == 2 and emitters == 1, ("paliers 1 : 2 rubans + 1 émetteur attendus, %d + %d"):format(trails, emitters))
-- Derniers paliers : + ruban du corps, traits, étincelles, sol, braises, rayons ; arc-en-ciel.
local high = PowerFx.Create(character(), 6, 6, 1)
trails, emitters = count(high)
assert(trails == 3 and emitters == 6, ("paliers 6 : 3 rubans + 6 émetteurs attendus, %d + %d"):format(trails, emitters))
assert(high.rainbow, "palier 6 de Vitesse : arc-en-ciel")
-- Vitesse seule : pas de flammes ; Force seule : pas de ruban.
local speedOnly = PowerFx.Create(character(), 3, 0, 1)
assert(#speedOnly.auraEmitters == 0 and #speedOnly.trails == 3, "Vitesse seule : rubans, pas d'aura")
local strengthOnly = PowerFx.Create(character(), 0, 4, 1)
assert(#strengthOnly.trails == 0 and #strengthOnly.auraEmitters == 3, "Force 4 : flammes + sol + braises, sans ruban")
-- Moins de particules sur téléphone.
local touch = PowerFx.Create(character(), 6, 6, C.TouchRateScale)
assert(math.abs(touch.auraEmitters[1].Rate - C.Strength[6].Wisps * C.TouchRateScale) < 1e-6, "débit réduit sur écran tactile")

-- Mise à jour : tout éteint au départ, rubans seulement en courant, tout caché si invisible.
PowerFx.Update(high, 0, true, false)
assert(high.auraEmitters[1].Enabled and not high.trails[1].Enabled, "à l'arrêt : aura oui, traînée non")
PowerFx.Update(high, 0.05, true, true)
assert(high.trails[1].Enabled and high.runEmitters[1].Enabled, "en courant : traînée et traits")
PowerFx.Update(high, 0.1, false, true)
assert(not high.auraEmitters[1].Enabled and not high.trails[1].Enabled, "caché : plus rien")
PowerFx.Destroy(high)

print("check-power-fx : OK")
