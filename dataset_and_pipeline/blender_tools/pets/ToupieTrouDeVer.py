"""Toupie Trou-de-Ver (Mythique, Absurdes) : « Toupie qui tourne si vite qu'elle aspire tout autour d'elle. »

En briques LEGO, très détaillée (Mythique : nacre, or et cristal, aucune lueur) : toupie en couches (pointe en or, corps
large en nacre violet pâle cerclé d'or, bandes de cristal violet et turquoise, poignée en or), un TROU DE VER en spirale
de cristal sombre sur le dessus, et des débris (cailloux, étoiles, une petite chaussette) aspirés qui tournent autour ;
visage tout étourdi sur le flanc (yeux en spirale, langue tirée). Elle flotte et tourne sur elle-même.
Parties animées : le trou de ver (tourne), les débris (tournent autour).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    pearl = kit.pearl("nacre", color="#EEE2FA", sheen="#C8F4FF")
    gold = kit.gold("or", hammered=0.3)
    violet = kit.gem("bande_violette", "#2A0A5A", "#8A4AE6", "#F0E0FF")
    teal = kit.gem("bande_turquoise", "#0A3A3A", "#2AD8C8", "#E0FFFA")
    hole = kit.gem("trou_de_ver", "#06041A", "#3A1A8A", "#B48AFF")
    rock = kit.mat("caillou", "#8A7A6E")
    sock = kit.mat("chaussette", "#FF5A8A")
    dark = kit.mat("traits", "#2A1A3A")
    tongue = kit.mat("langue", "#FF6A98")

    # --- toupie en couches ---
    kit.add(kit.wedge((0.12, 0.12, 0.2), center=(0, 0, 0.1), rot=(180, 0, 0), tip=0.1), gold, bevel=0.0)
    kit.add(kit.brick((0.3, 0.3, 0.1), center=(0, 0, 0.24)), gold, bevel=0.03)
    kit.add(kit.brick((0.56, 0.56, 0.14), center=(0, 0, 0.36)), pearl, bevel=0.05)
    kit.add(kit.brick((0.76, 0.76, 0.16), center=(0, 0, 0.5)), pearl, bevel=0.06)
    kit.add(kit.brick((0.8, 0.8, 0.05), center=(0, 0, 0.6)), gold, bevel=0.02)
    kit.add(kit.brick((0.7, 0.7, 0.1), center=(0, 0, 0.67)), pearl, bevel=0.04)
    for z, mat in ((0.44, violet), (0.55, teal)):
        kit.add(kit.brick((0.78 if z > 0.5 else 0.58, 0.78 if z > 0.5 else 0.58, 0.03), center=(0, 0, z)), mat, bevel=0.008)
    kit.add(kit.brick((0.12, 0.12, 0.18), center=(0, 0, 0.8)), gold, bevel=0.025)
    kit.add(kit.brick((0.18, 0.18, 0.05), center=(0, 0, 0.9)), gold, bevel=0.015)

    # --- visage étourdi sur le flanc ---
    for s in (-1, 1):
        cx = s * 0.13
        for k in range(4):
            r = 0.02 + k * 0.012
            kit.add(kit.box((r * 2, 0.012, 0.012), center=(cx, -0.385, 0.52 + (k % 2) * 0.006), rot=(0, k * 45, 0)), dark,
                    bevel=0.0)
    kit.add(kit.brick((0.08, 0.02, 0.03), center=(0, -0.385, 0.4)), dark, bevel=0.0)
    kit.add(kit.brick((0.05, 0.02, 0.05), center=(0.02, -0.39, 0.37)), tongue, bevel=0.008)

    # --- trou de ver en spirale sur le dessus (tourne) ---
    kit.add(kit.brick((0.44, 0.44, 0.03), center=(0, 0, 0.73)), hole, "Hole", bevel=0.01)
    for k in range(10):
        a = k * 0.7
        r = 0.04 + k * 0.018
        kit.add(kit.brick((0.05, 0.05, 0.03), center=(math.cos(a) * r, math.sin(a) * r, 0.755)), violet if k % 2 else teal,
                "Hole", bevel=0.0)
    kit.part("Hole", "Orbit", pivot=(0, 0, 0.74), phase=-2.0)

    # --- débris aspirés qui tournent autour ---
    for k, (r, z, mat, size) in enumerate(((0.58, 0.8, rock, 0.08), (0.62, 0.5, gold, 0.06), (0.54, 0.3, rock, 0.06),
                                           (0.66, 0.66, violet, 0.05), (0.6, 0.95, sock, 0.07))):
        a = k * 1.25
        kit.add(kit.brick((size, size * 0.8, size * (1.4 if mat is sock else 1)), center=(math.cos(a) * r, math.sin(a) * r, z),
                          rot=(30 * k, 20, 45)), mat, "Debris", bevel=0.01)
    kit.part("Debris", "Orbit", pivot=(0, 0, 0.6), phase=1.4)
    return kit.result()
