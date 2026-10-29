"""Objets d'Halloween 2026 (29 oct., Config.Halloween) : la citrouille à jeter dans le trou noir, et deux décors de
l'arène (citrouille sculptée, tombe). Une seule cuisson (une pièce par objet), en studs, posés au sol, sans néon ni
lueur cuite : la lumière des citrouilles sculptées vient d'une PointLight du jeu (server/HalloweenController).
Branchement : tools/make_items_wire.py Objets_Halloween -> ArtModels.Items.Halloween.<Citrouille | Lanterne | Tombe>.
"""

import math

import _items as I
from pet_kit import PetKit


def pumpkin_body(kit, x, part, scale, orange, light, dark):
    """Citrouille en côtes : étages octogonaux, une côte claire / une côte foncée sur chaque face."""
    s = scale
    layers = [(0.62 * s, 0.14 * s, dark), (0.86 * s, 0.22 * s, orange), (0.98 * s, 0.3 * s, orange),
              (0.96 * s, 0.28 * s, orange), (0.82 * s, 0.2 * s, orange), (0.56 * s, 0.12 * s, dark)]
    z, top = 0.0, 0.0
    for r, h, mat in layers:
        kit.add(I.octo(kit, r, h, (x, 0, z + h / 2)), mat, part, bevel=min(0.04 * s, h * 0.25))
        if mat is orange:
            for k in range(8):  # côtes : une tuile par face, claire et foncée en alternance, dans la hauteur de l'étage
                I.on_face(kit, x, 0, r, k * 45, z + h / 2, r * 0.42, h * 0.9, light if k % 2 == 0 else dark, part,
                          thick=0.04 * s, bevel=0.01 * s)
        z += h
        top = z
    return top


def citrouille(kit, x):
    P = "Citrouille"
    orange = kit.mat("orange", "#FF7A12", rough=0.35)
    light = kit.mat("orange_clair", "#FFA042", rough=0.3)
    dark = kit.mat("orange_fonce", "#D85204", rough=0.4)
    stem = kit.mat("tige", "#5E7A1E", rough=0.6)
    leaf = kit.mat("feuille", "#3EC22E", rough=0.35)
    top = pumpkin_body(kit, x, P, 1.0, orange, light, dark)
    kit.add(kit.brick((0.2, 0.2, 0.36), center=(x + 0.03, 0, top + 0.14), rot=(0, 14, 0)), stem, P, bevel=0.03)
    kit.add(kit.box((0.44, 0.26, 0.06), center=(x + 0.3, 0.06, top + 0.03), rot=(6, -10, 14), taper=(0.4, 0.7)), leaf,
            P, bevel=0.015)
    # vrille qui s'enroule sur le dessus
    for k in range(5):
        a = math.radians(-60 + k * 55)
        kit.add(kit.box((0.06, 0.16, 0.05), center=(x - 0.2 + math.cos(a) * 0.14, -0.08 + math.sin(a) * 0.14, top + 0.02),
                        rot=(0, 0, math.degrees(a) + 90)), stem, P, bevel=0.01)


def lanterne(kit, x):
    """Citrouille sculptée du décor : visage creusé vers l'avant (-Y), intérieur jaune (sans lueur cuite)."""
    P = "Lanterne"
    s = 1.8
    orange = kit.mat("l_orange", "#FF7A12", rough=0.35)
    light = kit.mat("l_orange_clair", "#FFA042", rough=0.3)
    dark = kit.mat("l_orange_fonce", "#D85204", rough=0.4)
    inner = kit.mat("l_interieur", "#FFC83A", rough=0.3)
    hollow = kit.mat("l_creux", "#5A2204", rough=0.5)
    stem = kit.mat("l_tige", "#5E7A1E", rough=0.6)
    top = pumpkin_body(kit, x, P, s, orange, light, dark)
    kit.add(kit.brick((0.3, 0.3, 0.5), center=(x - 0.05, 0.05, top + 0.2), rot=(0, -12, 8)), stem, P, bevel=0.04)
    # visage : contour sombre puis intérieur jaune, posés sur la face avant (les tuiles des côtes restent dessous)
    fy = -0.98 * s * I.FACE - 0.09
    for side in (-1, 1):  # yeux triangles
        kit.add(kit.box((0.42, 0.05, 0.36), center=(x + side * 0.36, fy, 1.42)), hollow, P, bevel=0.0)
        kit.add(kit.wedge((0.34, 0.04, 0.28), center=(x + side * 0.36, fy - 0.02, 1.4), tip=0.06), inner, P, bevel=0.0)
    kit.add(kit.box((0.22, 0.05, 0.2), center=(x, fy, 1.12)), hollow, P, bevel=0.0)  # nez
    kit.add(kit.wedge((0.16, 0.04, 0.15), center=(x, fy - 0.02, 1.11), tip=0.06), inner, P, bevel=0.0)
    kit.add(kit.box((1.0, 0.05, 0.3), center=(x, fy, 0.84)), hollow, P, bevel=0.0)  # bouche
    kit.add(kit.box((0.92, 0.04, 0.22), center=(x, fy - 0.02, 0.84)), inner, P, bevel=0.0)
    for k in range(4):  # dents en zigzag
        kit.add(kit.box((0.12, 0.05, 0.1), center=(x - 0.3 + k * 0.2, fy - 0.035, 0.91 if k % 2 else 0.77)), orange, P,
                bevel=0.0)


def tombe(kit, x):
    P = "Tombe"
    stone = kit.mat("pierre", "#8E92A2", rough=0.7)
    stone2 = kit.mat("pierre_fonce", "#6A6E80", rough=0.75)
    moss = kit.mat("mousse", "#4E9A3A", rough=0.6)
    engrave = kit.mat("gravure", "#4A4E5E", rough=0.8)
    kit.add(kit.brick((1.5, 0.9, 0.22), center=(x, 0, 0.11)), stone2, P, bevel=0.04)
    kit.add(kit.brick((1.1, 0.34, 1.5), center=(x, 0.04, 0.97)), stone, P, bevel=0.05)
    kit.add(kit.brick((0.8, 0.34, 0.24), center=(x, 0.04, 1.84)), stone, P, bevel=0.05)
    kit.add(kit.brick((0.44, 0.34, 0.14), center=(x, 0.04, 2.02)), stone, P, bevel=0.04)
    # inscription effacée (trois lignes gravées) et une fente
    for k, w in enumerate((0.6, 0.44, 0.52)):
        kit.add(kit.box((w, 0.04, 0.08), center=(x, -0.15, 1.42 - k * 0.2)), engrave, P, bevel=0.0)
    kit.add(kit.box((0.06, 0.04, 0.3), center=(x + 0.36, -0.15, 0.62), rot=(0, 25, 0)), engrave, P, bevel=0.0)
    # mousse sur le pied et le coin
    kit.add(kit.brick((0.6, 0.5, 0.08), center=(x - 0.3, -0.12, 0.25)), moss, P, bevel=0.02)
    kit.add(kit.brick((0.26, 0.2, 0.16), center=(x - 0.44, 0.0, 1.66)), moss, P, bevel=0.03)


def build(name: str) -> dict:
    kit = PetKit(name)
    for index, maker in enumerate((citrouille, lanterne, tombe)):
        maker(kit, I.slot(index + 1) * 1.4)
    return kit.result()
