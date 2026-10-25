"""Cactus Ronchon (Commun, Plantes) : « Petit cactus grincheux dans un pot. »

En briques LEGO, très détaillé : pot en terre cuite orange vif (pied, bande plus foncée, rebord, frise blanche en
zigzag), terre sombre et cailloux ; cactus vert franc en colonne à côtes plus foncées, épines crème partout, deux bras
de hauteurs différentes, une fleur rose au sommet ; visage ronchon (paupières lourdes, sourcils froncés, bouche en
moue). Parties animées : les deux bras, la fleur.
"""

import math

import _parts as P
from pet_kit import PetKit


def _spines(kit, part, points, mat):
    for x, y, z, dx, dy in points:
        P.tuft_piece(kit, part, (x, y, z), (dx, dy, 0.25), 0.06, 0.025, mat)


def build(name: str) -> dict:
    kit = PetKit(name)
    terra = kit.mat("terre_cuite", "#F07438")
    band = kit.mat("bande", "#C2501E")
    rim = kit.mat("rebord", "#FF8E52")
    white = kit.mat("frise", "#FFF4E2")
    soil = kit.mat("terreau", "#4A2C14")
    pebble = kit.mat("caillou", "#B8BEC8")
    green = kit.mat("cactus", "#3EC24E")
    rib = kit.mat("cotes", "#22963A")
    spine = kit.mat("epines", "#FFF0B0")
    pink = kit.mat("fleur", "#FF5AAE")
    pink2 = kit.mat("fleur_claire", "#FF9AD2")
    yellow = kit.mat("coeur", "#FFD21E")

    # --- pot en terre cuite avec frise en zigzag ---
    top = P.pot(kit, "Body", 0.0, 0.56, 0.42, terra, rim=rim, band=band, soil=soil)
    for k in range(5):
        x = (k - 2) * 0.1
        kit.add(kit.box((0.06, 0.02, 0.025), center=(x, -0.262, 0.31), rot=(0, 35 if k % 2 else -35, 0)), white,
                bevel=0.0)
    for x, y in ((0.18, -0.16), (-0.2, 0.12), (0.16, 0.18)):
        kit.add(kit.brick((0.06, 0.05, 0.04), center=(x, y, top + 0.02), rot=(0, 0, 30)), pebble, bevel=0.01)

    # --- colonne de cactus à côtes, épines, visage ronchon ---
    kit.add(kit.brick((0.32, 0.32, 0.62), center=(0, 0, top + 0.31)), green, bevel=0.06)
    kit.add(kit.brick((0.24, 0.24, 0.08), center=(0, 0, top + 0.64)), green, bevel=0.035)
    for x in (-0.09, 0.09):
        kit.add(kit.box((0.035, 0.02, 0.52), center=(x, -0.165, top + 0.3)), rib, bevel=0.0)
        kit.add(kit.box((0.02, 0.035, 0.52), center=(0.165, x, top + 0.3)), rib, bevel=0.0)
        kit.add(kit.box((0.02, 0.035, 0.52), center=(-0.165, x, top + 0.3)), rib, bevel=0.0)
        kit.add(kit.box((0.035, 0.02, 0.52), center=(x, 0.165, top + 0.3)), rib, bevel=0.0)
    _spines(kit, "Body", [(0.17, -0.1, top + 0.5, 1, -0.3), (0.17, 0.1, top + 0.2, 1, 0.3), (-0.17, -0.06, top + 0.12, -1, -0.3),
                          (-0.17, 0.1, top + 0.42, -1, 0.3), (0.1, 0.17, top + 0.32, 0.3, 1), (-0.08, 0.17, top + 0.52, -0.3, 1),
                          (0.12, -0.17, top + 0.12, 0.3, -1), (-0.12, -0.17, top + 0.58, -0.3, -1),
                          (0.0, 0.17, top + 0.1, 0, 1)], spine)
    P.eyes(kit, "Body", x=0.075, y=-0.165, z=top + 0.42, size=0.09, iris="#1A1A1A", pupil="round", lid=rib,
           lid_drop=0.28, brow=kit.mat("sourcils", "#145A22"), brow_angle=24)
    P.mouth(kit, "Body", y=-0.166, z=top + 0.27, w=0.12, smile=-0.45)

    # --- deux bras de hauteurs différentes ---
    for s, part, z, h in ((1, "ArmL", top + 0.3, 0.26), (-1, "ArmR", top + 0.2, 0.2)):
        kit.add(kit.brick((0.16, 0.14, 0.12), center=(s * 0.23, 0, z)), green, part, bevel=0.035)
        kit.add(kit.brick((0.13, 0.13, h), center=(s * 0.32, 0, z + h / 2 - 0.02)), green, part, bevel=0.04)
        kit.add(kit.box((0.02, 0.03, h * 0.8), center=(s * 0.32, -0.066, z + h / 2 - 0.02)), rib, part, bevel=0.0)
        _spines(kit, part, [(s * 0.39, 0, z + h * 0.6, s, 0), (s * 0.32, -0.065, z + h * 0.25, 0, -1),
                            (s * 0.25, 0.07, z + 0.02, 0, 1)], spine)
        kit.part(part, "Arm", pivot=(s * 0.16, 0, z), phase=0.0 if s > 0 else math.pi)

    # --- fleur rose au sommet ---
    fz = top + 0.69
    P.petals(kit, "Flower", (0.05, 0.0, fz), 5, 0.12, 0.08, [pink, pink2], facing=(0, -0.3, 1), tilt=0.6)
    kit.add(kit.brick((0.06, 0.06, 0.05), center=(0.05, 0.0, fz + 0.02)), yellow, "Flower", bevel=0.01)
    kit.part("Flower", "Leaf", pivot=(0.05, 0.0, fz - 0.02), phase=0.6)
    return kit.result()
