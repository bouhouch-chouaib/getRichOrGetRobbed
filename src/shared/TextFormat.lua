--!strict
-- TextFormat : mise en majuscules qui gère les accents (string.upper ne connaît que les lettres sans accent :
-- "Légendaire" donnait "LéGENDAIRE").

local TextFormat = {}

local ACCENTS = {
	["à"] = "À", ["â"] = "Â", ["ä"] = "Ä", ["ç"] = "Ç", ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ë"] = "Ë",
	["î"] = "Î", ["ï"] = "Ï", ["ô"] = "Ô", ["ö"] = "Ö", ["ù"] = "Ù", ["û"] = "Û", ["ü"] = "Ü", ["ÿ"] = "Ÿ",
	["œ"] = "Œ", ["æ"] = "Æ",
}

function TextFormat.upper(text: string): string
	local result = string.upper(text)
	for lower, upper in pairs(ACCENTS) do
		result = string.gsub(result, lower, upper)
	end
	return result
end

return TextFormat
