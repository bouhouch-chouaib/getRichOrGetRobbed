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
