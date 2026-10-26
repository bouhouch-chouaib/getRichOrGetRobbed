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

À voir encore : un vrai achat (amélioration et Robux), le zoom de caméra à l'ouverture, un vrai téléphone, les autres
fenêtres avec la nouvelle croix (Index, Fusion, Duel, Échange, Capsule). Dans l'aperçu téléphone de Studio, `NextGoals`,
`Magnet` et `Newcomer` attendent `HUD.Root` qui est alors rangé dans `PhonePreview` (avertissement « Infinite yield »,
déjà là avant, sans effet dans le vrai jeu).
