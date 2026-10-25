"""Arbre-Monde Miniature (Mythique, Plantes) : « Chêne colossal miniature aux racines cyan. »

En briques LEGO, très détaillé : chêne trapu au tronc large et évasé (écorce en couches, plis plus foncés), une petite
porte en arc avec poignée dorée et une fenêtre ronde éclairée à sa base, grandes racines LUMINEUSES cyan qui
s'étalent au sol, branches tordues, énorme couronne de feuillage en blocs (trois verts), glands et fruits cyan
lumineux dedans ; visage de vieux sage dans l'écorce (yeux cyan lumineux, sourcils et moustache de mousse).
Partie animée : la couronne (balancement lourd).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    bark = kit.mat("ecorce", "#7A4620")
    bark2 = kit.mat("ecorce_fonce", "#52300E")
    bark3 = kit.mat("ecorce_claire", "#9A6236")
    cyan = kit.mat("racines", "#1EE6FF", rough=0.1, glow=2.2)
    g1 = kit.mat("feuillage", "#34BE44")
    g2 = kit.mat("feuillage_fonce", "#1E8A32")
    g3 = kit.mat("feuillage_clair", "#6ADB4A")
    moss = kit.mat("mousse", "#7AE64E")
    door = kit.mat("porte", "#A8642A")
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.2)
    window = kit.mat("fenetre", "#FFD86A", rough=0.2, glow=1.6)
    acorn = kit.mat("gland", "#B87A2E")

    # --- racines lumineuses qui s'étalent ---
    for k in range(7):
        a = math.radians(-90 + 51.4 * k + 12)
        d = (math.cos(a), math.sin(a))
        P.chain(kit, "Body", [(d[0] * 0.16, d[1] * 0.16, 0.08), (d[0] * 0.34, d[1] * 0.34, 0.04),
                              (d[0] * 0.5 + d[1] * 0.06, d[1] * 0.5 - d[0] * 0.06, 0.03)], 0.07, [cyan], taper=0.015)

    # --- tronc évasé, plis, porte et fenêtre, visage ---
    kit.add(kit.brick((0.5, 0.46, 0.14), center=(0, 0, 0.07)), bark2, bevel=0.04)
    kit.add(kit.brick((0.42, 0.38, 0.3), center=(0, 0, 0.28)), bark, bevel=0.05)
    kit.add(kit.brick((0.34, 0.3, 0.32), center=(0, 0, 0.58)), bark, bevel=0.05)
    for x in (-0.15, 0.15):
        kit.add(kit.box((0.04, 0.02, 0.5), center=(x, -0.2, 0.36)), bark2, bevel=0.0)
        kit.add(kit.box((0.02, 0.04, 0.5), center=(0.21 if x > 0 else -0.21, 0.08, 0.36)), bark3, bevel=0.0)
    kit.add(kit.brick((0.12, 0.03, 0.16), center=(0.0, -0.245, 0.1)), door, bevel=0.01)
    kit.add(kit.wedge((0.12, 0.03, 0.05), center=(0.0, -0.245, 0.2), tip=0.4), door, bevel=0.0)
    kit.add(kit.box((0.02, 0.02, 0.02), center=(0.035, -0.262, 0.1)), gold, bevel=0.0)
    kit.add(kit.disc(0.035, 0.02, center=(0.14, -0.24, 0.17), normal=(0, -1, 0)), window, bevel=0.0)
    P.eyes(kit, "Body", x=0.075, y=-0.16, z=0.6, size=0.08, iris="#1EE6FF", pupil="round", lid=bark2, lid_drop=0.15,
           glow=2.0, tall=0.9)
    for s in (-1, 1):
        kit.add(kit.box((0.1, 0.04, 0.035), center=(s * 0.075, -0.17, 0.66), rot=(0, s * -12, 0)), moss, bevel=0.01)
        P.tuft_piece(kit, "Body", (s * 0.03, -0.17, 0.5), (s * 1.0, -0.2, -0.6), 0.1, 0.04, moss)

    # --- branches tordues ---
    for s in (-1, 1):
        P.chain(kit, "Body", [(s * 0.08, 0, 0.72), (s * 0.24, 0.02, 0.8), (s * 0.36, 0.0, 0.9)], 0.1, [bark, bark2])
    P.chain(kit, "Body", [(0, 0.04, 0.72), (0.02, 0.12, 0.86)], 0.12, [bark])

    # --- couronne de feuillage en blocs, glands et fruits lumineux ---
    blocks = [((0.96, 0.84, 0.3), (0, 0.02, 1.0), g1), ((0.74, 0.7, 0.24), (0.02, 0.0, 1.22), g1),
              ((0.48, 0.46, 0.16), (-0.02, 0.02, 1.4), g3), ((0.42, 0.38, 0.3), (0.5, 0.02, 0.96), g2),
              ((0.42, 0.38, 0.3), (-0.5, 0.0, 0.98), g2), ((0.38, 0.32, 0.26), (0.04, -0.4, 1.02), g3),
              ((0.38, 0.32, 0.26), (-0.02, 0.42, 1.06), g2), ((0.26, 0.24, 0.18), (0.36, -0.26, 1.2), g3),
              ((0.26, 0.24, 0.18), (-0.36, 0.24, 1.22), g3), ((0.22, 0.2, 0.16), (-0.34, -0.28, 0.84), g1)]
    for size, center, mat in blocks:
        kit.add(kit.brick(size, center=center), mat, "Canopy", bevel=0.05)
    for x, y, z in ((0.22, -0.44, 0.92), (-0.4, -0.3, 1.12), (0.5, -0.18, 1.08), (-0.12, -0.48, 1.12), (0.3, 0.3, 1.3)):
        kit.add(kit.brick((0.06, 0.06, 0.06), center=(x, y, z), rot=(0, 0, 45)), cyan, "Canopy", bevel=0.012)
    for x, y, z in ((-0.2, -0.44, 0.9), (0.42, -0.2, 0.86), (-0.52, -0.16, 0.86)):
        kit.add(kit.brick((0.05, 0.05, 0.07), center=(x, y, z)), acorn, "Canopy", bevel=0.012)
        kit.add(kit.brick((0.07, 0.07, 0.03), center=(x, y, z + 0.045)), bark2, "Canopy", bevel=0.008)
    kit.part("Canopy", "Canopy", pivot=(0, 0, 0.8))
    return kit.result()
