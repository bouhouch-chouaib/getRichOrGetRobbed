"""Ouroboros Infini (Sigma, Fantastiques) : « Serpent d'or holographique qui se mord la queue. »

En briques LEGO, très détaillé : un serpent d'or brillant qui forme un grand anneau debout et se mord la queue (il
flotte), cerclé tous les deux anneaux d'une bague HOLOGRAPHIQUE lumineuse (cyan, magenta, jaune), écailles en losanges
dorés plus foncés devant et derrière, ventre en plaques crème à l'intérieur de l'anneau ; tête de serpent royal au
sommet, mâchoires ouvertes sur le bout de sa queue, crocs, petites cornes, grands yeux magenta lumineux sur les côtés ;
une gemme lumineuse flotte au centre de l'anneau.
Parties animées : chaque anneau (vague), la tête.
"""

import math

import _parts as P
import procedural_geometry_recipes as G
from mathutils import Matrix, Vector
from pet_kit import PetKit

CENTER_Z, RADIUS = 0.82, 0.55
WIDTH, HEIGHT = 0.26, 0.24


def _ring(theta: float) -> Vector:
    """Point de l'anneau (dans le plan XZ, face au joueur) ; theta = 0 en haut, positif vers +X."""
    return Vector((RADIUS * math.sin(theta), 0.0, CENTER_Z + RADIUS * math.cos(theta)))


def build(name: str) -> dict:
    kit = PetKit(name)
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.18)
    deep = kit.mat("or_fonce", "#D88A0A", metal=0.85, rough=0.22)
    cream = kit.mat("ventre", "#FFF0B8", rough=0.2)
    holo = [kit.mat("holo_cyan", "#3AF4FF", rough=0.05, glow=1.8), kit.mat("holo_magenta", "#FF4AF0", rough=0.05,
                                                                          glow=1.8),
            kit.mat("holo_jaune", "#FFF45A", rough=0.05, glow=1.8)]
    gem = kit.mat("gemme", "#E6FCFF", rough=0.03, glow=2.6)
    fang = kit.mat("crocs", "#FFFFFF", rough=0.1)
    mouth = kit.mat("gueule", "#7A0A2A")

    # --- corps en anneau : du cou (theta = -30°) jusqu'au bout de la queue, dans la gueule (theta = +15°) ---
    n = 15
    thetas = [math.radians(-30 - 315 * k / n) for k in range(n + 1)]
    for k in range(n):
        a, b = _ring(thetas[k]), _ring(thetas[k + 1])
        f = k / (n - 1)
        w = WIDTH * (1 - 0.55 * max(0.0, f - 0.55) / 0.45)
        h = HEIGHT * w / WIDTH
        mid = (a + b) / 2
        out = (mid - Vector((0, 0, CENTER_Z))).normalized()
        frame = G.frame_matrix(mid, b - a, roll_hint=tuple(-out))  # Y local = vers l'extérieur de l'anneau
        r = frame.to_3x3()
        side = r @ Vector((1, 0, 0))
        length = (b - a).length
        part = f"Seg{k}"
        seg = kit.brick((w, h, length * 1.12))
        G.transform(seg, frame)
        kit.add(seg, gold, part, bevel=min(0.025, w * 0.15))
        plate = kit.brick((w * 0.7, h * 0.2, length))
        G.transform(plate, Matrix.Translation(-out * h * 0.42) @ frame)
        kit.add(plate, cream, part, bevel=0.008)
        for s in (-1, 1):  # losanges d'écailles devant et derrière
            scale = kit.brick((0.02, h * 0.42, h * 0.42), rot=(45, 0, 0))
            G.transform(scale, Matrix.Translation(side * s * (w / 2 + 0.008)) @ frame)
            kit.add(scale, deep, part, bevel=0.004)
        if k % 2 == 0:  # bague holographique
            band = kit.brick((w * 1.1, h * 1.1, 0.045))
            G.transform(band, frame)
            kit.add(band, holo[(k // 2) % 3], part, bevel=0.006)
        kit.part(part, "Serpent", pivot=tuple(mid), phase=k * 0.42)

    # --- tête au sommet, construite face à +X puis posée sur l'anneau (theta = -8°) ---
    top = CENTER_Z + RADIUS
    kit.add(kit.brick((0.44, 0.32, 0.28), center=(-0.02, 0, top + 0.04)), gold, "Head", bevel=0.035)
    kit.add(kit.brick((0.32, 0.34, 0.06), center=(0.0, 0, top + 0.19)), deep, "Head", bevel=0.012)
    kit.add(kit.brick((0.26, 0.28, 0.1), center=(0.28, 0, top + 0.1), rot=(0, -14, 0)), gold, "Head", bevel=0.02)
    kit.add(kit.brick((0.24, 0.26, 0.07), center=(0.26, 0, top - 0.07), rot=(0, 16, 0)), gold, "Head", bevel=0.015)
    kit.add(kit.brick((0.18, 0.22, 0.1), center=(0.2, 0, top + 0.01)), mouth, "Head", bevel=0.01)
    for s in (-1, 1):
        kit.add(kit.box((0.03, 0.03, 0.02), center=(0.39, s * 0.05, top + 0.16)), deep, "Head", bevel=0.0)
        kit.add(kit.wedge((0.03, 0.03, 0.07), center=(0.32, s * 0.09, top + 0.03), rot=(180, 0, 0), tip=0.15), fang,
                "Head", bevel=0.0)
        P.horn(kit, "Head", (-0.12, s * 0.1, top + 0.2), (-0.8, s * 0.3, 0.6), 0.18, 0.06, [gold, deep], segments=2)
        # grands yeux sur les côtés : blanc, iris magenta lumineux, fente, reflet
        y = s * 0.16
        kit.add(kit.box((0.14, 0.03, 0.13), center=(0.04, y + s * 0.005, top + 0.09)), kit.mat("blanc", "#FFFFFF"),
                "Head", bevel=0.01)
        kit.add(kit.box((0.1, 0.02, 0.1), center=(0.05, y + s * 0.02, top + 0.09)),
                kit.mat("iris", "#FF3AF0", rough=0.1, glow=2.4), "Head", bevel=0.006)
        kit.add(kit.box((0.025, 0.016, 0.08), center=(0.05, y + s * 0.03, top + 0.09)), kit.mat("pupille", "#0C0C10"),
                "Head", bevel=0.0)
        kit.add(kit.box((0.03, 0.01, 0.03), center=(0.02, y + s * 0.038, top + 0.12)), kit.mat("reflet", "#FFFFFF"),
                "Head", bevel=0.0)
    pivot = (0.0, 0.0, CENTER_Z)
    kit.turn("Head", pivot, (0, -8, 0))
    hp = _ring(math.radians(-24))
    kit.part("Head", "Head", pivot=tuple(hp), rot=(0, -24, 0))

    # --- gemme lumineuse au centre de l'anneau ---
    kit.add(kit.brick((0.2, 0.2, 0.2), center=(0, 0, CENTER_Z), rot=(45, 35.26, 0)), gem, bevel=0.012)
    kit.add(kit.brick((0.12, 0.12, 0.12), center=(0, 0, CENTER_Z), rot=(0, 45, 45)), gold, bevel=0.01)
    return kit.result()
