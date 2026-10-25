"""Navet Peureux (Inhabituel, Plantes) : « Navet blanc qui grelotte. »

En briques LEGO, très détaillé : bulbe de navet blanc pur qui devient violet vif en haut (dégradé en couches), radicelles
claires, deux petites jambes-racines et deux bras-racines levés devant la bouche, quatre grandes feuilles vertes à
nervures qui retombent, visage terrifié (yeux immenses aux petites pupilles, sourcils relevés, bouche tremblante en
zigzag), goutte de sueur bleue. Parties animées : 4 feuilles, 2 bras, 2 jambes (il grelotte de tout son corps).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("blanc", "#FFFFFF", rough=0.2)
    cream = kit.mat("creme", "#F2ECF4", rough=0.2)
    lilac = kit.mat("lilas", "#E0A4FF")
    purple = kit.mat("violet", "#B23CF0")
    deep = kit.mat("violet_fonce", "#8A1ED2")
    root = kit.mat("racine", "#E8DCC4")
    leaf = kit.mat("feuille", "#34CC22")
    leaf2 = kit.mat("feuille_claire", "#62E23A")
    vein = kit.mat("nervure", "#C8FF8A")
    sweat = kit.mat("sueur", "#7AD2FF", rough=0.05)
    mouth = kit.mat("bouche", "#3A1A4A")

    # --- bulbe blanc qui devient violet, radicelles ---
    kit.add(kit.brick((0.3, 0.3, 0.12), center=(0, 0, 0.24)), cream, bevel=0.04)
    kit.add(kit.brick((0.46, 0.44, 0.2), center=(0, 0, 0.39)), white, bevel=0.06)
    kit.add(kit.brick((0.48, 0.46, 0.14), center=(0, 0, 0.55)), white, bevel=0.05)
    kit.add(kit.brick((0.42, 0.4, 0.1), center=(0, 0, 0.67)), lilac, bevel=0.035)
    kit.add(kit.brick((0.34, 0.32, 0.1), center=(0, 0, 0.77)), purple, bevel=0.035)
    kit.add(kit.brick((0.22, 0.2, 0.06), center=(0, 0, 0.85)), deep, bevel=0.02)
    kit.add(kit.wedge((0.1, 0.1, 0.12), center=(0, 0.02, 0.13), rot=(180, 0, 0), tip=0.1), root, bevel=0.0)
    for x, z, a in ((0.2, 0.3, 50), (-0.21, 0.36, -50), (0.18, 0.47, 70), (-0.06, 0.25, -30)):
        kit.add(kit.box((0.06, 0.012, 0.012), center=(x, -0.1, z), rot=(0, a, 0)), root, bevel=0.0)

    # --- visage terrifié : grands yeux, sourcils relevés, bouche en zigzag, sueur ---
    P.eyes(kit, "Body", x=0.1, y=-0.23, z=0.48, size=0.12, iris="#5AB4FF", pupil="round", brow=deep, brow_angle=-22,
           tall=1.2, look=(0, 0.6))
    for k in range(4):
        kit.add(kit.box((0.05, 0.02, 0.018), center=(-0.07 + k * 0.045, -0.236, 0.37), rot=(0, 30 if k % 2 else -30, 0)),
                mouth, bevel=0.0)
    kit.add(kit.wedge((0.05, 0.03, 0.08), center=(0.23, -0.16, 0.66), rot=(180, 0, 0), tip=0.2), sweat, bevel=0.0)
    kit.add(kit.brick((0.05, 0.03, 0.04), center=(0.23, -0.16, 0.6)), sweat, bevel=0.01)

    # --- quatre feuilles qui retombent ---
    for k, (dx, dy, length, mat) in enumerate(((0.55, 0.1, 0.46, leaf), (-0.55, 0.05, 0.44, leaf2), (0.2, 0.6, 0.4, leaf2),
                                               (-0.2, 0.55, 0.5, leaf))):
        part = f"Leaf{k}"
        P.leaf(kit, part, (dx * 0.1, dy * 0.1, 0.86), (dx, dy, 1.0), length, 0.17, mat, vein, normal=(0, -1, 0.3),
               droop=0.45)
        kit.part(part, "Leaf", pivot=(dx * 0.1, dy * 0.1, 0.86), phase=k * 1.3)

    # --- bras-racines levés devant la bouche, jambes-racines ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        P.chain(kit, part, [(s * 0.22, -0.04, 0.46), (s * 0.28, -0.14, 0.42), (s * 0.2, -0.24, 0.4)], 0.05, [root])
        for k in range(2):
            P.tuft_piece(kit, part, (s * 0.18, -0.27, 0.41 + k * 0.03), (-s * 0.5, -0.6, 0.3 + k * 0.4), 0.05, 0.025,
                         root)
        kit.part(part, "Arm", pivot=(s * 0.22, -0.04, 0.46), phase=0.0 if s > 0 else math.pi)
    for s, part in ((1, "LegL"), (-1, "LegR")):
        P.chain(kit, part, [(s * 0.1, 0.0, 0.26), (s * 0.11, -0.01, 0.12), (s * 0.12, -0.02, 0.04)], 0.06, [root])
        kit.add(kit.brick((0.08, 0.12, 0.04), center=(s * 0.12, -0.05, 0.02)), cream, part, bevel=0.01)
        kit.part(part, "Leg", pivot=(s * 0.1, 0.0, 0.26), phase=0.0 if s > 0 else math.pi)
    return kit.result()
