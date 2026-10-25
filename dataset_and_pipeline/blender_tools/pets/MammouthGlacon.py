"""Mammouth Glaçon (Mythique, Glace) : « Mammouth resté coincé dans un glaçon pendant 10 000 ans. »

En briques LEGO, très détaillé (Mythique : nacre et cristal, aucune lueur) : mammouth laineux brun roux (mèches qui
pendent), tête bombée, petits yeux étonnés, petites oreilles, longue trompe qui se balance, grandes défenses courbes
en NACRE ; tout l'arrière-train est encore pris dans un gros GLAÇON de cristal bleu glacier à facettes, avec des
stalactites ; un peu de neige sur le dos. Parties animées : tête, trompe, pattes avant, oreilles.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    wool = kit.mat("laine", "#9A5A32", rough=0.5)
    wool2 = kit.mat("laine_foncee", "#6E3A1E", rough=0.5)
    skin = kit.mat("trompe", "#7A4A2E")
    pearl = kit.pearl("defenses", color="#FFF6E8", sheen="#E8F4FF")
    ice = kit.gem("glacon", "#3A7AB4", "#A8DCFF", "#FFFFFF")
    ice2 = kit.gem("glacon_clair", "#7AB4DC", "#D8F2FF", "#FFFFFF")
    snow = kit.mat("neige", "#FFFFFF", rough=0.4)

    # --- corps laineux, mèches ---
    P.quad_torso(kit, L=0.96, W=0.6, H=0.46, z=0.72, y0=0.08, main=wool, belly=wool2, chest=wool, back=wool)
    for x in (-0.28, -0.1, 0.1, 0.28):
        for y in (-0.28, -0.08):
            kit.add(kit.wedge((0.1, 0.06, 0.24), center=(x, y, 0.42), rot=(180, 0, 0), tip=0.3),
                    wool2, bevel=0.0)
    kit.add(kit.tile(0.3, 0.2, center=(0, -0.1, 1.02)), snow, bevel=0.006)

    # --- le gros glaçon qui emprisonne l'arrière ---
    kit.add(kit.brick((0.86, 0.6, 0.86), center=(0, 0.42, 0.5)), ice, bevel=0.05)
    kit.add(kit.brick((0.7, 0.66, 0.7), center=(0.04, 0.44, 0.56), rot=(0, 8, 12)), ice2, bevel=0.04)
    for x in (-0.3, -0.1, 0.12, 0.32):
        kit.add(kit.wedge((0.08, 0.08, 0.14), center=(x, 0.14, 0.02), rot=(180, 0, 0), tip=0.1), ice2, bevel=0.0)
    for x, z in ((0.44, 0.7), (-0.44, 0.4)):
        kit.add(kit.brick((0.1, 0.12, 0.2), center=(x, 0.4, z), rot=(20, 30, 15)), ice2, bevel=0.012)

    # --- tête bombée, yeux étonnés, défenses de nacre ---
    kit.add(kit.brick((0.5, 0.44, 0.46), center=(0, -0.42, 0.96)), wool, "Head", bevel=0.07)
    kit.add(kit.brick((0.36, 0.3, 0.12), center=(0, -0.4, 1.22)), wool2, "Head", bevel=0.04)
    P.eyes(kit, "Head", x=0.13, y=-0.645, z=1.0, size=0.08, iris="#2A1A0E", pupil="round", tall=1.2, look=(0, 0.4))
    for s in (-1, 1):
        pts = [(s * 0.13, -0.6, 0.78), (s * 0.18, -0.74, 0.64), (s * 0.2, -0.86, 0.66), (s * 0.16, -0.94, 0.78)]
        P.chain(kit, "Head", pts, 0.08, [pearl], taper=0.012)
    kit.part("Head", "Head", pivot=(0, -0.28, 0.82))
    for s, part in ((1, "EarL"), (-1, "EarR")):
        kit.add(kit.brick((0.08, 0.14, 0.16), center=(s * 0.28, -0.36, 1.0)), wool2, part, bevel=0.03)
        kit.part(part, "Ear", pivot=(s * 0.25, -0.36, 1.04), phase=float(s))
    # trompe qui se balance
    P.chain(kit, "Trunk", [(0, -0.64, 0.86), (0, -0.72, 0.66), (0, -0.74, 0.46), (0.02, -0.7, 0.3), (0.06, -0.62, 0.22)],
            0.12, [skin, wool2], taper=0.018)
    kit.part("Trunk", "Tentacle", pivot=(0, -0.64, 0.86), phase=0.4)

    # --- pattes avant (les arrière sont dans la glace) ---
    for s, part in ((1, "LegFL"), (-1, "LegFR")):
        kit.add(kit.brick((0.18, 0.2, 0.5), center=(s * 0.2, -0.26, 0.26)), wool, part, bevel=0.04)
        kit.add(kit.brick((0.2, 0.22, 0.06), center=(s * 0.2, -0.27, 0.03)), wool2, part, bevel=0.02)
        kit.part(part, "Leg", pivot=(s * 0.2, -0.26, 0.5), phase=0.0 if s > 0 else math.pi)
    return kit.result()
