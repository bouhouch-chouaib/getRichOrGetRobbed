"""Mouton Météore (Rare, Absurdes) : « Mouton laineux qui tombe du ciel en flammes, sans s'inquiéter. »

En briques LEGO, très détaillé (Rare : émail sur les flammes et les sabots, aucune lueur) : gros mouton tout en laine
blanche (grappes de cubes bouffants), tête et pattes noires, oreilles tombantes à intérieur rose, petite frange de
laine, yeux mi-clos tranquilles et léger sourire ; sur le dos une traînée de FLAMMES en briques émaillées (rouge,
orange, jaune) qui monte vers l'arrière, quelques mèches roussies grises. Parties animées : tête, oreilles, 4 pattes,
flammes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def _wool(kit, part, x, y, z, w, mats):
    a, b = mats
    kit.add(kit.brick((w, w, w * 0.8), center=(x, y, z)), a, part, bevel=w * 0.3)
    kit.add(kit.brick((w * 0.7, w * 0.7, w * 0.6), center=(x + w * 0.35, y - w * 0.2, z + w * 0.3)), b, part,
            bevel=w * 0.25)


def build(name: str) -> dict:
    kit = PetKit(name)
    wool = kit.mat("laine", "#FFFFFF", rough=0.5)
    wool2 = kit.mat("laine_creme", "#F2EEE6", rough=0.5)
    singed = kit.mat("roussi", "#9A969E", rough=0.5)
    black = kit.mat("noir", "#2A2630")
    pink = kit.mat("rose", "#FF9AB4")
    hoof = kit.enamel("sabots", "#1A1418")
    red = kit.enamel("flamme_rouge", "#FF3A1E")
    orange = kit.enamel("flamme", "#FF8A12")
    yellow = kit.enamel("flamme_jaune", "#FFD21E")

    # --- corps de laine en grappes ---
    kit.add(kit.brick((0.62, 0.86, 0.46), center=(0, 0.04, 0.62)), wool, bevel=0.08)
    for x in (-0.24, 0.0, 0.24):
        for y in (-0.3, -0.05, 0.2, 0.42):
            _wool(kit, "Body", x, y, 0.88 + 0.03 * math.sin(x * 9 + y * 7), 0.18, (wool, wool2))
    for s in (-1, 1):
        for y in (-0.2, 0.1, 0.38):
            _wool(kit, "Body", s * 0.32, y, 0.62, 0.16, (wool2, wool))
    for x, y in ((0.12, 0.3), (-0.2, 0.42)):
        kit.add(kit.brick((0.1, 0.1, 0.06), center=(x, y, 1.0)), singed, bevel=0.025)

    # --- traînée de flammes émaillées vers l'arrière (il tombe du ciel) ---
    for row, y in enumerate((0.2, 0.38, 0.56)):
        for col, x in enumerate((-0.18, 0.0, 0.18)):
            h = 0.22 + 0.1 * row - 0.06 * abs(col - 1)
            for j, mat in enumerate((red, orange, yellow)):
                hj = h * (1 - 0.3 * j)
                kit.add(kit.wedge((0.12 - j * 0.03, 0.08, hj), center=(x, y + 0.06 * j + hj * 0.3, 0.98 + hj * 0.32),
                                  rot=(-55, 0, 0), tip=0.1), mat, "Flames", bevel=0.0)
    kit.part("Flames", "Leaf", pivot=(0, 0.3, 1.0), phase=0.5)

    # --- tête noire, frange de laine, yeux tranquilles, oreilles ---
    kit.add(kit.brick((0.32, 0.36, 0.34), center=(0, -0.52, 0.78)), black, "Head", bevel=0.045)
    kit.add(kit.brick((0.24, 0.16, 0.16), center=(0, -0.72, 0.7)), black, "Head", bevel=0.03)
    _wool(kit, "Head", -0.06, -0.48, 1.0, 0.16, (wool, wool2))
    _wool(kit, "Head", 0.08, -0.5, 0.98, 0.13, (wool2, wool))
    P.eyes(kit, "Head", x=0.08, y=-0.705, z=0.84, size=0.08, iris="#3A2A1A", pupil="round", lid=black, lid_drop=0.3,
           tall=1.0)
    P.mouth(kit, "Head", y=-0.8, z=0.66, w=0.08, smile=0.4, color="#FF9AB4")
    for s in (-1, 1):
        kit.add(kit.box((0.03, 0.02, 0.025), center=(s * 0.04, -0.805, 0.72)), pink, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.38, 0.72))
    for s, part in ((1, "EarL"), (-1, "EarR")):
        kit.add(kit.brick((0.18, 0.08, 0.08), center=(s * 0.24, -0.5, 0.84), rot=(0, s * -25, 0)), black, part,
                bevel=0.02)
        kit.add(kit.brick((0.12, 0.02, 0.05), center=(s * 0.25, -0.545, 0.84), rot=(0, s * -25, 0)), pink, part,
                bevel=0.006)
        kit.part(part, "Ear", pivot=(s * 0.16, -0.5, 0.86), phase=float(s))

    # --- pattes noires à sabots émaillés, petite queue ---
    P.quad_legs(kit, black, yf=-0.26, yb=0.34, top_f=0.46, top_b=0.48, length_f=0.42, length_b=0.44, w=0.1, paw=hoof,
                toe=hoof, x=0.18, toes=1)
    _wool(kit, "Tail", 0, 0.5, 0.74, 0.14, (wool, wool2))
    kit.part("Tail", "Tail", pivot=(0, 0.44, 0.72))
    return kit.result()
