--!strict
-- TrainingController : stations d'entraînement de chaque base (achetées en boutique), façon Steal an Egg.
--   Tapis de course (Upgrade "Treadmill") -> XP de Vitesse.
--   Banc de muscu  (Upgrade "Bench")     -> XP de Force (puissance de lancer).
-- Le propriétaire marche sur sa station : le SERVEUR le bloque dessus (HumanoidRootPart ancré, debout face à la console
-- du tapis, ou allongé sur le banc), écrit l'attribut "Training" ("Treadmill" / "Bench") et lui donne de l'XP chaque
-- seconde. Le client (client/TrainingFx) joue l'animation (course sur place, développé couché + grognements) et affiche
-- les "+X 👟" / "+X 💪" qui s'envolent (attributs "TrainingGain" et "TrainingPulse", vus par tout le monde).
-- Pour descendre : sauter ou bouton ARRÊTER (Remotes.StopTraining) ; il faut quitter la station avant d'y remonter.
-- La station est cachée tant que le propriétaire de la base ne l'a pas achetée. Son niveau (1 à 25) choisit son modèle
-- (server/StationLooks : bois, acier, or, cristal, cosmique) et multiplie l'XP gagnée (Config.GetStationRate).
-- À côté, un panneau « Amélioration » montre le niveau suivant et son prix (bulle d'achat : client/UpgradeSigns).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local BaseManager = require(script.Parent.BaseManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local Quests = require(script.Parent.Quests)
local SessionData = require(script.Parent.SessionData)
local StationLooks = require(script.Parent.StationLooks)

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
	shownOwned: boolean, -- la base avait un propriétaire au dernier affichage (panneau d'amélioration visible)
	upgradeSign: Model?,
}

type Session = {
	station: Station,
	gained: number, -- XP gagnée depuis le dernier "+X"
	nextPulse: number,
	pulse: number,
}

local stations: { Station } = {}
local shopItem: { [string]: Config.ShopItem } = {}
for _, item in ipairs(Config.Shop) do
	shopItem[item.Id] = item
end
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
		return base * CFrame.new(0, height, 2 * Config.Training.TreadmillScale)
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

-- Panneau « Amélioration » : niveau actuel > suivant et prix (caché si la base n'a pas de propriétaire).
local function renderUpgradeSign(station: Station, level: number, owned: boolean)
	local sign = station.upgradeSign
	if not sign then
		return
	end
	for _, part in ipairs(sign:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = if owned then 0 else 1
			part.CanCollide = owned
			part.CanQuery = owned
		end
	end
	local board = sign:FindFirstChild("Board")
	local gui = board and board:FindFirstChild("Gui")
	if not gui or not gui:IsA("SurfaceGui") then
		return
	end
	gui.Enabled = owned
	local item = shopItem[station.kind.upgrade]
	local title = gui:FindFirstChild("Title")
	local levels = gui:FindFirstChild("Levels")
	local price = gui:FindFirstChild("Price")
	if not item or not title or not levels or not price or not title:IsA("TextLabel") or not levels:IsA("TextLabel") or not price:IsA("TextLabel") then
		return
	end
	local cost = Config.GetUpgradePrice(item, level)
	if level <= 0 then
		title.Text = station.kind.title
		levels.Text = "À ACHETER"
	elseif cost then
		title.Text = "AMÉLIORATION"
		levels.Text = string.format("NIVEAU %d > %d", level, level + 1)
	else
		title.Text = "AMÉLIORATION"
		levels.Text = "NIVEAU MAX !"
	end
	price.Text = if cost then NumberFormat.money(cost) else "★ " .. level .. " ★"
end

-- Affiche / cache la station et applique le modèle de son niveau (server/StationLooks).
local function render(station: Station, level: number, owned: boolean)
	if station.shownLevel == level and station.shownOwned == owned then
		return
	end
	if station.shownLevel ~= level then
		station.shownLevel = level
		local visible = level > 0
		-- Seules les pièces utiles (enfants directs) sont cachées ; le décor "Look" est reconstruit ou supprimé.
		for _, part in ipairs(station.model:GetChildren()) do
			if part:IsA("BasePart") then
				part.Transparency = if visible then 0 else 1
				part.CanCollide = visible
				part.CanQuery = visible
			end
		end
		StationLooks.Apply(station.model, station.kind.model, level)
		if station.sign then
			station.sign.Enabled = visible
		end
		if station.label then
			local tier = Config.GetStationTier(level)
			station.label.Text = string.format("%s\nNIVEAU %d • %s • XP x%s", station.kind.title, level, TextFormat.upper(tier.Title or tier.Name), NumberFormat.short(Config.GetStationRate(level)))
		end
	end
	station.shownOwned = owned
	renderUpgradeSign(station, level, owned)
end

local function update()
	local now = os.clock()
	for _, station in ipairs(stations) do
		local owner = BaseManager.GetOwner(station.base)
		local level = if owner then SessionData.GetUpgradeLevel(owner, station.kind.upgrade) else 0
		render(station, level, owner ~= nil)

		if owner and level > 0 then
			local session = sessions[owner]
			local root = getRoot(owner)
			if session and session.station == station then
				local gain = Config.GetStationRate(level) * TICK
				Quests.Add(owner, "Train", SessionData.AddTrainingXP(owner, station.kind.stat, gain))
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
				local upgradeSign = model:FindFirstChild("UpgradeSign")
				table.insert(stations, {
					base = base,
					kind = kind,
					model = model,
					zone = zone,
					sign = if sign and sign:IsA("BillboardGui") then sign else nil,
					label = if label and label:IsA("TextLabel") then label else nil,
					shownLevel = -1, -- force le premier affichage
					shownOwned = false,
					upgradeSign = if upgradeSign and upgradeSign:IsA("Model") then upgradeSign else nil,
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
