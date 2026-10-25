"""Calmar Colosse (Divin, Abysses) : « Calmar géant qui a déjà avalé trois sous-marins. »

En briques LEGO, très détaillé (Divin : or blanc et cristal, aucune lueur) : calmar géant bordeaux à manteau pointu
et nageoires en losange, ventre rose pâle, ÉNORMES yeux au regard repu, bracelets en OR BLANC sur les bras, ventouses
en cristal rose ; huit bras courts et deux longs tentacules qui enlacent un petit sous-marin jaune (hublots en
cristal, hélice chromée) ; il flotte et nage par propulsion. Parties animées : bras, tentacules, nageoires.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    wine = kit.enamel("bordeaux", "#8A1E3A")
    deep = kit.enamel("bordeaux_fonce", "#5A0E22")
    belly = kit.mat("ventre", "#F2A8B8")
    whitegold = kit.chrome("or_blanc", tint="#F6F0E0", rough=0.14)
    cups = kit.gem("ventouses", "#8A2A4A", "#FF8AB0", "#FFE6EE")
    sub = kit.enamel("sous_marin", "#FFC21E")
    port = kit.gem("hublots", "#1E3A6A", "#7AC8FF", "#E6F6FF")
    prop = kit.chrome("helice")

    # --- manteau pointu et nageoires en losange ---
    kit.add(kit.brick((0.5, 0.46, 0.4), center=(0, 0.04, 0.62)), wine, bevel=0.06)
    kit.add(kit.brick((0.42, 0.4, 0.34), center=(0, 0.06, 0.96)), wine, bevel=0.06)
    kit.add(kit.brick((0.3, 0.3, 0.24), center=(0, 0.08, 1.24)), wine, bevel=0.05)
    kit.add(kit.wedge((0.18, 0.18, 0.2), center=(0, 0.08, 1.44), tip=0.1), deep, bevel=0.0)
    kit.add(kit.brick((0.4, 0.06, 0.6), center=(0, -0.2, 0.8)), belly, bevel=0.025)
    # anneaux d'or blanc et taches de cristal sur le manteau
    kit.add(kit.brick((0.54, 0.5, 0.04), center=(0, 0.04, 0.8)), whitegold, bevel=0.012)
    kit.add(kit.brick((0.46, 0.44, 0.04), center=(0, 0.06, 1.12)), whitegold, bevel=0.012)
    for x, y, z in ((0.255, 0.1, 0.62), (-0.255, 0.0, 0.66), (0.215, -0.02, 1.0), (-0.215, 0.14, 0.94), (0.0, 0.28, 0.7),
                    (0.08, 0.27, 1.02)):
        n = (1, 0, 0) if abs(x) > 0.1 else (0, 1, 0)
        kit.add(kit.brick((0.03 if n[0] else 0.07, 0.07 if n[0] else 0.03, 0.07), center=(x, y, z), rot=(45 if n[0] else 0,
                          0 if n[0] else 45, 0)), cups, bevel=0.006)
    for s, part in ((1, "FinL"), (-1, "FinR")):
        kit.add(kit.brick((0.24, 0.05, 0.24), center=(s * 0.26, 0.08, 1.24), rot=(0, 45, 0)), deep, part, bevel=0.012)
        kit.add(kit.brick((0.1, 0.06, 0.1), center=(s * 0.33, 0.08, 1.24), rot=(0, 45, 0)), whitegold, part, bevel=0.008)
        kit.part(part, "Fin", pivot=(s * 0.16, 0.08, 1.24), phase=float(s))

    # --- énormes yeux repus ---
    P.eyes(kit, "Body", x=0.14, y=-0.24, z=0.6, size=0.16, iris="#FFC21E", pupil="slit", lid=wine, lid_drop=0.3,
           tall=1.0)

    # --- huit bras courts à bracelets ---
    for k in range(8):
        a = math.radians(-90 + 22.5 + 45 * k)
        d = (math.cos(a) * 0.6, math.sin(a) * 0.6, -1.0)
        base = (math.cos(a) * 0.16, 0.04 + math.sin(a) * 0.14, 0.42)
        part = f"Arm{k}"
        P.tentacle(kit, part, base, d, 0.36, 0.11, wine, cups=cups, phase=k * 0.7, segments=4, curl=0.5)
        kit.add(kit.brick((0.12, 0.12, 0.03), center=(base[0] + d[0] * 0.08, base[1] + d[1] * 0.08, 0.34)), whitegold, part,
                bevel=0.008)

    # --- deux longs tentacules qui enlacent un sous-marin ---
    for s in (-1, 1):
        part = f"Long{0 if s > 0 else 1}"
        P.chain(kit, part, [(s * 0.1, -0.12, 0.42), (s * 0.2, -0.36, 0.3), (s * 0.18, -0.56, 0.3), (s * 0.06, -0.66, 0.42)],
                0.08, [wine, deep], taper=0.01)
        kit.part(part, "Tentacle", pivot=(s * 0.1, -0.12, 0.42), phase=1.0 + s)
    kit.add(kit.brick((0.18, 0.4, 0.18), center=(0, -0.62, 0.38)), sub, bevel=0.06)
    kit.add(kit.brick((0.08, 0.12, 0.1), center=(0, -0.6, 0.51)), sub, bevel=0.02)
    for s in (-1, 1):
        kit.add(kit.disc(0.035, 0.02, center=(s * 0.095, -0.64, 0.4), normal=(s, 0, 0), sides=8), port, bevel=0.0)
    kit.add(kit.brick((0.16, 0.02, 0.04), center=(0, -0.42, 0.38)), prop, bevel=0.0)
    kit.add(kit.brick((0.04, 0.02, 0.16), center=(0, -0.42, 0.38)), prop, bevel=0.0)
    return kit.result()
