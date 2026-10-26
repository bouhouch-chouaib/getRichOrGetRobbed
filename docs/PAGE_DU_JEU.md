# Page du jeu (PLAN étape 14)

> Préparé le 11 octobre 2026, mis à jour le 26 octobre (nouveau nom, description, maturité, vidéo) pour la sortie.
> Tout se remplit sur **create.roblox.com → Créations → le jeu**.
> Prompts de la nouvelle miniature et de la nouvelle icône : `assets/store/PROMPTS.md` (images faites par une IA d'images,
> puis mises aux formats Roblox par Claude). Les anciennes captures de Studio restent dans `assets/store/`.

## 1. Réglages obligatoires avant d'ouvrir le jeu

| Où | Réglage | Pourquoi |
|---|---|---|
| Studio → Paramètres du jeu → **Places** (ou Creator Hub → Places → Accès) | **Taille du serveur : 8** | Il n'y a que 8 bases. Un 9e joueur est renvoyé avec le message « serveur plein ». |
| Creator Hub → **Accès** | Appareils : Ordinateur, Téléphone, Tablette, Console | Le jeu marche à la souris, au tactile et à la manette (R2). Pas de VR. |
| Creator Hub → **Localisation** | Langue source : **Français** ; activer la **traduction automatique** et la capture automatique du texte | Les joueurs anglais, espagnols… verront le jeu traduit. |
| Creator Hub → **Questionnaire de maturité** | voir la section 4 | Obligatoire pour être recommandé aux joueurs. |

## 2. Nom (choisi par Chouaib le 26 oct.)

- **Nom principal (anglais)** : `Steal Pets & Feed the Black Hole 🕳️`
- **Traduction française** (Localisation → Informations du jeu) : `Vole des Familiers & Nourris le Trou Noir 🕳️`

Pourquoi : les deux verbes disent quoi faire, et « Steal » vient en premier parce que le vol donne envie de cliquer.
« Feed the Black Hole » tout seul était trop proche de « A Game About Feeding a Black Hole » (un jeu Roblox et un jeu
Steam). Ne jamais reprendre le nom d'un autre jeu (« Steal a Brainrot », « Steal a Pet »…).

## 3. Description (moins de 1 000 caractères)

Ne jamais parler des mutations (Doré, Diamant, Arc-en-ciel) : elles doivent rester une surprise.

### English (main)

```
🕳️ A giant black hole is hungry... and it pays you in PETS!

🎯 Throw stuff into the black hole and win EGGS!
🥚 Hatch 106 brick pets, from Common to SIGMA!
💰 Your pets make money every second. Get RICH!
🏃 Sneak into other bases, grab a pet and RUN home!
🏏 Stop thieves with your bat and your grappling hook!
🔒 Lock your base and take back your stolen pets.
🌋 Travel through 7 worlds, from the Meadow to the Divine realm!
✨ Evolve, fuse and trade pets... then Rebirth to get even richer!

Steal pets, feed the black hole... or get robbed! 😈
👍 Like and ⭐ Favorite for new pets and updates!
```

### Français (traduction)

```
🕳️ Un trou noir géant a faim... et il te paie en FAMILIERS !

🎯 Lance des objets dans le trou noir et gagne des ŒUFS !
🥚 Fais éclore 106 familiers en briques, du Commun au SIGMA !
💰 Tes familiers rapportent de l'argent chaque seconde. Deviens RICHE !
🏃 Entre dans les bases des autres, prends un familier et COURS chez toi !
🏏 Arrête les voleurs avec ta batte et ton grappin !
🔒 Verrouille ta base et reprends tes familiers volés.
🌋 Voyage dans 7 mondes, de la Prairie jusqu'au monde Divin !
✨ Fais évoluer, fusionne et échange tes familiers... puis Rebirth pour devenir encore plus riche !

Vole des familiers, nourris le trou noir... ou fais-toi voler ! 😈
👍 Like et ⭐ Favori pour les nouveaux familiers et les mises à jour !
```

## 4. Questionnaire de maturité (réponses conseillées, revues le 26 oct.)

Règles officielles : https://create.roblox.com/docs/production/promotion/content-maturity
Répondre selon ce que le jeu contient vraiment : une fausse réponse peut faire sanctionner le jeu.

| Question | Réponse | Détail |
|---|---|---|
| **Violence** | **Oui** | Batte (le coup fait tomber le joueur), grappin qui attrape et tire un joueur, duels de familiers. |
| ↳ Intensité | **Légère (Mild)** | Pas de sang, personne ne meurt : le joueur tombe, se relève, lâche le familier qu'il portait. Violence « irréaliste ». |
| ↳ Fréquence | **Répétée (Repeated)** | Les coups arrivent souvent pendant les vols (c'est le cœur du jeu). |
| Sang | Non | |
| Humour grossier | Non | |
| Peur / horreur | Non | |
| Romance | Non | |
| Langage grossier | Non | Seulement le chat Roblox, déjà filtré. |
| Alcool, drogues, tabac | Non | |
| Jeux d'argent réels | Non | |
| **Objets aléatoires payants** | **Oui** | Œufs achetés en Robux (« 1 ŒUF », « 10 ŒUFS »). Les chances sont affichées avant l'achat. |
| ↳ Respecte `ArePaidRandomItemsRestricted` ? | **Oui** | `client/RobuxShop` cache ces achats quand `PolicyService` les interdit. |

Résultat attendu : **Mild** (violence légère répétée). Avec l'ancienne réponse « pas de violence », le jeu aurait été
classé Minimal à tort : la batte et le grappin sont arrivés le 14 oct., après la première version de ce tableau.

## 5. Images et vidéo

### Images (jusqu'à 10 images et vidéos en tout)

| Fichier | Où | Taille |
|---|---|---|
| icône (à faire avec `assets/store/PROMPTS.md`) | Icône | 512 × 512 |
| miniature (à faire avec `assets/store/PROMPTS.md`) | 1re vignette | 1920 × 1080, **moins de 3 Mo** |
| `thumb1_en.png`… `thumb3_fr.png` (captures du 11 oct.) | vignettes suivantes, si on les garde | 1920 × 1080 |

Les anciennes captures montrent l'ancien trou noir rose et les anciens familiers : mieux vaut les remplacer par de
nouvelles captures en jeu. Roblox teste les vignettes entre elles (« personnalisation ») : garder 2 à 5 vignettes
actives, chacune de moins de 3 Mo.

### Vidéo de jeu (Creator Hub → le jeu → Configurations → Places → la place → **Videos**)

Règles officielles (https://create.roblox.com/docs/production/promotion/thumbnails) :
- gratuit, **3 envois par mois**, et une vidéo refusée compte quand même : n'envoyer que la version finie ;
- seulement du **vrai jeu** : angles de caméra variés, petites retouches, logo, meilleurs moments mis bout à bout,
  textes de l'interface du jeu, musique du catalogue Roblox ;
- **interdit** : faux gameplay, images inventées (pas d'images d'IA dans la vidéo), voix, musique avec paroles,
  phrases de pub (« meilleur jeu », « gratuit ! »…) ;
- une fois acceptée, elle passe **en premier** sur la page du jeu (pas sur Xbox, PlayStation ni casque VR) ;
- formats (page d'envoi, 26 oct.) : `.mp4` ou `.mov`, **60 s au plus**, 100 Mo au plus, 16:9, de 640 × 360 à
  1920 × 1080, débit conseillé 15 Mbit/s.

**Vidéo faite le 26 oct. (version solo)** : `assets/store/video/video_page_jeu.mp4` (hors git : trop lourd).
46 s, 1920 × 1080, 30 i/s, H.264, 72 Mo, 12,5 Mbit/s, son AAC 192 kbit/s à -14 LUFS. **Musique de fond** (demande
de Chouaib : « une vibe Pokémon ») composée et jouée par le code, `tools/video/make_music.py` : mélodies originales,
aucun son externe, sans paroles ni voix (la génération de musique ForgeGUI est réservée aux offres payantes).
2 versions : **A** 8 bits (ondes carrées, do majeur, 136 BPM) et **B** moderne (cuivres, pizzicati, cordes, ré majeur,
130 BPM) ; les deux tombent sur l'accord final quand le titre apparaît. **Chouaib a choisi B** (26 oct.) :
`video_page_jeu.mp4` = version B (se refait par `bash tools/video/edit.sh B`). Vidéos de comparaison :
`video_page_jeu_musiqueA.mp4`, `video_page_jeu_musiqueB.mp4` ; `video_page_jeu_muette.mp4` sans musique. Filmée dans Studio
(Play solo, sauvegarde de test remise comme avant à la fin), caméra de cinéma par script, interface du jeu laissée
dans les plans de jeu, barre Roblox et chat cachés.

| Temps | Plan | Légende (anglais) |
|---|---|---|
| 0-4 s | Le trou noir au palier 7 (Divin), de nuit, en Prairie | — |
| 4-8 s | Le joueur ramasse un objet, le tient au-dessus de la tête, vise et le lance dans le trou | THROW STUFF IN THE BLACK HOLE |
| 8-17 s | Un œuf Divin tremble dans la couveuse (compte à rebours), « ÉCLOSION DIVIN ! », carte « QUELLE CHANCE ! » puis Dragon Aurore | HATCH RARE PETS |
| 17-22 s | La base vue du ciel, le dragon et les familiers qui se baladent | — |
| 22-26 s | Le joueur part en courant avec le dragon au-dessus de la tête | GRAB PETS AND RUN |
| 26-38 s | 4 mondes : Volcan, Glace, Cosmos, Divin, chacun avec ses familiers | 7 WORLDS TO UNLOCK |
| 38-42 s | Le trou noir du Volcan, « IL VA EXPLOSER ! » puis « IL A EXPLOSÉ ! » | — |
| 42-46 s | Le nom du jeu (STEAL PETS & FEED THE BLACK HOLE) sur le trou noir flouté | logo |

Pas dedans : un vrai vol entre 2 joueurs (impossible en solo dans Studio). Légendes courtes qui décrivent le jeu
(permis), aucune phrase de pub. Les plans ont été tournés avec des réglages de test (palier du trou noir forcé,
mondes et familiers donnés pour la prise) : tout ce qu'on voit existe dans le jeu, rien n'est dessiné en plus.

**Envoyer** (à faire par Chouaib) : Creator Hub → le jeu → Configurations → Places → la place → Videos → importer
`video_page_jeu.mp4`. Regarder la vidéo en entier avant : un envoi refusé compte dans les 3 du mois.

**Refaire ou modifier le montage** : les plans filmés sont dans `assets/store/video/rushes/`. Changer la liste des
plans en bas de `tools/video/edit.sh` (fichier, début, durée, légende), puis lancer `bash tools/video/edit.sh B` (la
musique choisie ; `A` pour l'autre, rien pour une vidéo muette ; ffmpeg, Python avec Pillow, numpy et scipy ; police LuckiestGuy prise
dans l'installation de Roblox). Légendes et titre : `tools/video/make_titles.py`. Si on change la durée de la vidéo,
caler la musique (tempo et nombre de mesures avant l'accord final) dans `make_music.py`.

**Filmer de nouveaux plans** (Claude, avec Studio ouvert) : `bash tools/video/rec.sh NOM SECONDES` filme la vue du jeu
même si Studio est derrière une autre fenêtre (pas réduit). Avant : en Play, fenêtre de Studio redimensionnée en
1450 × 1102 et panneaux Explorateur et Sortie fermés, pour que la vue du jeu soit exactement en 16:9 (1392 × 783) ;
à la fin, Fenêtre → Explorateur / Sortie pour les rouvrir. Méthode détaillée (caméra, ramasser, porter, sauvegarde) :
mémoire Claude « Filmer le jeu dans Studio ».

## 6. Ordre conseillé

1. Taille du serveur à 8, appareils, langue source.
2. Nom, description (anglais), puis les traductions françaises.
3. Icône et vignettes, puis la vidéo (prête depuis le 26 oct. : `assets/store/video/video_page_jeu.mp4`).
4. Questionnaire de maturité.
5. Avant de passer le jeu en **public** : une partie test dans le jeu publié avec 2 comptes et un téléphone (vol, batte,
   grappin, échange : jamais testés à 2 vrais joueurs). On peut filmer la vidéo pendant ce test.
6. Remise à zéro des testeurs (fait dans le code le 26 oct. : sauvegardes v4) : **Studio → Fichier → Publier sur Roblox**,
   sinon le jeu en ligne garde l'ancienne version et les anciennes sauvegardes.
7. Passer le jeu en public, puis seulement après, les publicités (section 7).

## 7. Publicités (Ads Manager, après le passage en public)

Règles relues le 26 oct. (https://create.roblox.com/docs/production/promotion/ads-manager) :
- il faut avoir 13 ans ou plus et un e-mail vérifié sur le compte ; paiement par carte (18 ans et plus) ou en
  **crédits pub achetés en Robux** (à partir de 1 crédit ; les Robux convertis ne reviennent jamais en Robux) ;
- les publicités envoient des joueurs dans le jeu : il doit être **public**, avec sa miniature, son icône et ses
  vignettes en place (une campagne accepte jusqu'à 10 vignettes 16:9) ; modération de la campagne en 24 h environ ;
- un jeu qui ressemble trop à un autre (nom, page, place) est moins montré : ne jamais copier un autre jeu ;
- un jeu interdit aux moins de 17 ans ne touche pas les 13-17 ans (pas notre cas : Mild).

Première campagne conseillée pour un jeu neuf : objectif **Plays** (parties), public **New Players** (les publics
« Recent » et « Lapsed » demandent 10 000 et 20 000 joueurs), petit budget par jour sur 3 à 5 jours, puis regarder dans
le Creator Hub combien de joueurs reviennent le lendemain et à quel moment ils partent (tutoriel, premier œuf) avant
de mettre plus. Les publicités ne changent pas la place du jeu dans « Recommandé pour toi » : c'est la rétention qui
compte.
