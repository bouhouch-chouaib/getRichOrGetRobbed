"""Chauve-Souris Vampire (Légendaire, Halloween 2026) : « Elle ne boit que du jus de tomate, promis. »

En briques LEGO, sans lueur (rareté Légendaire = or martelé) : petit corps violet poilu au ventre mauve, grosse tête
aux très grandes oreilles pointues à intérieur rose, yeux rouges, deux crocs blancs, sourire malin ; col de cape de
vampire rouge et noir dressé derrière la tête, médaillon en or martelé avec un rubis ; grandes ailes de chauve-souris
déployées (doigts violet foncé, membrane prune) ; petites pattes griffues. Parties animées : tête, 2 ailes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    purple = kit.mat("violet", "#6A3C96")
    deep = kit.mat("violet_fonce", "#3E2060")
    belly = kit.mat("ventre", "#B48CE0")
    membrane = kit.mat("membrane", "#8A4AA8")
    pink = kit.mat("rose", "#FF8FB1")
    red = kit.mat("cape", "#D0202E")
    cape_in = kit.mat("cape_noire", "#1E1626")
    fang = kit.mat("croc", "#FFFFFF", rough=0.1)
    gold = kit.gold("or")
    ruby = kit.gem("rubis", core="#FFB0B8", mid="#E81E3C", rim="#7A0A1E")

    # --- corps poilu ---
    kit.add(kit.brick((0.4, 0.34, 0.42), center=(0, 0.02, 0.62)), purple, bevel=0.06)
    kit.add(kit.brick((0.26, 0.05, 0.3), center=(0, -0.16, 0.6)), belly, bevel=0.02)
    for x, z in ((-0.12, 0.44), (0.12, 0.44), (0.0, 0.4)):
        P.tuft_piece(kit, "Body", (x, 0.0, z), (x * 2, 0, -1), 0.08, 0.07, purple)
    # pattes griffues
    for s in (-1, 1):
        kit.add(kit.brick((0.07, 0.07, 0.14), center=(s * 0.1, 0.02, 0.36)), deep, bevel=0.015)
        for k in (-1, 1):
            kit.add(kit.wedge((0.025, 0.05, 0.05), center=(s * 0.1 + k * 0.025, -0.03, 0.29), rot=(90, 0, 0),
                              tip=0.15), fang, bevel=0.0)

    # --- col de cape dressé, médaillon ---
    for s in (-1, 1):
        kit.add(kit.slope((0.2, 0.06, 0.3), center=(s * 0.17, 0.14, 0.98), facing="-Y", top=0.4, rot=(0, s * -18, 0)),
                red, bevel=0.015)
        kit.add(kit.box((0.17, 0.02, 0.26), center=(s * 0.16, 0.105, 0.97), rot=(0, s * -18, 0)), cape_in, bevel=0.0)
    kit.add(kit.brick((0.44, 0.1, 0.08), center=(0, 0.06, 0.84)), red, bevel=0.02)
    kit.add(kit.brick((0.1, 0.04, 0.1), center=(0, -0.19, 0.78), rot=(0, 45, 0)), gold, bevel=0.012)
    kit.add(kit.brick((0.05, 0.03, 0.05), center=(0, -0.215, 0.78), rot=(0, 45, 0)), ruby, bevel=0.008)

    # --- tête : grandes oreilles, yeux rouges, crocs ---
    kit.add(kit.brick((0.42, 0.36, 0.34), center=(0, -0.02, 1.02)), purple, "Head", bevel=0.05)
    kit.add(kit.brick((0.22, 0.08, 0.12), center=(0, -0.21, 0.94)), belly, "Head", bevel=0.02)
    for s in (-1, 1):
        P.ear(kit, "Head", s, (s * 0.15, 0.0, 1.17), w=0.2, h=0.36, color=purple, inner=pink, tilt=(-4, 20))
    P.eyes(kit, "Head", x=0.1, y=-0.2, z=1.06, size=0.12, iris="#FF2A3C", pupil="round", brow=deep, brow_angle=10)
    P.nose(kit, "Head", y=-0.255, z=0.97, w=0.06, color="#FF8FB1", nostril="#7A2A4A")
    P.mouth(kit, "Head", y=-0.255, z=0.91, w=0.12, smile=0.45)
    for s in (-1, 1):
        kit.add(kit.wedge((0.03, 0.03, 0.05), center=(s * 0.035, -0.265, 0.88), rot=(180, 0, 0), tip=0.1), fang,
                "Head", bevel=0.0)

    # --- grandes ailes de chauve-souris déployées ---
    P.spread_wings(kit, x=0.2, y=0.06, z=0.74, span=0.86, height=0.6, mats=(deep, membrane, deep), style="bat",
                   sweep=18, lift=22)
    kit.part("Head", "Head", pivot=(0, 0.0, 0.86))
    return kit.result()
