# Aimant, éclosions et progression — 18 octobre 2026 (étages retirés le 19)

## Comportement livré

- L’aimant démarre éteint sur les profils existants et nouveaux. Un bouton « AIMANT » dans le HUD et la touche G permettent de le basculer. Le choix est sauvegardé ; l’aimant exige toujours son amélioration ou son passe.
- Dans la portée achetée, il prend d’abord les objets qui rapportent le plus de points, puis les plus volumineux, puis les plus proches. Les limites du sac et les règles de portage restent appliquées côté serveur.
- Tout objet lancé est exclu de l’aimant jusqu’à sa prochaine récupération manuelle. Le temps de vol ne peut donc plus provoquer un retour automatique dans les mains.
- Les places actives de la base accueillent d’abord une copie de chaque espèce/forme, par revenu décroissant, puis les doublons. Dix copies d’un familier très rentable ne masquent plus une nouvelle espèce normale ou évoluée. Si toutes les places sont prises par des espèces différentes, les suivantes restent possédées dans l’Index ; le message d’éclosion l’indique.
- Les familiers équipés suivent toujours le personnage. Les places actives servent au revenu passif. Les doublons d’une même forme sont regroupés visuellement avec leur quantité.

## Étages : retirés le 19 octobre 2026

Les étages de base (terminal « AGRANDIR LA BASE », terrasses, escaliers, +10 places par étage, produit Robux
`BaseFloor`) ajoutés par ChatGPT ont été retirés à la demande de Chouaib, ainsi que la hausse des prix des mondes qui
comptait sur leur revenu (retour aux prix d'avant : Désert 1 M, Volcan 40 M, Glace 1,5 Md, Abysses 75 Md,
Cosmos 4 000 Md, Divin 250 000 Md). Le travail d'origine est dans l'historique git (commit « ChatGPT tel quel »).
La base garde ses 10 places (+1 par Rebirth, `Config.GetIncomeSlots`) ; quand elle est pleine, les familiers en plus
restent dans l'Index.

## Vérifications

Tests hors ligne sur les vrais modules avec types Roblox et services simulés :

- `tools/check-magnet-roster.luau` : tri de l’aimant, exclusions et interrupteur, lancer de plus de vingt secondes, nouvelles espèces normales/évoluées, places de la base.
- `tools/check-eggs.luau` : profils réels avec DataStore en mémoire, préférence de l’aimant, achat de monde, reconnexion/Rebirth ; régressions d’éclosion et de couveuse.
- `tools/check-newcomer-steal.luau` : protection des nouveaux joueurs.
- `tools/check-onboarding.luau` : suivi de progression et tutoriel existants.

L’analyse Luau et la construction Rojo complètent ces tests. Un essai dans Roblox Studio reste nécessaire pour valider les appareils mobiles et une partie à plusieurs joueurs. Le fichier local reconstruit ne publie pas l’expérience sur Roblox.
