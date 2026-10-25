"""Hamster Joufflu (Inhabituel, Animaux) : « Hamster roux en boule parfaite. »

En briques LEGO : une boule faite de briques empilées qui s'élargissent au milieu, roux avec un grand plastron crème,
d'énormes joues crème qui débordent (joufflu), petits yeux noirs brillants, truffe rose, deux dents blanches,
petites oreilles roses, pattes avant crème repliées. Parties animées : oreilles (frémissent), pattes avant.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    orange = kit.mat("roux", "#E68C46")
    cream = kit.mat("creme", "#FFE6C8")
    pink = kit.mat("rose", "#F4A3AE")
    white = kit.mat("dents", "#FFFFFF", rough=0.15)

    # --- boule en briques : bas, milieu large, haut, pentes ---
    kit.add(kit.brick((0.6, 0.58, 0.14), center=(0, 0.02, 0.09)), orange, bevel=0.03)
    kit.add(kit.brick((0.78, 0.72, 0.38), center=(0, 0.02, 0.35)), orange, bevel=0.04)
    kit.add(kit.brick((0.64, 0.58, 0.14), center=(0, 0.04, 0.61)), orange, bevel=0.03)
    kit.add(kit.brick((0.46, 0.42, 0.06), center=(0, 0.05, 0.71)), orange, bevel=0.015)
    kit.add(kit.brick((0.46, 0.06, 0.42), center=(0, -0.37, 0.32)), cream, bevel=0.025)

    # --- joues, yeux, truffe, dents ---
    for s in (-1, 1):
        kit.add(kit.brick((0.2, 0.22, 0.2), center=(s * 0.33, -0.28, 0.33)), cream, bevel=0.035)
    P.eyes(kit, "Body", 0.15, -0.37, 0.5, size=0.09, iris="#121214", pupil_w=0.0, highlight=True)
    kit.add(kit.brick((0.08, 0.05, 0.05), center=(0, -0.41, 0.42)), pink, bevel=0.01)
    for dx in (-0.025, 0.025):
        kit.add(kit.brick((0.04, 0.03, 0.06), center=(dx, -0.405, 0.36)), white, bevel=0.006)

    # --- oreilles roses ---
    for s, part in ((1, "EarL"), (-1, "EarR")):
        kit.add(kit.brick((0.14, 0.07, 0.12), center=(s * 0.22, -0.02, 0.8)), orange, part, bevel=0.02)
        kit.add(kit.brick((0.09, 0.02, 0.08), center=(s * 0.22, -0.06, 0.8)), pink, part, bevel=0.006)
        kit.part(part, "Ear", pivot=(s * 0.22, -0.02, 0.74), phase=float(s))

    # --- pattes avant repliées sur le ventre (Arm), petits pieds ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.1, 0.1, 0.12), center=(s * 0.13, -0.42, 0.24)), cream, part, bevel=0.015)
        kit.part(part, "Arm", pivot=(s * 0.13, -0.4, 0.3), phase=0.0 if s > 0 else 3.14159)
    for s in (-1, 1):
        kit.add(kit.brick((0.14, 0.16, 0.05), center=(s * 0.18, -0.24, 0.025)), cream, bevel=0.012)
    return kit.result()
