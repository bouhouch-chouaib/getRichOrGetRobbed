--!strict
-- Perks : bonus des passes Robux et du boost de chance serveur, calculés au même endroit pour le serveur
-- (effets réels) et le client (affichage, probabilités exactes). Lit seulement des attributs écrits par le serveur :
--   Player.Pass_<Key> = true (MonetizationController) ; ReplicatedStorage.LuckBoostUntil (heure serveur).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local M = Config.Monetization

local Perks = {}

function Perks.HasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

-- Multiplie tout l'argent gagné (revenu des familiers et gains des tirages).
function Perks.MoneyMultiplier(player: Player): number
	local multiplier = 1
	if Perks.HasPass(player, "DoubleMoney") then
		multiplier *= M.DoubleMoneyMultiplier
	end
	if Perks.HasPass(player, "VIP") then
		multiplier *= M.VipMoneyMultiplier
	end
	return multiplier
end

function Perks.ExtraCapacity(player: Player): number
	return if Perks.HasPass(player, "ExtraBackpack") then M.ExtraBackpack else 0
end

function Perks.ExtraEquipSlots(player: Player): number
	return if Perks.HasPass(player, "EquipPlus2") then M.ExtraEquipSlots else 0
end

function Perks.LockBonus(player: Player): number
	return if Perks.HasPass(player, "VIP") then M.VipLockBonus else 0
end

-- Secondes restantes du boost de chance serveur (0 s'il n'y en a pas).
function Perks.ServerLuckRemaining(): number
	local untilTime = ReplicatedStorage:GetAttribute("LuckBoostUntil")
	return if type(untilTime) == "number" then math.max(0, untilTime - Workspace:GetServerTimeNow()) else 0
end

-- Bonus de chance ajouté à TOUS les tirages du joueur (manches, tirages achetés).
function Perks.LuckBonus(player: Player): number
	local bonus = 0
	if Perks.HasPass(player, "LuckyLuck") then
		bonus += M.LuckyLuckBonus
	end
	if Perks.ServerLuckRemaining() > 0 then
		bonus += M.ServerLuckBonus
	end
	return bonus
end

return Perks
