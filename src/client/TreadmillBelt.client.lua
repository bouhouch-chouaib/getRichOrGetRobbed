--!strict
-- TreadmillBelt : fait défiler les flèches de la bande des tapis de course (Texture "BeltArrows" posée sur la Zone par
-- server/StationLooks, étiquette "TreadmillBelt", réglages Config.Training.BeltArrows). La bande recule vers l'arrière
-- (+Z, le dos du coureur), doucement à vide, vite quand quelqu'un court dessus (attribut "Training" = "Treadmill").

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local SETTINGS = Config.Training.BeltArrows
local DIRECTION = 1 -- sens de OffsetStudsV qui fait reculer la bande vers +Z (mesuré en jeu)

local belts: { [Texture]: boolean } = {}

local function add(instance: Instance)
	if instance:IsA("Texture") then
		belts[instance] = true
	end
end
CollectionService:GetInstanceAddedSignal("TreadmillBelt"):Connect(add)
CollectionService:GetInstanceRemovedSignal("TreadmillBelt"):Connect(function(instance: Instance)
	belts[instance :: Texture] = nil
end)
for _, instance in ipairs(CollectionService:GetTagged("TreadmillBelt")) do
	add(instance)
end

-- Quelqu'un court-il sur cette bande ?
local function occupied(zone: BasePart): boolean
	for _, other in ipairs(Players:GetPlayers()) do
		if other:GetAttribute("Training") == "Treadmill" then
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local offset = zone.CFrame:PointToObjectSpace(root.Position)
				if math.abs(offset.X) <= zone.Size.X / 2 + 1 and math.abs(offset.Z) <= zone.Size.Z / 2 + 1 then
					return true
				end
			end
		end
	end
	return false
end

RunService.RenderStepped:Connect(function(dt: number)
	for texture in pairs(belts) do
		local zone = texture.Parent
		if not texture.Parent or not zone or not zone:IsA("BasePart") then
			belts[texture] = nil
			continue
		end
		local speed = if occupied(zone) then SETTINGS.RunSpeed else SETTINGS.IdleSpeed
		texture.OffsetStudsV = (texture.OffsetStudsV + DIRECTION * speed * dt) % texture.StudsPerTileV
	end
end)
