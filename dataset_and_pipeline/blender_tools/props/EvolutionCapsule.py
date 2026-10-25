"""Capsule d'évolution (derrière chaque base) : cylindre de stase en briques, sans lueur (25 oct.).

Socle carré à gradins et pieds émaillés, couronne basse en acier, quatre montants et trois anneaux octogonaux autour
de la vitre, chapeau à gradins, émetteur à pointe de cristal, deux tuyaux à colliers sur les côtés, pupitre de
console devant. La vitre (transparente, on y voit l'œuf), l'écran ÉVOLUTION et la bulle [E] restent posés par le jeu
(server/MapGenerator) : le modèle laisse libre le volume de la vitre (rayon 3,2, de 2,4 à 11,9 studs).
Repère du jeu : la console vers -Y Blender = -Z Roblox (vers la base).
"""

import math

import _egg as E
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    steel = kit.mat("acier", "#A8B0C0", rough=0.35, metal=0.55)
    dark = kit.mat("acier_fonce", "#3A4052", rough=0.4, metal=0.5)
    teal = kit.enamel("stase", "#3ADCE6")
    crystal = kit.gem("cristal", "#0A4A5A", "#5AE6F0", "#E8FDFF")
    red = kit.enamel("bouton_rouge", "#FF4A4A")
    rubber = kit.mat("caoutchouc", "#2A2A30", rough=0.8)

    # --- socle à gradins, pieds ---
    kit.add(kit.brick((11.0, 11.0, 0.7), center=(0, 0, 0.35)), dark, "Base", bevel=0.12)
    kit.add(kit.brick((9.8, 9.8, 0.5), center=(0, 0, 0.95)), steel, "Base", bevel=0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.add(kit.brick((2.0, 2.0, 0.8), center=(sx * 4.6, sy * 4.6, 1.4)), teal, "Base", bevel=0.12)
            kit.add(kit.brick((1.2, 1.2, 0.3), center=(sx * 4.6, sy * 4.6, 1.95)), dark, "Base", bevel=0.06)
    kit.add(E.octo(kit, 4.6, 1.2, 1.8), steel, "Base", bevel=0.12)
    kit.add(E.octo(kit, 4.75, 0.25, 2.3), teal, "Base", bevel=0.05)

    # --- montants et anneaux autour de la vitre ---
    for k in range(4):
        a = math.radians(45 + 90 * k)
        kit.add(kit.brick((0.5, 0.5, 9.8), center=(math.cos(a) * 3.75, math.sin(a) * 3.75, 7.2)), dark, "Frame",
                bevel=0.06)
    for z in (3.4, 7.1, 10.8):
        r = 3.65
        for k in range(8):
            a = math.radians(22.5 + 45 * k)
            side = 2 * r * math.tan(math.radians(22.5)) + 0.05
            kit.add(kit.brick((side, 0.4, 0.4), center=(math.cos(a) * r, math.sin(a) * r, z),
                              rot=(0, 0, math.degrees(a) + 90)), teal if z == 7.1 else steel, "Frame", bevel=0.05)

    # --- chapeau à gradins, émetteur à pointe de cristal ---
    kit.add(E.octo(kit, 4.6, 1.4, 12.6), steel, "Top", bevel=0.14)
    kit.add(E.octo(kit, 4.75, 0.25, 12.0), teal, "Top", bevel=0.05)
    kit.add(kit.brick((5.0, 5.0, 1.0), center=(0, 0, 13.8)), dark, "Top", bevel=0.12)
    kit.add(kit.brick((3.2, 3.2, 0.5), center=(0, 0, 14.55)), steel, "Top", bevel=0.08)
    kit.add(E.octo(kit, 0.7, 2.2, 15.9), dark, "Top", bevel=0.06)
    for z in (15.2, 16.4):
        kit.add(E.octo(kit, 0.9, 0.22, z), teal, "Top", bevel=0.03)
    kit.add(kit.cylinder(0.75, 1.8, center=(0, 0, 17.9), rot=(0, 0, 22.5), sides=8, top=0.0), crystal, "Top", bevel=0.0)
    kit.add(kit.cylinder(0.75, 0.6, center=(0, 0, 16.9), rot=(180, 0, 22.5), sides=8, top=0.35), crystal, "Top", bevel=0.0)

    # --- tuyaux à colliers sur les côtés ---
    for s in (-1, 1):
        kit.add(E.octo(kit, 0.5, 10.6, 7.1, x=s * 4.6, y=2.6), dark, "Frame", bevel=0.05)
        for z in (4.0, 10.0):
            kit.add(kit.brick((1.5, 1.5, 0.5), center=(s * 4.6, 2.6, z)), steel, "Frame", bevel=0.08)
        kit.add(kit.brick((1.2, 0.6, 0.6), center=(s * 4.0, 2.6, 12.0)), dark, "Frame", bevel=0.06)

    # --- pupitre de console (l'écran ÉVOLUTION est posé par le jeu) ---
    kit.add(kit.brick((5.2, 2.2, 2.9), center=(0, -6.6, 1.45)), dark, "Console", bevel=0.12)
    kit.add(kit.brick((5.4, 2.4, 0.3), center=(0, -6.6, 2.95)), steel, "Console", bevel=0.06)
    for k in (-1, 1):
        kit.add(kit.cylinder(0.3, 0.3, center=(k * 1.4, -5.75, 3.2), rot=(0, 0, 22.5), sides=8), teal, "Console", bevel=0.04)
    kit.add(kit.cylinder(0.34, 0.32, center=(0, -5.75, 3.2), rot=(0, 0, 22.5), sides=8), red, "Console", bevel=0.04)
    kit.add(kit.brick((0.6, 2.6, 0.4), center=(0, -4.6, 1.0)), rubber, "Console", bevel=0.06)
    return kit.result()
