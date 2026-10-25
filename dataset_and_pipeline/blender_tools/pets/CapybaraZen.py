"""Le Capybara Zen (Sigma, Animaux) : « Capybara imperturbable, une orange sur la tête. »

En briques LEGO (le capybara est déjà un gros pavé !) : corps-tonneau brun en grosses briques, tête carrée au museau
plat et grosse truffe sombre, petites oreilles rondes, yeux mi-clos (paupières en tuiles : il est zen), une orange
posée sur la tête (cube orange arrondi + feuille verte, seul détail rond), pattes courtes, ventre plus clair.
Parties animées : tête (presque immobile, il est zen), 4 pattes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    brown = kit.mat("brun", "#A06E46")
    light = kit.mat("clair", "#C08E62")
    dark = kit.mat("fonce", "#5E3E26")
    orange = kit.mat("orange", "#FF962A", rough=0.35)
    leaf = kit.mat("feuille", "#3FAE3A")
    nose = kit.mat("truffe", "#3A2A20")

    # --- corps-tonneau : gros pavé ---
    kit.add(kit.brick((0.7, 1.1, 0.46), center=(0, 0.06, 0.62)), brown, bevel=0.05)
    kit.add(kit.brick((0.62, 0.96, 0.1), center=(0, 0.06, 0.9)), brown, bevel=0.025)
    kit.add(kit.brick((0.5, 0.9, 0.06), center=(0, 0.06, 0.37)), light, bevel=0.015)
    kit.add(kit.slope((0.62, 0.2, 0.36), center=(0, 0.66, 0.66), facing="+Y", top=0.4), brown, bevel=0.02)

    # --- tête carrée au museau plat, oreilles, yeux mi-clos, orange sur la tête ---
    kit.add(kit.brick((0.56, 0.52, 0.44), center=(0, -0.66, 0.92)), brown, "Head", bevel=0.045)
    kit.add(kit.brick((0.46, 0.18, 0.3), center=(0, -0.98, 0.86)), brown, "Head", bevel=0.035)
    kit.add(kit.brick((0.3, 0.05, 0.1), center=(0, -1.08, 0.92)), nose, "Head", bevel=0.012)
    kit.add(kit.brick((0.14, 0.04, 0.025), center=(0, -1.075, 0.78)), dark, "Head", bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.brick((0.12, 0.08, 0.1), center=(s * 0.22, -0.52, 1.18)), dark, "Head", bevel=0.02)
    P.eyes(kit, "Head", 0.17, -0.92, 1.04, size=0.09, iris="#1E1612", pupil_w=0.0, highlight=False)
    for s in (-1, 1):
        kit.add(kit.box((0.11, 0.045, 0.05), center=(s * 0.17, -0.95, 1.07)), dark, "Head", bevel=0.006)
    kit.add(kit.brick((0.26, 0.26, 0.24), center=(0, -0.64, 1.27)), orange, "Head", bevel=0.08)
    kit.add(kit.brick((0.04, 0.04, 0.06), center=(0, -0.64, 1.42)), dark, "Head", bevel=0.006)
    kit.add(kit.wedge((0.12, 0.03, 0.08), center=(0.06, -0.64, 1.45), rot=(0, 40, 0), tip=0.2), leaf, "Head",
            bevel=0.005)

    # --- pattes courtes ---
    P.legs4(kit, brown, dark, x=0.22, yf=-0.34, yb=0.42, h=0.24, w=0.18, paw_h=0.07)
    kit.part("Head", "Head", pivot=(0, -0.46, 0.8))
    return kit.result()
