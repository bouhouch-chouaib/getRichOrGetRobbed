--!strict
-- BlackholeController : le cœur du jeu.
--   Feeding   : avale les items lancés dans la zone (+1 point au propriétaire "Owner").
--   Digesting : distribue les récompenses RNG, puis le dôme repousse items et joueurs.
--
-- Détection par distance à chaque frame (et non par .Touched) : un objet rapide ne peut
-- pas traverser la zone sans être vu (anti-tunneling), et ça marche même si le client
-- est propriétaire réseau de l'objet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LootEngine = require(ReplicatedStorage.Shared.LootEngine)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BlackholeTiers = require(script.Parent.BlackholeTiers)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local EconomyController = require(script.Parent.EconomyController)
local PullRewards = require(script.Parent.PullRewards)
local SessionData = require(script.Parent.SessionData)

local BlackholeController = {}

local ARENA = Config.Arena
local KNOCKBACK = Config.Knockback
local ANTICHEAT = Config.AntiCheat
local CENTER = Vector3.zero

local map: Folder
local zone: BasePart
local looseItems: Folder
local knockbackCooldown: { [Player]: number } = {}

local function find(name: string): BasePart?
	local part = map:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- Direction horizontale du centre vers une position (jamais nulle).
local function outward(position: Vector3): Vector3
	local flat = Vector3.new(position.X, 0, position.Z)
	if flat.Magnitude < 0.1 then
		return Vector3.xAxis
	end
	return flat.Unit
end

local function setColors(color: Color3)
	local ring = find("HoleRing")
	if ring then
		ring.Color = color
	end
	local halo = find("BlackholeHalo")
	if halo then
		halo.Color = color
	end
	local core = find("BlackholeCore")
	local light = core and core:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = color
	end
	local aura = zone:FindFirstChildOfClass("ParticleEmitter")
	if aura then
		aura.Color = ColorSequence.new(color)
		aura.Rate = if color == Config.Colors.Digesting then 150 else 60 + BlackholeTiers.GetTier() * 12
	end
end

----------------------------------------------------------------------
-- Feeding : consommation des items
----------------------------------------------------------------------

-- Anti-triche : l'objet a-t-il vraiment été lancé par son propriétaire, depuis une distance atteignable ?
-- Retourne la raison du refus (nil si le lancer est valable).
local function rejectReason(item: BasePart, owner: Player): string?
	local throw = ItemInteraction.GetThrowInfo(item)
	if not throw then
		return "jamais lancé" -- lâché, poussé ou téléporté : ne rapporte rien
	end
	if throw.thrower ~= owner then
		return "lancé par un autre joueur"
	end
	if throw.tooFast then
		return "lancers trop rapprochés"
	end
	if os.clock() - throw.time > ANTICHEAT.MaxFlightTime then
		return "lancé il y a trop longtemps"
	end
	-- Distance à parcourir depuis le point de lancer jusqu'au bord du trou, comparée à la portée max théorique
	-- d'un projectile lancé à la vitesse max du joueur (v² / g), avec une marge.
	local flat = Vector3.new(throw.origin.X, 0, throw.origin.Z)
	local needed = flat.Magnitude - ARENA.HoleRadius
	local maxRange = throw.power * throw.power / Workspace.Gravity * ANTICHEAT.RangeMargin + ANTICHEAT.RangeBonus
	if needed > maxRange then
		return string.format("trop loin (%.0f studs pour une portée max de %.0f)", needed, maxRange)
	end
	-- Un objet ne peut pas voler plus vite que la vitesse de lancer du joueur : arrivé trop tôt = téléporté.
	local flightTime = os.clock() - throw.time
	local minFlightTime = math.max(0, needed) / throw.power * ANTICHEAT.MinFlightRatio - ANTICHEAT.FlightTimeMargin
	if flightTime < minFlightTime then
		return string.format("arrivé trop vite (%.2f s pour %.0f studs, minimum %.2f s)", flightTime, needed, minFlightTime)
	end
	return nil
end

-- caught : rattrapé par un tentacule (palier 4) juste avant le bord.
local function consume(item: BasePart, caught: boolean?)
	item:SetAttribute("Consumed", true)
	if caught then
		BlackholeTiers.OnCaught(item)
	end

	local ownerName = item:GetAttribute("Owner")
	local found = if type(ownerName) == "string" then Players:FindFirstChild(ownerName) else nil
	local owner = if found and found:IsA("Player") then found else nil
	if owner then
		local reason = rejectReason(item, owner)
		if not reason then
			-- Points = valeur de l'objet (Config.ItemTiers) × multiplicateur des familiers équipés × bonus du palier
			-- du trou noir (centre, combo, jackpot : server/BlackholeTiers, qui remplit aussi la jauge commune).
			local rawValue = item:GetAttribute("Value")
			local value = if type(rawValue) == "number" then rawValue else 1
			local bonus = BlackholeTiers.OnScored(owner, item, value)
			SessionData.AddScore(owner, value * SessionData.GetMultiplier(owner) * bonus)
		elseif reason ~= "jamais lancé" then
			-- Un objet simplement lâché près du trou n'est pas suspect ; le reste est signalé.
			warn(string.format("[AntiCheat] %s : objet avalé sans points (%s)", owner.Name, reason))
		end
	end

	local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	item.Anchored = true
	item.CanCollide = false

	-- Petite animation d'aspiration avant destruction.
	local tween = TweenService:Create(item, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = CENTER - Vector3.new(0, 2, 0),
		Size = Vector3.one * 0.2,
		Transparency = 1,
	})
	tween.Completed:Once(function()
		item:Destroy()
	end)
	tween:Play()
end

local function consumeItems()
	for _, child in ipairs(looseItems:GetChildren()) do
		if child:IsA("BasePart") and not ItemInteraction.IsHeld(child) and not child:GetAttribute("Consumed") then
			local position = child.Position
			local flatDistance = Vector3.new(position.X, 0, position.Z).Magnitude
			if flatDistance <= ARENA.HoleRadius and position.Y <= ARENA.HoleConsumeHeight then
				consume(child)
			elseif BlackholeTiers.CanCatch(child, flatDistance) then
				consume(child, true)
			end
		end
	end
end

----------------------------------------------------------------------
-- Digesting : dôme répulsif actif
----------------------------------------------------------------------

local function repelItem(item: BasePart)
	-- Le serveur reprend la main sur la physique de l'objet (sinon le client peut forcer le passage).
	pcall(function()
		item:SetNetworkOwner(nil)
	end)
	local direction = outward(item.Position)
	-- On replace l'objet juste à l'extérieur du dôme : il ne peut pas "traverser" entre deux frames.
	item.AssemblyLinearVelocity = Vector3.zero
	item.CFrame = CFrame.new(direction * (ARENA.DomeRadius + 3) + Vector3.new(0, math.max(item.Position.Y, 4), 0))
	local velocity = direction * KNOCKBACK.ItemOutwardSpeed + Vector3.new(0, KNOCKBACK.ItemUpSpeed, 0)
	item:ApplyImpulse(velocity * item.AssemblyMass)
end

local function knockbackPlayer(player: Player, humanoid: Humanoid, root: BasePart)
	local now = os.clock()
	if (knockbackCooldown[player] or 0) > now then
		return
	end
	knockbackCooldown[player] = now + KNOCKBACK.Cooldown

	ItemInteraction.ReleaseHeld(player)

	-- KO : assis (plus de contrôle) + soulevé d'1 stud pour annuler la friction du sol.
	humanoid.Sit = true
	root.CFrame += Vector3.new(0, 1, 0)

	-- Le personnage appartient au client : c'est lui qui applique la force d'éjection.
	local velocity = outward(root.Position) * KNOCKBACK.OutwardSpeed + Vector3.new(0, KNOCKBACK.UpSpeed, 0)
	Remotes.Knockback:FireClient(player, velocity)

	task.delay(KNOCKBACK.SitDuration, function()
		if humanoid.Parent then
			humanoid.Sit = false
		end
	end)
end

local function repel()
	for _, child in ipairs(looseItems:GetChildren()) do
		if child:IsA("BasePart") and not ItemInteraction.IsHeld(child) and not child:GetAttribute("Consumed") then
			if (child.Position - CENTER).Magnitude < ARENA.DomeRadius then
				repelItem(child)
			end
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			if (root.Position - CENTER).Magnitude < ARENA.DomeRadius then
				knockbackPlayer(player, humanoid, root)
			end
		end
	end
end

----------------------------------------------------------------------
-- Récompenses
----------------------------------------------------------------------

-- Argent des points de la manche : MoneyPerPoint par point, ou une fraction du revenu du joueur si c'est plus.
local function pointsMoney(player: Player, score: number): number
	local perPoint = math.max(Config.Economy.MoneyPerPoint, EconomyController.GetIncome(player) * Config.Economy.IncomeSecondsPerPoint)
	return math.floor(score * perPoint * Perks.MoneyMultiplier(player))
end

local function distributeRewards()
	for _, player in ipairs(Players:GetPlayers()) do
		local score = math.floor(SessionData.GetRoundScore(player) * 10) / 10
		local pulls = LootEngine.countPulls(score)
		if pulls > 0 then
			-- Chance selon le score + passes et boost serveur (shared/Perks) ; rang, doublons : server/PullRewards.
			local money = pointsMoney(player, score)
			PullRewards.Grant(player, pulls, LootEngine.luck(score, Perks.LuckBonus(player)), money, score)
			print(string.format("[Blackhole] %s : %.1f points -> %d tirage(s), +%d$", player.Name, score, pulls, money))
		else
			Remotes.RewardsGranted:FireClient(player, score, 0, {}, 0)
		end
	end
	SessionData.ResetRoundScores()
end

----------------------------------------------------------------------
-- États
----------------------------------------------------------------------

local function applyState(state: string)
	local dome = find("BlackholeDome")
	if state == "Feeding" then
		zone:SetAttribute("CanConsume", true)
		setColors(BlackholeTiers.Color())
		if dome then
			dome.Transparency = 1
		end
	elseif state == "Digesting" then
		zone:SetAttribute("CanConsume", false)
		-- Effondrement après le palier 7 : score du tour x2 avant les tirages, cadeaux et retour au palier 1 après.
		BlackholeTiers.BeforeRewards()
		distributeRewards()
		BlackholeTiers.AfterRewards()
		setColors(Config.Colors.Digesting)
		if dome then
			dome.Transparency = 0.35
		end
	end
end

function BlackholeController.Init()
	local foundMap = Workspace:WaitForChild("Map")
	assert(foundMap:IsA("Folder"), "Workspace.Map doit être un Folder")
	map = foundMap

	local foundZone = find("BlackholeZone")
	assert(foundZone, "BlackholeZone introuvable : MapGenerator doit tourner avant BlackholeController")
	zone = foundZone

	local foundLoose = map:FindFirstChild("LooseItems")
	assert(foundLoose and foundLoose:IsA("Folder"), "LooseItems introuvable")
	looseItems = foundLoose

	GameLoopManager.ServerEvent.Event:Connect(function(eventName: string, state: string)
		if eventName == "StateChanged" then
			applyState(state)
		end
	end)
	BlackholeTiers.TierChanged:Connect(function()
		if GameLoopManager.GetState() == "Feeding" then
			setColors(BlackholeTiers.Color())
		end
	end)

	RunService.Heartbeat:Connect(function()
		local state = GameLoopManager.GetState()
		if state == "Feeding" and zone:GetAttribute("CanConsume") then
			consumeItems()
		elseif state == "Digesting" then
			repel()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		knockbackCooldown[player] = nil
	end)
end

return BlackholeController
