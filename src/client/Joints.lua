--!strict
-- Joints : articulations d'un personnage R15 qu'on anime par le code (propriété Transform, écrite dans
-- RunService.Stepped, juste après les animations de Roblox).
-- Les avatars récents n'ont plus de Motor6D mais des AnimationConstraint (nouveau squelette) : on accepte les deux.
--   local shoulder = Joints.get(character, "RightUpperArm", "RightShoulder")
--   if shoulder then shoulder.Transform = CFrame.Angles(math.rad(90), 0, 0) end

local Joints = {}

export type Joint = { Transform: CFrame }

function Joints.get(character: Model, partName: string, jointName: string): Joint?
	local part = character:FindFirstChild(partName)
	local joint = part and part:FindFirstChild(jointName)
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		return joint :: any
	end
	return nil
end

return Joints
