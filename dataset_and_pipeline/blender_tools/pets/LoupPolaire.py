"""Loup Polaire (Épique, Animaux) : « Loup blanc entouré de flocons. »

En briques LEGO : grand loup blanc, collerette de fourrure en pentes autour du cou, museau en pente, truffe noire,
yeux bleu glacier lumineux, oreilles en coins à l'intérieur bleu, marques bleu glacier sur le front et le dos,
grosse queue touffue à bout bleu, pattes puissantes. Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("blanc", "#F2F4F7")
    shade = kit.mat("gris_clair", "#D6DDE6")
    ice = kit.mat("glace", "#8CC4FF", rough=0.15)
    black = kit.mat("truffe", "#1C1E24", rough=0.15)

    # --- corps puissant, collerette, marques ---
    kit.add(kit.brick((0.5, 0.98, 0.3), center=(0, 0.06, 0.62)), white, bevel=0.035)
    kit.add(kit.brick((0.44, 0.76, 0.1), center=(0, 0.0, 0.82)), white, bevel=0.02)
    kit.add(kit.slope((0.44, 0.24, 0.1), center=(0, 0.5, 0.82), facing="+Y", top=0.3), white, bevel=0.02)
    kit.add(kit.brick((0.42, 0.08, 0.32), center=(0, -0.46, 0.6)), shade, bevel=0.02)
    for s in (-1, 1):
        kit.add(kit.slope((0.16, 0.34, 0.3), center=(s * 0.3, -0.36, 0.72), facing="+X" if s > 0 else "-X", top=0.3),
                white, bevel=0.02)
    for y in (-0.12, 0.12):
        kit.add(kit.tile(0.1, 0.16, center=(0, y, 0.885)), ice, bevel=0.006)

    # --- tête : museau en pente, oreilles, yeux bleus ---
    kit.add(kit.brick((0.52, 0.42, 0.36), center=(0, -0.56, 1.06)), white, "Head", bevel=0.035)
    kit.add(kit.brick((0.3, 0.3, 0.16), center=(0, -0.88, 0.95)), white, "Head", bevel=0.025)
    kit.add(kit.slope((0.3, 0.26, 0.1), center=(0, -0.86, 1.08), facing="-Y", top=0.3), white, "Head", bevel=0.015)
    kit.add(kit.brick((0.1, 0.06, 0.07), center=(0, -1.04, 1.0)), black, "Head", bevel=0.01)
    kit.add(kit.tile(0.06, 0.2, center=(0, -0.62, 1.245)), ice, "Head", bevel=0.005)
    for s in (-1, 1):
        kit.add(kit.wedge((0.2, 0.09, 0.28), center=(s * 0.17, -0.5, 1.38), rot=(-4, s * 6, 0), tip=0.1), white,
                "Head", bevel=0.012)
        kit.add(kit.wedge((0.1, 0.02, 0.16), center=(s * 0.17, -0.55, 1.36), rot=(-4, s * 6, 0), tip=0.12), ice,
                "Head", bevel=0.005)
    P.eyes(kit, "Head", 0.13, -0.77, 1.13, size=0.11, iris="#58B4FF", pupil_w=0.35, pupil_h=0.7, glow=1.5, tall=0.8)

    # --- pattes, grosse queue à bout bleu ---
    P.legs4(kit, white, shade, x=0.17, yf=-0.32, yb=0.38, h=0.36, w=0.15, paw_h=0.09, thigh=(0.2, 0.32, 0.22))
    P.chain(kit, "Tail", [(0, 0.56, 0.72), (0, 0.78, 0.76), (0, 0.98, 0.88), (0, 1.1, 1.02), (0, 1.14, 1.16)], 0.2,
            [white, white, white, ice], taper=-0.005)
    kit.part("Tail", "Tail", pivot=(0, 0.54, 0.72))
    kit.part("Head", "Head", pivot=(0, -0.42, 0.88))
    return kit.result()
