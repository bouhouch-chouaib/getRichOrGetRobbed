"""Chat de ruelle (Commun, Animaux) : « Chat tigré gris ébouriffé, pansement sur la joue. »

Construit en briques LEGO (sans tenons), cubes d'abord. Tigré gris : rayures en tuiles foncées sur le dos, les flancs,
le front et la queue ; poitrail et museau crème ; grosse tête carrée (~40 % du corps) ; yeux carrés jaune-vert à
pupille fendue ; oreilles en coins avec l'intérieur rose ; touffes ébouriffées en pentes sur les joues et le crâne ;
pansement crème en biais sur la joue gauche ; pattes en briques à chaussettes crème ; queue rayée en briques qui
remonte. Parties animées : tête, 4 pattes (trot en diagonale), queue.
"""

from mathutils import Vector

import procedural_geometry_recipes as G
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    grey = kit.mat("gris", "#8C8D94")
    stripe = kit.mat("rayure", "#53545C")
    cream = kit.mat("creme", "#EBD8BC")
    pink = kit.mat("rose", "#F0A2B0")
    eye = kit.mat("oeil", "#CBDC45", rough=0.15)
    black = kit.mat("pupille", "#121214", rough=0.12)
    white = kit.mat("reflet", "#FFFFFF", rough=0.1)
    plaster = kit.mat("pansement", "#EED6AC")
    dots = kit.mat("trous", "#B6996C")

    # --- corps : briques empilées, pente vers la queue, poitrail crème ---
    kit.add(kit.brick((0.46, 0.9, 0.2), center=(0, 0.04, 0.44)), grey, bevel=0.025)
    kit.add(kit.brick((0.52, 0.96, 0.24), center=(0, 0.04, 0.66)), grey, bevel=0.03)
    kit.add(kit.brick((0.48, 0.6, 0.1), center=(0, -0.1, 0.83)), grey, bevel=0.02)
    kit.add(kit.slope((0.48, 0.34, 0.1), center=(0, 0.37, 0.83), facing="+Y", top=0.25), grey, bevel=0.02)
    kit.add(kit.brick((0.34, 0.07, 0.34), center=(0, -0.45, 0.6)), cream, bevel=0.02)
    for y in (-0.28, -0.04, 0.2):  # rayures : tuile sur le dos qui descend sur les deux flancs
        kit.add(kit.tile(0.5, 0.08, center=(0, y, 0.894)), stripe, bevel=0.008)
        for s in (-1, 1):
            kit.add(kit.box((0.03, 0.08, 0.26), center=(s * 0.27, y, 0.7)), stripe, bevel=0.008)

    # --- tête : grosse brique, couronne en plaque, joues ébouriffées, museau, yeux carrés, oreilles ---
    kit.add(kit.brick((0.62, 0.46, 0.4), center=(0, -0.5, 1.07)), grey, "Head", bevel=0.035)
    kit.add(kit.brick((0.54, 0.4, 0.08), center=(0, -0.48, 1.31)), grey, "Head", bevel=0.02)
    for s in (-1, 1):
        f = "+X" if s > 0 else "-X"
        kit.add(kit.slope((0.14, 0.26, 0.17), center=(s * 0.37, -0.56, 0.94), facing=f, top=0.2), grey, "Head",
                bevel=0.015)
        kit.add(kit.slope((0.11, 0.2, 0.11), center=(s * 0.37, -0.52, 1.05), facing=f, top=0.2), grey, "Head",
                bevel=0.012)
        x = s * 0.15
        kit.add(kit.box((0.15, 0.03, 0.15), center=(x, -0.737, 1.12)), eye, "Head", bevel=0.012)
        kit.add(kit.box((0.045, 0.02, 0.12), center=(x, -0.756, 1.12)), black, "Head", bevel=0.006)
        kit.add(kit.box((0.035, 0.012, 0.035), center=(x - s * 0.035, -0.765, 1.163)), white, "Head", bevel=0.0)
        kit.add(kit.wedge((0.22, 0.09, 0.25), center=(s * 0.2, -0.44, 1.475), rot=(0, s * 10, 0), tip=0.1), grey,
                "Head", bevel=0.015)
        kit.add(kit.wedge((0.12, 0.03, 0.16), center=(s * 0.2, -0.49, 1.45), rot=(0, s * 10, 0), tip=0.12), pink,
                "Head", bevel=0.008)
    kit.add(kit.brick((0.3, 0.1, 0.14), center=(0, -0.77, 0.94)), cream, "Head", bevel=0.02)
    kit.add(kit.brick((0.22, 0.08, 0.06), center=(0, -0.75, 0.85)), cream, "Head", bevel=0.012)
    kit.add(kit.slope((0.1, 0.05, 0.06), center=(0, -0.835, 1.03), facing="-Y", top=0.4), pink, "Head", bevel=0.008)
    for dx in (-0.1, 0.0, 0.1):  # rayures du front
        kit.add(kit.tile(0.05, 0.24, center=(dx, -0.5, 1.365)), stripe, "Head", bevel=0.006)
    kit.add(kit.wedge((0.1, 0.08, 0.15), center=(0.05, -0.42, 1.42), rot=(0, -16, 0), tip=0.15), grey, "Head",
            bevel=0.01)  # épi sur le crâne
    # pansement en biais sur la joue gauche (+X) avec ses petits trous
    kit.add(kit.box((0.17, 0.025, 0.065), center=(0.2, -0.738, 0.96), rot=(0, 28, 0)), plaster, "Head", bevel=0.008)
    for d in (-0.035, 0.035):
        kit.add(kit.box((0.016, 0.01, 0.016), center=(0.2 + d * 0.88, -0.752, 0.96 + d * 0.47)), dots, "Head",
                bevel=0.0)

    # --- pattes : briques, chaussettes crème ; cuisses arrière ---
    for s, fx in ((1, "L"), (-1, "R")):
        x = s * 0.16
        front, back = f"LegF{fx}", f"LegB{fx}"
        kit.add(kit.brick((0.16, 0.16, 0.3), center=(x, -0.3, 0.21)), grey, front, bevel=0.02)
        kit.add(kit.brick((0.19, 0.22, 0.07), center=(x, -0.33, 0.035)), cream, front, bevel=0.015)
        kit.part(front, "Leg", pivot=(x, -0.3, 0.4), phase=0.0 if s > 0 else 3.14159)
        kit.add(kit.brick((0.2, 0.32, 0.22), center=(s * 0.2, 0.3, 0.44)), grey, back, bevel=0.025)
        kit.add(kit.brick((0.16, 0.16, 0.26), center=(x, 0.34, 0.19)), grey, back, bevel=0.02)
        kit.add(kit.brick((0.19, 0.22, 0.07), center=(x, 0.31, 0.035)), cream, back, bevel=0.015)
        kit.part(back, "Leg", pivot=(s * 0.2, 0.3, 0.54), phase=3.14159 if s > 0 else 0.0)

    # --- queue rayée en briques qui remonte ---
    pts = [Vector(p) for p in ((0, 0.52, 0.74), (0, 0.72, 0.8), (0, 0.86, 0.96), (0, 0.91, 1.16), (0, 0.87, 1.35),
                               (0, 0.78, 1.46))]
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        width = 0.13 - 0.008 * k
        seg = kit.brick((width, width, (b - a).length * 1.1), label="Queue")
        G.transform(seg, G.frame_matrix((a + b) / 2, b - a))
        kit.add(seg, stripe if k % 2 else grey, "Tail", bevel=0.018)
    kit.part("Tail", "Tail", pivot=(0, 0.5, 0.74))
    kit.part("Head", "Head", pivot=(0, -0.36, 0.9))
    return kit.result()
