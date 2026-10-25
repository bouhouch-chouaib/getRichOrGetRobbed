"""Burrito Nébuleuse (Légendaire, Absurdes) : « Un burrito tiède qui contient une nébuleuse entière. »

En briques LEGO, très détaillé (Légendaire : or martelé et cristal, aucune lueur) : gros burrito couché en travers,
tortilla beige dorée avec taches grillées et plis roulés, le bout droit emballé dans une feuille d'OR martelée froissée ;
par le bout gauche ouvert déborde une NÉBULEUSE en cristaux (violet profond, rose, bleu) avec des étoiles en or qui
tournent ; visage tout content sur le devant (yeux brillants, grand sourire, joues roses).
Parties animées : la nébuleuse (ondule), les étoiles (tournent).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    tortilla = kit.mat("tortilla", "#F2CE8A")
    toast = kit.mat("grille", "#B47A3A")
    fold = kit.mat("pli", "#E0B46A")
    foil = kit.gold("papier_or", hammered=0.7)
    violet = kit.gem("nebuleuse_violet", "#2A0A5A", "#8A3AE6", "#E6C8FF")
    pinkg = kit.gem("nebuleuse_rose", "#5A0A3A", "#FF4AB4", "#FFD8F0")
    blueg = kit.gem("nebuleuse_bleu", "#0A1E5A", "#3A8AFF", "#D8F0FF")
    star = kit.gold("etoiles", tint="#FFE06A", hammered=0.0, rough=0.15)
    pink = kit.mat("joues", "#FF8AB0")

    # --- tortilla roulée couchée en travers, plis et taches grillées ---
    kit.add(kit.brick((1.0, 0.5, 0.46), center=(0, 0, 0.3)), tortilla, bevel=0.1)
    kit.add(kit.brick((0.94, 0.42, 0.56), center=(0, 0, 0.3)), tortilla, bevel=0.1)
    for x in (-0.18, 0.12):
        kit.add(kit.box((0.04, 0.52, 0.03), center=(x, 0, 0.565), rot=(0, 0, 8)), fold, bevel=0.0)
    for x, y in ((-0.3, 0.1), (0.04, 0.12), (-0.1, -0.12), (0.2, 0.05)):
        kit.add(kit.tile(0.06, 0.05, center=(x, y, 0.585), rot=(0, 0, 30)), toast, bevel=0.0)
    for x, z in ((-0.36, 0.42), (0.02, 0.16)):
        kit.add(kit.box((0.06, 0.02, 0.05), center=(x, -0.255, z)), toast, bevel=0.0)

    # --- feuille d'or froissée sur le bout droit ---
    kit.add(kit.brick((0.4, 0.56, 0.6), center=(0.38, 0, 0.3)), foil, bevel=0.06)
    for k in range(5):
        kit.add(kit.wedge((0.06, 0.12, 0.12), center=(0.17, (k - 2) * 0.11, 0.6 - abs(k - 2) * 0.04), rot=(0, 0, k * 20),
                          tip=0.3), foil, bevel=0.0)

    # --- nébuleuse qui déborde par le bout gauche ---
    kit.add(kit.brick((0.06, 0.38, 0.44), center=(-0.53, 0, 0.3)), violet, "Nebula", bevel=0.03)
    for y, z, w, mat in ((-0.12, 0.44, 0.16, pinkg), (0.12, 0.18, 0.14, blueg), (0.14, 0.44, 0.1, blueg),
                         (-0.14, 0.18, 0.12, pinkg), (0.0, 0.3, 0.12, violet)):
        kit.add(kit.brick((w, w, w), center=(-0.6, y, z), rot=(30, 20, 45)), mat, "Nebula", bevel=0.015)
    kit.part("Nebula", "Leaf", pivot=(-0.52, 0, 0.3), phase=0.7)
    for k in range(5):
        a = k * 1.3
        kit.add(kit.brick((0.05, 0.05, 0.05), center=(-0.66, math.cos(a) * 0.2, 0.3 + math.sin(a) * 0.18),
                          rot=(45, 0, 45)), star, "Stars", bevel=0.005)
    kit.part("Stars", "Orbit", pivot=(-0.66, 0, 0.3), rot=(0, -90, 0), phase=0.6)

    # --- visage content sur le devant ---
    P.eyes(kit, "Body", x=0.1, y=-0.26, z=0.36, size=0.11, iris="#3A1E0E", pupil="round", tall=1.15, at=-0.12)
    kit.add(kit.brick((0.14, 0.03, 0.06), center=(-0.12, -0.265, 0.22)), kit.mat("bouche", "#5A1E0A"), bevel=0.015)
    kit.add(kit.brick((0.07, 0.03, 0.025), center=(-0.12, -0.272, 0.205)), kit.mat("langue", "#FF5C8A"), bevel=0.006)
    for s in (-1, 1):
        kit.add(kit.box((0.06, 0.02, 0.04), center=(-0.12 + s * 0.16, -0.262, 0.27)), pink, bevel=0.005)
    return kit.result()
