"""Méduse Lampion (Légendaire, Abysses) : « Méduse qui flotte comme une lanterne de papier. »

En briques LEGO, très détaillée (Légendaire : or martelé, aucune lueur) : méduse dont la cloche est un LAMPION de
papier rose et corail tendu sur des arceaux en OR martelé, chapeau et anneau du bas en or, petit pompon ; visage
paisible sur le lampion (yeux fermés de bonheur, petit sourire, joues) ; dessous, des tentacules-pompons en rubans
roses et dorés et des glands qui ondulent. Elle flotte. Parties animées : six tentacules.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    paper = kit.enamel("papier", "#FF8AB4")
    paper2 = kit.enamel("papier_corail", "#FF6A7A")
    gold = kit.gold("arceaux", hammered=0.3)
    ribbon = kit.mat("rubans", "#FFB8D8")
    dark = kit.mat("traits", "#5A1A2A")
    blush = kit.mat("joues", "#FF4A6A")

    # --- cloche-lampion en couches, arceaux d'or ---
    for z, w, h in ((0.5, 0.62, 0.12), (0.64, 0.72, 0.16), (0.8, 0.7, 0.16), (0.94, 0.56, 0.12), (1.04, 0.36, 0.08)):
        kit.add(kit.brick((w, w, h), center=(0, 0, z)), paper, bevel=min(0.05, h * 0.35))
        # couche tournée de 45° plus petite (coins derrière le visage) et un peu plus haute (faces confondues = noir)
        kit.add(kit.brick((w * 0.7, w * 0.7, h + 0.012), center=(0, 0, z), rot=(0, 0, 45)), paper2,
                bevel=min(0.05, h * 0.35))
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        kit.add(kit.box((0.03, 0.03, 0.5), center=(math.cos(a) * 0.36, math.sin(a) * 0.36, 0.74)), gold, bevel=0.0)
    kit.add(kit.brick((0.44, 0.44, 0.05), center=(0, 0, 0.43)), gold, bevel=0.012)
    kit.add(kit.brick((0.2, 0.2, 0.08), center=(0, 0, 1.12)), gold, bevel=0.02)
    kit.add(kit.brick((0.08, 0.08, 0.08), center=(0, 0, 1.2)), ribbon, bevel=0.03)

    # --- visage paisible sur une plaque de papier clair (sinon il se perd entre les couches) ---
    face = kit.enamel("visage", "#FFF0F4")
    kit.add(kit.brick((0.42, 0.05, 0.3), center=(0, -0.375, 0.72)), face, bevel=0.02)
    kit.add(kit.brick((0.46, 0.04, 0.03), center=(0, -0.38, 0.88)), gold, bevel=0.008)
    kit.add(kit.brick((0.46, 0.04, 0.03), center=(0, -0.38, 0.56)), gold, bevel=0.008)
    for s in (-1, 1):
        kit.add(kit.box((0.1, 0.03, 0.03), center=(s * 0.09, -0.405, 0.77), rot=(0, s * -14, 0)), dark, bevel=0.0)
        kit.add(kit.box((0.07, 0.02, 0.04), center=(s * 0.15, -0.402, 0.68)), blush, bevel=0.005)
    P.mouth(kit, "Body", y=-0.402, z=0.64, w=0.1, smile=0.7, color="#5A1A2A")

    # --- tentacules-pompons qui ondulent ---
    for k in range(6):
        a = math.radians(60 * k + 30)
        part = f"Tentacle{k}"
        bx, by = math.cos(a) * 0.18, math.sin(a) * 0.18
        P.chain(kit, part, [(bx, by, 0.42), (bx * 1.15, by * 1.15, 0.3), (bx * 1.1, by * 1.1, 0.18), (bx * 1.2, by * 1.2, 0.08)],
                0.04, [ribbon, gold], height=0.03)
        kit.add(kit.wedge((0.06, 0.06, 0.08), center=(bx * 1.2, by * 1.2, 0.03), rot=(180, 0, 0), tip=0.3), gold, part,
                bevel=0.0)
        kit.part(part, "Tentacle", pivot=(bx, by, 0.42), phase=k * 1.0)
    return kit.result()
