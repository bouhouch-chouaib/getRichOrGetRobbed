--!strict
-- Sounds : module de sons centralisé (côté client). Les Id et volumes sont dans Config.Sounds.
--   Sounds.play("Pickup")                      -> son "2D" (entendu seulement par ce joueur, partout)
--   Sounds.playAt("Consume", position)         -> son "3D" (entendu par ce joueur s'il est près de l'endroit)
--   Sounds.setMusic("Feeding" | "Digesting")  -> fondu vers la musique de la phase
-- Deux groupes de volume (SoundGroup) : Music et Effects.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local SOUNDS = Config.Sounds

local Sounds = {}

local function group(name: string, volume: number): SoundGroup
	local soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = name
	soundGroup.Volume = volume
	soundGroup.Parent = SoundService
	return soundGroup
end

local musicGroup = group("Music", SOUNDS.MusicVolume)
local effectsGroup = group("Effects", SOUNDS.EffectsVolume)

-- Sons d'effets "2D" préparés une fois (rejoués à chaque appel, plusieurs à la fois grâce à PlayOnRemove).
local templates: { [string]: Sound } = {}
for name, def in pairs(SOUNDS.Effects) do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. def.Id
	sound.Volume = def.Volume or 1
	sound.PlaybackSpeed = def.Pitch or 1
	sound.SoundGroup = effectsGroup
	sound.Parent = effectsGroup
	templates[name] = sound
end

-- Durée de vie d'un son joué (il peut ne pas être encore chargé : on laisse alors de la marge).
local function lifetime(sound: Sound): number
	local length = if sound.TimeLength > 0 then sound.TimeLength / sound.PlaybackSpeed else 6
	return length + 1
end

-- Joue un effet pour ce joueur uniquement (interface, ses propres actions).
function Sounds.play(name: string)
	local template = templates[name]
	if not template then
		warn("[Sounds] Son inconnu : " .. name)
		return
	end
	local sound = template:Clone()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, lifetime(sound))
end

-- Joue un effet à un endroit du monde (s'atténue avec la distance).
function Sounds.playAt(name: string, position: Vector3)
	local template = templates[name]
	if not template then
		warn("[Sounds] Son inconnu : " .. name)
		return
	end
	local emitter = Instance.new("Attachment")
	emitter.Name = "Sound_" .. name
	emitter.WorldPosition = position
	emitter.Parent = Workspace.Terrain
	local sound = template:Clone()
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 140
	sound.Parent = emitter
	sound:Play()
	Debris:AddItem(emitter, lifetime(sound))
end

-- Musiques : une piste en boucle par phase, fondu de l'une à l'autre.
local tracks: { [string]: Sound } = {}
for name, def in pairs(SOUNDS.Music) do
	local track = Instance.new("Sound")
	track.Name = "Music_" .. name
	track.SoundId = "rbxassetid://" .. def.Id
	track.Looped = true
	track.Volume = 0
	track:SetAttribute("TargetVolume", def.Volume or 1)
	track.SoundGroup = musicGroup
	track.Parent = musicGroup
	tracks[name] = track
end

-- Préchargement en arrière-plan : le premier son joué ne sera pas en retard.
task.spawn(function()
	local all: { Instance } = {}
	for _, sound in pairs(templates) do
		table.insert(all, sound)
	end
	for _, track in pairs(tracks) do
		table.insert(all, track)
	end
	pcall(function()
		ContentProvider:PreloadAsync(all)
	end)
end)

local currentMusic: string? = nil

function Sounds.setMusic(name: string)
	if name == currentMusic then
		return
	end
	currentMusic = name
	local fade = TweenInfo.new(SOUNDS.MusicFade)
	for trackName, track in pairs(tracks) do
		if trackName == name then
			if not track.IsPlaying then
				track:Play()
			end
			local target = track:GetAttribute("TargetVolume")
			TweenService:Create(track, fade, { Volume = if type(target) == "number" then target else 1 }):Play()
		elseif track.IsPlaying then
			local tween = TweenService:Create(track, fade, { Volume = 0 })
			tween.Completed:Once(function()
				if currentMusic ~= trackName then
					track:Pause() -- reprendra où elle en était
				end
			end)
			tween:Play()
		end
	end
end

return Sounds
