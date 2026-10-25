"""Cerbère Chiot (Épique, Fantastiques) : « Chiot noir à trois têtes, collier à clous rouges. »

En briques LEGO, très détaillé : chiot noir tout rond à reflets violets, trois têtes de chiot (celle du milieu plus
grosse et plus haute, celles des côtés tournées vers l'extérieur), oreilles tombantes, grands yeux rouges brillants de
chiot, petites langues roses, truffes, chacune avec son collier rouge vif à clous blancs, ventre gris, grosses pattes de
chiot à coussinets, petite queue qui remue. Parties animées : trois têtes, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def _head(kit, part, hx, hy, hz, k, mats):
    black, sheen, grey, red, stud, tongue = mats
    # cou, crâne, front plus clair, museau, truffe, langue, yeux, oreilles tombantes
    kit.add(kit.brick((0.26 * k, 0.24 * k, 0.24 * k), center=(hx, hy + 0.08 * k, hz - 0.2 * k)), black, part,
            bevel=0.03)
    kit.add(kit.brick((0.4 * k, 0.36 * k, 0.34 * k), center=(hx, hy - 0.08 * k, hz + 0.06 * k)), black, part,
            bevel=0.04)
    kit.add(kit.brick((0.34 * k, 0.3 * k, 0.05 * k), center=(hx, hy - 0.08 * k, hz + 0.245 * k)), sheen, part,
            bevel=0.012)
    kit.add(kit.brick((0.24 * k, 0.16 * k, 0.15 * k), center=(hx, hy - 0.32 * k, hz - 0.03 * k)), grey, part,
            bevel=0.025)
    P.nose(kit, part, y=hy - 0.405 * k, z=hz + 0.02 * k, w=0.09 * k, color="#120E18", x=hx)
    P.mouth(kit, part, y=hy - 0.405 * k, z=hz - 0.06 * k, w=0.1 * k, smile=0.5, x=hx)
    kit.add(kit.box((0.06 * k, 0.04, 0.08 * k), center=(hx + 0.02 * k, hy - 0.41 * k, hz - 0.13 * k)), tongue, part,
            bevel=0.008)
    P.eyes(kit, part, x=0.095 * k, y=hy - 0.26 * k, z=hz + 0.12 * k, size=0.12 * k, iris="#FF2A3A", pupil="round",
           glow=1.2, tall=1.1, at=hx)
    for s in (-1, 1):
        kit.add(kit.brick((0.07 * k, 0.17 * k, 0.28 * k), center=(hx + s * 0.225 * k, hy - 0.05 * k, hz + 0.0 * k),
                          rot=(-8, s * -14, 0)), sheen, part, bevel=0.015)
    # collier rouge à clous blancs
    kit.add(kit.brick((0.34 * k, 0.3 * k, 0.08 * k), center=(hx, hy + 0.06 * k, hz - 0.2 * k)), red, part, bevel=0.012)
    for j in range(3):
        kit.add(kit.wedge((0.04 * k, 0.04 * k, 0.05 * k), center=(hx + (j - 1) * 0.1 * k, hy - 0.1 * k, hz - 0.2 * k),
                          rot=(90, 0, 0), tip=0.2), stud, part, bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.wedge((0.04 * k, 0.04 * k, 0.05 * k), center=(hx + s * 0.18 * k, hy + 0.06 * k, hz - 0.2 * k),
                          rot=(0, s * 90, 0), tip=0.2), stud, part, bevel=0.0)


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.mat("noir", "#2A2638", rough=0.2)
    sheen = kit.mat("reflet_violet", "#4A3C70", rough=0.2)
    grey = kit.mat("gris", "#76728C")
    red = kit.mat("collier", "#FF1E32")
    stud = kit.mat("clous", "#F4F4F8", metal=0.6, rough=0.2)
    tongue = kit.mat("langue", "#FF7A98")
    mats = (black, sheen, grey, red, stud, tongue)

    # --- corps de chiot tout rond ---
    P.quad_torso(kit, L=0.8, W=0.62, H=0.36, z=0.48, y0=0.08, main=black, belly=grey, chest=grey, back=sheen)

    # --- trois têtes : la grande au milieu, les deux autres tournées vers l'extérieur ---
    for i, hx, hy, hz, k, yaw, phase in ((0, 0.0, -0.4, 0.9, 1.0, 0.0, 0.0), (1, 0.33, -0.26, 0.76, 0.82, 30.0, 2.1),
                                         (2, -0.33, -0.26, 0.76, 0.82, -30.0, 4.2)):
        part = f"Head{i}"
        _head(kit, part, hx, hy, hz, k, mats)
        pivot = (hx, hy + 0.06, hz - 0.14)
        kit.turn(part, pivot, (-6 if i == 0 else 0, 0, yaw))
        kit.part(part, "Head", pivot=pivot, rot=(0, 0, yaw), phase=phase)

    # --- grosses pattes de chiot, petite queue ---
    P.quad_legs(kit, black, yf=-0.22, yb=0.36, top_f=0.5, top_b=0.52, length_f=0.44, length_b=0.46, w=0.15, paw=grey,
                toe=grey, x=0.2, toes=3)
    P.chain(kit, "Tail", [(0, 0.46, 0.62), (0, 0.56, 0.74), (0, 0.6, 0.86)], 0.09, [black, sheen])
    kit.part("Tail", "Tail", pivot=(0, 0.44, 0.62))
    return kit.result()
