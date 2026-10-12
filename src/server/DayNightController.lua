--!strict
-- DayNightController : nuit pendant le Feeding, jour pendant la Digestion.
-- L'heure avance toujours vers l'avant (coucher puis lever du soleil) sur TRANSITION secondes.
-- Les propriétés de Lighting modifiées par le serveur sont répliquées à tous les clients.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameLoopManager = require(script.Parent.GameLoopManager)

local DayNightController = {}

local TRANSITION = 4

type Preset = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Exposure: number,
	CloudCover: number, -- nuages du Terrain : moins la nuit, sinon ils sortent gris foncé
}

local PRESETS: { [string]: Preset } = {
	Feeding = { -- nuit : ciel bleu nuit étoilé (début de nuit, jamais noir), arène bien lisible
		ClockTime = 19.4,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(150, 155, 190),
		OutdoorAmbient = Color3.fromRGB(165, 170, 210),
		Exposure = 0.4,
		CloudCover = 0.12,
	},
	Digesting = { -- jour
		ClockTime = 14,
		Brightness = 2.5,
		Ambient = Color3.fromRGB(120, 120, 120),
		OutdoorAmbient = Color3.fromRGB(140, 140, 140),
		Exposure = 0,
		CloudCover = 0.55,
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
	local startExposure = Lighting.ExposureCompensation
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	local startCover = if clouds then clouds.Cover else preset.CloudCover
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
		Lighting.ExposureCompensation = startExposure + (preset.Exposure - startExposure) * alpha
		if clouds then
			clouds.Cover = startCover + (preset.CloudCover - startCover) * alpha
		end
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
	Lighting.ExposureCompensation = night.Exposure
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Cover = night.CloudCover
	end

	GameLoopManager.ServerEvent.Event:Connect(function(eventName: string, state: string)
		local preset = PRESETS[state]
		if eventName == "StateChanged" and preset then
			apply(preset)
		end
	end)
end

return DayNightController
