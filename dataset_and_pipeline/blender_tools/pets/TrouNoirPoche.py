"""Trou Noir de Poche (Sigma, Cosmos) : « Un petit trou noir apprivoisé. Ne le nourris pas après minuit. »

En briques LEGO, très détaillé (Sigma : or massif, cristal et chrome, aucune lueur) : une petite boule noire d'encre
(octogones empilés) au visage tout mignon (grands yeux blancs brillants, petit sourire, joues violettes), entourée d'un
grand DISQUE D'ACCRÉTION en anneaux d'OR MASSIF, de cristal violet et de chrome qui TOURNE, de petits astéroïdes et une
cuillère aspirés qui tournent avec lui, et un collier en or avec une médaille « N ». Il flotte.
Parties animées : le disque (tourne), les débris (tournent).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    ink = kit.enamel("encre", "#0E0A16")
    ink2 = kit.enamel("encre_violette", "#1E1430")
    gold = kit.gold("or_massif", hammered=0.45)
    violet = kit.gem("cristal_violet", "#2A0A5A", "#A06AFF", "#F0E0FF")
    chrome = kit.chrome("chrome")
    cheek = kit.mat("joues", "#B47AFF")
    rock = kit.mat("asteroides", "#8A7A6E")

    # --- boule d'encre en octogones empilés ---
    c = 0.7
    for z, w, h in ((c - 0.24, 0.3, 0.1), (c - 0.12, 0.46, 0.14), (c, 0.52, 0.14), (c + 0.12, 0.46, 0.14), (c + 0.24, 0.3, 0.1)):
        kit.add(kit.brick((w, w, h), center=(0, 0, z)), ink, bevel=min(0.05, h * 0.35))
        # couche tournée de 45° plus petite (coins derrière le visage) et un peu plus haute (faces confondues = noir)
        kit.add(kit.brick((w * 0.7, w * 0.7, h + 0.012), center=(0, 0, z), rot=(0, 0, 45)), ink2,
                bevel=min(0.05, h * 0.35))

    # --- visage tout mignon ---
    P.eyes(kit, "Body", x=0.1, y=-0.265, z=c + 0.04, size=0.11, iris="#2A1A4A", pupil="round", sclera="#FFFFFF",
           tall=1.2, look=(0, 0.2))
    P.mouth(kit, "Body", y=-0.266, z=c - 0.1, w=0.08, smile=0.8, color="#B47AFF")
    for s in (-1, 1):
        kit.add(kit.box((0.06, 0.02, 0.04), center=(s * 0.17, -0.262, c - 0.05)), cheek, bevel=0.005)
    kit.add(kit.brick((0.4, 0.4, 0.04), center=(0, 0, c - 0.22)), gold, bevel=0.012)
    kit.add(kit.disc(0.05, 0.02, center=(0, -0.22, c - 0.28), normal=(0, -1, 0), sides=10), gold, bevel=0.0)
    kit.add(kit.box((0.012, 0.01, 0.05), center=(-0.015, -0.232, c - 0.28)), ink, bevel=0.0)
    kit.add(kit.box((0.012, 0.01, 0.05), center=(0.015, -0.232, c - 0.28)), ink, bevel=0.0)
    kit.add(kit.box((0.012, 0.01, 0.055), center=(0.0, -0.232, c - 0.28), rot=(0, 30, 0)), ink, bevel=0.0)

    # --- disque d'accrétion qui tourne ---
    for ring, (r, mat, n, size) in enumerate(((0.42, gold, 18, 0.12), (0.52, violet, 22, 0.1), (0.6, chrome, 26, 0.07))):
        for k in range(n):
            a = 2 * math.pi * k / n + ring * 0.2
            kit.add(kit.brick((size, 0.05, 0.04), center=(math.cos(a) * r, math.sin(a) * r, c), rot=(0, 0, math.degrees(a) + 90)),
                    mat, "Disk", bevel=0.006)
    kit.part("Disk", "Orbit", pivot=(0, 0, c), rot=(14, 0, 0), phase=0.9)

    # --- débris aspirés ---
    for k, (r, z, mat, size) in enumerate(((0.74, c + 0.12, rock, 0.07), (0.7, c - 0.14, rock, 0.05), (0.78, c + 0.02, chrome, 0.05))):
        a = k * 2.1
        kit.add(kit.brick((size * (2 if mat is chrome else 1), size * 0.6, size * 0.6),
                          center=(math.cos(a) * r, math.sin(a) * r, z), rot=(20, 30, 45)), mat, "Debris", bevel=0.008)
    kit.part("Debris", "Orbit", pivot=(0, 0, c), phase=-0.6)
    return kit.result()
