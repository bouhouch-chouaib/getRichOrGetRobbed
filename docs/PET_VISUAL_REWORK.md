# Refonte des 75 familiers — 13 octobre 2026

Style : volumes rectangulaires étagés, facettes et pointes en WedgePart, tenons Roblox natifs,
yeux en plusieurs couches. Références : captures et deux vidéos fournies par Chouaib, dont
38 images extraites dans la session Codex. Les modèles sont des créations procédurales originales.

## Construction et intégration

- `PetSculpt.lua` : primitives ancrées sans collision, volumes étagés, yeux, ailes, cornes et anneaux.
- `PetSculptedModels.lua` : registre explicite des 75 Id, silhouettes et accessoires propres aux espèces.
- `PetSculptedEffects.lua` : effets élémentaires et progression visuelle de rareté.
- `PetAuraAnimator.client.lua` : animation commune à 20 Hz, particules/lumières suspendues au-delà de 110 studs et pendant l'invisibilité.
- `PetModelBuilder.BodyBounds` : dimensions du corps indépendantes des auras, conservées après `ScaleTo` et `PivotTo`.
- Base, suivi, vol, Index et révélation utilisent le même builder. Le suivi ajuste la hauteur aux dimensions et au rig R6/R15.

`Config.Pets.ModelStyle = "Sculpted"` est activé. `"Legacy"` réactive l'ancien rendu et les assets importés,
conservés sur disque. Les meshes distants ne sont pas chargés dans le mode Sculpted.
Les identifiants, raretés, revenus, sauvegardes et règles de vol ne changent pas.

Les corps gardent leurs couleurs en Plastic ; le néon sert aux incrustations, yeux élémentaires et effets.
Les communs n'ont aucun émetteur. Les autres ont au maximum trois émetteurs et 22 particules/s dans cette version.
Le maximum mesuré est 169 BaseParts par familier, décor d'aura inclus. Ces budgets ne constituent pas une mesure de FPS.

## Tailles (13 oct.)

L'échelle est dans `src/shared/PetSizes.lua` (unité J = un joueur, 5 studs ; une tranche par rareté, une taille
par familier). `PetSculptedModels.Build` applique `PetSizes.ScaleFor`. `PetMotion.lua`, requis mais absent du
commit Codex, a été ajouté (conversion des pivots d'articulation, sans animation).

## Vérification reproductible

`lune run tools/check-pets.luau . <dossier-de-sortie>` construit les 75 familiers à partir des vrais modules
avec les types Roblox de Lune. Il vérifie : couverture du catalogue et anciens Id, déterminisme, centrage,
taille de l'échelle PetSizes (tranche de la rareté, longueur limitée), pièces non physiques, budgets, dimensions après transport et déplacement.
Les méthodes Model de transformation sont simulées dans ce test : il ne remplace pas Studio.

Le fichier `tools/pet-gallery.project.json` construit une place de revue isolée :

```powershell
rojo build tools/pet-gallery.project.json -o GalerieFamiliers.rbxlx
```

Ouvrir cette place dans Studio et faire **Play** : les boutons Précédent/Suivant (ou flèches clavier)
parcourent les 75 modèles, Rotation arrête la caméra et Auras masque les effets. Aucun DataStore ni
octroi de familiers n'est utilisé. Refaire un build après toute modification des sources.

## Contrôle restant dans Roblox Studio

1. Galerie : parcourir les cinq catégories, observer de face/profil/dos et basculer les auras.
2. Dans le jeu avec Rojo connecté : Stop puis Play, vérifier l'Index et équiper un petit puis un grand familier.
3. À deux joueurs : voir un familier se déplacer, le porter après un vol, vérifier les étiquettes et le pouvoir d'invisibilité.
4. Sur mobile/émulation : surveiller les FPS dans une base pleine de rares, puis s'éloigner et revenir.

Les aperçus JPEG générés hors Studio montrent la géométrie exécutée ; ils ne simulent pas les tenons,
les particules, la transparence Roblox ni le bloom. Le rendu final et le gameplay multijoueur ne sont pas validés dans cette session.
