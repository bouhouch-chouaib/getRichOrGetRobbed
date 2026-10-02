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
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local SessionData = require(script.Parent.SessionData)

local BlackholeController = {}

local ARENA = Config.Arena
local KNOCKBACK = Config.Knockback
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
		aura.Rate = if color == Config.Colors.Digesting then 150 else 60
	end
end

----------------------------------------------------------------------
-- Feeding : consommation des items
----------------------------------------------------------------------

local function consume(item: BasePart)
	item:SetAttribute("Consumed", true)

	local ownerName = item:GetAttribute("Owner")
	local owner = if type(ownerName) == "string" then Players:FindFirstChild(ownerName) else nil
	if owner and owner:IsA("Player") then
		SessionData.AddScore(owner, 1)
	end

	local prompt = item:FindFirstChildOfClass("ProximityPrompt")
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

local function distributeRewards()
	for _, player in ipairs(Players:GetPlayers()) do
		local score = SessionData.GetRoundScore(player)
		local results, pulls = LootEngine.processRewards(score)
		if pulls > 0 then
			SessionData.AddPets(player, results)
		end
		print(string.format("[Blackhole] %s : %d points -> %d tirage(s)", player.Name, score, pulls))
		Remotes.RewardsGranted:FireClient(player, score, pulls, results)
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
		setColors(Config.Colors.Feeding)
		if dome then
			dome.Transparency = 1
		end
	elseif state == "Digesting" then
		zone:SetAttribute("CanConsume", false)
		distributeRewards()
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
