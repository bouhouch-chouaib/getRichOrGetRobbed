"""Fennec à Lunettes (Inhabituel, Désert) : « Petit fennec aux grandes oreilles, lunettes de soleil vissées sur le nez. »

En briques LEGO, très détaillé (Inhabituel : émail, aucune lueur) : petit renard des sables crème doré, oreilles
IMMENSES à intérieur rose, museau fin à truffe noire, lunettes de soleil noires laquées à monture
orange, sourire satisfait, ventre et chaussettes blancs, grosse queue touffue à bout noir.
Parties animées : tête, oreilles, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    sand = kit.mat("sable", "#F2C27A")
    deep = kit.mat("sable_fonce", "#D89A4A")
    cream = kit.mat("creme", "#FFF4DE")
    pink = kit.mat("rose", "#FF9AB4")
    lens = kit.enamel("verres", "#141418")
    frame = kit.enamel("monture", "#FF7A1E")
    black = kit.mat("noir", "#1E1614")

    P.quad_torso(kit, L=0.62, W=0.34, H=0.26, z=0.44, y0=0.05, main=sand, belly=cream, chest=cream, back=deep)
    kit.add(kit.brick((0.22, 0.2, 0.24), center=(0, -0.3, 0.6), rot=(22, 0, 0)), sand, bevel=0.03)

    kit.add(kit.brick((0.36, 0.3, 0.26), center=(0, -0.44, 0.78)), sand, "Head", bevel=0.04)
    kit.add(kit.brick((0.18, 0.2, 0.1), center=(0, -0.64, 0.72)), cream, "Head", bevel=0.025)
    kit.add(kit.slope((0.18, 0.18, 0.06), center=(0, -0.63, 0.8), facing="-Y", top=0.3), sand, "Head", bevel=0.01)
    P.nose(kit, "Head", y=-0.74, z=0.76, w=0.06, color="#1E1614")
    P.mouth(kit, "Head", y=-0.742, z=0.69, w=0.1, smile=0.7)
    for s in (-1, 1):
        kit.add(kit.brick((0.13, 0.04, 0.09), center=(s * 0.085, -0.6, 0.86)), lens, "Head", bevel=0.02)
        kit.add(kit.box((0.04, 0.012, 0.02), center=(s * 0.11, -0.625, 0.885)), cream, "Head", bevel=0.0)
        kit.add(kit.box((0.04, 0.2, 0.02), center=(s * 0.16, -0.5, 0.87)), frame, "Head", bevel=0.0)
    kit.add(kit.box((0.06, 0.03, 0.02), center=(0, -0.6, 0.875)), frame, "Head", bevel=0.0)
    kit.add(kit.box((0.32, 0.03, 0.02), center=(0, -0.625, 0.91)), frame, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.3, 0.66))
    for s, part in ((1, "EarL"), (-1, "EarR")):
        P.ear(kit, part, s, (s * 0.12, -0.42, 0.9), w=0.22, h=0.4, color=sand, inner=pink, tilt=(-5, 18), depth=0.07)
        kit.part(part, "Ear", pivot=(s * 0.12, -0.42, 0.9), phase=float(s))

    P.quad_legs(kit, sand, yf=-0.18, yb=0.26, top_f=0.46, top_b=0.48, length_f=0.44, length_b=0.46, w=0.09, paw=cream,
                toe=cream, x=0.11, toes=3)
    P.bushy_tail(kit, "Tail", [(0, 0.34, 0.5), (0, 0.5, 0.52), (0, 0.64, 0.6), (0, 0.72, 0.72), (0, 0.74, 0.84)], 0.18,
                 sand, tip=black)
    kit.part("Tail", "Tail", pivot=(0, 0.32, 0.5))
    return kit.result()
