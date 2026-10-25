"""Pingouin Comète (Épique, Absurdes) : « Glisse sur le ventre à toute vitesse, une traînée de comète derrière lui. »

En briques LEGO, très détaillé (Épique : émail, chrome et cristal, aucune lueur) : pingouin couché sur le ventre comme
une luge, dos noir laqué, ventre blanc, bec et pattes orange, joues roses, yeux plissés de plaisir, petites lunettes
d'aviateur chromées sur le front ; derrière lui une TRAÎNÉE DE COMÈTE en éclats de cristal bleu glacier et blanc qui
s'effilent. Parties animées : nageoires (battent), tête, pattes, traînée.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.enamel("dos", "#1E1E2A")
    white = kit.mat("ventre", "#FFFFFF")
    orange = kit.enamel("bec", "#FF8A12")
    pink = kit.mat("joues", "#FF9AB4")
    chrome = kit.chrome("lunettes")
    lens = kit.gem("verres", "#0A2A5A", "#5AB4FF", "#E6F6FF")
    ice = kit.gem("glace", "#0A3A6A", "#6ACBFF", "#F0FAFF")
    snow = kit.gem("neige", "#5A7AA8", "#C8E6FF", "#FFFFFF")

    # --- corps couché comme une luge ---
    kit.add(kit.brick((0.5, 0.86, 0.3), center=(0, 0.06, 0.2)), black, bevel=0.07)
    kit.add(kit.brick((0.42, 0.8, 0.06), center=(0, 0.06, 0.04)), white, bevel=0.02)
    kit.add(kit.brick((0.44, 0.7, 0.12), center=(0, 0.04, 0.37)), black, bevel=0.04)
    for s in (-1, 1):
        kit.add(kit.box((0.03, 0.66, 0.12), center=(s * 0.25, 0.06, 0.12)), white, bevel=0.01)

    # --- tête relevée, bec, joues, lunettes d'aviateur ---
    kit.add(kit.brick((0.42, 0.36, 0.34), center=(0, -0.44, 0.34)), black, "Head", bevel=0.06)
    kit.add(kit.brick((0.34, 0.06, 0.24), center=(0, -0.62, 0.3)), white, "Head", bevel=0.03)
    kit.add(kit.brick((0.14, 0.14, 0.08), center=(0, -0.72, 0.28)), orange, "Head", bevel=0.025)
    P.eyes(kit, "Head", x=0.09, y=-0.65, z=0.36, size=0.08, iris="#1A1A2A", pupil="round", lid=black, lid_drop=0.35,
           tall=1.0)
    for s in (-1, 1):
        kit.add(kit.box((0.06, 0.02, 0.04), center=(s * 0.14, -0.655, 0.28)), pink, "Head", bevel=0.005)
        kit.add(kit.brick((0.12, 0.06, 0.1), center=(s * 0.09, -0.52, 0.53)), chrome, "Head", bevel=0.02)
        kit.add(kit.brick((0.09, 0.03, 0.07), center=(s * 0.09, -0.555, 0.53)), lens, "Head", bevel=0.01)
    kit.add(kit.box((0.44, 0.04, 0.04), center=(0, -0.44, 0.52)), chrome, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.28, 0.26))

    # --- nageoires qui battent, pattes orange ---
    for s, part in ((1, "WingL"), (-1, "WingR")):
        kit.add(kit.brick((0.24, 0.3, 0.05), center=(s * 0.34, -0.08, 0.16), rot=(0, s * 10, 0)), black, part, bevel=0.02)
        kit.part(part, "Wing", pivot=(s * 0.24, -0.08, 0.18), phase=float(s))
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.12, 0.16, 0.04), center=(s * 0.1, 0.56, 0.08), rot=(-20, 0, 0)), orange, part, bevel=0.012)
        kit.part(part, "Leg", pivot=(s * 0.1, 0.48, 0.1), phase=0.0 if s > 0 else math.pi)

    # --- traînée de comète en éclats de cristal ---
    for k in range(7):
        y = 0.6 + k * 0.14
        w = 0.36 - k * 0.045
        dx = 0.06 * math.sin(k * 1.7)
        kit.add(kit.brick((w, 0.14, w * 0.5), center=(dx, y, 0.22 + k * 0.02), rot=(0, 0, 45 * (k % 2))),
                ice if k % 2 == 0 else snow, "Trail", bevel=0.012)
    for k in range(4):
        kit.add(kit.brick((0.05, 0.05, 0.05), center=(0.18 * (1 if k % 2 else -1), 0.7 + k * 0.18, 0.36 + 0.04 * k),
                          rot=(45, 45, 0)), snow, "Trail", bevel=0.006)
    kit.part("Trail", "Leaf", pivot=(0, 0.56, 0.2), phase=0.8)
    return kit.result()
