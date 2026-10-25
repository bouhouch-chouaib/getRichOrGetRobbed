"""Cochon-Tirelire (Inhabituel, Hybrides) : « Cochon en céramique rose avec une pièce coincée. »

En briques LEGO, très détaillé : tirelire-cochon en céramique rose bonbon brillante, fleurs peintes (pétales blancs,
cœur jaune) sur les flancs, fente noire sur le dos avec une grosse pièce d'or coincée à moitié, bouchon rouge sous le
ventre, groin à deux narines, yeux ronds rieurs, joues roses, petites oreilles en pointe, queue en tire-bouchon,
quatre petites pattes. Parties animées : oreilles, queue (frétille), 4 pattes.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    pink = kit.mat("rose", "#FF8AC0", rough=0.08)
    light = kit.mat("rose_clair", "#FFB8DA", rough=0.08)
    deep = kit.mat("rose_fonce", "#F25AA0", rough=0.08)
    white = kit.mat("fleur", "#FFFFFF", rough=0.1)
    yellow = kit.mat("coeur_fleur", "#FFD21E")
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.18)
    slot = kit.mat("fente", "#1A0E14")
    red = kit.mat("bouchon", "#FF2A3A")

    # --- corps en céramique, fleurs peintes, fente et pièce, bouchon ---
    kit.add(kit.brick((0.56, 0.84, 0.5), center=(0, 0.04, 0.5)), pink, bevel=0.08)
    kit.add(kit.brick((0.46, 0.72, 0.6), center=(0, 0.04, 0.5)), pink, bevel=0.07)
    kit.add(kit.brick((0.4, 0.6, 0.06), center=(0, 0.06, 0.82)), light, bevel=0.02)
    kit.add(kit.box((0.04, 0.24, 0.02), center=(0, 0.14, 0.86)), slot, bevel=0.0)
    kit.add(kit.disc(0.11, 0.03, center=(0, 0.14, 0.94), normal=(1, 0, 0)), gold, bevel=0.0)
    kit.add(kit.box((0.035, 0.06, 0.06), center=(0, 0.14, 0.96)), kit.mat("or_fonce", "#D8960A", metal=0.85), bevel=0.0)
    kit.add(kit.brick((0.12, 0.12, 0.04), center=(0, 0.12, 0.19)), red, bevel=0.012)
    for s in (-1, 1):
        cx = s * 0.285
        for k in range(5):
            a = math.radians(72 * k)
            kit.add(kit.box((0.02, 0.045, 0.045), center=(cx, 0.12 + math.cos(a) * 0.05, 0.52 + math.sin(a) * 0.05)), white,
                    bevel=0.0)
        kit.add(kit.box((0.022, 0.035, 0.035), center=(cx, 0.12, 0.52)), yellow, bevel=0.0)
        kit.add(kit.box((0.02, 0.03, 0.03), center=(cx, -0.08, 0.66)), white, bevel=0.0)
        kit.add(kit.box((0.02, 0.03, 0.03), center=(cx, 0.32, 0.38)), white, bevel=0.0)

    # --- groin, yeux, joues ---
    kit.add(kit.brick((0.24, 0.1, 0.18), center=(0, -0.42, 0.46)), light, bevel=0.04)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.07), center=(s * 0.05, -0.475, 0.46)), deep, bevel=0.006)
        kit.add(kit.box((0.06, 0.02, 0.04), center=(s * 0.17, -0.385, 0.48)), deep, bevel=0.005)
    P.eyes(kit, "Body", x=0.11, y=-0.37, z=0.64, size=0.09, iris="#2A1A1E", pupil="round", tall=1.15)
    P.mouth(kit, "Body", y=-0.372, z=0.34, w=0.1, smile=0.6)

    # --- oreilles en pointe ---
    for s, part in ((1, "EarL"), (-1, "EarR")):
        P.ear(kit, part, s, (s * 0.15, -0.22, 0.8), w=0.14, h=0.14, color=pink, inner=deep, tilt=(-25, 20), depth=0.05)
        kit.part(part, "Ear", pivot=(s * 0.15, -0.22, 0.8), phase=float(s))

    # --- quatre petites pattes, queue en tire-bouchon ---
    for part, x, y, ph in (("LegFL", 0.15, -0.2, 0.0), ("LegFR", -0.15, -0.2, math.pi), ("LegBL", 0.15, 0.3, math.pi),
                           ("LegBR", -0.15, 0.3, 0.0)):
        kit.add(kit.brick((0.12, 0.12, 0.2), center=(x, y, 0.12)), pink, part, bevel=0.03)
        kit.add(kit.brick((0.13, 0.13, 0.04), center=(x, y, 0.02)), deep, part, bevel=0.01)
        kit.part(part, "Leg", pivot=(x, y, 0.22), phase=ph)
    pts = []
    for k in range(7):
        a = k * 1.1
        pts.append((math.cos(a) * 0.05, 0.47 + k * 0.025, 0.56 + math.sin(a) * 0.05 + k * 0.012))
    P.chain(kit, "Tail", pts, 0.035, [pink, deep], taper=0.002)
    kit.part("Tail", "Tail", pivot=(0, 0.46, 0.56))
    return kit.result()
