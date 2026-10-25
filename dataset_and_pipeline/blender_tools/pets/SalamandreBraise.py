"""Salamandre Braise (Rare, Volcan) : « Salamandre brûlante qui fait griller tout ce qu'elle touche. »

En briques LEGO, très détaillée (Rare : émail, aucune lueur) : salamandre rouge braise laquée, grosses taches jaune
or et orange sur le dos, ventre orange vif, crête de petites flammes émaillées le long de l'échine, tête plate au
grand sourire, yeux ronds dorés, pattes écartées à doigts ronds, longue queue qui ondule et finit en flammèche.
Parties animées : tête, 4 pattes, queue, crête de flammes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    red = kit.enamel("braise", "#E8321E")
    dark = kit.enamel("braise_fonce", "#A81A10")
    orange = kit.enamel("ventre", "#FF8A1E")
    yellow = kit.enamel("taches", "#FFC21E")
    black = kit.mat("noir", "#1E1210")

    # --- corps bas et long, taches, ventre ---
    P.quad_torso(kit, L=0.86, W=0.38, H=0.2, z=0.24, y0=0.06, main=red, belly=orange, chest=orange, back=dark)
    for x, y, w, mat in ((0.1, -0.2, 0.1, yellow), (-0.08, 0.0, 0.12, orange), (0.08, 0.2, 0.09, yellow),
                         (-0.1, 0.32, 0.08, yellow), (0.14, 0.04, 0.06, orange)):
        kit.add(kit.tile(w, w, center=(x, y, 0.36), rot=(0, 0, 30)), mat, bevel=0.004)
    for k in range(5):
        y = -0.24 + k * 0.14
        P.tuft_piece(kit, "Crest", (0, y, 0.35), (0, 0.4, 1.0), 0.12 - abs(k - 2) * 0.015, 0.07, yellow if k % 2 else orange)
    kit.part("Crest", "Leaf", pivot=(0, 0.0, 0.36), phase=0.5)

    # --- tête plate, grand sourire, yeux dorés ---
    kit.add(kit.brick((0.36, 0.36, 0.18), center=(0, -0.56, 0.3)), red, "Head", bevel=0.04)
    kit.add(kit.brick((0.3, 0.2, 0.06), center=(0, -0.62, 0.21)), orange, "Head", bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.brick((0.12, 0.12, 0.1), center=(s * 0.12, -0.6, 0.42)), red, "Head", bevel=0.03)
    P.eyes(kit, "Head", x=0.12, y=-0.665, z=0.44, size=0.09, iris="#FFB21E", pupil="round", tall=1.1)
    kit.add(kit.box((0.26, 0.02, 0.02), center=(0, -0.745, 0.26)), black, "Head", bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.02), center=(s * 0.14, -0.745, 0.275), rot=(0, s * -30, 0)), black, "Head", bevel=0.0)
        kit.add(kit.box((0.03, 0.02, 0.02), center=(s * 0.05, -0.745, 0.33)), black, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.38, 0.26))

    # --- pattes écartées à doigts ronds ---
    for part, s, y, ph in (("LegFL", 1, -0.24, 0.0), ("LegFR", -1, -0.24, 3.14), ("LegBL", 1, 0.32, 3.14),
                           ("LegBR", -1, 0.32, 0.0)):
        P.chain(kit, part, [(s * 0.18, y, 0.22), (s * 0.32, y - 0.02, 0.14), (s * 0.36, y - 0.04, 0.04)], 0.08, [red])
        for k in range(3):
            kit.add(kit.brick((0.05, 0.05, 0.03), center=(s * 0.36 + (k - 1) * 0.05, y - 0.11, 0.015)), orange, part,
                    bevel=0.012)
        kit.part(part, "Leg", pivot=(s * 0.18, y, 0.22), phase=ph)

    # --- longue queue qui ondule et finit en flammèche ---
    P.chain(kit, "Tail", [(0, 0.48, 0.24), (0.08, 0.7, 0.2), (0.0, 0.9, 0.16), (-0.1, 1.06, 0.14), (-0.06, 1.2, 0.16)],
            0.16, [red, dark], taper=0.025)
    kit.add(kit.wedge((0.1, 0.08, 0.16), center=(-0.05, 1.28, 0.22), rot=(-50, 0, 0), tip=0.1), yellow, "Tail", bevel=0.0)
    kit.part("Tail", "Tail", pivot=(0, 0.46, 0.24))
    return kit.result()
