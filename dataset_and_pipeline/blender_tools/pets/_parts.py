"""Pièces communes aux familiers en briques (yeux carrés, 4 pattes, chaîne de briques, ailes, pattes d'oiseau).

Repère : face = -Y, haut = +Z, gauche du familier = +X. Chaque fonction ajoute ses pièces au kit et règle les pivots.
"""

from __future__ import annotations

import math

from mathutils import Vector

import procedural_geometry_recipes as G


def eyes(kit, part, x, y, z, size=0.15, iris="#2A2A2E", pupil="#101012", pupil_w=0.5, pupil_h=0.8, glow=0.0,
         highlight=True, tall=1.0):
    """Deux yeux carrés plaqués sur une face avant (y = la face) : iris, pupille, petit reflet blanc."""
    m_iris = kit.mat(f"iris_{iris}", iris, rough=0.15, glow=glow)
    m_pupil = kit.mat("pupille", pupil, rough=0.1)
    m_white = kit.mat("reflet", "#FFFFFF", rough=0.08)
    for s in (-1, 1):
        cx = s * x
        kit.add(kit.box((size, 0.03, size * tall), center=(cx, y - 0.012, z)), m_iris, part, bevel=0.01)
        if pupil_w > 0:
            kit.add(kit.box((size * pupil_w, 0.02, size * tall * pupil_h), center=(cx, y - 0.03, z)), m_pupil, part,
                    bevel=0.006)
        if highlight:
            hs = size * 0.24
            kit.add(kit.box((hs, 0.012, hs), center=(cx - s * size * 0.22, y - 0.04, z + size * tall * 0.26)),
                    m_white, part, bevel=0.0)


def legs4(kit, color, paw=None, x=0.16, yf=-0.3, yb=0.34, h=0.3, w=0.16, paw_h=0.07, thigh=None, z0=0.0):
    """4 pattes en briques (trot en diagonale). thigh = (largeur, profondeur, hauteur) d'une cuisse arrière."""
    m_paw = paw or color
    for s, fx in ((1, "L"), (-1, "R")):
        for leg, y, phase in ((f"LegF{fx}", yf, 0.0 if s > 0 else math.pi),
                              (f"LegB{fx}", yb, math.pi if s > 0 else 0.0)):
            cx = s * x
            kit.add(kit.brick((w, w, h), center=(cx, y, z0 + paw_h + h / 2 - 0.01)), color, leg, bevel=0.02)
            kit.add(kit.brick((w * 1.18, w * 1.35, paw_h), center=(cx, y - w * 0.15, z0 + paw_h / 2)), m_paw, leg,
                    bevel=0.015)
            top = z0 + paw_h + h
            if thigh and leg.startswith("LegB"):
                tw, td, th = thigh
                kit.add(kit.brick((tw, td, th), center=(s * (x + 0.02), y - 0.02, top + th * 0.3)), color, leg,
                        bevel=0.025)
                top += th * 0.5
            kit.part(leg, "Leg", pivot=(cx, y, top), phase=phase)


def chain(kit, part, points, width, mats, taper=0.008, height=None):
    """Chaîne de briques le long d'un chemin (queue, cou, tentacule) ; mats alternés (rayures)."""
    pts = [Vector(p) for p in points]
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        w = max(0.03, width - taper * k)
        seg = kit.brick((w, height or w, (b - a).length * 1.1), label="Chaine")
        G.transform(seg, G.frame_matrix((a + b) / 2, b - a))
        kit.add(seg, mats[k % len(mats)], part, bevel=min(0.02, w * 0.15))


def bird_wings(kit, color, x, y, z, length=0.62, height=0.38, thick=0.1, bars=None, tip=None):
    """Ailes repliées en briques plaquées sur les flancs (pointe en pente vers l'arrière) + barres claires."""
    for s, part in ((1, "WingL"), (-1, "WingR")):
        cx = s * x
        kit.add(kit.brick((thick, length, height), center=(cx, y, z)), color, part, bevel=0.025)
        kit.add(kit.slope((thick, length * 0.38, height * 0.8), center=(cx, y + length * 0.69, z - height * 0.08),
                          facing="+Y", top=0.25), tip or color, part, bevel=0.02)
        for k, mat in enumerate(bars or []):
            dz = (k - (len(bars) - 1) / 2) * height * 0.28
            kit.add(kit.box((0.025, length * 0.62, height * 0.13), center=(cx + s * thick * 0.6, y + 0.03, z + dz),
                            rot=(-12, 0, 0)), mat, part, bevel=0.008)
        kit.part(part, "Wing", pivot=(cx - s * thick * 0.3, y - length * 0.4, z + height * 0.45), phase=float(s))


def bird_legs(kit, color, x, y, h=0.24, w=0.11, toes=3):
    """Pattes d'oiseau en briques : tibia + doigts devant + ergot derrière."""
    for s, part in ((1, "LegL"), (-1, "LegR")):
        cx = s * x
        kit.add(kit.brick((w, w, h), center=(cx, y, h / 2 + 0.06)), color, part, bevel=0.015)
        for k in range(toes):
            dx = (k - (toes - 1) / 2) * 0.065
            kit.add(kit.brick((0.06, 0.17, 0.055), center=(cx + dx, y - 0.1, 0.028), rot=(0, 0, -dx * 240)), color,
                    part, bevel=0.01)
        kit.add(kit.brick((0.055, 0.1, 0.05), center=(cx, y + 0.08, 0.025)), color, part, bevel=0.01)
        kit.part(part, "Leg", pivot=(cx, y, h + 0.06), phase=0.0 if s > 0 else math.pi)
