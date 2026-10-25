"""Licorne de Bois (Rare, Fantastiques) : « Poney marron à la corne en branche torsadée. »

En briques LEGO, très détaillée : petit poney noisette trapu (torse sculpté, longues pattes à sabots bruns), liste
blanche sur le chanteau, museau clair à naseaux, grands yeux doux à longs cils, crinière en mèches brun foncé parsemée
de feuilles vertes et de petites fleurs, corne en BRANCHE TORSADÉE avec deux feuilles, queue en mèches avec feuilles.
Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    hazel = kit.mat("noisette", "#C07A3E")
    dark = kit.mat("brun_fonce", "#6A3A16")
    light = kit.mat("museau", "#F2C890")
    white = kit.mat("blanc", "#FFFFFF")
    wood = kit.mat("bois", "#8A5A2A")
    bark = kit.mat("ecorce", "#5A3A18")
    leaf = kit.mat("feuille", "#3EDB3A")
    flower = kit.mat("fleur", "#FF7AC8")
    hoof = kit.mat("sabot", "#4A2A14")

    # --- torse de poney ---
    P.quad_torso(kit, L=0.96, W=0.46, H=0.34, z=0.8, y0=0.04, main=hazel, belly=light, chest=hazel, back=hazel)
    kit.add(kit.brick((0.3, 0.3, 0.42), center=(0, -0.44, 1.04), rot=(28, 0, 0)), hazel, bevel=0.04)

    # --- tête : chanfrein long, museau clair, naseaux, yeux à cils, crinière à feuilles, corne-branche ---
    kit.add(kit.brick((0.38, 0.4, 0.34), center=(0, -0.62, 1.32)), hazel, "Head", bevel=0.04)
    kit.add(kit.brick((0.3, 0.3, 0.24), center=(0, -0.9, 1.2)), light, "Head", bevel=0.04)
    kit.add(kit.tile(0.08, 0.34, center=(0, -0.72, 1.495)), white, "Head", bevel=0.005)
    kit.add(kit.box((0.08, 0.02, 0.16), center=(0, -0.825, 1.4)), white, "Head", bevel=0.005)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.05), center=(s * 0.08, -1.055, 1.22)), dark, "Head", bevel=0.0)
        P.ear(kit, "Head", s, (s * 0.14, -0.52, 1.48), w=0.12, h=0.18, color=hazel, inner=light, tilt=(-8, 10))
        for k in range(3):  # cils
            kit.add(kit.box((0.012, 0.012, 0.05), center=(s * (0.14 + k * 0.03), -0.83, 1.46), rot=(0, s * (20 + k * 15), 0)),
                    dark, "Head", bevel=0.0)
    P.mouth(kit, "Head", y=-1.052, z=1.12, w=0.14, smile=0.4)
    P.eyes(kit, "Head", x=0.13, y=-0.82, z=1.38, size=0.12, iris="#6A3410", pupil="round", lid=hazel, lid_drop=0.0)
    P.horn(kit, "Head", (0, -0.66, 1.49), (0, -0.3, 1.0), 0.46, 0.11, [wood, bark], segments=5, twist=55, curl=0.2)
    for s in (-1, 1):
        P.tuft_piece(kit, "Head", (s * 0.04, -0.73, 1.72), (s * 1.0, -0.2, 0.5), 0.16, 0.1, leaf)
    # crinière en mèches avec feuilles et fleurs
    for k in range(5):
        y, z = -0.52 + k * 0.12, 1.5 - k * 0.14
        P.tuft_piece(kit, "Head" if k < 2 else "Body", (0.0, y, z), (0.6, 0.4, 0.3), 0.18, 0.12, dark)
        P.tuft_piece(kit, "Head" if k < 2 else "Body", (-0.04, y + 0.04, z), (-0.6, 0.4, 0.3), 0.16, 0.1, dark)
        if k % 2 == 0:
            kit.add(kit.wedge((0.08, 0.02, 0.06), center=(0.1, y, z), rot=(0, 60, 0), tip=0.2), leaf,
                    "Head" if k < 2 else "Body", bevel=0.0)
        else:
            kit.add(kit.brick((0.05, 0.05, 0.04), center=(-0.1, y, z + 0.02), rot=(0, 0, 45)), flower,
                    "Head" if k < 2 else "Body", bevel=0.006)

    # --- longues pattes à sabots ---
    P.quad_legs(kit, hazel, yf=-0.32, yb=0.38, top_f=0.84, top_b=0.88, length_f=0.82, length_b=0.86, w=0.12,
                paw=hoof, toe=hoof, x=0.15, toes=1)

    # --- queue en mèches avec feuilles ---
    P.bushy_tail(kit, "Tail", [(0, 0.52, 0.94), (0, 0.62, 0.84), (0, 0.68, 0.7), (0, 0.7, 0.54), (0, 0.68, 0.42)],
                 0.14, dark, tip=dark)
    kit.add(kit.wedge((0.08, 0.02, 0.07), center=(0.06, 0.66, 0.72), rot=(0, 50, 0), tip=0.2), leaf, "Tail", bevel=0.0)
    kit.part("Tail", "Tail", pivot=(0, 0.5, 0.94))
    kit.part("Head", "Head", pivot=(0, -0.5, 1.18))
    return kit.result()
