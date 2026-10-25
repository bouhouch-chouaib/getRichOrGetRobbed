"""Titan de Lave (Divin, Volcan) : « Géant de magma dont chaque pas fait trembler le volcan. »

En briques LEGO, très détaillé (Divin : or blanc et cristal, aucune lueur) : colosse de basalte noir aux épaules
massives, rivières de magma en émail orange, jaune et rouge qui coulent entre les blocs, couronne et bracelets en
OR BLANC, éclats de cristal orange plantés sur les épaules et le dos, cœur de cristal ambre au milieu du torse, visage
sévère aux yeux jaunes émaillés, poings énormes, jambes trapues. Parties animées : tête, bras, jambes.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    basalt = kit.mat("basalte", "#2A2428")
    rock = kit.mat("roche", "#4A4048")
    lava = kit.enamel("magma", "#FF5A12")
    hot = kit.enamel("magma_jaune", "#FFC21E")
    red = kit.enamel("magma_rouge", "#D81E12")
    whitegold = kit.chrome("or_blanc", tint="#F6EEDC", rough=0.14)
    shard = kit.gem("eclats", "#5A1A0A", "#FF7A2A", "#FFE0B0")
    core = kit.gem("coeur", "#8A3A0A", "#FFB43A", "#FFF4D0")

    # --- torse massif, rivières de magma, cœur de cristal ---
    kit.add(kit.brick((0.8, 0.5, 0.56), center=(0, 0, 0.86)), basalt, bevel=0.06)
    kit.add(kit.brick((0.56, 0.42, 0.24), center=(0, 0, 0.5)), basalt, bevel=0.05)
    for x, z, a, h, mat in ((-0.24, 0.9, 20, 0.36, lava), (0.24, 0.84, -25, 0.32, lava), (-0.1, 0.62, 60, 0.2, hot),
                            (0.14, 1.04, 70, 0.18, red), (0.0, 0.52, 0, 0.14, lava)):
        kit.add(kit.box((0.04, 0.012, h), center=(x, -0.256, z), rot=(0, a, 0)), mat, bevel=0.0)
    kit.add(kit.brick((0.18, 0.06, 0.18), center=(0, -0.27, 0.86), rot=(0, 45, 0)), core, bevel=0.02)
    kit.add(kit.brick((0.24, 0.04, 0.24), center=(0, -0.255, 0.86), rot=(0, 45, 0)), whitegold, bevel=0.012)
    for k in range(4):
        P.horn(kit, "Body", ((k - 1.5) * 0.16, 0.18, 1.12), ((k - 1.5) * 0.3, 0.6, 1.0), 0.2, 0.08, [shard], segments=2)

    # --- tête sévère, couronne d'or blanc ---
    kit.add(kit.brick((0.32, 0.3, 0.28), center=(0, -0.06, 1.3)), basalt, "Head", bevel=0.04)
    kit.add(kit.brick((0.34, 0.1, 0.06), center=(0, -0.18, 1.37)), rock, "Head", bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.brick((0.08, 0.03, 0.04), center=(s * 0.07, -0.215, 1.31)), hot, "Head", bevel=0.008)
    kit.add(kit.box((0.12, 0.02, 0.02), center=(0, -0.215, 1.22)), lava, "Head", bevel=0.0)
    kit.add(kit.brick((0.36, 0.34, 0.05), center=(0, -0.06, 1.46)), whitegold, "Head", bevel=0.015)
    for k in range(5):
        kit.add(kit.wedge((0.06, 0.05, 0.12), center=((k - 2) * 0.075, -0.2, 1.53), tip=0.15), whitegold, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, 0, 1.16))

    # --- épaules massives, bras, poings, bracelets ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.3, 0.36, 0.26), center=(s * 0.52, 0, 1.06)), rock, part, bevel=0.06)
        kit.add(kit.brick((0.22, 0.24, 0.34), center=(s * 0.56, 0, 0.78)), basalt, part, bevel=0.04)
        kit.add(kit.brick((0.25, 0.27, 0.06), center=(s * 0.56, 0, 0.6)), whitegold, part, bevel=0.015)
        kit.add(kit.brick((0.3, 0.32, 0.26), center=(s * 0.58, -0.02, 0.42)), rock, part, bevel=0.06)
        kit.add(kit.box((0.012, 0.03, 0.24), center=(s * 0.675, 0, 0.8), rot=(15, 0, 0)), lava, part, bevel=0.0)
        P.horn(kit, part, (s * 0.56, 0.0, 1.18), (s * 0.4, 0.2, 1.0), 0.18, 0.07, [shard], segments=2)
        kit.part(part, "Arm", pivot=(s * 0.48, 0, 1.1), phase=0.0 if s > 0 else math.pi)

    # --- jambes trapues ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.26, 0.3, 0.32), center=(s * 0.18, 0, 0.22)), basalt, part, bevel=0.05)
        kit.add(kit.brick((0.3, 0.36, 0.1), center=(s * 0.18, -0.03, 0.05)), rock, part, bevel=0.03)
        kit.add(kit.box((0.02, 0.012, 0.18), center=(s * 0.18, -0.156, 0.24), rot=(0, 20, 0)), lava, part, bevel=0.0)
        kit.part(part, "Leg", pivot=(s * 0.18, 0, 0.4), phase=0.0 if s > 0 else math.pi)
    return kit.result()
