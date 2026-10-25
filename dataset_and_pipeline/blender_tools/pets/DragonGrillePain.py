"""Dragon-Grille-Pain (Mythique, Hybrides) : « Dragon cubique en métal brossé qui crache des tartines. »

En briques LEGO, très détaillé : un grille-pain chromé tout cubique (bords arrondis, fentes noires sur le dessus,
manette rouge sur le côté, molette et voyant orange LUMINEUX devant) qui est le corps d'un petit dragon : tête de
dragon en métal à museau carré, cornes, yeux orange LUMINEUX, gueule à dents, petites ailes de chauve-souris à
membrane rouge, quatre pattes trapues, queue-cordon terminée par une prise. Deux TARTINES dorées sortent et
sautent des fentes. Parties animées : tête, mâchoire, ailes, 4 pattes, queue, tartines.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    chrome = kit.mat("chrome", "#D2D8E2", metal=0.9, rough=0.18)
    brushed = kit.mat("brosse", "#AAB2C0", metal=0.85, rough=0.32)
    dark = kit.mat("fentes", "#1A1C22")
    red = kit.mat("rouge", "#FF2A2A", rough=0.15)
    glow = kit.mat("voyant", "#FF8A1E", rough=0.1, glow=2.6)
    membrane = kit.mat("membrane", "#E0322A", rough=0.3)
    toast = kit.mat("tartine", "#F2B45A")
    crust = kit.mat("croute", "#A8621E")
    teeth = kit.mat("dents", "#FFFFFF", rough=0.15)
    cord = kit.mat("cordon", "#2A2A30")

    # --- grille-pain : corps chromé, fentes, manette, molette, voyant ---
    kit.add(kit.brick((0.62, 0.8, 0.5), center=(0, 0.04, 0.5)), chrome, bevel=0.08)
    kit.add(kit.brick((0.56, 0.74, 0.04), center=(0, 0.04, 0.76)), brushed, bevel=0.015)
    for x in (-0.13, 0.13):
        kit.add(kit.brick((0.1, 0.56, 0.03), center=(x, 0.04, 0.775)), dark, bevel=0.0)
    kit.add(kit.box((0.04, 0.06, 0.3), center=(0.315, 0.2, 0.52)), dark, bevel=0.0)
    kit.add(kit.brick((0.08, 0.1, 0.06), center=(0.35, 0.2, 0.6)), red, bevel=0.015)
    kit.add(kit.disc(0.06, 0.04, center=(-0.12, -0.375, 0.4), normal=(0, -1, 0), sides=12), dark, bevel=0.0)
    kit.add(kit.box((0.012, 0.02, 0.05), center=(-0.12, -0.4, 0.42)), chrome, bevel=0.0)
    kit.add(kit.brick((0.05, 0.03, 0.05), center=(0.12, -0.372, 0.4)), glow, bevel=0.01)
    for z in (0.3, 0.7):
        kit.add(kit.box((0.64, 0.82, 0.02), center=(0, 0.04, z)), brushed, bevel=0.0)

    # --- tartines qui sautent ---
    for k, x in enumerate((-0.13, 0.13)):
        part = f"Toast{k}"
        kit.add(kit.brick((0.07, 0.4, 0.3), center=(x, 0.04, 0.8)), toast, part, bevel=0.03)
        kit.add(kit.brick((0.075, 0.42, 0.04), center=(x, 0.04, 0.95)), crust, part, bevel=0.015)
        for y in (-0.19, 0.27):
            kit.add(kit.box((0.075, 0.03, 0.3), center=(x, y, 0.8)), crust, part, bevel=0.0)
        kit.part(part, "Toast", pivot=(x, 0.04, 0.7), phase=k * 2.0)

    # --- tête de dragon en métal ---
    kit.add(kit.brick((0.36, 0.3, 0.28), center=(0, -0.48, 0.66)), brushed, "Head", bevel=0.035)
    kit.add(kit.brick((0.28, 0.24, 0.12), center=(0, -0.7, 0.66)), chrome, "Head", bevel=0.025)
    kit.add(kit.slope((0.28, 0.22, 0.08), center=(0, -0.69, 0.76), facing="-Y", top=0.3), brushed, "Head", bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.02, 0.03), center=(s * 0.07, -0.82, 0.7)), dark, "Head", bevel=0.0)
        P.horn(kit, "Head", (s * 0.12, -0.42, 0.8), (s * 0.3, 0.8, 0.6), 0.22, 0.06, [red, dark], segments=2)
    P.eyes(kit, "Head", x=0.1, y=-0.63, z=0.74, size=0.09, iris="#FF8A1E", pupil="slit", lid=brushed, lid_drop=0.1,
           brow=dark, brow_angle=20, glow=2.4, tall=0.85)
    for k in range(4):
        kit.add(kit.wedge((0.04, 0.03, 0.05), center=((k - 1.5) * 0.06, -0.82, 0.6), rot=(180, 0, 0), tip=0.15), teeth,
                "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.34, 0.6))
    kit.add(kit.brick((0.26, 0.24, 0.06), center=(0, -0.68, 0.55)), brushed, "Jaw", bevel=0.015)
    kit.add(kit.brick((0.2, 0.18, 0.02), center=(0, -0.68, 0.585)), dark, "Jaw", bevel=0.0)
    kit.part("Jaw", "Jaw", pivot=(0, -0.56, 0.58), follows="Head")

    # --- petites ailes, pattes trapues, queue-cordon à prise ---
    P.spread_wings(kit, x=0.3, y=0.08, z=0.66, span=0.42, height=0.3, mats=(brushed, membrane, red), style="bat",
                   sweep=20, lift=30)
    for part, x, y, ph in (("LegFL", 0.2, -0.22, 0.0), ("LegFR", -0.2, -0.22, math.pi), ("LegBL", 0.2, 0.3, math.pi),
                           ("LegBR", -0.2, 0.3, 0.0)):
        kit.add(kit.brick((0.14, 0.16, 0.22), center=(x, y, 0.15)), brushed, part, bevel=0.03)
        kit.add(kit.brick((0.16, 0.2, 0.05), center=(x, y - 0.02, 0.025)), dark, part, bevel=0.012)
        kit.part(part, "Leg", pivot=(x, y, 0.26), phase=ph)
    P.chain(kit, "Tail", [(0, 0.44, 0.36), (0, 0.6, 0.3), (0.06, 0.74, 0.32), (0.08, 0.84, 0.42)], 0.05, [cord])
    kit.add(kit.brick((0.1, 0.08, 0.08), center=(0.08, 0.88, 0.48)), dark, "Tail", bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.box((0.02, 0.06, 0.02), center=(0.08 + s * 0.025, 0.94, 0.48)), chrome, "Tail", bevel=0.0)
    kit.part("Tail", "Tail", pivot=(0, 0.42, 0.36))
    return kit.result()
