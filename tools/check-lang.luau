-- Jeu en anglais (shared/Lang, shared/LangEn) : exemples de traduction, traduction stable (un texte déjà traduit ne
-- bouge plus) et textes du jeu qui n'ont pas encore leur anglais.
--   lune run tools/check-lang.luau .
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
local Lang, entries = load("Lang"), load("LangEn")
local t = Lang.translate

local function same(got, want)
	assert(got == want, string.format("%q donne %q au lieu de %q", tostring(got), tostring(got), want))
end

-- 1. Exemples
same(t("PRENDRE !"), "CLAIM!")
same(t("  PRENDRE !  "), "  CLAIM!  ")
same(t("Renard Furtif"), "Sneaky Fox")
same(t("RENARD FURTIF"), "SNEAKY FOX")
same(t("Bob A VOLÉ RENARD FURTIF À Alice !"), "Bob STOLE SNEAKY FOX FROM Alice!")
same(t("ŒUF " .. string.upper("Légendaire")), "LEGENDARY EGG")
same(t("ŒUF LÉGENDAIRE"), "LEGENDARY EGG")
same(t("Chien-Saucisse Ultime Doré"), "Golden Ultimate Sausage Dog")
same(t("Griffon Doré"), "Golden Griffin")
same(t("3 ŒUFS  •  <font color=\"#FFD23C\">2 NOUVEAUX !</font>  •  1 DÉJÀ EU"),
	"3 EGGS  •  <font color=\"#FFD23C\">2 NEW!</font>  •  1 ALREADY OWNED")
same(t("PRÊT DANS 1:05"), "READY IN 1:05")
same(t("PENDANT QUE TU N'ÉTAIS PAS LÀ : 3 ŒUFS ONT ÉCLOS  •  TA CAPSULE A FAIT 2 ESSAIS"),
	"WHILE YOU WERE AWAY: 3 EGGS HATCHED  •  YOUR CAPSULE MADE 2 TRIES")
same(t("+5 % PLUS VITE"), "+5% FASTER")
same(t("Aucun aimant  »  Portée 7 studs"), "No magnet  »  Range 7 studs")
same(t("Inconnu du dictionnaire"), "Inconnu du dictionnaire")
same(t("12 345"), "12 345")

-- 2. Une traduction ne bouge plus si on la retraduit (le jeu relit parfois un texte affiché et lui ajoute un morceau).
local unstable = {}
for _, entry in entries do
	local english = string.gsub(entry[2], "{%d+}", "X")
	english = string.gsub(english, "%%[%-%d%.]*[sdfx]", "X")
	if t(english) ~= english then
		table.insert(unstable, string.format("%q -> %q", english, t(english)))
	end
end
assert(#unstable == 0, "traductions qui changent encore :\n" .. table.concat(unstable, "\n"))

-- 3. Textes du jeu sans anglais : chaînes françaises (accents ou mots en MAJUSCULES) hors journaux de débogage.
-- Un morceau de phrase collé par le code (« PRÊT DANS " .. temps) compte s'il fait partie d'un modèle de LangEn.
local ignored = {
	["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true, ["Left Arm"] = true,
	["Studio access to APIs is not allowed"] = true, ["API access is not enabled"] = true,
	["#FFD23C"] = true, ["#9BDCFF"] = true,
	-- motifs anti-triche et journaux du serveur (jamais affichés)
	["jamais lancé"] = true, ["lancé par un autre joueur"] = true, ["lancers trop rapprochés"] = true,
	["lancé il y a trop longtemps"] = true, ["trop loin (%.0f studs pour une portée max de %.0f)"] = true,
	["arrivé trop vite (%.2f s pour %.0f studs, minimum %.2f s)"] = true, [" (le jeu doit être publié)."] = true,
}
local templates = {}
for _, entry in entries do
	table.insert(templates, entry[1])
end
local allTemplates = table.concat(templates, "\0")
local function sample(text)
	local filled = string.gsub(text, "(%u)%%s", "%1S")
	filled = string.gsub(filled, "%%[%-%d%.]*s", "Bob")
	filled = string.gsub(filled, "%%[%-%d%.]*[dfx]", "3")
	return (string.gsub(filled, "%%%%", "%%"))
end
local missing = {}
local seen = {}
for _, folder in { "client", "server", "shared" } do
	for _, file in fs.readDir(project .. "/src/" .. folder) do
		-- PetCatalog : seuls les noms s'affichent (les descriptions servent à fabriquer les modèles).
		if string.sub(file, -4) == ".lua" and file ~= "LangEn.lua" and file ~= "Lang.lua" and file ~= "PetCatalog.lua" then
			for line in string.gmatch(fs.readFile(project .. "/src/" .. folder .. "/" .. file), "[^\n]+") do
				local code = string.gsub(line, "%-%-.*$", "")
				local debug = string.find(code, "warn%(") or string.find(code, "print%(") or string.find(code, "error%(")
					or string.find(code, "assert%(")
				if not debug then
					for text in string.gmatch(code, "\"([^\"]*)\"") do
						local french = string.find(text, "[\128-\255]") or string.find(text, "%u%u%u")
						local plain = string.gsub(text, "\\n", "\n")
						plain = string.gsub(plain, "\\u{(%x+)}", function(hex)
							return utf8.char(tonumber(hex, 16))
						end)
						if french and string.find(text, "%a%a") and not ignored[text] and not seen[text]
							and not string.find(text, "^%[") and not string.find(text, "^[%w_]+$") and not string.find(text, "^%^")
							and not string.find(text, "rbx") then
							seen[text] = true
							local core = string.match(plain, "^[%s•]*(.-)%s*$")
							local filled = sample(plain)
							local covered = t(filled) ~= filled or string.find(allTemplates, core, 1, true) ~= nil
							if not covered then
								table.insert(missing, folder .. "/" .. file .. " : " .. text)
							end
						end
					end
				end
			end
		end
	end
end
if #missing > 0 then
	print(#missing .. " texte(s) sans anglais :\n" .. table.concat(missing, "\n"))
end
assert(#missing == 0, "ajouter ces textes à shared/LangEn")
print("check-lang PASS")
