"""Pieuvre Pirate (Mythique, Abysses) : « Huit bras, huit sabres, et un trésor caché quelque part. »

En briques LEGO, très détaillée (Mythique : nacre et or, aucune lueur) : pieuvre rouge framboise tachetée, tricorne
noir à liseré d'OR et tête de mort en NACRE, cache-œil noir, l'autre œil rusé, boucle d'oreille en or, sourire en coin ;
huit tentacules à ventouses roses, dont quatre tiennent des sabres (lames chromées, gardes en or) ; un petit coffre
au trésor en bois cerclé d'or plein de pièces à côté d'elle. Parties animées : huit tentacules.
"""

import math

from mathutils import Vector

import _parts as P
from pet_kit import PetKit


def _tip(base, direction, length, segments, curl):
    """Bout d'un tentacule de P.tentacle (même calcul), pour y mettre un sabre."""
    d, up, p = Vector(direction).normalized(), Vector((0, 0, 1)), Vector(base)
    for k in range(segments):
        f = k / segments
        p = p + (d * (1 - f * curl) + up * f * curl).normalized() * (length / segments)
    return p


def build(name: str) -> dict:
    kit = PetKit(name)
    red = kit.enamel("pieuvre", "#D8283E")
    spot = kit.mat("taches", "#A8142A")
    cups = kit.mat("ventouses", "#FFB0C0")
    black = kit.mat("tricorne", "#1A1A20")
    gold = kit.gold("or", hammered=0.3)
    pearl = kit.pearl("tete_de_mort")
    blade = kit.chrome("lames")
    wood = kit.mat("coffre", "#8A4A1E")

    # --- tête en dôme, taches ---
    kit.add(kit.brick((0.62, 0.58, 0.3), center=(0, 0.04, 0.42)), red, bevel=0.06)
    kit.add(kit.brick((0.58, 0.56, 0.32), center=(0, 0.06, 0.7)), red, bevel=0.07)
    kit.add(kit.brick((0.44, 0.42, 0.14), center=(0, 0.08, 0.92)), red, bevel=0.05)
    for x, y, z in ((0.28, 0.1, 0.72), (-0.29, -0.02, 0.6), (0.12, 0.33, 0.8), (-0.14, 0.3, 0.5)):
        kit.add(kit.box((0.05, 0.05, 0.05), center=(x, y, z)), spot, bevel=0.01)

    # --- visage : cache-œil, œil rusé, sourire en coin, boucle d'oreille ---
    P.eyes(kit, "Body", x=0.13, y=-0.25, z=0.64, size=0.1, iris="#2A8A4A", pupil="slit", lid=red, lid_drop=0.2,
           brow=spot, brow_angle=16, tall=1.0)
    kit.add(kit.brick((0.14, 0.04, 0.14), center=(-0.13, -0.275, 0.64)), black, bevel=0.03)
    kit.add(kit.box((0.5, 0.02, 0.02), center=(0, -0.26, 0.7), rot=(0, -20, 0)), black, bevel=0.0)
    P.mouth(kit, "Body", y=-0.27, z=0.46, w=0.12, smile=0.5, x=0.03)
    kit.add(kit.disc(0.035, 0.02, center=(0.31, -0.1, 0.56), normal=(1, 0, 0), sides=10), gold, bevel=0.0)

    # --- tricorne à liseré d'or et tête de mort en nacre ---
    kit.add(kit.brick((0.6, 0.5, 0.1), center=(0, 0.06, 1.02)), black, bevel=0.03)
    for s in (-1, 1):
        kit.add(kit.brick((0.1, 0.5, 0.14), center=(s * 0.3, 0.06, 1.08), rot=(0, s * -35, 0)), black, bevel=0.02)
    kit.add(kit.brick((0.5, 0.1, 0.14), center=(0, -0.2, 1.08), rot=(30, 0, 0)), black, bevel=0.02)
    kit.add(kit.brick((0.52, 0.03, 0.03), center=(0, -0.25, 1.14), rot=(30, 0, 0)), gold, bevel=0.0)
    kit.add(kit.brick((0.08, 0.03, 0.08), center=(0, -0.26, 1.08), rot=(30, 0, 0)), pearl, bevel=0.012)
    for s in (-1, 1):
        kit.add(kit.box((0.1, 0.02, 0.02), center=(0, -0.265, 1.04), rot=(30, s * 35, 0)), pearl, bevel=0.0)

    # --- huit tentacules, quatre sabres ---
    for k in range(8):
        a = math.radians(-90 + 22.5 + 45 * k)
        d = (math.cos(a), math.sin(a), -0.1)
        base = (math.cos(a) * 0.26, 0.04 + math.sin(a) * 0.24, 0.28)
        part = f"Tentacle{k}"
        P.tentacle(kit, part, base, d, 0.56, 0.15, red, cups=cups, phase=k * 0.8, segments=5, curl=0.7)
        if k in (0, 3, 4, 7):
            tip = _tip(base, d, 0.56, 5, 0.7)
            kit.add(kit.brick((0.1, 0.04, 0.04), center=tuple(tip)), gold, part, bevel=0.01)
            kit.add(kit.box((0.025, 0.02, 0.32), center=(tip.x, tip.y, tip.z + 0.18), rot=(0, (k % 2) * 12 - 6, 0)), blade,
                    part, bevel=0.0)

    # --- petit coffre au trésor ---
    kit.add(kit.brick((0.24, 0.16, 0.14), center=(0.46, -0.42, 0.07)), wood, bevel=0.02)
    kit.add(kit.brick((0.26, 0.18, 0.03), center=(0.46, -0.42, 0.1)), gold, bevel=0.008)
    kit.add(kit.brick((0.22, 0.12, 0.04), center=(0.46, -0.42, 0.16)), gold, bevel=0.012)
    return kit.result()
