"""Banane-Chien (Épique, Hybrides) : « Corps de banane, tête de Golden Retriever. »

En briques LEGO, très détaillé : long corps de banane jaune vif légèrement courbé (côtes plus foncées, petites taches
brunes, bout vert à l'avant), à moitié épluché au cou (trois lanières de peau qui retombent en collerette, chair
crème) ; tête de golden retriever doré tout content (grandes oreilles tombantes, museau clair, truffe, langue qui
pend, yeux brillants) ; quatre pattes de chien dorées ; la queue est la tige de la banane. Parties animées : tête,
oreilles, 4 pattes, queue (frétille).
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    yellow = kit.mat("banane", "#FFE02A")
    rib = kit.mat("cotes", "#F2C21E")
    spot = kit.mat("taches", "#8A5A1E")
    tip = kit.mat("bout_vert", "#8AD23A")
    flesh = kit.mat("chair", "#FFF6CC")
    gold = kit.mat("golden", "#F2B04A")
    cream = kit.mat("creme", "#FFE2A8")
    stem = kit.mat("tige", "#6A4A1E")
    tongue = kit.mat("langue", "#FF6A98")

    # --- long corps de banane courbé ---
    pts = [(0, -0.36, 0.66), (0, -0.14, 0.6), (0, 0.1, 0.58), (0, 0.34, 0.6), (0, 0.54, 0.68)]
    P.chain(kit, "Body", pts, 0.36, [yellow], taper=0.04, height=0.32)
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        cy, cz = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
        for s in (-1, 1):
            kit.add(kit.box((0.02, 0.2, 0.03), center=(s * (0.18 - k * 0.02), cy, cz + 0.06)), rib, bevel=0.0)
    for x, y, z in ((0.12, 0.06, 0.74), (-0.1, 0.28, 0.75), (0.14, 0.4, 0.62), (-0.15, -0.06, 0.56)):
        kit.add(kit.box((0.04, 0.04, 0.03), center=(x, y, z), rot=(0, 0, 30)), spot, bevel=0.0)
    kit.add(kit.brick((0.1, 0.1, 0.08), center=(0, 0.62, 0.72), rot=(-30, 0, 0)), tip, bevel=0.015)

    # --- peau épluchée en collerette au cou, chair crème ---
    kit.add(kit.brick((0.3, 0.14, 0.28), center=(0, -0.5, 0.72)), flesh, bevel=0.04)
    for k, (x, rz) in enumerate(((0.0, 0), (0.17, 40), (-0.17, -40))):
        kit.add(kit.brick((0.14, 0.04, 0.26), center=(x, -0.43 + abs(x) * 0.3, 0.48), rot=(18, 0, rz)), yellow,
                bevel=0.012)
        kit.add(kit.wedge((0.12, 0.04, 0.08), center=(x * 1.2, -0.45 + abs(x) * 0.3, 0.33), rot=(198, 0, rz), tip=0.3), tip,
                bevel=0.0)

    # --- tête de golden retriever ---
    kit.add(kit.brick((0.42, 0.38, 0.36), center=(0, -0.66, 0.92)), gold, "Head", bevel=0.05)
    kit.add(kit.brick((0.24, 0.22, 0.16), center=(0, -0.9, 0.84)), cream, "Head", bevel=0.035)
    kit.add(kit.slope((0.24, 0.2, 0.08), center=(0, -0.88, 0.95), facing="-Y", top=0.3), gold, "Head", bevel=0.012)
    P.nose(kit, "Head", y=-1.0, z=0.88, w=0.08, color="#1A1210")
    kit.add(kit.brick((0.08, 0.04, 0.12), center=(0.02, -1.0, 0.73)), tongue, "Head", bevel=0.012)
    P.mouth(kit, "Head", y=-1.005, z=0.8, w=0.14, smile=0.6)
    P.eyes(kit, "Head", x=0.11, y=-0.85, z=0.99, size=0.1, iris="#5A3412", pupil="round", tall=1.1)
    kit.part("Head", "Head", pivot=(0, -0.5, 0.8))
    for s, part in ((1, "EarL"), (-1, "EarR")):
        kit.add(kit.brick((0.08, 0.16, 0.24), center=(s * 0.24, -0.64, 0.9), rot=(0, s * -15, 0)), gold, part,
                bevel=0.03)
        kit.add(kit.brick((0.06, 0.14, 0.08), center=(s * 0.26, -0.64, 0.76), rot=(0, s * -15, 0)), rib, part,
                bevel=0.02)
        kit.part(part, "Ear", pivot=(s * 0.22, -0.64, 1.02), phase=float(s))

    # --- quatre pattes de chien dorées, queue-tige ---
    P.quad_legs(kit, gold, yf=-0.28, yb=0.4, top_f=0.56, top_b=0.6, length_f=0.52, length_b=0.56, w=0.11, paw=cream,
                toe=cream, x=0.13, toes=3)
    P.chain(kit, "Tail", [(0, 0.66, 0.74), (0, 0.74, 0.82), (0.02, 0.78, 0.92)], 0.06, [stem])
    kit.add(kit.brick((0.08, 0.08, 0.04), center=(0.02, 0.79, 0.98)), kit.mat("bout_tige", "#3A2A0E"), "Tail", bevel=0.01)
    kit.part("Tail", "Tail", pivot=(0, 0.64, 0.72))
    return kit.result()

