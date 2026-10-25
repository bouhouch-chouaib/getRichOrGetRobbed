"""Concierge Cosmique (Inhabituel, Absurdes) : « Balaie la poussière d'étoiles, mais il en tombe toujours plus. »

En briques LEGO, très détaillé (Inhabituel : plastique et émail, aucune lueur) : petit concierge en salopette bleu
marine à bretelles jaunes et poche (badge étoile), chemise blanche, casquette jaune à étoile, grosse moustache brune,
nez rond, yeux fatigués ; il tient un grand balai (manche bois, brosse paille) et une pelle ; autour de ses pieds, des
petites étoiles jaunes et bleues qu'il n'arrive jamais à ramasser. Parties animées : tête, bras du balai (balaie), bras
de la pelle, jambes.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    navy = kit.mat("salopette", "#2A3A8A")
    yellow = kit.enamel("jaune", "#FFC21E")
    white = kit.mat("chemise", "#F6F6F2")
    skin = kit.mat("peau", "#F2C8A0")
    brown = kit.mat("moustache", "#6A3A1E")
    wood = kit.mat("manche", "#B47A3A")
    straw = kit.mat("paille", "#E8C25A")
    metal = kit.mat("pelle", "#8A92A2", metal=0.6, rough=0.3)
    star_b = kit.enamel("etoile_bleue", "#5AB4FF")

    # --- corps : chemise, salopette, bretelles, poche à étoile ---
    kit.add(kit.brick((0.44, 0.32, 0.22), center=(0, 0, 0.66)), white, bevel=0.04)
    kit.add(kit.brick((0.46, 0.34, 0.3), center=(0, 0, 0.42)), navy, bevel=0.04)
    kit.add(kit.brick((0.3, 0.06, 0.16), center=(0, -0.17, 0.64)), navy, bevel=0.015)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.22), center=(s * 0.12, -0.165, 0.68)), yellow, bevel=0.0)
        kit.add(kit.brick((0.05, 0.03, 0.05), center=(s * 0.12, -0.19, 0.6)), yellow, bevel=0.008)
    kit.add(kit.brick((0.08, 0.02, 0.08), center=(0, -0.203, 0.66), rot=(0, 45, 0)), yellow, bevel=0.008)

    # --- tête : nez, moustache, yeux fatigués, casquette à étoile ---
    kit.add(kit.brick((0.4, 0.36, 0.34), center=(0, -0.02, 0.96)), skin, "Head", bevel=0.05)
    kit.add(kit.brick((0.1, 0.08, 0.08), center=(0, -0.24, 0.94)), kit.mat("nez", "#FF9A82"), "Head", bevel=0.03)
    for s in (-1, 1):
        kit.add(kit.brick((0.14, 0.06, 0.07), center=(s * 0.08, -0.22, 0.87), rot=(0, s * 15, 0)), brown, "Head",
                bevel=0.02)
    P.eyes(kit, "Head", x=0.09, y=-0.2, z=1.02, size=0.09, iris="#3A2A1A", pupil="round", lid=skin, lid_drop=0.25,
           brow=brown, brow_angle=-10, tall=1.0)
    kit.add(kit.brick((0.44, 0.4, 0.1), center=(0, -0.02, 1.16)), yellow, "Head", bevel=0.03)
    kit.add(kit.brick((0.36, 0.16, 0.03), center=(0, -0.26, 1.12)), yellow, "Head", bevel=0.01)
    kit.add(kit.brick((0.07, 0.02, 0.07), center=(0, -0.225, 1.17), rot=(0, 45, 0)), navy, "Head", bevel=0.006)
    kit.part("Head", "Head", pivot=(0, 0, 0.78))

    # --- bras droit : le grand balai (il balaie) ---
    kit.add(kit.brick((0.1, 0.12, 0.24), center=(-0.28, -0.04, 0.6)), white, "ArmR", bevel=0.025)
    kit.add(kit.brick((0.1, 0.12, 0.08), center=(-0.28, -0.12, 0.48)), skin, "ArmR", bevel=0.02)
    kit.add(kit.box((0.04, 0.04, 0.8), center=(-0.3, -0.16, 0.36), rot=(18, 0, 0)), wood, "ArmR", bevel=0.008)
    kit.add(kit.brick((0.22, 0.08, 0.06), center=(-0.3, -0.06, 0.02)), wood, "ArmR", bevel=0.01)
    for k in range(5):
        kit.add(kit.wedge((0.04, 0.06, 0.08), center=(-0.38 + k * 0.04, -0.06, -0.02), rot=(180, 0, 0), tip=0.3), straw,
                "ArmR", bevel=0.0)
    kit.part("ArmR", "Arm", pivot=(-0.26, 0, 0.72), phase=0.0)
    # --- bras gauche : la pelle ---
    kit.add(kit.brick((0.1, 0.12, 0.24), center=(0.28, -0.04, 0.6)), white, "ArmL", bevel=0.025)
    kit.add(kit.brick((0.1, 0.12, 0.08), center=(0.28, -0.12, 0.48)), skin, "ArmL", bevel=0.02)
    kit.add(kit.box((0.03, 0.03, 0.24), center=(0.28, -0.18, 0.38)), wood, "ArmL", bevel=0.006)
    kit.add(kit.brick((0.18, 0.16, 0.02), center=(0.28, -0.26, 0.26), rot=(-20, 0, 0)), metal, "ArmL", bevel=0.006)
    kit.part("ArmL", "Arm", pivot=(0.26, 0, 0.72), phase=math.pi)

    # --- jambes, chaussures ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        kit.add(kit.brick((0.16, 0.18, 0.2), center=(s * 0.11, 0, 0.18)), navy, part, bevel=0.03)
        kit.add(kit.brick((0.17, 0.24, 0.08), center=(s * 0.11, -0.04, 0.04)), brown, part, bevel=0.025)
        kit.part(part, "Leg", pivot=(s * 0.11, 0, 0.3), phase=0.0 if s > 0 else math.pi)

    # --- poussière d'étoiles autour des pieds ---
    for x, y, mat in ((0.3, -0.3, yellow), (-0.12, -0.42, star_b), (0.42, 0.1, star_b), (-0.4, -0.3, yellow),
                      (0.14, -0.46, yellow)):
        kit.add(kit.brick((0.06, 0.06, 0.03), center=(x, y, 0.015), rot=(0, 0, 45)), mat, bevel=0.006)
        kit.add(kit.brick((0.06, 0.06, 0.03), center=(x, y, 0.015)), mat, bevel=0.006)
    return kit.result()
