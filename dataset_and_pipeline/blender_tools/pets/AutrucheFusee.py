"""Autruche-Fusée (Commun, Absurdes) : « Autruche pressée avec deux réacteurs sur le dos. »

En briques LEGO, très détaillée (Commun : plastique, aucune lueur) : autruche au gros corps de plumes noires (bouts
d'ailes et queue blancs), long cou rose, petite tête aux énormes yeux à cils et au bec jaune, longues pattes roses à
deux doigts ; sur le dos deux FUSÉES blanches à bandes rouges et ailerons, dont sortent des flammes en briques orange et
jaunes. Parties animées : cou et tête, 2 jambes, ailes, flammes.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.mat("plumes", "#2A2630")
    grey = kit.mat("plumes_grises", "#4A4652")
    white = kit.mat("blanc", "#FFFFFF")
    pink = kit.mat("peau", "#FF9AB4")
    beak = kit.mat("bec", "#FFC21E")
    red = kit.mat("rouge", "#FF2A3A")
    orange = kit.mat("flamme", "#FF7A12")
    yellow = kit.mat("flamme_jaune", "#FFD21E")
    dark = kit.mat("tuyere", "#3A3E48", metal=0.6, rough=0.3)

    # --- gros corps de plumes, queue blanche ---
    kit.add(kit.brick((0.56, 0.7, 0.42), center=(0, 0.04, 0.86)), black, bevel=0.07)
    kit.add(kit.brick((0.46, 0.56, 0.12), center=(0, 0.04, 1.1)), grey, bevel=0.035)
    kit.add(kit.brick((0.46, 0.5, 0.14), center=(0, 0.06, 0.62)), grey, bevel=0.035)
    for k in range(5):
        P.tuft_piece(kit, "Body", ((k - 2) * 0.08, 0.38, 0.92), ((k - 2) * 0.3, 1.0, 0.7), 0.24, 0.1, white)

    # --- ailes à bouts blancs ---
    for s, part in ((1, "WingL"), (-1, "WingR")):
        kit.add(kit.brick((0.08, 0.4, 0.26), center=(s * 0.31, 0.06, 0.88)), black, part, bevel=0.03)
        for k in range(3):
            P.tuft_piece(kit, part, (s * 0.33, 0.12 + k * 0.08, 0.78), (s * 0.3, 0.6, -0.8), 0.16, 0.07, white)
        kit.part(part, "Wing", pivot=(s * 0.28, -0.1, 0.98), phase=float(s))

    # --- deux fusées et leurs flammes ---
    for s in (-1, 1):
        x = s * 0.17
        kit.add(kit.brick((0.16, 0.16, 0.5), center=(x, 0.47, 1.24)), white, bevel=0.04)
        kit.add(kit.brick((0.17, 0.17, 0.06), center=(x, 0.47, 1.28)), red, bevel=0.012)
        kit.add(kit.wedge((0.16, 0.16, 0.16), center=(x, 0.47, 1.56), tip=0.1), red, bevel=0.0)
        kit.add(kit.wedge((0.03, 0.14, 0.14), center=(x + s * 0.09, 0.47, 1.04), rot=(0, 0, 90), tip=0.2), red, bevel=0.0)
        kit.add(kit.brick((0.12, 0.12, 0.06), center=(x, 0.47, 0.96)), dark, bevel=0.012)
        part = f"Flame{0 if s > 0 else 1}"
        for k, (h, mat) in enumerate(((0.3, orange), (0.2, yellow))):
            kit.add(kit.wedge((0.12 - k * 0.04, 0.12 - k * 0.04, h), center=(x, 0.47, 0.93 - h / 2), rot=(180, 0, 0),
                              tip=0.1), mat, part, bevel=0.0)
        kit.part(part, "Leaf", pivot=(x, 0.47, 0.93), phase=1.0 + s)

    # --- long cou rose et petite tête aux grands yeux ---
    P.chain(kit, "Head", [(0, -0.26, 0.98), (0, -0.36, 1.22), (0, -0.4, 1.46)], 0.1, [pink])
    kit.add(kit.brick((0.24, 0.26, 0.2), center=(0, -0.44, 1.58)), pink, "Head", bevel=0.04)
    kit.add(kit.brick((0.12, 0.16, 0.06), center=(0, -0.64, 1.55)), beak, "Head", bevel=0.015)
    kit.add(kit.brick((0.1, 0.12, 0.04), center=(0, -0.62, 1.5)), beak, "Head", bevel=0.012)
    P.eyes(kit, "Head", x=0.07, y=-0.57, z=1.62, size=0.09, iris="#3A1E0E", pupil="round", tall=1.3)
    for s in (-1, 1):
        for k in range(3):
            kit.add(kit.box((0.01, 0.01, 0.04), center=(s * (0.07 + k * 0.025), -0.575, 1.69), rot=(0, s * (20 + k * 18), 0)),
                    black, "Head", bevel=0.0)
    for k in range(3):
        P.tuft_piece(kit, "Head", ((k - 1) * 0.04, -0.44, 1.68), ((k - 1) * 0.4, 0.3, 1.0), 0.1, 0.04, black)
    kit.part("Head", "Head", pivot=(0, -0.26, 0.98))

    # --- longues pattes roses à deux doigts ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        x = s * 0.13
        kit.add(kit.brick((0.12, 0.14, 0.18), center=(x, 0.04, 0.58)), grey, part, bevel=0.03)
        kit.add(kit.brick((0.06, 0.06, 0.48), center=(x, 0.04, 0.26)), pink, part, bevel=0.012)
        for dx, length in ((-0.03, 0.14), (0.03, 0.1)):
            kit.add(kit.brick((0.05, length, 0.04), center=(x + dx, 0.04 - length / 2, 0.02)), pink, part, bevel=0.01)
        kit.part(part, "Leg", pivot=(x, 0.04, 0.66), phase=0.0 if s > 0 else math.pi)
    return kit.result()
