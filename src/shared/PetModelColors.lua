--!strict
-- PetModelColors : couleurs des modèles 3D importés (assets/PetModels).
-- L'importeur 3D de Roblox ne reprend pas les couleurs des matières d'un .glb sans texture :
-- toutes les pièces arrivent grises. On les recolore ici, pièce par pièce (nom de la MeshPart).
-- Les valeurs viennent des matières du fichier .glb d'origine (converties en couleurs Roblox).

local PetModelColors: { [string]: { [string]: Color3 } } = {
	CapybaraZen = {
		["Cube.001"] = Color3.fromRGB(218, 118, 24), -- pelage roux doré
		["Cube.0012"] = Color3.fromRGB(255, 208, 82), -- ventre
		["Cube.0013"] = Color3.fromRGB(255, 174, 40), -- museau et pattes
		["Cube.0014"] = Color3.fromRGB(164, 66, 12), -- intérieur des oreilles
		["Cube.0015"] = Color3.fromRGB(33, 26, 18), -- yeux, nez, sourire
		["Cube.0016"] = Color3.fromRGB(255, 101, 0), -- orange
		["Cube.0017"] = Color3.fromRGB(68, 128, 12), -- tige
		["Cube.0018"] = Color3.fromRGB(93, 235, 10), -- feuille
		["Cube.0019"] = Color3.fromRGB(177, 255, 41), -- feuille (clair)
	},
}

return PetModelColors
