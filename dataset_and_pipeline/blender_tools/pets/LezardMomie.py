"""Lézard Momie (Légendaire, Désert) : « Lézard enroulé dans des bandelettes depuis 3000 ans, et toujours aussi pressé. »

En briques LEGO, très détaillé (Légendaire : or martelé, aucune lueur) : lézard vert jade presque entièrement enroulé
dans des bandelettes crème (bandes de travers, bouts qui pendent, peau verte visible entre elles), un grand œil
pressé qui dépasse, l'autre caché ; large collier égyptien en OR martelé et bleu lapis, scarabée en or sur le dos ;
quatre pattes, longue queue bandée. Parties animées : tête, 4 pattes, queue, bout de bandelette.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    wrap = kit.mat("bandelettes", "#F2E6C8")
    wrap2 = kit.mat("bandelettes_sales", "#D8C8A0")
    skin = kit.mat("peau", "#4EC27A")
    gold = kit.gold("or", hammered=0.4)
    lapis = kit.enamel("lapis", "#1E4ACB")

    # --- corps bas et long sous les bandelettes ---
    P.quad_torso(kit, L=0.9, W=0.36, H=0.24, z=0.32, y0=0.06, main=skin, belly=skin, chest=skin, back=skin)
    for k in range(7):
        y = -0.3 + k * 0.11
        kit.add(kit.brick((0.4, 0.07, 0.3), center=(0, y, 0.33), rot=(0, (k % 3 - 1) * 8, 0)), wrap if k % 2 else wrap2,
                bevel=0.012)
    kit.add(kit.brick((0.08, 0.06, 0.16), center=(0.21, 0.1, 0.22), rot=(0, 0, 20)), wrap, "Strip", bevel=0.008)
    kit.part("Strip", "Leaf", pivot=(0.2, 0.1, 0.3), phase=0.8)
    # scarabée en or sur le dos
    kit.add(kit.brick((0.14, 0.18, 0.05), center=(0, 0.12, 0.49)), gold, bevel=0.02)
    for s in (-1, 1):
        kit.add(kit.wedge((0.1, 0.03, 0.08), center=(s * 0.1, 0.12, 0.49), rot=(90, 0, s * 70), tip=0.3), gold, bevel=0.0)

    # --- tête : bandelettes, un œil pressé, collier égyptien ---
    kit.add(kit.brick((0.3, 0.36, 0.22), center=(0, -0.58, 0.4)), skin, "Head", bevel=0.04)
    kit.add(kit.brick((0.22, 0.16, 0.12), center=(0, -0.82, 0.36)), skin, "Head", bevel=0.025)
    for k, (y, rot) in enumerate(((-0.5, 10), (-0.62, -12), (-0.74, 8))):
        kit.add(kit.brick((0.34 - k * 0.04, 0.06, 0.26 - k * 0.04), center=(0, y, 0.41), rot=(0, rot, 0)), wrap, "Head",
                bevel=0.01)
    kit.add(kit.box((0.12, 0.05, 0.08), center=(-0.08, -0.69, 0.47), rot=(0, 20, 0)), wrap2, "Head", bevel=0.008)
    P.eyes(kit, "Head", x=0.09, y=-0.71, z=0.47, size=0.11, iris="#FFB21E", pupil="slit", tall=1.15, at=0.0)
    kit.add(kit.box((0.14, 0.06, 0.14), center=(-0.09, -0.725, 0.47)), wrap, "Head", bevel=0.01)
    P.mouth(kit, "Head", y=-0.905, z=0.33, w=0.12, smile=0.4)
    kit.part("Head", "Head", pivot=(0, -0.4, 0.36))
    for k in range(5):
        a = math.radians(-60 + 30 * k)
        kit.add(kit.brick((0.08, 0.05, 0.12), center=(math.sin(a) * 0.2, -0.42 - math.cos(a) * 0.05, 0.4)),
                gold if k % 2 == 0 else lapis, bevel=0.01)

    # --- pattes et queue bandées ---
    P.quad_legs(kit, skin, yf=-0.26, yb=0.34, top_f=0.32, top_b=0.34, length_f=0.3, length_b=0.32, w=0.09, paw=wrap,
                toe=skin, x=0.2, toes=3)
    P.chain(kit, "Tail", [(0, 0.5, 0.3), (0.06, 0.72, 0.24), (0.0, 0.92, 0.2), (-0.08, 1.08, 0.18)], 0.12,
            [wrap, skin, wrap2], taper=0.025)
    kit.part("Tail", "Tail", pivot=(0, 0.48, 0.3))
    return kit.result()
