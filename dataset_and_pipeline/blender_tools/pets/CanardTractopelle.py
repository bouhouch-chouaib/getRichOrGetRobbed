"""Le Canard-Tractopelle (Sigma, Hybrides) : « Canard de bain géant sur chenilles en or massif. »

En briques LEGO, très détaillé : énorme canard de bain en OR massif brillant (corps rond en couches, queue relevée,
ailes plaquées), grosse tête au bec orange, grands yeux brillants, casque de chantier blanc à bande orange ; il est
posé sur un châssis d'engin sur deux CHENILLES (patins noirs, roues dorées) ; devant, un bras de tractopelle articulé
en or avec un godet à dents ; derrière, un pot d'échappement chromé et un gyrophare orange LUMINEUX.
Parties animées : tête, bras du tractopelle (creuse), gyrophare.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    gold = kit.mat("or", "#FFC21E", metal=0.9, rough=0.15)
    gold2 = kit.mat("or_clair", "#FFE06A", metal=0.85, rough=0.12)
    deep = kit.mat("or_fonce", "#D8900A", metal=0.9, rough=0.2)
    beak = kit.mat("bec", "#FF7A12", rough=0.15)
    white = kit.mat("casque", "#FFFFFF", rough=0.15)
    orange = kit.mat("bande", "#FF6A12")
    track = kit.mat("chenille", "#22242A", rough=0.5)
    link = kit.mat("patins", "#3A3E48", metal=0.6, rough=0.3)
    chrome = kit.mat("chrome", "#E2E8F2", metal=0.95, rough=0.1)
    beacon = kit.mat("gyrophare", "#FF8A1E", rough=0.1, glow=3.0)
    teeth = kit.mat("dents", "#B8BEC8", metal=0.8, rough=0.2)

    # --- chenilles et châssis ---
    for s in (-1, 1):
        P.treads(kit, "Body", s * 0.36, -0.42, 0.46, 0.14, 0.24, 0.2, track, gold, link)
    kit.add(kit.brick((0.56, 0.86, 0.12), center=(0, 0.02, 0.28)), deep, bevel=0.03)

    # --- canard d'or en couches, queue relevée, ailes plaquées ---
    kit.add(kit.brick((0.7, 0.86, 0.32), center=(0, 0.06, 0.5)), gold, bevel=0.08)
    kit.add(kit.brick((0.6, 0.74, 0.16), center=(0, 0.08, 0.7)), gold, bevel=0.06)
    kit.add(kit.slope((0.4, 0.26, 0.26), center=(0, 0.52, 0.72), facing="+Y", top=0.3, rot=(180, 0, 180)), gold,
            bevel=0.04)
    for s in (-1, 1):
        kit.add(kit.brick((0.08, 0.46, 0.22), center=(s * 0.37, 0.12, 0.58), rot=(0, 0, s * 4)), gold2, bevel=0.04)
        for k in range(3):
            kit.add(kit.wedge((0.06, 0.06, 0.1), center=(s * 0.38, 0.34 + k * 0.04, 0.5 + k * 0.03), rot=(-90, 0, 0),
                              tip=0.2), deep, bevel=0.0)

    # --- tête : bec, yeux, casque de chantier ---
    kit.add(kit.brick((0.46, 0.42, 0.42), center=(0, -0.22, 1.0)), gold, "Head", bevel=0.08)
    kit.add(kit.brick((0.36, 0.26, 0.12), center=(0, -0.5, 0.92)), beak, "Head", bevel=0.04)
    kit.add(kit.brick((0.3, 0.2, 0.05), center=(0, -0.48, 0.85)), kit.mat("bec_fonce", "#E0520A"), "Head", bevel=0.015)
    P.eyes(kit, "Head", x=0.12, y=-0.43, z=1.08, size=0.12, iris="#2A1A0E", pupil="round", tall=1.15)
    kit.add(kit.brick((0.5, 0.46, 0.14), center=(0, -0.22, 1.27)), white, "Head", bevel=0.05)
    kit.add(kit.brick((0.4, 0.36, 0.08), center=(0, -0.22, 1.36)), white, "Head", bevel=0.03)
    kit.add(kit.brick((0.52, 0.48, 0.04), center=(0, -0.22, 1.22)), orange, "Head", bevel=0.01)
    kit.add(kit.brick((0.4, 0.14, 0.03), center=(0, -0.48, 1.21)), white, "Head", bevel=0.01)
    kit.part("Head", "Head", pivot=(0, -0.2, 0.8))

    # --- bras de tractopelle articulé et godet ---
    for s in (-1, 1):
        kit.add(kit.brick((0.06, 0.4, 0.08), center=(s * 0.18, -0.56, 0.4), rot=(-20, 0, 0)), gold, "Arm", bevel=0.015)
        kit.add(kit.brick((0.05, 0.05, 0.22), center=(s * 0.18, -0.36, 0.4)), chrome, "Arm", bevel=0.008)
    kit.add(kit.brick((0.44, 0.18, 0.06), center=(0, -0.8, 0.28)), deep, "Arm", bevel=0.015)
    kit.add(kit.brick((0.44, 0.06, 0.18), center=(0, -0.72, 0.36)), deep, "Arm", bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.brick((0.04, 0.18, 0.18), center=(s * 0.21, -0.8, 0.36)), deep, "Arm", bevel=0.01)
    for k in range(5):
        kit.add(kit.wedge((0.05, 0.05, 0.06), center=((k - 2) * 0.09, -0.92, 0.27), rot=(90, 0, 0), tip=0.2), teeth,
                "Arm", bevel=0.0)
    kit.part("Arm", "Excavator", pivot=(0, -0.34, 0.42))

    # --- pot d'échappement et gyrophare ---
    kit.add(kit.brick((0.08, 0.08, 0.36), center=(0.22, 0.4, 0.86)), chrome, bevel=0.02)
    kit.add(kit.brick((0.1, 0.1, 0.04), center=(0.22, 0.4, 1.05)), track, bevel=0.01)
    kit.add(kit.brick((0.1, 0.1, 0.06), center=(-0.2, 0.3, 0.81)), track, bevel=0.015)
    kit.add(kit.brick((0.08, 0.08, 0.1), center=(-0.2, 0.3, 0.89)), beacon, "Beacon", bevel=0.02)
    kit.part("Beacon", "Rotor", pivot=(-0.2, 0.3, 0.86))
    return kit.result()
