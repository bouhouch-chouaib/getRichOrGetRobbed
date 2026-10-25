"""Licorne Céleste (Mythique, Divin) : « Licorne blanche qui galope sur les nuages. »

En briques LEGO, très détaillée (Mythique : nacre et or, aucune lueur) : licorne en NACRE blanc rosé élancée, crinière
et queue en mèches pastel (rose, lavande, bleu ciel, en cristal tendre), longue corne spirale en OR, sabots dorés
posés sur des petits nuages blancs, grands yeux violets à longs cils, museau rosé, étoile dorée sur l'épaule.
Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def _cloud(kit, part, x, y, z, w, mats):
    a, b = mats
    kit.add(kit.brick((w, w * 0.9, w * 0.6), center=(x, y, z)), a, part, bevel=w * 0.25)
    kit.add(kit.brick((w * 0.7, w * 0.7, w * 0.5), center=(x + w * 0.4, y, z - w * 0.1)), b, part, bevel=w * 0.2)
    kit.add(kit.brick((w * 0.6, w * 0.7, w * 0.45), center=(x - w * 0.4, y, z - w * 0.12)), b, part, bevel=w * 0.2)


def build(name: str) -> dict:
    kit = PetKit(name)
    pearl = kit.pearl("nacre", color="#FBF2FA", sheen="#DCEEFF")
    gold = kit.gold("or", hammered=0.25)
    pinkm = kit.gem("meche_rose", "#C85A9A", "#FFB4DC", "#FFF0FA")
    lav = kit.gem("meche_lavande", "#7A5AC8", "#CDB4FF", "#F6F0FF")
    sky = kit.gem("meche_bleue", "#4A8AC8", "#B4E0FF", "#F0FAFF")
    muzzle = kit.mat("museau", "#FFD8E6")
    cloud = kit.mat("nuage", "#FFFFFF", rough=0.4)
    cloud2 = kit.mat("nuage_ombre", "#E6EEFA", rough=0.4)
    lash = kit.mat("cils", "#4A2A5A")

    P.quad_torso(kit, L=0.96, W=0.44, H=0.34, z=0.9, y0=0.04, main=pearl, belly=pearl, chest=pearl, back=pearl)
    kit.add(kit.brick((0.28, 0.28, 0.44), center=(0, -0.44, 1.14), rot=(28, 0, 0)), pearl, bevel=0.04)
    kit.add(kit.brick((0.08, 0.03, 0.08), center=(0.225, -0.2, 1.0), rot=(0, 45, 0)), gold, bevel=0.008)

    # --- tête, museau rosé, yeux à cils, corne spirale d'or ---
    kit.add(kit.brick((0.36, 0.4, 0.32), center=(0, -0.62, 1.42)), pearl, "Head", bevel=0.04)
    kit.add(kit.brick((0.28, 0.28, 0.22), center=(0, -0.9, 1.31)), muzzle, "Head", bevel=0.04)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.02, 0.04), center=(s * 0.07, -1.045, 1.33)), lash, "Head", bevel=0.0)
        P.ear(kit, "Head", s, (s * 0.13, -0.52, 1.58), w=0.11, h=0.17, color=pearl, inner=muzzle, tilt=(-8, 10))
        for k in range(3):
            kit.add(kit.box((0.012, 0.012, 0.05), center=(s * (0.13 + k * 0.03), -0.83, 1.52), rot=(0, s * (20 + k * 15), 0)),
                    lash, "Head", bevel=0.0)
    P.mouth(kit, "Head", y=-1.042, z=1.24, w=0.12, smile=0.5)
    P.eyes(kit, "Head", x=0.12, y=-0.82, z=1.46, size=0.12, iris="#8A3AE6", pupil="round", lid=pearl, lid_drop=0.0)
    P.horn(kit, "Head", (0, -0.66, 1.59), (0, -0.3, 1.0), 0.5, 0.1, [gold], segments=6, twist=60)
    for k, mat in enumerate((pinkm, lav, sky, pinkm, lav)):
        part = "Head" if k < 2 else "Body"
        y, z = -0.5 + k * 0.12, 1.6 - k * 0.14
        P.tuft_piece(kit, part, (0.02, y, z), (0.7, 0.4, 0.3), 0.2, 0.12, mat)
        P.tuft_piece(kit, part, (-0.02, y + 0.04, z), (-0.7, 0.4, 0.3), 0.18, 0.11, (sky, pinkm, lav)[k % 3])
    kit.part("Head", "Head", pivot=(0, -0.5, 1.28))

    # --- longues pattes, sabots dorés sur des nuages ---
    P.quad_legs(kit, pearl, yf=-0.32, yb=0.38, top_f=0.94, top_b=0.98, length_f=0.86, length_b=0.9, w=0.12, paw=gold,
                toe=gold, x=0.15, toes=1)
    for part, x, y in (("LegFL", 0.15, -0.32), ("LegFR", -0.15, -0.32), ("LegBL", 0.15, 0.38), ("LegBR", -0.15, 0.38)):
        _cloud(kit, part, x, y - 0.01, 0.05, 0.22, (cloud, cloud2))  # plus large que le sabot, sinon caché dedans

    # --- queue en mèches pastel ---
    for k, mat in enumerate((pinkm, lav, sky)):
        P.chain(kit, "Tail", [(0, 0.52, 1.02), ((k - 1) * 0.05, 0.64, 0.9), ((k - 1) * 0.08, 0.7, 0.74),
                              ((k - 1) * 0.1, 0.72, 0.58)], 0.07, [mat], taper=0.01)
    kit.part("Tail", "Tail", pivot=(0, 0.5, 1.02))
    return kit.result()
