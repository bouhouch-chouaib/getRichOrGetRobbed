"""Pousse de Haricot (Commun, Plantes) : « Tige verte sortant d'un tas de terre, avec des yeux. »

En briques LEGO, très détaillée : petit tas de terre en couches (terre claire, mottes, cailloux gris, brins d'herbe),
d'où sort une tige vert vif qui se courbe ; au bout, une tête-haricot vert tendre avec grands yeux brillants, sourire et
joues roses, coiffée de la peau du haricot tombée de travers comme un petit chapeau, deux cotylédons en feuilles
sur le dessus et une petite feuille sur la tige. Partie animée : toute la pousse (« Head ») se balance et regarde.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    dirt = kit.mat("terre", "#9A6436")
    dark = kit.mat("terre_fonce", "#6A3E1C")
    clod = kit.mat("motte", "#B87A42")
    pebble = kit.mat("caillou", "#A8AEB8")
    grass = kit.mat("herbe", "#4ED62E")
    stem = kit.mat("tige", "#4ED62E")
    bean = kit.mat("haricot", "#B4F26A")
    coat = kit.mat("peau_haricot", "#C8783A")
    leaf = kit.mat("feuille", "#2EC81E")
    vein = kit.mat("nervure", "#C8FF8A")
    pink = kit.mat("joues", "#FF8FB0")

    # --- tas de terre en couches, mottes, cailloux, brins d'herbe ---
    kit.add(kit.brick((0.9, 0.84, 0.14), center=(0, 0, 0.07)), dark, bevel=0.035)
    kit.add(kit.brick((0.72, 0.68, 0.12), center=(0.02, 0.0, 0.19)), dirt, bevel=0.03)
    kit.add(kit.brick((0.48, 0.46, 0.1), center=(0, 0.02, 0.29)), dirt, bevel=0.025)
    for x, y, z, w in ((0.3, -0.24, 0.17, 0.12), (-0.32, 0.12, 0.17, 0.1), (0.18, 0.26, 0.27, 0.09),
                       (-0.16, -0.2, 0.28, 0.08), (0.38, 0.18, 0.08, 0.1)):
        kit.add(kit.brick((w, w, w * 0.7), center=(x, y, z), rot=(0, 0, 25)), clod, bevel=0.015)
    for x, y, w in ((-0.36, -0.26, 0.08), (0.24, -0.36, 0.06), (-0.4, 0.3, 0.07)):
        kit.add(kit.brick((w, w * 0.8, w * 0.6), center=(x, y, 0.16), rot=(0, 0, 40)), pebble, bevel=0.012)
    for x, y in ((0.36, -0.3), (-0.3, -0.34), (0.42, 0.06)):
        for k in range(3):
            P.tuft_piece(kit, "Body", (x + (k - 1) * 0.025, y, 0.14), ((k - 1) * 0.4, 0.0, 1.0), 0.1, 0.03, grass)

    # --- la pousse : tige courbée, tête-haricot, peau en chapeau, cotylédons, petite feuille ---
    P.chain(kit, "Head", [(0, 0.02, 0.3), (0.0, 0.0, 0.48), (0.03, -0.03, 0.64), (0.02, -0.06, 0.74)], 0.12, [stem])
    P.leaf(kit, "Head", (0.06, -0.01, 0.5), (1.0, 0.1, 0.45), 0.24, 0.13, leaf, vein, normal=(0, -0.3, 1), droop=0.3)
    kit.add(kit.brick((0.44, 0.34, 0.36), center=(0.02, -0.08, 0.9), rot=(0, 6, 0)), bean, "Head", bevel=0.06)
    kit.add(kit.brick((0.36, 0.06, 0.28), center=(0.02, -0.25, 0.9), rot=(0, 6, 0)), bean, "Head", bevel=0.03)
    kit.add(kit.brick((0.32, 0.28, 0.08), center=(-0.04, 0.0, 1.1), rot=(0, -18, 8)), coat, "Head", bevel=0.025)
    kit.add(kit.box((0.04, 0.24, 0.02), center=(-0.04, 0.0, 1.145), rot=(0, -18, 8)), dark, "Head", bevel=0.0)
    for s in (-1, 1):
        P.leaf(kit, "Head", (0.06 + s * 0.04, -0.06, 1.08), (s * 0.9, 0.1, 0.8), 0.34, 0.18, leaf, vein,
               normal=(0, -0.4, 1), droop=0.4)
    P.eyes(kit, "Head", x=0.095, y=-0.28, z=0.94, size=0.11, iris="#2A7A1E", pupil="round", tall=1.1, at=0.025)
    P.mouth(kit, "Head", y=-0.28, z=0.82, w=0.13, smile=0.6, x=0.025)
    for s in (-1, 1):
        kit.add(kit.box((0.06, 0.02, 0.04), center=(0.025 + s * 0.16, -0.285, 0.86)), pink, "Head", bevel=0.005)
    kit.part("Head", "Head", pivot=(0, 0.02, 0.3))
    return kit.result()
