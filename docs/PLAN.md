# Plan étape par étape jusqu'à la sortie

> Rédigé le 8 octobre 2026, à partir de `docs/ROADMAP.md`.
> Une étape = une fonctionnalité, testée par Chouaib dans Studio (Test → Clients and Servers → 2 joueurs) avant de passer à la suivante.
> Les réglages chiffrés sont des points de départ. Les points **[À DÉCIDER]** se tranchent avec Chouaib avant de coder l'étape.

## Phase A — Le vol de familiers (le cœur du jeu)

| # | Étape | Ce que ça change pour le joueur | Fini quand… |
|---|---|---|---|
| 1 | ✅ **Anti-duplication** : verrou de session sur la sauvegarde (codé et testé le 8 oct. sur une fausse base : 28/28 ; reste le test réel) | Rien de visible ; empêche de copier des familiers en jouant sur 2 serveurs | Un même compte ne peut pas être chargé deux fois ; aucune perte de sauvegarde |
| 2 | ✅ **Familiers de base gérés par le serveur** (fait le 8 oct. ; décision : un familier équipé ne rapporte plus d'argent) | Tous les joueurs voient les familiers au même endroit ; le familier équipé ne se balade plus dans la base | 2 joueurs voient la même chose ; aucune saccade sur mobile |
| 3 | ✅ **Vol de familiers** (spec ROADMAP §5 ; codé le 8 oct. avec les réglages ci-dessous, logique testée 34/34, reste le test réel à 2) | [E] sur un familier adverse, le porter jusqu'à sa base, ralenti ×0,6 | Les 8 cas de test de la spec passent |
| 4 | ✅ **Défense** : récupération par le propriétaire ([E] près du voleur) + annonces de vol (fait le 8 oct. ; voleur entouré de rouge chez la victime ; logique testée 20/20, reste le test réel à 2) | La victime peut reprendre son familier | Testé à 2 joueurs |

Réglages proposés : vol **seulement pendant la digestion** et base déverrouillée ; vol annulé si la victime part ; transport max **30 s**.

## Phase B — Rendre le jeu vivant

| # | Étape | Détail |
|---|---|---|
| 5 | ✅ **Acquisition visible** (fait le 8 oct.) | Les familiers tirés apparaissent dans la base avec un effet ; annonce pour Légendaire+. Décidé : fenêtre de résultats gardée mais discrète (petite carte, 5 s) |
| 6 | ✅ **Sons et musique** (fait le 8 oct. : choisis par l'IA dans les banques sous licence via le MCP Studio, à faire écouter et ajuster par Chouaib) | Module de sons centralisé (IDs dans `Config.Sounds`), musique Feeding/Digesting + 16 effets |
| 7 | **Effets de satisfaction** | « +2.5 » qui s'envole, ouverture animée des tirages rares, petites secousses d'écran |
| 8 | **Tutoriel** | Flèche + 3 étapes (ramasser → lancer → voir son familier), sauvegardé une fois fini |

## Phase C — Préparer la publication

| # | Étape | Détail |
|---|---|---|
| 9 | **Renommer les familiers copiés** de Steal a Brainrot (noms cosmiques à nous) | Obligatoire (risque DMCA) |
| 10 | **Anti-triche des lancers** | Le serveur vérifie distance, puissance et délai (piste ROADMAP §7.9) |
| 11 | **Modèles 3D des 10-15 familiers les plus rares** | Pipeline ROADMAP §7.9, import direct dans Studio via le MCP |
| 12 | **Monétisation de base** | 2X Argent, VIP, +1 sac ; produits : boost de chance serveur, tirage instantané ; `ProcessReceipt` idempotent ; probabilités affichées. Chouaib crée les passes et donne les IDs. [À DÉCIDER] dès la sortie ou après |
| 13 | **Nettoyage avant sortie** | Nouvelle clé de DataStore, options Studio remises à zéro (`StudioTestPets` vide), classement Argent triable |
| 14 | **Page du jeu** | Icône, vignettes, description, questionnaire de maturité |
| 15 | **Test réel** | Plusieurs comptes et appareils (PC + téléphone), puis publication |

**→ Sortie publique possible après l'étape 15.**

## Phase D — Après la sortie (rétention)

16. Rebirth (multiplicateur permanent, +emplacement, +temps de verrou)
17. Socles explicites + 2e étage
18. Mutations cosmiques (Supernova, Matière noire, Nébuleuse…), revenu calculé dans une seule fonction
19. Outils de combat (gifle, ressort, piège…), débloqués par rebirth
20. Social : bonus d'amis, codes, badges, récompense quotidienne
21. Événements programmés et météo cosmique, familiers limités
22. Classement global
23. Échanges entre joueurs (uniquement après l'étape 1 testée en réel)
