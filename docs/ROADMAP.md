# Feed The Blackhole — Contexte, écarts et feuille de route

> **À lire en entier avant toute tâche.** Ce document complète le `CLAUDE.md` et le GDD du dépôt ; il ne les remplace pas.
> En cas de contradiction : (1) les instructions explicites de Chouaib dans la conversation, (2) le code et le `CLAUDE.md` existants, (3) ce document.
> Rédigé le 6 octobre 2026.

---

## 0. Comment travailler sur ce projet

- **Lis le code avant d'écrire.** Avant chaque feature, parcours les modules concernés (gestionnaires de boucle, de base, de familiers, de sauvegarde) et réutilise ce qui existe. Ne recrée jamais un système déjà présent (ex. ramassage/sac à dos, verrouillage de base, DataStore).
- **Planifie d'abord.** Pour toute feature de plus de ~50 lignes : propose un plan court (fichiers touchés, nouveaux RemoteEvents, changements de schéma de sauvegarde, cas limites) et attends la validation.
- **Serveur autoritaire, toujours.** Le client ne fait qu'envoyer des intentions. Toute validation (distance, propriété, état de phase, cooldown, coût) se fait côté serveur.
- **Luau typé strict** (`--!strict`), architecture modulaire existante (Rojo : client / serveur / partagé). Respecte les conventions déjà présentes dans le dépôt.
- **Schéma de sauvegarde** : toute modification doit être rétrocompatible (valeurs par défaut pour les anciens profils, champ de version si nécessaire). Ne jamais écraser une sauvegarde si le chargement a échoué (règle déjà en place, à préserver).
- **Petits incréments testables.** Une feature = une branche, des commits atomiques, un test multijoueur dans Studio (serveur local, 2 joueurs minimum) avant de déclarer « fini ».
- **Définition de « fini »** : la feature marche en multijoueur local, aucune duplication ni perte de données possible dans les cas limites listés, mobile et manette pris en compte si la feature a une interface.
- Les valeurs chiffrées proposées dans ce document (vitesses, durées, prix) sont **des points de départ à équilibrer**, pas des décisions définitives. Les points marqués **[À DÉCIDER]** demandent l'avis de Chouaib avant d'être codés.

---

## 1. Le projet en bref

- **Jeu Roblox compétitif**, développé en binôme. Stack : Luau, Rojo, Roblox Studio, GitHub.
- **Références visées** : *Steal a Brainrot* et *Steal an Egg*, deux des plus gros succès récents de Roblox (genre « Steal a… »).
- **Objectif** : atteindre le niveau de ces jeux en gameplay, rétention, visuels et monétisation.

### Boucle actuelle
- **Feeding (45 s)** : trou noir ouvert, nuit, objets qui apparaissent. Les joueurs ramassent ([E]) et lancent des objets dans le trou noir pour marquer des points (valeur × bonus du familier équipé).
- **Digesting (60 s)** : trou noir fermé, jour, dôme qui repousse objets et joueurs (KO, objets lâchés). Les points sont convertis en tirages de familiers + argent (15 $/point).
- Les familiers posés dans la base génèrent un revenu passif ($/s).

---

## 2. État actuel du jeu (ce qui EXISTE)

### Carte (générée par code)
- Arène prairie ronde (rayon 315), chemins de terre vers chaque base, 12 arbres.
- Trou noir central (disque de 80) : anneau violet (rouge en digestion), sphère noire + halo, particules, lumière, dôme rouge en digestion.
- 8 bases en cercle à 215 du centre : clôture bois + portail, nom du propriétaire, plaque d'apparition invisible, bouton de verrouillage devant la porte, 4 palettes à objets, tapis de course (gauche) et banc (droite) visibles une fois achetés.
- 4 kiosques entre les bases : BOUTIQUE + machine de FUSION, ouverts avec [E].
- Transition nuit/jour (4 s), ciel étoilé, atmosphère.

### Objets à jeter
| Objet | Points |
|---|---|
| Caillou | 0,25 |
| Brique | 0,5 |
| Cristal | 1 |
| Lingot d'or | 2,5 |
| Diamant | 6 |
| Météorite | 15 |

- Les plus rares brillent. 5 objets offerts à l'arrivée.
- Feeding : 1 objet / 2 s sur les palettes, 12 max par base ; objets « sauvages » dans l'arène (un peu plus précieux), 1 / 4 s, 25 max.
- Pas de glisse ni rebond ; bulle « [E] Ramasser (nom +valeur) » ; nettoyage auto du surplus.

### Ramasser et lancer
- [E], validé par le serveur qui désigne le propriétaire.
- Sac à dos : +1 objet porté par niveau (1er en main, les autres empilés dans le dos).
- Lancer : maintien pour charger (ralenti, zoom, arc de visée avec point d'impact), relâcher. Impossible depuis sa propre base. Puissance = Force.
- Commandes : clic gauche (PC), bouton LANCER avec jauge (mobile), R2 (manette).

### Récompenses (fin de Feeding)
- Points → tirages : 1er tirage = 2 points, chaque suivant +8 %, au moins 1 tirage dès qu'on a marqué. Chance qui monte un peu avec le score.
- Pitié : Épique ou mieux garanti au 60e tirage sans Épique.
- Fenêtre de résultats + annonce serveur pour Légendaire ou mieux.

### Familiers
- 75 familiers, 5 catégories (Animaux, Fantastiques, Plantes, Hybrides, Brainrot), 8 raretés de Commun (50 %) à Sigma (0,1 %).
- Modèles : 74 générés avec des formes de base (provisoires), 1 vrai modèle 3D importé (Capybara Zen).
- 1 familier équipé : suit le joueur, bonus de points additif (+0,1 à +9).
- Base : les 10 meilleurs se baladent (un par espèce, « x2 » si doublon), animations variées, nom + revenu affichés.
- Revenu passif : de 2 $/s (Commun) à ~25 milliards $/s (Sigma).
- Fusion : 5 familiers de même rareté + coût (250 $ → 250 milliards $) = 1 de la rareté supérieure, jusqu'à Divin (Sigma impossible par fusion). Prend d'abord les doublons, jamais les équipés.

### Progression
- Vitesse et Force par niveaux jusqu'à 60, +12 % d'XP par niveau.
- Tapis et banc : 5 niveaux (bois → diamant), ×1 à ×10.
- Boutique à niveaux : Tapis/banc (500 $ → 104 milliards), Chance (2 000 $ → ~400 000 milliards), Sac à dos (25 000 $ → 1 600 milliards), Verrou renforcé (5 millions).

### Bases et vol
- Base attribuée automatiquement, apparition dessus.
- Verrouillage 5 s (10 s avec verrou renforcé), relancé à chaque passage sur le bouton, intrus expulsés.
- Vol d'objets possible dans les bases ouvertes. **Vol de familiers : fait le 8 oct. 2026** (PLAN étape 3, voir GDD).

### Interface
- Style cartoon : police épaisse, contours noirs, dégradés, boutons qui rebondissent.
- Haut : phase, chrono (rouge clignotant en fin), points de la manche. Bas : consigne selon l'appareil.
- Gauche : argent (K/M/B/T…), revenu/s, barres XP Vitesse/Force, boutons BOUTIQUE et FAMILIERS.
- Fenêtres : Boutique, Familiers (collection 75, aperçu 3D, silhouettes, équipement au clic), Fusion, Résultats. Messages d'achat, niveau, erreurs, annonces. Classement Argent et Points.
- Mobile/manette : UI mise à l'échelle, bouton LANCER tactile, colonne gauche remontée, animations allégées, R2.

### Technique
- DataStore : argent, familiers, équipés, niveaux, XP, améliorations, pitié. Sauvegarde à la déconnexion, toutes les 60 s, à l'arrêt serveur. Rien n'est sauvegardé si le chargement a échoué. Verrou de session anti-duplication (fait le 8 oct. 2026, voir GDD).
- Serveur autoritaire : achats, fusion, équipement, ramassage, score, récompenses.
- Rojo, code typé strict : 7 fichiers client, 15 serveur, 7 partagés. GitHub, GDD, CLAUDE.md.
- Options Studio : tous les familiers, familiers de test équipés, durées courtes (30 s / 20 s, désactivé).

### Ce qui N'EXISTE PAS encore
- Contenu : ~~aucun son ni musique~~ (fait le 8 oct., voir GDD « Sons et musique ») ; 74/75 modèles provisoires ; pas de rebirth, quêtes, récompenses quotidiennes ; pas de classement global ni d'événements.
- Social : pas d'échanges ; pas de vol de familiers ; pas de codes, bonus de groupe, badges.
- Robux : aucun gamepass ni produit.
- Pas de tutoriel.
- Sécurité : pas d'anti-triche sur les lancers (calculés côté client) ; ~~pas de protection anti-duplication entre serveurs~~ (fait : verrou de session) ; sauvegarde pas remise à zéro pour l'ouverture.
- Publication : noms de brainrots repris de *Steal a Brainrot* non renommés ; icône, vignettes, description à faire ; questionnaire de maturité à remplir ; aucun test multijoueur réel.

---

## 3. Ce qui fait marcher les jeux de référence

### Le cœur du genre
Dans *Steal a Brainrot* et *Steal an Egg*, **ce qu'on vole, c'est la créature qui rapporte de l'argent** (brainrot, œuf, familier). Le voleur la porte jusqu'à sa base, le propriétaire le poursuit ; si on le frappe, il la perd. C'est cette tension (gain énorme d'un côté, frustration de l'autre, course-poursuite) qui crée l'engagement et la viralité. Une créature de valeur transforme son porteur en cible.

**Feed The Blackhole ne permet de voler que des objets à jeter. Le vol de familiers est donc le manque n°1.**

### Mécaniques clés observées
| Système | Steal a Brainrot | Steal an Egg |
|---|---|---|
| Acquisition | Tapis roulant central où défilent des brainrots à acheter, du commun au rare, visible par tous | Courir dans des biomes (vitesse requise), voler un œuf, le faire éclore dans son enclos |
| Revenu | Chaque créature rapporte des $/s sur son socle | Chaque familier rapporte des $/s dans l'enclos |
| Vol | [E] sur la créature, la ramener à sa base ; frappé = perdue | Voler les œufs des PNJ et des autres joueurs |
| Défense | Verrou de base (+temps à chaque rebirth), étages reliés par escalier, équipement | — |
| Progression | Rebirth (18 niveaux) : on perd ses créatures, on gagne +1 emplacement, +10 s de verrou, un multiplicateur, de l'argent, un nouvel équipement ; 2e étage (10 emplacements) au rebirth 2 | Tapis de course pour la vitesse, biomes à débloquer |
| Multiplicateurs | Mutations (une par créature : Gold ×1,25, Diamond ×1,5, Lava ×6, Rainbow ×10) + traits cumulables, le tout **multiplicatif** | 5 mutations qui multiplient le revenu, via éclosion, fusion, événements |
| Équipement | Gifle, ressort de vitesse, piège (gèle 10 s), grappin, taser, cape d'invisibilité, sentinelle, etc., débloqués par rebirth | — |
| Événements | « Admin abuse » (vendredis avant mise à jour, chaque mardi à heure fixe, surprises annoncées sur Discord), météo qui applique traits/mutations, objets limités | Événements thématiques (incubateur saisonnier, faille, vagues de monstres), œufs/familiers limités |
| Social | +10 % de revenu par ami, codes | Codes |
| Sessions | — | ~15 min en moyenne, objectif compris immédiatement |

### Monétisation observée
| Type | Steal a Brainrot | Steal an Egg |
|---|---|---|
| Passes permanents | 2X Money, VIP (bonus argent, tag, +10 s de verrou), HD Admin (~1 999 R$) | X2 Money (~399 R$), X2 Croissance (~467 R$) |
| Équipement payant | Gifle trou noir (~199 R$), tapis volant (~499), pistolet laser (~999), Ban Hammer (~1 499) | — |
| Achats répétables | — | Éclosion instantanée (~9 R$), faire pousser tous les œufs (~160 R$) |

Principe : **passes permanents** (rassurants, achat unique) + **produits consommables répétables** (l'essentiel du revenu).

---

## 4. Feuille de route par priorité

### P0 — Indispensable avant la sortie publique

#### P0.1 Vol de familiers (PROCHAINE FEATURE, voir spec §5)

#### P0.2 Acquisition visible
Aujourd'hui les tirages apparaissent dans une fenêtre privée. Il faut que les nouveaux familiers **apparaissent physiquement dans la base**, visibles par tous (effet d'apparition, annonce serveur pour les rares), pour donner envie de venir les voler.
- [À DÉCIDER] garder la fenêtre de résultats en plus, ou la remplacer par une apparition en base.

#### P0.3 Sons et musique
Aucun son actuellement. Minimum : musique d'ambiance (une pour Feeding, une pour Digesting), ramassage, chargement du lancer, lancer, aspiration par le trou noir, gain de points, tirage (par rareté), annonce légendaire, vol réussi, vol raté, verrouillage, achat, montée de niveau, KO par le dôme. Créer un module de sons centralisé (identifiants dans le module partagé), avec volume par catégorie.

#### P0.4 Modèles des familiers
74/75 sont provisoires. Dans ce genre, les créatures **sont** le produit. Priorité aux 10-15 plus rares (ce qu'on voit dans les vidéos). Chaque familier doit être reconnaissable en silhouette et avoir un nom marquant.

#### P0.5 Tutoriel
Le joueur doit comprendre en 30 secondes : flèche/balise + 3 étapes guidées (ramasser un objet → le lancer dans le trou noir → récupérer son familier / voler). Désactivé après la première complétion (stocké dans la sauvegarde).

#### P0.6 Sécurité et publication
- Anti-triche sur les lancers : le serveur valide la trajectoire (puissance max selon la Force du joueur, distance plausible, cooldown) au lieu de faire confiance au client.
- Anti-duplication (indispensable avant le vol de familiers et les échanges) : verrou de session sur le profil (ex. session lock dans le DataStore) pour empêcher un même joueur d'être chargé sur deux serveurs.
- Renommer **tous** les familiers dont le nom est repris de *Steal a Brainrot*.
- Remise à zéro des sauvegardes de test avant ouverture (nouvelle clé de DataStore).
- Icône, vignettes, description, questionnaire de maturité.
- Test multijoueur réel (plusieurs comptes, plusieurs appareils).

#### P0.7 Monétisation de base
- Passes : 2X Argent, VIP (bonus argent, tag de chat, +temps de verrou), +1 emplacement de sac à dos.
- Produits répétables : boost de chance pour tout le serveur (temporaire, annoncé à tous), tirage instantané, argent.
- 2-3 outils de combat payants (voir P1.4).
- Utiliser `MarketplaceService.ProcessReceipt` côté serveur avec gestion idempotente des reçus (ne jamais accorder deux fois le même achat, ne jamais en perdre un).

### P1 — Rétention

#### P1.1 Rebirth
Condition : une somme d'argent (+ éventuellement un familier précis). Effet : on perd argent et familiers (hors exceptions [À DÉCIDER]) ; on gagne un multiplicateur permanent de revenu, +1 emplacement de familier, +temps de verrou, et le déblocage d'un nouvel outil dans la boutique.

#### P1.2 Emplacements et étages
Aujourd'hui 10 familiers se baladent dans la base. Passer à des emplacements explicites (socles) qui augmentent avec les rebirths ; un 2e étage (accessible par escalier) débloqué à un rebirth donné, qui rend aussi le vol plus difficile.

#### P1.3 Mutations et traits
- Mutation : une seule par familier, change l'apparence (couleur, effet), multiplie le revenu (ex. Or ×1,25, Diamant ×1,5, Lave ×6, Arc-en-ciel ×10 — noms et valeurs à adapter au thème du trou noir, ex. « Cosmique », « Supernova », « Matière noire »).
- Traits : cumulables, obtenus par événements/météo.
- Formule : `revenu = base × mutation × trait1 × trait2 × …`.
- Les mutations doivent aussi pouvoir sortir de la fusion et des tirages.

#### P1.4 Équipement de combat et de défense
Aujourd'hui le seul KO vient du dôme. Ajouter une boutique d'outils débloqués par rebirth : gifle (repousse), ressort de vitesse, piège (immobilise quelques secondes), grappin, etc. Tous validés côté serveur (portée, cooldown).

#### P1.5 Social
Bonus +10 % de revenu par ami sur le serveur, bonus de groupe Roblox, codes cadeaux, badges, récompense quotidienne.

### P2 — Faire vivre le jeu

- **Événements programmés** à heure fixe (ex. un soir par semaine) + événements surprises : pluie de météorites, éclipse, trou noir géant… qui appliquent des traits/mutations temporaires. Ton thème cosmique s'y prête parfaitement.
- **Météo cosmique** appliquant des mutations.
- **Familiers en édition limitée** pendant les événements.
- **Classement global** (OrderedDataStore).
- **Échanges** entre joueurs : seulement après l'anti-duplication (P0.6) en place et testé.

---

## 5. Spec : vol de familiers (version minimale)

### Objectif
Permettre de voler un familier dans la base d'un autre joueur et de le ramener dans la sienne, avec une vraie possibilité pour la victime de le récupérer.

### Règles proposées (à valider)
- Familiers volables : ceux qui se baladent dans une base, **jamais le familier équipé**.
- Condition : la base cible est déverrouillée. [À DÉCIDER] autoriser le vol à tout moment, ou seulement pendant Digesting (ce qui donnerait un rôle aux 60 s de digestion, aujourd'hui sans action).
- [E] près du familier → il est porté dans le dos du voleur, visible par tous, avec un indicateur au-dessus (nom + rareté).
- Le voleur est ralenti (point de départ : vitesse ×0,6) et ne peut ni ramasser ni lancer d'objet pendant le transport.
- Un seul familier porté à la fois.
- Arrivée dans la base du voleur → transfert de propriété validé par le serveur, annonce (au moins à la victime ; à tout le serveur si rareté Légendaire ou plus).

### Échec du vol → le familier retourne chez sa victime si :
1. Le voleur est mis KO (dôme, et plus tard outils de combat).
2. Le voleur se déconnecte ou quitte le serveur.
3. Le propriétaire appuie sur [E] à proximité du voleur (portée à définir, ex. 8 studs) — défense minimale en attendant les outils de combat.
4. [À DÉCIDER] une durée maximale de transport.

### Exigences techniques
- Tout est validé côté serveur : distance au familier, état de la base, état du voleur (ne porte pas déjà un familier), propriété.
- **Aucune duplication ni disparition possible** : pendant le transport, le familier reste juridiquement à la victime (marqué « en cours de vol ») ; il n'est retiré de son profil et ajouté à celui du voleur qu'au moment du transfert, en une seule opération serveur, suivie d'une sauvegarde des deux profils.
- Si la victime quitte le serveur pendant le vol : [À DÉCIDER] le vol est annulé (recommandé pour la version minimale).
- Réutiliser le système existant de ramassage/portage d'objets et de bases plutôt que d'en créer un nouveau.
- Mettre à jour l'affichage de la base (familiers qui se baladent) des deux joueurs.

### Cas à tester (2 joueurs en serveur local, minimum)
> 8 oct. 2026 (PLAN étape 3) : logique vérifiée en faisant tourner le vrai `StealController` contre des dépendances simulées
> (34/34). « (L) » = logique vérifiée ; reste à cocher après le test réel à 2 joueurs de Chouaib.
- [ ] (L) Vol réussi : le familier change de base, les deux sauvegardes sont correctes après reconnexion.
- [ ] (L) Vol raté par KO : le familier revient chez la victime.
- [ ] (L) Vol raté par récupération du propriétaire (étape 4, logique vérifiée 20/20 le 8 oct.).
- [ ] (L) Déconnexion du voleur pendant le transport.
- [ ] (L) Déconnexion de la victime pendant le transport.
- [ ] (L) Impossible de voler le familier équipé, ou dans une base verrouillée.
- [ ] (L) Impossible de porter deux familiers.
- [ ] (L) Le familier volé n'apparaît jamais dans deux bases à la fois.

---

## 6. Contraintes et risques

1. **Politique de Roblox (août 2026)** : Roblox a retiré un jeu nommé *Steal an Egg* qui récompensait le visionnage de vidéos générées par IA, et restreint désormais pour les jeunes comptes les jeux qui récompensent la consommation d'un flux continu de contenu. **N'ajoute aucune mécanique de ce type** (récompense contre visionnage de contenu, flux sans fin).
2. **Propriété intellectuelle** : aucun nom, modèle ou visuel repris de *Steal a Brainrot* ou d'un autre jeu. Créer nos propres noms (le thème cosmique / trou noir est un avantage : l'utiliser).
3. **Duplication** : toute feature qui transfère un objet de valeur entre deux profils (vol, échange, cadeau) doit être conçue contre la duplication dès le départ.
4. **Performance mobile** : beaucoup de joueurs sont sur téléphone. Surveiller le nombre de pièces, particules et scripts par familier ; garder les animations allégées sur mobile.
5. **Économie** : avec des revenus jusqu'à 25 milliards $/s, vérifier qu'aucune nouvelle source de multiplicateur (rebirth, mutations, passes) ne casse la progression. Centraliser les multiplicateurs dans une seule fonction de calcul du revenu.

---

## 7. Notes techniques de passation (état du code au commit `30f9ef3`)

> Ajouté par l'IA précédente. Ces points viennent du code réel ; ils évitent les erreurs les plus probables.

### 7.1 Où travailler, comment livrer
- **Dépôt** : `github.com/bouhouch-chouaib/getRichOrGetRobbed`, branche `main`.
- **Dossier de Chouaib** (celui d'où il lance `rojo serve`, synchronisé en direct dans Studio) :
  `C:\Users\bouho\OneDrive - Conseil régional Grand Est - Numérique Educatif\Documents\GetRichOrGetRobbed`.
- **Copie de travail sans accents** : `C:\Users\bouho\dev\getRichOrGetRobbed` (les outils d'analyse plantent sur le chemin OneDrive).
- `C:\Users\bouho` est lui-même un dépôt git vide pointant sur le même remote (accident) : **ne jamais y travailler**.
- **Branches** : la §0 recommande une branche par feature, mais jusqu'ici Chouaib a explicitement demandé de **pousser directement sur `main`**. Lui demander avant de changer de méthode.
- **Workflow utilisé** : modifier dans `dev\`, analyser, commit, push, puis aligner le dossier OneDrive
  (`git fetch && git checkout -- . && git merge --ff-only origin/main`). Le `git push` reste parfois bloqué plusieurs minutes
  (fenêtre d'identification GitHub) : le lancer en arrière-plan et copier les fichiers dans OneDrive pour que Chouaib teste sans attendre.
- Chouaib est débutant : explications simples en français, dire clairement ce qui est vérifié (analyse + build) et ce qui ne l'est pas (rendu en jeu).

### 7.2 Vérifier le code (l'IA ne peut pas lancer Studio)
```
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
rojo build -o test.rbxlx
```
- Rojo 7.7.0 via aftman. `luau-lsp` n'est pas installé : télécharger `luau-lsp-win64.zip` (releases JohnnyMorganz/luau-lsp)
  et `scripts/globalTypes.d.luau` dans un dossier temporaire. Tout le code passe l'analyse `--!strict` sans erreur : garder ce niveau.
- Écrire les fichiers en UTF-8 / LF. Attention aux `\n` dans les scripts bash + python (ont déjà cassé une chaîne Luau) : préférer
  l'outil d'édition ou un script Python dans un fichier.

### 7.3 Pièges Rojo déjà rencontrés
- `rojo serve` **ne relit pas `default.project.json`** en cours de session : après toute modification de ce fichier, demander à
  Chouaib de relancer `rojo serve` + Connect. (C'est pour ça que `Remotes.lua` crée lui-même les RemoteEvents manquants côté serveur.)
- `ReplicatedStorage.PetModels` est mappé sur `assets/PetModels/` : un Model mis à la main dans ce dossier dans Studio serait effacé par
  Rojo. Les modèles 3D se versionnent en `.rbxm` dans `assets/PetModels/`.
- ~~Capybara Zen mal affiché~~ **Résolu (8 oct. 2026)** : les MeshParts arrivaient bien ; le vrai bug était dans
  `PetModelBuilder.normalizeCustom`, qui mesurait la boîte englobante AVEC le Root posé à l'origine alors que le modèle importé
  est loin (Y = -78) : modèle réduit à ~10 % et éclaté. La boîte est maintenant mesurée sur le contenu importé seul.

### 7.4 Carte du code (à réutiliser, ne pas recréer)
| Module | Rôle | API utile |
|---|---|---|
| `server/Main.server.lua` | Ordre d'initialisation (tout s'abonne avant `GameLoopManager.Start()`) | — |
| `server/GameLoopManager` | Phases Feeding/Digesting, attributs `GameState`/`TimeRemaining` sur ReplicatedStorage | `ServerEvent` ("StateChanged", "Tick"), `GetState()` |
| `server/SessionData` | Données joueur + DataStore `PlayerData_v1` (clé `u_<UserId>`) → attributs Player + leaderstats | `Get`, `AddMoney`, `SpendMoney`, `AddPets`, `RemovePets`, `GetSpareCount`, `Equip`, `Unequip`, `GetMultiplier`, `AddTrainingXP`, `GetUpgradeLevel`, `SetUpgradeLevel`, `HasUnlock`, `AddScore`, `GetPity`/`SetPity` |
| `server/BaseManager` | Attribution des bases | `GetBase(player)`, `GetOwner(base)`, `GetOccupiedBases()`, évènement `BaseAssigned` |
| `server/ItemInteraction` | Ramassage/portage/lancer autoritaire, sac à dos | `Register(item)`, `ReleaseHeld(player)`, `IsHeld(item)` |
| `server/BlackholeController` | Aspiration, dôme, KO (`knockbackPlayer`), distribution des récompenses | — |
| `server/LockController` | Bouton de verrouillage, portail, expulsion ; attributs `Locked`/`LockedUntil` sur la base | — |
| `server/EconomyController` | Revenu passif, achats boutique | `GetTopPets(player)` (les 10 meilleurs NON équipés = ceux de la base, qui rapportent), `GetIncome` |
| `server/BasePetsController` | Familiers de base autoritaires : repère `Base_N.Pets.<PetId>` (attributs `PetId`, `Count`, `Seed`, `Walk`) | `GetPetPosition(repère)` |
| `server/FusionController`, `PetController`, `TrainingController`, `ItemSpawner`, `MapGenerator`, `DayNightController` | Fusion, équipement, stations, apparition d'objets, carte, jour/nuit | — |
| `shared/Config` | **Toutes** les valeurs d'équilibrage (raretés, prix, durées, options Studio) | `GetUpgradePrice`, `GetXPNeeded`, `RarityIndex` |
| `shared/PetCatalog` | Les 75 familiers (Id sans accent, rareté, apparence) | `ById`, `ByRarity`, `GetIncome(petId)` |
| `shared/LootEngine`, `PetModelBuilder`, `PetModelColors`, `NumberFormat`, `Remotes` | Tirages, modèles 3D, couleurs des modèles importés, affichage K/M/B/T, RemoteEvents | — |
| `client/HUD`, `InteractionController`, `BasePets`, `PetFollow`, `ItemPromptAnchors`, `ScreenScale`, `Toast` | Interface, lancer (souris/tactile/manette), familiers de base, familiers équipés, bulles [E], mise à l'échelle, messages | `Toast.show(texte, couleur)`, `ScreenScale.attach(screenGui)` |

### 7.5 ⚠️ Prérequis pour le vol de familiers (§5) : l'état actuel ne le permet pas tel quel
- ~~Familiers de base 100 % côté client~~ **Fait (8 oct. 2026, PLAN étape 2)** : le serveur décide des trajets et porte un repère
  invisible par espèce (`Base_N.Pets.<PetId>`, Part ancrée, CanQuery = false) ; le client interpole avec `GetServerTimeNow()`.
  Pour le `[E]` du vol : mettre le ProximityPrompt sur ce repère et le faire suivre **localement** par chaque client (le serveur
  ne déplace jamais le repère, donc un `PivotTo` local n'est pas écrasé) ; valider la distance côté serveur avec `GetPetPosition`.
- Le serveur n'affiche qu'**une créature par espèce** (attribut `Count`) : le voleur emporte 1 exemplaire du lot.
- Les familiers de base sont exactement ceux de `EconomyController.GetTopPets`, qui **exclut désormais les exemplaires équipés**
  (`SessionData.GetSpareCount`) : tout ce qui est dans une base est volable.
- Points d'accroche existants : KO du dôme → `BlackholeController.knockbackPlayer` (appelle déjà `ItemInteraction.ReleaseHeld`) ;
  verrou → attribut `Locked` de la base ; transfert sans duplication → `SessionData.RemovePets` + `SessionData.AddPets`
  dans la même étape serveur, puis sauvegarde des deux profils.
- ~~Pas de verrou de session DataStore~~ **Fait (8 oct. 2026)** : verrou de session dans `SessionData` (voir GDD). Le transfert
  du vol doit rester une seule étape serveur (`RemovePets` + `AddPets`) entre deux joueurs dont ce serveur tient les deux verrous.

### 7.6 Sauvegarde (schéma actuel)
- Champs sauvegardés : `version = 2`, `session` {id, job, studio, time} (verrou, `nil` = libre), `levels` {Speed, Strength}, `xp` {Speed, Strength}, `money`, `pets` {petId → quantité},
  `equipped` {petId…}, `pity`, `upgrades` {Id → niveau}. Le score de manche n'est pas sauvegardé.
- Chargement asynchrone : les données par défaut existent dès l'arrivée ; la sauvegarde est fusionnée ensuite (`data.loaded = true`).
- Dans Studio, la sauvegarde ne marche que si le jeu est publié **et** que « Enable Studio Access to API Services » est coché
  (sinon un avertissement clair s'affiche et rien n'est sauvegardé).

### 7.7 Options de test actuellement actives (à remettre avant publication)
- `Config.StudioTestPets = { "CapybaraZen" }` : donne et équipe ce familier dans Studio (3 s après l'arrivée). Vider la liste ensuite.
- `Config.StudioGiveAllPets = false`, `Config.UseStudioDurations = false`.
- Les familiers donnés en test sont **sauvegardés** si l'accès API Studio est activé : prévoir la nouvelle clé de DataStore avant l'ouverture (§P0.6).

### 7.8 Préférences de Chouaib déjà exprimées
- Style visuel : Steal a Brainrot / Steal an Egg (cartoon, contours noirs épais, pas de néons dans les bases, prairie, bois).
- Grands nombres partout (du dollar aux trillions), affichage abrégé K/M/B/T.
- Progression lente et satisfaisante (entraînement long, prix croissants), mais qui « ne fait pas rager ».
- Textes et panneaux toujours visibles, juste au-dessus de ce qu'ils désignent.
- Il préfère avancer fonctionnalité par fonctionnalité et tester lui-même dans Studio entre chaque étape.

### 7.9 Compléments (ajoutés le 6 oct. au soir, à partir de la feuille de route de Chouaib et de l'historique)

**Fin de chaque feature.** Terminer par une **liste de tests précise** pour Chouaib (Studio : Test → Clients and Servers → 2 joueurs),
puis lui demander de coller la sortie **Output** (erreurs rouges / avertissements orange). Il copie-colle volontiers les logs.

**Monétisation (P0.7)** — [À DÉCIDER] : dès la sortie publique ou après les premiers retours de joueurs.
Points d'accroche déjà dans le code : `LootEngine.roll(score, pity, luckBonus)` (paramètre `luckBonus` prévu pour un pass de chance),
`PlayerData.equipSlots` (pour un pass « +emplacements »). Les gamepasses/produits doivent être créés par Chouaib, qui donne leurs IDs.

**Pipeline d'un modèle 3D de familier (testé avec le Capybara Zen).**
1. Chouaib génère un `.glb`/`.fbx` (ChatGPT, Meshy, Tripo, générateur Studio…) et le dépose dans `assets/PetModels/`.
2. L'IA l'inspecte (Python : en-tête glTF, nb de triangles < ~20 000, dimensions, matières, côté des yeux via les bornes des primitives).
   Les `.glb` regardent généralement vers **+Z** ; le jeu attend **-Z** → rotation 180° appliquée par défaut.
3. Chouaib l'importe dans Studio (Accueil → Importer 3D), renomme le Model **exactement** comme l'Id (`PetCatalog`), puis clic droit →
   « Enregistrer dans un fichier » → `assets/PetModels/<Id>.rbxm`, et supprime l'exemplaire du Workspace.
4. `PetModelBuilder.normalizeCustom` centre le modèle, le tourne (attribut `FacingYaw` en degrés sur le Model pour corriger, 180 par défaut)
   et le met à la hauteur de sa rareté (attribut `HeightScale` pour ajuster).
5. **L'importeur Roblox perd les couleurs d'un `.glb` sans texture** (toutes les MeshParts arrivent grises 163,162,165). Méthode utilisée :
   lire le `.rbxm` (binaire, chunks LZ4 : `pip install lz4`), récupérer noms + tailles des MeshParts, les apparier aux primitives du `.glb`
   (même ordre, mêmes dimensions), convertir `baseColorFactor` (linéaire) en sRGB, et écrire la table dans `shared/PetModelColors.lua`
   (`[Id] = { [NomMeshPart] = Color3 }`). Le builder les réapplique en SmoothPlastic.
6. Pour tester sans tirage : `Config.StudioTestPets = { "<Id>" }` (donné + équipé dans Studio).

**Piste d'anti-triche des lancers (P0.6).** Aujourd'hui `Remotes.ThrowItem` ne transporte que l'item, et le client possède la physique
de l'objet en vol (il pourrait le téléporter dans le trou). Proposition minimale, sans casser les règles physiques :
au `ThrowItem`, le serveur enregistre sur l'item `ThrowOrigin` (position du HumanoidRootPart), `ThrowTime` et `ThrowPower`
(attribut du joueur) ; dans `BlackholeController.consume`, refuser le point si la distance horizontale `ThrowOrigin → bord du trou`
dépasse la portée max théorique (`ThrowPower² / Workspace.Gravity` × marge ~1,3) ou si le temps de vol est invraisemblable ;
ajouter un cooldown serveur entre deux `ThrowItem` du même joueur. Les objets non lancés (portés à pied) ne doivent jamais compter.

**Petits restes connus dans le code.**
- ~~Commentaires « socles » dans `EconomyController`~~ et ~~familier équipé visible dans la base~~ : corrigés (étape 2).
- En Studio avec l'accès API activé, `Config.StudioTestPets` redonne +1 Capybara Zen **sauvegardé** à chaque partie de test
  (le compte de Chouaib en accumule) : vider la liste quand le modèle est validé.
- Le classement « Argent » est une `StringValue` (affichage abrégé) : il ne se trie pas numériquement.
- Les outils de vérification (`luau-lsp`) sont téléchargés dans le dossier temporaire de session : à re-télécharger à chaque nouvelle session.
