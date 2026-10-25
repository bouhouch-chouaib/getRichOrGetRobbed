"""Lion Nébuleuse (Divin, Cosmos) : « Sa crinière est une nébuleuse où naissent des étoiles. »

En briques LEGO, très détaillé (Divin : or blanc et cristal, aucune lueur) : lion violet profond à reflets indigo,
museau et ventre lavande, yeux dorés majestueux ; sa CRINIÈRE est une nébuleuse en grappes de cristaux rose, violet
et bleu, semée de petites étoiles en OR BLANC ; houppe de la queue en cristal, griffes d'or blanc.
Parties animées : tête (avec crinière), 4 pattes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    violet = kit.enamel("violet", "#4A2A9A")
    indigo = kit.enamel("indigo", "#2A1A6A")
    lav = kit.mat("lavande", "#C8B4F2")
    pink = kit.gem("nebuleuse_rose", "#5A0A3A", "#FF5AC8", "#FFE0F4")
    purple = kit.gem("nebuleuse_violette", "#2A0A5A", "#9A5AFF", "#F0E6FF")
    blue = kit.gem("nebuleuse_bleue", "#0A1E5A", "#3A8AFF", "#E0F0FF")
    whitegold = kit.chrome("or_blanc", tint="#F6F0E0", rough=0.14)

    P.quad_torso(kit, L=0.96, W=0.5, H=0.34, z=0.64, y0=0.06, main=violet, belly=lav, chest=lav, back=indigo)

    # --- tête et crinière-nébuleuse ---
    kit.add(kit.brick((0.4, 0.36, 0.34), center=(0, -0.56, 0.96)), violet, "Head", bevel=0.045)
    kit.add(kit.brick((0.26, 0.2, 0.18), center=(0, -0.78, 0.88)), lav, "Head", bevel=0.04)
    P.nose(kit, "Head", y=-0.88, z=0.94, w=0.08, color="#2A1A4A")
    P.mouth(kit, "Head", y=-0.882, z=0.82, w=0.12, smile=0.3)
    P.eyes(kit, "Head", x=0.11, y=-0.74, z=1.03, size=0.09, iris="#FFC21E", pupil="slit", lid=violet, lid_drop=0.12,
           brow=indigo, brow_angle=12, tall=0.85)
    mats = (pink, purple, blue)
    for k in range(14):
        a = 2 * math.pi * k / 14
        r = 0.3 + 0.05 * (k % 2)
        x, z = math.cos(a) * r, 0.98 + math.sin(a) * r
        w = 0.16 if k % 2 else 0.13
        kit.add(kit.brick((w, 0.16, w), center=(x, -0.46 + 0.04 * (k % 3), z), rot=(0, math.degrees(a) + 45, 0)),
                mats[k % 3], "Head", bevel=0.02)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        kit.add(kit.brick((0.04, 0.03, 0.04), center=(math.cos(a) * 0.36, -0.56, 0.98 + math.sin(a) * 0.36), rot=(0, 45, 0)),
                whitegold, "Head", bevel=0.0)
    for s in (-1, 1):
        P.ear(kit, "Head", s, (s * 0.14, -0.5, 1.12), w=0.1, h=0.1, color=violet, inner=lav, tilt=(-8, 12))
    kit.part("Head", "Head", pivot=(0, -0.42, 0.82))

    # --- pattes à griffes d'or blanc, queue à houppe de cristal ---
    P.quad_legs(kit, violet, yf=-0.3, yb=0.4, top_f=0.66, top_b=0.7, length_f=0.64, length_b=0.68, w=0.14, paw=lav,
                toe=lav, claw=whitegold, x=0.18, toes=3)
    P.chain(kit, "Tail", [(0, 0.54, 0.72), (0, 0.72, 0.66), (0, 0.88, 0.72), (0, 0.98, 0.86)], 0.06, [violet, indigo])
    for k, mat in enumerate(mats):
        kit.add(kit.brick((0.12, 0.12, 0.12), center=((k - 1) * 0.05, 1.0 + k * 0.02, 0.96 + (k % 2) * 0.05),
                          rot=(30, 20, 45)), mat, "Tail", bevel=0.02)
    kit.part("Tail", "Tail", pivot=(0, 0.52, 0.72))
    return kit.result()
