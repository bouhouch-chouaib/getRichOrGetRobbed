# Test réel avant la sortie (PLAN étape 15)

> Préparé le 11 octobre 2026. À faire sur le **vrai jeu publié** (pas dans Studio), jeu encore **privé**.
> Il faut : ton compte + 1 ou 2 comptes secondaires, un PC et un téléphone.
> Coche chaque ligne. Si quelque chose rate : capture d'écran + console (F9 sur PC → onglet Server et Client).

## 0. Préparation

- [ ] **Publier la dernière version** : Studio → Fichier → Publier sur Roblox (Rojo met le code dans Studio, mais le vrai jeu
      ne change qu'après « Publier »).
- [ ] Taille du serveur = **8** (Creator Hub → Lieux → le lieu → Accès). Vérifier après coup dans Studio :
      Paramètres du jeu → Lieux.
- [ ] Donner l'accès au jeu privé aux comptes secondaires : Creator Hub → Collaborateurs (ou jeu en « Amis seulement »
      si les comptes sont amis).
- [ ] Les comptes secondaires n'ont jamais joué : ils doivent voir le **tutoriel**.

## 1. Un seul joueur (PC)

- [ ] Arrivée : base attribuée, nom sur le panneau, 5 objets dans la base, tutoriel en 4 étapes (ramasser, lancer, recevoir un œuf, voir son éclosion).
- [ ] Ramasser [E], viser (clic gauche maintenu), lancer : l'objet tombe dans le trou → points.
- [ ] Fin de la nuit : tirages, œufs dans la couveuse, carte de résultats. Le tutoriel continue jusqu’à la vraie éclosion.
- [ ] Revenu d'argent qui monte, boutique (tapis, banc, sac, chance, verrou long), fusion.
- [ ] Sons et musique (nuit / jour) : volume correct, rien de gênant.
- [ ] **Quitter puis revenir** : argent, familiers, niveaux et équipement sont **conservés**, le tutoriel ne revient pas.

## 2. Deux joueurs (PC + téléphone, ou 2 PC)

- [ ] Les deux voient les mêmes familiers au même endroit dans chaque base.
- [ ] **Vol** pendant la digestion (jour) : [E] sur un familier adverse → porté au-dessus de la tête, voleur ralenti.
  - [ ] Ramené dans sa base → le familier change de propriétaire, chez les deux joueurs, après reconnexion aussi.
  - [ ] La victime appuie sur [E] « Reprendre » près du voleur → le familier revient.
  - [ ] Vol impossible pendant la nuit et quand la base est verrouillée.
  - [ ] Après 30 s sans arriver → vol annulé, familier rendu.
  - [ ] La victime quitte le jeu pendant le vol → vol annulé.
- [ ] Bouton de verrouillage : l'intrus est expulsé, le portail se ferme.
- [ ] Tableau « LES PLUS RICHES » (entre la 2e et la 3e base) : les deux joueurs apparaissent après ~1 minute.
- [ ] Liste des joueurs (Tab) : le plus riche est en haut.

## 3. Téléphone

- [ ] Interface lisible, rien ne déborde de l'écran.
- [ ] Bouton LANCER : viser et lancer au doigt.
- [ ] Bulles [E] faciles à toucher (ramasser, voler, reprendre, boutique, fusion).
- [ ] Le jeu reste fluide pendant plusieurs manches (pas d'échauffement ou de saccades fortes).

## 4. Sauvegarde et anti-duplication

- [ ] Jouer, gagner un familier, puis **rejoindre tout de suite un autre serveur** (quitter + relancer) :
      la progression suit, aucun familier en double.
- [ ] Rejoindre le même compte sur 2 appareils en même temps : le second attend (« sauvegarde ouverte ailleurs »)
      ou le premier est déconnecté, jamais deux copies qui jouent.

## 5. Achats Robux (compte secondaire, car le créateur possède déjà ses passes)

- [ ] Acheter le **Tirage instantané** (49 R$, le moins cher) : le familier tombe dans la base, un seul tirage reçu.
- [ ] Quitter / revenir : le familier est toujours là et l'achat n'est pas redonné.
- [ ] (Facultatif) Un passe pas cher : **Sac à dos +1** (149 R$) → sac à 1 objet de plus, bouton « POSSÉDÉ ».
- Les Robux dépensés par un compte secondaire reviennent en partie au créateur (moins la part de Roblox).

## 6. À la fin

- [ ] Lister les problèmes trouvés et me les envoyer (avec les erreurs de la console F9).
- [ ] Une fois tout corrigé : décider s'il faut effacer les progressions des tests (`Config.Save.Version` = 3,
      tout le monde repart de zéro, y compris le tableau des plus riches).
- [ ] Remplir la page du jeu (`docs/PAGE_DU_JEU.md`), puis **rendre le jeu public**.
