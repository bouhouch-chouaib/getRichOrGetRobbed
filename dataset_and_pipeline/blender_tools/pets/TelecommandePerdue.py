"""Télécommande Perdue (Rare, Absurdes) : « Personne ne sait d'où elle vient. Elle flotte et clignote. »

En briques LEGO, très détaillée (Rare : émail noir laqué, aucune lueur) : télécommande noire laquée qui flotte debout,
bords gris mat, grands yeux perdus en haut (au-dessus des touches), petite bouche inquiète ; touches en relief : gros
bouton rouge d'allumage, croix directionnelle bleue, touches de volume +/-, pavé de chiffres blancs, deux touches de
couleur ; émetteur rouge brillant au sommet et deux petits bras-câbles. Parties animées : les bras, l'émetteur.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.enamel("laque", "#1E1E26")
    edge = kit.mat("bords", "#4A4A58")
    red = kit.enamel("bouton_rouge", "#FF1E2A")
    blue = kit.enamel("croix", "#2E7CFF")
    white = kit.mat("touches", "#F2F2F6")
    green = kit.enamel("vert", "#2EDB4A")
    yellow = kit.enamel("jaune", "#FFC21E")
    ir = kit.gem("emetteur", "#5A0A0A", "#FF2A2A", "#FFD0D0")
    grey = kit.mat("gris", "#8A8A98")

    # --- boîtier laqué debout ---
    kit.add(kit.brick((0.4, 0.2, 1.0), center=(0, 0, 0.62)), black, bevel=0.06)
    kit.add(kit.brick((0.42, 0.18, 0.94), center=(0, 0, 0.62)), edge, bevel=0.05)
    kit.add(kit.brick((0.36, 0.06, 0.92), center=(0, -0.09, 0.62)), black, bevel=0.03)

    # --- grands yeux perdus, bouche inquiète ---
    P.eyes(kit, "Body", x=0.08, y=-0.12, z=0.96, size=0.1, iris="#5AB4FF", pupil="round", tall=1.2, look=(0.3, 0.2),
           brow=edge, brow_angle=-15)
    kit.add(kit.box((0.06, 0.02, 0.02), center=(0, -0.122, 0.84), rot=(0, 10, 0)), white, bevel=0.0)

    # --- touches en relief ---
    kit.add(kit.brick((0.08, 0.04, 0.08), center=(0.1, -0.13, 1.08)), red, bevel=0.02)
    kit.add(kit.brick((0.16, 0.03, 0.05), center=(0, -0.13, 0.7)), blue, bevel=0.012)
    kit.add(kit.brick((0.05, 0.03, 0.16), center=(0, -0.13, 0.7)), blue, bevel=0.012)
    kit.add(kit.brick((0.04, 0.04, 0.04), center=(0, -0.14, 0.7)), white, bevel=0.008)
    for s in (-1, 1):
        kit.add(kit.brick((0.05, 0.03, 0.1), center=(s * 0.13, -0.13, 0.7)), edge, bevel=0.01)
    for row in range(3):
        for k in range(3):
            kit.add(kit.brick((0.06, 0.03, 0.045), center=((k - 1) * 0.09, -0.13, 0.52 - row * 0.07)), white, bevel=0.008)
    for k, mat in enumerate((red, green, yellow, blue)):
        kit.add(kit.brick((0.06, 0.03, 0.035), center=((k - 1.5) * 0.08, -0.13, 0.27)), mat, bevel=0.008)

    # --- émetteur au sommet ---
    kit.add(kit.brick((0.14, 0.14, 0.06), center=(0, 0, 1.14)), ir, "Ir", bevel=0.02)
    kit.part("Ir", "Toast", pivot=(0, 0, 1.12), phase=0.0)

    # --- petits bras-câbles ---
    for s, part in ((1, "ArmL"), (-1, "ArmR")):
        P.chain(kit, part, [(s * 0.21, 0, 0.7), (s * 0.3, -0.04, 0.6), (s * 0.32, -0.08, 0.48)], 0.035, [grey])
        kit.add(kit.brick((0.06, 0.06, 0.06), center=(s * 0.32, -0.09, 0.45)), edge, part, bevel=0.015)
        kit.part(part, "Arm", pivot=(s * 0.21, 0, 0.7), phase=0.0 if s > 0 else math.pi)
    return kit.result()
