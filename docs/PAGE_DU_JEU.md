# Page du jeu (PLAN étape 14)

> Préparé le 11 octobre 2026. Tout se remplit sur **create.roblox.com → Créations → le jeu**.
> Images prêtes dans `assets/store/` (icône + 3 vignettes en français et en anglais).

## 1. Réglages obligatoires avant d'ouvrir le jeu

| Où | Réglage | Pourquoi |
|---|---|---|
| Studio → Paramètres du jeu → **Places** (ou Creator Hub → Places → Accès) | **Taille du serveur : 8** (aujourd'hui : 60) | Il n'y a que 8 bases. Un 9e joueur est renvoyé avec le message « serveur plein ». |
| Creator Hub → **Accès** | Appareils : Ordinateur, Téléphone, Tablette, Console | Le jeu marche à la souris, au tactile et à la manette (R2). Pas de VR. |
| Creator Hub → **Localisation** | Langue source : **Français** ; activer la **traduction automatique** et la capture automatique du texte | Les joueurs anglais, espagnols… verront le jeu traduit. |
| Creator Hub → **Questionnaire de maturité** | voir la section 4 | Obligatoire pour être recommandé aux joueurs. |

## 2. Nom

Le nom actuel est « Nourrir le trou noir ». Proposition :
- **Nom principal (anglais)** : `Feed the Black Hole 🕳️`. La plupart des joueurs Roblox cherchent en anglais.
- **Traduction française** (Localisation → Informations du jeu) : `Nourris le Trou Noir 🕳️`.

Autres idées : `Get Rich or Get Robbed`, `Black Hole Pets`, `Steal a Pet from the Black Hole`.
Ne jamais reprendre le nom d'un autre jeu (« Steal a Brainrot », etc.).

## 3. Description

### Français (traduction)

```
🕳️ Un trou noir géant a faim... et il te paie en FAMILIERS !

🎯 Lance des objets dans le trou noir pendant la nuit : plus tu marques de points, plus tu gagnes de tirages.
🐾 Collectionne 75 familiers absurdes et cosmiques, du Commun au DIVIN !
💰 Tes familiers rapportent de l'argent : améliore ta base, ton tapis de course et ton banc de muscu.
🦹 Pendant la digestion, faufile-toi dans les bases des autres et VOLE leurs familiers !
🔒 Verrouille ta base et récupère ce qu'on t'a volé.
🧪 Fusionne 5 familiers pour obtenir une rareté au-dessus.

Deviens le joueur le plus riche du tableau... ou fais-toi voler ! 😈
```

### English (main)

```
🕳️ A giant black hole is hungry... and it pays you in PETS!

🎯 Throw items into the black hole at night: the more points you score, the more pet rolls you win.
🐾 Collect 75 absurd cosmic pets, from Common to DIVINE!
💰 Your pets earn money: upgrade your base, your treadmill and your bench.
🦹 While the hole digests, sneak into other bases and STEAL their pets!
🔒 Lock your base and take back what was stolen.
🧪 Fuse 5 pets to get one of a higher rarity.

Become the richest player on the board... or get robbed! 😈
```

## 4. Questionnaire de maturité (réponses conseillées)

| Question | Réponse | Détail |
|---|---|---|
| Violence | **Non** | Pas d'armes ni de combat. Le dôme du trou noir repousse les joueurs, sans dégâts. |
| Sang | Non | |
| Humour grossier | Non | |
| Peur / horreur | Non | |
| Romance | Non | |
| Langage grossier | Non | Seulement le chat Roblox, déjà filtré. |
| Alcool, drogues, tabac | Non | |
| Jeux d'argent réels | Non | |
| **Objets aléatoires payants** | **Oui** | « Tirage instantané » et « 10 tirages » (Robux). Les chances exactes sont affichées avant l'achat, et ces produits sont cachés là où la loi les interdit (`PolicyService`). |
| Lieu de rencontre / discussion | Non | |

Résultat attendu : **Minimal** (tous âges). Si Roblox pose une question qui n'est pas dans ce tableau, réponds selon ce que le jeu contient vraiment.

## 5. Images (`assets/store/`)

| Fichier | Où | Taille |
|---|---|---|
| `icon.png` | Icône | 512 × 512 |
| `thumb1_en.png`, `thumb2_en.png`, `thumb3_en.png` | Vignettes (langue principale) | 1920 × 1080 |
| `thumb1_fr.png`, `thumb2_fr.png`, `thumb3_fr.png` | Vignettes de la traduction française | 1920 × 1080 |

Les vignettes ont été capturées dans Studio (scènes temporaires, rien n'est resté dans le jeu), puis le texte a été ajouté
avec la police du jeu (Luckiest Guy). La fenêtre 3D de Studio faisait 1629 × 581 : les images sont agrandies et un peu moins
nettes qu'une vraie capture en 1920 × 1080. Pour les refaire plus nettes, il suffit d'agrandir la fenêtre 3D de Studio
(fermer la sortie et les panneaux) et de relancer les captures.

## 6. Ordre conseillé

1. Taille du serveur à 8, appareils, langue source.
2. Nom, description (anglais), puis les traductions françaises.
3. Icône et vignettes.
4. Questionnaire de maturité.
5. Garder le jeu **privé** jusqu'à la fin de l'étape 15 (test réel avec plusieurs comptes et un téléphone).
