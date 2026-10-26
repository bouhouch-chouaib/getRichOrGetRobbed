"""Objets à jeter de la Glace (26 oct.) : boule de neige, cornet de glace, bonhomme de neige, patin d'or, flocon de
cristal, couronne de glace.

Du plus courant au plus précieux (Config.WorldItems.Glace) : plastique (boule, cornet), émail + boutons de cristal
(bonhomme), or martelé (patin), cristal sur nacre (flocon), or massif + cristaux de glace (couronne). Base : _items.py.
"""

import math

import _items as I
from pet_kit import PetKit


def boule_de_neige(kit, x):
    P = "BouleDeNeige"
    snow = kit.mat("neige", "#F6FAFF", rough=0.45)
    shade = kit.mat("neige_ombre", "#CFE4FF", rough=0.5)
    # vraie boule (7 étages), le dessous bleuté, deux mottes de neige collées sur le côté
    I.ball(kit, (x, 0, 0.82), 0.82, [shade, shade, snow, snow, snow, snow, snow], P, n=7, power=1.0)
    for dx, dy, z, size, rot in ((0.66, -0.3, 0.55, 0.24, (0, 20, 30)), (-0.5, 0.55, 0.42, 0.2, (15, 0, 10))):
        kit.add(kit.brick((size, size, size * 0.8), center=(x + dx, dy, z), rot=rot), snow, P, bevel=0.05)


def cornet(kit, x):
    P = "Cornet"
    cone = kit.mat("gaufre", "#E8A44A", rough=0.5)
    cone_dark = kit.mat("gaufre_fonce", "#B8702A", rough=0.55)
    pink = kit.mat("fraise", "#FF6EA8", rough=0.3)
    cream = kit.mat("vanille", "#FFF0CC", rough=0.3)
    cherry = kit.mat("cerise", "#E8102A", rough=0.2)
    stem = kit.mat("queue_cerise", "#3A8A2A", rough=0.4)
    sprinkles = [kit.mat("vermicelle_" + c, c, rough=0.3) for c in ("#2E9BFF", "#FFD21E", "#3CD03C", "#FFFFFF")]
    h = 0.95
    kit.add(I.octo(kit, 0.08, h, (x, 0, h / 2), top=0.5), cone, P, bevel=0.03)
    for k, t in enumerate((0.3, 0.55, 0.8)):
        kit.add(I.octo(kit, 0.08 + 0.42 * t + 0.025, 0.05, (x, 0, h * t)), cone_dark, P, bevel=0.01)
    kit.add(I.octo(kit, 0.55, 0.12, (x, 0, h + 0.04)), cone_dark, P, bevel=0.03)
    # boule fraise (avec son bord qui coule) puis boule vanille et la cerise
    kit.add(I.octo(kit, 0.58, 0.1, (x, 0, h + 0.14)), pink, P, bevel=0.03)
    for angle in (0, 90, 180, 270):
        c = I.face_point(x, 0, 0.58, angle, h + 0.04, out=0.0)
        kit.add(kit.box((0.18, 0.1, 0.22), center=c, rot=(0, 0, angle)), pink, P, bevel=0.03)
    I.ball(kit, (x, 0, h + 0.5), 0.5, pink, P, n=4, squash=0.85)
    I.ball(kit, (x, 0, h + 1.12), 0.4, cream, P, n=4, squash=0.85)
    kit.add(I.octo(kit, 0.12, 0.2, (x, 0, h + 1.55)), cherry, P, bevel=0.04)
    kit.add(kit.brick((0.04, 0.04, 0.24), center=(x + 0.05, 0, h + 1.74), rot=(0, 20, 0)), stem, P, bevel=0.0)
    for k, (angle, z) in enumerate(((0, 1.25), (60, 1.5), (135, 1.3), (200, 1.55), (270, 1.28), (320, 1.45),
                                    (30, 1.8), (110, 1.85), (250, 1.82))):
        r = 0.48 if z < 1.6 else 0.36
        a = math.radians(angle)
        c = (x + math.sin(a) * r, -math.cos(a) * r, h + z - 0.95)
        kit.add(kit.brick((0.14, 0.05, 0.05), center=c, rot=(0, 0, angle + 50 * (k % 2))), sprinkles[k % 4], P,
                bevel=0.0)


def bonhomme(kit, x):
    P = "Bonhomme"
    snow = kit.enamel("neige_bonhomme", "#F8FBFF")
    shade = kit.enamel("neige_bonhomme_ombre", "#D6E8FF")
    coal = kit.enamel("charbon_bonhomme", "#1E1E26")
    carrot = kit.enamel("nez", "#FF6A00")
    scarf = kit.enamel("echarpe", "#E81E3C")
    scarf2 = kit.enamel("echarpe_rayure", "#FFFFFF")
    ice = kit.gem("boutons_glace", "#0A3A6A", "#5AC8FF", "#E8FAFF")
    twig = kit.mat("bras", "#6B3A1E", rough=0.6)
    I.ball(kit, (x, 0, 0.5), 0.5, [shade, snow, snow, snow, snow], P, n=5)
    I.ball(kit, (x, 0, 1.18), 0.38, snow, P, n=4)
    I.ball(kit, (x, 0, 1.72), 0.29, snow, P, n=4)
    # chapeau
    kit.add(I.octo(kit, 0.36, 0.05, (x, 0, 1.98)), coal, P, bevel=0.01)
    kit.add(I.octo(kit, 0.24, 0.3, (x, 0, 2.15)), coal, P, bevel=0.03)
    kit.add(I.octo(kit, 0.25, 0.06, (x, 0, 2.06)), scarf, P, bevel=0.01)
    # yeux, bouche, nez carotte
    for s in (-1, 1):
        kit.add(kit.brick((0.07, 0.04, 0.07), center=(x + s * 0.1, -0.27, 1.8)), coal, P, bevel=0.0)
    for k in range(5):
        dx = (k - 2) * 0.06
        kit.add(kit.brick((0.04, 0.04, 0.04), center=(x + dx, -0.26, 1.6 + abs(k - 2) * 0.025)), coal, P, bevel=0.0)
    kit.add(I.octo(kit, 0.06, 0.3, (x, -0.38, 1.7), rot=(90, 0, 0), top=0.01), carrot, P, bevel=0.01)
    # écharpe rayée et son pan
    kit.add(I.octo(kit, 0.3, 0.12, (x, 0, 1.46)), scarf, P, bevel=0.03)
    kit.add(kit.brick((0.14, 0.06, 0.4), center=(x + 0.16, -0.3, 1.28), rot=(0, 10, 0)), scarf, P, bevel=0.02)
    for z in (1.18, 1.32):
        kit.add(kit.brick((0.15, 0.07, 0.04), center=(x + 0.16 + (1.28 - z) * 0.17, -0.3, z), rot=(0, 10, 0)), scarf2,
                P, bevel=0.0)
    # boutons de cristal
    for z in (1.05, 1.22, 0.55):
        r = 0.38 if z > 1 else 0.5
        kit.add(kit.disc(0.06, 0.05, center=(x, -r * 0.96, z), normal=(0, -1, 0), sides=8), ice, P, bevel=0.0)
    # bras en branches
    for s in (-1, 1):
        kit.add(kit.brick((0.5, 0.06, 0.06), center=(x + s * 0.55, 0, 1.3), rot=(0, -s * 30, 0)), twig, P, bevel=0.0)
        kit.add(kit.brick((0.18, 0.05, 0.05), center=(x + s * 0.72, 0, 1.48), rot=(0, -s * 70, 0)), twig, P,
                bevel=0.0)


def patin(kit, x):
    P = "Patin"
    gold = kit.gold("or_patin", hammered=0.4, rough=0.24)
    gold2 = kit.gold("or_patin_fonce", tint="#E8961A", hammered=0.5, rough=0.3)
    boot = kit.enamel("botte", "#F6F6FA")
    fur = kit.mat("fourrure", "#FFFFFF", rough=0.7)
    lace = kit.enamel("lacets", "#E81E3C")
    # lame d'or qui se recourbe à l'avant, deux supports, semelle
    kit.add(kit.brick((0.08, 1.8, 0.12), center=(x, 0.0, 0.06)), gold, P, bevel=0.02)
    kit.add(kit.brick((0.08, 0.2, 0.16), center=(x, -0.96, 0.16), rot=(-40, 0, 0)), gold, P, bevel=0.02)
    kit.add(kit.brick((0.08, 0.12, 0.14), center=(x, -1.02, 0.3)), gold, P, bevel=0.02)
    for y in (-0.55, 0.55):
        kit.add(kit.box((0.12, 0.26, 0.3), center=(x, y, 0.27), taper=(1.3, 1.3)), gold2, P, bevel=0.03)
    kit.add(kit.brick((0.5, 1.5, 0.08), center=(x, 0.05, 0.46)), gold2, P, bevel=0.02)
    # botte blanche : pied, bout arrondi, tige, col en fourrure
    kit.add(kit.brick((0.52, 1.0, 0.42), center=(x, 0.2, 0.71)), boot, P, bevel=0.08)
    kit.add(kit.slope((0.5, 0.42, 0.38), center=(x, -0.48, 0.69), facing="-Y", top=0.45), boot, P, bevel=0.08)
    kit.add(kit.box((0.52, 0.6, 0.8), center=(x, 0.42, 1.3), taper=(1.08, 1.05)), boot, P, bevel=0.07)
    kit.add(kit.brick((0.62, 0.7, 0.16), center=(x, 0.42, 1.76)), fur, P, bevel=0.06)
    # lacets rouges en croix et œillets d'or
    for k in range(4):
        z = 0.95 + k * 0.17
        y = 0.1 - (0.24 if k == 0 else 0.0)
        for s in (-1, 1):
            kit.add(kit.brick((0.05, 0.03, 0.05), center=(x + s * 0.14, y - 0.01, z), rot=(0, 0, 0)), gold, P, bevel=0.0)
        kit.add(kit.brick((0.3, 0.03, 0.04), center=(x, y - 0.02, z + 0.05), rot=(0, 25 * (1 if k % 2 else -1), 0)),
                lace, P, bevel=0.0)


def flocon(kit, x):
    P = "Flocon"
    ice = kit.gem("cristal_glace", "#0A3A6A", "#5AC8FF", "#E8FAFF")
    pearl = kit.pearl("socle_flocon", color="#F2F4FF", sheen="#C8E8FF")
    gold = kit.gold("or_flocon", hammered=0.3, rough=0.26)
    kit.add(I.octo(kit, 0.56, 0.2, (x, 0, 0.1)), pearl, P, bevel=0.04)
    kit.add(I.octo(kit, 0.6, 0.06, (x, 0, 0.23)), gold, P, bevel=0.015)
    kit.add(I.octo(kit, 0.44, 0.14, (x, 0, 0.33)), pearl, P, bevel=0.03)
    cz, R = 1.3, 0.92
    for k in range(6):
        a = math.radians(90 + 60 * k)
        d = (math.cos(a), math.sin(a))
        rot = (0, 90 - math.degrees(a), 0)  # l'axe de la branche dans le plan de face (X, Z)
        kit.add(kit.box((0.15, 0.12, R), center=(x + d[0] * R / 2, 0, cz + d[1] * R / 2), rot=rot, taper=(0.6, 1.0)),
                ice, P, bevel=0.03)
        for t, length in ((0.42, 0.3), (0.7, 0.22)):
            for s in (-1, 1):
                b = a + s * math.radians(50)
                e = (math.cos(b), math.sin(b))
                c = (x + d[0] * R * t + e[0] * length / 2, 0, cz + d[1] * R * t + e[1] * length / 2)
                kit.add(kit.box((0.09, 0.1, length), center=c, rot=(0, 90 - math.degrees(b), 0), taper=(0.5, 1.0)),
                        ice, P, bevel=0.02)
    kit.add(kit.disc(0.24, 0.18, center=(x, 0, cz), normal=(0, -1, 0), sides=6), ice, P, bevel=0.0)
    kit.add(kit.disc(0.12, 0.22, center=(x, 0, cz), normal=(0, -1, 0), sides=6), gold, P, bevel=0.0)


def couronne(kit, x):
    P = "Couronne"
    gold = kit.gold("or_couronne", hammered=0.35, rough=0.22)
    gold2 = kit.gold("or_couronne_fonce", tint="#E8961A", hammered=0.45, rough=0.28)
    ice = kit.gem("cristaux_couronne", "#0A3A6A", "#5AC8FF", "#E8FAFF")
    sapphire = kit.gem("saphir_couronne", "#020A3A", "#2860FF", "#D8E4FF")
    velvet = kit.enamel("velours", "#2440B8")
    # coiffe de velours bleu, bandeau d'or, bords
    I.stack(kit, x, 0, [(0.64, 0.3, velvet), (0.58, 0.16, velvet), (0.44, 0.12, velvet), (0.26, 0.08, velvet)], P,
            z0=0.08)
    I.ring(kit, (x, 0, 0.32), 0.72, 0.44, 0.14, gold, P, n=8)
    I.ring(kit, (x, 0, 0.1), 0.75, 0.1, 0.16, gold2, P, n=8)
    I.ring(kit, (x, 0, 0.56), 0.74, 0.08, 0.15, gold2, P, n=8)
    # pointes d'or coiffées de cristaux de glace, une grande sur deux
    for k in range(8):
        a = 2 * math.pi * k / 8
        px, py = x + math.cos(a) * 0.72, math.sin(a) * 0.72
        tall = k % 2 == 0
        h = 0.34 if tall else 0.22
        kit.add(kit.box((0.18, 0.16, h), center=(px, py, 0.6 + h / 2), rot=(0, 0, math.degrees(a) + 90),
                        taper=(0.45, 0.6)), gold, P, bevel=0.02)
        ch = 0.42 if tall else 0.26
        kit.add(kit.box((0.16, 0.16, ch), center=(px, py, 0.6 + h + ch / 2 - 0.02), rot=(0, 0, math.degrees(a) + 45),
                        taper=(0.05, 0.05)), ice, P, bevel=0.01)
        # pierres sur le bandeau
        n = (math.cos(a), math.sin(a))
        gem = sapphire if k % 2 else ice
        r = 0.11 if k == 6 else 0.07  # la plus grosse devant (-Y)
        kit.add(kit.disc(r, 0.06, center=(x + n[0] * 0.8, n[1] * 0.8, 0.33), normal=(n[0], n[1], 0), sides=8), gem, P,
                bevel=0.0)
    kit.add(I.octo(kit, 0.1, 0.12, (x, 0, 0.8)), gold, P, bevel=0.02)
    kit.add(kit.box((0.18, 0.18, 0.3), center=(x, 0, 1.0), rot=(0, 0, 45), taper=(0.05, 0.05)), ice, P, bevel=0.01)


def build(name: str) -> dict:
    kit = PetKit(name)
    for index, maker in enumerate((boule_de_neige, cornet, bonhomme, patin, flocon, couronne)):
        maker(kit, I.slot(index))
    return kit.result()
