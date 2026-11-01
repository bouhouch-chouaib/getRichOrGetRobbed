--!strict
-- TradePolicy : règle Roblox IsPaidItemTradingAllowed (PolicyService, déclarée au questionnaire de maturité le 1er nov.).
-- Les familiers peuvent sortir d'œufs payés en Robux : là où Roblox interdit l'échange d'objets payants (pays, âge du
-- compte), un joueur ne peut ni échanger de familiers (TradeController), ni vendre ou acheter au Marché
-- (MarketController), ni gagner ou perdre un familier à la roue du duel (DuelController : case d'argent à la place).
-- Tant que la réponse de Roblox n'est pas arrivée (ou si elle échoue) : interdit. Attribut "TradeAllowed" pour le client.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local TradePolicy = {}

local allowed: { [Player]: boolean } = {}

function TradePolicy.Allowed(player: Player): boolean
	return allowed[player] == true
end

local function fetch(player: Player)
	for attempt = 1, 3 do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if not player.Parent then
			return
		end
		if ok and type(info) == "table" then
			allowed[player] = (info :: any).IsPaidItemTradingAllowed == true
			player:SetAttribute("TradeAllowed", allowed[player])
			return
		end
		task.wait(2 * attempt)
	end
	player:SetAttribute("TradeAllowed", false)
end

function TradePolicy.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(fetch, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(fetch, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		allowed[player] = nil
	end)
end

return TradePolicy
