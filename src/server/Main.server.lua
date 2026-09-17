--!strict
-- Main : point d'entrée du serveur.
-- Require et initialise le MapGenerator, le BlackholeController et le GameLoopManager.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules locaux (même dossier que ce script)
local MapGenerator = require(script.Parent.MapGenerator)
local BlackholeController = require(script.Parent.BlackholeController)

-- Module partagé
local GameLoopManager = require(ReplicatedStorage.Shared.GameLoopManager)

-- 1. Génération de la map (trou noir + 4 bases)
MapGenerator.generate()

-- 2. Initialisation du contrôleur du trou noir avec le GameLoopManager
BlackholeController.Init(GameLoopManager)

-- 3. Démarrage du game loop (Feeding -> Digesting -> ...)
GameLoopManager.Start()
