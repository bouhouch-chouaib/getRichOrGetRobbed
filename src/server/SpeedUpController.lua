--!strict
-- SpeedUpController : accélérer en Robux ce qui demande du temps (29 oct., Chouaib). Un œuf de la couveuse éclot tout
-- de suite ; un œuf de la capsule finit son attente et tente sa prochaine évolution tout de suite (EggIncubation.SpeedUp :
-- la chance de l'essai, affichée dans le menu de la capsule, ne change pas).
--
-- Le joueur demande pour un de SES œufs (Remotes.SpeedUp, depuis l'œuf de la couveuse ou le menu de la capsule) ; le
-- serveur vérifie l'œuf, le retient et propose le produit du palier de temps qui reste (Config.GetSpeedUpProduct). À
-- l'achat (MonetizationController -> Grant) : l'œuf retenu s'il attend encore, sinon celui qui attend le plus longtemps ;
-- s'il n'y a plus rien à accélérer, l'accélération est gardée (champ sauvegardé speedUps) et sert à la prochaine demande
-- sans repayer : un achat n'est jamais perdu.
-- L'essai de la capsule est tiré au sort : là où les objets aléatoires payants sont interdits (PolicyService), seule la
-- couveuse s'accélère.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SessionData = require(script.Parent.SessionData)

local SpeedUpController = {}

type Pending = { eggId: string, at: number }
local pending: { [Player]: Pending } = {}
local capsuleAllowed: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}

-- Accélère l'œuf retenu s'il attend encore, sinon celui qui attend le plus longtemps, sinon garde l'accélération.
function SpeedUpController.Grant(player: Player)
	local time = os.time()
	local wanted = pending[player]
	pending[player] = nil
	local eggId: string? = nil
	if wanted and os.clock() - wanted.at <= Config.SpeedUp.PendingSeconds then
		local egg = SessionData.FindEgg(player, wanted.eggId)
		if egg and EggIncubation.WaitLeft(egg, time) > 0 then
			eggId = egg.id
		end
	end
	if not eggId then
		local egg = SessionData.LongestWait(player, time, capsuleAllowed[player] == true)
		eggId = if egg then egg.id else nil
	end
	if eggId and SessionData.SpeedUpEgg(player, eggId, time) then
		Remotes.SpeedUp:FireClient(player, "Done")
	else
		SessionData.AddSpeedUps(player, 1)
		Remotes.SpeedUp:FireClient(player, "Saved")
	end
end

function SpeedUpController.Init()
	Remotes.SpeedUp.OnServerEvent:Connect(function(player: Player, kind: unknown, eggId: unknown)
		if (kind ~= "Nest" and kind ~= "Capsule") or type(eggId) ~= "string" then
			return
		end
		local clock = os.clock()
		if clock - (lastRequest[player] or 0) < 0.5 then
			return
		end
		lastRequest[player] = clock
		local egg = SessionData.FindEgg(player, eggId)
		if not egg or (kind == "Capsule") ~= (egg.evolve ~= nil) then
			return
		end
		if egg.evolve and not capsuleAllowed[player] then
			return
		end
		local time = os.time()
		local left = EggIncubation.WaitLeft(egg, time)
		if left < Config.SpeedUp.MinSeconds then
			return
		end
		-- Une accélération déjà payée (achat sans œuf à accélérer) sert maintenant, sans repayer.
		if SessionData.SpendSpeedUp(player) then
			SessionData.SpeedUpEgg(player, eggId, time)
			Remotes.SpeedUp:FireClient(player, "Done")
			return
		end
		local product = Config.GetSpeedUpProduct(left)
		if not product then
			return
		end
		pending[player] = { eggId = eggId, at = clock }
		MarketplaceService:PromptProductPurchase(player, product.Id)
	end)

	local function onPlayerAdded(player: Player)
		local ok, policy = pcall(function(): any
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		capsuleAllowed[player] = ok and type(policy) == "table" and policy.ArePaidRandomItemsRestricted == false
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		pending[player] = nil
		capsuleAllowed[player] = nil
		lastRequest[player] = nil
	end)
end

return SpeedUpController
