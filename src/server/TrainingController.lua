--!strict
-- TrainingController : tapis de course de chaque base.
-- Pendant la Digestion, le tapis roule (il repousse le joueur) et chaque seconde passée
-- dessus augmente la statistique Speed du propriétaire de la base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseManager = require(script.Parent.BaseManager)
local GameLoopManager = require(script.Parent.GameLoopManager)
local SessionData = require(script.Parent.SessionData)

local TrainingController = {}

local TICK = 0.25

local bases: { Model } = {}

local function getTreadmill(base: Model): BasePart?
	local treadmill = base:FindFirstChild("TreadmillZone")
	if treadmill and treadmill:IsA("BasePart") then
		return treadmill
	end
	return nil
end

-- Un tapis ancré avec une vitesse "AssemblyLinearVelocity" agit comme un convoyeur.
local function setBelts(running: boolean)
	for _, base in ipairs(bases) do
		local treadmill = getTreadmill(base)
		if treadmill then
			-- +Z local = vers l'arrière de la base (dos au trou noir).
			local backward = treadmill.CFrame.LookVector * -1
			treadmill.AssemblyLinearVelocity = if running then backward * Config.Speed.BeltSpeed else Vector3.zero
		end
	end
end

local function isOnTreadmill(root: BasePart, treadmill: BasePart): boolean
	local localPosition = treadmill.CFrame:PointToObjectSpace(root.Position)
	local half = treadmill.Size / 2
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y > 0 and localPosition.Y < 6
end

function TrainingController.Init(generatedBases: { Model })
	bases = generatedBases

	GameLoopManager.ServerEvent.Event:Connect(function(eventName: string, state: string)
		if eventName == "StateChanged" then
			setBelts(state == "Digesting")
		end
	end)
	setBelts(GameLoopManager.GetState() == "Digesting")

	task.spawn(function()
		while true do
			task.wait(TICK)
			if GameLoopManager.GetState() == "Digesting" then
				for _, player in ipairs(Players:GetPlayers()) do
					local base = BaseManager.GetBase(player)
					local treadmill = base and getTreadmill(base)
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if treadmill and root and root:IsA("BasePart") and isOnTreadmill(root, treadmill) then
						SessionData.AddSpeed(player, Config.Speed.GainPerSecond * TICK)
					end
				end
			end
		end
	end)
end

return TrainingController
