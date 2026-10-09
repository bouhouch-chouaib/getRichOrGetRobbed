--!strict
-- PetMeshes : vrais modèles 3D des familiers, sous forme d'assets Roblox (forme + texture).
-- PetModelBuilder recrée ces modèles au démarrage (AssetService:CreateMeshPartAsync) et les utilise à la place
-- des modèles de remplacement. Ajouter un familier ici = il a son modèle 3D partout (base, suivi, collection...).
--   MeshId / TextureId : assets générés dans Studio (outil "generate_mesh") ou importés, appartenant au créateur du jeu.
--   FacingYaw : rotation (degrés) pour que le familier regarde vers -Z (0 si le modèle regarde déjà vers -Z).
--   HeightScale : ajuste la taille par rapport à la hauteur standard de sa rareté (1 par défaut).

export type MeshDef = {
	MeshId: string,
	TextureId: string,
	FacingYaw: number?,
	HeightScale: number?,
}

local PetMeshes: { [string]: MeshDef } = {
	BaleineGalaxie = { MeshId = "rbxassetid://92775947152560", TextureId = "rbxassetid://71989181481802", FacingYaw = 0 },
}

return PetMeshes
