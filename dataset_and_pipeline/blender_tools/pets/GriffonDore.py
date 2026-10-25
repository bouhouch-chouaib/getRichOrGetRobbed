"""Griffon Doré (Divin, Divin) : « Gardien du paradis aux plumes d'or pur. »

En briques LEGO, très détaillé (Divin : or blanc, or et cristal, aucune lueur) : griffon majestueux, tête d'aigle en
OR BLANC aux plumes en écailles, bec doré crochu, yeux bleu ciel perçants, collerette de plumes en OR, corps de lion en
or blanc à pattes avant de serres dorées et pattes arrière de lion, grandes ailes déployées en trois rangs (or blanc,
or, pointes de cristal bleu ciel), queue de lion à houppe de cristal ; plastron à gemme bleue.
Parties animées : tête, ailes, 4 pattes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    whitegold = kit.chrome("or_blanc", tint="#F6F0E0", rough=0.16)
    gold = kit.gold("or", hammered=0.35)
    feather = kit.enamel("plumes", "#FFF4DC")
    beak = kit.gold("bec", tint="#FFB43A", hammered=0.0, rough=0.2)
    sky = kit.gem("cristal_ciel", "#1E5A9A", "#7AC8FF", "#F0FAFF")

    P.quad_torso(kit, L=0.92, W=0.46, H=0.32, z=0.6, y0=0.06, main=whitegold, belly=feather, chest=feather, back=whitegold)
    for k in range(5):
        x = (k - 2) * 0.1
        P.tuft_piece(kit, "Body", (x, -0.38, 0.76 - abs(x) * 0.3), (x * 1.5, -0.7, -0.6), 0.16, 0.12, gold)
    kit.add(kit.brick((0.12, 0.04, 0.12), center=(0, -0.48, 0.66), rot=(0, 45, 0)), sky, bevel=0.012)

    # --- tête d'aigle en or blanc, bec doré, yeux bleus ---
    kit.add(kit.brick((0.4, 0.42, 0.36), center=(0, -0.54, 1.0)), feather, "Head", bevel=0.045)
    for k in range(3):
        kit.add(kit.brick((0.42, 0.1, 0.06), center=(0, -0.42 + k * 0.1, 1.2 - k * 0.03)), whitegold, "Head", bevel=0.015)
    kit.add(kit.brick((0.18, 0.18, 0.12), center=(0, -0.82, 0.96)), beak, "Head", bevel=0.025)
    kit.add(kit.slope((0.16, 0.1, 0.1), center=(0, -0.94, 0.92), facing="-Y", top=0.3, rot=(180, 0, 0)), beak, "Head",
            bevel=0.012)
    P.eyes(kit, "Head", x=0.12, y=-0.755, z=1.06, size=0.1, iris="#3AA8FF", pupil="round", lid=feather, lid_drop=0.1,
           brow=gold, brow_angle=18, tall=0.85)
    for k in range(3):
        P.tuft_piece(kit, "Head", ((k - 1) * 0.08, -0.4, 1.2), ((k - 1) * 0.4, 0.8, 0.6), 0.2, 0.08, gold)
    kit.part("Head", "Head", pivot=(0, -0.4, 0.82))

    # --- grandes ailes déployées ---
    P.spread_wings(kit, x=0.24, y=0.0, z=0.78, span=0.8, height=0.46, mats=(whitegold, gold, sky), style="feather",
                   sweep=25, lift=28)

    # --- serres dorées devant, pattes de lion derrière ---
    for s, part in ((1, "LegFL"), (-1, "LegFR")):
        x = s * 0.16
        kit.add(kit.brick((0.14, 0.16, 0.22), center=(x, -0.3, 0.46)), feather, part, bevel=0.03)
        kit.add(kit.brick((0.09, 0.09, 0.34), center=(x, -0.3, 0.2)), gold, part, bevel=0.012)
        for k, yaw in enumerate((18, 0, -18)):
            dx = (k - 1) * 0.045
            kit.add(kit.brick((0.04, 0.12, 0.04), center=(x + dx, -0.38, 0.02), rot=(0, 0, yaw)), gold, part, bevel=0.006)
        kit.part(part, "Leg", pivot=(x, -0.3, 0.56), phase=0.0 if s > 0 else math.pi)
    for s, part in ((1, "LegBL"), (-1, "LegBR")):
        P.quad_leg(kit, part, s, 0.38, 0.62, 0.58, 0.13, whitegold, paw=feather, toe=feather, hind=True,
                   phase=math.pi if s > 0 else 0.0, toes=3, x=0.16)

    # --- queue de lion à houppe de cristal ---
    P.chain(kit, "Tail", [(0, 0.5, 0.66), (0, 0.68, 0.7), (0, 0.82, 0.84), (0, 0.88, 0.98)], 0.07, [whitegold, gold])
    kit.add(kit.brick((0.14, 0.14, 0.16), center=(0, 0.9, 1.06), rot=(20, 30, 45)), sky, "Tail", bevel=0.02)
    kit.part("Tail", "Tail", pivot=(0, 0.48, 0.66))
    return kit.result()
