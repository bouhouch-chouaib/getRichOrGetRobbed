"""Astro-Hamster (Épique, Cosmos) : « Premier hamster à avoir couru dans une roue en apesanteur. »

En briques LEGO, très détaillé (Épique : chrome et cristal, aucune lueur) : hamster abricot aux grosses joues dans une
combinaison spatiale blanche (écusson, tuyaux chromés), casque-bulle en CRISTAL bleuté, réservoir dans le dos ; il
court dans une grande ROUE chromée à rayons qui TOURNE autour de lui, avec deux petits propulseurs ; mini-drapeau.
Parties animées : la roue (tourne), bras, jambes, oreilles.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    fur = kit.mat("pelage", "#F2A85A")
    cream = kit.mat("creme", "#FFF0DC")
    suit = kit.mat("combinaison", "#F4F4F8")
    chrome = kit.chrome("chrome")
    dome = kit.gem("casque", "#7AA8C8", "#D8F0FF", "#FFFFFF")
    blue = kit.enamel("ecusson", "#2E7CFF")
    red = kit.enamel("rouge", "#FF2A3A")
    pink = kit.mat("rose", "#FF9AB4")

    # --- hamster en combinaison spatiale ---
    kit.add(kit.brick((0.34, 0.3, 0.32), center=(0, 0, 0.52)), suit, bevel=0.06)
    kit.add(kit.brick((0.1, 0.03, 0.08), center=(0.08, -0.16, 0.58)), blue, bevel=0.012)
    kit.add(kit.box((0.04, 0.03, 0.02), center=(0.08, -0.17, 0.58)), red, bevel=0.0)
    kit.add(kit.brick((0.2, 0.12, 0.26), center=(0, 0.2, 0.54)), chrome, bevel=0.03)
    kit.add(kit.box((0.03, 0.2, 0.03), center=(0.12, 0.08, 0.64), rot=(30, 0, 0)), chrome, bevel=0.0)

    # --- tête : grosses joues, oreilles, casque-bulle ---
    kit.add(kit.brick((0.34, 0.3, 0.28), center=(0, -0.02, 0.84)), fur, "Head", bevel=0.06)
    kit.add(kit.brick((0.24, 0.06, 0.14), center=(0, -0.17, 0.79)), cream, "Head", bevel=0.03)
    for s in (-1, 1):
        kit.add(kit.brick((0.1, 0.12, 0.12), center=(s * 0.17, -0.1, 0.78)), cream, "Head", bevel=0.04)
    P.eyes(kit, "Head", x=0.07, y=-0.17, z=0.89, size=0.07, iris="#1A1210", pupil="round", tall=1.2)
    P.nose(kit, "Head", y=-0.2, z=0.81, w=0.04, color="#FF7A98")
    # casque ouvert devant (un cristal plein cacherait le visage) : coque derrière et dessus, cadre chromé
    kit.add(kit.brick((0.5, 0.2, 0.42), center=(0, 0.12, 0.86)), dome, "Head", bevel=0.08)
    kit.add(kit.brick((0.5, 0.42, 0.1), center=(0, -0.02, 1.1)), dome, "Head", bevel=0.04)
    kit.add(kit.brick((0.5, 0.04, 0.04), center=(0, -0.22, 1.06)), chrome, "Head", bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.brick((0.04, 0.42, 0.42), center=(s * 0.25, -0.02, 0.86)), chrome, "Head", bevel=0.012)
    kit.add(kit.brick((0.44, 0.4, 0.04), center=(0, -0.02, 0.66)), chrome, "Head", bevel=0.012)
    kit.add(kit.box((0.02, 0.02, 0.14), center=(0.18, 0.06, 1.22)), chrome, "Head", bevel=0.0)
    kit.add(kit.brick((0.05, 0.05, 0.05), center=(0.18, 0.06, 1.3)), red, "Head", bevel=0.015)
    kit.part("Head", "Head", pivot=(0, 0, 0.68))
    for s, part in ((1, "EarL"), (-1, "EarR")):
        kit.add(kit.brick((0.08, 0.04, 0.08), center=(s * 0.12, 0.0, 0.99)), pink, part, bevel=0.02)
        kit.part(part, "Ear", pivot=(s * 0.12, 0.0, 0.97), phase=float(s))

    # --- bras et jambes qui courent ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.08, 0.08, 0.16), center=(s * 0.21, -0.04, 0.52)), suit, part, bevel=0.025)
        kit.add(kit.brick((0.07, 0.07, 0.05), center=(s * 0.21, -0.06, 0.43)), fur, part, bevel=0.015)
        kit.part(part, "Arm", pivot=(s * 0.18, 0, 0.6), phase=0.0 if s > 0 else math.pi)
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.1, 0.12, 0.14), center=(s * 0.08, 0, 0.32)), suit, part, bevel=0.025)
        kit.add(kit.brick((0.1, 0.14, 0.04), center=(s * 0.08, -0.02, 0.23)), fur, part, bevel=0.012)
        kit.part(part, "Leg", pivot=(s * 0.08, 0, 0.4), phase=0.0 if s > 0 else math.pi)

    # --- grande roue chromée qui tourne (dans le plan avant-arrière : il court droit devant), support, propulseurs ---
    cz, r, half = 0.76, 0.58, 0.29
    for k in range(18):
        a = 2 * math.pi * k / 18
        kit.add(kit.brick((half * 2, 0.06, 0.06), center=(0, math.sin(a) * r, cz + math.cos(a) * r),
                          rot=(-math.degrees(a), 0, 0)), chrome, "Wheel", bevel=0.01)
    for x in (-half, half):
        for k in range(28):
            a = 2 * math.pi * (k + 0.5) / 28
            kit.add(kit.brick((0.04, 0.14, 0.05), center=(x, math.sin(a) * r, cz + math.cos(a) * r),
                              rot=(-math.degrees(a), 0, 0)), blue, "Wheel", bevel=0.008)
        for k in range(6):
            a = 2 * math.pi * k / 6
            kit.add(kit.box((0.02, 0.02, r), center=(x, math.sin(a) * r / 2, cz + math.cos(a) * r / 2),
                            rot=(-math.degrees(a), 0, 0)), chrome, "Wheel", bevel=0.0)
        kit.add(kit.disc(0.07, 0.05, center=(x, 0, cz), normal=(1, 0, 0), sides=10), chrome, "Wheel", bevel=0.0)
    kit.part("Wheel", "Drum", pivot=(0, 0, cz), rot=(0, 0, 90))
    for s in (-1, 1):
        x = s * (half + 0.06)
        for y in (-0.34, 0.34):
            P.chain(kit, "Body", [(x, 0, cz), (x, y, 0.03)], 0.05, [chrome])
        kit.add(kit.brick((0.08, 0.8, 0.05), center=(x, 0, 0.025)), chrome, bevel=0.012)
        kit.add(kit.brick((0.1, 0.12, 0.18), center=(x + s * 0.04, 0.36, 0.2)), chrome, bevel=0.025)
        kit.add(kit.brick((0.08, 0.06, 0.08), center=(x + s * 0.04, 0.44, 0.2)), red, bevel=0.012)
    # petit drapeau planté sur le support
    kit.add(kit.box((0.02, 0.02, 0.36), center=(-half - 0.06, 0.34, 0.24)), chrome, bevel=0.0)
    kit.add(kit.brick((0.02, 0.16, 0.1), center=(-half - 0.06, 0.42, 0.37)), blue, bevel=0.006)
    kit.add(kit.box((0.025, 0.05, 0.03), center=(-half - 0.06, 0.4, 0.38)), red, bevel=0.0)
    return kit.result()
