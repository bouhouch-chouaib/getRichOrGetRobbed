"""Hamster Joufflu (Inhabituel, Animaux) : « Hamster roux en boule parfaite. »

En briques LEGO, très détaillé : boule roux vif en briques empilées arrondie par des pentes, énorme plastron crème,
joues crème qui débordent (joufflu !) avec des taches rosées, grands yeux noirs brillants à double reflet, truffe rose
à narines, deux dents blanches, moustaches, oreilles roses, pattes avant qui tiennent une graine de tournesol rayée,
petits pieds à doigts, petite queue. Parties animées : oreilles (frémissent), pattes avant (tiennent la graine).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    orange = kit.mat("roux", "#FF8A2A")
    deep = kit.mat("roux_fonce", "#E06A12")
    cream = kit.mat("creme", "#FFF1D8")
    pink = kit.mat("rose", "#FF9EB8")
    blush = kit.mat("joues", "#FFB8C6")
    white = kit.mat("dents", "#FFFFFF", rough=0.15)
    seed = kit.mat("graine", "#3A2E28")
    stripe = kit.mat("rayure_graine", "#F4EEDF")

    # --- boule en briques arrondie ---
    kit.add(kit.brick((0.62, 0.6, 0.14), center=(0, 0.02, 0.09)), orange, bevel=0.03)
    kit.add(kit.brick((0.8, 0.74, 0.4), center=(0, 0.02, 0.36)), orange, bevel=0.045)
    kit.add(kit.brick((0.66, 0.6, 0.14), center=(0, 0.04, 0.63)), orange, bevel=0.03)
    kit.add(kit.brick((0.48, 0.44, 0.07), center=(0, 0.05, 0.735)), deep, bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.slope((0.1, 0.56, 0.14), center=(s * 0.38, 0.04, 0.63), facing=P.side(s), top=0.3), orange,
                bevel=0.015)
    kit.add(kit.slope((0.6, 0.12, 0.14), center=(0, 0.4, 0.63), facing="+Y", top=0.3), orange, bevel=0.015)
    kit.add(kit.brick((0.5, 0.06, 0.46), center=(0, -0.37, 0.34)), cream, bevel=0.025)

    # --- joues, visage ---
    for s in (-1, 1):
        kit.add(kit.brick((0.22, 0.24, 0.22), center=(s * 0.34, -0.27, 0.34)), cream, bevel=0.045)
        kit.add(kit.box((0.08, 0.02, 0.06), center=(s * 0.34, -0.395, 0.38)), blush, bevel=0.006)
    P.eyes(kit, "Body", x=0.15, y=-0.37, z=0.52, size=0.11, iris="#16161C", pupil="round", sclera="#16161C")
    P.nose(kit, "Body", y=-0.4, z=0.44, w=0.07, color="#FF8FA8", nostril="#B4466A")
    for dx in (-0.025, 0.025):
        kit.add(kit.brick((0.04, 0.03, 0.06), center=(dx, -0.405, 0.37)), white, bevel=0.006)
    P.whiskers(kit, "Body", x=0.08, y=-0.42, z=0.42, color="#FFFFFF", n=3, length=0.14)

    # --- oreilles roses (frémissent) ---
    for s, part in ((1, "EarL"), (-1, "EarR")):
        kit.add(kit.brick((0.15, 0.08, 0.13), center=(s * 0.22, -0.02, 0.82)), orange, part, bevel=0.025)
        kit.add(kit.brick((0.1, 0.02, 0.09), center=(s * 0.22, -0.065, 0.82)), pink, part, bevel=0.006)
        kit.part(part, "Ear", pivot=(s * 0.22, -0.02, 0.76), phase=float(s))

    # --- pattes avant qui tiennent une graine rayée ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.09, 0.1, 0.14), center=(s * 0.1, -0.43, 0.26), rot=(-20, 0, 0)), cream, part, bevel=0.015)
        for k in range(3):
            kit.add(kit.brick((0.025, 0.04, 0.03), center=(s * (0.07 + k * 0.025), -0.49, 0.32)), pink, part,
                    bevel=0.004)
        kit.part(part, "Arm", pivot=(s * 0.1, -0.4, 0.33), phase=0.0)
    kit.add(kit.wedge((0.08, 0.05, 0.14), center=(0, -0.5, 0.3), tip=0.3), seed, "ArmL", bevel=0.008)
    kit.add(kit.box((0.012, 0.052, 0.11), center=(0, -0.5, 0.3)), stripe, "ArmL", bevel=0.0)
    # --- pieds à doigts, petite queue ---
    for s in (-1, 1):
        kit.add(kit.brick((0.15, 0.16, 0.05), center=(s * 0.19, -0.24, 0.025)), cream, bevel=0.012)
        for k in range(3):
            kit.add(kit.brick((0.035, 0.05, 0.04), center=(s * 0.19 + (k - 1) * 0.045, -0.33, 0.02)), pink, bevel=0.004)
    P.tuft_piece(kit, "Body", (0, 0.38, 0.2), (0, 1, 0.4), 0.08, 0.06, orange)
    return kit.result()
