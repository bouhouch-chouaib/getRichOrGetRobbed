"""Lotus de l'Espace (Mythique, Plantes) : « Lotus rose flottant avec une mini-galaxie au centre. »

En briques LEGO, très détaillé : nénuphar vert à nervures et encoche, sépales, deux couronnes de pétales roses (rose vif
dehors, rose pâle à bout blanc dedans), cœur jaune avec un petit visage émerveillé ; au-dessus du cœur flotte une
MINI-GALAXIE LUMINEUSE (noyau blanc, deux bras en spirale violet et cyan, deux planètes) qui tourne. Il flotte.
Parties animées : les pétales (s'ouvrent doucement), la galaxie (tourne).
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    pad = kit.mat("nenuphar", "#2EC24E")
    pad2 = kit.mat("nenuphar_fonce", "#1E9A3A")
    sepal = kit.mat("sepales", "#4ED24A")
    pink = kit.mat("rose", "#FF4AB4")
    pink2 = kit.mat("rose_pale", "#FF9AD6")
    white = kit.mat("blanc_rose", "#FFE6F4")
    yellow = kit.mat("coeur", "#FFD23A")
    core = kit.mat("noyau", "#FFFFFF", rough=0.1, glow=3.0)
    violet = kit.mat("bras_violet", "#B07AFF", rough=0.1, glow=2.4)
    cyan = kit.mat("bras_cyan", "#5AE6FF", rough=0.1, glow=2.4)
    planet = kit.mat("planete", "#FF8A3A", rough=0.2, glow=0.8)
    planet2 = kit.mat("planete_bleue", "#3A8AFF", rough=0.2, glow=0.8)

    # --- nénuphar ---
    kit.add(kit.brick((0.96, 0.8, 0.06), center=(0, 0.02, 0.03)), pad, bevel=0.02)
    for y in (-0.44, 0.48):
        kit.add(kit.brick((0.7, 0.12, 0.05), center=(0, y, 0.025)), pad, bevel=0.02)
    kit.add(kit.brick((0.08, 0.3, 0.06), center=(0.0, -0.4, 0.036)), pad2, bevel=0.0)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        kit.add(kit.box((0.36, 0.02, 0.012), center=(math.cos(a) * 0.22, 0.02 + math.sin(a) * 0.22, 0.064),
                        rot=(0, 0, math.degrees(a))), pad2, bevel=0.0)

    # --- sépales, pétales, cœur jaune et visage ---
    kit.add(kit.brick((0.36, 0.36, 0.1), center=(0, 0, 0.12)), sepal, bevel=0.03)
    P.petals(kit, "Petals", (0, 0, 0.16), 8, 0.42, 0.2, [pink, pink2], facing=(0, 0, 1), tilt=0.55)
    P.petals(kit, "Petals", (0, 0, 0.22), 6, 0.32, 0.16, [pink2, white], facing=(0, 0, 1), tilt=1.5, start=math.pi / 6)
    kit.part("Petals", "Blossom", pivot=(0, 0, 0.16))
    kit.add(kit.brick((0.36, 0.36, 0.18), center=(0, 0, 0.32)), yellow, bevel=0.04)
    P.eyes(kit, "Body", x=0.08, y=-0.18, z=0.34, size=0.09, iris="#6A2AE6", pupil="round", tall=1.2, look=(0, 0.6))
    kit.add(kit.brick((0.05, 0.02, 0.05), center=(0, -0.185, 0.26)), kit.mat("bouche", "#7A1E4A"), bevel=0.01)

    # --- mini-galaxie lumineuse qui tourne ---
    gz = 0.6
    kit.add(kit.brick((0.08, 0.08, 0.08), center=(0, 0, gz), rot=(45, 35, 0)), core, "Galaxy", bevel=0.01)
    for arm, mat in ((0, violet), (1, cyan)):
        for k in range(6):
            r = 0.06 + 0.035 * k
            a = k * 0.75 + arm * math.pi
            w = 0.05 - k * 0.005
            kit.add(kit.brick((w, w, 0.02), center=(math.cos(a) * r, math.sin(a) * r, gz), rot=(0, 0, math.degrees(a))),
                    mat, "Galaxy", bevel=0.0)
    kit.add(kit.brick((0.06, 0.06, 0.06), center=(0.3, 0.06, gz + 0.02)), planet, "Galaxy", bevel=0.015)
    kit.add(kit.brick((0.045, 0.045, 0.045), center=(-0.26, -0.16, gz - 0.02)), planet2, "Galaxy", bevel=0.01)
    kit.part("Galaxy", "Orbit", pivot=(0, 0, gz), phase=0.8)
    return kit.result()
