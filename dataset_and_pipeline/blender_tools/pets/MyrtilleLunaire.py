"""Myrtille Lunaire (Inhabituel, Absurdes) : « Myrtille bleu nuit couverte de petits cratères. »

En briques LEGO, très détaillée (Inhabituel : émail brillant, aucune lueur) : grosse myrtille bleu nuit très brillante
(reflets lavande sur les arêtes), couronne étoilée à cinq pointes violettes sur le dessus, cratères lunaires gris-mauve
à rebord plus clair un peu partout, petit drapeau d'explorateur planté dans la couronne ; visage endormi et heureux
(paupières mi-closes, petit sourire, joues roses). Partie animée : le drapeau.
"""

import math

import _parts as P
from pet_kit import PetKit


def _crater(kit, center, normal, r, rim, pit):
    kit.add(kit.disc(r, 0.03, center=center, normal=normal, sides=8), rim, bevel=0.0)
    c = [center[i] + normal[i] * 0.012 for i in range(3)]
    kit.add(kit.disc(r * 0.65, 0.03, center=tuple(c), normal=normal, sides=8), pit, bevel=0.0)


def build(name: str) -> dict:
    kit = PetKit(name)
    blue = kit.enamel("myrtille", "#2E3AB4")
    deep = kit.enamel("myrtille_fonce", "#1E2482")
    lav = kit.mat("lavande", "#8A8AE6")
    rim = kit.mat("bord_cratere", "#B4B4D8")
    pit = kit.mat("cratere", "#6A6A9A")
    purple = kit.enamel("couronne", "#7A3AC8")
    pink = kit.mat("joues", "#FF8AC0")
    white = kit.mat("drapeau", "#FFFFFF")
    red = kit.mat("drapeau_rouge", "#FF2A4A")

    # --- grosse baie en couches ---
    # couches octogonales (deux briques à 45°) de plus en plus larges puis étroites : une baie ronde en briques
    for z, w, h, mat in ((0.05, 0.44, 0.1, deep), (0.15, 0.66, 0.12, blue), (0.3, 0.8, 0.2, blue), (0.48, 0.78, 0.18, blue),
                         (0.62, 0.64, 0.12, blue), (0.71, 0.44, 0.08, deep)):
        kit.add(kit.brick((w, w, h), center=(0, 0, z)), mat, bevel=min(0.06, h * 0.35))
        kit.add(kit.brick((w * 0.86, w * 0.86, h), center=(0, 0, z), rot=(0, 0, 45)), mat, bevel=min(0.06, h * 0.35))
    for x, y, z in ((0.22, -0.3, 0.6), (-0.3, 0.2, 0.52), (0.32, 0.18, 0.24)):
        kit.add(kit.tile(0.1, 0.08, center=(x, y, z), rot=(70, 0, 30)), lav, bevel=0.0)

    # --- cratères ---
    for center, normal, r in (((0.27, -0.4, 0.46), (0, -1, 0), 0.05), ((-0.28, -0.39, 0.22), (0, -1, 0), 0.045),
                              ((0.41, 0.1, 0.3), (1, 0, 0), 0.07), ((-0.4, -0.05, 0.46), (-1, 0, 0), 0.06),
                              ((-0.41, 0.2, 0.22), (-1, 0, 0), 0.05), ((0.1, 0.41, 0.4), (0, 1, 0), 0.07),
                              ((0.14, 0.1, 0.75), (0, 0, 1), 0.04)):
        _crater(kit, center, normal, r, rim, pit)

    # --- couronne étoilée, drapeau ---
    for k in range(5):
        a = math.radians(90 + 72 * k)
        P.tuft_piece(kit, "Body", (math.cos(a) * 0.06, math.sin(a) * 0.06, 0.7), (math.cos(a), math.sin(a), 0.6), 0.14,
                     0.08, purple)
    kit.add(kit.box((0.015, 0.015, 0.3), center=(-0.02, 0.02, 0.86)), kit.mat("mat", "#C8CCD8"), "Flag", bevel=0.0)
    kit.add(kit.box((0.14, 0.01, 0.09), center=(0.05, 0.02, 0.96)), white, "Flag", bevel=0.0)
    kit.add(kit.box((0.05, 0.012, 0.04), center=(0.04, 0.02, 0.97)), red, "Flag", bevel=0.0)
    kit.part("Flag", "Leaf", pivot=(-0.02, 0.02, 0.72), phase=0.4)

    # --- visage endormi et heureux ---
    P.eyes(kit, "Body", x=0.13, y=-0.41, z=0.42, size=0.12, iris="#1A1A3A", pupil="round", lid=deep, lid_drop=0.3,
           tall=1.0)
    P.mouth(kit, "Body", y=-0.411, z=0.28, w=0.12, smile=0.7)
    for s in (-1, 1):
        kit.add(kit.box((0.07, 0.02, 0.04), center=(s * 0.22, -0.405, 0.33)), pink, bevel=0.005)
    return kit.result()
