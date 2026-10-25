"""Cactus Cowboy (Rare, Désert) : « Cactus au chapeau de cowboy, toujours prêt pour un duel au soleil. »

En briques LEGO, très détaillé (Rare : émail, aucune lueur) : grand cactus vert franc à côtes et épines, chapeau de
cowboy en cuir brun (bord relevé, ruban rouge), bandana rouge à pois blancs, étoile de shérif jaune émaillée,
grosse moustache noire, regard plissé de duel ; deux bras levés en « U » ; il marche sur deux bottes de cowboy à
éperons. Parties animées : bras, bottes.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.mat("cactus", "#3EB84A")
    rib = kit.mat("cotes", "#22903A")
    spine = kit.mat("epines", "#FFF0B0")
    leather = kit.enamel("cuir", "#8A4A1E")
    dark = kit.enamel("cuir_fonce", "#5A2E10")
    red = kit.enamel("bandana", "#E01E2A")
    white = kit.mat("pois", "#FFFFFF")
    star = kit.enamel("etoile", "#FFC21E")
    black = kit.mat("moustache", "#1A1210")
    spur = kit.mat("eperons", "#B8BEC8", metal=0.6, rough=0.3)

    # --- colonne de cactus, côtes, épines ---
    kit.add(kit.brick((0.34, 0.34, 0.8), center=(0, 0, 0.66)), green, bevel=0.06)
    kit.add(kit.brick((0.26, 0.26, 0.08), center=(0, 0, 1.08)), green, bevel=0.03)
    for x in (-0.09, 0.09):
        for y0 in (-0.175, 0.175):
            kit.add(kit.box((0.035, 0.02, 0.7), center=(x, y0, 0.66)), rib, bevel=0.0)
        kit.add(kit.box((0.02, 0.035, 0.7), center=(0.175, x, 0.66)), rib, bevel=0.0)
        kit.add(kit.box((0.02, 0.035, 0.7), center=(-0.175, x, 0.66)), rib, bevel=0.0)
    for x, y, z, dx, dy in ((0.18, -0.1, 0.5, 1, -0.3), (-0.18, 0.1, 0.42, -1, 0.3), (0.12, 0.18, 0.8, 0.3, 1),
                            (-0.1, 0.18, 0.56, -0.3, 1), (0.18, 0.1, 0.95, 1, 0.2), (-0.18, -0.08, 0.92, -1, -0.2)):
        P.tuft_piece(kit, "Body", (x, y, z), (dx, dy, 0.2), 0.06, 0.025, spine)

    # --- visage de duel, moustache, bandana, étoile ---
    P.eyes(kit, "Body", x=0.075, y=-0.175, z=0.9, size=0.08, iris="#1A1A1A", pupil="round", lid=rib, lid_drop=0.35,
           brow=rib, brow_angle=18, tall=1.0)
    for s in (-1, 1):
        kit.add(kit.brick((0.12, 0.05, 0.05), center=(s * 0.06, -0.19, 0.8), rot=(0, s * 12, 0)), black, bevel=0.015)
    kit.add(kit.brick((0.38, 0.38, 0.08), center=(0, 0, 0.7)), red, bevel=0.02)
    kit.add(kit.wedge((0.16, 0.04, 0.12), center=(0, -0.2, 0.62), rot=(0, 180, 0), tip=0.15), red, bevel=0.0)
    for x, z in ((-0.12, 0.71), (0.0, 0.7), (0.12, 0.71), (0.0, 0.63)):
        kit.add(kit.box((0.025, 0.012, 0.025), center=(x, -0.205 if z < 0.65 else -0.195, z)), white, bevel=0.0)
    kit.add(kit.brick((0.08, 0.03, 0.08), center=(0.1, -0.18, 0.48), rot=(0, 45, 0)), star, bevel=0.008)
    kit.add(kit.brick((0.08, 0.03, 0.08), center=(0.1, -0.18, 0.48)), star, bevel=0.008)

    # --- chapeau de cowboy ---
    kit.add(kit.brick((0.62, 0.52, 0.04), center=(0, 0, 1.13)), leather, bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.brick((0.08, 0.5, 0.06), center=(s * 0.3, 0, 1.17), rot=(0, s * -30, 0)), leather, bevel=0.012)
    kit.add(kit.brick((0.34, 0.3, 0.18), center=(0, 0, 1.24)), leather, bevel=0.04)
    kit.add(kit.box((0.04, 0.32, 0.03), center=(0, 0, 1.34)), dark, bevel=0.0)
    kit.add(kit.brick((0.35, 0.31, 0.04), center=(0, 0, 1.17)), red, bevel=0.008)

    # --- bras levés en U ---
    for s, part, z in ((1, "ArmL", 0.62), (-1, "ArmR", 0.52)):
        kit.add(kit.brick((0.18, 0.14, 0.12), center=(s * 0.25, 0, z)), green, part, bevel=0.035)
        kit.add(kit.brick((0.13, 0.13, 0.26), center=(s * 0.34, 0, z + 0.12)), green, part, bevel=0.04)
        P.tuft_piece(kit, part, (s * 0.41, 0, z + 0.16), (s, 0, 0.2), 0.06, 0.025, spine)
        kit.part(part, "Arm", pivot=(s * 0.17, 0, z), phase=0.0 if s > 0 else math.pi)

    # --- bottes de cowboy à éperons ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        x = s * 0.1
        kit.add(kit.brick((0.13, 0.16, 0.22), center=(x, 0, 0.17)), leather, part, bevel=0.03)
        kit.add(kit.brick((0.14, 0.24, 0.07), center=(x, -0.04, 0.035)), dark, part, bevel=0.02)
        kit.add(kit.wedge((0.13, 0.06, 0.06), center=(x, 0.08, 0.27), tip=0.3), dark, part, bevel=0.0)
        kit.add(kit.disc(0.03, 0.015, center=(x, 0.1, 0.05), normal=(1, 0, 0), sides=8), spur, part, bevel=0.0)
        kit.part(part, "Leg", pivot=(x, 0, 0.28), phase=0.0 if s > 0 else math.pi)
    return kit.result()
