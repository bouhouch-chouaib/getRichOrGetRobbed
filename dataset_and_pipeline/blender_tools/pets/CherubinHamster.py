"""Chérubin Hamster (Légendaire, Divin) : « Hamster aux petites ailes dorées qui joue de la harpe. »

En briques LEGO, très détaillé (Légendaire : or martelé, aucune lueur) : hamster tout rond crème et abricot, joues
roses rebondies, yeux fermés de béatitude, petite toge blanche nouée à l'épaule par une broche en or, petites ailes
de plumes en OR martelé qui battent vite, auréole en or au-dessus de la tête, et une petite HARPE dorée à cordes
dans les bras. Il flotte. Parties animées : ailes (battent), bras (jouent), auréole.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    cream = kit.mat("creme", "#FFF0DC")
    apricot = kit.mat("abricot", "#F6B46A")
    pink = kit.mat("joues", "#FF9AB4")
    toga = kit.mat("toge", "#FFFFFF", rough=0.3)
    gold = kit.gold("or", hammered=0.35)
    string = kit.mat("cordes", "#FFF4D0")
    dark = kit.mat("traits", "#3A2A1A")

    # --- corps tout rond, toge ---
    kit.add(kit.brick((0.5, 0.44, 0.46), center=(0, 0, 0.4)), apricot, bevel=0.1)
    kit.add(kit.brick((0.38, 0.06, 0.34), center=(0, -0.22, 0.38)), cream, bevel=0.04)
    kit.add(kit.brick((0.52, 0.46, 0.2), center=(0, 0, 0.26), rot=(0, -12, 0)), toga, bevel=0.05)
    kit.add(kit.brick((0.1, 0.4, 0.3), center=(0.16, 0, 0.46), rot=(0, -30, 0)), toga, bevel=0.03)
    kit.add(kit.disc(0.04, 0.02, center=(0.2, -0.2, 0.6), normal=(0, -1, 0), sides=10), gold, bevel=0.0)

    # --- tête : joues, yeux béats, oreilles, auréole ---
    kit.add(kit.brick((0.44, 0.38, 0.34), center=(0, -0.04, 0.78)), apricot, bevel=0.08)
    kit.add(kit.brick((0.3, 0.06, 0.2), center=(0, -0.22, 0.74)), cream, bevel=0.04)
    for s in (-1, 1):
        kit.add(kit.brick((0.14, 0.14, 0.14), center=(s * 0.18, -0.14, 0.7)), cream, bevel=0.05)
        kit.add(kit.box((0.06, 0.02, 0.04), center=(s * 0.18, -0.215, 0.71)), pink, bevel=0.005)
        kit.add(kit.box((0.07, 0.02, 0.018), center=(s * 0.08, -0.255, 0.82), rot=(0, s * -15, 0)), dark, bevel=0.0)
        kit.add(kit.brick((0.08, 0.04, 0.08), center=(s * 0.14, -0.02, 0.97)), pink, bevel=0.02)
    P.nose(kit, "Body", y=-0.25, z=0.75, w=0.04, color="#FF7A98")
    P.mouth(kit, "Body", y=-0.255, z=0.69, w=0.06, smile=0.6)
    for k in range(10):
        a = 2 * math.pi * k / 10
        kit.add(kit.brick((0.08, 0.04, 0.03), center=(math.cos(a) * 0.15, -0.04 + math.sin(a) * 0.15, 1.1),
                          rot=(0, 0, math.degrees(a) + 90)), gold, "Halo", bevel=0.006)
    kit.part("Halo", "Toast", pivot=(0, -0.04, 1.08), phase=0.5)

    # --- petites ailes d'or ---
    P.spread_wings(kit, x=0.2, y=0.2, z=0.56, span=0.34, height=0.22, mats=(gold, gold, toga), style="feather", sweep=30,
                   lift=30)

    # --- bras qui jouent de la harpe ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.08, 0.1, 0.12), center=(s * 0.16, -0.24, 0.46)), apricot, part, bevel=0.03)
        kit.part(part, "Arm", pivot=(s * 0.18, -0.16, 0.5), phase=0.0 if s > 0 else math.pi)
    kit.add(kit.brick((0.04, 0.04, 0.3), center=(-0.08, -0.32, 0.42)), gold, bevel=0.008)
    kit.add(kit.brick((0.2, 0.04, 0.04), center=(0.0, -0.32, 0.56), rot=(0, -20, 0)), gold, bevel=0.008)
    kit.add(kit.brick((0.14, 0.04, 0.04), center=(0.02, -0.32, 0.28)), gold, bevel=0.008)
    for k in range(4):
        kit.add(kit.box((0.008, 0.01, 0.26 - k * 0.04), center=(-0.04 + k * 0.035, -0.32, 0.41 + k * 0.01)), string,
                bevel=0.0)
    return kit.result()
