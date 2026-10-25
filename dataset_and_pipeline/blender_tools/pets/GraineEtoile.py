"""Graine d'Étoile (Divin, Plantes) : « Pépite dorée lumineuse entourée d'anneaux. »

En briques LEGO, très détaillée : une graine-pépite d'or LUMINEUX taillée en pyramides de briques (losange vu de face),
facettes plus claires et plus foncées, un petit germe vert à deux feuilles au sommet, un visage tout content (grands
yeux sombres brillants, sourire, joues), et deux anneaux d'or et de lumière inclinés qui tournent autour en sens
inverse, avec des petites étoiles accrochées. Elle flotte. Parties animées : les deux anneaux (tournent).
"""

import math

import _parts as P
from pet_kit import PetKit, rot_matrix
import procedural_geometry_recipes as G


def _ring(kit, part, center, tilt, radius, n, mats, star):
    m = rot_matrix(center, tilt)
    for k in range(n):
        a = 2 * math.pi * k / n
        piece = kit.brick((0.12, 0.05, 0.05), center=(math.cos(a) * radius, math.sin(a) * radius, 0),
                          rot=(0, 0, math.degrees(a) + 90))
        G.transform(piece, m)
        kit.add(piece, mats[k % len(mats)], part, bevel=0.008)
        if k % 4 == 0:
            s = kit.brick((0.06, 0.06, 0.06), center=(math.cos(a) * radius, math.sin(a) * radius, 0.05), rot=(45, 45, 0))
            G.transform(s, m)
            kit.add(s, star, part, bevel=0.006)


def build(name: str) -> dict:
    kit = PetKit(name)
    gold = kit.mat("or", "#FFC21E", metal=0.8, rough=0.18, glow=0.6)
    light = kit.mat("or_clair", "#FFE47A", rough=0.15, glow=1.6)
    deep = kit.mat("or_fonce", "#E0960A", metal=0.85, rough=0.2)
    white = kit.mat("lumiere", "#FFF8DA", rough=0.1, glow=2.6)
    sprout = kit.mat("germe", "#4ED62E")
    leaf = kit.mat("feuille", "#3EC81E")
    pink = kit.mat("joues", "#FF8AB0")
    c = 0.62

    # --- pépite en pyramides de briques ---
    kit.add(kit.brick((0.5, 0.42, 0.22), center=(0, 0, c)), light, bevel=0.04)
    for s in (-1, 1):
        kit.add(kit.brick((0.38, 0.34, 0.12), center=(0, 0, c + s * 0.16)), gold, bevel=0.03)
        kit.add(kit.brick((0.24, 0.22, 0.1), center=(0, 0, c + s * 0.26)), deep if s < 0 else gold, bevel=0.025)
        kit.add(kit.brick((0.1, 0.1, 0.08), center=(0, 0, c + s * 0.34)), deep if s < 0 else light, bevel=0.02)
    for x, z in ((-0.2, c + 0.06), (0.21, c - 0.07)):
        kit.add(kit.box((0.05, 0.02, 0.05), center=(x, -0.215, z), rot=(0, 45, 0)), white, bevel=0.0)
    # visage
    P.eyes(kit, "Body", x=0.085, y=-0.215, z=c + 0.03, size=0.09, iris="#3A2408", pupil="round", sclera="#3A2408",
           tall=1.2)
    P.mouth(kit, "Body", y=-0.216, z=c - 0.07, w=0.1, smile=0.7)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.03), center=(s * 0.15, -0.216, c - 0.04)), pink, bevel=0.004)
    # germe
    P.chain(kit, "Body", [(0, 0, c + 0.38), (0.02, 0, c + 0.46)], 0.035, [sprout])
    for s in (-1, 1):
        P.leaf(kit, "Body", (0.02, 0, c + 0.46), (s * 1.0, 0, 0.6), 0.14, 0.08, leaf, normal=(0, -1, 0.2), droop=0.3,
               segments=2)

    # --- deux anneaux inclinés qui tournent en sens inverse ---
    _ring(kit, "Ring0", (0, 0, c), (68, 0, 18), 0.46, 20, [gold, white], light)
    kit.part("Ring0", "Orbit", pivot=(0, 0, c), rot=(68, 0, 18), phase=0.9)
    _ring(kit, "Ring1", (0, 0, c), (-62, 10, -24), 0.56, 24, [deep, light], white)
    kit.part("Ring1", "Orbit", pivot=(0, 0, c), rot=(-62, 10, -24), phase=-0.6)
    return kit.result()
