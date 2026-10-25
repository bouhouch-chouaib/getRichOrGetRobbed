"""Kraken de Baignoire (Mythique, Fantastiques) : « Pieuvre violette couronnée, avec un canard en plastique. »

En briques LEGO, très détaillé : pieuvre violet vif à la tête en dôme de briques (taches rose-violet, plus clair
dessous), énormes yeux ronds brillants aux paupières lourdes de roi blasé, petite bouche en O, couronne en or à
pointes et gemmes rouge / bleue / verte posée de travers, huit tentacules qui s'étalent et s'enroulent au bout,
ventouses roses, un canard en plastique jaune assis sur un tentacule, mousse de bain en blocs blancs.
Parties animées : huit tentacules (chacun son rythme), le canard bouge avec son tentacule.
"""

import math

import _parts as P
import procedural_geometry_recipes as G
from mathutils import Matrix, Vector
from pet_kit import PetKit, rot_matrix


def build(name: str) -> dict:
    kit = PetKit(name)
    purple = kit.mat("violet", "#A23CF0", rough=0.18)
    deep = kit.mat("violet_fonce", "#6E1EB8", rough=0.18)
    light = kit.mat("violet_clair", "#D29AFF", rough=0.18)
    cups = kit.mat("ventouses", "#FF9AD2")
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.2)
    ruby = kit.mat("rubis", "#FF1E46", rough=0.05, glow=0.6)
    sapph = kit.mat("saphir", "#2E7CFF", rough=0.05, glow=0.6)
    emer = kit.mat("emeraude", "#2EE06A", rough=0.05, glow=0.6)
    duck = kit.mat("canard", "#FFD21E", rough=0.15)
    beak = kit.mat("bec", "#FF8A1E", rough=0.15)
    foam = kit.mat("mousse", "#FFFFFF", rough=0.3)

    # --- tête en dôme de briques, taches, dessous plus clair ---
    kit.add(kit.brick((0.74, 0.68, 0.3), center=(0, 0.02, 0.42)), purple, bevel=0.05)
    kit.add(kit.brick((0.7, 0.68, 0.34), center=(0, 0.02, 0.72)), purple, bevel=0.06)
    kit.add(kit.brick((0.58, 0.56, 0.18), center=(0, 0.08, 0.96)), purple, bevel=0.05)
    kit.add(kit.brick((0.4, 0.4, 0.1), center=(0, 0.1, 1.08)), deep, bevel=0.035)
    kit.add(kit.brick((0.68, 0.62, 0.08), center=(0, 0.02, 0.26)), light, bevel=0.025)
    for x, y, z, w in ((0.3, 0.2, 0.86, 0.1), (-0.32, 0.0, 0.7, 0.08), (0.18, 0.36, 0.7, 0.09), (-0.16, 0.32, 0.98, 0.08),
                       (0.36, -0.06, 0.6, 0.06)):
        kit.add(kit.brick((w, w, w), center=(x, y, z), rot=(0, 0, 30)), light, bevel=0.015)

    # --- énormes yeux de roi blasé, bouche en O ---
    P.eyes(kit, "Body", x=0.17, y=-0.32, z=0.62, size=0.2, iris="#FFC21E", pupil="round", lid=deep, lid_drop=0.16,
           tall=1.05)
    kit.add(kit.brick((0.1, 0.03, 0.08), center=(0, -0.335, 0.4)), kit.mat("bouche", "#3A0A4A"), bevel=0.012)
    kit.add(kit.brick((0.14, 0.02, 0.02), center=(0, -0.335, 0.455)), deep, bevel=0.0)

    # --- couronne en or posée de travers ---
    crown = []
    for k in range(4):
        a = math.radians(45 + 90 * k)
        cx, cy = math.cos(a) * 0.15, 0.1 + math.sin(a) * 0.15
        crown.append(kit.add(kit.brick((0.2, 0.06, 0.1), center=(cx, cy, 1.18), rot=(0, 0, 90 * k + 90 + 45)), gold,
                             bevel=0.01))
        crown.append(kit.add(kit.wedge((0.08, 0.06, 0.12), center=(cx, cy, 1.29), rot=(0, 0, 90 * k + 135), tip=0.1),
                             gold, bevel=0.0))
    for gem, (x, y) in ((ruby, (0.0, -0.06)), (sapph, (0.16, 0.1)), (emer, (-0.16, 0.1))):
        crown.append(kit.add(kit.brick((0.06, 0.05, 0.06), center=(x, y - 0.02 if x == 0 else y, 1.18), rot=(0, 45, 0)),
                             gem, bevel=0.006))
    tilt = rot_matrix((0.04, 0.1, 1.17), (10, -12, 0)) @ Matrix.Translation(-Vector((0, 0.1, 1.18)))
    for piece in crown:
        G.transform(piece, tilt)

    # --- huit tentacules qui s'étalent ---
    for k in range(8):
        a = math.radians(-90 + 22.5 + 45 * k)
        d = (math.cos(a), math.sin(a), -0.12)
        base = (math.cos(a) * 0.3, 0.04 + math.sin(a) * 0.28, 0.28)
        P.tentacle(kit, f"Tentacle{k}", base, d, 0.62, 0.17, purple, cups=cups, phase=k * 0.8, segments=5, curl=0.7)

    # --- canard en plastique sur le tentacule avant gauche ---
    a = math.radians(-90 + 22.5 + 45 * 7)
    dx, dy = math.cos(a) * 0.62, 0.04 + math.sin(a) * 0.6
    part = "Tentacle7"
    kit.add(kit.brick((0.16, 0.22, 0.12), center=(dx, dy, 0.32)), duck, part, bevel=0.04)
    kit.add(kit.brick((0.12, 0.12, 0.12), center=(dx, dy - 0.07, 0.44)), duck, part, bevel=0.035)
    kit.add(kit.brick((0.08, 0.06, 0.03), center=(dx, dy - 0.15, 0.43)), beak, part, bevel=0.008)
    kit.add(kit.slope((0.12, 0.06, 0.06), center=(dx, dy + 0.13, 0.36), facing="+Y", top=0.2), duck, part, bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.box((0.025, 0.02, 0.025), center=(dx + s * 0.035, dy - 0.135, 0.46)), kit.mat("noir", "#141414"),
                part, bevel=0.0)

    # --- mousse de bain en blocs blancs autour de la base ---
    for x, y, w in ((0.42, -0.24, 0.12), (-0.46, -0.16, 0.1), (0.5, 0.3, 0.11), (-0.4, 0.4, 0.13), (0.06, -0.48, 0.09),
                    (-0.2, -0.42, 0.08)):
        kit.add(kit.brick((w, w, w * 0.8), center=(x, y, w * 0.4)), foam, bevel=w * 0.3)
        kit.add(kit.brick((w * 0.6, w * 0.6, w * 0.5), center=(x + w * 0.4, y + w * 0.2, w * 0.25)), foam, bevel=w * 0.2)
    return kit.result()
