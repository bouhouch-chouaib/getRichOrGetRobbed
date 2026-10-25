"""Titan Auréole (Sigma, Divin) : « Colosse de lumière, une auréole au-dessus de la tête. »

En briques LEGO, très détaillé (Sigma : or massif, or blanc et cristal, aucune lueur) : colosse en armure d'OR BLANC
(plastron, épaulières larges, jambières) rehaussée d'OR MASSIF martelé, cape en nacre, cœur de cristal ambre au
centre du torse, visage serein derrière un heaume à visière (yeux bleu ciel émaillés), grande AURÉOLE d'or massif à
rayons qui TOURNE au-dessus de la tête, poings gantés d'or. Parties animées : tête, auréole (tourne), bras, jambes.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    whitegold = kit.chrome("or_blanc", tint="#F6F0E0", rough=0.14)
    gold = kit.gold("or_massif", hammered=0.45)
    pearl = kit.pearl("cape")
    core = kit.gem("coeur", "#8A4A0A", "#FFC23A", "#FFF6D8")
    face = kit.enamel("visage", "#FFE6C8")
    eye = kit.enamel("yeux", "#3AA8FF")

    # --- plastron, cœur de cristal, cape ---
    kit.add(kit.brick((0.72, 0.46, 0.56), center=(0, 0, 0.88)), whitegold, bevel=0.06)
    kit.add(kit.brick((0.52, 0.4, 0.22), center=(0, 0, 0.52)), gold, bevel=0.04)
    kit.add(kit.brick((0.76, 0.48, 0.06), center=(0, 0, 0.62)), gold, bevel=0.015)
    kit.add(kit.brick((0.2, 0.06, 0.2), center=(0, -0.24, 0.9), rot=(0, 45, 0)), core, bevel=0.02)
    kit.add(kit.brick((0.28, 0.04, 0.28), center=(0, -0.235, 0.9), rot=(0, 45, 0)), gold, bevel=0.012)
    kit.add(kit.brick((0.66, 0.06, 0.76), center=(0, 0.27, 0.7)), pearl, bevel=0.03)

    # --- heaume à visière, visage serein ---
    kit.add(kit.brick((0.34, 0.32, 0.32), center=(0, -0.02, 1.32)), whitegold, "Head", bevel=0.05)
    kit.add(kit.brick((0.24, 0.04, 0.16), center=(0, -0.18, 1.3)), face, "Head", bevel=0.02)
    for s in (-1, 1):
        kit.add(kit.brick((0.06, 0.03, 0.04), center=(s * 0.06, -0.2, 1.33)), eye, "Head", bevel=0.008)
    kit.add(kit.brick((0.36, 0.06, 0.04), center=(0, -0.18, 1.4)), gold, "Head", bevel=0.012)
    kit.add(kit.wedge((0.08, 0.3, 0.14), center=(0, -0.02, 1.52), tip=0.2), gold, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, 0, 1.16))
    # --- auréole d'or massif à rayons qui tourne ---
    for k in range(16):
        a = 2 * math.pi * k / 16
        kit.add(kit.brick((0.1, 0.05, 0.04), center=(math.cos(a) * 0.3, 0.06 + math.sin(a) * 0.3, 1.72),
                          rot=(0, 0, math.degrees(a) + 90)), gold, "Halo", bevel=0.008)
        if k % 2 == 0:
            kit.add(kit.wedge((0.05, 0.04, 0.1), center=(math.cos(a) * 0.38, 0.06 + math.sin(a) * 0.38, 1.72),
                              rot=(90, 0, math.degrees(a) - 90), tip=0.1), gold, "Halo", bevel=0.0)
    kit.part("Halo", "Orbit", pivot=(0, 0.06, 1.72), phase=0.5)

    # --- épaulières, bras, poings d'or ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.3, 0.36, 0.16), center=(s * 0.48, 0, 1.14)), gold, part, bevel=0.05)
        kit.add(kit.brick((0.2, 0.22, 0.36), center=(s * 0.5, 0, 0.84)), whitegold, part, bevel=0.04)
        kit.add(kit.brick((0.24, 0.26, 0.2), center=(s * 0.52, -0.02, 0.56)), gold, part, bevel=0.05)
        kit.part(part, "Arm", pivot=(s * 0.44, 0, 1.08), phase=0.0 if s > 0 else math.pi)

    # --- jambières ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.22, 0.26, 0.36), center=(s * 0.16, 0, 0.24)), whitegold, part, bevel=0.04)
        kit.add(kit.brick((0.24, 0.28, 0.06), center=(s * 0.16, 0, 0.38)), gold, part, bevel=0.015)
        kit.add(kit.brick((0.26, 0.34, 0.08), center=(s * 0.16, -0.03, 0.04)), gold, part, bevel=0.025)
        kit.part(part, "Leg", pivot=(s * 0.16, 0, 0.44), phase=0.0 if s > 0 else math.pi)
    return kit.result()
