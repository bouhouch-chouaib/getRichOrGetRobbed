# Modèles 3D des familiers

Chaque fichier `<IdDuFamilier>.rbxm` de ce dossier devient `ReplicatedStorage.PetModels.<IdDuFamilier>` (via Rojo)
et remplace automatiquement le modèle de remplacement en formes de base (cf. `src/shared/PetModelBuilder.lua`).

Les Id sont dans `src/shared/PetCatalog.lua` (ex. `CapybaraZen`, `SigmaBoy`, `StrawberryElephant`).

Pour en ajouter un :
1. Dans Roblox Studio, importer le fichier 3D (.fbx / .obj / .glb) avec **Accueil > Importer 3D**.
2. Renommer le Model importé exactement comme l'Id du familier.
3. Clic droit sur le Model > **Enregistrer dans un fichier…** > l'enregistrer ici en `<Id>.rbxm`.
