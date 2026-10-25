"""Renard Furtif (Rare, Animaux) : « Renard orange au bandana rouge. »

En briques LEGO : corps orange, poitrail et museau blancs, museau pointu en pente, truffe noire, yeux ambre rusés,
grandes oreilles en coins à pointe noire, pattes à chaussettes noires, bandana rouge noué au cou (triangle qui pend),
grosse queue touffue qui finit en pointe blanche. Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    orange = kit.mat("orange", "#F07828")
    white = kit.mat("blanc", "#F6F1E8")
    black = kit.mat("noir", "#2A211E")
    red = kit.mat("bandana", "#D62F2A")
    dots = kit.mat("pois", "#FFFFFF")

    # --- corps ---
    kit.add(kit.brick((0.44, 0.88, 0.26), center=(0, 0.04, 0.55)), orange, bevel=0.03)
    kit.add(kit.brick((0.4, 0.7, 0.08), center=(0, 0.0, 0.72)), orange, bevel=0.02)
    kit.add(kit.slope((0.4, 0.2, 0.08), center=(0, 0.45, 0.72), facing="+Y", top=0.3), orange, bevel=0.015)
    kit.add(kit.brick((0.32, 0.07, 0.28), center=(0, -0.42, 0.52)), white, bevel=0.02)

    # --- tête : museau pointu, oreilles à pointe noire ---
    kit.add(kit.brick((0.5, 0.4, 0.34), center=(0, -0.52, 0.94)), orange, "Head", bevel=0.03)
    kit.add(kit.brick((0.3, 0.26, 0.12), center=(0, -0.82, 0.83)), white, "Head", bevel=0.02)
    kit.add(kit.slope((0.3, 0.26, 0.12), center=(0, -0.82, 0.95), facing="-Y", top=0.25), orange, "Head",
            bevel=0.015)
    kit.add(kit.brick((0.09, 0.06, 0.07), center=(0, -0.97, 0.88)), black, "Head", bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.slope((0.12, 0.26, 0.16), center=(s * 0.29, -0.58, 0.84), facing="+X" if s > 0 else "-X",
                          top=0.2), white, "Head", bevel=0.012)
        kit.add(kit.wedge((0.2, 0.08, 0.3), center=(s * 0.17, -0.46, 1.25), rot=(-6, s * 6, 0), tip=0.12), orange,
                "Head", bevel=0.012)
        kit.add(kit.wedge((0.08, 0.085, 0.1), center=(s * (0.17 + 0.026), -0.46, 1.37), rot=(-6, s * 6, 0), tip=0.1),
                black, "Head", bevel=0.006)
        kit.add(kit.wedge((0.1, 0.02, 0.17), center=(s * 0.17, -0.505, 1.23), rot=(-6, s * 6, 0), tip=0.12), white,
                "Head", bevel=0.005)
    P.eyes(kit, "Head", 0.13, -0.72, 1.02, size=0.11, iris="#F2B230", pupil_w=0.35, pupil_h=0.8, tall=0.75)

    # --- bandana rouge à pois : bande au cou + triangle qui pend devant ---
    kit.add(kit.brick((0.48, 0.12, 0.08), center=(0, -0.36, 0.74)), red, bevel=0.015)
    kit.add(kit.slope((0.3, 0.06, 0.2), center=(0, -0.45, 0.62), facing="-Y", top=0.3, rot=(180, 0, 0)), red,
            bevel=0.01)
    for dx, dz in ((-0.07, 0.66), (0.06, 0.62), (0.0, 0.57)):
        kit.add(kit.brick((0.03, 0.01, 0.03), center=(dx, -0.47, dz)), dots, bevel=0.0)

    # --- pattes à chaussettes noires, grosse queue touffue à pointe blanche ---
    P.legs4(kit, orange, black, x=0.15, yf=-0.28, yb=0.34, h=0.33, w=0.13, paw_h=0.1, thigh=(0.17, 0.28, 0.2))
    P.chain(kit, "Tail", [(0, 0.5, 0.62), (0, 0.72, 0.66), (0, 0.9, 0.78), (0, 1.0, 0.96), (0, 1.02, 1.1)], 0.2,
            [orange, orange, orange, white], taper=-0.008)
    kit.part("Tail", "Tail", pivot=(0, 0.48, 0.62))
    kit.part("Head", "Head", pivot=(0, -0.4, 0.78))
    return kit.result()
