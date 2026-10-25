"""Gardien du Trou Noir (Sigma, Divin) : « Le dragon qui veille sur le trou noir depuis le début des temps. »

En briques LEGO, très détaillé (Sigma : or massif et cristal, aucune lueur) : grand dragon bleu nuit presque noir
(ventre violet profond), armure en plaques d'OR MASSIF martelé sur le crâne, le dos et les épaules, cornes d'or
recourbées, yeux de cristal violet, grandes ailes déployées à membrane violette et doigts d'or ; entre ses pattes
avant il garde un petit TROU NOIR (sphère d'encre) entouré d'un anneau d'or et de cristal qui TOURNE ; longue
queue à pointe de cristal. Il vole. Parties animées : tête, ailes, 4 pattes, queue, anneau du trou noir.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    night = kit.enamel("bleu_nuit", "#141A3A")
    deep = kit.enamel("noir_bleu", "#0A0E22")
    belly = kit.enamel("ventre", "#3A1A6A")
    gold = kit.gold("or_massif", hammered=0.45)
    crystal = kit.gem("cristal_violet", "#2A0A5A", "#A06AFF", "#F0E0FF")
    ink = kit.enamel("encre", "#06040C")
    teeth = kit.mat("crocs", "#F4F0FF", rough=0.12)

    # --- corps, armure d'or ---
    P.quad_torso(kit, L=0.96, W=0.5, H=0.34, z=0.7, y0=0.06, main=night, belly=belly, chest=belly, back=deep)
    for k in range(4):
        kit.add(kit.brick((0.4 - k * 0.04, 0.18, 0.05), center=(0, -0.18 + k * 0.18, 0.89 - k * 0.01)), gold, bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.brick((0.14, 0.26, 0.2), center=(s * 0.27, -0.24, 0.82)), gold, bevel=0.03)
    kit.add(kit.brick((0.3, 0.3, 0.34), center=(0, -0.46, 0.94), rot=(30, 0, 0)), night, bevel=0.03)

    # --- tête cornue, yeux de cristal ---
    kit.add(kit.brick((0.42, 0.42, 0.32), center=(0, -0.66, 1.14)), night, "Head", bevel=0.035)
    kit.add(kit.brick((0.3, 0.3, 0.16), center=(0, -0.96, 1.06)), night, "Head", bevel=0.025)
    kit.add(kit.brick((0.4, 0.3, 0.06), center=(0, -0.62, 1.32)), gold, "Head", bevel=0.015)
    kit.add(kit.slope((0.3, 0.26, 0.1), center=(0, -0.94, 1.18), facing="-Y", top=0.25), gold, "Head", bevel=0.012)
    for s in (-1, 1):
        P.horn(kit, "Head", (s * 0.15, -0.54, 1.32), (s * 0.4, 0.8, 0.6), 0.4, 0.09, [gold], segments=4, curl=-0.4)
        kit.add(kit.box((0.04, 0.03, 0.03), center=(s * 0.08, -1.115, 1.1)), crystal, "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.12, y=-0.87, z=1.2, size=0.1, iris="#A06AFF", pupil="slit", lid=night, lid_drop=0.1,
           brow=gold, brow_angle=18, tall=0.8)
    for k in range(4):
        kit.add(kit.wedge((0.04, 0.03, 0.06), center=((k - 1.5) * 0.07, -1.1, 0.97), rot=(180, 0, 0), tip=0.15), teeth,
                "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.5, 1.0))

    # --- grandes ailes déployées ---
    P.spread_wings(kit, x=0.26, y=0.0, z=0.92, span=0.86, height=0.54, mats=(gold, belly, crystal), style="bat",
                   sweep=25, lift=28)

    # --- pattes, le petit trou noir gardé entre les pattes avant ---
    P.quad_legs(kit, night, yf=-0.3, yb=0.4, top_f=0.72, top_b=0.76, length_f=0.68, length_b=0.72, w=0.14, paw=deep,
                toe=deep, claw=gold, x=0.18, toes=3)
    cz = 0.26
    for z, w in ((cz - 0.08, 0.14), (cz, 0.2), (cz + 0.08, 0.14)):
        kit.add(kit.brick((w, w, 0.08), center=(0, -0.58, z)), ink, bevel=0.03)
        kit.add(kit.brick((w * 0.7, w * 0.7, 0.092), center=(0, -0.58, z), rot=(0, 0, 45)), ink, bevel=0.03)
    for k in range(14):
        a = 2 * math.pi * k / 14
        kit.add(kit.brick((0.06, 0.03, 0.03), center=(math.cos(a) * 0.2, -0.58 + math.sin(a) * 0.2, cz),
                          rot=(0, 0, math.degrees(a) + 90)), gold if k % 2 else crystal, "Ring", bevel=0.004)
    kit.part("Ring", "Orbit", pivot=(0, -0.58, cz), rot=(18, 0, 0), phase=1.2)

    # --- longue queue à pointe de cristal ---
    P.chain(kit, "Tail", [(0, 0.5, 0.74), (0, 0.76, 0.66), (0.06, 1.0, 0.62), (0.02, 1.2, 0.68), (-0.04, 1.36, 0.8)], 0.18,
            [night, deep], taper=0.025)
    for k in range(3):
        kit.add(kit.brick((0.08, 0.1, 0.03), center=(0, 0.64 + k * 0.22, 0.75 - k * 0.03)), gold, "Tail", bevel=0.008)
    kit.add(kit.brick((0.1, 0.1, 0.22), center=(-0.05, 1.44, 0.9), rot=(-40, 0, 45)), crystal, "Tail", bevel=0.01)
    kit.part("Tail", "Tail", pivot=(0, 0.48, 0.74))
    return kit.result()
