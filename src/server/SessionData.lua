--!strict
-- SessionData : données de session en mémoire par joueur (pas de DataStore pour le MVP).
-- Chaque valeur est recopiée en attribut sur le Player (lu par le HUD) et dans les leaderstats :
--   RoundScore, Money, Upgrade_<Id> (niveau), Capacity (objets portables),
--   SpeedLevel/SpeedXP/SpeedXPNeeded/Speed (WalkSpeed), StrengthLevel/StrengthXP/StrengthXPNeeded/ThrowPower,
--   Pet_<PetId> (quantité possédée), Equipped ("id1,id2"), Multiplier, EquipSlots

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)

export type Stat = "Speed" | "Strength"

export type PlayerData = {
	levels: { [string]: number }, -- Stat -> niveau
	xp: { [string]: number }, -- Stat -> XP vers le prochain niveau
	roundScore: number,
	money: number,
	pets: { [string]: number }, -- petId -> quantité
	equipped: { string }, -- petIds équipés (un même Id peut apparaître plusieurs fois si possédé en plusieurs exemplaires)
	equipSlots: number,
	pity: number,
	upgrades: { [string]: number }, -- Id d'amélioration -> niveau acheté
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

local function statValue(stat: string, level: number): number
	local statConfig = if stat == "Speed" then Config.Training.Speed else Config.Training.Strength
	return statConfig.Base + statConfig.PerLevel * level
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

	for _, stat in ipairs({ "Speed", "Strength" }) do
		local level = data.levels[stat]
		player:SetAttribute(stat .. "Level", level)
		player:SetAttribute(stat .. "XP", data.xp[stat])
		player:SetAttribute(stat .. "XPNeeded", Config.GetXPNeeded(level))
	end
	player:SetAttribute("Speed", statValue("Speed", data.levels.Speed))
	player:SetAttribute("ThrowPower", statValue("Strength", data.levels.Strength))
	player:SetAttribute("Capacity", 1 + (data.upgrades.Backpack or 0))
	player:SetAttribute("RoundScore", data.roundScore)
	player:SetAttribute("Money", data.money)

	for petId, count in pairs(data.pets) do
		player:SetAttribute("Pet_" .. petId, count)
	end
	player:SetAttribute("Equipped", table.concat(data.equipped, ","))
	player:SetAttribute("EquipSlots", data.equipSlots)
	player:SetAttribute("Multiplier", SessionData.GetMultiplier(player))
	for id, level in pairs(data.upgrades) do
		player:SetAttribute("Upgrade_" .. id, level)
	end

	local money = getStat(player, "Argent")
	if money then
		money.Value = math.floor(data.money)
	end
	local points = getStat(player, "Points")
	if points then
		points.Value = math.floor(data.roundScore)
	end
end

local function onPlayerAdded(player: Player)
	storage[player] = {
		levels = { Speed = 0, Strength = 0 },
		xp = { Speed = 0, Strength = 0 },
		roundScore = 0,
		money = 0,
		pets = {},
		equipped = {},
		equipSlots = Config.Pets.EquipSlots,
		pity = 0,
		upgrades = {},
	}

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
			task.defer(applySpeed, player, statValue("Speed", data.levels.Speed))
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
	for petId, count in pairs(newPets) do
		if PetCatalog.ById[petId] then
			data.pets[petId] = (data.pets[petId] or 0) + count
		end
	end
	sync(player)
end

-- Multiplicateur de points : 1 + somme des bonus des familiers équipés (additif, pas multiplicatif).
function SessionData.GetMultiplier(player: Player): number
	local data = storage[player]
	if not data then
		return 1
	end
	local multiplier = 1
	for _, petId in ipairs(data.equipped) do
		local entry = PetCatalog.ById[petId]
		local rarity = entry and Config.Rarities[Config.RarityIndex[entry.Rarity]]
		if rarity then
			multiplier += rarity.Multiplier - 1
		end
	end
	return multiplier
end

local function countEquipped(data: PlayerData, petId: string): number
	local count = 0
	for _, id in ipairs(data.equipped) do
		if id == petId then
			count += 1
		end
	end
	return count
end

-- Équipe un exemplaire de petId. Retourne false si impossible (pas possédé, plus de place).
function SessionData.Equip(player: Player, petId: string): boolean
	local data = storage[player]
	if not data or #data.equipped >= data.equipSlots then
		return false
	end
	if countEquipped(data, petId) >= (data.pets[petId] or 0) then
		return false
	end
	table.insert(data.equipped, petId)
	sync(player)
	return true
end

-- Déséquipe un exemplaire de petId.
function SessionData.Unequip(player: Player, petId: string)
	local data = storage[player]
	if not data then
		return
	end
	local index = table.find(data.equipped, petId)
	if index then
		table.remove(data.equipped, index)
		sync(player)
	end
end

function SessionData.GetPity(player: Player): number
	local data = storage[player]
	return if data then data.pity else 0
end

function SessionData.SetPity(player: Player, pity: number)
	local data = storage[player]
	if data then
		data.pity = pity
	end
end

-- Ajoute de l'XP d'entraînement. Gère les passages de niveau (plusieurs d'un coup si besoin).
-- Retourne le nombre de niveaux gagnés.
function SessionData.AddTrainingXP(player: Player, stat: Stat, amount: number): number
	local data = storage[player]
	if not data then
		return 0
	end
	local statConfig = if stat == "Speed" then Config.Training.Speed else Config.Training.Strength
	local gained = 0
	data.xp[stat] += amount
	while data.levels[stat] < statConfig.MaxLevel and data.xp[stat] >= Config.GetXPNeeded(data.levels[stat]) do
		data.xp[stat] -= Config.GetXPNeeded(data.levels[stat])
		data.levels[stat] += 1
		gained += 1
	end
	if data.levels[stat] >= statConfig.MaxLevel then
		data.xp[stat] = 0
	end
	if stat == "Speed" and gained > 0 then
		applySpeed(player, statValue("Speed", data.levels.Speed))
	end
	sync(player)
	return gained
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

function SessionData.GetUpgradeLevel(player: Player, id: string): number
	local data = storage[player]
	return if data then data.upgrades[id] or 0 else 0
end

function SessionData.HasUnlock(player: Player, id: string): boolean
	return SessionData.GetUpgradeLevel(player, id) >= 1
end

function SessionData.SetUpgradeLevel(player: Player, id: string, level: number)
	local data = storage[player]
	if data then
		data.upgrades[id] = level
		sync(player)
	end
end

return SessionData
