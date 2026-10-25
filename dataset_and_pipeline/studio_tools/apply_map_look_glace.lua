--!nocheck
-- Décors « niveau studio » du monde Glace dans Studio (mode Édition, barre MCP execute_luau ou rbxm + require).
-- GÉNÉRÉ par dataset_and_pipeline/tools/make_map_look_script.py (ne pas modifier à la main).
-- Avant : importer baked_assets/map/glace/Decors_Glace.fbx (Fichier > Importer 3D, réglages par défaut) : les MeshParts
-- nommées comme les décors arrivent dans le Workspace. Ce script :
--   1. range ces MeshParts dans ReplicatedStorage.ArtModels.Map.<Asset> (+ lueur / couleur de map_roblox.json) et
--      supprime l'import (sauvegarder le jeu ensuite : ArtModels n'est que dans le fichier du jeu) ;
--   2. pose les décors de l'arène dans Workspace.MapDecor.Glace (un Model par zone et par huitième de carte,
--      pour le streaming), sans toucher à Workspace.Map ni aux autres mondes ; les pièces de l'ancien rangement
--      (directement sous MapDecor) passent dans MapDecor.Prairie. Sans les décors des bases (zone « base ») :
--      ce sont les dossiers <Monde>Look de server/MapGenerator. client/WorldSkin montre le monde du joueur ;
--   3. MODE = "remove" retire Workspace.MapDecor.Glace.

local WORLD = "Glace"
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
	Glace_Barriere = Vector3.new(12.276, 5.5, 2.163),
	Glace_BlocMammouth = Vector3.new(9.478, 8.602, 13.477),
	Glace_Bonhomme = Vector3.new(5.289, 7.146, 2.81),
	Glace_Congere = Vector3.new(7.551, 1.699, 3.43),
	Glace_Cristaux = Vector3.new(5.156, 3.994, 4.227),
	Glace_Dalle = Vector3.new(8.084, 1.37, 5.984),
	Glace_Escalier = Vector3.new(19.2, 2.3, 5.805),
	Glace_Glacier = Vector3.new(36.078, 29.623, 15.03),
	Glace_Igloo = Vector3.new(12.137, 4.85, 14.227),
	Glace_Lanterne = Vector3.new(5.508, 12.05, 3.633),
	Glace_Pic = Vector3.new(6.981, 12.762, 5.842),
	Glace_PorteGlace = Vector3.new(26.051, 26.9, 4.4),
	Glace_Rocher = Vector3.new(9.317, 6.122, 6.716),
	Glace_Sapin = Vector3.new(8.79, 14.145, 8.79),
	Glace_SapinPetit = Vector3.new(5.284, 8.487, 5.284),
	Glace_Touffe = Vector3.new(2.11, 2.741, 2.079),
	Glace_Traineau = Vector3.new(5.244, 2.8, 2.65),
	Pancarte = Vector3.new(9.772, 7.5, 2.783),
}

-- asset, x, y (pied), z, yaw en degrés, échelle X, Y, Z, collision, zone
local ITEMS = {
	{ "Glace_Dalle", 44.615, -0.55, -5.874, 277.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 41.575, -0.55, -17.221, 292.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 35.701, -0.55, -27.394, 307.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 27.394, -0.55, -35.701, 322.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 17.221, -0.55, -41.575, 337.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 5.874, -0.55, -44.615, 352.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -5.874, -0.55, -44.615, 7.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -17.221, -0.55, -41.575, 22.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -27.394, -0.55, -35.701, 37.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -35.701, -0.55, -27.394, 52.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -41.575, -0.55, -17.221, 67.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -44.615, -0.55, -5.874, 82.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -44.615, -0.55, 5.874, 97.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -41.575, -0.55, 17.221, 112.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -35.701, -0.55, 27.394, 127.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -27.394, -0.55, 35.701, 142.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -17.221, -0.55, 41.575, 157.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", -5.874, -0.55, 44.615, 172.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 5.874, -0.55, 44.615, 187.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 17.221, -0.55, 41.575, 202.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 27.394, -0.55, 35.701, 217.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 35.701, -0.55, 27.394, 232.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 41.575, -0.55, 17.221, 247.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_Dalle", 44.615, -0.55, 5.874, 262.5, 1.12, 1.0, 1.4, false, "trou" },
	{ "Glace_PorteGlace", 66.0, 0, -0.0, 270.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_Lanterne", 62.232, 0, 14.941, 45.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Lanterne", 62.232, 0, -14.941, 45.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Cristaux", 52.661, -0.2, 21.813, 0.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_PorteGlace", 46.669, 0, 46.669, 225.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_Lanterne", 33.44, 0, 54.569, 0.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Lanterne", 54.569, 0, 33.44, 0.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Pic", 21.813, -0.2, 52.661, 53.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_PorteGlace", 0.0, 0, 66.0, 180.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_Lanterne", -14.941, 0, 62.232, 315.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Lanterne", 14.941, 0, 62.232, 315.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Cristaux", -21.813, -0.2, 52.661, 106.0, 1.1, 1.1, 1.1, true, "trou" },
	{ "Glace_PorteGlace", -46.669, 0, 46.669, 135.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_Lanterne", -54.569, 0, 33.44, 270.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Lanterne", -33.44, 0, 54.569, 270.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Pic", -52.661, -0.2, 21.813, 159.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_PorteGlace", -66.0, 0, 0.0, 90.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_Lanterne", -62.232, 0, -14.941, 225.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Lanterne", -62.232, 0, 14.941, 225.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Cristaux", -52.661, -0.2, -21.813, 212.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_PorteGlace", -46.669, 0, -46.669, 45.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_Lanterne", -33.44, 0, -54.569, 180.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Lanterne", -54.569, 0, -33.44, 180.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Pic", -21.813, -0.2, -52.661, 265.0, 1.1, 1.1, 1.1, true, "trou" },
	{ "Glace_PorteGlace", -0.0, 0, -66.0, 0.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_Lanterne", 14.941, 0, -62.232, 135.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Lanterne", -14.941, 0, -62.232, 135.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Cristaux", 21.813, -0.2, -52.661, 318.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_PorteGlace", 46.669, 0, -46.669, 315.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_Lanterne", 54.569, 0, -33.44, 90.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Lanterne", 33.44, 0, -54.569, 90.0, 0.9, 0.9, 0.9, true, "trou" },
	{ "Glace_Pic", 52.661, -0.2, -21.813, 11.0, 1.0, 1.0, 1.0, true, "trou" },
	{ "Glace_Touffe", 70.953, 0, 10.505, 309.6, 0.962, 0.962, 0.962, false, "chemin" },
	{ "Glace_Touffe", 81.739, 0, 10.682, 282.01, 1.229, 1.229, 1.229, false, "chemin" },
	{ "Glace_Touffe", 96.584, 0, 10.983, 211.15, 1.044, 1.044, 1.044, false, "chemin" },
	{ "Glace_Touffe", 110.497, 0, 9.799, 161.88, 1.389, 1.389, 1.389, false, "chemin" },
	{ "Glace_Touffe", 124.979, 0, 10.823, 90.54, 1.488, 1.488, 1.488, false, "chemin" },
	{ "Glace_Touffe", 141.413, 0, 11.049, 184.89, 0.946, 0.946, 0.946, false, "chemin" },
	{ "Glace_Touffe", 153.136, 0, 10.603, 164.68, 1.426, 1.426, 1.426, false, "chemin" },
	{ "Glace_Touffe", 74.619, 0, -9.645, 130.88, 1.153, 1.153, 1.153, false, "chemin" },
	{ "Glace_Touffe", 86.81, 0, -10.654, 41.92, 1.204, 1.204, 1.204, false, "chemin" },
	{ "Glace_Touffe", 101.811, 0, -10.68, 330.03, 1.055, 1.055, 1.055, false, "chemin" },
	{ "Glace_Touffe", 114.17, 0, -11.267, 186.48, 0.915, 0.915, 0.915, false, "chemin" },
	{ "Glace_Congere", 124.967, 0, -9.832, 253.68, 0.766, 0.766, 0.766, false, "chemin" },
	{ "Glace_Touffe", 134.787, 0, -10.72, 173.56, 1.037, 1.037, 1.037, false, "chemin" },
	{ "Glace_Touffe", 150.875, 0, -10.728, 168.99, 1.458, 1.458, 1.458, false, "chemin" },
	{ "Pancarte", 164.0, 0, 11.0, 70.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Glace_Touffe", 45.083, 0, 60.085, 110.75, 1.38, 1.38, 1.38, false, "chemin" },
	{ "Glace_Touffe", 54.389, 0, 69.185, 155.9, 1.077, 1.077, 1.077, false, "chemin" },
	{ "Glace_Touffe", 62.843, 0, 76.503, 215.02, 1.175, 1.175, 1.175, false, "chemin" },
	{ "Glace_Touffe", 71.584, 0, 86.406, 93.64, 1.191, 1.191, 1.191, false, "chemin" },
	{ "Glace_Touffe", 80.411, 0, 96.091, 200.82, 1.444, 1.444, 1.444, false, "chemin" },
	{ "Glace_Touffe", 92.127, 0, 106.509, 35.41, 1.314, 1.314, 1.314, false, "chemin" },
	{ "Glace_Touffe", 102.679, 0, 117.567, 347.5, 1.48, 1.48, 1.48, false, "chemin" },
	{ "Glace_Touffe", 59.078, 0, 45.338, 179.43, 0.958, 0.958, 0.958, false, "chemin" },
	{ "Glace_Touffe", 70.112, 0, 55.489, 5.05, 0.9, 0.9, 0.9, false, "chemin" },
	{ "Glace_Congere", 80.424, 0, 64.475, 285.76, 0.574, 0.574, 0.574, false, "chemin" },
	{ "Glace_Touffe", 90.072, 0, 74.581, 240.65, 1.281, 1.281, 1.281, false, "chemin" },
	{ "Glace_Touffe", 96.753, 0, 82.379, 277.03, 1.47, 1.47, 1.47, false, "chemin" },
	{ "Glace_Congere", 106.418, 0, 91.008, 80.25, 0.676, 0.676, 0.676, false, "chemin" },
	{ "Glace_Touffe", 118.401, 0, 102.595, 30.4, 1.301, 1.301, 1.301, false, "chemin" },
	{ "Pancarte", 108.187, 0, 123.744, 25.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Glace_Touffe", -11.247, 0, 76.268, 148.33, 1.385, 1.385, 1.385, false, "chemin" },
	{ "Glace_Congere", -9.954, 0, 89.428, 38.21, 0.766, 0.766, 0.766, false, "chemin" },
	{ "Glace_Touffe", -10.225, 0, 98.839, 277.03, 0.915, 0.915, 0.915, false, "chemin" },
	{ "Glace_Touffe", -10.19, 0, 111.922, 117.38, 0.973, 0.973, 0.973, false, "chemin" },
	{ "Glace_Touffe", -10.629, 0, 128.512, 55.4, 1.212, 1.212, 1.212, false, "chemin" },
	{ "Glace_Touffe", -10.206, 0, 140.981, 244.26, 0.942, 0.942, 0.942, false, "chemin" },
	{ "Glace_Touffe", -9.952, 0, 153.174, 16.29, 1.227, 1.227, 1.227, false, "chemin" },
	{ "Glace_Touffe", 10.958, 0, 73.615, 255.94, 1.427, 1.427, 1.427, false, "chemin" },
	{ "Glace_Touffe", 10.554, 0, 83.648, 186.07, 1.474, 1.474, 1.474, false, "chemin" },
	{ "Glace_Touffe", 11.12, 0, 93.931, 153.13, 1.148, 1.148, 1.148, false, "chemin" },
	{ "Glace_Touffe", 10.149, 0, 103.56, 94.84, 1.199, 1.199, 1.199, false, "chemin" },
	{ "Glace_Touffe", 10.348, 0, 118.802, 117.28, 1.189, 1.189, 1.189, false, "chemin" },
	{ "Glace_Touffe", 11.034, 0, 128.763, 293.81, 1.409, 1.409, 1.409, false, "chemin" },
	{ "Glace_Touffe", 11.317, 0, 139.614, 232.44, 1.145, 1.145, 1.145, false, "chemin" },
	{ "Glace_Touffe", 11.129, 0, 154.88, 346.03, 1.111, 1.111, 1.111, false, "chemin" },
	{ "Glace_Touffe", 10.612, 0, 165.134, 193.82, 0.966, 0.966, 0.966, false, "chemin" },
	{ "Pancarte", -11.0, 0, 164.0, 340.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Glace_Touffe", -60.153, 0, 45.13, 106.09, 1.061, 1.061, 1.061, false, "chemin" },
	{ "Glace_Touffe", -69.067, 0, 55.232, 343.76, 1.003, 1.003, 1.003, false, "chemin" },
	{ "Glace_Touffe", -80.14, 0, 64.631, 66.78, 1.278, 1.278, 1.278, false, "chemin" },
	{ "Glace_Touffe", -88.756, 0, 74.475, 104.77, 1.089, 1.089, 1.089, false, "chemin" },
	{ "Glace_Touffe", -96.323, 0, 82.587, 323.3, 1.366, 1.366, 1.366, false, "chemin" },
	{ "Glace_Congere", -104.972, 0, 91.356, 8.27, 0.537, 0.537, 0.537, false, "chemin" },
	{ "Glace_Touffe", -115.929, 0, 100.886, 126.11, 1.368, 1.368, 1.368, false, "chemin" },
	{ "Glace_Touffe", -45.63, 0, 60.772, 113.78, 1.029, 1.029, 1.029, false, "chemin" },
	{ "Glace_Touffe", -54.148, 0, 70.217, 247.13, 1.417, 1.417, 1.417, false, "chemin" },
	{ "Glace_Touffe", -64.437, 0, 80.365, 340.94, 1.114, 1.114, 1.114, false, "chemin" },
	{ "Glace_Congere", -75.581, 0, 90.269, 250.31, 0.587, 0.587, 0.587, false, "chemin" },
	{ "Glace_Congere", -86.903, 0, 102.516, 276.44, 0.596, 0.596, 0.596, false, "chemin" },
	{ "Glace_Touffe", -98.703, 0, 113.66, 201.91, 1.333, 1.333, 1.333, false, "chemin" },
	{ "Glace_Congere", -105.606, 0, 120.758, 45.25, 0.606, 0.606, 0.606, false, "chemin" },
	{ "Pancarte", -123.744, 0, 108.187, 295.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Glace_Touffe", -75.246, 0, -9.652, 128.15, 1.13, 1.13, 1.13, false, "chemin" },
	{ "Glace_Touffe", -86.161, 0, -10.358, 45.07, 1.226, 1.226, 1.226, false, "chemin" },
	{ "Glace_Touffe", -100.453, 0, -11.282, 142.87, 1.053, 1.053, 1.053, false, "chemin" },
	{ "Glace_Touffe", -110.635, 0, -9.642, 172.38, 1.058, 1.058, 1.058, false, "chemin" },
	{ "Glace_Touffe", -122.153, 0, -11.3, 302.24, 1.232, 1.232, 1.232, false, "chemin" },
	{ "Glace_Touffe", -136.354, 0, -11.33, 95.48, 1.28, 1.28, 1.28, false, "chemin" },
	{ "Glace_Touffe", -151.391, 0, -10.171, 4.11, 1.487, 1.487, 1.487, false, "chemin" },
	{ "Glace_Touffe", -164.155, 0, -11.346, 310.36, 1.456, 1.456, 1.456, false, "chemin" },
	{ "Glace_Touffe", -73.193, 0, 11.357, 83.7, 1.397, 1.397, 1.397, false, "chemin" },
	{ "Glace_Touffe", -84.942, 0, 9.962, 229.32, 1.229, 1.229, 1.229, false, "chemin" },
	{ "Glace_Touffe", -97.735, 0, 11.02, 67.64, 1.277, 1.277, 1.277, false, "chemin" },
	{ "Glace_Touffe", -107.965, 0, 11.209, 292.95, 1.401, 1.401, 1.401, false, "chemin" },
	{ "Glace_Touffe", -122.584, 0, 11.032, 30.31, 1.124, 1.124, 1.124, false, "chemin" },
	{ "Glace_Touffe", -137.432, 0, 9.848, 359.57, 0.911, 0.911, 0.911, false, "chemin" },
	{ "Glace_Touffe", -148.169, 0, 11.128, 206.15, 1.473, 1.473, 1.473, false, "chemin" },
	{ "Glace_Touffe", -160.213, 0, 11.334, 231.86, 0.995, 0.995, 0.995, false, "chemin" },
	{ "Pancarte", -164.0, 0, -11.0, 250.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Glace_Touffe", -42.261, 0, -57.702, 94.12, 0.925, 0.925, 0.925, false, "chemin" },
	{ "Glace_Touffe", -51.908, 0, -67.488, 105.45, 1.225, 1.225, 1.225, false, "chemin" },
	{ "Glace_Touffe", -60.057, 0, -76.109, 268.92, 0.906, 0.906, 0.906, false, "chemin" },
	{ "Glace_Touffe", -70.476, 0, -85.274, 292.37, 1.441, 1.441, 1.441, false, "chemin" },
	{ "Glace_Touffe", -81.72, 0, -97.834, 185.83, 1.008, 1.008, 1.008, false, "chemin" },
	{ "Glace_Touffe", -92.194, 0, -106.187, 185.4, 1.429, 1.429, 1.429, false, "chemin" },
	{ "Glace_Touffe", -102.403, 0, -115.985, 132.48, 1.03, 1.03, 1.03, false, "chemin" },
	{ "Glace_Congere", -108.866, 0, -123.995, 354.61, 0.645, 0.645, 0.645, false, "chemin" },
	{ "Glace_Touffe", -60.881, 0, -46.334, 233.12, 1.109, 1.109, 1.109, false, "chemin" },
	{ "Glace_Touffe", -72.059, 0, -58.175, 298.31, 1.31, 1.31, 1.31, false, "chemin" },
	{ "Glace_Congere", -81.593, 0, -66.527, 280.46, 0.526, 0.526, 0.526, false, "chemin" },
	{ "Glace_Touffe", -90.408, 0, -76.038, 81.38, 1.095, 1.095, 1.095, false, "chemin" },
	{ "Glace_Touffe", -99.661, 0, -85.24, 260.59, 1.414, 1.414, 1.414, false, "chemin" },
	{ "Glace_Touffe", -108.108, 0, -94.082, 79.26, 1.313, 1.313, 1.313, false, "chemin" },
	{ "Glace_Touffe", -117.221, 0, -101.64, 289.17, 1.129, 1.129, 1.129, false, "chemin" },
	{ "Glace_Touffe", -124.402, 0, -108.934, 45.93, 1.061, 1.061, 1.061, false, "chemin" },
	{ "Pancarte", -108.187, 0, -123.744, 205.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Glace_Touffe", 11.114, 0, -72.56, 52.33, 1.276, 1.276, 1.276, false, "chemin" },
	{ "Glace_Touffe", 11.35, 0, -83.435, 44.37, 1.076, 1.076, 1.076, false, "chemin" },
	{ "Glace_Congere", 10.322, 0, -96.099, 257.93, 0.702, 0.702, 0.702, false, "chemin" },
	{ "Glace_Touffe", 10.823, 0, -107.794, 327.08, 1.408, 1.408, 1.408, false, "chemin" },
	{ "Glace_Touffe", 10.802, 0, -124.416, 75.57, 1.111, 1.111, 1.111, false, "chemin" },
	{ "Glace_Touffe", 11.261, 0, -136.059, 3.79, 1.235, 1.235, 1.235, false, "chemin" },
	{ "Glace_Touffe", 10.201, 0, -147.077, 149.26, 1.367, 1.367, 1.367, false, "chemin" },
	{ "Glace_Touffe", 11.201, 0, -159.884, 13.5, 1.032, 1.032, 1.032, false, "chemin" },
	{ "Glace_Congere", -10.084, 0, -76.815, 75.32, 0.637, 0.637, 0.637, false, "chemin" },
	{ "Glace_Congere", -10.734, 0, -88.03, 249.28, 0.662, 0.662, 0.662, false, "chemin" },
	{ "Glace_Touffe", -9.772, 0, -97.122, 78.99, 1.178, 1.178, 1.178, false, "chemin" },
	{ "Glace_Touffe", -9.907, 0, -110.97, 204.35, 1.327, 1.327, 1.327, false, "chemin" },
	{ "Glace_Congere", -10.606, 0, -125.419, 97.51, 0.626, 0.626, 0.626, false, "chemin" },
	{ "Glace_Touffe", -10.922, 0, -135.901, 355.82, 1.446, 1.446, 1.446, false, "chemin" },
	{ "Glace_Touffe", -10.214, 0, -150.164, 218.38, 1.053, 1.053, 1.053, false, "chemin" },
	{ "Glace_Congere", -11.11, 0, -166.231, 176.4, 0.507, 0.507, 0.507, false, "chemin" },
	{ "Pancarte", 11.0, 0, -164.0, 160.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Glace_Touffe", 58.683, 0, -43.184, 98.51, 1.405, 1.405, 1.405, false, "chemin" },
	{ "Glace_Congere", 66.626, 0, -52.494, 147.91, 0.519, 0.519, 0.519, false, "chemin" },
	{ "Glace_Touffe", 77.638, 0, -62.379, 275.71, 1.079, 1.079, 1.079, false, "chemin" },
	{ "Glace_Touffe", 86.006, 0, -72.199, 188.08, 1.095, 1.095, 1.095, false, "chemin" },
	{ "Glace_Touffe", 94.485, 0, -80.044, 355.99, 1.418, 1.418, 1.418, false, "chemin" },
	{ "Glace_Touffe", 101.731, 0, -87.499, 313.75, 1.212, 1.212, 1.212, false, "chemin" },
	{ "Glace_Touffe", 110.068, 0, -96.221, 77.34, 1.178, 1.178, 1.178, false, "chemin" },
	{ "Glace_Touffe", 118.129, 0, -103.26, 184.93, 1.375, 1.375, 1.375, false, "chemin" },
	{ "Glace_Touffe", 47.03, 0, -61.851, 302.61, 1.095, 1.095, 1.095, false, "chemin" },
	{ "Glace_Touffe", 59.158, 0, -73.733, 194.07, 0.991, 0.991, 0.991, false, "chemin" },
	{ "Glace_Touffe", 67.893, 0, -83.963, 47.25, 1.39, 1.39, 1.39, false, "chemin" },
	{ "Glace_Touffe", 79.142, 0, -92.874, 12.43, 1.374, 1.374, 1.374, false, "chemin" },
	{ "Glace_Touffe", 90.679, 0, -104.711, 194.51, 1.114, 1.114, 1.114, false, "chemin" },
	{ "Glace_Congere", 99.62, 0, -113.672, 66.83, 0.546, 0.546, 0.546, false, "chemin" },
	{ "Glace_Touffe", 109.226, 0, -124.049, 10.44, 1.033, 1.033, 1.033, false, "chemin" },
	{ "Pancarte", 123.744, 0, -108.187, 115.0, 1.0, 1.0, 1.0, false, "chemin" },
	{ "Glace_Touffe", -110.987, 0, 30.547, 268.97, 0.924, 0.924, 0.924, false, "prairie" },
	{ "Glace_Touffe", -61.384, 0, -121.409, 14.5, 0.806, 0.806, 0.806, false, "prairie" },
	{ "Glace_Touffe", 103.723, 0, -70.163, 253.67, 1.451, 1.451, 1.451, false, "prairie" },
	{ "Glace_Touffe", 47.459, 0, -78.897, 293.92, 1.138, 1.138, 1.138, false, "prairie" },
	{ "Glace_Touffe", -133.285, 0, -59.544, 61.44, 0.98, 0.98, 0.98, false, "prairie" },
	{ "Glace_Touffe", 91.968, 0, 18.789, 57.06, 1.593, 1.593, 1.593, false, "prairie" },
	{ "Glace_Touffe", -98.408, 0, -52.522, 308.22, 1.364, 1.364, 1.364, false, "prairie" },
	{ "Glace_Touffe", 126.338, 0, 25.394, 158.57, 1.558, 1.558, 1.558, false, "prairie" },
	{ "Glace_Touffe", -65.62, 0, 51.971, 322.9, 1.391, 1.391, 1.391, false, "prairie" },
	{ "Glace_Touffe", -28.132, 0, 125.14, 56.9, 0.938, 0.938, 0.938, false, "prairie" },
	{ "Glace_Touffe", 150.187, 0, 50.891, 10.98, 1.577, 1.577, 1.577, false, "prairie" },
	{ "Glace_Touffe", -91.181, 0, 122.548, 284.2, 1.03, 1.03, 1.03, false, "prairie" },
	{ "Glace_Touffe", -149.176, 0, 19.815, 302.57, 1.191, 1.191, 1.191, false, "prairie" },
	{ "Glace_Touffe", -146.524, 0, 57.637, 164.17, 1.287, 1.287, 1.287, false, "prairie" },
	{ "Glace_Touffe", -128.579, 0, 85.084, 241.21, 1.061, 1.061, 1.061, false, "prairie" },
	{ "Glace_Touffe", -101.919, 0, -25.495, 297.34, 1.22, 1.22, 1.22, false, "prairie" },
	{ "Glace_Touffe", -82.735, 0, 15.95, 99.4, 0.83, 0.83, 0.83, false, "prairie" },
	{ "Glace_Touffe", -69.094, 0, 43.975, 332.12, 1.252, 1.252, 1.252, false, "prairie" },
	{ "Glace_Touffe", -101.925, 0, 51.915, 172.31, 0.818, 0.818, 0.818, false, "prairie" },
	{ "Glace_Touffe", 70.02, 0, 52.11, 37.86, 0.873, 0.873, 0.873, false, "prairie" },
	{ "Glace_Touffe", -95.101, 0, 21.112, 349.87, 1.399, 1.399, 1.399, false, "prairie" },
	{ "Glace_Touffe", 114.135, 0, -54.697, 43.08, 1.571, 1.571, 1.571, false, "prairie" },
	{ "Glace_Touffe", 112.727, 0, 76.525, 110.53, 1.177, 1.177, 1.177, false, "prairie" },
	{ "Glace_Touffe", -66.361, 0, -135.991, 248.56, 1.12, 1.12, 1.12, false, "prairie" },
	{ "Glace_Touffe", -102.187, 0, -57.129, 214.45, 1.151, 1.151, 1.151, false, "prairie" },
	{ "Glace_Touffe", 14.771, 0, 124.55, 212.6, 1.186, 1.186, 1.186, false, "prairie" },
	{ "Glace_Touffe", -85.72, 0, -18.923, 86.77, 1.217, 1.217, 1.217, false, "prairie" },
	{ "Glace_Touffe", -12.184, 0, -111.6, 264.69, 0.821, 0.821, 0.821, false, "prairie" },
	{ "Glace_Touffe", -95.835, 0, 71.687, 343.14, 0.898, 0.898, 0.898, false, "prairie" },
	{ "Glace_Touffe", 80.191, 0, -41.484, 145.94, 0.889, 0.889, 0.889, false, "prairie" },
	{ "Glace_Touffe", 125.353, 0, -98.067, 144.33, 0.805, 0.805, 0.805, false, "prairie" },
	{ "Glace_Touffe", 32.264, 0, -92.606, 288.14, 1.22, 1.22, 1.22, false, "prairie" },
	{ "Glace_Touffe", 70.766, 0, 43.568, 60.35, 1.529, 1.529, 1.529, false, "prairie" },
	{ "Glace_Touffe", 28.807, 0, -143.886, 289.11, 1.25, 1.25, 1.25, false, "prairie" },
	{ "Glace_Touffe", 98.566, 0, 72.19, 12.81, 1.568, 1.568, 1.568, false, "prairie" },
	{ "Glace_Barriere", 173.0, 0, -36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 173.0, 0, -24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 173.0, 0, -12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 173.0, 0, 12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 173.0, 0, 24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 173.0, 0, 36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 257.0, 0, -36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 257.0, 0, -24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 257.0, 0, -12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 257.0, 0, -0.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 257.0, 0, 12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 257.0, 0, 24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 257.0, 0, 36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 179.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 191.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 203.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 215.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 227.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 239.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 251.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 179.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 191.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 203.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 215.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 227.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 239.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 251.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Escalier", 170.4, 0, 0.0, 270.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Glace_PorteGlace", 173.4, 0, 0.0, 270.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Glace_Traineau", 183.0, 1.0, -32.0, 277.66, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", 179.0, 1.0, -36.0, 249.79, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", 233.0, 1.0, -37.0, 302.72, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", 228.0, 1.0, -36.5, 270.31, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Traineau", 183.0, 1.0, 32.0, 276.94, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", 179.0, 1.0, 36.0, 344.51, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", 233.0, 1.0, 37.0, 324.76, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", 228.0, 1.0, 36.5, 279.35, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Barriere", 147.785, 0, 96.874, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 139.3, 0, 105.359, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 130.815, 0, 113.844, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 113.844, 0, 130.815, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 105.359, 0, 139.3, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 96.874, 0, 147.785, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 207.182, 0, 156.271, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 198.697, 0, 164.756, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 190.212, 0, 173.241, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 181.726, 0, 181.726, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 173.241, 0, 190.212, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 164.756, 0, 198.697, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 156.271, 0, 207.182, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 156.271, 0, 96.874, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 164.756, 0, 105.359, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 173.241, 0, 113.844, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 181.726, 0, 122.329, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 190.212, 0, 130.815, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 198.697, 0, 139.3, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 207.182, 0, 147.785, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 96.874, 0, 156.271, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 105.359, 0, 164.756, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 113.844, 0, 173.241, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 122.329, 0, 181.726, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 130.815, 0, 190.212, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 139.3, 0, 198.697, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 147.785, 0, 207.182, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Escalier", 120.491, 0, 120.491, 225.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Glace_PorteGlace", 122.612, 0, 122.612, 225.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Glace_Traineau", 152.028, 1.0, 106.773, 227.41, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", 152.028, 1.0, 101.116, 349.57, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", 190.919, 1.0, 138.593, 16.93, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", 187.03, 1.0, 135.411, 216.82, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Traineau", 106.773, 1.0, 152.028, 227.43, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", 101.116, 1.0, 152.028, 100.48, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", 138.593, 1.0, 190.919, 2.63, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", 135.411, 1.0, 187.03, 227.35, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Barriere", 36.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 24.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 12.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -12.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -24.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -36.0, 0, 173.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 36.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 24.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 12.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 0.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -12.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -24.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -36.0, 0, 257.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, 179.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, 191.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, 203.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, 215.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, 227.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, 239.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, 251.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, 179.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, 191.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, 203.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, 215.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, 227.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, 239.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, 251.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Escalier", 0.0, 0, 170.4, 180.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Glace_PorteGlace", 0.0, 0, 173.4, 180.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Glace_Traineau", 32.0, 1.0, 183.0, 172.7, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", 36.0, 1.0, 179.0, 332.93, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", 37.0, 1.0, 233.0, 25.67, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", 36.5, 1.0, 228.0, 184.01, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Traineau", -32.0, 1.0, 183.0, 180.74, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", -36.0, 1.0, 179.0, 197.08, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", -37.0, 1.0, 233.0, 186.01, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", -36.5, 1.0, 228.0, 180.8, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Barriere", -96.874, 0, 147.785, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -105.359, 0, 139.3, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -113.844, 0, 130.815, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -130.815, 0, 113.844, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -139.3, 0, 105.359, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -147.785, 0, 96.874, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -156.271, 0, 207.182, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -164.756, 0, 198.697, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -173.241, 0, 190.212, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -181.726, 0, 181.726, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -190.212, 0, 173.241, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -198.697, 0, 164.756, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -207.182, 0, 156.271, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -96.874, 0, 156.271, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -105.359, 0, 164.756, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -113.844, 0, 173.241, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -122.329, 0, 181.726, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -130.815, 0, 190.212, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -139.3, 0, 198.697, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -147.785, 0, 207.182, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -156.271, 0, 96.874, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -164.756, 0, 105.359, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -173.241, 0, 113.844, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -181.726, 0, 122.329, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -190.212, 0, 130.815, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -198.697, 0, 139.3, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -207.182, 0, 147.785, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Escalier", -120.491, 0, 120.491, 135.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Glace_PorteGlace", -122.612, 0, 122.612, 135.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Glace_Traineau", -106.773, 1.0, 152.028, 134.92, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", -101.116, 1.0, 152.028, 19.16, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", -138.593, 1.0, 190.919, 126.72, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", -135.411, 1.0, 187.03, 135.74, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Traineau", -152.028, 1.0, 106.773, 134.42, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", -152.028, 1.0, 101.116, 87.22, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", -190.919, 1.0, 138.593, 5.45, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", -187.03, 1.0, 135.411, 132.72, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Barriere", -173.0, 0, 36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -173.0, 0, 24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -173.0, 0, 12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -173.0, 0, -12.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -173.0, 0, -24.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -173.0, 0, -36.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -257.0, 0, 36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -257.0, 0, 24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -257.0, 0, 12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -257.0, 0, 0.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -257.0, 0, -12.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -257.0, 0, -24.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -257.0, 0, -36.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -179.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -191.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -203.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -215.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -227.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -239.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -251.0, 0, 42.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -179.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -191.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -203.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -215.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -227.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -239.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -251.0, 0, -42.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Escalier", -170.4, 0, 0.0, 90.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Glace_PorteGlace", -173.4, 0, 0.0, 90.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Glace_Traineau", -183.0, 1.0, 32.0, 83.43, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", -179.0, 1.0, 36.0, 242.95, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", -233.0, 1.0, 37.0, 64.25, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", -228.0, 1.0, 36.5, 84.74, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Traineau", -183.0, 1.0, -32.0, 90.95, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", -179.0, 1.0, -36.0, 181.75, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", -233.0, 1.0, -37.0, 121.35, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", -228.0, 1.0, -36.5, 85.58, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Barriere", -147.785, 0, -96.874, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -139.3, 0, -105.359, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -130.815, 0, -113.844, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -113.844, 0, -130.815, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -105.359, 0, -139.3, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -96.874, 0, -147.785, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -207.182, 0, -156.271, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -198.697, 0, -164.756, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -190.212, 0, -173.241, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -181.726, 0, -181.726, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -173.241, 0, -190.212, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -164.756, 0, -198.697, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -156.271, 0, -207.182, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -156.271, 0, -96.874, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -164.756, 0, -105.359, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -173.241, 0, -113.844, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -181.726, 0, -122.329, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -190.212, 0, -130.815, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -198.697, 0, -139.3, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -207.182, 0, -147.785, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -96.874, 0, -156.271, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -105.359, 0, -164.756, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -113.844, 0, -173.241, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -122.329, 0, -181.726, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -130.815, 0, -190.212, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -139.3, 0, -198.697, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -147.785, 0, -207.182, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Escalier", -120.491, 0, -120.491, 45.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Glace_PorteGlace", -122.612, 0, -122.612, 45.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Glace_Traineau", -152.028, 1.0, -106.773, 47.34, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", -152.028, 1.0, -101.116, 60.81, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", -190.919, 1.0, -138.593, 33.27, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", -187.03, 1.0, -135.411, 41.89, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Traineau", -106.773, 1.0, -152.028, 48.97, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", -101.116, 1.0, -152.028, 46.9, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", -138.593, 1.0, -190.919, 338.5, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", -135.411, 1.0, -187.03, 52.25, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Barriere", -36.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -24.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -12.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 12.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 24.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 36.0, 0, -173.0, 0.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -36.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -24.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -12.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -0.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 12.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 24.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 36.0, 0, -257.0, 180.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, -179.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, -191.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, -203.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, -215.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, -227.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, -239.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", -42.0, 0, -251.0, 90.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, -179.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, -191.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, -203.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, -215.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, -227.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, -239.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 42.0, 0, -251.0, 270.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Escalier", -0.0, 0, -170.4, 0.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Glace_PorteGlace", -0.0, 0, -173.4, 0.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Glace_Traineau", -32.0, 1.0, -183.0, 4.46, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", -36.0, 1.0, -179.0, 296.2, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", -37.0, 1.0, -233.0, 170.77, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", -36.5, 1.0, -228.0, 3.87, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Traineau", 32.0, 1.0, -183.0, 2.99, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", 36.0, 1.0, -179.0, 116.06, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", 37.0, 1.0, -233.0, 178.19, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", 36.5, 1.0, -228.0, 352.31, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Barriere", 96.874, 0, -147.785, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 105.359, 0, -139.3, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 113.844, 0, -130.815, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 130.815, 0, -113.844, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 139.3, 0, -105.359, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 147.785, 0, -96.874, 315.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 156.271, 0, -207.182, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 164.756, 0, -198.697, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 173.241, 0, -190.212, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 181.726, 0, -181.726, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 190.212, 0, -173.241, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 198.697, 0, -164.756, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 207.182, 0, -156.271, 135.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 96.874, 0, -156.271, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 105.359, 0, -164.756, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 113.844, 0, -173.241, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 122.329, 0, -181.726, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 130.815, 0, -190.212, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 139.3, 0, -198.697, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 147.785, 0, -207.182, 45.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 156.271, 0, -96.874, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 164.756, 0, -105.359, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 173.241, 0, -113.844, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 181.726, 0, -122.329, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 190.212, 0, -130.815, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 198.697, 0, -139.3, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Barriere", 207.182, 0, -147.785, 225.0, 1.0, 1.0, 1.0, true, "base" },
	{ "Glace_Escalier", 120.491, 0, -120.491, 315.0, 1.0, 0.6, 1.0, false, "base" },
	{ "Glace_PorteGlace", 122.612, 0, -122.612, 315.0, 0.82, 0.82, 0.9, true, "base" },
	{ "Glace_Traineau", 106.773, 1.0, -152.028, 307.02, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", 101.116, 1.0, -152.028, 136.64, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", 138.593, 1.0, -190.919, 347.69, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", 135.411, 1.0, -187.03, 314.96, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Traineau", 152.028, 1.0, -106.773, 313.7, 1.0, 1.0, 1.0, false, "base" },
	{ "Glace_Bonhomme", 152.028, 1.0, -101.116, 204.03, 0.9, 0.9, 0.9, false, "base" },
	{ "Glace_Bonhomme", 190.919, 1.0, -138.593, 184.43, 0.85, 0.85, 0.85, false, "base" },
	{ "Glace_Traineau", 187.03, 1.0, -135.411, 312.12, 0.8, 0.8, 0.8, false, "base" },
	{ "Glace_Glacier", 258.942, -0.5, 149.5, 242.91, 0.7, 0.95, 0.75, true, "colline" },
	{ "Glace_Sapin", 262.535, 27.142, 148.248, 41.61, 1.251, 1.251, 1.251, true, "colline" },
	{ "Glace_Sapin", 267.822, 27.142, 138.469, 110.48, 1.113, 1.113, 1.113, true, "colline" },
	{ "Glace_Glacier", 279.935, -0.5, 115.953, 253.17, 0.75, 1.0, 0.75, true, "colline" },
	{ "Glace_Sapin", 280.279, 28.623, 121.547, 212.37, 0.997, 0.997, 0.997, true, "colline" },
	{ "Glace_Sapin", 281.895, 28.623, 117.753, 40.73, 0.951, 0.951, 0.951, true, "colline" },
	{ "Glace_Glacier", 288.812, -0.5, 77.387, 256.36, 0.7, 0.9, 0.75, true, "colline" },
	{ "Glace_Sapin", 289.626, 25.661, 83.78, 7.3, 1.143, 1.143, 1.143, true, "colline" },
	{ "Glace_Sapin", 294.568, 25.661, 64.278, 159.87, 0.949, 0.949, 0.949, true, "colline" },
	{ "Glace_Glacier", 251.477, -0.5, 125.382, 240.23, 0.6, 0.5, 0.6, true, "colline" },
	{ "Glace_Sapin", 251.35, 13.812, 131.131, 343.18, 1.076, 1.076, 1.076, true, "colline" },
	{ "Glace_Glacier", 266.479, -0.5, 89.163, 250.83, 0.6, 0.45, 0.6, true, "colline" },
	{ "Glace_Sapin", 272.71, 12.331, 77.471, 266.27, 1.064, 1.064, 1.064, true, "colline" },
	{ "Glace_Sapin", 240.593, 0, 53.742, 220.47, 0.811, 0.811, 0.811, true, "colline" },
	{ "Glace_Igloo", 238.204, 0, 55.978, 80.95, 1.042, 1.042, 1.042, true, "colline" },
	{ "Glace_SapinPetit", 216.423, 0, 119.369, 216.56, 1.026, 1.026, 1.026, true, "colline" },
	{ "Glace_Congere", 229.572, -0.4, 84.337, 328.31, 1.069, 1.069, 1.069, true, "colline" },
	{ "Glace_Congere", 216.856, -0.4, 111.578, 87.32, 1.054, 1.054, 1.054, true, "colline" },
	{ "Glace_Rocher", 215.623, -0.4, 78.805, 108.11, 1.224, 1.224, 1.224, true, "colline" },
	{ "Glace_Igloo", 199.898, 0, 117.749, 244.19, 1.0, 1.0, 1.0, true, "colline" },
	{ "Glace_BlocMammouth", 233.852, 0, 101.676, 178.88, 0.918, 0.918, 0.918, true, "colline" },
	{ "Glace_Glacier", 77.387, -0.5, 288.812, 192.69, 0.7, 0.95, 0.75, true, "colline" },
	{ "Glace_Sapin", 63.802, 27.142, 294.672, 202.24, 1.235, 1.235, 1.235, true, "colline" },
	{ "Glace_Sapin", 69.642, 27.142, 293.347, 288.38, 1.232, 1.232, 1.232, true, "colline" },
	{ "Glace_Glacier", 115.953, -0.5, 279.935, 203.87, 0.75, 1.0, 0.75, true, "colline" },
	{ "Glace_Sapin", 112.467, 28.623, 284.045, 189.27, 0.905, 0.905, 0.905, true, "colline" },
	{ "Glace_Sapin", 117.668, 28.623, 281.93, 307.49, 1.22, 1.22, 1.22, true, "colline" },
	{ "Glace_Glacier", 149.5, -0.5, 258.942, 210.71, 0.7, 0.9, 0.75, true, "colline" },
	{ "Glace_Sapin", 147.399, 25.661, 263.013, 38.52, 0.986, 0.986, 0.986, true, "colline" },
	{ "Glace_Sapin", 150.491, 25.661, 261.256, 156.76, 0.976, 0.976, 0.976, true, "colline" },
	{ "Glace_Glacier", 89.163, -0.5, 266.479, 192.87, 0.6, 0.5, 0.6, true, "colline" },
	{ "Glace_SapinPetit", 78.179, 13.812, 272.507, 78.25, 0.949, 0.949, 0.949, true, "colline" },
	{ "Glace_Glacier", 125.382, -0.5, 251.477, 207.72, 0.6, 0.45, 0.6, true, "colline" },
	{ "Glace_Sapin", 130.095, 12.331, 251.888, 149.89, 1.028, 1.028, 1.028, true, "colline" },
	{ "Glace_Sapin", 54.7, 0, 253.92, 237.2, 0.961, 0.961, 0.961, true, "colline" },
	{ "Glace_SapinPetit", 54.084, 0, 243.163, 314.7, 0.994, 0.994, 0.994, true, "colline" },
	{ "Glace_Sapin", 72.256, 0, 240.047, 85.21, 0.955, 0.955, 0.955, true, "colline" },
	{ "Glace_Rocher", 137.254, -0.4, 230.093, 286.44, 1.012, 1.012, 1.012, true, "colline" },
	{ "Glace_Rocher", 66.248, -0.4, 259.46, 166.96, 1.238, 1.238, 1.238, true, "colline" },
	{ "Glace_Congere", 88.102, -0.4, 213.143, 171.21, 1.174, 1.174, 1.174, true, "colline" },
	{ "Glace_Igloo", 58.088, 0, 224.61, 196.96, 1.0, 1.0, 1.0, true, "colline" },
	{ "Glace_Igloo", 95.216, 0, 236.556, 24.73, 1.114, 1.114, 1.114, true, "colline" },
	{ "Glace_Glacier", -149.5, -0.5, 258.942, 150.29, 0.7, 0.95, 0.75, true, "colline" },
	{ "Glace_Sapin", -152.807, 27.142, 259.908, 3.95, 0.957, 0.957, 0.957, true, "colline" },
	{ "Glace_Sapin", -147.832, 27.142, 262.77, 282.92, 1.178, 1.178, 1.178, true, "colline" },
	{ "Glace_Glacier", -115.953, -0.5, 279.935, 155.88, 0.75, 1.0, 0.75, true, "colline" },
	{ "Glace_Sapin", -109.409, 28.623, 285.237, 208.03, 1.147, 1.147, 1.147, true, "colline" },
	{ "Glace_Sapin", -122.233, 28.623, 279.981, 84.22, 1.23, 1.23, 1.23, true, "colline" },
	{ "Glace_Glacier", -77.387, -0.5, 288.812, 165.29, 0.7, 0.9, 0.75, true, "colline" },
	{ "Glace_Sapin", -77.193, 25.661, 291.451, 189.84, 1.016, 1.016, 1.016, true, "colline" },
	{ "Glace_Sapin", -70.738, 25.661, 293.084, 254.78, 1.209, 1.209, 1.209, true, "colline" },
	{ "Glace_Glacier", -125.382, -0.5, 251.477, 154.59, 0.6, 0.5, 0.6, true, "colline" },
	{ "Glace_Sapin", -135.371, 13.812, 249.092, 342.96, 1.025, 1.025, 1.025, true, "colline" },
	{ "Glace_Glacier", -89.163, -0.5, 266.479, 165.97, 0.6, 0.45, 0.6, true, "colline" },
	{ "Glace_Sapin", -97.052, 12.331, 266.37, 250.98, 1.191, 1.191, 1.191, true, "colline" },
	{ "Glace_Igloo", -136.304, 0, 222.723, 232.9, 1.014, 1.014, 1.014, true, "colline" },
	{ "Glace_Igloo", -139.318, 0, 211.655, 272.04, 0.959, 0.959, 0.959, true, "colline" },
	{ "Glace_Sapin", -65.423, 0, 238.321, 139.08, 0.923, 0.923, 0.923, true, "colline" },
	{ "Glace_Congere", -92.839, -0.4, 219.739, 148.81, 0.822, 0.822, 0.822, true, "colline" },
	{ "Glace_Rocher", -71.97, -0.4, 217.367, 351.23, 1.197, 1.197, 1.197, true, "colline" },
	{ "Glace_Congere", -101.659, -0.4, 209.518, 138.22, 1.257, 1.257, 1.257, true, "colline" },
	{ "Glace_Igloo", -58.088, 0, 224.61, 127.63, 1.0, 1.0, 1.0, true, "colline" },
	{ "Glace_Bonhomme", -106.773, 0, 231.57, 28.05, 0.953, 0.953, 0.953, true, "colline" },
	{ "Glace_Glacier", -288.812, -0.5, 77.387, 107.5, 0.7, 0.95, 0.75, true, "colline" },
	{ "Glace_Sapin", -287.37, 27.142, 91.219, 37.13, 1.145, 1.145, 1.145, true, "colline" },
	{ "Glace_Sapin", -291.094, 27.142, 78.527, 45.7, 1.25, 1.25, 1.25, true, "colline" },
	{ "Glace_Glacier", -279.935, -0.5, 115.953, 109.25, 0.75, 1.0, 0.75, true, "colline" },
	{ "Glace_SapinPetit", -279.802, 28.623, 122.641, 37.76, 1.217, 1.217, 1.217, true, "colline" },
	{ "Glace_Sapin", -275.755, 28.623, 131.488, 13.25, 1.076, 1.076, 1.076, true, "colline" },
	{ "Glace_Glacier", -258.942, -0.5, 149.5, 124.01, 0.7, 0.9, 0.75, true, "colline" },
	{ "Glace_Sapin", -257.306, 25.661, 157.15, 147.22, 1.048, 1.048, 1.048, true, "colline" },
	{ "Glace_Sapin", -258.277, 25.661, 155.548, 335.08, 1.066, 1.066, 1.066, true, "colline" },
	{ "Glace_Glacier", -266.479, -0.5, 89.163, 104.29, 0.6, 0.5, 0.6, true, "colline" },
	{ "Glace_Sapin", -267.506, 13.812, 93.876, 218.37, 1.186, 1.186, 1.186, true, "colline" },
	{ "Glace_Glacier", -251.477, -0.5, 125.382, 111.32, 0.6, 0.45, 0.6, true, "colline" },
	{ "Glace_Sapin", -247.246, 12.331, 138.714, 158.79, 1.154, 1.154, 1.154, true, "colline" },
	{ "Glace_Sapin", -217.762, 0, 136.971, 286.65, 0.95, 0.95, 0.95, true, "colline" },
	{ "Glace_SapinPetit", -211.592, 0, 125.35, 74.0, 0.856, 0.856, 0.856, true, "colline" },
	{ "Glace_Sapin", -228.132, 0, 119.702, 69.6, 0.935, 0.935, 0.935, true, "colline" },
	{ "Glace_Rocher", -206.508, -0.4, 128.256, 132.14, 1.135, 1.135, 1.135, true, "colline" },
	{ "Glace_Congere", -229.291, -0.4, 69.564, 92.21, 0.952, 0.952, 0.952, true, "colline" },
	{ "Glace_Rocher", -220.104, -0.4, 121.919, 248.29, 1.032, 1.032, 1.032, true, "colline" },
	{ "Glace_Igloo", -199.898, 0, 117.749, 129.69, 1.0, 1.0, 1.0, true, "colline" },
	{ "Glace_Pic", -230.245, 0, 109.601, 61.49, 0.958, 0.958, 0.958, true, "colline" },
	{ "Glace_Glacier", -258.942, -0.5, -149.5, 57.02, 0.7, 0.95, 0.75, true, "colline" },
	{ "Glace_Sapin", -254.897, 27.142, -161.027, 130.73, 0.975, 0.975, 0.975, true, "colline" },
	{ "Glace_Sapin", -255.876, 27.142, -159.468, 327.41, 1.138, 1.138, 1.138, true, "colline" },
	{ "Glace_Glacier", -279.935, -0.5, -115.953, 68.98, 0.75, 1.0, 0.75, true, "colline" },
	{ "Glace_Sapin", -279.567, 28.623, -123.176, 356.07, 1.038, 1.038, 1.038, true, "colline" },
	{ "Glace_Sapin", -287.282, 28.623, -103.92, 228.65, 0.914, 0.914, 0.914, true, "colline" },
	{ "Glace_Glacier", -288.812, -0.5, -77.387, 72.66, 0.7, 0.9, 0.75, true, "colline" },
	{ "Glace_Sapin", -289.247, 25.661, -85.078, 74.82, 0.949, 0.949, 0.949, true, "colline" },
	{ "Glace_Sapin", -294.697, 25.661, -63.685, 172.36, 1.014, 1.014, 1.014, true, "colline" },
	{ "Glace_Glacier", -251.477, -0.5, -125.382, 59.07, 0.6, 0.5, 0.6, true, "colline" },
	{ "Glace_Sapin", -259.292, 13.812, -114.63, 333.35, 1.016, 1.016, 1.016, true, "colline" },
	{ "Glace_Glacier", -266.479, -0.5, -89.163, 70.72, 0.6, 0.45, 0.6, true, "colline" },
	{ "Glace_Sapin", -272.183, 12.331, -79.299, 10.82, 1.026, 1.026, 1.026, true, "colline" },
	{ "Glace_Igloo", -230.173, 0, -70.096, 352.33, 1.093, 1.093, 1.093, true, "colline" },
	{ "Glace_Igloo", -225.682, 0, -118.769, 337.14, 0.971, 0.971, 0.971, true, "colline" },
	{ "Glace_SapinPetit", -243.751, 0, -52.955, 194.99, 0.889, 0.889, 0.889, true, "colline" },
	{ "Glace_Congere", -229.608, -0.4, -110.069, 193.43, 1.182, 1.182, 1.182, true, "colline" },
	{ "Glace_Rocher", -246.325, -0.4, -64.904, 156.02, 1.267, 1.267, 1.267, true, "colline" },
	{ "Glace_Congere", -215.574, -0.4, -80.737, 52.46, 1.13, 1.13, 1.13, true, "colline" },
	{ "Glace_Igloo", -224.61, 0, -58.088, 44.72, 1.0, 1.0, 1.0, true, "colline" },
	{ "Glace_BlocMammouth", -240.85, 0, -83.764, 310.36, 1.187, 1.187, 1.187, true, "colline" },
	{ "Glace_Glacier", -77.387, -0.5, -288.812, 12.17, 0.7, 0.95, 0.75, true, "colline" },
	{ "Glace_Sapin", -70.167, 27.142, -293.221, 100.17, 0.985, 0.985, 0.985, true, "colline" },
	{ "Glace_SapinPetit", -91.819, 27.142, -287.179, 13.82, 1.288, 1.288, 1.288, true, "colline" },
	{ "Glace_Glacier", -115.953, -0.5, -279.935, 22.2, 0.75, 1.0, 0.75, true, "colline" },
	{ "Glace_Sapin", -107.168, 28.623, -286.086, 293.23, 1.18, 1.18, 1.18, true, "colline" },
	{ "Glace_Sapin", -111.02, 28.623, -284.614, 103.01, 1.228, 1.228, 1.228, true, "colline" },
	{ "Glace_Glacier", -149.5, -0.5, -258.942, 30.67, 0.7, 0.9, 0.75, true, "colline" },
	{ "Glace_Sapin", -142.5, 25.661, -265.699, 314.69, 1.143, 1.143, 1.143, true, "colline" },
	{ "Glace_Sapin", -157.222, 25.661, -257.261, 94.25, 1.027, 1.027, 1.027, true, "colline" },
	{ "Glace_Glacier", -89.163, -0.5, -266.479, 21.07, 0.6, 0.5, 0.6, true, "colline" },
	{ "Glace_Sapin", -96.448, 13.812, -266.59, 197.97, 1.242, 1.242, 1.242, true, "colline" },
	{ "Glace_Glacier", -125.382, -0.5, -251.477, 29.38, 0.6, 0.45, 0.6, true, "colline" },
	{ "Glace_Sapin", -118.105, 12.331, -257.728, 259.84, 0.99, 0.99, 0.99, true, "colline" },
	{ "Glace_Igloo", -124.51, 0, -213.082, 15.45, 0.896, 0.896, 0.896, true, "colline" },
	{ "Glace_Sapin", -137.087, 0, -222.271, 99.32, 1.111, 1.111, 1.111, true, "colline" },
	{ "Glace_Igloo", -56.01, 0, -243.867, 268.11, 0.947, 0.947, 0.947, true, "colline" },
	{ "Glace_Rocher", -102.945, -0.4, -209.053, 254.05, 1.061, 1.061, 1.061, true, "colline" },
	{ "Glace_Rocher", -121.861, -0.4, -199.108, 329.03, 1.275, 1.275, 1.275, true, "colline" },
	{ "Glace_Rocher", -104.712, -0.4, -214.997, 244.63, 1.255, 1.255, 1.255, true, "colline" },
	{ "Glace_Igloo", -117.749, 0, -199.898, 39.07, 1.0, 1.0, 1.0, true, "colline" },
	{ "Glace_Igloo", -90.251, 0, -238.495, 354.21, 1.125, 1.125, 1.125, true, "colline" },
	{ "Glace_Glacier", 149.5, -0.5, -258.942, 335.94, 0.7, 0.95, 0.75, true, "colline" },
	{ "Glace_Sapin", 162.235, 27.142, -254.13, 289.43, 1.059, 1.059, 1.059, true, "colline" },
	{ "Glace_Sapin", 159.431, 27.142, -255.899, 145.39, 1.123, 1.123, 1.123, true, "colline" },
	{ "Glace_Glacier", 115.953, -0.5, -279.935, 331.59, 0.75, 1.0, 0.75, true, "colline" },
	{ "Glace_SapinPetit", 115.16, 28.623, -282.964, 318.2, 1.292, 1.292, 1.292, true, "colline" },
	{ "Glace_Sapin", 130.28, 28.623, -276.328, 6.71, 1.096, 1.096, 1.096, true, "colline" },
	{ "Glace_Glacier", 77.387, -0.5, -288.812, 348.23, 0.7, 0.9, 0.75, true, "colline" },
	{ "Glace_SapinPetit", 75.183, 25.661, -291.976, 276.42, 0.98, 0.98, 0.98, true, "colline" },
	{ "Glace_SapinPetit", 68.738, 25.661, -293.56, 72.29, 0.988, 0.988, 0.988, true, "colline" },
	{ "Glace_Glacier", 125.382, -0.5, -251.477, 331.98, 0.6, 0.5, 0.6, true, "colline" },
	{ "Glace_SapinPetit", 138.752, 13.812, -247.225, 189.09, 1.101, 1.101, 1.101, true, "colline" },
	{ "Glace_Glacier", 89.163, -0.5, -266.479, 340.89, 0.6, 0.45, 0.6, true, "colline" },
	{ "Glace_Sapin", 89.137, 12.331, -269.122, 347.9, 1.06, 1.06, 1.06, true, "colline" },
	{ "Glace_SapinPetit", 118.412, 0, -210.716, 127.97, 0.828, 0.828, 0.828, true, "colline" },
	{ "Glace_Sapin", 124.141, 0, -210.16, 17.92, 0.907, 0.907, 0.907, true, "colline" },
	{ "Glace_Sapin", 138.998, 0, -212.422, 60.0, 0.869, 0.869, 0.869, true, "colline" },
	{ "Glace_Congere", 126.168, -0.4, -211.892, 177.32, 0.969, 0.969, 0.969, true, "colline" },
	{ "Glace_Rocher", 67.792, -0.4, -233.104, 329.07, 0.841, 0.841, 0.841, true, "colline" },
	{ "Glace_Rocher", 110.334, -0.4, -246.349, 184.03, 0.847, 0.847, 0.847, true, "colline" },
	{ "Glace_Igloo", 117.749, 0, -199.898, 354.07, 1.0, 1.0, 1.0, true, "colline" },
	{ "Glace_Bonhomme", 85.548, 0, -240.222, 161.73, 0.906, 0.906, 0.906, true, "colline" },
	{ "Glace_Glacier", 288.812, -0.5, -77.387, 283.07, 0.7, 0.95, 0.75, true, "colline" },
	{ "Glace_Sapin", 291.236, 27.142, -78.0, 73.36, 1.239, 1.239, 1.239, true, "colline" },
	{ "Glace_Sapin", 294.461, 27.142, -64.77, 70.79, 0.925, 0.925, 0.925, true, "colline" },
	{ "Glace_Glacier", 279.935, -0.5, -115.953, 288.05, 0.75, 1.0, 0.75, true, "colline" },
	{ "Glace_Sapin", 282.408, 28.623, -116.516, 44.28, 1.123, 1.123, 1.123, true, "colline" },
	{ "Glace_Sapin", 286.673, 28.623, -105.587, 329.4, 1.294, 1.294, 1.294, true, "colline" },
	{ "Glace_Glacier", 258.942, -0.5, -149.5, 305.1, 0.7, 0.9, 0.75, true, "colline" },
	{ "Glace_Sapin", 258.46, 25.661, -155.244, 113.05, 1.118, 1.118, 1.118, true, "colline" },
	{ "Glace_Sapin", 263.992, 25.661, -145.638, 293.68, 0.939, 0.939, 0.939, true, "colline" },
	{ "Glace_Glacier", 266.479, -0.5, -89.163, 288.48, 0.6, 0.5, 0.6, true, "colline" },
	{ "Glace_Sapin", 266.032, 13.812, -97.975, 209.44, 0.978, 0.978, 0.978, true, "colline" },
	{ "Glace_Glacier", 251.477, -0.5, -125.382, 297.09, 0.6, 0.45, 0.6, true, "colline" },
	{ "Glace_Sapin", 258.896, 12.331, -115.52, 321.9, 1.257, 1.257, 1.257, true, "colline" },
	{ "Glace_SapinPetit", 252.577, 0, -68.83, 293.17, 1.062, 1.062, 1.062, true, "colline" },
	{ "Glace_SapinPetit", 241.128, 0, -61.904, 206.12, 1.148, 1.148, 1.148, true, "colline" },
	{ "Glace_SapinPetit", 247.029, 0, -77.466, 253.5, 0.909, 0.909, 0.909, true, "colline" },
	{ "Glace_Congere", 247.953, -0.4, -57.428, 48.97, 0.882, 0.882, 0.882, true, "colline" },
	{ "Glace_Rocher", 220.353, -0.4, -88.32, 282.32, 1.141, 1.141, 1.141, true, "colline" },
	{ "Glace_Rocher", 226.399, -0.4, -112.802, 137.56, 1.239, 1.239, 1.239, true, "colline" },
	{ "Glace_Igloo", 224.61, 0, -58.088, 295.05, 1.0, 1.0, 1.0, true, "colline" },
	{ "Glace_Pic", 235.303, 0, -98.272, 241.43, 1.035, 1.035, 1.035, true, "colline" },
	{ "Glace_Sapin", 269.735, -0.2, -102.601, 112.61, 0.885, 0.885, 0.885, true, "colline" },
	{ "Glace_Congere", 264.187, -0.2, -117.358, 295.38, 0.793, 0.793, 0.793, false, "colline" },
	{ "Glace_Rocher", 249.45, -0.2, -122.498, 51.55, 1.046, 1.046, 1.046, true, "colline" },
	{ "Glace_SapinPetit", 238.834, -0.2, -117.764, 131.21, 0.998, 0.998, 0.998, false, "colline" },
	{ "Glace_Sapin", 232.873, -0.2, -102.395, 70.05, 0.958, 0.958, 0.958, true, "colline" },
	{ "Glace_Congere", 238.35, -0.2, -90.873, 296.74, 0.756, 0.756, 0.756, false, "colline" },
	{ "Glace_Rocher", 251.057, -0.2, -85.591, 250.2, 0.957, 0.957, 0.957, true, "colline" },
	{ "Glace_SapinPetit", 262.326, -0.2, -89.238, 247.79, 0.935, 0.935, 0.935, false, "colline" },
	{ "Glace_Glacier", 340.385, -1, -3.058, 275.12, 1.6, 2.033, 1.3, false, "peripherie" },
	{ "Glace_SapinPetit", 346.385, 57.232, -1.251, 46.12, 1.681, 1.681, 1.681, false, "peripherie" },
	{ "Glace_Sapin", 349.296, 57.232, -11.237, 73.66, 1.455, 1.455, 1.455, false, "peripherie" },
	{ "Glace_Pic", 340.997, -1, -53.782, 282.56, 3.4, 4.44, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 327.192, -1, -94.662, 284.76, 1.6, 2.56, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 328.718, 72.843, -104.016, 69.73, 1.917, 1.917, 1.917, false, "peripherie" },
	{ "Glace_Sapin", 337.953, 72.843, -78.851, 26.14, 1.751, 1.751, 1.751, false, "peripherie" },
	{ "Glace_Glacier", 312.069, -1, -150.029, 293.03, 1.6, 2.089, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 318.815, 58.885, -149.347, 214.03, 1.689, 1.689, 1.689, false, "peripherie" },
	{ "Glace_Sapin", 316.637, 58.885, -154.392, 91.34, 1.376, 1.376, 1.376, false, "peripherie" },
	{ "Glace_Pic", 281.316, -1, -191.936, 299.56, 3.4, 4.139, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 245.064, -1, -234.252, 317.13, 1.6, 1.976, 1.3, false, "peripherie" },
	{ "Glace_SapinPetit", 233.644, 55.54, -251.012, 98.07, 1.928, 1.928, 1.928, false, "peripherie" },
	{ "Glace_SapinPetit", 257.311, 55.54, -231.376, 183.68, 1.448, 1.448, 1.448, false, "peripherie" },
	{ "Glace_Glacier", 206.625, -1, -268.929, 325.58, 1.6, 2.27, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 215.408, 64.248, -273.567, 134.98, 1.392, 1.392, 1.392, false, "peripherie" },
	{ "Glace_Sapin", 201.966, 64.248, -278.017, 252.67, 1.862, 1.862, 1.862, false, "peripherie" },
	{ "Glace_Pic", 148.09, -1, -311.086, 337.47, 3.4, 3.615, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 96.021, -1, -329.555, 339.22, 1.6, 2.24, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 103.913, 63.353, -335.126, 303.51, 1.664, 1.664, 1.664, false, "peripherie" },
	{ "Glace_Sapin", 90.224, 63.353, -336.979, 154.96, 1.884, 1.884, 1.884, false, "peripherie" },
	{ "Glace_Glacier", 64.096, -1, -338.629, 353.26, 1.6, 2.33, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 65.842, 66.02, -345.592, 145.41, 1.328, 1.328, 1.328, false, "peripherie" },
	{ "Glace_Sapin", 47.733, 66.02, -349.615, 220.74, 1.574, 1.574, 1.574, false, "peripherie" },
	{ "Glace_Pic", 10.705, -1, -341.724, 358.95, 3.4, 3.388, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -50.395, -1, -338.901, 3.94, 1.6, 2.3, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -59.538, 65.121, -343.628, 333.54, 1.893, 1.893, 1.893, false, "peripherie" },
	{ "Glace_Sapin", -46.721, 65.121, -346.52, 39.34, 1.737, 1.737, 1.737, false, "peripherie" },
	{ "Glace_Glacier", -115.291, -1, -322.204, 18.68, 1.6, 2.078, 1.3, false, "peripherie" },
	{ "Glace_SapinPetit", -129.886, 58.564, -324.166, 87.86, 1.425, 1.425, 1.425, false, "peripherie" },
	{ "Glace_Sapin", -118.729, 58.564, -326.843, 297.52, 1.572, 1.572, 1.572, false, "peripherie" },
	{ "Glace_Pic", -157.658, -1, -300.146, 27.75, 3.4, 3.781, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -209.386, -1, -270.197, 35.79, 1.6, 2.186, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -214.033, 61.767, -271.899, 206.15, 1.42, 1.42, 1.42, false, "peripherie" },
	{ "Glace_Sapin", -215.042, 61.767, -271.915, 147.54, 1.533, 1.533, 1.533, false, "peripherie" },
	{ "Glace_Glacier", -249.183, -1, -241.441, 41.79, 1.6, 2.332, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -260.167, 66.069, -235.468, 146.74, 1.316, 1.316, 1.316, false, "peripherie" },
	{ "Glace_Sapin", -252.923, 66.069, -244.501, 307.01, 1.312, 1.312, 1.312, false, "peripherie" },
	{ "Glace_Pic", -274.237, -1, -211.573, 53.52, 3.4, 3.887, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -310.904, -1, -145.276, 69.85, 1.6, 2.119, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -308.279, 59.764, -165.208, 99.55, 1.487, 1.487, 1.487, false, "peripherie" },
	{ "Glace_Sapin", -314.137, 59.764, -148.333, 336.47, 1.569, 1.569, 1.569, false, "peripherie" },
	{ "Glace_Glacier", -324.968, -1, -112.911, 72.83, 1.6, 1.979, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -332.34, 55.628, -117.858, 33.02, 1.561, 1.561, 1.561, false, "peripherie" },
	{ "Glace_Sapin", -338.096, 55.628, -101.099, 107.81, 1.75, 1.75, 1.75, false, "peripherie" },
	{ "Glace_Pic", -340.406, -1, -51.38, 82.83, 3.4, 3.905, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -339.397, -1, 8.577, 92.2, 1.6, 2.545, 1.3, false, "peripherie" },
	{ "Glace_SapinPetit", -347.537, 72.377, -3.259, 262.55, 1.794, 1.794, 1.794, false, "peripherie" },
	{ "Glace_Sapin", -344.961, 72.377, 27.529, 167.58, 1.363, 1.363, 1.363, false, "peripherie" },
	{ "Glace_Glacier", -342.33, -1, 54.863, 102.89, 1.6, 1.983, 1.3, false, "peripherie" },
	{ "Glace_SapinPetit", -344.187, 55.746, 73.837, 239.33, 1.926, 1.926, 1.926, false, "peripherie" },
	{ "Glace_Sapin", -348.624, 55.746, 61.93, 53.8, 1.427, 1.427, 1.427, false, "peripherie" },
	{ "Glace_Pic", -323.776, -1, 104.975, 106.18, 3.4, 3.839, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -302.653, -1, 156.051, 119.25, 1.6, 1.968, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -310.415, 55.307, 151.801, 254.84, 1.926, 1.926, 1.926, false, "peripherie" },
	{ "Glace_Sapin", -316.35, 55.307, 139.546, 105.42, 1.728, 1.728, 1.728, false, "peripherie" },
	{ "Glace_Glacier", -273.285, -1, 206.096, 127.75, 1.6, 2.48, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -271.388, 70.457, 222.87, 266.16, 1.942, 1.942, 1.942, false, "peripherie" },
	{ "Glace_Sapin", -273.13, 70.457, 212.946, 41.49, 1.499, 1.499, 1.499, false, "peripherie" },
	{ "Glace_Pic", -246.037, -1, 233.219, 130.85, 3.4, 3.618, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -195.182, -1, 280.814, 147.85, 1.6, 1.93, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -190.079, 54.166, 289.154, 184.15, 1.932, 1.932, 1.932, false, "peripherie" },
	{ "Glace_Sapin", -187.543, 54.166, 294.387, 23.21, 1.992, 1.992, 1.992, false, "peripherie" },
	{ "Glace_Glacier", -163.333, -1, 298.105, 155.37, 1.6, 2.396, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -150.947, 67.968, 310.862, 111.09, 1.345, 1.345, 1.345, false, "peripherie" },
	{ "Glace_Sapin", -170.792, 67.968, 299.008, 222.57, 1.745, 1.745, 1.745, false, "peripherie" },
	{ "Glace_Pic", -99.062, -1, 324.619, 160.94, 3.4, 3.574, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -44.714, -1, 336.353, 175.48, 1.6, 2.339, 1.3, false, "peripherie" },
	{ "Glace_SapinPetit", -39.011, 66.299, 341.848, 230.84, 1.737, 1.737, 1.737, false, "peripherie" },
	{ "Glace_Sapin", -64.345, 66.299, 341.887, 89.86, 1.353, 1.353, 1.353, false, "peripherie" },
	{ "Glace_Glacier", -4.786, -1, 340.735, 176.35, 1.6, 2.338, 1.3, false, "peripherie" },
	{ "Glace_Sapin", -2.062, 66.269, 346.651, 307.5, 1.367, 1.367, 1.367, false, "peripherie" },
	{ "Glace_Sapin", 11.836, 66.269, 347.194, 166.14, 1.486, 1.486, 1.486, false, "peripherie" },
	{ "Glace_Pic", 58.155, -1, 334.068, 194.72, 3.4, 4.083, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 106.601, -1, 327.972, 198.23, 1.6, 2.159, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 105.82, 60.942, 334.25, 271.85, 1.427, 1.427, 1.427, false, "peripherie" },
	{ "Glace_Sapin", 127.618, 60.942, 326.095, 253.86, 1.483, 1.483, 1.483, false, "peripherie" },
	{ "Glace_Glacier", 158.43, -1, 303.307, 207.53, 1.6, 2.052, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 157.713, 57.773, 310.18, 149.18, 1.57, 1.57, 1.57, false, "peripherie" },
	{ "Glace_Sapin", 167.675, 57.773, 306.449, 88.61, 1.626, 1.626, 1.626, false, "peripherie" },
	{ "Glace_Pic", 208.207, -1, 268.354, 219.74, 3.4, 3.7, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 242.175, -1, 242.45, 221.91, 1.6, 2.21, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 249.871, 62.481, 246.794, 193.54, 1.516, 1.516, 1.516, false, "peripherie" },
	{ "Glace_SapinPetit", 253.729, 62.481, 242.127, 155.17, 1.347, 1.347, 1.347, false, "peripherie" },
	{ "Glace_Glacier", 283.02, -1, 195.908, 230.77, 1.6, 2.356, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 288.301, 66.789, 203.441, 339.73, 1.373, 1.373, 1.373, false, "peripherie" },
	{ "Glace_Sapin", 294.947, 66.789, 187.531, 342.45, 1.811, 1.811, 1.811, false, "peripherie" },
	{ "Glace_Pic", 307.918, -1, 143.904, 244.42, 3.4, 3.436, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 327.203, -1, 99.709, 257.24, 1.6, 2.272, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 333.912, 64.305, 93.346, 106.58, 1.419, 1.419, 1.419, false, "peripherie" },
	{ "Glace_Sapin", 337.019, 64.305, 81.446, 180.02, 1.488, 1.488, 1.488, false, "peripherie" },
	{ "Glace_Glacier", 339.478, -1, 57.736, 260.88, 1.6, 2.133, 1.3, false, "peripherie" },
	{ "Glace_Sapin", 348.65, 60.172, 51.67, 274.76, 1.863, 1.863, 1.863, false, "peripherie" },
	{ "Glace_Sapin", 341.975, 60.172, 77.112, 184.2, 1.7, 1.7, 1.7, false, "peripherie" },
	{ "Glace_Glacier", 379.127, -1, -28.825, 274.25, 2.0, 3.6, 1.6, false, "peripherie" },
	{ "Glace_Sapin", 385.12, 103.644, -46.808, 176.5, 1.588, 1.588, 1.588, false, "peripherie" },
	{ "Glace_Sapin", 384.395, 103.644, -23.191, 230.81, 1.434, 1.434, 1.434, false, "peripherie" },
	{ "Glace_Pic", 369.292, -1, -105.667, 290.06, 3.4, 4.282, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 343.061, -1, -168.306, 296.54, 2.0, 3.439, 1.6, false, "peripherie" },
	{ "Glace_Sapin", 351.481, 98.889, -172.556, 321.36, 1.483, 1.483, 1.483, false, "peripherie" },
	{ "Glace_SapinPetit", 348.726, 98.889, -172.073, 162.99, 1.665, 1.665, 1.665, false, "peripherie" },
	{ "Glace_Glacier", 301.72, -1, -231.432, 310.7, 2.0, 3.251, 1.6, false, "peripherie" },
	{ "Glace_SapinPetit", 318.105, 93.294, -218.549, 61.51, 1.396, 1.396, 1.396, false, "peripherie" },
	{ "Glace_Sapin", 297.995, 93.294, -244.413, 112.61, 1.33, 1.33, 1.33, false, "peripherie" },
	{ "Glace_Pic", 256.664, -1, -281.217, 320.6, 3.4, 4.575, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 202.864, -1, -321.108, 323.01, 2.0, 3.528, 1.6, false, "peripherie" },
	{ "Glace_Sapin", 193.939, 101.515, -339.362, 331.03, 1.45, 1.45, 1.45, false, "peripherie" },
	{ "Glace_Sapin", 206.7, 101.515, -329.926, 343.53, 1.911, 1.911, 1.911, false, "peripherie" },
	{ "Glace_Glacier", 151.847, -1, -351.766, 334.4, 2.0, 3.887, 1.6, false, "peripherie" },
	{ "Glace_Sapin", 171.037, 112.141, -350.479, 179.61, 1.66, 1.66, 1.66, false, "peripherie" },
	{ "Glace_Sapin", 158.384, 112.141, -355.462, 173.87, 1.515, 1.515, 1.515, false, "peripherie" },
	{ "Glace_Pic", 78.694, -1, -369.826, 352.68, 3.4, 3.635, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 14.597, -1, -377.805, 0.46, 2.0, 3.888, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -4.442, 112.164, -386.385, 62.5, 1.613, 1.613, 1.613, false, "peripherie" },
	{ "Glace_SapinPetit", -2.277, 112.164, -384.492, 80.21, 1.328, 1.328, 1.328, false, "peripherie" },
	{ "Glace_Glacier", -68.532, -1, -372.986, 8.5, 2.0, 3.468, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -85.761, 99.732, -380.443, 298.67, 1.438, 1.438, 1.438, false, "peripherie" },
	{ "Glace_Sapin", -87.741, 99.732, -377.661, 330.84, 1.371, 1.371, 1.371, false, "peripherie" },
	{ "Glace_Pic", -124.611, -1, -361.033, 18.79, 3.4, 3.893, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -203.391, -1, -326.02, 34.78, 2.0, 3.066, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -204.281, 87.824, -338.184, 26.86, 1.395, 1.395, 1.395, false, "peripherie" },
	{ "Glace_Sapin", -193.804, 87.824, -342.461, 228.64, 1.577, 1.577, 1.577, false, "peripherie" },
	{ "Glace_Glacier", -255.687, -1, -277.894, 45.5, 2.0, 3.61, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -250.695, 103.952, -294.814, 194.82, 1.551, 1.551, 1.551, false, "peripherie" },
	{ "Glace_SapinPetit", -266.861, 103.952, -282.179, 170.06, 1.352, 1.352, 1.352, false, "peripherie" },
	{ "Glace_Pic", -305.891, -1, -225.266, 56.38, 3.4, 4.111, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -335.873, -1, -181.219, 59.89, 2.0, 3.387, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -347.507, 97.321, -170.409, 6.35, 1.891, 1.891, 1.891, false, "peripherie" },
	{ "Glace_Sapin", -330.148, 97.321, -201.294, 312.58, 1.974, 1.974, 1.974, false, "peripherie" },
	{ "Glace_Glacier", -361.154, -1, -113.03, 76.1, 2.0, 3.153, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -369.238, 90.391, -114.443, 53.72, 1.802, 1.802, 1.802, false, "peripherie" },
	{ "Glace_Sapin", -371.32, 90.391, -101.212, 79.16, 1.652, 1.652, 1.652, false, "peripherie" },
	{ "Glace_Pic", -373.763, -1, -49.328, 85.93, 3.4, 4.592, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -382.15, -1, 29.196, 90.51, 2.0, 3.624, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -391.804, 104.363, 12.784, 84.02, 1.531, 1.531, 1.531, false, "peripherie" },
	{ "Glace_Sapin", -391.26, 104.363, 17.339, 96.78, 1.763, 1.763, 1.763, false, "peripherie" },
	{ "Glace_Glacier", -374.96, -1, 85.927, 106.91, 2.0, 3.508, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -380.241, 100.923, 105.595, 264.89, 1.898, 1.898, 1.898, false, "peripherie" },
	{ "Glace_Sapin", -378.006, 100.923, 108.604, 16.34, 1.819, 1.819, 1.819, false, "peripherie" },
	{ "Glace_Pic", -339.439, -1, 165.713, 116.58, 3.4, 3.741, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -314.591, -1, 217.113, 121.04, 2.0, 3.403, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -323.059, 97.806, 223.571, 18.85, 1.814, 1.814, 1.814, false, "peripherie" },
	{ "Glace_Sapin", -314.151, 97.806, 227.31, 278.97, 1.903, 1.903, 1.903, false, "peripherie" },
	{ "Glace_Glacier", -261.349, -1, 272.973, 137.06, 2.0, 3.307, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -251.835, 94.978, 292.902, 170.32, 1.784, 1.784, 1.784, false, "peripherie" },
	{ "Glace_Sapin", -258.84, 94.978, 285.839, 180.26, 1.698, 1.698, 1.698, false, "peripherie" },
	{ "Glace_Pic", -208.999, -1, 322.967, 144.35, 3.4, 4.012, 3.4, false, "peripherie" },
	{ "Glace_Glacier", -148.552, -1, 353.627, 157.15, 2.0, 3.294, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -156.318, 94.593, 362.306, 96.02, 1.384, 1.384, 1.384, false, "peripherie" },
	{ "Glace_Sapin", -142.647, 94.593, 363.211, 32.08, 1.78, 1.78, 1.78, false, "peripherie" },
	{ "Glace_Glacier", -87.588, -1, 369.444, 171.3, 2.0, 3.886, 1.6, false, "peripherie" },
	{ "Glace_Sapin", -108.227, 112.105, 369.94, 174.32, 1.613, 1.613, 1.613, false, "peripherie" },
	{ "Glace_Sapin", -82.394, 112.105, 380.75, 7.58, 1.693, 1.693, 1.693, false, "peripherie" },
	{ "Glace_Pic", 2.438, -1, 377.695, 182.78, 3.4, 4.531, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 62.669, -1, 376.429, 186.64, 2.0, 3.175, 1.6, false, "peripherie" },
	{ "Glace_SapinPetit", 68.108, 91.052, 381.385, 340.02, 1.633, 1.633, 1.633, false, "peripherie" },
	{ "Glace_SapinPetit", 51.066, 91.052, 386.913, 123.35, 1.32, 1.32, 1.32, false, "peripherie" },
	{ "Glace_Glacier", 141.228, -1, 352.9, 202.77, 2.0, 3.107, 1.6, false, "peripherie" },
	{ "Glace_Sapin", 165.718, 89.049, 353.648, 333.74, 1.716, 1.716, 1.716, false, "peripherie" },
	{ "Glace_Sapin", 133.671, 89.049, 367.353, 167.84, 1.618, 1.618, 1.618, false, "peripherie" },
	{ "Glace_Pic", 189.882, -1, 326.268, 214.02, 3.4, 4.502, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 243.049, -1, 291.472, 219.01, 2.0, 3.635, 1.6, false, "peripherie" },
	{ "Glace_Sapin", 231.961, 104.691, 312.037, 337.46, 1.534, 1.534, 1.534, false, "peripherie" },
	{ "Glace_Sapin", 240.978, 104.691, 305.473, 177.31, 1.766, 1.766, 1.766, false, "peripherie" },
	{ "Glace_Glacier", 292.14, -1, 240.662, 232.19, 2.0, 3.255, 1.6, false, "peripherie" },
	{ "Glace_Sapin", 310.111, 93.42, 227.811, 4.96, 1.871, 1.871, 1.871, false, "peripherie" },
	{ "Glace_Sapin", 294.169, 93.42, 248.77, 43.39, 1.654, 1.654, 1.654, false, "peripherie" },
	{ "Glace_Pic", 339.023, -1, 168.727, 240.38, 3.4, 4.044, 3.4, false, "peripherie" },
	{ "Glace_Glacier", 358.881, -1, 123.344, 255.06, 2.0, 3.6, 1.6, false, "peripherie" },
	{ "Glace_Sapin", 358.936, 103.656, 142.718, 149.43, 1.653, 1.653, 1.653, false, "peripherie" },
	{ "Glace_Sapin", 363.581, 103.656, 124.859, 250.02, 1.764, 1.764, 1.764, false, "peripherie" },
	{ "Glace_Glacier", 380.91, -1, 30.942, 262.66, 2.0, 3.076, 1.6, false, "peripherie" },
	{ "Glace_Sapin", 389.878, 88.114, 38.816, 246.71, 1.562, 1.562, 1.562, false, "peripherie" },
	{ "Glace_Sapin", 390.432, 88.114, 20.89, 40.09, 1.517, 1.517, 1.517, false, "peripherie" },
	{ "Glace_Pic", 665.689, -6, 0.219, 301.01, 9.207, 12.237, 9.341, false, "lointain" },
	{ "Glace_Pic", 546.858, -6, -241.435, 341.36, 10.771, 13.674, 10.849, false, "lointain" },
	{ "Glace_Pic", 445.567, -6, -399.481, 153.67, 10.925, 14.374, 12.792, false, "lointain" },
	{ "Glace_Pic", 281.361, -6, -483.447, 154.54, 11.184, 14.269, 12.156, false, "lointain" },
	{ "Glace_Pic", 99.001, -6, -711.786, 11.24, 12.366, 14.982, 9.844, false, "lointain" },
	{ "Glace_Pic", -145.793, -6, -616.195, 340.22, 12.303, 13.501, 10.158, false, "lointain" },
	{ "Glace_Pic", -253.955, -6, -522.317, 264.38, 11.497, 13.785, 9.18, false, "lointain" },
	{ "Glace_Pic", -519.711, -6, -356.497, 232.12, 11.968, 13.988, 11.193, false, "lointain" },
	{ "Glace_Pic", -568.079, -6, -200.019, 351.64, 10.382, 12.143, 10.434, false, "lointain" },
	{ "Glace_Pic", -674.349, -6, -40.178, 178.36, 12.555, 12.058, 10.008, false, "lointain" },
	{ "Glace_Pic", -532.545, -6, 150.566, 204.88, 9.187, 12.979, 10.745, false, "lointain" },
	{ "Glace_Pic", -412.883, -6, 411.319, 125.35, 11.768, 13.157, 12.505, false, "lointain" },
	{ "Glace_Pic", -393.226, -6, 552.711, 161.82, 10.636, 12.94, 9.345, false, "lointain" },
	{ "Glace_Pic", -118.181, -6, 558.169, 274.85, 11.674, 15.336, 10.952, false, "lointain" },
	{ "Glace_Pic", 50.89, -6, 551.342, 237.75, 12.855, 13.15, 11.803, false, "lointain" },
	{ "Glace_Pic", 287.914, -6, 585.382, 281.89, 9.109, 14.021, 11.209, false, "lointain" },
	{ "Glace_Pic", 449.75, -6, 378.182, 94.9, 11.695, 14.644, 9.526, false, "lointain" },
	{ "Glace_Pic", 662.611, -6, 221.304, 315.13, 11.779, 12.658, 9.511, false, "lointain" },
	{ "Glace_Pic", 719.334, -4, -126.838, 337.45, 7.887, 7.887, 7.887, false, "lointain" },
	{ "Glace_Pic", 376.419, -4, -679.078, 270.38, 6.253, 6.253, 6.253, false, "lointain" },
	{ "Glace_Pic", -286.164, -4, -708.28, 157.82, 8.444, 8.444, 8.444, false, "lointain" },
	{ "Glace_Pic", -648.326, -4, -198.213, 103.24, 7.662, 7.662, 7.662, false, "lointain" },
	{ "Glace_Pic", -624.876, -4, 421.484, 56.18, 6.251, 6.251, 6.251, false, "lointain" },
	{ "Glace_Pic", -66.737, -4, 762.81, 69.26, 7.87, 7.87, 7.87, false, "lointain" },
	{ "Glace_Pic", 494.499, -4, 477.532, 185.3, 8.669, 8.669, 8.669, false, "lointain" },
}

-- Eau / lave (pièces Roblox, rien à envoyer) : kind, forme, x, y, z (centre), taille X, épaisseur, Z, yaw
local SURFACES = {
	{ "ice", "disc", 251.295, 0.13, -104.09, 30.0, 0.26, 30.0, 0.0 },
}

-- Décors qui éclairent (PointLight sans ombre, à une hauteur relative de la pièce) : seulement dans leur monde,
-- client/WorldSkin les éteint pour les joueurs des autres mondes.
local LIGHTS = {
	Glace_Igloo = { rel = -0.1, range = 14, brightness = 1.0 },
	Glace_Lanterne = { rel = 0.25, range = 20, brightness = 1.4 },
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
