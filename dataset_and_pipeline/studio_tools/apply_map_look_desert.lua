--!nocheck
-- Décors « niveau studio » du monde Desert dans Studio (mode Édition, barre MCP execute_luau ou rbxm + require).
-- GÉNÉRÉ par dataset_and_pipeline/tools/make_map_look_script.py (ne pas modifier à la main).
-- Avant : importer baked_assets/map/desert/Decors_Desert.fbx (Fichier > Importer 3D, réglages par défaut) : les MeshParts
-- nommées comme les décors arrivent dans le Workspace. Ce script :
--   1. range ces MeshParts dans ReplicatedStorage.ArtModels.Map.<Asset> (+ lueur / couleur de map_roblox.json) et
--      supprime l'import (sauvegarder le jeu ensuite : ArtModels n'est que dans le fichier du jeu) ;
--   2. pose les décors de l'arène dans Workspace.MapDecor.Desert (un Model par zone et par huitième de carte,
--      pour le streaming), sans toucher à Workspace.Map ni aux autres mondes ; les pièces de l'ancien rangement
--      (directement sous MapDecor) passent dans MapDecor.Prairie. Sans les décors des bases (zone « base ») :
--      ce sont les dossiers <Monde>Look de server/MapGenerator. client/WorldSkin montre le monde du joueur ;
--   3. MODE = "remove" retire Workspace.MapDecor.Desert.

local WORLD = "Desert"
local MODE = "all" -- "all" | "collect" | "decor" | "remove"
local INCLUDE_BASES = false
local FBX_YAW_OFFSET = 180

-- Couleurs renvoyées à la main (celles de l'import restaient grises) et masques de lueur (map_roblox.json).
local COLOR_OVERRIDE = {
}
local EMISSIVE = {
}

-- Taille de chaque décor dans Roblox (studs, axes X, Y haut, Z) avant mise à l'échelle.
local SIZE = {
	Caisse = Vector3.new(4.15, 4.1, 4.25),
	Desert_ArcheNaturelle = Vector3.new(28.995, 17.034, 6.211),
	Desert_Auvent = Vector3.new(8.02, 6.209, 6.794),
	Desert_Brasero = Vector3.new(3.362, 4.2, 3.198),
	Desert_CactusTonneau = Vector3.new(6.48, 2.9, 3.742),
	Desert_ColonneBrisee = Vector3.new(12.039, 8.905, 8.806),
	Desert_Dalle = Vector3.new(8.077, 1.416, 5.975),
	Desert_Escalier = Vector3.new(19.2, 2.3, 5.788),
	Desert_Figuier = Vector3.new(9.433, 7.692, 1.41),
	Desert_Fossile = Vector3.new(29.778, 8.716, 13.851),
	Desert_Jarre = Vector3.new(4.89, 3.74, 3.59),
	Desert_Mesa = Vector3.new(36.283, 29.894, 14.988),
	Desert_Muret = Vector3.new(11.959, 4.4, 2.85),
	Desert_Obelisque = Vector3.new(5.0, 15.95, 5.0),
	Desert_Palmier = Vector3.new(14.82, 15.386, 14.904),
	Desert_PorteTemple = Vector3.new(30.0, 23.35, 5.4),
	Desert_RocherGres_A = Vector3.new(7.913, 11.014, 5.839),
	Desert_RocherGres_B = Vector3.new(10.038, 4.515, 6.107),
	Desert_Saguaro = Vector3.new(9.1, 13.3, 2.9),
	Desert_Touffe = Vector3.new(2.349, 2.912, 2.323),
	Pancarte = Vector3.new(9.772, 7.5, 2.783),
}

-- asset, x, y (pied), z, yaw en degrés, échelle X, Y, Z, collision, zone
local ITEMS = {
	{ "Desert_Dalle", 44.615, -0.55, -5.874, 277.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 41.575, -0.55, -17.221, 292.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 35.701, -0.55, -27.394, 307.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 27.394, -0.55, -35.701, 322.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 17.221, -0.55, -41.575, 337.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 5.874, -0.55, -44.615, 352.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -5.874, -0.55, -44.615, 7.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -17.221, -0.55, -41.575, 22.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -27.394, -0.55, -35.701, 37.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -35.701, -0.55, -27.394, 52.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -41.575, -0.55, -17.221, 67.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -44.615, -0.55, -5.874, 82.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -44.615, -0.55, 5.874, 97.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -41.575, -0.55, 17.221, 112.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -35.701, -0.55, 27.394, 127.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -27.394, -0.55, 35.701, 142.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -17.221, -0.55, 41.575, 157.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", -5.874, -0.55, 44.615, 172.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 5.874, -0.55, 44.615, 187.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 17.221, -0.55, 41.575, 202.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 27.394, -0.55, 35.701, 217.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 35.701, -0.55, 27.394, 232.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 41.575, -0.55, 17.221, 247.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_Dalle", 44.615, -0.55, 5.874, 262.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Desert_PorteTemple", 66.0, 0, -0.0, 270.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_Obelisque", 62.232, 0, 14.941, 45.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_Obelisque", 62.232, 0, -14.941, 45.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_ColonneBrisee", 52.661, -0.2, 21.813, 0.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_PorteTemple", 46.669, 0, 46.669, 225.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_Obelisque", 33.44, 0, 54.569, 0.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_Obelisque", 54.569, 0, 33.44, 0.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_ColonneBrisee", 21.813, -0.2, 52.661, 53.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_PorteTemple", 0.0, 0, 66.0, 180.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_Obelisque", -14.941, 0, 62.232, 315.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_Obelisque", 14.941, 0, 62.232, 315.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_ColonneBrisee", -21.813, -0.2, 52.661, 106.0, 1.1, 1.1, 1.1, true, "trou" },
	{ "Desert_PorteTemple", -46.669, 0, 46.669, 135.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_Obelisque", -54.569, 0, 33.44, 270.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_Obelisque", -33.44, 0, 54.569, 270.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_ColonneBrisee", -52.661, -0.2, 21.813, 159.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_PorteTemple", -66.0, 0, 0.0, 90.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_Obelisque", -62.232, 0, -14.941, 225.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_Obelisque", -62.232, 0, 14.941, 225.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_ColonneBrisee", -52.661, -0.2, -21.813, 212.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_PorteTemple", -46.669, 0, -46.669, 45.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_Obelisque", -33.44, 0, -54.569, 180.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_Obelisque", -54.569, 0, -33.44, 180.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_ColonneBrisee", -21.813, -0.2, -52.661, 265.0, 1.1, 1.1, 1.1, true, "trou" },
	{ "Desert_PorteTemple", -0.0, 0, -66.0, 0.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_Obelisque", 14.941, 0, -62.232, 135.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_Obelisque", -14.941, 0, -62.232, 135.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_ColonneBrisee", 21.813, -0.2, -52.661, 318.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_PorteTemple", 46.669, 0, -46.669, 315.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_Obelisque", 54.569, 0, -33.44, 90.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_Obelisque", 33.44, 0, -54.569, 90.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Desert_ColonneBrisee", 52.661, -0.2, -21.813, 11.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Desert_Touffe", 70.953, 0, 10.505, 309.6, 0.962, 0.962, 0.962, false, "chemin" },
	{ "Desert_Touffe", 81.739, 0, 10.682, 282.01, 1.229, 1.229, 1.229, false, "chemin" },
	{ "Desert_Touffe", 96.584, 0, 10.983, 211.15, 1.044, 1.044, 1.044, false, "chemin" },
	{ "Desert_Touffe", 110.497, 0, 9.799, 161.88, 1.389, 1.389, 1.389, false, "chemin" },
	{ "Desert_Touffe", 124.979, 0, 10.823, 90.54, 1.488, 1.488, 1.488, false, "chemin" },
	{ "Desert_Touffe", 141.413, 0, 11.049, 184.89, 0.946, 0.946, 0.946, false, "chemin" },
	{ "Desert_Touffe", 153.136, 0, 10.603, 164.68, 1.426, 1.426, 1.426, false, "chemin" },
	{ "Desert_Touffe", 74.619, 0, -9.645, 130.88, 1.153, 1.153, 1.153, false, "chemin" },
	{ "Desert_Touffe", 86.81, 0, -10.654, 41.92, 1.204, 1.204, 1.204, false, "chemin" },
	{ "Desert_Touffe", 101.811, 0, -10.68, 330.03, 1.055, 1.055, 1.055, false, "chemin" },
	{ "Desert_Touffe", 114.17, 0, -11.267, 186.48, 0.915, 0.915, 0.915, false, "chemin" },
	{ "Desert_CactusTonneau", 124.967, 0, -9.832, 253.68, 0.966, 0.966, 0.966, false, "chemin" },
	{ "Desert_Touffe", 134.787, 0, -10.72, 173.56, 1.037, 1.037, 1.037, false, "chemin" },
	{ "Desert_Touffe", 150.875, 0, -10.728, 168.99, 1.458, 1.458, 1.458, false, "chemin" },
	{ "Pancarte", 164.0, 0, 11.0, 70.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Desert_Touffe", 45.083, 0, 60.085, 110.75, 1.38, 1.38, 1.38, false, "chemin" },
	{ "Desert_Touffe", 54.389, 0, 69.185, 155.9, 1.077, 1.077, 1.077, false, "chemin" },
	{ "Desert_Touffe", 62.843, 0, 76.503, 215.02, 1.175, 1.175, 1.175, false, "chemin" },
	{ "Desert_Touffe", 71.584, 0, 86.406, 93.64, 1.191, 1.191, 1.191, false, "chemin" },
	{ "Desert_Touffe", 80.411, 0, 96.091, 200.82, 1.444, 1.444, 1.444, false, "chemin" },
	{ "Desert_Touffe", 92.127, 0, 106.509, 35.41, 1.314, 1.314, 1.314, false, "chemin" },
	{ "Desert_Touffe", 102.679, 0, 117.567, 347.5, 1.48, 1.48, 1.48, false, "chemin" },
	{ "Desert_Touffe", 59.078, 0, 45.338, 179.43, 0.958, 0.958, 0.958, false, "chemin" },
	{ "Desert_Touffe", 70.112, 0, 55.489, 5.05, 0.9, 0.9, 0.9, false, "chemin" },
	{ "Desert_CactusTonneau", 80.424, 0, 64.475, 285.76, 0.774, 0.774, 0.774, false, "chemin" },
	{ "Desert_Touffe", 90.072, 0, 74.581, 240.65, 1.281, 1.281, 1.281, false, "chemin" },
	{ "Desert_Touffe", 96.753, 0, 82.379, 277.03, 1.47, 1.47, 1.47, false, "chemin" },
	{ "Desert_CactusTonneau", 106.418, 0, 91.008, 80.25, 0.876, 0.876, 0.876, false, "chemin" },
	{ "Desert_Touffe", 118.401, 0, 102.595, 30.4, 1.301, 1.301, 1.301, false, "chemin" },
	{ "Pancarte", 108.187, 0, 123.744, 25.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Desert_Touffe", -11.247, 0, 76.268, 148.33, 1.385, 1.385, 1.385, false, "chemin" },
	{ "Desert_CactusTonneau", -9.954, 0, 89.428, 38.21, 0.966, 0.966, 0.966, false, "chemin" },
	{ "Desert_Touffe", -10.225, 0, 98.839, 277.03, 0.915, 0.915, 0.915, false, "chemin" },
	{ "Desert_Touffe", -10.19, 0, 111.922, 117.38, 0.973, 0.973, 0.973, false, "chemin" },
	{ "Desert_Touffe", -10.629, 0, 128.512, 55.4, 1.212, 1.212, 1.212, false, "chemin" },
	{ "Desert_Touffe", -10.206, 0, 140.981, 244.26, 0.942, 0.942, 0.942, false, "chemin" },
	{ "Desert_Touffe", -9.952, 0, 153.174, 16.29, 1.227, 1.227, 1.227, false, "chemin" },
	{ "Desert_Touffe", 10.958, 0, 73.615, 255.94, 1.427, 1.427, 1.427, false, "chemin" },
	{ "Desert_Touffe", 10.554, 0, 83.648, 186.07, 1.474, 1.474, 1.474, false, "chemin" },
	{ "Desert_Touffe", 11.12, 0, 93.931, 153.13, 1.148, 1.148, 1.148, false, "chemin" },
	{ "Desert_Touffe", 10.149, 0, 103.56, 94.84, 1.199, 1.199, 1.199, false, "chemin" },
	{ "Desert_Touffe", 10.348, 0, 118.802, 117.28, 1.189, 1.189, 1.189, false, "chemin" },
	{ "Desert_Touffe", 11.034, 0, 128.763, 293.81, 1.409, 1.409, 1.409, false, "chemin" },
	{ "Desert_Touffe", 11.317, 0, 139.614, 232.44, 1.145, 1.145, 1.145, false, "chemin" },
	{ "Desert_Touffe", 11.129, 0, 154.88, 346.03, 1.111, 1.111, 1.111, false, "chemin" },
	{ "Desert_Touffe", 10.612, 0, 165.134, 193.82, 0.966, 0.966, 0.966, false, "chemin" },
	{ "Pancarte", -11.0, 0, 164.0, 340.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Desert_Touffe", -60.153, 0, 45.13, 106.09, 1.061, 1.061, 1.061, false, "chemin" },
	{ "Desert_Touffe", -69.067, 0, 55.232, 343.76, 1.003, 1.003, 1.003, false, "chemin" },
	{ "Desert_Touffe", -80.14, 0, 64.631, 66.78, 1.278, 1.278, 1.278, false, "chemin" },
	{ "Desert_Touffe", -88.756, 0, 74.475, 104.77, 1.089, 1.089, 1.089, false, "chemin" },
	{ "Desert_Touffe", -96.323, 0, 82.587, 323.3, 1.366, 1.366, 1.366, false, "chemin" },
	{ "Desert_CactusTonneau", -104.972, 0, 91.356, 8.27, 0.737, 0.737, 0.737, false, "chemin" },
	{ "Desert_Touffe", -115.929, 0, 100.886, 126.11, 1.368, 1.368, 1.368, false, "chemin" },
	{ "Desert_Touffe", -45.63, 0, 60.772, 113.78, 1.029, 1.029, 1.029, false, "chemin" },
	{ "Desert_Touffe", -54.148, 0, 70.217, 247.13, 1.417, 1.417, 1.417, false, "chemin" },
	{ "Desert_Touffe", -64.437, 0, 80.365, 340.94, 1.114, 1.114, 1.114, false, "chemin" },
	{ "Desert_CactusTonneau", -75.581, 0, 90.269, 250.31, 0.787, 0.787, 0.787, false, "chemin" },
	{ "Desert_CactusTonneau", -86.903, 0, 102.516, 276.44, 0.796, 0.796, 0.796, false, "chemin" },
	{ "Desert_Touffe", -98.703, 0, 113.66, 201.91, 1.333, 1.333, 1.333, false, "chemin" },
	{ "Desert_CactusTonneau", -105.606, 0, 120.758, 45.25, 0.806, 0.806, 0.806, false, "chemin" },
	{ "Pancarte", -123.744, 0, 108.187, 295.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Desert_Touffe", -75.246, 0, -9.652, 128.15, 1.13, 1.13, 1.13, false, "chemin" },
	{ "Desert_Touffe", -86.161, 0, -10.358, 45.07, 1.226, 1.226, 1.226, false, "chemin" },
	{ "Desert_Touffe", -100.453, 0, -11.282, 142.87, 1.053, 1.053, 1.053, false, "chemin" },
	{ "Desert_Touffe", -110.635, 0, -9.642, 172.38, 1.058, 1.058, 1.058, false, "chemin" },
	{ "Desert_Touffe", -122.153, 0, -11.3, 302.24, 1.232, 1.232, 1.232, false, "chemin" },
	{ "Desert_Touffe", -136.354, 0, -11.33, 95.48, 1.28, 1.28, 1.28, false, "chemin" },
	{ "Desert_Touffe", -151.391, 0, -10.171, 4.11, 1.487, 1.487, 1.487, false, "chemin" },
	{ "Desert_Touffe", -164.155, 0, -11.346, 310.36, 1.456, 1.456, 1.456, false, "chemin" },
	{ "Desert_Touffe", -73.193, 0, 11.357, 83.7, 1.397, 1.397, 1.397, false, "chemin" },
	{ "Desert_Touffe", -84.942, 0, 9.962, 229.32, 1.229, 1.229, 1.229, false, "chemin" },
	{ "Desert_Touffe", -97.735, 0, 11.02, 67.64, 1.277, 1.277, 1.277, false, "chemin" },
	{ "Desert_Touffe", -107.965, 0, 11.209, 292.95, 1.401, 1.401, 1.401, false, "chemin" },
	{ "Desert_Touffe", -122.584, 0, 11.032, 30.31, 1.124, 1.124, 1.124, false, "chemin" },
	{ "Desert_Touffe", -137.432, 0, 9.848, 359.57, 0.911, 0.911, 0.911, false, "chemin" },
	{ "Desert_Touffe", -148.169, 0, 11.128, 206.15, 1.473, 1.473, 1.473, false, "chemin" },
	{ "Desert_Touffe", -160.213, 0, 11.334, 231.86, 0.995, 0.995, 0.995, false, "chemin" },
	{ "Pancarte", -164.0, 0, -11.0, 250.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Desert_Touffe", -42.261, 0, -57.702, 94.12, 0.925, 0.925, 0.925, false, "chemin" },
	{ "Desert_Touffe", -51.908, 0, -67.488, 105.45, 1.225, 1.225, 1.225, false, "chemin" },
	{ "Desert_Touffe", -60.057, 0, -76.109, 268.92, 0.906, 0.906, 0.906, false, "chemin" },
	{ "Desert_Touffe", -70.476, 0, -85.274, 292.37, 1.441, 1.441, 1.441, false, "chemin" },
	{ "Desert_Touffe", -81.72, 0, -97.834, 185.83, 1.008, 1.008, 1.008, false, "chemin" },
	{ "Desert_Touffe", -92.194, 0, -106.187, 185.4, 1.429, 1.429, 1.429, false, "chemin" },
	{ "Desert_Touffe", -102.403, 0, -115.985, 132.48, 1.03, 1.03, 1.03, false, "chemin" },
	{ "Desert_CactusTonneau", -108.866, 0, -123.995, 354.61, 0.845, 0.845, 0.845, false, "chemin" },
	{ "Desert_Touffe", -60.881, 0, -46.334, 233.12, 1.109, 1.109, 1.109, false, "chemin" },
	{ "Desert_Touffe", -72.059, 0, -58.175, 298.31, 1.31, 1.31, 1.31, false, "chemin" },
	{ "Desert_CactusTonneau", -81.593, 0, -66.527, 280.46, 0.726, 0.726, 0.726, false, "chemin" },
	{ "Desert_Touffe", -90.408, 0, -76.038, 81.38, 1.095, 1.095, 1.095, false, "chemin" },
	{ "Desert_Touffe", -99.661, 0, -85.24, 260.59, 1.414, 1.414, 1.414, false, "chemin" },
	{ "Desert_Touffe", -108.108, 0, -94.082, 79.26, 1.313, 1.313, 1.313, false, "chemin" },
	{ "Desert_Touffe", -117.221, 0, -101.64, 289.17, 1.129, 1.129, 1.129, false, "chemin" },
	{ "Desert_Touffe", -124.402, 0, -108.934, 45.93, 1.061, 1.061, 1.061, false, "chemin" },
	{ "Pancarte", -108.187, 0, -123.744, 205.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Desert_Touffe", 11.114, 0, -72.56, 52.33, 1.276, 1.276, 1.276, false, "chemin" },
	{ "Desert_Touffe", 11.35, 0, -83.435, 44.37, 1.076, 1.076, 1.076, false, "chemin" },
	{ "Desert_CactusTonneau", 10.322, 0, -96.099, 257.93, 0.902, 0.902, 0.902, false, "chemin" },
	{ "Desert_Touffe", 10.823, 0, -107.794, 327.08, 1.408, 1.408, 1.408, false, "chemin" },
	{ "Desert_Touffe", 10.802, 0, -124.416, 75.57, 1.111, 1.111, 1.111, false, "chemin" },
	{ "Desert_Touffe", 11.261, 0, -136.059, 3.79, 1.235, 1.235, 1.235, false, "chemin" },
	{ "Desert_Touffe", 10.201, 0, -147.077, 149.26, 1.367, 1.367, 1.367, false, "chemin" },
	{ "Desert_Touffe", 11.201, 0, -159.884, 13.5, 1.032, 1.032, 1.032, false, "chemin" },
	{ "Desert_CactusTonneau", -10.084, 0, -76.815, 75.32, 0.837, 0.837, 0.837, false, "chemin" },
	{ "Desert_CactusTonneau", -10.734, 0, -88.03, 249.28, 0.862, 0.862, 0.862, false, "chemin" },
	{ "Desert_Touffe", -9.772, 0, -97.122, 78.99, 1.178, 1.178, 1.178, false, "chemin" },
	{ "Desert_Touffe", -9.907, 0, -110.97, 204.35, 1.327, 1.327, 1.327, false, "chemin" },
	{ "Desert_CactusTonneau", -10.606, 0, -125.419, 97.51, 0.826, 0.826, 0.826, false, "chemin" },
	{ "Desert_Touffe", -10.922, 0, -135.901, 355.82, 1.446, 1.446, 1.446, false, "chemin" },
	{ "Desert_Touffe", -10.214, 0, -150.164, 218.38, 1.053, 1.053, 1.053, false, "chemin" },
	{ "Desert_CactusTonneau", -11.11, 0, -166.231, 176.4, 0.707, 0.707, 0.707, false, "chemin" },
	{ "Pancarte", 11.0, 0, -164.0, 160.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Desert_Touffe", 58.683, 0, -43.184, 98.51, 1.405, 1.405, 1.405, false, "chemin" },
	{ "Desert_CactusTonneau", 66.626, 0, -52.494, 147.91, 0.719, 0.719, 0.719, false, "chemin" },
	{ "Desert_Touffe", 77.638, 0, -62.379, 275.71, 1.079, 1.079, 1.079, false, "chemin" },
	{ "Desert_Touffe", 86.006, 0, -72.199, 188.08, 1.095, 1.095, 1.095, false, "chemin" },
	{ "Desert_Touffe", 94.485, 0, -80.044, 355.99, 1.418, 1.418, 1.418, false, "chemin" },
	{ "Desert_Touffe", 101.731, 0, -87.499, 313.75, 1.212, 1.212, 1.212, false, "chemin" },
	{ "Desert_Touffe", 110.068, 0, -96.221, 77.34, 1.178, 1.178, 1.178, false, "chemin" },
	{ "Desert_Touffe", 118.129, 0, -103.26, 184.93, 1.375, 1.375, 1.375, false, "chemin" },
	{ "Desert_Touffe", 47.03, 0, -61.851, 302.61, 1.095, 1.095, 1.095, false, "chemin" },
	{ "Desert_Touffe", 59.158, 0, -73.733, 194.07, 0.991, 0.991, 0.991, false, "chemin" },
	{ "Desert_Touffe", 67.893, 0, -83.963, 47.25, 1.39, 1.39, 1.39, false, "chemin" },
	{ "Desert_Touffe", 79.142, 0, -92.874, 12.43, 1.374, 1.374, 1.374, false, "chemin" },
	{ "Desert_Touffe", 90.679, 0, -104.711, 194.51, 1.114, 1.114, 1.114, false, "chemin" },
	{ "Desert_CactusTonneau", 99.62, 0, -113.672, 66.83, 0.746, 0.746, 0.746, false, "chemin" },
	{ "Desert_Touffe", 109.226, 0, -124.049, 10.44, 1.033, 1.033, 1.033, false, "chemin" },
	{ "Pancarte", 123.744, 0, -108.187, 115.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Desert_Touffe", -110.987, 0, 30.547, 268.97, 0.924, 0.924, 0.924, false, "prairie" },
	{ "Desert_Touffe", -61.384, 0, -121.409, 14.5, 0.806, 0.806, 0.806, false, "prairie" },
	{ "Desert_Touffe", 103.723, 0, -70.163, 253.67, 1.451, 1.451, 1.451, false, "prairie" },
	{ "Desert_Touffe", 47.459, 0, -78.897, 293.92, 1.138, 1.138, 1.138, false, "prairie" },
	{ "Desert_Touffe", -133.285, 0, -59.544, 61.44, 0.98, 0.98, 0.98, false, "prairie" },
	{ "Desert_Touffe", 91.968, 0, 18.789, 57.06, 1.593, 1.593, 1.593, false, "prairie" },
	{ "Desert_Touffe", -98.408, 0, -52.522, 308.22, 1.364, 1.364, 1.364, false, "prairie" },
	{ "Desert_Touffe", 126.338, 0, 25.394, 158.57, 1.558, 1.558, 1.558, false, "prairie" },
	{ "Desert_Touffe", -65.62, 0, 51.971, 322.9, 1.391, 1.391, 1.391, false, "prairie" },
	{ "Desert_Touffe", -28.132, 0, 125.14, 56.9, 0.938, 0.938, 0.938, false, "prairie" },
	{ "Desert_Touffe", 150.187, 0, 50.891, 10.98, 1.577, 1.577, 1.577, false, "prairie" },
	{ "Desert_Touffe", -91.181, 0, 122.548, 284.2, 1.03, 1.03, 1.03, false, "prairie" },
	{ "Desert_Touffe", -149.176, 0, 19.815, 302.57, 1.191, 1.191, 1.191, false, "prairie" },
	{ "Desert_Touffe", -146.524, 0, 57.637, 164.17, 1.287, 1.287, 1.287, false, "prairie" },
	{ "Desert_Touffe", -128.579, 0, 85.084, 241.21, 1.061, 1.061, 1.061, false, "prairie" },
	{ "Desert_Touffe", -101.919, 0, -25.495, 297.34, 1.22, 1.22, 1.22, false, "prairie" },
	{ "Desert_Touffe", -82.735, 0, 15.95, 99.4, 0.83, 0.83, 0.83, false, "prairie" },
	{ "Desert_Touffe", -69.094, 0, 43.975, 332.12, 1.252, 1.252, 1.252, false, "prairie" },
	{ "Desert_Touffe", -101.925, 0, 51.915, 172.31, 0.818, 0.818, 0.818, false, "prairie" },
	{ "Desert_Touffe", 70.02, 0, 52.11, 37.86, 0.873, 0.873, 0.873, false, "prairie" },
	{ "Desert_Touffe", -95.101, 0, 21.112, 349.87, 1.399, 1.399, 1.399, false, "prairie" },
	{ "Desert_Touffe", 114.135, 0, -54.697, 43.08, 1.571, 1.571, 1.571, false, "prairie" },
	{ "Desert_Touffe", 112.727, 0, 76.525, 110.53, 1.177, 1.177, 1.177, false, "prairie" },
	{ "Desert_Touffe", -66.361, 0, -135.991, 248.56, 1.12, 1.12, 1.12, false, "prairie" },
	{ "Desert_Touffe", -102.187, 0, -57.129, 214.45, 1.151, 1.151, 1.151, false, "prairie" },
	{ "Desert_Touffe", 14.771, 0, 124.55, 212.6, 1.186, 1.186, 1.186, false, "prairie" },
	{ "Desert_Touffe", -85.72, 0, -18.923, 86.77, 1.217, 1.217, 1.217, false, "prairie" },
	{ "Desert_Touffe", -12.184, 0, -111.6, 264.69, 0.821, 0.821, 0.821, false, "prairie" },
	{ "Desert_Touffe", -95.835, 0, 71.687, 343.14, 0.898, 0.898, 0.898, false, "prairie" },
	{ "Desert_Touffe", 80.191, 0, -41.484, 145.94, 0.889, 0.889, 0.889, false, "prairie" },
	{ "Desert_Touffe", 125.353, 0, -98.067, 144.33, 0.805, 0.805, 0.805, false, "prairie" },
	{ "Desert_Touffe", 32.264, 0, -92.606, 288.14, 1.22, 1.22, 1.22, false, "prairie" },
	{ "Desert_Touffe", 70.766, 0, 43.568, 60.35, 1.529, 1.529, 1.529, false, "prairie" },
	{ "Desert_Touffe", 28.807, 0, -143.886, 289.11, 1.25, 1.25, 1.25, false, "prairie" },
	{ "Desert_Touffe", 98.566, 0, 72.19, 12.81, 1.568, 1.568, 1.568, false, "prairie" },
	{ "Desert_Muret", 173.0, 0, -36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 173.0, 0, -24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 173.0, 0, -12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 173.0, 0, 12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 173.0, 0, 24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 173.0, 0, 36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 257.0, 0, -36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 257.0, 0, -24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 257.0, 0, -12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 257.0, 0, -0.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 257.0, 0, 12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 257.0, 0, 24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 257.0, 0, 36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 179.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 191.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 203.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 215.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 227.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 239.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 251.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 179.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 191.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 203.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 215.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 227.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 239.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 251.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Escalier", 170.4, 0, 0.0, 270.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Desert_PorteTemple", 173.4, 0, 0.0, 270.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Caisse", 183.0, 1.0, -32.0, 277.66, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", 179.0, 1.0, -36.0, 249.79, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", 233.0, 1.0, -37.0, 302.72, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", 228.0, 1.0, -36.5, 270.31, 0.8, 0.8, 0.8, false, "base" },
	{ "Caisse", 183.0, 1.0, 32.0, 276.94, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", 179.0, 1.0, 36.0, 344.51, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", 233.0, 1.0, 37.0, 324.76, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", 228.0, 1.0, 36.5, 279.35, 0.8, 0.8, 0.8, false, "base" },
	{ "Desert_Muret", 147.785, 0, 96.874, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 139.3, 0, 105.359, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 130.815, 0, 113.844, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 113.844, 0, 130.815, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 105.359, 0, 139.3, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 96.874, 0, 147.785, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 207.182, 0, 156.271, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 198.697, 0, 164.756, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 190.212, 0, 173.241, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 181.726, 0, 181.726, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 173.241, 0, 190.212, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 164.756, 0, 198.697, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 156.271, 0, 207.182, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 156.271, 0, 96.874, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 164.756, 0, 105.359, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 173.241, 0, 113.844, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 181.726, 0, 122.329, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 190.212, 0, 130.815, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 198.697, 0, 139.3, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 207.182, 0, 147.785, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 96.874, 0, 156.271, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 105.359, 0, 164.756, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 113.844, 0, 173.241, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 122.329, 0, 181.726, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 130.815, 0, 190.212, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 139.3, 0, 198.697, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 147.785, 0, 207.182, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Escalier", 120.491, 0, 120.491, 225.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Desert_PorteTemple", 122.612, 0, 122.612, 225.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Caisse", 152.028, 1.0, 106.773, 227.41, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", 152.028, 1.0, 101.116, 349.57, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", 190.919, 1.0, 138.593, 16.93, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", 187.03, 1.0, 135.411, 216.82, 0.8, 0.8, 0.8, false, "base" },
	{ "Caisse", 106.773, 1.0, 152.028, 227.43, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", 101.116, 1.0, 152.028, 100.48, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", 138.593, 1.0, 190.919, 2.63, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", 135.411, 1.0, 187.03, 227.35, 0.8, 0.8, 0.8, false, "base" },
	{ "Desert_Muret", 36.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 24.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 12.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -12.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -24.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -36.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 36.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 24.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 12.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 0.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -12.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -24.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -36.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, 179.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, 191.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, 203.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, 215.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, 227.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, 239.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, 251.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, 179.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, 191.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, 203.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, 215.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, 227.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, 239.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, 251.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Escalier", 0.0, 0, 170.4, 180.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Desert_PorteTemple", 0.0, 0, 173.4, 180.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Caisse", 32.0, 1.0, 183.0, 172.7, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", 36.0, 1.0, 179.0, 332.93, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", 37.0, 1.0, 233.0, 25.67, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", 36.5, 1.0, 228.0, 184.01, 0.8, 0.8, 0.8, false, "base" },
	{ "Caisse", -32.0, 1.0, 183.0, 180.74, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", -36.0, 1.0, 179.0, 197.08, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", -37.0, 1.0, 233.0, 186.01, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", -36.5, 1.0, 228.0, 180.8, 0.8, 0.8, 0.8, false, "base" },
	{ "Desert_Muret", -96.874, 0, 147.785, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -105.359, 0, 139.3, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -113.844, 0, 130.815, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -130.815, 0, 113.844, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -139.3, 0, 105.359, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -147.785, 0, 96.874, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -156.271, 0, 207.182, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -164.756, 0, 198.697, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -173.241, 0, 190.212, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -181.726, 0, 181.726, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -190.212, 0, 173.241, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -198.697, 0, 164.756, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -207.182, 0, 156.271, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -96.874, 0, 156.271, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -105.359, 0, 164.756, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -113.844, 0, 173.241, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -122.329, 0, 181.726, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -130.815, 0, 190.212, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -139.3, 0, 198.697, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -147.785, 0, 207.182, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -156.271, 0, 96.874, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -164.756, 0, 105.359, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -173.241, 0, 113.844, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -181.726, 0, 122.329, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -190.212, 0, 130.815, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -198.697, 0, 139.3, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -207.182, 0, 147.785, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Escalier", -120.491, 0, 120.491, 135.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Desert_PorteTemple", -122.612, 0, 122.612, 135.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Caisse", -106.773, 1.0, 152.028, 134.92, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", -101.116, 1.0, 152.028, 19.16, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", -138.593, 1.0, 190.919, 126.72, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", -135.411, 1.0, 187.03, 135.74, 0.8, 0.8, 0.8, false, "base" },
	{ "Caisse", -152.028, 1.0, 106.773, 134.42, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", -152.028, 1.0, 101.116, 87.22, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", -190.919, 1.0, 138.593, 5.45, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", -187.03, 1.0, 135.411, 132.72, 0.8, 0.8, 0.8, false, "base" },
	{ "Desert_Muret", -173.0, 0, 36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -173.0, 0, 24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -173.0, 0, 12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -173.0, 0, -12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -173.0, 0, -24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -173.0, 0, -36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -257.0, 0, 36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -257.0, 0, 24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -257.0, 0, 12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -257.0, 0, 0.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -257.0, 0, -12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -257.0, 0, -24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -257.0, 0, -36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -179.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -191.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -203.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -215.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -227.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -239.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -251.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -179.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -191.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -203.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -215.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -227.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -239.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -251.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Escalier", -170.4, 0, 0.0, 90.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Desert_PorteTemple", -173.4, 0, 0.0, 90.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Caisse", -183.0, 1.0, 32.0, 83.43, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", -179.0, 1.0, 36.0, 242.95, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", -233.0, 1.0, 37.0, 64.25, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", -228.0, 1.0, 36.5, 84.74, 0.8, 0.8, 0.8, false, "base" },
	{ "Caisse", -183.0, 1.0, -32.0, 90.95, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", -179.0, 1.0, -36.0, 181.75, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", -233.0, 1.0, -37.0, 121.35, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", -228.0, 1.0, -36.5, 85.58, 0.8, 0.8, 0.8, false, "base" },
	{ "Desert_Muret", -147.785, 0, -96.874, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -139.3, 0, -105.359, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -130.815, 0, -113.844, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -113.844, 0, -130.815, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -105.359, 0, -139.3, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -96.874, 0, -147.785, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -207.182, 0, -156.271, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -198.697, 0, -164.756, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -190.212, 0, -173.241, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -181.726, 0, -181.726, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -173.241, 0, -190.212, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -164.756, 0, -198.697, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -156.271, 0, -207.182, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -156.271, 0, -96.874, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -164.756, 0, -105.359, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -173.241, 0, -113.844, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -181.726, 0, -122.329, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -190.212, 0, -130.815, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -198.697, 0, -139.3, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -207.182, 0, -147.785, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -96.874, 0, -156.271, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -105.359, 0, -164.756, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -113.844, 0, -173.241, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -122.329, 0, -181.726, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -130.815, 0, -190.212, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -139.3, 0, -198.697, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -147.785, 0, -207.182, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Escalier", -120.491, 0, -120.491, 45.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Desert_PorteTemple", -122.612, 0, -122.612, 45.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Caisse", -152.028, 1.0, -106.773, 47.34, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", -152.028, 1.0, -101.116, 60.81, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", -190.919, 1.0, -138.593, 33.27, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", -187.03, 1.0, -135.411, 41.89, 0.8, 0.8, 0.8, false, "base" },
	{ "Caisse", -106.773, 1.0, -152.028, 48.97, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", -101.116, 1.0, -152.028, 46.9, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", -138.593, 1.0, -190.919, 338.5, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", -135.411, 1.0, -187.03, 52.25, 0.8, 0.8, 0.8, false, "base" },
	{ "Desert_Muret", -36.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -24.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -12.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 12.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 24.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 36.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -36.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -24.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -12.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -0.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 12.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 24.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 36.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, -179.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, -191.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, -203.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, -215.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, -227.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, -239.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", -42.0, 0, -251.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, -179.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, -191.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, -203.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, -215.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, -227.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, -239.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 42.0, 0, -251.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Escalier", -0.0, 0, -170.4, 0.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Desert_PorteTemple", -0.0, 0, -173.4, 0.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Caisse", -32.0, 1.0, -183.0, 4.46, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", -36.0, 1.0, -179.0, 296.2, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", -37.0, 1.0, -233.0, 170.77, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", -36.5, 1.0, -228.0, 3.87, 0.8, 0.8, 0.8, false, "base" },
	{ "Caisse", 32.0, 1.0, -183.0, 2.99, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", 36.0, 1.0, -179.0, 116.06, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", 37.0, 1.0, -233.0, 178.19, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", 36.5, 1.0, -228.0, 352.31, 0.8, 0.8, 0.8, false, "base" },
	{ "Desert_Muret", 96.874, 0, -147.785, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 105.359, 0, -139.3, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 113.844, 0, -130.815, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 130.815, 0, -113.844, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 139.3, 0, -105.359, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 147.785, 0, -96.874, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 156.271, 0, -207.182, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 164.756, 0, -198.697, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 173.241, 0, -190.212, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 181.726, 0, -181.726, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 190.212, 0, -173.241, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 198.697, 0, -164.756, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 207.182, 0, -156.271, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 96.874, 0, -156.271, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 105.359, 0, -164.756, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 113.844, 0, -173.241, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 122.329, 0, -181.726, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 130.815, 0, -190.212, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 139.3, 0, -198.697, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 147.785, 0, -207.182, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 156.271, 0, -96.874, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 164.756, 0, -105.359, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 173.241, 0, -113.844, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 181.726, 0, -122.329, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 190.212, 0, -130.815, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 198.697, 0, -139.3, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Muret", 207.182, 0, -147.785, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Desert_Escalier", 120.491, 0, -120.491, 315.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Desert_PorteTemple", 122.612, 0, -122.612, 315.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Caisse", 106.773, 1.0, -152.028, 307.02, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", 101.116, 1.0, -152.028, 136.64, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", 138.593, 1.0, -190.919, 347.69, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", 135.411, 1.0, -187.03, 314.96, 0.8, 0.8, 0.8, false, "base" },
	{ "Caisse", 152.028, 1.0, -106.773, 313.7, 1.0, 1.0, 1.0, false, "base" },
	{ "Desert_Jarre", 152.028, 1.0, -101.116, 204.03, 0.9, 0.9, 0.9, false, "base" },
	{ "Desert_Jarre", 190.919, 1.0, -138.593, 184.43, 0.85, 0.85, 0.85, false, "base" },
	{ "Caisse", 187.03, 1.0, -135.411, 312.12, 0.8, 0.8, 0.8, false, "base" },
	{ "Desert_Mesa", 258.942, -0.5, 149.5, 242.91, 0.7, 0.95, 0.75, true, "colline" },
	{ "Desert_Saguaro", 262.535, 27.4, 148.248, 41.61, 1.251, 1.251, 1.251, true, "colline" },
	{ "Desert_Saguaro", 267.822, 27.4, 138.469, 110.48, 1.113, 1.113, 1.113, true, "colline" },
	{ "Desert_Mesa", 279.935, -0.5, 115.953, 253.17, 0.75, 1.0, 0.75, true, "colline" },
	{ "Desert_Saguaro", 280.279, 28.894, 121.547, 212.37, 0.997, 0.997, 0.997, true, "colline" },
	{ "Desert_Saguaro", 281.895, 28.894, 117.753, 40.73, 0.951, 0.951, 0.951, true, "colline" },
	{ "Desert_Mesa", 288.812, -0.5, 77.387, 256.36, 0.7, 0.9, 0.75, true, "colline" },
	{ "Desert_Saguaro", 289.626, 25.905, 83.78, 7.3, 1.143, 1.143, 1.143, true, "colline" },
	{ "Desert_Saguaro", 294.568, 25.905, 64.278, 159.87, 0.949, 0.949, 0.949, true, "colline" },
	{ "Desert_Mesa", 251.477, -0.5, 125.382, 240.23, 0.6, 0.5, 0.6, true, "colline" },
	{ "Desert_Saguaro", 251.35, 13.947, 131.131, 343.18, 1.076, 1.076, 1.076, true, "colline" },
	{ "Desert_Mesa", 266.479, -0.5, 89.163, 250.83, 0.6, 0.45, 0.6, true, "colline" },
	{ "Desert_Saguaro", 272.71, 12.452, 77.471, 266.27, 1.064, 1.064, 1.064, true, "colline" },
	{ "Desert_Saguaro", 240.593, 0, 53.742, 220.47, 0.811, 0.811, 0.811, true, "colline" },
	{ "Desert_RocherGres_A", 238.204, 0, 55.978, 80.95, 1.042, 1.042, 1.042, true, "colline" },
	{ "Desert_Palmier", 216.423, 0, 119.369, 216.56, 1.026, 1.026, 1.026, true, "colline" },
	{ "Desert_RocherGres_A", 229.572, -0.4, 84.337, 328.31, 1.069, 1.069, 1.069, true, "colline" },
	{ "Desert_RocherGres_A", 216.856, -0.4, 111.578, 87.32, 1.054, 1.054, 1.054, true, "colline" },
	{ "Desert_RocherGres_B", 215.623, -0.4, 78.805, 108.11, 1.224, 1.224, 1.224, true, "colline" },
	{ "Desert_ColonneBrisee", 199.898, 0, 117.749, 244.19, 1.0, 1.0, 1.0, true, "colline" },
	{ "Desert_ArcheNaturelle", 233.852, 0, 101.676, 178.88, 0.918, 0.918, 0.918, true, "colline" },
	{ "Desert_Mesa", 77.387, -0.5, 288.812, 192.69, 0.7, 0.95, 0.75, true, "colline" },
	{ "Desert_Saguaro", 63.802, 27.4, 294.672, 202.24, 1.235, 1.235, 1.235, true, "colline" },
	{ "Desert_Saguaro", 69.642, 27.4, 293.347, 288.38, 1.232, 1.232, 1.232, true, "colline" },
	{ "Desert_Mesa", 115.953, -0.5, 279.935, 203.87, 0.75, 1.0, 0.75, true, "colline" },
	{ "Desert_Saguaro", 112.467, 28.894, 284.045, 189.27, 0.905, 0.905, 0.905, true, "colline" },
	{ "Desert_Saguaro", 117.668, 28.894, 281.93, 307.49, 1.22, 1.22, 1.22, true, "colline" },
	{ "Desert_Mesa", 149.5, -0.5, 258.942, 210.71, 0.7, 0.9, 0.75, true, "colline" },
	{ "Desert_Saguaro", 147.399, 25.905, 263.013, 38.52, 0.986, 0.986, 0.986, true, "colline" },
	{ "Desert_Saguaro", 150.491, 25.905, 261.256, 156.76, 0.976, 0.976, 0.976, true, "colline" },
	{ "Desert_Mesa", 89.163, -0.5, 266.479, 192.87, 0.6, 0.5, 0.6, true, "colline" },
	{ "Desert_Figuier", 78.179, 13.947, 272.507, 78.25, 0.949, 0.949, 0.949, true, "colline" },
	{ "Desert_Mesa", 125.382, -0.5, 251.477, 207.72, 0.6, 0.45, 0.6, true, "colline" },
	{ "Desert_Saguaro", 130.095, 12.452, 251.888, 149.89, 1.028, 1.028, 1.028, true, "colline" },
	{ "Desert_Figuier", 54.7, 0, 253.92, 237.2, 0.961, 0.961, 0.961, true, "colline" },
	{ "Desert_Palmier", 54.084, 0, 243.163, 314.7, 0.994, 0.994, 0.994, true, "colline" },
	{ "Desert_Figuier", 72.256, 0, 240.047, 85.21, 0.955, 0.955, 0.955, true, "colline" },
	{ "Desert_RocherGres_B", 137.254, -0.4, 230.093, 286.44, 1.012, 1.012, 1.012, true, "colline" },
	{ "Desert_RocherGres_B", 66.248, -0.4, 259.46, 166.96, 1.238, 1.238, 1.238, true, "colline" },
	{ "Desert_RocherGres_A", 88.102, -0.4, 213.143, 171.21, 1.174, 1.174, 1.174, true, "colline" },
	{ "Desert_ColonneBrisee", 58.088, 0, 224.61, 196.96, 1.0, 1.0, 1.0, true, "colline" },
	{ "Desert_Fossile", 95.216, 0, 236.556, 24.73, 1.114, 1.114, 1.114, true, "colline" },
	{ "Desert_Mesa", -149.5, -0.5, 258.942, 150.29, 0.7, 0.95, 0.75, true, "colline" },
	{ "Desert_Saguaro", -152.807, 27.4, 259.908, 3.95, 0.957, 0.957, 0.957, true, "colline" },
	{ "Desert_Saguaro", -147.832, 27.4, 262.77, 282.92, 1.178, 1.178, 1.178, true, "colline" },
	{ "Desert_Mesa", -115.953, -0.5, 279.935, 155.88, 0.75, 1.0, 0.75, true, "colline" },
	{ "Desert_Saguaro", -109.409, 28.894, 285.237, 208.03, 1.147, 1.147, 1.147, true, "colline" },
	{ "Desert_Saguaro", -122.233, 28.894, 279.981, 84.22, 1.23, 1.23, 1.23, true, "colline" },
	{ "Desert_Mesa", -77.387, -0.5, 288.812, 165.29, 0.7, 0.9, 0.75, true, "colline" },
	{ "Desert_Saguaro", -77.193, 25.905, 291.451, 189.84, 1.016, 1.016, 1.016, true, "colline" },
	{ "Desert_Saguaro", -70.738, 25.905, 293.084, 254.78, 1.209, 1.209, 1.209, true, "colline" },
	{ "Desert_Mesa", -125.382, -0.5, 251.477, 154.59, 0.6, 0.5, 0.6, true, "colline" },
	{ "Desert_Saguaro", -135.371, 13.947, 249.092, 342.96, 1.025, 1.025, 1.025, true, "colline" },
	{ "Desert_Mesa", -89.163, -0.5, 266.479, 165.97, 0.6, 0.45, 0.6, true, "colline" },
	{ "Desert_Saguaro", -97.052, 12.452, 266.37, 250.98, 1.191, 1.191, 1.191, true, "colline" },
	{ "Desert_RocherGres_A", -136.304, 0, 222.723, 232.9, 1.014, 1.014, 1.014, true, "colline" },
	{ "Desert_RocherGres_A", -139.318, 0, 211.655, 272.04, 0.959, 0.959, 0.959, true, "colline" },
	{ "Desert_Figuier", -65.423, 0, 238.321, 139.08, 0.923, 0.923, 0.923, true, "colline" },
	{ "Desert_RocherGres_A", -92.839, -0.4, 219.739, 148.81, 0.822, 0.822, 0.822, true, "colline" },
	{ "Desert_RocherGres_B", -71.97, -0.4, 217.367, 351.23, 1.197, 1.197, 1.197, true, "colline" },
	{ "Desert_RocherGres_A", -101.659, -0.4, 209.518, 138.22, 1.257, 1.257, 1.257, true, "colline" },
	{ "Desert_ColonneBrisee", -58.088, 0, 224.61, 127.63, 1.0, 1.0, 1.0, true, "colline" },
	{ "Desert_RocherGres_A", -106.773, 0, 231.57, 28.05, 0.953, 0.953, 0.953, true, "colline" },
	{ "Desert_Mesa", -288.812, -0.5, 77.387, 107.5, 0.7, 0.95, 0.75, true, "colline" },
	{ "Desert_Saguaro", -287.37, 27.4, 91.219, 37.13, 1.145, 1.145, 1.145, true, "colline" },
	{ "Desert_Saguaro", -291.094, 27.4, 78.527, 45.7, 1.25, 1.25, 1.25, true, "colline" },
	{ "Desert_Mesa", -279.935, -0.5, 115.953, 109.25, 0.75, 1.0, 0.75, true, "colline" },
	{ "Desert_Figuier", -279.802, 28.894, 122.641, 37.76, 1.217, 1.217, 1.217, true, "colline" },
	{ "Desert_Saguaro", -275.755, 28.894, 131.488, 13.25, 1.076, 1.076, 1.076, true, "colline" },
	{ "Desert_Mesa", -258.942, -0.5, 149.5, 124.01, 0.7, 0.9, 0.75, true, "colline" },
	{ "Desert_Saguaro", -257.306, 25.905, 157.15, 147.22, 1.048, 1.048, 1.048, true, "colline" },
	{ "Desert_Saguaro", -258.277, 25.905, 155.548, 335.08, 1.066, 1.066, 1.066, true, "colline" },
	{ "Desert_Mesa", -266.479, -0.5, 89.163, 104.29, 0.6, 0.5, 0.6, true, "colline" },
	{ "Desert_Saguaro", -267.506, 13.947, 93.876, 218.37, 1.186, 1.186, 1.186, true, "colline" },
	{ "Desert_Mesa", -251.477, -0.5, 125.382, 111.32, 0.6, 0.45, 0.6, true, "colline" },
	{ "Desert_Saguaro", -247.246, 12.452, 138.714, 158.79, 1.154, 1.154, 1.154, true, "colline" },
	{ "Desert_Saguaro", -217.762, 0, 136.971, 286.65, 0.95, 0.95, 0.95, true, "colline" },
	{ "Desert_Palmier", -211.592, 0, 125.35, 74.0, 0.856, 0.856, 0.856, true, "colline" },
	{ "Desert_Saguaro", -228.132, 0, 119.702, 69.6, 0.935, 0.935, 0.935, true, "colline" },
	{ "Desert_RocherGres_B", -206.508, -0.4, 128.256, 132.14, 1.135, 1.135, 1.135, true, "colline" },
	{ "Desert_RocherGres_A", -229.291, -0.4, 69.564, 92.21, 0.952, 0.952, 0.952, true, "colline" },
	{ "Desert_RocherGres_B", -220.104, -0.4, 121.919, 248.29, 1.032, 1.032, 1.032, true, "colline" },
	{ "Desert_ColonneBrisee", -199.898, 0, 117.749, 129.69, 1.0, 1.0, 1.0, true, "colline" },
	{ "Desert_Auvent", -230.245, 0, 109.601, 61.49, 0.958, 0.958, 0.958, true, "colline" },
	{ "Desert_Mesa", -258.942, -0.5, -149.5, 57.02, 0.7, 0.95, 0.75, true, "colline" },
	{ "Desert_Saguaro", -254.897, 27.4, -161.027, 130.73, 0.975, 0.975, 0.975, true, "colline" },
	{ "Desert_Saguaro", -255.876, 27.4, -159.468, 327.41, 1.138, 1.138, 1.138, true, "colline" },
	{ "Desert_Mesa", -279.935, -0.5, -115.953, 68.98, 0.75, 1.0, 0.75, true, "colline" },
	{ "Desert_Saguaro", -279.567, 28.894, -123.176, 356.07, 1.038, 1.038, 1.038, true, "colline" },
	{ "Desert_Saguaro", -287.282, 28.894, -103.92, 228.65, 0.914, 0.914, 0.914, true, "colline" },
	{ "Desert_Mesa", -288.812, -0.5, -77.387, 72.66, 0.7, 0.9, 0.75, true, "colline" },
	{ "Desert_Saguaro", -289.247, 25.905, -85.078, 74.82, 0.949, 0.949, 0.949, true, "colline" },
	{ "Desert_Saguaro", -294.697, 25.905, -63.685, 172.36, 1.014, 1.014, 1.014, true, "colline" },
	{ "Desert_Mesa", -251.477, -0.5, -125.382, 59.07, 0.6, 0.5, 0.6, true, "colline" },
	{ "Desert_Saguaro", -259.292, 13.947, -114.63, 333.35, 1.016, 1.016, 1.016, true, "colline" },
	{ "Desert_Mesa", -266.479, -0.5, -89.163, 70.72, 0.6, 0.45, 0.6, true, "colline" },
	{ "Desert_Saguaro", -272.183, 12.452, -79.299, 10.82, 1.026, 1.026, 1.026, true, "colline" },
	{ "Desert_RocherGres_A", -230.173, 0, -70.096, 352.33, 1.093, 1.093, 1.093, true, "colline" },
	{ "Desert_RocherGres_A", -225.682, 0, -118.769, 337.14, 0.971, 0.971, 0.971, true, "colline" },
	{ "Desert_Palmier", -243.751, 0, -52.955, 194.99, 0.889, 0.889, 0.889, true, "colline" },
	{ "Desert_RocherGres_A", -229.608, -0.4, -110.069, 193.43, 1.182, 1.182, 1.182, true, "colline" },
	{ "Desert_RocherGres_B", -246.325, -0.4, -64.904, 156.02, 1.267, 1.267, 1.267, true, "colline" },
	{ "Desert_RocherGres_A", -215.574, -0.4, -80.737, 52.46, 1.13, 1.13, 1.13, true, "colline" },
	{ "Desert_ColonneBrisee", -224.61, 0, -58.088, 44.72, 1.0, 1.0, 1.0, true, "colline" },
	{ "Desert_ArcheNaturelle", -240.85, 0, -83.764, 310.36, 1.187, 1.187, 1.187, true, "colline" },
	{ "Desert_Mesa", -77.387, -0.5, -288.812, 12.17, 0.7, 0.95, 0.75, true, "colline" },
	{ "Desert_Saguaro", -70.167, 27.4, -293.221, 100.17, 0.985, 0.985, 0.985, true, "colline" },
	{ "Desert_Figuier", -91.819, 27.4, -287.179, 13.82, 1.288, 1.288, 1.288, true, "colline" },
	{ "Desert_Mesa", -115.953, -0.5, -279.935, 22.2, 0.75, 1.0, 0.75, true, "colline" },
	{ "Desert_Saguaro", -107.168, 28.894, -286.086, 293.23, 1.18, 1.18, 1.18, true, "colline" },
	{ "Desert_Saguaro", -111.02, 28.894, -284.614, 103.01, 1.228, 1.228, 1.228, true, "colline" },
	{ "Desert_Mesa", -149.5, -0.5, -258.942, 30.67, 0.7, 0.9, 0.75, true, "colline" },
	{ "Desert_Saguaro", -142.5, 25.905, -265.699, 314.69, 1.143, 1.143, 1.143, true, "colline" },
	{ "Desert_Saguaro", -157.222, 25.905, -257.261, 94.25, 1.027, 1.027, 1.027, true, "colline" },
	{ "Desert_Mesa", -89.163, -0.5, -266.479, 21.07, 0.6, 0.5, 0.6, true, "colline" },
	{ "Desert_Saguaro", -96.448, 13.947, -266.59, 197.97, 1.242, 1.242, 1.242, true, "colline" },
	{ "Desert_Mesa", -125.382, -0.5, -251.477, 29.38, 0.6, 0.45, 0.6, true, "colline" },
	{ "Desert_Saguaro", -118.105, 12.452, -257.728, 259.84, 0.99, 0.99, 0.99, true, "colline" },
	{ "Desert_RocherGres_A", -124.51, 0, -213.082, 15.45, 0.896, 0.896, 0.896, true, "colline" },
	{ "Desert_Saguaro", -137.087, 0, -222.271, 99.32, 1.111, 1.111, 1.111, true, "colline" },
	{ "Desert_RocherGres_A", -56.01, 0, -243.867, 268.11, 0.947, 0.947, 0.947, true, "colline" },
	{ "Desert_RocherGres_B", -102.945, -0.4, -209.053, 254.05, 1.061, 1.061, 1.061, true, "colline" },
	{ "Desert_RocherGres_B", -121.861, -0.4, -199.108, 329.03, 1.275, 1.275, 1.275, true, "colline" },
	{ "Desert_RocherGres_B", -104.712, -0.4, -214.997, 244.63, 1.255, 1.255, 1.255, true, "colline" },
	{ "Desert_ColonneBrisee", -117.749, 0, -199.898, 39.07, 1.0, 1.0, 1.0, true, "colline" },
	{ "Desert_Fossile", -90.251, 0, -238.495, 354.21, 1.125, 1.125, 1.125, true, "colline" },
	{ "Desert_Mesa", 149.5, -0.5, -258.942, 335.94, 0.7, 0.95, 0.75, true, "colline" },
	{ "Desert_Saguaro", 162.235, 27.4, -254.13, 289.43, 1.059, 1.059, 1.059, true, "colline" },
	{ "Desert_Saguaro", 159.431, 27.4, -255.899, 145.39, 1.123, 1.123, 1.123, true, "colline" },
	{ "Desert_Mesa", 115.953, -0.5, -279.935, 331.59, 0.75, 1.0, 0.75, true, "colline" },
	{ "Desert_Figuier", 115.16, 28.894, -282.964, 318.2, 1.292, 1.292, 1.292, true, "colline" },
	{ "Desert_Saguaro", 130.28, 28.894, -276.328, 6.71, 1.096, 1.096, 1.096, true, "colline" },
	{ "Desert_Mesa", 77.387, -0.5, -288.812, 348.23, 0.7, 0.9, 0.75, true, "colline" },
	{ "Desert_Figuier", 75.183, 25.905, -291.976, 276.42, 0.98, 0.98, 0.98, true, "colline" },
	{ "Desert_Figuier", 68.738, 25.905, -293.56, 72.29, 0.988, 0.988, 0.988, true, "colline" },
	{ "Desert_Mesa", 125.382, -0.5, -251.477, 331.98, 0.6, 0.5, 0.6, true, "colline" },
	{ "Desert_Figuier", 138.752, 13.947, -247.225, 189.09, 1.101, 1.101, 1.101, true, "colline" },
	{ "Desert_Mesa", 89.163, -0.5, -266.479, 340.89, 0.6, 0.45, 0.6, true, "colline" },
	{ "Desert_Saguaro", 89.137, 12.452, -269.122, 347.9, 1.06, 1.06, 1.06, true, "colline" },
	{ "Desert_Palmier", 118.412, 0, -210.716, 127.97, 0.828, 0.828, 0.828, true, "colline" },
	{ "Desert_Saguaro", 124.141, 0, -210.16, 17.92, 0.907, 0.907, 0.907, true, "colline" },
	{ "Desert_Figuier", 138.998, 0, -212.422, 60.0, 0.869, 0.869, 0.869, true, "colline" },
	{ "Desert_RocherGres_A", 126.168, -0.4, -211.892, 177.32, 0.969, 0.969, 0.969, true, "colline" },
	{ "Desert_RocherGres_B", 67.792, -0.4, -233.104, 329.07, 0.841, 0.841, 0.841, true, "colline" },
	{ "Desert_RocherGres_B", 110.334, -0.4, -246.349, 184.03, 0.847, 0.847, 0.847, true, "colline" },
	{ "Desert_ColonneBrisee", 117.749, 0, -199.898, 354.07, 1.0, 1.0, 1.0, true, "colline" },
	{ "Desert_RocherGres_A", 85.548, 0, -240.222, 161.73, 0.906, 0.906, 0.906, true, "colline" },
	{ "Desert_Mesa", 288.812, -0.5, -77.387, 283.07, 0.7, 0.95, 0.75, true, "colline" },
	{ "Desert_Saguaro", 291.236, 27.4, -78.0, 73.36, 1.239, 1.239, 1.239, true, "colline" },
	{ "Desert_Saguaro", 294.461, 27.4, -64.77, 70.79, 0.925, 0.925, 0.925, true, "colline" },
	{ "Desert_Mesa", 279.935, -0.5, -115.953, 288.05, 0.75, 1.0, 0.75, true, "colline" },
	{ "Desert_Saguaro", 282.408, 28.894, -116.516, 44.28, 1.123, 1.123, 1.123, true, "colline" },
	{ "Desert_Saguaro", 286.673, 28.894, -105.587, 329.4, 1.294, 1.294, 1.294, true, "colline" },
	{ "Desert_Mesa", 258.942, -0.5, -149.5, 305.1, 0.7, 0.9, 0.75, true, "colline" },
	{ "Desert_Saguaro", 258.46, 25.905, -155.244, 113.05, 1.118, 1.118, 1.118, true, "colline" },
	{ "Desert_Saguaro", 263.992, 25.905, -145.638, 293.68, 0.939, 0.939, 0.939, true, "colline" },
	{ "Desert_Mesa", 266.479, -0.5, -89.163, 288.48, 0.6, 0.5, 0.6, true, "colline" },
	{ "Desert_Saguaro", 266.032, 13.947, -97.975, 209.44, 0.978, 0.978, 0.978, true, "colline" },
	{ "Desert_Mesa", 251.477, -0.5, -125.382, 297.09, 0.6, 0.45, 0.6, true, "colline" },
	{ "Desert_Saguaro", 258.896, 12.452, -115.52, 321.9, 1.257, 1.257, 1.257, true, "colline" },
	{ "Desert_Palmier", 252.577, 0, -68.83, 293.17, 1.062, 1.062, 1.062, true, "colline" },
	{ "Desert_Palmier", 241.128, 0, -61.904, 206.12, 1.148, 1.148, 1.148, true, "colline" },
	{ "Desert_Palmier", 247.029, 0, -77.466, 253.5, 0.909, 0.909, 0.909, true, "colline" },
	{ "Desert_RocherGres_A", 247.953, -0.4, -57.428, 48.97, 0.882, 0.882, 0.882, true, "colline" },
	{ "Desert_RocherGres_B", 220.353, -0.4, -88.32, 282.32, 1.141, 1.141, 1.141, true, "colline" },
	{ "Desert_RocherGres_B", 226.399, -0.4, -112.802, 137.56, 1.239, 1.239, 1.239, true, "colline" },
	{ "Desert_ColonneBrisee", 224.61, 0, -58.088, 295.05, 1.0, 1.0, 1.0, true, "colline" },
	{ "Desert_Auvent", 235.303, 0, -98.272, 241.43, 1.035, 1.035, 1.035, true, "colline" },
	{ "Desert_Palmier", 268.738, 0, -103.084, 167.9, 1.062, 1.062, 1.062, true, "colline" },
	{ "Desert_Palmier", 262.008, 0, -113.974, 245.07, 0.982, 0.982, 0.982, true, "colline" },
	{ "Desert_Palmier", 245.719, 0, -115.938, 274.31, 1.203, 1.203, 1.203, true, "colline" },
	{ "Desert_Palmier", 235.897, 0, -110.03, 326.21, 1.161, 1.161, 1.161, true, "colline" },
	{ "Desert_Palmier", 236.29, 0, -97.657, 18.76, 1.126, 1.126, 1.126, true, "colline" },
	{ "Desert_Palmier", 247.579, 0, -91.875, 90.71, 0.949, 0.949, 0.949, true, "colline" },
	{ "Desert_Palmier", 262.029, 0, -94.217, 135.63, 1.125, 1.125, 1.125, true, "colline" },
	{ "Desert_Figuier", 265.572, -0.3, -108.373, 48.07, 0.706, 0.706, 0.706, false, "colline" },
	{ "Desert_RocherGres_B", 249.966, -0.3, -115.049, 211.73, 0.689, 0.689, 0.689, false, "colline" },
	{ "Desert_Figuier", 236.197, -0.3, -106.58, 62.95, 0.557, 0.557, 0.557, false, "colline" },
	{ "Desert_RocherGres_B", 243.293, -0.3, -94.669, 345.93, 0.62, 0.62, 0.62, false, "colline" },
	{ "Desert_Figuier", 261.447, -0.3, -95.778, 164.17, 0.506, 0.506, 0.506, false, "colline" },
	{ "Desert_Mesa", 343.234, -1, 8.913, 270.41, 1.6, 2.597, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 349.198, 74.638, -8.056, 45.53, 1.507, 1.507, 1.507, false, "peripherie" },
	{ "Desert_Saguaro", 348.901, 74.638, 16.808, 72.49, 1.96, 1.96, 1.96, false, "peripherie" },
	{ "Desert_Mesa", 335.736, -1, -49.863, 281.48, 1.6, 2.392, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 339.129, 68.516, -66.483, 260.86, 1.943, 1.943, 1.943, false, "peripherie" },
	{ "Desert_Saguaro", 345.718, 68.516, -33.02, 274.48, 1.902, 1.902, 1.902, false, "peripherie" },
	{ "Desert_Mesa", 329.171, -1, -100.046, 285.29, 1.6, 1.951, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 333.532, 55.321, -105.593, 353.07, 1.311, 1.311, 1.311, false, "peripherie" },
	{ "Desert_Palmier", 336.325, 55.321, -91.262, 27.45, 1.436, 1.436, 1.436, false, "peripherie" },
	{ "Desert_Mesa", 300.847, -1, -156.677, 292.53, 1.6, 2.024, 1.3, false, "peripherie" },
	{ "Desert_Palmier", 297.906, 57.502, -171.342, 352.01, 1.382, 1.382, 1.382, false, "peripherie" },
	{ "Desert_Saguaro", 297.493, 57.502, -173.752, 295.61, 1.865, 1.865, 1.865, false, "peripherie" },
	{ "Desert_Mesa", 269.165, -1, -209.865, 311.55, 1.6, 2.297, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 280.047, 65.673, -203.035, 297.41, 1.562, 1.562, 1.562, false, "peripherie" },
	{ "Desert_Saguaro", 282.509, 65.673, -199.584, 62.99, 1.451, 1.451, 1.451, false, "peripherie" },
	{ "Desert_Mesa", 237.356, -1, -247.856, 315.01, 1.6, 2.365, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 229.204, 67.709, -264.006, 174.79, 1.332, 1.332, 1.332, false, "peripherie" },
	{ "Desert_Saguaro", 246.929, 67.709, -249.152, 303.51, 1.664, 1.664, 1.664, false, "peripherie" },
	{ "Desert_Mesa", 205.842, -1, -276.16, 325.86, 1.6, 2.079, 1.3, false, "peripherie" },
	{ "Desert_Palmier", 197.851, 59.155, -289.407, 253.9, 1.73, 1.73, 1.73, false, "peripherie" },
	{ "Desert_Saguaro", 206.51, 59.155, -286.297, 263.5, 1.611, 1.611, 1.611, false, "peripherie" },
	{ "Desert_Mesa", 157.0, -1, -302.941, 335.09, 1.6, 2.597, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 154.749, 74.634, -308.98, 238.22, 1.538, 1.538, 1.538, false, "peripherie" },
	{ "Desert_Saguaro", 163.444, 74.634, -305.628, 205.5, 1.334, 1.334, 1.334, false, "peripherie" },
	{ "Desert_Mesa", 108.143, -1, -327.157, 341.8, 1.6, 2.06, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 96.572, 58.576, -339.83, 195.76, 1.639, 1.639, 1.639, false, "peripherie" },
	{ "Desert_Saguaro", 104.518, 58.576, -333.019, 101.28, 1.5, 1.5, 1.5, false, "peripherie" },
	{ "Desert_Mesa", 45.66, -1, -338.374, 356.09, 1.6, 2.471, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 66.342, 70.87, -341.344, 295.0, 1.943, 1.943, 1.943, false, "peripherie" },
	{ "Desert_Saguaro", 51.451, 70.87, -345.832, 171.87, 1.572, 1.572, 1.572, false, "peripherie" },
	{ "Desert_Mesa", -2.213, -1, -342.047, 2.64, 1.6, 1.956, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -2.238, 55.469, -348.788, 238.11, 1.923, 1.923, 1.923, false, "peripherie" },
	{ "Desert_Saguaro", 11.768, 55.469, -348.734, 147.54, 1.533, 1.533, 1.533, false, "peripherie" },
	{ "Desert_Mesa", -59.678, -1, -341.796, 5.79, 1.6, 2.332, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -72.075, 66.701, -343.42, 146.74, 1.316, 1.316, 1.316, false, "peripherie" },
	{ "Desert_Saguaro", -60.905, 66.701, -346.47, 307.01, 1.312, 1.312, 1.312, false, "peripherie" },
	{ "Desert_Mesa", -97.503, -1, -332.359, 17.52, 1.6, 2.197, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -100.937, 62.679, -340.773, 185.93, 1.336, 1.336, 1.336, false, "peripherie" },
	{ "Desert_Saguaro", -118.616, 62.679, -331.666, 78.23, 1.893, 1.893, 1.893, false, "peripherie" },
	{ "Desert_Mesa", -160.728, -1, -300.955, 26.95, 1.6, 2.554, 1.3, false, "peripherie" },
	{ "Desert_Palmier", -167.837, 73.357, -302.77, 251.63, 1.932, 1.932, 1.932, false, "peripherie" },
	{ "Desert_Saguaro", -150.729, 73.357, -313.012, 300.37, 1.451, 1.451, 1.451, false, "peripherie" },
	{ "Desert_Mesa", -213.504, -1, -273.489, 39.4, 1.6, 2.11, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -223.173, 60.066, -274.791, 310.28, 1.344, 1.344, 1.344, false, "peripherie" },
	{ "Desert_Saguaro", -221.426, 60.066, -278.307, 60.59, 1.389, 1.389, 1.389, false, "peripherie" },
	{ "Desert_Mesa", -240.8, -1, -243.094, 45.63, 1.6, 2.192, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -236.75, 62.519, -259.337, 189.45, 1.974, 1.974, 1.974, false, "peripherie" },
	{ "Desert_Saguaro", -255.094, 62.519, -234.773, 32.69, 1.765, 1.765, 1.765, false, "peripherie" },
	{ "Desert_Mesa", -284.05, -1, -194.679, 58.25, 1.6, 2.347, 1.3, false, "peripherie" },
	{ "Desert_Palmier", -291.643, 67.156, -193.876, 105.88, 1.535, 1.535, 1.535, false, "peripherie" },
	{ "Desert_Saguaro", -291.271, 67.156, -199.844, 35.11, 1.788, 1.788, 1.788, false, "peripherie" },
	{ "Desert_Mesa", -301.255, -1, -161.067, 64.84, 1.6, 2.201, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -315.511, 62.795, -149.624, 358.91, 1.35, 1.35, 1.35, false, "peripherie" },
	{ "Desert_Saguaro", -308.246, 62.795, -159.425, 11.77, 1.933, 1.933, 1.933, false, "peripherie" },
	{ "Desert_Mesa", -324.634, -1, -107.233, 69.56, 1.6, 2.344, 1.3, false, "peripherie" },
	{ "Desert_Palmier", -337.148, 67.065, -92.592, 227.33, 1.799, 1.799, 1.799, false, "peripherie" },
	{ "Desert_Saguaro", -334.921, 67.065, -92.532, 40.14, 1.862, 1.862, 1.862, false, "peripherie" },
	{ "Desert_Mesa", -339.204, -1, -64.363, 76.83, 1.6, 2.2, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -346.951, 62.765, -63.455, 184.15, 1.932, 1.932, 1.932, false, "peripherie" },
	{ "Desert_Saguaro", -348.506, 62.765, -51.726, 23.21, 1.992, 1.992, 1.992, false, "peripherie" },
	{ "Desert_Mesa", -339.765, -1, -10.194, 92.37, 1.6, 2.396, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -345.508, 68.617, 6.633, 111.09, 1.345, 1.345, 1.345, false, "peripherie" },
	{ "Desert_Saguaro", -343.956, 68.617, -16.43, 222.57, 1.745, 1.745, 1.745, false, "peripherie" },
	{ "Desert_Mesa", -334.211, -1, 59.109, 97.94, 1.6, 2.02, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -345.305, 57.394, 41.192, 341.09, 1.889, 1.889, 1.889, false, "peripherie" },
	{ "Desert_Saguaro", -340.838, 57.394, 60.454, 102.04, 1.723, 1.723, 1.723, false, "peripherie" },
	{ "Desert_Mesa", -324.769, -1, 99.282, 104.21, 1.6, 2.109, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -334.935, 60.053, 89.789, 203.83, 1.898, 1.898, 1.898, false, "peripherie" },
	{ "Desert_Saguaro", -328.674, 60.053, 101.555, 50.82, 1.623, 1.623, 1.623, false, "peripherie" },
	{ "Desert_Mesa", -309.696, -1, 151.464, 116.88, 1.6, 1.908, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -317.77, 54.041, 155.483, 131.54, 1.895, 1.895, 1.895, false, "peripherie" },
	{ "Desert_Saguaro", -312.597, 54.041, 164.859, 65.25, 1.491, 1.491, 1.491, false, "peripherie" },
	{ "Desert_Mesa", -270.157, -1, 210.494, 130.96, 1.6, 2.596, 1.3, false, "peripherie" },
	{ "Desert_Palmier", -282.27, 74.604, 204.514, 123.91, 1.357, 1.357, 1.357, false, "peripherie" },
	{ "Desert_Palmier", -266.946, 74.604, 223.74, 210.84, 1.501, 1.501, 1.501, false, "peripherie" },
	{ "Desert_Mesa", -243.333, -1, 240.442, 136.24, 1.6, 2.335, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -243.756, 66.802, 250.254, 220.34, 1.938, 1.938, 1.938, false, "peripherie" },
	{ "Desert_Palmier", -257.756, 66.802, 237.932, 98.57, 1.616, 1.616, 1.616, false, "peripherie" },
	{ "Desert_Mesa", -204.64, -1, 276.995, 143.74, 1.6, 2.448, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -205.892, 70.171, 283.517, 266.81, 1.901, 1.901, 1.901, false, "peripherie" },
	{ "Desert_Saguaro", -207.121, 70.171, 281.766, 234.45, 1.756, 1.756, 1.756, false, "peripherie" },
	{ "Desert_Mesa", -166.917, -1, 303.415, 152.53, 1.6, 2.198, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -180.034, 62.714, 302.94, 295.33, 1.78, 1.78, 1.78, false, "peripherie" },
	{ "Desert_Saguaro", -153.482, 62.714, 319.516, 184.02, 1.811, 1.811, 1.811, false, "peripherie" },
	{ "Desert_Mesa", -95.927, -1, 328.062, 159.83, 1.6, 2.207, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -78.758, 62.97, 339.256, 143.85, 1.354, 1.354, 1.354, false, "peripherie" },
	{ "Desert_Saguaro", -77.855, 62.97, 341.442, 66.77, 1.885, 1.885, 1.885, false, "peripherie" },
	{ "Desert_Mesa", -52.068, -1, 336.016, 174.41, 1.6, 2.589, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", -66.874, 74.396, 337.48, 274.76, 1.863, 1.863, 1.863, false, "peripherie" },
	{ "Desert_Saguaro", -71.178, 74.396, 338.84, 184.2, 1.7, 1.7, 1.7, false, "peripherie" },
	{ "Desert_Mesa", 2.078, -1, 342.215, 180.25, 1.6, 2.367, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 17.813, 67.75, 348.049, 176.5, 1.588, 1.588, 1.588, false, "peripherie" },
	{ "Desert_Saguaro", -3.308, 67.75, 346.165, 230.81, 1.434, 1.434, 1.434, false, "peripherie" },
	{ "Desert_Mesa", 62.357, -1, 340.448, 194.47, 1.6, 2.391, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 69.711, 68.465, 346.92, 180.8, 1.432, 1.432, 1.432, false, "peripherie" },
	{ "Desert_Saguaro", 50.153, 68.465, 348.458, 24.31, 1.617, 1.617, 1.617, false, "peripherie" },
	{ "Desert_Mesa", 107.536, -1, 329.338, 195.87, 1.6, 2.185, 1.3, false, "peripherie" },
	{ "Desert_Palmier", 95.098, 62.32, 341.629, 31.02, 1.42, 1.42, 1.42, false, "peripherie" },
	{ "Desert_Saguaro", 90.658, 62.32, 339.159, 122.67, 1.519, 1.519, 1.519, false, "peripherie" },
	{ "Desert_Mesa", 146.951, -1, 312.714, 209.94, 1.6, 2.227, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 157.914, 63.57, 316.351, 10.56, 1.983, 1.983, 1.983, false, "peripherie" },
	{ "Desert_Saguaro", 153.734, 63.57, 318.771, 266.29, 1.999, 1.999, 1.999, false, "peripherie" },
	{ "Desert_Mesa", 195.331, -1, 281.422, 218.49, 1.6, 2.568, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 207.626, 73.768, 279.185, 76.18, 1.902, 1.902, 1.902, false, "peripherie" },
	{ "Desert_Saguaro", 200.513, 73.768, 283.305, 68.07, 1.583, 1.583, 1.583, false, "peripherie" },
	{ "Desert_Mesa", 248.751, -1, 239.475, 225.92, 1.6, 2.591, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 251.741, 74.461, 244.29, 59.51, 1.829, 1.829, 1.829, false, "peripherie" },
	{ "Desert_Saguaro", 266.944, 74.461, 228.087, 172.33, 1.458, 1.458, 1.458, false, "peripherie" },
	{ "Desert_Mesa", 279.17, -1, 196.106, 237.85, 1.6, 2.512, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 291.285, 72.1, 187.847, 100.35, 1.664, 1.664, 1.664, false, "peripherie" },
	{ "Desert_Saguaro", 293.776, 72.1, 184.059, 344.35, 1.881, 1.881, 1.881, false, "peripherie" },
	{ "Desert_Mesa", 302.79, -1, 162.44, 241.91, 1.6, 2.517, 1.3, false, "peripherie" },
	{ "Desert_Palmier", 317.821, 72.238, 150.095, 104.39, 1.732, 1.732, 1.732, false, "peripherie" },
	{ "Desert_Saguaro", 307.243, 72.238, 166.06, 26.38, 1.848, 1.848, 1.848, false, "peripherie" },
	{ "Desert_Mesa", 328.427, -1, 95.602, 255.27, 1.6, 2.019, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 327.915, 57.342, 111.479, 8.56, 1.804, 1.804, 1.804, false, "peripherie" },
	{ "Desert_Saguaro", 329.104, 57.342, 111.592, 28.13, 1.775, 1.775, 1.775, false, "peripherie" },
	{ "Desert_Mesa", 341.482, -1, 47.058, 266.2, 1.6, 2.026, 1.3, false, "peripherie" },
	{ "Desert_Saguaro", 350.84, 57.564, 26.701, 323.55, 1.823, 1.823, 1.823, false, "peripherie" },
	{ "Desert_Saguaro", 347.913, 57.564, 62.01, 358.57, 1.553, 1.553, 1.553, false, "peripherie" },
	{ "Desert_Mesa", 382.192, -1, -27.775, 274.96, 2.0, 3.319, 1.6, false, "peripherie" },
	{ "Desert_Palmier", 390.241, 96.206, -19.911, 294.52, 1.658, 1.658, 1.658, false, "peripherie" },
	{ "Desert_Saguaro", 384.999, 96.206, -50.725, 24.58, 1.877, 1.877, 1.877, false, "peripherie" },
	{ "Desert_Mesa", 368.801, -1, -91.235, 286.55, 2.0, 3.295, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 380.94, 95.511, -79.817, 17.34, 1.829, 1.829, 1.829, false, "peripherie" },
	{ "Desert_Saguaro", 371.792, 95.511, -102.542, 187.0, 1.665, 1.665, 1.665, false, "peripherie" },
	{ "Desert_Mesa", 347.928, -1, -155.315, 289.06, 2.0, 3.241, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 351.055, 93.88, -174.81, 249.7, 1.38, 1.38, 1.38, false, "peripherie" },
	{ "Desert_Saguaro", 362.509, 93.88, -143.205, 84.02, 1.531, 1.531, 1.531, false, "peripherie" },
	{ "Desert_Mesa", 306.534, -1, -222.727, 305.98, 2.0, 3.237, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 316.115, 93.772, -220.951, 324.06, 1.863, 1.863, 1.863, false, "peripherie" },
	{ "Desert_Saguaro", 311.528, 93.772, -233.456, 214.8, 1.962, 1.962, 1.962, false, "peripherie" },
	{ "Desert_Mesa", 262.001, -1, -276.219, 313.45, 2.0, 3.683, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 262.511, 107.088, -285.87, 76.19, 1.758, 1.758, 1.758, false, "peripherie" },
	{ "Desert_Saguaro", 279.302, 107.088, -269.864, 113.73, 1.665, 1.665, 1.665, false, "peripherie" },
	{ "Desert_Mesa", 209.145, -1, -316.816, 331.34, 2.0, 3.68, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 212.455, 107.012, -326.541, 146.16, 1.402, 1.402, 1.402, false, "peripherie" },
	{ "Desert_Saguaro", 200.418, 107.012, -329.833, 287.04, 1.631, 1.631, 1.631, false, "peripherie" },
	{ "Desert_Mesa", 140.776, -1, -353.643, 338.0, 2.0, 3.655, 1.6, false, "peripherie" },
	{ "Desert_Palmier", 163.876, 106.252, -349.048, 138.27, 1.41, 1.41, 1.41, false, "peripherie" },
	{ "Desert_Saguaro", 159.745, 106.252, -354.053, 117.78, 1.646, 1.646, 1.646, false, "peripherie" },
	{ "Desert_Mesa", 65.989, -1, -374.602, 345.12, 2.0, 3.496, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 88.055, 101.521, -376.322, 176.33, 1.584, 1.584, 1.584, false, "peripherie" },
	{ "Desert_Saguaro", 58.741, 101.521, -382.448, 346.87, 1.405, 1.405, 1.405, false, "peripherie" },
	{ "Desert_Mesa", 20.085, -1, -384.408, 356.0, 2.0, 3.305, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 27.379, 95.789, -393.522, 344.95, 1.315, 1.315, 1.315, false, "peripherie" },
	{ "Desert_Palmier", 0.542, 95.789, -393.329, 336.66, 1.818, 1.818, 1.818, false, "peripherie" },
	{ "Desert_Mesa", -62.669, -1, -376.429, 6.64, 2.0, 3.175, 1.6, false, "peripherie" },
	{ "Desert_Palmier", -68.108, 91.912, -381.385, 340.02, 1.633, 1.633, 1.633, false, "peripherie" },
	{ "Desert_Palmier", -51.066, 91.912, -386.913, 123.35, 1.32, 1.32, 1.32, false, "peripherie" },
	{ "Desert_Mesa", -141.228, -1, -352.9, 22.77, 2.0, 3.107, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -165.718, 89.891, -353.648, 333.74, 1.716, 1.716, 1.716, false, "peripherie" },
	{ "Desert_Saguaro", -133.671, 89.891, -367.353, 167.84, 1.618, 1.618, 1.618, false, "peripherie" },
	{ "Desert_Mesa", -189.882, -1, -326.268, 34.02, 2.0, 3.817, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -185.327, 111.117, -335.774, 345.06, 1.565, 1.565, 1.565, false, "peripherie" },
	{ "Desert_Saguaro", -199.818, 111.117, -327.278, 120.3, 1.822, 1.822, 1.822, false, "peripherie" },
	{ "Desert_Mesa", -244.888, -1, -290.09, 39.93, 2.0, 3.254, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -253.508, 94.274, -290.6, 151.94, 1.768, 1.768, 1.768, false, "peripherie" },
	{ "Desert_Saguaro", -239.353, 94.274, -306.422, 92.5, 1.366, 1.366, 1.366, false, "peripherie" },
	{ "Desert_Mesa", -303.283, -1, -225.557, 56.63, 2.0, 3.456, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -307.557, 100.301, -230.116, 114.81, 1.305, 1.305, 1.305, false, "peripherie" },
	{ "Desert_Saguaro", -314.874, 100.301, -225.896, 78.08, 1.372, 1.372, 1.372, false, "peripherie" },
	{ "Desert_Mesa", -339.049, -1, -173.473, 64.98, 2.0, 3.42, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -349.056, 99.249, -168.25, 163.55, 1.594, 1.594, 1.594, false, "peripherie" },
	{ "Desert_Saguaro", -336.753, 99.249, -194.171, 246.71, 1.562, 1.562, 1.562, false, "peripherie" },
	{ "Desert_Mesa", -366.737, -1, -109.753, 71.59, 2.0, 3.612, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -377.307, 104.969, -100.343, 301.01, 1.336, 1.336, 1.336, false, "peripherie" },
	{ "Desert_Saguaro", -365.327, 104.969, -131.143, 140.27, 1.43, 1.43, 1.43, false, "peripherie" },
	{ "Desert_Mesa", -376.451, -1, -40.899, 83.07, 2.0, 3.402, 1.6, false, "peripherie" },
	{ "Desert_Palmier", -387.49, 98.702, -36.795, 135.99, 1.76, 1.76, 1.76, false, "peripherie" },
	{ "Desert_Saguaro", -383.35, 98.702, -62.141, 204.18, 1.771, 1.771, 1.771, false, "peripherie" },
	{ "Desert_Mesa", -375.202, -1, 39.255, 93.08, 2.0, 3.757, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -383.145, 109.323, 53.196, 104.2, 1.563, 1.563, 1.563, false, "peripherie" },
	{ "Desert_Saguaro", -381.845, 109.323, 30.724, 16.19, 1.612, 1.612, 1.612, false, "peripherie" },
	{ "Desert_Mesa", -365.818, -1, 107.935, 108.86, 2.0, 3.58, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -373.828, 104.031, 110.151, 284.76, 1.724, 1.724, 1.724, false, "peripherie" },
	{ "Desert_Saguaro", -369.22, 104.031, 132.396, 356.02, 1.906, 1.906, 1.906, false, "peripherie" },
	{ "Desert_Mesa", -350.391, -1, 158.69, 110.36, 2.0, 3.315, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -357.667, 96.098, 160.829, 113.04, 1.544, 1.544, 1.544, false, "peripherie" },
	{ "Desert_Saguaro", -350.953, 96.098, 178.811, 190.13, 1.925, 1.925, 1.925, false, "peripherie" },
	{ "Desert_Mesa", -303.656, -1, 234.358, 127.47, 2.0, 3.652, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -293.903, 106.18, 254.317, 249.55, 1.714, 1.714, 1.714, false, "peripherie" },
	{ "Desert_Saguaro", -295.707, 106.18, 255.681, 252.31, 1.501, 1.501, 1.501, false, "peripherie" },
	{ "Desert_Mesa", -269.932, -1, 270.714, 130.35, 2.0, 3.705, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -275.638, 107.75, 276.792, 266.63, 1.701, 1.701, 1.701, false, "peripherie" },
	{ "Desert_Saguaro", -275.535, 107.75, 279.517, 250.15, 1.389, 1.389, 1.389, false, "peripherie" },
	{ "Desert_Mesa", -215.915, -1, 315.33, 146.89, 2.0, 3.844, 1.6, false, "peripherie" },
	{ "Desert_Palmier", -212.096, 111.902, 331.096, 318.61, 1.607, 1.607, 1.607, false, "peripherie" },
	{ "Desert_Saguaro", -230.535, 111.902, 317.268, 292.47, 1.409, 1.409, 1.409, false, "peripherie" },
	{ "Desert_Mesa", -157.091, -1, 350.6, 157.1, 2.0, 3.173, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -159.298, 91.859, 357.246, 349.99, 1.354, 1.354, 1.354, false, "peripherie" },
	{ "Desert_Palmier", -158.814, 91.859, 355.199, 329.61, 1.871, 1.871, 1.871, false, "peripherie" },
	{ "Desert_Mesa", -84.073, -1, 371.717, 162.63, 2.0, 3.33, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", -100.259, 96.539, 374.987, 296.96, 1.987, 1.987, 1.987, false, "peripherie" },
	{ "Desert_Saguaro", -66.436, 96.539, 384.891, 182.4, 1.639, 1.639, 1.639, false, "peripherie" },
	{ "Desert_Mesa", -19.782, -1, 382.026, 173.04, 2.0, 3.012, 1.6, false, "peripherie" },
	{ "Desert_Palmier", -34.287, 87.027, 386.681, 338.97, 1.444, 1.444, 1.444, false, "peripherie" },
	{ "Desert_Saguaro", -6.26, 87.027, 390.042, 314.95, 1.65, 1.65, 1.65, false, "peripherie" },
	{ "Desert_Mesa", 51.42, -1, 375.384, 184.4, 2.0, 3.703, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 54.376, 107.689, 385.213, 13.12, 1.487, 1.487, 1.487, false, "peripherie" },
	{ "Desert_Saguaro", 40.944, 107.689, 387.01, 144.39, 1.67, 1.67, 1.67, false, "peripherie" },
	{ "Desert_Mesa", 120.107, -1, 363.924, 195.25, 2.0, 3.281, 1.6, false, "peripherie" },
	{ "Desert_Palmier", 136.397, 95.083, 366.299, 354.5, 1.931, 1.931, 1.931, false, "peripherie" },
	{ "Desert_Palmier", 141.876, 95.083, 361.732, 136.53, 1.926, 1.926, 1.926, false, "peripherie" },
	{ "Desert_Mesa", 185.615, -1, 335.814, 213.85, 2.0, 3.583, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 196.354, 104.104, 342.008, 196.98, 1.532, 1.532, 1.532, false, "peripherie" },
	{ "Desert_Saguaro", 190.214, 104.104, 344.801, 32.23, 1.586, 1.586, 1.586, false, "peripherie" },
	{ "Desert_Mesa", 246.886, -1, 285.591, 220.1, 2.0, 3.863, 1.6, false, "peripherie" },
	{ "Desert_Palmier", 243.911, 112.492, 300.186, 239.53, 1.687, 1.687, 1.687, false, "peripherie" },
	{ "Desert_Saguaro", 258.177, 112.492, 283.027, 15.87, 1.418, 1.418, 1.418, false, "peripherie" },
	{ "Desert_Mesa", 307.281, -1, 228.857, 235.85, 2.0, 3.874, 1.6, false, "peripherie" },
	{ "Desert_Palmier", 301.749, 112.8, 246.294, 355.42, 1.822, 1.822, 1.822, false, "peripherie" },
	{ "Desert_Saguaro", 321.884, 112.8, 218.689, 39.16, 1.976, 1.976, 1.976, false, "peripherie" },
	{ "Desert_Mesa", 331.513, -1, 184.414, 245.89, 2.0, 3.549, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 348.039, 103.086, 167.116, 43.47, 1.461, 1.461, 1.461, false, "peripherie" },
	{ "Desert_Saguaro", 346.156, 103.086, 180.026, 339.48, 1.685, 1.685, 1.685, false, "peripherie" },
	{ "Desert_Mesa", 369.464, -1, 105.251, 253.6, 2.0, 3.708, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 381.922, 107.856, 95.942, 43.79, 1.728, 1.728, 1.728, false, "peripherie" },
	{ "Desert_Saguaro", 374.097, 107.856, 121.876, 130.1, 1.991, 1.991, 1.991, false, "peripherie" },
	{ "Desert_Mesa", 376.33, -1, 33.464, 261.05, 2.0, 3.074, 1.6, false, "peripherie" },
	{ "Desert_Saguaro", 385.059, 88.899, 25.106, 94.85, 1.375, 1.375, 1.375, false, "peripherie" },
	{ "Desert_Saguaro", 382.754, 88.899, 38.309, 309.15, 1.377, 1.377, 1.377, false, "peripherie" },
	{ "Desert_RocherGres_B", 653.865, -6, -48.215, 344.24, 3.271, 3.252, 2.713, false, "lointain" },
	{ "Desert_Mesa", 539.855, -6, -202.97, 125.37, 3.151, 2.506, 2.556, false, "lointain" },
	{ "Desert_RocherGres_B", 481.139, -6, -334.641, 19.36, 3.332, 2.235, 2.22, false, "lointain" },
	{ "Desert_Mesa", 330.411, -6, -582.272, 213.04, 3.557, 2.965, 2.241, false, "lointain" },
	{ "Desert_RocherGres_B", 109.63, -6, -698.441, 23.1, 3.159, 2.204, 2.082, false, "lointain" },
	{ "Desert_Mesa", -51.236, -6, -682.164, 172.37, 2.714, 2.986, 2.639, false, "lointain" },
	{ "Desert_RocherGres_B", -286.593, -6, -631.569, 305.43, 3.32, 3.062, 2.227, false, "lointain" },
	{ "Desert_Mesa", -439.852, -6, -443.664, 123.93, 3.458, 3.097, 2.271, false, "lointain" },
	{ "Desert_RocherGres_B", -489.232, -6, -230.446, 210.66, 2.867, 2.25, 2.115, false, "lointain" },
	{ "Desert_Mesa", -599.682, -6, 17.863, 98.64, 2.403, 2.239, 2.161, false, "lointain" },
	{ "Desert_RocherGres_B", -543.981, -6, 192.867, 130.97, 2.759, 2.745, 2.379, false, "lointain" },
	{ "Desert_Mesa", -446.034, -6, 348.782, 118.62, 2.575, 3.05, 2.544, false, "lointain" },
	{ "Desert_RocherGres_B", -415.281, -6, 586.897, 7.06, 3.427, 2.471, 2.259, false, "lointain" },
	{ "Desert_Mesa", -90.855, -6, 514.426, 248.3, 2.415, 2.336, 2.786, false, "lointain" },
	{ "Desert_RocherGres_B", 131.678, -6, 605.267, 311.35, 3.463, 2.743, 2.01, false, "lointain" },
	{ "Desert_Mesa", 310.749, -6, 447.449, 168.57, 2.558, 3.195, 2.588, false, "lointain" },
	{ "Desert_RocherGres_B", 464.881, -6, 341.258, 314.41, 2.467, 2.882, 2.299, false, "lointain" },
	{ "Desert_Mesa", 494.667, -6, 210.562, 67.93, 2.635, 2.206, 2.775, false, "lointain" },
	{ "Desert_RocherGres_A", 719.15, -4, -126.806, 55.83, 6.803, 6.803, 6.803, false, "lointain" },
	{ "Desert_RocherGres_A", 328.476, -4, -592.587, 227.23, 6.347, 6.347, 6.347, false, "lointain" },
	{ "Desert_RocherGres_A", -261.965, -4, -648.386, 118.78, 6.619, 6.619, 6.619, false, "lointain" },
	{ "Desert_RocherGres_A", -616.912, -4, -188.609, 136.96, 7.179, 7.179, 7.179, false, "lointain" },
	{ "Desert_RocherGres_A", -642.315, -4, 433.247, 76.99, 8.489, 8.489, 8.489, false, "lointain" },
	{ "Desert_RocherGres_A", -63.136, -4, 721.649, 339.11, 7.139, 7.139, 7.139, false, "lointain" },
	{ "Desert_RocherGres_A", 496.309, -4, 479.28, 250.62, 7.25, 7.25, 7.25, false, "lointain" },
}

-- Eau / lave (pièces Roblox, rien à envoyer) : kind, forme, x, y, z (centre), taille X, épaisseur, Z, yaw
local SURFACES = {
	{ "water", "disc", 251.295, 0.13, -104.09, 26.0, 0.26, 26.0, 0.0 },
}

-- Décors qui éclairent (PointLight sans ombre, à une hauteur relative de la pièce) : seulement dans leur monde,
-- client/WorldSkin les éteint pour les joueurs des autres mondes.
local LIGHTS = {
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NO_SHADOW = { chemin = true, prairie = true, lointain = true }
local SLIM = { peripherie = true, lointain = true }
local WORLD_IDS = { Prairie = true, Desert = true, Volcan = true, Glace = true, Abysses = true, Cosmos = true, Divin = true }

local function collectImported()
	local art = ReplicatedStorage:FindFirstChild("ArtModels")
	if not art then
		art = Instance.new("Folder")
		art.Name = "ArtModels"
		art.Parent = ReplicatedStorage
	end
	local library = art:FindFirstChild("Map")
	if not library then
		library = Instance.new("Folder")
		library.Name = "Map"
		library.Parent = art
	end
	local moved, containers = 0, {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("MeshPart") and SIZE[inst.Name] and not inst:FindFirstAncestor("MapDecor")
			and not inst:FindFirstAncestor("Map") then
			local top = inst
			while top.Parent ~= Workspace do
				top = top.Parent
			end
			if top ~= inst then
				containers[top] = true
			end
			local old = library:FindFirstChild(inst.Name)
			if old then
				old:Destroy()
			end
			inst.Anchored = true
			local sa = inst:FindFirstChildOfClass("SurfaceAppearance")
			local glow = EMISSIVE[inst.Name]
			if sa and COLOR_OVERRIDE[inst.Name] then
				sa.ColorMapContent = Content.fromUri(COLOR_OVERRIDE[inst.Name])
			end
			if sa and glow then
				sa.EmissiveMaskContent = Content.fromUri(glow.id)
				sa.EmissiveStrength = glow.strength
				sa.EmissiveTint = Color3.new(1, 1, 1)
			end
			inst.Parent = library
			moved += 1
		end
	end
	for container in pairs(containers) do
		if #container:GetDescendants() == 0 or not container:FindFirstChildWhichIsA("BasePart", true) then
			container:Destroy()
		end
	end
	local count, total = 0, 0
	for name in pairs(SIZE) do
		total += 1
		if library:FindFirstChild(name) then
			count += 1
		end
	end
	return string.format("%d décors importés rangés (%d / %d de ce monde dans ArtModels.Map)", moved, count, total)
end

-- Workspace.MapDecor, avec un dossier par monde (l'ancien rangement à plat passe dans MapDecor.Prairie).
local function decorRoot(): Folder
	local root = Workspace:FindFirstChild("MapDecor")
	if not root then
		root = Instance.new("Folder")
		root.Name = "MapDecor"
		root.Parent = Workspace
	end
	local legacy = {}
	for _, child in ipairs(root:GetChildren()) do
		if not WORLD_IDS[child.Name] then
			table.insert(legacy, child)
		end
	end
	if #legacy > 0 then
		local prairie = root:FindFirstChild("Prairie") or Instance.new("Folder")
		prairie.Name = "Prairie"
		prairie.Parent = root
		for _, child in ipairs(legacy) do
			child.Parent = prairie
		end
	end
	return root
end

local function sectorOf(x: number, z: number): number
	return math.floor(((math.deg(math.atan2(z, x)) + 360) % 360) / 45) + 1
end

local LAVA_LIGHT = Color3.fromRGB(255, 110, 40)
local SURFACE_LOOK = {
	water = { name = "Eau", color = Color3.fromRGB(47, 168, 255), material = Enum.Material.Glass, transparency = 0.35 },
	lava = { name = "Lave", color = Color3.fromRGB(255, 122, 26), material = Enum.Material.Neon, transparency = 0 },
	-- bleu soutenu : un bleu pâle disparaît sur le sol de neige (vu en jeu le 25 oct.)
	ice = { name = "Glace", color = Color3.fromRGB(110, 190, 240), material = Enum.Material.Ice, transparency = 0 },
}

local function addLight(part: BasePart, spec)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Lumiere"
	attachment.Position = Vector3.new(0, part.Size.Y * spec.rel, 0)
	local light = Instance.new("PointLight")
	light.Color = LAVA_LIGHT
	light.Range = spec.range
	light.Brightness = spec.brightness
	light.Shadows = false
	light.Parent = attachment
	attachment.Parent = part
end

local function makeSurface(parent: Instance, s)
	local kind, shape, x, y, z, sx, sy, sz, yaw = table.unpack(s)
	local look = SURFACE_LOOK[kind]
	local part = Instance.new("Part")
	part.Name = look.name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = look.material
	part.Color = look.color
	part.Transparency = look.transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "disc" then
		part.Shape = Enum.PartType.Cylinder -- axe X : couché pour faire un disque
		part.Size = Vector3.new(sy, sx, sx)
		part.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
	else
		part.Size = Vector3.new(sx, sy, sz)
		part.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
	end
	if kind == "lava" then
		local light = Instance.new("PointLight")
		light.Color = LAVA_LIGHT
		light.Range = 40
		light.Brightness = 2
		light.Shadows = false
		light.Parent = part
	end
	part.Parent = parent
end

local function placeDecor()
	local library = ReplicatedStorage:FindFirstChild("ArtModels")
	library = library and library:FindFirstChild("Map")
	if not library then
		return "ReplicatedStorage.ArtModels.Map introuvable : importer les décors d'abord"
	end
	local root = decorRoot()
	local old = root:FindFirstChild(WORLD)
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Folder")
	holder.Name = WORLD
	local groups = {}
	local placed, skipped, missing = 0, 0, {}
	for _, item in ipairs(ITEMS) do
		local asset, x, y, z, yaw, sx, sy, sz, collide, zone = table.unpack(item)
		if zone == "base" and not INCLUDE_BASES then
			skipped += 1
			continue
		end
		local source = library:FindFirstChild(asset)
		local part = source and (source:IsA("BasePart") and source or source:FindFirstChildWhichIsA("BasePart", true))
		if not part then
			missing[asset] = true
			continue
		end
		local copy = part:Clone()
		local size = SIZE[asset] * Vector3.new(sx, sy, sz)
		copy.Size = size
		copy.CFrame = CFrame.new(x, y + size.Y / 2, z) * CFrame.Angles(0, math.rad(yaw + FBX_YAW_OFFSET), 0)
		copy.Anchored = true
		copy.CanCollide = collide
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = not NO_SHADOW[zone]
		pcall(function()
			copy.CollisionFidelity = Enum.CollisionFidelity.Box
			copy.RenderFidelity = Enum.RenderFidelity.Automatic
		end)
		local key = zone .. "_" .. sectorOf(x, z)
		local group = groups[key]
		if not group then
			group = Instance.new("Model")
			group.Name = key
			group.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			if SLIM[zone] then
				pcall(function()
					group.LevelOfDetail = Enum.ModelLevelOfDetail.SLIM
				end)
			end
			group.Parent = holder
			groups[key] = group
		end
		if LIGHTS[asset] and zone ~= "lointain" and zone ~= "peripherie" then -- au loin : inutile et coûteux
			addLight(copy, LIGHTS[asset])
		end
		copy.Parent = group
		placed += 1
	end
	if #SURFACES > 0 then
		local water = Instance.new("Model")
		water.Name = "surfaces"
		for _, s in ipairs(SURFACES) do
			makeSurface(water, s)
		end
		water.Parent = holder
	end
	holder.Parent = root
	local names = {}
	for asset in pairs(missing) do
		table.insert(names, asset)
	end
	return string.format("%d décors posés dans MapDecor.%s (+ %d surfaces d'eau / lave), %d de base ignorés, manquants : %s",
		placed, WORLD, #SURFACES, skipped, #names > 0 and table.concat(names, ", ") or "aucun")
end

local report = {}
if MODE == "remove" then
	local root = Workspace:FindFirstChild("MapDecor")
	local old = root and root:FindFirstChild(WORLD)
	if old then
		old:Destroy()
	end
	table.insert(report, "Workspace.MapDecor." .. WORLD .. " retiré")
else
	if MODE == "all" or MODE == "collect" then
		table.insert(report, collectImported())
	end
	if MODE == "all" or MODE == "decor" then
		table.insert(report, placeDecor())
	end
end
print("[MapLook] " .. table.concat(report, " | "))
return table.concat(report, " | ")
