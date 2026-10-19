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

- Catalogue : `PetCatalog` (5 catégories x 15 : Animaux, Fantastiques, Plantes, Hybrides, Absurdes cosmiques — originaux, remplacent depuis le 8 oct. 2026 les anciens « brainrots » repris de Steal a Brainrot ; `PetCatalog.Renamed` convertit les anciens Id des sauvegardes).
- Raretés (`Config.Rarities`) : Commun 50 %, Inhabituel 25 %, Rare 12 %, Épique 7 %, Légendaire 4 %, Mythique 1,5 %, Divin 0,4 %, Sigma 0,1 %.
- **Équipé** (1 place de base) : le familier suit le joueur et ajoute un bonus de points, additif :
  ×1,1 / 1,2 / 1,35 / 1,6 / 2 / 3 / 5 / 10 (score = 1 + somme des bonus). **Un familier équipé ne rapporte pas d'argent**
  et n'est pas dans la base (choix stratégique : bonus OU revenu).
- **Stats d'un familier équipé** (13 oct., `shared/PetStats`, `Config.Pets.EquipBonus`) : il ajoute aussi des **niveaux de
  Vitesse et de Force** tant qu'il est équipé. Total par rareté : 2 / 3 / 5 / 7 / 10 / 14 / 19 / 26 niveaux (Commun → Sigma),
  partagé selon sa taille dans sa tranche (`PetSizes`) : le plus petit 80 % Vitesse, le plus gros 80 % Force. Plafond 30 niveaux
  par stat (tous équipés confondus). Le serveur les ajoute à la vitesse de marche et à la force de lancer (`SessionData`,
  attributs `SpeedBonus` / `StrengthBonus`) ; affichés dans l'Index (fiche du familier) et dans le HUD (« NV 13 +5 »).
- **Dans la base** : les 10 meilleurs familiers **non équipés** se baladent librement dans la base, décidés par le **serveur**
  (`BasePetsController` : un repère invisible `Base_N.Pets.<PetId>` par espèce, attributs `PetId`, `Count`, `Seed` et `Walk` =
  trajet en cours ; module partagé `PetWander`). Les clients (`client/BasePets`) calculent la position avec l'horloge commune
  `GetServerTimeNow()` : tout le monde voit la même chose, sans réplication de mouvement. Position officielle côté serveur :
  `BasePetsController.GetPetPosition(repère)`. Animation locale : marche, sautille, ondule, plane, se balance, tourne ; une seule
  créature par espèce avec "x2" si plusieurs exemplaires. Ils rapportent de l'argent chaque seconde
  (base 2 / 25 / 400 / 8K / 200K / 6M / 250M / 25B $/s de Commun à Sigma,
  +15 % par rang du familier dans sa rareté : `PetCatalog.GetIncome`).
- **Tirages** (`LootEngine`) : 1er tirage = 2 points, chaque suivant +8 % (anti-emballement : 100 points = 20 tirages,
  1 000 = 48, 10 000 = 77), minimum 1 tirage. Chance augmentée par le score (x1 à x2). **Pitié** : Épique+ garanti au 60e
  tirage sans Épique+. **Toutes les sources** (fin de manche, roue des duels, Robux) passent par `server/PullRewards.Grant`.
- **13 oct. : récompenses lisibles** (retours des testeurs : « on ne comprend pas ce qu'on gagne ») :
  - **Tirages de la manche** dans la pastille de l'horloge pendant le Feeding (`client/HUD`, `LootEngine.progress`) :
    « 3 TIRAGES » + barre vers le suivant, « +1 TIRAGE ! » qui s'envole quand elle se remplit. La garantie Épique
    (attribut `Pity`) est rappelée sur la carte de résultats (14 oct. : plus de ligne permanente, l'écran était trop chargé).
  - **Capsules** (`client/PullReveal`) : à la digestion, jusqu'à `RevealCards` (8) capsules s'ouvrent une par une en bas de
    l'écran (« NOUVEAU ! », rareté, ou « VENDU +$ »), les autres résumées « +N AUTRES » ; clic = tout ouvrir. Le grand écran
    des familiers rares (`client/Effects`) passe après.
  - **Carte de résultats** : nouveaux d'abord, doublons vendus, argent, rang de tirage et prochain palier.
  - **Top 3 du trou noir** sur la jauge (attribut `HoleTop`, `BlackholeTiers`) : ceux qui gagneront les cadeaux de l'effondrement.
- **Rang de tirage** (`Config.Loot.Ranks`, attribut sauvegardé `TotalPulls` = tirages faits depuis le début ; les anciennes
  sauvegardes comptent leurs familiers) : APPRENTI (0) → DOMPTEUR (150 : plus de Communs) → MAÎTRE (600 : plus d'Inhabituels).
  Un tirage sous la rareté plancher monte au plancher : les chances des raretés au-dessus ne changent pas (pas d'inflation des
  rares). Une rareté ne disparaît que si **tous** ses familiers sont découverts (l'Index reste complétable). Indépendant des
  mondes (ils auront leurs familiers exclusifs). Les chances affichées dans la boutique Robux en tiennent compte.
- **Doublons vendus** : au-delà de `KeepCopies` (5) exemplaires d'un familier, les suivants sont vendus tout de suite
  (`SellSeconds` = 300 s de son revenu x monde x passes ; le jeter dans le trou rapporte le double).
- **Argent des points** : `MoneyPerPoint` (15 $) ou 0,1 s du revenu du joueur par point si c'est plus (`IncomeSecondsPerPoint`).
  **Nouveaux d'abord** : dans une rareté, un familier pas encore possédé pèse `Config.Loot.NewPetWeight` (5) contre 1
  (`LootEngine.rollPulls(..., owned)`, owned = `SessionData.GetOwnedPets`) ; les chances par rareté ne changent pas
  (affiché dans la boutique Robux).
- **Annonce serveur** pour tout drop Légendaire ou mieux.
- **Acquisition visible** : après un tirage, une fusion ou un vol réussi, `BasePetsController.Celebrate(joueur, petIds)` met la base
  à jour tout de suite et pose `ArrivedAt` (heure serveur) sur le repère des familiers concernés. Tous les clients (`client/BasePets`)
  jouent l'arrivée : chute depuis 18 studs, gerbe d'étincelles et flash à la couleur de la rareté, étiquette "✨ NOUVEAU ✨" 5 s,
  rayon de lumière si Légendaire+. Seuls les familiers affichés (10 meilleurs non équipés) ont l'effet ; les autres vont dans la collection.
- **Carte de résultats** (HUD) : petite carte sous le chrono (tirages, points, 4 meilleurs drops, doublons vendus, argent, rang),
  ne ferme aucune fenêtre, disparaît après 7 s ou au clic.
- **Machine de fusion** (`FusionController`, bâtiment physique dans chaque kiosque) : 5 familiers non équipés d'une rareté + un coût
  (250 / 15K / 750K / 40M / 2.5B / 250B $) = 1 familier aléatoire de la rareté au-dessus, de Commun jusqu'à Mythique → Divin.
  Le joueur choisit lui-même les 5 familiers dans les cases de la machine (`client/FusionMenu`, bouton « Auto » = doublons
  d'abord) ; `Remotes.Fuse(rarityIndex, choix)`, le serveur revalide le choix (sinon doublons d'abord). Le Sigma ne
  s'obtient que par chance.
- **Index** (`client/IndexMenu`) : collection par rareté ; chaque familier découvert donne une récompense à réclamer une
  seule fois = 120 s de son revenu (`Config.Index`, `SessionData.ClaimIndex`, champ sauvegardé `indexClaimed`, attribut
  `IndexClaimed`, `Remotes.ClaimIndex` / `IndexClaimed`). Un familier réclamé reste « découvert » même s'il est volé.
- Modèles, par ordre de priorité (`PetModelBuilder.Build`) :
  1. **vrais modèles 3D en assets** listés dans `shared/PetMeshes` (MeshId + TextureId + FacingYaw) : recréés une fois au
     démarrage côté client (`AssetService:CreateMeshPartAsync`), normalisés (taille de la rareté, -Z, particules), puis clonés.
     Quand ils sont prêts, `PetModelBuilder.MeshesReady` fait reconstruire ce qui est déjà affiché (BasePets, PetFollow, HUD) ;
  2. un Model nommé comme l'Id dans `ReplicatedStorage.PetModels` (fichiers `.rbxm` de `assets/PetModels/`, ex. Capybara Zen) ;
  3. sinon un modèle de remplacement en formes de base.
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
  **25 niveaux** chacune (depuis le 13 oct.) = 5 **modèles** de 5 niveaux (`server/StationLooks`, couleurs dans
  `Config.Training.StationTiers`) : Bois → Acier (bandes de couleur) → Or (portique) → Cristal (cristaux, chevrons
  lumineux, étincelles) → Cosmique (néons, halo de cubes). Dans un modèle, chaque niveau allume un voyant de plus ; au 5e,
  une étoile dorée. XP/s = 1,17^(niveau-1) (`Config.GetStationRate`, ×43 au niveau 25), prix ×4,04 par niveau (même
  prix final qu'avant). Anciennes sauvegardes (8 niveaux) converties à la lecture (`Config.Training.OldStationLevels`,
  champ `stationScale`). On court / pousse 4 % plus vite par niveau. Utilisables à tout moment par le propriétaire.
- **Panneau « Amélioration »** planté à côté de chaque station (niveau actuel > suivant, prix), visible dès que la base a
  un propriétaire, même avant l'achat ; la bulle [E] « Acheter / Améliorer » n'existe que chez le propriétaire
  (`client/UpgradeSigns` → `Remotes.BuyUpgrade`) ; message à chaque nouveau modèle. Cercle lumineux au sol sous chaque
  station (couleur du modèle) et devant la boutique et la fusion.
- **Base** : « ZONE SÛRE » peint au sol derrière une ligne rouge à l'entrée (un familier volé devient celui du voleur
  dans sa base) ; bouton de verrou sur un socle à bandes jaunes et noires.
- **Façon Steal an Egg** (depuis le 12 oct.) : marcher sur la station → le serveur (`TrainingController`) **ancre** le
  HumanoidRootPart (debout sur le tapis face à la console, ou allongé sur le dos sur le banc) et écrit l'attribut `Training`
  ("Treadmill" / "Bench"). XP chaque seconde ; attributs `TrainingGain` + `TrainingPulse` → `client/TrainingFx` affiche
  "+X 👟" / "+X 💪" au-dessus de la tête (pour tout le monde). Tapis : animation de course de Roblox jouée par le client du
  joueur (répliquée). Banc : développé couché animé par chaque client pour chaque joueur allongé (`Transform` des
  articulations dans `Stepped` — Motor6D **ou AnimationConstraint**, le nouveau squelette des avatars), barre qui suit les
  mains, grognement `Config.Sounds.Effects.Effort` à chaque poussée, `PlatformStand` pendant l'exercice. Descendre : sauter
  ou bouton ARRÊTER (`Remotes.StopTraining`) ; il faut quitter la station avant d'y remonter. Un coup d'arme fait descendre.
  Plus de tapis roulant physique (il repoussait le joueur).
- Lancer : vitesse = ThrowPower × (35 % + 65 % × charge). Au départ, portée ~22 studs : il faut s'approcher du trou.

## Économie et base

- **Argent** : nombres « astronomiques » (affichage K/M/B/T/Qa via `NumberFormat`). Revenu passif des 10 familiers exposés
  + 15 $ par point à la digestion. Prix boutique : tapis/banc 500 $ (×4,04/niveau, 25 niveaux), objets de qualité 2K (×18 → ~400T),
  sac à dos 25K (×400 → 1.6T), verrou renforcé 5M.
- **Kiosques** : entre chaque paire de bases, une échoppe BOUTIQUE et une machine de FUSION (prompt [E] → fenêtre, fermée en s'éloignant).
- **Boutique** (`Config.Shop`) : améliorations à niveaux, prix = BasePrice × PriceGrowth^niveau, attribut `Upgrade_<Id>`.
  - `Treadmill` (5 niv.), `Bench` (5 niv.) : stations d'entraînement.
  - `ItemQuality` (10 niv.) : objets plus précieux.
  - `Backpack` (4 niv.) : +1 objet porté par niveau (le 1er en main, les autres empilés dans le dos, lancés un par un).
  - `Magnet` (5 niv., 15 oct.) : aimant à objets, les objets proches sautent tout seuls dans les mains / le sac (portée 7, 10,
    13, 16, 20 studs ; `Config.Magnet`). En argent du jeu seulement (19 oct. : plus de passe Robux pour l'aimant).
    Le serveur (`ItemInteraction`) prend l'objet le plus proche par le même chemin que [E] (mêmes règles : mains libres, pas
    de familier porté, pas d'arme en main), ignore les objets des autres bases et ceux qu'on vient de lancer (2 s).
  - `LongLock` : base fermée 10 s au lieu de 5 s.
- **Bouton de verrouillage** (comme Steal a Brainrot) : au centre de la base devant la porte ; le propriétaire marche sur le gros bouton rouge → portail fermé pendant 5 s
  (relancé à chaque passage sur le bouton), tout autre joueur à l'intérieur est expulsé devant l'entrée.
- **Vol de familiers** (`StealController`, réglages `Config.Steal`) : **à tout moment** (depuis le 12 oct. ;
  `OnlyDuringDigesting = false`), [E] maintenu 0,3 s sur un familier qui se balade dans une base adverse **déverrouillée**,
  mains libres (ni objet ni arme). La bulle "Voler" est **créée par le client** sur le repère `Base_N.Pets.<PetId>` (client/BasePets),
  qu'il déplace localement sur le familier, et envoie `Remotes.StealPet(anchor)` (4 demandes/s max). Ne jamais remettre une
  bulle serveur : Roblox refuse un ProximityPrompt validé loin de sa position serveur, et le serveur ne déplace jamais les repères
  (c'était la cause des vols qui « ne marchaient pas »). Le voleur le porte à deux mains au-dessus de la tête (13 oct. : bras levés, mains
  qui le serrent sur les côtés selon sa largeur, petit rebond en marchant ; jeté dans le trou : élan en arrière, lancer et
  accompagnement des deux bras, il quitte les mains à `Config.Sacrifice.Throw.Release` puis vole vers le trou ; attribut `CarryingPet` + `CarryingUntil`, affiché
  par `client/PetFollow` pour tout le monde, étiquette nom + temps restant), est ralenti selon sa force et le poids du familier
  (13 oct., voir « Porter, jeter, lâcher » ci-dessous ; attribut `SpeedMultiplier`, appliqué par `SessionData`) et ne peut plus
  ramasser d'objet ni sortir d'arme. Arrivé dans **sa** base : transfert. Frappé (batte), KO du dôme, mort, réapparition, départ
  (`ItemInteraction.HeldReleased`) ou trop lent : il **lâche** le familier, qui rentre à pied (13 oct.). **La victime quitte le jeu pendant le vol** (depuis le 12 oct.) : le voleur GAGNE le
  familier tout de suite (résultat "VictimLeft"), transféré par `SessionData.OnLeaving` juste AVANT la dernière sauvegarde
  de la victime — quitter ne protège plus ses familiers.
  Anti-duplication : pendant le transport le familier reste à la victime, seulement **réservé** (`BasePetsController.Reserve`,
  caché de sa base) ; transfert en une étape serveur (`RemovePets` puis `AddPets`) seulement si les deux sauvegardes sont chargées
  (`SessionData.IsLoaded`), puis sauvegarde immédiate de la victime puis du voleur. Résultat envoyé au voleur : `Remotes.StealResult`.
- **Défense** : pendant un vol, le serveur pose une bulle [E] "Reprendre" (appui simple, 10 studs) sur le HumanoidRootPart du
  voleur ; attribut `CarryingFrom` = UserId de la victime. Chez la victime seulement (`client/PetFollow`) : bulle visible et voleur
  entouré de rouge (Highlight, visible à travers les murs). Le serveur vérifie que c'est la victime, vivante, à moins de 18 studs
  (`Config.Steal.RecoverMaxDistance`) → le familier rentre (résultat "Recovered").
- **Armes de PvP** (14 oct. : deux armes seulement ; `WeaponController`, `client/WeaponFx`, réglages `Config.Weapons.Bat` /
  `.Grapple`, achetées dans la boutique d'argent : `WeaponBat` Batte 2 K$, `WeaponGrapple` Grappin 150 K$). Un `Tool` par arme
  possédée (niveau 1 de l'amélioration, donc sauvegardé), redonné à chaque réapparition. Anciennes armes converties à la lecture
  (`Config.Weapons.OldWeapons` : gant / poêle -> batte, bâton -> batte + grappin). Combo : le grappin ramène un voleur, la batte lui
  fait lâcher le familier.
  - **Batte** : clic -> `Remotes.WeaponFx("Swing")` à tous ; au moment fort (`StrikeAt` de `SwingTime`) le serveur prend le joueur
    le plus proche devant soi, l'éjecte (`Remotes.Knockback` avec durée de KO : vrille puis `GettingUp`) et lui fait tout lâcher
    (`ReleaseHeld`) : un voleur touché perd le familier. Immunité 2 s. Animation (vérifiée en jeu par mesure de la direction de la
    batte) : batte posée sur l'épaule en main, vrai swing de baseball à deux mains (batte loin derrière, coup devant à hauteur de
    taille, accompagnement à gauche), traînée pendant la frappe, micro-pause à l'impact, flash, « BONK ! », étoiles, zoom caméra.
    Réglage des gestes : attribut Workspace `WeaponFxSlowMotion` (ralenti).
  - **Grappin** : clic lu par le client (`client/WeaponFx`) -> `Remotes.UseGrapple(direction)` ; le serveur choisit la cible (cône
    `AimCone` autour de la visée, portée `Range`, pas de mur, pas dans sa propre base, pas déjà attrapé il y a peu), puis
    `Remotes.WeaponFx("Grapple", tireur, id, point, victime?)` à tous (crochet qui vole avec sa corde, accroche, suit la victime,
    revient ; « CHOPÉ ! ») et `Remotes.Grappled(tireur, durée)` à la victime : son client la ramène devant le tireur
    (`PlatformStand`, vitesse imposée). Visée : bras tendu, viseur, joueur ciblable entouré (Highlight, mêmes règles qu'au serveur).
  - **Pouvoir d'invisibilité** (14 oct., `PowerInvisible` 500 K$, objet « orbe fantôme » rangé avec les armes ;
    `server/PowerController`, `client/InvisibilityFx`, réglages `Config.Weapons.Invisibility`) : clic -> 6 s presque invisible,
    recharge 45 s depuis l'activation. Pensé pour ne pas être frustrant : soi-même à 60 % de transparence ; les autres le voient à
    96 % de loin mais à 72 % à moins de 10 studs (silhouette), étincelles aux pieds quand il bouge, fumée + son à la disparition et
    à la réapparition ; nom, étiquettes et familiers équipés cachés. **Brisé** par : ramasser un objet (`ItemInteraction`),
    commencer un vol (`StealController`), frapper / tirer au grappin, être touché (`WeaponController`) -> `PowerController.Reveal`.
    Impossible en portant un familier volé. L'orbe est rangé à l'activation (mains libres pour voler... ce qui le brise). La batte et
    le grappin touchent toujours un joueur invisible ; seule la surbrillance de visée du grappin l'ignore. Attributs `InvisibleUntil`
    / `InvisibleReadyAt` (heure serveur). Pastille « INVISIBLE 4 s » / « RECHARGE 23 s » pour le joueur.
  - Mains exclusives : arme en main -> pas de ramassage ni de vol ; objets portés ou familier volé -> l'arme sortie est rangée.
    Articulations : `client/Joints` (Motor6D ou AnimationConstraint).
- **Clés** (14 oct., Robux uniquement : produit `Key1` à 49 R$, `Config.Keys`) : [E] maintenu devant le portail d'une base
  adverse FERMÉE (bulle `client/BaseKeys`) -> `Remotes.UseKey` ; `LockController` vérifie (base fermée, pas la sienne, distance,
  clé en réserve, pas crochetée depuis moins de `ProtectAfter` = 20 s) et ouvre la base 10 s (attribut `ForcedOpenUntil`) :
  pas d'expulsion, vol possible, même si le propriétaire repasse sur le bouton ; ensuite elle se referme si son compte à rebours
  tourne encore. Sans clé, la bulle affiche « Clé : 49 R$ » et ouvre l'achat ; la clé est utilisée dès que l'achat est validé si
  le joueur est encore devant le portail. Clés sauvegardées (`keys`, attribut `Keys`). Messages `KeyUsed` (propriétaire) /
  `KeyOpened` (utilisateur). Produit Roblox : Id 3718327246.
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
5. **Anti-triche des lancers** (`Config.AntiCheat`) : au `ThrowItem`, le serveur note (table interne d'`ItemInteraction`,
   `GetThrowInfo`) le lanceur, la position de son HumanoidRootPart côté serveur, l'heure et sa `ThrowPower` ; un lancer moins de
   0,12 s après le précédent est marqué suspect ; reprendre l'objet en main efface ce lancer. Quand le trou avale un objet
   (`BlackholeController.rejectReason`), pas de points s'il n'a jamais été lancé (lâché, poussé, téléporté), s'il a été lancé par
   un autre que son `Owner`, trop vite, il y a plus de 8 s, depuis plus loin que la portée max (ThrowPower² / gravité × 1,25
   + 15 studs), ou s'il est arrivé plus vite que la vitesse de lancer ne le permet (≥ 90 % du temps minimal − 0,15 s). L'objet est
   quand même avalé ; un message `[AntiCheat]` est écrit côté serveur (sauf pour un simple objet lâché).
   Limite connue : un tricheur à portée qui attend le temps d'un vrai vol avant de téléporter son objet n'est pas détecté
   (il ne gagne alors rien de plus qu'un lancer réussi).

## Monétisation (Robux)

- Catalogue : `Config.Monetization` (Id = numéro créé sur create.roblox.com ; 0 = pas encore créé -> "BIENTÔT").
  Passes : 2X Argent (x2), VIP (+25 % d'argent, étiquette au-dessus de la tête, verrou +10 s), Sac à dos +1, Équipement +2,
  Chance Chanceuse (+0,5 de chance). Produits : boost de chance serveur (+1 de chance = raretés au-dessus de Commun x2,
  10 min prolongeables, annoncé à tous : attributs `LuckBoostUntil/By/At` de ReplicatedStorage), 1 et 10 tirages instantanés
  (chance de base 0,5).
- Effets centralisés dans `shared/Perks` (lit `Player.Pass_<Key>`) : utilisé par EconomyController (revenu), BlackholeController
  (argent et chance des manches), LockController (verrou), ItemInteraction + SessionData (sac, places d'équipement).
- `server/MonetizationController` : vérifie les passes à l'arrivée et après achat (`PromptGamePassPurchaseFinished`) ;
  `ProcessReceipt` idempotent : reçu (PurchaseId) noté dans la sauvegarde (`receipts`, 100 derniers), PurchaseGranted seulement
  après une sauvegarde réussie ; l'affichage (carte, ouverture, annonces) tourne à part pour qu'une erreur visuelle ne fasse
  jamais refuser un achat déjà accordé. Studio : `StudioTestPasses` simule des passes possédés.
- `client/RobuxShop` (module, 13 oct. : plus de bouton à part, onglets Passes R$ / Produits R$ / Chances de la Boutique) : passes / produits (vrai prix lu sur Roblox), **probabilités exactes**
  d'un tirage acheté (`LootEngine.odds` avec la chance réelle du joueur) + règle de la pitié ; bandeau du boost serveur.
  Les tirages Robux et leurs chances sont **cachés** si `PolicyService` indique `ArePaidRandomItemsRestricted`
  (pays où les objets aléatoires payants sont interdits) ou si la réponse échoue. Le créateur du jeu possède d'office ses passes.
- **Aspirateur à objets** (19 oct., passe `Vacuum` « ASPIRATEUR », 199 R$, `Config.Vacuum`, `Perks.HasVacuum`) : remplace
  l'aimant quand il est allumé (même bouton « ASPIRATEUR : ACTIF / ARRÊT », touche G) : aspire TOUS les objets à 32 studs,
  un toutes les 0,08 s, mêmes règles que [E] (`ItemInteraction`) ; +4 objets portés (`Perks.ExtraCapacity`). Côté client
  (`client/Magnet`) : tourbillon de particules violettes autour du joueur, et chaque objet aspiré vole jusqu'à lui en
  tournant (`Remotes.VacuumPull` : copie locale, le vrai objet est déjà dans ses mains).
- Serveurs : 8 joueurs maximum (une base chacun). `BaseManager` renvoie un 9e joueur avec un message « serveur plein ».
- `shared/TextFormat.upper` : majuscules avec accents (remplace `:upper()` partout).

## Familiers : style voxel et auras (15 oct.)

- `PetModelBuilder` : les 61 modèles de remplacement sont en **voxels** (toutes les pièces en blocs, tenons sur les
  blocs larges, yeux carrés avec reflet). Les 14 vrais modèles 3D (`PetMeshes`) sont inchangés.
- (Remplacé le 13 oct. par la taille par familier, voir ci-dessous.)
- **Auras** à partir d'Épique (`AURAS` dans `PetModelBuilder`, pièces marquées attribut `Aura`) : fumée violette +
  anneau au sol (Épique), flammes + lumière (Légendaire), étincelles roses (Mythique), auréole + paillettes (Divin),
  auréole dorée + 8 rayons de lumière autour (Sigma). Retirées des aperçus des fenêtres (`MenuKit.petViewport`).

## Rétention : cadeau du jour, quêtes, codes, amis, Rebirth (16 oct.)

`server/ProgressionController` (+ `server/Quests`), fenêtres `client/BonusMenu` (bouton Bonus) et `client/RebirthMenu`
(bouton Rebirth), réglages `Config.Daily / Quests / Codes / Friends / Rebirth`. Remotes `Bonus` (client -> serveur) et
`BonusResult`. Sauvegardé : `rebirths`, `daily { last, streak }`, `quests { day, list }`, `codes`.
- Récompenses en argent = secondes du revenu actuel du joueur (attribut `Income`, plancher `MinMoney`) : elles valent
  autant au début qu'à la fin. Les tirages donnés sont des tirages gratuits (œufs, mutation secrète possible).
- **Cadeau du jour** : un par jour UTC (minuit UTC = 1 h / 2 h en France), série de 7 (5 min de revenu, 1 tirage,
  15 min, 3 tirages, 30 min, 5 tirages, 1 h + 10 tirages), un jour manqué = retour au jour 1. La fenêtre s'ouvre seule à
  la connexion s'il y en a un à prendre (après le tutoriel).
- **Quêtes du jour** : 3 (facile / moyenne / difficile) de sortes différentes, tirées avec une graine joueur + jour
  (mêmes quêtes toute la journée). Sortes : Feed (objets avalés), Pulls (tirages du trou noir), Hatch (œufs éclos),
  Train (niveaux d'entraînement), Upgrade (achats Boutique), Steal (vols réussis). `Quests.Add(joueur, sorte, n)`.
- **Codes** : `Config.Codes` (LANCEMENT, TROUNOIR, MERCI pour l'instant), une fois par joueur, `Until` facultatif.
- **Amis** : +10 % de revenu par ami Roblox sur le serveur (5 max), attribut `FriendsHere`.
- **Rebirth** : il faut le monde Divin (7) et $1Qa (x10 à chaque Rebirth). On perd argent, mondes et améliorations de
  la Boutique (armes et invisibilité gardées) ; on garde familiers, œufs, mutations, entraînement, clés, achats Robux.
  Gain à vie : revenu x(1 + n) et +1 familier qui rapporte dans la base (jusqu'à +5). Colonne « Rebirth » dans la liste
  des joueurs. Double appui pour confirmer. `SessionData.Rebirth`, sauvegarde immédiate.
- Revenu = familiers x passes x monde x Rebirth x amis (`EconomyController.GetIncome / BonusMultiplier`).

## Places de la base et réserve (19 oct.)

- La base a **15 places** (+1 par Rebirth, jusqu'à +5 ; `Config.Pets.IncomeSlots`, `Config.GetIncomeSlots`). Seuls ces
  familiers s'y promènent et rapportent. Les autres sont **en réserve** : possédés (Index, fusion, échanges, sacrifice),
  ils ne rapportent pas. Avant, la base n'en montrait que 10 sans rien expliquer : « des familiers que j'ai mais qui ne
  sont pas dans ma base ».
- Choix du joueur (`shared/PetRoster`, sauvegarde `basePicks { placed, removed }`, `SessionData.SetInBase`,
  `Remotes.BasePick`) : Index > « Dans la base » / « Retirer ». Ordre de remplissage : ceux qu'il a placés, puis une place
  par espèce/forme par revenu, puis les doublons ; ceux qu'il a retirés ne reviennent jamais tout seuls. Base pleine de
  choix => « BASE PLEINE : RETIRE D'ABORD UN FAMILIER QUE TU AS PLACÉ ».
- Affichage : attribut `InBase` (formes dans la base, `EconomyController`), étiquette BASE / ÉQUIPÉ / RÉSERVE sur chaque
  case de l'Index, « DANS TA BASE » / « EN RÉSERVE » / « ÉQUIPÉ » dans le détail ; à l'éclosion, « +1 NOM » avec
  « DANS TA BASE » ou « EN RÉSERVE (INDEX) ».
- **19 oct. : remise à zéro de toutes les sauvegardes** (`Config.Save.Version` = 3 : `PlayerData_v3`, tableau des plus riches
  `RichestBoard_v3`). Les sauvegardes v2 restent intactes dans leur DataStore.

## Badges, groupe Roblox, mutations par la fusion (19 oct.)

- **Badges** (`server/BadgeController`, `Config.Badges`) : 13 badges (bienvenue, premier œuf, premier vol, duel gagné,
  Désert / Cosmos / Divin, premier Rebirth, 25 / 50 / 75 familiers découverts, familier Ultime, familier Sigma).
  `BadgeController.Award(joueur, clé)` au moment de l'action + une ronde toutes les 5 s sur la progression. Id = 0 =>
  ignoré : il faut créer chaque badge sur create.roblox.com (images prêtes dans `assets/badges`,
  `tools/icons/make_badges.py`) et mettre son Id. Aucun badge sur les mutations (secrètes). Rien n'est envoyé dans Studio.
- **Groupe Roblox** (`Config.Group`) : membre = +10 % de revenu (attribut `InGroup`, vérifié à l'arrivée puis toutes les
  2 min ; `EconomyController.BonusMultiplier`). Id = 0 => désactivé, rien d'affiché. Ligne d'invitation dans Bonus > Codes.
- **Mutations par la fusion** (SECRET, `Config.Fusion.Mutation`, `FusionController.ResultMutation`) : tirage secret
  habituel ; chaque familier muté mis dans la machine a 12 % de passer sa mutation ; 5 familiers de la même mutation =>
  mutation sûre + 30 % de la suivante. Le client ne reçoit que l'espèce (œuf normal). La machine accepte maintenant
  toutes les formes possédées (évoluées, mutées) ; le bouton « Auto » ne prend que les espèces normales.

## Mutations (16 oct., `Config.Mutations`)

- **SECRET** (demande de Chouaib) : rien dans le jeu n'en parle, ni l'Index (pas d'onglet, pas de récompense, pas de
  compteur), ni les chances affichées. Ultra rares, pour que le joueur qui en tire une hallucine.
- 3 mutations, une au plus par familier, tirées pour chaque familier d'un tirage **gratuit** (trou noir, roue des duels ;
  `PullRewards.RollMutation`, chance fixe, sans bonus de chance) : **Doré** 1/4 000 (revenu x2), **Diamant** 1/25 000 (x5),
  **Arc-en-ciel** 1/150 000 (x10). **Jamais sur un tirage acheté en Robux** (`Grant(..., paid = true)`) : Roblox exige
  d'afficher toutes les chances des objets aléatoires payants, et la mutation doit rester secrète.
- Le client ne reçoit que l'espèce dans `RewardsGranted` (carte des tirages = œuf normal) ; un muté n'est jamais vendu
  comme doublon.
- Identifiant : `<Id>__M<Mutation>`, combiné avec l'évolution : `<Id>__E3__MRainbow` (`PetCatalog.Compose`,
  `WithMutation`, `Mutation`, `FormsOf[espèce]` = les 12 formes). Revenu = base x évolution x mutation. Une mutation
  reste quand l'œuf évolue dans la capsule (`PetCatalog.Variant`). Les doublons se comptent forme par forme.
- Aspect (`PetModelBuilder.applyMutation`) : Doré = or brillant (Foil), Diamant = cristal bleu translucide (Glass),
  Arc-en-ciel = dégradé du bas vers le haut qui défile (`client/RainbowPets`, tag `RainbowPet`) ; le visage (pièces
  `EyeSocket`, `Iris`, `Pupil`, `Mouth`...) ne change pas ; étincelles à la couleur de la mutation.
- Éclosion (`client/Eggs`, `mutationReveal`) : l'œuf éclot comme un œuf normal de sa rareté, puis l'écran
  s'assombrit, la musique se tait, la caméra tourne autour du nid, et explosion aux couleurs de la mutation (colonne
  géante, 8 ondes, rayons, confettis, 3 répliques, secousse) avec « MUTATION SECRÈTE ! », le nom, « REVENU xN » en dégradé
  qui défile. Annonce spéciale à tout le serveur (« INCROYABLE ! ... »), toutes mutations.
- Base : ligne de couleur au-dessus du nom. Rien dans l'Index.

## Familiers sculptés et échelle des tailles (13 oct.)

- Modèles refaits avec Codex : `PetSculpt`, `PetSculptedModels`, `PetSculptedEffects`, `PetMotion`,
  `client/PetAuraAnimator` (détails : `docs/PET_VISUAL_REWORK.md`). `Config.Pets.ModelStyle = "Sculpted"`.
- **Échelle** (`shared/PetSizes`) : unité **J = la taille d'un joueur (5 studs)**. Chaque rareté a sa tranche, sans
  chevauchement (resserrée le 13 oct. : avant 0,7 à 7,5 J, la base devenait illisible) : Commun 0,5-0,65 J,
  Inhabituel 0,65-0,8, Rare 0,8-0,95, Épique 0,95-1,15, Légendaire 1,15-1,4, Mythique 1,4-1,7, Divin 1,75-2,15,
  Sigma 2,3-2,9 J. Chaque familier a SA taille dans sa tranche (`PetSizes.Heights`) : un pigeon 0,5 J, la Baleine
  Galaxie 2,9 J. La taille est la hauteur ; les familiers longs sont limités à 2 x leur taille en longueur et 26 studs au sol.
- Les grands familiers se promènent plus près du centre de la base (`PetWander.randomSpot(rng, petId)`), se volent
  depuis leur flanc (bulle et contrôle serveur élargis de `PetSizes.Radius`), sont réduits à 2 J quand ils suivent le
  joueur (1,6 J max) et à 1,4 J quand on les porte. Les effets (particules, lumière) grandissent avec eux.
- Toise : `lune run tools/check-pets.luau . sortie` (vérifie aussi que chaque familier a sa taille dans sa tranche)
  puis `python tools/pet-size-chart.py sortie a.jpg b.jpg`.

## Mondes (paliers)

- 15 oct. : 7 mondes (`Config.Worlds`) : Prairie, Désert 1 M$, Volcan 40 M$, Glace 1,5 B$, Abysses 75 B$, Cosmos 4 T$,
  Divin 250 T$. Le joueur paie le monde suivant dans la fenêtre **Mondes** (bouton orange du HUD, `client/WorldMenu` ->
  `Remotes.BuyTier` -> `server/TierController` -> `SessionData.AdvanceTier`). Palier sauvegardé (`tier`, attribut `Tier`).
  Rien n'est perdu au voyage ; chaque monde multiplie le revenu (`IncomeMultiplier` : x1,5 / x2,25 / x3,4 / x5 / x7,5 / x11,
  appliqué dans `EconomyController.GetIncome`). Arrivée : flash, « MONDE 3 : VOLCAN », son ; annonce aux autres
  (`Remotes.TierReached`).
- **Tout change pour le joueur** (`client/WorldSkin`, visuel dans `shared/Worlds`) : l'arène entière (sol, mur rond,
  chemins, kiosques...) est repeinte dans SON monde ; chaque base est repeinte dans le monde de SON PROPRIÉTAIRE (on voit
  chez les autres des bases désert, glace, cosmos) ; les arbres sont remplacés par le décor du monde (cactus, roches de lave,
  cristaux, coraux, astéroïdes qui tournent, colonnes dorées) ; air, teinte, nuages et particules (sable, braises, neige,
  bulles, étoiles, plumes) changent ; musique `Config.Sounds.Playlists[palier]` (seul le palier 1 a sa playlist pour l'instant).
  Repères : `server/MapGenerator` pose l'attribut `Skin` (rôle de couleur) sur chaque pièce et `DecorSpot` sur les troncs.
  Les stations (tapis, banc) gardent leur modèle (`StationLooks`). Tout est local : aucune donnée envoyée.
- Trou noir à paliers : voir la section suivante.

## Porter, jeter, lâcher (13 oct., `server/StealController`, `Config.Carry`, `Config.Sacrifice`)

- **Porter le sien** : [E] « Porter » sur un familier de SA base (même bulle client que « Voler », `client/BasePets`). Le
  porter dans sa base ne compte qu'après en être sorti (`wasOutside`) ; y revenir le repose (« Home »).
- **Vitesse** : poids = taille (`shared/PetSizes`, en J) ^ 3 ; capacité = force de lancer (`ThrowPower`) / 10 ;
  vitesse = 1 / (1 + 0,8 x poids / capacité), entre 30 % et 95 %. Au départ : Commun 95 %, Légendaire ~76 %, Divin ~50 %,
  Sigma 30 % ; force 60 : Divin ~75 %, Sigma ~55 %. Le temps max de transport s'allonge d'autant (60 s / vitesse, 180 s max). Le message de
  départ dit « LÉGER / LOURD / TRÈS LOURD : VITESSE x % ».
- **Jeter dans le trou** (pendant le Feeding, à moins de 22 studs du bord) : bouton « JETER DANS LE TROU ! » + touche E /
  manette X (`client/CarryControls`, `Remotes.ThrowPet`). Le familier est perdu pour son PROPRIÉTAIRE (le sien ou celui volé à un
  autre !) ; le porteur gagne 10 min du revenu de ce familier (x monde x passes), des points du tour (2 à 240 selon la rareté,
  donc des tirages) et autant de jauge du trou noir. Animation : il s'envole en tournoyant dans le cœur, étincelles, « +$ »
  (`client/BlackholeFx`, `HoleEvent "Sacrifice"`). Volé puis jeté : la victime est prévenue ; annonce à tous si Légendaire+.
- **Lâcher** : porteur frappé à la batte (ou éjecté par le dôme, mort, réapparu, parti, trop lent) -> le familier tombe à
  sa position et **rentre à pied** vers la base de son propriétaire (9 studs/s) : arc autour du trou dans l'allée puis entrée de la
  base (`shared/PetPath`, repère `Workspace.Map.LoosePets.<PetId>` + attributs `Path`, `PathStart`, `PathSpeed` ; rendu et bulle
  locale dans `client/LoosePets`). N'importe qui peut le ramasser en chemin (`Remotes.PickLoosePet`) : « Reprendre » pour son
  propriétaire, « Voler » pour les autres. Arrivé : il réapparaît dans la base. Propriétaire parti : il disparaît (il est
  toujours dans sa sauvegarde).
- Anti-duplication : il reste réservé dans la base de son propriétaire pendant tout ce temps ; chaque réservation est rendue
  une seule fois (fin d'un transport qui ne le lâche pas, ou fin du retour à pied).

## Échanges de familiers (13 oct., `server/TradeController`, `client/TradeClient`, `Config.Trade`)

- Bulle [T] « Échanger » (manette L1) sur les autres joueurs ; invitation à accepter en 15 s ; 6 s entre deux demandes.
- Fenêtre ÉCHANGE : chacun met jusqu'à 6 familiers non équipés (ni portés ni en duel) dans son offre, voit celle de
  l'autre en direct avec le revenu total de chaque côté ; avertissement rouge si on donne plus de 3 fois ce qu'on reçoit.
- **Double confirmation** : 1) PRÊT des deux -> offres BLOQUÉES ; 2) CONFIRMER cliquable après 3 s de relecture, par
  les deux. Toute modification (ou « MODIFIER ») annule les validations. Fermer la fenêtre = annuler.
- Transfert en une étape serveur : revérification, retrait chez A, retrait chez B (A remboursé si échec), ajouts croisés,
  sauvegarde des deux. Annulé si un familier offert disparaît (vol, fusion), départ, ou 4 min écoulées.
- Pas d'échange pendant un duel (et pas de duel pendant un échange : attribut `InTrade`).

## Marché entre joueurs (19 oct., `server/MarketController`, `client/MarketMenu`, `Config.Market`)

- Tuile « Marché » du HUD. Onglets : **Acheter** (ventes des autres joueurs du serveur : aperçu, rareté, revenu, vendeur,
  prix, ACHETER ; « INDISPONIBLE » si le vendeur l'a équipé entre-temps), **Vendre** (choisir un familier libre, prix
  tapé « 25K / 3M / 1.5B », proposé = 10 min de son revenu), **Mes ventes** (RETIRER).
- Le vendeur garde son familier jusqu'à l'achat ; 3 ventes au plus par joueur ; un exemplaire ne peut être en vente
  qu'une fois ; les ventes ne sont pas sauvegardées (elles disparaissent quand le vendeur quitte le serveur).
- Achat en une étape serveur sans attente : revérification (deux sauvegardes chargées, familier toujours libre, argent),
  retrait chez le vendeur, argent pris à l'acheteur (vendeur remboursé si échec), ajout chez l'acheteur (le familier tombe
  dans sa base, `Celebrate`), argent au vendeur moins `Config.Market.Tax` (0 pour l'instant), sauvegarde des deux, message
  « VENDU À ... » au vendeur. Remotes : `Market` (List / Cancel / Buy / Refresh, réponse ok + message), `MarketUpdate` (liste).
- Test hors Studio : `lune run tools/check-market.luau .` (PASS).

## Duels de familiers (13 oct., `server/DuelController`, `client/DuelClient`, `client/DuelFx`, `shared/DuelStats`, `Config.Duel`)

- **Défi** : bulle [F] « Défier en duel » (manette Y) créée localement sur les autres joueurs (12 studs). La cible a 15 s
  pour ACCEPTER / REFUSER. 6 s entre deux défis. Pas de duel en portant un familier.
- **Choix** (60 s) : fenêtre DUEL DE FAMILIERS ; chacun choisit un familier de sa base (pas l'équipé), voit celui de
  l'autre avec ses PV / attaque ; **une rareté d'écart au maximum** (cartes grisées sinon) ; les deux valident « PRÊT »,
  changer de familier annule les deux validations (pas d'arnaque). Fermer la fenêtre = annuler.
- **Arène** : jusqu'à 3 arènes en même temps, qui flottent au-dessus du trou noir (y = 165) ; île volante en blocs à
  tenons (sol en damier violet, muret doré, piliers à flamme, estrades rouge / bleue, rochers en dessous) dessinée par
  chaque client d'après `Workspace.Duels.Duel_N` (attributs). Les joueurs y sont téléportés et immobilisés, caméra fixe.
- **Combat** : PV 150 et attaque 12, x (1 + 0,35 par rareté au-dessus de Commun) x (jusqu'à +10 % pour le plus grand de sa
  tranche de taille) ; les familiers frappent chacun leur tour toutes les 0,55 s, dégâts x 0,8 à 1,2, 12 % de coups
  critiques x 2 ; chaque clic du joueur (bouton « ENCOURAGE », clic, espace) donne +5 % au prochain coup (+60 % max,
  8 clics/s comptés). 45 s max (puis le plus de PV en % gagne). Abandon (départ, réinitialisation, ANNULER) = défaite.
- **Roue** (gagnant) : roue 3D de 8 cases au fond de l'arène, vue par tous : SON FAMILIER (1/8, transfert anti-duplication
  comme le vol), 2 min d'argent x 2, 5 min, 10 min (revenu du gagnant, 50 $/s minimum), 1 tirage, 3 tirages, RELANCE.
  Pendant tout le duel, les deux familiers sont réservés dans leur base (ni volables ni fusionnables).

## Paliers du trou noir (13 oct., `server/BlackholeTiers`, `client/BlackholeFx`, `Config.Blackhole`)

- **Jauge commune au serveur** : chaque objet avalé (lancer valable) ajoute sa valeur (au moins 1, sans multiplicateur).
  Jauge à remplir = `GaugeNeed[palier]` x (joueurs ^ 0,6) ; solo : 40, 50, 60, 75, 90, 110, 130 (~3 tours par palier).
  Pleine : le trou monte d'un palier tout de suite (flash, onde de choc, secousse, « LE TROU NOIR ÉVOLUE ! »).
  État en attributs de ReplicatedStorage (`HoleTier`, `HoleGauge`, `HoleNeed`, `HoleCollapse`, `HoleJackpotUntil`),
  moments forts par `Remotes.HoleEvent`. Le palier n'est pas sauvegardé (il appartient au serveur).
- **Une mécanique par palier, toujours un bonus** :
  1 Éveil (vortex violet, rien de plus) • 2 Éruption (3 roches de lave x3 recrachées dans l'arène toutes les 15 s,
  `ItemSpawner.SpawnSpecial`) • 3 Cible (point d'impact prévu à moins de 14 studs du centre : x2) • 4 Abysses
  (6 tentacules ; un objet lancé tombé à moins de 14 studs du bord, depuis moins de 5 s, est rattrapé et compte) •
  5 Gravité (objets sauvages attirés jusqu'à 52 studs du centre, sans y tomber ; 3 météorites de 5 points toutes les 18 s) •
  6 Supernova (combo : +0,25 par lancer réussi à moins de 5 s du précédent, x2 max) • 7 Divin (jackpot x5 pendant 10 s,
  une fois par tour, annoncé).
- **Effondrement** : jauge du palier 7 pleine -> à la digestion suivante, score du tour x2 avant les tirages, puis un
  familier Légendaire au 1er contributeur du cycle et un Épique aux 2e et 3e, puis retour au palier 1.
- Aspect (client, blocs à tenons) : muret en damier à tenons au bord (2 tons + chapeau, comme les murs de l'arène, couleurs reprises
  des mondes : `Wall` dans `Config.Blackhole.Tiers` ; néon seulement pour la lave, les abysses et les effets) + décor propre (vortex,
  roches et lave, anneaux de cible, tentacules animés, disque de matière et éclairs, pointes qui pulsent et ondes de choc,
  anneaux d'or et rayons). L'ancien décor est aspiré dans le cœur au changement. Jauge en panneau au-dessus du trou
  (taille en studs : petite de loin). Bulles « CENTRE ! x2 », « ATTRAPÉ ! », « COMBO x1.5 ».
- Test dans Studio : `game.ReplicatedStorage:SetAttribute("DebugHoleTier", 5)` (côté serveur) passe au palier 5 ;
  8 = jauge du palier 7 pleine (effondrement à la prochaine digestion).

- **Retour dans un monde déjà visité** (13 oct.) : fenêtre Mondes, bouton « Y ALLER » sur les mondes déjà débloqués
  (`Remotes.GoToWorld` -> `TierController` -> `SessionData.SetWorld`). Gratuit. Deux valeurs sauvegardées : `tier` (attribut
  `Tier`) = le monde le plus loin débloqué, qui garde le bonus de revenu ; `world` (attribut `World`) = le monde où le joueur
  se trouve : apparence de l'arène et de sa base (`client/WorldSkin`), musique, cadre du trou noir. Acheter le monde suivant
  y emmène directement.
- **Trou noir aux couleurs du monde** (13 oct.) : le muret autour du trou prend la palette du monde du joueur (WallA / WallB /
  WallTop, chapeau lumineux si le monde l'a) et 8 décors du monde l'entourent (buissons, cactus, roches de lave, cristaux,
  coraux, astéroïdes qui flottent, colonnes d'or). Le décor du palier du trou (vortex, tentacules...) se pose par-dessus.

## Sons et musique

- 13 oct. : une playlist par monde (`Config.Sounds.Playlists[1..7]`), 2e version : fond CALME (lo-fi, chill-hop, guitare,
  piano doux ; APM et DistroKid sous licence Roblox), volume musique 0,12. Vérifiés :
  chargés et de plus d'une minute ; choisis sur titre et fiche, pas écoutés). La musique suit l'attribut `World`.

- Tout est côté client. `client/Sounds` (module) : `play(nom)` (son 2D, pour soi), `playAt(nom, position)` (son 3D, Attachment
  dans Terrain, entendu jusqu'à ~140 studs), `setPlaylist(palier)` (13 oct. : une playlist par palier, `Config.Sounds.Playlists`,
  morceaux mélangés enchaînés en fondu de 2 s ; palier 1 = 5 morceaux calmes APM ; attribut joueur `Tier`, 1 par défaut),
  `duck(s)` (baisse la musique pendant un jingle). Deux SoundGroups : Music (0,3) et Effects (0,7). Sons préchargés.
- Interface : clic sur tout bouton `UiStyle` (`UiClick`), ouverture de fenêtre (`WindowOpen`), erreur / pas assez d'argent
  (`Error`), achat d'amélioration (`Cash`), récompense d'Index (`Coins`), fusion (`FusionDone`), nouveau modèle de tapis / banc
  (`ModelUnlock`), jingle à chaque changement de phase (`PhaseFeeding` / `PhaseDigesting`), tic les 5 dernières secondes (`Tick`).
- `client/SoundController` branche les sons sur le jeu sans rien envoyer au serveur : palier (musique), phase (jingle), `ItemGrabbed`, `RoundScore`,
  `Knockback`, objet `Consumed` (3D au trou), `RewardsGranted`, `FusionResult`, `Announcement`, `Upgrade_*`, niveaux, vol
  (`CarryingPet`, `StealResult`, `StealNotice`), base `Locked` (3D au bouton). Lancer : `InteractionController` ; atterrissage
  d'un familier : `BasePets`.
- Ids et volumes dans `Config.Sounds` (banques sous licence Roblox : APM Music, Pro Sound Effects, DistroKid). Ne jamais utiliser de
  sons repris d'autres jeux (le Creator Store en contient beaucoup : Geometry Dash, Undertale…).
- Au chargement de la sauvegarde, les changements de niveaux / améliorations ne déclenchent ni son ni message (`DataLoaded`).

## Effets de satisfaction (`client/Effects`, réglages `Config.Effects`)

- **Points qui s'envolent** : quand un objet dont tu es `Owner` est avalé (`Consumed`), sa position est notée ; à la hausse de
  `RoundScore`, un "+X" doré (BillboardGui, taille fixe à l'écran) jaillit de cet endroit, monte et s'efface (au-dessus du trou sinon).
- **Ouverture animée** d'un tirage rare (index >= `RevealMinRarity`, 4 = Épique) : le plus rare des `RewardsGranted`, et chaque
  `FusionResult`. Fond sombre, rayons tournants, boîte "?" qui tremble 1,1 s, puis flash, familier 3D qui pivote (ViewportFrame),
  nom + rareté, confettis, secousse, son `RareDrop`. 3,5 s ou un clic ; plusieurs ouvertures s'enchaînent (file).
- **Secousses d'écran** (après la caméra Roblox, `BindToRenderStep`) : éjection par le dôme (forte), ouverture rare (moyenne),
  "on vole ton familier" (légère).

## Tutoriel (`client/Tutorial`)

- Affiché une seule fois : attribut `TutorialDone` (sauvegardé, champ `tutorialDone`). Les anciennes sauvegardes sans ce champ qui
  ont déjà des familiers ou de l'argent sont considérées comme terminées. Le client attend `DataLoaded` (8 s max) avant de décider.
- 3 étapes : (1) ramasser un objet (`ItemGrabbed`), (2) le lancer dans le trou (hausse de `RoundScore`), (3) voir ses familiers
  (`RewardsGranted` avec tirages, fin 3 s après). Panneau en bas de l'écran + "⬇" au-dessus de la cible + rayon doré (Beam) du
  joueur à la cible : objet le plus proche, trou noir (ou un objet si on n'en tient plus), puis sa base. Pendant la digestion,
  l'étape 2 dit d'attendre. Bouton PASSER. Fin -> `Remotes.TutorialDone` -> `SessionData.SetTutorialDone`.

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
  - `MapGenerator` : arène ronde en damier de dalles à tenons (sol invisible dessous), mur d'enceinte circulaire, chemins
    en dalles beiges, arbres en cubes, trou noir, dôme, 8 bases clôturées (clôtures de ranch en X). Style : docs/DIRECTION_ARTISTIQUE.md.
  - `DayNightController` : nuit pendant le Feeding, jour pendant la Digestion (transition de 4 s).
  - `BaseManager` : une base par joueur (`BaseIndex` sur le Player, `OwnerName` sur la base), spawn sur sa base.
  - `ItemSpawner` : objets dans les bases occupées pendant le Feeding.
  - `ItemInteraction` : ramassage / lancer / lâcher (autorité serveur).
  - `BlackholeController` : consommation, dôme répulsif, récompenses.
  - `TrainingController` : stations tapis (Vitesse) et banc (Force), niveaux, XP, panneaux « Amélioration ».
  - `StationLooks` : modèle du tapis et du banc selon le niveau (5 modèles × 5 niveaux).
  - `LeaderboardController` : tableau « LES PLUS RICHES » dans l'arène (top 10 de tous les serveurs, `Config.Leaderboard`).
    Chaque minute : écrit l'argent des joueurs dans l'OrderedDataStore `RichestBoard_v2` (valeur = log10(argent + 1) × 10¹²,
    pour ranger les très grands nombres dans un entier) puis relit le top. Affichage seulement : la vraie sauvegarde reste
    `SessionData`. Sans DataStore (Studio sans accès API) : affiche les joueurs du serveur. Dans la liste des joueurs Roblox,
    « Argent » est un `IntValue` (trié, nombre complet) ; le HUD et le tableau gardent l'affichage abrégé.
  - `BasePetsController` : familiers qui vivent dans chaque base (repères + trajets décidés par le serveur, affichés par le client).
  - `LockController` : bouton de verrouillage, portail, expulsion des intrus.
  - `EconomyController` : revenu passif des familiers, achats de la boutique (`Remotes.BuyUpgrade`).
  - `SessionData` : données joueur (niveaux/XP Vitesse et Force, money, pets, équipés, pitié, upgrades) → attributs Player + leaderstats.
    **Sauvegardées** dans le DataStore `PlayerData_v2` (`PlayerData_v2_studio` dans Studio : les tests ne touchent jamais
    les vrais joueurs ; version dans `Config.Save.Version`, la changer remet tout à zéro) (clé `u_<UserId>`) : chargement à la connexion, sauvegarde à la
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
  - Icônes : `shared/Icons` (27 icônes 2D cartoon à gros contour noir, dessinées par `tools/icons/make_icons.py`, PNG dans
    `assets/icons`, envoyées sur Roblox ; `Icons.image(parent, nom)`). Plus aucun émoji dans l'interface ni le décor.
  - `HUD` (14 oct., écran désencombré) : boutons Boutique / Index / Mondes à gauche avec pastilles, Force / Vitesse /
    argent en chiffres italiques en bas à gauche ; en haut au centre UNE pastille (horloge + tirages de la manche) et dessous
    une pile `TopStack` qui n'affiche que l'utile (boost de chance, consigne 8 s après chaque phase ou objectif du transport,
    carte des tirages) ; bandeau de phase au milieu seulement au changement. Bas du centre réservé à la barre d'objets
    (`ScreenScale.BOTTOM_RESERVED` = 100) : boutons d'action (JETER, ARRÊTER, encourager), pilule d'invisibilité et capsules
    juste au-dessus, tutoriel encore au-dessus, messages (`Toast`) à 60 % de la hauteur.
    **Tactile** : écran de référence 1280 x 640 (interface un peu plus grande), argent / stats en haut à gauche, menus en
    tuiles carrées juste dessous (loin du joystick), fenêtres ouvertes entre les tuiles et le bouton de saut et réduites
    pour tenir (`MenuKit`, `TOUCH_LEFT_RESERVED` / `TOUCH_RIGHT_RESERVED`), 6 capsules max plus petites.
    **Aperçu téléphone (Studio)** : `workspace:SetAttribute("DebugPhone", Vector2.new(844, 390))` avant Play : chaque
    interface est dessinée dans un cadre de téléphone, en mode tactile, avec les zones du joystick et du saut.
  - Menus reconstruits façon Steal an Egg : `UiStyle` (fenêtres à tenons, en-tête coloré à rayures, croix rouge, cartes
    vives à rayons de soleil, pastilles), `MenuKit` (une fenêtre à la fois, onglets à droite, aperçus 3D),
    `ShopMenu` (cartes qui défilent, onglets Entraînement / Bonus / Combat puis Passes R$ / Produits R$ / Chances fournis par
    le module `RobuxShop`), `IndexMenu`, `FusionMenu`.
  - `Toast` (ModuleScript) : gros message temporaire au centre de l'écran (`Toast.show(texte, couleur)`).

## Carte (`Workspace.Map`, générée)

- Trou noir centré en (0, 0, 0) : `BlackholeZone` (disque 80x80), `HoleRing`, `BlackholeCore`, `BlackholeHalo`, `BlackholeDome`.
- `LooseItems` : objets ramassés ou lancés.
- `Base_1` … `Base_8` en cercle (rayon 215, ~150 studs entre l'entrée et le trou) : `BasePart`, `SpawnLocation`, `SafeZone` (visuel), `TreadmillZone`,
  `SpawnPoints` (4 coins), `ItemSpawns`, `Fence` (clôture en bois, entrée côté trou noir). Un chemin de terre (`Map.Paths`) relie chaque base au trou.
- `Kiosks` : boutique + machine de fusion, entre deux bases (un kiosque toutes les deux bases).
- `Leaderboard` : grand panneau en bois « LES PLUS RICHES » entre la 2e et la 3e base (rayon 190), lisible des deux côtés.

## Pas encore dans le MVP

- Familiers visibles physiquement dans la base, vol d'un objet dans les mains d'un autre joueur.
- (fait le 15 oct.) Œufs + couveuse + capsule d'évolution (3 stades, hasard) : voir `docs/INCUBATION.md`.

## Bases (15 oct.)

- 84 x 84 (avant 56), plan dans `shared/BaseLayout` (une seule source pour la carte, les familiers et les œufs) :
  entrée côté trou noir avec « ZONE SÛRE », **2 palettes à objets à l'avant** (de chaque côté du bouton de verrouillage),
  la **prairie** au milieu où se promènent les familiers (`PetWander`), la **couveuse** au fond (sol de paille, rebord
  ouvert au milieu, 12 nids, panneau « COUVEUSE » avec le nom du propriétaire au-dessus). Dehors, derrière la clôture
  du fond : la capsule d'évolution (cylindre de stase).
- Sauvegarde DataStore, familiers visibles / équipables, support mobile du lancer.
