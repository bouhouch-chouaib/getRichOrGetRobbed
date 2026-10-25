"""Astro-Boulon (Commun, Absurdes) : « Petit robot astronaute tout en boulons, toujours un peu rouillé. »

En briques LEGO, très détaillé (Commun : plastique, aucune lueur) : petit robot-astronaute blanc cassé, casque cubique à
grande visière bleu nuit derrière laquelle brillent deux gros yeux ronds, boulons gris à six pans partout, taches de
rouille orange, sac à oxygène à deux bonbonnes dans le dos, deux antennes à boule sur le casque, gants et bottes bleus,
drapeau de mission sur l'épaule. Parties animées : tête (avec antennes), bras, jambes.
"""

import math

import _parts as P
from pet_kit import PetKit


def _bolt(kit, part, center, normal, mat):
    kit.add(kit.disc(0.035, 0.02, center=center, normal=normal, sides=6), mat, part, bevel=0.0)


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("combinaison", "#F2F0EA")
    grey = kit.mat("boulons", "#8A92A2", metal=0.6, rough=0.3)
    rust = kit.mat("rouille", "#C8642A")
    blue = kit.mat("bleu", "#2E7CFF")
    visor = kit.mat("visiere", "#1A2A5A", rough=0.05)
    red = kit.mat("drapeau", "#FF2A3A")

    # --- corps : combinaison, ceinture, boulons, rouille ---
    kit.add(kit.brick((0.46, 0.36, 0.38), center=(0, 0, 0.5)), white, bevel=0.05)
    kit.add(kit.brick((0.48, 0.38, 0.06), center=(0, 0, 0.36)), grey, bevel=0.015)
    kit.add(kit.brick((0.16, 0.04, 0.12), center=(0, -0.195, 0.52)), blue, bevel=0.015)
    for x, z in ((-0.17, 0.62), (0.17, 0.62), (-0.17, 0.42), (0.17, 0.42)):
        _bolt(kit, "Body", (x, -0.185, z), (0, -1, 0), grey)
    for x, z, w in ((0.12, 0.62, 0.07), (-0.06, 0.44, 0.05), (0.2, 0.46, 0.04)):
        kit.add(kit.box((w, 0.01, w * 0.8), center=(x, -0.184, z), rot=(0, 30, 0)), rust, bevel=0.0)
    # sac à oxygène
    for s in (-1, 1):
        kit.add(kit.brick((0.14, 0.14, 0.34), center=(s * 0.09, 0.24, 0.52)), white, bevel=0.04)
        kit.add(kit.brick((0.1, 0.1, 0.04), center=(s * 0.09, 0.24, 0.71)), grey, bevel=0.01)
    kit.add(kit.box((0.04, 0.02, 0.06), center=(0.06, 0.315, 0.44)), rust, bevel=0.0)

    # --- tête-casque, visière, yeux, antennes ---
    kit.add(kit.brick((0.5, 0.44, 0.42), center=(0, -0.02, 0.92)), white, "Head", bevel=0.07)
    kit.add(kit.brick((0.4, 0.06, 0.3), center=(0, -0.235, 0.92)), visor, "Head", bevel=0.03)
    P.eyes(kit, "Head", x=0.09, y=-0.265, z=0.94, size=0.11, iris="#7AD2FF", pupil="round", sclera="#E6F6FF", tall=1.1)
    P.mouth(kit, "Head", y=-0.266, z=0.83, w=0.1, smile=0.5, color="#7AD2FF")
    for s in (-1, 1):
        _bolt(kit, "Head", (s * 0.255, -0.02, 0.92), (s, 0, 0), grey)
        P.chain(kit, "Head", [(s * 0.15, 0.0, 1.13), (s * 0.19, 0.02, 1.26), (s * 0.2, 0.02, 1.34)], 0.025, [grey])
        kit.add(kit.brick((0.06, 0.06, 0.06), center=(s * 0.2, 0.02, 1.37)), red if s > 0 else blue, "Head", bevel=0.015)
    kit.add(kit.box((0.08, 0.01, 0.05), center=(-0.16, -0.24, 1.08), rot=(0, 20, 0)), rust, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, 0, 0.7))

    # --- bras à gants bleus, drapeau sur l'épaule ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.12, 0.14, 0.26), center=(s * 0.3, 0, 0.5)), white, part, bevel=0.03)
        kit.add(kit.brick((0.13, 0.15, 0.1), center=(s * 0.3, 0, 0.33)), blue, part, bevel=0.025)
        _bolt(kit, part, (s * 0.362, 0, 0.58), (s, 0, 0), grey)
        kit.part(part, "Arm", pivot=(s * 0.28, 0, 0.62), phase=0.0 if s > 0 else math.pi)
    kit.add(kit.box((0.015, 0.015, 0.26), center=(-0.32, 0.12, 0.76)), grey, "ArmR", bevel=0.0)
    kit.add(kit.box((0.12, 0.01, 0.08), center=(-0.38, 0.12, 0.85)), red, "ArmR", bevel=0.0)

    # --- jambes à bottes bleues ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.15, 0.16, 0.18), center=(s * 0.11, 0, 0.22)), white, part, bevel=0.03)
        kit.add(kit.brick((0.16, 0.22, 0.12), center=(s * 0.11, -0.03, 0.06)), blue, part, bevel=0.03)
        kit.part(part, "Leg", pivot=(s * 0.11, 0, 0.32), phase=0.0 if s > 0 else math.pi)
    return kit.result()
