--!strict
-- Main : point d'entrée du serveur. L'ordre compte :
-- tous les modules s'abonnent au GameLoopManager AVANT qu'il ne démarre.
-- Pas de pcall ici : si un module plante, on veut voir l'erreur rouge dans la sortie.

local BaseManager = require(script.Parent.BaseManager)
local BlackholeController = require(script.Parent.BlackholeController)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local ItemSpawner = require(script.Parent.ItemSpawner)
local MapGenerator = require(script.Parent.MapGenerator)
local SessionData = require(script.Parent.SessionData)
local TrainingController = require(script.Parent.TrainingController)

SessionData.Init()

local bases = MapGenerator.generate()
BaseManager.Init(bases)
ItemInteraction.Init()
BlackholeController.Init()
ItemSpawner.Init()
TrainingController.Init(bases)

GameLoopManager.Start()
print("[Main] Serveur prêt.")
