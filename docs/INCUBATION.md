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

Un socle par rareté regroupe les œufs de cette rareté, affiche leur quantité et le compte à rebours de la prochaine éclosion. Cela limite l’affichage à huit modèles par base. Les coquilles se balancent, les raretés élevées flottent et émettent des particules. Elles tremblent dans les cinq dernières secondes puis se séparent avec une gerbe lumineuse. Les familiers rejoignent alors l’inventaire ; les dix espèces admissibles de la base suivent les règles habituelles d’affichage.

Avant éclosion, aucun revenu, équipement, fusion, échange ou vol n’est possible. Les œufs sont pris en compte dans la limite des cinq exemplaires par familier pour la vente automatique des doublons. La découverte dans l’Index intervient à l’éclosion. L’identité du familier est tirée par le serveur à l’attribution ; l’interface montre l’œuf en attendant.

## Sauvegarde et serveur

`SessionData.eggs` contient des lots avec identifiant unique, familier, quantité, début et échéance UTC. Les anciennes sauvegardes sans ce champ restent compatibles ; le DataStore v2 est conservé. Le retrait des œufs et l’ajout des familiers s’effectuent sans suspension, dans la même opération. Les tables de sauvegarde sont copiées avant `UpdateAsync`, pour empêcher un reçu concurrent d’être enregistré sans sa récompense.

`EggController` vérifie les échéances chaque seconde et réplique uniquement les socles, raretés, quantités et dates. Aucun événement client ne peut accélérer ou décider une éclosion. Les effets sont locaux et limités à proximité de la caméra.

## Vérification

Exécuter `lune run tools/check-eggs.luau . <dossier-sortie>` depuis le projet. Le test construit les huit modèles et exécute les vrais modules d’incubation, sauvegarde, tirages, reçus et réplication avec des services simulés. Il couvre les limites de temps, le chargement asynchrone, les anciens profils, la reconnexion, les doublons, les sauvegardes concurrentes et les échecs de sauvegarde des achats. Les avertissements de sauvegarde injectés pendant ce test sont attendus.

Un essai Studio reste nécessaire pour vérifier le rendu des particules, les étiquettes sur mobile, les animations et la synchronisation avec deux joueurs. Les vérifications hors Studio ne mesurent pas les performances graphiques.

L’Aura Astrale utilise le produit développeur `3718429232` et le déblocage permanent `Upgrade_AstralAura`, sauvegardé après validation du reçu. Son bouton se bloque pendant la validation puis indique « Possédé ». Le prix affiché est récupéré auprès de Roblox, avec 19 R$ comme valeur de secours.
