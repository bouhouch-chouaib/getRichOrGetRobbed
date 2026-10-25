"""Corbeau Voleur (Rare, Animaux) : « Corbeau noir avec une pièce d'or dans le bec. »

En briques LEGO, très détaillé : corbeau noir aux reflets bleu nuit, poitrail en plumes (coins), houppe de plumes
sur le crâne, long bec gris acier en pentes avec narines, une grosse pièce d'or brillante gravée d'un « $ » tenue dans
le bec, yeux jaune vif rusés sous un sourcil plongeant, ailes en trois rangs de plumes à reflets bleus, queue en
éventail, pattes gris foncé à griffes. Parties animées : tête, ailes, queue, pattes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.mat("noir", "#1E2236", rough=0.18)
    blue = kit.mat("bleu_nuit", "#2C3A6E", rough=0.18)
    wing = kit.mat("aile", "#252B48", rough=0.18)
    beak = kit.mat("bec", "#5A6478")
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.18)
    engrave = kit.mat("or_fonce", "#D18A0A", metal=0.85, rough=0.25)
    legs = kit.mat("pattes", "#3E4250")
    claw = kit.mat("griffes", "#14161E")

    # --- corps, poitrail en plumes ---
    kit.add(kit.brick((0.54, 0.6, 0.2), center=(0, 0.06, 0.4)), black, bevel=0.03)
    kit.add(kit.brick((0.64, 0.8, 0.3), center=(0, 0.06, 0.64)), black, bevel=0.035)
    kit.add(kit.brick((0.54, 0.46, 0.14), center=(0, -0.02, 0.86)), black, bevel=0.025)
    kit.add(kit.slope((0.54, 0.26, 0.14), center=(0, 0.36, 0.86), facing="+Y", top=0.2), black, bevel=0.02)
    kit.add(kit.slope((0.46, 0.2, 0.2), center=(0, 0.56, 0.62), facing="+Y", top=0.3), black, bevel=0.02)
    for row, z in enumerate((0.5, 0.62, 0.74)):
        for k in range(3):
            kit.add(kit.wedge((0.1, 0.03, 0.08), center=((k - 1) * 0.12 + (row % 2) * 0.06 - 0.03, -0.355, z),
                              rot=(180, 0, 0), tip=0.2), blue, bevel=0.0)

    # --- tête, houppe, long bec à narines, pièce d'or, yeux rusés ---
    kit.add(kit.brick((0.42, 0.44, 0.36), center=(0, -0.16, 1.12)), black, "Head", bevel=0.035)
    kit.add(kit.brick((0.36, 0.38, 0.06), center=(0, -0.14, 1.33)), blue, "Head", bevel=0.015)
    for k, (dy, h) in enumerate(((-0.08, 0.14), (0.02, 0.18), (0.12, 0.12))):
        P.tuft_piece(kit, "Head", (0, -0.14 + dy, 1.35), (0, 0.5, 1.0), h, 0.1, black)
    kit.add(kit.brick((0.16, 0.24, 0.1), center=(0, -0.48, 1.08)), beak, "Head", bevel=0.015)
    kit.add(kit.slope((0.16, 0.18, 0.1), center=(0, -0.67, 1.08), facing="-Y", top=0.2), beak, "Head", bevel=0.012)
    for s in (-1, 1):
        kit.add(kit.box((0.012, 0.04, 0.02), center=(s * 0.08, -0.44, 1.11)), claw, "Head", bevel=0.0)
    kit.add(kit.disc(0.13, 0.035, center=(0, -0.59, 0.98), normal=(0, -1, 0.12)), gold, "Head", bevel=0.008)
    kit.add(kit.box((0.025, 0.012, 0.13), center=(0, -0.612, 0.98)), engrave, "Head", bevel=0.0)
    for dz in (-0.035, 0.035):
        kit.add(kit.box((0.08, 0.012, 0.022), center=(0, -0.614, 0.98 + dz), rot=(0, 20 if dz > 0 else -20, 0)), engrave,
                "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.12, y=-0.38, z=1.19, size=0.1, iris="#FFD21A", pupil="round", lid=black, lid_drop=0.08,
           brow=blue, brow_angle=18, tall=0.85)

    # --- ailes à reflets bleus, queue en éventail, pattes ---
    P.bird_wings(kit, x=0.37, y=0.06, z=0.66, length=0.62, height=0.38, cov=wing, sec=black, prim=blue, bar=blue,
                 thick=0.1)
    P.tail_fan(kit, "Tail", (0, 0.56, 0.66), n=5, length=0.42, width=0.11, mats=[black, blue], spread=11, pitch=-22)
    P.bird_feet(kit, x=0.15, y=0.04, h=0.28, w=0.075, color=legs, claw=claw)
    kit.part("Head", "Head", pivot=(0, -0.14, 0.94))
    return kit.result()
