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
| `blender_tools/run_cerberus_blocks.py` | Cerbère en un seul maillage (image de présentation : planche + héros). |
| `blender_tools/run_cerberus_rig.py` | **Le Cerbère du jeu** : 12 pièces animées, 3 textures, `.fbx` + `rig.json` (`source/cerberus_rig.blend`). |
| `studio_tools/wire_cerberus_rig.lua` | Après l'import du `.fbx` : branche les pièces sur `PetMotion` et range le modèle dans `ArtModels`. |
| `blender_tools/export_studio_mesh.py` | `.mesh` natif Roblox pour voir un asset dans Studio sans import (aperçu local). |
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

## Essai 1.5 : Cerbère Secret en blocs (25 oct.)

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

**Auras : toutes refusées pour le Cerbère** (25 oct.) : anneau modélisé, aura de particules maison, puis flammes noires +
éclairs faits d'effets du Creator Store (« très mal fait, je n'aime pas du tout le rendu »). Le Cerbère n'a plus aucune
aura (`PetSculptedEffects.NO_AURA`). Ne pas en reproposer sans demande de Chouaib. Si un jour on reprend des effets du
Creator Store : `insert_asset` dans `ServerStorage`, lire les scripts d'abord (les écrans « CoreValidation » / TextBox
« Check » cachés dans des effets gratuits sont un piège connu), ne garder que les images.

**Contrôle en Play** (particules, familiers qui bougent) : les particules ne s'affichent que près de la caméra du joueur.
Téléporter le personnage (serveur), mettre la caméra en `Scriptable` (client, qui suit le familier par RenderStepped),
masquer les ScreenGui, puis `screen_capture` SANS position de caméra. Studio en arrière-plan tourne à ~15 images/s.

**Import Studio du `.fbx`** (25 oct.) : sans réglage, Studio lit 1 unité Blender = 100 studs (d'où `global_scale` dans
`run_cerberus_rig.py`, ~13 studs à l'import) ; l'import regarde déjà vers -Z (`FacingYaw` 0, contrairement au `.mesh`
exporté à la main) et la correspondance des axes est Blender (x, y, z) -> Studio (-x, z, y). L'importateur envoie
maillages et textures (couleur, relief, rugosité, métal) sur le compte, mais **pas la lueur** : envoyer les
`_Emissive.png` avec `upload_image` et les poser en `EmissiveMaskContent`.

## Cerbère animé (2e version, 25 oct.)

Retour de Chouaib sur la 1re version en jeu : peau « pas folle », rien ne bougeait. Causes : UNE texture de 1024 px pour
tout le Cerbère, découpée en ~1 000 îlots minuscules (flou, couleurs qui bavent entre îlots au loin, lueur perdue à
l'import) et UN seul maillage. Recette (à suivre pour tout familier animé) :

```bash
"/c/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup --python dataset_and_pipeline/blender_tools/run_cerberus_rig.py
```

1. **Découpe** (`build_blocky_cerberus(rig=True)`) : chaque bloc dit à quelle pièce il appartient (Body, Head0-2,
   Jaw0-2, LegFL/FR/BL/BR, Tail) ; pivots en Matrix (base du crâne, charnière de la mâchoire, épaule, hanche, base de la
   queue), orientés comme la pièce (une tête de côté tourne autour de SON axe). Gueules entrouvertes au repos (14°).
2. **Une texture par zone** : pièces regroupées en 3 atlas de 1024 (Tetes, Corps, Pattes), cuits ensemble (attribut de
   face `rig_id`) puis recoupés ; marges UV 0,006 et 16 px d'extension.
3. **Export** : `CerbereInfernal_Rig.fbx` (12 objets nommés comme les MeshParts du jeu) + `CerbereInfernal_rig.json`
   (pivots, genres de mouvement, phases). Planche : `qa_renders/cerberus_rig_board.png` (repos, pose animée, têtes).
4. **Studio** : Chouaib importe le `.fbx`, puis `studio_tools/wire_cerberus_rig.lua` (barre MCP) pose sur chaque pièce
   `MotionGroup` / `MotionKind` / `MotionPhase` / `MotionPivotRaw` (+ `MotionHingeRaw` pour une mâchoire, avec le pivot de
   sa tête), la lueur, et range le modèle dans `ReplicatedStorage.ArtModels.CerbereInfernal` (sauvegarder le jeu).
5. **Jeu** (`shared/PetMotion`) : « Head » regarde autour (têtes de côté vers l'extérieur), aboie (relève la tête,
   gueule grande ouverte), hoche au pas ; « Jaw » suit sa tête puis s'ouvre autour de sa charnière ; pattes « Leg »
   en diagonale, queue « Tail », profil « Cerberus » (souffle lourd, le corps monte à chaque foulée).

Vérifié en jeu (solo, 25 oct.) : 12 pièces, têtes indépendantes, mâchoire à 21° pendant un aboiement, trot,
peau nette de jour et de nuit (`qa_renders/cerberus_anime_face.jpg`, `_nuit.jpg`, `_marche.jpg`).

## Pistes pour la suite

- Une recette `build_pet_<forme>()` par silhouette de `PetCatalog` (quadrupède, oiseau, blob, plante, objet), à partir
  de `rounded_blob` + `curve_tube` + `voxel_fuse`.
- Cuisson par pièce pour garder Leg / Ear animables.
- Les 5 coquilles d'œufs de `egg_shells` (la Mythique est faite).
- Comparer une capture Studio de l'asset importé avec `hero.png` (outil MCP Roblox `screen_capture`).
