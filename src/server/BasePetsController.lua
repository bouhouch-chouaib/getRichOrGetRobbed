--!strict
-- BasePetsController : indique quels familiers vivent dans chaque base.
-- Ce sont les Config.Pets.IncomeSlots meilleurs familiers du propriétaire (ceux qui rapportent de l'argent,
-- EconomyController.GetTopPets). Écrit l'attribut "BasePets" ("id1,id2,...") sur la base ; chaque client
-- les fait se balader librement dans la base (client/BasePets).

local BaseManager = require(script.Parent.BaseManager)
local EconomyController = require(script.Parent.EconomyController)

local BasePetsController = {}

function BasePetsController.Init(bases: { Model })
	task.spawn(function()
		while true do
			for _, base in ipairs(bases) do
				local owner = BaseManager.GetOwner(base)
				local value = if owner then table.concat(EconomyController.GetTopPets(owner), ",") else ""
				if base:GetAttribute("BasePets") ~= value then
					base:SetAttribute("BasePets", value)
				end
			end
			task.wait(1)
		end
	end)
end

return BasePetsController
