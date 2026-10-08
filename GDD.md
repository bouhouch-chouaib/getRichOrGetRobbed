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
  ×1,1 / 1,2 / 1,35 / 1,6 / 2 / 3 / 5 / 10 (score = 1 + somme des bonus). **Un familier équipé ne rapporte pas d'argent**
  et n'est pas dans la base (choix stratégique : bonus de points OU revenu).
- **Dans la base** : les 10 meilleurs familiers **non équipés** se baladent librement dans la base, décidés par le **serveur**
  (`BasePetsController` : un repère invisible `Base_N.Pets.<PetId>` par espèce, attributs `PetId`, `Count`, `Seed` et `Walk` =
  trajet en cours ; module partagé `PetWander`). Les clients (`client/BasePets`) calculent la position avec l'horloge commune
  `GetServerTimeNow()` : tout le monde voit la même chose, sans réplication de mouvement. Position officielle côté serveur :
  `BasePetsController.GetPetPosition(repère)`. Animation locale : marche, sautille, ondule, plane, se balance, tourne ; une seule
  créature par espèce avec "x2" si plusieurs exemplaires. Ils rapportent de l'argent chaque seconde
  (base 2 / 25 / 400 / 8K / 200K / 6M / 250M / 25B $/s de Commun à Sigma,
  +15 % par rang du familier dans sa rareté : `PetCatalog.GetIncome`).
- **Tirages** (`LootEngine`) : 1er tirage = 5 points, chaque suivant +8 % (anti-emballement), minimum 1 tirage.
  Chance légèrement augmentée par le score. **Pitié** : Épique+ garanti au 60e tirage sans Épique+.
- **Annonce serveur** pour tout drop Légendaire ou mieux.
- **Acquisition visible** : après un tirage, une fusion ou un vol réussi, `BasePetsController.Celebrate(joueur, petIds)` met la base
  à jour tout de suite et pose `ArrivedAt` (heure serveur) sur le repère des familiers concernés. Tous les clients (`client/BasePets`)
  jouent l'arrivée : chute depuis 18 studs, gerbe d'étincelles et flash à la couleur de la rareté, étiquette "✨ NOUVEAU ✨" 5 s,
  rayon de lumière si Légendaire+. Seuls les familiers affichés (10 meilleurs non équipés) ont l'effet ; les autres vont dans la collection.
- **Carte de résultats** (HUD) : petite carte sous le chrono (points, tirages, 4 meilleurs drops, argent), ne ferme aucune fenêtre,
  disparaît après 5 s ou au clic.
- **Machine de fusion** (`FusionController`, bâtiment physique dans chaque kiosque) : 5 familiers non équipés d'une rareté + un coût
  (250 / 15K / 750K / 40M / 2.5B / 250B $) = 1 familier aléatoire de la rareté au-dessus, de Commun jusqu'à Mythique → Divin.
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
- Les objets apparaissent sur **4 palettes en bois** (basses, petit rebord) aux coins de la base.
- **Objets sauvages** : 1 toutes les 4 s pendant le Feeding dans l'arène (entre le dôme et les bases, max 25),
  ramassables par tout le monde, qualité équivalente à Chance niveau 2.
- Amélioration "🍀 Chance" (Id `ItemQuality`) : poids des objets précieux ×(1 + 0,5 × niveau)^rang.

## Entraînement (progression longue)

- Deux stats à niveaux : **Vitesse** (WalkSpeed 16 + 0,5/niveau) et **Force** (vitesse de lancer max 70 + 3/niveau), max niveau 60.
- XP pour passer au niveau suivant = 5 × 1,12^niveau (niveau 10 en ~1,5 min, niveau 30 en ~20 min, niveau 60 en plusieurs heures).
- Stations achetées en boutique, posées hors de la base : **tapis de course** (gauche, Vitesse) et **banc de muscu** (droite, Force).
  5 niveaux chacune (bois → pierre → fer → or → diamant) = XP ×1 / ×2 / ×3,5 / ×6 / ×10. Utilisables à tout moment par le propriétaire.
- Lancer : vitesse = ThrowPower × (35 % + 65 % × charge). Au départ, portée ~22 studs : il faut s'approcher du trou.

## Économie et base

- **Argent** : nombres « astronomiques » (affichage K/M/B/T/Qa via `NumberFormat`). Revenu passif des 10 familiers exposés
  + 15 $ par point à la digestion. Prix boutique : tapis/banc 500 $ (×120/niveau → 104B), objets de qualité 2K (×18 → ~400T),
  sac à dos 25K (×400 → 1.6T), verrou renforcé 5M.
- **Kiosques** : entre chaque paire de bases, une échoppe BOUTIQUE et une machine de FUSION (prompt [E] → fenêtre, fermée en s'éloignant).
- **Boutique** (`Config.Shop`) : améliorations à niveaux, prix = BasePrice × PriceGrowth^niveau, attribut `Upgrade_<Id>`.
  - `Treadmill` (5 niv.), `Bench` (5 niv.) : stations d'entraînement.
  - `ItemQuality` (10 niv.) : objets plus précieux.
  - `Backpack` (4 niv.) : +1 objet porté par niveau (le 1er en main, les autres empilés dans le dos, lancés un par un).
  - `LongLock` : base fermée 10 s au lieu de 5 s.
- **Bouton de verrouillage** (comme Steal a Brainrot) : au centre de la base devant la porte ; le propriétaire marche sur le gros bouton rouge → portail fermé pendant 5 s
  (relancé à chaque passage sur le bouton), tout autre joueur à l'intérieur est expulsé devant l'entrée.
- **Vol de familiers** (`StealController`, réglages `Config.Steal`) : pendant la **digestion**, [E] maintenu 0,5 s sur un familier
  qui se balade dans une base adverse **déverrouillée** (bulle "Voler" sur son repère `Base_N.Pets.<PetId>`, affichée par le
  client seulement quand le vol est possible). Le voleur le porte dans le dos (attribut `CarryingPet` + `CarryingUntil`, affiché
  par `client/PetFollow` pour tout le monde, étiquette nom + temps restant), est ralenti ×0,6 (attribut `SpeedMultiplier`, appliqué
  par `SessionData`) et ne peut plus ramasser d'objet. Arrivé dans **sa** base : transfert. Échec (le familier rentre) : KO / mort /
  réapparition / départ du voleur (`ItemInteraction.HeldReleased`), départ de la victime, 30 s écoulées.
  Anti-duplication : pendant le transport le familier reste à la victime, seulement **réservé** (`BasePetsController.Reserve`,
  caché de sa base) ; transfert en une étape serveur (`RemovePets` puis `AddPets`) seulement si les deux sauvegardes sont chargées
  (`SessionData.IsLoaded`), puis sauvegarde immédiate de la victime puis du voleur. Résultat envoyé au voleur : `Remotes.StealResult`.
- **Défense** : pendant un vol, le serveur pose une bulle [E] "Reprendre" (appui simple, 10 studs) sur le HumanoidRootPart du
  voleur ; attribut `CarryingFrom` = UserId de la victime. Chez la victime seulement (`client/PetFollow`) : bulle visible et voleur
  entouré de rouge (Highlight, visible à travers les murs). Le serveur vérifie que c'est la victime, vivante, à moins de 18 studs
  (`Config.Steal.RecoverMaxDistance`) → le familier rentre (résultat "Recovered").
- **Annonces** (`Remotes.StealNotice`) : à la victime "Started" (début), puis "Stolen" / "Recovered" / "Returned" (KO ou temps
  écoulé) ; à tout le serveur "Announce" pour un vol réussi de rareté >= `Config.Loot.AnnounceMinRarity` (Légendaire).

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

## Mobile / manette

- `client/ScreenScale` : toute l'interface est dessinée pour 1280x720 puis mise à l'échelle de l'écran (min 0,5).
- Bouton **LANCER** rond (bas droite, au-dessus du saut) sur écran tactile : maintenir = charger/viser, relâcher = lancer
  (jauge de charge dans le bouton). Gâchette droite (ButtonR2) à la manette.
- Consigne de phase adaptée à l'appareil ; colonne de gauche remontée sur tactile (joystick) ; familiers de base animés
  jusqu'à 150 studs sur téléphone (260 sur PC).

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
  - `BasePetsController` : familiers qui vivent dans chaque base (repères + trajets décidés par le serveur, affichés par le client).
  - `LockController` : bouton de verrouillage, portail, expulsion des intrus.
  - `EconomyController` : revenu passif des familiers, achats de la boutique (`Remotes.BuyUpgrade`).
  - `SessionData` : données joueur (niveaux/XP Vitesse et Force, money, pets, équipés, pitié, upgrades) → attributs Player + leaderstats.
    **Sauvegardées** dans le DataStore `PlayerData_v1` (clé `u_<UserId>`) : chargement à la connexion, sauvegarde à la
    déconnexion, toutes les 60 s et à l'arrêt du serveur. Échec de chargement = aucune sauvegarde (protection anti-écrasement).
    **Verrou de session** (anti-duplication, schéma `version = 2`) : la sauvegarde contient `session = { id, job, studio, time }`.
    Au chargement, le serveur prend le verrou par `UpdateAsync` ; s'il est tenu par un autre serveur, il réessaie toutes les 3 s
    (attribut `SaveWaiting` → message dans le HUD) et le reprend s'il n'a pas été rafraîchi depuis 3 min (serveur planté) ;
    au-delà de 3 min 30 le joueur est expulsé avec un message. Chaque sauvegarde vérifie que le verrou est toujours à nous
    (sinon : rien n'est écrit, joueur expulsé). Le départ du joueur / l'arrêt du serveur libèrent le verrou (`session = nil`).
    Les opérations d'un même joueur passent une par une (file à tickets). Dans Studio, le verrou laissé par une partie de test
    précédente est repris directement (jamais celui d'un vrai serveur).
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
