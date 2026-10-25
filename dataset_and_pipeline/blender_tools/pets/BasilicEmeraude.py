"""Basilic d'Émeraude (Mythique, Fantastiques) : « Serpent vert fluo aux yeux jaunes hypnotiques. »

En briques LEGO, très détaillé : grand serpent vert fluo enroulé au sol, cou dressé comme un cobra, écailles en losanges
émeraude foncé sur le dos, ventre jaune pâle en plaques, tête de roi des serpents à couronne de piques dorées et
collerette, grands yeux jaunes LUMINEUX hypnotiques (fente noire), langue fourchue rouge, petits crocs.
Parties animées : chaque anneau du corps (la vague passe de l'un à l'autre), la tête.
"""

import _parts as P
import procedural_geometry_recipes as G
from mathutils import Matrix, Vector
from pet_kit import PetKit

PATH = [(0.0, -0.3, 0.8), (0.0, -0.2, 0.56), (0.0, -0.08, 0.34), (0.06, 0.06, 0.16), (0.26, 0.16, 0.12),
        (0.34, 0.38, 0.11), (0.16, 0.56, 0.1), (-0.12, 0.56, 0.09), (-0.32, 0.4, 0.08), (-0.34, 0.16, 0.07),
        (-0.2, 0.0, 0.06), (-0.02, -0.04, 0.05)]


def build(name: str) -> dict:
    kit = PetKit(name)
    neon = kit.mat("vert_fluo", "#3CFF6E", rough=0.12)
    emerald = kit.mat("emeraude", "#0FB850", rough=0.1)
    dark = kit.mat("emeraude_fonce", "#08803A", rough=0.1)
    belly = kit.mat("ventre", "#F2FF9A")
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.2)
    tongue = kit.mat("langue", "#FF1E3C")
    fang = kit.mat("crocs", "#FFFFFF", rough=0.1)

    # --- corps enroulé en anneaux animés, losanges d'écailles sur le dos ---
    P.snake(kit, PATH, 0.26, 0.22, [neon, emerald], belly=belly)
    pts = [Vector(p) for p in PATH]
    n = len(pts) - 1
    for k in range(n):
        a, b = pts[k], pts[k + 1]
        f = k / (n - 1)
        w = 0.26 * (1 - 0.55 * max(0.0, f - 0.55) / 0.45)  # même affinement que P.snake
        frame = G.frame_matrix((a + b) / 2, b - a, roll_hint=(0, 0, -1))
        up = frame.to_3x3() @ Vector((0, 1, 0))
        scale = kit.brick((w * 0.42, 0.03, w * 0.42), rot=(0, 45, 0))
        G.transform(scale, Matrix.Translation(up * (0.22 * w / 0.26 * 0.5 + 0.01)) @ frame)
        kit.add(scale, dark, f"Seg{k}", bevel=0.006)

    # --- tête de roi des serpents ---
    kit.add(kit.brick((0.36, 0.42, 0.22), center=(0, -0.5, 0.88)), neon, "Head", bevel=0.04)
    kit.add(kit.brick((0.3, 0.2, 0.08), center=(0, -0.62, 0.8)), belly, "Head", bevel=0.02)
    kit.add(kit.slope((0.32, 0.18, 0.08), center=(0, -0.66, 1.02), facing="-Y", top=0.3), emerald, "Head", bevel=0.012)
    kit.add(kit.brick((0.32, 0.26, 0.08), center=(0, -0.4, 1.02)), emerald, "Head", bevel=0.015)
    # collerette de cobra derrière la tête
    for s in (-1, 1):
        kit.add(kit.brick((0.2, 0.06, 0.34), center=(s * 0.22, -0.3, 0.8), rot=(0, s * -20, s * 20)), emerald, "Head",
                bevel=0.02)
        kit.add(kit.brick((0.14, 0.03, 0.24), center=(s * 0.22, -0.335, 0.8), rot=(0, s * -20, s * 20)), belly, "Head",
                bevel=0.008)
    # couronne de piques dorées
    for k in range(5):
        dx = (k - 2) * 0.07
        P.horn(kit, "Head", (dx, -0.42 + abs(k - 2) * 0.02, 1.05), (dx * 1.5, 0.4, 1.0), 0.18 - abs(k - 2) * 0.03, 0.06,
               [gold], segments=2)
    # yeux hypnotiques : jaune lumineux, fente noire, contour sombre
    P.eyes(kit, "Head", x=0.11, y=-0.71, z=0.93, size=0.12, iris="#FFE600", pupil="slit", sclera="#1A2A10", glow=2.8,
           brow=dark, brow_angle=14, tall=0.9)
    # langue fourchue et petits crocs
    kit.add(kit.box((0.03, 0.14, 0.015), center=(0, -0.76, 0.81)), tongue, "Head", bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.box((0.025, 0.07, 0.015), center=(s * 0.02, -0.85, 0.81), rot=(0, 0, s * 25)), tongue, "Head",
                bevel=0.0)
        kit.add(kit.wedge((0.03, 0.03, 0.05), center=(s * 0.08, -0.7, 0.8), rot=(180, 0, 0), tip=0.15), fang, "Head",
                bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.32, 0.8))
    return kit.result()

