--!strict
-- SessionData : données de chaque joueur, sauvegardées dans un DataStore (progression conservée).
-- Chargement à la connexion, sauvegarde à la déconnexion, toutes les AUTOSAVE secondes et à l'arrêt du serveur.
-- Si le chargement échoue, on ne sauvegarde JAMAIS ce joueur (pour ne pas écraser sa vraie progression).
-- Chaque valeur est recopiée en attribut sur le Player (lu par le HUD) et dans les leaderstats :
--   RoundScore, Money, Upgrade_<Id> (niveau), Capacity (objets portables),
--   SpeedLevel/SpeedXP/SpeedXPNeeded/Speed (WalkSpeed), StrengthLevel/StrengthXP/StrengthXPNeeded/ThrowPower,
--   Pet_<PetId> (quantité possédée), Equipped ("id1,id2"), Multiplier, EquipSlots

local DataStoreService = game:GetService("DataStoreService")
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
	loaded: boolean, -- true quand la sauvegarde a été lue avec succès (sinon on ne sauvegarde pas)
}

local SessionData = {}

local storage: { [Player]: PlayerData } = {}

----------------------------------------------------------------------
-- Sauvegarde (DataStore)
----------------------------------------------------------------------

local STORE_NAME = "PlayerData_v1" -- changer le nom remet toutes les progressions à zéro
local AUTOSAVE = 60
local RETRIES = 3

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[SessionData] DataStore indisponible : la progression ne sera PAS sauvegardée. " .. tostring(result))
	end
end

local function storeKey(player: Player): string
	return "u_" .. player.UserId
end

-- Ce qui est écrit dans le DataStore (le score de manche n'est pas sauvegardé).
local function serialize(data: PlayerData): { [string]: any }
	return {
		version = 1,
		levels = data.levels,
		xp = data.xp,
		money = data.money,
		pets = data.pets,
		equipped = data.equipped,
		pity = data.pity,
		upgrades = data.upgrades,
	}
end

local function withRetries<T>(action: () -> T): (boolean, T | string)
	local lastError = ""
	for attempt = 1, RETRIES do
		local ok, result = pcall(action)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		task.wait(attempt)
	end
	return false, lastError
end

local function savePlayer(player: Player)
	local data = storage[player]
	if not data or not data.loaded or not store then
		return
	end
	local payload = serialize(data)
	local currentStore = store :: DataStore
	local ok, err = withRetries(function()
		currentStore:SetAsync(storeKey(player), payload, { player.UserId })
		return true
	end)
	if not ok then
		warn(string.format("[SessionData] Échec de sauvegarde pour %s : %s", player.Name, tostring(err)))
	end
end

local function numberOr(value: any, default: number): number
	return if type(value) == "number" then value else default
end

-- Applique une sauvegarde lue sur les données du joueur (en validant chaque champ).
local function applySaved(data: PlayerData, saved: { [string]: any })
	if type(saved.levels) == "table" then
		data.levels.Speed = numberOr(saved.levels.Speed, 0)
		data.levels.Strength = numberOr(saved.levels.Strength, 0)
	end
	if type(saved.xp) == "table" then
		data.xp.Speed = numberOr(saved.xp.Speed, 0)
		data.xp.Strength = numberOr(saved.xp.Strength, 0)
	end
	data.money = numberOr(saved.money, 0) + data.money
	data.pity = numberOr(saved.pity, 0)
	if type(saved.pets) == "table" then
		for petId, count in pairs(saved.pets) do
			if type(petId) == "string" and PetCatalog.ById[petId] and type(count) == "number" and count > 0 then
				data.pets[petId] = (data.pets[petId] or 0) + math.floor(count)
			end
		end
	end
	if type(saved.upgrades) == "table" then
		for id, level in pairs(saved.upgrades) do
			if type(id) == "string" and type(level) == "number" then
				data.upgrades[id] = math.max(data.upgrades[id] or 0, math.floor(level))
			end
		end
	end
	if type(saved.equipped) == "table" then
		data.equipped = {}
		for _, petId in ipairs(saved.equipped) do
			if type(petId) == "string" and #data.equipped < data.equipSlots and (data.pets[petId] or 0) > 0 then
				table.insert(data.equipped, petId)
			end
		end
	end
end

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
		loaded = false,
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

	-- Chargement de la sauvegarde (asynchrone : le joueur peut déjà bouger pendant ce temps).
	task.spawn(function()
		if not store then
			return
		end
		local currentStore = store :: DataStore
		local ok, result = withRetries(function()
			return currentStore:GetAsync(storeKey(player))
		end)
		local data = storage[player]
		if not data then
			return -- le joueur est déjà parti
		end
		if not ok then
			warn(string.format("[SessionData] Chargement impossible pour %s : sa progression ne sera pas sauvegardée cette session. %s", player.Name, tostring(result)))
			return
		end
		if type(result) == "table" then
			applySaved(data, result)
		end
		data.loaded = true
		applySpeed(player, statValue("Speed", data.levels.Speed))
		sync(player)
		player:SetAttribute("DataLoaded", true)
	end)
end

function SessionData.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		savePlayer(player)
		storage[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Sauvegarde automatique régulière (en cas de crash du serveur).
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(savePlayer, player)
			end
		end
	end)

	-- Arrêt du serveur : on sauvegarde tout le monde avant la fermeture.
	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				savePlayer(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
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

-- Nombre d'exemplaires de petId non équipés (utilisables pour une fusion).
function SessionData.GetSpareCount(player: Player, petId: string): number
	local data = storage[player]
	if not data then
		return 0
	end
	local equipped = 0
	for _, id in ipairs(data.equipped) do
		if id == petId then
			equipped += 1
		end
	end
	return math.max(0, (data.pets[petId] or 0) - equipped)
end

-- Retire des familiers (jamais plus que les exemplaires non équipés). Retourne false si impossible.
function SessionData.RemovePets(player: Player, toRemove: { [string]: number }): boolean
	local data = storage[player]
	if not data then
		return false
	end
	for petId, count in pairs(toRemove) do
		if SessionData.GetSpareCount(player, petId) < count then
			return false
		end
	end
	for petId, count in pairs(toRemove) do
		local remaining = (data.pets[petId] or 0) - count
		if remaining > 0 then
			data.pets[petId] = remaining
		else
			data.pets[petId] = nil
			player:SetAttribute("Pet_" .. petId, 0)
		end
	end
	sync(player)
	return true
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
