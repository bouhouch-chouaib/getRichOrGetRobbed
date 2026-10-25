"""Panthère Néon (Épique, Animaux) : « Panthère noire aux lignes magenta lumineuses. »

En briques LEGO : panthère noire élancée (briques basses et longues), lignes magenta LUMINEUSES le long des flancs,
sur le dos, le front et les pattes, yeux magenta lumineux en fente, oreilles courtes, longue queue noire à bout
magenta. Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.mat("noir", "#17161C", rough=0.18, accent="#241F33")
    neon = kit.mat("neon", "#FF28C8", rough=0.2, glow=3.0)
    nose = kit.mat("truffe", "#3A2A36")

    # --- corps long et bas, lignes néon sur les flancs et le dos ---
    kit.add(kit.brick((0.44, 1.0, 0.24), center=(0, 0.04, 0.56)), black, bevel=0.03)
    kit.add(kit.brick((0.38, 0.8, 0.08), center=(0, 0.0, 0.72)), black, bevel=0.02)
    kit.add(kit.slope((0.38, 0.22, 0.08), center=(0, 0.51, 0.72), facing="+Y", top=0.3), black, bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.box((0.025, 0.8, 0.035), center=(s * 0.225, 0.04, 0.6)), neon, bevel=0.006)
        kit.add(kit.box((0.025, 0.3, 0.035), center=(s * 0.225, 0.3, 0.5), rot=(20, 0, 0)), neon, bevel=0.006)
    kit.add(kit.tile(0.04, 0.7, center=(0, 0.02, 0.775)), neon, bevel=0.005)

    # --- tête : museau court, oreilles basses, yeux néon ---
    kit.add(kit.brick((0.46, 0.38, 0.3), center=(0, -0.58, 0.86)), black, "Head", bevel=0.03)
    kit.add(kit.brick((0.28, 0.16, 0.14), center=(0, -0.8, 0.8)), black, "Head", bevel=0.02)
    kit.add(kit.brick((0.08, 0.05, 0.05), center=(0, -0.89, 0.85)), nose, "Head", bevel=0.008)
    for s in (-1, 1):
        kit.add(kit.wedge((0.16, 0.08, 0.16), center=(s * 0.16, -0.5, 1.08), rot=(0, s * 10, 0), tip=0.15), black,
                "Head", bevel=0.01)
        kit.add(kit.box((0.025, 0.2, 0.03), center=(s * 0.235, -0.6, 0.86)), neon, "Head", bevel=0.005)
    kit.add(kit.tile(0.04, 0.24, center=(0, -0.58, 1.025)), neon, "Head", bevel=0.005)
    P.eyes(kit, "Head", 0.12, -0.77, 0.93, size=0.1, iris="#FF4FD8", pupil_w=0.25, pupil_h=0.85, glow=3.0,
           highlight=False, tall=0.7)

    # --- pattes à bracelets néon, longue queue à bout néon ---
    P.legs4(kit, black, black, x=0.15, yf=-0.32, yb=0.38, h=0.34, w=0.13, paw_h=0.08, thigh=(0.17, 0.3, 0.18))
    for leg, x, y in (("LegFL", 0.15, -0.32), ("LegFR", -0.15, -0.32), ("LegBL", 0.15, 0.38), ("LegBR", -0.15, 0.38)):
        kit.add(kit.box((0.15, 0.15, 0.03), center=(x, y, 0.16)), neon, leg, bevel=0.005)
    P.chain(kit, "Tail", [(0, 0.52, 0.66), (0, 0.76, 0.68), (0, 0.98, 0.76), (0, 1.14, 0.92), (0, 1.2, 1.1)], 0.1,
            [black, black, black, neon])
    kit.part("Tail", "Tail", pivot=(0, 0.5, 0.66))
    kit.part("Head", "Head", pivot=(0, -0.44, 0.74))
    return kit.result()
