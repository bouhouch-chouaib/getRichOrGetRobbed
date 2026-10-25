--!strict
-- PowerCap : plafond de revenu des familiers « trop forts pour toi » (Config.PowerCap, ECONOMY_REPORT.md règle 2) et
-- règle du vol utile (Config.StealShield, règle 7). Calculs purs, partagés par le serveur (revenu, vols, Index, sacrifice)
-- et le client (étiquettes, Index, bulles [E]).
--   selfBest : meilleure rareté (index de Config.Rarities) que le joueur a obtenue lui-même, attribut "SelfBest".

local Config = require(script.Parent.Config)
local PetCatalog = require(script.Parent.PetCatalog)

local PowerCap = {}

-- Revenu maximum d'un familier pour ce joueur ; nil = pas de plafond (la rareté visée dépasse le Sigma).
function PowerCap.Max(selfBest: number?): number?
	local rarity = Config.Rarities[(selfBest or #Config.Rarities) + Config.PowerCap.RarityGap]
	return if rarity then rarity.Income else nil
end

-- Revenu de ce familier pour ce joueur (plafonné).
function PowerCap.Income(petId: string, selfBest: number?): number
	return math.min(PetCatalog.GetIncome(petId), PowerCap.Max(selfBest) or math.huge)
end

-- Ce familier est-il bridé pour ce joueur ?
function PowerCap.IsCapped(petId: string, selfBest: number?): boolean
	return PowerCap.Income(petId, selfBest) < PetCatalog.GetIncome(petId)
end

-- Rareté qu'il faut obtenir soi-même pour libérer ce familier (nil s'il n'est pas bridé).
function PowerCap.UnlockRarity(petId: string, selfBest: number?): number?
	if not PowerCap.IsCapped(petId, selfBest) then
		return nil
	end
	local best = selfBest or 0
	for rarity = best + 1, #Config.Rarities do
		if PetCatalog.GetIncome(petId) <= (PowerCap.Max(rarity) or math.huge) then
			return rarity
		end
	end
	return #Config.Rarities
end

-- Meilleure rareté obtenue soi-même, lue sur le joueur (nil si la sauvegarde n'est pas encore chargée).
function PowerCap.SelfBestOf(player: Player): number?
	local value = player:GetAttribute("SelfBest")
	return if type(value) == "number" then value else nil
end

-- Vol utile : le familier ferait-il monter le revenu du voleur ? baseMin = revenu (plafonné) du moins bon familier de
-- sa base, 0 s'il lui reste une place (attribut "BaseMin", server/EconomyController).
function PowerCap.IsUseful(petId: string, selfBest: number?, baseMin: number): boolean
	return PowerCap.Income(petId, selfBest) > baseMin
end

return PowerCap
