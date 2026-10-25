"""Tréflant à 4 Feuilles (Légendaire, Plantes) : « Gros trèfle émeraude qui sème des pièces d'or. »

En briques LEGO, très détaillé : grand trèfle à quatre feuilles debout, face au joueur : quatre feuilles en cœur vert
émeraude (deux lobes et une pointe vers le centre), chevron vert clair sur chacune, une pièce d'or à trèfle sur chaque
feuille ; au centre, un moyeu vert foncé avec un visage rieur (yeux brillants, grand sourire, joues roses) ; petite
tige recourbée derrière. Il roule comme une roue en semant ses pièces. Parties animées : les quatre feuilles frémissent.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    emerald = kit.mat("emeraude", "#18C25A", rough=0.15)
    dark = kit.mat("emeraude_fonce", "#0E8A3E", rough=0.15)
    light = kit.mat("chevron", "#8AF2A8")
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.18)
    gold2 = kit.mat("or_fonce", "#D8960A", metal=0.85, rough=0.22)
    pink = kit.mat("joues", "#FF8AB0")
    c = 0.62  # hauteur du centre de la roue

    # --- quatre feuilles en cœur, en croix diagonale ---
    for k in range(4):
        a = math.radians(45 + 90 * k)
        r = (math.cos(a), math.sin(a))
        t = (-math.sin(a), math.cos(a))
        deg = -math.degrees(a)
        part = f"Leaf{k}"
        for side in (-1, 1):
            cx, cz = r[0] * 0.36 + t[0] * side * 0.1, c + r[1] * 0.36 + t[1] * side * 0.1
            kit.add(kit.brick((0.24, 0.1, 0.22), center=(cx, 0.0, cz), rot=(0, deg, 0)), emerald, part, bevel=0.05)
        kit.add(kit.wedge((0.3, 0.09, 0.2), center=(r[0] * 0.2, 0.0, c + r[1] * 0.2), rot=(0, deg + 90, 0), tip=0.15),
                emerald, part, bevel=0.01)
        kit.add(kit.brick((0.3, 0.1, 0.06), center=(r[0] * 0.47, 0.0, c + r[1] * 0.47), rot=(0, deg, 0)), dark, part,
                bevel=0.02)
        for side in (-1, 1):
            vx, vz = r[0] * 0.3 + t[0] * side * 0.05, c + r[1] * 0.3 + t[1] * side * 0.05
            kit.add(kit.box((0.12, 0.02, 0.025), center=(vx, -0.055, vz), rot=(0, deg + side * 35, 0)), light, part,
                    bevel=0.0)
        kit.add(kit.disc(0.065, 0.025, center=(r[0] * 0.4, -0.065, c + r[1] * 0.4), normal=(0, -1, 0)), gold, part,
                bevel=0.0)
        kit.add(kit.box((0.04, 0.012, 0.04), center=(r[0] * 0.4, -0.08, c + r[1] * 0.4), rot=(0, 45, 0)), gold2, part,
                bevel=0.0)
        kit.part(part, "Leaf", pivot=(0, 0, c), phase=k * 1.6)

    # --- moyeu avec visage, tige recourbée derrière ---
    kit.add(kit.brick((0.3, 0.16, 0.3), center=(0, 0.0, c)), dark, bevel=0.06)
    kit.add(kit.brick((0.24, 0.04, 0.24), center=(0, -0.09, c)), emerald, bevel=0.02)
    P.eyes(kit, "Body", x=0.055, y=-0.11, z=c + 0.04, size=0.07, iris="#0A3A1A", pupil="round", tall=1.15)
    P.mouth(kit, "Body", y=-0.111, z=c - 0.06, w=0.1, smile=0.8)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.02, 0.03), center=(s * 0.09, -0.112, c - 0.03)), pink, bevel=0.004)
    P.chain(kit, "Body", [(0, 0.08, c), (0.0, 0.18, c - 0.04), (0.06, 0.22, c - 0.12)], 0.05, [dark])
    return kit.result()
