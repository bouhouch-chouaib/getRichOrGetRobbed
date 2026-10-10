# CLAUDE.md — Get Rich Or Get Robbed (Roblox / Rojo)

Contexte de passation pour toute nouvelle session Claude. Lire aussi `GDD.md` (design + architecture à jour).
**Lire aussi `docs/ROADMAP.md`** : écarts avec les jeux de référence, feuille de route priorisée (P0/P1/P2),
spec du vol de familiers (prochaine feature) et notes techniques de passation (§7).

## L'utilisateur et la façon de travailler

- Parle français, débutant en dev Roblox ; veut avancer **étape par étape, fonctionnalité par fonctionnalité**,
  le plus vite possible, avec des explications simples (pas de jargon inutile).
- **Pousse directement sur `main`** (il l'a demandé explicitement). Pas de branches/PR.
- Il teste dans **Roblox Studio** ; Claude ne peut pas lancer Studio. Toujours dire clairement ce qui est vérifié
  (analyse statique + build) et ce qui ne l'est pas (rendu / gameplay en Studio).
- Inspiration revendiquée : **Steal a Brainrot / Steal an Egg** (style visuel cartoon, base à verrouiller, etc.).
  Reprendre le *style*, jamais copier assets/marques/noms/sons. Les 15 anciens « brainrots » repris de Steal a Brainrot
  ont été remplacés le 8 oct. 2026 par des « Absurdes cosmiques » originaux (`PetCatalog.Renamed` convertit les
  anciennes sauvegardes) : ne jamais réintroduire de personnage, mème ou son d'un autre jeu.

## Où est le code

- GitHub : `bouhouch-chouaib/getRichOrGetRobbed`, branche `main`.
- **Dossier de travail de l'utilisateur** (c'est de là qu'il lance `rojo serve`) :
  `C:\Users\bouho\OneDrive - Conseil régional Grand Est - Numérique Educatif\Documents\GetRichOrGetRobbed`
  → les fichiers modifiés là sont synchronisés en direct dans Studio (il fait juste Stop puis Play).
- Copie de travail sans accents (pratique pour les outils) : `C:\Users\bouho\dev\getRichOrGetRobbed`.
  Workflow utilisé jusqu'ici : modifier dans `dev\`, analyser, commit, push, puis aligner le dossier OneDrive
  (`git fetch && git checkout -- . && git merge --ff-only origin/main`). Si le push traîne (ça arrive : fenêtre
  d'identification GitHub en arrière-plan), copier les fichiers dans OneDrive pour qu'il teste sans attendre.
- `C:\Users\bouho` est lui-même un dépôt git vide pointant sur le même remote (accident) : **ne pas y travailler**.
- Fichier de place local ignoré par git : `FeedTheBlackhole.rbxlx`.
- Attention : aider/DeepSeek ont déjà réécrit des fichiers dans son dossier OneDrive (vieux code incompatible,
  ex. `BlackholeController.lua` le 03/10). Si Studio montre des erreurs "anciennes", vérifier `git status` là-bas.

## Vérifier le code (Claude ne peut pas jouer)

```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
rojo build -o test.rbxlx
```
- Rojo 7.7.0 via aftman (`~/.aftman/bin`). `luau-lsp` n'est pas installé : télécharger
  `luau-lsp-win64.zip` (releases JohnnyMorganz/luau-lsp) + `scripts/globalTypes.d.luau` dans un dossier temporaire.
  luau-lsp **échoue sur le chemin OneDrive (accents)** → analyser depuis `C:\Users\bouho\dev\getRichOrGetRobbed`.
- Tout le code est en `--!strict` et passe l'analyse sans erreur : garder ce niveau.
- Écrire les fichiers en UTF-8 / LF. Attention aux `\n` dans les heredocs bash+python (ont déjà cassé une chaîne Luau).

## Règles techniques à ne pas casser (détails dans GDD.md)

- Ramassage **autoritaire serveur** (`ItemInteraction`) : Owner/Holder + `SetNetworkOwner(player)` puis
  `Remotes.ItemGrabbed` ; le client soude l'item (WeldConstraint local) et lance (`ApplyImpulse`).
- Détection trou noir / dôme **par distance chaque Heartbeat**, jamais `.Touched`.
- Knockback : serveur `Sit = true` + soulève 1 stud, **le client** applique l'impulsion (`Remotes.Knockback`).
- RemoteEvents : déclarés dans `default.project.json` **et** créés par le serveur s'ils manquent (`Remotes.lua`) —
  `rojo serve` ne recharge pas les nouveaux remotes du project.json en cours de session.
- État des joueurs : `SessionData` → attributs Player (lus par le HUD) + leaderstats, **sauvegardé en DataStore**
  (`PlayerData_v2`, `PlayerData_v2_studio` dans Studio ; version dans `Config.Save`). Ne jamais sauvegarder si le chargement a échoué (`data.loaded`). Dans Studio il faut que le jeu
  soit publié et que "Enable Studio Access to API Services" soit coché (Game Settings > Security).
- **Verrou de session (anti-duplication)** : toute lecture/écriture de la sauvegarde passe par `UpdateAsync` et le champ
  `session` (jamais `SetAsync`/`GetAsync`) ; un serveur n'écrit que s'il tient le verrou, le libère au départ du joueur.
  Toute future feature qui transfère des familiers (vol, échanges) doit s'appuyer dessus. Détails : GDD.md.
- Toute valeur d'équilibrage va dans `src/shared/Config.lua`.

## État actuel (fait)

Boucle Feeding 45 s (nuit éclaircie) / Digesting 60 s (jour) • map prairie (herbe, chemins de terre, clôtures bois, arbres) •
8 bases, bouton de verrouillage 60 s (expulsion des intrus) • argent + boutique à niveaux (Treadmill, Bench,
ItemQuality, Backpack, LongLock) • entraînement Vitesse/Force par niveaux (XP ×1,12/niveau) sur stations hors base •
objets à valeur (6 types, kit de départ 5 objets, 1 objet/2 s en Feeding) • sac à dos (plusieurs objets portés) •
HUD style cartoon (LuckiestGuy, contours noirs, fenêtres, Toast, barres d'XP) • 75 familiers / 8 raretés
(`PetCatalog`), modèles de remplacement procéduraux (`PetModelBuilder`, surchargeables par
`ReplicatedStorage.PetModels.<Id>`) • tirages à coût croissant + pitié (`LootEngine`) • 1 familier équipé =
multiplicateur additif + suit le joueur (`PetFollow`) • revenu = 10 meilleurs familiers • fenêtre collection 3D •
annonces serveur Légendaire+ • familiers qui se baladent dans la base, **trajets décidés par le serveur** (`BasePetsController` + `shared/PetWander` +
`client/BasePets`, plus de socles ; un familier équipé ne rapporte pas et n'est pas dans la base) • verrou de session anti-duplication •
palettes à objets + objets sauvages dans l'arène + amélioration Chance • plaque d'apparition invisible •
verrouillage 5 s relancé à chaque passage • consigne de phase en bas de l'écran •
**mobile** : `client/ScreenScale` (UI à l'échelle), bouton LANCER tactile, gâchette R2 manette •
économie rééquilibrée (revenus bas, prix hauts) • objets non roulants (frottement max) • map agrandie (bases à 215) •
`Config.StudioGiveAllPets` (false par défaut ; true donne les 75 en Studio pour tester) • sauvegarde DataStore •
machine de fusion + boutique physiques dans 4 kiosques entre les bases • économie en grands nombres (K/M/B/T, `NumberFormat`) •
bulles [E] des objets recalées au-dessus de l'objet côté client (`ItemPromptAnchors`) •
**vol de familiers** pendant la digestion + défense « Reprendre » et annonces (`StealController`, `Config.Steal`, voir GDD) • modèles 3D importés à la bonne taille • nouveaux familiers qui tombent du ciel dans la base (`Celebrate`) + carte de résultats discrète • sons et musique (`client/Sounds`, `Config.Sounds`) • effets de satisfaction : points qui s'envolent, ouverture animée des tirages rares, secousses (`client/Effects`) • tutoriel en 3 étapes, une seule fois (`client/Tutorial`) • anti-triche des lancers (`Config.AntiCheat`, vérifié quand le trou avale l'objet) • vrais modèles 3D des 14 familiers Sigma/Divins (`shared/PetMeshes`, générés dans Studio avec l'outil MCP `generate_mesh`) • boutique Robux : 5 passes + 3 produits, achats sûrs, probabilités affichées (`MonetizationController`, `client/RobuxShop`) • nettoyage avant sortie : sauvegardes v2, Studio séparé (`_studio`), options de test vidées • tableau « LES PLUS RICHES » dans l'arène, top 10 tous serveurs (`LeaderboardController`) + « Argent » trié dans la liste des joueurs.

Pousser le code dans Studio sans `rojo serve` : voir la mémoire « Sync Studio sans Rojo » (rbxm + `GetObjects`).
⚠️ Si `rojo serve` tourne (port 34872), Rojo écrase ce qu'on modifie directement dans Studio par la version du dossier
OneDrive : dans ce cas, copier les fichiers dans OneDrive (ou aligner après le push) au lieu de passer par le rbxm.

## Prochaines étapes prévues (dans cet ordre, validé avec l'utilisateur)

1. (fait : socles) Idée : slots de socles supplémentaires achetables, vol de familiers sur les socles adverses.
2. (fait : machine de fusion, `FusionController` + fenêtre FUSION)
3. (fait : sauvegarde DataStore)
4. (fait le 9 oct. : monétisation codée — 5 passes + 3 produits, `MonetizationController`, `client/RobuxShop`, `shared/Perks`).
   Reste : l'utilisateur crée les passes/produits sur create.roblox.com et fournit leurs Id (`Config.Monetization`).
5. Échanges entre joueurs (double confirmation anti-arnaque).

Autres idées notées : vol de familiers dans les bases adverses (colle au nom du jeu), bulle ProximityPrompt
personnalisée au style cartoon, sauvegarde de la vitesse.
