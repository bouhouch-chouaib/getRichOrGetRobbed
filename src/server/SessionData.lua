--!strict
-- SessionData : données de chaque joueur, sauvegardées dans un DataStore (progression conservée).
-- Chargement à la connexion, sauvegarde à la déconnexion, toutes les AUTOSAVE secondes et à l'arrêt du serveur.
-- Si le chargement échoue, on ne sauvegarde JAMAIS ce joueur (pour ne pas écraser sa vraie progression).
-- Anti-duplication : une sauvegarde n'est ouverte que par un serveur à la fois (verrou de session, voir plus bas).
-- Chaque valeur est recopiée en attribut sur le Player (lu par le HUD) et dans les leaderstats :
--   RoundScore, Money, Upgrade_<Id> (niveau), Capacity (objets portables),
--   SpeedLevel/SpeedXP/SpeedXPNeeded/Speed (WalkSpeed), StrengthLevel/StrengthXP/StrengthXPNeeded/ThrowPower,
--   Pet_<PetId> (quantité possédée), Equipped ("id1,id2"), Multiplier, EquipSlots,
--   SpeedBonus/StrengthBonus (niveaux donnés par les familiers équipés, shared/PetStats),
--   Pity (tirages depuis le dernier Épique+), TotalPulls (tirages faits depuis le début : le rang, Config.Loot.Ranks),
--   Rebirths, DailyLast/DailyStreak (cadeau du jour), Quests (JSON des quêtes du jour), QuestsDay (server/ProgressionController)

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OnboardingAnalytics = require(script.Parent.OnboardingAnalytics)
local Config = require(ReplicatedStorage.Shared.Config)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local StarterJourney = require(ReplicatedStorage.Shared.StarterJourney)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Perks = require(ReplicatedStorage.Shared.Perks)
local PetStats = require(ReplicatedStorage.Shared.PetStats)
local PowerCap = require(ReplicatedStorage.Shared.PowerCap)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Stat = "Speed" | "Strength"

-- Quête du jour (server/Quests) : sorte (Config.Quests.Pool), objectif, avancement, récompense réclamée.
export type Quest = { id: string, goal: number, progress: number, claimed: boolean }

export type PlayerData = {
	levels: { [string]: number }, -- Stat -> niveau
	xp: { [string]: number }, -- Stat -> XP vers le prochain niveau
	roundScore: number,
	money: number,
	eggs: { EggIncubation.Egg }, -- récompenses en incubation, jamais utilisables comme familiers
	pets: { [string]: number }, -- petId -> quantité
	equipped: { string }, -- petIds équipés (un même Id peut apparaître plusieurs fois si possédé en plusieurs exemplaires)
	equipSlots: number,
	pity: number,
	-- Meilleure rareté obtenue soi-même (œufs éclos : tirages, fusion, capsule, récompenses) : plafond de revenu des
	-- familiers volés, échangés ou achetés (Config.PowerCap, shared/PowerCap).
	selfBest: number,
	totalPulls: number, -- tirages faits depuis le début (rang de tirage : Config.Loot.Ranks)
	upgrades: { [string]: number }, -- Id d'amélioration -> niveau acheté
	tutorialDone: boolean, -- tutoriel terminé (ou passé) : ne plus l'afficher
	keys: number, -- clés en réserve (Config.Keys, achetées en Robux)
	speedUps: number, -- accélérations payées sans œuf à accélérer : servent à la prochaine demande (Config.SpeedUp)
	tier: number, -- monde atteint (Config.Worlds), 1 = Prairie : le plus loin débloqué (bonus de revenu)
	world: number, -- monde où le joueur se trouve (déjà visité, <= tier) : l'apparence et la musique
	receipts: { string }, -- derniers achats Robux accordés (PurchaseId) : jamais deux fois le même (MonetizationController)
	indexClaimed: { string }, -- familiers dont la récompense d'Index a été réclamée (ils restent « découverts » même volés)
	rebirths: number, -- Rebirths faits (Config.Rebirth) : revenu x(1 + n), familiers en plus dans la base
	daily: { last: number, streak: number }, -- cadeau du jour : dernier jour réclamé (jour UTC), jour de la série (1 à 7)
	quests: { day: number, list: { Quest } }, -- quêtes du jour (refaites chaque jour UTC)
	codes: { string }, -- codes cadeaux déjà utilisés
	-- Invitations (Config.Invite) : by = UserId de qui l'a invité (0 = personne, cadeau de bienvenue déjà donné sinon),
	-- invited = UserIds des nouveaux amis qu'il a fait venir et pour lesquels il a été récompensé.
	referral: { by: number, invited: { number } },
	seenUpdate: number, -- dernière mise à jour annoncée au joueur (Config.Updates.Number, server/UpdateBoard)
	-- Familiers que le joueur a mis lui-même dans la base (dans l'ordre) ou retirés (shared/PetRoster).
	basePicks: { placed: { string }, removed: { string } },
	magnetEnabled: boolean,
	starter: StarterJourney.State,
	onboarding: OnboardingAnalytics.Progress,
	loaded: boolean, -- true quand la sauvegarde a été lue avec succès (sinon on ne sauvegarde pas)
}

local MAX_STAT = 2 ^ 53 -- valeur max affichée dans la liste des joueurs
local MAX_RECEIPTS = 100 -- on garde les 100 derniers achats (largement assez pour repérer un doublon)

local SessionData = {}

local storage: { [Player]: PlayerData } = {}
-- Appelés au départ d'un joueur, AVANT sa dernière sauvegarde (voir SessionData.OnLeaving).
local leavingCallbacks: { (Player) -> () } = {}

----------------------------------------------------------------------
-- Sauvegarde (DataStore)
----------------------------------------------------------------------

local AUTOSAVE = 60
local RETRIES = 3

-- Verrou de session (anti-duplication) : la sauvegarde note quel serveur l'a ouverte (champ `session`).
-- Un autre serveur ne peut pas la charger tant que ce verrou est tenu : il réessaie toutes les LOCK_RETRY s.
-- Le verrou est rafraîchi à chaque sauvegarde auto ; s'il n'a pas bougé depuis LOCK_STALE s, le serveur
-- qui le tenait est considéré comme planté et on le reprend. Au départ du joueur, le verrou est libéré.
local LOCK_STALE = AUTOSAVE * 3
local LOCK_RETRY = 3
local LOCK_MAX_WAIT = LOCK_STALE + 30 -- au-delà, le joueur est expulsé avec un message
local IS_STUDIO = RunService:IsStudio()
-- game.JobId est vide dans Studio : on se donne notre propre identifiant de serveur.
local SESSION_ID = HttpService:GenerateGUID(false)
-- "PlayerData_v4" en ligne, "PlayerData_v3_studio" dans Studio (voir Config.Save).
local STORE_NAME = if IS_STUDIO
	then "PlayerData_v" .. Config.Save.StudioVersion .. "_studio"
	else "PlayerData_v" .. Config.Save.Version

type SessionLock = {
	id: string, -- SESSION_ID du serveur qui a ouvert la sauvegarde
	job: string, -- game.JobId (pour le débogage)
	studio: boolean,
	time: number, -- os.time() du dernier rafraîchissement
}

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

local function storeKey(userId: number): string
	return "u_" .. userId
end

-- Snapshot des données (le score de manche n'est pas sauvegardé).
-- Copier les tables empêche un reçu ajouté pendant UpdateAsync de précéder sa récompense dans cette sauvegarde.
-- session = nil : la sauvegarde est libérée (le joueur a quitté ce serveur).
local function serialize(data: PlayerData, session: SessionLock?): { [string]: any }
	return {
		magnetEnabled = data.magnetEnabled,
		starter = table.clone(data.starter),
		onboarding = OnboardingAnalytics.Snapshot(data.onboarding),
		version = 2, -- 2 : ajout du verrou de session
		levels = table.clone(data.levels),
		xp = table.clone(data.xp),
		money = data.money,
		pets = table.clone(data.pets), -- snapshot cohérent avec la file d’œufs pendant un UpdateAsync
		eggs = table.clone(data.eggs),
		equipped = table.clone(data.equipped),
		pity = data.pity,
		selfBest = data.selfBest,
		totalPulls = data.totalPulls,
		upgrades = table.clone(data.upgrades),
		stationScale = 25, -- tapis et banc sur 25 niveaux (avant : 8, converti à la lecture)
		tutorialDone = data.tutorialDone,
		receipts = table.clone(data.receipts),
		keys = data.keys,
		speedUps = data.speedUps,
		tier = data.tier,
		world = data.world,
		indexClaimed = table.clone(data.indexClaimed),
		rebirths = data.rebirths,
		daily = table.clone(data.daily),
		quests = { day = data.quests.day, list = table.clone(data.quests.list) },
		codes = table.clone(data.codes),
		referral = { by = data.referral.by, invited = table.clone(data.referral.invited) },
		seenUpdate = data.seenUpdate,
		basePicks = { placed = table.clone(data.basePicks.placed), removed = table.clone(data.basePicks.removed) },
		session = session,
	}
end

local function newLock(): SessionLock
	return { id = SESSION_ID, job = game.JobId, studio = IS_STUDIO, time = os.time() }
end

-- Le verrou écrit dans une sauvegarde (nil si la sauvegarde est libre ou date d'avant le verrou).
local function readLock(saved: unknown): SessionLock?
	if type(saved) ~= "table" then
		return nil
	end
	local session = (saved :: { [string]: any }).session
	if type(session) ~= "table" or type(session.id) ~= "string" or type(session.time) ~= "number" then
		return nil
	end
	return { id = session.id, job = tostring(session.job), studio = session.studio == true, time = session.time }
end

-- Ce serveur peut-il ouvrir cette sauvegarde ? Oui si elle est libre, déjà à nous, ou abandonnée
-- (serveur planté). Dans Studio, on reprend aussi le verrou d'une partie de test précédente
-- (arrêter le test ne laisse pas toujours le temps de le libérer). Jamais celui d'un vrai serveur.
local function canOpen(lock: SessionLock?): boolean
	if not lock or lock.id == SESSION_ID then
		return true
	end
	if os.time() - lock.time > LOCK_STALE then
		return true
	end
	return IS_STUDIO and lock.studio
end

-- Une seule opération DataStore à la fois par joueur, dans l'ordre d'arrivée (file à tickets) : sinon une
-- sauvegarde auto en retard pourrait reverrouiller la sauvegarde après sa libération, ou un joueur qui revient
-- sur le même serveur pourrait recharger sa sauvegarde avant que celle de son départ soit écrite.
local nextTicket: { [number]: number } = {}
local serving: { [number]: number } = {}

local function lockKey(userId: number)
	local ticket = (nextTicket[userId] or 0) + 1
	nextTicket[userId] = ticket
	while (serving[userId] or 1) ~= ticket do
		task.wait(0.1)
	end
end

local function unlockKey(userId: number)
	local nextServed = (serving[userId] or 1) + 1
	if nextServed > (nextTicket[userId] or 0) then
		-- Plus personne dans la file : on oublie ce joueur.
		nextTicket[userId] = nil
		serving[userId] = nil
	else
		serving[userId] = nextServed
	end
end

local function withRetries<T>(action: () -> T): (boolean, T | string)
	local lastError = ""
	for attempt = 1, RETRIES do
		local ok, result = pcall(action)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		-- Studio sans "Enable Studio Access to API Services" : inutile de réessayer.
		-- (message différent selon l'appel : lecture "...is not allowed", écriture "...is not enabled")
		if string.find(lastError, "Studio access to APIs is not allowed", 1, true)
			or string.find(lastError, "API access is not enabled", 1, true)
		then
			warn("[SessionData] Sauvegarde désactivée dans Studio : Accueil > Paramètres du jeu > Sécurité > "
				.. "cocher \"Enable Studio Access to API Services\" (le jeu doit être publié).")
			return false, lastError
		end
		task.wait(attempt)
	end
	return false, lastError
end

-- Écrit la sauvegarde du joueur, seulement si ce serveur tient toujours son verrou.
-- release = true (départ du joueur, arrêt du serveur) : libère le verrou ; plus rien n'est écrit ensuite.
-- Retourne true si la sauvegarde a bien été écrite.
local function savePlayer(player: Player, release: boolean): boolean
	local data = storage[player]
	if not data or not data.loaded or not store then
		return false
	end
	local userId = player.UserId
	lockKey(userId)
	if not data.loaded then
		-- Déjà libérée (ou verrou perdu) pendant qu'on attendait notre tour.
		unlockKey(userId)
		return false
	end
	local payload = serialize(data, if release then nil else newLock())
	local currentStore = store :: DataStore
	local lostLock = false
	local ok, err = withRetries(function()
		lostLock = false
		currentStore:UpdateAsync(storeKey(userId), function(old: unknown)
			local lock = readLock(old)
			if not lock or lock.id ~= SESSION_ID then
				-- Un autre serveur a ouvert cette sauvegarde : surtout ne rien écraser.
				lostLock = true
				return nil
			end
			return payload, { userId }
		end)
		return true
	end)
	if release or lostLock then
		data.loaded = false
	end
	unlockKey(userId)

	if not ok then
		warn(string.format("[SessionData] Échec de sauvegarde pour %s : %s", player.Name, tostring(err)))
	elseif lostLock then
		warn(string.format("[SessionData] %s : sauvegarde ouverte par un autre serveur, plus aucune écriture ici.", player.Name))
		if not release and player.Parent then
			player:Kick("Ta partie a été ouverte sur un autre serveur. Reconnecte-toi pour continuer.")
		end
	end
	return ok and not lostLock
end

-- Rend la sauvegarde sans rien y changer d'autre (joueur parti pendant son chargement).
local function releaseLock(userId: number)
	local currentStore = store :: DataStore
	lockKey(userId)
	local ok, err = withRetries(function()
		currentStore:UpdateAsync(storeKey(userId), function(old: unknown)
			local lock = readLock(old)
			if type(old) ~= "table" or not lock or lock.id ~= SESSION_ID then
				return nil
			end
			local record = table.clone(old :: { [string]: any })
			record.session = nil
			return record, { userId }
		end)
		return true
	end)
	unlockKey(userId)
	if not ok then
		warn(string.format("[SessionData] Impossible de libérer la sauvegarde u_%d : %s", userId, tostring(err)))
	end
end

local function numberOr(value: any, default: number): number
	return if type(value) == "number" then value else default
end

-- Applique une sauvegarde lue sur les données du joueur (en validant chaque champ).
-- Index de rareté d'un familier (formes évoluées et mutées comprises), 0 s'il est inconnu.
local function rarityIndexOf(petId: string): number
	local entry = PetCatalog.ById[petId]
	return if entry then Config.RarityIndex[entry.Rarity] or 0 else 0
end

-- Un œuf vient d'éclore chez le joueur : sa rareté compte comme obtenue par lui-même (plafond de revenu).
local function raiseSelfBest(data: PlayerData, petId: string)
	data.selfBest = math.max(data.selfBest, rarityIndexOf(petId))
end

local function applySaved(data: PlayerData, saved: { [string]: any })
	data.magnetEnabled = saved.magnetEnabled == true
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
	data.totalPulls = math.max(0, math.floor(numberOr(saved.totalPulls, -1)))
	data.keys = math.max(math.floor(numberOr(saved.keys, 0)), 0) + data.keys
	data.speedUps = math.max(math.floor(numberOr(saved.speedUps, 0)), 0) + data.speedUps
	data.tier = math.clamp(math.floor(numberOr(saved.tier, 1)), 1, #Config.Worlds)
	data.world = math.clamp(math.floor(numberOr(saved.world, data.tier)), 1, data.tier)
	if type(saved.pets) == "table" then
		for savedId, count in pairs(saved.pets) do
			-- Les anciens Id (familiers renommés) sont convertis : le joueur garde ses familiers.
			local petId = if type(savedId) == "string" then PetCatalog.CurrentId(savedId) else nil
			if petId and PetCatalog.ById[petId] and type(count) == "number" and count > 0 then
				data.pets[petId] = (data.pets[petId] or 0) + math.floor(count)
			end
		end
	end
	data.eggs = EggIncubation.Merge(saved.eggs, data.eggs)
	if type(saved.selfBest) == "number" then
		data.selfBest = math.max(data.selfBest, math.clamp(math.floor(saved.selfBest), 0, #Config.Rarities))
	else
		-- Sauvegarde d'avant le plafond (25 oct.) : tout ce que le joueur possède compte comme obtenu par lui-même.
		for petId in pairs(data.pets) do
			data.selfBest = math.max(data.selfBest, rarityIndexOf(petId))
		end
		for _, egg in ipairs(data.eggs) do
			data.selfBest = math.max(data.selfBest, rarityIndexOf(egg.petId))
		end
	end
	if type(saved.upgrades) == "table" then
		for id, level in pairs(saved.upgrades) do
			if type(id) == "string" and type(level) == "number" then
				local value = math.floor(level)
				-- Ancienne échelle des stations (8 niveaux) : convertie vers les 25 niveaux actuels.
				if saved.stationScale == nil and (id == "Treadmill" or id == "Bench") and value > 0 then
					value = Config.Training.OldStationLevels[math.min(value, #Config.Training.OldStationLevels)]
				end
				data.upgrades[id] = math.max(data.upgrades[id] or 0, value)
			end
		end
		-- Anciennes armes (gant, poêle, bâton) : remplacées par la batte et le grappin.
		for oldId, newIds in pairs(Config.Weapons.OldWeapons) do
			if (data.upgrades[oldId] or 0) > 0 then
				data.upgrades[oldId] = nil
				for _, newId in ipairs(newIds) do
					data.upgrades[newId] = 1
				end
			end
		end
	end
	-- Les sauvegardes d'avant le tutoriel n'ont pas ce champ : un joueur qui a déjà joué (familiers ou argent)
	-- ne doit pas le revoir.
	local hasPlayed = (type(saved.pets) == "table" and next(saved.pets) ~= nil) or numberOr(saved.money, 0) > 0
	data.tutorialDone = data.tutorialDone or saved.tutorialDone == true or (saved.tutorialDone == nil and hasPlayed)
	if type(saved.receipts) == "table" then
		for _, purchaseId in ipairs(saved.receipts) do
			if type(purchaseId) == "string" and not table.find(data.receipts, purchaseId) then
				table.insert(data.receipts, purchaseId)
			end
		end
	end
	if type(saved.indexClaimed) == "table" then
		for _, savedId in ipairs(saved.indexClaimed) do
			local petId = if type(savedId) == "string" then PetCatalog.CurrentId(savedId) else nil
			if petId and PetCatalog.ById[petId] and not table.find(data.indexClaimed, petId) then
				table.insert(data.indexClaimed, petId)
			end
		end
	end
	data.rebirths = math.max(0, math.floor(numberOr(saved.rebirths, 0)))
	if type(saved.daily) == "table" then
		data.daily = {
			last = math.floor(numberOr(saved.daily.last, 0)),
			streak = math.clamp(math.floor(numberOr(saved.daily.streak, 0)), 0, #Config.Daily.Rewards),
		}
	end
	if type(saved.quests) == "table" and type(saved.quests.list) == "table" then
		local list: { Quest } = {}
		for _, quest in ipairs(saved.quests.list) do
			if type(quest) == "table" and type(quest.id) == "string" and type(quest.goal) == "number" then
				table.insert(list, {
					id = quest.id,
					goal = math.max(1, math.floor(quest.goal)),
					progress = math.max(0, math.floor(numberOr(quest.progress, 0))),
					claimed = quest.claimed == true,
				})
			end
		end
		data.quests = { day = math.floor(numberOr(saved.quests.day, 0)), list = list }
	end
	data.seenUpdate = math.max(0, math.floor(numberOr(saved.seenUpdate, 0)))
	if type(saved.referral) == "table" then
		data.referral.by = math.max(0, math.floor(numberOr(saved.referral.by, 0)))
		if type(saved.referral.invited) == "table" then
			for _, userId in ipairs(saved.referral.invited) do
				if type(userId) == "number" and not table.find(data.referral.invited, userId) then
					table.insert(data.referral.invited, userId)
				end
			end
		end
	end
	if type(saved.codes) == "table" then
		for _, code in ipairs(saved.codes) do
			if type(code) == "string" and not table.find(data.codes, code) then
				table.insert(data.codes, code)
			end
		end
	end
	if type(saved.basePicks) == "table" then
		for _, field in ipairs({ "placed", "removed" }) do
			local list = saved.basePicks[field]
			if type(list) == "table" then
				for _, savedId in ipairs(list) do
					local petId = if type(savedId) == "string" then PetCatalog.CurrentId(savedId) else nil
					if petId and PetCatalog.ById[petId] and not table.find(data.basePicks[field], petId) then
						table.insert(data.basePicks[field], petId)
					end
				end
			end
		end
	end
	if saved.totalPulls == nil then
		local owned = 0
		for _, count in pairs(data.pets) do
			owned += count
		end
		data.totalPulls = owned -- sauvegarde d'avant le rang : chaque familier possédé compte comme un tirage fait
	end
	if type(saved.equipped) == "table" then
		data.equipped = {}
		-- On garde jusqu'au maximum possible (avec le passe "Équipement +2") : la vérification des passes peut
		-- finir après le chargement ; le surplus éventuel est retiré ensuite (refreshPerks).
		local maxSlots = Config.Pets.EquipSlots + Config.Monetization.ExtraEquipSlots
		for _, savedId in ipairs(saved.equipped) do
			local petId = if type(savedId) == "string" then PetCatalog.CurrentId(savedId) else nil
			if petId and #data.equipped < maxSlots and (data.pets[petId] or 0) > 0 then
				table.insert(data.equipped, petId)
			end
		end
	end
end

-- Places d'équipement selon les passes (Perks) ; retire les familiers équipés en trop.
local function refreshPerks(player: Player, data: PlayerData)
	data.equipSlots = Config.Pets.EquipSlots + Perks.ExtraEquipSlots(player)
	while #data.equipped > data.equipSlots do
		table.remove(data.equipped)
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

-- Valeur d'une stat = niveau d'entraînement + niveaux donnés par les familiers équipés (shared/PetStats).
local function statValue(data: PlayerData, stat: string): number
	local statConfig = if stat == "Speed" then Config.Training.Speed else Config.Training.Strength
	local bonus = PetStats.Sum(data.equipped)
	local level = data.levels[stat] + (if stat == "Speed" then bonus.Speed else bonus.Strength)
	return statConfig.Base + statConfig.PerLevel * level
end

-- WalkSpeed = vitesse d'entraînement × attribut "SpeedMultiplier" du joueur (ex. ralenti pendant un vol).
local function applySpeed(player: Player, speed: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local multiplier = player:GetAttribute("SpeedMultiplier")
		humanoid.WalkSpeed = speed * (if type(multiplier) == "number" then multiplier else 1)
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
	player:SetAttribute("Speed", statValue(data, "Speed"))
	player:SetAttribute("ThrowPower", statValue(data, "Strength"))
	player:SetAttribute("Capacity", 1 + (data.upgrades.Backpack or 0) + Perks.ExtraCapacity(player))
	player:SetAttribute("RoundScore", data.roundScore)
	player:SetAttribute("Money", data.money)

	for petId, count in pairs(data.pets) do
		player:SetAttribute("Pet_" .. petId, count)
	end
	local eggCount, nextHatch = 0, math.huge
	for _, egg in ipairs(data.eggs) do
		eggCount += egg.count
		if not egg.evolve then -- l'œuf de la machine d'évolution n'éclot pas tout seul
			nextHatch = math.min(nextHatch, egg.readyAt)
		end
	end
	player:SetAttribute("EggCount", eggCount)
	player:SetAttribute("NextHatchAt", if eggCount > 0 then nextHatch else 0)
	player:SetAttribute("Equipped", table.concat(data.equipped, ","))
	local bonus = PetStats.Sum(data.equipped)
	player:SetAttribute("SpeedBonus", bonus.Speed)
	player:SetAttribute("StrengthBonus", bonus.Strength)
	player:SetAttribute("EquipSlots", data.equipSlots)
	player:SetAttribute("StarterEggGiven", data.starter.eggId ~= nil)
	player:SetAttribute("StarterBonusPaid", data.starter.bonusPaid)
	player:SetAttribute("NewcomerProtectedUntil", data.starter.protectionUntil)
	player:SetAttribute("MagnetEnabled", data.magnetEnabled)
	player:SetAttribute("BaseCapacity", Config.GetIncomeSlots(data.rebirths))
	player:SetAttribute("TutorialDone", data.tutorialDone)
	player:SetAttribute("Keys", data.keys)
	player:SetAttribute("SpeedUps", data.speedUps)
	player:SetAttribute("Tier", data.tier)
	player:SetAttribute("World", data.world)
	player:SetAttribute("IndexClaimed", table.concat(data.indexClaimed, ","))
	player:SetAttribute("Pity", data.pity)
	player:SetAttribute("SelfBest", if data.loaded then data.selfBest else nil)
	player:SetAttribute("TotalPulls", data.totalPulls)
	player:SetAttribute("Multiplier", SessionData.GetMultiplier(player))
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("DailyLast", data.daily.last)
	player:SetAttribute("DailyStreak", data.daily.streak)
	player:SetAttribute("QuestsDay", data.quests.day)
	player:SetAttribute("Quests", HttpService:JSONEncode(data.quests.list))
	for id, level in pairs(data.upgrades) do
		player:SetAttribute("Upgrade_" .. id, level)
	end

	-- Argent en nombre entier dans la liste des joueurs : Roblox la trie (le plus riche en haut) mais n'abrège pas.
	-- Plafonné pour rester exact (au-delà de 2^53, les nombres à virgule perdent les unités).
	local money = getStat(player, "Argent")
	if money then
		money.Value = math.clamp(math.floor(data.money), 0, MAX_STAT)
	end
	local points = getStat(player, "Points")
	if points then
		points.Value = math.floor(data.roundScore)
	end
	local rebirths = getStat(player, "Rebirth")
	if rebirths then
		rebirths.Value = data.rebirths
	end
end

-- Charge la sauvegarde en prenant son verrou. Si elle est encore ouverte sur un autre serveur (le joueur
-- vient d'en partir et sa dernière sauvegarde n'est pas finie), on réessaie toutes les LOCK_RETRY s.
-- Pendant ce temps le joueur joue déjà : ce qu'il gagne est ajouté à sa sauvegarde quand elle arrive.
local function loadPlayer(player: Player)
	if not store then
		return
	end
	local currentStore = store :: DataStore
	local userId = player.UserId
	local started = os.clock()
	while true do
		local saved: unknown = nil
		local blocked = false
		lockKey(userId)
		local ok, result = withRetries(function()
			saved, blocked = nil, false
			currentStore:UpdateAsync(storeKey(userId), function(old: unknown)
				if not canOpen(readLock(old)) then
					blocked = true
					return nil
				end
				saved = old
				local record: { [string]: any } = if type(old) == "table" then table.clone(old :: { [string]: any }) else { version = 2 }
				record.session = newLock()
				return record, { userId }
			end)
			return true
		end)
		unlockKey(userId)

		local data = storage[player]
		if not ok then
			if data then
				warn(string.format("[SessionData] Chargement impossible pour %s : sa progression ne sera pas sauvegardée cette session. %s", player.Name, tostring(result)))
			end
			return
		end
		if not blocked then
			if not data then
				releaseLock(userId) -- parti pendant le chargement
				return
			end
			if type(saved) == "table" then
				applySaved(data, saved :: { [string]: any })
			end
			data.starter = StarterJourney.Restore(if type(saved) == "table" then (saved :: { [string]: any }).starter else nil, saved == nil)
			data.onboarding = OnboardingAnalytics.Restore(if type(saved) == "table" then (saved :: { [string]: any }).onboarding else nil, saved == nil)
			refreshPerks(player, data)
			-- Résumé d'absence (client/NextGoals) : œufs prêts à éclore et tentatives de la capsule arrivées pendant
			-- l'absence (les œufs et la capsule avancent hors ligne) : la raison de revenir.
			local readyEggs, attempts, time = 0, 0, os.time()
			for _, egg in ipairs(data.eggs) do
				if egg.evolve then
					attempts += if not egg.evolve.done and egg.evolve.nextAt <= time then 1 else 0
				elseif egg.readyAt <= time then
					readyEggs += egg.count
				end
			end
			player:SetAttribute("AwaySummary", if readyEggs + attempts > 0 then readyEggs .. "," .. attempts else nil)
			data.loaded = true
			OnboardingAnalytics.Loaded(player, data.onboarding)
			applySpeed(player, statValue(data, "Speed"))
			sync(player)
			player:SetAttribute("SaveWaiting", nil)
			player:SetAttribute("DataLoaded", true)
			if data.onboarding.reached.Pickup then SessionData.GrantStarterEgg(player) end
			return
		end
		if not data then
			return -- parti pendant l'attente
		end
		if not player:GetAttribute("SaveWaiting") then
			player:SetAttribute("SaveWaiting", true)
			print(string.format("[SessionData] Sauvegarde de %s encore ouverte sur un autre serveur : on attend qu'elle se libère.", player.Name))
		end
		if os.clock() - started > LOCK_MAX_WAIT then
			player:Kick("Ta sauvegarde est encore ouverte sur un autre serveur. Réessaie dans quelques minutes.")
			return
		end
		task.wait(LOCK_RETRY)
	end
end

local function onPlayerAdded(player: Player)
	OnboardingAnalytics.Joined(player)
	storage[player] = {
		levels = { Speed = 0, Strength = 0 },
		xp = { Speed = 0, Strength = 0 },
		roundScore = 0,
		money = 0,
		pets = {},
		eggs = {},
		equipped = {},
		equipSlots = Config.Pets.EquipSlots,
		pity = 0,
		selfBest = 0,
		totalPulls = 0,
		upgrades = {},
		tutorialDone = false,
		keys = 0,
		speedUps = 0,
		tier = 1,
		world = 1,
		receipts = {},
		indexClaimed = {},
		rebirths = 0,
		daily = { last = 0, streak = 0 },
		quests = { day = 0, list = {} },
		codes = {},
		referral = { by = 0, invited = {} },
		seenUpdate = 0,
		basePicks = { placed = {}, removed = {} },
		magnetEnabled = false,
		starter = StarterJourney.Restore(nil, false),
		onboarding = OnboardingAnalytics.Restore(nil, false),
		loaded = false,
	}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local moneyStat = Instance.new("IntValue")
	moneyStat.Name = "Argent"
	moneyStat.Parent = leaderstats
	local pointsStat = Instance.new("IntValue")
	pointsStat.Name = "Points"
	pointsStat.Parent = leaderstats
	local rebirthStat = Instance.new("IntValue")
	rebirthStat.Name = "Rebirth"
	rebirthStat.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function()
		local data = storage[player]
		if data then
			-- Le Humanoid est créé avec le personnage : on attend la frame suivante par sécurité.
			task.defer(applySpeed, player, statValue(data, "Speed"))
		end
	end)

	sync(player)

	-- Chargement de la sauvegarde (asynchrone : le joueur peut déjà bouger pendant ce temps).
	task.spawn(loadPlayer, player)
end

function SessionData.Init()
	Remotes.TutorialDone.OnServerEvent:Connect(function(player: Player, skipped: unknown)
		if player:GetAttribute("DataLoaded") ~= true then return end
		OnboardingAnalytics.Dismissed(player, skipped)
		SessionData.SetTutorialDone(player)
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		-- Ce qui doit encore modifier son profil (ex. vol en cours) passe avant la dernière sauvegarde.
		for _, callback in ipairs(leavingCallbacks) do
			local ok, err = pcall(function()
				callback(player)
			end)
			if not ok then
				warn("[SessionData] Erreur au départ de " .. player.Name .. " : " .. tostring(err))
			end
		end
		OnboardingAnalytics.Leaving(player)
		savePlayer(player, true)
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
				task.spawn(savePlayer, player, false)
			end
		end
	end)

	-- Arrêt du serveur : on sauvegarde tout le monde avant la fermeture.
	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				OnboardingAnalytics.Leaving(player)
				savePlayer(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

-- callback(player) est appelé au départ du joueur, juste AVANT sa dernière sauvegarde : ses données sont encore là
-- et toute modification faite dedans (sans attendre) est enregistrée. Ne doit pas bloquer (pas de wait).
function SessionData.OnLeaving(callback: (Player) -> ())
	table.insert(leavingCallbacks, callback)
end

function SessionData.Get(player: Player): PlayerData?
	return storage[player]
end

-- true si la sauvegarde du joueur est chargée et sera écrite. Indispensable avant tout transfert entre joueurs :
-- modifier un profil non chargé (jamais sauvegardé) créerait une copie.
function SessionData.IsLoaded(player: Player): boolean
	local data = storage[player]
	return data ~= nil and data.loaded
end

-- Sauvegarde tout de suite (sans attendre la sauvegarde auto). Bloque jusqu'à la fin de l'écriture.
function SessionData.Save(player: Player): boolean
	return savePlayer(player, false)
end

-- Choix du joueur pour sa base (shared/PetRoster) : placed = liste dans l'ordre, removed = ensemble.
function SessionData.GetBasePicks(player: Player): ({ string }, { [string]: boolean })
	local data = storage[player]
	local removed: { [string]: boolean } = {}
	if not data then
		return {}, removed
	end
	for _, petId in ipairs(data.basePicks.removed) do
		removed[petId] = true
	end
	return data.basePicks.placed, removed
end

-- Met un familier possédé dans la base (wanted = true) ou l'en retire. slots = places de la base. Sans attente.
-- Retourne (ok, raison) ; raison "Full" : toutes les places sont déjà des familiers choisis par le joueur.
function SessionData.SetInBase(player: Player, petId: string, wanted: boolean, slots: number): (boolean, string?)
	local data = storage[player]
	if not data or not data.loaded or not PetCatalog.ById[petId] then
		return false, nil
	end
	local picks = data.basePicks
	-- Les familiers qu'il n'a plus (volés, fusionnés...) sont oubliés.
	for _, field in ipairs({ "placed", "removed" }) do
		local list = picks[field]
		for index = #list, 1, -1 do
			if (data.pets[list[index]] or 0) <= 0 then
				table.remove(list, index)
			end
		end
	end
	local placedAt = table.find(picks.placed, petId)
	local removedAt = table.find(picks.removed, petId)
	if wanted then
		if (data.pets[petId] or 0) <= 0 then
			return false, nil
		end
		if not placedAt then
			if #picks.placed >= slots then
				return false, "Full"
			end
			table.insert(picks.placed, petId)
		end
		if removedAt then
			table.remove(picks.removed, removedAt)
		end
	else
		if placedAt then
			table.remove(picks.placed, placedAt)
		end
		if not removedAt then
			table.insert(picks.removed, petId)
		end
	end
	return true, nil
end

-- Recopie les données vers les attributs (après une modification faite par un autre module via SessionData.Get).
function SessionData.Sync(player: Player)
	sync(player)
end

-- Un passe vient d'être détecté ou acheté : places d'équipement, sac, etc. sont recalculés.
function SessionData.RefreshPerks(player: Player)
	local data = storage[player]
	if data then
		refreshPerks(player, data)
		sync(player)
	end
end

-- Achats Robux déjà accordés (voir MonetizationController.ProcessReceipt).
function SessionData.HasReceipt(player: Player, purchaseId: string): boolean
	local data = storage[player]
	return data ~= nil and table.find(data.receipts, purchaseId) ~= nil
end

function SessionData.AddReceipt(player: Player, purchaseId: string)
	local data = storage[player]
	if data and not table.find(data.receipts, purchaseId) then
		table.insert(data.receipts, purchaseId)
		while #data.receipts > MAX_RECEIPTS do
			table.remove(data.receipts, 1)
		end
	end
end

-- Monde atteint (Config.Worlds).
-- Monde où se trouve le joueur (il peut retourner dans un monde déjà débloqué) : ses familiers exclusifs peuvent sortir.
function SessionData.GetWorld(player: Player): number
	local data = storage[player]
	return if data then data.world else 1
end

function SessionData.GetTier(player: Player): number
	local data = storage[player]
	return if data then data.tier else 1
end

-- Voyage au monde suivant : paie son prix. Retourne le nouveau monde, ou nil si impossible.
function SessionData.AdvanceTier(player: Player): number?
	local data = storage[player]
	if not data or not data.loaded or data.tier >= #Config.Worlds then
		return nil
	end
	local price = Config.Worlds[data.tier + 1].Price
	if data.money < price then
		return nil
	end
	data.money -= price
	data.tier += 1
	data.world = data.tier -- on arrive dans le nouveau monde
	sync(player)
	return data.tier
end

-- Rebirth (Config.Rebirth) : il faut avoir atteint le dernier monde et payer le prix. On repart en Prairie avec 0 $ et
-- les améliorations de la Boutique à zéro (sauf Config.Rebirth.KeepShopItems) ; familiers, œufs, entraînement, clés
-- et achats Robux restent. Sans attente. Retourne le nouveau nombre de Rebirths, ou nil si impossible.
function SessionData.Rebirth(player: Player): number?
	local data = storage[player]
	if not data or not data.loaded or data.tier < Config.Rebirth.RequiredTier then
		return nil
	end
	if data.money < Config.GetRebirthPrice(data.rebirths) then
		return nil
	end
	data.rebirths += 1
	data.money = 0
	data.tier = 1
	data.world = 1
	for _, item in ipairs(Config.Shop) do
		if not Config.Rebirth.KeepShopItems[item.Id] and (data.upgrades[item.Id] or 0) > 0 then
			data.upgrades[item.Id] = 0
		end
	end
	sync(player)
	return data.rebirths
end

function SessionData.GetRebirths(player: Player): number
	local data = storage[player]
	return if data then data.rebirths else 0
end

-- Retour dans un monde déjà visité (gratuit). Retourne true si le joueur a changé de monde.
function SessionData.SetWorld(player: Player, world: number): boolean
	local data = storage[player]
	if not data or not data.loaded or world ~= math.floor(world) or world < 1 or world > data.tier or world == data.world then
		return false
	end
	data.world = world
	sync(player)
	return true
end

-- Clés (Config.Keys), achetées en Robux : jamais refusées ni plafonnées.
function SessionData.GetKeys(player: Player): number
	local data = storage[player]
	return if data then data.keys else 0
end

function SessionData.AddKeys(player: Player, amount: number)
	local data = storage[player]
	if data then
		data.keys += amount
		sync(player)
	end
end

function SessionData.SpendKey(player: Player): boolean
	local data = storage[player]
	if not data or not data.loaded or data.keys < 1 then
		return false
	end
	data.keys -= 1
	sync(player)
	return true
end

-- Tutoriel terminé ou passé (demandé par le client : sans enjeu, aucune vérification nécessaire).
function SessionData.SetTutorialDone(player: Player)
	local data = storage[player]
	if data and not data.tutorialDone then
		data.tutorialDone = true
		sync(player)
	end
end

-- Index : récompense d'un familier découvert (possédé au moins une fois), une seule fois par familier.
-- Retourne l'argent gagné (0 si rien à réclamer).
function SessionData.ClaimIndex(player: Player, petId: string): number
	local data = storage[player]
	if not data or not data.loaded or not PetCatalog.ById[petId] or PetCatalog.ById[petId].Mutation then
		return 0 -- les mutations (secrètes) n'ont pas de récompense d'Index
	end
	if table.find(data.indexClaimed, petId) or (data.pets[petId] or 0) <= 0 then
		return 0
	end
	table.insert(data.indexClaimed, petId)
	local reward = Config.GetIndexReward(petId, PowerCap.Max(data.selfBest)) -- un familier bridé rapporte bridé
	data.money += reward
	sync(player)
	return reward
end

-- Réapplique la vitesse de marche (après un changement de l'attribut "SpeedMultiplier").
function SessionData.RefreshSpeed(player: Player)
	local data = storage[player]
	if data then
		applySpeed(player, statValue(data, "Speed"))
	end
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

-- These methods never yield: a hatch removes eggs and credits pets in one transaction.
function SessionData.AddEggs(player: Player, rewards: { [string]: number })
	local data = storage[player]
	if not data then return end
	local time = os.time()
	for petId, count in pairs(rewards) do
		local egg = EggIncubation.Create(petId, count, time, HttpService:GenerateGUID(false))
		if egg then
			table.insert(data.eggs, egg)
			OnboardingAnalytics.Mark(player, "EggReceived")
		end
	end
	sync(player)
end

-- Appelé uniquement après un ramassage validé (ou sa reprise après chargement).
function SessionData.GrantStarterEgg(player: Player): boolean
	local data = storage[player]
	if not data or not data.loaded or not data.onboarding.reached.Pickup then return false end
	local egg = StarterJourney.Grant(data.starter, os.time(), HttpService:GenerateGUID(false))
	if not egg then return false end
	table.insert(data.eggs, egg)
	OnboardingAnalytics.Mark(player, "EggReceived")
	sync(player)
	return true
end

function SessionData.IsNewcomerProtected(player: Player): boolean
	local data = storage[player]
	return data ~= nil and data.loaded and StarterJourney.IsProtected(data.starter, os.time())
end

function SessionData.EndNewcomerProtection(player: Player)
	local data = storage[player]
	if data and data.loaded and data.starter.eligible and not data.starter.protectionWaived then
		StarterJourney.EndProtection(data.starter)
		sync(player)
	end
end

-- Accélérer en Robux (Config.SpeedUp, server/SpeedUpController).
-- L'œuf `eggId` de ce joueur (couveuse ou capsule), nil s'il n'existe plus.
function SessionData.FindEgg(player: Player, eggId: string): EggIncubation.Egg?
	local data = storage[player]
	if not data then return nil end
	for _, egg in ipairs(data.eggs) do
		if egg.id == eggId then
			return egg
		end
	end
	return nil
end

-- L'œuf qui attend le plus longtemps (withCapsule : ceux de la capsule comptent aussi), nil si aucun n'attend.
function SessionData.LongestWait(player: Player, time: number, withCapsule: boolean): EggIncubation.Egg?
	local data = storage[player]
	if not data then return nil end
	local best: EggIncubation.Egg? = nil
	local bestLeft = 0
	for _, egg in ipairs(data.eggs) do
		local left = EggIncubation.WaitLeft(egg, time)
		if left > bestLeft and (withCapsule or not egg.evolve) then
			best, bestLeft = egg, left
		end
	end
	return best
end

-- Accélère l'œuf `eggId` (EggIncubation.SpeedUp). false s'il n'existe plus ou n'attend plus rien.
function SessionData.SpeedUpEgg(player: Player, eggId: string, time: number): boolean
	local data = storage[player]
	local egg = SessionData.FindEgg(player, eggId)
	if not data or not data.loaded or not egg or EggIncubation.WaitLeft(egg, time) <= 0 then
		return false
	end
	EggIncubation.SpeedUp(egg, time)
	sync(player)
	return true
end

function SessionData.GetSpeedUps(player: Player): number
	local data = storage[player]
	return if data then data.speedUps else 0
end

function SessionData.AddSpeedUps(player: Player, amount: number)
	local data = storage[player]
	if data then
		data.speedUps += amount
		sync(player)
	end
end

function SessionData.SpendSpeedUp(player: Player): boolean
	local data = storage[player]
	if not data or not data.loaded or data.speedUps < 1 then
		return false
	end
	data.speedUps -= 1
	sync(player)
	return true
end

function SessionData.GetEggs(player: Player): { EggIncubation.Egg }
	local data = storage[player]
	return if data then data.eggs else {}
end

function SessionData.GetRewardOwned(player: Player): { [string]: number }
	local data = storage[player]
	return if data then EggIncubation.Owned(data.pets, data.eggs) else {}
end

----------------------------------------------------------------------
-- Machine d'évolution (Config.Evolution) : un œuf y entre, évolue au fil du temps, le joueur l'ouvre quand il veut.
----------------------------------------------------------------------

local evolutionRng = Random.new()

-- Les œufs dans les chambres de la capsule (Config.GetCapsuleSlots), dans l'ordre d'entrée.
function SessionData.GetEvolvingList(player: Player): { EggIncubation.Egg }
	local data = storage[player]
	local list = {}
	if not data then return list end
	for _, egg in ipairs(data.eggs) do
		if egg.evolve then
			table.insert(list, egg)
		end
	end
	return list
end

-- Chambres de la capsule de ce joueur (+1 par Rebirth).
function SessionData.GetCapsuleSlots(player: Player): number
	local data = storage[player]
	return Config.GetCapsuleSlots(if data then data.rebirths else 0)
end

-- L'œuf montré par la capsule (nil si elle est vide) : celui qu'on peut ouvrir et qui n'évoluera plus, sinon le premier
-- qu'on peut ouvrir, sinon le premier entré. C'est lui que « Faire éclore » ouvre.
function SessionData.GetEvolving(player: Player): EggIncubation.Egg?
	local list = SessionData.GetEvolvingList(player)
	local time = os.time()
	local openable: EggIncubation.Egg? = nil
	for _, egg in ipairs(list) do
		if EggIncubation.CanOpen(egg, time) then
			if egg.evolve and egg.evolve.done then
				return egg
			end
			openable = openable or egg
		end
	end
	return openable or list[1]
end

local function newEvolve(egg: EggIncubation.Egg, time: number, tier: number): EggIncubation.Evolve
	return {
		stage = 1,
		maxStage = #Config.Evolution.Names, -- plus de plafond secret : chaque tentative est tirée au sort
		-- La capsule suit le niveau du joueur (monde le plus loin) : meilleures chances, plus rapide.
		nextAt = EggIncubation.FirstAttemptAt(egg, time, evolutionRng:NextNumber(), tier),
		done = false,
	}
end

-- Un doublon de sa meilleure rareté entre directement dans une chambre libre (Config.Evolution.DuplicatesToCapsule) au
-- lieu d'être vendu. Renvoie false si toutes les chambres sont prises.
function SessionData.AddCapsuleEgg(player: Player, petId: string, time: number): boolean
	local data = storage[player]
	if not data or not data.loaded or #SessionData.GetEvolvingList(player) >= SessionData.GetCapsuleSlots(player) then
		return false
	end
	local egg = EggIncubation.Create(petId, 1, time, HttpService:GenerateGUID(false))
	if not egg then
		return false
	end
	egg.evolve = newEvolve(egg, time, data.tier)
	table.insert(data.eggs, egg)
	sync(player)
	return true
end

-- Met dans la machine l'œuf de la clé donnée (« lot#n », shared/EggIncubation.UnitKey). Refusé si la machine est pleine,
-- si l'œuf n'existe plus ou s'il est déjà à l'heure d'éclore. Sans attente. L'œuf y finit son incubation normale, puis
-- tente d'évoluer (première tentative : EggIncubation.FirstAttemptAt).
function SessionData.StartEvolution(player: Player, key: string, time: number): boolean
	local data = storage[player]
	if not data or not data.loaded or #SessionData.GetEvolvingList(player) >= SessionData.GetCapsuleSlots(player) then
		return false -- toutes les chambres sont prises
	end
	local lotId, index = string.match(key, "^(.+)#(%d+)$")
	local unit = tonumber(index)
	if not lotId or not unit then
		return false
	end
	for position, egg in ipairs(data.eggs) do
		if egg.id == lotId and not egg.evolve and unit >= 1 and unit <= egg.count and egg.readyAt > time then
			local evolve = newEvolve(egg, time, data.tier)
			if egg.count == 1 then
				egg.evolve = evolve
			else
				-- Un seul exemplaire du lot entre dans la machine.
				egg.count -= 1
				table.insert(data.eggs, position + 1, {
					id = HttpService:GenerateGUID(false),
					petId = egg.petId,
					count = 1,
					startedAt = egg.startedAt,
					readyAt = egg.readyAt,
					evolve = evolve,
				})
			end
			sync(player)
			return true
		end
	end
	return false
end

-- Tentative d'évolution si c'est l'heure : "Evolved" ou "Maxed" (voir EggIncubation.TryEvolve), sinon nil.
-- roll : tirage imposé (tests) ; sinon au hasard.
function SessionData.TickEvolution(player: Player, time: number, roll: number?): string?
	local egg = SessionData.GetEvolving(player)
	if not egg then return nil end
	local data = storage[player]
	local result = EggIncubation.TryEvolve(egg, time, roll or evolutionRng:NextNumber(), if data then data.tier else 1)
	if result then
		sync(player)
	end
	return result
end

-- Une tentative pour chaque chambre dont c'est l'heure. Renvoie la liste des résultats (œuf, "Evolved" ou "Maxed").
function SessionData.TickEvolutions(player: Player, time: number): { { egg: EggIncubation.Egg, result: string } }
	local data = storage[player]
	local results = {}
	for _, egg in ipairs(SessionData.GetEvolvingList(player)) do
		local result = EggIncubation.TryEvolve(egg, time, evolutionRng:NextNumber(), if data then data.tier else 1)
		if result then
			table.insert(results, { egg = egg, result = result })
		end
	end
	if #results > 0 then
		sync(player)
	end
	return results
end

-- Ouvre l'œuf de la machine : le familier, à son stade, rejoint le joueur (sans attente). Renvoie son Id.
-- Refusé tant que son incubation normale n'est pas finie (sinon la capsule ferait éclore un œuf de 20 min tout de suite).
-- eggId : l'œuf d'une chambre précise (menu de la capsule, client/CapsuleMenu) ; sinon l'œuf montré par la capsule.
function SessionData.HatchEvolving(player: Player, time: number, eggId: string?): string?
	local data = storage[player]
	if not data or not data.loaded then return nil end
	local shown = if eggId == nil then SessionData.GetEvolving(player) else nil -- l'œuf montré par la capsule
	for index, egg in ipairs(data.eggs) do
		local evolve = egg.evolve
		if evolve and (egg == shown or (eggId ~= nil and egg.id == eggId)) then
			if not EggIncubation.CanOpen(egg, time) then
				return nil
			end
			table.remove(data.eggs, index)
			local petId = PetCatalog.Variant(egg.petId, evolve.stage)
			data.money += StarterJourney.Hatched(data.starter, egg.id)
			data.pets[petId] = (data.pets[petId] or 0) + 1
			raiseSelfBest(data, petId)
			OnboardingAnalytics.Mark(player, "Hatched")
			sync(player)
			return petId
		end
	end
	return nil
end

-- Fait éclore les œufs arrivés à échéance. Renvoie (petId -> quantité, lots éclos).
function SessionData.HatchEggs(player: Player, time: number): ({ [string]: number }, { EggIncubation.Egg })
	local data = storage[player]
	if not data or not data.loaded then return {}, {} end
	local pending, hatched, done = EggIncubation.Collect(data.eggs, time)
	if next(hatched) then
		data.eggs = pending
		for _, egg in ipairs(done) do data.money += StarterJourney.Hatched(data.starter, egg.id) end
		for petId, count in pairs(hatched) do
			data.pets[petId] = (data.pets[petId] or 0) + count
			raiseSelfBest(data, petId)
		end
		OnboardingAnalytics.Mark(player, "Hatched")
		sync(player)
	end
	return hatched, done
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
-- Familiers possédés (petId -> quantité). Lecture seule : ne pas modifier la table renvoyée.
function SessionData.GetOwnedPets(player: Player): { [string]: number }
	local data = storage[player]
	return if data then data.pets else {}
end

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
	applySpeed(player, statValue(data, "Speed")) -- ses stats comptent tout de suite
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
		applySpeed(player, statValue(data, "Speed"))
		sync(player)
	end
end

-- Meilleure rareté obtenue soi-même (Config.PowerCap) ; nil tant que la sauvegarde n'est pas chargée.
function SessionData.GetSelfBest(player: Player): number?
	local data = storage[player]
	return if data and data.loaded then data.selfBest else nil
end

function SessionData.GetPity(player: Player): number
	local data = storage[player]
	return if data then data.pity else 0
end

function SessionData.SetPity(player: Player, pity: number)
	local data = storage[player]
	if data then
		data.pity = pity
		player:SetAttribute("Pity", pity)
	end
end

-- Tirages faits depuis le début (le rang de tirage en dépend : Config.Loot.Ranks).
function SessionData.GetTotalPulls(player: Player): number
	local data = storage[player]
	return if data then data.totalPulls else 0
end

function SessionData.AddTotalPulls(player: Player, pulls: number)
	local data = storage[player]
	if data and pulls > 0 then
		data.totalPulls += pulls
		player:SetAttribute("TotalPulls", data.totalPulls)
	end
end

-- Familiers déjà découverts : possédés maintenant, ou récompense d'Index réclamée (même s'ils ont été volés).
function SessionData.GetDiscovered(player: Player): { [string]: boolean }
	local data = storage[player]
	local discovered: { [string]: boolean } = {}
	if data then
		for petId, count in pairs(data.pets) do
			if count > 0 then
				discovered[petId] = true
				local entry = PetCatalog.ById[petId]
				if entry and entry.BaseId then
					discovered[entry.BaseId] = true -- un familier évolué fait découvrir son espèce
				end
			end
		end
		for _, petId in ipairs(data.indexClaimed) do
			discovered[petId] = true
		end
	end
	return discovered
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
		applySpeed(player, statValue(data, "Speed"))
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

function SessionData.SetMagnetEnabled(player: Player, enabled: boolean): boolean
	local data = storage[player]
	if not data or not data.loaded or (enabled and Perks.MagnetLevel(player) <= 0 and not Perks.HasVacuum(player)) then return false end
	data.magnetEnabled = enabled
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
