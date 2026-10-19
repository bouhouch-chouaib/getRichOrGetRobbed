--!strict
-- Réserver d'abord une place par espèce évite que dix doublons masquent toutes les nouveautés.
local PetRoster = {}
function PetRoster.Select(owned: { [string]: number }, slots: number, income: (string) -> number): { string }
	local species = {}
	for id, count in pairs(owned) do
		if count > 0 then
			table.insert(species, id)
		end
	end
	table.sort(species, function(a, b)
		local av, bv = income(a), income(b)
		return if av == bv then a < b else av > bv
	end)
	local result = {}
	for _, id in ipairs(species) do
		if #result >= slots then
			break
		end
		table.insert(result, id)
	end
	for _, id in ipairs(species) do
		for _ = 2, owned[id] do
			if #result >= slots then
				return result
			end
			table.insert(result, id)
		end
	end
	return result
end
return PetRoster
