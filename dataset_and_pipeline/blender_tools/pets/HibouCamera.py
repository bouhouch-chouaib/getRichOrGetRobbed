"""Hibou-Caméra (Épique, Hybrides) : « Hibou mécanique blanc aux yeux-objectifs. »

En briques LEGO, très détaillé : hibou robot en plastique blanc brillant, joints et rainures gris, deux GROS
OBJECTIFS d'appareil photo à la place des yeux (fûts noirs, bagues grises qui TOURNENT, verre bleu à reflets), flash
lumineux sur le front, voyant rouge d'enregistrement, aigrettes en antennes, ventre à grille d'aération, ailes à
panneaux, queue en lamelles, serres métalliques. Parties animées : tête (tourne à 180° comme un hibou), ailes, queue,
bagues des objectifs.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("plastique", "#F6F8FC", rough=0.15)
    grey = kit.mat("joints", "#9AA2B4", rough=0.2)
    dark = kit.mat("gris_fonce", "#4A5060", metal=0.5, rough=0.3)
    black = kit.mat("objectif", "#16181E", rough=0.2)
    glass = kit.mat("verre", "#3A8AFF", rough=0.03, glow=0.6)
    shine = kit.mat("reflet", "#FFFFFF", rough=0.03)
    flash = kit.mat("flash", "#F4FBFF", rough=0.05, glow=2.4)
    rec = kit.mat("voyant", "#FF2A2A", rough=0.1, glow=2.6)

    # --- corps blanc, rainures, grille du ventre ---
    kit.add(kit.brick((0.58, 0.5, 0.28), center=(0, 0.04, 0.3)), white, bevel=0.035)
    kit.add(kit.brick((0.66, 0.56, 0.3), center=(0, 0.04, 0.56)), white, bevel=0.04)
    for z in (0.43, 0.7):
        kit.add(kit.box((0.68, 0.58, 0.02), center=(0, 0.04, z)), grey, bevel=0.0)
    kit.add(kit.brick((0.36, 0.04, 0.34), center=(0, -0.24, 0.44)), grey, bevel=0.012)
    for k in range(5):
        kit.add(kit.box((0.3, 0.02, 0.025), center=(0, -0.265, 0.32 + k * 0.06)), dark, bevel=0.0)

    # --- tête : deux objectifs, flash, voyant, aigrettes-antennes ---
    kit.add(kit.brick((0.74, 0.56, 0.48), center=(0, 0.0, 0.96)), white, "Head", bevel=0.045)
    kit.add(kit.box((0.76, 0.58, 0.02), center=(0, 0.0, 1.1)), grey, "Head", bevel=0.0)
    for s in (-1, 1):
        x = s * 0.17
        kit.add(kit.brick((0.26, 0.12, 0.26), center=(x, -0.31, 0.95)), black, "Head", bevel=0.03)
        kit.add(kit.brick((0.2, 0.06, 0.2), center=(x, -0.39, 0.95)), black, "Head", bevel=0.02)
        kit.add(kit.disc(0.075, 0.03, center=(x, -0.425, 0.95), normal=(0, -1, 0), sides=12), glass, "Head", bevel=0.0)
        kit.add(kit.box((0.03, 0.01, 0.03), center=(x - 0.03, -0.443, 0.98)), shine, "Head", bevel=0.0)
        kit.add(kit.box((0.015, 0.01, 0.015), center=(x + 0.03, -0.443, 0.92)), shine, "Head", bevel=0.0)
        P.tuft_piece(kit, "Head", (s * 0.28, 0.0, 1.2), (s * 0.4, 0.1, 1.0), 0.18, 0.06, grey)
        kit.add(kit.brick((0.04, 0.04, 0.04), center=(s * 0.33, 0.01, 1.37)), rec if s > 0 else flash, "Head",
                bevel=0.008)
    kit.add(kit.brick((0.16, 0.04, 0.06), center=(0, -0.29, 1.14)), flash, "Head", bevel=0.01)
    kit.add(kit.box((0.04, 0.02, 0.04), center=(0.28, -0.29, 1.1)), rec, "Head", bevel=0.0)
    kit.add(kit.wedge((0.08, 0.06, 0.08), center=(0, -0.34, 0.78), rot=(180, 0, 0), tip=0.2), dark, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, 0.0, 0.72))

    # --- bagues des objectifs qui tournent (mise au point) ---
    for s in (-1, 1):
        part = f"Lens{0 if s > 0 else 1}"
        P.gear(kit, part, (s * 0.17, -0.35, 0.95), 0.13, 0.03, 12, grey, normal=(0, -1, 0))
        kit.part(part, "Orbit", pivot=(s * 0.17, -0.35, 0.95), rot=(90, 0, 0), phase=0.5 * s)

    # --- ailes à panneaux, queue en lamelles, serres ---
    P.bird_wings(kit, x=0.36, y=0.04, z=0.48, length=0.52, height=0.46, cov=white, sec=grey, prim=white, bar=dark,
                 thick=0.1)
    P.tail_fan(kit, "Tail", (0, 0.26, 0.26), n=4, length=0.24, width=0.1, mats=[white, grey], spread=14, pitch=-38)
    P.bird_feet(kit, x=0.14, y=-0.1, h=0.16, w=0.075, color=dark, claw=grey)
    return kit.result()
