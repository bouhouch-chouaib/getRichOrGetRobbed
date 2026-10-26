"""Objets à jeter du Volcan (26 oct.) : charbon, roche de lave, piment de feu, enclume d'or, dent de dragon, cœur de
magma.

Du plus courant au plus précieux (Config.WorldItems.Volcan) : plastique (charbon, roche de lave aux fissures orange
SANS lueur), émail (piment), or martelé (enclume), ivoire nacré + or (dent), rubis dans l'or massif (cœur). La roche de
lave sert aussi aux roches crachées par le trou noir (palier ÉRUPTION). Base : _items.py.
"""

import math

import _items as I
from pet_kit import PetKit


def charbon(kit, x):
    P = "Charbon"
    coal = kit.mat("charbon", "#141218", rough=0.55)
    coal2 = kit.mat("charbon_clair", "#24212A", rough=0.5)
    shiny = kit.mat("charbon_brillant", "#0C0B10", rough=0.12)
    ember = kit.mat("braise", "#C8401A", rough=0.4)
    chunks = [((0.9, 0.8, 0.7), (0, 0, 0.35), (5, 8, 12), coal), ((0.62, 0.7, 0.56), (0.46, 0.12, 0.3), (-10, 6, 35), coal2),
              ((0.56, 0.52, 0.5), (-0.42, -0.2, 0.28), (12, -8, -20), coal), ((0.52, 0.5, 0.42), (0.05, 0.05, 0.78),
                                                                               (20, 10, 40), coal2),
              ((0.42, 0.46, 0.36), (-0.16, 0.38, 0.24), (0, 15, 60), shiny), ((0.36, 0.34, 0.3), (0.3, -0.36, 0.2),
                                                                             (-15, 5, 15), shiny)]
    for size, (dx, dy, z), rot, mat in chunks:
        kit.add(kit.brick(size, center=(x + dx, dy, z), rot=rot), mat, P, bevel=0.07)
    for dx, dy, z, rot in ((0.12, -0.42, 0.42, (80, 0, 10)), (-0.5, 0.05, 0.48, (0, 70, 0)), (0.3, 0.3, 0.92, (10, 20, 30))):
        kit.add(kit.box((0.18, 0.12, 0.03), center=(x + dx, dy, z), rot=rot), ember, P, bevel=0.0)


def roche_de_lave(kit, x):
    P = "RocheDeLave"
    basalt = kit.mat("basalte", "#241C22", rough=0.55)
    basalt2 = kit.mat("basalte_fonce", "#18121A", rough=0.6)
    lava = kit.enamel("fissures", "#FF6A10")
    lava2 = kit.enamel("fissures_jaunes", "#FFB21E")
    # cœur orange couvert de blocs de basalte inégaux et de travers : l'orange se voit dans les fissures
    kit.add(kit.brick((1.3, 1.05, 0.95), center=(x, 0, 0.52)), lava, P, bevel=0.04)
    blocks = [((0.86, 0.66, 0.6), (-0.3, -0.24, 0.32), (3, -4, 8)), ((0.62, 0.7, 0.66), (0.42, -0.2, 0.34), (-5, 6, -12)),
              ((0.7, 0.56, 0.5), (-0.36, 0.34, 0.26), (6, 2, -20)), ((0.56, 0.5, 0.56), (0.4, 0.36, 0.3), (-3, -8, 15)),
              ((0.78, 0.62, 0.46), (-0.22, -0.18, 0.86), (-8, 5, 24)), ((0.6, 0.58, 0.5), (0.4, 0.1, 0.84), (7, -6, -8)),
              ((0.5, 0.44, 0.4), (-0.42, 0.36, 0.78), (4, 10, 35)), ((0.52, 0.5, 0.36), (0.08, 0.06, 1.2), (10, -5, 50))]
    for k, (size, (dx, dy, z), rot) in enumerate(blocks):
        kit.add(kit.brick(size, center=(x + dx, dy, z), rot=rot), basalt if k % 3 else basalt2, P, bevel=0.09)
    # veines orange et jaunes sur le dessus
    for dx, dy, z, length, yaw, mat in ((0.02, -0.3, 1.1, 0.6, 10, lava), (0.42, 0.42, 1.08, 0.4, 70, lava2),
                                        (-0.5, -0.05, 1.0, 0.35, -40, lava2)):
        kit.add(kit.box((length, 0.08, 0.05), center=(x + dx, dy, z), rot=(0, 0, yaw)), mat, P, bevel=0.0)


def piment(kit, x):
    P = "Piment"
    red = kit.enamel("piment", "#F01414")
    red_dark = kit.enamel("piment_fonce", "#B80A10")
    shine = kit.enamel("piment_reflet", "#FF7A6A")
    green = kit.enamel("queue", "#2EB83A")
    # couché, la pointe qui remonte vers l'avant (-Y)
    p = [x, 0.95, 0.32]
    pieces = ((0.3, 0.3, 0), (0.34, 0.36, 0), (0.32, 0.36, 5), (0.27, 0.34, 18), (0.2, 0.3, 34), (0.12, 0.3, 52))
    for k, (r, length, pitch) in enumerate(pieces):
        a = math.radians(pitch)
        t = (0.0, -math.cos(a), math.sin(a))
        c = (p[0], p[1] + t[1] * length / 2, p[2] + t[2] * length / 2)
        tip = 0.03 if k == len(pieces) - 1 else None
        kit.add(I.octo(kit, r, length + 0.02, c, rot=(90 - pitch, 0, 0), top=tip), red if k % 2 == 0 else red_dark, P,
                bevel=0.03)
        p = [p[0], p[1] + t[1] * length, p[2] + t[2] * length]
    kit.add(kit.box((0.16, 0.5, 0.05), center=(x - 0.1, 0.3, 0.64), rot=(0, 0, 4)), shine, P, bevel=0.0)
    # queue verte : collerette et tige recourbée
    kit.add(I.octo(kit, 0.32, 0.12, (x, 1.0, 0.32), rot=(90, 0, 0)), green, P, bevel=0.03)
    kit.add(kit.brick((0.12, 0.3, 0.12), center=(x, 1.2, 0.36)), green, P, bevel=0.03)
    kit.add(kit.brick((0.12, 0.12, 0.26), center=(x, 1.32, 0.5)), green, P, bevel=0.03)


def enclume(kit, x):
    P = "Enclume"
    gold = kit.gold("or_enclume", tint="#F2A43A", hammered=0.55, rough=0.28)
    gold2 = kit.gold("or_enclume_fonce", tint="#C87A20", hammered=0.6, rough=0.32)
    iron = kit.mat("fer", "#3A3A46", rough=0.4, metal=0.6)
    wood = kit.mat("manche", "#A0602A", rough=0.55)
    steel = kit.chrome("tete_marteau")
    kit.add(kit.brick((1.2, 0.9, 0.1), center=(x, 0, 0.05)), gold2, P, bevel=0.03)
    kit.add(kit.box((1.1, 0.8, 0.3), center=(x, 0, 0.25), taper=(0.62, 0.68)), gold2, P, bevel=0.05)
    kit.add(kit.box((0.5, 0.42, 0.42), center=(x, 0, 0.61), taper=(1.5, 1.35)), gold, P, bevel=0.05)
    kit.add(kit.brick((1.4, 0.6, 0.3), center=(x + 0.15, 0, 0.97)), gold, P, bevel=0.05)
    kit.add(kit.box((0.5, 0.56, 0.75), center=(x - 0.55 - 0.37, 0, 0.98), rot=(0, -90, 0), taper=(0.2, 0.35)), gold, P,
            bevel=0.04)
    kit.add(kit.brick((0.3, 0.5, 0.22), center=(x + 0.95, 0, 0.98)), gold2, P, bevel=0.04)
    kit.add(kit.brick((1.0, 0.5, 0.04), center=(x + 0.2, 0, 1.13)), iron, P, bevel=0.01)  # table de frappe
    kit.add(kit.brick((0.12, 0.12, 0.03), center=(x + 0.6, 0.1, 1.155)), gold2, P, bevel=0.0)
    # petit marteau posé dessus
    kit.add(kit.brick((0.9, 0.1, 0.1), center=(x + 0.1, -0.05, 1.21), rot=(0, 0, 22)), wood, P, bevel=0.02)
    hx, hy = x + 0.1 - math.cos(math.radians(22)) * 0.45, -0.05 - math.sin(math.radians(22)) * 0.45
    kit.add(kit.brick((0.2, 0.42, 0.22), center=(hx, hy, 1.24), rot=(0, 0, 22)), steel, P, bevel=0.03)


def dent(kit, x):
    P = "DentDeDragon"
    ivory = kit.pearl("ivoire", color="#FFF2DE", sheen="#FFE0B0")
    gold = kit.gold("or_dent", hammered=0.3, rough=0.26)
    ruby = kit.gem("rubis_dent", "#3A0008", "#F01E3C", "#FFD0D8")
    # sertissure d'or et ses griffes
    kit.add(I.octo(kit, 0.52, 0.14, (x, 0, 0.07)), gold, P, bevel=0.03)
    kit.add(I.octo(kit, 0.46, 0.16, (x, 0, 0.22)), gold, P, bevel=0.03)
    for angle in (45, 135, 225, 315):
        c = I.face_point(x, 0, 0.42, angle, 0.46, out=0.02)
        kit.add(kit.box((0.12, 0.08, 0.36), center=c, rot=(0, 0, angle), taper=(0.4, 0.8)), gold, P, bevel=0.02)
    # croc recourbé vers l'avant
    p = [x, 0.0, 0.3]
    for k, r in enumerate((0.42, 0.4, 0.36, 0.31, 0.25, 0.19, 0.13)):
        pitch = k * 7.0
        a = math.radians(pitch)
        t = (0.0, -math.sin(a), math.cos(a))
        length = 0.27
        c = (p[0], p[1] + t[1] * length / 2, p[2] + t[2] * length / 2)
        kit.add(I.octo(kit, r, length + 0.02, c, rot=(pitch, 0, 0), top=r * 0.92), ivory, P, bevel=0.03)
        p = [p[0], p[1] + t[1] * length, p[2] + t[2] * length]
    a = math.radians(52)
    kit.add(kit.spike(tuple(p), (0, -math.sin(a), math.cos(a)), 0.42, 0.18), ivory, P, bevel=0.0)
    # bague d'or et rubis
    kit.add(I.octo(kit, 0.45, 0.1, (x, -0.02, 0.5), rot=(4, 0, 0)), gold, P, bevel=0.02)
    kit.add(kit.disc(0.09, 0.06, center=(x, -0.44, 0.5), normal=(0, -1, 0), sides=8), ruby, P, bevel=0.0)


def coeur_de_magma(kit, x):
    P = "CoeurDeMagma"
    ruby = kit.gem("rubis_coeur", "#4A0008", "#FF2A2A", "#FFD0C0")
    gold = kit.gold("or_coeur", hammered=0.35, rough=0.22)
    gold2 = kit.gold("or_coeur_fonce", tint="#E8961A", hammered=0.45, rough=0.28)
    obsidian = kit.gem("obsidienne", "#050008", "#2A1840", "#9A80C0")
    # socle d'obsidienne et pied d'or
    kit.add(I.octo(kit, 0.66, 0.2, (x, 0, 0.1)), obsidian, P, bevel=0.04)
    top = I.stack(kit, x, 0, [(0.56, 0.1, gold2), (0.44, 0.1, gold), (0.2, 0.22, gold), (0.34, 0.1, gold2)], P, z0=0.2)
    # cœur de rubis : deux lobes et une pointe en losange
    cz = top + 0.5
    kit.add(kit.box((0.84, 0.48, 0.84), center=(x, 0, cz), rot=(0, 45, 0)), ruby, P, bevel=0.05)
    for s in (-1, 1):
        kit.add(I.octo(kit, 0.42, 0.5, (x + s * 0.29, 0, cz + 0.32), rot=(90, 22.5, 0)), ruby, P, bevel=0.05)
    # griffes d'or qui tiennent le cœur, et cerclage
    for s in (-1, 1):
        kit.add(kit.box((0.1, 0.12, 0.5), center=(x + s * 0.3, 0, top + 0.22), rot=(0, s * 35, 0)), gold, P,
                bevel=0.02)
        kit.add(kit.box((0.12, 0.56, 0.1), center=(x + s * 0.62, 0, cz + 0.12), rot=(0, s * 30, 0)), gold, P,
                bevel=0.02)
    kit.add(kit.brick((0.12, 0.56, 0.12), center=(x, 0, cz + 0.62)), gold, P, bevel=0.02)


def build(name: str) -> dict:
    kit = PetKit(name)
    for index, maker in enumerate((charbon, roche_de_lave, piment, enclume, dent, coeur_de_magma)):
        maker(kit, I.slot(index))
    return kit.result()
