# Plan d'équilibrage de la progression (20 oct. 2026)

Retour d'un ami testeur : « soit c'est trop facile de monter, soit c'est trop difficile » (Rebirth, mondes, améliorations).
Ce document dit pourquoi, et comment on corrige, étape par étape.

## 1. Le diagnostic (chiffres tirés de `Config.lua`)

**a) Le revenu fait des bonds énormes d'une rareté à l'autre.** Un familier rapporte par seconde :
Commun 2 · Inhabituel 25 · Rare 400 · Épique 8K · Légendaire 200K · Mythique 6M · Divin 250M · Sigma 25B.
Entre deux raretés, c'est x12 à x100. Toute la progression dépend donc d'un coup de chance au tirage :
- un seul Légendaire (4 % par tirage) rapporte 200K/s : le Désert (1M) s'achète en 5 secondes, le Volcan en 3 min
  → **trop facile** ;
- sans Divin (0,4 % par tirage), le monde Divin (250T) demande des dizaines d'heures avec des Mythiques
  → **trop difficile**.

**b) Les prix des mondes ne suivent pas le revenu.** Chaque monde coûte x40 à x60 le précédent, mais ne multiplie le
revenu que par x1,5. Le prix ne dépend donc pas du monde atteint : il dépend uniquement de la rareté qu'on a tirée.

**c) Le Rebirth est trop facile une fois qu'on a de bons familiers.** On garde ses familiers et on gagne x2 de revenu :
on rachète tous les mondes en quelques secondes. Avec une équipe de Sigma, le Rebirth 2 (10 fois plus cher)
se paie presque tout de suite.

**d) Les améliorations ont leurs propres courbes, sans lien avec le reste.**
- Tapis niveau 25 : environ 1,8 x 10^17, plus cher que le 1er Rebirth.
- Chance niveau 10 : environ 2 x 10^14.
- Sac à dos : 25K, puis 10M, puis 4B, puis 1,6T.

Au début, elles semblent hors de prix ; avec un Légendaire, tout devient gratuit d'un coup.

**e) Les tirages ne dépendent pas du monde.** Les chances de rareté sont les mêmes en Prairie et en Divin : avancer
dans les mondes n'aide pas à obtenir de meilleurs familiers. Or c'est le moteur des jeux de référence : la zone
suivante donne de meilleurs œufs.

## 1 bis. Mesures du simulateur (étape 1, 20 oct.) : valeurs actuelles

`lune run tools/sim-economy.luau . 200 24` (200 parties de 24 h, un joueur seul ; détails des hypothèses en tête du fichier).

| Étape | chanceux | moyen | malchanceux |
| --- | --- | --- | --- |
| Désert | 4 min | 5 min | 9 min |
| Volcan | 7 min | 10 min | 14 min |
| Glace | 14 min | 18 min | 23 min |
| Abysses | 26 min | 33 min | 38 min |
| Cosmos | 42 min | 52 min | 1,1 h |
| Divin | 58 min | 1,3 h | 2,1 h |
| **Rebirth 1** | 1,3 h | **1,7 h** (visé : 8-10 h) | 2,4 h |
| Rebirth 2 | 2,0 h | 2,6 h | 3,5 h |
| Rebirth 3 | 3,8 h | 4,5 h | 5,7 h |
| Rebirth 4 | 17,5 h | 18,3 h | 19,5 h |

Revenu moyen : 0,9M/s après 10 min, 227M/s après 30 min, 15B/s après 1 h, 1,6T/s après 2 h, puis **bloqué vers 7T/s**
de 5 h à 20 h (on a déjà tous les meilleurs familiers). Une manche donne déjà 90 points et 19 tirages après 10 min,
puis 63 tirages. D'où vient l'argent avant le 1er Rebirth : points du trou 55 %, revenu des familiers 44 %, le reste
moins de 1 %. La fusion ne change presque rien au rythme.

**Ce que ça confirme :** tout va beaucoup trop vite jusqu'au Rebirth 3 (4,5 h au lieu de 8-10 h pour le 1er), puis
c'est un mur (Rebirth 4 : 14 h de plus, sans rien de nouveau à gagner). Les causes, par ordre d'importance :
1. **La Chance (amélioration ItemQuality)** est trop bon marché et trop forte : chaque niveau multiplie les objets
   rares, la valeur moyenne d'un objet explose, donc les points, donc les tirages (19 tirages par manche à 10 min).
2. **L'argent des points** (0,1 s de revenu par point) dépasse le revenu des familiers dès qu'on a beaucoup de points.
3. **Les écarts de revenu entre raretés** (x12 à x100) et des tirages qui ne dépendent pas du monde.
4. **Le Rebirth** : prix x10 à chaque fois alors que le revenu plafonne → facile au début, puis mur.

## 1 ter. Nouvelles valeurs (étapes 2 à 7, 20 oct.) : résultat du simulateur

200 parties de 26 h. Temps visés (choix de Chouaib : 1er Rebirth vers 8-10 h) entre parenthèses.

| Étape | chanceux | moyen | malchanceux |
| --- | --- | --- | --- |
| Désert (10 min) | 5 min | 9 min | 12 min |
| Volcan (30 min) | 18 min | 23 min | 30 min |
| Glace (1 h) | 40 min | 49 min | 1,1 h |
| Abysses (2 h) | 1,4 h | 1,8 h | 2,2 h |
| Cosmos (3,5 h) | 3,1 h | 3,7 h | 4,5 h |
| Divin (6 h) | 6,5 h | 7,1 h | 7,9 h |
| **Rebirth 1 (~9 h)** | 8,6 h | **9,2 h** | 10,0 h |
| Rebirth 2 (+6 h) | 13,4 h | 14,1 h | 14,8 h |
| Rebirth 3 (+5 h) | 19,0 h | 19,6 h | 20,4 h |

Revenu moyen : 4,6K/s après 10 min, 255K/s après 30 min, 3M/s après 1 h, 30M/s après 2 h, 151M/s après 5 h, 302M/s
après 10 h, 610M/s après 20 h (il continue de monter grâce aux Rebirths). Une manche : 6 tirages au début, 24 au plus.
Argent avant le 1er Rebirth : 77 % revenu des familiers, 15 % points du trou, 8 % doublons vendus.

Ce qui a changé dans `Config.lua` :
- **Chance** : `Items.QualityBoost` 0,5 → 0,2 ; prix x7,7 par niveau (avant x18).
- **Tirages** : `Loot.PullCostGrowth` 8 % → 22 % (moins de tirages par manche) ; `Loot.LuckPerPoint` 0,01 → 0,005.
- **Argent des points** : `Economy.IncomeSecondsPerPoint` 0,1 → 0,02.
- **Raretés** : revenus 2 / 14 / 100 / 700 / 5K / 35K / 250K / 1,75M (environ x7 d'une rareté à l'autre) ; poids des
  raretés hautes divisés (Mythique 9, Divin 2,5, Sigma 0,5).
- **Mondes** : nouveau `RarityBoost` (meilleurs tirages : x1,08 à x1,8 par rang de rareté) ; revenu x1,6 / 2,5 / 4 /
  6,5 / 10 / 16 ; prix 200K / 14M / 450M / 14B / 300B / 1,4T. Code : `LootEngine` (paramètre tier), `PullRewards`
  (monde le plus loin atteint), `RobuxShop` (chances affichées exactes).
- **Rebirth** (option a) : 2,5T, puis x2,1 à chaque fois (avant 1Qa puis x10).
- **Fusion** : prix ramenés aux nouveaux revenus (250 / 8K / 190K / 3,5M / 60M / 1,5B).
- **Boutique** : tapis et banc x2,44 par niveau (niveau 25 vers 17 h), Chance x7,7, sac à dos x150.

**21 oct. : 30 familiers exclusifs des mondes** : plus d'espèces, donc un revenu plus haut en fin de partie ; Rebirth
réajusté à 4T puis x2,7 (simulation : Divin 6,2 h, Rebirth 1 8,7 h, Rebirth 2 13,1 h, Rebirth 3 18,9 h).

Limite connue : la base prend un familier par espèce d'abord. Une fois les 5 Sigma et les 9 Divins obtenus, le revenu
ne monte plus que par les mondes, les Rebirths, la capsule d'évolution et les mutations (non simulées).

## 2. L'idée directrice

Une seule courbe de progression, avec un **temps de jeu visé pour chaque étape**. Tous les prix en découlent :
« le monde N coûte environ X minutes du revenu qu'on a normalement à ce moment-là ». La chance garde sa place
(un bon tirage fait gagner du temps), mais elle ne casse plus la courbe.

## 3. Les étapes (une à la fois, chacune testée)

1. **Simulateur de progression** (`tools/sim-economy.luau`, lancé hors Studio comme les autres tests). Il joue un
   joueur moyen manche après manche : points, tirages (chances, pitié, rang), revenu, achats. Il sort le temps pour
   chaque monde, chaque amélioration et chaque Rebirth, pour 3 profils : malchanceux, moyen, chanceux. On mesure
   d'abord les valeurs actuelles, pour confirmer le diagnostic avec des chiffres.
2. **Fixer les temps visés** (décision de Chouaib, 20 oct. : **1er Rebirth vers 8-10 h de jeu**), par exemple : Désert 10 min, Volcan 30 min, Glace 1 h, Abysses 2 h,
   Cosmos 4 h, Divin 7 h, 1er Rebirth vers 8-10 h, puis chaque Rebirth un peu plus rapide.
3. **Lisser les raretés** : écarts de revenu plus réguliers, d'environ x6 à x8 entre deux raretés au lieu de x12 à x100.
   Un familier rare reste un gros cadeau, sans faire sauter trois mondes d'un coup.
4. **Les mondes améliorent les tirages** : chaque monde augmente les chances des raretés hautes, sur le modèle de la
   zone suivante qui donne de meilleurs œufs. Avancer devient utile, et les familiers suivent le monde.
5. **Recalculer les prix des mondes** à partir de la courbe (étapes 2 à 4), avec le simulateur.
6. **Revoir le Rebirth** pour qu'il reste un vrai objectif. Pistes à choisir :
   - (a) le prix monte plus vite que le bonus ;
   - (b) le Rebirth demande aussi un familier d'une certaine rareté ;
   - (c) les places de la base repartent à zéro.

   Le simulateur dira laquelle donne le bon rythme.
7. **Améliorations liées aux mondes** : chaque monde débloque quelques niveaux de tapis, banc, chance, sac et aimant,
   à un prix de quelques minutes du revenu de ce monde. Plus de niveaux hors de prix, ni gratuits d'un coup.
8. **Vérification** :
   - le simulateur pour les 3 profils ;
   - une partie dans Studio (début de partie, achat d'un monde, Rebirth) ;
   - puis une nouvelle partie de l'ami testeur.

Toutes les valeurs restent dans `Config.lua` : Chouaib garde la main pour les derniers réglages.
