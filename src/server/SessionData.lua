--!strict
-- SessionData : données de session en mémoire par joueur (pas de DataStore pour le MVP).
-- Chaque valeur est recopiée en attribut sur le Player (lu par le HUD) et dans les leaderstats :
--   Speed, RoundScore, Money, Pets_<Rareté>, Unlock_<Id>

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type PlayerData = {
	speed: number,
	roundScore: number,
	money: number,
	pets: { [string]: number },
	unlocks: { [string]: boolean },
}

local SessionData = {}

local storage: { [Player]: PlayerData } = {}

local function getStat(player: Player, name: string): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(name)
	if stat and stat:IsA("IntValue") then
		return stat
	end
	return nil
end

local function applySpeed(player: Player, speed: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

-- Recopie les données du joueur vers ses attributs et leaderstats.
local function sync(player: Player)
	local data = storage[player]
	if not data then
		return
	end

	player:SetAttribute("Speed", data.speed)
	player:SetAttribute("RoundScore", data.roundScore)
	player:SetAttribute("Money", data.money)

	for name, count in pairs(data.pets) do
		player:SetAttribute("Pets_" .. name, count)
	end
	for id in pairs(data.unlocks) do
		player:SetAttribute("Unlock_" .. id, true)
	end

	local money = getStat(player, "Argent")
	if money then
		money.Value = math.floor(data.money)
	end
	local points = getStat(player, "Points")
	if points then
		points.Value = data.roundScore
	end
end

local function onPlayerAdded(player: Player)
	local pets = {}
	for _, rarity in ipairs(Config.Rarities) do
		pets[rarity.Name] = 0
	end
	storage[player] = { speed = Config.Speed.Base, roundScore = 0, money = 0, pets = pets, unlocks = {} }

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in ipairs({ "Argent", "Points" }) do
		local stat = Instance.new("IntValue")
		stat.Name = name
		stat.Parent = leaderstats
	end
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function()
		local data = storage[player]
		if data then
			-- Le Humanoid est créé avec le personnage : on attend la frame suivante par sécurité.
			task.defer(applySpeed, player, data.speed)
		end
	end)

	sync(player)
end

function SessionData.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		storage[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

function SessionData.Get(player: Player): PlayerData?
	return storage[player]
end

function SessionData.AddScore(player: Player, amount: number)
	local data = storage[player]
	if data then
		data.roundScore += amount
		sync(player)
	end
end

function SessionData.GetRoundScore(player: Player): number
	local data = storage[player]
	return if data then data.roundScore else 0
end

function SessionData.ResetRoundScores()
	for player, data in pairs(storage) do
		data.roundScore = 0
		sync(player)
	end
end

function SessionData.AddPets(player: Player, newPets: { [string]: number })
	local data = storage[player]
	if not data then
		return
	end
	for name, count in pairs(newPets) do
		data.pets[name] = (data.pets[name] or 0) + count
	end
	sync(player)
end

function SessionData.AddSpeed(player: Player, delta: number)
	local data = storage[player]
	if not data then
		return
	end
	data.speed = math.min(data.speed + delta, Config.Speed.Max)
	applySpeed(player, data.speed)
	sync(player)
end

function SessionData.AddMoney(player: Player, amount: number)
	local data = storage[player]
	if data then
		data.money += amount
		sync(player)
	end
end

-- Retire l'argent si le joueur en a assez. Retourne true si le paiement a réussi.
function SessionData.SpendMoney(player: Player, amount: number): boolean
	local data = storage[player]
	if not data or data.money < amount then
		return false
	end
	data.money -= amount
	sync(player)
	return true
end

function SessionData.HasUnlock(player: Player, id: string): boolean
	local data = storage[player]
	return data ~= nil and data.unlocks[id] == true
end

function SessionData.GiveUnlock(player: Player, id: string)
	local data = storage[player]
	if data then
		data.unlocks[id] = true
		sync(player)
	end
end

return SessionData
