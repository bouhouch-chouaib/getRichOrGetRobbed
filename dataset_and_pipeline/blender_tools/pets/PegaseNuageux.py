"""Pégase Nuageux (Légendaire, Fantastiques) : « Cheval blanc aux ailes de nuages. »

En briques LEGO, très détaillé : cheval blanc nacré élancé (torse sculpté, longues pattes à sabots dorés), museau
nacré au bout rose et naseaux, grands yeux bleu ciel à longs cils, crinière et queue en NUAGES bleu ciel (blocs empilés en
grappes), grandes ailes déployées en plumes blanches et bleues bordées de nuages, petits nuages qui flottent sous chaque sabot, étoile dorée
sur le front. Il vole (Float). Parties animées : tête, ailes, 4 pattes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def _cloud(kit, part, x, y, z, w, mats):
    a, b = mats
    kit.add(kit.brick((w, w * 0.9, w * 0.7), center=(x, y, z)), a, part, bevel=w * 0.25)
    kit.add(kit.brick((w * 0.7, w * 0.7, w * 0.6), center=(x + w * 0.45, y + w * 0.1, z - w * 0.12)), b, part,
            bevel=w * 0.22)
    kit.add(kit.brick((w * 0.65, w * 0.7, w * 0.55), center=(x - w * 0.42, y - w * 0.08, z - w * 0.14)), b, part,
            bevel=w * 0.2)
    kit.add(kit.brick((w * 0.55, w * 0.6, w * 0.5), center=(x + w * 0.1, y - w * 0.05, z + w * 0.38)), a, part,
            bevel=w * 0.2)


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("blanc", "#FFFFFF", rough=0.15)
    pearl = kit.mat("nacre", "#E6EEFF", rough=0.15)
    sky = kit.mat("bleu_ciel", "#7CC8FF", rough=0.2)
    sky2 = kit.mat("bleu_clair", "#B8E2FF", rough=0.2)
    pink = kit.mat("museau", "#FFC6D8")
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.2)
    dark = kit.mat("naseaux", "#5A4A6A")

    # --- torse élancé, poitrail ---
    P.quad_torso(kit, L=0.96, W=0.44, H=0.34, z=0.86, y0=0.04, main=white, belly=pearl, chest=white, back=pearl)
    kit.add(kit.brick((0.28, 0.28, 0.44), center=(0, -0.44, 1.1), rot=(28, 0, 0)), white, bevel=0.04)

    # --- tête : chanfrein, museau nacré à bout rose, naseaux, yeux à cils, étoile dorée, oreilles ---
    kit.add(kit.brick((0.36, 0.4, 0.32), center=(0, -0.62, 1.38)), white, "Head", bevel=0.04)
    kit.add(kit.brick((0.28, 0.28, 0.22), center=(0, -0.9, 1.27)), pearl, "Head", bevel=0.04)
    kit.add(kit.brick((0.22, 0.03, 0.12), center=(0, -1.045, 1.26)), pink, "Head", bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.05), center=(s * 0.07, -1.065, 1.29)), dark, "Head", bevel=0.0)
        P.ear(kit, "Head", s, (s * 0.13, -0.52, 1.54), w=0.11, h=0.17, color=white, inner=pink, tilt=(-8, 10))
        for k in range(3):  # cils
            kit.add(kit.box((0.012, 0.012, 0.05), center=(s * (0.13 + k * 0.03), -0.83, 1.52),
                            rot=(0, s * (20 + k * 15), 0)), dark, "Head", bevel=0.0)
    P.mouth(kit, "Head", y=-1.062, z=1.21, w=0.13, smile=0.45)
    P.eyes(kit, "Head", x=0.12, y=-0.82, z=1.44, size=0.12, iris="#3AA8FF", pupil="round", lid=white, lid_drop=0.0)
    kit.add(kit.brick((0.08, 0.03, 0.08), center=(0, -0.83, 1.5), rot=(0, 45, 0)), gold, "Head", bevel=0.006)

    # --- crinière en nuages bleu ciel ---
    for k, (y, z, w) in enumerate(((-0.52, 1.56, 0.16), (-0.42, 1.44, 0.17), (-0.32, 1.3, 0.16), (-0.22, 1.16, 0.14))):
        _cloud(kit, "Head" if k < 2 else "Body", 0.0, y, z, w, (sky, sky2))

    # --- grandes ailes de plumes bordées de nuages ---
    span, lift, sweep = 0.78, 22.0, 25.0
    P.spread_wings(kit, x=0.2, y=-0.12, z=1.06, span=span, height=0.42, mats=(white, sky2, sky), style="feather",
                   sweep=sweep, lift=lift)
    for s, part in ((1, "WingL"), (-1, "WingR")):  # nuages sur le bord avant des ailes
        for u, w in ((0.12, 0.13), (0.34, 0.12), (0.56, 0.1)):
            uu = span * u
            px = s * 0.2 + s * uu * math.cos(math.radians(lift))
            pz = 1.06 + uu * math.sin(math.radians(lift)) + 0.14
            py = -0.12 + uu * math.sin(math.radians(sweep)) * 0.5 - 0.02
            _cloud(kit, part, px, py, pz, w, (white, sky2))

    # --- longues pattes à sabots dorés, petits nuages sous les sabots ---
    P.quad_legs(kit, white, yf=-0.32, yb=0.38, top_f=0.9, top_b=0.94, length_f=0.86, length_b=0.9, w=0.12, paw=gold,
                toe=gold, x=0.15, toes=1)
    for part, x, y in (("LegFL", 0.15, -0.32), ("LegFR", -0.15, -0.32), ("LegBL", 0.15, 0.38), ("LegBR", -0.15, 0.38)):
        _cloud(kit, part, x, y + 0.02, 0.05, 0.1, (white, sky2))

    # --- queue en nuages ---
    for k, (y, z, w) in enumerate(((0.54, 0.98, 0.15), (0.64, 0.86, 0.16), (0.7, 0.72, 0.15), (0.72, 0.58, 0.12))):
        _cloud(kit, "Tail", 0.0, y, z, w, (sky, sky2))
    kit.part("Tail", "Tail", pivot=(0, 0.5, 1.0))
    kit.part("Head", "Head", pivot=(0, -0.5, 1.24))
    return kit.result()
