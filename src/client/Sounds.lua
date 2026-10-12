--!strict
-- Sounds : module de sons centralisé (côté client). Les Id et volumes sont dans Config.Sounds.
--   Sounds.play("Pickup")                      -> son "2D" (entendu seulement par ce joueur, partout)
--   Sounds.playAt("Consume", position)         -> son "3D" (entendu par ce joueur s'il est près de l'endroit)
--   Sounds.setPlaylist(palier)                 -> musiques du palier, mélangées, enchaînées en fondu
--   Sounds.duck(secondes)                      -> baisse la musique un moment (pendant un jingle)
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

-- Préchargement en arrière-plan : le premier son joué ne sera pas en retard.
task.spawn(function()
	local all: { Instance } = {}
	for _, sound in pairs(templates) do
		table.insert(all, sound)
	end
	pcall(function()
		ContentProvider:PreloadAsync(all)
	end)
end)

----------------------------------------------------------------------
-- Musique : playlist du palier (Config.Sounds.Playlists), morceaux mélangés enchaînés en fondu
----------------------------------------------------------------------

local playlistTier = 0
local playlistToken = 0
local currentTrack: Sound? = nil

-- Le groupe Music porte le volume général : on le baisse un moment pendant un jingle.
local duckToken = 0
function Sounds.duck(seconds: number)
	duckToken += 1
	local token = duckToken
	TweenService:Create(musicGroup, TweenInfo.new(0.3), { Volume = SOUNDS.MusicVolume * SOUNDS.MusicDuck }):Play()
	task.delay(seconds, function()
		if token == duckToken then
			TweenService:Create(musicGroup, TweenInfo.new(1), { Volume = SOUNDS.MusicVolume }):Play()
		end
	end)
end

local function fadeOut(track: Sound)
	local tween = TweenService:Create(track, TweenInfo.new(SOUNDS.MusicFade), { Volume = 0 })
	tween.Completed:Once(function()
		track:Destroy()
	end)
	tween:Play()
end

local function shuffled(list: { SoundDef }): { SoundDef }
	local copy = table.clone(list)
	for index = #copy, 2, -1 do
		local other = math.random(1, index)
		copy[index], copy[other] = copy[other], copy[index]
	end
	return copy
end

type SoundDef = { Id: number, Volume: number?, Pitch: number? }

-- Lance la playlist d'un palier (sans effet si c'est déjà elle). Un palier sans liste reprend celle du palier 1.
function Sounds.setPlaylist(tier: number)
	local list = SOUNDS.Playlists[tier] or SOUNDS.Playlists[1]
	if not list or #list == 0 then
		return
	end
	local effective = if SOUNDS.Playlists[tier] then tier else 1
	if effective == playlistTier then
		return
	end
	playlistTier = effective
	playlistToken += 1
	local token = playlistToken
	if currentTrack then
		fadeOut(currentTrack)
		currentTrack = nil
	end
	task.spawn(function()
		local queue: { SoundDef } = {}
		local last: number? = nil
		while token == playlistToken do
			if #queue == 0 then
				queue = shuffled(list)
				-- Pas deux fois le même morceau d'affilée quand la liste recommence.
				if #queue > 1 and queue[1].Id == last then
					queue[1], queue[#queue] = queue[#queue], queue[1]
				end
			end
			local def = table.remove(queue, 1) :: SoundDef
			last = def.Id
			local track = Instance.new("Sound")
			track.Name = "Music"
			track.SoundId = "rbxassetid://" .. def.Id
			track.Volume = 0
			track.SoundGroup = musicGroup
			track.Parent = musicGroup
			currentTrack = track
			track:Play()
			TweenService:Create(track, TweenInfo.new(SOUNDS.MusicFade), { Volume = def.Volume or 1 }):Play()
			-- Attend la fin du morceau (moins le fondu) pour enchaîner.
			local started = os.clock()
			while token == playlistToken and track.Parent do
				local length = track.TimeLength
				if length > 0 and (track.TimePosition >= length - SOUNDS.MusicFade or not track.IsPlaying) then
					break
				end
				if length == 0 and os.clock() - started > 20 then
					break -- morceau qui ne se charge pas : on passe au suivant
				end
				task.wait(0.25)
			end
			if token ~= playlistToken then
				return
			end
			fadeOut(track)
		end
	end)
end

return Sounds
