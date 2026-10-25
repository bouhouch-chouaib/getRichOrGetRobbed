--!nocheck
-- Décors « niveau studio » du monde Volcan dans Studio (mode Édition, barre MCP execute_luau ou rbxm + require).
-- GÉNÉRÉ par dataset_and_pipeline/tools/make_map_look_script.py (ne pas modifier à la main).
-- Avant : importer baked_assets/map/volcan/Decors_Volcan.fbx (Fichier > Importer 3D, réglages par défaut) : les MeshParts
-- nommées comme les décors arrivent dans le Workspace. Ce script :
--   1. range ces MeshParts dans ReplicatedStorage.ArtModels.Map.<Asset> (+ lueur / couleur de map_roblox.json) et
--      supprime l'import (sauvegarder le jeu ensuite : ArtModels n'est que dans le fichier du jeu) ;
--   2. pose les décors de l'arène dans Workspace.MapDecor.Volcan (un Model par zone et par huitième de carte,
--      pour le streaming), sans toucher à Workspace.Map ni aux autres mondes ; les pièces de l'ancien rangement
--      (directement sous MapDecor) passent dans MapDecor.Prairie. Sans les décors des bases (zone « base ») :
--      ce sont les dossiers <Monde>Look de server/MapGenerator. client/WorldSkin montre le monde du joueur ;
--   3. MODE = "remove" retire Workspace.MapDecor.Volcan.

local WORLD = "Volcan"
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
	Pancarte = Vector3.new(9.772, 7.5, 2.783),
	Volcan_ArbreCalcine = Vector3.new(8.739, 13.67, 9.666),
	Volcan_Chariot = Vector3.new(4.516, 4.272, 3.6),
	Volcan_Chaudron = Vector3.new(4.176, 3.65, 4.176),
	Volcan_Cheminee = Vector3.new(11.436, 6.75, 11.214),
	Volcan_Cristaux = Vector3.new(4.9, 5.846, 3.9),
	Volcan_Dalle = Vector3.new(8.063, 1.415, 5.957),
	Volcan_Eclats = Vector3.new(8.274, 8.233, 7.557),
	Volcan_Enclume = Vector3.new(9.137, 7.203, 4.1),
	Volcan_Escalier = Vector3.new(19.2, 2.3, 5.836),
	Volcan_Grill = Vector3.new(12.567, 9.2, 4.904),
	Volcan_Orgues = Vector3.new(36.377, 31.38, 15.648),
	Volcan_PilierBrasier = Vector3.new(4.93, 15.9, 4.93),
	Volcan_PorteForge = Vector3.new(28.4, 22.799, 5.3),
	Volcan_Rempart = Vector3.new(12.0, 4.8, 2.375),
	Volcan_Roche = Vector3.new(9.147, 5.322, 6.075),
	Volcan_TeteGolem = Vector3.new(14.384, 7.554, 7.401),
	Volcan_Touffe = Vector3.new(2.11, 2.741, 2.079),
}

-- asset, x, y (pied), z, yaw en degrés, échelle X, Y, Z, collision, zone
local ITEMS = {
	{ "Volcan_Dalle", 44.615, -0.55, -5.874, 277.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 41.575, -0.55, -17.221, 292.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 35.701, -0.55, -27.394, 307.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 27.394, -0.55, -35.701, 322.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 17.221, -0.55, -41.575, 337.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 5.874, -0.55, -44.615, 352.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -5.874, -0.55, -44.615, 7.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -17.221, -0.55, -41.575, 22.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -27.394, -0.55, -35.701, 37.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -35.701, -0.55, -27.394, 52.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -41.575, -0.55, -17.221, 67.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -44.615, -0.55, -5.874, 82.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -44.615, -0.55, 5.874, 97.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -41.575, -0.55, 17.221, 112.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -35.701, -0.55, 27.394, 127.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -27.394, -0.55, 35.701, 142.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -17.221, -0.55, 41.575, 157.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", -5.874, -0.55, 44.615, 172.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 5.874, -0.55, 44.615, 187.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 17.221, -0.55, 41.575, 202.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 27.394, -0.55, 35.701, 217.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 35.701, -0.55, 27.394, 232.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 41.575, -0.55, 17.221, 247.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_Dalle", 44.615, -0.55, 5.874, 262.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Volcan_PorteForge", 66.0, 0, -0.0, 270.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PilierBrasier", 62.232, 0, 14.941, 45.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PilierBrasier", 62.232, 0, -14.941, 45.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_Eclats", 52.661, -0.2, 21.813, 0.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PorteForge", 46.669, 0, 46.669, 225.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PilierBrasier", 33.44, 0, 54.569, 0.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PilierBrasier", 54.569, 0, 33.44, 0.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_Enclume", 21.813, -0.2, 52.661, 53.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PorteForge", 0.0, 0, 66.0, 180.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PilierBrasier", -14.941, 0, 62.232, 315.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PilierBrasier", 14.941, 0, 62.232, 315.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_Eclats", -21.813, -0.2, 52.661, 106.0, 1.1, 1.1, 1.1, true, "trou" },
	{ "Volcan_PorteForge", -46.669, 0, 46.669, 135.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PilierBrasier", -54.569, 0, 33.44, 270.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PilierBrasier", -33.44, 0, 54.569, 270.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_Enclume", -52.661, -0.2, 21.813, 159.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PorteForge", -66.0, 0, 0.0, 90.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PilierBrasier", -62.232, 0, -14.941, 225.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PilierBrasier", -62.232, 0, 14.941, 225.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_Eclats", -52.661, -0.2, -21.813, 212.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PorteForge", -46.669, 0, -46.669, 45.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PilierBrasier", -33.44, 0, -54.569, 180.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PilierBrasier", -54.569, 0, -33.44, 180.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_Enclume", -21.813, -0.2, -52.661, 265.0, 1.1, 1.1, 1.1, true, "trou" },
	{ "Volcan_PorteForge", -0.0, 0, -66.0, 0.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PilierBrasier", 14.941, 0, -62.232, 135.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PilierBrasier", -14.941, 0, -62.232, 135.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_Eclats", 21.813, -0.2, -52.661, 318.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PorteForge", 46.669, 0, -46.669, 315.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_PilierBrasier", 54.569, 0, -33.44, 90.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_PilierBrasier", 33.44, 0, -54.569, 90.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Volcan_Enclume", 52.661, -0.2, -21.813, 11.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Volcan_Touffe", 70.953, 0, 10.505, 309.6, 0.962, 0.962, 0.962, false, "chemin" },
	{ "Volcan_Touffe", 81.739, 0, 10.682, 282.01, 1.229, 1.229, 1.229, false, "chemin" },
	{ "Volcan_Touffe", 96.584, 0, 10.983, 211.15, 1.044, 1.044, 1.044, false, "chemin" },
	{ "Volcan_Touffe", 110.497, 0, 9.799, 161.88, 1.389, 1.389, 1.389, false, "chemin" },
	{ "Volcan_Touffe", 124.979, 0, 10.823, 90.54, 1.488, 1.488, 1.488, false, "chemin" },
	{ "Volcan_Touffe", 141.413, 0, 11.049, 184.89, 0.946, 0.946, 0.946, false, "chemin" },
	{ "Volcan_Touffe", 153.136, 0, 10.603, 164.68, 1.426, 1.426, 1.426, false, "chemin" },
	{ "Volcan_Touffe", 74.619, 0, -9.645, 130.88, 1.153, 1.153, 1.153, false, "chemin" },
	{ "Volcan_Touffe", 86.81, 0, -10.654, 41.92, 1.204, 1.204, 1.204, false, "chemin" },
	{ "Volcan_Touffe", 101.811, 0, -10.68, 330.03, 1.055, 1.055, 1.055, false, "chemin" },
	{ "Volcan_Touffe", 114.17, 0, -11.267, 186.48, 0.915, 0.915, 0.915, false, "chemin" },
	{ "Volcan_Cristaux", 124.967, 0, -9.832, 253.68, 0.722, 0.722, 0.722, false, "chemin" },
	{ "Volcan_Touffe", 134.787, 0, -10.72, 173.56, 1.037, 1.037, 1.037, false, "chemin" },
	{ "Volcan_Touffe", 150.875, 0, -10.728, 168.99, 1.458, 1.458, 1.458, false, "chemin" },
	{ "Pancarte", 164.0, 0, 11.0, 70.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Volcan_Touffe", 45.083, 0, 60.085, 110.75, 1.38, 1.38, 1.38, false, "chemin" },
	{ "Volcan_Touffe", 54.389, 0, 69.185, 155.9, 1.077, 1.077, 1.077, false, "chemin" },
	{ "Volcan_Touffe", 62.843, 0, 76.503, 215.02, 1.175, 1.175, 1.175, false, "chemin" },
	{ "Volcan_Touffe", 71.584, 0, 86.406, 93.64, 1.191, 1.191, 1.191, false, "chemin" },
	{ "Volcan_Touffe", 80.411, 0, 96.091, 200.82, 1.444, 1.444, 1.444, false, "chemin" },
	{ "Volcan_Touffe", 92.127, 0, 106.509, 35.41, 1.314, 1.314, 1.314, false, "chemin" },
	{ "Volcan_Touffe", 102.679, 0, 117.567, 347.5, 1.48, 1.48, 1.48, false, "chemin" },
	{ "Volcan_Touffe", 59.078, 0, 45.338, 179.43, 0.958, 0.958, 0.958, false, "chemin" },
	{ "Volcan_Touffe", 70.112, 0, 55.489, 5.05, 0.9, 0.9, 0.9, false, "chemin" },
	{ "Volcan_Cristaux", 80.424, 0, 64.475, 285.76, 0.562, 0.562, 0.562, false, "chemin" },
	{ "Volcan_Touffe", 90.072, 0, 74.581, 240.65, 1.281, 1.281, 1.281, false, "chemin" },
	{ "Volcan_Touffe", 96.753, 0, 82.379, 277.03, 1.47, 1.47, 1.47, false, "chemin" },
	{ "Volcan_Cristaux", 106.418, 0, 91.008, 80.25, 0.647, 0.647, 0.647, false, "chemin" },
	{ "Volcan_Touffe", 118.401, 0, 102.595, 30.4, 1.301, 1.301, 1.301, false, "chemin" },
	{ "Pancarte", 108.187, 0, 123.744, 25.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Volcan_Touffe", -11.247, 0, 76.268, 148.33, 1.385, 1.385, 1.385, false, "chemin" },
	{ "Volcan_Cristaux", -9.954, 0, 89.428, 38.21, 0.722, 0.722, 0.722, false, "chemin" },
	{ "Volcan_Touffe", -10.225, 0, 98.839, 277.03, 0.915, 0.915, 0.915, false, "chemin" },
	{ "Volcan_Touffe", -10.19, 0, 111.922, 117.38, 0.973, 0.973, 0.973, false, "chemin" },
	{ "Volcan_Touffe", -10.629, 0, 128.512, 55.4, 1.212, 1.212, 1.212, false, "chemin" },
	{ "Volcan_Touffe", -10.206, 0, 140.981, 244.26, 0.942, 0.942, 0.942, false, "chemin" },
	{ "Volcan_Touffe", -9.952, 0, 153.174, 16.29, 1.227, 1.227, 1.227, false, "chemin" },
	{ "Volcan_Touffe", 10.958, 0, 73.615, 255.94, 1.427, 1.427, 1.427, false, "chemin" },
	{ "Volcan_Touffe", 10.554, 0, 83.648, 186.07, 1.474, 1.474, 1.474, false, "chemin" },
	{ "Volcan_Touffe", 11.12, 0, 93.931, 153.13, 1.148, 1.148, 1.148, false, "chemin" },
	{ "Volcan_Touffe", 10.149, 0, 103.56, 94.84, 1.199, 1.199, 1.199, false, "chemin" },
	{ "Volcan_Touffe", 10.348, 0, 118.802, 117.28, 1.189, 1.189, 1.189, false, "chemin" },
	{ "Volcan_Touffe", 11.034, 0, 128.763, 293.81, 1.409, 1.409, 1.409, false, "chemin" },
	{ "Volcan_Touffe", 11.317, 0, 139.614, 232.44, 1.145, 1.145, 1.145, false, "chemin" },
	{ "Volcan_Touffe", 11.129, 0, 154.88, 346.03, 1.111, 1.111, 1.111, false, "chemin" },
	{ "Volcan_Touffe", 10.612, 0, 165.134, 193.82, 0.966, 0.966, 0.966, false, "chemin" },
	{ "Pancarte", -11.0, 0, 164.0, 340.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Volcan_Touffe", -60.153, 0, 45.13, 106.09, 1.061, 1.061, 1.061, false, "chemin" },
	{ "Volcan_Touffe", -69.067, 0, 55.232, 343.76, 1.003, 1.003, 1.003, false, "chemin" },
	{ "Volcan_Touffe", -80.14, 0, 64.631, 66.78, 1.278, 1.278, 1.278, false, "chemin" },
	{ "Volcan_Touffe", -88.756, 0, 74.475, 104.77, 1.089, 1.089, 1.089, false, "chemin" },
	{ "Volcan_Touffe", -96.323, 0, 82.587, 323.3, 1.366, 1.366, 1.366, false, "chemin" },
	{ "Volcan_Cristaux", -104.972, 0, 91.356, 8.27, 0.531, 0.531, 0.531, false, "chemin" },
	{ "Volcan_Touffe", -115.929, 0, 100.886, 126.11, 1.368, 1.368, 1.368, false, "chemin" },
	{ "Volcan_Touffe", -45.63, 0, 60.772, 113.78, 1.029, 1.029, 1.029, false, "chemin" },
	{ "Volcan_Touffe", -54.148, 0, 70.217, 247.13, 1.417, 1.417, 1.417, false, "chemin" },
	{ "Volcan_Touffe", -64.437, 0, 80.365, 340.94, 1.114, 1.114, 1.114, false, "chemin" },
	{ "Volcan_Cristaux", -75.581, 0, 90.269, 250.31, 0.572, 0.572, 0.572, false, "chemin" },
	{ "Volcan_Cristaux", -86.903, 0, 102.516, 276.44, 0.58, 0.58, 0.58, false, "chemin" },
	{ "Volcan_Touffe", -98.703, 0, 113.66, 201.91, 1.333, 1.333, 1.333, false, "chemin" },
	{ "Volcan_Cristaux", -105.606, 0, 120.758, 45.25, 0.589, 0.589, 0.589, false, "chemin" },
	{ "Pancarte", -123.744, 0, 108.187, 295.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Volcan_Touffe", -75.246, 0, -9.652, 128.15, 1.13, 1.13, 1.13, false, "chemin" },
	{ "Volcan_Touffe", -86.161, 0, -10.358, 45.07, 1.226, 1.226, 1.226, false, "chemin" },
	{ "Volcan_Touffe", -100.453, 0, -11.282, 142.87, 1.053, 1.053, 1.053, false, "chemin" },
	{ "Volcan_Touffe", -110.635, 0, -9.642, 172.38, 1.058, 1.058, 1.058, false, "chemin" },
	{ "Volcan_Touffe", -122.153, 0, -11.3, 302.24, 1.232, 1.232, 1.232, false, "chemin" },
	{ "Volcan_Touffe", -136.354, 0, -11.33, 95.48, 1.28, 1.28, 1.28, false, "chemin" },
	{ "Volcan_Touffe", -151.391, 0, -10.171, 4.11, 1.487, 1.487, 1.487, false, "chemin" },
	{ "Volcan_Touffe", -164.155, 0, -11.346, 310.36, 1.456, 1.456, 1.456, false, "chemin" },
	{ "Volcan_Touffe", -73.193, 0, 11.357, 83.7, 1.397, 1.397, 1.397, false, "chemin" },
	{ "Volcan_Touffe", -84.942, 0, 9.962, 229.32, 1.229, 1.229, 1.229, false, "chemin" },
	{ "Volcan_Touffe", -97.735, 0, 11.02, 67.64, 1.277, 1.277, 1.277, false, "chemin" },
	{ "Volcan_Touffe", -107.965, 0, 11.209, 292.95, 1.401, 1.401, 1.401, false, "chemin" },
	{ "Volcan_Touffe", -122.584, 0, 11.032, 30.31, 1.124, 1.124, 1.124, false, "chemin" },
	{ "Volcan_Touffe", -137.432, 0, 9.848, 359.57, 0.911, 0.911, 0.911, false, "chemin" },
	{ "Volcan_Touffe", -148.169, 0, 11.128, 206.15, 1.473, 1.473, 1.473, false, "chemin" },
	{ "Volcan_Touffe", -160.213, 0, 11.334, 231.86, 0.995, 0.995, 0.995, false, "chemin" },
	{ "Pancarte", -164.0, 0, -11.0, 250.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Volcan_Touffe", -42.261, 0, -57.702, 94.12, 0.925, 0.925, 0.925, false, "chemin" },
	{ "Volcan_Touffe", -51.908, 0, -67.488, 105.45, 1.225, 1.225, 1.225, false, "chemin" },
	{ "Volcan_Touffe", -60.057, 0, -76.109, 268.92, 0.906, 0.906, 0.906, false, "chemin" },
	{ "Volcan_Touffe", -70.476, 0, -85.274, 292.37, 1.441, 1.441, 1.441, false, "chemin" },
	{ "Volcan_Touffe", -81.72, 0, -97.834, 185.83, 1.008, 1.008, 1.008, false, "chemin" },
	{ "Volcan_Touffe", -92.194, 0, -106.187, 185.4, 1.429, 1.429, 1.429, false, "chemin" },
	{ "Volcan_Touffe", -102.403, 0, -115.985, 132.48, 1.03, 1.03, 1.03, false, "chemin" },
	{ "Volcan_Cristaux", -108.866, 0, -123.995, 354.61, 0.621, 0.621, 0.621, false, "chemin" },
	{ "Volcan_Touffe", -60.881, 0, -46.334, 233.12, 1.109, 1.109, 1.109, false, "chemin" },
	{ "Volcan_Touffe", -72.059, 0, -58.175, 298.31, 1.31, 1.31, 1.31, false, "chemin" },
	{ "Volcan_Cristaux", -81.593, 0, -66.527, 280.46, 0.522, 0.522, 0.522, false, "chemin" },
	{ "Volcan_Touffe", -90.408, 0, -76.038, 81.38, 1.095, 1.095, 1.095, false, "chemin" },
	{ "Volcan_Touffe", -99.661, 0, -85.24, 260.59, 1.414, 1.414, 1.414, false, "chemin" },
	{ "Volcan_Touffe", -108.108, 0, -94.082, 79.26, 1.313, 1.313, 1.313, false, "chemin" },
	{ "Volcan_Touffe", -117.221, 0, -101.64, 289.17, 1.129, 1.129, 1.129, false, "chemin" },
	{ "Volcan_Touffe", -124.402, 0, -108.934, 45.93, 1.061, 1.061, 1.061, false, "chemin" },
	{ "Pancarte", -108.187, 0, -123.744, 205.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Volcan_Touffe", 11.114, 0, -72.56, 52.33, 1.276, 1.276, 1.276, false, "chemin" },
	{ "Volcan_Touffe", 11.35, 0, -83.435, 44.37, 1.076, 1.076, 1.076, false, "chemin" },
	{ "Volcan_Cristaux", 10.322, 0, -96.099, 257.93, 0.669, 0.669, 0.669, false, "chemin" },
	{ "Volcan_Touffe", 10.823, 0, -107.794, 327.08, 1.408, 1.408, 1.408, false, "chemin" },
	{ "Volcan_Touffe", 10.802, 0, -124.416, 75.57, 1.111, 1.111, 1.111, false, "chemin" },
	{ "Volcan_Touffe", 11.261, 0, -136.059, 3.79, 1.235, 1.235, 1.235, false, "chemin" },
	{ "Volcan_Touffe", 10.201, 0, -147.077, 149.26, 1.367, 1.367, 1.367, false, "chemin" },
	{ "Volcan_Touffe", 11.201, 0, -159.884, 13.5, 1.032, 1.032, 1.032, false, "chemin" },
	{ "Volcan_Cristaux", -10.084, 0, -76.815, 75.32, 0.614, 0.614, 0.614, false, "chemin" },
	{ "Volcan_Cristaux", -10.734, 0, -88.03, 249.28, 0.635, 0.635, 0.635, false, "chemin" },
	{ "Volcan_Touffe", -9.772, 0, -97.122, 78.99, 1.178, 1.178, 1.178, false, "chemin" },
	{ "Volcan_Touffe", -9.907, 0, -110.97, 204.35, 1.327, 1.327, 1.327, false, "chemin" },
	{ "Volcan_Cristaux", -10.606, 0, -125.419, 97.51, 0.605, 0.605, 0.605, false, "chemin" },
	{ "Volcan_Touffe", -10.922, 0, -135.901, 355.82, 1.446, 1.446, 1.446, false, "chemin" },
	{ "Volcan_Touffe", -10.214, 0, -150.164, 218.38, 1.053, 1.053, 1.053, false, "chemin" },
	{ "Volcan_Cristaux", -11.11, 0, -166.231, 176.4, 0.505, 0.505, 0.505, false, "chemin" },
	{ "Pancarte", 11.0, 0, -164.0, 160.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Volcan_Touffe", 58.683, 0, -43.184, 98.51, 1.405, 1.405, 1.405, false, "chemin" },
	{ "Volcan_Cristaux", 66.626, 0, -52.494, 147.91, 0.516, 0.516, 0.516, false, "chemin" },
	{ "Volcan_Touffe", 77.638, 0, -62.379, 275.71, 1.079, 1.079, 1.079, false, "chemin" },
	{ "Volcan_Touffe", 86.006, 0, -72.199, 188.08, 1.095, 1.095, 1.095, false, "chemin" },
	{ "Volcan_Touffe", 94.485, 0, -80.044, 355.99, 1.418, 1.418, 1.418, false, "chemin" },
	{ "Volcan_Touffe", 101.731, 0, -87.499, 313.75, 1.212, 1.212, 1.212, false, "chemin" },
	{ "Volcan_Touffe", 110.068, 0, -96.221, 77.34, 1.178, 1.178, 1.178, false, "chemin" },
	{ "Volcan_Touffe", 118.129, 0, -103.26, 184.93, 1.375, 1.375, 1.375, false, "chemin" },
	{ "Volcan_Touffe", 47.03, 0, -61.851, 302.61, 1.095, 1.095, 1.095, false, "chemin" },
	{ "Volcan_Touffe", 59.158, 0, -73.733, 194.07, 0.991, 0.991, 0.991, false, "chemin" },
	{ "Volcan_Touffe", 67.893, 0, -83.963, 47.25, 1.39, 1.39, 1.39, false, "chemin" },
	{ "Volcan_Touffe", 79.142, 0, -92.874, 12.43, 1.374, 1.374, 1.374, false, "chemin" },
	{ "Volcan_Touffe", 90.679, 0, -104.711, 194.51, 1.114, 1.114, 1.114, false, "chemin" },
	{ "Volcan_Cristaux", 99.62, 0, -113.672, 66.83, 0.538, 0.538, 0.538, false, "chemin" },
	{ "Volcan_Touffe", 109.226, 0, -124.049, 10.44, 1.033, 1.033, 1.033, false, "chemin" },
	{ "Pancarte", 123.744, 0, -108.187, 115.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Volcan_Touffe", -110.987, 0, 30.547, 268.97, 0.924, 0.924, 0.924, false, "prairie" },
	{ "Volcan_Touffe", -61.384, 0, -121.409, 14.5, 0.806, 0.806, 0.806, false, "prairie" },
	{ "Volcan_Touffe", 103.723, 0, -70.163, 253.67, 1.451, 1.451, 1.451, false, "prairie" },
	{ "Volcan_Touffe", 47.459, 0, -78.897, 293.92, 1.138, 1.138, 1.138, false, "prairie" },
	{ "Volcan_Touffe", -133.285, 0, -59.544, 61.44, 0.98, 0.98, 0.98, false, "prairie" },
	{ "Volcan_Touffe", 91.968, 0, 18.789, 57.06, 1.593, 1.593, 1.593, false, "prairie" },
	{ "Volcan_Touffe", -98.408, 0, -52.522, 308.22, 1.364, 1.364, 1.364, false, "prairie" },
	{ "Volcan_Touffe", 126.338, 0, 25.394, 158.57, 1.558, 1.558, 1.558, false, "prairie" },
	{ "Volcan_Touffe", -65.62, 0, 51.971, 322.9, 1.391, 1.391, 1.391, false, "prairie" },
	{ "Volcan_Touffe", -28.132, 0, 125.14, 56.9, 0.938, 0.938, 0.938, false, "prairie" },
	{ "Volcan_Touffe", 150.187, 0, 50.891, 10.98, 1.577, 1.577, 1.577, false, "prairie" },
	{ "Volcan_Touffe", -91.181, 0, 122.548, 284.2, 1.03, 1.03, 1.03, false, "prairie" },
	{ "Volcan_Touffe", -149.176, 0, 19.815, 302.57, 1.191, 1.191, 1.191, false, "prairie" },
	{ "Volcan_Touffe", -146.524, 0, 57.637, 164.17, 1.287, 1.287, 1.287, false, "prairie" },
	{ "Volcan_Touffe", -128.579, 0, 85.084, 241.21, 1.061, 1.061, 1.061, false, "prairie" },
	{ "Volcan_Touffe", -101.919, 0, -25.495, 297.34, 1.22, 1.22, 1.22, false, "prairie" },
	{ "Volcan_Touffe", -82.735, 0, 15.95, 99.4, 0.83, 0.83, 0.83, false, "prairie" },
	{ "Volcan_Touffe", -69.094, 0, 43.975, 332.12, 1.252, 1.252, 1.252, false, "prairie" },
	{ "Volcan_Touffe", -101.925, 0, 51.915, 172.31, 0.818, 0.818, 0.818, false, "prairie" },
	{ "Volcan_Touffe", 70.02, 0, 52.11, 37.86, 0.873, 0.873, 0.873, false, "prairie" },
	{ "Volcan_Touffe", -95.101, 0, 21.112, 349.87, 1.399, 1.399, 1.399, false, "prairie" },
	{ "Volcan_Touffe", 114.135, 0, -54.697, 43.08, 1.571, 1.571, 1.571, false, "prairie" },
	{ "Volcan_Touffe", 112.727, 0, 76.525, 110.53, 1.177, 1.177, 1.177, false, "prairie" },
	{ "Volcan_Touffe", -66.361, 0, -135.991, 248.56, 1.12, 1.12, 1.12, false, "prairie" },
	{ "Volcan_Touffe", -102.187, 0, -57.129, 214.45, 1.151, 1.151, 1.151, false, "prairie" },
	{ "Volcan_Touffe", 14.771, 0, 124.55, 212.6, 1.186, 1.186, 1.186, false, "prairie" },
	{ "Volcan_Touffe", -85.72, 0, -18.923, 86.77, 1.217, 1.217, 1.217, false, "prairie" },
	{ "Volcan_Touffe", -12.184, 0, -111.6, 264.69, 0.821, 0.821, 0.821, false, "prairie" },
	{ "Volcan_Touffe", -95.835, 0, 71.687, 343.14, 0.898, 0.898, 0.898, false, "prairie" },
	{ "Volcan_Touffe", 80.191, 0, -41.484, 145.94, 0.889, 0.889, 0.889, false, "prairie" },
	{ "Volcan_Touffe", 125.353, 0, -98.067, 144.33, 0.805, 0.805, 0.805, false, "prairie" },
	{ "Volcan_Touffe", 32.264, 0, -92.606, 288.14, 1.22, 1.22, 1.22, false, "prairie" },
	{ "Volcan_Touffe", 70.766, 0, 43.568, 60.35, 1.529, 1.529, 1.529, false, "prairie" },
	{ "Volcan_Touffe", 28.807, 0, -143.886, 289.11, 1.25, 1.25, 1.25, false, "prairie" },
	{ "Volcan_Touffe", 98.566, 0, 72.19, 12.81, 1.568, 1.568, 1.568, false, "prairie" },
	{ "Volcan_Rempart", 173.0, 0, -36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 173.0, 0, -24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 173.0, 0, -12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 173.0, 0, 12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 173.0, 0, 24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 173.0, 0, 36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 257.0, 0, -36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 257.0, 0, -24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 257.0, 0, -12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 257.0, 0, -0.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 257.0, 0, 12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 257.0, 0, 24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 257.0, 0, 36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 179.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 191.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 203.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 215.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 227.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 239.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 251.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 179.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 191.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 203.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 215.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 227.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 239.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 251.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Escalier", 170.4, 0, 0.0, 270.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Volcan_PorteForge", 173.4, 0, 0.0, 270.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Volcan_Chariot", 183.0, 1.0, -32.0, 277.66, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", 179.0, 1.0, -36.0, 249.79, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", 233.0, 1.0, -37.0, 302.72, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", 228.0, 1.0, -36.5, 270.31, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Chariot", 183.0, 1.0, 32.0, 276.94, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", 179.0, 1.0, 36.0, 344.51, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", 233.0, 1.0, 37.0, 324.76, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", 228.0, 1.0, 36.5, 279.35, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Rempart", 147.785, 0, 96.874, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 139.3, 0, 105.359, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 130.815, 0, 113.844, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 113.844, 0, 130.815, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 105.359, 0, 139.3, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 96.874, 0, 147.785, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 207.182, 0, 156.271, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 198.697, 0, 164.756, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 190.212, 0, 173.241, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 181.726, 0, 181.726, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 173.241, 0, 190.212, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 164.756, 0, 198.697, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 156.271, 0, 207.182, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 156.271, 0, 96.874, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 164.756, 0, 105.359, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 173.241, 0, 113.844, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 181.726, 0, 122.329, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 190.212, 0, 130.815, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 198.697, 0, 139.3, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 207.182, 0, 147.785, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 96.874, 0, 156.271, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 105.359, 0, 164.756, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 113.844, 0, 173.241, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 122.329, 0, 181.726, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 130.815, 0, 190.212, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 139.3, 0, 198.697, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 147.785, 0, 207.182, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Escalier", 120.491, 0, 120.491, 225.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Volcan_PorteForge", 122.612, 0, 122.612, 225.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Volcan_Chariot", 152.028, 1.0, 106.773, 227.41, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", 152.028, 1.0, 101.116, 349.57, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", 190.919, 1.0, 138.593, 16.93, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", 187.03, 1.0, 135.411, 216.82, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Chariot", 106.773, 1.0, 152.028, 227.43, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", 101.116, 1.0, 152.028, 100.48, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", 138.593, 1.0, 190.919, 2.63, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", 135.411, 1.0, 187.03, 227.35, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Rempart", 36.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 24.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 12.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -12.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -24.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -36.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 36.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 24.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 12.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 0.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -12.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -24.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -36.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, 179.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, 191.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, 203.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, 215.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, 227.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, 239.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, 251.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, 179.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, 191.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, 203.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, 215.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, 227.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, 239.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, 251.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Escalier", 0.0, 0, 170.4, 180.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Volcan_PorteForge", 0.0, 0, 173.4, 180.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Volcan_Chariot", 32.0, 1.0, 183.0, 172.7, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", 36.0, 1.0, 179.0, 332.93, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", 37.0, 1.0, 233.0, 25.67, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", 36.5, 1.0, 228.0, 184.01, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Chariot", -32.0, 1.0, 183.0, 180.74, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", -36.0, 1.0, 179.0, 197.08, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", -37.0, 1.0, 233.0, 186.01, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", -36.5, 1.0, 228.0, 180.8, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Rempart", -96.874, 0, 147.785, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -105.359, 0, 139.3, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -113.844, 0, 130.815, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -130.815, 0, 113.844, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -139.3, 0, 105.359, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -147.785, 0, 96.874, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -156.271, 0, 207.182, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -164.756, 0, 198.697, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -173.241, 0, 190.212, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -181.726, 0, 181.726, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -190.212, 0, 173.241, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -198.697, 0, 164.756, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -207.182, 0, 156.271, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -96.874, 0, 156.271, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -105.359, 0, 164.756, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -113.844, 0, 173.241, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -122.329, 0, 181.726, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -130.815, 0, 190.212, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -139.3, 0, 198.697, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -147.785, 0, 207.182, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -156.271, 0, 96.874, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -164.756, 0, 105.359, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -173.241, 0, 113.844, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -181.726, 0, 122.329, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -190.212, 0, 130.815, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -198.697, 0, 139.3, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -207.182, 0, 147.785, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Escalier", -120.491, 0, 120.491, 135.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Volcan_PorteForge", -122.612, 0, 122.612, 135.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Volcan_Chariot", -106.773, 1.0, 152.028, 134.92, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", -101.116, 1.0, 152.028, 19.16, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", -138.593, 1.0, 190.919, 126.72, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", -135.411, 1.0, 187.03, 135.74, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Chariot", -152.028, 1.0, 106.773, 134.42, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", -152.028, 1.0, 101.116, 87.22, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", -190.919, 1.0, 138.593, 5.45, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", -187.03, 1.0, 135.411, 132.72, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Rempart", -173.0, 0, 36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -173.0, 0, 24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -173.0, 0, 12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -173.0, 0, -12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -173.0, 0, -24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -173.0, 0, -36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -257.0, 0, 36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -257.0, 0, 24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -257.0, 0, 12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -257.0, 0, 0.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -257.0, 0, -12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -257.0, 0, -24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -257.0, 0, -36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -179.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -191.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -203.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -215.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -227.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -239.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -251.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -179.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -191.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -203.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -215.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -227.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -239.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -251.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Escalier", -170.4, 0, 0.0, 90.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Volcan_PorteForge", -173.4, 0, 0.0, 90.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Volcan_Chariot", -183.0, 1.0, 32.0, 83.43, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", -179.0, 1.0, 36.0, 242.95, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", -233.0, 1.0, 37.0, 64.25, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", -228.0, 1.0, 36.5, 84.74, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Chariot", -183.0, 1.0, -32.0, 90.95, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", -179.0, 1.0, -36.0, 181.75, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", -233.0, 1.0, -37.0, 121.35, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", -228.0, 1.0, -36.5, 85.58, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Rempart", -147.785, 0, -96.874, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -139.3, 0, -105.359, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -130.815, 0, -113.844, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -113.844, 0, -130.815, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -105.359, 0, -139.3, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -96.874, 0, -147.785, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -207.182, 0, -156.271, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -198.697, 0, -164.756, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -190.212, 0, -173.241, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -181.726, 0, -181.726, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -173.241, 0, -190.212, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -164.756, 0, -198.697, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -156.271, 0, -207.182, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -156.271, 0, -96.874, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -164.756, 0, -105.359, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -173.241, 0, -113.844, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -181.726, 0, -122.329, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -190.212, 0, -130.815, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -198.697, 0, -139.3, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -207.182, 0, -147.785, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -96.874, 0, -156.271, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -105.359, 0, -164.756, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -113.844, 0, -173.241, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -122.329, 0, -181.726, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -130.815, 0, -190.212, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -139.3, 0, -198.697, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -147.785, 0, -207.182, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Escalier", -120.491, 0, -120.491, 45.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Volcan_PorteForge", -122.612, 0, -122.612, 45.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Volcan_Chariot", -152.028, 1.0, -106.773, 47.34, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", -152.028, 1.0, -101.116, 60.81, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", -190.919, 1.0, -138.593, 33.27, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", -187.03, 1.0, -135.411, 41.89, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Chariot", -106.773, 1.0, -152.028, 48.97, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", -101.116, 1.0, -152.028, 46.9, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", -138.593, 1.0, -190.919, 338.5, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", -135.411, 1.0, -187.03, 52.25, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Rempart", -36.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -24.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -12.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 12.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 24.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 36.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -36.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -24.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -12.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -0.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 12.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 24.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 36.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, -179.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, -191.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, -203.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, -215.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, -227.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, -239.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", -42.0, 0, -251.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, -179.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, -191.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, -203.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, -215.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, -227.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, -239.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 42.0, 0, -251.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Escalier", -0.0, 0, -170.4, 0.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Volcan_PorteForge", -0.0, 0, -173.4, 0.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Volcan_Chariot", -32.0, 1.0, -183.0, 4.46, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", -36.0, 1.0, -179.0, 296.2, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", -37.0, 1.0, -233.0, 170.77, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", -36.5, 1.0, -228.0, 3.87, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Chariot", 32.0, 1.0, -183.0, 2.99, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", 36.0, 1.0, -179.0, 116.06, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", 37.0, 1.0, -233.0, 178.19, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", 36.5, 1.0, -228.0, 352.31, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Rempart", 96.874, 0, -147.785, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 105.359, 0, -139.3, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 113.844, 0, -130.815, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 130.815, 0, -113.844, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 139.3, 0, -105.359, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 147.785, 0, -96.874, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 156.271, 0, -207.182, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 164.756, 0, -198.697, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 173.241, 0, -190.212, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 181.726, 0, -181.726, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 190.212, 0, -173.241, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 198.697, 0, -164.756, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 207.182, 0, -156.271, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 96.874, 0, -156.271, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 105.359, 0, -164.756, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 113.844, 0, -173.241, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 122.329, 0, -181.726, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 130.815, 0, -190.212, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 139.3, 0, -198.697, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 147.785, 0, -207.182, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 156.271, 0, -96.874, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 164.756, 0, -105.359, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 173.241, 0, -113.844, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 181.726, 0, -122.329, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 190.212, 0, -130.815, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 198.697, 0, -139.3, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Rempart", 207.182, 0, -147.785, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Volcan_Escalier", 120.491, 0, -120.491, 315.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Volcan_PorteForge", 122.612, 0, -122.612, 315.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Volcan_Chariot", 106.773, 1.0, -152.028, 307.02, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", 101.116, 1.0, -152.028, 136.64, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", 138.593, 1.0, -190.919, 347.69, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", 135.411, 1.0, -187.03, 314.96, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Chariot", 152.028, 1.0, -106.773, 313.7, 1.0, 1.0, 1.0, false, "base" },
	{ "Volcan_Chaudron", 152.028, 1.0, -101.116, 204.03, 0.9, 0.9, 0.9, false, "base" },
	{ "Volcan_Chaudron", 190.919, 1.0, -138.593, 184.43, 0.85, 0.85, 0.85, false, "base" },
	{ "Volcan_Chariot", 187.03, 1.0, -135.411, 312.12, 0.8, 0.8, 0.8, false, "base" },
	{ "Volcan_Orgues", 258.942, -0.5, 149.5, 242.91, 0.7, 0.95, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 262.535, 28.811, 148.248, 41.61, 1.251, 1.251, 1.251, true, "colline" },
	{ "Volcan_ArbreCalcine", 267.822, 28.811, 138.469, 110.48, 1.113, 1.113, 1.113, true, "colline" },
	{ "Volcan_Orgues", 279.935, -0.5, 115.953, 253.17, 0.75, 1.0, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 280.279, 30.38, 121.547, 212.37, 0.997, 0.997, 0.997, true, "colline" },
	{ "Volcan_ArbreCalcine", 281.895, 30.38, 117.753, 40.73, 0.951, 0.951, 0.951, true, "colline" },
	{ "Volcan_Orgues", 288.812, -0.5, 77.387, 256.36, 0.7, 0.9, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 289.626, 27.242, 83.78, 7.3, 1.143, 1.143, 1.143, true, "colline" },
	{ "Volcan_ArbreCalcine", 294.568, 27.242, 64.278, 159.87, 0.949, 0.949, 0.949, true, "colline" },
	{ "Volcan_Orgues", 251.477, -0.5, 125.382, 240.23, 0.6, 0.5, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", 251.35, 14.69, 131.131, 343.18, 1.076, 1.076, 1.076, true, "colline" },
	{ "Volcan_Orgues", 266.479, -0.5, 89.163, 250.83, 0.6, 0.45, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", 272.71, 13.121, 77.471, 266.27, 1.064, 1.064, 1.064, true, "colline" },
	{ "Volcan_ArbreCalcine", 240.593, 0, 53.742, 220.47, 0.811, 0.811, 0.811, true, "colline" },
	{ "Volcan_Eclats", 238.204, 0, 55.978, 80.95, 1.042, 1.042, 1.042, true, "colline" },
	{ "Volcan_Cheminee", 216.423, 0, 119.369, 216.56, 1.026, 1.026, 1.026, true, "colline" },
	{ "Volcan_Eclats", 229.572, -0.4, 84.337, 328.31, 1.069, 1.069, 1.069, true, "colline" },
	{ "Volcan_Eclats", 216.856, -0.4, 111.578, 87.32, 1.054, 1.054, 1.054, true, "colline" },
	{ "Volcan_Roche", 215.623, -0.4, 78.805, 108.11, 1.224, 1.224, 1.224, true, "colline" },
	{ "Volcan_Cheminee", 199.898, 0, 117.749, 244.19, 1.0, 1.0, 1.0, true, "colline" },
	{ "Volcan_TeteGolem", 233.852, 0, 101.676, 178.88, 0.918, 0.918, 0.918, true, "colline" },
	{ "Volcan_Orgues", 77.387, -0.5, 288.812, 192.69, 0.7, 0.95, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 63.802, 28.811, 294.672, 202.24, 1.235, 1.235, 1.235, true, "colline" },
	{ "Volcan_ArbreCalcine", 69.642, 28.811, 293.347, 288.38, 1.232, 1.232, 1.232, true, "colline" },
	{ "Volcan_Orgues", 115.953, -0.5, 279.935, 203.87, 0.75, 1.0, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 112.467, 30.38, 284.045, 189.27, 0.905, 0.905, 0.905, true, "colline" },
	{ "Volcan_ArbreCalcine", 117.668, 30.38, 281.93, 307.49, 1.22, 1.22, 1.22, true, "colline" },
	{ "Volcan_Orgues", 149.5, -0.5, 258.942, 210.71, 0.7, 0.9, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 147.399, 27.242, 263.013, 38.52, 0.986, 0.986, 0.986, true, "colline" },
	{ "Volcan_ArbreCalcine", 150.491, 27.242, 261.256, 156.76, 0.976, 0.976, 0.976, true, "colline" },
	{ "Volcan_Orgues", 89.163, -0.5, 266.479, 192.87, 0.6, 0.5, 0.6, true, "colline" },
	{ "Volcan_Cristaux", 78.179, 14.69, 272.507, 78.25, 0.949, 0.949, 0.949, true, "colline" },
	{ "Volcan_Orgues", 125.382, -0.5, 251.477, 207.72, 0.6, 0.45, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", 130.095, 13.121, 251.888, 149.89, 1.028, 1.028, 1.028, true, "colline" },
	{ "Volcan_Cristaux", 54.7, 0, 253.92, 237.2, 0.961, 0.961, 0.961, true, "colline" },
	{ "Volcan_Cheminee", 54.084, 0, 243.163, 314.7, 0.994, 0.994, 0.994, true, "colline" },
	{ "Volcan_Cristaux", 72.256, 0, 240.047, 85.21, 0.955, 0.955, 0.955, true, "colline" },
	{ "Volcan_Roche", 137.254, -0.4, 230.093, 286.44, 1.012, 1.012, 1.012, true, "colline" },
	{ "Volcan_Roche", 66.248, -0.4, 259.46, 166.96, 1.238, 1.238, 1.238, true, "colline" },
	{ "Volcan_Eclats", 88.102, -0.4, 213.143, 171.21, 1.174, 1.174, 1.174, true, "colline" },
	{ "Volcan_Cheminee", 58.088, 0, 224.61, 196.96, 1.0, 1.0, 1.0, true, "colline" },
	{ "Volcan_Grill", 95.216, 0, 236.556, 24.73, 1.114, 1.114, 1.114, true, "colline" },
	{ "Volcan_Orgues", -149.5, -0.5, 258.942, 150.29, 0.7, 0.95, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -152.807, 28.811, 259.908, 3.95, 0.957, 0.957, 0.957, true, "colline" },
	{ "Volcan_ArbreCalcine", -147.832, 28.811, 262.77, 282.92, 1.178, 1.178, 1.178, true, "colline" },
	{ "Volcan_Orgues", -115.953, -0.5, 279.935, 155.88, 0.75, 1.0, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -109.409, 30.38, 285.237, 208.03, 1.147, 1.147, 1.147, true, "colline" },
	{ "Volcan_ArbreCalcine", -122.233, 30.38, 279.981, 84.22, 1.23, 1.23, 1.23, true, "colline" },
	{ "Volcan_Orgues", -77.387, -0.5, 288.812, 165.29, 0.7, 0.9, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -77.193, 27.242, 291.451, 189.84, 1.016, 1.016, 1.016, true, "colline" },
	{ "Volcan_ArbreCalcine", -70.738, 27.242, 293.084, 254.78, 1.209, 1.209, 1.209, true, "colline" },
	{ "Volcan_Orgues", -125.382, -0.5, 251.477, 154.59, 0.6, 0.5, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", -135.371, 14.69, 249.092, 342.96, 1.025, 1.025, 1.025, true, "colline" },
	{ "Volcan_Orgues", -89.163, -0.5, 266.479, 165.97, 0.6, 0.45, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", -97.052, 13.121, 266.37, 250.98, 1.191, 1.191, 1.191, true, "colline" },
	{ "Volcan_Eclats", -136.304, 0, 222.723, 232.9, 1.014, 1.014, 1.014, true, "colline" },
	{ "Volcan_Eclats", -139.318, 0, 211.655, 272.04, 0.959, 0.959, 0.959, true, "colline" },
	{ "Volcan_Cristaux", -65.423, 0, 238.321, 139.08, 0.923, 0.923, 0.923, true, "colline" },
	{ "Volcan_Eclats", -92.839, -0.4, 219.739, 148.81, 0.822, 0.822, 0.822, true, "colline" },
	{ "Volcan_Roche", -71.97, -0.4, 217.367, 351.23, 1.197, 1.197, 1.197, true, "colline" },
	{ "Volcan_Eclats", -101.659, -0.4, 209.518, 138.22, 1.257, 1.257, 1.257, true, "colline" },
	{ "Volcan_Cheminee", -58.088, 0, 224.61, 127.63, 1.0, 1.0, 1.0, true, "colline" },
	{ "Volcan_Cheminee", -106.773, 0, 231.57, 28.05, 0.953, 0.953, 0.953, true, "colline" },
	{ "Volcan_Orgues", -288.812, -0.5, 77.387, 107.5, 0.7, 0.95, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -287.37, 28.811, 91.219, 37.13, 1.145, 1.145, 1.145, true, "colline" },
	{ "Volcan_ArbreCalcine", -291.094, 28.811, 78.527, 45.7, 1.25, 1.25, 1.25, true, "colline" },
	{ "Volcan_Orgues", -279.935, -0.5, 115.953, 109.25, 0.75, 1.0, 0.75, true, "colline" },
	{ "Volcan_Cristaux", -279.802, 30.38, 122.641, 37.76, 1.217, 1.217, 1.217, true, "colline" },
	{ "Volcan_ArbreCalcine", -275.755, 30.38, 131.488, 13.25, 1.076, 1.076, 1.076, true, "colline" },
	{ "Volcan_Orgues", -258.942, -0.5, 149.5, 124.01, 0.7, 0.9, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -257.306, 27.242, 157.15, 147.22, 1.048, 1.048, 1.048, true, "colline" },
	{ "Volcan_ArbreCalcine", -258.277, 27.242, 155.548, 335.08, 1.066, 1.066, 1.066, true, "colline" },
	{ "Volcan_Orgues", -266.479, -0.5, 89.163, 104.29, 0.6, 0.5, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", -267.506, 14.69, 93.876, 218.37, 1.186, 1.186, 1.186, true, "colline" },
	{ "Volcan_Orgues", -251.477, -0.5, 125.382, 111.32, 0.6, 0.45, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", -247.246, 13.121, 138.714, 158.79, 1.154, 1.154, 1.154, true, "colline" },
	{ "Volcan_ArbreCalcine", -217.762, 0, 136.971, 286.65, 0.95, 0.95, 0.95, true, "colline" },
	{ "Volcan_Cheminee", -211.592, 0, 125.35, 74.0, 0.856, 0.856, 0.856, true, "colline" },
	{ "Volcan_ArbreCalcine", -228.132, 0, 119.702, 69.6, 0.935, 0.935, 0.935, true, "colline" },
	{ "Volcan_Roche", -206.508, -0.4, 128.256, 132.14, 1.135, 1.135, 1.135, true, "colline" },
	{ "Volcan_Eclats", -229.291, -0.4, 69.564, 92.21, 0.952, 0.952, 0.952, true, "colline" },
	{ "Volcan_Roche", -220.104, -0.4, 121.919, 248.29, 1.032, 1.032, 1.032, true, "colline" },
	{ "Volcan_Cheminee", -199.898, 0, 117.749, 129.69, 1.0, 1.0, 1.0, true, "colline" },
	{ "Volcan_Eclats", -230.245, 0, 109.601, 61.49, 0.958, 0.958, 0.958, true, "colline" },
	{ "Volcan_Orgues", -258.942, -0.5, -149.5, 57.02, 0.7, 0.95, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -254.897, 28.811, -161.027, 130.73, 0.975, 0.975, 0.975, true, "colline" },
	{ "Volcan_ArbreCalcine", -255.876, 28.811, -159.468, 327.41, 1.138, 1.138, 1.138, true, "colline" },
	{ "Volcan_Orgues", -279.935, -0.5, -115.953, 68.98, 0.75, 1.0, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -279.567, 30.38, -123.176, 356.07, 1.038, 1.038, 1.038, true, "colline" },
	{ "Volcan_ArbreCalcine", -287.282, 30.38, -103.92, 228.65, 0.914, 0.914, 0.914, true, "colline" },
	{ "Volcan_Orgues", -288.812, -0.5, -77.387, 72.66, 0.7, 0.9, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -289.247, 27.242, -85.078, 74.82, 0.949, 0.949, 0.949, true, "colline" },
	{ "Volcan_ArbreCalcine", -294.697, 27.242, -63.685, 172.36, 1.014, 1.014, 1.014, true, "colline" },
	{ "Volcan_Orgues", -251.477, -0.5, -125.382, 59.07, 0.6, 0.5, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", -259.292, 14.69, -114.63, 333.35, 1.016, 1.016, 1.016, true, "colline" },
	{ "Volcan_Orgues", -266.479, -0.5, -89.163, 70.72, 0.6, 0.45, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", -272.183, 13.121, -79.299, 10.82, 1.026, 1.026, 1.026, true, "colline" },
	{ "Volcan_Eclats", -230.173, 0, -70.096, 352.33, 1.093, 1.093, 1.093, true, "colline" },
	{ "Volcan_Eclats", -225.682, 0, -118.769, 337.14, 0.971, 0.971, 0.971, true, "colline" },
	{ "Volcan_Cheminee", -243.751, 0, -52.955, 194.99, 0.889, 0.889, 0.889, true, "colline" },
	{ "Volcan_Eclats", -229.608, -0.4, -110.069, 193.43, 1.182, 1.182, 1.182, true, "colline" },
	{ "Volcan_Roche", -246.325, -0.4, -64.904, 156.02, 1.267, 1.267, 1.267, true, "colline" },
	{ "Volcan_Eclats", -215.574, -0.4, -80.737, 52.46, 1.13, 1.13, 1.13, true, "colline" },
	{ "Volcan_Cheminee", -224.61, 0, -58.088, 44.72, 1.0, 1.0, 1.0, true, "colline" },
	{ "Volcan_TeteGolem", -240.85, 0, -83.764, 310.36, 1.187, 1.187, 1.187, true, "colline" },
	{ "Volcan_Orgues", -77.387, -0.5, -288.812, 12.17, 0.7, 0.95, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -70.167, 28.811, -293.221, 100.17, 0.985, 0.985, 0.985, true, "colline" },
	{ "Volcan_Cristaux", -91.819, 28.811, -287.179, 13.82, 1.288, 1.288, 1.288, true, "colline" },
	{ "Volcan_Orgues", -115.953, -0.5, -279.935, 22.2, 0.75, 1.0, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -107.168, 30.38, -286.086, 293.23, 1.18, 1.18, 1.18, true, "colline" },
	{ "Volcan_ArbreCalcine", -111.02, 30.38, -284.614, 103.01, 1.228, 1.228, 1.228, true, "colline" },
	{ "Volcan_Orgues", -149.5, -0.5, -258.942, 30.67, 0.7, 0.9, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", -142.5, 27.242, -265.699, 314.69, 1.143, 1.143, 1.143, true, "colline" },
	{ "Volcan_ArbreCalcine", -157.222, 27.242, -257.261, 94.25, 1.027, 1.027, 1.027, true, "colline" },
	{ "Volcan_Orgues", -89.163, -0.5, -266.479, 21.07, 0.6, 0.5, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", -96.448, 14.69, -266.59, 197.97, 1.242, 1.242, 1.242, true, "colline" },
	{ "Volcan_Orgues", -125.382, -0.5, -251.477, 29.38, 0.6, 0.45, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", -118.105, 13.121, -257.728, 259.84, 0.99, 0.99, 0.99, true, "colline" },
	{ "Volcan_Eclats", -124.51, 0, -213.082, 15.45, 0.896, 0.896, 0.896, true, "colline" },
	{ "Volcan_ArbreCalcine", -137.087, 0, -222.271, 99.32, 1.111, 1.111, 1.111, true, "colline" },
	{ "Volcan_Eclats", -56.01, 0, -243.867, 268.11, 0.947, 0.947, 0.947, true, "colline" },
	{ "Volcan_Roche", -102.945, -0.4, -209.053, 254.05, 1.061, 1.061, 1.061, true, "colline" },
	{ "Volcan_Roche", -121.861, -0.4, -199.108, 329.03, 1.275, 1.275, 1.275, true, "colline" },
	{ "Volcan_Roche", -104.712, -0.4, -214.997, 244.63, 1.255, 1.255, 1.255, true, "colline" },
	{ "Volcan_Cheminee", -117.749, 0, -199.898, 39.07, 1.0, 1.0, 1.0, true, "colline" },
	{ "Volcan_Grill", -90.251, 0, -238.495, 354.21, 1.125, 1.125, 1.125, true, "colline" },
	{ "Volcan_Orgues", 149.5, -0.5, -258.942, 335.94, 0.7, 0.95, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 162.235, 28.811, -254.13, 289.43, 1.059, 1.059, 1.059, true, "colline" },
	{ "Volcan_ArbreCalcine", 159.431, 28.811, -255.899, 145.39, 1.123, 1.123, 1.123, true, "colline" },
	{ "Volcan_Orgues", 115.953, -0.5, -279.935, 331.59, 0.75, 1.0, 0.75, true, "colline" },
	{ "Volcan_Cristaux", 115.16, 30.38, -282.964, 318.2, 1.292, 1.292, 1.292, true, "colline" },
	{ "Volcan_ArbreCalcine", 130.28, 30.38, -276.328, 6.71, 1.096, 1.096, 1.096, true, "colline" },
	{ "Volcan_Orgues", 77.387, -0.5, -288.812, 348.23, 0.7, 0.9, 0.75, true, "colline" },
	{ "Volcan_Cristaux", 75.183, 27.242, -291.976, 276.42, 0.98, 0.98, 0.98, true, "colline" },
	{ "Volcan_Cristaux", 68.738, 27.242, -293.56, 72.29, 0.988, 0.988, 0.988, true, "colline" },
	{ "Volcan_Orgues", 125.382, -0.5, -251.477, 331.98, 0.6, 0.5, 0.6, true, "colline" },
	{ "Volcan_Cristaux", 138.752, 14.69, -247.225, 189.09, 1.101, 1.101, 1.101, true, "colline" },
	{ "Volcan_Orgues", 89.163, -0.5, -266.479, 340.89, 0.6, 0.45, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", 89.137, 13.121, -269.122, 347.9, 1.06, 1.06, 1.06, true, "colline" },
	{ "Volcan_Cheminee", 118.412, 0, -210.716, 127.97, 0.828, 0.828, 0.828, true, "colline" },
	{ "Volcan_ArbreCalcine", 124.141, 0, -210.16, 17.92, 0.907, 0.907, 0.907, true, "colline" },
	{ "Volcan_Cristaux", 138.998, 0, -212.422, 60.0, 0.869, 0.869, 0.869, true, "colline" },
	{ "Volcan_Eclats", 126.168, -0.4, -211.892, 177.32, 0.969, 0.969, 0.969, true, "colline" },
	{ "Volcan_Roche", 67.792, -0.4, -233.104, 329.07, 0.841, 0.841, 0.841, true, "colline" },
	{ "Volcan_Roche", 110.334, -0.4, -246.349, 184.03, 0.847, 0.847, 0.847, true, "colline" },
	{ "Volcan_Cheminee", 117.749, 0, -199.898, 354.07, 1.0, 1.0, 1.0, true, "colline" },
	{ "Volcan_Cheminee", 85.548, 0, -240.222, 161.73, 0.906, 0.906, 0.906, true, "colline" },
	{ "Volcan_Orgues", 288.812, -0.5, -77.387, 283.07, 0.7, 0.95, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 291.236, 28.811, -78.0, 73.36, 1.239, 1.239, 1.239, true, "colline" },
	{ "Volcan_ArbreCalcine", 294.461, 28.811, -64.77, 70.79, 0.925, 0.925, 0.925, true, "colline" },
	{ "Volcan_Orgues", 279.935, -0.5, -115.953, 288.05, 0.75, 1.0, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 282.408, 30.38, -116.516, 44.28, 1.123, 1.123, 1.123, true, "colline" },
	{ "Volcan_ArbreCalcine", 286.673, 30.38, -105.587, 329.4, 1.294, 1.294, 1.294, true, "colline" },
	{ "Volcan_Orgues", 258.942, -0.5, -149.5, 305.1, 0.7, 0.9, 0.75, true, "colline" },
	{ "Volcan_ArbreCalcine", 258.46, 27.242, -155.244, 113.05, 1.118, 1.118, 1.118, true, "colline" },
	{ "Volcan_ArbreCalcine", 263.992, 27.242, -145.638, 293.68, 0.939, 0.939, 0.939, true, "colline" },
	{ "Volcan_Orgues", 266.479, -0.5, -89.163, 288.48, 0.6, 0.5, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", 266.032, 14.69, -97.975, 209.44, 0.978, 0.978, 0.978, true, "colline" },
	{ "Volcan_Orgues", 251.477, -0.5, -125.382, 297.09, 0.6, 0.45, 0.6, true, "colline" },
	{ "Volcan_ArbreCalcine", 258.896, 13.121, -115.52, 321.9, 1.257, 1.257, 1.257, true, "colline" },
	{ "Volcan_Cheminee", 252.577, 0, -68.83, 293.17, 1.062, 1.062, 1.062, true, "colline" },
	{ "Volcan_Cheminee", 241.128, 0, -61.904, 206.12, 1.148, 1.148, 1.148, true, "colline" },
	{ "Volcan_Cheminee", 247.029, 0, -77.466, 253.5, 0.909, 0.909, 0.909, true, "colline" },
	{ "Volcan_Eclats", 247.953, -0.4, -57.428, 48.97, 0.882, 0.882, 0.882, true, "colline" },
	{ "Volcan_Roche", 220.353, -0.4, -88.32, 282.32, 1.141, 1.141, 1.141, true, "colline" },
	{ "Volcan_Roche", 226.399, -0.4, -112.802, 137.56, 1.239, 1.239, 1.239, true, "colline" },
	{ "Volcan_Cheminee", 224.61, 0, -58.088, 295.05, 1.0, 1.0, 1.0, true, "colline" },
	{ "Volcan_Eclats", 235.303, 0, -98.272, 241.43, 1.035, 1.035, 1.035, true, "colline" },
	{ "Volcan_Cheminee", 267.742, -0.3, -103.124, 112.61, 0.839, 0.839, 0.839, true, "colline" },
	{ "Volcan_Roche", 259.339, -0.3, -114.567, 295.38, 0.77, 0.77, 0.77, true, "colline" },
	{ "Volcan_Cristaux", 241.661, -0.3, -113.832, 51.55, 0.96, 0.96, 0.96, false, "colline" },
	{ "Volcan_Cheminee", 234.813, -0.3, -104.646, 131.21, 0.923, 0.923, 0.923, true, "colline" },
	{ "Volcan_Roche", 244.389, -0.3, -93.192, 70.05, 0.894, 0.894, 0.894, true, "colline" },
	{ "Volcan_Cristaux", 259.693, -0.3, -93.76, 296.74, 0.742, 0.742, 0.742, false, "colline" },
	{ "Volcan_Orgues", 344.559, -1, 0.775, 266.21, 1.6, 2.35, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 352.026, 70.745, -2.999, 33.77, 1.67, 1.67, 1.67, false, "peripherie" },
	{ "Volcan_Cheminee", 349.709, 70.745, 19.569, 59.92, 1.449, 1.449, 1.449, false, "peripherie" },
	{ "Volcan_Eclats", 341.198, -1, -51.713, 279.63, 3.6, 4.612, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 325.584, -1, -101.642, 285.29, 1.6, 1.989, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 333.482, 59.4, -96.047, 72.49, 1.96, 1.96, 1.96, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 336.26, 59.4, -85.108, 156.91, 1.914, 1.914, 1.914, false, "peripherie" },
	{ "Volcan_Orgues", 306.492, -1, -162.122, 302.06, 1.6, 2.407, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 321.678, 72.539, -149.218, 274.48, 1.902, 1.902, 1.902, false, "peripherie" },
	{ "Volcan_Cheminee", 308.331, 72.539, -169.41, 121.96, 1.557, 1.557, 1.557, false, "peripherie" },
	{ "Volcan_Eclats", 276.518, -1, -203.704, 306.83, 3.6, 4.369, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 236.911, -1, -246.094, 314.96, 1.6, 2.052, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 226.734, 61.404, -260.981, 63.7, 1.301, 1.301, 1.301, false, "peripherie" },
	{ "Volcan_Cheminee", 229.377, 61.404, -259.126, 352.01, 1.382, 1.382, 1.382, false, "peripherie" },
	{ "Volcan_Orgues", 207.9, -1, -276.793, 320.6, 1.6, 2.321, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 210.256, 69.827, -280.659, 204.26, 1.903, 1.903, 1.903, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 220.322, 69.827, -272.939, 297.41, 1.562, 1.562, 1.562, false, "peripherie" },
	{ "Volcan_Eclats", 162.044, -1, -298.799, 328.38, 3.6, 4.808, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 96.339, -1, -330.875, 347.63, 1.6, 2.462, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 110.563, 74.25, -334.305, 174.79, 1.332, 1.332, 1.332, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 104.253, 74.25, -336.441, 303.51, 1.664, 1.664, 1.664, false, "peripherie" },
	{ "Volcan_Orgues", 58.033, -1, -339.511, 352.86, 1.6, 2.079, 1.3, false, "peripherie" },
	{ "Volcan_Cheminee", 44.899, 62.244, -347.686, 253.9, 1.73, 1.73, 1.73, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 54.026, 62.244, -348.846, 263.5, 1.611, 1.611, 1.611, false, "peripherie" },
	{ "Volcan_Eclats", 2.356, -1, -341.199, 2.09, 3.6, 5.194, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -44.013, -1, -341.077, 2.87, 1.6, 2.174, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -24.399, 65.217, -348.833, 341.46, 1.308, 1.308, 1.308, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -37.899, 65.217, -347.895, 82.18, 1.656, 1.656, 1.656, false, "peripherie" },
	{ "Volcan_Orgues", -116.593, -1, -325.524, 18.59, 1.6, 2.321, 1.3, false, "peripherie" },
	{ "Volcan_Cheminee", -117.947, 69.837, -333.841, 272.44, 1.72, 1.72, 1.72, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -109.732, 69.837, -333.551, 290.4, 1.331, 1.331, 1.331, false, "peripherie" },
	{ "Volcan_Eclats", -149.107, -1, -306.037, 26.37, 3.6, 4.239, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -209.774, -1, -275.59, 36.17, 1.6, 2.479, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -196.835, 74.775, -293.955, 127.41, 1.586, 1.586, 1.586, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -197.672, 74.775, -291.033, 16.01, 1.962, 1.962, 1.962, false, "peripherie" },
	{ "Volcan_Orgues", -237.864, -1, -246.353, 39.33, 1.6, 2.464, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -254.413, 74.326, -239.781, 89.38, 1.938, 1.938, 1.938, false, "peripherie" },
	{ "Volcan_Cheminee", -243.098, 74.326, -251.911, 9.34, 1.698, 1.698, 1.698, false, "peripherie" },
	{ "Volcan_Eclats", -278.871, -1, -199.696, 49.69, 3.6, 4.737, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -310.607, -1, -151.302, 59.15, 1.6, 2.017, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -324.281, 60.293, -136.82, 345.31, 1.401, 1.401, 1.401, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -312.36, 60.293, -163.6, 185.93, 1.336, 1.336, 1.336, false, "peripherie" },
	{ "Volcan_Orgues", -328.916, -1, -109.943, 75.06, 1.6, 2.007, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -338.121, 59.989, -97.271, 153.0, 1.862, 1.862, 1.862, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -329.116, 59.989, -125.173, 251.63, 1.932, 1.932, 1.932, false, "peripherie" },
	{ "Volcan_Eclats", -335.88, -1, -54.457, 82.78, 3.6, 4.201, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -340.634, -1, 7.953, 96.29, 1.6, 2.596, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -345.897, 78.467, 14.097, 158.12, 1.749, 1.749, 1.749, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -348.951, 78.467, -10.483, 287.15, 1.452, 1.452, 1.452, false, "peripherie" },
	{ "Volcan_Orgues", -342.046, -1, 43.764, 97.39, 1.6, 2.394, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -352.361, 72.119, 30.153, 300.7, 1.454, 1.454, 1.454, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -345.237, 72.119, 55.788, 267.62, 1.642, 1.642, 1.642, false, "peripherie" },
	{ "Volcan_Eclats", -323.545, -1, 101.924, 103.76, 3.6, 5.147, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -303.707, -1, 161.462, 114.81, 1.6, 2.005, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -315.763, 59.904, 151.928, 178.51, 1.651, 1.651, 1.651, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -309.557, 59.904, 163.967, 117.45, 1.601, 1.601, 1.601, false, "peripherie" },
	{ "Volcan_Orgues", -274.582, -1, 208.321, 124.77, 1.6, 2.526, 1.3, false, "peripherie" },
	{ "Volcan_Cheminee", -268.229, 76.265, 222.629, 134.93, 1.965, 1.965, 1.965, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -290.496, 76.265, 195.322, 345.21, 1.887, 1.887, 1.887, false, "peripherie" },
	{ "Volcan_Eclats", -241.011, -1, 242.129, 130.59, 3.6, 4.867, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -201.323, -1, 275.41, 139.99, 1.6, 2.265, 1.3, false, "peripherie" },
	{ "Volcan_Cheminee", -217.359, 68.077, 269.88, 74.54, 1.467, 1.467, 1.467, false, "peripherie" },
	{ "Volcan_Cheminee", -210.432, 68.077, 278.681, 275.57, 1.32, 1.32, 1.32, false, "peripherie" },
	{ "Volcan_Orgues", -150.12, -1, 305.716, 156.14, 1.6, 2.225, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -158.339, 66.82, 306.359, 23.21, 1.992, 1.992, 1.992, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -166.398, 66.82, 302.05, 256.39, 1.962, 1.962, 1.962, false, "peripherie" },
	{ "Volcan_Eclats", -95.523, -1, 327.836, 159.77, 3.6, 3.89, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -57.072, -1, 338.122, 167.89, 1.6, 2.42, 1.3, false, "peripherie" },
	{ "Volcan_Cheminee", -73.644, 72.93, 342.258, 240.69, 1.546, 1.546, 1.546, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -47.828, 72.93, 346.491, 341.09, 1.889, 1.889, 1.889, false, "peripherie" },
	{ "Volcan_Orgues", 1.199, -1, 343.03, 182.58, 1.6, 2.478, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 5.635, 74.756, 348.361, 284.39, 1.425, 1.425, 1.425, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -10.293, 74.756, 349.306, 203.83, 1.898, 1.898, 1.898, false, "peripherie" },
	{ "Volcan_Eclats", 44.109, -1, 340.35, 185.27, 3.6, 5.051, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 100.249, -1, 326.379, 197.16, 1.6, 2.531, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 92.422, 76.41, 334.529, 263.77, 1.559, 1.559, 1.559, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 96.231, 76.41, 334.474, 271.85, 1.427, 1.427, 1.427, false, "peripherie" },
	{ "Volcan_Orgues", 152.533, -1, 311.508, 211.03, 1.6, 2.204, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 153.022, 66.176, 320.247, 232.2, 1.579, 1.579, 1.579, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 154.543, 66.176, 316.12, 210.84, 1.501, 1.501, 1.501, false, "peripherie" },
	{ "Volcan_Eclats", 199.416, -1, 277.95, 217.24, 3.6, 4.67, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 245.901, -1, 240.92, 225.25, 1.6, 2.072, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 239.265, 62.029, 259.679, 177.07, 1.622, 1.622, 1.622, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 241.007, 62.029, 254.434, 235.09, 1.351, 1.351, 1.351, false, "peripherie" },
	{ "Volcan_Orgues", 271.972, -1, 212.149, 229.76, 1.6, 2.501, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 285.573, 75.492, 204.994, 234.45, 1.756, 1.756, 1.756, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 285.693, 75.492, 200.568, 152.36, 1.459, 1.459, 1.459, false, "peripherie" },
	{ "Volcan_Eclats", 308.353, -1, 144.443, 248.46, 3.6, 4.617, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 323.47, -1, 108.578, 254.04, 1.6, 2.182, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 332.659, 65.478, 101.38, 137.62, 1.672, 1.672, 1.672, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 326.564, 65.478, 125.6, 143.85, 1.354, 1.354, 1.354, false, "peripherie" },
	{ "Volcan_Orgues", 343.953, -1, 45.487, 257.59, 1.6, 2.528, 1.3, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 348.946, 76.313, 56.235, 295.88, 1.315, 1.315, 1.315, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 347.836, 76.313, 51.755, 192.46, 1.882, 1.882, 1.882, false, "peripherie" },
	{ "Volcan_Orgues", 380.388, -1, -23.366, 274.23, 2.0, 3.46, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 389.185, 105.59, -19.262, 213.8, 1.679, 1.679, 1.679, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 391.322, 105.59, -16.607, 154.41, 1.824, 1.824, 1.824, false, "peripherie" },
	{ "Volcan_Eclats", 371.677, -1, -92.849, 280.94, 3.6, 4.769, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 343.588, -1, -171.725, 300.65, 2.0, 3.631, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 349.043, 110.934, -181.997, 180.8, 1.432, 1.432, 1.432, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 356.553, 110.934, -161.49, 24.31, 1.617, 1.617, 1.617, false, "peripherie" },
	{ "Volcan_Orgues", 311.626, -1, -225.147, 303.63, 2.0, 3.366, 1.6, false, "peripherie" },
	{ "Volcan_Cheminee", 329.653, 102.639, -216.706, 31.02, 1.42, 1.42, 1.42, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 328.189, 102.639, -210.938, 122.67, 1.519, 1.519, 1.519, false, "peripherie" },
	{ "Volcan_Eclats", 273.44, -1, -268.922, 319.29, 3.6, 4.56, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 201.952, -1, -324.901, 329.0, 2.0, 3.317, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 185.097, 101.099, -340.479, 331.03, 1.45, 1.45, 1.45, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 205.715, 101.099, -333.753, 343.53, 1.911, 1.911, 1.911, false, "peripherie" },
	{ "Volcan_Orgues", 151.847, -1, -351.766, 334.4, 2.0, 3.887, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 171.037, 118.968, -350.479, 179.61, 1.66, 1.66, 1.66, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 158.384, 118.968, -355.462, 173.87, 1.515, 1.515, 1.515, false, "peripherie" },
	{ "Volcan_Eclats", 78.694, -1, -369.826, 352.68, 3.6, 4.109, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 14.597, -1, -377.805, 0.46, 2.0, 3.888, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -4.442, 118.993, -386.385, 62.5, 1.613, 1.613, 1.613, false, "peripherie" },
	{ "Volcan_Cheminee", -2.277, 118.993, -384.492, 80.21, 1.328, 1.328, 1.328, false, "peripherie" },
	{ "Volcan_Orgues", -68.532, -1, -372.986, 8.5, 2.0, 3.468, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -85.761, 105.824, -380.443, 298.67, 1.438, 1.438, 1.438, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -87.741, 105.824, -377.661, 330.84, 1.371, 1.371, 1.371, false, "peripherie" },
	{ "Volcan_Eclats", -124.611, -1, -361.033, 18.79, 3.6, 4.401, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -203.391, -1, -326.02, 34.78, 2.0, 3.066, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -204.281, 93.209, -338.184, 26.86, 1.395, 1.395, 1.395, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -193.804, 93.209, -342.461, 228.64, 1.577, 1.577, 1.577, false, "peripherie" },
	{ "Volcan_Orgues", -255.687, -1, -277.894, 45.5, 2.0, 3.61, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -250.695, 110.294, -294.814, 194.82, 1.551, 1.551, 1.551, false, "peripherie" },
	{ "Volcan_Cheminee", -266.861, 110.294, -282.179, 170.06, 1.352, 1.352, 1.352, false, "peripherie" },
	{ "Volcan_Eclats", -305.891, -1, -225.266, 56.38, 3.6, 4.647, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -335.873, -1, -181.219, 59.89, 2.0, 3.387, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -347.507, 103.27, -170.409, 6.35, 1.891, 1.891, 1.891, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -330.148, 103.27, -201.294, 312.58, 1.974, 1.974, 1.974, false, "peripherie" },
	{ "Volcan_Orgues", -361.154, -1, -113.03, 76.1, 2.0, 3.153, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -369.238, 95.928, -114.443, 53.72, 1.802, 1.802, 1.802, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -371.32, 95.928, -101.212, 79.16, 1.652, 1.652, 1.652, false, "peripherie" },
	{ "Volcan_Eclats", -373.763, -1, -49.328, 85.93, 3.6, 5.191, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -382.15, -1, 29.196, 90.51, 2.0, 3.624, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -391.804, 110.729, 12.784, 84.02, 1.531, 1.531, 1.531, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -391.26, 110.729, 17.339, 96.78, 1.763, 1.763, 1.763, false, "peripherie" },
	{ "Volcan_Orgues", -374.96, -1, 85.927, 106.91, 2.0, 3.508, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -380.241, 107.086, 105.595, 264.89, 1.898, 1.898, 1.898, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -378.006, 107.086, 108.604, 16.34, 1.819, 1.819, 1.819, false, "peripherie" },
	{ "Volcan_Eclats", -339.439, -1, 165.713, 116.58, 3.6, 4.229, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -314.591, -1, 217.113, 121.04, 2.0, 3.403, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -323.059, 103.783, 223.571, 18.85, 1.814, 1.814, 1.814, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -314.151, 103.783, 227.31, 278.97, 1.903, 1.903, 1.903, false, "peripherie" },
	{ "Volcan_Orgues", -261.349, -1, 272.973, 137.06, 2.0, 3.307, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -251.835, 100.787, 292.902, 170.32, 1.784, 1.784, 1.784, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -258.84, 100.787, 285.839, 180.26, 1.698, 1.698, 1.698, false, "peripherie" },
	{ "Volcan_Eclats", -208.999, -1, 322.967, 144.35, 3.6, 4.536, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", -148.552, -1, 353.627, 157.15, 2.0, 3.294, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -156.318, 100.38, 362.306, 96.02, 1.384, 1.384, 1.384, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -142.647, 100.38, 363.211, 32.08, 1.78, 1.78, 1.78, false, "peripherie" },
	{ "Volcan_Orgues", -87.588, -1, 369.444, 171.3, 2.0, 3.886, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -108.227, 118.931, 369.94, 174.32, 1.613, 1.613, 1.613, false, "peripherie" },
	{ "Volcan_ArbreCalcine", -82.394, 118.931, 380.75, 7.58, 1.693, 1.693, 1.693, false, "peripherie" },
	{ "Volcan_Eclats", 2.438, -1, 377.695, 182.78, 3.6, 5.122, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 62.669, -1, 376.429, 186.64, 2.0, 3.175, 1.6, false, "peripherie" },
	{ "Volcan_Cheminee", 68.108, 96.629, 381.385, 340.02, 1.633, 1.633, 1.633, false, "peripherie" },
	{ "Volcan_Cheminee", 51.066, 96.629, 386.913, 123.35, 1.32, 1.32, 1.32, false, "peripherie" },
	{ "Volcan_Orgues", 141.228, -1, 352.9, 202.77, 2.0, 3.107, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 165.718, 94.508, 353.648, 333.74, 1.716, 1.716, 1.716, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 133.671, 94.508, 367.353, 167.84, 1.618, 1.618, 1.618, false, "peripherie" },
	{ "Volcan_Eclats", 189.882, -1, 326.268, 214.02, 3.6, 5.09, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 243.049, -1, 291.472, 219.01, 2.0, 3.635, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 231.961, 111.077, 312.037, 337.46, 1.534, 1.534, 1.534, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 240.978, 111.077, 305.473, 177.31, 1.766, 1.766, 1.766, false, "peripherie" },
	{ "Volcan_Orgues", 292.14, -1, 240.662, 232.19, 2.0, 3.255, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 310.111, 99.137, 227.811, 4.96, 1.871, 1.871, 1.871, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 294.169, 99.137, 248.77, 43.39, 1.654, 1.654, 1.654, false, "peripherie" },
	{ "Volcan_Eclats", 339.023, -1, 168.727, 240.38, 3.6, 4.572, 3.6, false, "peripherie" },
	{ "Volcan_Orgues", 358.881, -1, 123.344, 255.06, 2.0, 3.6, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 358.936, 109.981, 142.718, 149.43, 1.653, 1.653, 1.653, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 363.581, 109.981, 124.859, 250.02, 1.764, 1.764, 1.764, false, "peripherie" },
	{ "Volcan_Orgues", 380.91, -1, 30.942, 262.66, 2.0, 3.076, 1.6, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 389.878, 93.517, 38.816, 246.71, 1.562, 1.562, 1.562, false, "peripherie" },
	{ "Volcan_ArbreCalcine", 390.432, 93.517, 20.89, 40.09, 1.517, 1.517, 1.517, false, "peripherie" },
	{ "Volcan_Cheminee", 665.689, -6, 0.219, 301.01, 18.414, 30.591, 18.681, false, "lointain" },
	{ "Volcan_Cheminee", 546.858, -6, -241.435, 341.36, 21.542, 34.185, 21.698, false, "lointain" },
	{ "Volcan_Cheminee", 445.567, -6, -399.481, 153.67, 21.85, 35.935, 25.583, false, "lointain" },
	{ "Volcan_Cheminee", 281.361, -6, -483.447, 154.54, 22.369, 35.672, 24.313, false, "lointain" },
	{ "Volcan_Cheminee", 99.001, -6, -711.786, 11.24, 24.732, 37.454, 19.687, false, "lointain" },
	{ "Volcan_Cheminee", -145.793, -6, -616.195, 340.22, 24.605, 33.753, 20.316, false, "lointain" },
	{ "Volcan_Cheminee", -253.955, -6, -522.317, 264.38, 22.994, 34.463, 18.36, false, "lointain" },
	{ "Volcan_Cheminee", -519.711, -6, -356.497, 232.12, 23.936, 34.97, 22.386, false, "lointain" },
	{ "Volcan_Cheminee", -568.079, -6, -200.019, 351.64, 20.764, 30.358, 20.868, false, "lointain" },
	{ "Volcan_Cheminee", -674.349, -6, -40.178, 178.36, 25.111, 30.145, 20.016, false, "lointain" },
	{ "Volcan_Cheminee", -532.545, -6, 150.566, 204.88, 18.374, 32.448, 21.49, false, "lointain" },
	{ "Volcan_Cheminee", -412.883, -6, 411.319, 125.35, 23.536, 32.893, 25.01, false, "lointain" },
	{ "Volcan_Cheminee", -393.226, -6, 552.711, 161.82, 21.273, 32.35, 18.691, false, "lointain" },
	{ "Volcan_Cheminee", -118.181, -6, 558.169, 274.85, 23.347, 38.339, 21.904, false, "lointain" },
	{ "Volcan_Cheminee", 50.89, -6, 551.342, 237.75, 25.711, 32.874, 23.607, false, "lointain" },
	{ "Volcan_Cheminee", 287.914, -6, 585.382, 281.89, 18.217, 35.053, 22.418, false, "lointain" },
	{ "Volcan_Cheminee", 449.75, -6, 378.182, 94.9, 23.39, 36.61, 19.051, false, "lointain" },
	{ "Volcan_Cheminee", 662.611, -6, 221.304, 315.13, 23.559, 31.646, 19.021, false, "lointain" },
	{ "Volcan_Eclats", 719.334, -4, -126.838, 337.45, 7.887, 7.887, 7.887, false, "lointain" },
	{ "Volcan_Eclats", 376.419, -4, -679.078, 270.38, 6.253, 6.253, 6.253, false, "lointain" },
	{ "Volcan_Eclats", -286.164, -4, -708.28, 157.82, 8.444, 8.444, 8.444, false, "lointain" },
	{ "Volcan_Eclats", -648.326, -4, -198.213, 103.24, 7.662, 7.662, 7.662, false, "lointain" },
	{ "Volcan_Eclats", -624.876, -4, 421.484, 56.18, 6.251, 6.251, 6.251, false, "lointain" },
	{ "Volcan_Eclats", -66.737, -4, 762.81, 69.26, 7.87, 7.87, 7.87, false, "lointain" },
	{ "Volcan_Eclats", 494.499, -4, 477.532, 185.3, 8.669, 8.669, 8.669, false, "lointain" },
}

-- Eau / lave (pièces Roblox, rien à envoyer) : kind, forme, x, y, z (centre), taille X, épaisseur, Z, yaw
local SURFACES = {
	{ "lava", "disc", 251.295, 0.13, -104.09, 25.0, 0.26, 25.0, 0.0 },
}

-- Décors qui éclairent (PointLight sans ombre, à une hauteur relative de la pièce) : seulement dans leur monde,
-- client/WorldSkin les éteint pour les joueurs des autres mondes.
local LIGHTS = {
	Volcan_Chaudron = { rel = 0.35, range = 12, brightness = 1.0 },
	Volcan_Cheminee = { rel = 0.3, range = 18, brightness = 1.4 },
	Volcan_PilierBrasier = { rel = 0.45, range = 22, brightness = 1.6 },
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
