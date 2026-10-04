# Get Rich Or Get Robbed — Game Design & Architecture

## Concept

Jeu multijoueur (jusqu'à 8 joueurs, une base chacun) autour d'un trou noir central.
Les joueurs ramassent des objets (dans leur base ou en volant ceux des autres), les jettent dans
le trou noir pendant le **Feeding**, puis le trou noir **digère** et convertit les points en familiers (RNG).

## Boucle de jeu (`GameLoopManager`, serveur)

| Phase | Durée (Studio) | Trou noir | Joueurs |
|---|---|---|---|
| **Feeding** | 60 s (30 s) | Violet, `CanConsume = true` | Ramassent [E] et lancent (clic gauche maintenu) des objets dans le trou. 1 objet = 1 point. |
| **Digesting** | 120 s (20 s) | Rouge, dôme répulsif actif | Récompenses (familiers + argent) distribuées au début de la phase. Les joueurs ferment leur base, achètent des améliorations, s'entraînent sur leur tapis (s'il est acheté). |

Les durées Studio raccourcies se désactivent avec `Config.UseStudioDurations = false`.

## Économie et base

- **Argent** : chaque familier rapporte de l'argent chaque seconde (`Config.Economy.PetIncome`), et chaque point marqué rapporte `MoneyPerPoint` $ à la digestion.
- **Boutique** (`Config.Shop`) : déblocages permanents pour la session. Achat validé par le serveur, enregistré en attribut `Unlock_<Id>`.
  - `Treadmill` : tapis de course à l'extérieur de la base (+Speed pendant la Digestion).
  - `StrongArm` : lancers 25 % plus puissants.
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
  - `TrainingController` : tapis de course déblocable (convoyeur) → +Speed pendant la Digestion.
  - `LockController` : bouton de verrouillage, portail, expulsion des intrus.
  - `EconomyController` : revenu passif des familiers, achats de la boutique (`Remotes.BuyUpgrade`).
  - `SessionData` : données en mémoire (speed, roundScore, money, pets, unlocks) → attributs Player + leaderstats.
- `src/client` → `StarterPlayerScripts.Client`
  - `InteractionController` : tenir, charger, arc de prédiction, lancer, knockback.
  - `HUD` : phase + chrono, argent et revenu, points, vitesse, familiers, popup de récompenses, boutique.

## Carte (`Workspace.Map`, générée)

- Trou noir centré en (0, 0, 0) : `BlackholeZone` (disque 80x80), `HoleRing`, `BlackholeCore`, `BlackholeHalo`, `BlackholeDome`.
- `LooseItems` : objets ramassés ou lancés.
- `Base_1` … `Base_8` en cercle (rayon 175) : `BasePart`, `SpawnLocation`, `SafeZone` (visuel), `TreadmillZone`,
  `SpawnPoints` (4 coins), `ItemSpawns`, `Fence` (clôture en bois, entrée côté trou noir). Un chemin de terre (`Map.Paths`) relie chaque base au trou.

## Pas encore dans le MVP

- Familiers visibles physiquement dans la base, œufs + incubateur, vol d'un objet dans les mains d'un autre joueur.
- Sauvegarde DataStore, familiers visibles / équipables, support mobile du lancer.
