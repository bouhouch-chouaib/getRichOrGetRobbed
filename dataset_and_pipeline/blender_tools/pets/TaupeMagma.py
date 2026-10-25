"""Taupe Magma (Épique, Volcan) : « Creuse des tunnels dans la lave avec ses griffes incandescentes. »

En briques LEGO, très détaillée (Épique : chrome et cristal, aucune lueur) : taupe ronde au pelage brun chocolat
(plus clair sur le ventre), gros nez rose étoilé, petits yeux plissés derrière des lunettes de mineur chromées,
casque de mineur chromé à lampe de cristal jaune, énormes pattes avant de creuseur dont les griffes sont des cristaux
orange et rouges, petites pattes arrière, mottes de roche volcanique et de lave émaillée autour d'elle.
Parties animées : bras (creusent), tête, pattes arrière.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    fur = kit.mat("pelage", "#6A4430")
    fur2 = kit.mat("pelage_clair", "#9A6A4A")
    pink = kit.mat("nez", "#FF8AB0")
    chrome = kit.chrome("chrome")
    lamp = kit.gem("lampe", "#C88A0A", "#FFE06A", "#FFFFFF")
    claw = kit.gem("griffes", "#5A0A0A", "#FF5A1E", "#FFD0A0")
    rock = kit.mat("roche", "#3A3438")
    lava = kit.enamel("lave", "#FF6A12")

    # --- corps rond, ventre clair ---
    kit.add(kit.brick((0.64, 0.7, 0.5), center=(0, 0.04, 0.32)), fur, bevel=0.08)
    kit.add(kit.brick((0.54, 0.6, 0.6), center=(0, 0.04, 0.34)), fur, bevel=0.08)
    kit.add(kit.brick((0.4, 0.06, 0.36), center=(0, -0.32, 0.3)), fur2, bevel=0.02)

    # --- tête : nez étoilé, lunettes et casque de mineur ---
    kit.add(kit.brick((0.44, 0.34, 0.32), center=(0, -0.3, 0.6)), fur, "Head", bevel=0.05)
    kit.add(kit.brick((0.16, 0.14, 0.12), center=(0, -0.52, 0.54)), fur2, "Head", bevel=0.03)
    kit.add(kit.brick((0.12, 0.08, 0.1), center=(0, -0.62, 0.55)), pink, "Head", bevel=0.025)
    for k in range(6):
        a = math.radians(60 * k)
        kit.add(kit.box((0.03, 0.03, 0.03), center=(math.cos(a) * 0.07, -0.665, 0.55 + math.sin(a) * 0.07)), pink, "Head",
                bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.brick((0.12, 0.04, 0.09), center=(s * 0.1, -0.48, 0.66)), chrome, "Head", bevel=0.02)
        kit.add(kit.box((0.06, 0.012, 0.012), center=(s * 0.1, -0.505, 0.66)), kit.mat("yeux", "#141014"), "Head",
                bevel=0.0)
    kit.add(kit.box((0.44, 0.03, 0.03), center=(0, -0.47, 0.68)), chrome, "Head", bevel=0.0)
    # casque de mineur en dôme à gradins, arête sur le dessus
    kit.add(kit.brick((0.5, 0.44, 0.03), center=(0, -0.28, 0.75)), chrome, "Head", bevel=0.01)
    for z, w, d in ((0.8, 0.42, 0.36), (0.87, 0.34, 0.3), (0.93, 0.22, 0.2)):
        kit.add(kit.brick((w, d, 0.07), center=(0, -0.27, z)), chrome, "Head", bevel=0.025)
    kit.add(kit.brick((0.05, 0.38, 0.04), center=(0, -0.27, 0.96)), chrome, "Head", bevel=0.01)
    kit.add(kit.brick((0.1, 0.06, 0.08), center=(0, -0.46, 0.83)), chrome, "Head", bevel=0.015)
    kit.add(kit.brick((0.08, 0.04, 0.06), center=(0, -0.5, 0.83)), lamp, "Head", bevel=0.012)
    kit.part("Head", "Head", pivot=(0, -0.2, 0.5))

    # --- énormes pattes avant de creuseur, griffes de cristal ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        kit.add(kit.brick((0.14, 0.18, 0.22), center=(s * 0.34, -0.2, 0.28)), fur, part, bevel=0.035)
        kit.add(kit.brick((0.24, 0.2, 0.08), center=(s * 0.4, -0.34, 0.14)), fur2, part, bevel=0.025)
        for k in range(4):
            kit.add(kit.wedge((0.05, 0.05, 0.14), center=(s * (0.3 + k * 0.06), -0.5, 0.12), rot=(100, 0, 0), tip=0.15),
                    claw, part, bevel=0.0)
        kit.part(part, "Arm", pivot=(s * 0.3, -0.14, 0.38), phase=0.0 if s > 0 else math.pi)
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.12, 0.16, 0.1), center=(s * 0.2, 0.3, 0.05)), fur2, part, bevel=0.025)
        kit.part(part, "Leg", pivot=(s * 0.2, 0.3, 0.12), phase=0.0 if s > 0 else math.pi)

    # --- mottes de roche volcanique et de lave ---
    for x, y, w, mat in ((0.42, -0.5, 0.1, rock), (-0.46, -0.44, 0.12, rock), (0.3, -0.6, 0.06, lava), (-0.36, -0.58, 0.07, lava),
                         (0.5, 0.2, 0.09, rock)):
        kit.add(kit.brick((w, w, w * 0.7), center=(x, y, w * 0.35), rot=(0, 0, 30)), mat, bevel=w * 0.25)
    return kit.result()
