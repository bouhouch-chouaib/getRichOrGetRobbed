--!strict
-- BlackholeTiers : les 7 paliers du trou noir, partagés par tout le serveur (docs/DIRECTION_ARTISTIQUE.md §8).
-- Une jauge COMMUNE se remplit avec les objets avalés (valeur de l'objet, au moins 1, sans multiplicateur) ;
-- pleine, le trou monte d'un palier. Chaque palier a son aspect (client/BlackholeFx) et UNE petite mécanique,
-- toujours un bonus, jamais une punition (Config.Blackhole) :
--   1 Éveil      rien de plus (la boucle de base)
--   2 Éruption   recrache des roches de lave (x3) dans l'arène toutes les 15 s
--   3 Cible      point d'impact prévu près du centre : x2
--   4 Abysses    les tentacules rattrapent les lancers tombés juste avant le bord
--   5 Gravité    attire doucement les objets sauvages vers le trou + pluie de météorites
--   6 Supernova  combo de lancers réussis d'affilée (jusqu'à x2)
--   7 Divin      jackpot x5 pendant 10 s, une fois par tour, annoncé
-- Jauge du palier 7 pleine : Effondrement au début de la digestion suivante (score du tour x2, familiers offerts aux
-- 3 meilleurs contributeurs du cycle), puis retour au palier 1.
-- État publié pour les clients en attributs de ReplicatedStorage : HoleTier, HoleGauge, HoleNeed, HoleCollapse,
-- HoleJackpotUntil (horloge serveur). Événements visuels : Remotes.HoleEvent (voir Remotes.lua).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BasePetsController = require(script.Parent.BasePetsController)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local ItemSpawner = require(script.Parent.ItemSpawner)
local SessionData = require(script.Parent.SessionData)

local HOLE = Config.Blackhole
local ARENA = Config.Arena
local MAX_TIER = #HOLE.Tiers

local BlackholeTiers = {}

local tierChanged = Instance.new("BindableEvent")
-- Déclenché (tier) quand le palier change : BlackholeController recolore le trou.
BlackholeTiers.TierChanged = tierChanged.Event

local tier = 1
local gauge = 0
local collapsePending = false
local contributions: { [number]: number } = {} -- UserId -> jauge apportée depuis le palier 1
local combos: { [Player]: { count: number, last: number } } = {}
local jackpotUntil = 0
local feedingElapsed = 0
local rng = Random.new()

local function need(): number
	local players = math.max(1, #Players:GetPlayers())
	return math.max(1, math.floor(HOLE.GaugeNeed[tier] * players ^ HOLE.PlayerScaling + 0.5))
end

local function publish()
	ReplicatedStorage:SetAttribute("HoleTier", tier)
	ReplicatedStorage:SetAttribute("HoleGauge", math.floor(gauge * 10 + 0.5) / 10)
	ReplicatedStorage:SetAttribute("HoleNeed", need())
	ReplicatedStorage:SetAttribute("HoleCollapse", collapsePending)
	ReplicatedStorage:SetAttribute("HoleJackpotUntil", jackpotUntil)
end

function BlackholeTiers.GetTier(): number
	return tier
end

-- Couleur du trou pendant le Feeding (anneau, halo, lumière, particules).
function BlackholeTiers.Color(): Color3
	return HOLE.Tiers[tier].Color
end

local function setTier(newTier: number)
	tier = math.clamp(newTier, 1, MAX_TIER)
	gauge = 0
	jackpotUntil = 0
	table.clear(combos)
	publish()
	tierChanged:Fire(tier)
end

local function addGauge(player: Player, amount: number)
	if collapsePending then
		return
	end
	gauge += amount
	contributions[player.UserId] = (contributions[player.UserId] or 0) + amount
	if gauge >= need() then
		if tier < MAX_TIER then
			setTier(tier + 1)
			Remotes.HoleEvent:FireAllClients("TierUp", tier)
			return
		end
		gauge = need()
		collapsePending = true
		Remotes.HoleEvent:FireAllClients("CollapseSoon")
	end
	publish()
end

-- Remplit la jauge commune (familier jeté dans le trou : server/StealController).
function BlackholeTiers.AddGauge(player: Player, amount: number)
	addGauge(player, amount)
end

----------------------------------------------------------------------
-- Mécaniques appelées par BlackholeController
----------------------------------------------------------------------

-- Point où l'objet touchera le sol du trou (y = 0,5), d'après sa position et sa vitesse.
local function landingPoint(item: BasePart): Vector3
	local p, v = item.Position, item.AssemblyLinearVelocity
	local g = Workspace.Gravity
	local height = p.Y - 0.5
	local t = if height > 0 then (v.Y + math.sqrt(math.max(0, v.Y * v.Y + 2 * g * height))) / g else 0
	return Vector3.new(p.X + v.X * t, 0.5, p.Z + v.Z * t)
end

-- Un objet lancé par `owner` vient d'être avalé (lancer valable). Remplit la jauge et renvoie le bonus de points.
function BlackholeTiers.OnScored(owner: Player, item: BasePart, value: number): number
	addGauge(owner, math.max(1, value))
	local bonus = 1
	if tier == 3 then
		local landing = landingPoint(item)
		if Vector3.new(landing.X, 0, landing.Z).Magnitude <= HOLE.Target.Radius then
			bonus *= HOLE.Target.Multiplier
			Remotes.HoleEvent:FireAllClients("Bullseye", landing, owner)
		end
	elseif tier == 6 then
		local now = os.clock()
		local previous = combos[owner]
		local combo = if previous and now - previous.last <= HOLE.Combo.Window
			then { count = previous.count + 1, last = now }
			else { count = 0, last = now }
		combos[owner] = combo
		local multiplier = math.min(HOLE.Combo.Max, 1 + HOLE.Combo.Step * combo.count)
		if combo.count > 0 then
			bonus *= multiplier
			Remotes.HoleEvent:FireAllClients("Combo", item.Position, owner, multiplier)
		end
	end
	if Workspace:GetServerTimeNow() < jackpotUntil then
		bonus *= HOLE.Jackpot.Multiplier
	end
	return bonus
end

-- Palier 4 : un objet lancé tombé juste avant le bord est rattrapé par un tentacule.
function BlackholeTiers.CanCatch(item: BasePart, flatDistance: number): boolean
	if tier ~= 4 or flatDistance <= ARENA.HoleRadius or flatDistance > ARENA.HoleRadius + HOLE.Tentacles.Reach then
		return false
	end
	if item.Position.Y > HOLE.Tentacles.MaxHeight then
		return false
	end
	local throw = ItemInteraction.GetThrowInfo(item)
	return throw ~= nil and os.clock() - throw.time <= HOLE.Tentacles.MaxAge
end

function BlackholeTiers.OnCaught(item: BasePart)
	Remotes.HoleEvent:FireAllClients("Catch", item.Position)
end

-- Vitesse d'un tir en cloche qui part de `from` et arrive à `to` en `time` secondes.
local function ballistic(from: Vector3, to: Vector3, time: number): Vector3
	return (to - from) / time + Vector3.new(0, 0.5 * Workspace.Gravity * time, 0)
end

local function randomArenaPoint(minRadius: number, maxRadius: number): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(minRadius, maxRadius)
	return Vector3.new(math.cos(angle) * radius, 1.5, math.sin(angle) * radius)
end

-- Palier 2 : le trou recrache des roches de lave.
local function spitLava()
	local lava = HOLE.Lava
	local from = Vector3.new(0, 22, 0)
	for _ = 1, lava.Count do
		local target = randomArenaPoint(lava.MinRadius, lava.MaxRadius)
		ItemSpawner.SpawnSpecial("Lava", from, ballistic(from, target, lava.FlightTime))
	end
	Remotes.HoleEvent:FireAllClients("Spit")
end

-- Palier 5 : pluie de météorites dans l'arène.
local function meteorShower()
	local gravity = HOLE.Gravity
	for _ = 1, gravity.MeteorCount do
		local target = randomArenaPoint(Config.Items.WildMinRadius, Config.Items.WildMaxRadius)
		local side = randomArenaPoint(30, 50) - Vector3.new(0, 1.5, 0)
		local from = target + side + Vector3.new(0, 150, 0)
		ItemSpawner.SpawnSpecial("Meteor", from, ballistic(from, target, 1.1))
	end
	Remotes.HoleEvent:FireAllClients("Meteors")
end

-- Palier 5 : les objets sauvages au sol glissent doucement vers le bord du trou (sans y tomber).
local function pullItems()
	local map = Workspace:FindFirstChild("Map")
	local wild = map and map:FindFirstChild("WildItems")
	if not wild then
		return
	end
	local gravity = HOLE.Gravity
	for _, item in ipairs(wild:GetChildren()) do
		if item:IsA("BasePart") and not item.Anchored and not ItemInteraction.IsHeld(item) then
			local flat = Vector3.new(item.Position.X, 0, item.Position.Z)
			local distance = flat.Magnitude
			if distance > gravity.StopRadius and distance < gravity.PullRadius then
				if not item:GetAttribute("Pulled") then
					item:SetAttribute("Pulled", true)
					pcall(function()
						item:SetNetworkOwner(nil) -- le serveur pilote le glissement
					end)
				end
				local velocity = item.AssemblyLinearVelocity
				local pull = -flat.Unit * gravity.Speed
				item.AssemblyLinearVelocity = Vector3.new(pull.X, velocity.Y, pull.Z)
			end
		end
	end
end

-- Palier 7 : un jackpot par tour, à un moment au hasard du Feeding.
local function scheduleJackpot()
	local duration = GameLoopManager.GetTimeRemaining()
	local at = rng:NextNumber(6, math.max(7, duration - HOLE.Jackpot.Duration - 4))
	task.delay(at, function()
		if tier == MAX_TIER and GameLoopManager.GetState() == "Feeding" and not collapsePending then
			jackpotUntil = Workspace:GetServerTimeNow() + HOLE.Jackpot.Duration
			publish()
			Remotes.HoleEvent:FireAllClients("Jackpot", jackpotUntil)
		end
	end)
end

----------------------------------------------------------------------
-- Effondrement (appelé par BlackholeController au début de la digestion)
----------------------------------------------------------------------

-- Avant les récompenses : le score du tour de chacun est multiplié.
function BlackholeTiers.BeforeRewards(): boolean
	if not collapsePending then
		return false
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local score = SessionData.GetRoundScore(player)
		if score > 0 then
			SessionData.AddScore(player, score * (HOLE.Collapse.ScoreMultiplier - 1))
		end
	end
	return true
end

-- Après les récompenses : familiers offerts aux meilleurs contributeurs, retour au palier 1.
function BlackholeTiers.AfterRewards()
	if not collapsePending then
		return
	end
	local ranking: { { player: Player, amount: number } } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local amount = contributions[player.UserId]
		if amount and amount > 0 and SessionData.IsLoaded(player) then
			table.insert(ranking, { player = player, amount = amount })
		end
	end
	table.sort(ranking, function(a, b)
		return a.amount > b.amount
	end)
	local winners: { string } = {}
	for index, rarity in ipairs(HOLE.Collapse.Rewards) do
		local entry = ranking[index]
		local pool = PetCatalog.ByRarity[rarity]
		if entry and pool and #pool > 0 then
			local pet = pool[rng:NextInteger(1, #pool)]
			SessionData.AddPets(entry.player, { [pet.Id] = 1 })
			BasePetsController.Celebrate(entry.player, { pet.Id })
			Remotes.Announcement:FireAllClients(entry.player.DisplayName, pet.Id)
			table.insert(winners, entry.player.DisplayName)
		end
	end
	collapsePending = false
	table.clear(contributions)
	setTier(1)
	Remotes.HoleEvent:FireAllClients("Collapse", winners)
end

----------------------------------------------------------------------

function BlackholeTiers.Init()
	publish()
	GameLoopManager.ServerEvent.Event:Connect(function(eventName: string, state: string)
		if state ~= "Feeding" then
			return
		end
		if eventName == "StateChanged" then
			feedingElapsed = 0
			jackpotUntil = 0
			if tier == MAX_TIER then
				scheduleJackpot()
			end
		elseif eventName == "Tick" then
			feedingElapsed += 1
		else
			return
		end
		if collapsePending then
			return
		end
		if tier == 2 and feedingElapsed % HOLE.Lava.Interval == 1 then
			spitLava()
		elseif tier == 5 and feedingElapsed % HOLE.Gravity.MeteorInterval == 3 then
			meteorShower()
		end
	end)

	RunService.Heartbeat:Connect(function()
		if tier == 5 and GameLoopManager.GetState() == "Feeding" then
			pullItems()
		end
	end)

	Players.PlayerAdded:Connect(publish)
	Players.PlayerRemoving:Connect(function(player: Player)
		combos[player] = nil
		task.defer(publish)
	end)

	-- Test dans Studio : ReplicatedStorage:SetAttribute("DebugHoleTier", 5) passe directement au palier 5 ;
	-- 8 = jauge du palier 7 pleine (Effondrement à la prochaine digestion).
	if RunService:IsStudio() then
		ReplicatedStorage:GetAttributeChangedSignal("DebugHoleTier"):Connect(function()
			local wanted = ReplicatedStorage:GetAttribute("DebugHoleTier")
			if type(wanted) ~= "number" then
				return
			end
			if wanted > MAX_TIER then
				setTier(MAX_TIER)
				gauge = need()
				collapsePending = true
				publish()
				Remotes.HoleEvent:FireAllClients("CollapseSoon")
			else
				collapsePending = false
				setTier(math.floor(wanted))
				Remotes.HoleEvent:FireAllClients("TierUp", tier)
			end
		end)
	end
end

return BlackholeTiers
