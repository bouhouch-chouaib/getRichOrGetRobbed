"""T-Rex de Poche (Divin, Animaux) : « Petit tyrannosaure vert pomme aux écailles dorées. »

En briques LEGO : corps vert pomme penché en avant, ventre jaune-vert, grosse tête carrée à mâchoire qui s'ouvre
(dents blanches en coins), petits yeux jaunes sous une arcade, minuscules bras, grosses pattes arrière à griffes,
longue queue en briques, écailles DORÉES en pentes le long du dos et de la queue. Parties animées : tête, mâchoire
(rugit), bras (« Arm »), pattes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.mat("vert", "#8CE63C")
    belly = kit.mat("ventre", "#E2F28A")
    gold = kit.mat("or", "#FFCE3A", metal=0.6, rough=0.22, glow=0.5)
    teeth = kit.mat("dents", "#FFFFFF", rough=0.15)
    mouth = kit.mat("gueule", "#B83A3A")
    claw = kit.mat("griffes", "#F4EBD8")

    # --- corps penché en avant ---
    kit.add(kit.brick((0.56, 0.7, 0.5), center=(0, 0.08, 0.72), rot=(12, 0, 0)), green, bevel=0.04)
    kit.add(kit.brick((0.42, 0.08, 0.42), center=(0, -0.3, 0.66), rot=(12, 0, 0)), belly, bevel=0.02)
    kit.add(kit.brick((0.4, 0.34, 0.3), center=(0, -0.34, 1.0), rot=(24, 0, 0)), green, bevel=0.03)  # cou
    for k, (y, z) in enumerate(((-0.22, 1.16), (0.0, 1.02), (0.22, 0.98), (0.42, 0.9))):
        kit.add(kit.wedge((0.08, 0.14, 0.14), center=(0, y, z), tip=0.15), gold, bevel=0.006)

    # --- tête carrée, arcade, yeux, mâchoire du haut avec dents ---
    kit.add(kit.brick((0.5, 0.5, 0.32), center=(0, -0.62, 1.28)), green, "Head", bevel=0.035)
    kit.add(kit.brick((0.44, 0.2, 0.1), center=(0, -0.92, 1.2)), green, "Head", bevel=0.02)
    kit.add(kit.brick((0.5, 0.12, 0.06), center=(0, -0.5, 1.46)), green, "Head", bevel=0.015)
    P.eyes(kit, "Head", 0.16, -0.87, 1.36, size=0.08, iris="#F2D23A", pupil_w=0.3, pupil_h=0.8, tall=0.9)
    for k in range(5):
        kit.add(kit.wedge((0.05, 0.035, 0.07), center=((k - 2) * 0.085, -1.0, 1.12), rot=(180, 0, 0), tip=0.15),
                teeth, "Head", bevel=0.0)
    kit.add(kit.wedge((0.06, 0.14, 0.12), center=(0, -0.62, 1.5), tip=0.15), gold, "Head", bevel=0.006)
    # --- mâchoire du bas (s'ouvre en rugissant) ---
    kit.add(kit.brick((0.44, 0.44, 0.1), center=(0, -0.74, 1.04)), green, "Jaw", bevel=0.02)
    kit.add(kit.brick((0.38, 0.32, 0.03), center=(0, -0.76, 1.1)), mouth, "Jaw", bevel=0.0)
    for k in range(4):
        kit.add(kit.wedge((0.05, 0.035, 0.06), center=((k - 1.5) * 0.09, -0.94, 1.12), tip=0.15), teeth, "Jaw",
                bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.42, 1.18))
    kit.part("Jaw", "Jaw", pivot=(0, -0.52, 1.08), follows="Head")

    # --- minuscules bras ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.07, 0.16, 0.07), center=(s * 0.25, -0.42, 0.86), rot=(-30, 0, 0)), green, part,
                bevel=0.012)
        kit.add(kit.brick((0.06, 0.05, 0.05), center=(s * 0.25, -0.5, 0.8)), claw, part, bevel=0.006)
        kit.part(part, "Arm", pivot=(s * 0.25, -0.36, 0.92), phase=0.0 if s > 0 else math.pi)

    # --- grosses pattes arrière : cuisse, jambe, pied à griffes ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        x = s * 0.25
        kit.add(kit.brick((0.2, 0.34, 0.3), center=(x, 0.12, 0.56)), green, part, bevel=0.03)
        kit.add(kit.brick((0.14, 0.14, 0.32), center=(x, 0.18, 0.24), rot=(-10, 0, 0)), green, part, bevel=0.02)
        kit.add(kit.brick((0.18, 0.3, 0.08), center=(x, 0.06, 0.04)), green, part, bevel=0.015)
        for dx in (-0.05, 0.05):
            kit.add(kit.wedge((0.05, 0.06, 0.06), center=(x + dx, -0.12, 0.04), rot=(90, 0, 0), tip=0.2), claw, part,
                    bevel=0.0)
        kit.part(part, "Leg", pivot=(x, 0.12, 0.66), phase=0.0 if s > 0 else math.pi)

    # --- longue queue + écailles dorées ---
    pts = [(0, 0.4, 0.66), (0, 0.66, 0.56), (0, 0.9, 0.46), (0, 1.12, 0.38), (0, 1.32, 0.32)]
    P.chain(kit, "Tail", pts, 0.34, [green], taper=0.06, height=0.3)
    for y, z in ((0.66, 0.74), (0.9, 0.62), (1.12, 0.52)):
        kit.add(kit.wedge((0.07, 0.12, 0.12), center=(0, y, z), tip=0.15), gold, "Tail", bevel=0.006)
    kit.part("Tail", "Tail", pivot=(0, 0.38, 0.66))
    return kit.result()
