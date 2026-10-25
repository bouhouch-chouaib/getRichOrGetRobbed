"""Yéti Câlin (Légendaire, Glace) : « Énorme, poilu, et il ne veut que des câlins. »

En briques LEGO, très détaillé (Légendaire : or martelé, aucune lueur) : grand yéti tout en fourrure blanche (grappes
de mèches), visage, mains et pieds bleu glacier, grands yeux attendris, grand sourire avec deux petites dents, joues
roses, bras grands ouverts pour un câlin, écharpe tricotée bleue à rayures blanches fermée par une boucle en OR
martelé, petit cœur en or sur l'écharpe. Parties animées : tête, bras (s'ouvrent), jambes.
"""

import math

import _parts as P
from pet_kit import PetKit


def _fur(kit, part, x, y, z, w, mats):
    a, b = mats
    kit.add(kit.brick((w, w, w * 0.8), center=(x, y, z)), a, part, bevel=w * 0.3)
    kit.add(kit.wedge((w * 0.6, w * 0.4, w * 0.5), center=(x + w * 0.2, y - w * 0.3, z - w * 0.4), rot=(180, 0, 0), tip=0.2),
            b, part, bevel=0.0)


def build(name: str) -> dict:
    kit = PetKit(name)
    fur = kit.mat("fourrure", "#FFFFFF", rough=0.5)
    fur2 = kit.mat("fourrure_ombre", "#E2EEFA", rough=0.5)
    ice = kit.mat("peau_glacier", "#7ACBF2")
    scarf = kit.enamel("echarpe", "#2E7CFF")
    stripe = kit.mat("rayures", "#FFFFFF")
    gold = kit.gold("boucle", hammered=0.3)
    pink = kit.mat("joues", "#FF9AB4")
    tooth = kit.mat("dents", "#FFFFFF", rough=0.15)

    # --- grand corps de fourrure ---
    kit.add(kit.brick((0.7, 0.5, 0.66), center=(0, 0, 0.66)), fur, bevel=0.08)
    for x in (-0.24, 0.0, 0.24):
        for z in (0.46, 0.7, 0.92):
            _fur(kit, "Body", x, -0.24, z, 0.16, (fur2, fur))
    kit.add(kit.brick((0.4, 0.06, 0.4), center=(0, -0.26, 0.58)), fur2, bevel=0.03)

    # --- écharpe tricotée à boucle d'or et cœur ---
    kit.add(kit.brick((0.62, 0.48, 0.1), center=(0, -0.02, 1.0)), scarf, bevel=0.03)
    for x in (-0.2, 0.0, 0.2):
        kit.add(kit.box((0.04, 0.5, 0.11), center=(x, -0.02, 1.0)), stripe, bevel=0.0)
    kit.add(kit.brick((0.1, 0.06, 0.3), center=(0.18, -0.28, 0.84)), scarf, bevel=0.02)
    kit.add(kit.brick((0.1, 0.04, 0.08), center=(0.18, -0.31, 0.98)), gold, bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.02, 0.04), center=(-0.12 + s * 0.02, -0.285, 0.86), rot=(0, s * 45, 0)), gold, bevel=0.0)
    kit.add(kit.wedge((0.06, 0.02, 0.04), center=(-0.12, -0.285, 0.83), rot=(0, 180, 0), tip=0.1), gold, bevel=0.0)

    # --- tête : visage bleu glacier, grand sourire ---
    kit.add(kit.brick((0.56, 0.46, 0.44), center=(0, -0.04, 1.28)), fur, "Head", bevel=0.08)
    for x in (-0.14, 0.0, 0.14):
        _fur(kit, "Head", x, -0.06, 1.5, 0.14, (fur, fur2))
    kit.add(kit.brick((0.36, 0.06, 0.3), center=(0, -0.27, 1.25)), ice, "Head", bevel=0.04)
    P.eyes(kit, "Head", x=0.08, y=-0.3, z=1.3, size=0.09, iris="#1E3A6A", pupil="round", tall=1.15, look=(0, 0.3))
    kit.add(kit.brick((0.16, 0.03, 0.05), center=(0, -0.305, 1.17)), kit.mat("bouche", "#3A1A3A"), "Head", bevel=0.012)
    for s in (-1, 1):
        kit.add(kit.box((0.03, 0.02, 0.03), center=(s * 0.03, -0.31, 1.19)), tooth, "Head", bevel=0.0)
        kit.add(kit.box((0.05, 0.02, 0.03), center=(s * 0.14, -0.302, 1.2)), pink, "Head", bevel=0.004)
    kit.part("Head", "Head", pivot=(0, 0, 1.06))

    # --- bras grands ouverts, mains bleues ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.36, 0.2, 0.2), center=(s * 0.5, -0.06, 0.86), rot=(0, s * -15, s * 10)), fur, part, bevel=0.06)
        kit.add(kit.brick((0.14, 0.16, 0.16), center=(s * 0.72, -0.12, 0.92)), ice, part, bevel=0.04)
        _fur(kit, part, s * 0.5, -0.12, 0.76, 0.12, (fur2, fur))
        kit.part(part, "Arm", pivot=(s * 0.34, 0, 0.9), phase=0.0 if s > 0 else math.pi)

    # --- jambes et grands pieds bleus ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.24, 0.26, 0.3), center=(s * 0.18, 0, 0.22)), fur, part, bevel=0.06)
        kit.add(kit.brick((0.24, 0.34, 0.08), center=(s * 0.18, -0.06, 0.04)), ice, part, bevel=0.03)
        kit.part(part, "Leg", pivot=(s * 0.18, 0, 0.36), phase=0.0 if s > 0 else math.pi)
    return kit.result()
