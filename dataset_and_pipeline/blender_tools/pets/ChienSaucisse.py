"""Chien-Saucisse (Commun, Animaux) : « Teckel brun excessivement long. »

En briques LEGO, très détaillé : teckel brun roux très long (torse sculpté étiré, poitrail bombé, ventre clair),
pattes très courtes articulées à doigts, tête au long museau en pente, grosse truffe noire à narines, langue rose qui
dépasse, yeux marron doux sous des sourcils clairs, longues oreilles tombantes brun foncé, collier rouge vif à
médaille dorée, petite queue relevée. Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    brown = kit.mat("brun", "#C0692A")
    dark = kit.mat("brun_fonce", "#6E3612")
    tan = kit.mat("feu", "#F2B070")
    red = kit.mat("collier", "#FF2E3A")
    gold = kit.mat("medaille", "#FFC93A", metal=0.6, rough=0.22)
    tongue = kit.mat("langue", "#FF6F8E")

    # --- torse très long ---
    P.quad_torso(kit, L=1.4, W=0.4, H=0.28, z=0.36, y0=0.02, main=brown, belly=tan, chest=tan, back=dark)
    kit.add(kit.brick((0.26, 0.24, 0.24), center=(0, -0.76, 0.5), rot=(20, 0, 0)), brown, bevel=0.025)

    # --- tête au long museau, truffe, langue, yeux doux, oreilles tombantes ---
    kit.add(kit.brick((0.4, 0.36, 0.32), center=(0, -0.86, 0.64)), brown, "Head", bevel=0.035)
    kit.add(kit.brick((0.34, 0.3, 0.06), center=(0, -0.84, 0.83)), brown, "Head", bevel=0.015)
    kit.add(kit.brick((0.24, 0.32, 0.18), center=(0, -1.14, 0.56)), brown, "Head", bevel=0.025)
    kit.add(kit.slope((0.24, 0.2, 0.08), center=(0, -1.1, 0.69), facing="-Y", top=0.35), brown, "Head", bevel=0.012)
    kit.add(kit.brick((0.18, 0.2, 0.05), center=(0, -1.12, 0.46)), tan, "Head", bevel=0.01)
    P.nose(kit, "Head", y=-1.3, z=0.6, w=0.11, color="#18100C")
    P.mouth(kit, "Head", y=-1.302, z=0.5, w=0.16, smile=0.4, tongue=tongue)
    P.eyes(kit, "Head", x=0.11, y=-1.04, z=0.72, size=0.1, iris="#7A3A10", pupil="round", lid=brown, lid_drop=0.02,
           brow=tan, brow_angle=-12, tall=1.0)
    for s in (-1, 1):
        kit.add(kit.brick((0.06, 0.22, 0.34), center=(s * 0.23, -0.8, 0.56), rot=(0, s * -10, 0)), dark, "Head",
                bevel=0.018)
        kit.add(kit.slope((0.06, 0.2, 0.08), center=(s * 0.25, -0.8, 0.36), facing="-Y", top=0.4, rot=(0, s * -10, 0)),
                dark, "Head", bevel=0.01)

    # --- collier rouge à médaille ---
    kit.add(kit.brick((0.32, 0.12, 0.08), center=(0, -0.72, 0.5), rot=(20, 0, 0)), red, bevel=0.012)
    kit.add(kit.disc(0.04, 0.02, center=(0, -0.79, 0.43), normal=(0, -1, 0)), gold, bevel=0.0)

    # --- pattes très courtes, petite queue relevée ---
    P.quad_legs(kit, brown, yf=-0.5, yb=0.48, top_f=0.3, top_b=0.32, length_f=0.26, length_b=0.28, w=0.12, paw=dark,
                toe=dark, x=0.14, toes=3)
    P.chain(kit, "Tail", [(0, 0.74, 0.46), (0, 0.86, 0.56), (0, 0.93, 0.7), (0, 0.94, 0.84)], 0.09, [brown, brown, dark])
    kit.part("Tail", "Tail", pivot=(0, 0.72, 0.46))
    kit.part("Head", "Head", pivot=(0, -0.7, 0.56))
    return kit.result()
