"""Machine de fusion (kiosque entre deux bases) : laboratoire en briques, sans lueur (25 oct.).

Socle octogonal en acier, deux cuves (liquide en cristal vert et violet dans une cage d'acier, couvercles et
boulons), chambre centrale en cristal violet cerclée d'acier sur son pied, tuyaux qui relient les cuves à la chambre,
paratonnerre ; console devant avec écran, trois boutons et un levier. Repère du jeu : -Y Blender = -Z Roblox = vers
le trou noir. La bulle [E] et le panneau FUSION sont posés par le jeu (server/MapGenerator).
"""

import math

import _egg as E
import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    steel = kit.mat("acier", "#9AA0B4", rough=0.35, metal=0.55)
    dark = kit.mat("acier_fonce", "#464A58", rough=0.4, metal=0.5)
    trim = kit.enamel("violet", "#9A4AE6")
    green = kit.gem("liquide_vert", "#0A4A1A", "#3AE66A", "#E0FFE8")
    purple = kit.gem("liquide_violet", "#2A0A5A", "#B46AFF", "#F4E6FF")
    screen = kit.enamel("ecran", "#123A3A")
    line = kit.enamel("ecran_lignes", "#3AE6A0")
    red = kit.enamel("bouton_rouge", "#FF3A3A")
    yellow = kit.enamel("bouton_jaune", "#FFD23A")
    blue = kit.enamel("bouton_bleu", "#3A9AFF")
    rubber = kit.mat("caoutchouc", "#2A2A30", rough=0.8)

    # --- socle ---
    kit.add(E.octo(kit, 6.2, 0.8, 0.4), dark, "Machine", bevel=0.12)
    kit.add(E.octo(kit, 5.6, 0.3, 0.95), steel, "Machine", bevel=0.06)
    kit.add(E.octo(kit, 5.75, 0.12, 0.86), trim, "Machine", bevel=0.03)

    # --- deux cuves ---
    for x, liquid in ((-3.6, green), (3.6, purple)):
        y = 2.0
        kit.add(E.octo(kit, 1.9, 0.8, 1.5, x=x, y=y), steel, "Tanks", bevel=0.1)
        kit.add(E.octo(kit, 1.9, 0.8, 9.0, x=x, y=y), steel, "Tanks", bevel=0.1)
        kit.add(E.octo(kit, 1.2, 0.5, 9.65, x=x, y=y), dark, "Tanks", bevel=0.06)
        kit.add(E.octo(kit, 1.25, 6.4, 5.25, x=x, y=y), liquid, "Tanks", bevel=0.0)
        for k in range(4):
            a = 45 + 90 * k
            cx, cy = x + math.cos(math.radians(a)) * 1.6, y + math.sin(math.radians(a)) * 1.6
            kit.add(kit.brick((0.35, 0.35, 6.6), center=(cx, cy, 5.25)), dark, "Tanks", bevel=0.05)
        for z in (3.4, 7.1):
            kit.add(E.octo(kit, 1.72, 0.25, z, x=x, y=y), steel, "Tanks", bevel=0.04)
        # tuyau vers la chambre centrale
        P.chain(kit, "Tanks", [(x * 0.8, y, 9.2), (x * 0.55, y, 9.8), (x * 0.3, y, 8.4)], 0.55, [steel, dark])

    # --- chambre centrale en cristal, cerclée d'acier, sur son pied ---
    kit.add(E.octo(kit, 0.8, 2.8, 2.4, y=2.0), steel, "Machine", bevel=0.08)
    kit.add(E.octo(kit, 1.6, 0.4, 3.8, y=2.0), dark, "Machine", bevel=0.06)
    for z, r, h in ((4.6, 1.6, 0.8), (5.5, 2.3, 1.0), (6.5, 2.4, 1.0), (7.5, 1.7, 0.8), (8.1, 0.9, 0.4)):
        kit.add(E.octo(kit, r, h, z, y=2.0), purple, "Machine", bevel=0.06)
    kit.add(E.octo(kit, 2.55, 0.35, 6.0, y=2.0), steel, "Machine", bevel=0.05)
    kit.add(kit.brick((0.4, 0.4, 2.2), center=(0, 2.0, 9.4)), dark, "Machine", bevel=0.05)
    kit.add(kit.brick((0.8, 0.8, 0.8), center=(0, 2.0, 10.7), rot=(45, 0, 45)), trim, "Machine", bevel=0.08)

    # --- console devant ---
    kit.add(kit.brick((5.2, 2.2, 2.6), center=(0, -3.5, 1.3)), dark, "Console", bevel=0.12)
    kit.add(kit.brick((5.4, 2.6, 0.3), center=(0, -3.5, 2.75)), steel, "Console", bevel=0.06)
    kit.add(kit.brick((4.2, 0.25, 1.5), center=(0, -3.35, 3.55), rot=(-30, 0, 0)), dark, "Console", bevel=0.06)
    kit.add(kit.brick((3.6, 0.2, 1.1), center=(0, -3.47, 3.58), rot=(-30, 0, 0)), screen, "Console", bevel=0.03)
    for k in range(3):
        kit.add(kit.brick((2.6 - k * 0.6, 0.1, 0.12), center=(-0.4 + k * 0.3, -3.58, 3.35 + k * 0.22), rot=(-30, 0, 0)), line,
                "Console", bevel=0.0)
    for k, mat in enumerate((red, yellow, blue)):
        kit.add(kit.cylinder(0.32, 0.3, center=(-1.4 + k * 1.4, -4.2, 3.0), rot=(0, 0, 22.5), sides=8), mat, "Console",
                bevel=0.04)
    kit.add(kit.brick((0.25, 0.25, 1.4), center=(2.3, -3.0, 3.6), rot=(0, 20, 0)), steel, "Console", bevel=0.04)
    kit.add(kit.brick((0.55, 0.55, 0.55), center=(2.55, -3.0, 4.3)), red, "Console", bevel=0.1)
    kit.add(kit.brick((0.6, 3.4, 0.4), center=(0, -1.1, 0.95)), rubber, "Console", bevel=0.06)
    return kit.result()
