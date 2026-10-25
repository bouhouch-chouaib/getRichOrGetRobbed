"""T-Rex Tank (Mythique, Hybrides) : « Dino cyborg avec un canon de char sur le dos. »

En briques LEGO, très détaillé : T-Rex vert camouflage (taches vert foncé et kaki), plaques de blindage grises
rivetées sur le dos et les cuisses, œil cyborg rouge LUMINEUX dans une monture métallique (l'autre œil jaune
furieux), grande gueule à dents qui s'ouvre, petits bras à pinces métalliques, grosses pattes, queue à plaques ; sur
le dos une TOURELLE de char avec un long canon qui balaie l'horizon, trappe et antenne. Parties animées : tête,
mâchoire, bras, jambes, queue, tourelle.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.mat("vert", "#4EA83A")
    camo = kit.mat("camo", "#2E6A26")
    khaki = kit.mat("kaki", "#9AA84A")
    belly = kit.mat("ventre", "#C8D88A")
    armor = kit.mat("blindage", "#7A8292", metal=0.7, rough=0.3)
    dark = kit.mat("metal_fonce", "#3E4452", metal=0.7, rough=0.3)
    red = kit.mat("oeil_cyborg", "#FF2A2A", rough=0.1, glow=2.8)
    teeth = kit.mat("dents", "#FFFFFF", rough=0.15)
    mouth = kit.mat("gueule", "#7A1E2A")

    # --- corps penché, ventre, taches de camouflage, plaques de blindage ---
    kit.add(kit.brick((0.56, 0.7, 0.5), center=(0, 0.06, 0.82), rot=(-15, 0, 0)), green, bevel=0.06)
    kit.add(kit.brick((0.42, 0.1, 0.4), center=(0, -0.3, 0.76), rot=(-15, 0, 0)), belly, bevel=0.03)
    for x, y, z in ((0.2, -0.05, 0.96), (-0.22, 0.2, 0.86), (0.25, 0.3, 0.74), (-0.18, -0.15, 0.7)):
        kit.add(kit.box((0.04, 0.16, 0.12), center=(math.copysign(0.28, x), y, z)), camo if x > 0 else khaki, bevel=0.008)
    for k in range(3):
        kit.add(kit.brick((0.5, 0.18, 0.05), center=(0, -0.1 + k * 0.2, 1.08 - k * 0.05), rot=(-15, 0, 0)), armor,
                bevel=0.015)
        for s in (-1, 1):
            kit.add(kit.box((0.03, 0.03, 0.03), center=(s * 0.2, -0.1 + k * 0.2, 1.11 - k * 0.05)), dark, bevel=0.0)

    # --- tête : œil cyborg, gueule à dents ---
    kit.add(kit.brick((0.5, 0.6, 0.34), center=(0, -0.56, 1.24)), green, "Head", bevel=0.05)
    kit.add(kit.brick((0.44, 0.5, 0.06), center=(0, -0.56, 1.43)), camo, "Head", bevel=0.015)
    kit.add(kit.brick((0.44, 0.36, 0.08), center=(0, -0.7, 1.08)), mouth, "Head", bevel=0.012)
    for k in range(5):
        kit.add(kit.wedge((0.05, 0.035, 0.07), center=((k - 2) * 0.09, -0.86, 1.06), rot=(180, 0, 0), tip=0.15), teeth,
                "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.13, y=-0.86, z=1.3, size=0.1, iris="#FFD21E", pupil="slit", lid=green, lid_drop=0.12,
           brow=camo, brow_angle=22, tall=0.85)
    # œil cyborg : monture métallique et lentille rouge par-dessus l'œil gauche
    kit.add(kit.brick((0.12, 0.06, 0.16), center=(0.13, -0.87, 1.3)), armor, "Head", bevel=0.02)
    kit.add(kit.brick((0.07, 0.03, 0.07), center=(0.13, -0.905, 1.3)), red, "Head", bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.03, 0.03), center=(s * 0.06, -0.865, 1.38)), camo, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.36, 1.12))
    kit.add(kit.brick((0.46, 0.5, 0.1), center=(0, -0.6, 0.98)), green, "Jaw", bevel=0.025)
    kit.add(kit.brick((0.38, 0.38, 0.03), center=(0, -0.62, 1.04)), mouth, "Jaw", bevel=0.0)
    for k in range(4):
        kit.add(kit.wedge((0.045, 0.035, 0.06), center=((k - 1.5) * 0.09, -0.83, 1.06), tip=0.15), teeth, "Jaw", bevel=0.0)
    kit.part("Jaw", "Jaw", pivot=(0, -0.4, 1.06), follows="Head")

    # --- petits bras à pinces ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.08, 0.16, 0.08), center=(s * 0.27, -0.4, 0.9), rot=(-30, 0, 0)), green, part, bevel=0.02)
        for k in (-1, 1):
            kit.add(kit.wedge((0.03, 0.03, 0.07), center=(s * 0.27 + k * 0.025, -0.5, 0.84), rot=(150, 0, 0), tip=0.2),
                    armor, part, bevel=0.0)
        kit.part(part, "Arm", pivot=(s * 0.25, -0.34, 0.96), phase=0.0 if s > 0 else math.pi)

    # --- grosses pattes blindées ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.22, 0.32, 0.36), center=(s * 0.26, 0.12, 0.62)), green, part, bevel=0.05)
        kit.add(kit.brick((0.06, 0.24, 0.24), center=(s * 0.38, 0.12, 0.64)), armor, part, bevel=0.02)
        kit.add(kit.brick((0.14, 0.16, 0.34), center=(s * 0.26, 0.16, 0.24)), green, part, bevel=0.03)
        kit.add(kit.brick((0.2, 0.3, 0.08), center=(s * 0.26, 0.06, 0.04)), camo, part, bevel=0.02)
        for k in range(3):
            kit.add(kit.wedge((0.04, 0.04, 0.06), center=(s * 0.26 + (k - 1) * 0.06, -0.12, 0.04), rot=(90, 0, 0), tip=0.2),
                    teeth, part, bevel=0.0)
        kit.part(part, "Leg", pivot=(s * 0.26, 0.12, 0.78), phase=0.0 if s > 0 else math.pi)

    # --- queue à plaques ---
    P.chain(kit, "Tail", [(0, 0.38, 0.74), (0, 0.62, 0.66), (0, 0.86, 0.6), (0, 1.06, 0.58)], 0.26, [green, camo],
            taper=0.06)
    for k in range(3):
        kit.add(kit.brick((0.16 - k * 0.03, 0.12, 0.04), center=(0, 0.5 + k * 0.22, 0.83 - k * 0.07)), armor, "Tail",
                bevel=0.01)
    kit.part("Tail", "Tail", pivot=(0, 0.36, 0.74))

    # --- tourelle de char qui balaie, canon (au-dessus de la tête), trappe, antenne ---
    kit.add(kit.brick((0.16, 0.16, 0.24), center=(0, 0.1, 1.2)), armor, bevel=0.02)
    kit.add(kit.brick((0.4, 0.42, 0.16), center=(0, 0.1, 1.44)), armor, "Turret", bevel=0.03)
    kit.add(kit.brick((0.3, 0.3, 0.06), center=(0, 0.12, 1.55)), dark, "Turret", bevel=0.015)
    kit.add(kit.disc(0.07, 0.03, center=(0.08, 0.16, 1.59), normal=(0, 0, 1), sides=8), armor, "Turret", bevel=0.0)
    kit.add(kit.brick((0.08, 0.6, 0.08), center=(0, -0.42, 1.51)), dark, "Turret", bevel=0.015)
    kit.add(kit.brick((0.11, 0.08, 0.11), center=(0, -0.72, 1.51)), armor, "Turret", bevel=0.015)
    kit.add(kit.box((0.015, 0.015, 0.3), center=(-0.12, 0.24, 1.66)), dark, "Turret", bevel=0.0)
    kit.part("Turret", "Turret", pivot=(0, 0.1, 1.44))
    return kit.result()
