--!strict
-- FusionController : machine de fusion.
-- Config.Fusion.Count familiers d'une même rareté (non équipés) + un coût en $ -> 1 familier
-- aléatoire de la rareté au-dessus. Le joueur choisit les familiers dans les cases de la machine (client/HUD) ;
-- sans choix valide, les doublons sont consommés en priorité.
-- Le Sigma ne peut pas être obtenu par fusion (Config.Fusion.MaxFromRarity).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BasePetsController = require(script.Parent.BasePetsController)
local SessionData = require(script.Parent.SessionData)

local FusionController = {}

local rng = Random.new()

-- Choisit quels familiers consommer : à chaque fois celui qui a le plus d'exemplaires libres (doublons d'abord).
local function pickIngredients(player: Player, rarityId: string): { [string]: number }?
	local bucket = PetCatalog.ByRarity[rarityId]
	if not bucket then
		return nil
	end
	local spare: { [string]: number } = {}
	for _, entry in ipairs(bucket) do
		spare[entry.Id] = SessionData.GetSpareCount(player, entry.Id)
	end
	local chosen: { [string]: number } = {}
	for _ = 1, Config.Fusion.Count do
		local bestId: string? = nil
		for petId, count in pairs(spare) do
			if count > 0 and (bestId == nil or count > spare[bestId :: string]) then
				bestId = petId
			end
		end
		if not bestId then
			return nil -- pas assez de familiers libres de cette rareté
		end
		local id = bestId :: string
		spare[id] -= 1
		chosen[id] = (chosen[id] or 0) + 1
	end
	return chosen
end

-- Valide le choix du client : exactement Config.Fusion.Count familiers libres, tous de cette rareté.
local function checkChosen(player: Player, rarityId: string, chosen: unknown): { [string]: number }?
	if type(chosen) ~= "table" then
		return nil
	end
	local result: { [string]: number } = {}
	local total = 0
	for petId, count in pairs(chosen :: { [unknown]: unknown }) do
		if type(petId) ~= "string" or type(count) ~= "number" or count % 1 ~= 0 or count < 1 then
			return nil
		end
		local entry = PetCatalog.ById[petId]
		if not entry or entry.Rarity ~= rarityId or SessionData.GetSpareCount(player, petId) < count then
			return nil
		end
		result[petId] = count
		total += count
	end
	return if total == Config.Fusion.Count then result else nil
end

local function onFuse(player: Player, rarityIndex: unknown, chosen: unknown)
	if type(rarityIndex) ~= "number" or rarityIndex % 1 ~= 0 then
		return
	end
	if rarityIndex < 1 or rarityIndex > Config.Fusion.MaxFromRarity then
		return
	end
	local cost = Config.Fusion.Costs[rarityIndex]
	local data = SessionData.Get(player)
	if not cost or not data or data.money < cost then
		return
	end

	local rarityId = Config.Rarities[rarityIndex].Id
	local ingredients = checkChosen(player, rarityId, chosen) or pickIngredients(player, rarityId)
	if not ingredients then
		return
	end
	local nextBucket = PetCatalog.ByRarity[Config.Rarities[rarityIndex + 1].Id]
	if not nextBucket or #nextBucket == 0 then
		return
	end

	-- Retrait des familiers puis paiement (les deux sont validés avant).
	if not SessionData.RemovePets(player, ingredients) then
		return
	end
	SessionData.SpendMoney(player, cost)

	local result = nextBucket[rng:NextInteger(1, #nextBucket)]
	SessionData.AddPets(player, { [result.Id] = 1 })
	BasePetsController.Celebrate(player, { result.Id })
	Remotes.FusionResult:FireClient(player, result.Id)
	print(string.format("[Fusion] %s : %d %s -> %s", player.Name, Config.Fusion.Count, Config.Rarities[rarityIndex].Name, result.Name))

	if rarityIndex + 1 >= Config.Loot.AnnounceMinRarity then
		Remotes.Announcement:FireAllClients(player.DisplayName, result.Id)
	end
end

function FusionController.Init()
	Remotes.Fuse.OnServerEvent:Connect(onFuse)
end

return FusionController
