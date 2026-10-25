"""Tortue-Burger (Commun, Hybrides) : « Tortue à la carapace en hamburger. »

En briques LEGO, très détaillée : tortue vert vif (tête ronde à grands yeux, sourire gourmand, joues roses, pattes
trapues à griffes, petite queue) dont la carapace est un HAMBURGER : pain du dessous doré, steak brun grillé, fromage
jaune qui coule aux coins, salade verte frisée qui dépasse, rondelles de tomate rouge, pain du dessus en dôme doré avec
graines de sésame. Parties animées : tête, 4 pattes, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.mat("tortue", "#4ED23A")
    light = kit.mat("tortue_claire", "#A6EE6A")
    bun = kit.mat("pain", "#F2A43A")
    bun2 = kit.mat("pain_dore", "#D8822A")
    patty = kit.mat("steak", "#6A3414")
    grill = kit.mat("grill", "#3E1E0A")
    cheese = kit.mat("fromage", "#FFD21E")
    lettuce = kit.mat("salade", "#46D22E")
    tomato = kit.mat("tomate", "#FF2E2E")
    seed = kit.mat("sesame", "#FFF4D6")
    claw = kit.mat("griffes", "#FFF4D6")
    pink = kit.mat("joues", "#FF8AB0")

    # --- burger-carapace en couches ---
    kit.add(kit.brick((0.7, 0.8, 0.12), center=(0, 0.04, 0.32)), bun2, bevel=0.04)
    kit.add(kit.brick((0.76, 0.86, 0.1), center=(0, 0.04, 0.42)), patty, bevel=0.035)
    for k in range(3):
        kit.add(kit.box((0.6, 0.03, 0.02), center=(0, -0.2 + k * 0.2, 0.47)), grill, bevel=0.0)
    kit.add(kit.brick((0.8, 0.9, 0.03), center=(0, 0.04, 0.485), rot=(0, 0, 45)), cheese, bevel=0.008)
    for x, y in ((0.4, 0.5), (-0.4, -0.42), (0.42, -0.4), (-0.4, 0.5)):
        kit.add(kit.wedge((0.08, 0.04, 0.12), center=(x * 0.82, y * 0.82, 0.43), rot=(180, 0, 45), tip=0.3), cheese,
                bevel=0.0)
    for k in range(10):
        a = math.radians(36 * k)
        kit.add(kit.brick((0.16, 0.08, 0.05), center=(math.cos(a) * 0.4, 0.04 + math.sin(a) * 0.45, 0.51),
                          rot=(0, 15, math.degrees(a) + 90)), lettuce, bevel=0.012)
    for x, y in ((0.2, -0.24), (-0.22, 0.16), (0.16, 0.3)):
        kit.add(kit.brick((0.2, 0.2, 0.04), center=(x, y, 0.53)), tomato, bevel=0.015)
    kit.add(kit.brick((0.74, 0.84, 0.14), center=(0, 0.04, 0.6)), bun, bevel=0.05)
    kit.add(kit.brick((0.6, 0.7, 0.1), center=(0, 0.04, 0.71)), bun, bevel=0.04)
    kit.add(kit.brick((0.4, 0.48, 0.06), center=(0, 0.04, 0.78)), bun, bevel=0.025)
    for x, y, z in ((0.0, 0.04, 0.815), (0.14, -0.12, 0.765), (-0.16, 0.2, 0.765), (0.2, 0.24, 0.765), (-0.2, -0.16, 0.765),
                    (0.28, 0.0, 0.7), (-0.29, 0.06, 0.7), (0.0, -0.3, 0.7), (0.05, 0.38, 0.7)):
        kit.add(kit.brick((0.05, 0.03, 0.02), center=(x, y, z), rot=(0, 0, 30)), seed, bevel=0.004)

    # --- corps de tortue sous le burger ---
    kit.add(kit.brick((0.56, 0.66, 0.16), center=(0, 0.04, 0.2)), light, bevel=0.04)

    # --- tête ronde, yeux, sourire, joues ---
    kit.add(kit.brick((0.18, 0.2, 0.16), center=(0, -0.42, 0.3)), green, "Head", bevel=0.03)
    kit.add(kit.brick((0.34, 0.3, 0.28), center=(0, -0.58, 0.4)), green, "Head", bevel=0.05)
    kit.add(kit.brick((0.26, 0.06, 0.1), center=(0, -0.73, 0.33)), light, "Head", bevel=0.02)
    P.eyes(kit, "Head", x=0.08, y=-0.73, z=0.46, size=0.1, iris="#2A1A0E", pupil="round", tall=1.15)
    P.mouth(kit, "Head", y=-0.765, z=0.34, w=0.12, smile=0.6, tongue=kit.mat("langue", "#FF5C8A"))
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.03), center=(s * 0.12, -0.735, 0.38)), pink, "Head", bevel=0.004)
    kit.part("Head", "Head", pivot=(0, -0.38, 0.3))

    # --- pattes trapues à griffes, petite queue ---
    for part, x, y, ph in (("LegFL", 0.24, -0.24, 0.0), ("LegFR", -0.24, -0.24, math.pi), ("LegBL", 0.24, 0.32, math.pi),
                           ("LegBR", -0.24, 0.32, 0.0)):
        kit.add(kit.brick((0.16, 0.18, 0.22), center=(x, y, 0.12)), green, part, bevel=0.04)
        for k in range(3):
            kit.add(kit.wedge((0.03, 0.03, 0.04), center=(x + (k - 1) * 0.045, y - 0.1, 0.02), rot=(90, 0, 0), tip=0.2),
                    claw, part, bevel=0.0)
        kit.part(part, "Leg", pivot=(x, y, 0.22), phase=ph)
    kit.add(kit.wedge((0.08, 0.06, 0.14), center=(0, 0.46, 0.2), rot=(-100, 0, 0), tip=0.15), green, "Tail", bevel=0.01)
    kit.part("Tail", "Tail", pivot=(0, 0.4, 0.2))
    return kit.result()
