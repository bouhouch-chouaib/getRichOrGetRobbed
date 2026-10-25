# CLAUDE.md — Get Rich Or Get Robbed (Roblox / Rojo)

Contexte de passation pour toute nouvelle session Claude. Lire aussi `GDD.md` (design + architecture à jour).
**Lire aussi `docs/ROADMAP.md`** : écarts avec les jeux de référence, feuille de route priorisée (P0/P1/P2),
spec du vol de familiers (prochaine feature) et notes techniques de passation (§7).
**Pour tout travail visuel, lire `docs/DIRECTION_ARTISTIQUE.md`** (style Steal an Egg relevé sur captures :
tenons partout, palette, interface, zones). Captures de référence dans `references/` (local, exclu de git).
**Pour fabriquer un modèle 3D (familier, œuf, décor), lire `dataset_and_pipeline/PIPELINE.md`** : pipeline Blender
par code (phase 1, 25 oct.), matériaux PBR procéduraux, cuisson en textures pour SurfaceAppearance, contrôle visuel.

## Pipeline 3D procédural (phase 1, 25 oct. 2026) — comment l'appeler

Dossier `dataset_and_pipeline/` (détails, règles et limites : `PIPELINE.md`). Blender 5.0 en arrière-plan, sans MCP :
`"/c/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup --python <script>` depuis
`C:\Users\bouho\dev\getRichOrGetRobbed`. Dans un script (ou par `execute_blender_code` du MCP Blender) :

```python
import sys; sys.path.insert(0, r"C:\Users\bouho\dev\getRichOrGetRobbed\dataset_and_pipeline\blender_tools")
import shader_node_library as S, procedural_geometry_recipes as G, auto_pbr_baker as B, visual_qa_renderer as Q
gold = S.create_etched_metal_or_gold(name="M_Or", tint="#FFC830", hammered=0.5)   # 1. matériaux (4 familles)
part = G.lathe("Coupe", [(0, 0), (1, 0), (1.1, 0.6), (0, 0.6)], segments=32)       # 2. formes (pas de primitives)
G.assign_material(part, gold); G.add_bevel_finish(part, width=0.05, segments=3)     # 3. finition (Bevel + Weighted Normal)
high, low = ..., ...      # voxel_fuse / add_organic_displace pour le high, make_low pour le low (< 8 000 triangles)
report = B.bake_asset(low, "NomAsset", high=high)   # 4. UV + cuisson Cycles -> baked_assets/ (PNG, FBX, GLB, manifeste)
Q.render_qa_grid([{"label": "cuit", "objects": [low], "kind": "baked"}])  # 5. planche qa_renders/preview.png
```

Après chaque `render_qa_grid` : **ouvrir `qa_renders/preview.png` avec l'outil de lecture d'image** et corriger tant que
ça fait « primitives » ou « plat ». Fiches des 20 familiers (stats calculées depuis Config, specs 3D) :
`dataset_and_pipeline/game_design_matrix.json`. Exemples complets : `build_stylized_pedestal()`,
`build_mythic_gem_egg()`, `blender_tools/run_poc.py`. Règles clés : un seul Principled « BAKE_BSDF » par matériau,
lueur = couleur de la surface (seule l'intensité varie), tenons par la Normal map (pas de TextureID), pas de Néon.
Vérifié dans Blender, rendu validé par Chouaib (`qa_renders/hero.png` = niveau minimum attendu) ; **import Roblox pas
encore testé**.
**Essai 1.5 (25 oct.) : Cerbère Secret validé** (`blender_tools/block_creatures.py`, `run_cerberus_blocks.py`, 9 328 triangles) :
familiers en blocs biseautés superposés, **sans tenons**, pas trop épais, en suivant l'image de référence (ni jouet lisse, ni
voxels « Minecraft »). **Une aura ne se modélise jamais** : effets tout faits du Creator Store (on garde les images, jamais
les scripts), recréés et réglés par code (`vfx_tools/CerbereAura.lua`). Aperçu dans Studio sans import par un `.mesh` dans
le dossier content (`export_studio_mesh.py`). Méthode, pièges et photos : `PIPELINE.md` « Essai 1.5 ».

## L'utilisateur et la façon de travailler

- Parle français, débutant en dev Roblox ; veut avancer **étape par étape, fonctionnalité par fonctionnalité**,
  le plus vite possible, avec des explications simples (pas de jargon inutile).
- **Pousse directement sur `main`** (il l'a demandé explicitement). Pas de branches/PR.
- Il teste dans **Roblox Studio** ; Claude ne peut pas lancer Studio. Toujours dire clairement ce qui est vérifié
  (analyse statique + build) et ce qui ne l'est pas (rendu / gameplay en Studio).
- Inspiration revendiquée : **Steal a Brainrot / Steal an Egg** (style visuel cartoon, base à verrouiller, etc.).
  Reprendre le *style*, jamais copier assets/marques/noms/sons. Les 15 anciens « brainrots » repris de Steal a Brainrot
  ont été remplacés le 8 oct. 2026 par des « Absurdes cosmiques » originaux (`PetCatalog.Renamed` convertit les
  anciennes sauvegardes) : ne jamais réintroduire de personnage, mème ou son d'un autre jeu.

## Où est le code

- GitHub : `bouhouch-chouaib/getRichOrGetRobbed`, branche `main`.
- **Dossier de travail de l'utilisateur** (c'est de là qu'il lance `rojo serve`) :
  `C:\Users\bouho\OneDrive - Conseil régional Grand Est - Numérique Educatif\Documents\GetRichOrGetRobbed`
  → les fichiers modifiés là sont synchronisés en direct dans Studio (il fait juste Stop puis Play).
- Copie de travail sans accents (pratique pour les outils) : `C:\Users\bouho\dev\getRichOrGetRobbed`.
  Workflow utilisé jusqu'ici : modifier dans `dev\`, analyser, commit, push, puis aligner le dossier OneDrive
  (`git fetch && git checkout -- . && git merge --ff-only origin/main`). Si le push traîne (ça arrive : fenêtre
  d'identification GitHub en arrière-plan), copier les fichiers dans OneDrive pour qu'il teste sans attendre.
- `C:\Users\bouho` est lui-même un dépôt git vide pointant sur le même remote (accident) : **ne pas y travailler**.
- Fichier de place local ignoré par git : `FeedTheBlackhole.rbxlx`.
- Attention : aider/DeepSeek ont déjà réécrit des fichiers dans son dossier OneDrive (vieux code incompatible,
  ex. `BlackholeController.lua` le 03/10). Si Studio montre des erreurs "anciennes", vérifier `git status` là-bas.

## Vérifier le code (Claude ne peut pas jouer)

```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
rojo build -o test.rbxlx
```
- Rojo 7.7.0 via aftman (`~/.aftman/bin`). `luau-lsp` n'est pas installé : télécharger
  `luau-lsp-win64.zip` (releases JohnnyMorganz/luau-lsp) + `scripts/globalTypes.d.luau` dans un dossier temporaire.
  luau-lsp **échoue sur le chemin OneDrive (accents)** → analyser depuis `C:\Users\bouho\dev\getRichOrGetRobbed`.
- Tout le code est en `--!strict` et passe l'analyse sans erreur : garder ce niveau.
- Écrire les fichiers en UTF-8 / LF. Attention aux `\n` dans les heredocs bash+python (ont déjà cassé une chaîne Luau).

## Règles techniques à ne pas casser (détails dans GDD.md)

- Ramassage **autoritaire serveur** (`ItemInteraction`) : Owner/Holder + `SetNetworkOwner(player)` puis
  `Remotes.ItemGrabbed` ; le client soude l'item (WeldConstraint local) et lance (`ApplyImpulse`).
- Détection trou noir / dôme **par distance chaque Heartbeat**, jamais `.Touched`.
- Knockback : serveur `Sit = true` + soulève 1 stud, **le client** applique l'impulsion (`Remotes.Knockback`).
- RemoteEvents : déclarés dans `default.project.json` **et** créés par le serveur s'ils manquent (`Remotes.lua`) —
  `rojo serve` ne recharge pas les nouveaux remotes du project.json en cours de session.
- État des joueurs : `SessionData` → attributs Player (lus par le HUD) + leaderstats, **sauvegardé en DataStore**
  (`PlayerData_v2`, `PlayerData_v2_studio` dans Studio ; version dans `Config.Save`). Ne jamais sauvegarder si le chargement a échoué (`data.loaded`). Dans Studio il faut que le jeu
  soit publié et que "Enable Studio Access to API Services" soit coché (Game Settings > Security).
- **Verrou de session (anti-duplication)** : toute lecture/écriture de la sauvegarde passe par `UpdateAsync` et le champ
  `session` (jamais `SetAsync`/`GetAsync`) ; un serveur n'écrit que s'il tient le verrou, le libère au départ du joueur.
  Toute future feature qui transfère des familiers (vol, échanges) doit s'appuyer dessus. Détails : GDD.md.
- Toute valeur d'équilibrage va dans `src/shared/Config.lua`.

## État actuel (fait)

Boucle Feeding 45 s (nuit éclaircie) / Digesting 60 s (jour) • map en briques à tenons façon Steal an Egg (damier, mur d'enceinte, clôtures en X, arbres en cubes, nuit bleu nuit ; plan des paliers dans `docs/DIRECTION_ARTISTIQUE.md` §8) •
8 bases, bouton de verrouillage 60 s (expulsion des intrus) • argent + boutique à niveaux (Treadmill, Bench,
ItemQuality, Backpack, LongLock) • entraînement Vitesse/Force par niveaux (XP ×1,12/niveau) sur stations hors base •
objets à valeur (6 types, kit de départ 5 objets, 1 objet/2 s en Feeding) • sac à dos (plusieurs objets portés) •
HUD style cartoon (LuckiestGuy, contours noirs, fenêtres, Toast, barres d'XP) • 75 familiers / 8 raretés
(`PetCatalog`), modèles de remplacement procéduraux (`PetModelBuilder`, surchargeables par
`ReplicatedStorage.PetModels.<Id>`) • tirages à coût croissant + pitié (`LootEngine`) • 1 familier équipé =
multiplicateur additif + suit le joueur (`PetFollow`) • revenu = 10 meilleurs familiers • fenêtre collection 3D •
annonces serveur Légendaire+ • familiers qui se baladent dans la base, **trajets décidés par le serveur** (`BasePetsController` + `shared/PetWander` +
`client/BasePets`, plus de socles ; un familier équipé ne rapporte pas et n'est pas dans la base) • verrou de session anti-duplication •
palettes à objets + objets sauvages dans l'arène + amélioration Chance • plaque d'apparition invisible •
verrouillage 5 s relancé à chaque passage • consigne de phase sous l'horloge (8 s) •
**mobile** : `client/ScreenScale` (UI à l'échelle), bouton LANCER tactile, gâchette R2 manette •
économie rééquilibrée (revenus bas, prix hauts) • objets non roulants (frottement max) • map agrandie (bases à 215) •
`Config.StudioGiveAllPets` (false par défaut ; true donne les 75 en Studio pour tester) • sauvegarde DataStore •
machine de fusion + boutique physiques dans 4 kiosques entre les bases • économie en grands nombres (K/M/B/T, `NumberFormat`) •
bulles [E] des objets recalées au-dessus de l'objet côté client (`ItemPromptAnchors`) •
**vol de familiers** pendant la digestion + défense « Reprendre » et annonces (`StealController`, `Config.Steal`, voir GDD) • modèles 3D importés à la bonne taille • nouveaux familiers qui tombent du ciel dans la base (`Celebrate`) + carte de résultats discrète • sons et musique (`client/Sounds`, `Config.Sounds`) • effets de satisfaction : points qui s'envolent, ouverture animée des tirages rares, secousses (`client/Effects`) • tutoriel en 3 étapes, une seule fois (`client/Tutorial`) • anti-triche des lancers (`Config.AntiCheat`, vérifié quand le trou avale l'objet) • vrais modèles 3D des 14 familiers Sigma/Divins (`shared/PetMeshes`, générés dans Studio avec l'outil MCP `generate_mesh`) • boutique Robux : 5 passes + 3 produits, achats sûrs, probabilités affichées (`MonetizationController`, `client/RobuxShop`) • nettoyage avant sortie : sauvegardes v2, Studio séparé (`_studio`), options de test vidées • tableau « LES PLUS RICHES » dans l'arène, top 10 tous serveurs (`LeaderboardController`) + « Argent » trié dans la liste des joueurs • page du jeu préparée (`docs/PAGE_DU_JEU.md`, images `assets/store/`), tirages Robux cachés si `PolicyService` les interdit, 9e joueur renvoyé (8 bases : taille des serveurs à régler à 8) • 12 oct. (retours de la 1re session de jeu) : objet lancé de nouveau ramassable, vol à tout moment, voleur ×0,9 et 60 s, bulle « Voler » créée côté client (`Remotes.StealPet`), armes de PvP (`WeaponController`, `Config.Weapons` ; depuis le 14 oct. : batte + grappin) • tirages : familiers pas encore possédés ×5 (`Config.Loot.NewPetWeight`) • tapis et banc façon Steal an Egg (joueur bloqué sur la station, course / développé couché, « +X 👟 / 💪 », `client/TrainingFx`) • 13 oct. : tapis et banc à 25 niveaux / 5 modèles (`server/StationLooks`), panneaux « Amélioration » (`client/UpgradeSigns`), « ZONE SÛRE », cercles lumineux, socle du verrou • menus et HUD reconstruits façon Steal an Egg (`client/UiStyle`, `MenuKit`, `ShopMenu`, `IndexMenu` avec récompenses à réclamer, `FusionMenu` avec choix des familiers, `RobuxShop`) • icônes 2D dessinées à la place des émojis (`shared/Icons`, `tools/icons/make_icons.py`) • musique par palier (`Config.Sounds.Playlists`, palier 1 calme) + sons d'interface. Les avatars récents ont des articulations `AnimationConstraint` (pas Motor6D) : en tenir compte pour toute animation par code.

**15 oct. : œufs (Codex) puis corrections Claude** (`server/EggController`, `client/Eggs`, `shared/EggIncubation`,
`docs/INCUBATION.md`) : toutes les récompenses arrivent en œufs qui incubent (15 s à 30 min). Claude : un nid par œuf
(12 nids dans la couveuse, file d'attente au-delà), montée en tension puis éclosion de plus en plus spectaculaire selon la
rareté, le familier sort de son nid (ou « +1 NOM » s'il n'est pas dans les 10 affichés). **Bases agrandies à 84 x 84 et
structurées** (`shared/BaseLayout` : entrée, 2 palettes à l'avant, prairie, couveuse au fond). Vérifié en jeu (solo) :
les œufs dans leurs nids, la montée en tension, l'éclosion Divine (colonne de lumière, bandeau, familier qui sort du nid),
la base de haut. Test hors Studio : `lune run tools/check-eggs.luau . <sortie>` (PASS). Pas vu : éclosions à 2 joueurs,
le « +1 NOM » d'un familier hors des 10 affichés, sur téléphone.

**15 oct. : aimant à objets** (`Config.Magnet`, amélioration `Magnet` de la Boutique 5 niveaux, en argent du jeu seulement) :
les objets proches sautent tout seuls dans les mains / le sac (`ItemInteraction`, mêmes règles que [E]). Vérifié en jeu (solo) :
achat de 3 niveaux, objet attiré depuis 9 studs.
**19 oct. : aspirateur à objets** (passe Robux `Vacuum` « ASPIRATEUR » 199 R$, `Config.Vacuum`, remplace l'ancien passe AIMANT MAX) :
aspire tout à 32 studs, très vite, +4 objets portés, tourbillon violet et objets qui volent vers le joueur. Vérifié en jeu (solo,
passe simulé par l'attribut `Pass_Vacuum`) : bouton, tourbillon, 5 objets aspirés depuis 18 studs. Passe « ASPIRATEUR » créé
sur Roblox le 19 oct. (Id 2038180912, dans `Config.Monetization.GamePasses`).
**19 oct. : marché entre joueurs** (`server/MarketController`, `client/MarketMenu`, tuile « Marché », GDD « Marché ») : vendre un
familier contre de l'argent du jeu, acheter ceux des autres. Vérifié en jeu (solo) : les 3 onglets, mise en vente, refus (prix 0,
doublon, 4e vente) ; achat vérifié hors Studio (`tools/check-market.luau`). **À tester à 2 joueurs** : un vrai achat. Icône d'aimant dessinée (`assets/icons/Magnet.png`) mais pas encore
envoyée sur Roblox : la Boutique utilise l'icône « Orb » en attendant.

**19 oct. : modèles 3D faits dans Blender** (connecteur Blender MCP, voir GDD « Modèles faits à la main ») : Claude modélise
dans Blender, exporte en .fbx (`assets/models/`, source `assets/models/source_modeles.blend`), Chouaib importe dans Studio
(Fichier > Importer 3D : les formes sont envoyées sur son compte), Claude range le modèle dans `ReplicatedStorage.ArtModels`
(**dans le fichier du jeu, pas dans git** : sauvegarder / publier), le recolore et l'oriente. Faits : `Treadmill_Bois` (tapis
niveaux 1-5, pièces Main / Dark recolorées par niveau, Metal) et `ChienSaucisse` (familier, pièces Leg / Ear animées par
`PetMotion`). Vérifié en jeu (solo) : tapis en place avec écran et voyants, chien dans la base, qui marche tête en avant, pattes qui bougent.

**22 oct. : modèles Blender en jeu** (`ReplicatedStorage.ArtModels`, dans le fichier du jeu) : les 5 tapis (Bois, Acier, Or,
Cristal, Cosmique : couleurs, Foil / Marble / Fabric / Glass / Neon, attribut `StarY`), Renard Furtif et Tigre du Bengal
(tenons par SurfaceAppearance en AlphaMode Overlay : un TextureID cachait la couleur, le tigre était noir). Doublons d'import
rangés dans `ServerStorage.ArtImportsDoublons`. Puis les 5 bancs (`Bench_<Niveau>`, source `assets/models/source_bancs.blend`) : le jeu cache
le banc en blocs (Seat / Leg / Upright) et garde barre, disques, voyants, étoile ; vérifiés en jeu aux niveaux 3, 8, 13, 18, 25
+ développé couché (la Force monte). Vérifié en jeu (solo) : les 4 nouveaux tapis aux niveaux 8, 13, 18 et 25
(étoile), renard et tigre dans la base.

**21 oct. : 30 familiers exclusifs des mondes** (5 par monde, GDD « Familiers exclusifs des mondes ») : ne sortent que dans
leur monde (monde actuel du joueur), pastille du monde dans l'Index ; Rebirth réajusté (4T puis x2,7) pour garder ~9 h.
Analyse + 10 tests OK (dont `check-world-pets`) ; pas encore vu dans Studio.

**20 oct. : équilibrage de la progression** (docs/PLAN_EQUILIBRAGE.md, simulateur `lune run tools/sim-economy.luau . 200 26`) :
1er Rebirth vers 9 h de jeu (avant 1,7 h), un nouveau monde toutes les 1 à 2 h, Rebirths suivants ~5 h ; revenus des raretés lissés,
tirages meilleurs dans les mondes plus loin (`Config.Worlds[].RarityBoost`), Chance / tirages / argent des points calmés, prix des
mondes, Rebirth, fusion et Boutique recalculés. Analyse + 9 tests OK ; pas encore joué dans Studio.

**20 oct. : capsule corrigée** (retour d'un ami testeur) : on ne peut plus ouvrir un œuf avant la fin de son incubation
normale ; ensuite tentatives d'évolution tirées au sort, chance affichée, suspense « TENTATIVE EN COURS... » (docs/INCUBATION.md).
Analyse + `check-eggs` OK ; pas encore vu dans Studio (Studio fermé).

**15 oct. : capsule d'évolution** (`Config.Evolution`, `client/EvolutionMachine`, `docs/INCUBATION.md`) : cylindre de stase
dehors derrière chaque base ; on y met un œuf (il n'éclot plus tout seul), il tente d'évoluer au fil du temps (Normal → Évolué x3
→ Ultime x8), plafond secret tiré au hasard (« IL N'ÉVOLUERA PLUS »), on l'ouvre quand on veut. Formes évoluées = `<Id>__E2/__E3`
(`PetCatalog.Everything`, `PetCatalog.Variant/Stage`). Vérifié en jeu (solo) : capsule, œuf en stase, évolution, limite atteinte,
éclosion « ÉPIQUE ÉVOLUÉ », familiers évolués dans la base (anneau, couronne Ultime), sauvegarde d'une partie à l'autre.
Pas vu : la fenêtre de choix de l'œuf (l'insertion a été testée par le remote), à 2 joueurs, sur téléphone.
**Capsule par niveau de monde** (`client/CapsuleDecor`, attribut `CapsuleTier`, `Config.Evolution.SpeedPerTier / UltimeWeightPerTier`) :
7 versions de plus en plus grandes et épiques (photographiées en jeu) et de plus en plus efficaces. **Familiers évolués complets** :
Index (onglets ★ / ★★ / ★★★, équiper, récompenses, compteur), stats et duel x1,4 / x2, étiquette dorée dans la base.

**19 oct. : remise à zéro + places de la base** (GDD « Places de la base et réserve ») : sauvegardes v3 (tout le monde
repart de zéro), 15 places, le joueur choisit qui va dans la base (Index), étiquettes BASE / RÉSERVE ; corrigés : étiquette
« +1 NOM » géante à l'éclosion (elle grandissait avec le familier), panneau du tutoriel par-dessus les fenêtres, messages
qui se superposaient au tutoriel. Vérifié en jeu (solo) : 20 familiers -> 15 dans la base, choix d'un familier en réserve,
éclosion Légendaire dans la base + Commun en réserve, sauvegarde Studio vide.

**19 oct. : badges, groupe, mutations par la fusion** (GDD « Badges, groupe Roblox... ») : 13 badges (Id à créer sur
Roblox, images dans `assets/badges`), +10 % de revenu pour les membres du groupe (`Config.Group.Id` à remplir), fusion qui
transmet les mutations en secret. Vérifié en jeu : fusion de 5 Dorés -> œuf Doré secret ; démarrage sans erreur. Pas vu :
attribution réelle des badges et bonus de groupe (Id = 0, et Studio n'envoie pas les badges).
**19 oct. : étages de ChatGPT retirés** (docs/CORRECTIONS_AIMANT.md) ; police Montserrat de ChatGPT gardée (choix de Chouaib).

**16 oct. : refonte de l'interface** (docs/DIRECTION_ARTISTIQUE.md §3.1, d'après 3 vidéos de packs « Studs UI ») :
25 icônes ForgeGUI, textures (`assets/ui`), fenêtres / boutons / tuiles / pastilles / bandeaux refaits dans `UiStyle`,
animations et flou dans `MenuKit`, offres Robux à droite (`client/OffersPanel`). Vérifié en jeu (PC) : HUD, Boutique (+
Passes R$), Index, Mondes, Bonus, Rebirth, bandeaux. Pas vu : sur téléphone, Fusion / Duel / Échange / Capsule.
⚠️ Studio avait des scripts en double (copie Rojo périmée + copie neuve) : vérifier les doublons après un ajout de fichier.

**16 oct. : rétention** (GDD « Rétention », `server/ProgressionController`, `server/Quests`, `client/BonusMenu`,
`client/RebirthMenu`) : boutons Bonus (cadeau du jour sur 7 jours, 3 quêtes du jour, codes cadeaux) et Rebirth (monde Divin
+ $1Qa : on perd argent, mondes, Boutique sauf armes ; revenu x(1+n) à vie, +1 familier dans la base), +10 % de revenu par
ami sur le serveur. Vérifié en jeu (solo) : cadeau du jour, quête réclamée, code (accepté, déjà utilisé, inconnu), Rebirth
(confirmation, célébration, Prairie, revenu x2, 11 familiers). Tests hors Studio dans `tools/check-eggs.luau`. Pas vu :
bonus d'amis (il faut 2 vrais comptes amis), passage à minuit, sur téléphone (tuiles sur 2 rangées).

**16 oct. : mutations SECRÈTES** (`Config.Mutations`, `client/RainbowPets`, GDD « Mutations ») : Doré 1/4 000 x2,
Diamant 1/25 000 x5, Arc-en-ciel 1/150 000 x10, seulement sur les tirages gratuits (jamais Robux : chances à afficher) ;
pas dans l'Index ni nulle part dans le jeu (demande de Chouaib : la surprise doit être énorme) ; éclosion surprise
(`mutationReveal`) ; ids `<Id>__MGold` (avec évolution `<Id>__E3__MRainbow`). Vérifié en jeu : la révélation Arc-en-ciel et
Diamant, l'annonce, l'Index sans mutation.
Vérifié en jeu (solo) : aspect des 3 mutations dans la base (y compris un familier blanc), dégradé arc-en-ciel qui défile,
éclosion d'un œuf Diamant (bandeau « ÉCLOSION RARE DIAMANT ! », familier qui sort du nid), Index (rangée — / OR / DIAM. / ARC,
revenu x10, losanges). Pas vu : l'annonce à tout le serveur, à 2 joueurs, sur téléphone.

**15 oct. : 7 mondes (paliers) achetables** (`Config.Worlds`, `shared/Worlds`, `client/WorldSkin`, `client/WorldMenu`,
`server/TierController`) : l'arène dans le monde du joueur, chaque base dans le monde de son propriétaire, revenu x1,5 par monde.

**13 oct. : récompenses du trou noir lisibles + fin des doublons inutiles** (`server/PullRewards`, `client/PullReveal`,
`Config.Loot`) : barre « prochain tirage » en direct, capsules ouvertes une par une, top 3 sur la jauge, rang de tirage
(plus de Communs à 150 tirages, plus d'Inhabituels à 600, si la rareté est complète), doublons au-delà de 5 vendus,
argent des points selon le revenu. Vérifié en jeu (solo) : barre, capsules, vente des doublons, top 3. Pas encore fait :
les mutations (fait le 16 oct.).

**13 oct. : stats des familiers équipés** (`shared/PetStats`, `Config.Pets.EquipBonus`) : niveaux de Vitesse / Force en plus
selon la rareté et la taille (petit = rapide, gros = fort), en plus du bonus de points ; toujours pas d'argent quand il est équipé.

**13 oct. : échanges entre joueurs** (`server/TradeController`, `client/TradeClient`) : [T], offres de 6 familiers,
double confirmation (PRÊT puis CONFIRMER après 3 s). Analyse OK, démarrage sans erreur ; **à tester à 2 joueurs**.

**13 oct. : musique des 7 mondes** (`Config.Sounds.Playlists`) : 2e version calme (lo-fi, guitare, piano), volume 0,12 ; les ukulélés
et musiques orientales / épiques rendaient fou (Chouaib). Vérifié en jeu.

**13 oct. : retour dans les mondes visités** (attribut `World`, bouton « Y ALLER », bonus de revenu du monde le plus loin)
et **trou noir aux couleurs du monde** (muret + 8 décors, `client/BlackholeFx`). Vérifié en jeu : achat du Désert, retour en Prairie
(revenu du Désert gardé), muret et décors qui changent. Fenêtre Mondes (« Y ALLER ») pas photographiée.

**13 oct. : duels de familiers** (`server/DuelController`, `client/DuelClient`, `client/DuelFx`) : défi [F], choix des
familiers (une rareté d'écart), arène flottante au-dessus du trou, combat auto + clics, roue du gagnant (1/8 : le familier
adverse). Testé à 2 joueurs le 13 oct. (Studio > Test > Clients et serveurs) : défi, invitation, choix, double validation, combat
et clics, K.O., roue, retour des joueurs, abandon. Reste à voir : la case « son familier » (forçable dans Studio :
`workspace:SetAttribute("DuelForceWheel", 1)` côté serveur). Pour donner des familiers aux joueurs de test, un Script
créé à la volée dans ServerScriptService partage les modules du jeu (pas la barre de commande).

**14 oct. : écran désencombré, surtout sur téléphone** (`client/HUD`, `client/ScreenScale`, `client/MenuKit`) : bouton Robux
supprimé (son contenu = onglets Passes R$ / Produits R$ / Chances de la Boutique) ; en haut au centre UNE pastille horloge +
tirages, et dessous une pile (boost, consigne 8 s, carte des tirages) ; bandeau de phase seulement au changement ; bas du centre
réservé à la barre d'objets (`ScreenScale.BOTTOM_RESERVED`) ; tactile : argent/stats + tuiles de menu en haut à gauche, fenêtres
ouvertes entre les tuiles et le bouton de saut, mises à l'échelle pour tenir. **Aperçu téléphone dans Studio** :
`workspace:SetAttribute("DebugPhone", Vector2.new(844, 390))` avant Play (à retirer ensuite : `nil`). Vérifié sur l'aperçu :
HUD, capsules, Boutique Robux, fenêtre 860 x 560 ; la marge droite des fenêtres (saut) n'a pas encore été photographiée.

**13 oct. : porter, jeter, lâcher** (`server/StealController`, `client/CarryControls`, `client/LoosePets`, `shared/PetPath`) :
porter son propre familier ou en voler un, vitesse selon force et poids, le jeter dans le trou (récompense selon le familier),
le lâcher quand on est frappé (il rentre à pied, n'importe qui peut le reprendre). Vérifié en jeu (solo).
Porté à deux mains au-dessus de la tête + geste de lancer des deux bras (`client/PetFollow`, `Config.Sacrifice.Throw`), vérifié en jeu (solo).

**13 oct. : trou noir à 7 paliers** (`server/BlackholeTiers`, `client/BlackholeFx`, `Config.Blackhole`) : jauge commune,
un aspect et une mécanique bonus par palier, effondrement après le 7. Vérifié en jeu (solo) : les 7 aspects, annonce,
lave, météorites, attraction, effondrement, jauge qui se remplit. Test : attribut serveur `DebugHoleTier`.

**15 oct. : familiers en voxels** (blocs à tenons, yeux carrés), taille par familier (13 oct. : échelle `shared/PetSizes`, 0,5 à 2,9 tailles de joueur),
auras Épique+ (anneau au sol, flammes, étincelles, auréole, rayons). Vérifié en jeu (rangée d'un familier par rareté, Index).

## À vérifier en priorité (état au 12 oct. 2026, fin de session Claude)

- 14 oct. : armes remplacées par **batte + grappin** (voir GDD). Vérifiés en jeu (solo) : achat, pose et swing de la batte
  (direction mesurée image par image), tir du grappin dans le vide et retour du crochet. **À tester à 2 joueurs** : coup de
  batte sur quelqu'un, grappin qui attrape et ramène un joueur, victime qui part en vrille. Pouvoir d'invisibilité (6 s,
  recharge 45 s, brisé par toute action) : vérifié en solo (achat, activation, fin, recharge) ; à voir à 2 joueurs (rendu vu par les autres).
- **À tester à 2 joueurs** : vol (bulle client + `Remotes.StealPet`), défense « Reprendre », coups d'armes sur un voleur,
  victime qui quitte pendant un vol (le voleur gagne : testé seulement avec des joueurs simulés).
- Vérifiés en jeu (solo) : lancer puis re-ramasser un objet, achat / réapparition des armes, mains exclusives,
  tapis et banc (blocage, course, développé couché, « +X »), tirages « nouveaux d'abord » (simulation 20 000 tirages).
- Les **clés** (ouvrir une base fermée 10 s) sont revenues le 14 oct., **en Robux uniquement** (49 R$ la clé, produit `Key1`).
  Produit créé sur Roblox le 14 oct. (Id 3718327246, dans `Config.Monetization.Products`).
- Chaque changement ne passe dans le vrai jeu qu'après **Publier** dans Studio puis redémarrage des serveurs.
- Pistes de Chouaib pour la suite : se rapprocher de la direction artistique de Steal an Egg (map faite de vrais modèles 3D
  plutôt que générée par `MapGenerator`, effets, interface) ; voir les conseils de passation dans l'historique.

Pousser le code dans Studio sans `rojo serve` : voir la mémoire « Sync Studio sans Rojo » (rbxm + `GetObjects`).
⚠️ Si `rojo serve` tourne (port 34872), Rojo écrase ce qu'on modifie directement dans Studio par la version du dossier
OneDrive : dans ce cas, copier les fichiers dans OneDrive (ou aligner après le push) au lieu de passer par le rbxm.

## Prochaines étapes prévues (dans cet ordre, validé avec l'utilisateur)

1. (fait : socles) Idée : slots de socles supplémentaires achetables, vol de familiers sur les socles adverses.
2. (fait : machine de fusion, `FusionController` + fenêtre FUSION)
3. (fait : sauvegarde DataStore)
4. (fait le 9 oct. : monétisation codée — 5 passes + 3 produits, `MonetizationController`, `client/RobuxShop`, `shared/Perks`).
   Passes/produits créés le 11 oct. et Id remplis dans `Config.Monetization`. Le créateur du jeu possède d'office ses passes chez Roblox : depuis le 12 oct., `Config.Monetization.CreatorOwnsPasses = false` les ignore (il joue sans avantages, comme ses amis).
5. (fait le 13 oct. : `TradeController`) Échanges entre joueurs (double confirmation anti-arnaque).

Autres idées notées : vol de familiers dans les bases adverses (colle au nom du jeu), bulle ProximityPrompt
personnalisée au style cartoon, sauvegarde de la vitesse.
