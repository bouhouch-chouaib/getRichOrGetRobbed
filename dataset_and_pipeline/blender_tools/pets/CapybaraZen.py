"""Le Capybara Zen (Sigma, Animaux) : « Capybara imperturbable, une orange sur la tête. »

En briques LEGO, très détaillé (le capybara est déjà un gros pavé !) : corps-tonneau brun caramel en grosses briques
avec mèches de poil sur le dos, ventre plus clair, tête carrée au long museau plat, énorme truffe sombre à narines,
deux grandes incisives, moustaches, petites oreilles rondes, yeux mi-clos sereins (paupières tombantes, il est zen),
une orange posée sur la tête avec sa feuille et sa tige, pattes courtes à doigts palmés.
Parties animées : tête (lente, il est zen), 4 pattes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    brown = kit.mat("caramel", "#C87A3A")
    light = kit.mat("clair", "#E8AA6C")
    dark = kit.mat("fonce", "#7A4520")
    orange = kit.mat("orange", "#FF8A10", rough=0.35)
    peel = kit.mat("orange_fonce", "#E86A00", rough=0.4)
    leaf = kit.mat("feuille", "#36D23A")
    nose = kit.mat("truffe", "#3A2418")
    teeth = kit.mat("dents", "#FFF8E8", rough=0.2)

    # --- corps-tonneau, mèches sur le dos ---
    P.quad_torso(kit, L=1.12, W=0.72, H=0.46, z=0.62, y0=0.06, main=brown, belly=light, chest=brown, back=brown,
                 hump=0.4)
    for x, y in ((-0.2, -0.2), (0.15, -0.1), (-0.05, 0.12), (0.22, 0.26), (-0.2, 0.34)):
        P.tuft_piece(kit, "Body", (x, y, 0.92), (x * 0.6, 0.6, 0.6), 0.1, 0.09, dark)

    # --- tête carrée, museau plat, truffe, incisives, moustaches, yeux zen, oreilles, orange ---
    kit.add(kit.brick((0.56, 0.52, 0.44), center=(0, -0.66, 0.94)), brown, "Head", bevel=0.045)
    kit.add(kit.brick((0.48, 0.44, 0.06), center=(0, -0.64, 1.19)), brown, "Head", bevel=0.015)
    kit.add(kit.brick((0.48, 0.2, 0.32), center=(0, -0.99, 0.88)), brown, "Head", bevel=0.04)
    kit.add(kit.brick((0.4, 0.06, 0.1), center=(0, -1.1, 0.79)), light, "Head", bevel=0.012)
    P.nose(kit, "Head", y=-1.1, z=0.96, w=0.3, color="#3A2418", nostril="#120A06")
    for dx in (-0.03, 0.03):
        kit.add(kit.brick((0.05, 0.03, 0.07), center=(dx, -1.12, 0.73)), teeth, "Head", bevel=0.006)
    P.whiskers(kit, "Head", x=0.2, y=-1.06, z=0.86, color="#2A1A10", n=2, length=0.14)
    P.eyes(kit, "Head", x=0.19, y=-0.92, z=1.06, size=0.1, iris="#3A2414", pupil="round", lid=brown, lid_drop=0.42,
           tall=0.8)
    for s in (-1, 1):
        kit.add(kit.brick((0.13, 0.08, 0.11), center=(s * 0.23, -0.52, 1.22)), dark, "Head", bevel=0.03)
        kit.add(kit.brick((0.08, 0.02, 0.07), center=(s * 0.23, -0.565, 1.21)), light, "Head", bevel=0.006)
    kit.add(kit.brick((0.28, 0.28, 0.24), center=(0, -0.64, 1.34)), orange, "Head", bevel=0.09)
    for k in range(4):
        kit.add(kit.box((0.012, 0.29, 0.12), center=((k - 1.5) * 0.06, -0.64, 1.34)), peel, "Head", bevel=0.0)
    kit.add(kit.brick((0.04, 0.04, 0.07), center=(0, -0.64, 1.49)), dark, "Head", bevel=0.006)
    kit.add(kit.wedge((0.14, 0.03, 0.09), center=(0.07, -0.64, 1.52), rot=(0, 45, 0), tip=0.2), leaf, "Head",
            bevel=0.005)

    # --- pattes courtes à doigts ---
    P.quad_legs(kit, brown, yf=-0.36, yb=0.46, top_f=0.48, top_b=0.5, length_f=0.42, length_b=0.46, w=0.17, paw=dark,
                toe=dark, x=0.24, toes=4)
    kit.part("Head", "Head", pivot=(0, -0.46, 0.82))
    return kit.result()
