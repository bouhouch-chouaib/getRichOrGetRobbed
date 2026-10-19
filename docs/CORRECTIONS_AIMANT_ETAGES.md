# Aimant, éclosions, étages et progression — 18 octobre 2026

## Comportement livré

- L’aimant démarre éteint sur les profils existants et nouveaux. Un bouton « AIMANT » dans le HUD et la touche G permettent de le basculer. Le choix est sauvegardé ; l’aimant exige toujours son amélioration ou son passe.
- Dans la portée achetée, il prend d’abord les objets qui rapportent le plus de points, puis les plus volumineux, puis les plus proches. Les limites du sac et les règles de portage restent appliquées côté serveur.
- Tout objet lancé est exclu de l’aimant jusqu’à sa prochaine récupération manuelle. Le temps de vol ne peut donc plus provoquer un retour automatique dans les mains.
- Les places actives de la base accueillent d’abord une copie de chaque espèce/forme, par revenu décroissant, puis les doublons. Dix copies d’un familier très rentable ne masquent plus une nouvelle espèce normale ou évoluée. Si toutes les places sont prises par des espèces différentes, les suivantes restent possédées dans l’Index ; le message d’éclosion indique d’agrandir la base.
- Les familiers équipés suivent toujours le personnage. Les places actives, y compris celles des étages, servent au revenu passif. Les doublons d’une même forme sont regroupés visuellement avec leur quantité.

## Étages

Le terminal cyan « AGRANDIR LA BASE », près de l’avant de chaque base, ouvre le menu d’achat. Le serveur ajoute une terrasse, des colonnes, des garde-corps et un escalier latéral alterné. Chaque étage ajoute dix places actives. Les familiers supplémentaires se promènent aux niveaux supérieurs ; leur hauteur est utilisée pour les interactions, le vol et l’affichage, y compris sur mobile.

Un monde atteint permet un étage supplémentaire : Prairie = un étage achetable au-dessus du rez-de-chaussée ; Divin = sept étages au maximum. Les étages restent après Rebirth et reconnexion. Après un Rebirth, il faut dépasser le nombre d’étages déjà possédés en mondes débloqués pour en acheter un nouveau.

| Étage | Prix en argent du jeu |
| --- | ---: |
| 1 | 250 000 |
| 2 | 5 millions |
| 3 | 250 millions |
| 4 | 15 milliards |
| 5 | 1 000 milliards |
| 6 | 100 000 milliards |
| 7 | 10 millions de milliards |

L’achat Robux utilise un **produit développeur rachetable** `BaseFloor`, proposé à 149 Robux. Son `Id` vaut encore **0** dans `src/shared/Config.lua` : créer le produit dans cette expérience puis remplacer cet ID est nécessaire pour activer les paiements réels. Le prix effectif est celui défini sur Roblox et confirmé par sa fenêtre d’achat.

Un reçu accorde un crédit permanent, consommé immédiatement si le monde permet de construire. Si un achat en argent a rempli la limite entre l’ouverture de la fenêtre Roblox et l’arrivée du reçu, le crédit reste sauvegardé et est utilisé au prochain monde admissible. Le reçu et le crédit sont enregistrés dans la même sauvegarde ; les tentatives répétées ne doublent pas la récompense. Aucun reçu réel n’a été utilisé pendant les tests.

## Nouveaux prix des mondes

| Monde | Ancien prix | Nouveau prix |
| --- | ---: | ---: |
| Prairie | Gratuit | Gratuit |
| Désert | 1 million | 5 millions |
| Volcan | 40 millions | 320 millions |
| Glace | 1,5 milliard | 18 milliards |
| Abysses | 75 milliards | 1 500 milliards |
| Cosmos | 4 000 milliards | 120 000 milliards |
| Divin | 250 000 milliards | 12,5 millions de milliards |

Les mondes déjà débloqués sont conservés. Ces prix constituent un premier réglage plus exigeant ; le temps réel pour progresser devra être mesuré en partie, en tenant compte des revenus des étages, mutations et Rebirths.

## Vérifications

Tests hors ligne sur les vrais modules avec types Roblox et services simulés :

- `tools/check-base-expansion.luau` : tri de l’aimant, exclusions et interrupteur, lancer de plus de vingt secondes, nouvelles espèces normales/évoluées, positions en hauteur, sept modèles d’étages, terminal, paiement en argent, limite avant achat, route Robux et réattribution d’une base.
- `tools/check-eggs.luau` : profils réels avec DataStore en mémoire, préférence de l’aimant, achat d’étage, reconnexion/Rebirth, course entre achats, crédits, reçus répétés et nouvelle tentative après échec de sauvegarde ; régressions d’éclosion et de couveuse.
- `tools/check-newcomer-steal.luau` : protection des nouveaux joueurs et refus de portage/ramassage à travers un étage.
- `tools/check-onboarding.luau` : suivi de progression et tutoriel existants.

L’analyse Luau et la construction Rojo complètent ces tests. Un essai dans Roblox Studio reste nécessaire pour valider visuellement les escaliers, les appareils mobiles et une partie à plusieurs joueurs. Le fichier local reconstruit ne publie pas l’expérience sur Roblox.
