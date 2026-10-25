"""Grenouille Globuleuse (Inhabituel, Animaux) : « Grenouille vert fluo aux yeux énormes. »

En briques LEGO, très détaillée : corps trapu vert fluo en trois étages arrondis par des pentes, ventre et flancs vert
citron, petites pustules et taches vert foncé sur le dos, grand sourire qui fait le tour de l'avant, joues roses,
narines, deux ÉNORMES yeux globuleux sur le dessus (socle vert, œil blanc, iris doré, grosse pupille, reflets,
paupière), cuisses repliées à jambes et grands pieds palmés à 4 doigts ronds, bras avant à mains écartées.
Parties animées : yeux (« Head »), pattes arrière (« FrogLeg », sauts), bras (« Arm »).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.mat("vert", "#33E02A", rough=0.22)
    lime = kit.mat("citron", "#D6FF5A")
    dark = kit.mat("vert_fonce", "#169A28")
    pink = kit.mat("joues", "#FF7FA8")
    white = kit.mat("blanc", "#FFFFFF", rough=0.12)

    # --- corps trapu : trois étages arrondis ---
    kit.add(kit.brick((0.88, 0.78, 0.24), center=(0, 0.02, 0.24)), green, bevel=0.04)
    kit.add(kit.brick((0.8, 0.72, 0.22), center=(0, 0.04, 0.46)), green, bevel=0.035)
    kit.add(kit.brick((0.66, 0.46, 0.12), center=(0, 0.08, 0.62)), green, bevel=0.025)
    kit.add(kit.slope((0.66, 0.14, 0.12), center=(0, -0.21, 0.62), facing="-Y", top=0.3), green, bevel=0.02)
    kit.add(kit.slope((0.66, 0.14, 0.12), center=(0, 0.38, 0.62), facing="+Y", top=0.3), green, bevel=0.02)
    for s in (-1, 1):
        kit.add(kit.slope((0.08, 0.5, 0.12), center=(s * 0.37, 0.08, 0.62), facing=P.side(s), top=0.3), green,
                bevel=0.012)
        kit.add(kit.brick((0.04, 0.6, 0.12), center=(s * 0.44, 0.02, 0.18)), lime, bevel=0.01)
    kit.add(kit.brick((0.62, 0.05, 0.3), center=(0, -0.395, 0.26)), lime, bevel=0.02)
    # pustules et taches sur le dos
    for x, y, w in ((0.2, 0.2, 0.12), (-0.18, 0.04, 0.1), (0.04, 0.26, 0.08), (-0.2, 0.3, 0.07), (0.24, -0.02, 0.07)):
        kit.add(kit.tile(w, w, center=(x, y, 0.685)), dark, bevel=0.006)
    for x, y in ((0.1, 0.12), (-0.08, 0.18), (0.26, 0.3), (-0.28, 0.16)):
        kit.add(kit.brick((0.045, 0.045, 0.035), center=(x, y, 0.69)), green, bevel=0.008)
    # grand sourire, joues roses, narines
    P.mouth(kit, "Body", y=-0.4, z=0.43, w=0.66, color="#0E5A1A", smile=0.45)
    for s in (-1, 1):
        kit.add(kit.box((0.1, 0.02, 0.06), center=(s * 0.3, -0.405, 0.5)), pink, bevel=0.006)
        kit.add(kit.box((0.035, 0.03, 0.02), center=(s * 0.06, -0.24, 0.69)), dark, bevel=0.0)

    # --- énormes yeux globuleux ---
    for s in (-1, 1):
        x = s * 0.2
        kit.add(kit.brick((0.3, 0.28, 0.12), center=(x, -0.12, 0.72)), green, "Head", bevel=0.025)
        kit.add(kit.brick((0.27, 0.25, 0.24), center=(x, -0.13, 0.88)), white, "Head", bevel=0.045)
        kit.add(kit.brick((0.29, 0.27, 0.06), center=(x, -0.12, 1.02)), green, "Head", bevel=0.015)
        kit.add(kit.slope((0.29, 0.07, 0.06), center=(x, -0.24, 1.02), facing="-Y", top=0.3), green, "Head",
                bevel=0.01)
    P.eyes(kit, "Head", x=0.2, y=-0.255, z=0.87, size=0.2, iris="#FFC81E", pupil="round", sclera="#FFFFFF")

    # --- cuisses, jambes et grands pieds palmés (sauts) ---
    for s, part in ((1, "LegBL"), (-1, "LegBR")):
        x = s * 0.46
        kit.add(kit.brick((0.2, 0.42, 0.22), center=(x, 0.12, 0.22), rot=(0, 0, s * -10)), green, part, bevel=0.035)
        kit.add(kit.brick((0.12, 0.3, 0.1), center=(s * 0.52, 0.0, 0.08), rot=(0, 0, s * -18)), green, part, bevel=0.02)
        kit.add(kit.brick((0.3, 0.26, 0.04), center=(s * 0.54, -0.16, 0.02), rot=(0, 0, s * -8)), lime, part,
                bevel=0.012)
        for k in range(4):
            a = math.radians(-30 + k * 20) * s
            fx, fy = s * 0.54 + math.sin(a) * 0.18, -0.16 - math.cos(a) * 0.18
            kit.add(kit.brick((0.05, 0.14, 0.035), center=(fx, fy, 0.02), rot=(0, 0, -math.degrees(a))), lime, part,
                    bevel=0.006)
            kit.add(kit.brick((0.07, 0.07, 0.04), center=(fx + math.sin(a) * 0.08, fy - math.cos(a) * 0.08, 0.022)),
                    green, part, bevel=0.01)
        kit.part(part, "FrogLeg", pivot=(s * 0.42, 0.25, 0.28))
    # --- bras avant, mains à 4 doigts écartés ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        x = s * 0.25
        kit.add(kit.brick((0.1, 0.12, 0.18), center=(x, -0.34, 0.12), rot=(-12, 0, 0)), green, part, bevel=0.018)
        for k in range(4):
            a = math.radians(-36 + k * 24)
            kit.add(kit.brick((0.035, 0.1, 0.03), center=(x + math.sin(a) * 0.07, -0.45 - math.cos(a) * 0.05, 0.015),
                              rot=(0, 0, -math.degrees(a))), lime, part, bevel=0.005)
        kit.part(part, "Arm", pivot=(x, -0.32, 0.22), phase=0.0 if s > 0 else math.pi)

    kit.part("Head", "Head", pivot=(0, -0.12, 0.66))
    return kit.result()
