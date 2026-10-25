"""Golem Distributeur (Divin, Hybrides) : « Golem de pierre au torse en machine à canettes. »

En briques LEGO, très détaillé : golem de pierre grise (blocs taillés, fissures, mousse) aux épaules en rochers,
gros bras et jambes de pierre, poings massifs ; son torse est un DISTRIBUTEUR de canettes rouge vif : vitrine
LUMINEUSE avec trois rangées de canettes colorées, bandeau néon rouge en haut, boutons LUMINEUX, fente à pièces et
trappe de sortie ; petite tête de pierre aux yeux rouges LUMINEUX. Parties animées : tête, bras, jambes.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    stone = kit.mat("pierre", "#8C92A2")
    dark = kit.mat("pierre_fonce", "#5E6474")
    light = kit.mat("pierre_claire", "#B4BACA")
    crack = kit.mat("fissure", "#3A3E4A")
    moss = kit.mat("mousse", "#5ED63A")
    red = kit.mat("distributeur", "#E01E2A", rough=0.15)
    red2 = kit.mat("distributeur_fonce", "#A8101C", rough=0.15)
    neon = kit.mat("neon", "#FF3A4A", rough=0.1, glow=3.0)
    window = kit.mat("vitrine", "#DFF4FF", rough=0.05, glow=1.2)
    cans = [kit.mat("canette_bleue", "#2E7CFF", metal=0.6), kit.mat("canette_verte", "#3EDB4A", metal=0.6),
            kit.mat("canette_jaune", "#FFD21E", metal=0.6), kit.mat("canette_rose", "#FF5AAE", metal=0.6)]
    button = kit.mat("boutons", "#FFE23A", rough=0.1, glow=2.0)
    eye = kit.mat("yeux", "#FF2A2A", rough=0.1, glow=2.8)

    # --- distributeur-torse ---
    kit.add(kit.brick((0.62, 0.42, 0.66), center=(0, 0, 0.88)), red, bevel=0.035)
    kit.add(kit.brick((0.4, 0.04, 0.46), center=(-0.07, -0.22, 0.9)), window, bevel=0.012)
    for row in range(3):
        for k in range(3):
            kit.add(kit.brick((0.08, 0.04, 0.12), center=(-0.19 + k * 0.12, -0.235, 0.74 + row * 0.15)),
                    cans[(row + k) % len(cans)], bevel=0.01)
        kit.add(kit.box((0.4, 0.03, 0.015), center=(-0.07, -0.24, 0.675 + row * 0.15)), red2, bevel=0.0)
    kit.add(kit.brick((0.6, 0.06, 0.1), center=(0, -0.22, 1.18)), neon, bevel=0.015)
    for k in range(4):
        kit.add(kit.brick((0.06, 0.03, 0.05), center=(0.22, -0.225, 1.02 - k * 0.08)), button, bevel=0.008)
    kit.add(kit.box((0.02, 0.02, 0.06), center=(0.22, -0.225, 0.7)), crack, bevel=0.0)
    kit.add(kit.brick((0.36, 0.04, 0.1), center=(-0.04, -0.22, 0.6)), red2, bevel=0.01)
    kit.add(kit.brick((0.3, 0.03, 0.06), center=(-0.04, -0.235, 0.6)), crack, bevel=0.0)

    # --- bassin et épaules de rocher ---
    kit.add(kit.brick((0.56, 0.4, 0.16), center=(0, 0, 0.5)), stone, bevel=0.04)
    for s in (-1, 1):
        kit.add(kit.brick((0.3, 0.34, 0.26), center=(s * 0.4, 0, 1.16)), stone, bevel=0.06)
        kit.add(kit.brick((0.2, 0.24, 0.08), center=(s * 0.42, -0.02, 1.32)), light, bevel=0.03)
        kit.add(kit.tile(0.12, 0.1, center=(s * 0.44, 0.04, 1.37)), moss, bevel=0.004)

    # --- petite tête de pierre aux yeux rouges ---
    kit.add(kit.brick((0.28, 0.26, 0.22), center=(0, -0.02, 1.36)), stone, "Head", bevel=0.04)
    kit.add(kit.brick((0.3, 0.06, 0.06), center=(0, -0.15, 1.42)), dark, "Head", bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.brick((0.07, 0.03, 0.04), center=(s * 0.07, -0.16, 1.37)), eye, "Head", bevel=0.008)
    kit.add(kit.box((0.1, 0.02, 0.02), center=(0, -0.155, 1.29)), crack, "Head", bevel=0.0)
    kit.add(kit.tile(0.1, 0.08, center=(0.06, 0.0, 1.48)), moss, "Head", bevel=0.004)
    kit.part("Head", "Head", pivot=(0, 0, 1.26))

    # --- gros bras et poings ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.2, 0.22, 0.32), center=(s * 0.46, 0, 0.88)), stone, part, bevel=0.05)
        kit.add(kit.brick((0.18, 0.2, 0.24), center=(s * 0.48, -0.02, 0.58)), dark, part, bevel=0.04)
        kit.add(kit.brick((0.24, 0.26, 0.2), center=(s * 0.48, -0.04, 0.38)), stone, part, bevel=0.05)
        kit.add(kit.box((0.02, 0.02, 0.12), center=(s * 0.56, -0.1, 0.9), rot=(0, 25, 0)), crack, part, bevel=0.0)
        kit.part(part, "Arm", pivot=(s * 0.44, 0, 1.1), phase=0.0 if s > 0 else math.pi)

    # --- jambes de pierre ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.22, 0.24, 0.3), center=(s * 0.16, 0, 0.3)), dark, part, bevel=0.04)
        kit.add(kit.brick((0.26, 0.32, 0.12), center=(s * 0.16, -0.03, 0.06)), stone, part, bevel=0.035)
        kit.part(part, "Leg", pivot=(s * 0.16, 0, 0.46), phase=0.0 if s > 0 else math.pi)
    return kit.result()
