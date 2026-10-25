"""Aigle Royal (Légendaire, Animaux) : « Aigle brun couronné de plumes dorées. »

En briques LEGO : aigle fier, corps brun, tête blanche, bec jaune crochu (pente + coin vers le bas), regard sévère
(sourcils en pente), couronne de plumes dorées (coins dorés sur un bandeau d'or), grandes ailes repliées brunes à
pointes foncées, queue en plaques blanches, pattes jaunes à serres noires. Parties animées : tête, ailes, queue, pattes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    brown = kit.mat("brun", "#6E4623")
    dark = kit.mat("brun_fonce", "#46290F")
    white = kit.mat("blanc", "#F7F5EE")
    yellow = kit.mat("bec", "#F2B427")
    gold = kit.mat("or", "#FFC838", metal=0.7, rough=0.22, glow=0.4)
    claw = kit.mat("serres", "#1E1C1C")

    # --- corps fier (poitrail bombé en pente) ---
    kit.add(kit.brick((0.6, 0.62, 0.24), center=(0, 0.08, 0.42)), brown, bevel=0.03)
    kit.add(kit.brick((0.7, 0.82, 0.34), center=(0, 0.06, 0.7)), brown, bevel=0.04)
    kit.add(kit.slope((0.6, 0.18, 0.34), center=(0, -0.43, 0.7), facing="-Y", top=0.5, rot=(180, 0, 0)), brown,
            bevel=0.02)
    kit.add(kit.brick((0.58, 0.5, 0.14), center=(0, 0.0, 0.94)), brown, bevel=0.025)

    # --- tête blanche, bec crochu, sourcils, couronne dorée ---
    kit.add(kit.brick((0.46, 0.48, 0.4), center=(0, -0.16, 1.2)), white, "Head", bevel=0.035)
    kit.add(kit.brick((0.18, 0.22, 0.12), center=(0, -0.5, 1.16)), yellow, "Head", bevel=0.02)
    kit.add(kit.slope((0.18, 0.12, 0.1), center=(0, -0.66, 1.15), facing="-Y", top=0.3, rot=(180, 0, 0)), yellow,
            "Head", bevel=0.012)
    P.eyes(kit, "Head", 0.13, -0.4, 1.25, size=0.1, iris="#F2C230", pupil_w=0.45, pupil_h=0.55, tall=0.75)
    for s in (-1, 1):
        kit.add(kit.slope((0.18, 0.1, 0.07), center=(s * 0.13, -0.42, 1.33), facing="-Y", top=0.4,
                          rot=(0, s * -18, 0)), white, "Head", bevel=0.01)
    kit.add(kit.brick((0.42, 0.42, 0.06), center=(0, -0.14, 1.43)), gold, "Head", bevel=0.012)
    for x, y in ((-0.14, -0.3), (0.0, -0.32), (0.14, -0.3), (-0.17, -0.06), (0.17, -0.06), (0.0, 0.04)):
        kit.add(kit.wedge((0.1, 0.06, 0.16), center=(x, y, 1.53), tip=0.12), gold, "Head", bevel=0.006)

    # --- grandes ailes, queue blanche, pattes et serres ---
    P.bird_wings(kit, brown, x=0.4, y=0.1, z=0.72, length=0.68, height=0.42, thick=0.12, bars=[dark], tip=dark)
    for yaw in (-15, 0, 15):
        kit.add(kit.brick((0.18, 0.44, 0.06), center=(yaw * 0.007, 0.78, 0.52), rot=(-14, 0, yaw)), white, "Tail",
                bevel=0.015)
    kit.part("Tail", "Tail", pivot=(0, 0.54, 0.54))
    P.bird_legs(kit, yellow, x=0.16, y=0.0, h=0.22, w=0.12)
    for s in (-1, 1):
        for dx in (-0.065, 0.0, 0.065):
            kit.add(kit.wedge((0.04, 0.05, 0.06), center=(s * 0.16 + dx, -0.21, 0.03), rot=(90, 0, 0), tip=0.2), claw,
                    "LegL" if s > 0 else "LegR", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.12, 1.0))
    return kit.result()
