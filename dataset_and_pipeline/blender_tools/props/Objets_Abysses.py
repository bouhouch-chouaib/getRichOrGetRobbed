"""Objets à jeter des Abysses (26 oct.) : coquillage, étoile de mer, ancre, coffre au trésor, huître perlière, trident
d'or.

Du plus courant au plus précieux (Config.WorldItems.Abysses) : plastique (coquillage, étoile de mer), chrome + corde
(ancre), bois cerclé d'or martelé (coffre), nacre + grosse perle (huître), or massif + aigues-marines (trident).
Base : _items.py.
"""

import math

import _items as I
from pet_kit import PetKit


def coquillage(kit, x):
    P = "Coquillage"
    pink = kit.mat("coquille_rose", "#FF6E8A", rough=0.35)
    peach = kit.mat("coquille_peche", "#FFAA70", rough=0.35)
    hinge = kit.mat("charniere", "#E0506A", rough=0.4)
    # éventail de 7 côtes qui partent de la charnière (+Y) vers l'avant, plus hautes au milieu
    hy = 0.62
    for k in range(7):
        yaw = -63 + k * 21
        a = math.radians(yaw)
        d = (math.sin(a), -math.cos(a))
        length = 1.2 - abs(k - 3) * 0.06
        thick = 0.42 - abs(k - 3) * 0.06
        c = (x + d[0] * length / 2, hy + d[1] * length / 2, thick / 2)
        kit.add(kit.box((0.2, thick, length), center=c, rot=(90, 0, yaw), taper=(1.9, 1.0)), pink if k % 2 else peach,
                P, bevel=0.05)
    for s in (-1, 1):
        kit.add(kit.box((0.36, 0.26, 0.2), center=(x + s * 0.22, hy + 0.08, 0.1), taper=(0.7, 1.0)), hinge, P,
                bevel=0.04)


def etoile_de_mer(kit, x):
    P = "EtoileDeMer"
    orange = kit.mat("etoile", "#FF5A28", rough=0.35)
    bumps = kit.mat("etoile_points", "#FFC060", rough=0.35)
    center = kit.mat("etoile_centre", "#E83E1A", rough=0.4)
    kit.add(I.octo(kit, 0.4, 0.34, (x, 0, 0.17)), center, P, bevel=0.05)
    for k in range(5):
        a = math.radians(72 * k)
        d = (math.sin(a), -math.cos(a))
        c = (x + d[0] * 0.62, d[1] * 0.62, 0.15)
        kit.add(kit.box((0.4, 0.28, 0.9), center=c, rot=(90, 0, 72 * k), taper=(0.3, 0.55)), orange, P, bevel=0.05)
        for t in (0.35, 0.6, 0.85):
            kit.add(I.octo(kit, 0.07 - t * 0.03, 0.06, (x + d[0] * t, d[1] * t, 0.29 - t * 0.1)), bumps, P, bevel=0.0)
    kit.add(I.octo(kit, 0.12, 0.06, (x, 0, 0.36)), bumps, P, bevel=0.0)


def ancre(kit, x):
    P = "Ancre"
    steel = kit.chrome("acier_ancre", tint="#D6DEEA")
    rope = kit.mat("corde", "#D8A860", rough=0.7)
    rope2 = kit.mat("corde_fonce", "#A87830", rough=0.75)
    # tige, jas (barre du haut), anneau
    kit.add(kit.brick((0.22, 0.26, 1.8), center=(x, 0, 1.12)), steel, P, bevel=0.04)
    kit.add(kit.brick((1.1, 0.22, 0.2), center=(x, 0, 1.78)), steel, P, bevel=0.04)
    for s in (-1, 1):
        kit.add(I.octo(kit, 0.12, 0.24, (x + s * 0.6, 0, 1.78), rot=(0, 90, 0)), steel, P, bevel=0.02)
    I.ring(kit, (x, 0, 2.2), 0.17, 0.12, 0.08, steel, P, n=8, rot=(90, 0, 0))
    # couronne et bras recourbés, pattes en pointe
    kit.add(kit.brick((0.44, 0.3, 0.3), center=(x, 0, 0.24)), steel, P, bevel=0.05)
    for s in (-1, 1):
        kit.add(kit.brick((0.62, 0.26, 0.2), center=(x + s * 0.42, 0, 0.3), rot=(0, -s * 25, 0)), steel, P, bevel=0.04)
        kit.add(kit.brick((0.2, 0.26, 0.42), center=(x + s * 0.74, 0, 0.62), rot=(0, s * 12, 0)), steel, P,
                bevel=0.04)
        kit.add(kit.box((0.36, 0.3, 0.36), center=(x + s * 0.8, 0, 0.92), rot=(0, s * 20, 0), taper=(0.08, 0.6)), steel,
                P, bevel=0.03)
    # corde enroulée autour de la tige, un bout qui pend
    for k, z in enumerate((1.25, 1.38, 1.51)):
        kit.add(kit.brick((0.32, 0.36, 0.1), center=(x, 0, z), rot=(14 if k % 2 else -14, 0, 0)), rope if k % 2 else
                rope2, P, bevel=0.03)
    kit.add(kit.brick((0.09, 0.09, 0.5), center=(x + 0.2, -0.12, 1.08), rot=(0, -12, 0)), rope, P, bevel=0.02)


def coffre(kit, x):
    P = "Coffre"
    wood = kit.mat("bois_coffre", "#9A5424", rough=0.55)
    wood_dark = kit.mat("bois_coffre_fonce", "#6A3414", rough=0.6)
    gold = kit.gold("or_coffre", hammered=0.45, rough=0.26)
    coin = kit.gold("pieces", hammered=0.2, rough=0.22)
    ruby = kit.gem("rubis_coffre", "#3A0008", "#F01E3C", "#FFD0D8")
    pearl = kit.pearl("perle_coffre")
    lock = kit.enamel("serrure", "#2A1A10")
    # caisse avec ses planches
    kit.add(kit.brick((1.6, 1.1, 0.8), center=(x, 0, 0.45)), wood, P, bevel=0.05)
    for z in (0.3, 0.58):
        kit.add(kit.brick((1.62, 1.12, 0.04), center=(x, 0, z)), wood_dark, P, bevel=0.0)
    kit.add(kit.brick((1.66, 1.16, 0.1), center=(x, 0, 0.05)), gold, P, bevel=0.03)
    # cerclages et coins d'or sur la caisse
    for dx in (-0.55, 0.55):
        kit.add(kit.brick((0.14, 1.16, 0.84), center=(x + dx, 0, 0.45)), gold, P, bevel=0.02)
    kit.add(kit.brick((0.3, 0.06, 0.36), center=(x, -0.57, 0.66)), gold, P, bevel=0.02)
    kit.add(kit.brick((0.08, 0.03, 0.14), center=(x, -0.61, 0.64)), lock, P, bevel=0.0)
    # trésor qui dépasse : pièces, rubis, perle
    for k, (dx, dy, n) in enumerate(((-0.4, 0.0, 3), (-0.1, -0.15, 4), (0.25, 0.1, 3), (0.5, -0.2, 2), (0.05, 0.25, 2))):
        for j in range(n):
            kit.add(I.octo(kit, 0.13, 0.05, (x + dx + j * 0.015, dy, 0.88 + j * 0.055)), coin, P, bevel=0.0)
    kit.add(kit.box((0.2, 0.2, 0.2), center=(x - 0.2, 0.18, 0.98), rot=(0, 0, 45), taper=(0.1, 0.1)), ruby, P,
            bevel=0.01)
    I.pearl(kit, (x + 0.35, -0.12, 1.02), 0.12, pearl, P)
    # couvercle entrouvert : il tourne de 32° autour de la charnière arrière
    hinge = (0.55, 0.85)
    ang = -32.0
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))

    def lid(size, ly, lz, mat, bevel=0.04, dx=0.0):
        y = hinge[0] + ly * ca - lz * sa
        z = hinge[1] + ly * sa + lz * ca
        kit.add(kit.brick(size, center=(x + dx, y, z), rot=(ang, 0, 0)), mat, P, bevel=bevel)

    lid((1.62, 1.12, 0.22), -0.56, 0.11, wood)
    lid((1.62, 0.9, 0.16), -0.56, 0.3, wood)
    lid((1.62, 0.56, 0.12), -0.56, 0.44, wood)
    for dx in (-0.55, 0.55):
        lid((0.14, 1.14, 0.26), -0.56, 0.11, gold, 0.02, dx)
        lid((0.14, 0.92, 0.2), -0.56, 0.3, gold, 0.02, dx)
    lid((0.3, 0.06, 0.2), -1.12, 0.1, gold, 0.02)


def huitre(kit, x):
    P = "Huitre"
    shell = kit.enamel("coquille_huitre", "#4A5A84")
    shell2 = kit.enamel("coquille_huitre_clair", "#7A8CB8")
    nacre = kit.pearl("nacre_huitre", color="#F4ECF8", sheen="#BFE8FF")
    pearl = kit.pearl("grosse_perle", color="#FFF8FC", sheen="#FFD8F0")
    gold = kit.gold("or_huitre", hammered=0.3, rough=0.26)
    # coquille du dessous, nacre, perle
    kit.add(I.octo(kit, 0.82, 0.16, (x, 0, 0.08)), shell, P, bevel=0.04)
    kit.add(I.octo(kit, 0.92, 0.14, (x, 0, 0.23)), shell2, P, bevel=0.04)
    kit.add(I.octo(kit, 0.8, 0.06, (x, 0, 0.31)), nacre, P, bevel=0.015)
    kit.add(I.octo(kit, 0.3, 0.06, (x, -0.05, 0.36)), gold, P, bevel=0.015)
    I.pearl(kit, (x, -0.05, 0.8), 0.44, pearl, P)
    # coquille du dessus ouverte (charnière à l'arrière)
    hinge = (0.82, 0.3)
    ang = -58.0
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))

    def top(r, h, ly, lz, mat, bevel=0.04):
        y = hinge[0] + ly * ca - lz * sa
        z = hinge[1] + ly * sa + lz * ca
        kit.add(I.octo(kit, r, h, (x, y, z), rot=(ang, 0, 0)), mat, P, bevel=bevel)

    top(0.88, 0.14, -0.82, 0.14, shell2)
    top(0.78, 0.12, -0.82, 0.27, shell)
    top(0.55, 0.08, -0.82, 0.37, shell2)
    top(0.78, 0.05, -0.82, 0.04, nacre, 0.015)


def trident(kit, x):
    P = "Trident"
    gold = kit.gold("or_trident", hammered=0.35, rough=0.22)
    gold2 = kit.gold("or_trident_fonce", tint="#E8961A", hammered=0.45, rough=0.28)
    aqua = kit.gem("aigue_marine", "#00304A", "#20D0F0", "#D8FAFF")
    stone = kit.enamel("rocher", "#1E3A6A")
    coral = kit.enamel("corail", "#FF6A7A")
    # rocher et corail au pied
    kit.add(I.octo(kit, 0.56, 0.24, (x, 0, 0.12)), stone, P, bevel=0.05)
    kit.add(I.octo(kit, 0.6, 0.06, (x, 0, 0.27)), gold2, P, bevel=0.015)
    for dx, dy, h, rot in ((0.32, 0.18, 0.4, (0, 15, 20)), (0.4, 0.06, 0.26, (0, 35, 0)), (-0.36, -0.16, 0.32,
                                                                                         (10, -20, 0))):
        kit.add(kit.brick((0.09, 0.09, h), center=(x + dx, dy, 0.3 + h / 2), rot=rot), coral, P, bevel=0.02)
    # hampe, bague d'aigue-marine, traverse, trois dents
    kit.add(kit.brick((0.13, 0.13, 1.3), center=(x, 0, 0.95)), gold, P, bevel=0.03)
    kit.add(I.octo(kit, 0.12, 0.08, (x, 0, 0.62)), gold2, P, bevel=0.015)
    kit.add(I.octo(kit, 0.15, 0.2, (x, 0, 1.66)), aqua, P, bevel=0.03)
    kit.add(kit.brick((0.86, 0.15, 0.15), center=(x, 0, 1.82)), gold, P, bevel=0.03)
    kit.add(kit.brick((0.14, 0.14, 0.5), center=(x, 0, 2.12)), gold, P, bevel=0.03)
    kit.add(kit.spike((x, 0, 2.36), (0, 0, 1), 0.3, 0.2), gold, P, bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.brick((0.13, 0.13, 0.42), center=(x + s * 0.39, 0, 2.06)), gold, P, bevel=0.03)
        kit.add(kit.spike((x + s * 0.39, 0, 2.26), (s * 0.12, 0, 1), 0.26, 0.18), gold, P, bevel=0.0)
        kit.add(kit.spike((x + s * 0.39, 0, 2.0), (s * 0.7, 0, -0.7), 0.16, 0.1), gold2, P, bevel=0.0)
        kit.add(kit.disc(0.06, 0.05, center=(x + s * 0.22, -0.09, 1.82), normal=(0, -1, 0), sides=8), aqua, P,
                bevel=0.0)


def build(name: str) -> dict:
    kit = PetKit(name)
    for index, maker in enumerate((coquillage, etoile_de_mer, ancre, coffre, huitre, trident)):
        maker(kit, I.slot(index))
    return kit.result()
