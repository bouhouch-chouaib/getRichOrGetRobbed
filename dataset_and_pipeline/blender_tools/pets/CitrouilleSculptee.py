"""Citrouille Sculptée (Rare, Plantes) : « Citrouille d'Halloween éclairée de l'intérieur. »

En briques LEGO, très détaillée : grosse citrouille orange vif en côtes (lobes alternés clairs et foncés autour d'un
cœur), dessus et dessous plus foncés, visage creusé qui LUIT de l'intérieur (yeux triangles, nez, grande bouche en zigzag
avec deux dents), tige verte tordue, vrille qui s'enroule et une feuille. Partie animée : la vrille et sa feuille.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    orange = kit.mat("orange", "#FF7A12")
    light = kit.mat("orange_clair", "#FF9A3A")
    dark = kit.mat("orange_fonce", "#DC5604")
    glow = kit.mat("lueur", "#FFC83A", rough=0.2, glow=2.8)
    inner = kit.mat("creux", "#5A2204")
    stem = kit.mat("tige", "#5E8A1E")
    stem2 = kit.mat("tige_fonce", "#3E6A12")
    leaf = kit.mat("feuille", "#3EC22E")
    vein = kit.mat("nervure", "#B4F27A")

    # --- côtes : lobes autour d'un cœur ---
    kit.add(kit.brick((0.56, 0.52, 0.52), center=(0, 0, 0.32)), orange, bevel=0.05)
    for k in range(10):
        a = math.radians(-90 + 36 * k)
        kit.add(kit.brick((0.2, 0.2, 0.54), center=(math.cos(a) * 0.3, math.sin(a) * 0.27, 0.32),
                          rot=(0, 0, math.degrees(a))), light if k % 2 == 0 else orange, bevel=0.06)
    kit.add(kit.brick((0.42, 0.4, 0.06), center=(0, 0, 0.6)), dark, bevel=0.02)
    kit.add(kit.brick((0.24, 0.22, 0.04), center=(0, 0.02, 0.645)), orange, bevel=0.015)
    kit.add(kit.brick((0.5, 0.48, 0.06), center=(0, 0, 0.03)), dark, bevel=0.02)

    # --- visage creusé qui luit : plaque, yeux, nez, bouche en zigzag ---
    kit.add(kit.brick((0.46, 0.06, 0.44), center=(0, -0.36, 0.33)), orange, bevel=0.025)
    for s in (-1, 1):
        kit.add(kit.box((0.15, 0.02, 0.13), center=(s * 0.12, -0.394, 0.43)), inner, bevel=0.0)
        kit.add(kit.wedge((0.13, 0.02, 0.11), center=(s * 0.12, -0.402, 0.42), tip=0.08), glow, bevel=0.0)
    kit.add(kit.wedge((0.07, 0.02, 0.06), center=(0, -0.402, 0.33), tip=0.08), glow, bevel=0.0)
    kit.add(kit.box((0.34, 0.02, 0.1), center=(0, -0.394, 0.2)), inner, bevel=0.0)
    kit.add(kit.box((0.31, 0.02, 0.07), center=(0, -0.402, 0.2)), glow, bevel=0.0)
    for k in range(4):
        x = -0.12 + k * 0.08
        kit.add(kit.box((0.035, 0.022, 0.04), center=(x, -0.405, 0.235 if k % 2 else 0.165)), orange, bevel=0.0)

    # --- tige tordue, vrille, feuille ---
    P.chain(kit, "Body", [(0, 0.02, 0.6), (0.02, 0.03, 0.7), (-0.03, 0.06, 0.78)], 0.09, [stem, stem2])
    P.chain(kit, "Vine", [(0.02, 0.02, 0.63), (0.16, 0.02, 0.66), (0.24, -0.04, 0.72), (0.22, -0.12, 0.78),
                          (0.15, -0.12, 0.8)], 0.03, [stem])
    P.leaf(kit, "Vine", (0.06, 0.06, 0.63), (0.6, 0.8, 0.35), 0.3, 0.2, leaf, vein, normal=(0, 0, 1), droop=0.2)
    kit.part("Vine", "Leaf", pivot=(0.02, 0.02, 0.63), phase=0.4)
    return kit.result()
