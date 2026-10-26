# Guide UI / UX — Get Rich Or Get Robbed (phase 1.8, 26 oct. 2026)

Ce guide sert de règle pour tous les menus du jeu. Il complète `docs/DIRECTION_ARTISTIQUE.md` (§3 et §3.1 : style des
fenêtres, textures, icônes) et s'applique d'abord à la Boutique, refaite en une seule page qui défile.

Code concerné : `src/client/UiStyle.lua` (briques de style), `src/client/MenuKit.lua` (fenêtres, onglets, flou),
`src/client/ScreenScale.lua` (mise à l'échelle), `src/client/UIJuiceController.lua` (effets, nouveau),
`src/client/ShopKit.lua` (briques de la Boutique, nouveau), `src/client/ShopMenu.lua` et `src/client/RobuxShop.lua`.

---

## 1. Audit des scripts d'interface (état au 26 oct., avant la refonte)

### 1.1 Comment l'écran est mis à l'échelle (ce qui marche déjà)

Toute l'interface est dessinée sur un écran virtuel de 1280 x 720 (1280 x 640 au doigt) puis réduite par un `UIScale`
(`ScreenScale.attach`). Les tailles en pixels (`UDim2.fromOffset`) sont donc des pixels **virtuels** : elles suivent
l'écran, comme des tailles en pourcentage, sans les défauts du pourcentage (texte flou, cartes déformées). Les
fenêtres sont en plus ajustées à la place libre (`MenuKit` : fonction `fit`). On garde ce système : il n'y a pas de
faille « Offset contre Scale » à corriger en bloc.

Ce qui reste à surveiller : un pixel virtuel devient **0,56 pixel réel** sur un téléphone en paysage (844 x 390 points,
fenêtre de 900 de large). Tout ce qui est fin sur PC devient minuscule au doigt :

| Élément (Boutique d'avant)                   | Taille virtuelle | Sur téléphone (points) | Minimum lisible / touchable |
|----------------------------------------------|------------------|------------------------|-----------------------------|
| Description des cartes (`MaxTextSize = 14`)  | 12 à 14 px       | **7 à 8 pt**           | 12 pt                       |
| Bouton de prix                               | 50 px de haut    | **29 pt**              | 44 pt                       |
| Croix de fermeture                           | 52 px            | 30 pt                  | 44 pt                       |
| Carte (largeur)                              | 214 px           | 123 pt                 | —                           |

Calcul : échelle de l'écran 0,609 (390 / 640) x échelle de la fenêtre 0,94 (place libre entre les tuiles du HUD et le
bouton de saut) = 0,575 pour l'ancienne Boutique (946 de large avec ses onglets).

### 1.2 Failles de la Boutique actuelle

1. **Six onglets pour une seule boutique.** Entraînement / Bonus / Combat / Passes R$ / Produits R$ / Chances : il
   faut cliquer 6 fois pour tout voir. Les passes Robux ne sont jamais vus si on ne va pas les chercher, et la colonne
   d'onglets prend 206 px de large (22 % de la fenêtre).
2. **Cartes qui défilent de gauche à droite.** La molette de la souris fait défiler de haut en bas : sur PC, rien ne
   bouge ; il faut attraper la barre. 3 cartes visibles sur 4 ou 5, aucun signe qu'il y en a d'autres.
3. **Texte trop petit au doigt** (tableau ci-dessus) : descriptions à 7-8 pt, boutons à 29 pt.
4. **Effet faux pour « Chance »** : la carte annonçait « +50 % chance » par niveau alors que le jeu donne +20 %
   (`Config.Items.QualityBoost = 0.2`, `server/ItemSpawner`). Corrigé : l'effet est lu dans `Config`.
5. **Aucune jauge de niveau** : « Niveau 3 / 25 » en petit texte, pas de barre qui montre où on en est.
6. **Pas assez d'argent = bouton rouge + bandeau**, sans dire combien il manque ni secouer quoi que ce soit.
7. **Achat sans réaction dans la fenêtre** : le son et le bandeau viennent du HUD ; la carte ne bouge pas, le chiffre
   d'argent n'est pas dans la fenêtre.
8. **Cartes détruites et recréées** à chaque changement d'onglet (et la position de défilement perdue).
9. **Rien n'est mis en avant** : pas de « conseillé », pas d'offre exclusive en tête, pas de pastille par section
   (seulement « ! » sur les onglets).
10. **Survol sans effet** : `UiStyle.bounce` garde l'échelle à 1 au survol (pour ne pas déborder sur les voisins dans
    les grilles serrées) ; seul le reflet passe.
11. **Croix de fermeture rentrée dans l'en-tête**, pas assez visible ni assez grande au doigt.

### 1.3 Autres menus (relevé rapide, à reprendre plus tard avec les mêmes règles)

- Index (860 x 560), Marché, Fusion, Duel, Échange, Bonus : même socle `MenuKit`, mêmes tailles de texte fines au doigt.
- Mondes et Capsule d'évolution défilent encore de gauche à droite (même faille 2).
- Le guide s'applique à chaque menu refait ; la Boutique sert de modèle.

---

## 2. Style « chunky » (règles visuelles)

- **Contours** : `UIStroke` en mode `Border`, noir, 3 px (boutons) à 5 px (fenêtres) ; textes avec contour noir
  arrondi (`Typography.StrokeSize`).
- **Coins** : `UICorner` 8 à 12 px partout ; les rubans et pastilles en rond.
- **Boutons en relief** : dégradé vertical clair -> franc -> sombre (`UiStyle.buttonColors`), reflet en haut, lèvre
  sombre en bas (ombre portée), reflet qui balaie au survol.
- **Police** : Montserrat Heavy partout (`shared/Typography`), **choix de Chouaib** : on ne passe pas à FredokaOne ni
  à LuckiestGuy. Toujours avec contour noir.
- **Icônes d'abord** : chaque bouton, pastille et carte porte une icône dessinée (`shared/Icons`), jamais d'émoji ; le
  texte vient en second. Aucune nouvelle image envoyée sur le compte de Chouaib sans son accord (avertissement de
  modération du 25 oct.) : on réutilise les icônes et textures déjà en ligne.

### 2.1 Couleurs selon la fonction

| Couleur                 | Sens                                              | Où                                    |
|-------------------------|---------------------------------------------------|---------------------------------------|
| Vert `Colors.Green`     | Acheter avec l'argent du jeu, valider             | Boutons de prix, section Bonus        |
| Or `Colors.Gold`        | Premium, exclusif, Robux                          | Offres Robux, rubans « EXCLUSIF »     |
| Cyan `Colors.Speed`     | Vitesse                                           | Tapis de course                       |
| Orange `Colors.Strength`| Force                                             | Banc de muscu                         |
| Rouge `Colors.Red`      | Combat, refus, fermer                             | Section Combat, croix, éclair de refus|
| Violet                  | Produits Robux (tirages, clés, boost)             | Section Produits                      |
| Gris                    | Maximum atteint, déjà possédé, pas disponible     | Boutons « MAX », « POSSÉDÉ »          |

Un bouton de prix est vert si on peut payer, **rouge** s'il manque de l'argent (le clic explique combien), gris au
maximum.

### 2.2 Rubans

Courts et vrais : « CONSEILLÉ » (la moins chère des améliorations qu'on peut s'offrir), « EXCLUSIF » (offre Robux en
tête), « x2 ARGENT », « +25 % », « x10 », « TOUT LE SERVEUR ». Pas de « POPULAIRE » ni de « MEILLEURE VENTE » tant que
le jeu ne mesure pas les ventes : ce serait faux.

---

## 3. Ergonomie et écrans (téléphone d'abord)

- **Une seule page qui défile de haut en bas** (molette, doigt, manette), sections dans l'ordre : À la une,
  Entraînement, Bonus, Combat, Passes R$, Produits R$, Chances.
- **Pastilles de navigation** en haut : une par section, icône en haut et mot court dessous (l'icône seule au doigt) ;
  un clic fait glisser la page jusqu'à la section (`TweenService` sur `CanvasPosition`), la pastille de la section
  visible s'allume, une pastille « ! » signale un achat possible dans la section.
- **Tailles au doigt** (`ShopKit.TOUCH`) : fenêtre 860 x 540 (moins réduite), textes et cibles x1,3, 2 colonnes au
  lieu de 3, boutons de prix de 76 px virtuels (≈ 44 pt sur un téléphone de 390 pt de haut).
- **Taille minimale des textes** : `UITextSizeConstraint` compte en **vrais pixels de l'écran** (après la mise à
  l'échelle ; constaté dans Studio le 26 oct.). Le minimum sert de plancher de lisibilité (11 px sur PC, 12 au doigt),
  pas plus : un minimum plus haut fait déborder les textes sur une petite fenêtre. Pour qu'un mot tienne, on lui donne
  de la place (pastilles : mot sous l'icône, largeur selon la longueur du mot ; phrases : deux lignes).
- **Largeurs en pourcentage dans la page** : les cartes remplissent leurs colonnes (`UIGridLayout`, `CellSize` en
  `Scale`), les hauteurs restent en pixels virtuels ; les icônes gardent leur forme (`ScaleType.Fit`, taille carrée).
- **Croix de fermeture** : grosse croix rouge qui chevauche le coin haut droit de chaque fenêtre (64 px, 76 au doigt).
- **Texte qui ne déborde jamais** : chaque libellé a une taille maximale et minimale (`UITextSizeConstraint`), un
  texte long passe à la ligne ou va dans l'encart « ? » de la carte.

---

## 4. Effets (« jus ») — `client/UIJuiceController`

| Moment                    | Effet                                                                     | Réglage            |
|---------------------------|---------------------------------------------------------------------------|--------------------|
| Survol d'un bouton (PC)   | grossit à 1,06 avec un léger rebond (`Back`) + reflet                      | 0,18 s             |
| Appui                     | s'écrase à 0,92                                                            | 0,07 s             |
| Relâché                   | revient avec un rebond + petit « pop »                                     | 0,35 s, `Back`     |
| Ouverture d'une fenêtre   | monte du bas avec rebond, flou du décor 0 -> 14 (`MenuKit`, déjà là), la caméra zoome un peu (FOV -6°) | 0,32 s / 0,35 s |
| Achat réussi              | la carte saute, pièces et étoiles jaillissent du bouton, la jauge se remplit, l'argent défile jusqu'au nouveau montant ; son « caisse » (déjà joué par `SoundController`) | 0,45 à 0,9 s |
| Pas assez d'argent        | secousse de la carte, éclair rouge, son grave, bandeau « IL TE MANQUE ... »| 0,25 s / 0,45 s    |

Au doigt, pas d'effet de survol (il resterait coincé après un appui). Un objet qu'on secoue ou fait sauter a son propre
support : la grille place le support, l'effet bouge la carte dedans.

---

## 5. Boutique en une page — ce qui est branché

- Améliorations : `Config.Shop` (prix `Config.GetUpgradePrice`), achat par `Remotes.BuyUpgrade` (le serveur vérifie le
  prix, rien n'a changé côté serveur). Confirmation : l'attribut `Upgrade_<Id>` qui monte.
- Robux : `Config.Monetization`, achats par `MarketplaceService` (prix lus sur Roblox), traités par
  `server/MonetizationController` comme avant ; tirages Robux et chances cachés là où `PolicyService` les interdit.
- Les chances exactes restent affichées (règle Roblox) dans la dernière section, et chaque carte de tirage a un bouton
  « CHANCES » qui y mène.
- Pas de « packs d'argent » contre des Robux : le jeu n'en a pas. En ajouter demande de créer les produits sur Roblox
  et de mesurer l'effet sur l'économie (`dataset_and_pipeline/ECONOMY_REPORT.md`) : décision de Chouaib.

## 5 bis. Menu Mondes (refait le 26 oct. avec ces règles)

`client/WorldMenu` : une page qui défile de haut en bas, sans pastilles (2 sections seulement : les pastilles servent
aux pages de 4 sections ou plus).
- **Prochain monde** : grande carte aux couleurs du monde à débloquer (paysage, « MONDE 2 », revenu, tirages, nombre
  de familiers exclusifs), jauge argent / prix, « IL TE MANQUE ... » ou « TU PEUX Y ALLER ! », gros bouton de prix.
  Cachée quand tous les mondes sont débloqués.
- **Les 7 mondes** : une large carte par monde (paysage + numéro, revenu, tirages, ses familiers exclusifs en aperçu 3D,
  en silhouette tant qu'ils ne sont pas découverts, « 2 / 5 »), ruban « TU ES ICI », bouton ACTUEL / Y ALLER / prix /
  VERROUILLÉ ; les mondes pas encore accessibles sont voilés avec un cadenas.
- Mêmes effets que la Boutique (`UIJuiceController`) : boutons qui grossissent et s'écrasent, secousse + éclair rouge et
  « IL TE MANQUE ... » / « DÉBLOQUE D'ABORD ... ». L'argent de l'en-tête vient de `ShopKit.moneyChip` (partagé).
- Les aperçus 3D sont créés à la première ouverture, un par image (pas d'à-coup), et refaits quand un familier est
  découvert.
- Au doigt, les sous-titres des bandeaux sont cachés (ils chevauchaient le titre).

## 6. Vérifié dans Studio (26 oct., en solo, sans rien acheter)

- PC (fenêtre de Studio de 1303 x 410, donc très réduite) : la Boutique s'ouvre, 7 pastilles avec leurs mots entiers,
  À la une (CONSEILLÉ : tapis à $500 ; EXCLUSIF : 2X ARGENT R$ 399), 3 colonnes, Passes R$, Chances.
- Pastilles : la page glisse jusqu'à Entraînement, Passes, Chances ; la pastille s'allume.
- Molette : la page défile de haut en bas et la pastille BONUS s'allume toute seule.
- Effets déclenchés à la main (pas d'achat, pour ne pas toucher la sauvegarde) : 14 pièces qui jaillissent puis
  disparaissent, carte qui saute, secousse + éclair rouge qui reviennent en place.
- Aperçu téléphone (`DebugPhone` 844 x 390, retiré ensuite) : pastilles en grosses icônes, 2 colonnes, gros boutons,
  croix visible, rien sous le joystick ni le bouton de saut.
- Croix rouge qui chevauche le coin : vue sur Boutique et Mondes.

- Mondes (PC et aperçu téléphone) : Prochain monde (Désert, jauge pleine, « TU PEUX Y ALLER ! », $200K), les 7 cartes
  (TU ES ICI sur la Prairie, Glace / Abysses voilées avec cadenas, VERROUILLÉ + prix), les 6 cases du Volcan tiennent,
  molette ; 31 aperçus 3D créés. Pendant ce test Studio ne dessinait plus la 3D (décor noir, Index vide aussi) : les
  familiers dans les cases n'ont pas pu être photographiés.
- Nouvelle croix vue aussi sur l'Index.

À voir encore : un vrai achat (amélioration et Robux), un vrai voyage, les familiers dans les cases du menu Mondes, le
zoom de caméra à l'ouverture, un vrai téléphone, la croix sur Fusion, Duel, Échange, Capsule. Dans l'aperçu téléphone de Studio, `NextGoals`,
`Magnet` et `Newcomer` attendent `HUD.Root` qui est alors rangé dans `PhonePreview` (avertissement « Infinite yield »,
déjà là avant, sans effet dans le vrai jeu).

---

## 7. Pour les enfants qui lisent mal (26 oct.)

Une grande partie des joueurs Roblox a moins de 10 ans : beaucoup lisent lentement, ou pas encore. Un enfant qui ne
comprend pas ce qu'il doit faire quitte le jeu. Règle de base : **on doit pouvoir jouer sans lire** ; le texte confirme
ce que l'image montre déjà.

### 7.1 Règles

1. **L'image d'abord** : chaque étape, bouton et carte a une image (icône dessinée, œuf en 3D, ★, flèche).
2. **Phrases très courtes** : 6 mots au plus par ligne, une seule idée, en **MAJUSCULES d'imprimerie** (ce sont les
   premières lettres qu'on apprend à l'école maternelle).
3. **Mots de tous les jours** (tableau ci-dessous). Pas de mot technique dans ce qui s'affiche en jouant.
4. **Montrer où aller** : flèche et rayon doré du tutoriel, ruban « TU ES ICI », bouton qui saute quand il faut cliquer.
5. **Une touche = une chose** : [E] devant un objet ouvre toujours « la chose qui est là » (la capsule ouvre son menu,
   qui montre tout ; plus de choix caché entre « mettre » et « ouvrir »).
6. **Les chiffres et les couleurs parlent** : chrono « 1:23 », barres qui se remplissent, ★★★, vert = oui, rouge = non,
   gris = pas encore.
7. **Réagir sans texte** : son, carte qui tremble et éclair rouge quand c'est impossible, pièces qui jaillissent quand
   ça marche (`UIJuiceController`).
8. **Les explications restent là pour ceux qui lisent** (parents, grands frères) : bouton « ? » des cartes.

### 7.2 Mots remplacés

| Avant                          | Maintenant                               | Où                                   |
|--------------------------------|------------------------------------------|--------------------------------------|
| Digestion / LE TROU NOIR DIGÈRE| Sieste / LE TROU NOIR FAIT LA SIESTE     | horloge et bandeau du HUD, trou noir |
| Tirage(s)                      | Œuf(s) (chaque tirage donne un œuf)      | HUD, carte de fin de manche, objectifs |
| Incubation : 1:23              | PRÊT DANS 1:23 / ÉCLOT DANS 1:23         | capsule, menu de la capsule          |
| Tentative d'évolution          | ESSAI ★★                                 | capsule, objectifs, absence          |
| Faire éclore                   | OUVRIR                                   | capsule                              |
| Garanti                        | SÛR                                      | objectifs, carte de fin de manche    |
| Bridé : obtiens un…            | EST BLOQUÉ : TROUVE UN…                  | objectifs                            |
| Évolution maximale / stade     | AU MAXIMUM ! / IL RESTE ★★               | capsule                              |
| Pendant ton absence            | PENDANT QUE TU N'ÉTAIS PAS LÀ            | résumé au retour                     |
| Effondrement                   | IL VA EXPLOSER                           | trou noir                            |
| Chambres                       | CASES                                    | capsule                              |
| Réclamer                       | PRENDRE                                  | Index, Bonus                         |
| Équipé / Déséquiper            | IL TE SUIT / ENLEVER                     | Index, Fusion, Marché                |
| Quêtes                         | DÉFIS (et leurs textes : « JETTE 60 OBJETS DANS LE TROU NOIR ») | Bonus, `Config.Quests` |
| Même rareté                    | MÊME COULEUR (chaque rareté a sa couleur) | Fusion                              |
| Revenu (à vie)                 | ARGENT (POUR TOUJOURS)                   | Rebirth, groupe                      |
| Tirage instantané / 10 tirages | 1 ŒUF / 10 ŒUFS                          | produits Robux (`Config.Monetization`) |
| Indisponible / Prix conseillé  | DÉJÀ PRIS / BON PRIX                     | Marché                               |
| Anti-vol / Protection terminée | PROTÉGÉ / PROTECTION FINIE               | bouclier du nouveau venu             |
| PV / ATT / Critique            | VIE / COUP / GROS COUP                   | Duel                                 |
| Confirmer / Revenu             | VALIDER / ARGENT                         | Échange                              |
| Palier / Effondrement / Jauge  | NIVEAU / IL EXPLOSE / BARRE              | trou noir (`Config.Blackhole.Tiers`) |
| Prime / Défense                | BONUS / VOLEUR ARRÊTÉ                    | couronne                             |

Mots gardés : « Rebirth », « Index », les noms de raretés et de mondes (ce sont des noms, avec leur couleur et leur
icône ; les enfants de Roblox les connaissent).

### 7.3 Fait le 26 oct.

- **Menu de la capsule** (`client/CapsuleMenu`, [E] devant la capsule) : 3 images « METS UN ŒUF » » « ATTENDS » »
  « IL DEVIENT PLUS FORT ! » ; les cases de la capsule (œuf en 3D, ★, « PRÊT DANS », barre, « ESSAI ★★ DANS »,
  chance, gros bouton OUVRIR) ; les œufs de la couveuse avec un gros bouton METTRE ; « ? » pour l'explication complète.
  Serveur : chaque case est publiée (`ChamberList` sur la capsule) et OUVRIR ouvre l'œuf de CETTE case
  (`SessionData.HatchEvolving(..., eggId)`).
- **Tutoriel** : une grosse image par étape (objet, trou noir, œuf, patte) avec « 1/4 », titres et consignes courts.
- **HUD** : « Sieste » au lieu de « Digestion », consignes de phase en 3 morceaux courts, « 0 ŒUF » au lieu de
  « 0 TIRAGE ».

### 7.4 À faire ensuite (même méthode)

- Messages de vol (« VOL EN COURS… », « LÂCHÉ !… ») et des armes ; panneaux dans le monde (stations, kiosques).
- Montrer le chemin plus souvent : une flèche vers la capsule la première fois qu'on a 2 œufs, vers la Boutique quand on
  peut acheter le premier tapis.
- Onglets des menus (`MenuKit.sideTabs`) : sur une toute petite fenêtre, « Acheter » se coupe en « Achete / r ».
- Tester avec un vrai enfant de 6-8 ans : noter où il s'arrête, sans l'aider.

### 7.5 Deuxième passe (26 oct.)

Index, Fusion, Rebirth, Bonus (cadeau du jour, défis, codes), Marché (et ses messages serveur), carte de fin de manche,
bouclier du nouveau venu, défis du jour et noms des produits Robux réécrits avec les règles du §7.1. Corrigé en même
temps, vu sur les photos de Studio :
- Rebirth : la ligne des cases de la capsule sortait de sa carte (mise en page resserrée) ; « mutations » retiré de « TU
  GARDES » (elles sont secrètes).
- Bonus : « 3 ŒUFS » ne tenait pas dans les petites cartes : image d'œuf + « x3 » ; le jour 7 montre l'argent ET les
  10 œufs.
- Index : le résumé de collection en 4 lignes très courtes (« TROUVÉS », « 106/106 », « ★★★ 1/212 », « SUIVENT 1/3 »).
- Marché : la phrase sous le prix raccourcie et agrandie.
- « PAS ASSEZ D'ARGENT » devient « IL TE MANQUE $X ! » (Fusion, Marché), comme dans la Boutique.

### 7.6 Troisième passe (26 oct.)

Duel, Échange, trou noir (panneau, bandeaux, indices des 7 niveaux dans `Config.Blackhole.Tiers`) et couronne (étiquettes
et messages) réécrits. Corrigé en même temps, vu sur les photos de Studio :
- Duel et Échange : les noms des familiers ne montraient que leur premier mot (« LA », « LE ») ; ils passent sur deux
  lignes et rétrécissent. « VIE / COUP » tient sur une ligne.
- Duel : la règle en bas ne garde que l'essentiel, « ATTENTION : LE GAGNANT PEUT GAGNER TON FAMILIER ! » (la règle
  « presque aussi rare » est dite par un message quand on choisit un familier trop fort ou trop faible).
- Échange : « TOI / LUI » sur deux lignes ; titre « TES FAMILIERS À DONNER ».
Vu en ouvrant les fenêtres par un message envoyé à soi-même (affichage seulement) ; pas vu : un vrai duel, un vrai
échange, la couronne (il faut 2 joueurs).
