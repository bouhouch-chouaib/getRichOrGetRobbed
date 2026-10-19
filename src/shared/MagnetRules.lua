--!strict
-- Sélection déterministe : points, puis volume, puis proximité. Les objets lancés sont exclus.
local MagnetRules = {}
function MagnetRules.Best(
	items: { BasePart },
	origin: Vector3,
	radius: number,
	isThrown: (BasePart) -> boolean
): BasePart?
	local best: BasePart? = nil
	local bestValue, bestVolume, bestDistance = -math.huge, -math.huge, math.huge
	for _, item in ipairs(items) do
		if item:GetAttribute("Holder") or item:GetAttribute("Consumed") or isThrown(item) then
			continue
		end
		local distance = (item.Position - origin).Magnitude
		if distance > radius then
			continue
		end
		local raw = item:GetAttribute("Value")
		local value = if type(raw) == "number" then raw else 1
		local volume = item.Size.X * item.Size.Y * item.Size.Z
		if
			value > bestValue
			or (value == bestValue and (volume > bestVolume or (volume == bestVolume and distance < bestDistance)))
		then
			best, bestValue, bestVolume, bestDistance = item, value, volume, distance
		end
	end
	return best
end
return MagnetRules
