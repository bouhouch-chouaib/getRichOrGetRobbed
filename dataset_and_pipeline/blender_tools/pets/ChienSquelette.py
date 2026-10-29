"""Chien Squelette (Mythique, Halloween 2026) : « Il enterre ses propres os pour plus tard. »

En briques LEGO, sans lueur (rareté Mythique = nacre + or) : chien en os de nacre (blanc rosé aux reflets bleutés), crâne
au museau carré, orbites noires avec un petit reflet, truffe noire, dents en ligne, oreilles en os ; colonne vertébrale
en vertèbres, cage thoracique en 4 côtes autour d'un creux sombre, bassin ; pattes fines aux os bien marqués ; collier
en or avec une médaille en os ; un os dans la gueule ; queue en vertèbres qui frétille.
Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    bone = kit.pearl("os", color="#F4EEE4", sheen="#D8ECFF")
    bone2 = kit.mat("os_ombre", "#D6CCBE", rough=0.4)
    hollow = kit.mat("creux", "#2A2234", rough=0.4)
    black = kit.mat("noir", "#141218", rough=0.2)
    shine = kit.mat("reflet", "#FFFFFF", rough=0.05)
    gold = kit.gold("or", rough=0.4)

    # --- creux sombre du corps, colonne vertébrale, côtes, bassin ---
    kit.add(kit.brick((0.3, 0.5, 0.24), center=(0, 0.02, 0.62)), hollow, bevel=0.04)
    for k in range(7):
        y = -0.3 + k * 0.1
        kit.add(kit.brick((0.1, 0.07, 0.07), center=(0, y, 0.78)), bone, bevel=0.015)
        kit.add(kit.brick((0.05, 0.035, 0.05), center=(0, y, 0.83)), bone2, bevel=0.008)
    for k in range(4):
        y = -0.24 + k * 0.1
        for s in (-1, 1):
            kit.add(kit.brick((0.05, 0.06, 0.22), center=(s * 0.17, y, 0.66), rot=(0, s * 12, 0)), bone, bevel=0.015)
        kit.add(kit.brick((0.3, 0.06, 0.05), center=(0, y, 0.53)), bone, bevel=0.012)
    kit.add(kit.brick((0.3, 0.14, 0.12), center=(0, 0.3, 0.68)), bone, bevel=0.03)
    kit.add(kit.brick((0.2, 0.06, 0.06), center=(0, 0.375, 0.66)), bone2, bevel=0.012)

    # --- collier en or, médaille en os ---
    kit.add(kit.brick((0.24, 0.1, 0.06), center=(0, -0.38, 0.8), rot=(25, 0, 0)), gold, bevel=0.015)
    kit.add(kit.brick((0.07, 0.03, 0.07), center=(0, -0.44, 0.74), rot=(0, 45, 0)), bone, bevel=0.01)

    # --- crâne : museau carré, orbites, truffe, dents, oreilles, os dans la gueule ---
    kit.add(kit.brick((0.4, 0.34, 0.3), center=(0, -0.52, 1.0)), bone, "Head", bevel=0.05)
    kit.add(kit.brick((0.24, 0.2, 0.14), center=(0, -0.76, 0.92)), bone, "Head", bevel=0.03)
    kit.add(kit.brick((0.2, 0.16, 0.05), center=(0, -0.74, 0.83)), bone2, "Head", bevel=0.012)
    for s in (-1, 1):
        kit.add(kit.box((0.11, 0.03, 0.11), center=(s * 0.1, -0.685, 1.06)), black, "Head", bevel=0.01)
        kit.add(kit.box((0.03, 0.012, 0.03), center=(s * 0.1 - 0.02, -0.703, 1.085)), shine, "Head", bevel=0.0)
        kit.add(kit.brick((0.08, 0.12, 0.18), center=(s * 0.2, -0.46, 1.17), rot=(-10, s * 20, 0)), bone, "Head",
                bevel=0.02)
        kit.add(kit.brick((0.05, 0.06, 0.06), center=(s * 0.24, -0.46, 1.27)), bone2, "Head", bevel=0.01)
    kit.add(kit.brick((0.1, 0.06, 0.06), center=(0, -0.865, 0.98)), black, "Head", bevel=0.015)
    for k in range(5):
        kit.add(kit.box((0.03, 0.03, 0.035), center=(-0.08 + k * 0.04, -0.86, 0.885)), shine, "Head", bevel=0.004)
    # os dans la gueule, en travers
    kit.add(kit.brick((0.4, 0.05, 0.05), center=(0, -0.83, 0.86)), bone, "Head", bevel=0.012)
    for s in (-1, 1):
        for dz in (-0.03, 0.03):
            kit.add(kit.brick((0.06, 0.06, 0.06), center=(s * 0.22, -0.83, 0.86 + dz)), bone, "Head", bevel=0.015)

    # --- pattes en os, queue en vertèbres ---
    P.quad_legs(kit, bone, yf=-0.28, yb=0.3, top_f=0.58, top_b=0.6, length_f=0.58, length_b=0.6, w=0.09, paw=bone,
                toe=bone2, x=0.15, toes=3)
    P.chain(kit, "Tail", [(0, 0.4, 0.7), (0, 0.5, 0.78), (0, 0.58, 0.9), (0, 0.62, 1.02)], 0.06, [bone, bone2],
            taper=0.004)
    kit.part("Tail", "Tail", pivot=(0, 0.38, 0.7))
    kit.part("Head", "Head", pivot=(0, -0.4, 0.84))
    return kit.result()
