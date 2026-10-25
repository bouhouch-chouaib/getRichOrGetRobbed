"""Lion Enceinte (Divin, Hybrides) : « Lion noir à la crinière en caissons de basses. »

En briques LEGO, très détaillé : lion noir mat à reflets gris anthracite, museau gris clair, yeux cyan LUMINEUX,
nez noir brillant ; sa crinière est faite de CAISSONS DE BASSES (boîtes noires, anneaux cyan LUMINEUX, membranes qui
POMPENT au rythme) tout autour de la tête ; deux enceintes sur le poitrail, des jack dorés, pattes puissantes, queue en
câble terminée par une prise jack. Parties animées : les membranes (battent la mesure), 4 pattes, queue.
"""

import _parts as P
import procedural_geometry_recipes as G
from pet_kit import PetKit, rot_matrix


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.mat("noir", "#1E1E26", rough=0.35)
    grey = kit.mat("anthracite", "#3A3A48", rough=0.3)
    light = kit.mat("museau", "#8A8A9A")
    box = kit.mat("caisson", "#141418", rough=0.4)
    ring = kit.mat("anneau", "#2AE6FF", rough=0.1, glow=2.6)
    cone = kit.mat("membrane", "#2A2A34", rough=0.5)
    cap = kit.mat("cache", "#5A5A6A", metal=0.6, rough=0.3)
    gold = kit.mat("jack", "#FFC21E", metal=0.85, rough=0.2)

    # --- corps de lion, enceintes du poitrail ---
    P.quad_torso(kit, L=0.96, W=0.5, H=0.36, z=0.62, y0=0.06, main=black, belly=grey, chest=grey, back=grey)
    for s in (-1, 1):
        P.speaker(kit, "Body", (s * 0.11, -0.44, 0.62), 0.16, (box, ring, cone, cap))
        kit.add(kit.brick((0.1, 0.04, 0.1), center=(s * 0.11, -0.545, 0.62)), cone, f"Woof{2 if s > 0 else 3}",
                bevel=0.008)
        kit.part(f"Woof{2 if s > 0 else 3}", "Thump", pivot=(s * 0.11, -0.53, 0.62), phase=0.4)

    # --- tête : museau, yeux cyan, nez ---
    kit.add(kit.brick((0.44, 0.38, 0.36), center=(0, -0.62, 0.98)), black, bevel=0.05)
    kit.add(kit.brick((0.28, 0.2, 0.18), center=(0, -0.86, 0.9)), light, bevel=0.04)
    kit.add(kit.slope((0.26, 0.18, 0.08), center=(0, -0.84, 1.02), facing="-Y", top=0.3), black, bevel=0.012)
    P.nose(kit, "Body", y=-0.96, z=0.96, w=0.1, color="#0A0A0E")
    P.mouth(kit, "Body", y=-0.962, z=0.85, w=0.14, smile=0.3)
    P.eyes(kit, "Body", x=0.11, y=-0.81, z=1.06, size=0.1, iris="#2AE6FF", pupil="slit", lid=black, lid_drop=0.12,
           brow=grey, brow_angle=14, glow=2.4, tall=0.85)
    for s in (-1, 1):
        P.ear(kit, "Body", s, (s * 0.15, -0.56, 1.15), w=0.12, h=0.12, color=black, inner=grey, tilt=(-8, 12))

    # --- crinière en caissons de basses ---
    spots = [((0.0, -0.46, 1.28), (20, 0, 0), 0.22), ((0.27, -0.5, 1.18), (10, 0, -40), 0.2),
             ((-0.27, -0.5, 1.18), (10, 0, 40), 0.2), ((0.33, -0.52, 0.94), (0, 0, -70), 0.2),
             ((-0.33, -0.52, 0.94), (0, 0, 70), 0.2), ((0.26, -0.5, 0.72), (-15, 0, -50), 0.17),
             ((-0.26, -0.5, 0.72), (-15, 0, 50), 0.17), ((0.0, -0.36, 1.22), (40, 0, 180), 0.2)]
    for center, rot, size in spots:
        P.speaker(kit, "Body", center, size, (box, ring, cone, cap), rot=rot)
    # membranes qui pompent sur les deux plus gros caissons (devant)
    for k, (center, rot) in enumerate((((0.27, -0.5, 1.18), (10, 0, -40)), ((-0.27, -0.5, 1.18), (10, 0, 40)))):
        part = f"Woof{k}"
        m = rot_matrix(center, rot)
        piece = kit.brick((0.12, 0.04, 0.12), center=(0, -0.08, 0))
        G.transform(piece, m)
        kit.add(piece, cone, part, bevel=0.008)
        kit.part(part, "Thump", pivot=center, rot=rot, phase=k * 0.5)

    # --- pattes, jacks dorés, queue-câble à prise jack ---
    P.quad_legs(kit, black, yf=-0.3, yb=0.4, top_f=0.64, top_b=0.68, length_f=0.62, length_b=0.66, w=0.15, paw=grey,
                toe=grey, x=0.18, toes=3)
    for s in (-1, 1):
        kit.add(kit.disc(0.04, 0.03, center=(s * 0.255, 0.1, 0.72), normal=(s, 0, 0), sides=8), gold, bevel=0.0)
    P.chain(kit, "Tail", [(0, 0.54, 0.7), (0, 0.72, 0.62), (0, 0.88, 0.66), (0, 0.98, 0.8)], 0.05, [box])
    kit.add(kit.brick((0.08, 0.08, 0.1), center=(0, 1.0, 0.88)), box, "Tail", bevel=0.015)
    kit.add(kit.brick((0.03, 0.03, 0.12), center=(0, 1.0, 0.98)), gold, "Tail", bevel=0.004)
    kit.part("Tail", "Tail", pivot=(0, 0.52, 0.7))
    return kit.result()
