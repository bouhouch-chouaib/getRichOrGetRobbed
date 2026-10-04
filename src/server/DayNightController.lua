--!strict
-- DayNightController : nuit pendant le Feeding, jour pendant la Digestion.
-- L'heure avance toujours vers l'avant (coucher puis lever du soleil) sur TRANSITION secondes.
-- Les propriétés de Lighting modifiées par le serveur sont répliquées à tous les clients.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local GameLoopManager = require(script.Parent.GameLoopManager)

local DayNightController = {}

local TRANSITION = 4

type Preset = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
}

local PRESETS: { [string]: Preset } = {
	Feeding = { -- nuit
		ClockTime = 0,
		Brightness = 1,
		Ambient = Color3.fromRGB(70, 75, 110),
		OutdoorAmbient = Color3.fromRGB(95, 100, 140),
	},
	Digesting = { -- jour
		ClockTime = 14,
		Brightness = 2.5,
		Ambient = Color3.fromRGB(120, 120, 120),
		OutdoorAmbient = Color3.fromRGB(140, 140, 140),
	},
}

local transitionId = 0

local function apply(preset: Preset)
	transitionId += 1
	local id = transitionId

	local startTime = Lighting.ClockTime
	-- Écart toujours positif : on fait avancer l'horloge, jamais reculer.
	local delta = (preset.ClockTime - startTime) % 24
	local startBrightness = Lighting.Brightness
	local startAmbient = Lighting.Ambient
	local startOutdoor = Lighting.OutdoorAmbient
	local elapsed = 0

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		if id ~= transitionId then
			connection:Disconnect()
			return
		end
		elapsed = math.min(elapsed + dt, TRANSITION)
		local alpha = elapsed / TRANSITION
		Lighting.ClockTime = (startTime + delta * alpha) % 24
		Lighting.Brightness = startBrightness + (preset.Brightness - startBrightness) * alpha
		Lighting.Ambient = startAmbient:Lerp(preset.Ambient, alpha)
		Lighting.OutdoorAmbient = startOutdoor:Lerp(preset.OutdoorAmbient, alpha)
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

function DayNightController.Init()
	-- Démarrage directement de nuit (la partie commence en Feeding).
	local night = PRESETS.Feeding
	Lighting.ClockTime = night.ClockTime
	Lighting.Brightness = night.Brightness
	Lighting.Ambient = night.Ambient
	Lighting.OutdoorAmbient = night.OutdoorAmbient

	GameLoopManager.ServerEvent.Event:Connect(function(eventName: string, state: string)
		local preset = PRESETS[state]
		if eventName == "StateChanged" and preset then
			apply(preset)
		end
	end)
end

return DayNightController
