--!strict
-- BasePetsController : indique quels familiers vivent dans chaque base.
-- Ce sont les Config.Pets.IncomeSlots meilleurs familiers du propriétaire (ceux qui rapportent de l'argent,
-- EconomyController.GetTopPets). Écrit l'attribut "BasePets" ("id:quantité,id2:quantité,...") sur la base :
-- une seule créature par espèce (avec "x2" si plusieurs exemplaires). Chaque client les fait se balader
-- librement dans la base (client/BasePets).

local BaseManager = require(script.Parent.BaseManager)
local EconomyController = require(script.Parent.EconomyController)

local BasePetsController = {}

function BasePetsController.Init(bases: { Model })
	task.spawn(function()
		while true do
			for _, base in ipairs(bases) do
				local owner = BaseManager.GetOwner(base)
				local value = ""
				if owner then
					local counts: { [string]: number } = {}
					local order: { string } = {}
					for _, petId in ipairs(EconomyController.GetTopPets(owner)) do
						if not counts[petId] then
							table.insert(order, petId)
						end
						counts[petId] = (counts[petId] or 0) + 1
					end
					local parts = {}
					for _, petId in ipairs(order) do
						table.insert(parts, petId .. ":" .. counts[petId])
					end
					value = table.concat(parts, ",")
				end
				if base:GetAttribute("BasePets") ~= value then
					base:SetAttribute("BasePets", value)
				end
			end
			task.wait(1)
		end
	end)
end

return BasePetsController
