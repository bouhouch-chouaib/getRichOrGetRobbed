"""Poisson-Ampoule (Inhabituel, Hybrides) : « Poisson jaune surmonté d'une ampoule allumée. »

En briques LEGO, très détaillé : poisson-lanterne jaune vif tout rond (ventre crème, taches orange, écailles en
plaques sur les flancs), gros yeux étonnés, bouche en O, nageoires orange ; sur le front, une tige-lanterne qui se
courbe et tient une AMPOULE allumée (verre blanc-jaune LUMINEUX, filament, culot vissé gris). Il nage dans l'air.
Parties animées : la lanterne (se balance), les nageoires, la queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    yellow = kit.mat("jaune", "#FFD21E", rough=0.15)
    deep = kit.mat("jaune_fonce", "#FFAA1E", rough=0.15)
    cream = kit.mat("ventre", "#FFF2C0")
    orange = kit.mat("orange", "#FF7A1E")
    glass = kit.mat("ampoule", "#FFF6C8", rough=0.05, glow=2.8)
    fil = kit.mat("filament", "#FF9A1E", rough=0.1, glow=3.0)
    metal = kit.mat("culot", "#B8BEC8", metal=0.8, rough=0.25)
    mouth = kit.mat("bouche", "#7A2A1E")

    # --- corps tout rond en briques, ventre, taches, écailles ---
    kit.add(kit.brick((0.56, 0.62, 0.5), center=(0, 0.0, 0.5)), yellow, bevel=0.07)
    kit.add(kit.brick((0.48, 0.5, 0.62), center=(0, 0.0, 0.5)), yellow, bevel=0.06)
    kit.add(kit.brick((0.46, 0.66, 0.4), center=(0, 0.0, 0.5)), yellow, bevel=0.06)
    kit.add(kit.brick((0.4, 0.5, 0.08), center=(0, 0.0, 0.2)), cream, bevel=0.025)
    for x, y, z in ((0.0, 0.1, 0.82), (0.14, 0.2, 0.78), (-0.12, 0.24, 0.79)):
        kit.add(kit.tile(0.08, 0.08, center=(x, y, z)), orange, bevel=0.004)
    for s in (-1, 1):
        for k in range(3):
            for j in range(2):
                kit.add(kit.box((0.02, 0.08, 0.06), center=(s * 0.285, 0.04 + k * 0.1, 0.42 + j * 0.12 + (k % 2) * 0.06)),
                        deep, bevel=0.004)

    # --- visage : gros yeux, bouche en O ---
    P.eyes(kit, "Body", x=0.13, y=-0.33, z=0.58, size=0.15, iris="#1E3A8A", pupil="round", tall=1.1, look=(0, 0.3))
    kit.add(kit.brick((0.12, 0.04, 0.1), center=(0, -0.335, 0.38)), mouth, bevel=0.02)
    kit.add(kit.brick((0.16, 0.03, 0.14), center=(0, -0.325, 0.38)), deep, bevel=0.02)

    # --- lanterne : tige courbée, culot vissé, ampoule allumée ---
    P.chain(kit, "Lure", [(0, -0.12, 0.78), (0, -0.2, 0.96), (0, -0.34, 1.06), (0, -0.48, 1.04)], 0.05, [deep, yellow])
    kit.add(kit.brick((0.1, 0.1, 0.06), center=(0, -0.5, 1.0)), metal, "Lure", bevel=0.012)
    for z in (0.95, 0.92):
        kit.add(kit.brick((0.11, 0.11, 0.015), center=(0, -0.5, z)), metal, "Lure", bevel=0.0)
    kit.add(kit.brick((0.18, 0.18, 0.18), center=(0, -0.5, 0.8)), glass, "Lure", bevel=0.05)
    kit.add(kit.brick((0.12, 0.12, 0.06), center=(0, -0.5, 0.89)), glass, "Lure", bevel=0.02)
    kit.add(kit.box((0.08, 0.02, 0.02), center=(0, -0.5, 0.8)), fil, "Lure", bevel=0.0)
    kit.part("Lure", "Leaf", pivot=(0, -0.12, 0.78), phase=0.6)

    # --- nageoires orange, queue en éventail ---
    for s, part in ((1, "FinL"), (-1, "FinR")):
        kit.add(kit.wedge((0.22, 0.04, 0.2), center=(s * 0.36, -0.06, 0.42), rot=(0, s * -70, 0), tip=0.2), orange, part,
                bevel=0.006)
        kit.part(part, "Fin", pivot=(s * 0.28, -0.06, 0.44), phase=float(s))
    kit.add(kit.wedge((0.1, 0.08, 0.2), center=(0, -0.0, 0.84), tip=0.2), orange, bevel=0.008)
    kit.add(kit.brick((0.16, 0.16, 0.16), center=(0, 0.38, 0.5)), yellow, "Tail", bevel=0.03)
    kit.add(kit.wedge((0.06, 0.24, 0.3), center=(0, 0.52, 0.64), rot=(-40, 0, 0), tip=0.2), orange, "Tail", bevel=0.008)
    kit.add(kit.wedge((0.06, 0.24, 0.3), center=(0, 0.52, 0.36), rot=(220, 0, 0), tip=0.2), orange, "Tail", bevel=0.008)
    kit.part("Tail", "SwimTail", pivot=(0, 0.32, 0.5))
    return kit.result()
