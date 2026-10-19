# Premières minutes : œuf de départ et protection anti-vol

Ajout du 17 octobre 2026, après l'installation du suivi d'accueil.

## Parcours

1. Un **nouveau profil** ramasse réellement son premier objet. Le serveur lui accorde un seul œuf de Chien Saucisse Commun dans la couveuse, même pendant la digestion du trou noir.
2. L'œuf suit l'incubation normale des Communs : **15 secondes** par défaut. Il n'ajoute pas de tirage, de progression du rang ou de mutation secrète.
3. Son éclosion crédite **500 $ une seule fois**, suffisants pour acheter le premier tapis ou banc dans la boutique. Ouvrir l'œuf depuis la capsule d'évolution crédite aussi cette prime.
4. Pendant la digestion, le tutoriel guide vers cet œuf, puis conseille d'utiliser la prime pour une station. À la réouverture du trou, il reprend l'apprentissage du lancer ; il ne valide pas un lancer que le joueur n'a pas réussi.

La boutique remet la catégorie Entraînement au premier plan pour un joueur ayant reçu la prime et n'ayant encore acheté aucune amélioration. Aucun achat ne se déclenche automatiquement.

## Protection anti-vol

- Elle dure **300 secondes à partir de l'attribution de l'œuf**. Le compte à rebours apparaît dans la pile du HUD, sous les autres indications, sans position flottante qui les recouvre.
- Le délai est une échéance UTC sauvegardée : il continue hors ligne, ne recommence pas en changeant de serveur et ne revient pas après expiration.
- Le serveur refuse de voler les familiers de ce joueur dans sa base **et** de ramasser contre son gré un familier qui rentre à pied. Les prompts clients suivent la même règle.
- Le propriétaire peut toujours porter ses propres familiers et les récupérer.
- Commencer un vol valide contre quelqu'un d'autre met fin à la protection. Une tentative refusée (distance, verrou, cible protégée, etc.) ne la retire pas.
- Un vol commencé avant le premier ramassage renonce également à la future protection : réclamer ensuite l'œuf ne permet pas de devenir protégé après avoir attaqué.
- Il s'agit d'une protection contre le **vol**, pas d'une invincibilité aux armes ni d'une annulation des échanges ou duels acceptés volontairement.

## Sauvegarde et réglages

Les profils existants sans champ `starter` restent inéligibles. Le changement ne remet aucune progression à zéro. Le champ `starter` est copié dans le snapshot existant avec l'œuf, les familiers et l'argent ; il n'utilise pas une seconde clé DataStore.

Réglages dans `Config.Newcomer` : `PetId`, `BonusMoney`, `ProtectionSeconds`. La durée d'éclosion reste celle de `Config.Eggs.Seconds.Commun`. Les cadeaux sont décidés par le serveur, sans RemoteEvent permettant au client de les réclamer.

## Vérification avant publication

- Avec un profil neuf, rejoindre pendant la digestion et ramasser : un œuf apparaît, avec un seul compte à rebours anti-vol. Ramasser à nouveau n'ajoute pas d'œuf offert.
- Voir éclore cet œuf : 500 $ sont crédités une seule fois et la boutique permet d'acheter une station.
- Quitter/revenir pendant l'incubation puis après l'éclosion : même œuf ou familier, prime jamais répétée, protection non rallongée.
- Avec deux joueurs : voler ce débutant est refusé, y compris après qu'il a porté puis lâché son familier. Ses propres interactions restent possibles.
- Faire commencer un vol valide au débutant : le compteur s'arrête, sa base redevient vulnérable et la reconnexion ne rétablit pas sa protection.
- Sur téléphone : vérifier le compteur dans le HUD avec le boost serveur, les résultats et les indications de phase visibles.

Tests hors ligne : `tools/check-eggs.luau` (profil réel en mémoire, prime, éclosion, évolution et reprise), `tools/check-newcomer-steal.luau` (contrôleur de vol réel), `tools/check-onboarding.luau` (guidage et mesures). Ils ne remplacent pas un test multijoueur dans Roblox Studio ou le jeu publié.
