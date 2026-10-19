# Premiers joueurs : suivi et décisions de lancement

Implémenté le 17 octobre 2026. Source : `src/server/OnboardingAnalytics.lua`.
Les points, achats et récompenses restent décidés par leurs contrôleurs existants.

## Ce qui est mesuré

Le funnel d'accueil, dans Creator Hub → jeu → Analytics → Funnels, suit les **nouveaux profils créés après cette mise à jour** :

| Étape | Nom dans le tableau de bord | Preuve serveur |
|---|---|---|
| 1 | SaveLoaded | Profil chargé avec succès |
| 2 | FirstItemPickedUp | Ramassage accepté par ItemInteraction |
| 3 | FirstScoredThrow | Lancer consommé par le trou noir, après ses contrôles anti-triche |
| 4 | FirstEggReceived | Œuf réellement ajouté à la sauvegarde |
| 5 | FirstEggHatched | Œuf transformé en familier, normalement ou depuis la capsule |
| 6 | FirstUpgradeBought | Amélioration achetée avec l'argent du jeu, paiement accepté |
| 7 | SecondVisit | Deuxième connexion dont le profil a chargé |

Les actions faites dans un autre ordre sont conservées. Le funnel attend toutes les étapes précédentes : Roblox considère sinon une étape sautée comme réussie. Un œuf de cadeau quotidien ou une amélioration précoce ne simulent donc pas un lancer réussi. Les actions individuelles sont également suivies sans attendre cet ordre.

**SecondVisit n'est pas une rétention J1** : revenir cinq minutes plus tard suffit. Pour J1/J7, utiliser les cohortes de rétention natives de Roblox. Les anciens profils sans champ `onboarding` sont classés ExistingPlayer, sans être ajoutés artificiellement au funnel des nouveaux joueurs.

## Événements personnalisés

| Événement | Valeur | Utilisation |
|---|---|---|
| SessionJoined | 1 | Arrivées, y compris avant le chargement du profil |
| SaveLoadedSeconds | Secondes depuis l'arrivée | Temps de chargement de la sauvegarde |
| FirstActionSeconds | Secondes depuis l'arrivée dans la session de cette action | Premier Pickup / Scored / EggReceived / Hatched / Upgraded / Returned / Loaded |
| TutorialDismissed | 1 | Skipped / Finished / Unspecified ; choix déclaré par le client, sans valider d'action |
| SessionEndedSeconds | Durée de la session en secondes | Étape au départ et durée Under60s / 60to180s / Over180s |

Champs personnalisés :

- CustomField01 : FirstVisit, ReturningPlayer, ExistingPlayer ou Loading.
- CustomField02 : Step0 à Step7, dernière étape consécutive validée au moment de l'événement.
- CustomField03 : action, motif ou tranche de durée selon l'événement.

Pour mesurer le temps jusqu'au premier familier **dans la première session**, filtrer FirstActionSeconds sur CustomField01 = FirstVisit et CustomField03 = Hatched. La valeur est une durée dans la session, pas le temps total passé depuis la création du compte ; elle n'inclut pas les absences. Les actions avant la fin du chargement conservent leur heure d'origine.

## Sauvegarde et fiabilité

Le champ `onboarding` utilise la sauvegarde existante, sans nouvelle clé DataStore et sans remise à zéro. Il conserve les jalons et le nombre de visites ; le snapshot copie les tables pour ne pas bouger pendant une écriture. La sauvegarde normale reste soumise à ses délais habituels : un crash avant sauvegarde peut faire perdre les derniers jalons comme les autres modifications de la session.

Les événements sont envoyés depuis une file bornée, sans faire attendre les transactions. Une erreur d'AnalyticsService ne bloque pas une récompense. L'envoi reste de meilleur effort : une saturation, un arrêt brutal ou une erreur réseau peuvent perdre des événements. Les avertissements sont limités à un par minute. Studio n'envoie aucune donnée réelle.

## Tutoriel corrigé

Quatre étapes : ramasser → réussir un lancer → recevoir un œuf → voir son éclosion. La flèche pointe vers l'œuf qui éclora le plus tôt, ou vers la capsule si le joueur y a placé son œuf. Le compte à rebours suit le serveur. Le tutoriel reprend après reconnexion et reste passable ; passer ne valide aucune étape de gameplay. Il attend le chargement réel du profil au lieu de démarrer après un délai fixe de huit secondes.

## Vérification après publication

1. Publier cette version dans Roblox Studio, puis entrer dans le **jeu publié** avec un compte de test sans profil existant ; une session Studio n'alimente pas les statistiques.
2. Ramasser et lancer un objet. Vérifier que le tutoriel accompagne l'œuf et reste présent jusqu'à l'éclosion.
3. Acheter une amélioration, quitter, puis revenir. Vérifier que les données restent et que le tutoriel terminé ne recommence pas.
4. Dans Creator Hub, consulter Analytics → Funnels et Custom, après le délai de traitement de Roblox. Choisir une plage de dates postérieure au déploiement ; vérifier les premiers événements avant d'investir en acquisition.
5. Séparer les joueurs de la première visite, les retours et les profils existants ; utiliser les filtres natifs par appareil et provenance lorsqu'ils sont disponibles dans le rapport.

Commencer par l'étape qui perd le plus de joueurs. Comparer aussi la rétention J1/J7 native, la durée de session et les références de jeux similaires. Avec quelques testeurs, les tendances servent à trouver des problèmes, pas à annoncer une rentabilité.

## Tests hors ligne

`lune run tools/check-onboarding.luau <chemin-du-projet>` vérifie l'ordre, les doublons, la migration des anciens profils, la reprise, les snapshots, les actions pendant le chargement, l'indépendance en cas de panne et la fin réelle du tutoriel après éclosion.

`lune run tools/check-eggs.luau <chemin-du-projet> <dossier-de-sortie>` vérifie notamment la persistance et le retour du compteur de visites, avec les modules réels et un DataStore en mémoire.

Ces tests ne valident ni le rendu Studio ni l'arrivée effective de données dans Creator Hub.

Documentation officielle : [funnel events](https://create.roblox.com/docs/production/analytics/funnel-events), [custom events](https://create.roblox.com/docs/production/analytics/custom-events), [rétention](https://create.roblox.com/docs/production/analytics/retention).
