"""Slime Gl gl (Commun, Fantastiques) : « Cube de gelée verte transparente. »

En briques LEGO, très détaillé : un cube de gelée vert pomme très brillant, plus clair sur les arêtes (effet gélatine),
reflets blancs en traits sur les faces, bulles claires prises dans la gelée, gouttes qui coulent sur les bords et
petite flaque au sol, une pièce d'or coincée à moitié dans le flanc, grands yeux noirs brillants, grande bouche ouverte
heureuse avec langue, joues roses. Partie animée : le corps rebondit (profil Slime du jeu).
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.mat("vert", "#5CF03A", rough=0.06)
    light = kit.mat("vert_clair", "#B6FF7A", rough=0.06)
    deep = kit.mat("vert_fonce", "#2EB82A", rough=0.08)
    shine = kit.mat("reflet", "#FFFFFF", rough=0.03)
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.2)
    pink = kit.mat("joues", "#FF8FB0")
    mouth = kit.mat("bouche", "#145A1A")
    tongue = kit.mat("langue", "#FF5C8A")

    # --- cube de gelée, arêtes claires, flaque ---
    kit.add(kit.brick((0.7, 0.66, 0.6), center=(0, 0, 0.36)), green, bevel=0.07)
    kit.add(kit.brick((0.6, 0.56, 0.06), center=(0, 0, 0.69)), light, bevel=0.03)
    for s in (-1, 1):
        kit.add(kit.box((0.06, 0.06, 0.56), center=(s * 0.34, -0.31, 0.36)), light, bevel=0.02)
        kit.add(kit.box((0.06, 0.06, 0.56), center=(s * 0.34, 0.31, 0.36)), light, bevel=0.02)
    kit.add(kit.brick((0.86, 0.8, 0.04), center=(0.02, 0.02, 0.02)), light, bevel=0.015)
    # reflets et bulles
    for x, z, h in ((0.27, 0.17, 0.12), (0.31, 0.19, 0.06)):
        kit.add(kit.box((0.04, 0.012, h), center=(x, -0.335, z), rot=(0, 20, 0)), shine, bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.box((0.012, 0.18, 0.04), center=(s * 0.352, -0.05, 0.56), rot=(20, 0, 0)), shine, bevel=0.0)
    for x, y, z, w in ((0.24, 0.0, 0.62, 0.06), (0.36, 0.2, 0.3, 0.05), (-0.36, 0.12, 0.2, 0.07), (0.1, 0.34, 0.5, 0.05)):
        kit.add(kit.brick((w, w, w), center=(x, y, z)), light, bevel=0.012)
    # gouttes qui coulent
    for x, y, h in ((0.24, -0.33, 0.14), (-0.3, 0.33, 0.12), (0.35, 0.2, 0.1)):
        kit.add(kit.brick((0.08, 0.08, h), center=(x, y, 0.08 + h / 2)), deep, bevel=0.025)
    # pièce d'or coincée dans le flanc
    kit.add(kit.disc(0.11, 0.03, center=(0.355, 0.08, 0.34), normal=(1, 0, 0.2)), gold, bevel=0.006)

    # --- visage : grands yeux, bouche ouverte heureuse, langue, joues ---
    P.eyes(kit, "Body", x=0.15, y=-0.335, z=0.47, size=0.14, iris="#101014", pupil="round", sclera="#101014", tall=1.15)
    kit.add(kit.brick((0.26, 0.03, 0.12), center=(0, -0.335, 0.27)), mouth, bevel=0.02)
    kit.add(kit.brick((0.14, 0.03, 0.05), center=(0, -0.345, 0.235)), tongue, bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.box((0.09, 0.02, 0.05), center=(s * 0.24, -0.34, 0.36)), pink, bevel=0.006)
    return kit.result()
