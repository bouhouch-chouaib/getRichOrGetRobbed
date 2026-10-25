"""La Baleine Galaxie (Sigma, Absurdes) : « Baleine immense qui porte une galaxie entière dans son ventre. »

En briques LEGO, très détaillée (Sigma : or massif, cristal et chrome, aucune lueur) : grande baleine bleu nuit laquée,
ventre rayé de sillons crème, une grande fenêtre ovale cerclée d'OR sur le flanc où l'on voit une GALAXIE en cristaux
(cœur blanc, bras rose et violet, étoiles en or) qui tourne ; harnais et nageoires bordés d'or martelé, petite couronne
d'or sur le front, jet d'eau en nacre qui sort de l'évent, grands yeux doux, sourire. Elle nage dans le ciel.
Parties animées : nageoires, queue, la galaxie (tourne), le jet d'eau.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    navy = kit.enamel("bleu_nuit", "#1E2A7A")
    deep = kit.enamel("bleu_profond", "#141C5A")
    cream = kit.mat("sillons", "#F2E6D0")
    gold = kit.gold("or_massif", hammered=0.45)
    glass = kit.gem("fenetre", "#06061E", "#1E1E5A", "#9AA8FF")
    core = kit.gem("coeur", "#C8B4FF", "#F6F0FF", "#FFFFFF")
    pinkg = kit.gem("bras_rose", "#4A0A3A", "#FF5AC8", "#FFE0F6")
    violet = kit.gem("bras_violet", "#2A0A5A", "#9A5AFF", "#F0E6FF")
    starg = kit.gold("etoiles", tint="#FFE06A", hammered=0.0, rough=0.15)
    spray = kit.pearl("jet")

    # --- grand corps de baleine en étages ---
    kit.add(kit.brick((0.8, 0.9, 0.62), center=(0, -0.1, 0.56)), navy, bevel=0.08)
    kit.add(kit.brick((0.66, 0.5, 0.5), center=(0, 0.5, 0.58)), navy, bevel=0.07)
    kit.add(kit.brick((0.46, 0.34, 0.36), center=(0, 0.86, 0.62)), navy, bevel=0.05)
    kit.add(kit.brick((0.7, 0.86, 0.08), center=(0, -0.1, 0.89)), deep, bevel=0.025)
    kit.add(kit.brick((0.66, 1.0, 0.1), center=(0, 0.0, 0.26)), cream, bevel=0.03)
    for k in range(5):
        kit.add(kit.box((0.6, 0.04, 0.03), center=(0, -0.42 + k * 0.16, 0.2)), kit.mat("sillon_fonce", "#C8B490"), bevel=0.0)

    # --- visage : grands yeux doux, sourire, couronne d'or ---
    P.eyes(kit, "Body", x=0.2, y=-0.56, z=0.62, size=0.13, iris="#3A5AE6", pupil="round", tall=1.1)
    kit.add(kit.brick((0.4, 0.03, 0.03), center=(0, -0.566, 0.44), rot=(0, 0, 0)), deep, bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.box((0.08, 0.03, 0.03), center=(s * 0.22, -0.566, 0.46), rot=(0, s * -25, 0)), deep, bevel=0.0)
    for k in range(5):
        x = (k - 2) * 0.08
        kit.add(kit.wedge((0.07, 0.06, 0.12 if k % 2 == 0 else 0.08), center=(x, -0.36, 0.98), tip=0.1), gold, bevel=0.0)
    kit.add(kit.brick((0.44, 0.08, 0.05), center=(0, -0.36, 0.92)), gold, bevel=0.012)

    # --- fenêtre sur le ventre-galaxie (flanc gauche et droit) ---
    for s in (-1, 1):
        kit.add(kit.disc(0.24, 0.05, center=(s * 0.405, -0.02, 0.56), normal=(s, 0, 0), sides=16), gold, bevel=0.0)
        kit.add(kit.disc(0.2, 0.04, center=(s * 0.42, -0.02, 0.56), normal=(s, 0, 0), sides=16), glass, bevel=0.0)
        part = f"Galaxy{0 if s > 0 else 1}"
        kit.add(kit.brick((0.03, 0.07, 0.07), center=(s * 0.445, -0.02, 0.56), rot=(45, 0, 0)), core, part, bevel=0.008)
        for arm, mat in ((0, pinkg), (1, violet)):
            for k in range(5):
                r = 0.045 + 0.03 * k
                a = k * 0.75 + arm * math.pi
                kit.add(kit.brick((0.02, 0.04 - k * 0.004, 0.04 - k * 0.004),
                                  center=(s * 0.445, -0.02 + math.cos(a) * r, 0.56 + math.sin(a) * r)), mat, part, bevel=0.0)
        for k in range(3):
            a = k * 2.1 + 0.5
            kit.add(kit.brick((0.02, 0.025, 0.025), center=(s * 0.446, -0.02 + math.cos(a) * 0.16, 0.56 + math.sin(a) * 0.16),
                              rot=(45, 0, 0)), starg, part, bevel=0.0)
        kit.part(part, "Orbit", pivot=(s * 0.445, -0.02, 0.56), rot=(0, s * 90, 0), phase=0.6 * s)

    # --- harnais d'or, nageoires bordées d'or, queue ---
    kit.add(kit.box((0.84, 0.06, 0.66), center=(0, 0.32, 0.56)), gold, bevel=0.012)
    for s, part in ((1, "FinL"), (-1, "FinR")):
        kit.add(kit.slope((0.4, 0.26, 0.07), center=(s * 0.56, -0.18, 0.36), facing="+X" if s > 0 else "-X", top=0.3,
                          rot=(0, s * 20, 0)), navy, part, bevel=0.015)
        kit.add(kit.box((0.36, 0.04, 0.03), center=(s * 0.56, -0.3, 0.37), rot=(0, s * 20, 0)), gold, part, bevel=0.0)
        kit.part(part, "Fin", pivot=(s * 0.38, -0.18, 0.4), phase=float(s))
    kit.add(kit.brick((0.24, 0.2, 0.22), center=(0, 1.08, 0.64)), navy, "Tail", bevel=0.03)
    for s in (-1, 1):
        kit.add(kit.slope((0.4, 0.24, 0.06), center=(s * 0.22, 1.24, 0.68), facing="+X" if s > 0 else "-X", top=0.3,
                          rot=(0, s * -10, s * 15)), deep, "Tail", bevel=0.012)
        kit.add(kit.box((0.36, 0.03, 0.03), center=(s * 0.22, 1.36, 0.7), rot=(0, s * -10, s * 15)), gold, "Tail", bevel=0.0)
    kit.part("Tail", "SwimTail", pivot=(0, 1.0, 0.62))

    # --- jet d'eau en nacre par l'évent ---
    kit.add(kit.brick((0.08, 0.08, 0.04), center=(0, -0.2, 0.94)), deep, bevel=0.01)
    for k, (x, z, w) in enumerate(((0.0, 1.04, 0.07), (0.0, 1.14, 0.09), (-0.06, 1.22, 0.07), (0.07, 1.22, 0.07),
                                   (-0.1, 1.28, 0.05), (0.11, 1.28, 0.05))):
        kit.add(kit.brick((w, w, w), center=(x, -0.2, z)), spray, "Spout", bevel=w * 0.3)
    kit.part("Spout", "Leaf", pivot=(0, -0.2, 0.96), phase=0.5)
    return kit.result()
