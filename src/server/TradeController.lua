--!strict
-- TradeController : échanges de familiers entre deux joueurs (Config.Trade).
--
--   1. Demande : [T] « Échanger » sur un joueur (bulle créée par client/TradeClient) -> Remotes.TradeAction("Request").
--      La cible a InviteTime secondes pour accepter.
--   2. Offres (phase "Edit") : chacun ajoute / retire ses familiers non équipés (MaxPets au plus) ; les deux voient tout.
--      Chaque changement d'offre annule toutes les validations.
--   3. Double confirmation (anti-arnaque) : les deux cliquent PRÊT -> phase "Confirm" : les offres sont BLOQUÉES ;
--      CONFIRMER n'est accepté qu'après ConfirmDelay secondes (le temps de relire). « Modifier » revient à la phase 1.
--   4. Les deux ont confirmé : transfert en UNE étape serveur sans attente, après revérification (familiers toujours
--      libres, sauvegardes chargées) : retrait chez A, retrait chez B (si échec : A est remboursé), ajouts croisés,
--      puis sauvegarde des deux profils.
--   Annulation : bouton, départ, mort, temps écoulé (MaxTime), ou un familier offert qui n'est plus disponible.
--
-- Anti-duplication : rien ne bouge avant l'étape 4 ; les familiers portés ou en duel (réservés dans la base) ne
-- peuvent pas être offerts (BasePetsController.GetReserved), et SessionData.RemovePets refuse tout retrait impossible.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local BasePetsController = require(script.Parent.BasePetsController)
local SessionData = require(script.Parent.SessionData)

local TradeController = {}

local TRADE = Config.Trade

type Offer = { [string]: number }
type Side = { player: Player, offer: Offer, ready: boolean, confirmed: boolean }
type Trade = {
	a: Side,
	b: Side,
	state: string, -- "Invite", "Edit", "Confirm", "Done"
	deadline: number,
	confirmAt: number,
}

local tradeOf: { [Player]: Trade } = {}
local lastRequest: { [Player]: number } = {}

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

local function send(player: Player, ...: any)
	if player.Parent then
		Remotes.TradeEvent:FireClient(player, ...)
	end
end

local function sideOf(trade: Trade, player: Player): (Side, Side)
	if trade.a.player == player then
		return trade.a, trade.b
	end
	return trade.b, trade.a
end

local function count(offer: Offer): number
	local total = 0
	for _, n in pairs(offer) do
		total += n
	end
	return total
end

-- Exemplaires libres d'un familier : non équipés, ni portés ni en duel.
local function freeCount(player: Player, petId: string): number
	local base = BaseManager.GetBase(player)
	local reserved = if base then BasePetsController.GetReserved(base, petId) else 0
	return SessionData.GetSpareCount(player, petId) - reserved
end

local function isFree(player: Player): boolean
	return tradeOf[player] == nil
		and player:GetAttribute("InDuel") == nil
		and SessionData.IsLoaded(player)
		and BaseManager.GetBase(player) ~= nil
end

-- Ce que chacun voit : son offre, celle de l'autre, les validations, la phase.
local function sendState(trade: Trade)
	for _, side in ipairs({ trade.a, trade.b }) do
		local mine, other = sideOf(trade, side.player)
		send(side.player, "State", mine.offer, mine.ready, mine.confirmed, other.offer, other.ready, other.confirmed,
			trade.state, trade.confirmAt)
	end
end

local function close(trade: Trade)
	trade.state = "Done"
	for _, side in ipairs({ trade.a, trade.b }) do
		if tradeOf[side.player] == trade then
			tradeOf[side.player] = nil
		end
		if side.player.Parent then
			side.player:SetAttribute("InTrade", nil)
		end
	end
end

local function cancel(trade: Trade, reason: string)
	if trade.state == "Done" then
		return
	end
	send(trade.a.player, "Cancelled", reason)
	send(trade.b.player, "Cancelled", reason)
	close(trade)
end

-- Retour à la modification : plus personne n'est prêt ni n'a confirmé.
local function resetValidations(trade: Trade)
	trade.state = "Edit"
	for _, side in ipairs({ trade.a, trade.b }) do
		side.ready = false
		side.confirmed = false
	end
end

local function stillAvailable(side: Side): boolean
	for petId, n in pairs(side.offer) do
		if freeCount(side.player, petId) < n then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------
-- Transfert
----------------------------------------------------------------------

local function petList(offer: Offer): { string }
	local list = {}
	for petId in pairs(offer) do
		table.insert(list, petId)
	end
	return list
end

local function execute(trade: Trade)
	local a, b = trade.a, trade.b
	if not (a.player.Parent and b.player.Parent and SessionData.IsLoaded(a.player) and SessionData.IsLoaded(b.player)) then
		cancel(trade, "Left")
		return
	end
	if not stillAvailable(a) or not stillAvailable(b) then
		cancel(trade, "PetGone")
		return
	end
	-- Une seule étape, sans aucune attente entre les retraits et les ajouts.
	if next(a.offer) and not SessionData.RemovePets(a.player, a.offer) then
		cancel(trade, "PetGone")
		return
	end
	if next(b.offer) and not SessionData.RemovePets(b.player, b.offer) then
		SessionData.AddPets(a.player, a.offer) -- A est remboursé
		cancel(trade, "PetGone")
		return
	end
	SessionData.AddPets(a.player, b.offer)
	SessionData.AddPets(b.player, a.offer)
	close(trade)
	BasePetsController.Celebrate(a.player, petList(b.offer))
	BasePetsController.Celebrate(b.player, petList(a.offer))
	send(a.player, "Done", b.offer, a.offer, b.player.DisplayName)
	send(b.player, "Done", a.offer, b.offer, a.player.DisplayName)
	local function describe(offer: Offer): string
		local parts = {}
		for petId, n in pairs(offer) do
			table.insert(parts, petId .. " x" .. n)
		end
		return if #parts > 0 then table.concat(parts, ", ") else "rien"
	end
	print(string.format("[Trade] %s donne (%s) à %s qui donne (%s)", a.player.Name, describe(a.offer), b.player.Name,
		describe(b.offer)))
	task.spawn(function()
		SessionData.Save(a.player)
		SessionData.Save(b.player)
	end)
end

----------------------------------------------------------------------
-- Actions des joueurs
----------------------------------------------------------------------

local function onRequest(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player then
		return
	end
	local time = os.clock()
	if time - (lastRequest[player] or 0) < TRADE.RequestCooldown then
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
	if not myRoot or not theirRoot or (myRoot.Position - theirRoot.Position).Magnitude > TRADE.PromptDistance + 8 then
		return
	end
	local function newSide(p: Player): Side
		return { player = p, offer = {}, ready = false, confirmed = false }
	end
	local trade: Trade = {
		a = newSide(player),
		b = newSide(target),
		state = "Invite",
		deadline = now() + TRADE.InviteTime,
		confirmAt = 0,
	}
	tradeOf[player] = trade
	tradeOf[target] = trade
	send(target, "Invite", player, trade.deadline)
	send(player, "Waiting", target, trade.deadline)
end

local function onAnswer(player: Player, accept: boolean)
	local trade = tradeOf[player]
	if not trade or trade.state ~= "Invite" or trade.b.player ~= player then
		return
	end
	if not accept then
		cancel(trade, "Declined")
		return
	end
	trade.state = "Edit"
	trade.deadline = now() + TRADE.MaxTime
	trade.a.player:SetAttribute("InTrade", true)
	trade.b.player:SetAttribute("InTrade", true)
	send(trade.a.player, "Open", trade.b.player)
	send(trade.b.player, "Open", trade.a.player)
	sendState(trade)
end

local function onChangeOffer(player: Player, petId: unknown, delta: number)
	local trade = tradeOf[player]
	if not trade or trade.state ~= "Edit" or type(petId) ~= "string" or not PetCatalog.ById[petId] then
		return
	end
	local mine = sideOf(trade, player)
	local current = mine.offer[petId] or 0
	local wanted = current + delta
	if wanted < 0 then
		return
	end
	if delta > 0 and (count(mine.offer) >= TRADE.MaxPets or wanted > freeCount(player, petId)) then
		send(player, "Cancelled", if count(mine.offer) >= TRADE.MaxPets then "Full" else "NoMore")
		return
	end
	if wanted > 0 then
		mine.offer[petId] = wanted
	else
		mine.offer[petId] = nil
	end
	resetValidations(trade)
	sendState(trade)
end

local function onReady(player: Player, ready: boolean)
	local trade = tradeOf[player]
	if not trade or trade.state ~= "Edit" then
		return
	end
	local mine, other = sideOf(trade, player)
	if ready and next(mine.offer) == nil and next(other.offer) == nil then
		send(player, "Cancelled", "Empty")
		return
	end
	mine.ready = ready
	if trade.a.ready and trade.b.ready then
		-- Première confirmation des deux : offres bloquées, temps de relecture avant CONFIRMER.
		trade.state = "Confirm"
		trade.confirmAt = now() + TRADE.ConfirmDelay
	end
	sendState(trade)
end

local function onConfirm(player: Player)
	local trade = tradeOf[player]
	if not trade or trade.state ~= "Confirm" or now() < trade.confirmAt - 0.2 then
		return
	end
	local mine = sideOf(trade, player)
	mine.confirmed = true
	if trade.a.confirmed and trade.b.confirmed then
		execute(trade)
	else
		sendState(trade)
	end
end

local function onBack(player: Player)
	local trade = tradeOf[player]
	if not trade or trade.state ~= "Confirm" then
		return
	end
	resetValidations(trade)
	sendState(trade)
end

function TradeController.Init()
	Remotes.TradeAction.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
		if action == "Request" then
			onRequest(player, arg)
		elseif action == "Answer" then
			onAnswer(player, arg == true)
		elseif action == "Add" then
			onChangeOffer(player, arg, 1)
		elseif action == "Remove" then
			onChangeOffer(player, arg, -1)
		elseif action == "Ready" then
			onReady(player, arg == true)
		elseif action == "Confirm" then
			onConfirm(player)
		elseif action == "Back" then
			onBack(player)
		elseif action == "Cancel" then
			local trade = tradeOf[player]
			if trade then
				cancel(trade, "Cancelled")
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local trade = tradeOf[player]
		if trade then
			cancel(trade, "Left")
		end
		lastRequest[player] = nil
	end)

	-- Délais (invitation, échange trop long) et familiers qui disparaissent pendant l'échange (vol, fusion...).
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		local seen: { [Trade]: boolean } = {}
		for _, trade in pairs(tradeOf) do
			if not seen[trade] then
				seen[trade] = true
				if now() > trade.deadline then
					cancel(trade, "Timeout")
				elseif trade.state ~= "Invite" and (not stillAvailable(trade.a) or not stillAvailable(trade.b)) then
					cancel(trade, "PetGone")
				end
			end
		end
	end)
end

return TradeController
