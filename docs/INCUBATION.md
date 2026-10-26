# Œufs et éclosion

Toutes les nouvelles récompenses arrivent dans la base sous forme d’œufs : manches, roue des duels, tirages Robux, fusion et effondrement du trou noir. Les échanges, vols et remboursements transfèrent toujours les familiers déjà éclos. Les anciens familiers sont conservés.

| Rareté | Modèle | Durée |
| --- | --- | --- |
| Commun | Coquille crème tachetée | 15 s |
| Inhabituel | Vignes et pousse feuillue | 30 s |
| Rare | Coquille bleue et cristaux de glace | 1 min |
| Épique | Améthyste et rune lumineuse | 3 min |
| Légendaire | Bandes dorées, couronne et rubis | 5 min |
| Mythique | Écailles, cornes et fissures de lave | 10 min |
| Divin | Coquille nacrée, plumes et auréole | 20 min |
| Sigma | Coquille sombre, fragments cosmiques et étoile | 30 min |

Les durées se règlent dans `Config.Eggs.Seconds`. Elles sont fixées à l’attribution : modifier la configuration ne redémarre pas les œufs déjà obtenus. Tous incubent en parallèle, y compris hors ligne. Au retour, les échéances terminées sont traitées après chargement de la sauvegarde.

**15 oct. (Claude) : un nid par œuf.** La couveuse au fond de la base (`shared/BaseLayout`) a 12 nids : chaque œuf a le sien, les 12 premiers à éclore sont posés et gardent leur nid jusqu’à l’éclosion ; au-delà, « +N ŒUFS EN ATTENTE » sur le panneau (attribut `Waiting`). Plusieurs œufs reçus ensemble tombent dans leurs nids l’un après l’autre. Chaque œuf affiche sa rareté, le temps restant et une barre ; il est d’autant plus gros qu’il est rare.

**Montée en tension et éclosion** (`client/Eggs`, `Config.Eggs.BuildUp`) : dans les dernières secondes (2 s pour un Commun, 7 s pour un Sigma), l’œuf tremble de plus en plus vite, s’élève, tourne et brille ; Divin et Sigma sont entourés d’éclats qui tournent. À l’éclosion (un `Remotes.EggHatched` par œuf), la coquille éclate et l’effet grandit avec la rareté (table `SPECTACLE`) : gerbe d’étincelles et éclair (tous), ondes de choc au sol (Inhabituel+), colonne de lumière (Épique+), confettis + secousse + bandeau « ÉCLOSION LÉGENDAIRE ! » (Légendaire+), rayons qui tournent + flash blanc (Mythique+), double explosion d’étoiles (Sigma). Le grand écran du familier rare (`client/Effects`) passe ensuite.

**Le familier** : s’il fait partie des familiers affichés dans la base (les 10 meilleurs), il sort de son nid et part se promener (`BasePetsController.Celebrate` avec la position du nid) ; sinon il apparaît un instant au-dessus du nid (« +1 NOM, DANS TA COLLECTION ») puis s’envole. Avant cette correction, un familier hors des 10 meilleurs disparaissait sans rien montrer.

Avant éclosion, aucun revenu, équipement, fusion, échange ou vol n’est possible. Les œufs sont pris en compte dans la limite des cinq exemplaires par familier pour la vente automatique des doublons. La découverte dans l’Index intervient à l’éclosion. L’identité du familier est tirée par le serveur à l’attribution ; l’interface montre l’œuf en attendant.

## Capsule d’évolution (15 oct.)

Chaque base a une **capsule d’évolution** dehors, derrière la clôture du fond (côté droit) : un cylindre de stase de science-fiction (socle de métal, cylindre de verre avec brume froide, anneaux lumineux qui pulsent, tuyaux, émetteur, console « ÉVOLUTION »). Réglages : `Config.Evolution`.

- Le propriétaire choisit un de ses œufs en couveuse (bulle [E] « Mettre un œuf », fenêtre de choix) : l’œuf vole jusqu’à la capsule. Il **n’éclot plus tout seul** : le joueur se prive de son familier pour tenter d’en avoir un meilleur.
- **3 stades** : Normal → Évolué (revenu x3, plus grand, petite couronne d’acier argenté à 4 pointes et gemme saphir) → Ultime
  (revenu x8, plus grand, grande couronne d’or à 8 pointes, 4 gemmes rubis et flèche). Depuis le 25 oct. : couronnes en
  briques posées sur la tête, qui suivent ses mouvements, sans néon ni étincelles ni anneau (`PetModelBuilder.addCrown`). Les formes évoluées sont des familiers à part entière (`<Id>__E2`, `<Id>__E3` dans `PetCatalog.ById`, pas dans les tirages ni dans l’Index) : base, échanges, vols, duels, revenu.
- **20 oct. (retour d'un joueur) : la capsule ne fait plus éclore un œuf avant l'heure.** Avant, on mettait un œuf de
  20 min dans la capsule et on l'ouvrait tout de suite. Maintenant, 2 étapes affichées sur le panneau :
  1. **Incubation** : l'œuf finit son temps normal dans la capsule (« 1. INCUBATION : 12:34 ») ; [E] refusé avant.
  2. **Tentatives d'évolution** : la 1re a lieu 4 fois la durée d'éclosion de la rareté après la fin de l'incubation,
     la 2e 12 fois après la 1re (± 25 %, plus tôt dans une capsule de monde supérieur). Chaque tentative est un **tirage
     au sort visible** : le panneau affiche la chance (Prairie : 60 % pour ★★, puis 30 % pour ★★★, mêmes probabilités au
     total qu'avant), clignote « TENTATIVE EN COURS... » pendant 1,6 s, puis RÉUSSIE (gerbe) ou RATÉE (nuage gris : il
     garde son stade). `EggIncubation.StageChance / FirstAttemptAt / CanOpen`.
- Le joueur l’ouvre quand il veut après l'incubation (bulle [E] « Faire éclore », à maintenir) : l’éclosion part de la capsule avec le spectacle des raretés au-dessus (« ÉCLOSION ÉPIQUE ÉVOLUÉ ! »), et le familier rentre dans la prairie.
- **La capsule suit le niveau du joueur** (monde le plus loin atteint, attribut `CapsuleTier`) : plus grande d’un monde à l’autre et décorée au thème du monde (`client/CapsuleDecor`) — Désert : obélisques à pointe dorée et sable ; Volcan : roches fissurées de lave et braises ; Glace : pics de cristal, givre, neige ; Abysses : spirale lumineuse, algues, bulles ; Cosmos : anneaux d’orbite et planètes ; Divin : double auréole, grandes ailes de lumière, rayon jusqu’au ciel, plumes. Et meilleure : par monde au-dessus de la Prairie, tentatives 6 % plus tôt et 2 points de chance passent de « n’évoluera pas » à « Ultime » (Divin : 36 % plus rapide, 30 % d’Ultime). Le panneau et la fenêtre de choix l’affichent.
- **Familiers évolués partout** : plus forts (stats données quand ils sont équipés et puissance en duel x1,4 / x2, `PowerMultiplier`) ; dans l’Index, onglets ★ / ★★ / ★★★ sur la fiche (aperçu, revenu, stats, équiper, récompense propre à chaque forme), étoiles sur la case, compteur « Évolutions x/150 », « Réclamer tout » compris ; étiquette dorée « ★★ ÉVOLUÉ » / « ★★★ ULTIME » dans la base ; échanges et duels les proposent. La fusion ne les prend pas.
- Serveur : `SessionData.StartEvolution / TickEvolution / HatchEvolving`, `EggController` (état publié sur `Base_N.EvolutionCapsule.EvolutionMachine`, `Remotes.Evolution`) ; client : `client/EvolutionMachine`. Une case de plus par Rebirth (`Config.GetCapsuleSlots`).
- **26 oct. : menu de la capsule** (`client/CapsuleMenu`, pensé pour les enfants qui lisent peu, `dataset_and_pipeline/UI_UX_GUIDELINES.md` §7) : [E] devant la capsule ouvre toujours ce menu. COMMENT ÇA MARCHE en 3 images (un œuf » un chrono » ★★★) ; TA CAPSULE : une carte par case (œuf en 3D, étoiles dorées, « PRÊT DANS 1:23 » et sa barre, puis « ESSAI ★★ DANS 4:10 » et sa chance, ou « AU MAXIMUM ! » / « IL NE GRANDIRA PLUS », bouton OUVRIR qui ferme le menu pour voir l'éclosion) ; TES ŒUFS : les œufs de la couveuse avec METTRE ; « ? » pour l'explication complète. Le serveur publie chaque case (attribut `ChamberList` : id, rareté, stade, début, fin, prochain essai, fini ; jamais le stade maximum) et OUVRIR ouvre l'œuf de CETTE case (`Remotes.Evolution("Hatch", id)`, `SessionData.HatchEvolving(player, time, eggId)`). Panneau au-dessus de la capsule en mots simples : PRÊT DANS, ESSAI ★★, CHANCE, OUVRIR.

## Mutations

Un œuf peut contenir un familier muté (Doré, Diamant, Arc-en-ciel, `Config.Mutations`) : même durée d'incubation que sa
rareté, mais éclosion plus spectaculaire (Doré +1 rang de spectacle, Diamant +2, Arc-en-ciel +3) et bandeau à la couleur de la
mutation. Dans la capsule d'évolution, la mutation est gardée (`PetCatalog.Variant`).

## Sauvegarde et serveur

`SessionData.eggs` contient des lots avec identifiant unique, familier, quantité, début et échéance UTC. Les anciennes sauvegardes sans ce champ restent compatibles ; le DataStore v2 est conservé. Le retrait des œufs et l’ajout des familiers s’effectuent sans suspension, dans la même opération. Les tables de sauvegarde sont copiées avant `UpdateAsync`, pour empêcher un reçu concurrent d’être enregistré sans sa récompense.

`EggController` vérifie les échéances chaque seconde et réplique un repère par œuf posé (rareté, dates, nid ; jamais le familier). Aucun événement client ne peut accélérer ou décider une éclosion. Les effets sont locaux et limités à proximité de la caméra.

## Vérification

Exécuter `lune run tools/check-eggs.luau . <dossier-sortie>` depuis le projet. Le test construit les huit modèles et exécute les vrais modules d’incubation, sauvegarde, tirages, reçus et réplication avec des services simulés. Il couvre les limites de temps, le chargement asynchrone, les anciens profils, la reconnexion, les doublons, les sauvegardes concurrentes et les échecs de sauvegarde des achats. Les avertissements de sauvegarde injectés pendant ce test sont attendus.

Un essai Studio reste nécessaire pour vérifier le rendu des particules, les étiquettes sur mobile, les animations et la synchronisation avec deux joueurs. Les vérifications hors Studio ne mesurent pas les performances graphiques.

L’Aura Astrale utilise le produit développeur `3718429232` et le déblocage permanent `Upgrade_AstralAura`, sauvegardé après validation du reçu. Son bouton se bloque pendant la validation puis indique « Possédé ». Le prix affiché est récupéré auprès de Roblox, avec 19 R$ comme valeur de secours.
