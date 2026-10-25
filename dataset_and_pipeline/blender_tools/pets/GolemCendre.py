"""Golem de Cendre (Légendaire, Volcan) : « Bloc de roche volcanique qui fume en permanence. »

En briques LEGO, très détaillé (Légendaire : or martelé, aucune lueur) : golem trapu en basalte gris-noir (blocs
taillés, arêtes plus claires), fissures de lave en émail orange et jaune qui courent sur le torse et les bras, filons
d'OR martelé, petite tête au regard bougon (yeux orange émaillés sous un front lourd), cheminées de roche sur les
épaules d'où montent des volutes de fumée grise, gros poings. Parties animées : tête, bras, jambes, fumée.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    basalt = kit.mat("basalte", "#3E3A40")
    light = kit.mat("basalte_clair", "#6A6470")
    lava = kit.enamel("lave", "#FF6A12")
    hot = kit.enamel("lave_jaune", "#FFC21E")
    gold = kit.gold("filons", hammered=0.4)
    smoke = kit.mat("fumee", "#A8A4B0", rough=0.6)

    # --- torse et bassin de basalte, fissures de lave, filons d'or ---
    kit.add(kit.brick((0.66, 0.46, 0.5), center=(0, 0, 0.76)), basalt, bevel=0.05)
    kit.add(kit.brick((0.5, 0.4, 0.2), center=(0, 0, 0.44)), basalt, bevel=0.04)
    kit.add(kit.brick((0.58, 0.42, 0.08), center=(0, 0.0, 1.04)), light, bevel=0.025)
    for x, z, a, h, mat in ((0.1, 0.84, 25, 0.2, lava), (0.16, 0.7, -30, 0.14, hot), (-0.12, 0.78, -20, 0.22, lava),
                            (-0.06, 0.6, 35, 0.12, hot), (0.0, 0.92, 80, 0.16, lava)):
        kit.add(kit.box((0.03, 0.012, h), center=(x, -0.236, z), rot=(0, a, 0)), mat, bevel=0.0)
    kit.add(kit.box((0.04, 0.012, 0.2), center=(-0.24, -0.236, 0.82), rot=(0, 15, 0)), gold, bevel=0.0)
    kit.add(kit.box((0.18, 0.012, 0.035), center=(0.18, -0.236, 0.56), rot=(0, -10, 0)), gold, bevel=0.0)

    # --- petite tête bougonne ---
    kit.add(kit.brick((0.3, 0.28, 0.24), center=(0, -0.04, 1.18)), basalt, "Head", bevel=0.04)
    kit.add(kit.brick((0.32, 0.1, 0.06), center=(0, -0.16, 1.24)), light, "Head", bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.brick((0.07, 0.03, 0.04), center=(s * 0.07, -0.18, 1.18)), lava, "Head", bevel=0.008)
    kit.add(kit.box((0.1, 0.02, 0.02), center=(0, -0.181, 1.1)), hot, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, 0, 1.06))

    # --- épaules-cheminées et fumée ---
    for s in (-1, 1):
        kit.add(kit.brick((0.24, 0.3, 0.2), center=(s * 0.42, 0, 1.0)), light, bevel=0.04)
        kit.add(kit.brick((0.1, 0.1, 0.16), center=(s * 0.44, 0.06, 1.18)), basalt, bevel=0.02)
        kit.add(kit.brick((0.06, 0.06, 0.02), center=(s * 0.44, 0.06, 1.265)), lava, bevel=0.0)
        part = f"Smoke{0 if s > 0 else 1}"
        for k, (dz, w) in enumerate(((1.36, 0.12), (1.5, 0.1), (1.62, 0.07))):
            kit.add(kit.brick((w, w, w), center=(s * (0.44 + k * 0.03), 0.08 + k * 0.03, dz), rot=(0, 0, 25 * k)), smoke,
                    part, bevel=w * 0.25)
        kit.part(part, "Leaf", pivot=(s * 0.44, 0.06, 1.28), phase=1.0 + s)

    # --- gros bras et poings, fissures ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.2, 0.22, 0.34), center=(s * 0.46, 0, 0.72)), basalt, part, bevel=0.04)
        kit.add(kit.brick((0.26, 0.28, 0.22), center=(s * 0.48, -0.02, 0.44)), light, part, bevel=0.05)
        kit.add(kit.box((0.012, 0.03, 0.2), center=(s * 0.565, -0.02, 0.72), rot=(20, 0, 0)), lava, part, bevel=0.0)
        kit.part(part, "Arm", pivot=(s * 0.42, 0, 0.92), phase=0.0 if s > 0 else math.pi)
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.22, 0.26, 0.3), center=(s * 0.15, 0, 0.2)), basalt, part, bevel=0.04)
        kit.add(kit.brick((0.26, 0.32, 0.08), center=(s * 0.15, -0.03, 0.04)), light, part, bevel=0.025)
        kit.part(part, "Leg", pivot=(s * 0.15, 0, 0.36), phase=0.0 if s > 0 else math.pi)
    return kit.result()
