--!strict
-- PetRoster : quels familiers vont dans la base (et rapportent), Config.GetIncomeSlots places.
--   1. ceux que le joueur a PLACÉS lui-même (bouton « Mettre dans la base » de l'Index), dans l'ordre de ses choix ;
--   2. puis une place par espèce/forme, par revenu décroissant (dix doublons ne masquent pas une nouveauté) ;
--   3. puis les doublons.
-- Ceux que le joueur a RETIRÉS (« Retirer de la base ») ne sont jamais ajoutés automatiquement. Les autres restent
-- « en réserve » : possédés (Index, fusion, échanges, sacrifice) mais pas dans la base, ils ne rapportent pas.
local PetRoster = {}

function PetRoster.Select(
	owned: { [string]: number },
	slots: number,
	income: (string) -> number,
	placed: { string }?,
	removed: { [string]: boolean }?
): { string }
	local result: { string } = {}
	local used: { [string]: number } = {}
	local function take(id: string): boolean
		if #result >= slots then
			return false
		end
		if (used[id] or 0) >= (owned[id] or 0) then
			return false
		end
		used[id] = (used[id] or 0) + 1
		table.insert(result, id)
		return true
	end
	for _, id in ipairs(placed or {}) do
		take(id)
	end
	local species = {}
	for id, count in pairs(owned) do
		if count > 0 and not (removed and removed[id]) then
			table.insert(species, id)
		end
	end
	table.sort(species, function(a, b)
		local av, bv = income(a), income(b)
		return if av == bv then a < b else av > bv
	end)
	for _, id in ipairs(species) do
		if (used[id] or 0) == 0 then
			take(id)
		end
	end
	for _, id in ipairs(species) do
		while #result < slots and take(id) do
		end
	end
	return result
end

return PetRoster
