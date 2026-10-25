"""Assemblages « sculptés » communs aux familiers en briques LEGO (25 oct., 2e niveau de détail).

Chouaib : plus de détails, plus d'éléments, mieux sculpté pour ressembler un peu plus à l'animal réel, toujours en
formes LEGO, couleurs saturées pour enfants, chaque familier très travaillé. D'où des sous-ensembles anatomiques
(torse avec poitrail / reins / croupe, pattes articulées à doigts et griffes, yeux en couches avec paupière et sourcil,
truffe à narines, oreilles à pointe et touffe, ailes en trois rangs de plumes, queue en éventail, touffes de poils).

Repère : face = -Y, haut = +Z, gauche du familier = +X. s = côté (+1 gauche, -1 droite).
"""

from __future__ import annotations

import math

from mathutils import Vector

import procedural_geometry_recipes as G


def side(s: int) -> str:
    return "+X" if s > 0 else "-X"


# ---------------------------------------------------------------------------------------------------------------------
# Visage
# ---------------------------------------------------------------------------------------------------------------------

def eyes(kit, part, x, y, z, size=0.14, iris="#3A8CFF", pupil="round", lid=None, lid_drop=0.0, brow=None,
         brow_angle=0.0, look=(0.0, 0.0), glow=0.0, sclera="#FFFFFF", tall=1.0):
    """Deux yeux en couches sur une face qui regarde vers -Y (y = la face) : blanc, iris, pupille, deux reflets,
    paupière (lid_drop 0 = grand ouvert, 0,5 = mi-clos) et sourcil (brow_angle > 0 = froncé vers le centre).
    pupil : "round" (tuile ronde), "slit" (fente de chat), "square"."""
    m_scl = kit.mat("blanc_oeil", sclera, rough=0.12)
    m_iris = kit.mat(f"iris{iris}", iris, rough=0.12, glow=glow)
    m_pup = kit.mat("pupille", "#0C0C10", rough=0.08)
    m_hi = kit.mat("reflet", "#FFFFFF", rough=0.05)
    h = size * tall
    for s in (-1, 1):
        cx, lx, lz = s * x, look[0] * size * 0.18, look[1] * size * 0.18
        kit.add(kit.box((size, 0.04, h), center=(cx, y - 0.015, z)), m_scl, part, bevel=0.012)
        kit.add(kit.box((size * 0.66, 0.02, h * 0.66), center=(cx + lx, y - 0.04, z + lz)), m_iris, part, bevel=0.008)
        if pupil == "round":
            kit.add(kit.disc(size * 0.17, 0.016, center=(cx + lx, y - 0.051, z + lz), normal=(0, -1, 0), sides=16),
                    m_pup, part, bevel=0.0)
        elif pupil == "slit":
            kit.add(kit.box((size * 0.13, 0.016, h * 0.56), center=(cx + lx, y - 0.051, z + lz)), m_pup, part, bevel=0.0)
        else:
            kit.add(kit.box((size * 0.3, 0.016, h * 0.3), center=(cx + lx, y - 0.051, z + lz)), m_pup, part, bevel=0.0)
        kit.add(kit.box((size * 0.16, 0.01, size * 0.16), center=(cx + lx - s * size * 0.15, y - 0.058, z + lz + h * 0.16)),
                m_hi, part, bevel=0.0)
        kit.add(kit.box((size * 0.08, 0.01, size * 0.08), center=(cx + lx + s * size * 0.12, y - 0.058, z + lz - h * 0.14)),
                m_hi, part, bevel=0.0)
        if lid:
            lh = h * (0.18 + lid_drop)
            kit.add(kit.box((size * 1.1, 0.05, lh), center=(cx, y - 0.02, z + h / 2 - lh / 2 + 0.01)), lid, part,
                    bevel=0.01)
        if brow:
            kit.add(kit.box((size * 1.15, 0.06, size * 0.17), center=(cx, y - 0.02, z + h * 0.5 + size * 0.16),
                            rot=(0, s * brow_angle, 0)), brow, part, bevel=0.01)


def side_eyes(kit, part, x, y, z, size=0.13, iris="#F2B230", pupil="round", ring=None, brow=None, brow_angle=0.0):
    """Yeux sur les côtés de la tête (oiseaux, poissons) : face qui regarde vers ±X."""
    m_scl = kit.mat("blanc_oeil", "#FFFFFF", rough=0.12)
    m_iris = kit.mat(f"iris{iris}", iris, rough=0.12)
    m_pup = kit.mat("pupille", "#0C0C10", rough=0.08)
    m_hi = kit.mat("reflet", "#FFFFFF", rough=0.05)
    for s in (-1, 1):
        cx = s * x
        if ring:
            kit.add(kit.box((0.03, size * 1.25, size * 1.25), center=(cx, y, z)), ring, part, bevel=0.01)
        kit.add(kit.box((0.035, size, size), center=(cx + s * 0.02, y, z)), m_scl, part, bevel=0.01)
        kit.add(kit.box((0.02, size * 0.66, size * 0.66), center=(cx + s * 0.04, y - size * 0.06, z)), m_iris, part,
                bevel=0.006)
        if pupil == "round":
            kit.add(kit.disc(size * 0.18, 0.015, center=(cx + s * 0.052, y - size * 0.08, z), normal=(s, 0, 0), sides=16),
                    m_pup, part, bevel=0.0)
        else:
            kit.add(kit.box((0.015, size * 0.3, size * 0.3), center=(cx + s * 0.052, y - size * 0.08, z)), m_pup, part,
                    bevel=0.0)
        kit.add(kit.box((0.01, size * 0.15, size * 0.15), center=(cx + s * 0.06, y - size * 0.22, z + size * 0.18)),
                m_hi, part, bevel=0.0)
        if brow:
            kit.add(kit.box((0.05, size * 1.1, size * 0.16), center=(cx + s * 0.01, y, z + size * 0.62),
                            rot=(-brow_angle, 0, 0)), brow, part, bevel=0.008)


def nose(kit, part, y, z, w, color, x=0.0, nostril="#1A1416"):
    """Truffe : brique + pente au-dessus + deux narines."""
    m_n = kit.mat(f"truffe{color}", color, rough=0.12)
    m_ho = kit.mat(f"narine{nostril}", nostril, rough=0.2)
    kit.add(kit.brick((w, w * 0.6, w * 0.55), center=(x, y - w * 0.3, z)), m_n, part, bevel=min(0.02, w * 0.18))
    kit.add(kit.slope((w * 0.9, w * 0.35, w * 0.22), center=(x, y - w * 0.18, z + w * 0.38), facing="-Y", top=0.3), m_n,
            part, bevel=0.006)
    for s in (-1, 1):
        kit.add(kit.box((w * 0.18, 0.012, w * 0.14), center=(x + s * w * 0.22, y - w * 0.6 - 0.004, z - w * 0.06)), m_ho,
                part, bevel=0.0)


def mouth(kit, part, y, z, w, color="#2A1418", smile=0.25, tongue=None, fangs=None, x=0.0):
    """Bouche : trait central + coins relevés (smile), langue et crocs en option."""
    m = kit.mat(f"bouche{color}", color, rough=0.25)
    kit.add(kit.box((w * 0.5, 0.02, 0.022), center=(x, y - 0.006, z)), m, part, bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.box((w * 0.3, 0.02, 0.022), center=(x + s * w * 0.36, y - 0.006, z + w * smile * 0.12),
                        rot=(0, -s * smile * 55, 0)), m, part, bevel=0.0)
    if tongue:
        kit.add(kit.box((w * 0.22, 0.03, 0.05), center=(x, y - 0.01, z - 0.03)), tongue, part, bevel=0.008)
    if fangs:
        for s in (-1, 1):
            kit.add(kit.wedge((0.03, 0.02, 0.05), center=(x + s * w * 0.18, y - 0.012, z - 0.035), rot=(180, 0, 0),
                              tip=0.15), fangs, part, bevel=0.0)


def ear(kit, part, s, base, w, h, color, inner=None, tilt=(0.0, 0.0), tip=None, tuft=None, depth=0.08):
    """Oreille en coin : extérieur, intérieur, pointe d'une autre couleur, touffe au bout (lynx)."""
    rot = (tilt[0], s * tilt[1], 0)
    bx, by, bz = base
    kit.add(kit.wedge((w, depth, h), center=(bx, by, bz + h / 2), rot=rot, tip=0.1), color, part, bevel=0.012)
    if inner:
        kit.add(kit.wedge((w * 0.55, 0.02, h * 0.68), center=(bx, by - depth / 2 - 0.006, bz + h * 0.4), rot=rot,
                          tip=0.12), inner, part, bevel=0.004)
    if tip:
        kit.add(kit.wedge((w * 0.36, depth * 1.06, h * 0.3), center=(bx + s * h * math.sin(math.radians(tilt[1])) * 0.82,
                                                                    by, bz + h * 0.86), rot=rot, tip=0.1), tip, part,
                bevel=0.004)
    if tuft:
        tuft_piece(kit, part, (bx, by, bz + h * 0.95), (s * 0.2, 0.0, 1.0), h * 0.35, w * 0.25, tuft)


def tuft_piece(kit, part, base, direction, length, width, color):
    """Touffe / mèche / épine : coin LEGO orienté le long de `direction`."""
    obj = kit.wedge((width, width * 0.7, length), center=(0, 0, 0), tip=0.1, label="Touffe")
    d = Vector(direction).normalized()
    G.transform(obj, G.frame_matrix(Vector(base) + d * length / 2, d))
    kit.add(obj, color, part, bevel=0.006)


def whiskers(kit, part, x, y, z, color="#FFFFFF", n=3, length=0.16):
    """Moustaches : fines tuiles en éventail de chaque côté du museau."""
    m = kit.mat(f"moustache{color}", color, rough=0.2)
    for s in (-1, 1):
        for k in range(n):
            a = (k - (n - 1) / 2) * 12
            kit.add(kit.box((length, 0.012, 0.012), center=(s * (x + length * 0.45), y, z + k * 0.025 - 0.025),
                            rot=(0, -s * a, 0)), m, part, bevel=0.0)


# ---------------------------------------------------------------------------------------------------------------------
# Corps de quadrupède
# ---------------------------------------------------------------------------------------------------------------------

def quad_torso(kit, L, W, H, z, main, y0=0.0, belly=None, chest=None, back=None, hump=0.6):
    """Torse sculpté : tronc, poitrail bombé, épaules, reins, croupe arrondie, dos, ventre rentré."""
    belly, chest, back = belly or main, chest or main, back or main
    kit.add(kit.brick((W, L * 0.56, H), center=(0, y0, z)), main, bevel=0.035)
    kit.add(kit.brick((W * 1.03, L * 0.26, H * 1.04), center=(0, y0 - L * 0.37, z + H * 0.03)), main, bevel=0.035)
    kit.add(kit.brick((W * 0.62, 0.05, H * 0.82), center=(0, y0 - L * 0.5 - 0.02, z - H * 0.02)), chest, bevel=0.02)
    kit.add(kit.slope((W * 0.86, L * 0.14, H * 0.3), center=(0, y0 - L * 0.44, z - H * 0.42), facing="-Y", top=0.3,
                      rot=(180, 0, 0)), main, bevel=0.02)
    kit.add(kit.slope((W * 0.92, L * 0.18, H * 0.18 * hump / 0.6), center=(0, y0 - L * 0.38, z + H * 0.6), facing="-Y",
                      top=0.35), back, bevel=0.02)
    kit.add(kit.brick((W * 0.98, L * 0.24, H * 0.96), center=(0, y0 + L * 0.38, z + H * 0.01)), main, bevel=0.035)
    kit.add(kit.slope((W * 0.9, L * 0.16, H * 0.22), center=(0, y0 + L * 0.47, z + H * 0.58), facing="+Y", top=0.3),
            back, bevel=0.02)
    kit.add(kit.brick((W * 0.86, L * 0.56, H * 0.12), center=(0, y0 - 0.0, z + H * 0.56)), back, bevel=0.02)
    kit.add(kit.brick((W * 0.7, L * 0.56, H * 0.1), center=(0, y0 - L * 0.04, z - H * 0.55)), belly, bevel=0.02)
    kit.add(kit.slope((W * 0.7, L * 0.12, H * 0.18), center=(0, y0 + L * 0.26, z - H * 0.5), facing="+Y", top=0.3,
                      rot=(180, 0, 0)), main, bevel=0.015)


def quad_leg(kit, part, s, y, top, length, w, main, paw=None, toe=None, claw=None, hind=False, phase=0.0, toes=3,
             x=None, lower=None):
    """Patte articulée : épaule / cuisse, jambe (jarret pour l'arrière), patte, doigts, griffes ; pivot en haut.
    lower = couleur du bas de la patte (chaussettes du renard...)."""
    x = s * (x if x is not None else 0.16)
    paw, toe, lower = paw or main, toe or paw or main, lower or main
    if hind:
        kit.add(kit.brick((w * 1.4, w * 1.9, length * 0.46), center=(x + s * w * 0.06, y + w * 0.1, top - length * 0.2),
                          rot=(10, 0, 0)), main, part, bevel=0.03)
        kit.add(kit.brick((w * 0.95, w * 0.95, length * 0.5), center=(x, y + w * 0.32, top - length * 0.6),
                          rot=(-12, 0, 0)), lower, part, bevel=0.02)
    else:
        kit.add(kit.brick((w * 1.25, w * 1.45, length * 0.4), center=(x + s * w * 0.04, y, top - length * 0.18)), main,
                part, bevel=0.03)
        kit.add(kit.brick((w, w * 0.95, length * 0.52), center=(x, y, top - length * 0.6)), lower, part, bevel=0.02)
    ph = max(0.05, length * 0.12)
    kit.add(kit.brick((w * 1.22, w * 1.4, ph), center=(x, y - w * 0.1, ph / 2)), paw, part, bevel=0.015)
    for k in range(toes):
        dx = (k - (toes - 1) / 2) * w * 0.38
        kit.add(kit.brick((w * 0.3, w * 0.36, ph * 0.8), center=(x + dx, y - w * 0.92, ph * 0.4)), toe, part, bevel=0.008)
        if claw:
            kit.add(kit.wedge((w * 0.16, w * 0.2, ph * 0.5), center=(x + dx, y - w * 1.18, ph * 0.28), rot=(90, 0, 0),
                              tip=0.15), claw, part, bevel=0.0)
    kit.part(part, "Leg", pivot=(x, y, top), phase=phase)


def quad_legs(kit, main, yf, yb, top_f, top_b, length_f, length_b, w, paw=None, toe=None, claw=None, x=0.16, toes=3,
              lower=None):
    """Les 4 pattes (trot en diagonale : avant gauche avec arrière droite)."""
    for s, fx in ((1, "L"), (-1, "R")):
        quad_leg(kit, f"LegF{fx}", s, yf, top_f, length_f, w, main, paw, toe, claw, False,
                 0.0 if s > 0 else math.pi, toes, x, lower)
        quad_leg(kit, f"LegB{fx}", s, yb, top_b, length_b, w, main, paw, toe, claw, True,
                 math.pi if s > 0 else 0.0, toes, x, lower)


def chain(kit, part, points, width, mats, taper=0.008, height=None):
    """Chaîne de briques le long d'un chemin (queue, cou, tentacule) ; mats alternés (rayures)."""
    pts = [Vector(p) for p in points]
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        w = max(0.03, width - taper * k)
        seg = kit.brick((w, height or w, (b - a).length * 1.12), label="Chaine")
        G.transform(seg, G.frame_matrix((a + b) / 2, b - a))
        kit.add(seg, mats[k % len(mats)], part, bevel=min(0.02, w * 0.15))


def bushy_tail(kit, part, points, width, main, tip=None, tufts=True):
    """Queue touffue : chaîne qui s'élargit, mèches en coins de chaque côté, bout d'une autre couleur."""
    pts = [Vector(p) for p in points]
    n = len(pts) - 1
    for k in range(n):
        a, b = pts[k], pts[k + 1]
        w = width * (0.6 + 0.5 * math.sin(math.pi * (k + 0.5) / n) + 0.15 * k / n)
        mat = tip if (tip and k == n - 1) else main
        seg = kit.brick((w, w * 0.9, (b - a).length * 1.15), label="Queue")
        G.transform(seg, G.frame_matrix((a + b) / 2, b - a))
        kit.add(seg, mat, part, bevel=0.02)
        if tufts and 0 < k < n - 1:
            d = (b - a).normalized()
            for sx in (-1, 1):
                tuft_piece(kit, part, (a + b) / 2 + Vector((sx * w * 0.42, 0, 0)), (sx * 0.8, d.y * 0.4, d.z * 0.4 + 0.2),
                           w * 0.55, w * 0.35, mat)


# ---------------------------------------------------------------------------------------------------------------------
# Oiseaux
# ---------------------------------------------------------------------------------------------------------------------

def bird_wings(kit, x, y, z, length, height, cov, sec, prim, bar=None, thick=0.1):
    """Ailes repliées en trois rangs de plumes (couvertures, secondaires, rémiges en pente vers l'arrière)."""
    for s, part in ((1, "WingL"), (-1, "WingR")):
        cx = s * x
        kit.add(kit.brick((thick, length * 0.62, height * 0.55), center=(cx, y - length * 0.12, z + height * 0.2)), cov,
                part, bevel=0.025)
        kit.add(kit.slope((thick, length * 0.2, height * 0.3), center=(cx, y - length * 0.5, z + height * 0.33),
                          facing="-Y", top=0.3), cov, part, bevel=0.015)
        kit.add(kit.brick((thick * 0.9, length * 0.72, height * 0.42), center=(cx + s * 0.012, y + length * 0.06,
                                                                              z - height * 0.12)), sec, part, bevel=0.02)
        kit.add(kit.slope((thick * 0.8, length * 0.46, height * 0.32), center=(cx + s * 0.02, y + length * 0.6,
                                                                             z - height * 0.22),
                          facing="+Y", top=0.2), prim, part, bevel=0.015)
        for k in range(3):  # pointes de rémiges, en escalier
            kit.add(kit.wedge((thick * 0.6, 0.07, height * 0.18), center=(cx + s * 0.024, y + length * (0.82 + 0.04 * k),
                                                                          z - height * (0.34 - 0.06 * k)),
                              rot=(-90, 0, 0), tip=0.2), prim, part, bevel=0.0)
        if bar:
            kit.add(kit.box((0.02, length * 0.5, height * 0.08), center=(cx + s * thick * 0.55, y - 0.02, z + 0.0),
                            rot=(-10, 0, 0)), bar, part, bevel=0.0)
            kit.add(kit.box((0.02, length * 0.42, height * 0.08), center=(cx + s * thick * 0.55, y + 0.04, z - height * 0.14),
                            rot=(-10, 0, 0)), bar, part, bevel=0.0)
        kit.part(part, "Wing", pivot=(cx - s * thick * 0.3, y - length * 0.42, z + height * 0.42), phase=float(s))


def tail_fan(kit, part, base, n, length, width, mats, spread=15.0, pitch=-25.0, thick=0.055):
    """Queue en éventail : n plumes en plaques, la centrale au-dessus."""
    bx, by, bz = base
    for k in range(n):
        yaw = (k - (n - 1) / 2) * spread
        depth = 0.004 * abs(k - (n - 1) / 2)
        kit.add(kit.brick((width, length, thick), center=(bx + math.sin(math.radians(yaw)) * length * 0.45,
                                                          by + length * 0.45, bz - depth),
                          rot=(pitch, 0, yaw)), mats[k % len(mats)], part, bevel=0.012)
    kit.part(part, "Tail", pivot=(bx, by, bz))


def bird_feet(kit, x, y, h, w, color, claw=None):
    """Pattes d'oiseau : tibia à « genou », 3 doigts devant, ergot derrière, griffes."""
    claw = claw or color
    for s, part in ((1, "LegL"), (-1, "LegR")):
        cx = s * x
        kit.add(kit.brick((w * 1.25, w * 1.25, h * 0.35), center=(cx, y, h * 0.85)), color, part, bevel=0.015)
        kit.add(kit.brick((w, w, h * 0.6), center=(cx, y, h * 0.42)), color, part, bevel=0.012)
        for k, yaw in enumerate((20, 0, -20)):
            dx = (k - 1) * w * 0.6
            kit.add(kit.brick((w * 0.5, w * 1.6, w * 0.45), center=(cx + dx, y - w * 0.9, w * 0.22), rot=(0, 0, yaw)),
                    color, part, bevel=0.008)
            kit.add(kit.wedge((w * 0.3, w * 0.3, w * 0.3), center=(cx + dx * 1.35, y - w * 1.8, w * 0.15), rot=(90, 0, 0),
                              tip=0.2), claw, part, bevel=0.0)
        kit.add(kit.brick((w * 0.45, w * 0.9, w * 0.4), center=(cx, y + w * 0.65, w * 0.2)), color, part, bevel=0.008)
        kit.part(part, "Leg", pivot=(cx, y, h), phase=0.0 if s > 0 else math.pi)
