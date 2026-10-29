"""Chaudron Glouton (Sigma, Halloween 2026) : « Un chaudron de sorcière sur pattes qui avale tous les bonbons. »

En briques LEGO, sans lueur (rareté Sigma = or massif) : gros chaudron de fonte noire en octogone, bords et ceinture en
or massif avec des gemmes, potion vert pomme qui bouillonne (bulles), grands yeux sur le devant et large sourire
gourmand aux dents de sucre, langue rose ; quatre pattes d'or trapues ; une louche en bois plantée dans la potion ;
une ronde de bonbons emballés (rose, bleu, jaune, violet) qui tourne au-dessus.
Parties animées : 4 pattes, la louche, la ronde de bonbons.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    iron = kit.mat("fonte", "#141218", rough=0.35, metal=0.4)
    iron2 = kit.mat("fonte_claire", "#2C2834", rough=0.35, metal=0.4)
    gold = kit.gold("or", hammered=0.2)
    potion = kit.mat("potion", "#7EE64A", rough=0.15)
    bubble = kit.mat("bulle", "#C4FF96", rough=0.1)
    gem = kit.gem("emeraude", core="#D8FFE0", mid="#2ED46A", rim="#0A6A2E")
    tooth = kit.mat("sucre", "#FFFFFF", rough=0.1)
    tongue = kit.mat("langue", "#FF5C8A")
    wood = kit.mat("bois", "#8A5A2E", rough=0.6)
    candies = [kit.mat("bonbon_rose", "#FF4FA0"), kit.mat("bonbon_bleu", "#3AB8FF"),
               kit.mat("bonbon_jaune", "#FFD21E"), kit.mat("bonbon_violet", "#A85CFF")]

    # --- chaudron en octogone : étages droits et tournés de 45° (0,7 fois plus petits, un peu plus hauts) ---
    for w, h, z in ((0.56, 0.1, 0.24), (0.78, 0.16, 0.37), (0.88, 0.22, 0.56), (0.84, 0.16, 0.74)):
        kit.add(kit.brick((w, w, h), center=(0, 0, z)), iron, bevel=0.04)
        kit.add(kit.brick((w * 0.72, w * 0.72, h + 0.02), center=(0, 0, z), rot=(0, 0, 45)), iron2, bevel=0.04)
    # ceinture et bord en or massif, gemmes
    kit.add(kit.brick((0.92, 0.92, 0.07), center=(0, 0, 0.5)), gold, bevel=0.02)
    kit.add(kit.brick((0.94, 0.94, 0.08), center=(0, 0, 0.86)), gold, bevel=0.025)
    kit.add(kit.brick((0.7, 0.7, 0.1), center=(0, 0, 0.87), rot=(0, 0, 45)), gold, bevel=0.025)
    for s in (-1, 1):
        kit.add(kit.brick((0.05, 0.12, 0.05), center=(s * 0.5, 0, 0.86)), gold, bevel=0.01)  # anses
        kit.add(kit.brick((0.05, 0.05, 0.14), center=(s * 0.53, 0, 0.8)), gold, bevel=0.01)
    kit.add(kit.brick((0.1, 0.05, 0.1), center=(0, -0.49, 0.86), rot=(0, 45, 0)), gem, bevel=0.012)  # gemme du bord
    # potion qui bouillonne
    kit.add(kit.brick((0.76, 0.76, 0.05), center=(0, 0, 0.9)), potion, bevel=0.02)
    for x, y, s in ((-0.18, 0.1, 0.1), (0.15, -0.12, 0.08), (0.2, 0.18, 0.06), (-0.05, -0.2, 0.07)):
        kit.add(kit.brick((s, s, s), center=(x, y, 0.94)), bubble, bevel=0.02)

    # --- visage gourmand sur le devant ---
    P.eyes(kit, "Body", x=0.15, y=-0.45, z=0.66, size=0.16, iris="#7EE64A", pupil="round", tall=1.1)
    kit.add(kit.box((0.42, 0.03, 0.1), center=(0, -0.455, 0.37)), kit.mat("bouche", "#3A0A1A"), bevel=0.01)
    kit.add(kit.box((0.18, 0.03, 0.05), center=(0, -0.465, 0.345)), tongue, bevel=0.008)
    for k in range(6):
        kit.add(kit.wedge((0.05, 0.03, 0.05), center=(-0.15 + k * 0.06, -0.47, 0.4), rot=(180, 0, 0), tip=0.1), tooth,
                bevel=0.0)

    # --- pattes d'or trapues ---
    P.quad_legs(kit, gold, yf=-0.22, yb=0.22, top_f=0.26, top_b=0.26, length_f=0.26, length_b=0.26, w=0.12,
                paw=iron2, toe=gold, x=0.24, toes=3)

    # --- louche plantée dans la potion ---
    kit.add(kit.box((0.04, 0.04, 0.5), center=(0.22, 0.16, 1.1), rot=(18, -22, 0)), wood, "Ladle", bevel=0.008)
    kit.add(kit.brick((0.12, 0.12, 0.05), center=(0.13, 0.08, 0.92)), wood, "Ladle", bevel=0.02)
    kit.part("Ladle", "Leaf", pivot=(0.16, 0.1, 0.9), phase=0.8)

    # --- ronde de bonbons emballés qui tourne au-dessus ---
    for k in range(6):
        a = math.radians(k * 60)
        cx, cy, cz = math.cos(a) * 0.42, math.sin(a) * 0.42, 1.18 + 0.05 * math.sin(a * 2)
        mat = candies[k % len(candies)]
        kit.add(kit.brick((0.1, 0.07, 0.07), center=(cx, cy, cz), rot=(0, 0, k * 60 + 90)), mat, "Candy", bevel=0.02)
        for s in (-1, 1):
            ex, ey = math.cos(a + math.pi / 2) * 0.08 * s, math.sin(a + math.pi / 2) * 0.08 * s
            kit.add(kit.wedge((0.06, 0.05, 0.06), center=(cx + ex, cy + ey, cz), rot=(0, 90 * s, k * 60 + 90), tip=0.1),
                    mat, "Candy", bevel=0.0)
    kit.part("Candy", "Orbit", pivot=(0, 0, 1.18), phase=0.9)
    return kit.result()
