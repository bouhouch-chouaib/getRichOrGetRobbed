"""Loup Polaire (Épique, Animaux) : « Loup blanc entouré de flocons. »

En briques LEGO, très détaillé : grand loup blanc neige à reflets bleu glacier, épaisse collerette de touffes autour
du cou, joues touffues, museau long en pente, truffe noire à narines, gueule à petits crocs, yeux bleu glacier
lumineux sous un sourcil fier, oreilles pointues à intérieur bleu, cristaux de glace bleus lumineux sur les épaules
et le dos (ses « flocons »), pattes puissantes articulées à griffes, grosse queue touffue au bout bleu.
Parties animées : tête, 4 pattes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("blanc", "#F4F8FF")
    shade = kit.mat("gris_bleu", "#CFDDF2")
    ice = kit.mat("glace", "#4EC4FF", rough=0.12, glow=1.6)
    pale = kit.mat("glace_pale", "#A8E2FF", rough=0.15)
    claw = kit.mat("griffes", "#7A8AA8")

    # --- torse puissant, collerette touffue ---
    P.quad_torso(kit, L=1.0, W=0.5, H=0.32, z=0.66, y0=0.06, main=white, belly=shade, chest=shade, back=shade)
    kit.add(kit.brick((0.36, 0.3, 0.36), center=(0, -0.44, 0.9), rot=(20, 0, 0)), white, bevel=0.035)
    for k in range(5):
        a = -60 + k * 30
        dx, dz = math.sin(math.radians(a)) * 0.26, math.cos(math.radians(a)) * 0.2
        P.tuft_piece(kit, "Body", (dx, -0.52, 0.86 + dz * 0.5), (dx * 2.5, -0.6, dz * 1.2 - 0.6), 0.16, 0.12, white)
    for s in (-1, 1):
        P.tuft_piece(kit, "Body", (s * 0.27, -0.42, 0.78), (s, -0.3, -0.5), 0.18, 0.12, white)
    # cristaux de glace (flocons)
    for x, y, h, tilt in ((0.16, -0.22, 0.22, 10), (-0.14, -0.18, 0.18, -12), (0.0, 0.1, 0.16, 0), (0.12, 0.3, 0.12, 8)):
        P.tuft_piece(kit, "Body", (x, y, 0.88), (tilt * 0.03, 0.15, 1.0), h, 0.08, ice)

    # --- tête : joues touffues, museau, truffe, crocs, yeux glacier, oreilles ---
    kit.add(kit.brick((0.52, 0.42, 0.36), center=(0, -0.58, 1.1)), white, "Head", bevel=0.04)
    kit.add(kit.brick((0.44, 0.36, 0.06), center=(0, -0.56, 1.3)), white, "Head", bevel=0.015)
    kit.add(kit.tile(0.06, 0.26, center=(0, -0.6, 1.335)), pale, "Head", bevel=0.004)
    for s in (-1, 1):
        kit.add(kit.slope((0.14, 0.28, 0.2), center=(s * 0.32, -0.62, 1.0), facing=P.side(s), top=0.2), white, "Head",
                bevel=0.015)
        P.tuft_piece(kit, "Head", (s * 0.36, -0.64, 0.94), (s, -0.2, -0.4), 0.12, 0.08, white)
        P.ear(kit, "Head", s, (s * 0.17, -0.5, 1.32), w=0.2, h=0.3, color=white, inner=pale, tilt=(-4, 6))
    kit.add(kit.brick((0.3, 0.32, 0.16), center=(0, -0.92, 0.98)), white, "Head", bevel=0.025)
    kit.add(kit.slope((0.3, 0.28, 0.1), center=(0, -0.9, 1.11), facing="-Y", top=0.3), white, "Head", bevel=0.015)
    P.nose(kit, "Head", y=-1.08, z=1.04, w=0.1, color="#1C1E2A")
    P.mouth(kit, "Head", y=-1.082, z=0.94, w=0.2, smile=0.15, fangs=kit.mat("crocs", "#FFFFFF", rough=0.15))
    P.eyes(kit, "Head", x=0.13, y=-0.79, z=1.17, size=0.12, iris="#4EC4FF", pupil="slit", lid=white, lid_drop=0.06,
           brow=shade, brow_angle=10, glow=1.6, tall=0.8)

    # --- pattes puissantes, queue touffue au bout glacier ---
    P.quad_legs(kit, white, yf=-0.32, yb=0.4, top_f=0.68, top_b=0.72, length_f=0.64, length_b=0.68, w=0.14, paw=shade,
                toe=shade, claw=claw, x=0.17, toes=3)
    P.bushy_tail(kit, "Tail", [(0, 0.58, 0.74), (0, 0.8, 0.76), (0, 1.0, 0.84), (0, 1.14, 0.98), (0, 1.2, 1.14),
                               (0, 1.2, 1.28)], 0.22, white, tip=ice)
    kit.part("Tail", "Tail", pivot=(0, 0.56, 0.74))
    kit.part("Head", "Head", pivot=(0, -0.44, 0.94))
    return kit.result()
