"""Objets à jeter du Désert (26 oct.) : cactus en pot, cruche, scarabée, lampe magique, chat sacré, pyramide d'or.

Du plus courant au plus précieux (Config.WorldItems.Desert) : plastique (cactus, cruche), turquoise + chrome
(scarabée), or martelé (lampe), émail noir + or sur nacre (chat), or massif + saphir (pyramide). Base : _items.py.
"""

import math

import _items as I
from pet_kit import PetKit


def cactus(kit, x):
    P = "Cactus"
    pot = kit.mat("pot", "#E0703A", rough=0.5)
    pot_dark = kit.mat("pot_fonce", "#B84E24", rough=0.55)
    band = kit.mat("pot_bande", "#2E9BE6", rough=0.35)
    soil = kit.mat("terre", "#5A3420", rough=0.8)
    green = kit.mat("cactus", "#2EB848", rough=0.4)
    green_dark = kit.mat("cactus_fonce", "#22A23E", rough=0.45)
    spine = kit.mat("epines", "#FFF8E0", rough=0.3)
    petal = kit.mat("fleur", "#FF4FA0", rough=0.3)
    heart = kit.mat("coeur_fleur", "#FFD21E", rough=0.3)
    top = I.stack(kit, x, 0, [(0.44, 0.12, pot_dark), (0.48, 0.42, pot), (0.58, 0.14, pot_dark)], P)
    kit.add(I.octo(kit, 0.49, 0.08, (x, 0, 0.36)), band, P, bevel=0.015)
    kit.add(I.octo(kit, 0.46, 0.04, (x, 0, top + 0.0)), soil, P, bevel=0.01)
    # colonne et bras
    cz = top + 0.6
    kit.add(kit.brick((0.52, 0.52, 1.2), center=(x, 0, cz)), green, P, bevel=0.08)
    kit.add(kit.brick((0.42, 0.42, 0.14), center=(x, 0, cz + 0.66)), green, P, bevel=0.05)
    for s in (-1, 1):
        kit.add(kit.brick((0.08, 0.56, 1.1), center=(x + s * 0.24, 0, cz)), green_dark, P, bevel=0.02)
        # (décalée et plus étroite : ses faces ne se confondent pas avec l'autre arête, sinon le coin cuit en noir)
        kit.add(kit.brick((0.54, 0.08, 1.1), center=(x, s * 0.25, cz)), green_dark, P, bevel=0.02)
    for s, z, reach, up in ((1, top + 0.75, 0.5, 0.5), (-1, top + 0.5, 0.42, 0.38)):
        kit.add(kit.brick((reach, 0.34, 0.3), center=(x + s * (0.26 + reach / 2 - 0.05), 0, z)), green, P, bevel=0.06)
        ax = x + s * (0.26 + reach - 0.12)
        kit.add(kit.brick((0.32, 0.32, up), center=(ax, 0, z + up / 2 + 0.05)), green, P, bevel=0.06)
        kit.add(kit.brick((0.06, 0.34, up * 0.9), center=(ax + s * 0.14, 0, z + up / 2 + 0.05)), green_dark, P,
                bevel=0.01)
    # épines (petites briques claires) devant et derrière
    for dx, dz in ((-0.14, 0.2), (0.12, 0.45), (-0.1, 0.75), (0.14, 1.0), (0.0, 0.62)):
        for sy in (-1, 1):
            kit.add(kit.brick((0.04, 0.12, 0.04), center=(x + dx, sy * 0.3, top + dz), rot=(sy * 20, 0, 0)), spine, P,
                    bevel=0.0)
    # fleur rose au sommet
    fz = cz + 0.76
    for k in range(5):
        a = math.radians(72 * k)
        kit.add(kit.box((0.2, 0.14, 0.08), center=(x + math.cos(a) * 0.13, math.sin(a) * 0.13, fz),
                        rot=(0, -20, math.degrees(a))), petal, P, bevel=0.02)
    kit.add(I.octo(kit, 0.08, 0.1, (x, 0, fz + 0.04)), heart, P, bevel=0.02)


def cruche(kit, x):
    P = "Cruche"
    clay = kit.mat("terre_cuite", "#E8843E", rough=0.5)
    clay_dark = kit.mat("terre_cuite_fonce", "#C0602A", rough=0.55)
    blue = kit.mat("peinture_bleue", "#1E8CE6", rough=0.35)
    white = kit.mat("peinture_blanche", "#FFF6E6", rough=0.35)
    layers = [(0.32, 0.12, clay_dark), (0.24, 0.1, clay_dark), (0.5, 0.22, clay), (0.68, 0.3, clay), (0.72, 0.3, clay),
              (0.62, 0.24, clay), (0.4, 0.14, clay), (0.25, 0.3, clay), (0.36, 0.1, clay_dark)]
    top = I.stack(kit, x, 0, layers, P)
    kit.add(I.octo(kit, 0.73, 0.1, (x, 0, 0.74)), blue, P, bevel=0.02)
    kit.add(I.octo(kit, 0.635, 0.06, (x, 0, 1.22)), blue, P, bevel=0.015)
    # losanges blancs peints tout autour
    for angle in range(0, 360, 45):
        c = I.face_point(x, 0, 0.72, angle, 0.92, out=0.015)
        kit.add(kit.box((0.14, 0.03, 0.14), center=c, rot=(0, 45, angle)), white, P, bevel=0.0)
    # deux anses du col à l'épaule
    for s in (-1, 1):
        kit.add(kit.brick((0.34, 0.14, 0.12), center=(x + s * 0.38, 0, 1.6)), clay_dark, P, bevel=0.03)
        kit.add(kit.brick((0.12, 0.14, 0.48), center=(x + s * 0.52, 0, 1.36)), clay_dark, P, bevel=0.03)
        kit.add(kit.brick((0.16, 0.14, 0.12), center=(x + s * 0.5, 0, 1.12)), clay_dark, P, bevel=0.03)
    del top


def scarabee(kit, x):
    P = "Scarabee"
    turq = kit.enamel("turquoise", "#16CDBE")
    chrome = kit.chrome("chrome_scarabee")
    blue = kit.enamel("lapis", "#1E3CC8")
    sun = kit.enamel("soleil_rouge", "#FF4A1E")
    # carapace (deux élytres de turquoise, couture de chrome), dos bombé
    for s in (-1, 1):
        kit.add(kit.box((0.5, 1.1, 0.4), center=(x + s * 0.27, 0.15, 0.36), taper=(0.75, 0.92)), turq, P, bevel=0.06)
        kit.add(kit.box((0.36, 0.86, 0.12), center=(x + s * 0.24, 0.17, 0.6), taper=(0.7, 0.85)), turq, P, bevel=0.04)
    kit.add(kit.brick((0.07, 1.12, 0.5), center=(x, 0.15, 0.4)), chrome, P, bevel=0.02)
    kit.add(kit.box((1.08, 0.1, 0.36), center=(x, 0.72, 0.32), taper=(0.8, 1.0)), chrome, P, bevel=0.02)
    # corselet, tête, cornes
    kit.add(kit.box((0.86, 0.42, 0.38), center=(x, -0.6, 0.34), taper=(0.85, 0.8)), blue, P, bevel=0.06)
    kit.add(kit.brick((0.5, 0.3, 0.26), center=(x, -0.92, 0.3)), chrome, P, bevel=0.05)
    for s in (-1, 1):
        kit.add(kit.box((0.08, 0.26, 0.08), center=(x + s * 0.16, -1.1, 0.36), rot=(25, 0, s * 18)), chrome, P,
                bevel=0.0)
    # six pattes de chrome
    for k, y in enumerate((-0.6, -0.1, 0.4)):
        for s in (-1, 1):
            kit.add(kit.box((0.3, 0.09, 0.09), center=(x + s * 0.6, y, 0.15), rot=(0, s * 35, s * (k - 1) * 18)),
                    chrome, P, bevel=0.0)
            kit.add(kit.brick((0.1, 0.14, 0.08), center=(x + s * 0.72, y + (k - 1) * 0.05, 0.04)), chrome, P,
                    bevel=0.0)
    # le soleil qu'il pousse
    kit.add(kit.disc(0.19, 0.12, center=(x, -1.2, 0.3), normal=(0, -1, 0), sides=8), sun, P, bevel=0.0)
    kit.add(kit.disc(0.22, 0.06, center=(x, -1.13, 0.3), normal=(0, -1, 0), sides=8), chrome, P, bevel=0.0)


def lampe(kit, x):
    P = "Lampe"
    gold = kit.gold("or_lampe", hammered=0.45, rough=0.25)
    gold2 = kit.gold("or_lampe_fonce", tint="#E8961A", hammered=0.5, rough=0.3)
    ruby = kit.gem("rubis_lampe", "#3A0008", "#F01E3C", "#FFD0D8")
    dark = kit.enamel("bec", "#2A1A10")
    top = I.stack(kit, x, 0.15, [(0.42, 0.1, gold2), (0.3, 0.08, gold2), (0.62, 0.16, gold), (0.76, 0.22, gold),
                                 (0.68, 0.16, gold), (0.48, 0.1, gold2)], P)
    kit.add(I.octo(kit, 0.34, 0.12, (x, 0.15, top + 0.06)), gold, P, bevel=0.03)
    kit.add(I.octo(kit, 0.14, 0.16, (x, 0.15, top + 0.2)), gold2, P, bevel=0.03)
    kit.add(I.octo(kit, 0.1, 0.16, (x, 0.15, top + 0.36), rot=(0, 0, 0)), ruby, P, bevel=0.02)
    # bec qui s'affine vers l'avant et monte un peu
    d = (0.0, -math.cos(math.radians(20)), math.sin(math.radians(20)))
    start = (x, 0.15 - 0.62, 0.42)
    c = (start[0], start[1] + d[1] * 0.55, start[2] + d[2] * 0.55)
    kit.add(kit.box((0.36, 0.28, 1.1), center=c, rot=(70, 0, 0), taper=(0.5, 0.55)), gold, P, bevel=0.04)
    tip = (x, start[1] + d[1] * 1.1, start[2] + d[2] * 1.1)
    kit.add(kit.disc(0.09, 0.05, center=tip, normal=d, sides=8), dark, P, bevel=0.0)
    # anse à l'arrière, recourbée
    kit.add(kit.brick((0.12, 0.42, 0.12), center=(x, 0.15 + 0.82, 0.62)), gold2, P, bevel=0.03)
    kit.add(kit.brick((0.12, 0.12, 0.42), center=(x, 0.15 + 0.98, 0.45)), gold2, P, bevel=0.03)
    kit.add(kit.brick((0.12, 0.36, 0.12), center=(x, 0.15 + 0.82, 0.26)), gold2, P, bevel=0.03)
    kit.add(kit.brick((0.12, 0.16, 0.16), center=(x, 0.15 + 0.98, 0.72)), gold2, P, bevel=0.03)
    # rubis tout autour du ventre
    for angle in (45, 90, 135, 225, 270, 315):
        I.disc_on_face(kit, x, 0.15, 0.76, angle, 0.45, 0.08, ruby, P, thick=0.06)


def chat_sacre(kit, x):
    P = "ChatSacre"
    black = kit.enamel("chat_noir", "#1E1A2C")
    pearl = kit.pearl("socle_sable", color="#F6EAD2", sheen="#FFE6B0")
    gold = kit.gold("or_chat", hammered=0.3, rough=0.26)
    eye = kit.gem("yeux_emeraude", "#043A1A", "#28E070", "#D8FFE6")
    lapis = kit.gem("lapis_chat", "#06103A", "#2A50E0", "#D0DCFF")
    nose = kit.enamel("truffe", "#4A3A50")
    kit.add(kit.brick((1.0, 1.3, 0.26), center=(x, 0, 0.13)), pearl, P, bevel=0.05)
    kit.add(kit.brick((1.04, 1.34, 0.06), center=(x, 0, 0.29)), gold, P, bevel=0.015)
    z0 = 0.32
    kit.add(kit.brick((0.8, 0.86, 0.5), center=(x, 0.15, z0 + 0.25)), black, P, bevel=0.08)
    kit.add(kit.box((0.54, 0.46, 0.92), center=(x, -0.1, z0 + 0.7), rot=(-6, 0, 0), taper=(0.85, 0.85)), black, P,
            bevel=0.07)
    for s in (-1, 1):
        kit.add(kit.brick((0.17, 0.18, 0.76), center=(x + s * 0.15, -0.3, z0 + 0.38)), black, P, bevel=0.04)
        kit.add(kit.brick((0.19, 0.26, 0.1), center=(x + s * 0.15, -0.36, z0 + 0.05)), black, P, bevel=0.03)
    # collier d'or et pendentif
    kit.add(kit.brick((0.56, 0.5, 0.12), center=(x, -0.1, z0 + 1.14)), gold, P, bevel=0.03)
    kit.add(kit.box((0.2, 0.06, 0.24), center=(x, -0.37, z0 + 1.0), taper=(0.3, 1.0), rot=(0, 180, 0)), gold, P,
            bevel=0.01)
    kit.add(kit.disc(0.07, 0.05, center=(x, -0.41, z0 + 1.02), normal=(0, -1, 0), sides=8), lapis, P, bevel=0.0)
    # tête, museau, oreilles hautes
    hz = z0 + 1.42
    kit.add(kit.brick((0.5, 0.44, 0.42), center=(x, -0.12, hz)), black, P, bevel=0.07)
    kit.add(kit.brick((0.26, 0.14, 0.18), center=(x, -0.38, hz - 0.08)), black, P, bevel=0.04)
    kit.add(kit.brick((0.08, 0.04, 0.06), center=(x, -0.46, hz - 0.03)), nose, P, bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.box((0.18, 0.1, 0.36), center=(x + s * 0.15, -0.1, hz + 0.36), taper=(0.12, 0.8)), black, P,
                bevel=0.02)
        kit.add(kit.box((0.1, 0.03, 0.2), center=(x + s * 0.15, -0.16, hz + 0.32), taper=(0.15, 1.0)), gold, P,
                bevel=0.0)
        kit.add(kit.brick((0.11, 0.03, 0.07), center=(x + s * 0.11, -0.35, hz + 0.06)), eye, P, bevel=0.0)
    kit.add(I.octo(kit, 0.06, 0.05, (x + 0.27, -0.1, hz + 0.16), rot=(0, 90, 0)), gold, P, bevel=0.0)  # boucle d'oreille
    # queue enroulée devant le socle
    kit.add(kit.brick((0.12, 0.7, 0.12), center=(x + 0.46, 0.0, z0 + 0.06)), black, P, bevel=0.03)
    kit.add(kit.brick((0.34, 0.12, 0.12), center=(x + 0.35, -0.38, z0 + 0.06)), black, P, bevel=0.03)


def pyramide(kit, x):
    P = "Pyramide"
    gold = kit.gold("or_pyramide", hammered=0.4, rough=0.24)
    gold2 = kit.gold("or_pyramide_fonce", tint="#E8961A", hammered=0.5, rough=0.3)
    sapphire = kit.gem("saphir_pyramide", "#020A3A", "#2860FF", "#D8E4FF")
    door = kit.enamel("porte", "#2A1606")
    lapis = kit.enamel("hieroglyphes", "#1E3CC8")
    z = 0.0
    for k, w in enumerate((2.2, 1.8, 1.4, 1.0, 0.62)):
        kit.add(kit.brick((w, w, 0.32), center=(x, 0, z + 0.16)), gold if k % 2 == 0 else gold2, P, bevel=0.05)
        # petits signes bleus sur la face avant des marches
        if k < 3:
            for j in ((-1, 1) if k == 0 else (-1, 0, 1)):  # la porte est au milieu de la 1re marche
                kit.add(kit.brick((0.1, 0.03, 0.12), center=(x + j * w * 0.28, -w / 2 - 0.01, z + 0.16)), lapis, P,
                        bevel=0.0)
        z += 0.32
    kit.add(kit.box((0.5, 0.5, 0.46), center=(x, 0, z + 0.23), taper=(0.06, 0.06)), sapphire, P, bevel=0.03)
    kit.add(kit.brick((0.36, 0.04, 0.24), center=(x, -1.11, 0.16)), door, P, bevel=0.0)
    kit.add(kit.brick((0.5, 0.06, 0.06), center=(x, -1.12, 0.3)), gold2, P, bevel=0.0)


def build(name: str) -> dict:
    kit = PetKit(name)
    for index, maker in enumerate((cactus, cruche, scarabee, lampe, chat_sacre, pyramide)):
        maker(kit, I.slot(index))
    return kit.result()
