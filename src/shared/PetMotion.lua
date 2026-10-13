--!strict
-- PetMotion : prépare les articulations décrites par PetSculpt.motionSince (ailes, queues).
-- Les pièces gardent leur groupe ; le pivot est converti dans le repère du Root après le centrage du modèle
-- (attribut MotionPivot, en studs non mis à l'échelle). Aucune animation n'est lancée ici.
local Catalog = require(script.Parent.PetCatalog)

local PetMotion = {}

function PetMotion.Prepare(m: Model, _e: Catalog.Pet, kind: string, center: Vector3)
	m:SetAttribute("MotionFamily", kind)
	for _, q in ipairs(m:GetChildren()) do
		if q:IsA("BasePart") then
			local raw = q:GetAttribute("MotionPivotRaw")
			if typeof(raw) == "CFrame" then
				q:SetAttribute("MotionPivot", CFrame.new(-center) * raw)
				q:SetAttribute("MotionPivotRaw", nil)
			end
		end
	end
end

return PetMotion
