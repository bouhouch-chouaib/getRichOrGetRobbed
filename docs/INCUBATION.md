# Œufs et éclosion

Toutes les nouvelles récompenses arrivent dans la base sous forme d’œufs : manches, roue des duels, tirages Robux, fusion et effondrement du trou noir. Les échanges, vols et remboursements transfèrent toujours les familiers déjà éclos. Les anciens familiers sont conservés.

| Rareté | Modèle | Durée |
| --- | --- | --- |
| Commun | Coquille crème tachetée | 15 s |
| Inhabituel | Vignes et pousse feuillue | 30 s |
| Rare | Coquille bleue et cristaux de glace | 1 min |
| Épique | Améthyste et rune lumineuse | 3 min |
| Légendaire | Bandes dorées, couronne et rubis | 5 min |
| Mythique | Écailles, cornes et fissures de lave | 10 min |
| Divin | Coquille nacrée, plumes et auréole | 20 min |
| Sigma | Coquille sombre, fragments cosmiques et étoile | 30 min |

Les durées se règlent dans `Config.Eggs.Seconds`. Elles sont fixées à l’attribution : modifier la configuration ne redémarre pas les œufs déjà obtenus. Tous incubent en parallèle, y compris hors ligne. Au retour, les échéances terminées sont traitées après chargement de la sauvegarde.

**15 oct. (Claude) : un nid par œuf.** La couveuse au fond de la base (`shared/BaseLayout`) a 12 nids : chaque œuf a le sien, les 12 premiers à éclore sont posés et gardent leur nid jusqu’à l’éclosion ; au-delà, « +N ŒUFS EN ATTENTE » sur le panneau (attribut `Waiting`). Plusieurs œufs reçus ensemble tombent dans leurs nids l’un après l’autre. Chaque œuf affiche sa rareté, le temps restant et une barre ; il est d’autant plus gros qu’il est rare.

**Montée en tension et éclosion** (`client/Eggs`, `Config.Eggs.BuildUp`) : dans les dernières secondes (2 s pour un Commun, 7 s pour un Sigma), l’œuf tremble de plus en plus vite, s’élève, tourne et brille ; Divin et Sigma sont entourés d’éclats qui tournent. À l’éclosion (un `Remotes.EggHatched` par œuf), la coquille éclate et l’effet grandit avec la rareté (table `SPECTACLE`) : gerbe d’étincelles et éclair (tous), ondes de choc au sol (Inhabituel+), colonne de lumière (Épique+), confettis + secousse + bandeau « ÉCLOSION LÉGENDAIRE ! » (Légendaire+), rayons qui tournent + flash blanc (Mythique+), double explosion d’étoiles (Sigma). Le grand écran du familier rare (`client/Effects`) passe ensuite.

**Le familier** : s’il fait partie des familiers affichés dans la base (les 10 meilleurs), il sort de son nid et part se promener (`BasePetsController.Celebrate` avec la position du nid) ; sinon il apparaît un instant au-dessus du nid (« +1 NOM, DANS TA COLLECTION ») puis s’envole. Avant cette correction, un familier hors des 10 meilleurs disparaissait sans rien montrer.

Avant éclosion, aucun revenu, équipement, fusion, échange ou vol n’est possible. Les œufs sont pris en compte dans la limite des cinq exemplaires par familier pour la vente automatique des doublons. La découverte dans l’Index intervient à l’éclosion. L’identité du familier est tirée par le serveur à l’attribution ; l’interface montre l’œuf en attendant.

## Sauvegarde et serveur

`SessionData.eggs` contient des lots avec identifiant unique, familier, quantité, début et échéance UTC. Les anciennes sauvegardes sans ce champ restent compatibles ; le DataStore v2 est conservé. Le retrait des œufs et l’ajout des familiers s’effectuent sans suspension, dans la même opération. Les tables de sauvegarde sont copiées avant `UpdateAsync`, pour empêcher un reçu concurrent d’être enregistré sans sa récompense.

`EggController` vérifie les échéances chaque seconde et réplique un repère par œuf posé (rareté, dates, nid ; jamais le familier). Aucun événement client ne peut accélérer ou décider une éclosion. Les effets sont locaux et limités à proximité de la caméra.

## Vérification

Exécuter `lune run tools/check-eggs.luau . <dossier-sortie>` depuis le projet. Le test construit les huit modèles et exécute les vrais modules d’incubation, sauvegarde, tirages, reçus et réplication avec des services simulés. Il couvre les limites de temps, le chargement asynchrone, les anciens profils, la reconnexion, les doublons, les sauvegardes concurrentes et les échecs de sauvegarde des achats. Les avertissements de sauvegarde injectés pendant ce test sont attendus.

Un essai Studio reste nécessaire pour vérifier le rendu des particules, les étiquettes sur mobile, les animations et la synchronisation avec deux joueurs. Les vérifications hors Studio ne mesurent pas les performances graphiques.

L’Aura Astrale utilise le produit développeur `3718429232` et le déblocage permanent `Upgrade_AstralAura`, sauvegardé après validation du reçu. Son bouton se bloque pendant la validation puis indique « Possédé ». Le prix affiché est récupéré auprès de Roblox, avec 19 R$ comme valeur de secours.
