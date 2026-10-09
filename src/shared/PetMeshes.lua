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

-- Générés dans Studio le 9 oct. 2026 (tous regardent déjà vers -Z : FacingYaw = 0).
local PetMeshes: { [string]: MeshDef } = {
	-- Sigma
	BaleineGalaxie = { MeshId = "rbxassetid://92775947152560", TextureId = "rbxassetid://71989181481802", FacingYaw = 0 },
	OuroborosInfini = { MeshId = "rbxassetid://86861216561963", TextureId = "rbxassetid://97000627844161", FacingYaw = 0 },
	FougereFibonacci = { MeshId = "rbxassetid://87273920925171", TextureId = "rbxassetid://108959383081440", FacingYaw = 0 },
	CanardTractopelle = { MeshId = "rbxassetid://73107475676084", TextureId = "rbxassetid://124439842039113", FacingYaw = 0 },
	-- Divin
	TRexPoche = { MeshId = "rbxassetid://72460497913978", TextureId = "rbxassetid://95091502209778", FacingYaw = 0 },
	LeviathanAbyssal = { MeshId = "rbxassetid://132685214769465", TextureId = "rbxassetid://76401423279873", FacingYaw = 0 },
	PhenixSolaire = { MeshId = "rbxassetid://82805689012774", TextureId = "rbxassetid://105454532557275", FacingYaw = 0 },
	CarniflorToxique = { MeshId = "rbxassetid://133585764726309", TextureId = "rbxassetid://94478411479170", FacingYaw = 0 },
	GraineEtoile = { MeshId = "rbxassetid://113465033696541", TextureId = "rbxassetid://103161541753539", FacingYaw = 0 },
	GolemDistributeur = { MeshId = "rbxassetid://130788365043706", TextureId = "rbxassetid://114028985439860", FacingYaw = 0 },
	LionEnceinte = { MeshId = "rbxassetid://106669459511217", TextureId = "rbxassetid://97210094075955", FacingYaw = 0 },
	MachineQuantique = { MeshId = "rbxassetid://72500701004219", TextureId = "rbxassetid://72610471027136", FacingYaw = 0 },
	DragonAurore = { MeshId = "rbxassetid://84192935982751", TextureId = "rbxassetid://85583712268098", FacingYaw = 0 },
}

return PetMeshes
