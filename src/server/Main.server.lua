--!strict
-- Main : point d'entrée du serveur.
-- Require et initialise le MapGenerator, le BlackholeController et le GameLoopManager.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require protégé : affiche un warn() clair si le module est manquant, vide ou
-- plante à l'exécution, et retourne nil au lieu de faire crasher tout le serveur.
local function safeRequire(module, moduleName)
    if not module then
        warn("[Main] ⚠️ Module introuvable : " .. moduleName .. " (le fichier n'existe pas ou n'est pas un ModuleScript).")
        return nil
    end

    local ok, result = pcall(require, module)
    if not ok then
        warn("[Main] ⚠️ Échec du require de " .. moduleName .. " : " .. tostring(result))
        return nil
    end

    if result == nil then
        warn("[Main] ⚠️ Le module " .. moduleName .. " est vide (il ne retourne rien).")
        return nil
    end

    return result
end

-- Modules locaux (même dossier que ce script)
local MapGenerator = safeRequire(script.Parent:FindFirstChild("MapGenerator"), "MapGenerator")
local BlackholeController = safeRequire(script.Parent:FindFirstChild("BlackholeController"), "BlackholeController")
local ItemSpawner = safeRequire(script.Parent:FindFirstChild("ItemSpawner"), "ItemSpawner")
local SessionData = safeRequire(script.Parent:FindFirstChild("SessionData"), "SessionData")

-- Module partagé
local GameLoopManager = safeRequire(ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("GameLoopManager"), "GameLoopManager")

-- 0. Initialisation de l'inventaire de session (avant tout le reste)
if SessionData and SessionData.Init then
    SessionData.Init()
else
    warn("[Main] ⚠️ SessionData indisponible : l'inventaire de session ne sera pas initialisé.")
end

-- 1. Génération de la map (trou noir + 4 bases)
if MapGenerator and MapGenerator.generate then
    MapGenerator.generate()
else
    warn("[Main] ⚠️ MapGenerator indisponible : la map ne sera pas générée.")
end

-- 2. Initialisation du contrôleur du trou noir avec le GameLoopManager
if BlackholeController and BlackholeController.Init and GameLoopManager then
    BlackholeController.Init(GameLoopManager)
else
    warn("[Main] ⚠️ BlackholeController ou GameLoopManager indisponible : le trou noir ne sera pas initialisé.")
end

-- 3. Démarrage du game loop (Feeding -> Digesting -> ...)
if GameLoopManager and GameLoopManager.Start then
    GameLoopManager.Start()
else
    warn("[Main] ⚠️ GameLoopManager indisponible : le game loop ne démarrera pas.")
end

-- 4. Démarrage du spawner d'objets
if ItemSpawner and ItemSpawner.start then
    ItemSpawner.start()
else
    warn("[Main] ⚠️ ItemSpawner indisponible : les objets ne seront pas spawnés.")
end
