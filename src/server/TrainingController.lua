--!strict
-- TrainingController : tapis de course (déblocable en boutique, Id "Treadmill").
-- Le tapis est posé à l'extérieur de chaque base par MapGenerator mais reste caché tant que
-- le propriétaire de la base ne l'a pas acheté. Pendant la Digestion, le tapis roule (il
-- repousse le joueur) et chaque seconde passée dessus augmente la statistique Speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseManager = require(script.Parent.BaseManager)
local GameLoopManager = require(script.Parent.GameLoopManager)
local SessionData = require(script.Parent.SessionData)

local TrainingController = {}

local TICK = 0.25
local UNLOCK_ID = "Treadmill"

local bases: { Model } = {}

local function getTreadmill(base: Model): (Model?, BasePart?)
	local model = base:FindFirstChild("Treadmill")
	local belt = model and model:FindFirstChild("TreadmillZone")
	if model and model:IsA("Model") and belt and belt:IsA("BasePart") then
		return model, belt
	end
	return nil, nil
end

local function isUnlocked(base: Model): boolean
	local owner = BaseManager.GetOwner(base)
	return owner ~= nil and SessionData.HasUnlock(owner, UNLOCK_ID)
end

local function setVisible(model: Model, visible: boolean)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = if visible then 0 else 1
			part.CanCollide = visible
			part.CanQuery = visible
		end
	end
end

local function isOnTreadmill(root: BasePart, belt: BasePart): boolean
	local localPosition = belt.CFrame:PointToObjectSpace(root.Position)
	local half = belt.Size / 2
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y > 0 and localPosition.Y < 6
end

-- Met à jour l'affichage et la vitesse de chaque tapis selon l'achat et la phase.
local function refreshTreadmills()
	local digesting = GameLoopManager.GetState() == "Digesting"
	for _, base in ipairs(bases) do
		local model, belt = getTreadmill(base)
		if model and belt then
			local unlocked = isUnlocked(base)
			if (belt.Transparency == 0) ~= unlocked then
				setVisible(model, unlocked)
			end
			-- Un tapis ancré avec une AssemblyLinearVelocity agit comme un convoyeur (vers l'arrière de la base).
			local running = unlocked and digesting
			belt.AssemblyLinearVelocity = if running then belt.CFrame.LookVector * -Config.Speed.BeltSpeed else Vector3.zero
		end
	end
end

function TrainingController.Init(generatedBases: { Model })
	bases = generatedBases

	task.spawn(function()
		while true do
			task.wait(TICK)
			refreshTreadmills()
			if GameLoopManager.GetState() == "Digesting" then
				for _, player in ipairs(Players:GetPlayers()) do
					local base = BaseManager.GetBase(player)
					local _, belt = if base then getTreadmill(base) else nil, nil
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if base and belt and isUnlocked(base) and root and root:IsA("BasePart") and isOnTreadmill(root, belt) then
						SessionData.AddSpeed(player, Config.Speed.GainPerSecond * TICK)
					end
				end
			end
		end
	end)
end

return TrainingController
