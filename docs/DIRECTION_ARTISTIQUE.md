# Direction artistique — Get Rich Or Get Robbed

Fiche de référence pour toute IA ou personne qui touche au visuel du jeu.
Référence de **style** : *Steal an Egg* (Roblox, place 107778070777162). On reprend le style, **jamais** les
modèles, noms, sons, icônes ou menus à l'identique (voir CLAUDE.md).

Sources étudiées le 12 oct. 2026 (dossier local `references/`, exclu de git, ne jamais publier) :
11 captures en jeu de Chouaib (`references/captures/sae_*.png`), sa vidéo de 83 s (traversée de toutes les zones),
une vidéo YouTube de 34 min (progression complète), planches d'images dans `references/video_*`.

---

## 1. La règle d'or : tout est en briques à tenons

Le point qui fait 80 % de la ressemblance : **chaque surface porte la texture de tenons Roblox** (les « studs » façon
LEGO) : sol, murs, clôtures, machines, panneaux, **et même les fenêtres d'interface**.

- Sol : grand damier de 2 tons d'une même couleur + tenons. Cases d'environ 8 à 12 studs.
- Murs : damier 2 tons + tenons, avec un liseré d'herbe vert vif sur le dessus.
- Familiers et œufs : **voxels** (petits cubes) recouverts de tenons, contours nets, pas de formes lisses.
- Interface : texture de tenons en léger relief dans le fond des fenêtres et des cartes.

Fait le 13 oct. : `MapGenerator` construit tout en Plastic à tenons (`studify`), sols en damier de dalles posées
sur un sol invisible (les tenons ne s'affichent que sur du Plastic et des faces planes, pas sur les cylindres).

## 2. Palette relevée sur les captures (valeurs approchées)

| Rôle | Couleur | Notes |
|---|---|---|
| Herbe, ton 1 / ton 2 | `#98E634` / `#51CC29` | Vert pomme saturé, damier |
| Mur, ton 1 / ton 2 | `#CA9156` / `#B97D49` | Beige orangé, damier |
| Clôture bois | `#C87425` | Orange vif, poteaux gris-brun `#8B716A` |
| Ciel | bleu clair + gros cumulus blancs | Ciel lumineux, jamais gris |
| Fond des fenêtres | `#323141` | Gris-bleu nuit + tenons |
| En-tête vert / violet / cyan | `#A3DC0B` / `#A804FC` / `#36CCFE` | Dégradé + 2 rayures diagonales claires |
| Bouton fermer | rouge vif ~`#E8141A`, X blanc | Carré, contour noir |
| Bouton « Index » | `#07C7FF` | Cyan |
| Bouton « Boutique » | vert vif ~`#5BE51E` | |
| Boutons ronds à droite | `#F7494C` rouge, `#F3A646` orange | Carrés arrondis, icône blanche |
| Bouton prix / acheter | `#60FE03` | Vert fluo, texte blanc contour noir |
| Cartes par rareté | gris → `#1AFA4D` vert → `#016DFD` bleu → `#D50BFA` violet → `#F9DD00` or | Fond en **rayons de soleil** (sunburst) |

Règle : couleurs **pures et saturées**, peu de pastel, pas de marron terne. Le néon est réservé aux effets
(familiers rares, machines, zones de clic au sol), jamais aux murs ou au sol.

## 3. Interface

- **Police** : Montserrat Black, graisse Heavy, droite pour les textes et les chiffres (dernière référence GUI du 16 oct.). Définition commune dans `shared/Typography` ; voir [TYPOGRAPHIE.md](TYPOGRAPHIE.md).
- **Contour noir épais** sur tout le texte (UIStroke 2 à 3 px) et sur tous les boutons.
- **Fenêtres** : fond sombre texturé, en-tête coloré (couleur = fonction : vert vente, violet machines/boutiques,
  cyan collection), bouton X rouge en haut à droite, coins peu arrondis (4 à 6 px), pas d'ombres floues.
- **HUD** : en bas à gauche, icône + gros chiffre italique (vitesse en bleu, argent en vert). À gauche au milieu,
  2 gros boutons rectangulaires (Boutique, Index) avec pastille rouge de notification. À droite, boutons carrés
  colorés. En bas à droite, le minuteur jour/nuit avec une icône lune.
- **Textes dans le monde** : grosses lettres colorées à contour noir (« VENDRE » rouge, « GRATUIT ! » vert,
  nom de machine en bleu + compteur « 0/3 »), étiquettes des familiers en 3 lignes : rareté (couleur de rareté),
  nom (blanc), revenu (vert, « $1.3K/s »).
- **Annonces** : bandeau centré en haut (« RUN!! » rouge, nom de zone à l'entrée de chaque zone, apparition
  d'un œuf rare dans tout le serveur), texte coloré par rareté.

### 3.1 Refonte du 16 oct. 2026 (packs « Studs UI » montrés par Chouaib, analysés image par image)

- **Icônes** : 25 icônes 3D brillantes à contour bleu nuit générées avec ForgeGUI (planches de 8, découpées par
  `tools/icons/split_sheet.py`, fichiers dans `assets/icons/forgegui`), Ids dans `shared/Icons`. Le compte gratuit
  ForgeGUI (10 000 crédits) a permis 4 générations (~2 500 crédits l'une) : le reste des icônes (Moon, Sun, Gem,
  Orb...) garde les anciennes.
- **Textures** (`tools/icons/make_ui_textures.py`, `assets/ui`) : tenon en relief, éclats de lumière, rayons, halo,
  ombre, reflet ; Ids dans `UiStyle.Textures`.
- **Fenêtres** (`UiStyle.window`) : ombre douce, corps gris-bleu à tenons en relief, en-tête coloré avec éclats et
  bande d'ombre, grosse icône penchée qui déborde ; ouverture : monte du bas avec rebond, icône élastique, **décor
  flouté** (`MenuKit`, BlurEffect) ; fermeture rapide qui rétrécit.
- **Boutons** : dégradé 3 tons, reflet en haut, lèvre sombre en bas, reflet qui balaie au survol, penchent et
  grossissent au survol, s'écrasent au clic. Pastilles rouges qui pulsent.
- **HUD** : tuiles carrées à tenons 2 par 2 (Boutique, Index, Mondes, Bonus) + une large Rebirth arc-en-ciel animée ;
  icônes qui se balancent. **Offres Robux** à droite (`client/OffersPanel`, PC seulement) : icône sur rayons qui
  tournent, prix en pastille verte, tournent toutes les 9 s, cachées quand une fenêtre est ouverte.
- **Une seule police partout : Montserrat Black** (titres, textes, chiffres, panneaux et interactions ; remplace FredokaOne et LuckiestGuy selon la dernière référence du 16 oct.). Icône Rebirth = boucle rouge et blanche dessinée par `tools/icons/make_rebirth_icon.py`.
- **Messages** (`client/Toast`) : bandeaux colorés effacés sur les côtés, qui s'empilent (3 max).
- **Cadeau du jour** : cartes avec pastille d'état (REÇU / AUJOURD'HUI / BLOQUÉ), jour 7 arc-en-ciel, rayons derrière
  le cadeau du jour.

## 4. Le monde

- **Structure** : un très long couloir encadré de hauts murs, découpé en **zones à thème** qui s'enchaînent
  (Neige, Volcan, Océan des abysses, Préhistoire, Cosmique, Cerisiers, Temple des titans, Anges,
  Forêt enchantée…). Chaque zone change : couleur du sol, matière des murs, décor (coraux, os géants, torii,
  cascades, cristaux, palmiers, colonnes dorées), et le ciel (étoiles en zone cosmique).
- **Entrée de zone** : grande arche ou portail + nom de la zone affiché en haut de l'écran.
- **Bases** : enclos de clôtures en bois orange sur l'herbe, avec une ligne rouge au sol et le texte géant
  « ZONE SÛRE » peint par terre. Les familiers se baladent librement dedans.
- **Stations** : tapis de course, machine de fusion, stand de vente (auvent rayé rouge et blanc), boutique
  (auvent jaune et blanc), coffre gratuit, tableau des scores. Chaque station a un **cercle lumineux au sol**
  (vert, jaune) qui montre où se placer.
- **Évolution visible** : le tapis change de modèle à chaque niveau (gris → orange et or → noir et or avec
  cristaux bleus lumineux). Le joueur *voit* sa progression.

## 5. Familiers et œufs

- **Taille** : beaucoup sont **plus grands que l'avatar**, les plus rares sont gigantesques (2 à 5 fois l'avatar).
  Les œufs aussi grandissent avec la rareté (« œuf géant »).
- **Style** : voxels + tenons, couleurs franches, yeux simples, grosses formes lisibles de loin.
- **Rareté = effets** : rien pour les communs ; à partir d'Épique, aura (fumée violette, flammes, étincelles,
  ailes lumineuses, halo). Les plus rares sont lisibles à 100 studs.
- **Œuf porté** : tenu au-dessus de la tête, bandeau « RUN!! », bouton « Drop » rouge en bas.

## 6. Effets et lumière

- Lumière de plein jour, forte, ombres légères. Bloom modéré (les néons « bavent » un peu). Saturation
  légèrement poussée. La nuit reste claire (bleu nuit, jamais noir).
- Traînée lumineuse derrière le joueur quand il court (achetable : grise, verte, bleue…).
- Chiffres qui s'envolent (« +30/pas », « +$28K ») en couleur vive à contour noir.
- Éclosion : flash blanc, rayons, nuages de particules, apparition du familier en grand.

## 7. Méthode de travail

1. Une zone à la fois : d'abord **une base**, puis le couloir et ses zones, puis l'interface, puis les effets.
2. Pour chaque zone : capture Studio (outil MCP `screen_capture`) à côté de la capture de référence, corriger
   jusqu'à ce que les deux se ressemblent.
3. Modèles : générer avec `generate_mesh` (comme les 14 familiers Sigma/Divins), ou modèles gratuits de la
   boutique Roblox **sans scripts** (les vérifier et supprimer leurs scripts avant usage).
4. Performance mobile : texture de tenons partagée, pas de particules sur les communs, limiter les pièces.

---

## 8. Plan validé avec Chouaib (13 oct. 2026)

**Le cœur du jeu ne change pas** : voler les autres joueurs et nourrir le trou noir. Le visuel et les paliers
servent ce cœur, ils ne le remplacent pas. **Pas de couloir de zones** (refusé).

- **Structure** : la carte reste **circulaire** autour du trou noir (arène ronde, 8 bases en anneau, 4 kiosques).
- **Mondes par palier (joueur)** : quand un joueur dépasse le niveau max de son palier, il passe au suivant.
  C'est **sa base** qui change de monde (sol, clôtures, décor, lumière, sons) : Prairie → Désert → Volcan →
  Glace → Abysses → Cosmos → Divin (liste à confirmer). Les 8 bases restent côte à côte : on voit les bases
  épiques des autres, elles deviennent des cibles. Ascension (rebirth) : à décider.
- **Trou noir par palier (serveur)** : un seul trou noir, partagé, qui monte de palier avec une jauge
  commune (objets avalés sur le serveur). De plus en plus épique, une mécanique légère par palier, **sans rendre
  le jeu impossible** (effets courts, rares, jamais punitifs) :

  | Palier | Aspect | Mécanique (légère) |
  |---|---|---|
  | 1 Éveil | vortex violet | boucle actuelle |
  | 2 Éruption | bord de lave | quelques roches ×3 recrachées dans l'arène |
  | 3 Cible | anneaux qui tournent | centre de la cible = ×2 points |
  | 4 Abysses | tentacules en cubes | rattrapent les lancers un peu courts ; rarement, font lâcher un objet |
  | 5 Gravité | disque de matière, éclairs | attire doucement les objets au sol ; pluie de météorites |
  | 6 Supernova | pulsations | combo de lancers d'affilée |
  | 7 Divin | or et blanc | jackpot ×5 pendant 10 s, annoncé |
  | Effondrement | implosion | grosse digestion, familier rare aux meilleurs, retour au palier 1 |

- **Qualité visée** : chaque élément améliorable a beaucoup de niveaux (20 à 30) avec un nouveau modèle tous
  les ~5 niveaux, de plus en plus épique, toujours en blocs à tenons ; créatures en voxels détaillés ; effets
  et sons travaillés.
- **Ordre de travail** : 1) passe tenons + palette (fait le 13 oct.) ; 2) une base du palier 1 en qualité (fait le 13 oct.)
  finale (ZONE SÛRE, cercles au sol, tapis et banc à paliers visuels) ; 3) interface (fait le 13 oct. : menus reconstruits) ; 4) mondes des paliers (fait le 15 oct. : couleurs, décors, ambiance ; musiques des paliers 2 à 7 à choisir) ;
  5) familiers en voxels + auras (fait le 15 oct.) ; 6) paliers du trou noir (fait le 13 oct. : jauge commune, 7 aspects, mécaniques, effondrement).
