"""Satellite Ronchon (Épique, Absurdes) : « Satellite cabossé qui grésille dès qu'on lui parle. »

En briques LEGO, très détaillé (Épique : chrome, or et cristal, aucune lueur) : satellite au corps en CHROME cabossé
(plaques de travers, une bosse), enveloppé par endroits de feuille d'OR martelée comme les vrais satellites, deux grands
panneaux solaires en émail bleu nuit quadrillés de chrome, parabole blanche avec son cornet, antennes, objectif en
cristal bleu ; visage grognon (sourcils très froncés, bouche tordue), petite étincelle d'émail jaune.
Parties animées : panneaux solaires, parabole.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    chrome = kit.chrome("chrome")
    gold = kit.gold("feuille_or", hammered=0.6)
    panel = kit.enamel("panneau", "#1E3A9A")
    white = kit.mat("parabole", "#F4F4F8", rough=0.2)
    dark = kit.mat("noir", "#1E2028")
    lens = kit.gem("objectif", "#0A1E5A", "#3A8AFF", "#E0F0FF")
    spark = kit.enamel("etincelle", "#FFE23A")

    # --- corps en chrome cabossé, feuille d'or ---
    kit.add(kit.brick((0.5, 0.46, 0.5), center=(0, 0, 0.6)), chrome, bevel=0.04)
    kit.add(kit.brick((0.52, 0.48, 0.18), center=(0, 0, 0.4)), gold, bevel=0.03)
    kit.add(kit.brick((0.3, 0.3, 0.12), center=(0.04, 0.02, 0.89), rot=(4, -6, 8)), gold, bevel=0.03)
    kit.add(kit.brick((0.18, 0.04, 0.14), center=(0.15, -0.24, 0.72), rot=(0, 12, 0)), chrome, bevel=0.015)
    kit.add(kit.brick((0.1, 0.06, 0.1), center=(-0.2, 0.22, 0.7), rot=(15, 20, 0)), chrome, bevel=0.02)

    # --- visage grognon ---
    P.eyes(kit, "Body", x=0.1, y=-0.235, z=0.66, size=0.1, iris="#1A1A2A", pupil="round", lid=dark, lid_drop=0.22,
           brow=dark, brow_angle=28, tall=0.9)
    for k, (x, z) in enumerate(((-0.05, 0.5), (0.0, 0.52), (0.05, 0.49))):
        kit.add(kit.box((0.05, 0.02, 0.015), center=(x, -0.236, z), rot=(0, 25 if k % 2 else -25, 0)), dark, bevel=0.0)
    kit.add(kit.disc(0.05, 0.03, center=(-0.16, -0.24, 0.5), normal=(0, -1, 0), sides=8), lens, bevel=0.0)
    kit.add(kit.brick((0.05, 0.05, 0.05), center=(0.3, -0.2, 0.92), rot=(45, 45, 0)), spark, bevel=0.006)

    # --- panneaux solaires ---
    for s, part in ((1, "PanelL"), (-1, "PanelR")):
        kit.add(kit.brick((0.18, 0.06, 0.06), center=(s * 0.34, 0, 0.62)), chrome, part, bevel=0.012)
        kit.add(kit.brick((0.56, 0.03, 0.36), center=(s * 0.71, 0, 0.62)), panel, part, bevel=0.01)
        for k in range(4):
            kit.add(kit.box((0.012, 0.04, 0.36), center=(s * (0.48 + k * 0.15), 0, 0.62)), chrome, part, bevel=0.0)
        kit.add(kit.box((0.56, 0.04, 0.012), center=(s * 0.71, 0, 0.62)), chrome, part, bevel=0.0)
        kit.part(part, "SolarWing", pivot=(s * 0.25, 0, 0.62), phase=float(s))

    # --- parabole et antennes ---
    kit.add(kit.box((0.04, 0.04, 0.14), center=(0, 0.06, 1.0)), chrome, "Dish", bevel=0.006)
    kit.add(kit.disc(0.2, 0.04, center=(0, 0.04, 1.12), normal=(0, -0.5, 1), sides=12), white, "Dish", bevel=0.0)
    kit.add(kit.box((0.02, 0.02, 0.14), center=(0, -0.02, 1.2)), chrome, "Dish", bevel=0.0)
    kit.add(kit.brick((0.04, 0.04, 0.04), center=(0, -0.04, 1.28)), dark, "Dish", bevel=0.008)
    kit.part("Dish", "Leaf", pivot=(0, 0.06, 0.94), phase=1.2)
    for x, h in ((-0.18, 0.3), (0.2, 0.22)):
        kit.add(kit.box((0.015, 0.015, h), center=(x, 0.18, 0.85 + h / 2)), chrome, bevel=0.0)
        kit.add(kit.brick((0.04, 0.04, 0.04), center=(x, 0.18, 0.85 + h)), gold, bevel=0.008)
    return kit.result()
