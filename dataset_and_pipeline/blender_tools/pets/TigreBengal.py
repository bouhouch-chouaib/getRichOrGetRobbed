"""Tigre du Bengal (Légendaire, Animaux) : « Tigre massif aux rayures dorées. »

En briques LEGO : tigre massif orange, rayures DORÉES légèrement lumineuses (tuiles sur le dos, les flancs, le front et
la queue), museau et joues blancs (favoris en pentes), grosses pattes à chaussons blancs, oreilles courtes à l'intérieur
blanc, yeux ambre. Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    orange = kit.mat("orange", "#F58C1E")
    gold = kit.mat("or", "#FFD24A", metal=0.5, rough=0.22, glow=0.8)
    white = kit.mat("blanc", "#F8F2E8")
    nose = kit.mat("truffe", "#E3707C")
    dark = kit.mat("bouche", "#2A1A14")

    # --- corps massif, rayures dorées ---
    kit.add(kit.brick((0.6, 1.04, 0.34), center=(0, 0.06, 0.66)), orange, bevel=0.04)
    kit.add(kit.brick((0.54, 0.86, 0.1), center=(0, 0.02, 0.88)), orange, bevel=0.02)
    kit.add(kit.slope((0.54, 0.22, 0.1), center=(0, 0.56, 0.88), facing="+Y", top=0.3), orange, bevel=0.02)
    kit.add(kit.brick((0.44, 0.08, 0.36), center=(0, -0.48, 0.64)), white, bevel=0.025)
    for y in (-0.28, -0.04, 0.2, 0.42):
        kit.add(kit.tile(0.56, 0.07, center=(0, y, 0.945)), gold, bevel=0.006)
        for s in (-1, 1):
            kit.add(kit.box((0.03, 0.07, 0.26), center=(s * 0.31, y + 0.02, 0.72), rot=(8, 0, 0)), gold, bevel=0.006)

    # --- tête : grosse, favoris blancs, rayures du front ---
    kit.add(kit.brick((0.62, 0.48, 0.42), center=(0, -0.6, 1.14)), orange, "Head", bevel=0.04)
    kit.add(kit.brick((0.36, 0.16, 0.18), center=(0, -0.9, 1.02)), white, "Head", bevel=0.025)
    kit.add(kit.brick((0.12, 0.06, 0.07), center=(0, -0.99, 1.1)), nose, "Head", bevel=0.01)
    kit.add(kit.brick((0.22, 0.04, 0.03), center=(0, -0.985, 0.95)), dark, "Head", bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.slope((0.16, 0.3, 0.22), center=(s * 0.38, -0.66, 1.02), facing="+X" if s > 0 else "-X", top=0.2),
                white, "Head", bevel=0.015)
        kit.add(kit.brick((0.16, 0.08, 0.14), center=(s * 0.22, -0.48, 1.42)), orange, "Head", bevel=0.02)
        kit.add(kit.brick((0.09, 0.02, 0.08), center=(s * 0.22, -0.525, 1.41)), white, "Head", bevel=0.005)
    for dx in (-0.12, 0.0, 0.12):
        kit.add(kit.tile(0.05, 0.22, center=(dx, -0.6, 1.365)), gold, "Head", bevel=0.005)
    P.eyes(kit, "Head", 0.15, -0.84, 1.2, size=0.12, iris="#F2A11E", pupil_w=0.35, pupil_h=0.75, tall=0.8)

    # --- grosses pattes à chaussons blancs, queue rayée ---
    P.legs4(kit, orange, white, x=0.2, yf=-0.34, yb=0.42, h=0.4, w=0.19, paw_h=0.11, thigh=(0.24, 0.38, 0.26))
    P.chain(kit, "Tail", [(0, 0.6, 0.78), (0, 0.84, 0.8), (0, 1.04, 0.92), (0, 1.16, 1.1), (0, 1.18, 1.3)], 0.14,
            [orange, gold], taper=0.006)
    kit.part("Tail", "Tail", pivot=(0, 0.58, 0.78))
    kit.part("Head", "Head", pivot=(0, -0.44, 0.94))
    return kit.result()
