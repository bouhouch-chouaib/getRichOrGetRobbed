"""Objets à jeter du Cosmos (26 oct.) : roche lunaire, casque d'astronaute, fusée, planète à anneaux, soucoupe
volante, météorite d'or.

Du plus courant au plus précieux (Config.WorldItems.Cosmos) : plastique (roche, casque), émail + chrome (fusée), or
martelé (anneaux de la planète), nacre + cristal + or (soucoupe), or massif + améthystes (météorite). Base : _items.py.
"""

import math

import _items as I
from pet_kit import PetKit


def lumps(kit, x, chunks, mats, part, bevel=0.07):
    """Caillou en blocs de travers : chunks = [((taille), (dx, dy, z), (rotation))]."""
    for k, (size, (dx, dy, z), rot) in enumerate(chunks):
        kit.add(kit.brick(size, center=(x + dx, dy, z), rot=rot), mats[k % len(mats)], part, bevel=bevel)


ROCK = [((0.95, 0.85, 0.72), (0, 0, 0.36), (4, 6, 10)), ((0.64, 0.7, 0.58), (0.46, 0.14, 0.3), (-8, 5, 32)),
        ((0.6, 0.55, 0.52), (-0.44, -0.18, 0.28), (10, -6, -18)), ((0.55, 0.52, 0.44), (0.04, 0.06, 0.8), (16, 8, 36)),
        ((0.44, 0.48, 0.38), (-0.18, 0.4, 0.24), (0, 12, 58))]


def roche_lunaire(kit, x):
    P = "RocheLunaire"
    grey = kit.mat("lune", "#B4B6C4", rough=0.6)
    grey2 = kit.mat("lune_fonce", "#8A8C9A", rough=0.65)
    crater = kit.mat("crateres", "#5A5C68", rough=0.7)
    I.ball(kit, (x, 0, 0.8), 0.8, [grey2, grey, grey2, grey, grey2, grey], P, n=6, power=0.95)
    # cratères : pastille sombre dans un anneau clair, sur les faces des étages (rayon des coins de chaque étage)
    # (chaque cratère reste dans la hauteur d'un étage, sinon il dépasse de l'étage voisin, plus étroit)
    for angle, layer, r in ((0, 2, 0.1), (45, 3, 0.09), (135, 1, 0.08), (225, 3, 0.1), (270, 2, 0.07), (315, 2, 0.06),
                            (90, 3, 0.08), (180, 2, 0.09)):
        t = -1 + (layer + 0.5) * 2 / 6
        rk = 0.8 * max(0.42, math.sqrt(1 - t * t) ** 0.95)  # comme I.ball
        z = (layer + 0.5) * 1.6 / 6
        I.disc_on_face(kit, x, 0, rk, angle, z, r + 0.03, grey, P, thick=0.04)
        I.disc_on_face(kit, x, 0, rk, angle, z, r, crater, P, thick=0.07)
    for dx, dy, r in ((0.1, -0.08, 0.14), (-0.18, 0.16, 0.08)):
        kit.add(I.octo(kit, r + 0.05, 0.04, (x + dx, dy, 1.6 + 0.01)), grey, P, bevel=0.0)
        kit.add(I.octo(kit, r, 0.06, (x + dx, dy, 1.6 + 0.02)), crater, P, bevel=0.0)


def casque(kit, x):
    P = "Casque"
    white = kit.mat("casque", "#F4F6FA", rough=0.3)
    grey = kit.mat("casque_gris", "#8A92A4", rough=0.35)
    visor = kit.mat("visiere", "#1A2A72", rough=0.08)
    shine = kit.mat("visiere_reflet", "#8AB0FF", rough=0.1)
    red = kit.mat("antenne", "#F01E2E", rough=0.3)
    kit.add(I.octo(kit, 0.6, 0.22, (x, 0, 0.11)), grey, P, bevel=0.04)
    I.ball(kit, (x, 0, 0.92), 0.76, white, P, n=5)
    kit.add(kit.box((0.96, 0.24, 0.62), center=(x, -0.68, 0.95), taper=(0.9, 1.0)), visor, P, bevel=0.06)
    kit.add(kit.box((0.2, 0.04, 0.12), center=(x - 0.22, -0.81, 1.1), rot=(0, 30, 0)), shine, P, bevel=0.0)
    kit.add(kit.box((0.1, 0.04, 0.08), center=(x - 0.05, -0.81, 1.15), rot=(0, 30, 0)), shine, P, bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.brick((0.16, 0.36, 0.36), center=(x + s * 0.74, 0, 0.92)), grey, P, bevel=0.05)
    kit.add(kit.brick((0.05, 0.05, 0.42), center=(x + 0.36, 0.2, 1.75)), grey, P, bevel=0.0)
    kit.add(I.octo(kit, 0.08, 0.14, (x + 0.36, 0.2, 1.99)), red, P, bevel=0.02)


def fusee(kit, x):
    P = "Fusee"
    white = kit.enamel("fusee", "#F6F7FC")
    red = kit.enamel("fusee_rouge", "#F01E2E")
    chrome = kit.chrome("chrome_fusee")
    window = kit.gem("hublot", "#02204A", "#3AA8FF", "#E0F4FF")
    # tuyère, corps, bandes, nez
    kit.add(I.octo(kit, 0.24, 0.3, (x, 0, 0.2), top=0.32), chrome, P, bevel=0.03)
    top = I.stack(kit, x, 0, [(0.44, 0.5, white), (0.45, 0.1, red), (0.44, 0.45, white), (0.45, 0.1, red),
                              (0.42, 0.3, white)], P, z0=0.35)
    kit.add(I.octo(kit, 0.42, 0.62, (x, 0, top + 0.31), top=0.03), red, P, bevel=0.03)
    # hublot cerclé de chrome
    I.disc_on_face(kit, x, 0, 0.44, 0, 1.25, 0.21, chrome, P, thick=0.05)
    I.disc_on_face(kit, x, 0, 0.44, 0, 1.25, 0.15, window, P, thick=0.09)
    # quatre ailerons de chrome jusqu'au sol
    for angle in (45, 135, 225, 315):
        a = math.radians(angle)
        d = (math.sin(a), -math.cos(a))
        c = (x + d[0] * 0.6, d[1] * 0.6, 0.38)
        kit.add(kit.box((0.08, 0.48, 0.76), center=c, rot=(0, 0, angle), taper=(1.0, 0.35), shift=(0.0, 0.12)), chrome,
                P, bevel=0.02)
    # rivets
    for angle in (45, 135, 225, 315):
        I.disc_on_face(kit, x, 0, 0.45, angle, 0.95, 0.04, chrome, P, thick=0.04)


def planete(kit, x):
    P = "Planete"
    purple = kit.enamel("planete", "#8A3AE6")
    lilac = kit.enamel("planete_clair", "#C482FF")
    pink = kit.enamel("planete_rose", "#FF6EC8")
    gold = kit.gold("or_anneau", hammered=0.45, rough=0.25)
    gold2 = kit.gold("or_anneau_fonce", tint="#E8961A", hammered=0.5, rough=0.3)
    I.ball(kit, (x, 0, 0.78), 0.66, [purple, lilac, pink, purple, pink, lilac, purple], P, n=7, power=1.0)
    I.ring(kit, (x, 0, 0.78), 1.0, 0.07, 0.24, gold, P, n=16, rot=(18, 0, 0))
    I.ring(kit, (x, 0, 0.78), 0.78, 0.06, 0.12, gold2, P, n=16, rot=(18, 0, 0))


def soucoupe(kit, x):
    P = "Soucoupe"
    pearl = kit.pearl("coque_soucoupe", color="#F2F0FA", sheen="#C8E0FF")
    gold = kit.gold("or_soucoupe", hammered=0.3, rough=0.24)
    dome = kit.gem("dome", "#04304A", "#3AD0FF", "#E8FCFF")
    lights = [kit.enamel("feu_" + c, c) for c in ("#FF3A4A", "#FFD21E", "#2E9BFF")]
    # trois pieds
    for k in range(3):
        a = math.radians(90 + 120 * k)
        px, py = x + math.cos(a) * 0.55, math.sin(a) * 0.55
        kit.add(kit.brick((0.1, 0.1, 0.32), center=(px, py, 0.2), rot=(0, 0, 0)), gold, P, bevel=0.02)
        kit.add(I.octo(kit, 0.12, 0.06, (px, py, 0.03)), gold, P, bevel=0.01)
    top = I.stack(kit, x, 0, [(0.46, 0.12, pearl), (0.92, 0.12, pearl), (1.16, 0.1, gold), (0.96, 0.12, pearl),
                              (0.62, 0.1, pearl)], P, z0=0.32)
    # feux colorés (émail, sans lueur) autour du bord d'or
    for k, angle in enumerate(range(0, 360, 45)):
        I.disc_on_face(kit, x, 0, 1.16, angle, 0.32 + 0.24 + 0.05, 0.06, lights[k % 3], P, thick=0.05)
    I.stack(kit, x, 0, [(0.52, 0.16, dome), (0.46, 0.14, dome), (0.34, 0.12, dome), (0.18, 0.08, dome)], P, z0=top)
    kit.add(I.octo(kit, 0.54, 0.05, (x, 0, top + 0.02)), gold, P, bevel=0.01)


def meteorite(kit, x):
    P = "Meteorite"
    gold = kit.gold("or_meteorite", hammered=0.6, rough=0.26)
    gold2 = kit.gold("or_meteorite_fonce", tint="#E8961A", hammered=0.6, rough=0.32)
    amethyst = kit.gem("amethyste", "#2A0050", "#A040FF", "#F0D8FF")
    lumps(kit, x, [((s[0] * 1.15, s[1] * 1.15, s[2] * 1.15), (p[0] * 1.15, p[1] * 1.15, p[2] * 1.15), r)
                   for s, p, r in ROCK], [gold, gold2], P, bevel=0.08)
    # grappes d'améthystes qui sortent de la roche
    for (bx, by, bz), crystals in (((0.1, -0.05, 1.05), ((0, 0, 0.8, 0.3), (28, 30, 0.55, 0.22), (-30, -40, 0.5, 0.2))),
                                   ((0.62, -0.2, 0.55), ((62, 0, 0.6, 0.24), (42, 40, 0.42, 0.18))),
                                   ((-0.58, -0.3, 0.45), ((-58, -10, 0.56, 0.22), (-36, -60, 0.4, 0.17)))):
        for tilt, yaw, h, w in crystals:
            kit.add(kit.box((w, w, h), center=(0, 0, h / 2), taper=(0.08, 0.08)), amethyst, P, bevel=0.01)
            obj = kit.items[-1][0]
            I.placed(obj, (x + bx, by, bz), (0, tilt, yaw))


def build(name: str) -> dict:
    kit = PetKit(name)
    for index, maker in enumerate((roche_lunaire, casque, fusee, planete, soucoupe, meteorite)):
        maker(kit, I.slot(index))
    return kit.result()
