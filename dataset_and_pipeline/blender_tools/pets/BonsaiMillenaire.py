"""Bonsaï Millénaire (Épique, Plantes) : « Arbre miniature torsadé habité par un esprit bleu. »

En briques LEGO, très détaillé : pot rectangulaire bas en céramique bleue (pieds, rebord, motif de vagues blanches),
terre, mousse et cailloux ; tronc brun très torsadé et épais en bas, branches tordues, trois nuages de feuillage en
plateaux superposés (vert vif, foncé, clair) ; vieux visage sage sur le tronc (sourcils blancs broussailleux,
barbe de mousse) ; un petit esprit bleu LUMINEUX (cube aux grands yeux, traîne) qui flotte à côté.
Parties animées : les feuillages, l'esprit (il flotte autour).
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    blue = kit.mat("ceramique", "#2E6ADB", rough=0.12)
    navy = kit.mat("bleu_fonce", "#1A4AA8", rough=0.12)
    wave = kit.mat("vagues", "#E6F2FF")
    soil = kit.mat("terre", "#4A2C14")
    moss = kit.mat("mousse", "#5ED63A")
    pebble = kit.mat("caillou", "#C8CCD4")
    bark = kit.mat("ecorce", "#7A4620")
    bark2 = kit.mat("ecorce_fonce", "#56300F")
    g1 = kit.mat("feuillage", "#36C246")
    g2 = kit.mat("feuillage_fonce", "#20963A")
    g3 = kit.mat("feuillage_clair", "#7AE45A")
    brow = kit.mat("sourcils", "#F4F4F4")
    spirit = kit.mat("esprit", "#6ACBFF", rough=0.1, glow=2.2)
    spirit2 = kit.mat("esprit_clair", "#C8F0FF", rough=0.1, glow=2.6)

    # --- pot rectangulaire bleu à vagues, terre, mousse, cailloux ---
    for x in (-0.3, 0.3):
        for y in (-0.18, 0.18):
            kit.add(kit.brick((0.1, 0.08, 0.05), center=(x, y, 0.025)), navy, bevel=0.012)
    kit.add(kit.brick((0.84, 0.56, 0.16), center=(0, 0, 0.13)), blue, bevel=0.03)
    kit.add(kit.brick((0.9, 0.62, 0.05), center=(0, 0, 0.235)), navy, bevel=0.015)
    for k in range(5):
        kit.add(kit.box((0.08, 0.02, 0.025), center=(-0.28 + k * 0.14, -0.282, 0.12), rot=(0, 30 if k % 2 else -30, 0)),
                wave, bevel=0.0)
    kit.add(kit.brick((0.78, 0.5, 0.03), center=(0, 0, 0.26)), soil, bevel=0.008)
    for x, y, w in ((0.24, 0.1, 0.16), (-0.26, -0.08, 0.12), (0.08, -0.16, 0.1)):
        kit.add(kit.tile(w, w * 0.8, center=(x, y, 0.285), thick=0.025), moss, bevel=0.005)
    for x, y in ((0.32, -0.16), (-0.3, 0.16)):
        kit.add(kit.brick((0.06, 0.05, 0.04), center=(x, y, 0.29), rot=(0, 0, 35)), pebble, bevel=0.01)

    # --- tronc torsadé et branches ---
    kit.add(kit.brick((0.3, 0.26, 0.16), center=(0.0, 0.02, 0.35)), bark2, bevel=0.04)
    P.chain(kit, "Body", [(0.0, 0.02, 0.3), (-0.08, 0.0, 0.5), (0.06, 0.02, 0.66), (-0.04, 0.0, 0.8),
                          (0.06, 0.02, 0.92)], 0.22, [bark, bark2], taper=0.03)
    P.chain(kit, "Body", [(-0.04, 0.0, 0.8), (-0.24, 0.02, 0.86), (-0.42, 0.0, 0.92)], 0.1, [bark2, bark])
    P.chain(kit, "Body", [(0.06, 0.02, 0.66), (0.24, 0.0, 0.72), (0.42, 0.02, 0.78)], 0.1, [bark, bark2])
    # vieux visage sage
    P.eyes(kit, "Body", x=0.06, y=-0.11, z=0.54, size=0.07, iris="#3A2A1A", pupil="round", lid=bark, lid_drop=0.2,
           tall=0.9, at=-0.04)
    for s in (-1, 1):
        kit.add(kit.box((0.09, 0.04, 0.04), center=(-0.04 + s * 0.065, -0.12, 0.6), rot=(0, s * -15, 0)), brow,
                bevel=0.01)
    for k in range(3):
        P.tuft_piece(kit, "Body", (-0.04 + (k - 1) * 0.04, -0.12, 0.47), ((k - 1) * 0.3, -0.3, -1.0), 0.1, 0.04, moss)

    # --- trois nuages de feuillage en plateaux ---
    for cx, cy, cz, k in ((-0.44, 0.0, 0.98, 1.0), (0.44, 0.02, 0.84, 0.9), (0.06, 0.02, 1.02, 1.1)):
        kit.add(kit.brick((0.38 * k, 0.32 * k, 0.1), center=(cx, cy, cz)), g2, "Canopy", bevel=0.03)
        kit.add(kit.brick((0.32 * k, 0.28 * k, 0.09), center=(cx + 0.02, cy, cz + 0.08)), g1, "Canopy", bevel=0.03)
        kit.add(kit.brick((0.2 * k, 0.18 * k, 0.07), center=(cx - 0.02, cy - 0.02, cz + 0.15)), g3, "Canopy", bevel=0.02)
        for dx in (-0.16, 0.16):
            kit.add(kit.brick((0.08, 0.1, 0.06), center=(cx + dx * k, cy - 0.06, cz + 0.02)), g3, "Canopy", bevel=0.015)
    kit.part("Canopy", "Canopy", pivot=(0, 0, 0.9))

    # --- esprit bleu lumineux qui flotte ---
    kit.add(kit.brick((0.16, 0.16, 0.16), center=(0.3, -0.22, 0.56)), spirit, "Spirit", bevel=0.04)
    kit.add(kit.wedge((0.12, 0.1, 0.14), center=(0.32, -0.2, 0.42), rot=(180, 0, 20), tip=0.1), spirit, "Spirit",
            bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.02, 0.05), center=(0.3 + s * 0.035, -0.305, 0.57)), kit.mat("yeux_esprit", "#0A1A3A"),
                "Spirit", bevel=0.0)
        kit.add(kit.box((0.02, 0.01, 0.02), center=(0.3 + s * 0.035 - 0.008, -0.312, 0.585)), spirit2, "Spirit",
                bevel=0.0)
    kit.part("Spirit", "Companion", pivot=(0.3, -0.22, 0.56), phase=1.2)
    return kit.result()
