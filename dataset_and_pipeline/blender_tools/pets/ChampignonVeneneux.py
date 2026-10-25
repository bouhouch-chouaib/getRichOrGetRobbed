"""Champignon Vénéneux (Rare, Plantes) : « Amanite rouge à pois blancs. »

En briques LEGO, très détaillé : amanite tue-mouches : pied blanc sur un bulbe crème, anneau-jupette qui retombe,
lamelles beiges sous le chapeau, grand chapeau rouge vif en dôme de couches (bord plus foncé), pois blancs en tuiles
sur le dessus et les côtés ; visage malicieux sur le pied (œil mi-clos, sourcil levé, sourire en coin), touffes d'herbe
et un petit champignon bébé au pied. Partie animée : le chapeau (il ondule doucement).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("blanc", "#FFFFFF", rough=0.2)
    cream = kit.mat("creme", "#FFEED2")
    gills = kit.mat("lamelles", "#F2CFA4")
    red = kit.mat("rouge", "#FF1E2A", rough=0.15)
    dark = kit.mat("rouge_fonce", "#C40E1E", rough=0.15)
    grass = kit.mat("herbe", "#46D22E")

    # --- bulbe, pied, jupette ---
    kit.add(kit.brick((0.38, 0.38, 0.14), center=(0, 0, 0.07)), cream, bevel=0.04)
    kit.add(kit.brick((0.3, 0.3, 0.52), center=(0, 0, 0.39)), white, bevel=0.05)
    kit.add(kit.brick((0.42, 0.42, 0.05), center=(0, 0, 0.57)), white, bevel=0.015)
    for k in range(8):
        a = k * 45
        kit.add(kit.slope((0.12, 0.06, 0.08), center=(0.18 * math.cos(math.radians(a)),
                                                      0.18 * math.sin(math.radians(a)), 0.52),
                          facing="+X", top=0.3, rot=(0, 0, a)), white, bevel=0.008)
    # --- visage malicieux sur le pied ---
    P.eyes(kit, "Body", x=0.07, y=-0.15, z=0.38, size=0.1, iris="#7A1E2A", pupil="round", lid=cream, lid_drop=0.12,
           brow=kit.mat("sourcil", "#8A5A3A"), brow_angle=16, tall=1.05)
    P.mouth(kit, "Body", y=-0.151, z=0.25, w=0.12, smile=0.7)
    # --- herbe et bébé champignon ---
    for x, y in ((0.24, -0.16), (-0.26, -0.1), (0.16, 0.24)):
        for k in range(3):
            P.tuft_piece(kit, "Body", (x + (k - 1) * 0.025, y, 0.0), ((k - 1) * 0.4, 0.0, 1.0), 0.12, 0.035, grass)
    kit.add(kit.brick((0.06, 0.06, 0.1), center=(-0.28, -0.22, 0.05)), white, bevel=0.012)
    kit.add(kit.brick((0.14, 0.14, 0.06), center=(-0.28, -0.22, 0.12)), red, bevel=0.02)
    kit.add(kit.tile(0.03, 0.03, center=(-0.26, -0.24, 0.155)), white, bevel=0.0)

    # --- chapeau en dôme de couches, lamelles, pois ---
    kit.add(kit.brick((0.72, 0.72, 0.04), center=(0, 0, 0.70)), gills, "Cap", bevel=0.01)
    kit.add(kit.brick((0.9, 0.88, 0.1), center=(0, 0, 0.77)), dark, "Cap", bevel=0.035)
    kit.add(kit.brick((0.82, 0.8, 0.14), center=(0, 0, 0.88)), red, "Cap", bevel=0.04)
    kit.add(kit.brick((0.66, 0.64, 0.12), center=(0, 0, 1.00)), red, "Cap", bevel=0.035)
    kit.add(kit.brick((0.46, 0.44, 0.1), center=(0, 0, 1.10)), red, "Cap", bevel=0.03)
    kit.add(kit.brick((0.24, 0.22, 0.06), center=(0, 0, 1.17)), red, "Cap", bevel=0.02)
    for x, y, z, w in ((0.0, 0.0, 1.2, 0.1), (0.17, 0.1, 1.15, 0.09), (-0.15, -0.08, 1.15, 0.1), (0.27, -0.18, 1.06, 0.11),
                       (-0.25, 0.2, 1.06, 0.1), (0.06, 0.27, 1.06, 0.09), (-0.32, -0.27, 0.95, 0.11), (0.35, 0.23, 0.95, 0.1),
                       (-0.02, -0.33, 1.06, 0.09)):
        kit.add(kit.tile(w, w * 0.9, center=(x, y, z), thick=0.025), white, "Cap", bevel=0.004)
    for x, z in ((-0.22, 0.9), (0.18, 0.88), (0.0, 0.79)):
        kit.add(kit.box((0.09, 0.02, 0.06), center=(x, -0.42, z)), white, "Cap", bevel=0.004)
    kit.part("Cap", "Canopy", pivot=(0, 0, 0.7))
    return kit.result()
