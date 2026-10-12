--!strict
-- TrainingController : stations d'entraînement de chaque base (achetées en boutique), façon Steal an Egg.
--   Tapis de course (Upgrade "Treadmill") -> XP de Vitesse.
--   Banc de muscu  (Upgrade "Bench")     -> XP de Force (puissance de lancer).
-- Le propriétaire marche sur sa station : le SERVEUR le bloque dessus (HumanoidRootPart ancré, debout face à la console
-- du tapis, ou allongé sur le banc), écrit l'attribut "Training" ("Treadmill" / "Bench") et lui donne de l'XP chaque
-- seconde. Le client (client/TrainingFx) joue l'animation (course sur place, développé couché + grognements) et affiche
-- les "+X 👟" / "+X 💪" qui s'envolent (attributs "TrainingGain" et "TrainingPulse", vus par tout le monde).
-- Pour descendre : sauter ou bouton ARRÊTER (Remotes.StopTraining) ; il faut quitter la station avant d'y remonter.
-- La station est cachée tant que le propriétaire de la base ne l'a pas achetée. Son niveau (1 à 5) change sa matière
-- (bois -> diamant) et multiplie l'XP gagnée (Config.Training.StationRates).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local BaseManager = require(script.Parent.BaseManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local SessionData = require(script.Parent.SessionData)

local TrainingController = {}

local TICK = 0.25
local PULSE = 1 -- secondes entre deux "+X" affichés

type StationKind = { model: string, upgrade: string, stat: SessionData.Stat, title: string }

local KINDS: { StationKind } = {
	{ model = "Treadmill", upgrade = "Treadmill", stat = "Speed", title = "TAPIS DE COURSE" },
	{ model = "Bench", upgrade = "Bench", stat = "Strength", title = "BANC DE MUSCU" },
}

type Station = {
	base: Model,
	kind: StationKind,
	model: Model,
	zone: BasePart,
	label: TextLabel?,
	sign: BillboardGui?,
	shownLevel: number, -- niveau actuellement affiché (0 = caché)
}

type Session = {
	station: Station,
	gained: number, -- XP gagnée depuis le dernier "+X"
	nextPulse: number,
	pulse: number,
}

local stations: { Station } = {}
local sessions: { [Player]: Session } = {}
local mustLeave: { [Player]: Station } = {} -- descendu de cette station : il doit en sortir avant de remonter

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isOnZone(root: BasePart, zone: BasePart): boolean
	local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y > -1 and localPosition.Y < 8
end

-- Où placer le joueur pendant l'entraînement (HumanoidRootPart ancré).
local function trainingPose(station: Station, root: BasePart, humanoid: Humanoid): CFrame
	local zone = station.zone
	local base = zone.CFrame * CFrame.new(0, -zone.Size.Y / 2, 0) -- niveau du sol de la station, -Z vers la console
	if station.kind.model == "Treadmill" then
		-- Debout au milieu du tapis, face à la console.
		local height = zone.Size.Y + humanoid.HipHeight + root.Size.Y / 2
		return base * CFrame.new(0, height, 2)
	end
	-- Allongé sur le dos sur le banc, la tête sous la barre (vers -Z), le visage vers le ciel.
	local position = (base * CFrame.new(0, 3.05, -0.8)).Position
	return CFrame.lookAt(position, position + Vector3.yAxis, base.LookVector)
end

-- Où reposer le joueur quand il descend (à côté de la station).
local function exitPose(station: Station, root: BasePart): CFrame
	local zone = station.zone
	local side = zone.Size.X / 2 + 3
	return zone.CFrame * CFrame.new(side, root.Size.Y / 2 + 3, 0)
end

local function stop(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	mustLeave[player] = session.station
	player:SetAttribute("Training", nil)
	player:SetAttribute("TrainingGain", nil)
	local root = getRoot(player)
	if root then
		root.CFrame = exitPose(session.station, root)
		root.Anchored = false
	end
end

-- À appeler quand le joueur doit descendre de force (coup d'arme, KO...). Sans effet s'il ne s'entraîne pas.
TrainingController.Stop = stop

function TrainingController.IsTraining(player: Player): boolean
	return sessions[player] ~= nil
end

local function start(player: Player, station: Station)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = getRoot(player)
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	-- Mains libres : pas d'objet porté ni de familier volé ; l'arme éventuelle est rangée.
	if ItemInteraction.GetHeldCount(player) > 0 or player:GetAttribute("CarryingPet") ~= nil then
		return
	end
	humanoid:UnequipTools()
	sessions[player] = { station = station, gained = 0, nextPulse = os.clock() + PULSE, pulse = 0 }
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = trainingPose(station, root, humanoid)
	player:SetAttribute("Training", station.kind.model)
end

-- Affiche / cache la station et applique la matière de son niveau.
local function render(station: Station, level: number)
	if station.shownLevel == level then
		return
	end
	station.shownLevel = level
	local visible = level > 0
	local look = Config.Training.StationMaterials[math.clamp(level, 1, #Config.Training.StationMaterials)]
	for _, part in ipairs(station.model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = if visible then 0 else 1
			part.CanCollide = visible
			part.CanQuery = visible
			if part:GetAttribute("Tint") then
				part.Color = look.Color
				part.Material = look.Material
			end
		end
	end
	-- Hauts niveaux (Émeraude, Rubis, Cosmique) : lumière + étincelles à la couleur de la matière.
	local glowing = visible and look.Glow == true
	local sparkles = station.zone:FindFirstChild("StationSparkles")
	local light = station.zone:FindFirstChild("StationLight")
	if glowing then
		if not sparkles then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "StationSparkles"
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Rate = 14
			emitter.Lifetime = NumberRange.new(0.8, 1.6)
			emitter.Speed = NumberRange.new(2, 5)
			emitter.SpreadAngle = Vector2.new(25, 25)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Size = NumberSequence.new(0.6, 0)
			emitter.LightEmission = 1
			emitter.Parent = station.zone
			sparkles = emitter
		end
		if not light then
			local point = Instance.new("PointLight")
			point.Name = "StationLight"
			point.Range = 14
			point.Brightness = 1.5
			point.Parent = station.zone
			light = point
		end
		if sparkles and sparkles:IsA("ParticleEmitter") then
			sparkles.Color = ColorSequence.new(look.Color)
		end
		if light and light:IsA("PointLight") then
			light.Color = look.Color
		end
	else
		if sparkles then
			sparkles:Destroy()
		end
		if light then
			light:Destroy()
		end
	end
	if station.sign then
		station.sign.Enabled = visible
	end
	if station.label then
		station.label.Text = string.format("%s\nNIVEAU %d • %s • XP x%s", station.kind.title, level, TextFormat.upper(look.Name), tostring(Config.Training.StationRates[level] or 1))
	end
end

local function update()
	local now = os.clock()
	for _, station in ipairs(stations) do
		local owner = BaseManager.GetOwner(station.base)
		local level = if owner then SessionData.GetUpgradeLevel(owner, station.kind.upgrade) else 0
		render(station, level)

		if owner and level > 0 then
			local session = sessions[owner]
			local root = getRoot(owner)
			if session and session.station == station then
				local gain = (Config.Training.StationRates[level] or 1) * TICK
				SessionData.AddTrainingXP(owner, station.kind.stat, gain)
				session.gained += gain
				if now >= session.nextPulse then
					session.nextPulse = now + PULSE
					session.pulse += 1
					owner:SetAttribute("TrainingGain", session.gained)
					owner:SetAttribute("TrainingPulse", session.pulse) -- change à chaque fois : les clients affichent "+X"
					session.gained = 0
				end
			elseif not session and root then
				local onZone = isOnZone(root, station.zone)
				if mustLeave[owner] == station then
					if not onZone then
						mustLeave[owner] = nil
					end
				elseif onZone then
					start(owner, station)
				end
			end
		end
	end
	-- Plus propriétaire de la base de sa station (changement de base...) : il descend.
	for player, session in pairs(sessions) do
		if BaseManager.GetOwner(session.station.base) ~= player then
			stop(player)
		end
	end
end

function TrainingController.Init(bases: { Model })
	for _, base in ipairs(bases) do
		for _, kind in ipairs(KINDS) do
			local model = base:FindFirstChild(kind.model)
			local zone = model and model:FindFirstChild("Zone")
			if model and model:IsA("Model") and zone and zone:IsA("BasePart") then
				local sign = model:FindFirstChild("StationSign")
				local label = sign and sign:FindFirstChild("Label")
				table.insert(stations, {
					base = base,
					kind = kind,
					model = model,
					zone = zone,
					sign = if sign and sign:IsA("BillboardGui") then sign else nil,
					label = if label and label:IsA("TextLabel") then label else nil,
					shownLevel = 0,
				})
			else
				warn("[TrainingController] Station " .. kind.model .. " introuvable dans " .. base.Name)
			end
		end
	end

	-- Le joueur saute ou touche ARRÊTER.
	Remotes.StopTraining.OnServerEvent:Connect(function(player: Player)
		stop(player)
	end)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			-- Nouveau personnage (mort, réapparition) : l'ancien était ancré sur la station, celui-ci est libre.
			sessions[player] = nil
			mustLeave[player] = nil
			player:SetAttribute("Training", nil)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
		mustLeave[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			update()
		end
	end)
end

return TrainingController
