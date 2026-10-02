--!strict
-- GameLoopManager : machine à états du temps global (Feeding <-> Digesting).
-- Côté serveur uniquement. Les autres modules serveur écoutent ServerEvent.
-- Les clients lisent les attributs "GameState" / "TimeRemaining" de ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

export type State = "Feeding" | "Digesting"

local GameLoopManager = {}

local durations = if RunService:IsStudio() and Config.UseStudioDurations
	then Config.StudioDurations
	else Config.Durations

-- Événement serveur : ("StateChanged", state, timeRemaining) puis ("Tick", state, timeRemaining) chaque seconde.
local ServerEvent = Instance.new("BindableEvent")
ServerEvent.Name = "GameLoopServerEvent"
GameLoopManager.ServerEvent = ServerEvent

local currentState: State? = nil
local timeRemaining = 0
local loopThread: thread? = nil

function GameLoopManager.GetState(): State?
	return currentState
end

function GameLoopManager.GetTimeRemaining(): number
	return timeRemaining
end

local function publish()
	ReplicatedStorage:SetAttribute("GameState", currentState)
	ReplicatedStorage:SetAttribute("TimeRemaining", timeRemaining)
end

local function setState(newState: State)
	currentState = newState
	timeRemaining = durations[newState]
	publish()
	ServerEvent:Fire("StateChanged", newState, timeRemaining)
end

function GameLoopManager.Start()
	if loopThread then
		return
	end

	setState("Feeding")

	loopThread = task.spawn(function()
		while true do
			task.wait(1)
			timeRemaining -= 1
			if timeRemaining <= 0 then
				setState(if currentState == "Feeding" then "Digesting" else "Feeding")
			else
				publish()
				ServerEvent:Fire("Tick", currentState, timeRemaining)
			end
		end
	end)
end

function GameLoopManager.Stop()
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
end

return GameLoopManager
