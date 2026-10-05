--!strict
-- FusionController : machine de fusion.
-- Config.Fusion.Count familiers d'une même rareté (non équipés) + un coût en $ -> 1 familier
-- aléatoire de la rareté au-dessus. Les doublons sont consommés en priorité.
-- Le Sigma ne peut pas être obtenu par fusion (Config.Fusion.MaxFromRarity).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
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

local function onFuse(player: Player, rarityIndex: unknown)
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

	local ingredients = pickIngredients(player, Config.Rarities[rarityIndex].Id)
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
	Remotes.FusionResult:FireClient(player, result.Id)
	print(string.format("[Fusion] %s : 5 %s -> %s", player.Name, Config.Rarities[rarityIndex].Name, result.Name))

	if rarityIndex + 1 >= Config.Loot.AnnounceMinRarity then
		Remotes.Announcement:FireAllClients(player.DisplayName, result.Id)
	end
end

function FusionController.Init()
	Remotes.Fuse.OnServerEvent:Connect(onFuse)
end

return FusionController
