"""Objets à jeter de la Prairie (26 oct.) : pomme, carotte, fromage, pot de miel, trèfle d'émeraude, ruche d'or.

Du plus courant au plus précieux (Config.WorldItems.Prairie) : plastique (pomme, carotte), émail (fromage), cristal
d'ambre + or martelé (pot de miel), émeraude sur nacre (trèfle), or massif (ruche). Base commune : _items.py.
"""

import math

import _items as I
from pet_kit import PetKit


def pomme(kit, x):
    P = "Pomme"
    red = kit.mat("pomme", "#EC1C2C", rough=0.3)
    dark = kit.mat("pomme_fonce", "#B01020", rough=0.35)
    shine = kit.mat("pomme_reflet", "#FF7A6E", rough=0.25)
    wood = kit.mat("tige", "#6B3A1E", rough=0.6)
    leaf = kit.mat("feuille", "#38C838", rough=0.35)
    leaf_dark = kit.mat("feuille_fonce", "#1E9A2A", rough=0.4)
    layers = [(0.44, 0.16, dark), (0.68, 0.24, dark), (0.84, 0.3, red), (0.88, 0.3, red), (0.8, 0.26, red),
              (0.6, 0.16, red)]
    top = I.stack(kit, x, 0, layers, P)
    kit.add(I.octo(kit, 0.32, 0.06, (x, 0, top + 0.0)), dark, P, bevel=0.01)  # creux autour de la tige
    kit.add(kit.brick((0.14, 0.14, 0.46), center=(x + 0.03, 0, top + 0.2), rot=(0, 12, 0)), wood, P, bevel=0.03)
    kit.add(kit.box((0.44, 0.24, 0.08), center=(x + 0.3, 0.02, top + 0.26), rot=(8, -28, 18), taper=(0.35, 0.6)),
            leaf, P, bevel=0.02)
    kit.add(kit.brick((0.3, 0.03, 0.09), center=(x + 0.29, 0.02, top + 0.31), rot=(8, -28, 18)), leaf_dark, P,
            bevel=0.0)
    # reflets (tuiles claires) et petites taches
    I.on_face(kit, x, 0, 0.88, -45, 0.86, 0.2, 0.22, shine, P)  # chaque tuile reste sur un seul étage
    I.on_face(kit, x, 0, 0.84, -45, 0.55, 0.12, 0.12, shine, P)
    for angle, z in ((45, 0.75), (135, 0.95), (225, 0.7)):
        I.disc_on_face(kit, x, 0, 0.86, angle, z, 0.05, shine, P, thick=0.03)


def carotte(kit, x):
    P = "Carotte"
    orange = kit.mat("carotte", "#F25200", rough=0.45)
    ridge = kit.mat("carotte_fonce", "#D84A00", rough=0.4)
    green = kit.mat("fanes", "#3CCB3C", rough=0.35)
    green_dark = kit.mat("fanes_fonce", "#20962A", rough=0.4)
    # couchée le long de Y, la pointe vers l'avant (-Y), posée sur sa partie la plus grosse
    z = 0.45 * I.FACE
    y = 0.85
    sections = ((0.42, 0.3), (0.45, 0.36), (0.4, 0.4), (0.32, 0.38), (0.22, 0.32), (0.13, 0.3))
    for k, (r, length) in enumerate(sections):
        tip = 0.02 if k == len(sections) - 1 else None  # la pointe : un cône
        kit.add(I.octo(kit, r, length, (x, y - length / 2, z), rot=(90, 22.5, 0), top=tip), orange, P,
                bevel=min(0.04, length * 0.2))
        if r > 0.3:
            kit.add(I.octo(kit, r * 0.82 + 0.06, 0.05, (x, y - length, z), rot=(90, 22.5, 0)), ridge, P, bevel=0.01)
        y -= length
    kit.add(I.octo(kit, 0.18, 0.18, (x, 0.94, z), rot=(90, 22.5, 0)), green_dark, P, bevel=0.03)
    for k, (yaw, pitch, length) in enumerate(((-28, 35, 0.8), (0, 48, 0.95), (26, 32, 0.75), (-12, 62, 0.7),
                                               (14, 60, 0.72))):
        a, b = math.radians(yaw), math.radians(pitch)
        d = (math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), math.sin(b))
        c = (x + d[0] * length / 2, 1.0 + d[1] * length / 2, z + d[2] * length / 2)
        kit.add(kit.box((0.2 if k < 3 else 0.16, length, 0.07), center=c, rot=(pitch, 0, -yaw), taper=(0.5, 1.0)),
                green if k % 2 == 0 else green_dark, P, bevel=0.02)


def fromage(kit, x):
    P = "Fromage"
    cheese = kit.enamel("fromage", "#FFC81E")
    hole = kit.enamel("trous", "#E89400")
    rind = kit.enamel("croute", "#FFA81A")
    # part de fromage : triangle vu de dessus, pointe vers l'avant, croûte au dos
    kit.add(kit.box((1.9, 0.95, 2.0), center=(x, 0, 0.475), rot=(90, 0, 0), taper=(0.1, 1.0)), cheese, P, bevel=0.05)
    kit.add(kit.brick((1.92, 0.1, 0.97), center=(x, 1.02, 0.485)), rind, P, bevel=0.03)
    for dx, dy, r in ((-0.35, 0.55, 0.16), (0.42, 0.45, 0.12), (0.05, -0.15, 0.13), (-0.12, 0.85, 0.09),
                      (0.3, 0.05, 0.07)):
        kit.add(I.octo(kit, r, 0.05, (x + dx, dy, 0.955)), hole, P, bevel=0.01)
    for dx, z, r in ((-0.5, 0.35, 0.12), (0.35, 0.62, 0.1), (0.6, 0.25, 0.07)):
        kit.add(kit.disc(r, 0.05, center=(x + dx, 1.07, z), normal=(0, 1, 0), sides=8), hole, P, bevel=0.0)
    # trous à cheval sur les flancs (pastilles dans le plan des côtés)
    side = math.atan2(0.855, 2.0)
    for s, t, z in ((-1, 0.35, 0.5), (1, 0.6, 0.3), (1, 0.2, 0.62)):
        yy = -1 + 2 * t
        half = (0.19 + 0.855 * (yy + 1)) / 2
        kit.add(kit.disc(0.1, 0.05, center=(x + s * half, yy, z), normal=(s * math.cos(side), -math.sin(side), 0),
                         sides=8), hole, P, bevel=0.0)


def pot_de_miel(kit, x):
    P = "PotDeMiel"
    amber = kit.gem("pot_ambre", "#7A3A00", "#FF9A10", "#FFE4A0")
    honey = kit.enamel("miel", "#FFAE14")
    gold = kit.gold("or_miel", hammered=0.35, rough=0.28)
    wood = kit.mat("cuillere", "#B8742E", rough=0.55)
    label = kit.enamel("etiquette", "#FFF4D6")
    top = I.stack(kit, x, 0, [(0.5, 0.18, amber), (0.72, 0.3, amber), (0.82, 0.36, amber), (0.78, 0.3, amber),
                              (0.6, 0.18, amber)], P)
    kit.add(I.octo(kit, 0.66, 0.16, (x, 0, top + 0.06)), gold, P, bevel=0.03)
    kit.add(I.octo(kit, 0.64, 0.12, (x, 0, top + 0.2)), honey, P, bevel=0.03)
    kit.add(I.octo(kit, 0.16, 0.16, (x, 0, top + 0.34)), gold, P, bevel=0.03)
    kit.add(I.octo(kit, 0.52, 0.06, (x, 0, 0.03)), gold, P, bevel=0.01)
    # étiquette et alvéole d'or devant
    I.on_face(kit, x, 0, 0.82, 0, 0.66, 0.6, 0.42, label, P)
    kit.add(kit.disc(0.14, 0.05, center=(x, -0.82 * I.FACE - 0.06, 0.66), normal=(0, -1, 0), sides=6), gold, P,
            bevel=0.0)
    # coulures de miel depuis le couvercle
    # (sur le dernier étage, par-dessus le rebord, puis le long du ventre du pot)
    shoulder = top - 0.18
    for angle, length in ((-45, 0.3), (45, 0.2), (135, 0.34), (225, 0.24)):
        kit.add(kit.box((0.2, 0.08, 0.2), center=I.face_point(x, 0, 0.6, angle, top - 0.09, out=0.03),
                        rot=(0, 0, angle)), honey, P, bevel=0.02)
        kit.add(kit.box((0.2, 0.24, 0.07), center=I.face_point(x, 0, 0.6, angle, shoulder + 0.03, out=0.11),
                        rot=(0, 0, angle)), honey, P, bevel=0.02)
        kit.add(kit.box((0.2, 0.08, length), center=I.face_point(x, 0, 0.78, angle, shoulder - length / 2 + 0.05,
                                                                  out=0.03), rot=(0, 0, angle)), honey, P, bevel=0.02)
        kit.add(I.octo(kit, 0.11, 0.14, I.face_point(x, 0, 0.78, angle, shoulder - length + 0.03, out=0.06),
                       rot=(0, 0, angle + 22.5)), honey, P, bevel=0.03)
    # cuillère à miel plantée dans le couvercle, penchée
    d = (math.sin(math.radians(28)), 0.0, math.cos(math.radians(28)))
    base = (x + 0.15, 0.1, top + 0.2)
    at = lambda t: (base[0] + d[0] * t, base[1], base[2] + d[2] * t)  # noqa: E731
    kit.add(I.octo(kit, 0.05, 0.9, at(0.45), rot=(0, 28, 0)), wood, P, bevel=0.02)
    for t, r in ((0.74, 0.13), (0.84, 0.16), (0.94, 0.13)):
        kit.add(I.octo(kit, r, 0.08, at(t), rot=(0, 28, 0)), wood, P, bevel=0.02)


def trefle(kit, x):
    P = "Trefle"
    emerald = kit.gem("emeraude", "#03401C", "#18D45C", "#C8FFDC")
    pearl = kit.pearl("socle_nacre")
    gold = kit.gold("or_trefle", hammered=0.3, rough=0.28)
    # socle de nacre cerclé d'or
    kit.add(I.octo(kit, 0.62, 0.22, (x, 0, 0.11)), pearl, P, bevel=0.04)
    kit.add(I.octo(kit, 0.66, 0.08, (x, 0, 0.26)), gold, P, bevel=0.02)
    kit.add(I.octo(kit, 0.5, 0.16, (x, 0, 0.38)), pearl, P, bevel=0.03)
    # tige d'or un peu courbée
    kit.add(kit.brick((0.14, 0.14, 0.6), center=(x, 0, 0.74), rot=(0, 6, 0)), gold, P, bevel=0.03)
    kit.add(kit.brick((0.13, 0.13, 0.5), center=(x + 0.05, 0, 1.24), rot=(0, -8, 0)), gold, P, bevel=0.03)
    cz = 1.72
    # 4 feuilles en cœur (deux lobes chacune), dans le plan de face
    for k in range(4):
        a = math.radians(45 + 90 * k)
        dx, dz = math.cos(a), math.sin(a)
        px, pz = -dz, dx
        for s in (-1, 1):
            c = (x + dx * 0.4 + px * s * 0.13, 0, cz + dz * 0.4 + pz * s * 0.13)
            kit.add(kit.brick((0.34, 0.14, 0.34), center=c, rot=(0, -math.degrees(a) + 45 + s * 0, 0)), emerald, P,
                    bevel=0.03)
        tip = (x + dx * 0.2, -0.02, cz + dz * 0.2)
        kit.add(kit.brick((0.26, 0.12, 0.26), center=tip, rot=(0, -math.degrees(a) + 45, 0)), emerald, P, bevel=0.03)
        # nervure d'or
        kit.add(kit.brick((0.5, 0.05, 0.04), center=(x + dx * 0.3, -0.09, cz + dz * 0.3), rot=(0, -math.degrees(a), 0)),
                gold, P, bevel=0.0)
    kit.add(kit.disc(0.12, 0.2, center=(x, -0.02, cz), normal=(0, -1, 0), sides=8), gold, P, bevel=0.0)


def ruche(kit, x):
    P = "RucheDOr"
    gold = kit.gold("or_ruche", hammered=0.45, rough=0.25)
    gold2 = kit.gold("or_ruche_fonce", tint="#E8961A", hammered=0.5, rough=0.3)
    door = kit.enamel("entree", "#4A2410")
    bee = kit.enamel("abeille", "#FFD21E")
    black = kit.enamel("rayures", "#1E1A22")
    wing = kit.pearl("ailes")
    amber = kit.gem("goutte_miel", "#7A3A00", "#FF9A10", "#FFE4A0")
    kit.add(I.octo(kit, 0.92, 0.12, (x, 0, 0.06)), gold2, P, bevel=0.03)
    layers = [(0.76, 0.28), (0.84, 0.3), (0.82, 0.3), (0.74, 0.28), (0.62, 0.26), (0.46, 0.22), (0.28, 0.16)]
    top = I.stack(kit, x, 0, [(r, h, gold if k % 2 == 0 else gold2) for k, (r, h) in enumerate(layers)], P, z0=0.12)
    kit.add(I.octo(kit, 0.12, 0.14, (x, 0, top + 0.07)), gold2, P, bevel=0.03)
    # entrée de la ruche et son perchoir
    kit.add(kit.disc(0.2, 0.06, center=(x, -0.76 * I.FACE - 0.02, 0.36), normal=(0, -1, 0), sides=8), door, P,
            bevel=0.0)
    kit.add(kit.brick((0.5, 0.18, 0.06), center=(x, -0.8, 0.17)), gold2, P, bevel=0.02)
    # goutte de miel en ambre
    c = I.face_point(x, 0, 0.62, 60, 1.25, out=0.03)
    kit.add(kit.box((0.14, 0.08, 0.36), center=c, rot=(0, 0, 60)), amber, P, bevel=0.02)
    kit.add(I.octo(kit, 0.1, 0.12, I.face_point(x, 0, 0.62, 60, 1.03, out=0.05)), amber, P, bevel=0.02)
    # deux abeilles posées sur la ruche
    for angle, z in ((-62, 0.95), (140, 0.62)):
        cx, cy, cz = I.face_point(x, 0, 0.84, angle, z, out=0.14)
        rot = (0, 0, angle + 90)
        kit.add(kit.brick((0.32, 0.2, 0.2), center=(cx, cy, cz), rot=rot), bee, P, bevel=0.04)
        for off in (-0.06, 0.06):
            a = math.radians(angle + 90)
            kit.add(kit.brick((0.05, 0.22, 0.22), center=(cx + math.cos(a) * off, cy + math.sin(a) * off, cz), rot=rot),
                    black, P, bevel=0.01)
        a = math.radians(angle + 90)
        kit.add(kit.brick((0.12, 0.17, 0.17), center=(cx + math.cos(a) * 0.2, cy + math.sin(a) * 0.2, cz), rot=rot),
                black, P, bevel=0.02)
        for s in (-1, 1):
            kit.add(kit.box((0.2, 0.12, 0.03), center=(cx, cy, cz + 0.13), rot=(0, s * 25, angle + 90 + s * 20)), wing,
                    P, bevel=0.0)


def build(name: str) -> dict:
    kit = PetKit(name)
    for index, maker in enumerate((pomme, carotte, fromage, pot_de_miel, trefle, ruche)):
        maker(kit, I.slot(index))
    return kit.result()
