"""Chien-Saucisse (Commun, Animaux) : « Teckel brun excessivement long. »

En briques LEGO : corps très long en briques brunes (ventre plus clair), pattes très courtes, tête carrée au long
museau, truffe noire, oreilles tombantes brun foncé, collier rouge, petite queue relevée.
Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    brown = kit.mat("brun", "#8C552D")
    dark = kit.mat("brun_fonce", "#5A371E")
    belly = kit.mat("ventre", "#C08A5A")
    red = kit.mat("collier", "#D63A2E")
    gold = kit.mat("medaille", "#F2C24B", metal=0.6, rough=0.25)
    black = kit.mat("truffe", "#141214", rough=0.15)

    # --- corps très long ---
    kit.add(kit.brick((0.4, 1.36, 0.28), center=(0, 0.02, 0.36)), brown, bevel=0.03)
    kit.add(kit.brick((0.36, 1.24, 0.08), center=(0, 0.02, 0.54)), brown, bevel=0.02)
    kit.add(kit.brick((0.3, 1.1, 0.06), center=(0, 0.02, 0.215)), belly, bevel=0.015)
    kit.add(kit.slope((0.36, 0.18, 0.08), center=(0, 0.72, 0.54), facing="+Y", top=0.3), brown, bevel=0.015)

    # --- tête, long museau, oreilles tombantes, collier ---
    kit.add(kit.brick((0.4, 0.38, 0.34), center=(0, -0.82, 0.62)), brown, "Head", bevel=0.03)
    kit.add(kit.brick((0.34, 0.32, 0.06), center=(0, -0.8, 0.82)), brown, "Head", bevel=0.015)
    kit.add(kit.brick((0.24, 0.3, 0.18), center=(0, -1.12, 0.55)), brown, "Head", bevel=0.025)
    kit.add(kit.slope((0.24, 0.18, 0.08), center=(0, -1.1, 0.68), facing="-Y", top=0.35), brown, "Head", bevel=0.012)
    kit.add(kit.brick((0.12, 0.06, 0.08), center=(0, -1.28, 0.6)), black, "Head", bevel=0.012)
    P.eyes(kit, "Head", 0.1, -1.01, 0.72, size=0.09, iris="#2B1A10", pupil_w=0.0, highlight=True)
    for s in (-1, 1):
        kit.add(kit.brick((0.06, 0.2, 0.3), center=(s * 0.23, -0.78, 0.55), rot=(0, s * -8, 0)), dark, "Head",
                bevel=0.015)
    kit.add(kit.brick((0.44, 0.1, 0.09), center=(0, -0.6, 0.5)), red, bevel=0.015)
    kit.add(kit.disc(0.04, 0.02, center=(0, -0.66, 0.44), normal=(0, -1, 0)), gold, bevel=0.0)

    # --- pattes très courtes, petite queue relevée ---
    P.legs4(kit, brown, dark, x=0.14, yf=-0.48, yb=0.48, h=0.13, w=0.13, paw_h=0.06)
    P.chain(kit, "Tail", [(0, 0.74, 0.5), (0, 0.86, 0.6), (0, 0.92, 0.74), (0, 0.92, 0.86)], 0.09, [brown, brown, dark])
    kit.part("Tail", "Tail", pivot=(0, 0.72, 0.5))
    kit.part("Head", "Head", pivot=(0, -0.66, 0.55))
    return kit.result()
