# Carte « niveau studio » (phase 1.6, 25 oct. 2026) — proposition à valider

Habillage de la carte du jeu (ronde, trou noir au centre, 8 bases en anneau : plan validé le 13 oct.) avec des décors
faits par code dans Blender, cuits en PBR, et un éclairage réglé comme dans Roblox. **Rien n'est encore dans le jeu** :
c'est une proposition à juger sur les rendus, puis à brancher étape par étape.

Rendus : `qa_renders/map_hero.png` (depuis la base 1, face à l'arène), `qa_renders/map_aesthetic_board.png`
(survol, entrée de base, entrée de l'arène, colline, nuit, depuis le trou), `qa_renders/map_assets_board.png` (les 21
décors cuits). Charte : `map_art_bible.json`.

## Choix artistiques

- **Même langage que les familiers refaits** : blocs biseautés empilés, tenons Roblox sur les faces du dessus (pierre
  taillée, bois, feuillages), couleurs saturées. Les rochers naturels sont facettés, sans tenons.
- **Une cuvette** : la carte reste plate pour le jeu (lancers, objets, familiers), le relief est autour : collines en
  gradins adossées au mur entre les bases, puis 2 couronnes de falaises (55-75 et 85-110 studs) couronnées d'arbres
  derrière le mur, monts lointains dans la brume.
- **Le trou noir comme sanctuaire** : anneau de 24 dalles runiques, 8 arches anciennes sur les chemins, 16 totems à
  cristaux, obsidienne à veines violettes. Les runes et les champignons sont les repères lumineux de la nuit.
- **Chemins qui invitent** : sable doré, touffes d'herbe et petits champignons en bas-côtés, pancarte au départ.
- **Bases en bastions** : muret de pierre + palis taillés en pointe, arche d'entrée, escalier, caisses et tonneaux.
- Palette : chaude près des bases, froide (lilas, violet) vers le trou. Jour lumineux, nuit bleu nuit lisible.

## Lancer

Depuis `C:\Users\bouho\dev\getRichOrGetRobbed` (Blender 5.0 en arrière-plan) :

```bash
"/c/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup --python dataset_and_pipeline/blender_tools/run_map_assets.py -- --samples 16
"/c/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup --python dataset_and_pipeline/blender_tools/run_map_scene.py -- --samples 64
python dataset_and_pipeline/tools/make_map_look_script.py
```

1. `run_map_assets.py` (~10 min) : construit les 21 décors (`blender_tools/environment_recipes.py`, catalogue
   `BUILDERS`), les cuit (Color avec AO, Normal, Roughness, Metalness, Emissive) et les exporte dans
   `baked_assets/map/` (`.fbx`, PNG, manifestes, `map_assets_report.json`) + `source/map_assets.blend`.
   `--no-bake` : formes seules, planche `map_assets_shapes.png` en 1 min (pour régler une recette).
2. `run_map_scene.py` (~2 min) : pose ~940 décors cuits aux vraies dimensions du jeu (`Config.Arena`), rend les vues
   et écrit `baked_assets/map/map_layout.json` (positions en coordonnées Roblox). Le post-traitement reprend les
   réglages Roblox de la charte (Atmosphere, Bloom, ColorCorrection, exposition) ; nuit = préréglage « nuit ».
3. `make_map_look_script.py` : écrit `studio_tools/apply_map_look.lua` (éclairage + décors, données embarquées).

Le matériau « peint à la main » de `shader_node_library` a gagné les veinures de bois (`wood`, `wood_axis`,
`wood_scale`).

## Décors (budget 6 000 triangles, tous dedans)

Nature : RocherCalcaire A/B/C (570-950), RocherObsidienne A/B (~2 400, veines lumineuses), FalaiseGradins (5 616),
ArbreMajestueux A/B et ArbreCerisier (~4 200), ChampignonGeant (4 932, lamelles lumineuses), TouffeHerbe (440).
Civilisation : MurRuine (2 700), ArcheAncienne (3 348, runes), TotemEnergie (3 494, cristaux), DalleRunique (1 296),
EscalierPierre (1 512), Caisse (2 356), Tonneau (4 676), Pancarte (1 022), Palissade (3 084), PontBois (4 212).
Rochers et obsidienne cuits depuis une version détaillée (facettes ébréchées), le reste cuit sur lui-même.

## Passer dans Roblox (à faire avec Chouaib, rien n'est vérifié dans Studio)

1. Importer les `.fbx` de `baked_assets/map/` (Fichier > Importer 3D), ranger chaque MeshPart dans
   `ReplicatedStorage.ArtModels.Map.<Asset>`. Lueur : envoyer les `_Emissive.png` (outil MCP `upload_image`) et les
   poser en `EmissiveMaskContent` (l'importateur ne le fait pas, voir PIPELINE.md).
2. Lancer `studio_tools/apply_map_look.lua` en Édition (`MODE = "all"`). Il pose les décors dans `Workspace.MapDecor`
   (un Model Atomic par zone et par huitième de carte ; SLIM pour la périphérie), sans les décors des bases.
   À vérifier au premier essai : le sens du demi-tour des `.fbx` (`FBX_YAW_OFFSET`).
3. Garder le look en jeu : reporter les valeurs du préréglage dans `server/MapGenerator.applyLighting` et
   `server/DayNightController` (ils écrasent l'éclairage au Play) ; habiller les bases dans `MapGenerator`
   (remplacer les clôtures par les palissades, l'arche à l'entrée) plutôt que par-dessus.

## Règles de jeu respectées par le placement

Chemins et cercle du trou sans collision décorative ; anneau des objets sauvages (r 70-160) : seulement herbe et
champignons sans collision (un objet sauvage tombe de Y = 6 n'importe où dans l'anneau) ; obsidienne à r 57, avant
l'anneau ; gros décors avec collision entre les bases (r > 225) ; kiosques et tableau des scores dégagés ; tout décor
`CanQuery = false`, `CanTouch = false`, collision en boîte. StreamingEnabled : ne pas l'activer d'un coup (BasePets,
Eggs, WorldSkin supposent la carte entière présente).

## Vérifié / pas vérifié (25 oct.)

- Vérifié dans Blender : les 21 décors cuits sous 6 000 triangles, UV sans chevauchement (Caisse 3,9 %), cuit fidèle
  aux formes (`map_assets_board.png`), scène complète rendue de jour et de nuit, placement exporté (938 décors).
- Pas vérifié : import des décors dans Studio, rendu sous l'éclairage Roblox, performance (surtout téléphone),
  `apply_map_look.lua` jamais lancé, collisions et parcours des joueurs autour des arches.
- Limites vues sur les rendus : les falaises répètent le même module (varier : 2e module, rochers à leur pied) ;
  le mur d'enceinte reste une grande bande unie (piste : le remplacer par une falaise) ; la prairie sauvage est
  volontairement dégagée (jeu) ; la vue aérienne reste un peu brumeuse.
