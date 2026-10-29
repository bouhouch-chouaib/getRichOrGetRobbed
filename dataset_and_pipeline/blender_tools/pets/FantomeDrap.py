"""Fantôme en Drap (Épique, Halloween 2026) : « Un drap qui fait "bouh". Il a peur du noir. »

En briques LEGO, sans lueur (rareté Épique = chrome + cristal) : un drap blanc posé sur une petite tête, en étages qui
s'élargissent vers le bas, ombres gris-bleu entre les étages, ourlet ondulé (pans de longueurs différentes), deux grands
trous noirs pour les yeux avec un reflet, bouche ronde « bouh », joues roses. Deux pans de drap en guise de bras ; dans
la main droite, une petite lanterne en chrome avec un cristal (il a peur du noir). Il flotte (le jeu le fait léviter).
Parties animées : les deux bras (ils ondulent) et la lanterne.
"""

import math

from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("drap", "#F6F6FA", rough=0.5)
    shade = kit.mat("ombre", "#C8D0E4", rough=0.5)
    hole = kit.mat("trou", "#16141E", rough=0.2)
    shine = kit.mat("reflet", "#FFFFFF", rough=0.05)
    blush = kit.mat("joue", "#FFA8C4")
    chrome = kit.chrome("chrome")
    crystal = kit.gem("cristal", core="#FFF6C8", mid="#FFD25A", rim="#FF9E2A")

    # --- drap : sommet bien arrondi (étages droits + étages tournés de 45°), puis une jupe qui s'évase ---
    for w, h, z in ((0.24, 0.07, 1.25), (0.4, 0.09, 1.18), (0.52, 0.12, 1.08), (0.6, 0.18, 0.94), (0.64, 0.22, 0.75)):
        kit.add(kit.brick((w, w * 0.94, h), center=(0, 0, z)), white, bevel=min(0.05, h * 0.4))
        kit.add(kit.brick((w * 0.72, w * 0.68, h + 0.02), center=(0, 0, z), rot=(0, 0, 45)), white,
                bevel=min(0.05, h * 0.4))
    # jupe : pans qui s'écartent vers le bas, de longueurs différentes (ourlet ondulé), plis gris-bleu entre eux
    for k in range(16):
        a = math.radians(k * 22.5)
        length = (0.5, 0.42, 0.56, 0.38)[k % 4]
        r = 0.31
        kit.add(kit.brick((0.15, 0.1, length), center=(math.cos(a) * r, math.sin(a) * r, 0.66 - length / 2),
                          rot=(-14, 0, k * 22.5 + 90)), shade if k % 4 == 3 else white, bevel=0.035)

    # --- visage : grands trous noirs, reflets, bouche « bouh », joues ---
    for s in (-1, 1):
        kit.add(kit.box((0.15, 0.03, 0.22), center=(s * 0.12, -0.31, 0.96)), hole, bevel=0.02)
        kit.add(kit.box((0.05, 0.012, 0.05), center=(s * 0.12 - 0.03, -0.328, 1.02)), shine, bevel=0.0)
        kit.add(kit.box((0.1, 0.02, 0.05), center=(s * 0.21, -0.315, 0.8)), blush, bevel=0.008)
    kit.add(kit.box((0.1, 0.03, 0.12), center=(0, -0.33, 0.76)), hole, bevel=0.02)

    # --- bras (pans du drap) qui ondulent, lanterne dans la main droite (-X) ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.12, 0.16, 0.3), center=(s * 0.42, -0.04, 0.8), rot=(0, s * -30, 0)), white, part,
                bevel=0.04)
        for k, dy in enumerate((-0.07, 0.0, 0.07)):  # bout du pan qui retombe en franges
            kit.add(kit.brick((0.06, 0.05, 0.1 + 0.04 * (k % 2)), center=(s * 0.5, -0.04 + dy, 0.64)), white, part,
                    bevel=0.015)
        kit.part(part, "Leaf", pivot=(s * 0.33, -0.04, 0.92), phase=0.0 if s > 0 else math.pi)
    # lanterne : anse, toit, cage en chrome, cristal au centre (sans lueur)
    lx, ly, lz = -0.52, -0.06, 0.44
    kit.add(kit.box((0.02, 0.02, 0.12), center=(lx, ly, lz + 0.18)), chrome, "Lantern", bevel=0.004)
    kit.add(kit.brick((0.14, 0.14, 0.04), center=(lx, ly, lz + 0.11)), chrome, "Lantern", bevel=0.01)
    kit.add(kit.brick((0.14, 0.14, 0.03), center=(lx, ly, lz - 0.08)), chrome, "Lantern", bevel=0.01)
    for dx in (-0.055, 0.055):
        for dy in (-0.055, 0.055):
            kit.add(kit.box((0.02, 0.02, 0.17), center=(lx + dx, ly + dy, lz + 0.015)), chrome, "Lantern", bevel=0.004)
    kit.add(kit.brick((0.07, 0.07, 0.11), center=(lx, ly, lz + 0.015), rot=(0, 0, 45)), crystal, "Lantern",
            bevel=0.015)
    kit.part("Lantern", "Leaf", pivot=(lx, ly, lz + 0.24), phase=1.3)
    return kit.result()
