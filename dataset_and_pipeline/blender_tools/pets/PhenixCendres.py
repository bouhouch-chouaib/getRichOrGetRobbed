"""Phénix de Cendres (Rare, Fantastiques) : « Oiseau gris qui fume en permanence. »

En briques LEGO, très détaillé : phénix couleur de cendre (gris anthracite et gris clair), fissures de braise orange
LUMINEUSES en zigzag sur le poitrail, crête de cinq plumes cendrées rabattues à pointes de braise, yeux orange
lumineux à l'air fatigué, bec crochu gris, ailes à demi ouvertes en trois rangs dont les rémiges rougeoient, longue
traîne de cinq plumes à bouts de braise, volutes de fumée en blocs gris qui montent du dos.
Parties animées : tête, ailes, queue, fumée (pattes fixes : il sautille avec le corps).
"""

import math

import _parts as P
import procedural_geometry_recipes as G
from mathutils import Vector
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    ash = kit.mat("cendre", "#767B8E")
    light = kit.mat("cendre_claire", "#B0B6C8")
    dark = kit.mat("anthracite", "#43475A")
    ember = kit.mat("braise", "#FF6A12", rough=0.2, glow=2.6)
    smoke = kit.mat("fumee", "#CDD1DC", rough=0.6)
    beak = kit.mat("bec", "#5A5E70")

    # --- corps de l'oiseau : ventre, poitrail bombé, dos qui descend vers la queue ---
    kit.add(kit.brick((0.5, 0.54, 0.22), center=(0, 0.06, 0.44)), ash, bevel=0.03)
    kit.add(kit.brick((0.6, 0.66, 0.3), center=(0, 0.04, 0.68)), ash, bevel=0.035)
    kit.add(kit.brick((0.46, 0.12, 0.44), center=(0, -0.3, 0.6)), light, bevel=0.03)
    kit.add(kit.slope((0.42, 0.12, 0.14), center=(0, -0.34, 0.33), facing="-Y", top=0.3, rot=(180, 0, 0)), light,
            bevel=0.015)
    kit.add(kit.slope((0.5, 0.26, 0.2), center=(0, 0.46, 0.7), facing="+Y", top=0.3), dark, bevel=0.02)
    kit.add(kit.brick((0.4, 0.34, 0.16), center=(0, -0.08, 0.89)), ash, bevel=0.025)
    # fissures de braise en zigzag sur le poitrail
    for x, z, ang, h in ((0.08, 0.72, 30, 0.12), (0.12, 0.62, -25, 0.1), (0.08, 0.53, 30, 0.08), (-0.1, 0.66, -30, 0.12),
                         (-0.13, 0.56, 25, 0.09), (0.0, 0.45, 0, 0.06)):
        kit.add(kit.box((0.025, 0.012, h), center=(x, -0.364, z), rot=(0, ang, 0)), ember, bevel=0.0)

    # --- tête, bec crochu, crête rabattue à pointes de braise, yeux fatigués ---
    kit.add(kit.brick((0.4, 0.4, 0.34), center=(0, -0.16, 1.1)), ash, "Head", bevel=0.035)
    kit.add(kit.brick((0.34, 0.06, 0.12), center=(0, -0.37, 1.0)), light, "Head", bevel=0.012)
    kit.add(kit.brick((0.16, 0.14, 0.1), center=(0, -0.41, 1.09)), beak, "Head", bevel=0.015)
    kit.add(kit.slope((0.14, 0.08, 0.1), center=(0, -0.5, 1.03), facing="-Y", top=0.25, rot=(180, 0, 0)), beak, "Head",
            bevel=0.01)
    for k in range(5):
        dx = (k - 2) * 0.06
        base = Vector((dx, -0.22 + abs(k - 2) * 0.03, 1.27))
        d = Vector((dx * 1.2, 0.75, 0.75)).normalized()
        length = 0.26 - abs(k - 2) * 0.04
        P.tuft_piece(kit, "Head", tuple(base), tuple(d), length, 0.09, dark)
        tip = kit.wedge((0.05, 0.05, 0.08), tip=0.1)
        G.transform(tip, G.frame_matrix(base + d * (length + 0.03), d))
        kit.add(tip, ember, "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.11, y=-0.37, z=1.16, size=0.1, iris="#FF8A1E", pupil="round", lid=ash, lid_drop=0.22,
           glow=1.4, tall=0.9)

    # --- ailes à demi ouvertes, rémiges qui rougeoient ---
    P.spread_wings(kit, x=0.3, y=0.08, z=0.78, span=0.56, height=0.36, mats=(ash, dark, ember), style="feather",
                   sweep=35, lift=18)

    # --- longue traîne de cinq plumes à bouts de braise ---
    base = Vector((0, 0.5, 0.66))
    for k in range(5):
        yaw = math.radians((k - 2) * 13)
        pitch = math.radians(-16 - abs(k - 2) * 4)
        d = Vector((math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
        length = 0.72 - abs(k - 2) * 0.1
        plume = kit.brick((0.12, 0.05, length))
        G.transform(plume, G.frame_matrix(base + d * (length / 2), d, roll_hint=(0, 0, -1)))
        kit.add(plume, (dark, ash, light, ash, dark)[k], "Tail", bevel=0.012)
        tip = kit.wedge((0.11, 0.05, 0.12), tip=0.12)
        G.transform(tip, G.frame_matrix(base + d * (length + 0.05), d, roll_hint=(0, 0, -1)))
        kit.add(tip, ember, "Tail", bevel=0.0)
    kit.part("Tail", "Tail", pivot=tuple(base))
    P.bird_feet(kit, x=0.14, y=0.06, h=0.3, w=0.075, color=dark, claw=dark)

    # --- volutes de fumée qui montent du dos (ondulent) ---
    for k, (x, y, z, w) in enumerate(((0.06, 0.22, 1.0, 0.16), (-0.04, 0.28, 1.16, 0.13), (0.08, 0.32, 1.3, 0.1),
                                      (0.02, 0.38, 1.42, 0.07))):
        kit.add(kit.brick((w, w, w), center=(x, y, z), rot=(0, 0, 20 * k)), smoke, "Smoke", bevel=0.03)
    kit.part("Smoke", "Leaf", pivot=(0, 0.2, 0.94), phase=0.8)
    kit.part("Head", "Head", pivot=(0, -0.12, 0.94))
    return kit.result()
