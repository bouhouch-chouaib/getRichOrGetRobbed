"""Mandragore Hurlante (Légendaire, Plantes) : « Racine humanoïde aux cache-oreilles rouges. »

En briques LEGO, très détaillée : petit bonhomme-racine beige doré (corps en navet allongé cerclé de rides plus
foncées, radicelles), grosse tête d'où jaillissent cinq feuilles vertes, gros cache-oreilles rouges reliés par un
arceau, visage qui HURLE (yeux plissés en > <, sourcils froncés, bouche immense avec langue et mâchoire qui s'ouvre),
bras-racines aux doigts fourchus, jambes-racines. Parties animées : tête, mâchoire, bras, jambes.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    root = kit.mat("racine", "#E2AE6A")
    light = kit.mat("racine_claire", "#F6CC8E")
    dark = kit.mat("rides", "#B47A3A")
    red = kit.mat("cache_oreilles", "#FF1E32")
    red2 = kit.mat("cache_oreilles_fonce", "#C40E22")
    band = kit.mat("arceau", "#3A3A48")
    leaf = kit.mat("feuille", "#34CC22")
    leaf2 = kit.mat("feuille_claire", "#6AE23A")
    vein = kit.mat("nervure", "#C8FF8A")
    mouth = kit.mat("gorge", "#4A0A12")
    tongue = kit.mat("langue", "#FF5C8A")
    tooth = kit.mat("dent", "#FFFFFF", rough=0.15)

    # --- corps en racine ridée, radicelles ---
    kit.add(kit.brick((0.3, 0.26, 0.12), center=(0, 0, 0.24)), root, bevel=0.035)
    kit.add(kit.brick((0.4, 0.34, 0.3), center=(0, 0, 0.44)), root, bevel=0.06)
    for z in (0.34, 0.46, 0.56):
        kit.add(kit.box((0.42, 0.36, 0.02), center=(0, 0, z)), dark, bevel=0.0)
    for x, z, a in ((0.21, 0.4, 55), (-0.22, 0.33, -50), (0.12, 0.2, 30)):
        kit.add(kit.box((0.07, 0.014, 0.014), center=(x, -0.12, z), rot=(0, a, 0)), dark, bevel=0.0)

    # --- tête : feuilles, cache-oreilles et arceau, visage qui hurle ---
    kit.add(kit.brick((0.46, 0.4, 0.38), center=(0, -0.02, 0.8)), light, "Head", bevel=0.06)
    kit.add(kit.brick((0.38, 0.34, 0.06), center=(0, -0.02, 1.0)), root, "Head", bevel=0.02)
    for k, (dx, dy, length, mat) in enumerate(((0.0, 0.1, 0.36, leaf), (0.55, 0.2, 0.32, leaf2), (-0.55, 0.2, 0.32, leaf2),
                                               (0.3, -0.3, 0.26, leaf), (-0.3, -0.3, 0.26, leaf))):
        P.leaf(kit, "Head", (dx * 0.08, dy * 0.08, 1.02), (dx, dy, 1.0), length, 0.14, mat, vein, normal=(0, -1, 0.3),
               droop=0.25)
    P.chain(kit, "Head", [(0.27, 0.0, 0.86), (0.24, 0.0, 1.0), (0.12, 0.0, 1.08), (-0.12, 0.0, 1.08), (-0.24, 0.0, 1.0),
                          (-0.27, 0.0, 0.86)], 0.05, [band])
    for s in (-1, 1):
        kit.add(kit.brick((0.1, 0.22, 0.22), center=(s * 0.27, 0.0, 0.82)), red, "Head", bevel=0.05)
        kit.add(kit.brick((0.04, 0.16, 0.16), center=(s * 0.33, 0.0, 0.82)), red2, "Head", bevel=0.03)
        # yeux plissés en > <
        for k in (-1, 1):
            kit.add(kit.box((0.09, 0.02, 0.025), center=(s * 0.11, -0.225, 0.88 + k * 0.018), rot=(0, s * k * 28, 0)),
                    band, "Head", bevel=0.0)
        kit.add(kit.box((0.11, 0.03, 0.03), center=(s * 0.1, -0.226, 0.95), rot=(0, s * 22, 0)), dark, "Head", bevel=0.0)
    kit.add(kit.brick((0.24, 0.03, 0.12), center=(0, -0.222, 0.75)), mouth, "Head", bevel=0.02)
    for k in range(3):
        kit.add(kit.wedge((0.04, 0.02, 0.04), center=((k - 1) * 0.07, -0.235, 0.795), rot=(180, 0, 0), tip=0.15), tooth,
                "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, 0, 0.6))
    # mâchoire du bas : grande bouche qui s'ouvre en hurlant
    kit.add(kit.brick((0.3, 0.14, 0.07), center=(0, -0.17, 0.66)), light, "Jaw", bevel=0.02)
    kit.add(kit.brick((0.22, 0.1, 0.02), center=(0, -0.18, 0.7)), mouth, "Jaw", bevel=0.0)
    kit.add(kit.brick((0.12, 0.08, 0.025), center=(0, -0.19, 0.71)), tongue, "Jaw", bevel=0.006)
    kit.part("Jaw", "Jaw", pivot=(0, -0.1, 0.7), follows="Head")

    # --- bras-racines aux doigts fourchus, jambes-racines ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        P.chain(kit, part, [(s * 0.2, 0.0, 0.52), (s * 0.32, -0.04, 0.44), (s * 0.38, -0.08, 0.32)], 0.07, [root, light])
        for k in (-1, 0, 1):
            P.tuft_piece(kit, part, (s * 0.38, -0.08, 0.3), (s * 0.3 + k * 0.4, -0.3, -1.0), 0.07, 0.03, root)
        kit.part(part, "Arm", pivot=(s * 0.2, 0.0, 0.52), phase=0.0 if s > 0 else math.pi)
    for s, part in ((1, "LegL"), (-1, "LegR")):
        P.chain(kit, part, [(s * 0.09, 0.0, 0.22), (s * 0.11, 0.0, 0.1), (s * 0.12, -0.02, 0.04)], 0.08, [root])
        kit.add(kit.brick((0.09, 0.14, 0.04), center=(s * 0.12, -0.05, 0.02)), dark, part, bevel=0.012)
        kit.part(part, "Leg", pivot=(s * 0.09, 0.0, 0.24), phase=0.0 if s > 0 else math.pi)
    return kit.result()
