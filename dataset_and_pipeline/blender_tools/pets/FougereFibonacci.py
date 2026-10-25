"""La Fougère de Fibonacci (Sigma, Plantes) : « Plante fractale parfaite, d'un blanc aveuglant. »

En briques LEGO, très détaillée : petite souche blanche nacrée qui flotte, avec un visage paisible (grands yeux sombres
brillants, petit sourire, joues rosées) ; d'elle jaillissent cinq frondes de fougère d'un blanc LUMINEUX, chacune une
spirale d'or (Fibonacci : chaque brique 0,8 fois plus petite que la précédente, enroulée en crosse au bout), bordée de
folioles qui rapetissent, nervure dorée ; petits cristaux blancs qui flottent dessous. Elle flotte.
Parties animées : les cinq frondes (se déroulent et se balancent).
"""

import math

import _parts as P
import procedural_geometry_recipes as G
from mathutils import Vector
from pet_kit import PetKit


def _frond(kit, part, base, yaw, length, mats, gold):
    """Spirale de Fibonacci dans le plan vertical d'angle `yaw` : segments de plus en plus courts qui s'enroulent."""
    out = Vector((math.cos(yaw), math.sin(yaw), 0))
    up = Vector((0, 0, 1))
    side = up.cross(out)
    p = Vector(base)
    angle = math.radians(78)
    step = length
    for k in range(9):
        d = out * math.cos(angle) + up * math.sin(angle)
        q = p + d * step
        w = 0.08 * 0.86 ** k
        seg = kit.brick((w, w * 0.8, step * 1.12))
        G.transform(seg, G.frame_matrix((p + q) / 2, q - p, roll_hint=tuple(-side)))
        kit.add(seg, gold if k >= 6 else mats[k % 2], part, bevel=min(0.012, w * 0.15))
        if 1 <= k <= 5:
            # folioles des deux côtés, de plus en plus petites
            for s in (-1, 1):
                lean = (side * s + d * 0.35).normalized()
                P.leaf(kit, part, tuple((p + q) / 2), tuple(lean), 0.26 * 0.8 ** k, 0.1 * 0.85 ** k, mats[(k + 1) % 2],
                       vein=gold, normal=tuple(d.cross(lean).normalized() if s > 0 else lean.cross(d).normalized()),
                       segments=2, thick=0.03)
        p = q
        angle -= math.radians(34)
        step *= 0.8


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.mat("blanc", "#FFFFFF", rough=0.12, glow=0.8)
    pearl = kit.mat("nacre", "#E2ECFF", rough=0.12, glow=0.5)
    gold = kit.mat("or_pale", "#FFE27A", rough=0.15, glow=1.6)
    crystal = kit.mat("cristal", "#F4FBFF", rough=0.05, glow=1.4)
    pink = kit.mat("joues", "#FFB8D4")

    # --- souche nacrée qui flotte, visage, cristaux ---
    kit.add(kit.brick((0.44, 0.4, 0.26), center=(0, 0, 0.24)), pearl, bevel=0.06)
    kit.add(kit.brick((0.36, 0.34, 0.08), center=(0, 0, 0.4)), white, bevel=0.025)
    kit.add(kit.brick((0.3, 0.28, 0.08), center=(0, 0, 0.08)), pearl, bevel=0.025)
    P.eyes(kit, "Body", x=0.085, y=-0.2, z=0.27, size=0.09, iris="#2A2A4A", pupil="round", sclera="#2A2A4A", tall=1.15)
    P.mouth(kit, "Body", y=-0.201, z=0.18, w=0.08, smile=0.6)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.03), center=(s * 0.15, -0.202, 0.21)), pink, bevel=0.004)
    for x, y, z, w in ((0.12, -0.08, -0.02, 0.06), (-0.1, 0.06, -0.06, 0.05), (0.02, 0.12, -0.1, 0.04)):
        kit.add(kit.brick((w, w, w * 1.6), center=(x, y, z + 0.06), rot=(30, 20, 45)), crystal, bevel=0.006)

    # --- cinq frondes en spirale de Fibonacci ---
    for k in range(5):
        yaw = math.radians(90 + 72 * k + 18)
        part = f"Frond{k}"
        base = (math.cos(yaw) * 0.08, math.sin(yaw) * 0.08, 0.44)
        _frond(kit, part, base, yaw, 0.26 if k != 1 else 0.3, [white, pearl], gold)
        kit.part(part, "Leaf", pivot=base, phase=k * 1.25)
    return kit.result()
