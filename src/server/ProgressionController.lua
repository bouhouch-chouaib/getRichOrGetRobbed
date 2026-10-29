--!strict
-- ProgressionController : ce qui fait revenir les joueurs (Config.Daily, Config.Quests, Config.Codes, Config.Friends,
-- Config.Rebirth). Tout est décidé ici, le client demande seulement (Remotes.Bonus) :
--   ("Daily")           réclamer le cadeau du jour (un par jour UTC, série de 7 jours, un jour manqué = jour 1) ;
--   ("Quest", index)    réclamer une quête du jour terminée (server/Quests suit l'avancement) ;
--   ("Code", texte)     utiliser un code cadeau (une fois par joueur) ;
--   ("Rebirth")         faire un Rebirth (SessionData.Rebirth vérifie monde et argent).
-- Réponses (Remotes.BonusResult) : au joueur ("Daily", jour, argent, tirages), ("Quest", index, argent, tirages),
-- ("Code", ok, message, argent, tirages, bonbons?) ; à tout le serveur ("Rebirth", joueur, nombre).
-- Invitations (Config.Invite) : ("Invited", nom de l'ami, argent, tirages) au nouveau venu, ("Invite", nom du nouveau,
-- argent, tirages) à celui qui l'a invité.
-- Amis : l'attribut "FriendsHere" compte les amis Roblox présents sur le serveur (bonus de revenu, EconomyController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PullRewards = require(script.Parent.PullRewards)
local Quests = require(script.Parent.Quests)
local SessionData = require(script.Parent.SessionData)

local ProgressionController = {}

local lastRequest: { [Player]: number } = {}

-- Argent d'une récompense : des secondes du revenu actuel du joueur, avec un plancher.
local function moneyFor(player: Player, seconds: number, minimum: number): number
	local income = player:GetAttribute("Income")
	return math.floor(math.max((if type(income) == "number" then income else 0) * seconds, minimum))
end

-- Donne une récompense (argent + tirages gratuits). Retourne (argent, tirages).
local function grant(player: Player, reward: Config.BonusReward, minimum: number): (number, number)
	local money = if reward.Seconds then moneyFor(player, reward.Seconds, minimum) else 0
	if money > 0 then
		SessionData.AddMoney(player, money)
	end
	local pulls = reward.Pulls or 0
	if pulls > 0 then
		PullRewards.Grant(player, pulls, Perks.LuckBonus(player))
	end
	if reward.Candy then
		SessionData.AddCandy(player, reward.Candy) -- bonbons d'Halloween (codes HALLOWEEN, BOO)
	end
	return money, pulls
end

----------------------------------------------------------------------
-- Cadeau du jour
----------------------------------------------------------------------

-- Jour de la série qu'on peut réclamer aujourd'hui (1 à 7), ou nil si déjà réclamé aujourd'hui.
function ProgressionController.DailyDay(last: number, streak: number, today: number): number?
	if today <= last then
		return nil
	end
	if today == last + 1 and streak > 0 then
		return streak % #Config.Daily.Rewards + 1
	end
	return 1
end

local function claimDaily(player: Player)
	local data = SessionData.Get(player)
	if not data or not data.loaded then
		return
	end
	local today = Quests.Today()
	local day = ProgressionController.DailyDay(data.daily.last, data.daily.streak, today)
	if not day then
		return
	end
	data.daily = { last = today, streak = day }
	local money, pulls = grant(player, Config.Daily.Rewards[day], Config.Daily.MinMoney)
	SessionData.Sync(player)
	Remotes.BonusResult:FireClient(player, "Daily", day, money, pulls)
	print(string.format("[Bonus] %s : cadeau du jour %d (+%d$, %d tirage(s))", player.Name, day, money, pulls))
end

----------------------------------------------------------------------
-- Quêtes
----------------------------------------------------------------------

local function claimQuest(player: Player, index: unknown)
	local data = SessionData.Get(player)
	if not data or not data.loaded or type(index) ~= "number" then
		return
	end
	if Quests.Ensure(player) then
		SessionData.Sync(player)
		return -- les quêtes viennent de changer (nouveau jour) : celle demandée n'existe plus
	end
	local quest = data.quests.list[index]
	if not quest or quest.claimed or quest.progress < quest.goal then
		return
	end
	quest.claimed = true
	local reward = Config.Quests.Rewards[math.clamp(index, 1, #Config.Quests.Rewards)]
	local money, pulls = grant(player, reward, Config.Quests.MinMoney)
	SessionData.Sync(player)
	Remotes.BonusResult:FireClient(player, "Quest", index, money, pulls)
	print(string.format("[Bonus] %s : quête %s terminée (+%d$, %d tirage(s))", player.Name, quest.id, money, pulls))
end

----------------------------------------------------------------------
-- Codes cadeaux
----------------------------------------------------------------------

function ProgressionController.NormalizeCode(text: string): string
	return string.upper((string.gsub(text, "%s+", "")))
end

local function redeem(player: Player, text: unknown)
	local data = SessionData.Get(player)
	if not data or not data.loaded or type(text) ~= "string" or #text > 40 then
		return
	end
	local code = ProgressionController.NormalizeCode(text)
	local def = Config.Codes[code]
	if not def or (def.Until and os.time() > def.Until) then
		Remotes.BonusResult:FireClient(player, "Code", false, "CE CODE NE MARCHE PAS")
		return
	end
	local key = def.Same or code -- LAUNCH et LANCEMENT comptent comme un seul code
	if table.find(data.codes, key) then
		Remotes.BonusResult:FireClient(player, "Code", false, "CODE DÉJÀ UTILISÉ")
		return
	end
	table.insert(data.codes, key)
	local money, pulls = grant(player, def.Reward, Config.Daily.MinMoney)
	SessionData.Sync(player)
	Remotes.BonusResult:FireClient(player, "Code", true, code, money, pulls, def.Reward.Candy)
	print(string.format("[Bonus] %s : code %s (+%d$, %d tirage(s))", player.Name, code, money, pulls))
end

----------------------------------------------------------------------
-- Invitations récompensées
----------------------------------------------------------------------

-- Un joueur arrivé par l'invitation de inviterId : cadeau de bienvenue à sa 1re visite seulement (une fois par
-- compte), et cadeau à celui qui l'a invité s'il est sur ce serveur (une fois par nouvel ami, Config.Invite.MaxRewards
-- au plus). Retourne vrai si le nouveau venu a reçu son cadeau.
function ProgressionController.ApplyReferral(player: Player, inviterId: number): boolean
	local data = SessionData.Get(player)
	if not data or not data.loaded or data.referral.by ~= 0 or inviterId <= 0 or inviterId == player.UserId then
		return false
	end
	if not data.onboarding.newPlayer or data.onboarding.visits > 1 then
		return false -- déjà venu avant : pas un nouveau joueur amené par l'invitation
	end
	data.referral.by = inviterId
	local inviter = Players:GetPlayerByUserId(inviterId)
	local money, pulls = grant(player, Config.Invite.NewPlayerReward, Config.Daily.MinMoney)
	SessionData.Sync(player)
	Remotes.BonusResult:FireClient(player, "Invited", if inviter then inviter.DisplayName else "", money, pulls)
	print(string.format("[Invite] %s arrive invité par %d (+%d$, %d tirage(s))", player.Name, inviterId, money, pulls))
	local inviterData = inviter and SessionData.Get(inviter)
	if inviter and inviterData and inviterData.loaded and #inviterData.referral.invited < Config.Invite.MaxRewards
		and not table.find(inviterData.referral.invited, player.UserId) then
		table.insert(inviterData.referral.invited, player.UserId)
		local friendMoney, friendPulls = grant(inviter, Config.Invite.FriendReward, Config.Daily.MinMoney)
		SessionData.Sync(inviter)
		Remotes.BonusResult:FireClient(inviter, "Invite", player.DisplayName, friendMoney, friendPulls)
		print(string.format("[Invite] %s : ami invité n° %d (+%d$, %d tirage(s))", inviter.Name, #inviterData.referral.invited, friendMoney, friendPulls))
	end
	return true
end

local function checkReferral(player: Player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local inviterId = if ok and type(joinData) == "table" then (joinData :: any).ReferredByPlayerId else nil
	if type(inviterId) == "number" and inviterId > 0 then
		ProgressionController.ApplyReferral(player, inviterId)
	end
end

----------------------------------------------------------------------
-- Rebirth
----------------------------------------------------------------------

local function rebirth(player: Player)
	local count = SessionData.Rebirth(player)
	if not count then
		return
	end
	Remotes.BonusResult:FireAllClients("Rebirth", player, count)
	print(string.format("[Rebirth] %s : Rebirth %d (revenu x%d)", player.Name, count, Config.GetRebirthMultiplier(count)))
	task.spawn(SessionData.Save, player) -- un Rebirth ne doit pas se perdre si le serveur s'arrête
end

----------------------------------------------------------------------
-- Amis sur le serveur
----------------------------------------------------------------------

local friendships: { [Player]: { [Player]: boolean } } = {}

local function refreshFriends()
	for _, player in ipairs(Players:GetPlayers()) do
		local count = 0
		for other in pairs(friendships[player] or {}) do
			if other.Parent then
				count += 1
			end
		end
		player:SetAttribute("FriendsHere", count)
	end
end

-- Groupe Roblox (Config.Group) : attribut "InGroup" = membre (bonus de revenu dans EconomyController).
local function checkGroup(player: Player)
	if Config.Group.Id == 0 or player:GetAttribute("InGroup") == true then
		return
	end
	local ok, member = pcall(function()
		return player:IsInGroupAsync(Config.Group.Id)
	end)
	if ok and member and player.Parent then
		player:SetAttribute("InGroup", true)
	end
end

local function onPlayerAdded(player: Player)
	task.spawn(checkGroup, player)
	friendships[player] = friendships[player] or {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local ok, friends = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if ok and friends and player.Parent and other.Parent then
				friendships[player][other] = true
				friendships[other] = friendships[other] or {}
				friendships[other][player] = true
			end
		end
	end
	refreshFriends()
	-- Les quêtes du jour existent dès l'arrivée (affichées tout de suite dans la fenêtre Bonus). Puis le cadeau
	-- d'invitation, s'il est arrivé par l'invitation d'un ami.
	task.spawn(function()
		while player.Parent and not SessionData.IsLoaded(player) do
			task.wait(0.5)
		end
		if player.Parent and Quests.Ensure(player) then
			SessionData.Sync(player)
		end
		if player.Parent then
			checkReferral(player)
		end
	end)
end

----------------------------------------------------------------------

function ProgressionController.Init()
	Remotes.Bonus.OnServerEvent:Connect(function(player: Player, action: unknown, argument: unknown)
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.4 then
			return -- double clic : une seule demande
		end
		lastRequest[player] = now
		if action == "Daily" then
			claimDaily(player)
		elseif action == "Quest" then
			claimQuest(player, argument)
		elseif action == "Code" then
			redeem(player, argument)
		elseif action == "Rebirth" then
			rebirth(player)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastRequest[player] = nil
		friendships[player] = nil
		for _, set in pairs(friendships) do
			set[player] = nil
		end
		refreshFriends()
	end)
	-- Passage à minuit (UTC) : nouvelles quêtes pour les joueurs déjà là. Et un joueur qui vient de rejoindre le groupe
	-- (sans quitter le jeu) reçoit son bonus.
	task.spawn(function()
		local rounds = 0
		while true do
			task.wait(30)
			rounds += 1
			if rounds % 4 == 0 then
				for _, player in ipairs(Players:GetPlayers()) do
					task.spawn(checkGroup, player)
				end
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if Quests.Ensure(player) then
					SessionData.Sync(player)
				end
			end
		end
	end)
end

return ProgressionController
