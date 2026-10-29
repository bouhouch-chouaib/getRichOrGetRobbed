"""Chat-Citrouille (Rare, Halloween 2026) : « Chat noir qui a fait sa maison dans une citrouille. »

En briques LEGO, sans lueur (rareté Rare = émail) : grosse citrouille orange émaillée en côtes (lobes clairs et foncés),
fenêtre sculptée sur le flanc, d'où sort un chat noir : tête aux grands yeux jaunes à pupille fendue, oreilles à
intérieur rose, truffe rose, moustaches blanches, petites pattes avant posées sur le bord, petite tige verte sur la tête
comme un chapeau. Quatre courtes pattes noires sous la citrouille, longue queue noire qui s'enroule derrière.
Parties animées : tête, 4 pattes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    orange = kit.enamel("orange", "#FF7A12")
    light = kit.enamel("orange_clair", "#FF9C3E")
    dark = kit.mat("orange_fonce", "#D85204")
    hollow = kit.mat("creux", "#3A1404")
    black = kit.mat("noir", "#24202C")
    black2 = kit.mat("noir_doux", "#3A3446")
    pink = kit.mat("rose", "#FF8FB1")
    stem = kit.mat("tige", "#5E8A1E")
    leaf = kit.mat("feuille", "#3EC22E")

    # --- citrouille en côtes : lobes autour d'un cœur ---
    kit.add(kit.brick((0.68, 0.62, 0.5), center=(0, 0.04, 0.5)), orange, bevel=0.05)
    for k in range(10):
        a = math.radians(-90 + 36 * k)
        kit.add(kit.brick((0.24, 0.24, 0.52), center=(math.cos(a) * 0.36, 0.04 + math.sin(a) * 0.33, 0.5),
                          rot=(0, 0, math.degrees(a))), light if k % 2 == 0 else orange, bevel=0.07)
    kit.add(kit.brick((0.52, 0.48, 0.06), center=(0, 0.04, 0.785)), dark, bevel=0.02)
    kit.add(kit.brick((0.58, 0.54, 0.07), center=(0, 0.04, 0.24)), dark, bevel=0.02)
    # fenêtre ronde sculptée sur le flanc gauche (+X) et petite porte à l'arrière
    kit.add(kit.box((0.03, 0.16, 0.14), center=(0.47, 0.06, 0.55)), hollow, bevel=0.0)
    kit.add(kit.box((0.02, 0.02, 0.15), center=(0.485, 0.06, 0.55)), dark, bevel=0.0)
    kit.add(kit.box((0.18, 0.03, 0.2), center=(0, 0.45, 0.42)), hollow, bevel=0.0)

    # --- tête du chat qui sort du dessus ---
    kit.add(kit.brick((0.44, 0.36, 0.32), center=(0, -0.12, 0.98)), black, "Head", bevel=0.05)
    kit.add(kit.brick((0.36, 0.3, 0.06), center=(0, -0.1, 1.16)), black, "Head", bevel=0.015)
    kit.add(kit.brick((0.2, 0.08, 0.1), center=(0, -0.31, 0.92)), black2, "Head", bevel=0.02)
    for s in (-1, 1):
        P.ear(kit, "Head", s, (s * 0.14, -0.06, 1.17), w=0.17, h=0.22, color=black, inner=pink, tilt=(-6, 12))
        P.tuft_piece(kit, "Head", (s * 0.22, -0.16, 0.92), (s, -0.2, -0.2), 0.09, 0.06, black)
    P.eyes(kit, "Head", x=0.1, y=-0.3, z=1.02, size=0.13, iris="#FFD21E", pupil="slit", tall=1.05)
    P.nose(kit, "Head", y=-0.355, z=0.95, w=0.06, color="#FF8FB1", nostril="#B4466A")
    P.mouth(kit, "Head", y=-0.355, z=0.89, w=0.1, smile=0.4)
    P.whiskers(kit, "Head", x=0.09, y=-0.33, z=0.93, color="#FFFFFF", n=3, length=0.13)
    # petite tige de citrouille posée sur la tête, comme un chapeau, et sa feuille
    kit.add(kit.brick((0.07, 0.07, 0.12), center=(0.04, -0.08, 1.25), rot=(0, 12, 0)), stem, "Head", bevel=0.015)
    P.leaf(kit, "Head", (0.07, -0.08, 1.27), (0.8, 0.2, 0.3), 0.14, 0.09, leaf, normal=(0, 0, 1), droop=0.15)
    # pattes avant posées sur le bord de la citrouille
    for s in (-1, 1):
        kit.add(kit.brick((0.1, 0.12, 0.06), center=(s * 0.13, -0.3, 0.82)), black, bevel=0.02)
        for k in (-1, 0, 1):
            kit.add(kit.brick((0.025, 0.03, 0.03), center=(s * 0.13 + k * 0.03, -0.37, 0.81)), black2, bevel=0.004)

    # --- courtes pattes sous la citrouille, queue qui s'enroule ---
    P.quad_legs(kit, black, yf=-0.18, yb=0.26, top_f=0.3, top_b=0.3, length_f=0.3, length_b=0.3, w=0.1, paw=black2,
                toe=black2, x=0.2, toes=3)
    P.chain(kit, "Tail", [(0, 0.42, 0.5), (0, 0.56, 0.58), (0, 0.66, 0.74), (0, 0.66, 0.92), (0, 0.58, 1.04),
                          (0, 0.48, 1.06)], 0.09, [black, black2], taper=0.006)
    kit.part("Tail", "Tail", pivot=(0, 0.4, 0.5))
    kit.part("Head", "Head", pivot=(0, -0.1, 0.84))
    return kit.result()
