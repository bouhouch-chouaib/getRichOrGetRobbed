"""Les Jumeaux Éclipse (Mythique, Absurdes) : « Le Soleil et la Lune, collés, qui se disputent la vedette. »

En briques LEGO, très détaillé (Mythique : or martelé, nacre et cristal, aucune lueur) : un disque-soleil en OR martelé
(couronne de rayons dorés en coins qui TOURNE lentement derrière lui) collé à un croissant de lune en NACRE à cratères
gris perle ; chacun a son visage : le soleil fier et vexé (sourcils hauts, bouche boudeuse, joues orange), la lune
blasée (paupières lourdes, petite moue) ; une étoile en cristal accrochée entre les deux. Ils flottent.
Parties animées : la couronne de rayons (tourne), l'étoile (bouge).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    gold = kit.gold("soleil", hammered=0.5)
    gold2 = kit.gold("rayons", tint="#FFD86A", hammered=0.2, rough=0.18)
    pearl = kit.pearl("lune")
    crater = kit.mat("cratere", "#B8B4C8")
    orange = kit.mat("joues_soleil", "#FF8A3A")
    lilac = kit.mat("joues_lune", "#C8B4E6")
    star = kit.enamel("etoile", "#8ACBFF")
    face = kit.enamel("visage_soleil", "#FFC83A")
    dark = kit.mat("traits", "#3A2A1A")

    # --- soleil en or martelé (gauche du familier = +X) ---
    sx, z = 0.3, 0.7
    kit.add(kit.brick((0.56, 0.24, 0.56), center=(sx, 0, z)), gold, bevel=0.06)
    kit.add(kit.brick((0.46, 0.3, 0.66), center=(sx, 0, z)), gold, bevel=0.06)
    kit.add(kit.brick((0.66, 0.3, 0.46), center=(sx, 0, z)), gold, bevel=0.06)
    # le visage est sur une plaque d'émail : de face, l'or miroir reflète le fond et paraît noir
    kit.add(kit.brick((0.4, 0.03, 0.38), center=(sx, -0.155, z)), face, bevel=0.03)
    P.eyes(kit, "Body", x=0.1, y=-0.175, z=z + 0.06, size=0.1, iris="#5A2A0A", pupil="round", brow=dark, brow_angle=-18,
           tall=1.1, at=sx)
    kit.add(kit.brick((0.1, 0.03, 0.04), center=(sx, -0.178, z - 0.12)), dark, bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.box((0.06, 0.02, 0.04), center=(sx + s * 0.15, -0.178, z - 0.06)), orange, bevel=0.005)
    # couronne de rayons qui tourne
    for k in range(12):
        a = 2 * math.pi * k / 12
        r = 0.44 if k % 2 == 0 else 0.4
        kit.add(kit.wedge((0.12, 0.06, 0.18 if k % 2 == 0 else 0.12), center=(sx + math.cos(a) * r, 0.06, z + math.sin(a) * r),
                          rot=(0, -math.degrees(a) + 90, 0), tip=0.1), gold2, "Rays", bevel=0.0)
    kit.part("Rays", "Orbit", pivot=(sx, 0.06, z), rot=(90, 0, 0), phase=0.35)

    # --- croissant de lune en nacre (droite du familier = -X) ---
    mx = -0.3
    kit.add(kit.brick((0.4, 0.26, 0.64), center=(mx, 0, z)), pearl, bevel=0.06)
    kit.add(kit.brick((0.24, 0.26, 0.2), center=(mx - 0.12, 0, z + 0.34)), pearl, bevel=0.05)
    kit.add(kit.brick((0.24, 0.26, 0.2), center=(mx - 0.12, 0, z - 0.34)), pearl, bevel=0.05)
    for cx, cz, r in ((mx - 0.08, z + 0.2, 0.05), (mx + 0.06, z - 0.2, 0.04), (mx - 0.14, z - 0.06, 0.035)):
        kit.add(kit.disc(r, 0.03, center=(cx, -0.135, cz), normal=(0, -1, 0), sides=8), crater, bevel=0.0)
    P.eyes(kit, "Body", x=0.07, y=-0.135, z=z + 0.04, size=0.08, iris="#2A2A4A", pupil="round", lid=pearl,
           lid_drop=0.35, tall=1.0, at=mx + 0.02)
    kit.add(kit.box((0.07, 0.02, 0.02), center=(mx + 0.02, -0.136, z - 0.08), rot=(0, -12, 0)), dark, bevel=0.0)
    kit.add(kit.box((0.05, 0.02, 0.03), center=(mx + 0.12, -0.136, z - 0.03)), lilac, bevel=0.004)

    # --- étoile en cristal accrochée entre les deux ---
    kit.add(kit.brick((0.1, 0.06, 0.1), center=(0, -0.08, z + 0.42), rot=(0, 45, 0)), star, "Star", bevel=0.01)
    kit.add(kit.brick((0.1, 0.06, 0.1), center=(0, -0.08, z + 0.42)), star, "Star", bevel=0.01)
    kit.part("Star", "Toast", pivot=(0, -0.08, z + 0.36), phase=1.0)
    return kit.result()
