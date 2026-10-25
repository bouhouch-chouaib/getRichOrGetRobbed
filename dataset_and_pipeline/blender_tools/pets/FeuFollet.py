"""Feu Follet (Commun, Fantastiques) : « Petite boule de feu bleue flottante. »

En briques LEGO, très détaillé : un petit cube de feu bleu électrique LUMINEUX, cœur blanc-bleu qui brille, couronne de
flammes bleues puis cyan puis blanches qui montent (trois mèches qui ondulent séparément), traîne de feu qui s'effile
en dessous, petites étincelles autour, grands yeux noirs brillants et petit sourire malicieux, joues cyan.
Il flotte (le jeu le fait léviter). Parties animées : trois mèches de flammes (« Leaf », elles ondulent).
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    blue = kit.mat("bleu", "#2E86FF", rough=0.2, glow=1.6)
    cyan = kit.mat("cyan", "#4EE6FF", rough=0.2, glow=2.4)
    core = kit.mat("coeur", "#E6F8FF", rough=0.15, glow=3.2)
    deep = kit.mat("bleu_nuit", "#1A4ED8", rough=0.2, glow=1.0)

    # --- corps : cube de feu, faces plus claires, traîne qui s'effile dessous ---
    kit.add(kit.brick((0.56, 0.52, 0.5), center=(0, 0, 0.62)), blue, bevel=0.05)
    kit.add(kit.brick((0.46, 0.05, 0.4), center=(0, -0.27, 0.62)), cyan, bevel=0.02)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.4, 0.36), center=(s * 0.28, 0.0, 0.64)), cyan, bevel=0.015)
    for k, (w, z) in enumerate(((0.42, 0.32), (0.3, 0.2), (0.18, 0.1), (0.08, 0.02))):
        kit.add(kit.brick((w, w, 0.12), center=(0.03 * k, 0.04 * k, z + 0.04), rot=(0, 0, 12 * k)), deep if k % 2 else blue,
                bevel=0.02)
    # visage
    P.eyes(kit, "Body", x=0.12, y=-0.295, z=0.7, size=0.13, iris="#0C0C18", pupil="round", sclera="#0C0C18", tall=1.1)
    P.mouth(kit, "Body", y=-0.3, z=0.53, w=0.16, color="#0C1440", smile=0.6)
    for s in (-1, 1):
        kit.add(kit.box((0.07, 0.02, 0.04), center=(s * 0.2, -0.3, 0.58)), core, bevel=0.005)
    # étincelles autour
    for x, y, z in ((0.38, -0.1, 0.9), (-0.36, 0.08, 0.84), (0.3, 0.2, 0.36), (-0.32, -0.16, 0.4)):
        kit.add(kit.brick((0.05, 0.05, 0.05), center=(x, y, z), rot=(45, 45, 0)), core, bevel=0.005)

    # --- trois mèches de flammes qui ondulent ---
    for part, x, y, size, phase in (("FlameC", 0.0, 0.0, 0.42, 0.0), ("FlameL", 0.17, 0.06, 0.3, 1.7),
                                    ("FlameR", -0.17, -0.04, 0.3, 3.4)):
        P.flames(kit, part, (x, y, 0.84), size, [blue, cyan, core], n=3, spread=0.8)
        kit.part(part, "Leaf", pivot=(x, y, 0.86), phase=phase)
    return kit.result()
