--!strict
-- MonetizationController : passes et produits Robux (catalogue : Config.Monetization, effets : shared/Perks).
--
-- Passes (achat unique) : à l'arrivée du joueur et après un achat en jeu, l'attribut Player.Pass_<Key> = true est posé ;
-- tout le reste du jeu lit ces attributs via Perks. VIP : étiquette au-dessus de la tête.
--
-- Produits (rachetables) : MarketplaceService.ProcessReceipt. Un achat n'est JAMAIS accordé deux fois ni perdu :
--   - joueur absent ou sauvegarde pas chargée -> NotProcessedYet (Roblox réessaiera plus tard) ;
--   - reçu déjà noté dans la sauvegarde -> déjà accordé : on confirme seulement (après une sauvegarde réussie) ;
--   - sinon : effet accordé, reçu noté, sauvegarde immédiate ; PurchaseGranted seulement si elle a réussi
--     (sinon Roblox réessaie, et le reçu noté évite de l'accorder une 2e fois sur ce serveur).

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Perks = require(ReplicatedStorage.Shared.Perks)
local PullRewards = require(script.Parent.PullRewards)
local SessionData = require(script.Parent.SessionData)

local MonetizationController = {}

local M = Config.Monetization

local passesById: { [number]: Config.MonetizationItem } = {}
for _, pass in ipairs(M.GamePasses) do
	if pass.Id ~= 0 then
		passesById[pass.Id] = pass
	end
end
local productsById: { [number]: Config.MonetizationItem } = {}
for _, product in ipairs(M.Products) do
	if product.Id ~= 0 then
		productsById[product.Id] = product
	end
end

----------------------------------------------------------------------
-- Passes
----------------------------------------------------------------------

-- Étiquette "VIP" au-dessus de la tête (visible par tous).
local function addVipTag(character: Model)
	local head = character:WaitForChild("Head", 5)
	if not head or not head:IsA("BasePart") or head:FindFirstChild("VipTag") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.fromScale(4, 1)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 80
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Typography.Face
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 215, 60)
	label.Text = "VIP"
	label.Position = UDim2.fromScale(0.3, 0)
	label.Size = UDim2.fromScale(0.7, 1)
	Icons.image(tag, "Crown", UDim2.fromScale(0.3, 1))
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Parent = label
	label.Parent = tag
	tag.Parent = head
end

local function grantPass(player: Player, key: string)
	if player:GetAttribute("Pass_" .. key) == true then
		return
	end
	player:SetAttribute("Pass_" .. key, true)
	SessionData.RefreshPerks(player) -- places d'équipement, sac à dos...
	if key == "VIP" and player.Character then
		task.spawn(addVipTag, player.Character)
	end
end

local function checkPasses(player: Player)
	if RunService:IsStudio() then
		for _, key in ipairs(M.StudioTestPasses) do
			grantPass(player, key)
		end
	end
	-- Le créateur possède d'office ses passes chez Roblox : on l'ignore (Config.Monetization.CreatorOwnsPasses).
	local isCreator = game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
	if isCreator and not M.CreatorOwnsPasses then
		return
	end
	for _, pass in ipairs(M.GamePasses) do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns and player.Parent then
				grantPass(player, pass.Key)
			elseif not ok then
				warn(string.format("[Monetization] Vérification du passe %s impossible pour %s : %s", pass.Key, player.Name, tostring(owns)))
			end
		end
	end
end

----------------------------------------------------------------------
-- Produits
----------------------------------------------------------------------

-- Boost de chance pour tout le serveur : prolongé si un boost est déjà en cours, annoncé à tous (attributs lus par
-- client/RobuxShop).
local function grantServerLuck(player: Player)
	local now = Workspace:GetServerTimeNow()
	local untilTime = ReplicatedStorage:GetAttribute("LuckBoostUntil")
	local base = if type(untilTime) == "number" and untilTime > now then untilTime else now
	ReplicatedStorage:SetAttribute("LuckBoostUntil", base + M.ServerLuckDuration)
	ReplicatedStorage:SetAttribute("LuckBoostBy", player.DisplayName)
	ReplicatedStorage:SetAttribute("LuckBoostAt", now) -- change à chaque achat : déclenche l'annonce
end

-- Tirages achetés : même moteur que les manches (server/PullRewards : rang, doublons vendus, affichage à part),
-- avec la chance de base des tirages achetés + bonus (Perks).
local function grantPulls(player: Player, pulls: number)
	PullRewards.Grant(player, pulls, M.PullLuck + Perks.LuckBonus(player), nil, nil, true)
end

local function grantProduct(player: Player, product: Config.MonetizationItem)
	if product.Key == "AstralAura" then
		SessionData.SetUpgradeLevel(player, Config.PlayerAura.UnlockId, 1)
	elseif product.Key == "ServerLuck" then
		grantServerLuck(player)
	elseif product.Pulls then
		grantPulls(player, product.Pulls)
	elseif product.Keys then
		SessionData.AddKeys(player, product.Keys)
	else
		error("Produit sans effet : " .. product.Key)
	end
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player or not SessionData.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if SessionData.HasReceipt(player, purchaseId) then
		-- Déjà accordé : on confirme dès que la sauvegarde qui le prouve est écrite.
		return if SessionData.Save(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productsById[info.ProductId]
	if not product then
		warn("[Monetization] Produit inconnu : " .. tostring(info.ProductId) .. " (Id à ajouter dans Config.Monetization ?)")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(function()
		grantProduct(player, product)
		return true
	end)
	if not ok then
		warn(string.format("[Monetization] Échec de l'effet %s pour %s : %s", product.Key, player.Name, tostring(err)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	SessionData.AddReceipt(player, purchaseId)
	print(string.format("[Monetization] %s a acheté %s (%s)", player.Name, product.Key, purchaseId))
	return if SessionData.Save(player)
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationController.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local pass = passesById[passId]
		if purchased and pass then
			grantPass(player, pass.Key)
		end
	end)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			if Perks.HasPass(player, "VIP") then
				addVipTag(character)
			end
		end)
		task.spawn(checkPasses, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

-- Pour les tests : traite un reçu comme le ferait Roblox.
MonetizationController.ProcessReceipt = processReceipt

return MonetizationController
