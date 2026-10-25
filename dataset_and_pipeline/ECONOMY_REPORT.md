# Rapport économique (phase 1.7)

**État au 25 oct. 2026 : étape 1 (audit) faite.** Les étapes 2 à 5 (courbes, risque du vol, rétention, simulateur
Monte-Carlo) viennent ensuite. **Rien n'a encore été changé dans le jeu** : ce document constate, il ne règle rien.

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
- **E2. Jouer rapporte peu.** 80 % de l'argent vient du revenu passif, et une manche ne donne plus que 24 tirages
  après 5 h, quoi qu'on fasse. Lancer des objets ou rester sans bouger rapporte presque pareil.
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
les profils (prudent, voleur, nouveau dans un serveur avancé, duo d'amis), les absences, la capsule d'évolution,
les mutations, le marché et les échanges, et les vraies premières minutes (objets par manche selon la Force).

## 7. Prochaine étape

Étape 2 : courbe coûts / revenus (montée rapide au début, puis paliers où il vaut mieux prendre des risques) et
règles pour les défenses qui gênent les autres (verrou, grappin, batte). Les cibles chiffrées seront déduites des
mesures ci-dessus, puis vérifiées par le simulateur de l'étape 5 avant de toucher `Config.lua`.
