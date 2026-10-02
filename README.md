# GetRichOrGetRobbed

Jeu Roblox multijoueur — voir [GDD.md](GDD.md) pour le design et l'architecture.

## Lancer le jeu

1. Installer les outils : `aftman install` (Rojo 7.7.0).
2. Construire la place une première fois :

   ```bash
   rojo build -o "GetRichOrGetRobbed.rbxlx"
   ```

3. Ouvrir `GetRichOrGetRobbed.rbxlx` dans Roblox Studio, puis lancer la synchro :

   ```bash
   rojo serve
   ```

   et cliquer sur **Connect** dans le plugin Rojo de Studio.
4. **Play** (F5). Pour tester à plusieurs : onglet **Test** → **Clients and Servers** → 2 joueurs ou plus.

## Contrôles

- **E** : ramasser un objet
- **Clic gauche maintenu** : viser (arc de prédiction), **relâcher** : lancer. Impossible depuis sa propre base.
- Pendant la Digestion : courir sur le tapis de sa base pour gagner de la vitesse.
