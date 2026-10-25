"""Tournesol Joyeux (Inhabituel, Plantes) : « Tournesol jaune au grand sourire. »

En briques LEGO, très détaillé : pot en terre cuite à pois blancs, tige vert vif avec deux grandes feuilles à nervures,
grande fleur : deux couronnes de pétales (jaune soleil devant, orange derrière), sépales verts au dos, cœur brun
semé de graines plus claires, et dessus un énorme sourire bouche ouverte (langue rose), grands yeux brillants, joues
roses. Parties animées : la fleur (« Head », fière, elle regarde vers le soleil), les deux feuilles.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    terra = kit.mat("terre_cuite", "#F07438")
    rim = kit.mat("rebord", "#FF8E52")
    dots = kit.mat("pois", "#FFFFFF")
    soil = kit.mat("terreau", "#4A2C14")
    stem = kit.mat("tige", "#3EC82E")
    leaf = kit.mat("feuille", "#2EB81E")
    vein = kit.mat("nervure", "#B4F27A")
    yellow = kit.mat("petale", "#FFD21E")
    gold = kit.mat("petale_dore", "#FFB41E")
    orange = kit.mat("petale_orange", "#FF8A1E")
    brown = kit.mat("coeur", "#7A4418")
    dark = kit.mat("coeur_fonce", "#552C0E")
    seed = kit.mat("graines", "#A8682C")
    pink = kit.mat("joues", "#FF7AA8")

    # --- pot à pois, tige, deux feuilles ---
    top = P.pot(kit, "Body", 0.0, 0.46, 0.34, terra, rim=rim, soil=soil)
    for x, z in ((-0.12, 0.14), (0.1, 0.22), (0.0, 0.1), (0.15, 0.1), (-0.06, 0.26)):
        kit.add(kit.box((0.04, 0.02, 0.04), center=(x, -0.215, z)), dots, bevel=0.0)
    P.chain(kit, "Body", [(0, 0, top), (0.02, 0.0, top + 0.24), (0, -0.03, top + 0.5), (0, -0.05, top + 0.62)], 0.09,
            [stem])
    for s, part, z in ((1, "LeafL", top + 0.18), (-1, "LeafR", top + 0.32)):
        P.leaf(kit, part, (s * 0.03, 0, z), (s * 1.0, -0.1, 0.5), 0.34, 0.2, leaf, vein, normal=(0, -0.3, 1), droop=0.35)
        kit.part(part, "Leaf", pivot=(s * 0.03, 0, z), phase=1.0 if s > 0 else 2.6)

    # --- la fleur : sépales, pétales orange derrière, pétales jaunes devant, cœur brun, visage ---
    cz = top + 0.82
    kit.add(kit.brick((0.44, 0.08, 0.44), center=(0, 0.03, cz)), stem, "Head", bevel=0.03)
    P.petals(kit, "Head", (0, -0.02, cz), 12, 0.3, 0.13, [orange, gold], facing=(0, -1, 0), tilt=0.05, start=0.26)
    P.petals(kit, "Head", (0, -0.07, cz), 12, 0.32, 0.14, [yellow, gold], facing=(0, -1, 0), tilt=0.12)
    kit.add(kit.brick((0.42, 0.1, 0.42), center=(0, -0.11, cz)), brown, "Head", bevel=0.04)
    kit.add(kit.brick((0.34, 0.03, 0.34), center=(0, -0.17, cz)), dark, "Head", bevel=0.01)
    for x, z in ((-0.13, 0.13), (0.13, 0.13), (-0.15, -0.02), (0.15, -0.02), (0.0, 0.15), (-0.08, -0.15),
                 (0.08, -0.15), (0.0, -0.17)):
        kit.add(kit.box((0.03, 0.012, 0.03), center=(x, -0.188, cz + z), rot=(0, 45, 0)), seed, "Head", bevel=0.0)
    P.eyes(kit, "Head", x=0.075, y=-0.185, z=cz + 0.05, size=0.09, iris="#2A1A0E", pupil="round", tall=1.15)
    kit.add(kit.brick((0.16, 0.03, 0.07), center=(0, -0.19, cz - 0.07)), kit.mat("bouche", "#3A0E06"), "Head",
            bevel=0.012)
    kit.add(kit.brick((0.08, 0.03, 0.03), center=(0, -0.2, cz - 0.09)), kit.mat("langue", "#FF5C8A"), "Head",
            bevel=0.006)
    for s in (-1, 1):
        kit.add(kit.box((0.022, 0.02, 0.04), center=(s * 0.085, -0.192, cz - 0.05), rot=(0, s * 40, 0)),
                kit.mat("bouche", "#3A0E06"), "Head", bevel=0.0)
        kit.add(kit.box((0.05, 0.02, 0.035), center=(s * 0.13, -0.192, cz - 0.02)), pink, "Head", bevel=0.004)
    kit.part("Head", "Head", pivot=(0, -0.05, top + 0.6))
    return kit.result()
