"""Chat Comète (Légendaire, Cosmos) : « Chat bleu nuit qui file d'une planète à l'autre, queue en traînée d'étoiles. »

En briques LEGO, très détaillé (Légendaire : or martelé, aucune lueur) : chat élancé bleu nuit laqué, ventre et
chaussettes bleu ciel, taches en forme d'étoiles bleu pâle, grands yeux dorés en amande, collier en OR martelé avec
un pendentif croissant de lune ; sa longue queue est une traînée d'étoiles en or et en émail bleu ciel qui
rapetissent. Parties animées : tête, oreilles, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    navy = kit.enamel("bleu_nuit", "#1E2A6A")
    sky = kit.mat("bleu_ciel", "#7AC8FF")
    pale = kit.mat("etoiles", "#B4DCFF")
    gold = kit.gold("or", hammered=0.3)
    pink = kit.mat("rose", "#FF9AC8")
    star = kit.enamel("etoiles_or", "#FFC21E")  # émail : une étoile en or miroir sort noire

    P.quad_torso(kit, L=0.86, W=0.38, H=0.28, z=0.56, y0=0.05, main=navy, belly=sky, chest=sky, back=navy)
    for x, y, z in ((0.12, -0.1, 0.72), (-0.1, 0.12, 0.73), (0.08, 0.3, 0.7)):
        kit.add(kit.brick((0.07, 0.07, 0.03), center=(x, y, z), rot=(0, 0, 45)), pale, bevel=0.004)
        kit.add(kit.brick((0.07, 0.07, 0.02), center=(x, y, z)), pale, bevel=0.004)
    kit.add(kit.brick((0.26, 0.24, 0.3), center=(0, -0.38, 0.76), rot=(24, 0, 0)), navy, bevel=0.03)
    kit.add(kit.brick((0.3, 0.3, 0.06), center=(0, -0.4, 0.66), rot=(24, 0, 0)), gold, bevel=0.015)
    kit.add(kit.wedge((0.08, 0.03, 0.08), center=(0, -0.55, 0.58), rot=(0, 0, 0), tip=0.3), gold, bevel=0.0)

    kit.add(kit.brick((0.4, 0.34, 0.3), center=(0, -0.5, 0.96)), navy, "Head", bevel=0.045)
    kit.add(kit.brick((0.22, 0.12, 0.14), center=(0, -0.7, 0.88)), sky, "Head", bevel=0.03)
    P.nose(kit, "Head", y=-0.76, z=0.92, w=0.05, color="#FF7AA8")
    P.mouth(kit, "Head", y=-0.765, z=0.85, w=0.1, smile=0.6)
    P.whiskers(kit, "Head", x=0.08, y=-0.74, z=0.89, color="#B4DCFF", n=2, length=0.14)
    P.eyes(kit, "Head", x=0.1, y=-0.67, z=1.0, size=0.1, iris="#FFC21E", pupil="slit", lid=navy, lid_drop=0.08, tall=0.85)
    kit.part("Head", "Head", pivot=(0, -0.36, 0.82))
    for s, part in ((1, "EarL"), (-1, "EarR")):
        P.ear(kit, part, s, (s * 0.13, -0.46, 1.1), w=0.16, h=0.2, color=navy, inner=pink, tilt=(-6, 12))
        kit.part(part, "Ear", pivot=(s * 0.13, -0.46, 1.1), phase=float(s))

    P.quad_legs(kit, navy, yf=-0.26, yb=0.34, top_f=0.58, top_b=0.6, length_f=0.56, length_b=0.58, w=0.1, paw=sky,
                toe=sky, x=0.13, toes=3, lower=sky)

    # --- queue en traînée d'étoiles ---
    P.chain(kit, "Tail", [(0, 0.44, 0.64), (0, 0.58, 0.76), (0, 0.66, 0.92)], 0.08, [navy])
    for k, (y, z, w) in enumerate(((0.72, 1.04, 0.12), (0.8, 1.14, 0.1), (0.9, 1.2, 0.08), (1.0, 1.24, 0.065), (1.1, 1.26, 0.05))):
        mat = star if k % 2 == 0 else sky
        kit.add(kit.brick((w, 0.055, w), center=(0, y, z), rot=(0, 45, 0)), mat, "Tail", bevel=0.006)
        kit.add(kit.brick((w, 0.04, w), center=(0, y, z)), mat, "Tail", bevel=0.006)
    kit.part("Tail", "Tail", pivot=(0, 0.42, 0.64))
    return kit.result()
