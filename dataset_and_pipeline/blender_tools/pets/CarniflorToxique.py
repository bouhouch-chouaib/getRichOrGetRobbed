"""Carniflore Toxique (Divin, Plantes) : « Plante carnivore néon violet et vert acide. »

En briques LEGO, très détaillée : pot violet sombre cerclé de vert acide, terre noire, quatre grandes feuilles
dentelées qui débordent ; long cou vert annelé ; tête de dionée VIOLET néon : mâchoire du haut tachetée de vert acide,
gros yeux méchants vert acide LUMINEUX, rangées de dents vert acide, intérieur de la gueule qui luit, mâchoire du bas
qui claque, gouttes de bave toxique. Parties animées : tête, mâchoire (elle claque), quatre feuilles.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    violet = kit.mat("violet", "#A42EFF", rough=0.15, glow=0.5)
    vdark = kit.mat("violet_fonce", "#6A12C8", rough=0.15)
    acid = kit.mat("vert_acide", "#9EFF2A", rough=0.15, glow=1.8)
    inside = kit.mat("gorge", "#C8FF5A", rough=0.15, glow=2.4)
    stem = kit.mat("tige", "#3EA82A")
    ring = kit.mat("anneaux", "#2A7A1E")
    leaf = kit.mat("feuille", "#3EB42E")
    vein = kit.mat("nervure", "#9EFF2A")
    potm = kit.mat("pot", "#3E2A5A")
    rim = kit.mat("rebord", "#523A72")
    soil = kit.mat("terre", "#1A100A")

    # --- pot, feuilles dentelées ---
    top = P.pot(kit, "Body", 0.0, 0.5, 0.32, potm, rim=rim, band=acid, soil=soil)
    for k in range(4):
        a = math.radians(-45 + 90 * k)
        d = (math.cos(a), math.sin(a), 0.5)
        part = f"Leaf{k}"
        P.leaf(kit, part, (d[0] * 0.12, d[1] * 0.12, top), d, 0.4, 0.18, leaf, vein, normal=(0, 0, 1), droop=0.55)
        for j in range(3):
            f = 0.35 + 0.18 * j
            P.tuft_piece(kit, part, (d[0] * (0.12 + 0.4 * f), d[1] * (0.12 + 0.4 * f), top + 0.14 * f),
                         (-d[1], d[0], 0.2), 0.06, 0.03, acid)
        kit.part(part, "Leaf", pivot=(d[0] * 0.12, d[1] * 0.12, top), phase=k * 1.4)

    # --- long cou annelé ---
    P.chain(kit, "Body", [(0, 0, top), (0.03, 0.04, top + 0.22), (0, 0.0, top + 0.42), (0, -0.08, top + 0.54)], 0.12,
            [stem, ring])

    # --- tête de dionée : mâchoire du haut, yeux, taches, dents ---
    hz = top + 0.66
    kit.add(kit.brick((0.5, 0.46, 0.16), center=(0, -0.3, hz + 0.08)), violet, "Head", bevel=0.05)
    kit.add(kit.slope((0.44, 0.38, 0.1), center=(0, -0.3, hz + 0.21), facing="-Y", top=0.4), violet, "Head", bevel=0.02)
    kit.add(kit.brick((0.44, 0.4, 0.03), center=(0, -0.3, hz - 0.005)), inside, "Head", bevel=0.0)
    for x, y in ((0.16, -0.18), (-0.14, -0.22), (0.02, -0.12), (-0.18, -0.4), (0.18, -0.42)):
        kit.add(kit.tile(0.06, 0.06, center=(x, y, hz + 0.165), thick=0.02), acid, "Head", bevel=0.0)
    for k in range(6):
        x = (k - 2.5) * 0.08
        kit.add(kit.wedge((0.04, 0.03, 0.08), center=(x, -0.52, hz - 0.03), rot=(180, 0, 0), tip=0.1), acid, "Head",
                bevel=0.0)
    for s in (-1, 1):
        for k in range(3):
            kit.add(kit.wedge((0.03, 0.04, 0.07), center=(s * 0.245, -0.44 + k * 0.1, hz - 0.03), rot=(180, 0, 0), tip=0.1),
                    acid, "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.12, y=-0.53, z=hz + 0.12, size=0.1, iris="#9EFF2A", pupil="slit", lid=vdark, lid_drop=0.12,
           brow=vdark, brow_angle=26, glow=2.4, tall=0.85)
    kit.part("Head", "Head", pivot=(0, -0.08, hz - 0.08))

    # --- mâchoire du bas qui claque, bave toxique ---
    kit.add(kit.brick((0.48, 0.44, 0.12), center=(0, -0.29, hz - 0.12)), violet, "Jaw", bevel=0.04)
    kit.add(kit.brick((0.42, 0.38, 0.03), center=(0, -0.3, hz - 0.055)), inside, "Jaw", bevel=0.0)
    for k in range(5):
        x = (k - 2) * 0.09
        kit.add(kit.wedge((0.04, 0.03, 0.07), center=(x, -0.5, hz - 0.03), tip=0.1), acid, "Jaw", bevel=0.0)
    for x, h in ((0.12, 0.1), (-0.08, 0.14)):
        kit.add(kit.brick((0.04, 0.04, h), center=(x, -0.5, hz - 0.18 - h / 2)), acid, "Jaw", bevel=0.01)
    kit.part("Jaw", "Jaw", pivot=(0, -0.08, hz - 0.08), follows="Head")
    return kit.result()
