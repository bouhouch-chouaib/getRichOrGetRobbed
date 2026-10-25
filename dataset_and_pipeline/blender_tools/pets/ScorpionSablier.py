"""Scorpion Sablier (Épique, Désert) : « Sa queue est un sablier : quand le sable est tombé, il pique. »

En briques LEGO, très détaillé (Épique : chrome et cristal, aucune lueur) : scorpion couleur sable doré en plaques
articulées, ventre crème, deux grosses pinces, huit pattes fines ; sa queue segmentée se recourbe au-dessus du dos et
porte un SABLIER (montants chromés, verre en cristal, sable doré) avec un dard chromé ; yeux noirs brillants et air
malin. Parties animées : pinces, 8 pattes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    sand = kit.mat("sable", "#E0A84A")
    deep = kit.mat("sable_fonce", "#B87A2A")
    cream = kit.mat("ventre", "#FFE6B0")
    chrome = kit.chrome("chrome")
    glass = kit.gem("verre", "#7AA8C8", "#D8F0FF", "#FFFFFF")
    grain = kit.enamel("sable_dore", "#FFC83A")

    # --- corps en plaques articulées ---
    for k in range(4):
        w = 0.5 - k * 0.04
        kit.add(kit.brick((w, 0.18, 0.18), center=(0, -0.1 + k * 0.17, 0.26)), sand if k % 2 == 0 else deep, bevel=0.04)
    kit.add(kit.brick((0.4, 0.66, 0.05), center=(0, 0.14, 0.15)), cream, bevel=0.015)
    kit.add(kit.brick((0.46, 0.26, 0.2), center=(0, -0.3, 0.28)), sand, bevel=0.04)
    P.eyes(kit, "Body", x=0.09, y=-0.43, z=0.34, size=0.08, iris="#1A1210", pupil="round", lid=deep, lid_drop=0.15,
           brow=deep, brow_angle=12, tall=1.0)
    P.mouth(kit, "Body", y=-0.432, z=0.24, w=0.1, smile=0.6)

    # --- pinces ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        P.chain(kit, part, [(s * 0.22, -0.36, 0.26), (s * 0.34, -0.5, 0.26), (s * 0.34, -0.66, 0.28)], 0.08, [sand, deep])
        kit.add(kit.brick((0.16, 0.18, 0.12), center=(s * 0.34, -0.76, 0.28)), sand, part, bevel=0.03)
        kit.add(kit.wedge((0.06, 0.14, 0.08), center=(s * 0.38, -0.88, 0.3), rot=(90, 0, 0), tip=0.2), deep, part, bevel=0.0)
        kit.add(kit.wedge((0.06, 0.12, 0.06), center=(s * 0.29, -0.86, 0.26), rot=(90, 0, 0), tip=0.2), deep, part, bevel=0.0)
        kit.part(part, "Arm", pivot=(s * 0.22, -0.36, 0.26), phase=0.0 if s > 0 else math.pi)

    # --- huit pattes fines ---
    for k in range(4):
        for s in (-1, 1):
            part = f"Leg{k}{'L' if s > 0 else 'R'}"
            y = -0.14 + k * 0.15
            P.chain(kit, part, [(s * 0.2, y, 0.24), (s * 0.36, y, 0.3), (s * 0.44, y + 0.02, 0.04)], 0.04, [deep])
            kit.part(part, "Leg", pivot=(s * 0.2, y, 0.24), phase=(k % 2) * math.pi + (0 if s > 0 else math.pi))

    # --- queue recourbée et sablier ---
    pts = [(0, 0.48, 0.28), (0, 0.6, 0.42), (0, 0.64, 0.6), (0, 0.56, 0.76), (0, 0.42, 0.86)]
    P.chain(kit, "Tail", pts, 0.13, [sand, deep], taper=0.012)
    hx, hy, hz = 0.0, 0.3, 0.92
    for dz in (-0.14, 0.14):
        kit.add(kit.brick((0.18, 0.18, 0.03), center=(hx, hy, hz + dz)), chrome, "Tail", bevel=0.008)
    for dx in (-0.075, 0.075):
        kit.add(kit.box((0.02, 0.02, 0.28), center=(hx + dx, hy - 0.075, hz)), chrome, "Tail", bevel=0.0)
        kit.add(kit.box((0.02, 0.02, 0.28), center=(hx + dx, hy + 0.075, hz)), chrome, "Tail", bevel=0.0)
    kit.add(kit.wedge((0.12, 0.12, 0.12), center=(hx, hy, hz + 0.065), rot=(180, 0, 0), tip=0.2), glass, "Tail", bevel=0.0)
    kit.add(kit.wedge((0.12, 0.12, 0.12), center=(hx, hy, hz - 0.065), tip=0.2), glass, "Tail", bevel=0.0)
    kit.add(kit.brick((0.08, 0.08, 0.04), center=(hx, hy, hz - 0.1)), grain, "Tail", bevel=0.01)
    kit.add(kit.wedge((0.05, 0.05, 0.12), center=(hx, hy - 0.1, hz - 0.2), rot=(150, 0, 0), tip=0.1), chrome, "Tail", bevel=0.0)
    kit.part("Tail", "Tail", pivot=(0, 0.46, 0.28))
    return kit.result()
