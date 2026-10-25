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

## Dans Studio (fait le 25 oct., style validé par Chouaib)

1. Export : `blender_tools/export_map_lot.py` -> `baked_assets/map/Decors_Carte.fbx` (21 décors, vraie taille en studs,
   global_scale 0,01). Chouaib l'importe (Fichier > Importer 3D, réglages par défaut) : 21 MeshParts avec leur
   SurfaceAppearance (couleur, relief, rugosité, métal) dans `Workspace.Decors_Carte`.
2. Lueur : les 6 `_Emissive.png` envoyés avec `upload_image` (Id dans `baked_assets/map/map_roblox.json`).
3. `studio_tools/apply_map_look.lua` (88 Ko : trop gros pour la barre MCP, passer par un `.rbxm` : projet Rojo
   `{ "MapLook": { "$path": "apply_map_look.lua" } }` -> `claude_maplook.rbxm` copié dans le dossier `content` de Studio,
   puis `require(game:GetObjects("rbxasset://claude_maplook.rbxm")[1].MapLook)`). Résultat : 21 décors rangés dans
   `ReplicatedStorage.ArtModels.Map` (lueurs posées, import supprimé), éclairage « jour », 642 décors dans
   `Workspace.MapDecor` (les 296 des bases ignorés). **Le tout est dans le fichier du jeu : Ctrl+S puis Publier.**
4. Sens vérifié par mesure : la face en marches d'une falaise importée est son -Z ; les 122 falaises et arches posées
   regardent le trou noir (`FBX_YAW_OFFSET = 180` juste).
5. Textures : 2 couleurs de l'import restaient grises (FalaiseGradins, RocherCalcaire_A) alors que l'image est bonne :
   renvoyées à la main (`color_override` de `map_roblox.json`, reprises par le script), en attente de la modération
   Roblox au moment de l'écriture.

Éclairage en jeu (25 oct., code) : `server/MapGenerator.applyLighting` pose le préréglage « jour » (Atmosphere,
Bloom, ColorCorrection, DepthOfField, SunRays, latitude, échelles d'environnement, ombres douces) ;
`server/DayNightController` fait varier en plus le bloom, le contraste, Glare et Haze entre jour et nuit ; l'air de la
Prairie (`shared/Worlds`) reprend la couleur, la densité, la teinte et la saturation de la charte (les autres mondes
gardent leur air). La couleur de l'air de nuit de la charte n'est pas appliquée (elle se battrait avec WorldSkin).

Bases habillées (25 oct., code, **Prairie seulement** : chaque monde aura plus tard son propre habillage) :
`server/MapGenerator.createPrairieDressing` copie d'`ArtModels.Map` 27 palissades (rail vers l'extérieur ; 3 étirées de
chaque côté de l'entrée), l'arche ancienne sur l'entrée et l'escalier devant (hauteur = plateforme), sans collision,
dans le dossier `PrairieLook` de chaque base. L'ancienne clôture reste (collisions, porte, verrou inchangés) et
`client/WorldSkin` montre l'une ou l'autre selon le monde du propriétaire de la base ; les décors de l'arène
(`Workspace.MapDecor`) ne sont visibles et solides que pour un joueur en Prairie (CanCollide local), et remplacent alors
les arbres en cubes. Vérifié en Play (solo) : 29 pièces par base, bascules, entrée à pied, photo
`qa_renders/map_roblox_entree_base.jpg`. Déjà vrai avant : le personnage enjambe la clôture (rail bas à 1,9 stud),
donc on traverse aussi les palissades à côté de l'entrée.

Décision de Chouaib (25 oct.) : les bases restent ouvertes comme avant (on enjambe la clôture), pas de mur invisible.

Reste à faire : regarder la performance sur téléphone.

## Règles de jeu respectées par le placement

Chemins et cercle du trou sans collision décorative ; anneau des objets sauvages (r 70-160) : seulement herbe et
champignons sans collision (un objet sauvage tombe de Y = 6 n'importe où dans l'anneau) ; obsidienne à r 57, avant
l'anneau ; gros décors avec collision entre les bases (r > 225) ; kiosques et tableau des scores dégagés ; tout décor
`CanQuery = false`, `CanTouch = false`, collision en boîte. StreamingEnabled : ne pas l'activer d'un coup (BasePets,
Eggs, WorldSkin supposent la carte entière présente).

## Vérifié / pas vérifié (25 oct.)

- Vérifié dans Blender : les 21 décors cuits sous 6 000 triangles, UV sans chevauchement (Caisse 3,9 %), cuit fidèle
  aux formes (`map_assets_board.png`), scène complète rendue de jour et de nuit, placement exporté (938 décors).
- Vérifié dans Studio (Édition + Play solo) : import, script lancé, décors à leur place autour de la vraie carte
  (anneau d'arches, arbres et ruines entre les bases, falaises derrière le mur), sens des falaises et arches.
- Pas vérifié : la couleur des 2 textures renvoyées (modération), performance (surtout téléphone), collisions et
  parcours des joueurs autour des arches.
- Vérifié en Play (solo, 25 oct.) : l'éclairage de la charte la nuit (au démarrage) puis le jour après la transition,
  valeurs relues sur le serveur, pas d'erreur ; photos `qa_renders/map_roblox_nuit.jpg` et `map_roblox_jour.jpg`.
- Limites vues sur les rendus : les falaises répètent le même module (varier : 2e module, rochers à leur pied) ;
  le mur d'enceinte reste une grande bande unie (piste : le remplacer par une falaise) ; la prairie sauvage est
  volontairement dégagée (jeu) ; la vue aérienne reste un peu brumeuse.

---

# Monde 2 : Désert (25 oct. 2026) — proposition à valider

Même méthode que la Prairie, **chaque monde a la sienne** (décision de Chouaib) : charte `map_art_bible_desert.json`
(« L'Oasis des Pharaons oubliés », d'après les 5 familiers du Désert), 19 décors dans `blender_tools/environment_desert.py`,
rendus `qa_renders/map_hero_desert.png`, `map_aesthetic_board_desert.png`, `map_assets_board_desert.png`.

- **Aucune lueur** dans ce monde : pas d'émission, donc aucun `_Emissive.png` à envoyer (avertissement de modération du
  25 oct. sur ce type d'image). L'accent froid est le turquoise émaillé (dalles, bandeaux, hiéroglyphes) avec l'or.
- Décors (tous < 6 000 triangles) : Mesa (canyon en strates crème / rouge brique, terrasses de sable doré), RocherGres A
  (cheminée de fée) et B, ArcheNaturelle, Saguaro, CactusTonneau, Figuier, Palmier, Touffe (herbe sèche), Fossile
  (cage thoracique géante), Obelisque, ColonneBrisee, PorteTemple (pylônes, disque solaire), Dalle (disque solaire),
  Muret (fort d'adobe crénelé, poutres), Escalier (grès), Jarre, Auvent, Brasero. Caisse et Pancarte : celles de la
  Prairie (déjà dans `ArtModels.Map`).
- Placement : `run_map_scene.py --world Desert` (même plan et mêmes règles de jeu que la Prairie ; chaque monde choisit
  un décor par rôle dans `WORLD_CFG`) -> `baked_assets/map/desert/map_layout.json` (943 décors).
- Lancer : `run_map_assets.py -- --world Desert`, `run_map_scene.py -- --world Desert`,
  `export_map_lot.py -- --world Desert` (-> `baked_assets/map/desert/Decors_Desert.fbx`, 19 décors, 34 Mo).

Reste à faire après validation : import de `Decors_Desert.fbx` (l'importateur envoie les textures sur le compte de
Chouaib : avec son accord), ranger la carte par monde (`Workspace.MapDecor.<Monde>`, `ArtModels.Map`), habillage des
bases au Désert (muret, porte de temple, escalier) dans `MapGenerator` + bascule par monde dans `WorldSkin`, air du
Désert dans `shared/Worlds` (valeurs de la charte), braseros allumés la nuit (PointLight + feu de particules Roblox).

