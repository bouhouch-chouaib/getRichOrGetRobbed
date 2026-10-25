"""Machine à Laver Quantique (Divin, Absurdes) : « Essore une galaxie à 3000 tours par seconde. »

En briques LEGO, très détaillée (Divin : or blanc, or et cristal, aucune lueur) : machine à laver en OR BLANC brillant
(bords chromés), grand hublot cerclé d'or dont la vitre de cristal montre une GALAXIE qui tourne (cœur blanc, bras violet
et bleu, étoiles dorées), tableau de bord avec molettes en or, voyants en cristal et grands yeux sur l'écran,
bulles de mousse en nacre qui débordent, tuyau sur le côté, petits pieds. Parties animées : la galaxie du hublot
(tourne), les bulles.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.chrome("or_blanc", tint="#F6F2E8", rough=0.14)
    edge = kit.chrome("bords")
    gold = kit.gold("or", hammered=0.2)
    glass = kit.gem("hublot", "#0A0A2A", "#2A2A6A", "#B4C8FF")
    violet = kit.gem("bras_violet", "#2A0A5A", "#A06AFF", "#F0E0FF")
    blue = kit.gem("bras_bleu", "#0A1E5A", "#3A8AFF", "#E0F0FF")
    core = kit.gem("coeur", "#B4A8FF", "#F0EAFF", "#FFFFFF")
    pearl = kit.pearl("mousse")
    screen = kit.enamel("ecran", "#1A1E3A")
    hose = kit.mat("tuyau", "#5A6070")

    # --- carrosserie en or blanc, bords chromés, pieds ---
    kit.add(kit.brick((0.84, 0.76, 0.9), center=(0, 0, 0.53)), white, bevel=0.06)
    for z in (0.09, 0.97):
        kit.add(kit.brick((0.86, 0.78, 0.04), center=(0, 0, z)), edge, bevel=0.012)
    for x in (-0.32, 0.32):
        for y in (-0.28, 0.28):
            kit.add(kit.brick((0.1, 0.1, 0.06), center=(x, y, 0.03)), edge, bevel=0.015)

    # --- tableau de bord : écran avec yeux, molettes en or, voyants ---
    kit.add(kit.brick((0.8, 0.06, 0.2), center=(0, -0.38, 0.86)), edge, bevel=0.02)
    kit.add(kit.brick((0.3, 0.03, 0.14), center=(0.06, -0.41, 0.86)), screen, bevel=0.012)
    P.eyes(kit, "Body", x=0.06, y=-0.42, z=0.87, size=0.07, iris="#7AD2FF", pupil="round", sclera="#E6F6FF", tall=1.1,
           at=0.06)
    for x in (-0.3, -0.17):
        kit.add(kit.disc(0.05, 0.04, center=(x, -0.42, 0.86), normal=(0, -1, 0), sides=8), gold, bevel=0.0)
        kit.add(kit.box((0.012, 0.02, 0.04), center=(x, -0.445, 0.88)), edge, bevel=0.0)
    for k, mat in enumerate((violet, blue, core)):
        kit.add(kit.brick((0.04, 0.03, 0.04), center=(0.26 + k * 0.05, -0.415, 0.86)), mat, bevel=0.006)

    # --- hublot cerclé d'or, galaxie qui tourne ---
    kit.add(kit.disc(0.3, 0.06, center=(0, -0.39, 0.44), normal=(0, -1, 0), sides=16), gold, bevel=0.0)
    kit.add(kit.disc(0.25, 0.04, center=(0, -0.42, 0.44), normal=(0, -1, 0), sides=16), glass, bevel=0.0)
    kit.add(kit.brick((0.08, 0.03, 0.08), center=(0, -0.445, 0.44), rot=(0, 45, 0)), core, "Galaxy", bevel=0.01)
    for arm, mat in ((0, violet), (1, blue)):
        for k in range(6):
            r = 0.05 + 0.03 * k
            a = k * 0.7 + arm * math.pi
            kit.add(kit.brick((0.045 - k * 0.004, 0.02, 0.045 - k * 0.004), center=(math.cos(a) * r, -0.445, 0.44 + math.sin(a) * r),
                              rot=(0, -math.degrees(a), 0)), mat, "Galaxy", bevel=0.0)
    for k in range(4):
        a = k * 1.6 + 0.4
        kit.add(kit.brick((0.025, 0.02, 0.025), center=(math.cos(a) * 0.2, -0.446, 0.44 + math.sin(a) * 0.2), rot=(0, 45, 0)),
                gold, "Galaxy", bevel=0.0)
    kit.part("Galaxy", "Drum", pivot=(0, -0.445, 0.44))
    kit.add(kit.brick((0.06, 0.06, 0.12), center=(0.3, -0.42, 0.44)), gold, bevel=0.015)

    # --- bulles de mousse en nacre, tuyau ---
    for x, y, z, w in ((0.36, -0.3, 1.02, 0.1), (0.24, -0.24, 1.06, 0.08), (-0.3, 0.2, 1.03, 0.12), (0.0, 0.28, 1.04, 0.09),
                       (-0.38, -0.4, 0.2, 0.08), (0.44, -0.36, 0.14, 0.07)):
        kit.add(kit.brick((w, w, w), center=(x, y, z)), pearl, "Bubbles", bevel=w * 0.3)
    kit.part("Bubbles", "Leaf", pivot=(0, 0, 1.0), phase=0.9)
    P.chain(kit, "Body", [(0.43, 0.2, 0.3), (0.52, 0.24, 0.2), (0.56, 0.3, 0.08), (0.5, 0.38, 0.02)], 0.06, [hose])
    return kit.result()
