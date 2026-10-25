"""Boutique (kiosque entre deux bases) : échoppe de marché en briques, sans lueur (25 oct.).

Comptoir en planches avec sa caisse et un tas de pièces d'or, mur du fond à deux étagères garnies (caisses, sacs,
potions en cristal, piles de pièces, coffre), quatre poteaux, auvent rayé rouge et blanc à festons. Repère du jeu :
-Y Blender = -Z Roblox = vers le trou noir (le client devant le comptoir). La bulle [E] et le panneau BOUTIQUE sont
posés par le jeu (server/MapGenerator).
"""

import math

from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    wood = kit.mat("bois", "#C88A4A", rough=0.55)
    plank = kit.mat("planches", "#A86A34", rough=0.6)
    dark = kit.mat("bois_fonce", "#6E4626", rough=0.6)
    red = kit.enamel("rouge", "#E63232")
    white = kit.enamel("blanc", "#FAF5EB")
    gold = kit.gold("or", hammered=0.3, rough=0.3)
    crate = kit.mat("caisses", "#D8A060", rough=0.6)
    sack = kit.mat("sacs", "#E8D2A0", rough=0.8)
    green = kit.gem("potion_verte", "#0A4A1A", "#3AE66A", "#E0FFE8")
    blue = kit.gem("potion_bleue", "#0A2A5A", "#3A9AFF", "#E0F0FF")
    pink = kit.gem("potion_rose", "#5A0A3A", "#FF5AB4", "#FFE0F0")
    till = kit.enamel("caisse", "#2E7CFF")

    # --- comptoir en planches ---
    kit.add(kit.brick((12.0, 3.0, 3.4), center=(0, -1.5, 1.7)), wood, "Stall", bevel=0.12)
    for k in range(7):
        kit.add(kit.brick((0.18, 3.06, 3.2), center=(-5.4 + k * 1.8, -1.5, 1.7)), plank, "Stall", bevel=0.03)
    kit.add(kit.brick((12.6, 3.6, 0.4), center=(0, -1.5, 3.6)), dark, "Stall", bevel=0.08)
    kit.add(kit.disc(0.9, 0.2, center=(0, -3.05, 1.9), normal=(0, -1, 0), sides=16), gold, "Stall", bevel=0.0)
    kit.add(kit.brick((0.5, 0.1, 0.9), center=(0, -3.16, 1.9)), dark, "Stall", bevel=0.0)
    # caisse enregistreuse et tas de pièces sur le comptoir
    kit.add(kit.brick((1.6, 1.2, 0.9), center=(3.6, -1.2, 4.25)), till, "Goods", bevel=0.1)
    kit.add(kit.brick((1.4, 0.5, 0.5), center=(3.6, -1.0, 4.9), rot=(-25, 0, 0)), dark, "Goods", bevel=0.06)
    for k, (x, y, h) in enumerate(((-3.6, -1.4, 0.5), (-3.0, -1.7, 0.35), (-4.1, -1.9, 0.3), (-3.4, -1.1, 0.25))):
        kit.add(kit.cylinder(0.32, h, center=(x, y, 3.8 + h / 2), rot=(0, 0, 22.5), sides=8), gold, "Goods", bevel=0.03)

    # --- mur du fond et étagères ---
    kit.add(kit.brick((12.0, 0.8, 8.0), center=(0, 4.0, 4.0)), wood, "Stall", bevel=0.12)
    for k in range(5):
        kit.add(kit.brick((12.06, 0.86, 0.16), center=(0, 4.0, 1.4 + k * 1.6)), plank, "Stall", bevel=0.03)
    for z in (3.5, 6.0):
        kit.add(kit.brick((11.0, 1.8, 0.3), center=(0, 3.0, z)), dark, "Stall", bevel=0.06)
    # marchandise : caisses, sacs, potions, piles de pièces, coffre
    for x in (-4.6, 1.4):
        kit.add(kit.brick((1.6, 1.3, 1.2), center=(x, 3.0, 4.25)), crate, "Goods", bevel=0.1)
        kit.add(kit.brick((1.66, 0.14, 1.26), center=(x, 2.36, 4.25)), dark, "Goods", bevel=0.02)
    for x in (-2.6, 4.0):
        kit.add(kit.brick((1.3, 1.1, 1.3), center=(x, 3.0, 4.3)), sack, "Goods", bevel=0.35)
        kit.add(kit.brick((0.5, 0.5, 0.3), center=(x, 3.0, 5.05)), dark, "Goods", bevel=0.08)
    for k, (x, mat) in enumerate(((-4.8, green), (-3.8, blue), (-2.8, pink), (-1.8, green))):
        kit.add(kit.cylinder(0.38, 0.8, center=(x, 3.0, 6.55), rot=(0, 0, 22.5), sides=8), mat, "Goods", bevel=0.04)
        kit.add(kit.brick((0.24, 0.24, 0.3), center=(x, 3.0, 7.1)), dark, "Goods", bevel=0.03)
    for x, h in ((0.2, 0.6), (0.9, 0.4)):
        kit.add(kit.cylinder(0.35, h, center=(x, 3.0, 6.15 + h / 2), rot=(0, 0, 22.5), sides=8), gold, "Goods", bevel=0.03)
    kit.add(kit.brick((2.2, 1.3, 1.0), center=(3.2, 3.0, 6.65)), dark, "Goods", bevel=0.1)
    kit.add(kit.brick((2.3, 1.4, 0.5), center=(3.2, 3.0, 7.35)), wood, "Goods", bevel=0.12)
    kit.add(kit.brick((2.36, 1.46, 0.14), center=(3.2, 3.0, 7.05)), gold, "Goods", bevel=0.03)
    kit.add(kit.brick((0.3, 0.1, 0.4), center=(3.2, 2.28, 6.9)), gold, "Goods", bevel=0.02)

    # --- poteaux ---
    # (hauteur de chaque poteau : jusque sous l'auvent incliné, ni plus ni moins)
    for x in (-6.0, 6.0):
        for y, h in ((-3.0, 8.55), (4.0, 10.3)):
            kit.add(kit.brick((0.8, 0.8, h), center=(x, y, h / 2)), dark, "Stall", bevel=0.08)

    # --- auvent rayé rouge et blanc, incliné vers l'avant, festons ---
    tilt = 14.0
    for k in range(7):
        x = -6.0 + k * 2.0
        mat = red if k % 2 == 0 else white
        kit.add(kit.brick((2.0, 9.2, 0.3), center=(x, 0.4, 9.45), rot=(tilt, 0, 0)), mat, "Awning", bevel=0.05)
        front_z = 9.45 - math.sin(math.radians(tilt)) * 4.6 - 0.1
        kit.add(kit.wedge((1.9, 0.25, 0.7), center=(x, 0.4 - 4.5, front_z - 0.35), rot=(180, 0, 0), tip=0.25), mat,
                "Awning", bevel=0.0)
    return kit.result()
