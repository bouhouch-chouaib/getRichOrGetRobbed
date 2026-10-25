"""Tigre du Bengal (Légendaire, Animaux) : « Tigre massif aux rayures dorées. »

En briques LEGO, très détaillé : tigre massif orange vif (torse puissant, épaules hautes), rayures DORÉES légèrement
lumineuses sur le dos, les flancs, le front et la queue, poitrail, ventre et chaussons blancs, grosse tête aux
favoris blancs en touffes, museau blanc, truffe rose à narines, gueule à crocs, yeux ambre en fente sous un sourcil
fier, oreilles rondes à intérieur blanc et point noir au dos, pattes énormes à griffes.
Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    orange = kit.mat("orange", "#FF8418")
    deep = kit.mat("orange_fonce", "#E86A08")
    gold = kit.mat("or", "#FFD23A", metal=0.5, rough=0.2, glow=0.9)
    white = kit.mat("blanc", "#FFFDF5")
    black = kit.mat("noir", "#2A1E18")
    claw = kit.mat("griffes", "#F2E6D2")

    # --- torse massif, rayures dorées ---
    P.quad_torso(kit, L=1.08, W=0.6, H=0.36, z=0.72, y0=0.06, main=orange, belly=white, chest=white, back=deep)
    for y in (-0.3, -0.08, 0.14, 0.34, 0.5):
        kit.add(kit.tile(0.5, 0.06, center=(0, y, 0.98)), gold, bevel=0.005)
        for s in (-1, 1):
            kit.add(kit.box((0.03, 0.06, 0.26), center=(s * 0.31, y + 0.02, 0.76), rot=(12, 0, 0)), gold, bevel=0.005)
            kit.add(kit.box((0.03, 0.05, 0.12), center=(s * 0.31, y - 0.06, 0.66), rot=(-8, 0, 0)), gold, bevel=0.005)
    kit.add(kit.brick((0.44, 0.32, 0.4), center=(0, -0.5, 0.96), rot=(16, 0, 0)), orange, bevel=0.04)

    # --- grosse tête : favoris, museau blanc, truffe rose, crocs, yeux, oreilles rondes ---
    kit.add(kit.brick((0.64, 0.5, 0.44), center=(0, -0.64, 1.18)), orange, "Head", bevel=0.045)
    kit.add(kit.brick((0.56, 0.42, 0.07), center=(0, -0.62, 1.43)), deep, "Head", bevel=0.015)
    for dx, ang in ((-0.12, 15), (0.0, 0), (0.12, -15)):
        kit.add(kit.box((0.045, 0.03, 0.16), center=(dx, -0.892, 1.3), rot=(0, ang, 0)), gold, "Head", bevel=0.004)
    for dx in (-0.14, 0.0, 0.14):
        kit.add(kit.tile(0.045, 0.3, center=(dx, -0.62, 1.47)), gold, "Head", bevel=0.004)
    for s in (-1, 1):
        kit.add(kit.slope((0.18, 0.3, 0.26), center=(s * 0.4, -0.7, 1.06), facing=P.side(s), top=0.2), white, "Head",
                bevel=0.015)
        for dz in (0.0, -0.09):
            P.tuft_piece(kit, "Head", (s * 0.46, -0.72, 1.02 + dz), (s, -0.2, -0.35), 0.14, 0.1, white)
        kit.add(kit.brick((0.18, 0.09, 0.16), center=(s * 0.23, -0.52, 1.46)), orange, "Head", bevel=0.03)
        kit.add(kit.brick((0.1, 0.02, 0.1), center=(s * 0.23, -0.57, 1.45)), white, "Head", bevel=0.006)
        kit.add(kit.box((0.08, 0.02, 0.08), center=(s * 0.23, -0.474, 1.47)), black, "Head", bevel=0.006)
    kit.add(kit.brick((0.4, 0.18, 0.22), center=(0, -0.96, 1.06)), white, "Head", bevel=0.03)
    P.nose(kit, "Head", y=-1.05, z=1.15, w=0.12, color="#FF7A8C", nostril="#A83246")
    P.mouth(kit, "Head", y=-1.052, z=1.0, w=0.24, smile=0.1, fangs=claw)
    P.whiskers(kit, "Head", x=0.16, y=-1.02, z=1.06, color="#FFFFFF", n=3, length=0.18)
    P.eyes(kit, "Head", x=0.16, y=-0.89, z=1.24, size=0.13, iris="#FFB21A", pupil="slit", lid=orange, lid_drop=0.05,
           brow=deep, brow_angle=12, tall=0.82)

    # --- pattes énormes à chaussons blancs et griffes, queue rayée ---
    P.quad_legs(kit, orange, yf=-0.36, yb=0.44, top_f=0.74, top_b=0.78, length_f=0.7, length_b=0.74, w=0.2, paw=white,
                toe=white, claw=claw, x=0.22, toes=4)
    P.chain(kit, "Tail", [(0, 0.62, 0.84), (0, 0.84, 0.86), (0, 1.04, 0.96), (0, 1.18, 1.12), (0, 1.22, 1.3),
                          (0, 1.18, 1.44)], 0.15, [orange, gold], taper=0.008)
    kit.part("Tail", "Tail", pivot=(0, 0.6, 0.84))
    kit.part("Head", "Head", pivot=(0, -0.48, 0.98))
    return kit.result()
