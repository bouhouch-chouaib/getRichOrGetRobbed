"""Chat-Coptère (Commun, Hybrides) : « Chat tigré avec une hélice sur la tête. »

En briques LEGO, très détaillé : chaton roux tigré (rayures orange foncé sur le dos, la tête et la queue), museau,
poitrail et chaussettes blancs, grands yeux verts émerveillés, truffe rose, moustaches ; sur la tête une casquette à
hélice rouge et bleue (bouton jaune) dont les deux pales TOURNENT ; il vole, pattes pendantes. Parties animées :
l'hélice (tourne vite), les oreilles, la queue, les 4 pattes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    orange = kit.mat("roux", "#FF8A1E")
    stripe = kit.mat("rayures", "#D85A08")
    white = kit.mat("blanc", "#FFF8EE")
    pink = kit.mat("rose", "#FF8AA8")
    red = kit.mat("casquette", "#FF2A3A")
    blue = kit.mat("visiere", "#2E7CFF")
    yellow = kit.mat("bouton", "#FFD21E")
    blade = kit.mat("pales", "#2E7CFF")
    blade2 = kit.mat("pales_rouges", "#FF2A3A")

    # --- corps de chaton, rayures, poitrail blanc ---
    P.quad_torso(kit, L=0.7, W=0.42, H=0.3, z=0.5, y0=0.06, main=orange, belly=white, chest=white, back=orange)
    for y in (-0.08, 0.08, 0.24):
        kit.add(kit.box((0.36, 0.06, 0.03), center=(0, y, 0.67)), stripe, bevel=0.008)
        for s in (-1, 1):
            kit.add(kit.box((0.03, 0.06, 0.14), center=(s * 0.215, y, 0.56)), stripe, bevel=0.006)

    # --- tête : rayures sur le front, museau blanc, yeux verts, truffe, moustaches, oreilles ---
    kit.add(kit.brick((0.46, 0.38, 0.36), center=(0, -0.36, 0.84)), orange, bevel=0.05)
    kit.add(kit.brick((0.26, 0.12, 0.16), center=(0, -0.58, 0.76)), white, bevel=0.03)
    for dx in (-0.07, 0.0, 0.07):
        kit.add(kit.box((0.03, 0.12, 0.03), center=(dx, -0.42, 1.03)), stripe, bevel=0.005)
    P.eyes(kit, "Body", x=0.11, y=-0.55, z=0.88, size=0.12, iris="#3EDB3A", pupil="slit", tall=1.15)
    P.nose(kit, "Body", y=-0.64, z=0.8, w=0.06, color="#FF7A98")
    P.mouth(kit, "Body", y=-0.645, z=0.73, w=0.1, smile=0.5)
    P.whiskers(kit, "Body", x=0.1, y=-0.62, z=0.77, color="#FFFFFF", n=2, length=0.14)
    for s, part in ((1, "EarL"), (-1, "EarR")):
        P.ear(kit, part, s, (s * 0.14, -0.4, 1.02), w=0.16, h=0.2, color=orange, inner=pink, tilt=(-6, 14))
        kit.part(part, "Ear", pivot=(s * 0.14, -0.4, 1.02), phase=float(s))

    # --- casquette à hélice ---
    kit.add(kit.brick((0.3, 0.28, 0.08), center=(0, -0.32, 1.05)), red, bevel=0.025)
    kit.add(kit.brick((0.2, 0.12, 0.03), center=(0, -0.5, 1.02)), blue, bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.box((0.02, 0.28, 0.08), center=(s * 0.09, -0.32, 1.05)), blue, bevel=0.0)
    kit.add(kit.brick((0.04, 0.04, 0.12), center=(0, -0.32, 1.15)), yellow, bevel=0.008)
    kit.add(kit.brick((0.08, 0.08, 0.05), center=(0, -0.32, 1.22)), yellow, "Rotor", bevel=0.012)
    for s, mat in ((1, blade), (-1, blade2)):
        kit.add(kit.brick((0.32, 0.08, 0.02), center=(s * 0.18, -0.32, 1.23), rot=(s * 10, 0, 0)), mat, "Rotor",
                bevel=0.006)
    kit.part("Rotor", "Rotor", pivot=(0, -0.32, 1.22))

    # --- pattes pendantes à chaussettes blanches, queue tigrée ---
    P.quad_legs(kit, orange, yf=-0.2, yb=0.3, top_f=0.5, top_b=0.52, length_f=0.42, length_b=0.44, w=0.11, paw=white,
                toe=white, x=0.13, toes=3)
    P.chain(kit, "Tail", [(0, 0.4, 0.56), (0, 0.56, 0.62), (0, 0.66, 0.76), (0, 0.68, 0.92)], 0.08,
            [orange, stripe])
    kit.part("Tail", "Tail", pivot=(0, 0.38, 0.56))
    return kit.result()
