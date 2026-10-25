"""Corbeau Voleur (Rare, Animaux) : « Corbeau noir avec une pièce d'or dans le bec. »

En briques LEGO : corps et tête en briques noires à reflets bleutés, long bec gris anthracite en pentes, une pièce
d'or (tuile ronde, le seul détail rond) tenue dans le bec, yeux jaunes rusés, ailes repliées avec deux barres
gris-bleu, queue en plaques, pattes gris foncé. Parties animées : tête, ailes, queue, pattes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.mat("noir", "#1B1C22", rough=0.2, accent="#2B3550")
    wing = kit.mat("aile", "#24262E", rough=0.2, accent="#33406A")
    beak = kit.mat("bec", "#4A4C52")
    bar = kit.mat("barre", "#4C5A78")
    gold = kit.mat("or", "#F5C443", metal=0.8, rough=0.22)
    legs = kit.mat("pattes", "#3A3B40")

    # --- corps en briques ---
    kit.add(kit.brick((0.54, 0.6, 0.2), center=(0, 0.06, 0.4)), black, bevel=0.03)
    kit.add(kit.brick((0.64, 0.8, 0.3), center=(0, 0.06, 0.64)), black, bevel=0.035)
    kit.add(kit.brick((0.54, 0.46, 0.14), center=(0, -0.02, 0.86)), black, bevel=0.025)
    kit.add(kit.slope((0.54, 0.26, 0.14), center=(0, 0.36, 0.86), facing="+Y", top=0.2), black, bevel=0.02)
    kit.add(kit.slope((0.46, 0.2, 0.2), center=(0, 0.56, 0.62), facing="+Y", top=0.3), black, bevel=0.02)

    # --- tête, long bec, pièce d'or, yeux ---
    kit.add(kit.brick((0.42, 0.44, 0.36), center=(0, -0.16, 1.12)), black, "Head", bevel=0.035)
    kit.add(kit.brick((0.36, 0.38, 0.06), center=(0, -0.14, 1.33)), black, "Head", bevel=0.015)
    kit.add(kit.brick((0.16, 0.24, 0.1), center=(0, -0.48, 1.08)), beak, "Head", bevel=0.015)
    kit.add(kit.slope((0.16, 0.16, 0.1), center=(0, -0.66, 1.08), facing="-Y", top=0.2), beak, "Head", bevel=0.012)
    kit.add(kit.disc(0.12, 0.03, center=(0, -0.58, 0.99), normal=(0, -1, 0.15)), gold, "Head", bevel=0.008)
    P.eyes(kit, "Head", 0.12, -0.38, 1.18, size=0.09, iris="#F2D23C", pupil_w=0.4, pupil_h=0.7, highlight=True)

    # --- ailes, queue, pattes ---
    P.bird_wings(kit, wing, x=0.37, y=0.06, z=0.66, length=0.6, height=0.36, bars=[bar, bar])
    for yaw in (-14, 0, 14):
        kit.add(kit.brick((0.16, 0.42, 0.06), center=(yaw * 0.006, 0.76, 0.66), rot=(-24, 0, yaw)), wing, "Tail",
                bevel=0.015)
    kit.part("Tail", "Tail", pivot=(0, 0.58, 0.64))
    P.bird_legs(kit, legs, x=0.15, y=0.04)
    kit.part("Head", "Head", pivot=(0, -0.14, 0.94))
    return kit.result()
