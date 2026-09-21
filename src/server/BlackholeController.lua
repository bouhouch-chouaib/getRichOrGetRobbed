-- BlackholeController : gère le comportement visuel et logique du trou noir
-- en fonction des événements émis par le GameLoopManager.

local BlackholeController = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LootEngine = require(ReplicatedStorage.Shared.LootEngine)
local SessionData = require(script.Parent.SessionData)

-- RemoteEvent utilisé pour notifier le client qu'il doit lâcher son item (KO).
local knockbackEvent = ReplicatedStorage:FindFirstChild("KnockbackEvent")
if not knockbackEvent then
    knockbackEvent = Instance.new("RemoteEvent")
    knockbackEvent.Name = "KnockbackEvent"
    knockbackEvent.Parent = ReplicatedStorage
end

-- Couleurs par état
local FEEDING_COLOR = Color3.fromRGB(150, 0, 255)   -- violet
local DIGESTING_COLOR = Color3.fromRGB(255, 30, 30) -- rouge

-- Références internes
local blackholeZone = nil
local gameLoopManager = nil
local connections = {}

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

-- Paramètres de l'effet "gifle" infligé par le dôme.
local DOME_KNOCKBACK_FORCE = 350
local DOME_STUN_DURATION = 3

-- Anti-spam : empêche de re-déclencher la gifle sur un joueur déjà KO.
local stunnedPlayers = {}

-- Applique un effet de gifle : projette le joueur et le met KO au sol.
local function slapPlayer(character, domePosition)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then
        return
    end

    -- Anti-spam : ignore si le joueur est déjà étourdi.
    if stunnedPlayers[character] then
        return
    end
    stunnedPlayers[character] = true

    -- Direction de projection : du centre du dôme vers le joueur (recul vers l'arrière),
    -- avec une poussée vers le haut pour un effet "gifle".
    local away = root.Position - domePosition
    away = Vector3.new(away.X, 0, away.Z)
    if away.Magnitude < 0.1 then
        away = Vector3.new(1, 0, 0)
    end
    away = away.Unit

    -- Annule toute vélocité résiduelle (le joueur peut courir vers le dôme ou tomber)
    -- pour garantir que la projection soit entièrement contrôlée par l'impulsion.
    root.AssemblyLinearVelocity = Vector3.zero

    -- Impulsion forte vers l'arrière (extérieur du dôme) + vers le haut.
    local impulse = (away + Vector3.new(0, 0.9, 0)).Unit * DOME_KNOCKBACK_FORCE
    root:ApplyImpulse(impulse * root.AssemblyMass)

    -- Notifie le client qu'il doit lâcher l'item qu'il tient.
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        knockbackEvent:FireClient(player)
    end

    -- Met le joueur KO : ragdoll (physique) + contrôle désactivé.
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.JumpHeight = 0
    humanoid.AutoRotate = false
    humanoid.PlatformStand = true
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    -- Réveille le joueur après la durée de KO.
    task.delay(DOME_STUN_DURATION, function()
        if humanoid and humanoid.Parent then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
            humanoid.JumpHeight = 7.2
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        stunnedPlayers[character] = nil
    end)
end

-- Récupère le BlackholeDome sous workspace.Map
local function getBlackholeDome()
    local map = Workspace:FindFirstChild("Map")
    if not map then
        return nil
    end
    local dome = map:FindFirstChild("BlackholeDome")
    if dome and dome:IsA("BasePart") then
        return dome
    end
    return nil
end

-- Applique la couleur et l'attribut CanConsume selon l'état
local function applyState(state)
    if not blackholeZone then
        return
    end

    local barrier = getBlackholeBarrier()
    local dome = getBlackholeDome()

    if state == "Feeding" then
        blackholeZone.Color = FEEDING_COLOR
        blackholeZone:SetAttribute("CanConsume", true)

        -- Le bouclier s'éteint : on peut jeter les objets.
        if barrier then
            barrier.CanCollide = false
            barrier.Transparency = 1
        end

        -- Le dôme s'éteint : les joueurs peuvent viser le trou noir.
        if dome then
            dome.CanCollide = false
            dome.Transparency = 1
            dome.CanTouch = false
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

        -- Le dôme s'allume : impossible de jeter des items dans le trou noir.
        -- CanCollide reste false pour éviter que les joueurs l'escaladent,
        -- mais CanTouch = true permet de détecter et gifler les joueurs.
        if dome then
            dome.CanCollide = false
            dome.CanTouch = true
            dome.Transparency = 0.85
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
    for playerName, score in pairs(gauges) do
        local results, pulls = LootEngine.processRewards(score)

        if pulls > 0 then
            -- Formate les gains en ignorant les raretés à 0.
            local parts = {}
            for rarity, amount in pairs(results) do
                if amount > 0 then
                    table.insert(parts, rarity .. ": " .. amount)
                end
            end
            local rewardString = table.concat(parts, ", ")

            print("[RNG] 🎰 " .. playerName .. " a fait " .. pulls .. " tirages (Score: " .. score .. ") et a obtenu -> " .. rewardString)

            -- Sauvegarde les pets gagnés dans l'inventaire du joueur.
            SessionData.AddPets(playerName, results)

            -- Affiche l'inventaire total mis à jour.
            local data = SessionData.GetPlayerData(playerName)
            if data then
                print("🎒 Inventaire total de " .. playerName .. " -> Commun: " .. data.pets.Commun .. " | Rare: " .. data.pets.Rare .. " | Epique: " .. data.pets.Epique .. " | Sigma: " .. data.pets.Sigma)
            end
        else
            print("[RNG] " .. playerName .. " n'a rien mis dans le trou noir.")
        end
    end
end

-- Initialise le contrôleur avec une référence au GameLoopManager
function BlackholeController.Init(manager)
    local map = workspace:FindFirstChild("Map")
    local barrier = map and map:FindFirstChild("BlackholeBarrier")
    -- On assigne la variable module-level (et non une locale) pour que applyState
    -- puisse la voir et mettre à jour CanConsume / la couleur.
    blackholeZone = map and map:FindFirstChild("BlackholeZone")
    gameLoopManager = manager

    -- 1. LE BOUCLIER RÉPULSIF (Anti-Tunneling & Network Ownership)
    if barrier and barrier:IsA("BasePart") then
        connection = barrier.Touched:Connect(function(hit)
            -- On ne repousse que pendant la digestion
            if manager.GetState() ~= "Digesting" then return end

            -- Calcul de la direction depuis le centre (aplatie sur X et Z pour un beau vol plané)
            local direction = (hit.Position - barrier.Position)
            direction = Vector3.new(direction.X, 0, direction.Z).Unit
            local pushForce = (direction * 180) + Vector3.new(0, 60, 0) -- Force massive

            -- CAS A : L'objet jeté
            if hit.Name == "Item" and not hit.Anchored then
                -- 🚨 FORCER LE CONTRÔLE SERVEUR (Évite que le client force le passage)
                if hit:CanSetNetworkOwnership() then
                    hit:SetNetworkOwner(nil)
                end
                
                -- Stopper sa course et le reculer physiquement d'un cran (Anti-Tunneling)
                hit.AssemblyLinearVelocity = Vector3.zero
                hit.CFrame = hit.CFrame + (direction * 2) 
                
                -- Le propulser violemment
                hit:ApplyImpulse(pushForce * hit.AssemblyMass)
                return
            end

            -- CAS B : Le Joueur
            -- On réutilise exactement la même logique que slapPlayer (ragdoll + debounce
            -- via stunnedPlayers + knockbackEvent:FireClient) pour unifier les deux KO.
            local character = hit.Parent
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    slapPlayer(character, barrier.Position)
                end
            end
        end)
    end

    -- 2. L'ABSORPTION DES POINTS (Phase Feeding)
    if blackholeZone then
        connection = blackholeZone.Touched:Connect(function(hit)
            -- On ne mange que si le script du Trou Noir l'autorise (géré par applyState)
            if not blackholeZone:GetAttribute("CanConsume") then return end
            
            if hit.Name == "Item" and not hit.Anchored then
                local owner = hit:GetAttribute("Owner") or "Unknown"
                
                -- Si l'objet n'a pas de propriétaire valide (ex: un bug), on le détruit sans donner de point
                if owner == "Unknown" then
                    hit:Destroy()
                    return
                end

                -- Enregistre les scores dans la table module-level playerGauges.
                playerGauges[owner] = (playerGauges[owner] or 0) + 1
                print("[Blackhole] Miam ! +1 point pour " .. owner .. " (Total: " .. playerGauges[owner] .. ")")
                
                hit:Destroy()
            end
        end))
    end
end

-- Nettoie toutes les connexions
function BlackholeController.Destroy()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
end

return BlackholeController
