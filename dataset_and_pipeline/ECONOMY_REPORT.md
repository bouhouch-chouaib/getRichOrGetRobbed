# Rapport économique (phase 1.7)

**État au 25 oct. 2026 : étapes 1 à 5 faites. Dans le jeu : premier lot (règles 3, 5, 6, 11, 13 et la batte, voir
5.3), deuxième lot (verrou à cycle, bouclier, plafond, vol utile, voir 5.5), Rebirth (règles 15 et 16, voir 5.6) et
couronne du plus riche (règle 9, voir 5.7), pile « prochain objectif » (règle 12, voir 5.8) et jeu entre amis
(règles 17 à 19, voir 5.9).** Restent au choix de Chouaib : gros butin signalé à tous (10), ruée des voleurs (14). Rien n'a encore été
vérifié dans Studio. **Rien n'a encore été changé dans le jeu** :
les règles proposées seront d'abord prouvées par le simulateur (étape 5).

Règle suivie : aucun chiffre « au doigt mouillé ». Tout ce qui suit vient du code ou d'un calcul refaisable.

## Comment c'est mesuré

- Code lu : `src/shared/Config.lua`, `server/StealController`, `server/LockController`, `server/EconomyController`,
  `server/PullRewards`, `server/WeaponController`, `server/MarketController`, `server/SessionData` (vitesse, Force),
  `shared/LootEngine`, `shared/PetCatalog`, `shared/PetSizes`, `shared/PetRoster`, `shared/PetStats`,
  `shared/BaseLayout`, `server/MapGenerator`, `game_design_matrix.json`.
- Carte, vitesses, poursuites : `python -I dataset_and_pipeline/economy_map_metrics.py`. Le script lit les valeurs
  dans `Config.lua` (rien n'est recopié à la main) et refait la géométrie de `MapGenerator` / `BaseLayout`.
- Progression : `lune run tools/sim-economy.luau . 200 30`, le simulateur du 20 oct. (un joueur seul, sans vol),
  200 parties de 30 h.
- Depuis l'étape 2 : `python -I dataset_and_pipeline/economy_simulator.py solo|segments`. Les valeurs du jeu sont
  relues à chaque lancement par `tools/export-economy.luau` (Lune charge les vrais modules et écrit
  `economy_data.json`). Avec `--no-capsule`, il donne les mêmes résultats que le simulateur Luau (1er Rebirth 8,5 h
  contre 8,6 h, mêmes sources d'argent à 0,1 point près) ; par défaut il joue aussi la capsule d'évolution.

---

## 1. La carte et les vitesses

### Distances (studs)

| Trajet | Distance |
| --- | --- |
| Spawn de la base -> bord du trou noir | 181 |
| Entrée de la base -> bord du trou noir | 133 |
| Entrée -> zone où l'on peut jeter un familier (rayon 62) | 111 |
| Base voisine : centre à centre / entrée à entrée | 165 / 132 |
| 2 bases plus loin / 3 / en face (entrée à entrée) | 245 / 320 / 346 |
| **Voleur : d'un familier au hasard jusqu'à SA base**, base voisine (médiane) | **109** (71 à 145) |
| Idem, 2 bases plus loin / 3 / en face (autour du dôme) | 241 / 339 / 392 |
| Voleur : d'un familier jusqu'à la zone de sacrifice | 151 |

Les clôtures font 4 studs et s'enjambent (bases ouvertes, décision du 25 oct.) : le voleur va tout droit.

### Vitesses

- Marche : 16 au départ, 46 au niveau 60 de Vitesse, **61** avec un familier équipé (+30 niveaux au plus).
  La carte ne grandit pas : tous les trajets sont divisés par 2,9 (3,8 avec le familier).
- Portée d'un lancer (45°) : 25 studs à Force 70 (départ), 130 au niveau 30, 319 au niveau 60.
  **Dès le niveau 33 de Force, on lance depuis sa propre palette** : on n'a plus besoin de sortir de sa base.

### Vitesse en portant un familier (x vitesse de marche)

Formule `Config.Carry` : `1 / (1 + 0,8 x taille³ / (Force / 10))`, bornée entre 0,3 et 0,95.

| Rareté (taille moyenne) | Force 70 (départ) | Force 160 (niv. 30) | Force 250 (niv. 60) | Force 340 (+ familier) |
| --- | --- | --- | --- | --- |
| Commun (0,57) | 0,95 | 0,95 | 0,95 | 0,95 |
| Épique (1,05) | 0,88 | 0,95 | 0,95 | 0,95 |
| Légendaire (1,27) | 0,81 | 0,91 | 0,94 | 0,95 |
| Mythique (1,55) | 0,70 | 0,84 | 0,89 | 0,92 |
| Divin (1,95) | 0,54 | 0,73 | 0,81 | 0,85 |
| Sigma (2,6) | 0,33 | 0,53 | 0,64 | 0,71 |

Jusqu'au Mythique, le poids ne compte presque plus après 20 minutes de banc. Temps pour rentrer dans la base
voisine : **7 à 21 s pour un débutant** (Commun -> Sigma), **2,5 à 3,7 s pour un voleur entraîné**.

### La victime rattrape-t-elle le voleur ?

Victime prévenue au début du vol, elle part après 1,5 s. « Reprendre » marche à 10 studs, le grappin à 55.
Chiffres = vols réussis vers la base voisine (sans grappin / avec grappin).

| Victime | Duel | Commun | Légendaire | Mythique | Divin | Sigma |
| --- | --- | --- | --- | --- | --- | --- |
| chez elle | débutant contre débutant | 59 % / 0 % | 40 % / 0 % | 16 % / 0 % | 0 % / 0 % | 0 % / 0 % |
| chez elle | entraîné contre entraîné | 76 % / 0 % | 77 % / 0 % | 79 % / 0 % | 79 % / 0 % | 48 % / 0 % |
| près du trou | débutant contre débutant | 92 % / 17 % | 54 % / 1 % | 28 % / 0 % | 1 % / 0 % | 0 % / 0 % |
| près du trou | entraîné contre entraîné | 100 % / 92 % | 100 % / 84 % | 100 % / 79 % | 100 % / 56 % | 64 % / 15 % |
| de l'autre côté | tous | ~100 % | ~100 % | ~100 % | 93 à 100 % | 7 % (débutants) à 100 % |

Ce que ça montre :
1. **Le vol se joue sur la position de la victime, pas sur l'adresse.** À vitesse égale, courir derrière le voleur ne
   sert à rien (on va aussi vite que lui) : on ne l'attrape que si on est déjà sur son chemin.
2. **Le grappin (150K $) rend la défense chez soi totale** : 0 % de vols réussis contre une victime chez elle qui l'a.
3. **Le résultat est presque tout ou rien.** Un débutant ne vole jamais un Divin ou un Sigma à quelqu'un d'attentif
   (0 %) ; un voleur entraîné vole n'importe quoi à un absent en 3 s.

---

## 2. Les formules en place

- **Revenu par seconde** = somme des 15 familiers de la base (+1 par Rebirth, +5 au plus) :
  `revenu de la rareté x (1 + 0,15 x (rang - 1))` x évolution (x3 / x8) x mutation (x2 / x5 / x10),
  puis x monde (1 à 16) x passes (2X x2, VIP x1,25) x (1 + Rebirths) x amis (+10 % par ami, +50 % au plus) x groupe (+10 %).
  Revenus des raretés : 2 / 14 / 100 / 700 / 5K / 35K / 250K / 1,75M (environ x7 d'une rareté à l'autre).
  Le rang va jusqu'à 14 (Divins) : le dernier Divin rapporte **x2,95**, pas « +45 % » comme le dit le commentaire.
  Les exclusifs des mondes sont en fin de liste : ce sont toujours les plus rentables de leur rareté.
- **Une manche** : objets avalés x valeur moyenne (0,43 point à Chance 0) x bonus du familier équipé (1,1 à 10)
  x bonus du trou. Tirages : le 1er coûte 2 points, chaque suivant +22 %. Chance +0,005 par point (+1 au plus).
  Pitié : un Épique+ garanti au 60e tirage. Plus de Communs après 150 tirages, plus d'Inhabituels après 600.
  Familier pas encore possédé x5. Monde : poids de la rareté x `RarityBoost ^ (rang - 1)` (x1 à x1,8).
- **Argent des points** : par point, 15 $ ou 0,02 s de revenu (le plus grand).
- **Prix** : mondes 200K / 14M / 450M / 14B / 300B / 1,4T (x70, x32, x31, x21, x4,7) ; Boutique à prix fixes
  (Tapis et Banc x2,44 sur 25 niveaux, Chance x7,7, Sac x150, Aimant x9) ; Rebirth 4T puis x2,7.
- **Vol** : gratuit, pas de recharge, vitesse ci-dessus, 60 s au plus (180 s si très lent). Doublons gardés : 5 par espèce.
- **Verrou** : 5 s (10 s avec Verrou renforcé, +10 s VIP), **relancé toutes les 0,1 s tant que le propriétaire est
  sur le bouton**. Seule une clé (49 R$) ouvre une base fermée, 10 s.
- **Jeter un familier dans le trou** : 600 s du revenu du familier x monde du lanceur, + 2 à 240 points.
- **Marché** : taxe 0, prix de 1 à 10^30. **Duel** : 1 chance sur 7 de gagner le familier adverse (la case
  RELANCE se relance).

---

## 3. Ce que dit le simulateur actuel (joueur seul, sans vol)

| Étape | chanceux | moyen | malchanceux |
| --- | --- | --- | --- |
| Désert | 5 min | 7 min | 12 min |
| Volcan | 18 min | 23 min | 30 min |
| 1er Divin / 1er Sigma | 10 min / 26 min | 35 min / 1,2 h | 1,1 h / 2,1 h |
| Glace | 38 min | 51 min | 1,1 h |
| Abysses | 1,3 h | 1,8 h | 2,2 h |
| Cosmos | 3,1 h | 3,6 h | 4,2 h |
| Divin | 5,6 h | 6,2 h | 7,1 h |
| **Rebirth 1** | 8,0 h | **8,6 h** | 9,5 h |
| Tapis et Banc au max | 10,0 h | 10,7 h | 11,6 h |
| Rebirth 2 / 3 / 4 | 12,1 / 17,6 / 27,4 h | 12,8 / 18,4 / 28,1 h | 13,8 / 19,5 / 29,3 h |

Revenu moyen : 4,9K/s à 10 min, 238K/s à 30 min, 2,8M/s à 1 h, 37M/s à 2 h, 207M/s à 5 h, 970M/s à 10 h, 2B/s à 20 h.
Une manche : 6 tirages à 10 min, puis **24 tirages au plus dès 5 h** (le coût +22 % par tirage plafonne).
Argent avant le 1er Rebirth : **80 % revenu des familiers**, 16 % points du trou, 4 % doublons vendus.

Le rythme jusqu'au Rebirth 3 colle à l'objectif du 20 oct. (1er Rebirth vers 9 h). Le revenu monte de plus en plus
lentement : il est multiplié par 2,7 toutes les 5 min au début, toutes les 27 min vers 1 h, toutes les 3 h vers 5 h,
toutes les 14 h après 10 h.

---

## 4. Points de rupture

### Ennui (progression trop lente ou plus rien à faire)

- **E1. Mur après le Rebirth 3.** Rebirth 4 = +9,7 h (contre +4 à +6 h avant), et plus rien à acheter dans la
  Boutique après ~11 h (Tapis et Banc au max). Le prix monte x2,7 par Rebirth, le revenu seulement x(n+1)/n
  (x1,33 au 4e) : chaque Rebirth demande donc plus de temps que le précédent, sans fin.
  *Précision de l'étape 2 :* ce simulateur ne jouait pas la capsule d'évolution. Avec elle, Rebirth 4 = +5,8 h et
  Rebirth 5 vers +8 h : le mur arrive un cran plus tard, mais il est là (partie 2.1).
- **E2. Après ~5 h, jouer ne fait presque plus monter le revenu.** Les tirages (le jeu actif) sont ce qui fait
  grandir la base, mais une manche plafonne à 24 tirages après 5 h, et la base est déjà pleine des meilleures
  espèces : les nouveaux tirages sont surtout des doublons vendus. 80 % de l'argent vient du revenu passif.
- **E3. Les premières minutes sont plus lentes que le simulateur ne le croit.** Un vrai débutant (Force 70, sac 1)
  marche 121 studs de sa palette jusqu'à pouvoir lancer : ~3 objets par manche, 1 tirage, 30 $ de points. Le simulateur
  compte 16 objets dès le départ. Le banc (500 $) corrige vite : Force 130 -> 6 objets, niveau 33 -> 34 objets (le max).

### Frustration (vol impossible ou perte trop dure)

- **F1. Le joueur le plus riche est intouchable.** Rester sur son bouton garde la base fermée pour toujours, les
  intrus sont expulsés, le grappin ne marche pas dans sa propre base. Seule une clé Robux l'ouvre. Comme 80 % de l'argent
  est passif, la meilleure stratégie d'un joueur riche est de camper sur son bouton : le vol, cœur du jeu, ne touche
  plus que les absents et les débutants, et voler un riche devient « payer pour voler ».
- **F2. Le vol est tout ou rien** (partie 1) : impossible pour un débutant sur un Divin ou un Sigma, imparable en 3 s
  pour un voleur entraîné contre un absent. Le poids (taille³) ne pèse vraiment qu'au tout début.
- **F3. Les pertes ne sont pas justes.**
  - Un vétéran ne perd rien : avec 5 exemplaires d'une espèce, le suivant prend la place du volé (revenu -0 %).
  - Un joueur à 1 h (2,8M/s, monde Glace) qui perd son seul Divin (250K x4 = 1M/s) perd **environ un tiers** de son
    revenu (30 à 36 % selon le familier qui prend sa place).
  - Un familier jeté dans le trou est perdu pour toujours.
- **F4. Harcèlement possible.**
  - La batte (2K $) frappe partout, même dans la base de la victime : assommé 1,4 s, protégé 2 s, recharge 1,1 s.
    En théorie, un attaquant qui suit sa victime peut la garder au sol 1,4 s sur 2 (70 % du temps).
  - La quête « Vole N familiers » compte n'importe quel vol : les bases des débutants (Communs, aucune défense) sont les
    cibles les plus faciles pour la remplir.
  - Aucune protection après une grosse perte, et la protection des nouveaux ne dure que 5 min.

### Chaos (inflation, tout s'achète trop vite)

- **C1. Le jackpot du vol casse la courbe des nouveaux.** Ce que rapporte un vol, comparé au revenu du voleur :

  | Voleur | Légendaire | Mythique | Divin | Sigma | Sigma jeté dans le trou |
  | --- | --- | --- | --- | --- | --- |
  | à 10 min (4,9K/s, Désert) | revenu x1,7 | x12 | x83 | **x577** | 1,7B $ : Désert -> Glace d'un coup |
  | à 1 h (2,8M/s, Glace) | x0,007 | x0,05 | x0,36 | x2,5 | 25 min de revenu |
  | à 5 h (207M/s, Cosmos) | ~0 | ~0 | x0,01 | x0,08 | 1 min de revenu |

  Le principe est bon : plus on est petit, plus voler un gros rapporte, et un riche n'a aucun intérêt à voler un
  petit. Mais l'écart est trop grand : un seul Sigma volé à 10 min fait sauter 1 à 2 h de progression.
- **C2. Le marché permet de donner de l'argent sans limite.** Taxe 0 et prix jusqu'à 10^30 : un ami riche achète un
  Commun 1T $ et son ami débutant saute au monde Divin. Même chose juste avant un Rebirth (l'argent serait perdu de
  toute façon) et avec un deuxième compte. Les échanges (6 familiers, sans limite) font pareil avec les familiers :
  un vétéran peut remplir la base d'un ami de 15 Sigma.
- **C3. La carte rétrécit.** Vitesse x2,9 à x3,8, portée de lancer x13 (25 -> 319 studs) sur une carte qui ne bouge
  pas. Dès Force 33, on lance depuis sa base : on ne sort plus. Avec F1, tout le monde finit par rester chez soi.
- **C4. Les défenses sont permanentes et peu chères.** Batte 2K, grappin 150K, Verrou renforcé 5M (vers 30 min) : une
  fois achetées, elles servent pour toujours, sans coût d'usage. Côté voleur : invisibilité 500K (recharge 45 s), et
  les clés seulement en Robux.

---

## 5. Erreurs trouvées dans les données

- `game_design_matrix.json`, `core_loop.rebirth.game` : prix 500, x2,44, bonus 0. Ce sont les valeurs du Tapis et du
  groupe. Les vraies : 4T, x2,7, +100 % par Rebirth. `core_loop.steal.game.hold_e_s` = 0,6 (durée de la clé) ; le vol
  prend 0,3 s. Cause : `dataset_and_pipeline/tools/build_game_design_matrix.py` (lignes 536 et 561-562) cherche la
  première valeur de ce nom dans tout `Config.lua` au lieu de chercher dans le bon tableau.
- `Config.lua` (`Config.Rarities`) : le commentaire parle d'un bonus « de 0 à +45 % » par familier ; c'est jusqu'à
  +195 % (14 Divins). `PetSizes.lua` parle encore de bases de 56 x 56 (84 x 84 depuis le 15 oct.).
- `tools/sim-economy.luau` : 16 objets par manche dès le départ, trop pour un débutant (voir E3).

## 6. Ce que le futur simulateur devra savoir faire (étape 5)

Le simulateur actuel ne joue qu'un joueur seul, toujours présent, sans vol. Il manque :
plusieurs joueurs sur un serveur (8 bases), le vol et la défense (positions, vitesses, verrou, grappin, batte),
les profils (prudent, voleur, nouveau dans un serveur avancé, duo d'amis), les absences, ~~la capsule d'évolution~~
(ajoutée à l'étape 2), les mutations, le marché et les échanges, et les vraies premières minutes (objets par manche
selon la Force).

---

# Étape 2 : courbe coûts / revenus et défenses qui gênent les autres

## 2.1 La courbe mesurée, monde par monde

`python -I dataset_and_pipeline/economy_simulator.py segments --runs 120 --hours 30` (capsule comprise, médianes).
« Montée » = revenu en quittant le monde / revenu en y arrivant. « Plateau » = part du séjour passée après 90 % de la
montée : on attend l'argent du monde suivant sans que le revenu bouge.

| Séjour | Durée | Montée | Plateau | Revenu en sortie |
| --- | --- | --- | --- | --- |
| Prairie | 10 min | x356 | 40 % | 713/s |
| Désert | 16 min | x20 | 20 % | 49K/s |
| Volcan | 30 min | x8,3 | 21 % | 868K/s |
| Glace | 1,1 h | x9,4 | 17 % | 15M/s |
| Abysses | 1,9 h | x3,5 | 20 % | 94M/s |
| Cosmos | 2,5 h | x1,6 | 51 % | 226M/s |
| Divin | 2,3 h | x1,3 | 60 % | 501M/s |
| Après le Rebirth 1 : Prairie -> Cosmos | ~1 h en tout | x1 | 100 % | |
| Rebirth 1 : Divin | 2,5 h | x1,0 | ~100 % | 1,3B/s |
| Rebirths 2 / 3 / 4 : Divin | 3,3 / 5,4 / 8,3 h | x1,03 à x1,05 | | 2,4 / 3,6 / 5,9B/s |

Calendrier, capsule comprise : Désert 10 min, Volcan 26 min, Glace 54 min, Abysses 2,0 h, Cosmos 3,9 h, Divin 6,4 h,
Rebirth 1 8,8 h, puis 12,2 h, 16,0 h, 21,8 h (cibles du 20 oct. : 10 min, 30 min, 1 h, 2 h, 3,5 h, 6 h, ~9 h).

Ce que ça dit :
- **Jusqu'aux Abysses, la dent de scie est bonne** : on arrive, le revenu monte vite (x3 à x20), puis ~20 % du
  séjour à attendre. On n'y touche pas.
- **Cosmos et Divin : la moitié du séjour à attendre.** La base est pleine de Sigma et de Divins dès la Glace
  (meilleure rareté en quittant la Glace : Sigma dans 90 % des parties ; Mythique au Volcan, Légendaire au Désert,
  Rare en Prairie). Il ne reste à gagner que les exclusifs des mondes.
- **Après le 1er Rebirth, ce n'est plus une dent de scie, c'est une file d'attente** : on rachète les 5 premiers mondes
  en ~1 h, puis on attend au Divin 2,5 h, 3,3 h, 5,4 h, 8,3 h sans que le revenu bouge.

Prix ressentis (en minutes du revenu du moment, avant le 1er Rebirth, médianes) : améliorations 0,9 à 1,8 min
(~8 min pour les 5 derniers niveaux de Tapis et Banc), mondes 12,6 min (8 au début, 15 à la fin). Les améliorations
sont des achats « en passant » qui accélèrent la montée : rien d'inflationniste. **L'étape 7 du plan du 20 oct.
(améliorations liées aux mondes) n'est donc pas nécessaire.**

## 2.2 Les relations

1. **Revenu** : `I = M_monde x (1 + Rebirths) x S`, où S = somme des 15 familiers de la base. S a un plafond : avec
   les 106 familiers, **S_max = 32,6M/s** (les 10 Sigma font 29,3M, puis 5 Divins). La place de plus donnée par chaque
   Rebirth ajoute un Divin : **+2 % seulement**.
2. **Attente au Divin quand la base est pleine** : `T_n = prix du Rebirth n / (S x 16 x (1 + n))`. Sans capsule :
   2,8 h, 5,0 h, 10 h, 21 h, 47 h (le simulateur trouve 3,0 / 4,8 / 9,1 h : la formule suffit à l'expliquer). Le prix
   monte x2,7 par Rebirth, le revenu x(2 + n)/(1 + n) : l'attente grandit sans fin. La capsule fait grandir S d'environ
   +20 % par cycle (40M, 50M, 56M, 74M mesurés) : les cycles mesurés durent 3,4 h, 3,8 h, 5,8 h, puis ~8 h.
3. **Tirages d'une manche** : `tirages = log(1 + 0,11 x points) / log(1,22)`. Doubler ses points ne donne que
   ~3,5 tirages de plus : la boucle active est volontairement freinée (réglage du 20 oct.) et plafonne à 24.
4. **Ce que rapporte un vol** (gain de revenu divisé par le revenu du voleur, mesuré en quittant chaque monde, médianes) :

   | Monde du voleur | +1 rareté au-dessus de son meilleur familier | +2 | +3 | +4 |
   | --- | --- | --- | --- | --- |
   | Prairie | x2,2 | x16 | x110 | x670 |
   | Désert | x1,7 | x12 | x55 | |
   | Volcan | x1,8 | x5,7 | | |

   Un séjour dans un monde fait monter le revenu de x8 à x20 (Désert, Volcan, Glace). Donc : voler **une rareté
   au-dessus casse le mur** (le revenu triple, l'attente du monde suivant est divisée par ~3) ; **deux raretés ≈ un monde
   d'avance** ; trois et plus = plusieurs mondes sautés d'un coup (le jackpot C1).
5. **Cycle du Rebirth** : `durée(n) = rachat des mondes + prix(n) / revenu(n)`. Pour que chaque cycle dure ρ fois le
   précédent, il faut `prix(n + 1) / prix(n) = ρ x σ x (2 + n) / (1 + n)`, où σ = croissance de S pendant un cycle
   (~1,2 avec une capsule). Le choix de ρ appartient à l'étape 4 (Rebirth).

## 2.3 Les règles proposées (à prouver à l'étape 5 avant de toucher `Config.lua`)

**Règle 1. Prix des mondes et de la Boutique avant le 1er Rebirth : inchangés.** Le calendrier colle aux cibles à
±15 % près et une amélioration coûte 1 à 2 min de revenu.

**Règle 2. Plafond pour les familiers « trop forts pour toi ».** Un familier rapporte au plus comme un familier de
la rareté `r + 2`, où r = la meilleure rareté que le joueur a obtenue lui-même (tirages, fusion, capsule). Ça vaut pour
les familiers volés, échangés, achetés au marché ou gagnés en duel. Un familier tiré soi-même n'est jamais bridé :
en solo, la règle ne joue jamais. Dès que le joueur obtient lui-même une rareté de plus, le plafond monte d'autant.
- D'où vient le « +2 » : relation 4. Deux raretés d'écart rapportent x6 à x16, autant que la montée d'un monde
  (x8 à x20). Un coup de chance, ou un ami généreux, fait gagner au plus un monde, jamais trois.
- Ce que ça change : le Sigma volé à 10 min rapporte comme un Légendaire ou un Mythique (gain ~x12 au lieu de x577) ;
  jeté dans le trou, il rapporte 5M à 34M $ au lieu de 1,7B. Un vétéran ne peut plus remplir la base d'un nouvel ami de
  Sigma qui rapportent tout de suite.
- Dans le jeu : le familier affiche « Trop puissant pour toi : il rapporte X au lieu de Y. Obtiens un Mythique pour le
  libérer. » Le gros familier volé devient un objectif au lieu d'un raccourci.

**Règle 3. Marché : prix plafonné à 1 h du revenu du familier** (revenu plafonné par la règle 2), soit 6 fois le prix
proposé (10 min). D'où vient 1 h : un séjour dans un monde dure environ 1 h (Glace 1,1 h). Personne n'achète un
familier plus cher que ce qu'il rapporte pendant un séjour : au-delà, c'est un cadeau d'argent déguisé. Fini le
Commun à 1T $. Taxe toujours à 0.

**Règle 4. Il faut quelque chose qui fasse monter le revenu en fin de partie.** Quand la base est pleine, seule la
capsule (une place) fait encore grandir S. Exigence : pendant chaque cycle de Rebirth, S doit pouvoir grandir d'au
moins x1,5, sinon plus de la moitié du cycle est de l'attente pure. Les pistes, chiffrées, seront tranchées à
l'étape 4 : une place de capsule de plus par Rebirth (une seule Sigma Ultime ajoute +60 % à S_max), les familiers
évolués et mutés comme cibles de vol de fin de partie (le vol reste utile aux vétérans), prix du Rebirth recalculés par
la relation 5.

## 2.4 Les défenses et armes qui gênent les autres

Méthode : pour chaque objet, on regarde qui il gêne, et ce qui se passe quand tout le monde l'a. Un objet utile à
chacun, mais qui tue le vol quand tout le monde l'a, déclenche une course aux armements. Un prix plus haut ne fait que
retarder le moment où tout le monde l'a : il faut limiter son **usage**.

| Objet | Aujourd'hui | Quand tout le monde l'a | Règle proposée | D'où viennent les chiffres |
| --- | --- | --- | --- | --- |
| Verrou (bouton) | 5 s, relancé tant qu'on est dessus : fermé pour toujours | plus aucun vol chez ceux qui campent ; on ne vole que les absents et les débutants (F1, F4) | **Cycle fixe : fermé 45 s, puis bouton grisé 60 s.** 45 + 60 = 105 s = une manche : on ferme une fois par manche, et on choisit quand (pendant qu'on lance, ou pendant qu'on part voler) | 45 s = le Feeding : un débutant est loin, à lancer, pendant tout le Feeding (121 studs de marche) ; 60 s = la digestion |
| Verrou renforcé (5M), VIP | 10 s ; +10 s | idem | rallongent la fermeture (55 s, 65 s avec les deux) dans le même cycle de 105 s ; la base reste ouverte **au moins 30 s** par cycle | 30 s = temps d'un débutant pour voler chez son voisin : 8 s d'entrée à entrée, 3 s jusqu'au familier, 0,3 s, puis le retour (20 s en tout pour un Légendaire, 32 s pour un Sigma : le plus lourd reste juste hors de portée d'un débutant) |
| Batte (2K) | assommé 1,4 s, protégé 2 s : jusqu'à 70 % du temps au sol | harcèlement | **2 coups au plus par victime toutes les 10 s** (28 % du temps au sol au maximum) | 10 s = le trajet d'un vol (109 studs à 16 = 6,8 s) + 1,5 s de réaction + 1,4 s de KO : le temps de se relever et d'agir |
| Grappin (150K) | défense totale chez soi (0 % de vols réussis) | tout le monde l'a dès le Volcan | prix gardé ; le 0 % est un problème de poursuite : **étape 3** | |
| Invisibilité (500K), clés (49 R$) | outils du voleur | | gardés ; avec le cycle du verrou, la clé n'est plus le seul moyen de voler un riche qui campe | |
| Aimant, aspirateur | prennent les objets sauvages, partagés | ~1 objet de moins par manche pour les autres (~5 % de leurs points) | gardés | 11 objets sauvages par Feeding pour tout le serveur |
| Familier jeté dans le trou | 600 s du revenu du familier | jackpot (C1) | même calcul, sur le revenu plafonné (règle 2) | |

Pourquoi aucune défense réservée aux joueurs qui ont fait un Rebirth : les débutants resteraient sans défense, donc
seules cibles (F4).

Ce qui change pour le joueur riche : aujourd'hui, camper sur son bouton ne coûte rien et protège à 100 %. C'est la
meilleure stratégie, et elle tue le vol. Avec le cycle, sa base est ouverte au moins 40 s par manche (60 s sans
bonus) : il doit être là et se défendre (batte, grappin, « Reprendre ») pendant ces moments. La meilleure stratégie
devient « être chez soi quand c'est ouvert » : du jeu actif, et une raison de revenir vers sa base.

## 2.5 Suite

- Étape 3 : poursuite et poids (grappin à 100 %, carte qui rétrécit, vol tout ou rien), protection après une grosse perte.
- Étape 4 : ce qui fait monter le revenu en fin de partie, et le Rebirth (choix de ρ).
- Étape 5 : simulateur à 8 joueurs avec vols, pour prouver les règles 2 et 3, le cycle du verrou et la règle de la
  batte avant de toucher `Config.lua`.

---

# Étape 3 : le risque du vol et l'anti-boule de neige

Calculs : `python -I dataset_and_pipeline/economy_map_metrics.py --etape3` (poursuites) et
`python -I dataset_and_pipeline/economy_simulator.py cibles --runs 120 --hours 10.5` (qui a intérêt à voler qui).
Même modèle de poursuite qu'à l'étape 1 : lignes droites, la victime part après 1,5 s, « Reprendre » à 10 studs.

## 3.1 Le principe : la distance qui sauve

Pour chaque rareté, on calcule **D\***, la distance à laquelle le propriétaire doit se trouver pour qu'un vol réussisse,
à vitesse égale :

`D* = 10 + d / λ - vitesse du propriétaire x 1,5 s`, avec d = trajet du voleur (110 studs vers la base voisine) et
λ = vitesse du voleur chargé / vitesse du propriétaire.

On compare D\* aux endroits où le propriétaire se trouve vraiment (distance médiane au familier volé, en studs) :
dans sa base 23, à son tapis 54, au kiosque voisin 84, aux objets sauvages 99, en train de lancer près du trou 149,
de l'autre côté du trou 278, en train de voler 2 bases plus loin 300.

**La bonne tension, c'est une échelle** : un Commun se vole dès que le propriétaire s'éloigne un peu, un Sigma
seulement s'il est à l'autre bout de la carte. Le joueur doit choisir son moment (le timing), et plus le butin est gros,
plus il faut attendre une vraie ouverture.

## 3.2 La courbe actuelle s'écrase quand on s'entraîne

| Rareté | m actuel, débutant (Force 70) | m actuel, entraîné (Force 250) | D\* actuel, débutants | D\* actuel, entraînés |
| --- | --- | --- | --- | --- |
| Commun | 0,95 | 0,95 | 101 | 56 |
| Rare | 0,93 | 0,95 | 104 | 56 |
| Légendaire | 0,81 | 0,94 | 122 | 58 |
| Divin | 0,54 | 0,81 | 189 | 77 |
| Sigma | 0,33 | 0,64 | 316 | 112 |

Entre joueurs entraînés, toutes les raretés se volent de la même façon (D\* de 56 à 112) : un Sigma part dès que le
propriétaire est à son tapis. La Force fait disparaître le poids, et la vitesse x2,9 fait fondre la carte (C3).

## 3.3 Règle 5 : vitesse en portant = min(sa vitesse, celle du propriétaire) x m(rareté)

`m(rareté) = 0,95 x 0,876^(rang - 1)` : **0,95 / 0,83 / 0,73 / 0,64 / 0,56 / 0,49 / 0,43 / 0,38** (Commun -> Sigma).
La Force ne compte plus pour porter (elle garde son rôle : lancer loin).

D'où viennent les chiffres :
- Commun = 0,95 : le plafond actuel (`Config.Carry.MaxSpeed`), porter ralentit toujours un peu.
- Sigma = 0,38 : à vitesse égale, il doit être volable **tout juste** quand le propriétaire est de l'autre côté du trou :
  `m = 110 / (278 - 10 + 16 x 1,5) = 0,376`.
- Entre les deux, chaque rareté retire le même pourcentage (x0,876) : l'échelle est régulière.
- Vérification croisée avec l'étape 2 : un débutant met 11,3 s pour arriver au familier, puis 18,2 s pour rentrer avec
  un Sigma = 30 s, exactement la fenêtre ouverte minimale du verrou. Deux calculs indépendants donnent la même borne.
- « min(sa vitesse, celle du propriétaire) » : un voleur plus rapide que sa victime ne la distance plus avec un gros
  butin ; la carte ne fond plus quand tout le monde s'entraîne.

| Rareté | D\* proposé, débutants | D\* proposé, entraînés | secondes à porter (vitesse 16 / 46) |
| --- | --- | --- | --- |
| Commun | 101 | 56 | 7,2 / 2,5 |
| Rare | 136 | 91 | 9,4 / 3,3 |
| Légendaire | 182 | 137 | 12,2 / 4,3 |
| Divin | 241 | 196 | 16,0 / 5,6 |
| Sigma | 277 | 232 | 18,2 / 6,3 |

Porter ne descend jamais sous 38 % de sa vitesse, et le trajet le plus long dure 18 s : lent, mais pas pénible.

Vols réussis vers la base voisine, **entre joueurs entraînés**, courbe actuelle -> proposée (sans grappin) :

| Propriétaire | Commun | Rare | Légendaire | Divin | Sigma |
| --- | --- | --- | --- | --- | --- |
| dans sa base | 76 -> 79 % | 82 -> 58 % | 78 -> 25 % | 74 -> 0 % | 52 -> 0 % |
| à son tapis | 100 -> 100 % | 100 -> 100 % | 100 -> 67 % | 100 -> 22 % | 92 -> 6 % |
| au kiosque voisin | 100 -> 100 % | 100 -> 100 % | 100 -> 88 % | 100 -> 36 % | 100 -> 9 % |
| lance près du trou | 100 -> 100 % | 100 -> 97 % | 100 -> 48 % | 100 -> 2 % | 68 -> 0 % |
| de l'autre côté du trou | 100 -> 100 % | 100 -> 100 % | 100 -> 100 % | 100 -> 85 % | 100 -> 57 % |
| en train de voler 2 bases plus loin | 100 -> 100 % | 100 -> 100 % | 100 -> 100 % | 100 -> 50 % | 100 -> 28 % |

Entre débutants, l'échelle existait déjà et reste proche (Sigma : 0 % partout sauf de l'autre côté du trou, 6 -> 19 %).
Un voleur débutant contre un propriétaire entraîné : ~0 % partout avec les deux courbes (seul un Commun passe, 30 %,
quand le propriétaire est de l'autre côté du trou) : il ne vole un riche que s'il est absent, et s'entraîner en Vitesse
devient le chemin pour voler les riches.

## 3.4 Règle 6 : un grappin qui demande de viser

Aujourd'hui, un propriétaire chez lui avec un grappin gagne à 100 %, quelle que soit la rareté : il vise à 14° près
(13 studs de marge à 55 studs) et peut retirer toutes les 5 s (4 tirs pendant qu'un Sigma est porté).
- **Cône de visée 14° -> 8°** : la cible fait ~2,5 studs de large (plus le familier porté), plus ~1,5 stud de décalage
  dû au ping (0,1 s à 16 studs/s) ; ~4 studs de marge à mi-portée (28 studs) = 8°.
- **Recharge 5 s -> 9 s** : 9 s = la moitié du plus long trajet (Sigma, 18,2 s). Au plus 2 tirs sur un gros butin,
  1 seul sur un petit (moins de 9 s) ou contre un voleur entraîné (moins de 6,3 s). Rater coûte cher : c'est de l'adresse.
- Ces deux valeurs ne se vérifient pas hors ligne (il faudrait mesurer l'adresse réelle) : **test à 2 joueurs dans Studio**.

## 3.5 Qui a intérêt à voler qui

Pour un voleur et une victime pris à deux moments de la partie : part des familiers de la victime qui feraient monter le
revenu du voleur, et gain du meilleur vol (sans plafond -> avec le plafond de la règle 2).

| Voleur \ victime | 10 min | 1 h | 2 h | 10 h |
| --- | --- | --- | --- | --- |
| 10 min | 87 %, x0,6 | 100 %, x130 -> x7,7 | 100 %, x710 -> x11 | 100 %, x5000 -> x11 |
| 30 min | 7 %, x0,004 | 100 %, x2,7 | 100 %, x16 -> x5,7 | 100 %, x76 -> x11 |
| 1 h | 0 % | 93 %, x0,26 | 100 %, x2,3 | 100 %, x16 -> x6,6 |
| 2 h | 0 % | 20 %, x0,02 | 100 %, x0,21 | 100 %, x1,4 |
| 10 h | 0 % | 0 % | 13 %, x0,004 | 94 %, x0,12 |

Ce que ça montre :
- **Voler un plus avancé** : tous ses familiers sont utiles, et le plafond ramène le gain à x6 à x11 au plus (un monde
  d'avance environ, comme voulu à l'étape 2). C'est le rattrapage naturel du jeu.
- **Voler un moins avancé ne rapporte rien** dès 30 min à 1 h d'écart : 0 à 7 % de ses familiers serviraient, pour
  +0,4 % de revenu. Un riche qui vole un débutant ne le fait que pour gêner (ou pour la quête « Vole N familiers »).
- **Entre joueurs du même niveau**, un vol vaut +12 à +60 % de revenu : la vraie rivalité.

## 3.6 Règles anti-boule de neige et anti-harcèlement

**Règle 7. Vol utile.** On ne peut prendre que les familiers qui feraient monter son revenu (revenu plafonné par la
règle 2 plus grand que son moins bon familier de base, ou une place libre). La bulle [E] ne s'affiche pas sur les
autres. Raison (théorie des jeux) : un vol qui ne rapporte rien au voleur et fait perdre la victime n'est que du
harcèlement ; l'interdire ne retire aucun choix intéressant. Effet mesuré (3.5) : un joueur avancé ne peut plus voler
quelqu'un qui a 30 min à 1 h de retard. La quête « Vole N familiers » ne compte donc plus que des vols utiles.

**Règle 8. Bouclier après une grosse perte.** Si un vol fait perdre au moins 20 % de son revenu (après remplacement
par le suivant de la réserve), la base ne peut plus être volée pendant 105 s.
- 20 % = la part du séjour passée sur le plateau (étape 2) : au-delà, une seule perte renvoie plus loin que le mur.
- 105 s = un cycle du verrou (étape 2) : le temps de revenir (le point le plus loin, la base d'en face, est à
  ~430 studs = 27 s à vitesse 16) et de refermer.
- Un vétéran qui a des doublons perd souvent 0 % (le doublon prend la place) : pas de bouclier, il peut se faire
  piller s'il s'absente, c'est le jeu.

**Règle 9. La couronne du plus riche (prime).** Le joueur qui a le plus gros revenu du serveur porte une couronne
(au-dessus de sa tête et sur sa base).
- Voler la couronne : en plus du familier, **prime = 10 min du revenu du familier volé** (plafonné), comme le jeter
  dans le trou (`Config.Sacrifice.IncomeSeconds`) : le familier vaut deux fois plus à prendre chez le roi que chez un
  autre, sans casser l'économie (montants déjà bornés par la règle 2).
- Défendre la couronne : chaque voleur arrêté dans sa base (Reprendre, batte, grappin) donne au roi la même somme,
  un compteur « défenses » et une annonce. La domination est récompensée par du jeu (défendre) et du prestige
  (couronne, annonces), pas par plus de revenu : ça ne nourrit pas la boule de neige.
- Effet attendu : les voleurs visent le roi plutôt que le joueur moyen ; le roi doit rester actif ; s'il s'absente, il
  perd des familiers (des doublons, le plus souvent) et la couronne peut changer de tête.

**Règle 10 (au choix de Chouaib). Gros butin signalé à tous.** Un porteur de Mythique ou plus est signalé à tout le
serveur ; n'importe qui peut le frapper (le familier tombe et rentre à pied, et peut être ramassé, en respectant la règle 7).
- Seuil Mythique : à partir de là, le trajet (14 s et plus à vitesse 16) dure à peu près le temps qu'il faut à un
  autre joueur pour réagir et traverser la moitié de la carte (2,5 s + ~200 studs à 16 = 15 s) : il a le temps d'arriver.
- Risque mesuré (un autre joueur qui veut l'intercepter, placé au hasard) : Mythique 44 %, Divin 48 %, Sigma 62 % à
  vitesse 16 ; 20 %, 22 %, 38 % à vitesse 46. Plus le butin est gros, plus le voleur est exposé longtemps.
- Contre : avec cette règle, un vol de Sigma entre joueurs entraînés, propriétaire de l'autre côté du trou, réussit
  ~35 % du temps au lieu de 57 %. C'est rare, mais encore possible.

## 3.7 Suite

- Étape 4 : rétention (objectifs entamés, pitié, événements de serveur), Rebirth et ce qui fait monter le revenu en fin
  de partie (règle 4), avantages réels à jouer avec un ami.
- Étape 5 : simulateur à 8 joueurs (prudent, voleur, nouveau dans un serveur avancé, duo d'amis) avec les règles 2 à 10,
  pour mesurer les vols réussis, les pertes et l'écart entre le plus riche et les autres, avant de toucher
  `Config.lua`. Le grappin (règle 6) sera testé à 2 joueurs dans Studio.

---

# Étape 4 : rétention, Rebirth et jeu entre amis

Calculs : `python -I dataset_and_pipeline/economy_simulator.py retention --runs 150 --hours 12` (pitié, jauge, Index),
`segments` / `solo` avec les options `--capsules-rebirth --doublons-capsule --rebirth-croissance 1.62` (Rebirth),
`python -I dataset_and_pipeline/economy_map_metrics.py --etape4` (amis).

Ce qui existe déjà et marche : cadeau du jour (7 jours), 3 quêtes par jour, codes, barre « prochain tirage », Index
avec récompenses, œufs et capsule qui avancent même hors ligne, paliers du trou noir et effondrement, +10 % de revenu
par ami présent. Ce qui manque : aucune jauge vers le prochain monde, aucune pitié utile, une fin de partie plate.

## 4.1 Une pitié qui sert vraiment

Tirages qu'il faut pour obtenir une rareté (ou mieux) : 1 chance sur 2 / 9 chances sur 10. Chance réelle de chaque
monde (points médians d'une manche x 0,005), tirages par heure mesurés.

| Monde | Tirages / h | Épique | Légendaire | Mythique | Divin | Sigma |
| --- | --- | --- | --- | --- | --- | --- |
| Prairie | 133 | 7 / 22 | 17 / 55 | 56 / 186 | 225 / 747 | 1350 / 4482 |
| Désert | 243 | 5 / 17 | 13 / 41 | 39 / 128 | 145 / 479 | 814 / 2702 |
| Volcan | 374 | 4 / 13 | 9 / 29 | 26 / 86 | 91 / 301 | 479 / 1590 |
| Glace | 524 | 3 / 9 | 6 / 20 | 17 / 55 | 55 / 182 | 272 / 902 |
| Divin | 823 | 2 / 4 | 3 / 8 | 5 / 16 | 13 / 41 | 48 / 157 |

**La pitié actuelle (un Épique garanti au 60e tirage) ne se déclenche jamais** : 0 fois en 150 parties de 12 h. Il
faut au pire 22 tirages pour avoir un Épique 9 fois sur 10 : personne n'atteint 60.

**Règle 11. Pitié par palier.** La rareté juste au-dessus de la meilleure qu'on possède est garantie au tirage où
9 joueurs sur 10 l'auraient déjà eue (`ln(0,1) / ln(1 - p)`, p = chance de cette rareté ou mieux, calculée par
`LootEngine.odds` avec le monde et la chance du moment). Seuls les 10 % les plus malchanceux en profitent ; elle
remplace l'ancienne.

| Mesuré (150 parties) | sans | avec la règle 11 |
| --- | --- | --- |
| 1er Légendaire, 1 joueur sur 100 le plus malchanceux | 38 min | 28 min |
| 1er Sigma, 9 sur 10 / 99 sur 100 | 2,4 h / 3,1 h | 2,0 h / 2,5 h |
| Monde Divin, 99 sur 100 | 8,1 h | 7,5 h |
| 1er Rebirth, médiane | 8,7 h | 8,7 h (inchangé) |

0,8 garantie par partie de 12 h : elle coupe la très grosse malchance sans accélérer le jeu. Elle s'affiche :
« Mythique garanti dans 23 tirages » (objectif entamé, toujours visible). Les tirages achetés en Robux suivent la même
règle, qui doit alors être écrite dans l'onglet Chances (règle Roblox sur les objets aléatoires payants).

## 4.2 Toujours un objectif entamé sous les yeux

**Règle 12. Le prochain objectif à l'écran.** Une petite pile dans le HUD montre les deux objectifs les plus proches,
avec une barre : prochain monde (argent / prix), garantie de la pitié, prochaine tentative de la capsule, Index
(64 / 106), familier bridé à libérer (règle 2). Choix : celui qui arrivera le plus tôt (argent manquant / revenu, etc.)
et celui qui est le plus avancé. Raison : on se souvient mieux d'une tâche commencée que d'une tâche pas encore
lancée (effet Zeigarnik). Une barre à 70 % retient plus qu'un prix affiché.

Avancée de l'Index mesurée : 21 familiers à 10 min, 64 à 1 h, 95 à 5 h, 100 à 10 h ; les 75 de base vers 4,5 h. Les
106 ne sont jamais complets en 12 h : les exclusifs d'un monde ne sortent que là, et on n'y retourne pas. C'est un bon
objectif de long terme (le bouton « Y ALLER » existe), à montrer dans la pile (« 6 exclusifs du Volcan à trouver »).

**Au retour** : un résumé « Pendant ton absence : 3 œufs ont éclos, ta capsule a tenté 2 évolutions » (les œufs et la
capsule avancent hors ligne). C'est la raison de revenir le lendemain.

## 4.3 Des moments forts sur le serveur

Les paliers du trou noir sont déjà ces moments (lave x3, cible x2, tentacules, gravité, combo, jackpot, puis
l'effondrement). Mais leur rythme dépend de la Chance des joueurs. Durée d'un tour complet des 7 paliers aujourd'hui :

| Joueurs en sont à | seul | 4 joueurs | 8 joueurs |
| --- | --- | --- | --- |
| 10 min | 37 min | 21 min | 16 min |
| 1 h | 16 min | 9 min | 7 min |
| 10 h | 10 min | 6 min | 4 min |

*(Corrigé à l'étape 5 : le jeu compte au moins 1 point de jauge par objet, `math.max(1, valeur)` dans
`BlackholeTiers.OnScored` ; la première version de ce tableau comptait la valeur brute et donnait des tours 1,1 à
2,5 fois trop longs. La règle 13 n'en dépend pas : elle compte déjà 1 par objet ordinaire.)*

En fin de partie, les 7 paliers passent en 4 min : moins d'une manche (105 s) chacun. On n'a même pas le temps de
voir la mécanique d'un palier qu'il a déjà changé.

**Règle 13. Jauge du trou en « objets », pas en valeur.** Chaque objet avalé compte sa valeur divisée par la valeur
moyenne d'un objet à la Chance du lanceur (un objet ordinaire = 1, un rare compte plus). Le tour ne dépend plus de
l'avancée. Pour qu'à 8 joueurs au maximum (38 objets par manche chacun) chaque palier dure au moins une manche, il
faut `jauge totale >= 8 manches x 8 x 38 / 8^0,6 = 699` : `GaugeNeed` x1,26 (50, 63, 76, 95, 113, 139, 164). Tour
complet : 14 à 33 min à 8 joueurs, 18 à 44 min à 4, 32 à 76 min seul.

**Règle 14 (au choix de Chouaib). La ruée des voleurs.** Pendant la digestion qui suit l'effondrement, tous les verrous
sont coupés 60 s. Le grand moment du trou noir devient aussi un grand moment de vol, une fois par tour (14 à 76 min).
Les règles 7 (vol utile) et 8 (bouclier) et la protection des nouveaux empêchent que ça tourne au massacre des
débutants.

## 4.4 Le Rebirth : une récompense qui change le jeu, au bon moment

Aujourd'hui, la place de base en plus (+2 % de revenu) ne change presque rien. Après le 1er Rebirth, le revenu ne
monte plus pendant les séjours au Divin (étape 2), et le prix x2,7 allonge les cycles sans fin.

Essais dans le simulateur, séjour au Divin : montée du revenu / part du séjour sur le plateau.

| Cycle | aujourd'hui (1 capsule) | + 1 capsule par Rebirth | + un doublon de sa meilleure rareté va dans une capsule libre |
| --- | --- | --- | --- |
| Rebirth 2 | x1,03 / 68 % | x1,3 / 34 % | x1,3 / 34 % |
| Rebirth 3 | x1,05 / 47 % | x1,11 / 31 % | x1,33 / 33 % |
| Rebirth 4 | x1,05 / 34 % | x1,1 / 26 % | x1,43 / 19 % |

Ce qui bloquait : en fin de partie, les doublons au-delà de 5 sont vendus aussitôt, les capsules ne reçoivent plus
que des œufs de Divin et la base n'évolue plus. Avec les deux règles, la base grandit de x1,46 à x1,48 par cycle : c'est
l'exigence de la règle 4 (x1,5).

**Règle 15. Chaque Rebirth donne une capsule d'évolution de plus** (6 au maximum, la place de base en plus est gardée).
Un doublon de sa meilleure rareté va dans une capsule libre au lieu d'être vendu. Récompense visible (une capsule de
plus derrière la base, de plus en plus grande avec le monde : `client/CapsuleDecor`) et récompense de jeu (de quoi
grandir à chaque cycle). Le multiplicateur x(1 + Rebirths) reste.

**Règle 16. Prix du Rebirth : `4T x (n + 1) x 1,62^n`.** Relation 5 de l'étape 2 :
`prix(n + 1) / prix(n) = ρ x σ x (2 + n) / (1 + n)`. Le produit des `(2 + n) / (1 + n)` fait simplement `(n + 1)`.
σ = 1,47 (croissance de la base par cycle, mesurée avec la règle 15), ρ = 1,1 (chaque cycle un peu plus long que le
précédent, un mur doux, pas un mur dur).

| Rebirth | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Prix aujourd'hui | 4T | 10,8T | 29T | 79T | 213T | 574T | 1,5Qa |
| Prix règle 16 | 4T | 13T | 31T | 68T | 138T | 268T | 506T |
| Atteint (aujourd'hui + règle 15) | 8,8 h | 12,2 h | 15,6 h | 19,8 h | 25,9 h | 35,0 h | après 45 h |
| Atteint (règles 15 + 16) | 8,8 h | 12,5 h | 16,1 h | 19,8 h | 24,2 h | 29,4 h | 35,8 h |

Les cycles durent 3,6 à 3,7 h, puis 4,4 h, 5,2 h et 6,4 h (au lieu de 6,1 h puis 9,1 h). Le Rebirth est payable
quand le séjour au Divin a passé 26 à 39 % de son temps sur le plateau, comme dans les mondes qui marchent bien
(20 à 35 %). C'est le « bon moment » : le revenu a fini de monter, on n'attend pas des heures pour rien.

## 4.5 Jouer avec un ami doit vraiment aider

Aujourd'hui : +10 % de revenu par ami présent (5 au plus). Rien dans le vol ni la défense.

- **Règle 17. Base voisine et refuge.** Un joueur qui arrive reçoit, si elle est libre, la base à côté d'un ami. Un
  familier volé peut être rapporté dans la base d'un ami présent (il va quand même au voleur). Trajet médian depuis
  les bases éloignées : 308 -> 241 studs (-22 %).
- **Règle 18. Escorte.** Si un ami reste à moins de 15 studs du porteur (portée de la batte, 8 + 3, avec un peu de
  marge), le familier compte comme une rareté plus légère : +14 % de vitesse. D\* d'un Sigma : 278 -> 241 studs (volable
  quand le propriétaire vole deux bases plus loin, plus seulement de l'autre côté du trou). Un gros vol se fait à deux.
- **Règle 19. Reprendre pour un ami.** Les amis de la victime voient aussi la bulle « Reprendre ». Deux défenseurs
  couvrent deux fois plus de terrain.
- **Invitation récompensée.** Quand un ami arrive par ton invitation, vous recevez chacun un œuf gratuit (une fois
  par ami et par jour). À vérifier : `Player:GetJoinData()` donne qui a invité (champ `ReferredByPlayerId` dans la
  documentation Roblox).

## 4.6 Où ça va dans le code (pour l'étape 5)

Rien n'est codé : cette table sert à l'étape 5, après la preuve par le simulateur.

| Règle | Fichiers | Ce qui change |
| --- | --- | --- |
| 2, 7 | `shared/PetCatalog` (revenu plafonné), `server/EconomyController`, `server/StealController`, `client/BasePets` | revenu plafonné par la meilleure rareté obtenue soi-même (nouveau champ sauvegardé `selfBest`) ; bulle [E] seulement sur les vols utiles |
| 3 | `server/MarketController`, `Config.Market` | prix max = 3 600 s du revenu plafonné |
| Verrou, batte (étape 2) | `server/LockController`, `server/WeaponController`, `Config.Lock`, `Config.Weapons` | cycle fermé 45 s / grisé 60 s ; 2 coups au plus en 10 s par victime |
| 5, 6 | `server/StealController.CarrySpeed`, `Config.Carry`, `Config.Weapons.Grapple` | table `SpeedByRarity`, min(vitesse du voleur, du propriétaire) ; cône 8°, recharge 9 s |
| 8, 9 | `server/StealController`, nouveau `server/CrownController` | bouclier 105 s après 20 % de perte ; couronne du plus gros revenu, prime et défenses |
| 11 | `shared/LootEngine`, `server/PullRewards`, `server/SessionData` | seuil du palier, compteur sauvegardé, attribut pour le HUD |
| 12 | nouveau `shared/NextGoals` (calcul pur, testable avec Lune), `client/HUD` | pile « prochain objectif » ; résumé d'absence au chargement |
| 13, 14 | `server/BlackholeTiers`, `server/LockController`, `Config.Blackhole` | jauge en objets, `GaugeNeed` x1,26 ; verrous coupés après l'effondrement |
| 15, 16 | `server/EggController`, `server/SessionData`, `server/ProgressionController`, `client/EvolutionMachine`, `Config.Evolution`, `Config.Rebirth` | plusieurs capsules, doublons vers une capsule libre ; `GetRebirthPrice` = base x (n + 1) x 1,62^n |
| 17-19 | `server/BaseManager`, `server/StealController`, `server/ProgressionController` (liste des amis présents) | base voisine, refuge, escorte, « Reprendre » pour un ami, œuf d'invitation |

## 4.7 Suite

Étape 5 : simulateur à 8 joueurs sur un serveur (prudent, voleur, nouveau dans un serveur avancé, duo d'amis), avec les
positions, les vols et les règles 2 à 19. On mesure les vols réussis, les pertes, l'écart entre le plus riche et les
autres, et le temps jusqu'aux mondes pour chaque profil. Ensuite seulement : `Config.lua`, `game_design_matrix.json`
(et son générateur, qui lit de mauvaises valeurs) et le code Luau, règle par règle, chacune testée.

---

# Étape 5 : le serveur à 8 joueurs, puis les premières règles dans le jeu

## 5.1 Le simulateur de serveur

`dataset_and_pipeline/economy_server.py`, lancé par `python -I dataset_and_pipeline/economy_simulator.py serveur`
(scénarios détaillés) ou `balayage` (`--second` pour le second balayage).

- Chaque joueur est une partie complète du simulateur solo (tirages, œufs, capsule, Boutique, mondes, Rebirth). Les
  vétérans sont des parties jouées seul jusqu'à leur ancienneté (1 à 12 h), copiées dans le serveur.
- Chaque manche a deux phases (Feeding, digestion). Les voleurs choisissent le vol qui rapporte le plus en moyenne
  (chance de réussite x gain), parmi les bases ouvertes et non protégées.
- La réussite vient des tables de poursuite des étapes 1 et 3 : rareté, endroit où est le propriétaire, écart entre les
  bases, niveau d'entraînement des deux, grappin, attention du propriétaire, ami de la victime.
- Mesure principale : **base / seul** = valeur de la base (somme des revenus des familiers, sans monde ni Rebirth) en
  fin de session, divisée par celle de la même partie jouée seule sans vols. 1,00 = les vols n'ont rien changé.
- Scénarios : « mixte » (nouveau, voleur 1 h, prudent 2 h, duo 2 h, prudent 5 h, voleur 8 h, prudent 12 h) ; « nouveau
  chez les vétérans » (un nouveau, 7 joueurs de 5 à 12 h) ; « duo de nouveaux » (2 amis nouveaux, 2 nouveaux seuls,
  4 joueurs de 2 à 5 h).

**Hypothèses de comportement** (aucune donnée réelle encore : à remplacer par Roblox Analytics après la sortie) :

| Profil | Où pendant la digestion | Attention à l'alerte de vol | Verrou | Vols tentés |
| --- | --- | --- | --- | --- |
| prudent | base 60 %, tapis 40 % | 9 fois sur 10 | quand il est chez lui | jamais |
| voleur | part voler | 1 fois sur 2 | pendant qu'il vole | 1 par digestion, 1 Feeding sur 2 (~50 / h) |
| nouveau | tapis, kiosque, base | 1 fois sur 2 | 1 fois sur 3 | 1 digestion sur 3 |
| duo | partent voler ensemble | 6 fois sur 10 | pendant qu'ils volent | 1 par digestion, l'autre escorte |

Pendant le Feeding, chacun lance : depuis sa base dès le niveau « moyen » (stations au niveau 8), sinon près du trou.
Le grappin est acheté dès 300K $ ; on suppose qu'un tir touche 6 fois sur 10 avec les règles proposées (cône de 8°),
toujours avec les règles actuelles (cône de 14°).

## 5.2 Résultats (30 serveurs, sessions de 1 h)

| Réglages | nouveau chez les vétérans : base / seul, jackpots | prudent 12 h : base / seul, vols subis / h | voleur 8 h : base / seul, réussis / h | duo de nouveaux | écart riche / médiane |
| --- | --- | --- | --- | --- | --- |
| **règles actuelles** | x1,86, **5,3** | x0,99, 0,5 | x1,00, 30 | x2,7 | 2,34 |
| **règles proposées (étapes 2 à 4)** | x2,0 à x3,6, 0,3 à 0,4 | **x0,77**, 2,3 | x1,3, 17 | x23 à x25 | 1,9 |
| fenêtre ouverte 30 s au lieu de 60 | x1,09, 0,1 | x0,63, 3,1 | x1,72, 11 | x8 | 2,34 |
| bouclier 20 % cumulés en 10 min -> 5 min | x1,98, 0,3 | x0,73, 2,9 | x1,66, 13 | x20 | 1,77 |
| **bouclier 10 % perdus en 1 h -> 30 min** | **x1,72, 0,07** | x0,77, 3,5 | x1,34, 6,7 | x10 | 2,30 |
| bouclier 15 % en 1 h -> 15 min | x2,2, 0,3 | x0,70, 3,2 | x1,69, 9,3 | x14 | 1,98 |
| prudents moins attentifs (8 fois sur 10) | x2,37, 0,3 | x0,73, 5,3 | x1,40, 20 | x27 | 1,99 |
| prudents très attentifs (97 fois sur 100) | x2,04, 0,4 | **x1,00**, 0,7 | x1,00, 15 | x18 | 2,01 |
| grappin qui touche 4 / 8 fois sur 10 | x2,1 / x2,0 | x0,77 / x0,77 | x1,29 / x1,14 | x23 / x26 | 1,9 |
| plafond à +1 rareté | x1,49, 0 | x0,77, 2,3 | x1,29, 17 | x12 | 2,07 |
| plafond à +3 raretés | x2,20, 2,0 | x0,77, 2,4 | x1,29, 17 | x33 | 1,87 |
| duo sans escorte, ou sans refuge, ou sans « Reprendre » pour un ami | inchangé | inchangé | inchangé | x25 | 1,9 à 2,0 |

Jackpot = un vol qui multiplie le revenu du voleur par 20 ou plus. Les chiffres bougent d'un lancement à l'autre
(même réglage : nouveau x2,0 puis x3,6) : l'ordre des familiers dépendait du hasard de Python (corrigé depuis), et
30 serveurs restent peu. Les ordres de grandeur sont fiables, pas les décimales.

Ce que ça montre :
- **Le jackpot disparaît** : 5,3 jackpots par session pour un nouveau aujourd'hui, 0,3 avec les règles proposées
  (0,07 avec le bouclier sur 1 h). Le nouveau avance quand même 1,7 à 3,6 fois plus vite que seul : le rattrapage reste.
- **Voler paie enfin** : aujourd'hui, les voleurs se volent entre eux 30 fois par heure sans rien gagner au total
  (x1,00). Avec les règles proposées, ils réussissent moins (7 à 17 par heure) mais gagnent (x1,3).
- **L'écart entre le plus riche et les autres se réduit** : 2,3 -> 1,9.
- **Le prix à payer : le joueur prudent.** Sa base n'est plus fermée en permanence. S'il réagit 9 fois sur 10 à
  l'alerte, il perd ~23 % de sa base en 1 h face à trois voleurs qui tentent chacun ~50 vols par heure ; s'il réagit
  97 fois sur 100, il ne perd rien. La précision du grappin n'y change presque rien : les vols réussis viennent des
  moments d'inattention. C'est voulu (« sois là quand c'est ouvert »), mais le chiffre dépend d'hypothèses
  (attention, nombre de tentatives) qu'on ne connaîtra qu'avec de vrais joueurs.
- **Le plafond à +2** est le bon compromis : à +1, plus aucun jackpot mais le rattrapage tombe à x1,5 ; à +3, les
  jackpots reviennent (2 par session).
- **Fenêtre de 30 s au lieu de 60** : pire pour les prudents (x0,63). Les voleurs, mieux fermés eux-mêmes, se
  rabattent sur eux. On garde 60 s.
- **Le duo** : ce qui le rend si fort (x23), c'est le nombre de vols tentés (le profil vole à chaque digestion), pas
  l'escorte ni le refuge. Sans eux, le résultat ne change pas. Les règles 17 à 19 restent utiles pour le plaisir de
  jouer ensemble, pas pour l'équilibre. En revanche, un nouveau qui vole à chaque manche avance très vite (x10 à x25)
  : le plafond limite chaque vol, mais pas leur nombre. Le bouclier sur 1 h divise ce chiffre par 2,5.

## 5.3 Appliqué dans le jeu le 25 oct. (premier lot)

Les règles dont l'effet ne dépend pas du comportement des joueurs, ou qui ne font que retirer un abus :

| Règle | Où | Ce qui change |
| --- | --- | --- |
| 11. Pitié par palier | `Config.Loot.PityPercentile`, `shared/LootEngine` (`pityTarget`, `pityAt`), `server/PullRewards`, `client/HUD`, `client/RobuxShop` | la rareté au-dessus de ta meilleure est garantie au tirage où 9 joueurs sur 10 l'auraient eue ; la carte de résultats dit « MYTHIQUE OU MIEUX GARANTI DANS 23 TIRAGES » ; l'onglet Chances l'explique (tirages Robux compris) |
| 13. Jauge en objets | `Config.MeanGaugePerItem`, `Config.Blackhole.GaugeNeed` (x1,26), `server/BlackholeTiers.OnScored` | chaque palier dure au moins une manche, même à 8 joueurs avancés |
| 5. Vitesse en portant | `Config.Carry.SpeedByRarity`, `server/StealController.CarrySpeed` | 0,95 -> 0,38 selon la rareté, jamais plus vite que le propriétaire ; la Force ne compte plus pour porter |
| 6. Grappin | `Config.Weapons.Grapple` | cône 14° -> 8°, recharge 5 s -> 9 s |
| Batte (étape 2) | `Config.Weapons.HitWindow`, `MaxHitsPerWindow`, `server/WeaponController` | 2 coups au plus par victime toutes les 10 s |
| 3. Marché | `Config.Market.MaxPriceSeconds`, `Config.GetMarketMaxPrice`, `server/MarketController`, `client/MarketMenu` | prix au plus 1 h du revenu du familier ; la fenêtre affiche le maximum |
| Matrice | `dataset_and_pipeline/tools/build_game_design_matrix.py`, `game_design_matrix.json` | valeurs lues dans le bon tableau (Rebirth 4T, x2,7, +100 % ; vol en 0,3 s) ; nouvelles vitesses de transport |

Vérifié : analyse Luau (`luau-lsp analyze`, mode strict) sans erreur ; `rojo build` réussi ; les 9 tests Lune passent,
dont le nouveau `tools/check-pity.luau` (seuil, garantie, compteur, pas de garantie au-dessus du Sigma, ~1 garantie
pour 9 Mythiques tirés au hasard). Les tests du marché et du vol des nouveaux ont reçu les nouveaux réglages, et le test
du marché vérifie qu'un prix trop haut est refusé. Simulateur solo relancé avec le nouveau `Config.lua` (200 parties de
30 h) : 1er Rebirth 8,7 h (inchangé), 1er Sigma avant 2,0 h pour 9 joueurs sur 10 (2,4 h avant), mêmes sources d'argent.
`economy_data.json` contient maintenant les valeurs du jeu modifié ; celles d'avant restent dans l'historique git.

**Pas vérifié : rien n'a été joué dans Studio.** À regarder : la ligne de pitié sur la carte de résultats, l'onglet
Chances, la vitesse en portant (message « TRÈS LOURD »), le prix maximum au marché ; à 2 joueurs, le grappin plus
étroit et la batte limitée.

## 5.4 Ce qui restait à décider

1. **Verrou à cycle fixe, bouclier sur 1 h, plafond +2, vol utile** : décidé par Chouaib le 25 oct., appliqué (5.5).
2. **Rebirth (règles 15 et 16)** : une capsule de plus par Rebirth et le nouveau prix. C'est le plus gros chantier
   (plusieurs capsules sur la carte et dans l'interface).
3. **Couronne du plus riche (9)**, **pile « prochain objectif » (12)**, **jeu entre amis (17 à 19)**.
4. **Au choix** : gros butin signalé à tous (10), ruée des voleurs après l'effondrement (14).

## 5.5 Appliqué dans le jeu le 25 oct. (deuxième lot)

| Règle | Où | Ce qui change |
| --- | --- | --- |
| Verrou à cycle (étape 2) | `Config.Lock` (`Duration` 45, `LongBonus` 10, `Cycle` 105, `MinOpen` 30), `Config.GetLockDuration`, `server/LockController`, `client/ShopMenu`, description du Verrou renforcé | un passage sur le bouton ferme la base 45 s (55 s avec le Verrou renforcé, 65 s avec le VIP en plus), puis le bouton reste gris (« RECHARGE : Xs ») jusqu'à 105 s après le passage ; rester sur le bouton ne prolonge plus rien |
| 8. Bouclier | `Config.StealShield`, `server/StealController` (`recordLoss`, `IsShielded`), `client/Newcomer`, `client/BasePets`, `client/LoosePets` | 10 % de la valeur de la base perdus en 1 h (vols et familiers jetés au trou) -> 30 min sans pouvoir être volé ; compte à rebours « BOUCLIER » dans le HUD, bulles [E] cachées chez les autres |
| 2. Plafond +2 | `Config.PowerCap`, nouveau `shared/PowerCap`, `server/SessionData` (champ sauvegardé `selfBest`, attribut `SelfBest`), `server/EconomyController` (revenu, base, attribut `BaseMin`), `server/StealController` (sacrifice), récompense d'Index (`Config.GetIndexReward`), `client/BasePets` (étiquette « (BRIDÉ) » chez soi), `client/IndexMenu`, `client/CarryControls` | un familier rapporte au plus le revenu de base de la rareté juste 2 crans au-dessus de la meilleure que tu as fait éclore toi-même ; l'Index dit « BRIDÉ : 4,11M/s avec un Divin à toi » |
| 7. Vol utile | `shared/PowerCap.IsUseful`, `server/StealController` (`tryStart`, `tryPickLoose`), `client/BasePets`, `client/LoosePets` | on ne peut prendre chez un autre que ce qui ferait monter son revenu ; la bulle [E] n'apparaît que sur ces familiers ; la quête « Vole N familiers » ne compte donc plus que ceux-là |

Sauvegardes : les profils d'avant ce lot reçoivent `selfBest` = la meilleure rareté qu'ils possèdent déjà (ils ne sont
pas bridés). Les nouveaux profils partent de 0 (le Chien-Saucisse offert, une fois éclos, compte comme un Commun à soi).

Vérifié : analyse Luau sans erreur, `rojo build` réussi, les 10 tests Lune passent, dont le nouveau
`tools/check-steal-rules.luau` (plafond, rareté à obtenir, vol utile, durée du verrou). Trois tests existants ont reçu
les nouveaux modules dans leurs remplaçants (`PowerCap`, `SessionData.GetSelfBest`, `EconomyController`).

**Pas vérifié (Studio)** : les contrôleurs eux-mêmes (cycle du verrou, déclenchement du bouclier) ne sont pas joués
hors ligne. À regarder :
- seul : bouton du verrou (vert 45 s, puis gris « RECHARGE », puis rouge), Verrou renforcé, étiquettes « (BRIDÉ) » et
  Index avec un familier donné par un script, aperçu du familier jeté au trou ;
- à 2 joueurs : bulles [E] seulement sur les familiers utiles, bouclier après une grosse perte (compte à rebours, bulles
  cachées chez le voleur), vol pendant la recharge du verrou.

## 5.6 Appliqué dans le jeu le 25 oct. (Rebirth : règles 15 et 16)

| Règle | Où | Ce qui change |
| --- | --- | --- |
| 15. Une chambre de capsule de plus par Rebirth | `Config.Rebirth.ExtraCapsules` (1), `MaxExtraCapsules` (5), `Config.GetCapsuleSlots`, `server/SessionData` (`GetEvolvingList`, `GetCapsuleSlots`, `TickEvolutions`), `server/EggController`, `client/EvolutionMachine`, `client/RebirthMenu` | la capsule tient 1 œuf au départ, puis 2, 3… jusqu'à 6 ; chacun tente d'évoluer de son côté ; la capsule montre l'œuf le plus avancé et « CHAMBRES 2/3 » ; la fenêtre Rebirth affiche « CHAMBRES DE LA CAPSULE 1 → 2 » |
| 15. Doublons vers une chambre libre | `Config.Evolution.DuplicatesToCapsule`, `SessionData.AddCapsuleEgg`, `server/PullRewards` | un doublon de sa meilleure rareté (au-delà de 5 exemplaires) entre dans une chambre libre au lieu d'être vendu |
| 16. Prix du Rebirth | `Config.Rebirth.PriceGrowth` (2,7 -> 1,62), `Config.GetRebirthPrice` = 4T x (n + 1) x 1,62^n | 4T, 13T, 31,5T, 68T, 138T, 268T, 506T (avant : 4T, 10,8T, 29T, 79T, 213T, 574T, 1,5Qa) |

**Écart avec la proposition de l'étape 4** : « une capsule de plus » est devenue **une chambre de plus dans la même
capsule**. Effet de jeu identique (plusieurs œufs qui évoluent en même temps, c'est ce que le simulateur a mesuré), mais
sans poser jusqu'à 6 capsules derrière chaque base, là où les autres agents posent les décors des mondes, et sans
réécrire toute l'interface de la capsule. Des capsules visibles en plus pourront venir ensuite si Chouaib le veut.

Avec plusieurs chambres, [E] sur la capsule : ouvrir l'œuf montré s'il n'évoluera plus, sinon mettre un œuf s'il reste
une chambre, sinon ouvrir l'œuf montré (une fois son incubation finie). Un œuf qui évolue encore ne s'ouvre donc tôt que
si toutes les chambres sont prises.

Simulateur solo avec les règles du jeu (120 parties de 45 h ; prix et chambres lus dans le jeu par
`tools/export-economy.luau`) : Rebirths à 8,7 h, 12,5 h, 16,1 h, 20,0 h, 24,2 h, 29,6 h, 36,2 h, soit des cycles de 3,6
à 6,6 h, comme prévu à l'étape 4 (avant : Rebirth 5 vers 28 h, Rebirth 6 hors de portée). Revenu à 20 h : 5,7B/s (avant 3,4B/s).

Vérifié : analyse Luau sans erreur, `rojo build` réussi, les 10 tests Lune passent. `tools/check-eggs.luau` vérifie
maintenant, avec la vraie sauvegarde, deux chambres après un Rebirth, le refus quand elles sont pleines, une tentative
par chambre, l'ouverture de l'une puis de l'autre et le doublon envoyé dans une chambre libre ; il suit aussi la
nouvelle formule du prix.

**Pas vérifié (Studio)** : la capsule à plusieurs chambres (titre « CHAMBRES », bulle [E] qui passe de « Mettre un
œuf » à « Faire éclore »), la fenêtre Rebirth (nouvelle ligne), un doublon qui part dans la capsule pendant
l'ouverture des tirages.

## 5.7 Appliqué dans le jeu le 25 oct. (couronne du plus riche : règle 9)

| Où | Ce qui change |
| --- | --- |
| `Config.Crown`, nouveau `shared/CrownRules` (règles pures), nouveau `server/CrownController`, `server/Main.server` | toutes les 2 s, le plus gros revenu du serveur prend la couronne (dès 2 joueurs) ; pour la lui prendre, il faut le dépasser de 10 % ; annonce à tout le serveur |
| `server/StealController` | voler le roi rapporte, en plus du familier, une prime égale à ce que rapporterait de jeter ce familier au trou (600 s de son revenu plafonné x monde x passes du voleur) ; un voleur arrêté chez le roi (repris, frappé, trop lent) rapporte au roi la même somme, +1 au compteur de défenses et une annonce |
| nouveau `client/Crown`, `client/HUD` | couronne et « ROI DU SERVEUR • 3 DÉFENSES » au-dessus de la tête du roi, panneau « BASE DU ROI • PRIME SUR SES FAMILIERS » sur sa base ; messages « X EST LE ROI DU SERVEUR », « TU ES LE ROI… », « X A DÉFENDU SA COURONNE CONTRE Y », « PRIME DU ROI : +… » |

Garde-fous : la récompense de défense est payée au plus 3 fois par heure et une fois par voleur toutes les 10 min
(`CrownRules.CanReward`). Sans ça, deux amis pourraient s'enrichir en se volant exprès ; avec, au plus ~+7 % du revenu du
roi par heure. La prime du voleur n'a pas besoin de limite : le roi perd vraiment le familier, et son bouclier (règle 8)
se déclenche après 10 % de pertes. La couronne ne donne aucun revenu en plus : prestige et jeu, pas de boule de neige.

Vérifié : analyse Luau sans erreur, `rojo build` réussi, les 10 tests Lune passent (`check-steal-rules` teste maintenant
le choix du roi, la marge de 10 % et les limites de récompense). **Pas vérifié (Studio)** : c'est une règle à au moins
2 joueurs (Test > Clients et serveurs) : couronne au-dessus de la tête et sur la base, changement de roi, prime du
voleur, défense du roi (Reprendre ou batte) et ses limites. Après l'ajout de nouveaux fichiers, vérifier qu'il n'y a pas
de scripts en double dans Studio (déjà arrivé, voir CLAUDE.md).

## 5.8 Appliqué dans le jeu le 25 oct. (pile « prochain objectif » : règle 12)

| Où | Ce qui change |
| --- | --- |
| nouveau `shared/NextGoals` (calcul pur) | la liste des objectifs entamés, avec avancée et temps restant : prochain monde (ou Rebirth au dernier monde), pitié (« MYTHIQUE GARANTI DANS 10 TIRAGES »), prochaine tentative de la capsule, Index (40 / 106), familier bridé à libérer (« LE CAPYBARA ZEN BRIDÉ : OBTIENS UN MYTHIQUE ») ; on en montre deux : celui qui arrivera le plus tôt, puis le plus avancé des autres |
| nouveau `client/NextGoals` | deux lignes avec une barre dans la pile sous l'horloge (sous le compte à rebours ANTI-VOL / BOUCLIER) : « MONDE DÉSERT • 75 % • 50 s » |
| `server/SessionData` (au chargement), `client/NextGoals` | résumé d'absence : « PENDANT TON ABSENCE : 3 ŒUFS ONT ÉCLOS • TA CAPSULE A 2 TENTATIVES D'ÉVOLUTION » (œufs et capsule avancent hors ligne) |

Temps restants : argent manquant / revenu ; pitié = tirages restants / tirages de la dernière manche x 105 s ; capsule =
heure de la prochaine tentative publiée par la capsule.

Vérifié : analyse Luau sans erreur, `rojo build` réussi, les 10 tests Lune passent (`check-steal-rules` teste maintenant
les objectifs : 75 % du Désert en 50 s, la pitié, le choix des deux objectifs, le Rebirth au dernier monde, le familier
bridé, accents compris). **Pas vérifié (Studio)** : la place de la pile à l'écran (PC et téléphone, aperçu
`DebugPhone`), les deux lignes qui changent au fil de la partie, le résumé d'absence en revenant après une éclosion.

## 5.9 Appliqué dans le jeu le 25 oct. (jeu entre amis : règles 17 à 19)

| Règle | Où | Ce qui change |
| --- | --- | --- |
| Liste des amis | nouveau `server/Friends` (attribut `FriendIds`), `server/Main.server` | les amitiés Roblox entre joueurs présents, vérifiées une fois à l'arrivée (3 s au plus, en parallèle) |
| 17. Base voisine | `server/BaseManager` (`pickBase`) | un joueur qui arrive reçoit, si elle est libre, la base à côté de celle d'un ami ; sinon la première libre comme avant |
| 17. Refuge | `server/StealController` (`update`) | un familier volé peut être rapporté dans la base d'un ami présent : le vol réussit, le familier va au voleur |
| 18. Escorte | `Config.Friends.EscortRadius` (15), `StealController.CarrySpeed`, `updateEscort` | un ami à moins de 15 studs du porteur : le familier compte comme une rareté plus légère (+14 % de vitesse), recalculé 10 fois par seconde (attributs `SpeedMultiplier`, `Escorted`) |
| 19. Reprendre pour un ami | `StealController.tryRecover`, `client/PetFollow`, `client/HUD` | les amis de la victime voient le voleur entouré de rouge et la bulle « Reprendre », et peuvent rendre le familier à son propriétaire ; ils sont prévenus : « VOL CHEZ TON AMI X : RATTRAPE Y… » |

Rappel du simulateur (5.2) : ces règles ne changent presque rien à l'équilibre (ce qui rend un duo fort, c'est le nombre
de vols tentés). Elles sont là pour le plaisir de jouer ensemble et pour inviter ses amis (le bonus de +10 % de revenu par
ami présent reste). L'œuf offert quand un ami arrive par invitation (étape 4) n'est pas fait : le champ Roblox qui dit
qui a invité reste à vérifier dans la documentation.

Vérifié : analyse Luau sans erreur, `rojo build` réussi, les 10 tests Lune passent (`check-steal-rules` vérifie que
chaque rareté est ~14 % plus rapide que la suivante et que l'escorte est à portée de batte). **Pas vérifié** : ces règles
ont besoin de **deux vrais comptes Roblox amis** dans le jeu publié (les joueurs de test de Studio ne sont pas amis entre
eux, comme pour le bonus d'amis déjà en place) : base voisine, vol rapporté chez l'ami, vitesse escortée, bulle
« Reprendre » et alerte chez l'ami.
