--!strict
-- SoundController : branche les sons (client/Sounds) sur ce qui se passe dans le jeu.
-- Rien n'est envoyé au serveur : on écoute les attributs répliqués et les RemoteEvents existants.
-- Les sons du lancer (InteractionController) et de l'arrivée d'un familier (BasePets) sont joués par ces scripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(script.Parent.Sounds)

local player = Players.LocalPlayer
local started = os.clock()

-- Au chargement de la sauvegarde, niveaux et améliorations passent de 0 à leur valeur : ce ne sont pas des
-- montées de niveau. On attend que la sauvegarde soit chargée (ou 8 s si elle ne se charge pas, ex. Studio).
local function ready(): boolean
	return player:GetAttribute("DataLoaded") == true or os.clock() - started > 8
end

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- Joue `sound` chaque fois que l'attribut numérique `name` du joueur augmente.
local function onIncrease(name: string, sound: string)
	local last = numberAttribute(name)
	player:GetAttributeChangedSignal(name):Connect(function()
		local value = numberAttribute(name)
		if value > last and ready() then
			Sounds.play(sound)
		end
		last = value
	end)
end

-- Musique de la phase en cours.
local function updateMusic()
	local state = ReplicatedStorage:GetAttribute("GameState")
	Sounds.setMusic(if state == "Digesting" then "Digesting" else "Feeding")
end
ReplicatedStorage:GetAttributeChangedSignal("GameState"):Connect(updateMusic)
updateMusic()

-- Ramasser, marquer des points, être éjecté par le dôme.
Remotes.ItemGrabbed.OnClientEvent:Connect(function()
	Sounds.play("Pickup")
end)
onIncrease("RoundScore", "Score")
Remotes.Knockback.OnClientEvent:Connect(function()
	Sounds.play("Knockback")
end)

-- Objets avalés par le trou noir : entendus par tous ceux qui sont près du trou.
local function watchLooseItem(item: Instance)
	if not item:IsA("BasePart") then
		return
	end
	item:GetAttributeChangedSignal("Consumed"):Connect(function()
		if item:GetAttribute("Consumed") then
			Sounds.playAt("Consume", item.Position)
		end
	end)
end
task.spawn(function()
	local map = Workspace:WaitForChild("Map")
	local loose = map:WaitForChild("LooseItems")
	loose.ChildAdded:Connect(watchLooseItem)
	for _, item in ipairs(loose:GetChildren()) do
		watchLooseItem(item)
	end
end)

-- Tirages, fusion, annonce d'un gros drop.
Remotes.RewardsGranted.OnClientEvent:Connect(function(_score: number, pulls: number)
	if pulls > 0 then
		Sounds.play("Rewards")
	end
end)
Remotes.FusionResult.OnClientEvent:Connect(function()
	Sounds.play("Rewards")
end)
Remotes.Announcement.OnClientEvent:Connect(function()
	Sounds.play("RareDrop")
end)

-- Boutique et entraînement.
for _, item in ipairs(Config.Shop) do
	onIncrease("Upgrade_" .. item.Id, "Purchase")
end
onIncrease("SpeedLevel", "LevelUp")
onIncrease("StrengthLevel", "LevelUp")

-- Vol de familiers : côté voleur…
player:GetAttributeChangedSignal("CarryingPet"):Connect(function()
	if player:GetAttribute("CarryingPet") ~= nil then
		Sounds.play("StealStart")
	end
end)
Remotes.StealResult.OnClientEvent:Connect(function(outcome: string)
	Sounds.play(if outcome == "Success" then "StealSuccess" else "StealFail")
end)
-- …et côté victime.
local VICTIM_SOUNDS = { Started = "StealAlarm", Stolen = "StealFail", Recovered = "Recovered", Returned = "Recovered" }
Remotes.StealNotice.OnClientEvent:Connect(function(kind: string)
	local sound = VICTIM_SOUNDS[kind]
	if sound then
		Sounds.play(sound)
	end
end)

-- Verrouillage d'une base : cliquetis au bouton, entendu par ceux qui sont à côté.
local function watchBase(base: Instance)
	if not base:IsA("Model") or not base.Name:match("^Base_%d+$") then
		return
	end
	base:GetAttributeChangedSignal("Locked"):Connect(function()
		local button = base:FindFirstChild("LockButton")
		if base:GetAttribute("Locked") == true and button and button:IsA("BasePart") then
			Sounds.playAt("Lock", button.Position)
		end
	end)
end
task.spawn(function()
	local map = Workspace:WaitForChild("Map")
	map.ChildAdded:Connect(watchBase)
	for _, child in ipairs(map:GetChildren()) do
		watchBase(child)
	end
end)
