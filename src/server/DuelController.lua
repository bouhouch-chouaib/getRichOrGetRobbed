--!strict
-- DuelController : duels de familiers entre deux joueurs (Config.Duel).
--
--   1. Défi : [F] « Défier » sur un joueur (bulle créée par client/DuelClient) -> Remotes.DuelAction("Request", cible).
--      La cible reçoit l'invitation (InviteTime secondes pour accepter).
--   2. Choix : chacun choisit un de ses familiers non équipés (DuelAction "Pick") ; les deux voient le choix de l'autre.
--      Raretés proches obligatoires (MaxRarityGap). Les deux doivent valider (DuelAction "Ready") ; changer de
--      familier annule les validations (double confirmation, pas d'arnaque).
--   3. Combat : les deux joueurs sont téléportés et immobilisés dans une arène qui flotte au-dessus du trou noir
--      (dessinée par client/DuelFx d'après les attributs du modèle Workspace.Duels.Duel_N). Les familiers frappent chacun
--      leur tour (dégâts aléatoires, coups critiques) ; chaque clic d'un joueur (DuelAction "Cheer") augmente les
--      dégâts du prochain coup de son familier.
--   4. Roue : le gagnant la tourne (case tirée ici, animée chez tout le monde) ; 1 case sur 8 = le familier de
--      l'adversaire. Puis retour des deux joueurs à leur place.
--   Abandon (départ, réinitialisation du personnage, ANNULER) : l'autre gagne s'il y avait combat, sinon le duel s'arrête.
--
-- Anti-duplication : pendant le duel, les deux familiers sont réservés dans leur base (cachés, ni volables ni
-- fusionnables) ; le transfert éventuel se fait en une étape (RemovePets puis AddPets), sauvegardes chargées, puis les
-- deux profils sont sauvegardés (le perdant d'abord).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DuelStats = require(ReplicatedStorage.Shared.DuelStats)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Perks = require(ReplicatedStorage.Shared.Perks)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local BasePetsController = require(script.Parent.BasePetsController)
local EconomyController = require(script.Parent.EconomyController)
local ItemInteraction = require(script.Parent.ItemInteraction)
local PowerController = require(script.Parent.PowerController)
local PullRewards = require(script.Parent.PullRewards)
local BadgeController = require(script.Parent.BadgeController)
local SessionData = require(script.Parent.SessionData)

local DuelController = {}

local DUEL = Config.Duel

type Side = {
	player: Player,
	petId: string?,
	ready: boolean,
	base: Model?, -- base où le familier est réservé pendant le combat
	hp: number,
	maxHp: number,
	attack: number,
	cheer: number, -- clics depuis le dernier coup
	cheerWindow: number, -- début de la seconde en cours (limite de clics par seconde)
	cheerInWindow: number,
	returnTo: CFrame?, -- où le joueur revient après le duel
}

type Duel = {
	a: Side,
	b: Side,
	state: string, -- "Invite", "Pick", "Fight", "Wheel", "Done"
	deadline: number,
	slot: number?,
	model: Model?,
}

local duelOf: { [Player]: Duel } = {}
local slotsUsed: { [number]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local folder: Folder
local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function newSide(player: Player): Side
	return {
		player = player,
		petId = nil,
		ready = false,
		base = nil,
		hp = 0,
		maxHp = 0,
		attack = 0,
		cheer = 0,
		cheerWindow = 0,
		cheerInWindow = 0,
		returnTo = nil,
	}
end

local function sideOf(duel: Duel, player: Player): (Side, Side)
	if duel.a.player == player then
		return duel.a, duel.b
	end
	return duel.b, duel.a
end

local function send(player: Player, ...: any)
	if player.Parent then
		Remotes.DuelEvent:FireClient(player, ...)
	end
end

-- Le joueur est-il libre pour un duel ? (pas déjà en duel, mains libres, vivant, a une base)
local function isFree(player: Player): boolean
	return duelOf[player] == nil
		and player:GetAttribute("InTrade") == nil
		and player:GetAttribute("CarryingPet") == nil
		and BaseManager.GetBase(player) ~= nil
		and SessionData.IsLoaded(player)
		and isAlive(player)
end

-- Exemplaires libres d'un familier (non équipés, ni portés ni en duel).
local function freeCount(player: Player, petId: string): number
	local base = BaseManager.GetBase(player)
	local reserved = if base then BasePetsController.GetReserved(base, petId) else 0
	return SessionData.GetSpareCount(player, petId) - reserved
end

-- Ce que chacun voit dans la fenêtre de choix : son choix, celui de l'autre, les validations.
local function sendState(duel: Duel)
	for _, side in ipairs({ duel.a, duel.b }) do
		local mine, other = sideOf(duel, side.player)
		send(side.player, "State", mine.petId, mine.ready, other.petId, other.ready, duel.deadline)
	end
end

local function setAttributes(duel: Duel)
	local model = duel.model
	if not model then
		return
	end
	model:SetAttribute("HpA", math.max(0, math.floor(duel.a.hp + 0.5)))
	model:SetAttribute("HpB", math.max(0, math.floor(duel.b.hp + 0.5)))
end

----------------------------------------------------------------------
-- Fin du duel
----------------------------------------------------------------------

-- Le joueur redescend de l'arène (le familier, lui, reste réservé jusqu'à la fin de la roue).
local function freePlayer(side: Side)
	local returnTo = side.returnTo
	if returnTo then
		-- Une seule fois : il était immobilisé dans l'arène, on le libère et on le remet à sa place.
		side.returnTo = nil
		local root = getRoot(side.player)
		if root then
			root.Anchored = false
			root.CFrame = returnTo
		end
	end
	if side.player.Parent then
		side.player:SetAttribute("InDuel", nil)
	end
end

local function releaseSide(side: Side)
	if side.base and side.petId then
		BasePetsController.Reserve(side.base, side.petId, -1)
	end
	side.base = nil
	freePlayer(side)
end

local function closeDuel(duel: Duel)
	if duel.state == "Done" then
		return
	end
	duel.state = "Done"
	for _, side in ipairs({ duel.a, duel.b }) do
		if duelOf[side.player] == duel then
			duelOf[side.player] = nil
		end
		releaseSide(side)
	end
	if duel.model then
		duel.model:Destroy()
	end
	if duel.slot then
		slotsUsed[duel.slot] = nil
	end
end

-- Duel arrêté avant le combat (refus, temps écoulé, annulation).
local function cancel(duel: Duel, reason: string)
	if duel.state ~= "Invite" and duel.state ~= "Pick" then
		return
	end
	send(duel.a.player, "Cancelled", reason)
	send(duel.b.player, "Cancelled", reason)
	closeDuel(duel)
end

----------------------------------------------------------------------
-- Roue et récompenses
----------------------------------------------------------------------

local function grantPulls(player: Player, pulls: number)
	PullRewards.Grant(player, pulls, Perks.LuckBonus(player))
end

-- Accorde la case `index` au gagnant. Renvoie le texte affiché (et false si c'est « Relance »).
local function grant(duel: Duel, winner: Side, loser: Side, index: number): (string, boolean)
	local slot = DUEL.Wheel[index]
	local player = winner.player
	if slot.Kind == "Respin" then
		return slot.Label, false
	end
	if slot.Kind == "Pet" and loser.petId then
		local petId = loser.petId
		local ok = loser.player.Parent ~= nil
			and SessionData.IsLoaded(loser.player)
			and SessionData.IsLoaded(player)
			and SessionData.RemovePets(loser.player, { [petId] = 1 })
		if ok then
			-- Le familier quitte la base du perdant : sa réservation n'a plus lieu d'être.
			if loser.base then
				BasePetsController.Reserve(loser.base, petId, -1)
				loser.base = nil
			end
			SessionData.AddPets(player, { [petId] = 1 })
			BasePetsController.Celebrate(player, { petId })
			task.spawn(function()
				SessionData.Save(loser.player)
				SessionData.Save(player)
			end)
			local entry = PetCatalog.ById[petId]
			Remotes.DuelEvent:FireAllClients("PetWon", player.DisplayName, loser.player.DisplayName, petId)
			return string.format("%s EST À TOI !", if entry then string.upper(entry.Name) else petId), true
		end
		-- Le perdant est parti ou n'a plus ce familier : la plus grosse case d'argent à la place.
		slot = { Kind = "Money", Label = "10 MIN D'ARGENT", Color = slot.Color, Seconds = 600 }
	end
	if slot.Kind == "Pulls" then
		grantPulls(player, slot.Pulls or 1)
		return slot.Label, true
	end
	local income = math.max(EconomyController.GetIncome(player), DUEL.MinIncome)
	local money = math.floor(income * (slot.Seconds or 120))
	SessionData.AddMoney(player, money)
	return "+" .. NumberFormat.money(money), true
end

-- Le gagnant tourne la roue (une case tirée au hasard, animée chez tout le monde), autant de fois que « Relance ».
local function spinWheel(duel: Duel, winner: Side, loser: Side)
	duel.state = "Wheel"
	for _ = 1, 5 do
		local index = rng:NextInteger(1, #DUEL.Wheel)
		-- Test dans Studio : workspace:SetAttribute("DuelForceWheel", 1) force la case (1 = le familier de l'adversaire).
		local forced = Workspace:GetAttribute("DuelForceWheel")
		if RunService:IsStudio() and type(forced) == "number" and DUEL.Wheel[forced] then
			index = forced
		end
		if duel.model then
			duel.model:SetAttribute("SpinIndex", index)
			duel.model:SetAttribute("SpinAt", now())
		end
		Remotes.DuelEvent:FireAllClients("Spin", duel.model, index)
		task.wait(DUEL.SpinTime)
		local text, final = grant(duel, winner, loser, index)
		print(string.format("[Duel] roue de %s : case %d (%s) -> %s", winner.player.Name, index, DUEL.Wheel[index].Kind, text))
		send(winner.player, "Reward", index, text)
		if final then
			break
		end
		task.wait(0.8)
	end
	task.wait(2.5)
	closeDuel(duel)
end

----------------------------------------------------------------------
-- Combat
----------------------------------------------------------------------

local function finishFight(duel: Duel, winner: Side, loser: Side, forfeit: boolean)
	if duel.state ~= "Fight" then
		return
	end
	duel.state = "Wheel"
	if duel.model then
		duel.model:SetAttribute("Winner", if winner == duel.a then "A" else "B")
	end
	Remotes.DuelEvent:FireAllClients("End", duel.model, if winner == duel.a then "A" else "B", forfeit)
	send(winner.player, "Won", loser.player.DisplayName)
	BadgeController.Award(winner.player, "DuelWin")
	send(loser.player, "Lost", winner.player.DisplayName)
	print(string.format("[Duel] %s (%s) bat %s (%s)%s", winner.player.Name, tostring(winner.petId), loser.player.Name,
		tostring(loser.petId), if forfeit then " par abandon" else ""))
	-- Le perdant redescend tout de suite ; le gagnant reste pour la roue.
	freePlayer(loser)
	if duelOf[loser.player] == duel then
		duelOf[loser.player] = nil
	end
	task.spawn(function()
		task.wait(2)
		if winner.player.Parent then
			spinWheel(duel, winner, loser)
		else
			closeDuel(duel)
		end
	end)
end

local function strike(duel: Duel, attacker: Side, target: Side, label: string)
	local cheer = math.min(DUEL.CheerMax, attacker.cheer * DUEL.CheerPerClick)
	attacker.cheer = 0
	local crit = rng:NextNumber() < DUEL.CritChance
	local damage = attacker.attack * (1 + rng:NextNumber(-DUEL.Spread, DUEL.Spread)) * (1 + cheer)
		* (if crit then DUEL.CritMultiplier else 1)
	damage = math.max(1, math.floor(damage + 0.5))
	target.hp -= damage
	setAttributes(duel)
	Remotes.DuelEvent:FireAllClients("Hit", duel.model, label, damage, crit, cheer)
end

local function runFight(duel: Duel)
	local started = os.clock()
	local turn = rng:NextInteger(0, 1)
	task.wait(2.5) -- présentation : « 3, 2, 1, COMBAT ! » chez les clients
	while duel.state == "Fight" do
		local attacker, target, label = duel.a, duel.b, "A"
		if turn % 2 == 1 then
			attacker, target, label = duel.b, duel.a, "B"
		end
		turn += 1
		strike(duel, attacker, target, label)
		if target.hp <= 0 then
			finishFight(duel, attacker, target, false)
			return
		end
		if os.clock() - started > DUEL.MaxTime then
			local aShare, bShare = duel.a.hp / duel.a.maxHp, duel.b.hp / duel.b.maxHp
			if aShare >= bShare then
				finishFight(duel, duel.a, duel.b, false)
			else
				finishFight(duel, duel.b, duel.a, false)
			end
			return
		end
		task.wait(DUEL.AttackInterval)
	end
end

local function slotCenter(slot: number): Vector3
	local offset = (slot - (DUEL.MaxArenas + 1) / 2) * DUEL.ArenaSpacing
	return DUEL.ArenaCenter + Vector3.new(offset, 0, 0)
end

-- Les deux ont validé : familiers réservés, joueurs téléportés dans une arène libre, combat.
local function startFight(duel: Duel)
	local slot: number? = nil
	for index = 1, DUEL.MaxArenas do
		if not slotsUsed[index] then
			slot = index
			break
		end
	end
	if not slot then
		cancel(duel, "ArenaFull")
		return
	end
	-- Dernière vérification : les deux familiers sont toujours libres.
	for _, side in ipairs({ duel.a, duel.b }) do
		if not side.petId or freeCount(side.player, side.petId) < 1 or not isAlive(side.player) then
			cancel(duel, "PetGone")
			return
		end
	end
	slotsUsed[slot] = true
	duel.slot = slot
	duel.state = "Fight"
	local center = slotCenter(slot)

	local model = Instance.new("Model")
	model.Name = "Duel_" .. slot
	model:SetAttribute("Center", center)
	model:SetAttribute("PlayerA", duel.a.player.DisplayName)
	model:SetAttribute("PlayerB", duel.b.player.DisplayName)
	model:SetAttribute("UserA", duel.a.player.UserId)
	model:SetAttribute("UserB", duel.b.player.UserId)
	for index, side in ipairs({ duel.a, duel.b }) do
		local label = if index == 1 then "A" else "B"
		local sign = if index == 1 then -1 else 1
		local petId = side.petId :: string
		local hp, attack = DuelStats.of(petId)
		side.hp, side.maxHp, side.attack = hp, hp, attack
		side.base = BaseManager.GetBase(side.player)
		if side.base then
			BasePetsController.Reserve(side.base, petId, 1)
		end
		model:SetAttribute("Pet" .. label, petId)
		model:SetAttribute("Max" .. label, hp)
		-- Téléporté sur son estrade, face à l'adversaire, immobilisé pendant le combat.
		ItemInteraction.ReleaseHeld(side.player)
		PowerController.Reveal(side.player)
		local root = getRoot(side.player)
		if root then
			side.returnTo = root.CFrame
			local spot = center + Vector3.new(sign * 30, 3.2, 0)
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z))
			root.Anchored = true
		end
		side.player:SetAttribute("InDuel", label)
	end
	model.Parent = folder
	duel.model = model
	setAttributes(duel)
	send(duel.a.player, "Start", model, "A")
	send(duel.b.player, "Start", model, "B")
	Remotes.DuelEvent:FireAllClients("Announce", duel.a.player.DisplayName, duel.b.player.DisplayName, duel.a.petId, duel.b.petId)
	print(string.format("[Duel] %s (%s) contre %s (%s)", duel.a.player.Name, tostring(duel.a.petId), duel.b.player.Name,
		tostring(duel.b.petId)))
	task.spawn(runFight, duel)
end

----------------------------------------------------------------------
-- Actions des joueurs
----------------------------------------------------------------------

local function onRequest(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player then
		return
	end
	local time = os.clock()
	if time - (lastRequest[player] or 0) < DUEL.RequestCooldown then
		send(player, "Cancelled", "Cooldown")
		return
	end
	lastRequest[player] = time
	if not isFree(player) then
		return
	end
	if not isFree(target) then
		send(player, "Cancelled", "Busy")
		return
	end
	local myRoot, theirRoot = getRoot(player), getRoot(target)
	if not myRoot or not theirRoot or (myRoot.Position - theirRoot.Position).Magnitude > DUEL.PromptDistance + 8 then
		return
	end
	local duel: Duel = { a = newSide(player), b = newSide(target), state = "Invite", deadline = now() + DUEL.InviteTime }
	duelOf[player] = duel
	duelOf[target] = duel
	send(target, "Invite", player, duel.deadline)
	send(player, "Waiting", target, duel.deadline)
end

local function onAnswer(player: Player, accept: boolean)
	local duel = duelOf[player]
	if not duel or duel.state ~= "Invite" or duel.b.player ~= player then
		return
	end
	if not accept then
		cancel(duel, "Declined")
		return
	end
	duel.state = "Pick"
	duel.deadline = now() + DUEL.PickTime
	send(duel.a.player, "Pick", duel.b.player, duel.deadline)
	send(duel.b.player, "Pick", duel.a.player, duel.deadline)
	sendState(duel)
end

local function onPick(player: Player, petId: unknown)
	local duel = duelOf[player]
	if not duel or duel.state ~= "Pick" or type(petId) ~= "string" or not PetCatalog.ById[petId] then
		return
	end
	local mine, other = sideOf(duel, player)
	if freeCount(player, petId) < 1 then
		return
	end
	if other.petId and not DuelStats.compatible(petId, other.petId) then
		send(player, "Cancelled", "RarityGap") -- simple message : le duel continue
		return
	end
	if mine.petId ~= petId then
		mine.petId = petId
		-- Le choix change : les deux doivent revalider (personne ne valide un échange qu'il n'a pas vu).
		mine.ready = false
		other.ready = false
	end
	sendState(duel)
end

local function onReady(player: Player, ready: boolean)
	local duel = duelOf[player]
	if not duel or duel.state ~= "Pick" then
		return
	end
	local mine, other = sideOf(duel, player)
	if not mine.petId or not other.petId or not DuelStats.compatible(mine.petId, other.petId) then
		mine.ready = false
		sendState(duel)
		return
	end
	mine.ready = ready
	sendState(duel)
	if duel.a.ready and duel.b.ready then
		startFight(duel)
	end
end

local function onCheer(player: Player)
	local duel = duelOf[player]
	if not duel or duel.state ~= "Fight" then
		return
	end
	local mine = sideOf(duel, player)
	local time = os.clock()
	if time - mine.cheerWindow >= 1 then
		mine.cheerWindow = time
		mine.cheerInWindow = 0
	end
	if mine.cheerInWindow < DUEL.CheerRate then
		mine.cheerInWindow += 1
		mine.cheer += 1
	end
end

-- Le joueur s'en va (départ, réinitialisation, bouton ANNULER) : abandon.
local function forfeit(player: Player, reason: string)
	local duel = duelOf[player]
	if not duel then
		return
	end
	if duel.state == "Invite" or duel.state == "Pick" then
		cancel(duel, reason)
	elseif duel.state == "Fight" then
		local mine, other = sideOf(duel, player)
		finishFight(duel, other, mine, true)
	elseif duel.state == "Wheel" then
		duelOf[player] = nil
	end
end

function DuelController.Init()
	local duelsFolder = Instance.new("Folder")
	duelsFolder.Name = "Duels"
	duelsFolder.Parent = Workspace
	folder = duelsFolder

	Remotes.DuelAction.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
		if action == "Request" then
			onRequest(player, arg)
		elseif action == "Answer" then
			onAnswer(player, arg == true)
		elseif action == "Pick" then
			onPick(player, arg)
		elseif action == "Ready" then
			onReady(player, arg == true)
		elseif action == "Cheer" then
			onCheer(player)
		elseif action == "Cancel" then
			forfeit(player, "Cancelled")
		end
	end)

	local function watchDeath(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				local duel = duelOf[player]
				if duel and duel.state ~= "Wheel" then
					forfeit(player, "Left")
				end
			end)
		end
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(watchDeath, player, character)
			-- Nouveau personnage pendant un duel (réinitialisation) : abandon.
			local duel = duelOf[player]
			if duel and duel.state ~= "Wheel" then
				forfeit(player, "Left")
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
		if player.Character then
			task.spawn(watchDeath, player, player.Character)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		forfeit(player, "Left")
		lastRequest[player] = nil
	end)

	-- Délais : invitation et choix.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local time = now()
		local seen: { [Duel]: boolean } = {}
		for _, duel in pairs(duelOf) do
			if not seen[duel] then
				seen[duel] = true
				if (duel.state == "Invite" or duel.state == "Pick") and time > duel.deadline then
					cancel(duel, "Timeout")
				end
			end
		end
	end)
end

return DuelController
