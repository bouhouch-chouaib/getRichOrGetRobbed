"""Objets à jeter du monde Divin (26 oct.) : plume d'ange, nuage, lyre, calice d'or, ailes d'ange, soleil d'or.

Du plus courant au plus précieux (Config.WorldItems.Divin) : plastique (plume, nuage), chrome + cordes de cristal
(lyre), or martelé + rubis (calice), nacre + or (ailes), or massif + topaze sur un nuage (soleil). Sans lueur ni
auréole lumineuse. Base : _items.py.
"""

import math

import _items as I
from pet_kit import PetKit


def plume(kit, x):
    P = "Plume"
    white = kit.mat("plume", "#FAFBFF", rough=0.5)
    tip = kit.mat("plume_bout", "#9EC4FF", rough=0.45)
    quill = kit.mat("tuyau", "#F0C860", rough=0.4)
    cloud = kit.mat("nuage_plume", "#FFFFFF", rough=0.55)
    shade = kit.mat("nuage_plume_ombre", "#D2E2FF", rough=0.6)
    # touffe de nuage au pied
    kit.add(kit.brick((1.0, 0.7, 0.14), center=(x, 0, 0.08)), shade, P, bevel=0.05)
    for size, (dx, z) in (((0.9, 0.66, 0.36), (0, 0.3)), ((0.44, 0.5, 0.4), (-0.32, 0.38)), ((0.42, 0.46, 0.34),
                                                                                         (0.34, 0.34))):
        kit.add(kit.brick(size, center=(x + dx, 0, z)), cloud, P, bevel=0.12)
    # tuyau un peu penché et courbé, dans le plan de face (X, Z)
    pts = [(0.0, 0.3), (0.06, 0.8), (0.14, 1.3), (0.26, 1.8), (0.42, 2.25)]
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        length = math.hypot(bx - ax, bz - az)
        kit.add(kit.brick((0.08, 0.08, length + 0.04), center=(x + (ax + bx) / 2, 0, (az + bz) / 2),
                          rot=(0, math.degrees(math.atan2(bx - ax, bz - az)), 0)), quill, P, bevel=0.0)
    # barbes : lamelles de chaque côté, relevées vers le haut, plus courtes vers le bout
    for k in range(9):
        t = k / 8
        u = 0.75 + t * 1.45  # hauteur le long du tuyau
        cx = 0.42 * ((u - 0.3) / 1.95) ** 1.6
        width = 0.46 * (1 - abs(t - 0.35) * 0.95)
        for side in (-1, 1):
            c = (x + cx + side * (width / 2 + 0.03), 0, u)
            kit.add(kit.box((width, 0.1, 0.2), center=c, rot=(0, side * -28, 0)), tip if k >= 7 else white, P,
                    bevel=0.02)


def nuage(kit, x):
    P = "Nuage"
    white = kit.mat("nuage", "#FFFFFF", rough=0.55)
    shade = kit.mat("nuage_ombre", "#D2E2FF", rough=0.6)
    kit.add(kit.brick((1.7, 0.8, 0.16), center=(x, 0, 0.1)), shade, P, bevel=0.06)
    for size, (dx, dy, z) in (((1.5, 0.9, 0.56), (0, 0, 0.42)), ((0.8, 0.8, 0.7), (-0.46, -0.02, 0.62)),
                              ((0.92, 0.86, 0.82), (0.22, 0.02, 0.74)), ((0.6, 0.72, 0.56), (0.78, 0.0, 0.48)),
                              ((0.62, 0.64, 0.5), (-0.06, 0.04, 1.2)), ((0.46, 0.5, 0.4), (-0.86, 0.0, 0.42))):
        kit.add(kit.brick(size, center=(x + dx, dy, z)), white, P, bevel=0.16)


def lyre(kit, x):
    P = "Lyre"
    silver = kit.chrome("argent_lyre", tint="#E4E8F2")
    crystal = kit.gem("cordes", "#08305A", "#7AD8FF", "#F0FCFF")
    gem = kit.gem("pierre_lyre", "#020A3A", "#2860FF", "#D8E4FF")
    kit.add(kit.brick((1.0, 0.42, 0.2), center=(x, 0, 0.1)), silver, P, bevel=0.05)
    kit.add(kit.brick((0.8, 0.36, 0.14), center=(x, 0, 0.27)), silver, P, bevel=0.04)
    # bras qui s'écartent puis se recourbent, en briques
    path = [(0.3, 0.32), (0.56, 0.82), (0.6, 1.36), (0.44, 1.8), (0.62, 2.04)]
    for s in (-1, 1):
        for (ax, az), (bx, bz) in zip(path, path[1:]):
            length = math.hypot(bx - ax, bz - az)
            angle = math.degrees(math.atan2(s * (bx - ax), bz - az))
            kit.add(kit.brick((0.15, 0.2, length + 0.08), center=(x + s * (ax + bx) / 2, 0, (az + bz) / 2),
                              rot=(0, angle, 0)), silver, P, bevel=0.03)
        kit.add(I.octo(kit, 0.1, 0.22, (x + s * 0.64, 0, 2.06), rot=(90, 0, 0)), silver, P, bevel=0.02)
    kit.add(kit.brick((1.08, 0.16, 0.16), center=(x, 0, 1.74)), silver, P, bevel=0.03)
    for k in range(5):
        dx = (k - 2) * 0.12
        kit.add(kit.brick((0.035, 0.035, 1.38), center=(x + dx, 0, 1.03)), crystal, P, bevel=0.0)
        kit.add(I.octo(kit, 0.04, 0.08, (x + dx, -0.1, 1.74), rot=(90, 0, 0)), silver, P, bevel=0.0)
    kit.add(kit.disc(0.1, 0.06, center=(x, -0.22, 0.12), normal=(0, -1, 0), sides=8), gem, P, bevel=0.0)


def calice(kit, x):
    P = "Calice"
    gold = kit.gold("or_calice", hammered=0.45, rough=0.24)
    gold2 = kit.gold("or_calice_fonce", tint="#E8961A", hammered=0.5, rough=0.3)
    ruby = kit.gem("rubis_calice", "#3A0008", "#F01E3C", "#FFD0D8")
    sapphire = kit.gem("saphir_calice", "#020A3A", "#2860FF", "#D8E4FF")
    wine = kit.enamel("dedans", "#7A0A2A")
    layers = [(0.56, 0.08, gold2), (0.46, 0.1, gold), (0.3, 0.1, gold2), (0.12, 0.3, gold), (0.21, 0.14, gold2),
              (0.12, 0.2, gold), (0.3, 0.1, gold2), (0.46, 0.15, gold), (0.56, 0.25, gold), (0.6, 0.3, gold),
              (0.63, 0.1, gold2)]
    top = I.stack(kit, x, 0, layers, P)
    kit.add(I.octo(kit, 0.55, 0.06, (x, 0, top - 0.06)), wine, P, bevel=0.01)
    for angle in range(0, 360, 45):
        mat = ruby if angle % 90 == 0 else sapphire
        I.disc_on_face(kit, x, 0, 0.6, angle, top - 0.27, 0.07 if angle % 90 == 0 else 0.05, mat, P, thick=0.06)
    for angle in (0, 90, 180, 270):
        I.disc_on_face(kit, x, 0, 0.21, angle, 0.58, 0.05, ruby, P, thick=0.05)


def ailes(kit, x):
    P = "Ailes"
    pearl = kit.pearl("plumes_ailes", color="#FFF6FA", sheen="#C8E0FF")
    pearl2 = kit.pearl("plumes_ailes_bout", color="#E8EEFF", sheen="#C8E0FF")
    gold = kit.gold("or_ailes", hammered=0.3, rough=0.24)
    cloud = kit.mat("nuage_ailes", "#FFFFFF", rough=0.55)
    # petit nuage de socle
    for size, (dx, z) in (((1.1, 0.6, 0.3), (0, 0.15)), ((0.5, 0.5, 0.4), (-0.36, 0.3)), ((0.56, 0.52, 0.44),
                                                                                        (0.3, 0.32))):
        kit.add(kit.brick(size, center=(x + dx, 0, z)), cloud, P, bevel=0.12)
    # cœur d'or au milieu
    cz = 1.0
    kit.add(kit.box((0.4, 0.22, 0.4), center=(x, 0, cz), rot=(0, 45, 0)), gold, P, bevel=0.03)
    for s in (-1, 1):
        kit.add(I.octo(kit, 0.18, 0.22, (x + s * 0.13, 0, cz + 0.16), rot=(90, 22.5, 0)), gold, P, bevel=0.03)
    kit.add(kit.brick((0.12, 0.14, 0.42), center=(x, 0, 0.62)), gold, P, bevel=0.02)
    # deux ailes : rangées de plumes qui rayonnent depuis l'épaule, liseré d'or en haut
    for s in (-1, 1):
        sx, sz = x + s * 0.28, 1.12
        for row, (y, scale, mat) in enumerate(((0.06, 1.0, pearl2), (-0.07, 0.7, pearl))):
            for k in range(5):
                phi = math.radians(s * (28 + 15 * k))
                length = (0.62 + 0.1 * (4 - abs(k - 1.5))) * scale
                d = (math.sin(phi), math.cos(phi))
                # chaque plume un peu plus en arrière que la précédente : des faces confondues cuisent en noir
                c = (sx + d[0] * length / 2, y + k * 0.016, sz + d[1] * length / 2 - 0.1)
                kit.add(kit.box((0.2, 0.1, length), center=c, rot=(0, math.degrees(phi), 0), taper=(0.6, 1.0)), mat, P,
                        bevel=0.03)
        kit.add(kit.brick((0.62, 0.14, 0.1), center=(x + s * 0.5, -0.02, 1.48), rot=(0, -s * 32, 0)), gold, P,
                bevel=0.02)


def soleil(kit, x):
    P = "Soleil"
    gold = kit.gold("or_soleil", hammered=0.4, rough=0.22)
    gold2 = kit.gold("or_soleil_fonce", tint="#E8961A", hammered=0.5, rough=0.28)
    topaz = kit.gem("topaze", "#6A2A00", "#FFA020", "#FFF0B0")
    cloud = kit.mat("nuage_soleil", "#FFFFFF", rough=0.55)
    shade = kit.mat("nuage_soleil_ombre", "#D2E2FF", rough=0.6)
    # disque d'or debout, rayons longs et courts, topaze au milieu
    cz = 1.3
    kit.add(kit.disc(0.6, 0.3, center=(x, 0, cz), normal=(0, -1, 0), sides=8), gold, P, bevel=0.0)
    kit.add(kit.disc(0.46, 0.36, center=(x, 0, cz), normal=(0, -1, 0), sides=8), gold2, P, bevel=0.0)
    kit.add(kit.disc(0.3, 0.44, center=(x, 0, cz), normal=(0, -1, 0), sides=8), topaz, P, bevel=0.0)
    for k in range(16):
        theta = 360 / 16 * k
        long = k % 2 == 0
        length = 0.46 if long else 0.28
        a = math.radians(theta)
        d = (math.sin(a), math.cos(a))
        r = 0.56 + length / 2
        kit.add(kit.box((0.26 if long else 0.18, 0.2, length), center=(x + d[0] * r, 0, cz + d[1] * r),
                        rot=(0, theta, 0), taper=(0.12, 0.7)), gold if long else gold2, P, bevel=0.02)
    # nuage qui le porte
    kit.add(kit.brick((1.5, 0.8, 0.16), center=(x, 0, 0.1)), shade, P, bevel=0.06)
    for size, (dx, z) in (((1.4, 0.86, 0.5), (0, 0.38)), ((0.7, 0.8, 0.6), (-0.5, 0.5)), ((0.76, 0.82, 0.64),
                                                                                        (0.42, 0.52))):
        kit.add(kit.brick(size, center=(x + dx, 0, z)), cloud, P, bevel=0.15)


def build(name: str) -> dict:
    kit = PetKit(name)
    for index, maker in enumerate((plume, nuage, lyre, calice, ailes, soleil)):
        maker(kit, I.slot(index))
    return kit.result()
