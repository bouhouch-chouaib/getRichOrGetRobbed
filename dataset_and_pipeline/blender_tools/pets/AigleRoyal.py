"""Aigle Royal (Légendaire, Animaux) : « Aigle brun couronné de plumes dorées. »

En briques LEGO, très détaillé : aigle majestueux, corps brun chocolat au poitrail en écailles de plumes, tête et
collerette blanches en touffes, bec jaune vif crochu (pente + coin qui plonge), cire jaune, regard sévère (yeux or
sous un gros sourcil blanc froncé), COURONNE de plumes dorées lumineuses sur un bandeau d'or serti d'un rubis, grandes
ailes en trois rangs à pointes foncées, queue blanche en éventail, pattes jaunes à serres noires.
Parties animées : tête, ailes, queue, pattes.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    brown = kit.mat("brun", "#8A4E1C")
    mid = kit.mat("brun_moyen", "#6A3A12")
    dark = kit.mat("brun_fonce", "#3E2008")
    white = kit.mat("blanc", "#FFFFFF")
    yellow = kit.mat("bec", "#FFC21A")
    gold = kit.mat("or", "#FFD23A", metal=0.7, rough=0.18, glow=0.6)
    ruby = kit.mat("rubis", "#FF1E46", rough=0.1, glow=0.8)
    claw = kit.mat("serres", "#1A1614")

    # --- corps fier, poitrail en écailles de plumes ---
    kit.add(kit.brick((0.6, 0.62, 0.24), center=(0, 0.08, 0.42)), brown, bevel=0.03)
    kit.add(kit.brick((0.72, 0.84, 0.36), center=(0, 0.06, 0.71)), brown, bevel=0.04)
    kit.add(kit.slope((0.6, 0.18, 0.34), center=(0, -0.43, 0.7), facing="-Y", top=0.5, rot=(180, 0, 0)), brown,
            bevel=0.02)
    kit.add(kit.brick((0.6, 0.52, 0.14), center=(0, 0.0, 0.95)), brown, bevel=0.025)
    for row, z in enumerate((0.5, 0.62, 0.74, 0.86)):
        for k in range(4 - row % 2):
            kit.add(kit.wedge((0.11, 0.03, 0.08), center=((k - (3 - row % 2) / 2) * 0.13, -0.44, z), rot=(180, 0, 0),
                              tip=0.2), mid, bevel=0.0)

    # --- tête blanche, collerette, bec crochu, regard sévère, couronne ---
    for k in range(6):
        a = -150 + k * 60

        P.tuft_piece(kit, "Body", (math.sin(math.radians(a)) * 0.3, -0.1 + math.cos(math.radians(a)) * 0.2, 1.0),
                     (math.sin(math.radians(a)), math.cos(math.radians(a)) * 0.5, -0.6), 0.16, 0.12, white)
    kit.add(kit.brick((0.48, 0.5, 0.42), center=(0, -0.16, 1.22)), white, "Head", bevel=0.04)
    kit.add(kit.brick((0.18, 0.2, 0.12), center=(0, -0.5, 1.18)), yellow, "Head", bevel=0.02)
    kit.add(kit.brick((0.14, 0.08, 0.06), center=(0, -0.44, 1.27)), yellow, "Head", bevel=0.01)
    kit.add(kit.slope((0.18, 0.12, 0.1), center=(0, -0.66, 1.17), facing="-Y", top=0.3, rot=(180, 0, 0)), yellow,
            "Head", bevel=0.012)
    kit.add(kit.wedge((0.1, 0.06, 0.1), center=(0, -0.71, 1.08), rot=(180, 0, 0), tip=0.2), yellow, "Head", bevel=0.0)
    kit.add(kit.box((0.14, 0.02, 0.02), center=(0, -0.6, 1.13)), dark, "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.13, y=-0.41, z=1.27, size=0.1, iris="#FFC81E", pupil="round", lid=white, lid_drop=0.1,
           brow=white, brow_angle=22, tall=0.8)
    kit.add(kit.brick((0.46, 0.46, 0.07), center=(0, -0.14, 1.465)), gold, "Head", bevel=0.012)
    kit.add(kit.box((0.07, 0.03, 0.05), center=(0, -0.38, 1.465)), ruby, "Head", bevel=0.006)
    for x, y in ((-0.16, -0.32), (0.0, -0.34), (0.16, -0.32), (-0.19, -0.08), (0.19, -0.08), (-0.12, 0.08),
                 (0.12, 0.08)):
        kit.add(kit.wedge((0.1, 0.06, 0.18), center=(x, y, 1.58), tip=0.12), gold, "Head", bevel=0.006)

    # --- grandes ailes, queue blanche, pattes à serres ---
    P.bird_wings(kit, x=0.42, y=0.1, z=0.72, length=0.72, height=0.46, cov=brown, sec=mid, prim=dark, bar=None,
                 thick=0.12)
    P.tail_fan(kit, "Tail", (0, 0.5, 0.56), n=5, length=0.46, width=0.13, mats=[white], spread=12, pitch=-14)
    P.bird_feet(kit, x=0.17, y=0.0, h=0.3, w=0.09, color=yellow, claw=claw)
    kit.part("Head", "Head", pivot=(0, -0.12, 1.0))
    return kit.result()
