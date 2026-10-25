"""Dragon Barbecue (Mythique, Volcan) : « Dragon cuisinier : sa grille est toujours chaude. »

En briques LEGO, très détaillé (Mythique : nacre et or, aucune lueur) : dragon rouge vif dodu, ventre jaune à plaques,
toque de chef en NACRE immense, tablier blanc à liseré rouge, petite moustache de chef ; il tient une spatule en OR
dans une patte et porte sur le ventre une grille de barbecue noire avec deux saucisses et un épi de maïs ; cornes
dorées, petites ailes, gueule souriante qui s'ouvre, queue à pointe. Parties animées : tête, mâchoire, bras
(spatule), ailes, jambes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    red = kit.enamel("dragon", "#E0281E")
    deep = kit.enamel("dragon_fonce", "#A8140E")
    belly = kit.mat("ventre", "#FFC83A")
    pearl = kit.pearl("toque")
    apron = kit.mat("tablier", "#FFFFFF")
    gold = kit.gold("or", hammered=0.3)
    grill = kit.mat("grille", "#24242C", metal=0.5, rough=0.4)
    sausage = kit.mat("saucisse", "#C8643A")
    corn = kit.enamel("mais", "#FFD21E")
    teeth = kit.mat("dents", "#FFFFFF", rough=0.15)

    # --- corps dodu, ventre à plaques, tablier, grille ---
    kit.add(kit.brick((0.6, 0.5, 0.56), center=(0, 0, 0.6)), red, bevel=0.07)
    for k in range(4):
        kit.add(kit.brick((0.36 - abs(k - 1.5) * 0.04, 0.05, 0.1), center=(0, -0.26, 0.42 + k * 0.11)), belly, bevel=0.015)
    kit.add(kit.brick((0.46, 0.04, 0.44), center=(0, -0.29, 0.56)), apron, bevel=0.015)
    kit.add(kit.box((0.48, 0.045, 0.03), center=(0, -0.29, 0.79)), red, bevel=0.0)
    kit.add(kit.brick((0.4, 0.03, 0.22), center=(0, -0.32, 0.54)), grill, bevel=0.01)
    for k in range(4):
        kit.add(kit.box((0.38, 0.02, 0.012), center=(0, -0.34, 0.46 + k * 0.055)), kit.mat("barreaux", "#5A5A66", metal=0.5),
                bevel=0.0)
    for x in (-0.1, 0.04):
        kit.add(kit.brick((0.12, 0.05, 0.05), center=(x, -0.36, 0.56)), sausage, bevel=0.02)
    kit.add(kit.brick((0.06, 0.05, 0.14), center=(0.15, -0.36, 0.54)), corn, bevel=0.015)

    # --- tête : museau, moustache de chef, cornes dorées, toque de nacre ---
    kit.add(kit.brick((0.42, 0.4, 0.34), center=(0, -0.1, 1.06)), red, "Head", bevel=0.05)
    kit.add(kit.brick((0.3, 0.2, 0.14), center=(0, -0.36, 1.02)), red, "Head", bevel=0.03)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.02, 0.03), center=(s * 0.07, -0.465, 1.06)), deep, "Head", bevel=0.0)
        kit.add(kit.brick((0.12, 0.05, 0.04), center=(s * 0.07, -0.47, 0.99), rot=(0, s * -20, 0)), kit.mat("moustache", "#3A1A0E"),
                "Head", bevel=0.012)
        P.horn(kit, "Head", (s * 0.15, -0.04, 1.22), (s * 0.4, 0.5, 0.8), 0.16, 0.06, [gold], segments=2)
    P.eyes(kit, "Head", x=0.1, y=-0.31, z=1.13, size=0.1, iris="#2A1A0E", pupil="round", tall=1.1)
    kit.add(kit.brick((0.4, 0.38, 0.08), center=(0, -0.1, 1.26)), pearl, "Head", bevel=0.02)
    kit.add(kit.brick((0.36, 0.34, 0.2), center=(0, -0.1, 1.38)), pearl, "Head", bevel=0.05)
    for s in (-1, 0, 1):
        kit.add(kit.brick((0.16, 0.16, 0.14), center=(s * 0.12, -0.1 + abs(s) * 0.02, 1.52)), pearl, "Head", bevel=0.05)
    kit.part("Head", "Head", pivot=(0, 0, 0.86))
    kit.add(kit.brick((0.28, 0.18, 0.05), center=(0, -0.36, 0.93)), red, "Jaw", bevel=0.015)
    kit.add(kit.brick((0.22, 0.14, 0.02), center=(0, -0.36, 0.96)), kit.mat("gueule", "#5A0A14"), "Jaw", bevel=0.0)
    for k in range(3):
        kit.add(kit.wedge((0.03, 0.02, 0.04), center=((k - 1) * 0.07, -0.44, 0.97), tip=0.15), teeth, "Jaw", bevel=0.0)
    kit.part("Jaw", "Jaw", pivot=(0, -0.26, 0.96), follows="Head")

    # --- bras : spatule en or, ailes, jambes, queue ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.12, 0.14, 0.26), center=(s * 0.36, -0.08, 0.66), rot=(-20, 0, 0)), red, part, bevel=0.03)
        kit.part(part, "Arm", pivot=(s * 0.32, 0, 0.8), phase=0.0 if s > 0 else math.pi)
    kit.add(kit.box((0.03, 0.03, 0.34), center=(0.38, -0.2, 0.6)), gold, "ArmL", bevel=0.006)
    kit.add(kit.brick((0.12, 0.02, 0.14), center=(0.38, -0.22, 0.82)), gold, "ArmL", bevel=0.01)
    P.spread_wings(kit, x=0.24, y=0.18, z=0.86, span=0.4, height=0.28, mats=(red, deep, gold), style="bat", sweep=20,
                   lift=30)
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.18, 0.22, 0.26), center=(s * 0.16, 0, 0.2)), red, part, bevel=0.04)
        kit.add(kit.brick((0.2, 0.28, 0.06), center=(s * 0.16, -0.04, 0.03)), deep, part, bevel=0.02)
        kit.part(part, "Leg", pivot=(s * 0.16, 0, 0.34), phase=0.0 if s > 0 else math.pi)
    P.chain(kit, "Tail", [(0, 0.24, 0.42), (0, 0.46, 0.32), (0.06, 0.64, 0.3), (0.04, 0.78, 0.38)], 0.14, [red, deep],
            taper=0.03)
    kit.add(kit.wedge((0.14, 0.04, 0.16), center=(0.04, 0.84, 0.48), rot=(-30, 0, 0), tip=0.1), gold, "Tail", bevel=0.0)
    kit.part("Tail", "Tail", pivot=(0, 0.22, 0.42))
    return kit.result()
