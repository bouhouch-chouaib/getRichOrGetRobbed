"""Gargouille Mignonne (Inhabituel, Fantastiques) : « Petite statue de pierre aux ailes de chauve-souris. »

En briques LEGO, très détaillée : petite gargouille accroupie en pierre gris-bleu (blocs taillés, fissures, plaques
de mousse vert vif), grosse tête aux petites cornes recourbées et oreilles pointues, grands yeux ambre lumineux,
sourire à deux petits crocs, ventre plus clair en plaques, ailes de chauve-souris déployées à membranes violettes,
bras et jambes trapus à griffes, queue à pointe de flèche. Parties animées : tête, ailes, bras, jambes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    stone = kit.mat("pierre", "#8C97B4")
    dark = kit.mat("pierre_fonce", "#5A6484")
    light = kit.mat("pierre_claire", "#B4BED6")
    moss = kit.mat("mousse", "#5EDB3A")
    membrane = kit.mat("membrane", "#9A5AE0")
    crack = kit.mat("fissure", "#3A4060")
    fang = kit.mat("crocs", "#FFFFFF", rough=0.15)

    # --- corps accroupi, ventre en plaques, fissures, mousse ---
    kit.add(kit.brick((0.5, 0.42, 0.42), center=(0, 0.04, 0.46)), stone, bevel=0.04)
    kit.add(kit.brick((0.44, 0.38, 0.12), center=(0, 0.04, 0.72)), stone, bevel=0.025)
    for k, z in enumerate((0.36, 0.48, 0.6)):
        kit.add(kit.brick((0.3 - k * 0.02, 0.05, 0.1), center=(0, -0.19, z)), light, bevel=0.012)
    kit.add(kit.box((0.02, 0.02, 0.18), center=(0.18, -0.2, 0.5), rot=(0, 25, 0)), crack, bevel=0.0)
    kit.add(kit.box((0.02, 0.02, 0.1), center=(0.2, -0.2, 0.4), rot=(0, -20, 0)), crack, bevel=0.0)
    kit.add(kit.tile(0.16, 0.14, center=(-0.1, 0.1, 0.785)), moss, bevel=0.005)
    kit.add(kit.box((0.03, 0.12, 0.1), center=(-0.255, 0.0, 0.58)), moss, bevel=0.005)

    # --- grosse tête : cornes, oreilles, yeux lumineux, crocs ---
    kit.add(kit.brick((0.56, 0.46, 0.44), center=(0, -0.06, 1.0)), stone, "Head", bevel=0.045)
    kit.add(kit.brick((0.5, 0.4, 0.07), center=(0, -0.05, 1.25)), dark, "Head", bevel=0.015)
    kit.add(kit.brick((0.3, 0.12, 0.14), center=(0, -0.32, 0.9)), light, "Head", bevel=0.025)
    for s in (-1, 1):
        P.horn(kit, "Head", (s * 0.18, -0.06, 1.26), (s * 0.4, 0.3, 1.0), 0.22, 0.08, [dark, dark, light], segments=3,
               curl=-0.6)
        P.ear(kit, "Head", s, (s * 0.3, -0.04, 1.02), w=0.16, h=0.2, color=stone, inner=membrane, tilt=(0, 55))
        kit.add(kit.tile(0.08, 0.06, center=(s * 0.12, -0.12, 1.29)), moss, "Head", bevel=0.004)
    P.eyes(kit, "Head", x=0.13, y=-0.29, z=1.06, size=0.14, iris="#FFB21E", pupil="slit", lid=stone, lid_drop=0.02,
           brow=dark, brow_angle=-8, glow=1.8)
    P.mouth(kit, "Head", y=-0.385, z=0.88, w=0.18, smile=0.5, fangs=fang)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.02, 0.03), center=(s * 0.05, -0.385, 0.95)), crack, "Head", bevel=0.0)

    # --- ailes de chauve-souris déployées ---
    P.spread_wings(kit, x=0.22, y=0.18, z=0.78, span=0.62, height=0.4, mats=(dark, membrane, light), style="bat",
                   sweep=25, lift=25)

    # --- bras et jambes trapus à griffes ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        x = s * 0.31
        kit.add(kit.brick((0.13, 0.14, 0.26), center=(x, -0.06, 0.52), rot=(-14, 0, 0)), stone, part, bevel=0.025)
        kit.add(kit.brick((0.12, 0.14, 0.1), center=(x, -0.14, 0.36)), dark, part, bevel=0.018)
        for k in range(3):
            kit.add(kit.wedge((0.03, 0.03, 0.05), center=(x + (k - 1) * 0.035, -0.22, 0.33), rot=(110, 0, 0), tip=0.2),
                    fang, part, bevel=0.0)
        kit.part(part, "Arm", pivot=(x, -0.04, 0.66), phase=0.0 if s > 0 else math.pi)
    for s, part in ((1, "LegL"), (-1, "LegR")):
        x = s * 0.16
        kit.add(kit.brick((0.16, 0.24, 0.2), center=(x, -0.02, 0.2)), stone, part, bevel=0.03)
        kit.add(kit.brick((0.16, 0.22, 0.08), center=(x, -0.1, 0.04)), dark, part, bevel=0.015)
        for k in range(3):
            kit.add(kit.wedge((0.035, 0.04, 0.05), center=(x + (k - 1) * 0.05, -0.23, 0.03), rot=(90, 0, 0), tip=0.2),
                    fang, part, bevel=0.0)
        kit.part(part, "Leg", pivot=(x, -0.02, 0.3), phase=0.0 if s > 0 else math.pi)

    # --- queue à pointe de flèche ---
    P.chain(kit, "Tail", [(0, 0.24, 0.3), (0, 0.42, 0.24), (0, 0.58, 0.28), (0, 0.68, 0.4)], 0.07, [stone, dark])
    kit.add(kit.wedge((0.16, 0.05, 0.16), center=(0, 0.72, 0.5), rot=(-20, 0, 0), tip=0.1), membrane, "Tail", bevel=0.008)
    kit.part("Tail", "Tail", pivot=(0, 0.22, 0.3))
    kit.part("Head", "Head", pivot=(0, -0.04, 0.78))
    return kit.result()
