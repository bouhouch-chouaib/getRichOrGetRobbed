"""Kitsune à 3 Queues (Légendaire, Fantastiques) : « Renard blanc aux marques rouges et trois queues. »

En briques LEGO, très détaillé : renard blanc neige élancé, marques rouge vif (traits sous les yeux, triangle sur le
front, bouts d'oreilles, chaussettes), yeux dorés en amande soulignés de rouge, museau fin à truffe noire, grandes
oreilles à intérieur rose, cordon rouge noué au cou avec une clochette dorée, TROIS grosses queues touffues en éventail
à bouts rouges coiffés d'une petite flamme orange. Parties animées : tête, 4 pattes, trois queues (chacune son rythme).
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("blanc", "#FFFFFF", rough=0.2)
    snow = kit.mat("blanc_bleute", "#E8EEFA", rough=0.2)
    red = kit.mat("rouge", "#FF1E3C")
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.2)
    flame = kit.mat("flamme", "#FF8A1E", rough=0.2, glow=1.6)
    pink = kit.mat("rose", "#FFB0C8")
    black = kit.mat("noir", "#1A1418")

    # --- torse élancé, cou incliné, cordon rouge et clochette ---
    P.quad_torso(kit, L=0.9, W=0.42, H=0.3, z=0.62, y0=0.05, main=white, belly=snow, chest=snow, back=white)
    kit.add(kit.brick((0.3, 0.28, 0.34), center=(0, -0.42, 0.84), rot=(24, 0, 0)), white, bevel=0.03)
    kit.add(kit.brick((0.36, 0.3, 0.07), center=(0, -0.42, 0.72), rot=(24, 0, 0)), red, bevel=0.012)
    kit.add(kit.brick((0.1, 0.1, 0.1), center=(0, -0.6, 0.6)), gold, bevel=0.025)
    kit.add(kit.box((0.06, 0.02, 0.02), center=(0, -0.655, 0.58)), black, bevel=0.0)

    # --- tête : museau fin, marques rouges, yeux dorés en amande, grandes oreilles ---
    kit.add(kit.brick((0.44, 0.36, 0.3), center=(0, -0.56, 1.06)), white, "Head", bevel=0.035)
    kit.add(kit.brick((0.36, 0.3, 0.06), center=(0, -0.55, 1.24)), white, "Head", bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.slope((0.14, 0.26, 0.2), center=(s * 0.27, -0.6, 0.97), facing=P.side(s), top=0.2), snow, "Head",
                bevel=0.015)
        P.tuft_piece(kit, "Head", (s * 0.31, -0.62, 0.92), (s, -0.3, -0.45), 0.08, 0.06, white)
        kit.add(kit.box((0.1, 0.02, 0.025), center=(s * 0.15, -0.745, 0.99), rot=(0, s * -20, 0)), red, "Head", bevel=0.0)
        kit.add(kit.box((0.08, 0.02, 0.025), center=(s * 0.16, -0.745, 0.95), rot=(0, s * -20, 0)), red, "Head", bevel=0.0)
        P.ear(kit, "Head", s, (s * 0.15, -0.5, 1.21), w=0.21, h=0.34, color=white, inner=pink, tilt=(-6, 8), tip=red)
    kit.add(kit.brick((0.26, 0.26, 0.12), center=(0, -0.86, 0.97)), white, "Head", bevel=0.02)
    kit.add(kit.slope((0.26, 0.26, 0.1), center=(0, -0.86, 1.08), facing="-Y", top=0.25), white, "Head", bevel=0.012)
    kit.add(kit.wedge((0.1, 0.02, 0.12), center=(0, -0.745, 1.17), rot=(0, 180, 0), tip=0.1), red, "Head", bevel=0.0)
    P.nose(kit, "Head", y=-0.99, z=1.03, w=0.08, color="#1A1210")
    P.mouth(kit, "Head", y=-0.99, z=0.94, w=0.14, smile=0.45)
    P.eyes(kit, "Head", x=0.12, y=-0.74, z=1.09, size=0.11, iris="#FFB21E", pupil="slit", lid=red, lid_drop=0.08,
           tall=0.75)

    # --- pattes à chaussettes rouges ---
    P.quad_legs(kit, white, yf=-0.3, yb=0.38, top_f=0.64, top_b=0.68, length_f=0.62, length_b=0.66, w=0.12,
                paw=red, toe=red, claw=snow, x=0.15, toes=3)

    # --- trois grosses queues en éventail, bouts rouges coiffés d'une flamme ---
    for i, dx, phase in ((0, 0.0, 0.0), (1, 0.34, 1.6), (2, -0.34, 3.2)):
        part = f"Tail{i}"
        h = 1.0 if i == 0 else 0.86
        pts = [(dx * 0.1, 0.5, 0.68), (dx * 0.4, 0.68, 0.76 * h + 0.04), (dx * 0.75, 0.84, 0.92 * h + 0.06),
               (dx, 0.96, 1.12 * h + 0.06), (dx * 1.1, 1.0, 1.3 * h + 0.06)]
        P.bushy_tail(kit, part, pts, 0.2, white, tip=red)
        kit.add(kit.wedge((0.16, 0.14, 0.2), center=(dx * 1.1, 1.0, 1.3 * h + 0.14), tip=0.1), flame, part, bevel=0.0)
        kit.add(kit.wedge((0.08, 0.08, 0.12), center=(dx * 1.1, 1.0, 1.3 * h + 0.12), tip=0.1), gold, part, bevel=0.0)
        kit.part(part, "Tail", pivot=pts[0], phase=phase)
    kit.part("Head", "Head", pivot=(0, -0.42, 0.88))
    return kit.result()
