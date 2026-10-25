--!strict
-- DayNightController : nuit pendant le Feeding, jour pendant la Digestion.
-- L'heure avance toujours vers l'avant (coucher puis lever du soleil) sur TRANSITION secondes.
-- Les propriétés de Lighting modifiées par le serveur sont répliquées à tous les clients.
-- Valeurs : préréglages « jour » / « nuit » de shared/Worlds (Worlds.DayNight). En plus de la lumière, on fait varier le
-- bloom, le contraste, Glare et Haze de l'air ; la couleur de l'air et la saturation restent à client/WorldSkin (elles
-- dépendent du monde du joueur), qui remplace aussi une partie de la lumière par le ciel du monde (Worlds.Looks.*.Sky)
-- en suivant l'attribut Lighting.DayAmount (0 nuit -> 1 jour) publié ici.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Worlds = require(ReplicatedStorage.Shared.Worlds)
local GameLoopManager = require(script.Parent.GameLoopManager)

local DayNightController = {}

local TRANSITION = 4

type Preset = Worlds.DayNight

local PRESETS: { [string]: Preset } = Worlds.DayNight

local transitionId = 0

-- Effets créés par MapGenerator (cherchés à chaque fois : ils peuvent être recréés).
local function effects(): (BloomEffect?, ColorCorrectionEffect?, Atmosphere?)
	return Lighting:FindFirstChildOfClass("BloomEffect"), Lighting:FindFirstChildOfClass("ColorCorrectionEffect"),
		Lighting:FindFirstChildOfClass("Atmosphere")
end

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
	local bloom, grading, air = effects()
	local startBloom = if bloom
		then { Intensity = bloom.Intensity, Size = bloom.Size, Threshold = bloom.Threshold }
		else preset.Bloom
	local startContrast = if grading then grading.Contrast else preset.Contrast
	local startGlare = if air then air.Glare else preset.Glare
	local startHaze = if air then air.Haze else preset.Haze
	local currentAmount = Lighting:GetAttribute("DayAmount")
	local startAmount = if type(currentAmount) == "number" then currentAmount else preset.DayAmount
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
		Lighting:SetAttribute("DayAmount", startAmount + (preset.DayAmount - startAmount) * alpha)
		Lighting.Brightness = startBrightness + (preset.Brightness - startBrightness) * alpha
		Lighting.Ambient = startAmbient:Lerp(preset.Ambient, alpha)
		Lighting.OutdoorAmbient = startOutdoor:Lerp(preset.OutdoorAmbient, alpha)
		Lighting.ExposureCompensation = startExposure + (preset.Exposure - startExposure) * alpha
		if clouds then
			clouds.Cover = startCover + (preset.CloudCover - startCover) * alpha
		end
		if bloom then
			bloom.Intensity = startBloom.Intensity + (preset.Bloom.Intensity - startBloom.Intensity) * alpha
			bloom.Size = startBloom.Size + (preset.Bloom.Size - startBloom.Size) * alpha
			bloom.Threshold = startBloom.Threshold + (preset.Bloom.Threshold - startBloom.Threshold) * alpha
		end
		if grading then
			grading.Contrast = startContrast + (preset.Contrast - startContrast) * alpha
		end
		if air then
			air.Glare = startGlare + (preset.Glare - startGlare) * alpha
			air.Haze = startHaze + (preset.Haze - startHaze) * alpha
		end
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

function DayNightController.Init()
	-- Démarrage directement de nuit (la partie commence en Feeding).
	local night = PRESETS.Feeding
	Lighting:SetAttribute("DayAmount", night.DayAmount)
	Lighting.ClockTime = night.ClockTime
	Lighting.Brightness = night.Brightness
	Lighting.Ambient = night.Ambient
	Lighting.OutdoorAmbient = night.OutdoorAmbient
	Lighting.ExposureCompensation = night.Exposure
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Cover = night.CloudCover
	end
	local bloom, grading, air = effects()
	if bloom then
		bloom.Intensity = night.Bloom.Intensity
		bloom.Size = night.Bloom.Size
		bloom.Threshold = night.Bloom.Threshold
	end
	if grading then
		grading.Contrast = night.Contrast
	end
	if air then
		air.Glare = night.Glare
		air.Haze = night.Haze
	end

	GameLoopManager.ServerEvent.Event:Connect(function(eventName: string, state: string)
		local preset = PRESETS[state]
		if eventName == "StateChanged" and preset then
			apply(preset)
		end
	end)
end

return DayNightController
