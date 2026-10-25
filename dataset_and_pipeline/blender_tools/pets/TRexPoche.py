"""T-Rex de Poche (Divin, Animaux) : « Petit tyrannosaure vert pomme aux écailles dorées. »

En briques LEGO, très détaillé : tyrannosaure vert pomme vif penché en avant, ventre jaune-vert en plaques, rayures
vert foncé sur le dos, rangée d'écailles DORÉES lumineuses du crâne au bout de la queue, grosse tête carrée à arcade
sourcilière, narines, yeux jaunes en fente sous un sourcil buté, mâchoire qui s'ouvre (gueule rouge, langue, dents
blanches en deux rangées), minuscules bras à deux griffes, grosses pattes arrière à trois orteils griffus, longue queue.
Parties animées : tête, mâchoire (rugit), bras (« Arm »), pattes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.mat("vert", "#5EE23A")
    dark = kit.mat("vert_fonce", "#2FA82A")
    belly = kit.mat("ventre", "#E8FF7A")
    gold = kit.mat("or", "#FFD23A", metal=0.6, rough=0.2, glow=0.7)
    teeth = kit.mat("dents", "#FFFFFF", rough=0.12)
    mouth = kit.mat("gueule", "#FF4A5A")
    tongue = kit.mat("langue", "#FF8AA0")
    claw = kit.mat("griffes", "#FFF4DC")

    # --- corps penché, ventre en plaques, rayures, cou ---
    kit.add(kit.brick((0.56, 0.7, 0.5), center=(0, 0.08, 0.74), rot=(12, 0, 0)), green, bevel=0.045)
    kit.add(kit.brick((0.5, 0.5, 0.1), center=(0, 0.06, 1.0), rot=(12, 0, 0)), dark, bevel=0.02)
    for k, z in enumerate((0.56, 0.68, 0.8)):
        kit.add(kit.brick((0.4 - k * 0.03, 0.06, 0.1), center=(0, -0.3 + k * 0.03, z), rot=(12, 0, 0)), belly,
                bevel=0.012)
    kit.add(kit.brick((0.4, 0.34, 0.3), center=(0, -0.34, 1.02), rot=(24, 0, 0)), green, bevel=0.035)
    for s in (-1, 1):
        for y in (-0.1, 0.12, 0.32):
            kit.add(kit.box((0.025, 0.07, 0.22), center=(s * 0.285, y, 0.82 - y * 0.2), rot=(12, 0, 0)), dark,
                    bevel=0.004)
    for y, z in ((-0.24, 1.2), (-0.02, 1.08), (0.2, 1.04), (0.4, 0.96)):
        kit.add(kit.wedge((0.09, 0.14, 0.16), center=(0, y, z), tip=0.12), gold, bevel=0.006)

    # --- tête : crâne, arcade, narines, yeux, mâchoire du haut et dents ---
    kit.add(kit.brick((0.52, 0.52, 0.32), center=(0, -0.64, 1.3)), green, "Head", bevel=0.04)
    kit.add(kit.brick((0.46, 0.22, 0.12), center=(0, -0.95, 1.2)), green, "Head", bevel=0.025)
    kit.add(kit.brick((0.54, 0.14, 0.07), center=(0, -0.52, 1.48)), dark, "Head", bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.03, 0.03), center=(s * 0.09, -1.065, 1.24)), dark, "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.17, y=-0.9, z=1.38, size=0.09, iris="#FFE01E", pupil="slit", lid=green, lid_drop=0.08,
           brow=dark, brow_angle=16, tall=0.9)
    kit.add(kit.brick((0.4, 0.12, 0.04), center=(0, -0.98, 1.135)), mouth, "Head", bevel=0.0)
    for k in range(6):
        kit.add(kit.wedge((0.045, 0.035, 0.07), center=((k - 2.5) * 0.072, -1.03, 1.12), rot=(180, 0, 0), tip=0.15),
                teeth, "Head", bevel=0.0)
    kit.add(kit.wedge((0.07, 0.16, 0.14), center=(0, -0.64, 1.53), tip=0.12), gold, "Head", bevel=0.006)
    # --- mâchoire du bas : gueule rouge, langue, dents ---
    kit.add(kit.brick((0.46, 0.46, 0.1), center=(0, -0.76, 1.05)), green, "Jaw", bevel=0.025)
    kit.add(kit.brick((0.4, 0.34, 0.03), center=(0, -0.78, 1.11)), mouth, "Jaw", bevel=0.0)
    kit.add(kit.brick((0.16, 0.22, 0.03), center=(0, -0.74, 1.125)), tongue, "Jaw", bevel=0.006)
    for k in range(5):
        kit.add(kit.wedge((0.045, 0.035, 0.06), center=((k - 2) * 0.08, -0.97, 1.13), tip=0.15), teeth, "Jaw",
                bevel=0.0)
    kit.add(kit.brick((0.36, 0.3, 0.05), center=(0, -0.74, 0.99)), belly, "Jaw", bevel=0.01)
    kit.part("Head", "Head", pivot=(0, -0.42, 1.2))
    kit.part("Jaw", "Jaw", pivot=(0, -0.54, 1.1), follows="Head")

    # --- minuscules bras à deux griffes ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.08, 0.1, 0.14), center=(s * 0.26, -0.38, 0.9), rot=(-20, 0, 0)), green, part, bevel=0.012)
        kit.add(kit.brick((0.07, 0.14, 0.06), center=(s * 0.26, -0.46, 0.82), rot=(-50, 0, 0)), green, part,
                bevel=0.01)
        for dx in (-0.018, 0.018):
            kit.add(kit.wedge((0.025, 0.03, 0.05), center=(s * 0.26 + dx, -0.53, 0.78), rot=(120, 0, 0), tip=0.2), claw,
                    part, bevel=0.0)
        kit.part(part, "Arm", pivot=(s * 0.26, -0.34, 0.96), phase=0.0 if s > 0 else math.pi)

    # --- grosses pattes arrière : cuisse, jambe, pied à trois orteils griffus ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        x = s * 0.27
        kit.add(kit.brick((0.22, 0.36, 0.32), center=(x, 0.14, 0.58)), green, part, bevel=0.035)
        kit.add(kit.box((0.025, 0.2, 0.2), center=(x + s * 0.115, 0.14, 0.6)), dark, part, bevel=0.004)
        kit.add(kit.brick((0.15, 0.15, 0.34), center=(x, 0.2, 0.25), rot=(-12, 0, 0)), green, part, bevel=0.02)
        kit.add(kit.brick((0.2, 0.24, 0.08), center=(x, 0.08, 0.04)), green, part, bevel=0.015)
        for k in range(3):
            dx = (k - 1) * 0.065
            kit.add(kit.brick((0.055, 0.12, 0.07), center=(x + dx, -0.08, 0.035)), green, part, bevel=0.01)
            kit.add(kit.wedge((0.04, 0.06, 0.06), center=(x + dx, -0.16, 0.035), rot=(90, 0, 0), tip=0.2), claw, part,
                    bevel=0.0)
        kit.part(part, "Leg", pivot=(x, 0.14, 0.7), phase=0.0 if s > 0 else math.pi)

    # --- longue queue + écailles dorées ---
    pts = [(0, 0.42, 0.68), (0, 0.66, 0.58), (0, 0.9, 0.48), (0, 1.12, 0.4), (0, 1.32, 0.34), (0, 1.48, 0.3)]
    P.chain(kit, "Tail", pts, 0.34, [green, green, dark], taper=0.055, height=0.3)
    for y, z in ((0.66, 0.76), (0.9, 0.64), (1.12, 0.54), (1.32, 0.46)):
        kit.add(kit.wedge((0.07, 0.12, 0.12), center=(0, y, z), tip=0.15), gold, "Tail", bevel=0.006)
    kit.part("Tail", "Tail", pivot=(0, 0.4, 0.68))
    return kit.result()
