--!strict
-- MarketController : marché entre joueurs du même serveur (Config.Market, fenêtre client/MarketMenu).
--   - Vendre (Remotes.Market "List", petId, prix) : un familier libre (non équipé, pas en cours de vol / duel) est mis en
--     vente pour un prix en argent du jeu. MaxListings ventes au plus par joueur. Rien ne bouge tant que personne n'achète :
--     le vendeur garde son familier (il peut le retirer, l'équiper, le fusionner : la vente devient alors impossible).
--   - Retirer (Remotes.Market "Cancel", id).
--   - Acheter (Remotes.Market "Buy", id) : tout est revérifié (les deux sauvegardes chargées, familier toujours libre chez le
--     vendeur, argent de l'acheteur), puis en UNE étape sans attente : retrait chez le vendeur, ajout chez l'acheteur,
--     argent de l'acheteur au vendeur (moins la taxe Config.Market.Tax). Les deux profils sont sauvegardés aussitôt.
--   - Les ventes ne sont pas sauvegardées : elles disparaissent quand le vendeur quitte le serveur.
-- Le client reçoit la liste complète (Remotes.MarketUpdate) à chaque changement ; les résultats par Remotes.Market.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local BasePetsController = require(script.Parent.BasePetsController)
local SessionData = require(script.Parent.SessionData)

local MarketController = {}

export type Listing = { id: string, seller: Player, petId: string, price: number }
local listings: { Listing } = {}
local lastAction: { [Player]: number } = {}

-- Exemplaires vendables : libres (non équipés) et pas réservés dans la base (porté, volé, en duel).
local function freeCount(player: Player, petId: string): number
	local base = BaseManager.GetBase(player)
	local reserved = if base then BasePetsController.GetReserved(base, petId) else 0
	return SessionData.GetSpareCount(player, petId) - reserved
end

-- Liste envoyée aux clients : { id, seller (UserId), sellerName, petId, price, available }.
local function publish()
	local list = {}
	for _, listing in ipairs(listings) do
		table.insert(list, {
			id = listing.id,
			seller = listing.seller.UserId,
			sellerName = listing.seller.DisplayName,
			petId = listing.petId,
			price = listing.price,
			available = freeCount(listing.seller, listing.petId) >= MarketController.CountListed(listing.seller, listing.petId),
		})
	end
	Remotes.MarketUpdate:FireAllClients(list)
end

-- Nombre de ventes en cours de ce familier chez ce vendeur.
function MarketController.CountListed(seller: Player, petId: string): number
	local count = 0
	for _, listing in ipairs(listings) do
		if listing.seller == seller and listing.petId == petId then
			count += 1
		end
	end
	return count
end

local function find(id: unknown): (Listing?, number?)
	for index, listing in ipairs(listings) do
		if listing.id == id then
			return listing, index
		end
	end
	return nil, nil
end

local function reply(player: Player, ok: boolean, message: string)
	Remotes.Market:FireClient(player, ok, message)
end

function MarketController.List(player: Player, petId: unknown, price: unknown): (boolean, string)
	if type(petId) ~= "string" or not PetCatalog.ById[petId] or type(price) ~= "number" then
		return false, "VENTE IMPOSSIBLE"
	end
	if price ~= price or price < Config.Market.MinPrice or price > Config.Market.MaxPrice then
		return false, "PRIX INVALIDE"
	end
	-- Au plus 1 h du revenu du familier (Config.Market.MaxPriceSeconds) : pas de cadeau d'argent déguisé.
	local maxPrice = Config.GetMarketMaxPrice(PetCatalog.GetIncome(petId))
	if price > maxPrice then
		return false, "PRIX TROP HAUT : " .. MarketController.FormatMoney(maxPrice) .. " AU PLUS"
	end
	if not SessionData.IsLoaded(player) then
		return false, "SAUVEGARDE EN CHARGEMENT"
	end
	local mine = 0
	for _, listing in ipairs(listings) do
		if listing.seller == player then
			mine += 1
		end
	end
	if mine >= Config.Market.MaxListings then
		return false, string.format("%d VENTES AU PLUS : RETIRES-EN UNE", Config.Market.MaxListings)
	end
	if freeCount(player, petId) <= MarketController.CountListed(player, petId) then
		return false, "CE FAMILIER N'EST PAS LIBRE (ÉQUIPÉ OU DÉJÀ EN VENTE)"
	end
	table.insert(listings, { id = HttpService:GenerateGUID(false), seller = player, petId = petId, price = math.floor(price) })
	publish()
	return true, "EN VENTE !"
end

function MarketController.Cancel(player: Player, id: unknown): (boolean, string)
	local listing, index = find(id)
	if not listing or not index or listing.seller ~= player then
		return false, "VENTE INTROUVABLE"
	end
	table.remove(listings, index)
	publish()
	return true, "VENTE RETIRÉE"
end

function MarketController.Buy(buyer: Player, id: unknown): (boolean, string)
	local listing, index = find(id)
	if not listing or not index then
		return false, "DÉJÀ VENDU OU RETIRÉ"
	end
	local seller = listing.seller
	if seller == buyer then
		return false, "C'EST TA PROPRE VENTE"
	end
	if not seller.Parent or not SessionData.IsLoaded(seller) or not SessionData.IsLoaded(buyer) then
		return false, "VENTE IMPOSSIBLE POUR LE MOMENT"
	end
	local data = SessionData.Get(buyer)
	if not data or data.money < listing.price then
		return false, "PAS ASSEZ D'ARGENT"
	end
	if freeCount(seller, listing.petId) < 1 then
		return false, "LE VENDEUR N'A PLUS CE FAMILIER LIBRE"
	end
	-- Une seule étape, sans attente entre le retrait et l'ajout.
	if not SessionData.RemovePets(seller, { [listing.petId] = 1 }) then
		return false, "LE VENDEUR N'A PLUS CE FAMILIER LIBRE"
	end
	if not SessionData.SpendMoney(buyer, listing.price) then
		SessionData.AddPets(seller, { [listing.petId] = 1 }) -- impossible en pratique (vérifié juste avant)
		return false, "PAS ASSEZ D'ARGENT"
	end
	SessionData.AddPets(buyer, { [listing.petId] = 1 })
	SessionData.AddMoney(seller, math.floor(listing.price * (1 - Config.Market.Tax)))
	table.remove(listings, index)
	BasePetsController.Celebrate(buyer, { listing.petId })
	task.spawn(SessionData.Save, seller)
	task.spawn(SessionData.Save, buyer)
	local entry = PetCatalog.ById[listing.petId]
	Remotes.Market:FireClient(seller, true, string.format("VENDU À %s : %s (+%s) !", string.upper(buyer.DisplayName),
		string.upper(entry.Name), MarketController.FormatMoney(listing.price * (1 - Config.Market.Tax))))
	print(string.format("[Market] %s achète %s à %s pour %d", buyer.Name, listing.petId, seller.Name, listing.price))
	publish()
	return true, "ACHETÉ : " .. string.upper(entry.Name) .. " !"
end

function MarketController.FormatMoney(value: number): string
	return NumberFormat.money(math.floor(value))
end

function MarketController.Init()
	Remotes.Market.OnServerEvent:Connect(function(player: Player, action: unknown, a: unknown, b: unknown)
		local now = os.clock()
		if now - (lastAction[player] or 0) < 0.3 then
			return
		end
		lastAction[player] = now
		local ok, message = false, ""
		if action == "List" then
			ok, message = MarketController.List(player, a, b)
		elseif action == "Cancel" then
			ok, message = MarketController.Cancel(player, a)
		elseif action == "Buy" then
			ok, message = MarketController.Buy(player, a)
		elseif action == "Refresh" then
			publish()
			return
		else
			return
		end
		reply(player, ok, message)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastAction[player] = nil
		local changed = false
		for index = #listings, 1, -1 do
			if listings[index].seller == player then
				table.remove(listings, index)
				changed = true
			end
		end
		if changed then
			publish()
		end
	end)
	-- Disponibilité (équipé, fusionné...) : rafraîchie régulièrement.
	task.spawn(function()
		while true do
			task.wait(5)
			if #listings > 0 then
				publish()
			end
		end
	end)
end

return MarketController
