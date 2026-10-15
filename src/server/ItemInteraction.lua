--!strict
-- ItemInteraction : autorité serveur sur le ramassage / lancer / lâcher des objets.
--
-- Flux :
--   1. Le ProximityPrompt de l'item est déclenché -> le SERVEUR valide, écrit Owner + Holder,
--      donne la propriété réseau de l'item au joueur, puis envoie ItemGrabbed au client.
--   2. Le client soude l'item à sa main (WeldConstraint local). Comme il est propriétaire
--      réseau de l'item, la position qu'il simule est répliquée à tout le monde.
--   3. Au lancer, le client détruit le weld, applique l'impulsion et prévient le serveur (ThrowItem).
--   4. Lâcher forcé (KO, mort, départ) : le serveur efface "Holder", le client le détecte et lâche.
-- Sac à dos : un joueur peut porter 1 + niveau "Backpack" objets (le 1er en main, les autres dans le dos).
-- Aimant à objets (Config.Magnet, niveau Perks.MagnetLevel) : le serveur ramasse pour le joueur l'objet le plus proche
-- dans sa portée, par le même chemin que la bulle [E] (mêmes règles). Les objets des autres bases sont ignorés.
-- Anti-triche : à chaque lancer, le serveur note qui, d'où (position de son personnage côté serveur), quand et avec
-- quelle puissance max ; BlackholeController vérifie ces infos (GetThrowInfo) avant de donner des points.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PowerController = require(script.Parent.PowerController)
local SessionData = require(script.Parent.SessionData)

local ItemInteraction = {}

local held: { [Player]: { BasePart } } = {}

export type ThrowInfo = {
	thrower: Player,
	origin: Vector3, -- position du HumanoidRootPart (côté serveur) au moment du lancer
	time: number, -- os.clock() du serveur
	power: number, -- vitesse de lancer max du joueur (attribut "ThrowPower", calculé par le serveur)
	tooFast: boolean, -- lancé trop vite après le précédent (Config.AntiCheat.MinThrowInterval)
}

-- Clés faibles : un objet détruit disparaît aussi de cette table.
local throws: { [BasePart]: ThrowInfo } = setmetatable({}, { __mode = "k" }) :: any
local lastThrow: { [Player]: number } = {}

-- Infos du dernier lancer de cet objet (nil s'il n'a jamais été lancé : lâché, poussé, téléporté...).
function ItemInteraction.GetThrowInfo(item: BasePart): ThrowInfo?
	return throws[item]
end

-- Déclenché (player) chaque fois que le joueur doit tout lâcher : KO du dôme, mort, réapparition, départ.
-- StealController s'y abonne pour faire échouer un vol en cours.
local heldReleased = Instance.new("BindableEvent")
ItemInteraction.HeldReleased = heldReleased.Event

local function getLooseFolder(): Instance
	local map = Workspace:FindFirstChild("Map")
	return (map and map:FindFirstChild("LooseItems")) or Workspace
end

local function setPromptEnabled(item: BasePart, enabled: boolean)
	local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = enabled
	end
end

-- Rend un item à la physique normale, sans porteur.
local function free(item: BasePart)
	item:SetAttribute("Holder", nil)
	item.CanCollide = true
	item.Massless = false
	setPromptEnabled(item, true)
end

-- Lâche (sans lancer) tous les objets portés par le joueur.
function ItemInteraction.ReleaseHeld(player: Player)
	local items = held[player]
	held[player] = nil
	if items then
		for _, item in ipairs(items) do
			if item.Parent then
				free(item)
			end
		end
	end
	heldReleased:Fire(player)
end

local function getCapacity(player: Player): number
	return 1 + SessionData.GetUpgradeLevel(player, "Backpack") + Perks.ExtraCapacity(player)
end

-- Nombre d'objets portés par le joueur (WeaponController : pas d'arme en main tant qu'il en porte).
function ItemInteraction.GetHeldCount(player: Player): number
	local items = held[player]
	return if items then #items else 0
end

function ItemInteraction.IsHeld(item: BasePart): boolean
	return item:GetAttribute("Holder") ~= nil
end

local function onPromptTriggered(item: BasePart, player: Player)
	local items = held[player] or {}
	if item:GetAttribute("Holder") or item:GetAttribute("Consumed") or #items >= getCapacity(player) then
		return
	end
	-- Pendant le transport d'un familier volé, les mains sont prises.
	if player:GetAttribute("CarryingPet") then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Une arme en main (Tool équipé, server/WeaponController) : pas de ramassage.
	if character and character:FindFirstChildOfClass("Tool") then
		return
	end

	table.insert(items, item)
	held[player] = items
	throws[item] = nil -- un ancien lancer ne compte plus une fois l'objet repris en main
	item:SetAttribute("Holder", player.Name)
	item:SetAttribute("Owner", player.Name)
	item.CanCollide = false
	item.Massless = true
	item.Parent = getLooseFolder() -- l'item ne compte plus dans les objets de la base
	setPromptEnabled(item, false)
	pcall(function()
		item:SetNetworkOwner(player)
	end)

	Remotes.ItemGrabbed:FireClient(player, item)
	PowerController.Reveal(player) -- ramasser brise l'invisibilité
end

-- À appeler pour chaque item créé (par ItemSpawner).
function ItemInteraction.Register(item: BasePart)
	local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			onPromptTriggered(item, player)
		end)
	end
end

function ItemInteraction.Init()
	Remotes.ThrowItem.OnServerEvent:Connect(function(player: Player, item: unknown)
		local items = held[player]
		local index = if items and typeof(item) == "Instance" then table.find(items, item :: any) else nil
		if not items or not index then
			return
		end
		local part = table.remove(items, index) :: BasePart
		-- Owner reste en place : c'est lui qui marquera le point.
		-- La propriété réseau reste au lanceur pour que la trajectoire soit fluide de son côté.
		part:SetAttribute("Holder", nil)
		part.CanCollide = true
		part.Massless = false
		-- La bulle [E] revient : un objet lancé qui rate le trou doit pouvoir être ramassé à nouveau.
		setPromptEnabled(part, true)

		-- Anti-triche : on note le lancer tel que le serveur le voit (le client ne peut rien y changer).
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local power = player:GetAttribute("ThrowPower")
		local now = os.clock()
		if root and root:IsA("BasePart") then
			throws[part] = {
				thrower = player,
				origin = root.Position,
				time = now,
				power = if type(power) == "number" then power else Config.Training.Strength.Base,
				tooFast = now - (lastThrow[player] or 0) < Config.AntiCheat.MinThrowInterval,
			}
		end
		lastThrow[player] = now
	end)

	local function watchCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				ItemInteraction.ReleaseHeld(player)
			end)
		end
	end

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			ItemInteraction.ReleaseHeld(player)
			watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Aimant à objets : quelques fois par seconde, l'objet le plus proche dans la portée de chaque joueur équipé.
	local MAGNET = Config.Magnet
	local lastPull: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPull[player] = nil
	end)
	local function candidates(player: Player): { BasePart }
		local list: { BasePart } = {}
		local map = Workspace:FindFirstChild("Map")
		if not map then
			return list
		end
		local function addFrom(folder: Instance?)
			if folder then
				for _, child in ipairs(folder:GetChildren()) do
					if child:IsA("BasePart") then
						table.insert(list, child)
					end
				end
			end
		end
		addFrom(map:FindFirstChild("LooseItems"))
		addFrom(map:FindFirstChild("WildItems"))
		-- Les palettes de SA base seulement (les objets des autres bases sont à eux).
		for _, base in ipairs(map:GetChildren()) do
			if base:IsA("Model") and base:GetAttribute("OwnerName") == player.Name then -- server/BaseManager
				addFrom(base:FindFirstChild("ItemSpawns"))
			end
		end
		return list
	end
	task.spawn(function()
		while true do
			task.wait(0.15)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local level = Perks.MagnetLevel(player)
				if level <= 0 or now - (lastPull[player] or 0) < MAGNET.Interval then
					continue
				end
				if #(held[player] or {}) >= getCapacity(player) or player:GetAttribute("CarryingPet") then
					continue
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or not root:IsA("BasePart") then
					continue
				end
				local radius = MAGNET.Radius[level]
				local best: BasePart? = nil
				local bestDistance = radius
				for _, item in ipairs(candidates(player)) do
					if item:GetAttribute("Holder") or item:GetAttribute("Consumed") then
						continue
					end
					local throw = throws[item]
					if throw and throw.thrower == player and now - throw.time < MAGNET.IgnoreOwnThrow then
						continue
					end
					local distance = (item.Position - root.Position).Magnitude
					if distance < bestDistance then
						best, bestDistance = item, distance
					end
				end
				if best then
					lastPull[player] = now
					onPromptTriggered(best, player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		ItemInteraction.ReleaseHeld(player)
		lastThrow[player] = nil
	end)
end

return ItemInteraction
