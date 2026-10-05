# Get Rich Or Get Robbed — Game Design & Architecture

## Concept

Jeu multijoueur (jusqu'à 8 joueurs, une base chacun) autour d'un trou noir central.
Les joueurs ramassent des objets (dans leur base ou en volant ceux des autres), les jettent dans
le trou noir pendant le **Feeding**, puis le trou noir **digère** et convertit les points en familiers (RNG).

## Boucle de jeu (`GameLoopManager`, serveur)

| Phase | Durée | Trou noir | Joueurs |
|---|---|---|---|
| **Feeding** | 45 s | Violet, `CanConsume = true` | Ramassent [E] et lancent (clic gauche maintenu) des objets dans le trou. 1 objet = 1 point. |
| **Digesting** | 60 s | Rouge, dôme répulsif actif | Récompenses (familiers + argent) distribuées au début de la phase. Les joueurs ferment leur base, achètent des améliorations, s'entraînent sur leur tapis (s'il est acheté). |

Pour tester plus vite dans Studio : `Config.UseStudioDurations = true` (durées de `Config.StudioDurations`).

## Familiers (75, 8 raretés)

- Catalogue : `PetCatalog` (5 catégories x 15 : Animaux, Fantastiques, Plantes, Hybrides, Brainrot).
- Raretés (`Config.Rarities`) : Commun 50 %, Inhabituel 25 %, Rare 12 %, Épique 7 %, Légendaire 4 %, Mythique 1,5 %, Divin 0,4 %, Sigma 0,1 %.
- **Équipé** (1 place de base) : le familier suit le joueur et ajoute un bonus de points, additif :
  ×1,1 / 1,2 / 1,35 / 1,6 / 2 / 3 / 5 / 10 (score = 1 + somme des bonus).
- **Dans la base** : les 10 meilleurs familiers sont exposés sur des socles (`PedestalController`) et rapportent de l'argent chaque seconde
  (0,2 / 0,5 / 1,2 / 3 / 8 / 20 / 60 / 200 $/s de Commun à Sigma).
- **Tirages** (`LootEngine`) : 1er tirage = 5 points, chaque suivant +8 % (anti-emballement), minimum 1 tirage.
  Chance légèrement augmentée par le score. **Pitié** : Épique+ garanti au 60e tirage sans Épique+.
- **Annonce serveur** pour tout drop Légendaire ou mieux.
- **Machine de fusion** (`FusionController`, bouton 🧪) : 5 familiers non équipés d'une rareté + un coût
  (50 / 150 / 500 / 1500 / 5000 / 15000 $) = 1 familier aléatoire de la rareté au-dessus, de Commun jusqu'à Mythique → Divin.
  Doublons consommés en priorité. Le Sigma ne s'obtient que par chance.
- Modèles : `PetModelBuilder` construit un modèle de remplacement en formes de base ; un Model nommé comme l'Id
  dans `ReplicatedStorage.PetModels` le remplace automatiquement.
- Test : `Config.StudioGiveAllPets = true` donne les 75 familiers dans Studio (désactivé par défaut : fausse l'économie).

## Objets à jeter

- Kit de départ : 5 objets au hasard dans la base à l'arrivée du joueur.
- Pendant le Feeding : 1 objet toutes les 2 s dans chaque base occupée (max 12).
- 6 types (`Config.ItemTiers`) : Caillou 0,25 • Brique 0,5 • Cristal 1 • Lingot 2,5 • Diamant 6 • Météorite 15 points.
- Points marqués = valeur de l'objet × multiplicateur des familiers équipés.
- Physique : frottement maximal, aucun rebond, aucune forme ronde : un objet s'arrête où il tombe (la Force compte).
- Amélioration "Objets de qualité" : poids des objets précieux ×(1 + 0,35 × niveau)^rang.

## Entraînement (progression longue)

- Deux stats à niveaux : **Vitesse** (WalkSpeed 16 + 0,5/niveau) et **Force** (vitesse de lancer max 70 + 3/niveau), max niveau 60.
- XP pour passer au niveau suivant = 5 × 1,12^niveau (niveau 10 en ~1,5 min, niveau 30 en ~20 min, niveau 60 en plusieurs heures).
- Stations achetées en boutique, posées hors de la base : **tapis de course** (gauche, Vitesse) et **banc de muscu** (droite, Force).
  5 niveaux chacune (bois → pierre → fer → or → diamant) = XP ×1 / ×2 / ×3,5 / ×6 / ×10. Utilisables à tout moment par le propriétaire.
- Lancer : vitesse = ThrowPower × (35 % + 65 % × charge). Au départ, portée ~22 studs : il faut s'approcher du trou.

## Économie et base

- **Argent** : revenu passif des 10 familiers exposés + 4 $ par point à la digestion. Prix boutique : tapis/banc 300 $ (×4 par niveau),
  objets de qualité 400 $ (×2,2), sac à dos 1000 $ (×3), verrou renforcé 5000 $.
- **Boutique** (`Config.Shop`) : améliorations à niveaux, prix = BasePrice × PriceGrowth^niveau, attribut `Upgrade_<Id>`.
  - `Treadmill` (5 niv.), `Bench` (5 niv.) : stations d'entraînement.
  - `ItemQuality` (10 niv.) : objets plus précieux.
  - `Backpack` (4 niv.) : +1 objet porté par niveau (le 1er en main, les autres empilés dans le dos, lancés un par un).
  - `LongLock` : base fermée 90 s au lieu de 60 s.
- **Bouton de verrouillage** (comme Steal a Brainrot) : le propriétaire marche sur le gros bouton rouge de sa base → portail fermé pendant 60 s, tout autre joueur à l'intérieur est expulsé devant l'entrée.

## Règles physiques / réseau (ne pas régresser)

1. **Ramassage autoritaire serveur** : le `ProximityPrompt.Triggered` est traité par le serveur
   (`ItemInteraction`), qui écrit `Owner` + `Holder`, désactive le prompt et fait
   `SetNetworkOwner(player)`, puis envoie `Remotes.ItemGrabbed` au client.
   Sans la propriété réseau, tout ce que fait le client sur l'item (weld, impulsion) reste invisible au serveur.
2. **Tenir / lancer côté client** : le client soude l'item à la main (`WeldConstraint` local), coupe les collisions.
   Au relâchement : destruction du weld, collisions réactivées, `ApplyImpulse`, puis `Remotes.ThrowItem` au serveur.
3. **Lâcher forcé** : le serveur efface l'attribut `Holder` (KO, mort, départ). Le client écoute ce changement et lâche.
4. **Détection par distance, pas par `.Touched`** (`BlackholeController`, chaque Heartbeat) :
   - Feeding : item libre à moins de `HoleRadius` (à plat) et sous `HoleConsumeHeight` → avalé, +1 point à `Owner`.
   - Digesting, items dans le dôme : `SetNetworkOwner(nil)`, vélocité à zéro, replacé hors du dôme, `ApplyImpulse` vers l'extérieur.
   - Digesting, joueurs dans le dôme : lâcher forcé, `humanoid.Sit = true`, soulevé d'1 stud, puis
     `Remotes.Knockback` → **le client** applique l'impulsion (il est propriétaire réseau de son personnage ;
     une impulsion appliquée par le serveur sur un personnage n'est pas fiable).

## Architecture (Rojo)

- `src/shared` → `ReplicatedStorage.Shared`
  - `Config` : toutes les valeurs d'équilibrage (durées, tailles, lancer, loot, couleurs).
  - `Remotes` : accès typé aux RemoteEvents (déclarés dans `default.project.json` sous `ReplicatedStorage.Remotes`).
  - `LootEngine` : `processRewards(score) -> (results, pulls)`. 1 tirage / `PointsPerPull` points (min 1 si score > 0) ;
    plus le score est haut, plus les raretés hautes ont de poids.
- `src/server` → `ServerScriptService.Server`
  - `Main.server.lua` : initialise tout, démarre la boucle en dernier.
  - `GameLoopManager` : timer + `ServerEvent` (`"StateChanged"`, `"Tick"`) ; publie `GameState` / `TimeRemaining` en attributs de `ReplicatedStorage`.
  - `MapGenerator` : prairie, chemins de terre, arbres, trou noir, dôme, 8 bases clôturées en bois.
  - `DayNightController` : nuit pendant le Feeding, jour pendant la Digestion (transition de 4 s).
  - `BaseManager` : une base par joueur (`BaseIndex` sur le Player, `OwnerName` sur la base), spawn sur sa base.
  - `ItemSpawner` : objets dans les bases occupées pendant le Feeding.
  - `ItemInteraction` : ramassage / lancer / lâcher (autorité serveur).
  - `BlackholeController` : consommation, dôme répulsif, récompenses.
  - `TrainingController` : stations tapis (Vitesse) et banc (Force), niveaux, XP.
  - `PedestalController` : familiers exposés sur les 10 socles de la base.
  - `LockController` : bouton de verrouillage, portail, expulsion des intrus.
  - `EconomyController` : revenu passif des familiers, achats de la boutique (`Remotes.BuyUpgrade`).
  - `SessionData` : données joueur (niveaux/XP Vitesse et Force, money, pets, équipés, pitié, upgrades) → attributs Player + leaderstats.
    **Sauvegardées** dans le DataStore `PlayerData_v1` (clé `u_<UserId>`) : chargement à la connexion, sauvegarde à la
    déconnexion, toutes les 60 s et à l'arrêt du serveur. Échec de chargement = aucune sauvegarde (protection anti-écrasement).
- `src/client` → `StarterPlayerScripts.Client`
  - `InteractionController` : tenir, charger, arc de prédiction, lancer, knockback.
  - `HUD` : style cartoon (police LuckiestGuy, contours noirs épais, boutons en dégradé) : phase + chrono, argent et revenu, points, vitesse, boutons BOUTIQUE / FAMILIERS (fenêtres), popup de récompenses.
  - `Toast` (ModuleScript) : gros message temporaire au centre de l'écran (`Toast.show(texte, couleur)`).

## Carte (`Workspace.Map`, générée)

- Trou noir centré en (0, 0, 0) : `BlackholeZone` (disque 80x80), `HoleRing`, `BlackholeCore`, `BlackholeHalo`, `BlackholeDome`.
- `LooseItems` : objets ramassés ou lancés.
- `Base_1` … `Base_8` en cercle (rayon 215, ~150 studs entre l'entrée et le trou) : `BasePart`, `SpawnLocation`, `SafeZone` (visuel), `TreadmillZone`,
  `SpawnPoints` (4 coins), `ItemSpawns`, `Fence` (clôture en bois, entrée côté trou noir). Un chemin de terre (`Map.Paths`) relie chaque base au trou.

## Pas encore dans le MVP

- Familiers visibles physiquement dans la base, œufs + incubateur, vol d'un objet dans les mains d'un autre joueur.
- Sauvegarde DataStore, familiers visibles / équipables, support mobile du lancer.
