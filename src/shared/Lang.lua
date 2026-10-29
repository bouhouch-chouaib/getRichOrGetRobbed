--!strict
-- Lang : le jeu est écrit en français ; les joueurs dont Roblox n'est pas réglé en français le voient en anglais
-- (29 oct. 2026, docs/STRATEGIE_JOUEURS.md étape A1). client/Translate passe chaque texte affiché par Lang.translate.
--
-- Le dictionnaire (shared/LangEn) liste des paires { français, anglais } :
--   - texte fixe : "PRENDRE !" -> "CLAIM!" ; on retrouve aussi sa version en MAJUSCULES et ses espaces autour ;
--   - texte à trous : "%s A VOLÉ %s À %s !" -> "%s STOLE %s FROM %s!" ; chaque trou (%s, %d, %.1f...) est traduit à son
--     tour (noms de familiers, raretés...). Pour changer l'ordre, l'anglais peut écrire {1}, {2}... à la place de %s.
-- Un texte inconnu est coupé aux retours à la ligne, aux balises <font> et aux « • », puis ses morceaux connus sont
-- remplacés mot à mot (un nom de familier au milieu d'une phrase, par exemple). Ce qui reste inconnu reste en français.
-- Studio : workspace:SetAttribute("DebugLang", "en") AVANT Play pour voir le jeu en anglais (ou "fr").

local TextFormat = require(script.Parent.TextFormat)

local Lang = {}

type Piece = string | number -- texte fixe ou numéro du trou
-- separators : le modèle contient lui-même un retour à la ligne, une balise ou un « • » ; sinon il ne s'applique
-- qu'à un morceau sans séparateur (un trou ne doit pas avaler la suite d'un texte fait de plusieurs morceaux).
type Pattern = { pattern: string, parts: { Piece }, weight: number, separators: boolean }
type Fragment = { fr: string, en: string }

local exact: { [string]: string } = {}
local patterns: { Pattern } = {}
local fragments: { [string]: { Fragment } } = {} -- rangés par premier mot, du plus long au plus court
local built = false
local memo: { [string]: string } = {}
local memoSize = 0

local SPEC = "%%[%-%d%.]*[sdfx]"
local MAGIC = "([%^%$%(%)%.%[%]%*%+%-%?%%])"

local function isWordCode(code: number): boolean
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		or (code >= 0xC0 and code <= 0x24F and code ~= 0xD7 and code ~= 0xF7)
end

local function codeAt(text: string, index: number): number?
	if index > #text then
		return nil
	end
	local ok, code = pcall(utf8.codepoint, text, index)
	return if ok then code else nil
end

local function charLength(text: string, index: number): number
	local byte = string.byte(text, index) or 0
	return if byte >= 0xF0 then 4 elseif byte >= 0xE0 then 3 elseif byte >= 0xC0 then 2 else 1
end

local function startsWord(text: string, index: number): boolean
	local code = codeAt(text, index)
	return code ~= nil and isWordCode(code)
end

-- Fin (exclue) du mot qui commence à index ; garde ensemble « L'ŒUF », « ARC-EN-CIEL », « T’ATTEND ».
local function wordEnd(text: string, index: number): number
	local i = index
	while i <= #text do
		if startsWord(text, i) then
			i += charLength(text, i)
		else
			local code = codeAt(text, i)
			local joiner = code == 39 or code == 45 or code == 0x2019
			if joiner and startsWord(text, i + charLength(text, i)) and i > index then
				i += charLength(text, i)
			else
				break
			end
		end
	end
	return i
end

-- Après une mise en majuscules, « %S » redevient « %s » (et « %D » « %d »...).
local function lowerSpecs(text: string): string
	return (string.gsub(text, "%%[%-%d%.]*[SDFX]", string.lower))
end

local function upperKeepSpecs(text: string): string
	return lowerSpecs(TextFormat.upper(text))
end

-- Séparateurs entre les morceaux d'un texte composé : retour à la ligne, balise, « • », « · », « » », « → ».
local SEPARATORS = { "\n", "<", "\226\128\162", "\194\183", "\194\187", "\226\134\146" }

local function hasSeparator(text: string): boolean
	for _, separator in SEPARATORS do
		if string.find(text, separator, 1, true) then
			return true
		end
	end
	return false
end

local function compileEnglish(en: string): { Piece }
	local parts: { Piece } = {}
	local hole = 0
	local i = 1
	while i <= #en do
		local s, e = string.find(en, "%%[%-%d%.]*[sdfx]", i)
		local b1, b2, number = string.find(en, "{(%d+)}", i)
		local percent = string.find(en, "%%%%", i)
		local first = math.min(s or math.huge, b1 or math.huge, percent or math.huge)
		if first == math.huge then
			table.insert(parts, string.sub(en, i))
			break
		end
		if first > i then
			table.insert(parts, string.sub(en, i, first - 1))
		end
		if first == percent and first ~= s then
			table.insert(parts, "%")
			i = first + 2
		elseif first == s then
			hole += 1
			table.insert(parts, hole)
			i = (e :: number) + 1
		else
			table.insert(parts, tonumber(number) :: number)
			i = (b2 :: number) + 1
		end
	end
	return parts
end

local function addPattern(fr: string, en: string)
	local body = ""
	local literal = 0
	local i = 1
	while i <= #fr do
		local s, e = string.find(fr, SPEC, i)
		local percent = string.find(fr, "%%%%", i)
		local first = math.min(s or math.huge, percent or math.huge)
		local stop = if first == math.huge then #fr + 1 else first
		local chunk = string.sub(fr, i, stop - 1)
		literal += #chunk
		body ..= string.gsub(chunk, MAGIC, "%%%1")
		if first == math.huge then
			break
		elseif first == percent and first ~= s then
			body ..= "%%"
			literal += 1
			i = first + 2
		else
			-- « ŒUF%s » : un trou collé à un mot en majuscules est une marque du pluriel (S, X ou rien).
			local before = string.byte(fr, first - 1) or 0
			local suffix = string.sub(fr, first, e :: number) == "%s" and ((before >= 65 and before <= 90) or before >= 0x80)
			body ..= if suffix then "(%u*)" else "(.-)"
			i = (e :: number) + 1
		end
	end
	table.insert(patterns, {
		pattern = "^" .. body .. "$",
		parts = compileEnglish(en),
		weight = literal,
		separators = hasSeparator(fr),
	})
end

local function addFragment(fr: string, en: string)
	if #fr < 2 or not startsWord(fr, 1) then
		return
	end
	local key = string.sub(fr, 1, wordEnd(fr, 1) - 1)
	local list = fragments[key]
	if not list then
		list = {}
		fragments[key] = list
	end
	for _, fragment in list do
		if fragment.fr == fr then
			return
		end
	end
	table.insert(list, { fr = fr, en = en })
end

local function addEntry(fr: string, en: string, exactOnly: boolean?)
	local core = string.match(fr, "^%s*(.-)%s*$") or fr
	local coreEn = string.match(en, "^%s*(.-)%s*$") or en
	if core == "" then
		return
	end
	if string.find(core, SPEC) then
		addPattern(core, coreEn)
	else
		core = string.gsub(core, "%%%%", "%%")
		coreEn = string.gsub(coreEn, "%%%%", "%%")
		if exact[core] == nil then
			exact[core] = coreEn
		end
		if not exactOnly then
			addFragment(core, coreEn)
		end
	end
end

local function build()
	if built then
		return
	end
	built = true
	local entries = require(script.Parent.LangEn) :: { { any } }
	for _, entry in entries do
		addEntry(entry[1], entry[2], entry[3])
	end
	-- Les mêmes en MAJUSCULES : avec les accents (TextFormat.upper) et sans (string.upper laisse « é »).
	for _, entry in entries do
		local fr, en = entry[1] :: string, entry[2] :: string
		for _, variant in { upperKeepSpecs(fr), lowerSpecs(string.upper(fr)) } do
			if variant ~= fr then
				addEntry(variant, upperKeepSpecs(en), entry[3])
			end
		end
	end
	table.sort(patterns, function(a: Pattern, b: Pattern): boolean
		return a.weight > b.weight
	end)
	for _, list in fragments do
		table.sort(list, function(a: Fragment, b: Fragment): boolean
			return #a.fr > #b.fr
		end)
	end
end

local translate: (string) -> string

local function whole(text: string): string?
	local lead, core, trail = string.match(text, "^(%s*)(.-)(%s*)$")
	if not core or core == "" then
		return nil
	end
	local found = exact[core]
	if found then
		return (lead :: string) .. found .. (trail :: string)
	end
	local split = hasSeparator(core)
	for _, entry in patterns do
		local captures = if split and not entry.separators then {} else { string.match(core, entry.pattern) }
		if captures[1] ~= nil then
			local out = table.create(#entry.parts)
			for _, part in entry.parts do
				if type(part) == "number" then
					local value = captures[part]
					table.insert(out, if value then translate(value) else "")
				else
					table.insert(out, part)
				end
			end
			return (lead :: string) .. table.concat(out) .. (trail :: string)
		end
	end
	return nil
end

-- Coupe le texte en morceaux (séparateurs gardés tels quels) et traduit chaque morceau.
local function splitBy(text: string, separator: string): string?
	local out = {}
	local i = 1
	local cut = false
	while true do
		local s, e = string.find(text, separator, i)
		if not s then
			break
		end
		if s > i then
			table.insert(out, translate(string.sub(text, i, s - 1)))
		end
		table.insert(out, string.sub(text, s, e))
		i = (e :: number) + 1
		cut = true
	end
	if not cut then
		return nil
	end
	if i <= #text then
		table.insert(out, translate(string.sub(text, i)))
	end
	return table.concat(out)
end

local function replaceFragments(text: string): string
	if utf8.len(text) == nil then
		return text
	end
	local out = {}
	local i = 1
	local previousWord = false
	while i <= #text do
		local word = startsWord(text, i)
		if word and not previousWord then
			local stop = wordEnd(text, i)
			local matched = false
			local list = fragments[string.sub(text, i, stop - 1)]
			if list then
				for _, fragment in list do
					local after = i + #fragment.fr
					if string.sub(text, i, after - 1) == fragment.fr and not startsWord(text, after) then
						table.insert(out, fragment.en)
						i = after
						matched = true
						break
					end
				end
			end
			if not matched then
				table.insert(out, string.sub(text, i, stop - 1))
				i = stop
			end
			previousWord = false
		else
			local length = charLength(text, i)
			table.insert(out, string.sub(text, i, i + length - 1))
			i += length
			previousWord = word
		end
	end
	return table.concat(out)
end

translate = function(text: string): string
	if text == "" or not string.find(text, "[%a\128-\255]") then
		return text
	end
	local cached = memo[text]
	if cached then
		return cached
	end
	build()
	local result = whole(text)
		or (if string.find(text, "\n", 1, true) then splitBy(text, "\n") else nil)
		or (if string.find(text, "<", 1, true) then splitBy(text, "<[^>]*>") else nil)
		or splitBy(text, "%s*\226\128\162%s*") -- •
		or splitBy(text, "%s*\194\183%s*") -- ·
		or splitBy(text, "%s*\194\187%s*") -- » (niveau actuel » niveau suivant)
		or splitBy(text, "%s*\226\134\146%s*") -- →
		or replaceFragments(text)
	if memoSize > 4000 then
		table.clear(memo)
		memoSize = 0
	end
	memo[text] = result
	memoSize += 1
	return result
end

Lang.translate = translate

-- Vrai si le joueur voit le jeu en français (Roblox réglé en français) ; sinon le jeu s'affiche en anglais.
function Lang.isFrench(): boolean
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("DebugLang")
		if forced == "en" or forced == "fr" then
			return forced == "fr"
		end
	end
	local locale = game:GetService("LocalizationService").RobloxLocaleId
	return string.sub(string.lower(locale), 1, 2) == "fr"
end

return Lang
