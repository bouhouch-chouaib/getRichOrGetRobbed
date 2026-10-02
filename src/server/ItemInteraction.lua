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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ItemInteraction = {}

local held: { [Player]: BasePart } = {}

local function getLooseFolder(): Instance
	local map = Workspace:FindFirstChild("Map")
	return (map and map:FindFirstChild("LooseItems")) or Workspace
end

local function setPromptEnabled(item: BasePart, enabled: boolean)
	local prompt = item:FindFirstChildOfClass("ProximityPrompt")
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

-- Lâche (sans lancer) l'item tenu par le joueur, s'il y en a un.
function ItemInteraction.ReleaseHeld(player: Player)
	local item = held[player]
	held[player] = nil
	if item and item.Parent then
		free(item)
	end
end

function ItemInteraction.IsHeld(item: BasePart): boolean
	return item:GetAttribute("Holder") ~= nil
end

local function onPromptTriggered(item: BasePart, player: Player)
	if item:GetAttribute("Holder") or item:GetAttribute("Consumed") or held[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	held[player] = item
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
end

-- À appeler pour chaque item créé (par ItemSpawner).
function ItemInteraction.Register(item: BasePart)
	local prompt = item:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			onPromptTriggered(item, player)
		end)
	end
end

function ItemInteraction.Init()
	Remotes.ThrowItem.OnServerEvent:Connect(function(player: Player, item: unknown)
		if typeof(item) ~= "Instance" or held[player] ~= item then
			return
		end
		held[player] = nil
		-- Owner reste en place : c'est lui qui marquera le point.
		-- La propriété réseau reste au lanceur pour que la trajectoire soit fluide de son côté.
		item:SetAttribute("Holder", nil)
		local part = item :: BasePart
		part.CanCollide = true
		part.Massless = false
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
	Players.PlayerRemoving:Connect(ItemInteraction.ReleaseHeld)
end

return ItemInteraction
