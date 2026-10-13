--!strict
-- PowerController : pouvoir d'invisibilité (Config.Weapons.Invisibility), objet "PowerInvisible" acheté en boutique et
-- rangé dans l'inventaire comme les armes (server/WeaponController crée l'objet et appelle Activate au clic).
--
-- Règles pensées pour ne pas être frustrantes :
--   - court (Duration) et long à recharger (Cooldown, compté depuis l'activation) ;
--   - imparfait : les autres voient une silhouette fantomatique de près et des étincelles aux pieds (client/InvisibilityFx) ;
--   - brisé par toute action : ramasser un objet (ItemInteraction), commencer un vol (StealController), frapper ou tirer
--     au grappin, se faire toucher (WeaponController) -> PowerController.Reveal ;
--   - impossible pendant qu'on porte un familier volé ;
--   - la batte et le grappin touchent toujours un joueur invisible (il faut juste bien viser).
--
-- État répliqué (attributs du Player, lus par client/InvisibilityFx) :
--   "InvisibleUntil" = heure serveur (Workspace:GetServerTimeNow()) de fin, nil quand visible ;
--   "InvisibleReadyAt" = heure serveur à partir de laquelle on peut le réutiliser.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local PowerController = {}

local INVISIBILITY = Config.Weapons.Invisibility

local tokens: { [Player]: number } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function PowerController.IsInvisible(player: Player): boolean
	local untilTime = player:GetAttribute("InvisibleUntil")
	return type(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow()
end

-- Rend le joueur visible tout de suite (fin du pouvoir, ou une action l'a brisé). Sans effet s'il est déjà visible.
function PowerController.Reveal(player: Player)
	if player:GetAttribute("InvisibleUntil") == nil then
		return
	end
	tokens[player] = (tokens[player] or 0) + 1
	player:SetAttribute("InvisibleUntil", nil)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
end

-- Clic avec le pouvoir en main. Retourne true s'il a été activé.
function PowerController.Activate(player: Player): boolean
	local humanoid = humanoidOf(player)
	local now = Workspace:GetServerTimeNow()
	local readyAt = player:GetAttribute("InvisibleReadyAt")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if type(readyAt) == "number" and now < readyAt then
		return false
	end
	if player:GetAttribute("CarryingPet") ~= nil or PowerController.IsInvisible(player) then
		return false
	end
	tokens[player] = (tokens[player] or 0) + 1
	local token = tokens[player]
	player:SetAttribute("InvisibleReadyAt", now + INVISIBILITY.Cooldown)
	player:SetAttribute("InvisibleUntil", now + INVISIBILITY.Duration)
	-- Le nom au-dessus de la tête disparaît (les autres étiquettes sont cachées par chaque client).
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- Les mains se libèrent (le pouvoir est rangé) : on peut aller voler... ce qui brisera l'invisibilité.
	task.delay(0.35, function()
		local current = humanoidOf(player)
		if current and tokens[player] == token then
			current:UnequipTools()
		end
	end)
	task.delay(INVISIBILITY.Duration, function()
		if tokens[player] == token then
			PowerController.Reveal(player)
		end
	end)
	return true
end

function PowerController.Init()
	local function onPlayerAdded(player: Player)
		-- Mort / réapparition : on redevient visible.
		player.CharacterAdded:Connect(function()
			PowerController.Reveal(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		tokens[player] = nil
	end)
end

return PowerController
