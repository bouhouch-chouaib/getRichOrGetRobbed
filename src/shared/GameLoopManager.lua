-- GameLoopManager : machine à états gérant le temps global du serveur.
-- États : Feeding (60s) et Digesting (120s).
-- Notifie les autres modules via un BindableEvent à chaque seconde et lors des changements d'état.

type GameLoopManagerModule = {
	ServerEvent: BindableEvent,
	GetState: (self: GameLoopManagerModule) -> string?,
	GetTimeRemaining: (self: GameLoopManagerModule) -> number,
	GetStateDuration: (self: GameLoopManagerModule, state: string) -> number?,
	Start: (self: GameLoopManagerModule) -> (),
	Stop: (self: GameLoopManagerModule) -> (),
}

local GameLoopManager: GameLoopManagerModule = {} :: GameLoopManagerModule

-- Durées des états (en secondes)
local STATE_DURATIONS: { [string]: number } = {
	Feeding = 60,
	Digesting = 120,
}

-- Ordre de transition des états
local STATE_ORDER: { string } = { "Feeding", "Digesting" }

-- Événement utilisé pour notifier les autres modules
local ServerEvent = Instance.new("BindableEvent")
ServerEvent.Name = "GameLoopServerEvent"
ServerEvent.Parent = script

-- État interne
local currentState: string? = nil
local timeRemaining: number = 0
local isRunning: boolean = false
local loopThread: thread? = nil

-- Expose l'événement pour que les autres modules puissent s'y connecter
GameLoopManager.ServerEvent = ServerEvent

-- Retourne l'état actuel
function GameLoopManager.GetState(): string?
	return currentState
end

-- Retourne le temps restant dans l'état actuel
function GameLoopManager.GetTimeRemaining(): number
	return timeRemaining
end

-- Retourne la durée totale d'un état
function GameLoopManager.GetStateDuration(state: string): number?
	return STATE_DURATIONS[state]
end

-- Retourne l'état suivant dans le cycle
local function getNextState(state: string): string
	for index, name in ipairs(STATE_ORDER) do
		if name == state then
			local nextIndex = (index % #STATE_ORDER) + 1
			return STATE_ORDER[nextIndex] or STATE_ORDER[1]
		end
	end
	return STATE_ORDER[1]
end

-- Change l'état courant et notifie les abonnés
local function setState(newState: string)
	currentState = newState
	timeRemaining = STATE_DURATIONS[newState] or 0

	ServerEvent:Fire("StateChanged", newState, timeRemaining)
end

-- Boucle principale du game loop
local function runLoop()
	while isRunning do
		-- Notifie chaque seconde du temps restant
		ServerEvent:Fire("Tick", currentState, timeRemaining)

		task.wait(1)

		if not isRunning then
			break
		end

		timeRemaining = timeRemaining - 1

		if timeRemaining <= 0 then
			local state = currentState
			if state then
				local nextState = getNextState(state)
				setState(nextState)
			end
		end
	end
end

-- Démarre le game loop (commence en Feeding)
function GameLoopManager.Start()
	if isRunning then
		return
	end

	isRunning = true
	setState(STATE_ORDER[1])

	loopThread = task.spawn(runLoop)
end

-- Arrête le game loop
function GameLoopManager.Stop()
	isRunning = false
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
end

return GameLoopManager
