"""Phénix Solaire (Divin, Fantastiques) : « Oiseau majestueux fait de feu pur. »

En briques LEGO, très détaillé : grand oiseau de feu LUMINEUX (cœur blanc-jaune, corps orange, bords rouges), poitrail
bombé blanc-or, crête de flammes rabattue vers l'arrière, bec doré crochu, yeux noirs perçants bordés d'or, grandes
ailes déployées en trois rangs de plumes (orange, rouge, bouts jaune vif), longue traîne de cinq plumes et deux longs
rubans de feu qui ondulent, serres dorées repliées. Il vole (Float).
Parties animées : tête, ailes, queue, rubans, flammes de la crête.
"""

import math

import _parts as P
import procedural_geometry_recipes as G
from mathutils import Vector
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("coeur", "#FFF6C2", rough=0.15, glow=2.4)
    yellow = kit.mat("jaune", "#FFD21E", rough=0.15, glow=2.0)
    orange = kit.mat("orange", "#FF7A12", rough=0.15, glow=1.4)
    red = kit.mat("rouge", "#FF3A10", rough=0.15, glow=1.2)
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.2)
    black = kit.mat("noir", "#1A0E08", rough=0.1)

    # --- corps : ventre jaune, poitrail blanc-or bombé, dos orange, flancs rouges ---
    kit.add(kit.brick((0.5, 0.56, 0.22), center=(0, 0.06, 0.48)), yellow, bevel=0.03)
    kit.add(kit.brick((0.62, 0.68, 0.32), center=(0, 0.04, 0.73)), orange, bevel=0.035)
    kit.add(kit.brick((0.46, 0.12, 0.46), center=(0, -0.31, 0.66)), yellow, bevel=0.03)
    kit.add(kit.slope((0.42, 0.12, 0.14), center=(0, -0.35, 0.38), facing="-Y", top=0.3, rot=(180, 0, 0)), yellow,
            bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.5, 0.18), center=(s * 0.32, 0.06, 0.66)), red, bevel=0.012)
    kit.add(kit.slope((0.52, 0.26, 0.2), center=(0, 0.48, 0.74), facing="+Y", top=0.3), red, bevel=0.02)
    kit.add(kit.brick((0.42, 0.34, 0.16), center=(0, -0.08, 0.96)), orange, bevel=0.025)
    for k in range(3):  # plumes du poitrail en écailles
        kit.add(kit.wedge((0.12, 0.03, 0.12), center=((k - 1) * 0.13, -0.385, 0.54), rot=(0, 180, 0), tip=0.15), white,
                bevel=0.0)

    # --- tête : crête de flammes, bec doré crochu, yeux perçants bordés d'or ---
    kit.add(kit.brick((0.4, 0.4, 0.34), center=(0, -0.16, 1.18)), orange, "Head", bevel=0.035)
    kit.add(kit.brick((0.34, 0.06, 0.14), center=(0, -0.37, 1.07)), white, "Head", bevel=0.012)
    kit.add(kit.brick((0.16, 0.14, 0.1), center=(0, -0.41, 1.16)), gold, "Head", bevel=0.015)
    kit.add(kit.slope((0.14, 0.08, 0.1), center=(0, -0.5, 1.1), facing="-Y", top=0.25, rot=(180, 0, 0)), gold, "Head",
            bevel=0.01)
    P.eyes(kit, "Head", x=0.11, y=-0.37, z=1.24, size=0.1, iris="#1A0E08", pupil="square", sclera="#FFF6C2", lid=red,
           lid_drop=0.06, brow=gold, brow_angle=16, tall=0.8)
    kit.add(kit.brick((0.4, 0.4, 0.04), center=(0, -0.16, 1.37)), red, "Head", bevel=0.01)
    P.flames(kit, "Crest", (0, -0.12, 1.36), 0.38, [red, orange, yellow], n=5, spread=0.6, lean=(0.0, 0.5))
    kit.part("Crest", "Leaf", pivot=(0, -0.12, 1.38), phase=1.3)
    kit.part("Head", "Head", pivot=(0, -0.12, 1.0))

    # --- grandes ailes déployées ---
    P.spread_wings(kit, x=0.3, y=0.08, z=0.84, span=0.9, height=0.46, mats=(orange, red, yellow), style="feather",
                   sweep=25, lift=22)

    # --- traîne de cinq plumes à bouts jaunes ---
    base = Vector((0, 0.52, 0.7))
    for k in range(5):
        yaw = math.radians((k - 2) * 12)
        pitch = math.radians(-14 - abs(k - 2) * 5)
        d = Vector((math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
        length = 0.8 - abs(k - 2) * 0.12
        plume = kit.brick((0.13, 0.05, length))
        G.transform(plume, G.frame_matrix(base + d * (length / 2), d, roll_hint=(0, 0, -1)))
        kit.add(plume, (red, orange, yellow, orange, red)[k], "Tail", bevel=0.012)
        tip = kit.wedge((0.12, 0.05, 0.14), tip=0.12)
        G.transform(tip, G.frame_matrix(base + d * (length + 0.06), d, roll_hint=(0, 0, -1)))
        kit.add(tip, white if k == 2 else yellow, "Tail", bevel=0.0)
    kit.part("Tail", "Tail", pivot=tuple(base))
    # deux longs rubans de feu qui ondulent
    for s, part in ((1, "RibbonL"), (-1, "RibbonR")):
        P.chain(kit, part, [(s * 0.1, 0.5, 0.66), (s * 0.22, 0.78, 0.52), (s * 0.3, 1.02, 0.5), (s * 0.34, 1.22, 0.62),
                            (s * 0.32, 1.36, 0.8)], 0.07, [orange, red], taper=0.006)
        tip = kit.wedge((0.1, 0.05, 0.14), tip=0.12)
        G.transform(tip, G.frame_matrix(Vector((s * 0.31, 1.4, 0.9)), Vector((0, 0.3, 1.0))))
        kit.add(tip, yellow, part, bevel=0.0)
        kit.part(part, "Tail", pivot=(s * 0.1, 0.5, 0.66), phase=1.5 if s > 0 else 3.0)

    # --- serres dorées repliées (il vole) ---
    for s in (-1, 1):
        kit.add(kit.brick((0.07, 0.07, 0.14), center=(s * 0.12, 0.06, 0.3)), gold, bevel=0.012)
        for j in range(3):
            kit.add(kit.wedge((0.03, 0.03, 0.06), center=(s * 0.12 + (j - 1) * 0.03, 0.0, 0.22), rot=(150, 0, 0), tip=0.2),
                    black, bevel=0.0)
    return kit.result()
