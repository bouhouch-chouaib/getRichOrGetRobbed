"""Pingouin Patineur (Rare, Glace) : « Champion de patinage artistique, triple axel sur la banquise. »

En briques LEGO, très détaillé (Rare : émail, aucune lueur) : pingouin debout, dos bleu nuit laqué, ventre blanc,
justaucorps de patinage bleu ciel à paillettes (petites tuiles blanches et argent), petite écharpe rouge qui vole,
bec et joues, yeux fiers, nageoires écartées comme un patineur, PATINS blancs à lames en acier sur les pieds orange,
médaille d'or au cou. Parties animées : tête, nageoires, pieds, écharpe.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    navy = kit.enamel("dos", "#1E2A4A")
    white = kit.mat("ventre", "#FFFFFF")
    sky = kit.enamel("justaucorps", "#5AB4FF")
    sparkle = kit.mat("paillettes", "#E6F2FF", metal=0.5, rough=0.2)
    red = kit.enamel("echarpe", "#FF2A3A")
    beak = kit.enamel("bec", "#FF8A12")
    skate = kit.mat("patins", "#F6F6F8", rough=0.2)
    blade = kit.mat("lames", "#C8D0DC", metal=0.85, rough=0.15)
    medal = kit.gold("medaille", hammered=0.2)
    pink = kit.mat("joues", "#FF9AB4")

    # --- corps debout, justaucorps à paillettes ---
    kit.add(kit.brick((0.46, 0.38, 0.6), center=(0, 0, 0.5)), navy, bevel=0.07)
    kit.add(kit.brick((0.34, 0.06, 0.5), center=(0, -0.19, 0.48)), white, bevel=0.03)
    kit.add(kit.brick((0.48, 0.4, 0.2), center=(0, 0, 0.36)), sky, bevel=0.04)
    for x, z in ((-0.1, 0.32), (0.06, 0.4), (0.14, 0.3), (-0.02, 0.28), (0.18, 0.42), (-0.18, 0.4)):
        kit.add(kit.box((0.025, 0.012, 0.025), center=(x, -0.205, z), rot=(0, 45, 0)), sparkle, bevel=0.0)

    # --- tête, bec, joues, écharpe, médaille ---
    kit.add(kit.brick((0.4, 0.36, 0.32), center=(0, -0.02, 0.94)), navy, "Head", bevel=0.06)
    kit.add(kit.brick((0.3, 0.06, 0.22), center=(0, -0.2, 0.92)), white, "Head", bevel=0.03)
    kit.add(kit.brick((0.12, 0.12, 0.06), center=(0, -0.28, 0.88)), beak, "Head", bevel=0.02)
    P.eyes(kit, "Head", x=0.08, y=-0.225, z=0.98, size=0.08, iris="#1A1A2A", pupil="round", lid=navy, lid_drop=0.15,
           tall=1.0)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.03), center=(s * 0.12, -0.23, 0.9)), pink, "Head", bevel=0.004)
    kit.part("Head", "Head", pivot=(0, 0, 0.78))
    kit.add(kit.brick((0.44, 0.4, 0.07), center=(0, 0, 0.8)), red, bevel=0.02)
    P.chain(kit, "Scarf", [(0.14, 0.18, 0.8), (0.24, 0.32, 0.76), (0.32, 0.44, 0.7)], 0.08, [red], height=0.03)
    kit.part("Scarf", "Leaf", pivot=(0.14, 0.18, 0.8), phase=0.6)
    kit.add(kit.disc(0.05, 0.02, center=(0, -0.215, 0.7), normal=(0, -1, 0), sides=10), medal, bevel=0.0)

    # --- nageoires écartées de patineur ---
    for s, part in ((1, "WingL"), (-1, "WingR")):
        kit.add(kit.brick((0.3, 0.12, 0.06), center=(s * 0.36, 0, 0.62), rot=(0, s * -25, 0)), navy, part, bevel=0.02)
        kit.part(part, "Wing", pivot=(s * 0.23, 0, 0.68), phase=float(s))

    # --- pieds orange sur patins à lames d'acier ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        x = s * 0.11
        kit.add(kit.brick((0.12, 0.18, 0.06), center=(x, -0.04, 0.16)), beak, part, bevel=0.015)
        kit.add(kit.brick((0.12, 0.22, 0.08), center=(x, -0.02, 0.11)), skate, part, bevel=0.02)
        kit.add(kit.box((0.02, 0.3, 0.04), center=(x, -0.03, 0.04)), blade, part, bevel=0.0)
        kit.add(kit.box((0.02, 0.04, 0.04), center=(x, -0.17, 0.07), rot=(30, 0, 0)), blade, part, bevel=0.0)
        kit.part(part, "Leg", pivot=(x, 0, 0.2), phase=0.0 if s > 0 else math.pi)
    return kit.result()
