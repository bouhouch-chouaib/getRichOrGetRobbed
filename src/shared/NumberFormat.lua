--!strict
-- NumberFormat : affichage des grands nombres façon simulateur Roblox.
--   NumberFormat.short(1234567)  -> "1.23M"
--   NumberFormat.money(2.5e12)   -> "$2.50T"
--   NumberFormat.perSecond(42)   -> "+$42/s"

local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function NumberFormat.short(value: number): string
	if value ~= value or value == math.huge then
		return "∞"
	end
	local negative = value < 0
	local n = math.abs(value)
	local text: string
	if n < 1000 then
		text = if n < 10 and n % 1 ~= 0 then string.format("%.1f", n) else tostring(math.floor(n))
	else
		local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
		local scaled = n / 10 ^ (tier * 3)
		local digits = if scaled < 10 then "%.2f" elseif scaled < 100 then "%.1f" else "%.0f"
		text = string.format(digits, math.floor(scaled * 100) / 100) .. SUFFIXES[tier + 1]
	end
	return (if negative then "-" else "") .. text
end

function NumberFormat.money(value: number): string
	return "$" .. NumberFormat.short(value)
end

function NumberFormat.perSecond(value: number): string
	return "+$" .. NumberFormat.short(value) .. "/s"
end

return NumberFormat
