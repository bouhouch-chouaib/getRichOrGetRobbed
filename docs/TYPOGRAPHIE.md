# Typographie commune

La référence GUI fournie le 16 octobre 2026 est reproduite avec **Montserrat Black** : lettres géométriques très grasses, droites, contours sombres arrondis. L'identification depuis une capture reste visuelle ; Roblox remplace désormais l'ancien Gotham Black par Montserrat.

`src/shared/Typography.lua` définit une seule `FontFace` : `rbxasset://fonts/families/Montserrat.json`, graisse `Heavy`, style `Normal`. Menus, chiffres, saisie de codes, tutoriel, notifications, panneaux, classement, noms de familiers, œufs et textes d'effets utilisent cette définition. La galerie des familiers utilise aussi cette police.

- Titres et actions : blanc avec contour sombre.
- Explications : blanc cassé, contour plus fin selon la taille.
- Argent, vitesse, force et raretés : leurs couleurs existantes sont conservées.
- Boutons : marges intérieures et réduction de taille plafonnée pour les libellés longs.
- Paragraphes à hauteur automatique : retours à la ligne conservés, sans réduction automatique de police.

`PromptStyle.client.lua` habille aussi les ProximityPrompts avec cette police, une touche colorée et une barre d'appui. La visibilité, l'exclusivité, les touches et les durées d'appui restent contrôlées par Roblox ; les contrôles serveur existants restent en place. Les menus système Roblox (Échap, chat et interfaces d'achat Roblox) sont gérés par Roblox et ne sont pas modifiés.

Vérification hors Studio : `lune run tools/check-typography.luau <chemin-projet>` contrôle la police, les contraintes de taille, les paragraphes automatiques et les interactions clavier/manette/tactile avec des services simulés. L'analyse Luau et la construction Rojo complètent cette vérification. Un essai Studio reste nécessaire pour contrôler le rendu réel et la disposition sur téléphone.

Sources Roblox : [Font](https://create.roblox.com/docs/reference/engine/datatypes/Font), [correspondance des anciennes polices](https://create.roblox.com/docs/reference/engine/enums/Font), [ProximityPrompts](https://create.roblox.com/docs/ui/proximity-prompts).
