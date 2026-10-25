"""Bébé Griffon (Inhabituel, Fantastiques) : « Mi-aigle, mi-lionceau, tout duveteux. »

En briques LEGO, très détaillé : l'avant est un aiglon (tête crème duveteuse avec touffes sur le crâne, bec jaune
orangé crochu, grands yeux ambre de bébé, collerette de plumes dorées, pattes avant à serres jaunes), l'arrière un
lionceau (corps sable doré, pattes à coussinets, queue de lion à houppe), petites ailes duveteuses repliées sur le
dos. Parties animées : tête, ailes, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    sand = kit.mat("sable", "#F2B85A")
    deep = kit.mat("sable_fonce", "#D8902E")
    cream = kit.mat("creme", "#FFF4D6")
    gold = kit.mat("plumes_or", "#FFD06A")
    beak = kit.mat("bec", "#FFAA1E")
    talon = kit.mat("serres", "#FFC83A")
    claw = kit.mat("griffes", "#5A4030")

    # --- corps de lionceau, collerette de plumes ---
    P.quad_torso(kit, L=0.84, W=0.46, H=0.3, z=0.52, y0=0.06, main=sand, belly=cream, chest=cream, back=deep)
    for k in range(5):
        x = (k - 2) * 0.1
        P.tuft_piece(kit, "Body", (x, -0.36, 0.66 - abs(x) * 0.3), (x * 1.5, -0.7, -0.6), 0.14, 0.11, gold)
    kit.add(kit.brick((0.34, 0.26, 0.28), center=(0, -0.38, 0.74), rot=(16, 0, 0)), cream, bevel=0.035)

    # --- tête d'aiglon duveteuse ---
    kit.add(kit.brick((0.5, 0.44, 0.42), center=(0, -0.5, 0.98)), cream, "Head", bevel=0.05)
    for k, (x, h) in enumerate(((-0.08, 0.12), (0.0, 0.16), (0.08, 0.12))):
        P.tuft_piece(kit, "Head", (x, -0.48, 1.18), (x * 2, 0.2, 1.0), h, 0.08, gold)
    for s in (-1, 1):
        P.tuft_piece(kit, "Head", (s * 0.26, -0.5, 1.02), (s, 0.2, 0.3), 0.12, 0.09, cream)
    kit.add(kit.brick((0.18, 0.16, 0.12), center=(0, -0.78, 0.94)), beak, "Head", bevel=0.025)
    kit.add(kit.slope((0.16, 0.1, 0.1), center=(0, -0.9, 0.92), facing="-Y", top=0.3, rot=(180, 0, 0)), beak, "Head",
            bevel=0.012)
    P.eyes(kit, "Head", x=0.12, y=-0.72, z=1.04, size=0.13, iris="#FFA41A", pupil="round", tall=1.05)

    # --- petites ailes duveteuses repliées ---
    P.bird_wings(kit, x=0.27, y=0.02, z=0.78, length=0.52, height=0.34, cov=cream, sec=gold, prim=deep, thick=0.08)

    # --- pattes : serres d'aigle devant, pattes de lion derrière ---
    for s, part in ((1, "LegFL"), (-1, "LegFR")):
        x = s * 0.15
        kit.add(kit.brick((0.14, 0.16, 0.2), center=(x, -0.28, 0.42)), cream, part, bevel=0.03)
        kit.add(kit.brick((0.09, 0.09, 0.3), center=(x, -0.28, 0.2)), talon, part, bevel=0.012)
        for k, yaw in enumerate((18, 0, -18)):
            dx = (k - 1) * 0.045
            kit.add(kit.brick((0.04, 0.12, 0.04), center=(x + dx, -0.36, 0.02), rot=(0, 0, yaw)), talon, part, bevel=0.006)
            kit.add(kit.wedge((0.03, 0.03, 0.04), center=(x + dx * 1.4, -0.43, 0.02), rot=(90, 0, 0), tip=0.2), claw,
                    part, bevel=0.0)
        kit.part(part, "Leg", pivot=(x, -0.28, 0.52), phase=0.0 if s > 0 else 3.14159)
    for s, part in ((1, "LegBL"), (-1, "LegBR")):
        P.quad_leg(kit, part, s, 0.34, 0.56, 0.52, 0.12, sand, paw=cream, toe=cream, hind=True,
                   phase=3.14159 if s > 0 else 0.0, toes=3, x=0.15)

    # --- queue de lion à houppe ---
    P.chain(kit, "Tail", [(0, 0.46, 0.62), (0, 0.64, 0.66), (0, 0.78, 0.78), (0, 0.84, 0.92)], 0.07, [sand])
    kit.add(kit.brick((0.13, 0.13, 0.14), center=(0, 0.85, 0.99)), deep, "Tail", bevel=0.035)
    kit.part("Tail", "Tail", pivot=(0, 0.44, 0.62))
    kit.part("Head", "Head", pivot=(0, -0.38, 0.8))
    return kit.result()
