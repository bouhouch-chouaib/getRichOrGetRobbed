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

**Branché dans Studio (25 oct., style validé par Chouaib)** :
- Chouaib importe `Decors_Desert.fbx` (**Studio en mode Édition** : un import fait pendant un Play disparaît à l'arrêt,
  c'est arrivé une fois). `studio_tools/apply_map_look_desert.lua` (par `.rbxm` + `require`, comme la Prairie) range les
  19 décors dans `ArtModels.Map` (40 avec la Prairie), passe l'ancien rangement à plat dans `MapDecor.Prairie` et pose
  647 décors dans `Workspace.MapDecor.Desert` (les 296 des bases ignorés). Rien n'a été envoyé par Claude.
- Code par monde : `server/MapGenerator` crée dans chaque base un dossier `<Monde>Look` par monde dont les modèles
  sont dans `ArtModels.Map` (`DRESSINGS` : Prairie = Palissade / ArcheAncienne / EscalierPierre, Désert = Desert_Muret /
  Desert_PorteTemple / Desert_Escalier) ; `client/WorldSkin` montre l'habillage du monde du propriétaire de la base
  (sinon l'ancienne clôture) et `MapDecor.<Monde>` aux seuls joueurs de ce monde (sinon cachés et traversables), à la
  place des arbres en cubes / de l'ancien décor ; air du Désert dans `shared/Worlds`.
- Vérifié en Play (solo ; monde changé côté client seulement, rien dans la sauvegarde) : Prairie inchangée ; au Désert,
  29 pièces DesertLook par base, palissades / clôture / décors Prairie cachés, MapDecor.Desert visible, vieux cactus
  retirés ; aucun décor solide dans l'anneau des objets sauvages ; 124 canyons et portes tournés vers le trou ; photos
  `qa_renders/map_roblox_desert_nuit.jpg`, `map_roblox_desert_entree_base.jpg`. Avant les modèles, un joueur au Désert
  retrouvait bien l'ancien décor.
- Pas vu : deux joueurs de mondes différents en même temps, téléphone, braseros (pas posés : à allumer plus tard avec
  PointLight + feu de particules Roblox). Pour tester un monde sans l'acheter : côté client,
  `LocalPlayer:SetAttribute("World", 2)` et `SetAttribute("Tier", 2)` (le serveur les remet à la prochaine sauvegarde).

---

# Monde 3 : Volcan (25 oct. 2026) — proposition à valider

« La Forge du Titan » (charte `map_art_bible_volcan.json`, d'après les familiers du Volcan : Salamandre, Taupe Magma,
Golem de Cendre, Dragon Barbecue, Titan de Lave, Cerbère Infernal). 17 décors dans `blender_tools/environment_volcan.py`,
rendus `qa_renders/map_hero_volcan.png`, `map_aesthetic_board_volcan.png`, `map_assets_board_volcan.png`.

- **Aucune lueur** : la lave est une couleur (orange-jaune) et apparaît dans les creux du basalte (couleur des creux =
  orange) ; la vraie lumière vient du Neon déjà en jeu (chemins, haut du mur) et de PointLight posées par le script
  (piliers-braseros, cheminées, chaudrons, mare de lave), éteintes par `WorldSkin` pour les autres mondes. Rien à envoyer.
- Décors (< 6 000 triangles) : Orgues (basalte en colonnes hexagonales), Roche, Eclats (obsidienne), Cheminee,
  ArbreCalcine, Cristaux (cristaux de feu), Touffe (cendre), PorteForge, PilierBrasier, Enclume, Dalle, Rempart (piques de
  fer), Escalier, Chariot, Chaudron, Grill (du Dragon Barbecue), TeteGolem. Pancarte reprise de la Prairie.
- Scène : `run_map_scene.py -- --world Volcan` -> `baked_assets/map/volcan/map_layout.json` (889 décors + mare de lave) ;
  au loin, cônes de volcan géants (cheminées x30) ; un module de la couronne extérieure sur trois remplacé par des
  éclats d'obsidienne (casse l'effet « ville »). `export_map_lot.py -- --world Volcan` -> `Decors_Volcan.fbx` (33 Mo).
- **Branché dans Studio (25 oct., style validé par Chouaib)** : import de `Decors_Volcan.fbx` (Édition),
  `apply_map_look_volcan.lua` -> 17 décors dans `ArtModels.Map` (57 en tout), 593 posés dans `MapDecor.Volcan` + mare de
  lave ; 98 / 98 portes et orgues tournées vers le trou ; bases `VolcanLook`. Lumières : 37 PointLight (16 braseros du
  sanctuaire, 20 cheminées, la mare) ; celles des cônes lointains et de la périphérie sont retirées (inutiles, coûteuses).
- Vérifié en Play (solo, monde changé côté client) : au Volcan, VolcanLook visible (autres habillages cachés), 37 lumières
  allumées, vieilles roches de lave retirées ; de nuit, mare et cheminées éclairent le sol en rouge. Photos
  `qa_renders/map_roblox_volcan_jour.jpg`, `map_roblox_volcan_nuit_lave.jpg`. En Prairie : lumières du Volcan éteintes.
- Différence avec les rendus : en jeu le ciel reste bleu le jour (le jeu ne change pas le ciel selon le monde, seulement
  l'air) ; piste : un Sky par monde dans `client/WorldSkin`.

## Eau et lave en jeu (25 oct.)

Jusqu'ici l'eau (ruisseau et mare de la Prairie, oasis du Désert) n'existait que dans les rendus : le script ne posait que
les modèles (le pont de la Prairie ne franchissait rien). Désormais `run_map_scene.py` exporte aussi des `surfaces`
(disques et bandes) et les scripts Studio les créent en pièces Roblox simples (eau : Glass bleu transparent ; lave : Neon
orange + PointLight), sans collision, dans `MapDecor.<Monde>.surfaces`. Mares rendues rondes (un cylindre Roblox ne
peut pas être ovale). Prairie : 24 surfaces, Désert : 1, Volcan : 1. Les arbres posés sur les falaises de la Prairie sont
aussi remontés de ~1,6 stud (hauteur réelle de la falaise au lieu de 28,2). Relancé dans Studio le 25 oct. et vérifié en
Play : ruisseau sous le pont de la Prairie (`map_roblox_prairie_ruisseau.jpg`), oasis du Désert
(`map_roblox_desert_oasis.jpg`). Au changement de monde, les textures du nouveau monde mettent quelques secondes à
s'afficher (gris le temps du chargement).

---

# Monde 4 : Glace (25 oct. 2026) — proposition à valider

« Le Village Givré du Yéti » (charte `map_art_bible_glace.json`, d'après Pingouin Patineur, Morse Moustachu, Yéti Câlin,
Mammouth Glaçon, Narval Aurore). 17 décors dans `blender_tools/environment_glace.py`, rendus `qa_renders/map_hero_glace.png`,
`map_aesthetic_board_glace.png`, `map_assets_board_glace.png` (les 5 familiers du monde, déjà refaits, posent dans la base).

- **Aucune lueur** : vitres des lanternes et fenêtre de l'igloo en couleur chaude ; PointLight posées par le script
  (lanternes du sanctuaire, igloos), éteintes pour les autres mondes. Rien à envoyer.
- Décors (< 6 000 triangles) : Glacier (strates de glace, terrasses de neige), Sapin et SapinPetit (étages enneigés),
  Rocher (chapeau de neige), Cristaux, Congere, Touffe (herbe givrée), Pic (aiguilles de glace), BlocMammouth (mammouth
  pris dans la glace), PorteGlace (stalactites, flocon), Lanterne, Dalle (flocon), Barriere (rondins enneigés),
  Escalier, Igloo, Traineau (cadeaux), Bonhomme. Pancarte reprise de la Prairie.
- Scène : `run_map_scene.py -- --world Glace` -> `baked_assets/map/glace/map_layout.json` (891 décors + lac gelé : surface
  « ice », matériau Ice de Roblox) ; pics de glace géants au loin, un module de glacier sur trois remplacé par des pics ;
  neige : soleil moins fort, exposition -0,2, saturation et contraste remontés (sinon tout est bleu pâle).
  `export_map_lot.py -- --world Glace` -> `Decors_Glace.fbx` (26,5 Mo).
- **Branché dans Studio (25 oct., style validé par Chouaib)** : import de `Decors_Glace.fbx` (Édition),
  `apply_map_look_glace.lua` -> 17 décors dans `ArtModels.Map` (74 pour les 4 mondes), 595 posés dans `MapDecor.Glace` +
  lac gelé, 33 PointLight (lanternes, igloos) ; 98 / 98 portes et glaciers tournés vers le trou ; bases `GlaceLook`.
- Vérifié en Play (solo, monde changé côté client) : à la Glace, GlaceLook visible (les 3 autres cachés), 33 lumières de
  la Glace allumées et les 37 du Volcan éteintes, vieux cristaux retirés ; photos `qa_renders/map_roblox_glace_nuit.jpg`,
  `map_roblox_glace_lac_jour.jpg`. Le lac (bleu pâle) se voyait à peine sur la neige : recoloré en bleu soutenu
  (110, 190, 240). Saturation de l'air de la Glace passée de 0,05 à 0,12 (`shared/Worlds`, accord de Chouaib) : vérifié
  en Play (ColorCorrection à 0,12 au monde Glace, glaciers plus bleus, lac bien visible).

---

# Monde 5 : Abysses (25 oct. 2026) — proposition à valider

« Le Royaume Englouti du Roi Corail » (charte `map_art_bible_abysses.json`, d'après Pieuvre Pirate, Méduse Lampion, Roi
Corail, Calmar Colosse, Poisson-Lanterne Disco). 17 décors dans `blender_tools/environment_abysses.py`, rendus
`qa_renders/map_hero_abysses.png`, `map_aesthetic_board_abysses.png`, `map_assets_board_abysses.png`.

- **Aucune lueur** : perles et nacre en couleur pâle ; PointLight cyan posées par le script (perles des piliers du
  sanctuaire, coquillages géants), éteintes pour les autres mondes. Rien à envoyer. Les lumières peuvent maintenant avoir
  leur couleur (4e valeur de `LIGHTS` dans `make_map_look_script.py`, orange de la lave sinon).
- Décors (< 6 000 triangles) : Recif (roche bleu-violet en gradins, corniches de coraux), Corail (branchu, bouts jaunes),
  CorailEventail, Algue, Anemone, Rocher (étoile de mer), Coquillage (bénitier géant à perle), Touffe (herbier),
  ColonneEngloutie, PorteAtlante (arche en coquillage, trident d'or), PilierPerle, Dalle (mosaïque trident), Muret
  (pierre, coraux, cordage), Escalier (sable), Coffre (trésor), Ancre, Epave (navire de la Pieuvre Pirate, 5 616
  triangles). Pancarte reprise de la Prairie.
- Scène : `run_map_scene.py -- --world Abysses` -> `baked_assets/map/abysses/map_layout.json` (891 décors + fosse d'eau
  sombre : surface « trench », Glass bleu nuit presque opaque) ; au loin, algues géantes et monts arrondis dans l'eau ;
  un module de récif sur trois remplacé par un corail géant (~85 studs : les récifs en gradins faisaient une « ligne
  d'immeubles ») ; algues des récifs x1,8 (`cliff_tree_scale`). Brume moins forte et saturation 0,32 : sinon les coraux
  chauds disparaissent dans le bleu. `export_map_lot.py -- --world Abysses` -> `Decors_Abysses.fbx`.
- **Branché dans Studio (25 oct., style validé par Chouaib)** : import de `Decors_Abysses.fbx` (Édition),
  `apply_map_look_abysses.lua` -> 17 décors dans `ArtModels.Map` (91 pour les 5 mondes), 595 posés dans
  `MapDecor.Abysses` + fosse, 22 PointLight cyan (16 piliers à perle, 6 coquillages) ; 8 / 8 portes et 90 / 90 récifs
  tournés vers le trou ; bases `AbyssesLook` (8 bases, 29 pièces chacune). Rojo n'a pas repris la ligne ajoutée à
  `MapGenerator` (fichier réécrit puis touché sans effet) : source envoyée dans Studio par rbxm, la même que dans OneDrive.
- Vérifié en Play (solo, monde changé côté client) : aux Abysses, seuls les décors des Abysses visibles (596 pièces, les
  4 autres mondes cachés), 22 lumières allumées (0 pour la Glace), AbyssesLook visible et les 4 autres habillages
  cachés ; retour en Prairie : tout s'éteint et se cache. Photos `qa_renders/map_roblox_abysses_jour.jpg`,
  `map_roblox_abysses_fosse.jpg`, `map_roblox_abysses_nuit.jpg`, `map_roblox_abysses_sanctuaire_nuit.jpg`.
- Air des Abysses éclairci (`shared/Worlds`, accord de Chouaib) : densité 0,45 -> 0,34, teinte moins cyan
  (215, 242, 250), saturation 0,15 -> 0,26 ; l'ancien air voilait tout et délavait les coraux. Vérifié en Play
  (Atmosphere 0,34, ColorCorrection 0,26 au monde Abysses) : coraux roses et jaunes nets, de jour comme de nuit
  (photos jour / nuit ci-dessus, reprises après le changement).

---

# Monde 6 : Cosmos (25 oct. 2026) — proposition à valider

« L'Observatoire de l'Astro-Hamster » (charte `map_art_bible_cosmos.json`, d'après Astro-Hamster, Chat Comète, Alien
Gélatine, Lion Nébuleuse, Trou Noir de Poche) : une base lunaire sur un astéroïde dans une nébuleuse violette. 17 décors
dans `blender_tools/environment_cosmos.py`, rendus `qa_renders/map_hero_cosmos.png`, `map_aesthetic_board_cosmos.png`,
`map_assets_board_cosmos.png`.

- **Aucune lueur** : cristaux en couleurs vives (matériau cristal sans émission ; les pièces de cristal qui ne viennent pas
  de `G.crystal_cluster` reçoivent leurs attributs `grad` / `facet` par `gem()`, sinon elles sortent sombres) ; PointLight
  posées par le script : cyan sur les pylônes du sanctuaire, roses sur les cristaux des chemins et des collines (42 en
  tout, aucune en périphérie). Rien à envoyer.
- Décors (< 6 000 triangles) : Falaise (roche lunaire en strates, terrasses de mousse alien), Cristaux, ArbreAlien
  (houppier en dôme de cubes), Champignon (chapeaux cyan / rose à pois), Rocher (bord de cratère), Touffe, Meteorite
  (cratère, roche sombre aux creux roses), Aiguille (cristaux géants), PorteStellaire (anneau sur deux pylônes, clé en
  cristal, étoile d'or, astéroïdes en orbite), Pylone (griffe d'or, cristal), Dalle (constellation en or), Barriere
  (balises), Escalier, Fusee (pas de tir, tour de lancement), Satellite, Caisse, Planete (anneau). Pancarte reprise.
- Scène : `run_map_scene.py -- --world Cosmos` -> `baked_assets/map/cosmos/map_layout.json` (891 décors + cratère de
  poussière d'étoiles : surface « stardust », Neon violet + PointLight dans Roblox) ; au loin, aiguilles de cristal et
  astéroïdes arrondis ; un module de falaise sur trois remplacé par une aiguille de cristal (~95 studs) ; jour lavande
  (exposition +0,45) pour qu'il se distingue de la nuit indigo. `export_map_lot.py -- --world Cosmos` ->
  `Decors_Cosmos.fbx` (30,3 Mo).
- Le script Studio sait maintenant poser une lumière sur n'importe quelle surface (`light` dans `SURFACE_LOOK`).
- **Branché dans Studio (26 oct., style validé par Chouaib)** : import de `Decors_Cosmos.fbx` (Édition),
  `apply_map_look_cosmos.lua` -> 17 décors dans `ArtModels.Map` (108 pour les 6 mondes), 595 posés dans `MapDecor.Cosmos`
  + cratère de poussière d'étoiles (Neon violet + PointLight), 42 PointLight (16 pylônes cyan, 26 cristaux roses) ;
  8 / 8 portes et 90 / 90 falaises tournées vers le trou ; bases `CosmosLook` (8 bases, 29 pièces chacune). La ligne
  `Cosmos` de `MapGenerator` est ajoutée dans la source de Studio et dans le dossier OneDrive (Rojo ne la reprend pas seul).
- Vérifié en Play (solo, monde changé côté client) : au Cosmos, seuls les décors du Cosmos visibles (596 pièces, les 5
  autres mondes cachés), 43 lumières allumées (aucune des autres mondes), CosmosLook visible et les 5 autres habillages
  cachés ; retour en Prairie : tout s'éteint et se cache. Photos `qa_renders/map_roblox_cosmos_jour.jpg`,
  `map_roblox_cosmos_nuit.jpg`, `map_roblox_cosmos_cratere.jpg`.
- Différence avec les rendus : en jeu le ciel ne change pas selon le monde (bleu à nuages le jour) ; dans l'espace ça se
  voit plus qu'ailleurs. Piste : un Sky par monde dans `client/WorldSkin`.

---

# Un ciel par monde (26 oct. 2026)

Jusqu'ici le ciel restait le même partout (bleu à nuages le jour), ce qui se voyait surtout dans l'espace. Désormais
chaque monde a son ciel (`shared/Worlds`, champ `Sky` de chaque monde), appliqué côté client par `client/WorldSkin`.

- **Sans image** (aucun envoi sur le compte) : la couleur du ciel vient de l'air (`Atmosphere` Color / Decay, déjà par
  monde) rendue visible par la brume (`Haze`) ; plus les nuages du Terrain, le nombre d'étoiles, la taille du soleil et
  de la lune du `Sky` de Roblox.
- Les préréglages jour / nuit sont passés de `server/DayNightController` à `Worlds.DayNight` (une seule source pour le
  serveur et le client). Le serveur publie l'attribut `Lighting.DayAmount` (0 nuit -> 1 jour, suivi pendant le passage
  de 4 s) ; chaque image, le client mélange les valeurs nuit / jour du ciel de son monde et les réécrit si le serveur
  les a changées. En quittant un monde, une valeur qu'il remplaçait reprend une fois celle de la phase.
- Prairie : ciel des préréglages (inchangé). Désert : ciel chaud voilé, gros soleil, nuits très étoilées. Volcan : fumée
  orangée et nuages sombres, presque pas d'étoiles. Glace : ciel pâle, nuages de neige, nuits polaires étoilées.
  Abysses : couleur de l'eau, ni nuages, ni étoiles, ni soleil ; eau sombre la nuit. Cosmos : toujours de nuit (heure
  20,1 le jour, 21,6 la nuit) pour garder les étoiles et une lune géante, scène éclairée le jour par la lumière
  ambiante et l'exposition. Divin : ciel lumineux à l'horizon doré, nuages légers.
- Vérifié en Play (solo, monde changé côté client), jour et nuit : planche `qa_renders/ciels_par_monde.jpg`. Réglés
  après les premières photos : la nuit des Abysses (brume 3,4 : eau cyan qui délavait les récifs -> 1,4), le Divin
  (trop de nuages : ciel gris -> 0,4 et brume 2), le Désert (encore bleu -> brume 2,3).

---

# Monde 7 : Divin (26 oct. 2026) — proposition à valider

« Le Sanctuaire Céleste du Titan Auréole » (charte `map_art_bible_divin.json`, d'après Chérubin Hamster, Licorne
Céleste, Griffon Doré, Titan Auréole, Gardien du Trou Noir) : une cité de marbre blanc et d'or au-dessus des nuages.
17 décors dans `blender_tools/environment_divin.py`, rendus `qa_renders/map_hero_divin.png`,
`map_aesthetic_board_divin.png`, `map_assets_board_divin.png`.

- **Aucune lueur** : marbre aux fissures dorées (couleur des creux), cristaux de lumière blanc-or et eau céleste en
  matériau cristal sans émission (attributs par `gem()`) ; PointLight chaudes sur les vasques du sanctuaire (16) et
  bleu pâle sur les fontaines (2). Rien à envoyer.
- Décors (< 6 000 triangles) : Falaise (marbre en strates, terrasses de nuages et de mousse dorée), Nuage, ArbreDore
  (écorce blanche, houppier or et blanc, clochettes), Buisson (laurier taillé), Rocher, Touffe, Colonne (brisée,
  couronne de laurier), Tour (coupole d'or), PorteCeleste (colonnes cannelées, arche blanche et or, soleil rayonnant),
  Vasque (cristal de lumière), Dalle (soleil d'or), Balustrade (balustres en vase), Escalier, Harpe (du Chérubin
  Hamster), Fontaine (à étages), Statue (orbe d'or ailé), Temple (rond, six colonnes, coupole d'or). Pancarte reprise.
- Scène : `run_map_scene.py -- --world Divin` -> `baked_assets/map/divin/map_layout.json` (891 décors + source céleste :
  surface « spring », Glass bleu clair + PointLight douce) ; au loin, mer de nuages et tours géantes ; un module de
  falaise sur trois remplacé par une tour à coupole d'or (~90 studs : la couronne devient une cité céleste). Scène très
  claire : exposition -0,45, contraste 0,22, bloom réduit (sinon le marbre blanc se confond avec le sol blanc).
  `export_map_lot.py -- --world Divin` -> `Decors_Divin.fbx` (34,3 Mo).
- Pièges vus : un lathe à 12 côtés (30° entre faces) dépasse le seuil de biseau de 25° et se fait biseauter sur tout
  son tour (+3 800 triangles pour la fontaine) : seuil passé à 35° pour elle.
- **Branché dans Studio (26 oct., style validé par Chouaib)** : import de `Decors_Divin.fbx` (Édition),
  `apply_map_look_divin.lua` -> 17 décors dans `ArtModels.Map` (125 pour les 7 mondes), 595 posés dans `MapDecor.Divin`
  + source céleste (Glass bleu clair + PointLight), 18 PointLight (16 vasques chaudes, 2 fontaines bleu pâle) ; 8 / 8
  portes et 90 / 90 falaises tournées vers le trou ; bases `DivinLook` (8 bases, 29 pièces chacune). La ligne `Divin` de
  `MapGenerator` était déjà dans Studio et dans le dossier OneDrive.
- Vérifié en Play (solo, monde changé côté client) : au Divin, seuls les décors du Divin visibles (596 pièces, les 6
  autres mondes cachés), 19 lumières allumées (aucune des autres mondes), DivinLook visible et les 6 autres habillages
  cachés ; retour en Prairie : tout s'éteint et se cache. Photos `qa_renders/map_roblox_divin_jour.jpg`,
  `map_roblox_divin_nuit.jpg`, `map_roblox_divin_source.jpg`. En jeu le jour est très blanc (air du monde : saturation
  0,1 dans `shared/Worlds`) : lisible, mais peu de contraste entre le marbre et le sol.
- **Les 7 mondes ont maintenant leur habillage « niveau studio » dans le jeu.**
