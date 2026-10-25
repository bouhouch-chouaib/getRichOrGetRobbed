"""Alien Gélatine (Mythique, Cosmos) : « Extraterrestre gluant et fluo qui imite tout ce qu'il voit. »

En briques LEGO, très détaillé (Mythique : nacre et cristal, aucune lueur) : petit alien en gélatine vert fluo (cristal
vert pomme à facettes, plus clair sur les bords), qui coule en gouttes à la base, trois yeux ronds sur pédoncules,
antennes à boules de NACRE, grand sourire, petits bras gluants (dont un qui « imite » une main avec des doigts),
bulles et un petit bonbon coincé dedans, ceinture de soucoupe en nacre et or. Parties animées : yeux, antennes, bras.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    jelly = kit.gem("gelatine", "#1E8A2A", "#7AFF6A", "#E6FFDA")
    jelly2 = kit.gem("gelatine_claire", "#3AB43A", "#B4FF8A", "#F6FFE6")
    pearl = kit.pearl("nacre")
    gold = kit.gold("or", hammered=0.3)
    candy = kit.enamel("bonbon", "#FF4AB4")
    mouth = kit.mat("bouche", "#145A1A")

    # --- corps de gélatine qui coule ---
    kit.add(kit.brick((0.6, 0.56, 0.5), center=(0, 0, 0.38)), jelly, bevel=0.09)
    kit.add(kit.brick((0.5, 0.46, 0.2), center=(0, 0, 0.7)), jelly2, bevel=0.07)
    for x, y, h in ((0.24, -0.26, 0.14), (-0.28, -0.12, 0.1), (0.1, 0.28, 0.12), (-0.18, 0.24, 0.08)):
        kit.add(kit.brick((0.1, 0.1, h), center=(x, y, h / 2)), jelly2, bevel=0.03)
    kit.add(kit.brick((0.7, 0.66, 0.05), center=(0, 0, 0.26)), pearl, bevel=0.015)
    for k in range(8):
        a = 2 * math.pi * k / 8
        kit.add(kit.brick((0.04, 0.04, 0.04), center=(math.cos(a) * 0.35, math.sin(a) * 0.33, 0.26)), gold, bevel=0.008)
    kit.add(kit.brick((0.08, 0.04, 0.08), center=(0.14, -0.27, 0.42), rot=(0, 45, 0)), candy, bevel=0.01)
    for x, z in ((-0.16, 0.52), (0.2, 0.6)):
        kit.add(kit.brick((0.05, 0.05, 0.05), center=(x, -0.27, z)), pearl, bevel=0.015)

    # --- grand sourire ---
    kit.add(kit.brick((0.24, 0.03, 0.06), center=(0, -0.29, 0.34)), mouth, bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.02), center=(s * 0.14, -0.29, 0.37), rot=(0, s * -30, 0)), mouth, bevel=0.0)

    # --- trois yeux sur pédoncules ---
    for k, (x, h) in enumerate(((-0.16, 0.14), (0.0, 0.22), (0.16, 0.12))):
        part = f"Eye{k}"
        kit.add(kit.box((0.04, 0.04, h), center=(x, -0.08, 0.8 + h / 2)), jelly2, part, bevel=0.008)
        kit.add(kit.brick((0.12, 0.1, 0.12), center=(x, -0.1, 0.86 + h)), pearl, part, bevel=0.035)
        kit.add(kit.brick((0.05, 0.03, 0.05), center=(x, -0.16, 0.86 + h)), kit.mat("pupille", "#14141A"), part, bevel=0.008)
        kit.part(part, "Ear", pivot=(x, -0.08, 0.8), phase=float(k - 1) or 0.5)

    # --- antennes à boules de nacre ---
    for s in (-1, 1):
        part = f"Antenna{0 if s > 0 else 1}"
        P.chain(kit, part, [(s * 0.2, 0.1, 0.8), (s * 0.3, 0.14, 0.98), (s * 0.34, 0.16, 1.1)], 0.03, [jelly2])
        kit.add(kit.brick((0.08, 0.08, 0.08), center=(s * 0.35, 0.16, 1.15)), pearl, part, bevel=0.03)
        kit.part(part, "Leaf", pivot=(s * 0.2, 0.1, 0.8), phase=1.0 + s)

    # --- petits bras gluants, l'un imite une main ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        P.chain(kit, part, [(s * 0.3, -0.04, 0.44), (s * 0.44, -0.1, 0.5), (s * 0.5, -0.14, 0.62)], 0.08, [jelly, jelly2])
        kit.part(part, "Arm", pivot=(s * 0.28, -0.04, 0.44), phase=0.0 if s > 0 else math.pi)
    for k in range(4):
        kit.add(kit.brick((0.025, 0.025, 0.07), center=(0.47 + k * 0.025, -0.15, 0.7)), jelly2, "ArmL", bevel=0.006)
    return kit.result()
