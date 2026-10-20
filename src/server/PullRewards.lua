--!strict
-- PullRewards : accorde des tirages à un joueur, au même endroit pour toutes les sources (fin de manche du trou
-- noir, roue des duels, tirages achetés en Robux).
--   - Rang de tirage : la rareté plancher dépend des tirages faits depuis le début (LootEngine.floor).
--   - Mutations secrètes (Config.Mutations) : un familier gagné par un tirage gratuit peut être Doré, Diamant ou
--     Arc-en-ciel ; le client ne reçoit que l'espèce (surprise à l'éclosion).
--   - Doublons : au-delà de Config.Loot.KeepCopies exemplaires d'un même familier, le suivant est vendu tout de
--     suite (Config.Loot.SellSeconds secondes de son revenu, x bonus du monde et des passes).
--   - Le client reçoit Remotes.RewardsGranted(score, tirages, familiers gardés, argent total, détails) ; détails =
--     { drops = { { Id, New, Sold, Egg } } dans l'ordre, sold, floor, rank, eggs = true } (client/PullReveal).
-- Les récompenses gardées entrent en incubation ; les annonces de familiers attendent leur éclosion.
-- Les données sont modifiées tout de suite ; l'affichage tourne à part (une erreur d'affichage ne doit jamais
-- faire échouer un achat déjà accordé).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LootEngine = require(ReplicatedStorage.Shared.LootEngine)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SessionData = require(script.Parent.SessionData)

local PullRewards = {}

export type Drop = { Id: string, New: boolean, Sold: number?, Egg: boolean? }
export type Details = { drops: { Drop }, sold: number, floor: number, rank: number, eggs: boolean }

-- Mutation tirée en secret pour un familier gagné (Config.Mutations, la plus rare d'abord), chance fixe.
-- nil = pas de mutation.
local mutationRng = Random.new()
function PullRewards.RollMutation(): string?
	for index = #Config.Mutations, 1, -1 do
		local mutation = Config.Mutations[index]
		if mutationRng:NextNumber() < mutation.Chance then
			return mutation.Id
		end
	end
	return nil
end

-- Prix de vente automatique d'un doublon.
function PullRewards.SellValue(player: Player, petId: string): number
	local world = Config.GetWorld(SessionData.GetTier(player))
	return math.floor(PetCatalog.GetIncome(petId) * Config.Loot.SellSeconds * world.IncomeMultiplier * Perks.MoneyMultiplier(player))
end

-- Rareté plancher actuelle du joueur.
function PullRewards.Floor(player: Player): number
	return LootEngine.floor(SessionData.GetTotalPulls(player), SessionData.GetDiscovered(player))
end

-- pulls tirages avec cette chance ; extraMoney (argent des points de la manche) et score servent à l'affichage.
-- paid = tirages achetés en Robux : jamais de mutation (leurs chances affichées doivent être complètes).
function PullRewards.Grant(player: Player, pulls: number, luck: number, extraMoney: number?, score: number?, paid: boolean?): Details
	local discovered = SessionData.GetDiscovered(player)
	local owned = SessionData.GetRewardOwned(player) -- pending eggs count toward the duplicate limit
	local floorIndex = LootEngine.floor(SessionData.GetTotalPulls(player), discovered)
	local rankIndex = LootEngine.rank(SessionData.GetTotalPulls(player))
	-- Monde le plus loin atteint : meilleures raretés (Config.Worlds[].RarityBoost).
	local outcome = LootEngine.rollPulls(pulls, SessionData.GetPity(player), luck, owned, floorIndex, SessionData.GetTier(player))

	local kept: { [string]: number } = {}
	local shownKept: { [string]: number } = {} -- ce que voit le client : l'espèce seulement (mutation secrète)
	local drops: { Drop } = {}
	local sold = 0
	for _, rolledId in ipairs(outcome.drops) do
		local isNew = not discovered[rolledId]
		discovered[rolledId] = true
		-- Mutation secrète, révélée à l'éclosion : un familier muté est un autre familier (jamais vendu comme doublon).
		local mutation = if paid then nil else PullRewards.RollMutation()
		local petId = if mutation then PetCatalog.WithMutation(rolledId, mutation) else rolledId
		if not mutation and (owned[petId] or 0) + (kept[petId] or 0) >= Config.Loot.KeepCopies then
			local value = PullRewards.SellValue(player, petId)
			sold += value
			table.insert(drops, { Id = petId, New = false, Sold = value })
		else
			kept[petId] = (kept[petId] or 0) + 1
			shownKept[rolledId] = (shownKept[rolledId] or 0) + 1
			table.insert(drops, { Id = rolledId, New = isNew, Egg = true })
			if mutation then
				print(string.format("[PullRewards] %s : mutation secrète %s", player.Name, petId))
			end
		end
	end

	SessionData.SetPity(player, outcome.pity)
	SessionData.AddTotalPulls(player, outcome.pulls)
	if next(kept) then
		SessionData.AddEggs(player, kept)
	end
	local money = sold + (extraMoney or 0)
	if money > 0 then
		SessionData.AddMoney(player, money)
	end

	local details: Details = { drops = drops, sold = sold, floor = floorIndex, rank = rankIndex, eggs = true }
	task.spawn(function()
		local ok, err = pcall(function()
			Remotes.RewardsGranted:FireClient(player, score or 0, outcome.pulls, shownKept, money, details)
		end)
		if not ok then
			warn("[PullRewards] affichage : " .. tostring(err))
		end
	end)
	local soldCount = 0
	for _, drop in ipairs(drops) do
		if drop.Sold then
			soldCount += 1
		end
	end
	print(string.format("[PullRewards] %s : %d tirage(s), %d vendu(s) +%d$, plancher %d, rang %d", player.Name,
		outcome.pulls, soldCount, sold, floorIndex, rankIndex))
	return details
end

return PullRewards
