"""Tasse-Chien (Rare, Hybrides) : « Carlin beige coincé dans un gros mug. »

En briques LEGO, très détaillé : gros mug blanc (bandes bleu ciel, cœur rouge peint, anse épaisse sur le côté, café
brun autour du chien) ; dedans, un carlin beige dont seuls dépassent la tête et les pattes avant posées sur le rebord :
masque noir, plis du front, grands yeux brillants qui louchent un peu, langue rose qui pend, oreilles noires
tombantes. Un peu de vapeur blanche. Parties animées : tête, oreilles, pattes avant.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    mug = kit.mat("tasse", "#FFFFFF", rough=0.1)
    band = kit.mat("bandes", "#5AB4FF", rough=0.1)
    heart = kit.mat("coeur", "#FF2A4A")
    coffee = kit.mat("cafe", "#6A3A1A", rough=0.05)
    fawn = kit.mat("fauve", "#E8C08A")
    fawn2 = kit.mat("fauve_fonce", "#C89A62")
    black = kit.mat("masque", "#2A2220")
    tongue = kit.mat("langue", "#FF6A98")
    steam = kit.mat("vapeur", "#F2F4F8", rough=0.6)

    # --- le mug : corps octogonal en briques, bandes, cœur, anse, café ---
    kit.add(kit.brick((0.7, 0.62, 0.62), center=(0, 0, 0.33)), mug, bevel=0.05)
    kit.add(kit.brick((0.62, 0.7, 0.62), center=(0, 0, 0.33)), mug, bevel=0.05)
    for z in (0.12, 0.56):
        kit.add(kit.brick((0.72, 0.64, 0.05), center=(0, 0, z)), band, bevel=0.012)
        kit.add(kit.brick((0.64, 0.72, 0.05), center=(0, 0, z)), band, bevel=0.012)
    for s in (-1, 1):
        kit.add(kit.box((0.06, 0.02, 0.06), center=(s * 0.03, -0.362, 0.36), rot=(0, s * 45, 0)), heart, bevel=0.0)
    kit.add(kit.wedge((0.1, 0.02, 0.07), center=(0, -0.362, 0.31), rot=(0, 180, 0), tip=0.1), heart, bevel=0.0)
    for z in (0.18, 0.48):
        kit.add(kit.brick((0.1, 0.1, 0.08), center=(0.4, 0, z)), mug, bevel=0.025)
    kit.add(kit.brick((0.1, 0.1, 0.38), center=(0.48, 0, 0.33)), mug, bevel=0.03)
    kit.add(kit.brick((0.6, 0.6, 0.03), center=(0, 0, 0.62)), coffee, bevel=0.008)

    # --- tête de carlin ---
    kit.add(kit.brick((0.48, 0.42, 0.38), center=(0, -0.04, 0.82)), fawn, "Head", bevel=0.06)
    kit.add(kit.brick((0.3, 0.12, 0.2), center=(0, -0.28, 0.74)), black, "Head", bevel=0.04)
    for k in range(3):
        kit.add(kit.box((0.18 - k * 0.04, 0.02, 0.02), center=(0, -0.255, 0.95 + k * 0.03)), fawn2, "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.13, y=-0.25, z=0.87, size=0.13, iris="#3A2412", pupil="round", look=(0.2, 0.1), tall=1.1)
    P.nose(kit, "Head", y=-0.34, z=0.78, w=0.08, color="#1A1210")
    kit.add(kit.brick((0.06, 0.03, 0.1), center=(0.02, -0.345, 0.66)), tongue, "Head", bevel=0.01)
    kit.part("Head", "Head", pivot=(0, -0.02, 0.66))
    for s, part in ((1, "EarL"), (-1, "EarR")):
        kit.add(kit.brick((0.12, 0.08, 0.16), center=(s * 0.25, -0.02, 0.92), rot=(0, s * 30, 0)), black, part,
                bevel=0.025)
        kit.part(part, "Ear", pivot=(s * 0.22, -0.02, 0.98), phase=float(s))

    # --- pattes avant posées sur le rebord ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.12, 0.14, 0.18), center=(s * 0.2, -0.28, 0.62)), fawn, part, bevel=0.03)
        kit.add(kit.brick((0.13, 0.16, 0.06), center=(s * 0.2, -0.33, 0.67)), fawn, part, bevel=0.02)
        for k in range(3):
            kit.add(kit.box((0.015, 0.02, 0.04), center=(s * 0.2 + (k - 1) * 0.035, -0.415, 0.66)), fawn2, part, bevel=0.0)
        kit.part(part, "Arm", pivot=(s * 0.2, -0.24, 0.62), phase=0.0 if s > 0 else math.pi)

    # --- vapeur ---
    for k, (x, z, w) in enumerate(((0.22, 0.74, 0.08), (0.26, 0.86, 0.06), (0.21, 0.96, 0.05))):
        kit.add(kit.brick((w, w, w), center=(x, 0.18, z), rot=(0, 0, 25 * k)), steam, "Steam", bevel=0.015)
    kit.part("Steam", "Leaf", pivot=(0.22, 0.18, 0.7), phase=1.0)
    return kit.result()
