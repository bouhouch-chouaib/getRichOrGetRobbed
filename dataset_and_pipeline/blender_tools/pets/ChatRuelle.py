"""Chat de ruelle (Commun, Animaux) : « Chat tigré gris ébouriffé, pansement sur la joue. »

En briques LEGO, très détaillé : chat tigré gris-bleu ébouriffé (touffes sur les joues, le crâne et les oreilles),
rayures bleu nuit en « M » sur le front, sur le dos et les flancs, poitrail, museau et chaussettes crème, truffe rose
à narines, sourire en coin, moustaches blanches, grands yeux vert citron à pupille fendue, oreilles à intérieur rose,
pansement crème en croix sur la joue gauche, torse sculpté, pattes articulées, longue queue rayée qui s'enroule.
Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    grey = kit.mat("gris", "#9AA6BE")
    stripe = kit.mat("rayure", "#46506E")
    cream = kit.mat("creme", "#FFF0D6")
    pink = kit.mat("rose", "#FF8FB1")
    plaster = kit.mat("pansement", "#FFD9A8")

    # --- torse sculpté, rayures sur le dos et les flancs ---
    P.quad_torso(kit, L=0.92, W=0.44, H=0.3, z=0.56, y0=0.04, main=grey, belly=cream, chest=cream, back=grey)
    for y in (-0.22, 0.0, 0.2, 0.38):
        kit.add(kit.tile(0.4, 0.06, center=(0, y, 0.763)), stripe, bevel=0.005)
        for s in (-1, 1):
            kit.add(kit.box((0.025, 0.06, 0.22), center=(s * 0.225, y + 0.02, 0.6), rot=(10, 0, 0)), stripe, bevel=0.004)
    kit.add(kit.brick((0.32, 0.24, 0.3), center=(0, -0.4, 0.78), rot=(18, 0, 0)), grey, bevel=0.03)

    # --- tête : crâne, touffes ébouriffées, museau crème, yeux, oreilles, pansement ---
    kit.add(kit.brick((0.6, 0.46, 0.4), center=(0, -0.52, 1.04)), grey, "Head", bevel=0.04)
    kit.add(kit.brick((0.52, 0.38, 0.07), center=(0, -0.5, 1.27)), grey, "Head", bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.slope((0.13, 0.26, 0.18), center=(s * 0.35, -0.56, 0.92), facing=P.side(s), top=0.2), grey, "Head",
                bevel=0.015)
        for dz, length in ((0.0, 0.12), (-0.07, 0.1), (0.07, 0.08)):
            P.tuft_piece(kit, "Head", (s * 0.38, -0.58, 0.92 + dz), (s, -0.2, -0.3 + dz * 3), length, 0.07, grey)
        P.ear(kit, "Head", s, (s * 0.19, -0.46, 1.25), w=0.22, h=0.27, color=grey, inner=pink, tilt=(-6, 12), tuft=grey)
    for k, (dx, ang) in enumerate(((-0.1, 20), (0.0, 0), (0.1, -20))):  # le « M » du tigré
        kit.add(kit.box((0.04, 0.03, 0.14), center=(dx, -0.752, 1.16), rot=(0, ang, 0)), stripe, "Head", bevel=0.004)
    for dx in (-0.1, 0.0, 0.1):
        kit.add(kit.tile(0.04, 0.26, center=(dx, -0.52, 1.31)), stripe, "Head", bevel=0.004)
    P.tuft_piece(kit, "Head", (0.05, -0.42, 1.3), (0.3, 0.3, 1.0), 0.14, 0.08, grey)
    P.tuft_piece(kit, "Head", (-0.06, -0.46, 1.3), (-0.4, 0.1, 1.0), 0.11, 0.07, grey)
    kit.add(kit.brick((0.3, 0.12, 0.15), center=(0, -0.79, 0.93)), cream, "Head", bevel=0.025)
    kit.add(kit.brick((0.2, 0.08, 0.06), center=(0, -0.77, 0.84)), cream, "Head", bevel=0.012)
    P.nose(kit, "Head", y=-0.85, z=1.0, w=0.08, color="#FF8FB1", nostril="#B4466A")
    P.mouth(kit, "Head", y=-0.852, z=0.91, w=0.14, smile=0.35)
    P.whiskers(kit, "Head", x=0.13, y=-0.82, z=0.95, color="#FFFFFF", n=3, length=0.16)
    P.eyes(kit, "Head", x=0.14, y=-0.75, z=1.1, size=0.15, iris="#B8F02A", pupil="slit", lid=grey, lid_drop=0.04,
           brow=stripe, brow_angle=-6, tall=0.95)
    # pansement en croix sur la joue gauche (+X)
    for ang in (35, -35):
        kit.add(kit.box((0.16, 0.025, 0.055), center=(0.215, -0.756, 0.97), rot=(0, ang, 0)), plaster, "Head",
                bevel=0.006)

    # --- pattes articulées à chaussettes crème, queue rayée qui s'enroule ---
    P.quad_legs(kit, grey, yf=-0.3, yb=0.34, top_f=0.6, top_b=0.62, length_f=0.56, length_b=0.6, w=0.13, paw=cream,
                toe=cream, x=0.15, toes=3)
    P.chain(kit, "Tail", [(0, 0.5, 0.66), (0, 0.68, 0.72), (0, 0.82, 0.86), (0, 0.9, 1.04), (0, 0.88, 1.22),
                          (0, 0.8, 1.34), (0, 0.7, 1.38)], 0.12, [grey, stripe], taper=0.006)
    kit.part("Tail", "Tail", pivot=(0, 0.48, 0.66))
    kit.part("Head", "Head", pivot=(0, -0.38, 0.88))
    return kit.result()
