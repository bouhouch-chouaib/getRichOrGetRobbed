"""Léviathan Abyssal (Divin, Fantastiques) : « Dragon des mers bleu marine, bioluminescence cyan. »

En briques LEGO, très détaillé : long dragon des mers bleu marine qui ondule en l'air (il flotte), ventre bleu canard en
plaques, lignes et points de BIOLUMINESCENCE cyan lumineux le long des flancs, nageoires dorsales cyan translucides,
grandes nageoires pectorales, nageoire de queue en éventail ; tête de dragon à museau long, naseaux et yeux cyan
lumineux, cornes rabattues à bouts cyan, collerettes de nageoires de chaque côté, barbillons qui pendent, mâchoire à
crocs qui s'ouvre. Parties animées : chaque anneau (vague), tête, mâchoire, nageoires.
"""

import _parts as P
import procedural_geometry_recipes as G
from mathutils import Matrix, Vector
from pet_kit import PetKit

PATH = [(0.0, -0.32, 0.92), (0.0, -0.16, 0.72), (0.08, 0.04, 0.6), (0.12, 0.24, 0.64), (0.06, 0.42, 0.8),
        (-0.06, 0.58, 0.88), (-0.14, 0.76, 0.8), (-0.12, 0.92, 0.62), (-0.04, 1.04, 0.46), (0.04, 1.14, 0.34)]
WIDTH, HEIGHT = 0.32, 0.28


def build(name: str) -> dict:
    kit = PetKit(name)
    navy = kit.mat("marine", "#16307E", rough=0.12)
    deep = kit.mat("abysse", "#0C1C52", rough=0.12)
    belly = kit.mat("ventre", "#2A9AC0", rough=0.15)
    cyan = kit.mat("cyan", "#1EF4FF", rough=0.1, glow=2.6)
    fin = kit.mat("nageoire", "#3AD8FF", rough=0.1, glow=1.2)
    fang = kit.mat("crocs", "#F0FAFF", rough=0.1)
    mouth = kit.mat("gueule", "#1A0A3A")

    # --- corps en anneaux qui ondulent, lignes lumineuses, nageoires dorsales ---
    P.snake(kit, PATH, WIDTH, HEIGHT, [navy, deep], belly=belly)
    pts = [Vector(p) for p in PATH]
    n = len(pts) - 1
    for k in range(n):
        a, b = pts[k], pts[k + 1]
        f = k / (n - 1)
        w = WIDTH * (1 - 0.55 * max(0.0, f - 0.55) / 0.45)  # même affinement que P.snake
        h = HEIGHT * w / WIDTH
        length = (b - a).length
        frame = G.frame_matrix((a + b) / 2, b - a, roll_hint=(0, 0, -1))
        r = frame.to_3x3()
        side, up = r @ Vector((1, 0, 0)), r @ Vector((0, 1, 0))
        part = f"Seg{k}"
        for s in (-1, 1):  # lignes de bioluminescence sur les flancs
            line = kit.brick((0.02, h * 0.18, length * 0.8))
            G.transform(line, Matrix.Translation(side * s * (w / 2 + 0.006)) @ frame)
            kit.add(line, cyan, part, bevel=0.0)
            dot = kit.brick((0.02, 0.04, 0.04))
            G.transform(dot, Matrix.Translation(side * s * (w / 2 + 0.006) + up * h * 0.28) @ frame)
            kit.add(dot, cyan, part, bevel=0.0)
        if 0 < k < n - 1:  # nageoire dorsale
            dorsal = kit.wedge((length * 0.8, 0.03, 0.12 + 0.06 * (1 - f)), tip=0.1)
            G.transform(dorsal, G.frame_matrix((a + b) / 2 + up * (h / 2 + 0.05), up, roll_hint=tuple(side)))
            kit.add(dorsal, fin, part, bevel=0.0)
    # nageoire de queue en éventail (sur le dernier anneau)
    tail, d = pts[-1], (pts[-1] - pts[-2]).normalized()
    for pitch in (-0.7, 0.0, 0.7):
        direction = (d + Vector((0, 0, pitch))).normalized()
        blade = kit.wedge((0.03, 0.16, 0.3), tip=0.2)
        G.transform(blade, G.frame_matrix(tail + direction * 0.15, direction, roll_hint=(1, 0, 0)))
        kit.add(blade, fin if pitch else cyan, f"Seg{n - 1}", bevel=0.0)
    # grandes nageoires pectorales
    for s, part in ((1, "FinL"), (-1, "FinR")):
        for j, (length, mat) in enumerate(((0.36, fin), (0.28, cyan), (0.22, fin))):
            blade = kit.box((length, 0.18 - j * 0.03, 0.03), center=(s * (0.16 + length / 2), -0.08 + j * 0.1,
                                                                     0.64 - j * 0.02), rot=(0, s * -20, s * -20))
            kit.add(blade, mat, part, bevel=0.0)
        kit.part(part, "Fin", pivot=(s * 0.16, 0.0, 0.64), phase=float(s))

    # --- tête de dragon des mers ---
    kit.add(kit.brick((0.4, 0.42, 0.3), center=(0, -0.48, 1.04)), navy, "Head", bevel=0.035)
    kit.add(kit.brick((0.32, 0.32, 0.14), center=(0, -0.8, 1.0)), navy, "Head", bevel=0.025)
    kit.add(kit.slope((0.32, 0.3, 0.1), center=(0, -0.78, 1.12), facing="-Y", top=0.3), deep, "Head", bevel=0.012)
    kit.add(kit.brick((0.34, 0.34, 0.06), center=(0, -0.46, 1.21)), deep, "Head", bevel=0.012)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.03, 0.03), center=(s * 0.08, -0.965, 1.05)), cyan, "Head", bevel=0.0)
        P.horn(kit, "Head", (s * 0.14, -0.36, 1.18), (s * 0.3, 0.85, 0.5), 0.36, 0.08, [navy, deep, cyan], segments=3)
        for j in range(3):  # collerette de nageoires
            blade = kit.wedge((0.03, 0.12, 0.24 - j * 0.04), tip=0.15)
            direction = Vector((s * 1.0, 0.5 + j * 0.25, 0.35 - j * 0.3)).normalized()
            G.transform(blade, G.frame_matrix(Vector((s * 0.2, -0.42 + j * 0.06, 1.04)) + direction * 0.1, direction,
                                              roll_hint=(0, 0, 1)))
            kit.add(blade, fin if j != 1 else cyan, "Head", bevel=0.0)
        P.chain(kit, "Head", [(s * 0.14, -0.9, 0.96), (s * 0.2, -0.94, 0.84), (s * 0.22, -0.92, 0.72)], 0.03, [cyan])
        for z in (1.0, 1.08):  # points lumineux sur les joues
            kit.add(kit.box((0.02, 0.04, 0.04), center=(s * 0.205, -0.56 + (z - 1.0) * 1.2, z)), cyan, "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.12, y=-0.69, z=1.1, size=0.11, iris="#1EF4FF", pupil="slit", lid=navy, lid_drop=0.06,
           brow=deep, brow_angle=16, glow=2.6, tall=0.8)
    for k in range(4):  # crocs du haut
        kit.add(kit.wedge((0.04, 0.03, 0.06), center=((k - 1.5) * 0.08, -0.93, 0.91), rot=(180, 0, 0), tip=0.15), fang,
                "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.34, 0.94))

    # --- mâchoire du bas qui s'ouvre ---
    kit.add(kit.brick((0.3, 0.34, 0.08), center=(0, -0.76, 0.86)), navy, "Jaw", bevel=0.02)
    kit.add(kit.brick((0.24, 0.28, 0.03), center=(0, -0.76, 0.905)), mouth, "Jaw", bevel=0.0)
    kit.add(kit.brick((0.22, 0.26, 0.04), center=(0, -0.74, 0.81)), belly, "Jaw", bevel=0.008)
    for k in range(3):
        kit.add(kit.wedge((0.04, 0.03, 0.05), center=((k - 1) * 0.08, -0.9, 0.93), tip=0.15), fang, "Jaw", bevel=0.0)
    kit.part("Jaw", "Jaw", pivot=(0, -0.6, 0.9), follows="Head")
    return kit.result()
