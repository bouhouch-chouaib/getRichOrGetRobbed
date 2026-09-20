# Feed The Blackhole - Game Design & Architecture

## Concept

Jeu multijoueur frénétique (méta "Brainrot / Steal"). Les joueurs apparaissent dans leurs bases, volent des objets aléatoires (Items) et les jettent dans un trou noir géant au centre de la carte. À la fin du chrono, le trou noir digère les objets et donne des familiers/récompenses RNG basés sur le score.

## Architecture Technique (Rojo)

- `src/server` &rarr; `ServerScriptService.Server`
- `src/client` &rarr; `StarterPlayerScripts.Client`
- `src/shared` &rarr; `ReplicatedStorage.Shared`

## Game Loop (GameLoopManager)

- **Feeding (60s) :** Le trou noir est violet, `CanConsume = true`. Les joueurs jettent des objets dedans.
- **Digesting (120s) :** Le trou noir est rouge, `CanConsume = false`. Calcul des scores et distribution de la RNG.

## Entités

- **BlackholeZone :** Le trou noir physique (CylinderMesh plat au sol + Aura ParticleEmitter). Écoute l'événement `.Touched` pour absorber les Items.
- **Item :** Objets physiques jetables. Possèdent un attribut "Owner" pour savoir à qui donner le point.
- **PlayerBases :** 4 bases contenant chacune SafeZone, TreadmillZone, IncubatorZone, et ItemSpawns.
