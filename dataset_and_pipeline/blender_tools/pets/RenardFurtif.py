"""Renard Furtif (Rare, Animaux) : « Renard orange au bandana rouge. »

En briques LEGO, très détaillé (25 oct., 2e niveau) : renard roux vif à la silhouette réelle (poitrail bombé, reins,
croupe, cou incliné), gorge et poitrail crème, museau long et fin à truffe noire et sourire en coin, joues à touffes
blanches, yeux ambre en fente sous une paupière rusée et un sourcil, grandes oreilles à intérieur crème et pointe
noire, moustaches, pattes articulées à chaussettes noires et griffes, bandana rouge vif à pois blancs noué derrière
le cou, énorme queue touffue à bout blanc. Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    orange = kit.mat("roux", "#FF6A13")
    rust = kit.mat("roux_fonce", "#E04E06")
    cream = kit.mat("creme", "#FFF4E2")
    black = kit.mat("noir", "#24180F")
    red = kit.mat("bandana", "#F0182A")
    dots = kit.mat("pois", "#FFFFFF")
    claw = kit.mat("griffes", "#F3E3CC")

    # --- torse sculpté + dos plus foncé + cou incliné ---
    P.quad_torso(kit, L=0.96, W=0.42, H=0.3, z=0.6, y0=0.05, main=orange, belly=cream, chest=cream, back=rust)
    kit.add(kit.brick((0.3, 0.28, 0.34), center=(0, -0.42, 0.82), rot=(24, 0, 0)), orange, bevel=0.03)
    kit.add(kit.brick((0.2, 0.05, 0.3), center=(0, -0.55, 0.78), rot=(24, 0, 0)), cream, bevel=0.015)

    # --- tête : crâne, front, joues à touffes, museau fin, truffe, sourire, yeux rusés, oreilles, moustaches ---
    kit.add(kit.brick((0.46, 0.36, 0.3), center=(0, -0.56, 1.02)), orange, "Head", bevel=0.035)
    kit.add(kit.brick((0.38, 0.3, 0.06), center=(0, -0.55, 1.2)), orange, "Head", bevel=0.015)
    kit.add(kit.slope((0.38, 0.1, 0.06), center=(0, -0.74, 1.2), facing="-Y", top=0.3), orange, "Head", bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.slope((0.14, 0.26, 0.2), center=(s * 0.28, -0.6, 0.93), facing=P.side(s), top=0.2), cream, "Head",
                bevel=0.015)
        P.tuft_piece(kit, "Head", (s * 0.32, -0.62, 0.88), (s, -0.3, -0.45), 0.08, 0.06, cream)
        P.tuft_piece(kit, "Head", (s * 0.3, -0.66, 0.95), (s, -0.4, -0.2), 0.06, 0.05, cream)
    kit.add(kit.brick((0.26, 0.26, 0.12), center=(0, -0.86, 0.93)), cream, "Head", bevel=0.02)
    kit.add(kit.slope((0.26, 0.26, 0.1), center=(0, -0.86, 1.04), facing="-Y", top=0.25), orange, "Head", bevel=0.012)
    kit.add(kit.brick((0.18, 0.12, 0.06), center=(0, -0.8, 0.85)), cream, "Head", bevel=0.01)
    P.nose(kit, "Head", y=-0.99, z=0.99, w=0.09, color="#1A1210")
    P.mouth(kit, "Head", y=-0.99, z=0.9, w=0.16, smile=0.5)
    P.eyes(kit, "Head", x=0.12, y=-0.74, z=1.06, size=0.11, iris="#FFB61E", pupil="slit", lid=orange, lid_drop=0.1,
           brow=rust, brow_angle=12, tall=0.8)
    P.whiskers(kit, "Head", x=0.1, y=-0.93, z=0.95, color="#3A2A22", n=2, length=0.12)
    for s in (-1, 1):
        P.ear(kit, "Head", s, (s * 0.15, -0.5, 1.17), w=0.21, h=0.32, color=orange, inner=cream, tilt=(-6, 8), tip=black)

    # --- bandana rouge à pois, noué derrière ---
    kit.add(kit.brick((0.4, 0.32, 0.07), center=(0, -0.42, 0.68), rot=(24, 0, 0)), red, bevel=0.015)
    kit.add(kit.slope((0.28, 0.06, 0.22), center=(0, -0.6, 0.57), facing="-Y", top=0.25, rot=(180, 0, 0)), red,
            bevel=0.01)
    kit.add(kit.brick((0.1, 0.08, 0.08), center=(0, -0.26, 0.8)), red, bevel=0.012)
    for dx in (-0.06, 0.06):
        P.tuft_piece(kit, "Body", (dx, -0.22, 0.8), (dx * 4, 1.0, -0.5), 0.12, 0.07, red)
    for dx, dz in ((-0.07, 0.6), (0.06, 0.57), (0.0, 0.51), (-0.13, 0.68), (0.12, 0.68)):
        kit.add(kit.brick((0.03, 0.01, 0.03), center=(dx, -0.625 if dz < 0.65 else -0.585, dz)), dots, bevel=0.0)

    # --- pattes articulées à chaussettes noires et griffes ---
    P.quad_legs(kit, orange, yf=-0.3, yb=0.38, top_f=0.62, top_b=0.66, length_f=0.6, length_b=0.64, w=0.12,
                paw=black, toe=black, claw=claw, x=0.15, toes=3, lower=black)

    # --- énorme queue touffue à bout blanc ---
    P.bushy_tail(kit, "Tail", [(0, 0.52, 0.68), (0, 0.72, 0.7), (0, 0.92, 0.78), (0, 1.07, 0.94), (0, 1.13, 1.12),
                               (0, 1.12, 1.28)], 0.22, orange, tip=cream)
    kit.part("Tail", "Tail", pivot=(0, 0.5, 0.68))
    kit.part("Head", "Head", pivot=(0, -0.42, 0.86))
    return kit.result()
