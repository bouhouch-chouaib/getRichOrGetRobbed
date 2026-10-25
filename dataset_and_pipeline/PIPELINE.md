# Pipeline 3D procédural (phase 1) — Blender → Roblox

Boîte à outils pour fabriquer des modèles 3D de qualité « jeu de studio » **par code** dans Blender, les cuire en
textures PBR et les exporter pour Roblox. Faite le 25 oct. 2026 (Blender 5.0, GPU GTX 1650 en CUDA).
Preuve de concept : un piédestal de base et un œuf Mythique (`qa_renders/hero.png`).

## Ce qu'il y a dans le dossier

| Fichier | Rôle |
|---|---|
| `game_design_matrix.json` | 20 familiers du jeu classés Common / Rare / Epic / Mythic / Secret : stats calculées depuis `Config.lua` (taille, poids, ralentissement du voleur, revenu, chance de tirage) + fiche 3D (silhouette, palette, matériaux, accessoires, budget de triangles) ; 5 coquilles d'œufs ; règles de la boucle de jeu (« game » = valeur actuelle, « proposed » = idée chiffrée) ; repères relevés sur Steal a Brainrot, Steal an Egg, Pet Simulator 99 et Sol's RNG (ordres de grandeur seulement, sources citées). |
| `tools/build_game_design_matrix.py` | Régénère le JSON : `python dataset_and_pipeline/tools/build_game_design_matrix.py` (à relancer après un rééquilibrage). |
| `blender_tools/shader_node_library.py` | 4 familles de matériaux en nœuds + tenons. |
| `blender_tools/procedural_geometry_recipes.py` | Constructeurs de formes, piles de modificateurs, assemblages de référence. |
| `blender_tools/auto_pbr_baker.py` | UV automatiques, cuisson Cycles, PNG, FBX / GLB, manifeste. |
| `blender_tools/visual_qa_renderer.py` | Studio 3 points, 4 vues, planche `preview.png` + rapport chiffré. |
| `blender_tools/run_poc.py` | Exemple complet (piédestal + œuf + planche des matériaux). |
| `blender_tools/block_creatures.py` | Créatures en blocs biseautés (essai 1.5) : `block`, `stepped_plate`, `staircase_spike`, `tooth`, `claw`, `spike_band`, `blocky_wolf_head`, `build_blocky_cerberus`. |
| `blender_tools/run_cerberus_blocks.py` | Fabrique, cuit et contrôle le Cerbère (`source/cerberus_blocs.blend`, planche + héros). |
| `blender_tools/export_studio_mesh.py` | `.mesh` natif Roblox pour voir un asset dans Studio sans import (aperçu local). |
| `vfx_tools/CerbereAura.lua` | Aura du Cerbère (flammes noires et rouges + éclairs) faite avec des effets du Creator Store. |
| `baked_assets/` | Sorties prêtes pour Roblox (`<Asset>_Color/Roughness/Metalness/Normal/Emissive/AO.png`, `.fbx`, `.glb`, `_manifest.json`). |
| `qa_renders/` | `preview.png` (contrôle), `materials.png` (les 4 matériaux), `hero.png`, rapports JSON. |
| `source/poc_phase1.blend` | La scène de la preuve de concept (high, low cuits, matériaux). |

## Lancer

Sans ouvrir Blender (le plus fiable, ~2 min 20 en qualité finale) :

```bash
"/c/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup --python dataset_and_pipeline/blender_tools/run_poc.py -- --res 1024 --qa-res 420 --samples 32 --qa-samples 48
```

Essai rapide : `-- --res 256 --qa-res 200 --samples 8 --qa-samples 12` (~40 s). Lancer depuis
`C:\Users\bouho\dev\getRichOrGetRobbed` (chemin sans accents).

Dans le Blender ouvert (connecteur MCP Blender, `execute_blender_code`) : `run_poc.py` crée sa propre scène
« POC_Pipeline » sans toucher au reste :

```python
p = r"C:\Users\bouho\dev\getRichOrGetRobbed\dataset_and_pipeline\blender_tools\run_poc.py"
exec(open(p, encoding="utf-8").read(), {"__file__": p, "__name__": "__main__"})
```

Pour un nouvel asset, importer les modules :

```python
import sys, importlib; sys.path.insert(0, r"C:\Users\bouho\dev\getRichOrGetRobbed\dataset_and_pipeline\blender_tools")
import shader_node_library as S, procedural_geometry_recipes as G, auto_pbr_baker as B, visual_qa_renderer as Q
for m in (S, G, B, Q): importlib.reload(m)
```

## La chaîne, étape par étape (phase 2 : production)

1. **Lire la fiche** de l'asset dans `game_design_matrix.json` (`creatures[].spec_3d` ou `egg_shells[]`) : silhouette,
   palette, `materials[].preset` + `params`, accessoires, `tri_budget`.
2. **Matériaux** : `S.from_spec(nom, preset, params)` ou appel direct (`S.create_etched_metal_or_gold(tint="#FFC830", ...)`).
3. **Formes** (jamais une primitive posée telle quelle) :
   - profils de révolution : `G.lathe(nom, [(rayon, z), ...], segments, twist_alternate=True pour une taille gemme)`,
     `G.egg_profile()`, `G.ring_profile()` (tores, bagues) ;
   - tubes le long d'une courbe : `G.curve_tube()` (griffes, tentacules, queues, anses) ;
   - `G.crystal()`, `G.crystal_cluster()` (écrivent les attributs `grad` et `facet` lus par le cristal) ;
   - `G.rounded_blob()` = ellipsoïde à fondre (corps, perles), jamais seul.
4. **Finition** :
   - surfaces dures : `G.add_bevel_finish(obj, width, segments=3, profile=0.7)` (Bevel + Weighted Normal + lissage par angle) ;
   - organique : `G.add_organic_displace(obj, texture="CLOUDS" | "VORONOI" | "MUSGRAVE", strength, size, subdiv)` ;
   - plusieurs pièces en une peau continue : `G.voxel_fuse(pièces, nom, voxel_size)` puis `G.make_low(high, budget)`
     (Voxel Remesh + Corrective Smooth ; les zones de matériaux sont retrouvées par proximité).
5. **Haute / basse définition** : le high garde tout le détail (déplacement, surface fondue), le low respecte le budget
   (< 8 000 triangles ; limite Roblox 20 000). Pièces identiques dans les deux : `G.duplicate()`. Puis
   `high = G.join([...], "X_high")`, `low = G.join([...], "X_low")`. Voir `build_stylized_pedestal()` et
   `build_mythic_gem_egg()`, écrits pour servir de modèle.
6. **Cuire** : `report = B.bake_asset(low, "NomAsset", high=high)` (sans `high` : cuit l'objet sur lui-même).
   Sortie dans `baked_assets/`, le low porte ensuite le matériau cuit (aperçu fidèle à Roblox).
7. **Contrôler** : `Q.render_qa_grid([{"label": ..., "objects": [high], "kind": "procedural"}, {"label": ...,
   "objects": [low], "kind": "baked"}])`, puis **ouvrir `qa_renders/preview.png` avec l'outil de lecture d'image**
   (obligatoire). Bandeau orange = procédural, vert = cuit. Corriger les scripts et relancer tant que ça fait
   « assemblage de primitives », « plat » ou que le cuit diffère du procédural. `Q.render_hero()` pour une image soignée.
8. **Roblox** (pas encore testé, voir plus bas).

## Règles à respecter (sinon le cuit trahit le rendu Blender)

- **Contrat BAKE_BSDF** : un matériau = un seul Principled BSDF nommé `BAKE_BSDF`, branché sur la sortie, pas de Mix
  Shader. Le baker branche tour à tour Base Color, Roughness, Metallic, une AO locale et Emission Strength sur une
  Emission et cuit en EMIT (la passe DIFFUSE de Cycles rendrait l'or noir).
- **Lueur = couleur de la surface** : Roblox calcule ColorMap × masque × EmissiveTint. Seule l'intensité varie
  (Emission Strength constante ou masque). Une lueur d'une autre couleur ne se cuit pas (c'était la cause des taches
  sombres du premier œuf cuit).
- **Fresnel, anisotropie, SSS, Coat** : rendu Blender seulement (la cuisson regarde la surface de face). Le dégradé
  d'un cristal vient de l'attribut `grad` + des arêtes lumineuses, qui eux se cuisent. Garder `top` < 1 dans
  `write_grad_attribute` pour qu'une gemme reste saturée.
- **Tenons** : `studs=1.0` (vrai tenon Roblox) sur `create_stylized_edge_wear_material`, pour les décors et socles.
  **Pas de tenons sur les familiers** (Chouaib, 25 oct. : « on ne comprend plus grand chose »). Seulement sur les faces
  tournées vers le haut, comme dans Roblox. Ils passent par la Normal map : **pas de
  TextureID** (un SurfaceAppearance le masquerait).
- **Néon interdit pour le volume** : la lumière passe par `_Emissive.png` (EmissiveMaskContent).
- **Unités** : 1 unité Blender = 1 stud, pivot au sol au centre, devant = -Y Blender. `use_auto_smooth` n'existe plus
  depuis Blender 4.1 : `G.smooth_by_angle()`.
- **API Blender 5.0** : chercher les nœuds par type ou identifiant, jamais par nom affiché ; `angle_limit` de Smart UV
  est en radians ; Musgrave n'existe plus en nœud (Noise type RIDGED_MULTIFRACTAL), il reste en texture de Displace.

## Côté Roblox (phase 2, non vérifié)

1. Studio : Fichier > Importer 3D > `baked_assets/<Asset>.fbx` (même chemin que les modèles de `assets/models`).
   À vérifier : si l'importateur crée lui-même le SurfaceAppearance à partir des textures incluses dans le .fbx.
2. Sinon : ajouter un `SurfaceAppearance` dans la MeshPart, y mettre `ColorMap`, `NormalMap`, `RoughnessMap`,
   `MetalnessMap` (et `EmissiveMaskContent` + `EmissiveStrength` du manifeste, `EmissiveTint` blanc), AlphaMode Overlay.
   Les PNG s'envoient avec l'outil MCP Roblox `upload_image` (marche, vérifié le 25 oct. avec le Cerbère).
3. Ranger le modèle dans `ReplicatedStorage.ArtModels` comme les tapis et bancs (dans le fichier du jeu, pas dans git).
4. Familiers : noms de MeshParts attendus par `PetSculptedModels` (Body, Head, Leg, Ear...) si on veut l'animation
   `PetMotion` : cuire alors chaque pièce séparément (un appel `bake_asset` par pièce) ou une seule texture partagée.

## Ce qui est vérifié / pas vérifié (25 oct.)

- Vérifié (Blender 5.0, en arrière-plan) : toute la chaîne sans erreur ; piédestal 4 960 triangles, œuf 6 440 ; UV sans
  chevauchement (0 %) ; cartes Color / Roughness / Metalness / Normal / Emissive / AO + FBX + GLB ; rendu cuit fidèle
  au procédural (planche `preview.png`) ; les 4 familles de matériaux (`materials.png`) ; cuisson sans high.
- **Rendu validé par Chouaib le 25 oct.** (`qa_renders/hero.png`) : c'est le niveau de qualité minimum pour la phase 2.
- Pas vérifié : import dans Roblox Studio, rendu des cartes dans Roblox (éclairage différent), envoi des PNG par le MCP
  Roblox, export GLB relu par un autre outil.

## Essai 1.5 : Cerbère Secret en blocs + aura (25 oct.)

**Style (validé par Chouaib après 3 essais refusés)** : ni jouet vinyle lisse (trop cartoon), ni voxels à tenons
(« Minecraft »). Des blocs et rectangles biseautés de tailles variées, inclinés et superposés comme des plaques
d'armure, pas trop épais, en suivant l'image de référence donnée : charbon fissuré de lave, rangées de dents, oreilles
en escalier, colliers et bracelets dorés à pointes, longues griffes, crêtes de cristal.

```bash
"/c/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup --python dataset_and_pipeline/blender_tools/run_cerberus_blocks.py
```

Résultat : 9 328 triangles en jeu (34 134 en high), 0 chevauchement entre les 3 têtes (`G.clipping_report`), UV sans
chevauchement (29 % de la texture remplie), `qa_renders/cerberus_qa_board.png` et `cerberus_hero.png` (sur le piédestal).
`G.set_detail("high" | "low")` règle segments / subdivisions / biseaux entre la version cuite et la version de jeu.

**Voir le modèle dans Studio sans import** (vérifié le 25 oct.) : `export_studio_mesh.py` écrit un `.mesh` natif ; on
le copie dans le dossier `content\claude\` de Studio puis `AssetService:CreateMeshPartAsync("rbxasset://claude/...")`
par la barre MCP. Les cartes PNG passent par l'outil MCP `upload_image` (envoyées sur le compte de Chouaib : Color
112772134269437, Normal 73370126848372, Roughness 116668183918093, Metalness 120152447623403, Emissive
137420531509006, EmissiveStrength 3,47). Aperçu local seulement : ne pas publier le jeu avec ce MeshPart.

**Aura = effets tout faits, jamais modélisée** (Chouaib : anneau modélisé puis aura de particules maison refusés) :
1. `search_asset` (Creator Store, gratuit) puis `insert_asset` dans `ServerStorage` (scripts mis en bac à sable,
   jamais lancés). Lire la liste des scripts avant tout : les écrans « CoreValidation » / TextBox « Check » cachés dans
   des effets gratuits sont un piège connu, on jette le modèle.
2. Ne garder que les **images** (Texture des ParticleEmitter), recréer les émetteurs par code, régler taille / couleur.
   Le Cerbère : `rbxassetid://935947741` (flammes noires) + `rbxassetid://9135310747` (éclair, planche 4x4), voir
   `vfx_tools/CerbereAura.lua`. Flammes avec ZOffset négatif : elles passent derrière le corps et dessinent la
   silhouette (effet haki d'anime) sans cacher la tête. Orientation `FacingCameraWorldUp` (sinon couchées au sol).
3. Contrôle en Play : les particules ne s'affichent que près de la caméra du joueur. Téléporter le personnage (serveur),
   mettre la caméra en `Scriptable` devant le familier, masquer les ScreenGui (client), puis `screen_capture`. Studio en
   arrière-plan tourne à ~15 images/s en qualité auto : il y a moins de particules (comme sur téléphone), d'où des
   flammes grandes. Photos : `qa_renders/cerberus_aura_nuit.jpg`, `cerberus_aura_nuit_34.jpg`, `cerberus_aura_jour.jpg`.

Pas vérifié : import du `.fbx` dans le vrai jeu, aura sur un familier qui marche dans la base (`PetMotion`), sur
téléphone, avec la qualité graphique au maximum.

## Pistes pour la suite

- Une recette `build_pet_<forme>()` par silhouette de `PetCatalog` (quadrupède, oiseau, blob, plante, objet), à partir
  de `rounded_blob` + `curve_tube` + `voxel_fuse`.
- Cuisson par pièce pour garder Leg / Ear animables.
- Les 5 coquilles d'œufs de `egg_shells` (la Mythique est faite).
- Comparer une capture Studio de l'asset importé avec `hero.png` (outil MCP Roblox `screen_capture`).
