-- BlackholeController : gère le comportement visuel et logique du trou noir
-- en fonction des événements émis par le GameLoopManager.

local BlackholeController = {}

local Workspace = game:GetService("Workspace")

-- Couleurs par état
local FEEDING_COLOR = Color3.fromRGB(150, 0, 255)   -- violet
local DIGESTING_COLOR = Color3.fromRGB(255, 30, 30) -- rouge

-- Références internes
local blackholeZone = nil
local gameLoopManager = nil
local connection = nil

-- Score (nombre d'items avalés) par joueur
local playerGauges = {}

-- Récupère la BlackholeZone sous workspace.Map
local function getBlackholeZone()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	local zone = map:FindFirstChild("BlackholeZone")
	if zone and zone:IsA("BasePart") then
		return zone
	end
	return nil
end

-- Récupère la BlackholeBarrier sous workspace.Map
local function getBlackholeBarrier()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	local barrier = map:FindFirstChild("BlackholeBarrier")
	if barrier and barrier:IsA("BasePart") then
		return barrier
	end
	return nil
end

-- Applique la couleur et l'attribut CanConsume selon l'état
local function applyState(state)
	if not blackholeZone then
		return
	end

	local barrier = getBlackholeBarrier()

	if state == "Feeding" then
		blackholeZone.Color = FEEDING_COLOR
		blackholeZone:SetAttribute("CanConsume", true)

		-- Le bouclier s'éteint : on peut jeter les objets.
		if barrier then
			barrier.CanCollide = false
			barrier.Transparency = 1
		end
	elseif state == "Digesting" then
		-- Distribution des récompenses RNG avant de passer en rouge
		BlackholeController.CalculateRNGRewards(playerGauges)
		playerGauges = {}

		blackholeZone.Color = DIGESTING_COLOR
		blackholeZone:SetAttribute("CanConsume", false)

		-- Le bouclier s'allume : les objets rebondissent dessus.
		if barrier then
			barrier.CanCollide = true
			barrier.Transparency = 0.5
		end
	end
end

-- Gestionnaire d'événements du GameLoopManager
local function onGameLoopEvent(eventName, state, timeRemaining)
	if eventName == "StateChanged" and state then
		applyState(state)
	elseif eventName == "Tick" then
		-- Réagir au tick si nécessaire (ex: mise à jour UI)
	end
end

-- Distribue les récompenses RNG selon les objets avalés par chaque joueur
function BlackholeController.CalculateRNGRewards(gauges)
	for player, score in pairs(gauges) do
		print("[RNG] Calcul des récompenses pour " .. player .. " (Score final : " .. score .. ")")
	end
end

-- Initialise le contrôleur avec une référence au GameLoopManager
function BlackholeController.Init(manager)
	gameLoopManager = manager
	blackholeZone = getBlackholeZone()

	-- État initial par défaut
	if blackholeZone then
		blackholeZone:SetAttribute("CanConsume", false)
	end

	-- Connexion à l'événement du GameLoopManager
	if gameLoopManager and gameLoopManager.ServerEvent then
		connection = gameLoopManager.ServerEvent.Event:Connect(onGameLoopEvent)
	end

	-- Absorption des items jetés dans le trou noir
	if blackholeZone then
		blackholeZone.Touched:Connect(function(hit)
			if not blackholeZone:GetAttribute("CanConsume") then
				return
			end

			if hit and hit.Name == "Item" and not hit.Anchored then
				local owner = hit:GetAttribute("Owner") or "Unknown"
				playerGauges[owner] = (playerGauges[owner] or 0) + 1
				print("[Blackhole] Miam ! +1 point pour " .. owner .. " (Total: " .. playerGauges[owner] .. ")")
				hit:Destroy()
			end
		end)
	end

	-- Applique immédiatement l'état courant si disponible
	if gameLoopManager and gameLoopManager.GetState then
		local currentState = gameLoopManager.GetState()
		if currentState then
			applyState(currentState)
		end
	end
end

-- Nettoie la connexion
function BlackholeController.Destroy()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return BlackholeController
