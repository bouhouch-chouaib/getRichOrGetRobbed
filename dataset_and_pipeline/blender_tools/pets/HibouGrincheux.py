"""Hibou Grincheux (Rare, Animaux) : « Hibou brun aux sourcils froncés. »

En briques LEGO, très détaillé : grosse tête de hibou presque aussi large que le corps, disque facial beige encadré
de plumes brun foncé, énormes yeux orange vif sous des paupières tombantes et de gros sourcils froncés vers le
centre (grincheux), bec jaune crochu, aigrettes en touffes, ventre beige à chevrons, ailes en trois rangs de plumes
tachetées, queue en éventail, pattes jaunes à griffes noires. Parties animées : tête (un hibou tourne la tête),
ailes, queue, pattes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    brown = kit.mat("brun", "#9A5F28")
    mid = kit.mat("brun_moyen", "#7A4518")
    dark = kit.mat("brun_fonce", "#4A2A0E")
    beige = kit.mat("beige", "#FFD9A0")
    yellow = kit.mat("bec", "#FFC21A")
    feet = kit.mat("pattes", "#FFB01F")
    claw = kit.mat("griffes", "#2A1E18")

    # --- corps : deux étages arrondis par des pentes, ventre beige à chevrons ---
    kit.add(kit.brick((0.58, 0.5, 0.28), center=(0, 0.04, 0.3)), brown, bevel=0.035)
    kit.add(kit.brick((0.66, 0.56, 0.3), center=(0, 0.04, 0.56)), brown, bevel=0.04)
    for s in (-1, 1):
        kit.add(kit.slope((0.08, 0.5, 0.22), center=(s * 0.33, 0.04, 0.24), facing=P.side(s), top=0.3, rot=(0, 180, 0)),
                brown, bevel=0.012)
    kit.add(kit.brick((0.44, 0.05, 0.5), center=(0, -0.245, 0.42)), beige, bevel=0.02)
    for row, z in enumerate((0.26, 0.36, 0.46, 0.56)):
        for k in range(3 - row % 2):
            dx = (k - (2 - row % 2) / 2) * 0.12
            kit.add(kit.wedge((0.08, 0.02, 0.05), center=(dx, -0.275, z), rot=(180, 0, 0), tip=0.15), mid, bevel=0.0)

    # --- tête : grand bloc, disque facial encadré, yeux grincheux, bec crochu, aigrettes ---
    kit.add(kit.brick((0.72, 0.58, 0.5), center=(0, 0.0, 0.96)), brown, "Head", bevel=0.045)
    kit.add(kit.brick((0.64, 0.5, 0.06), center=(0, 0.0, 1.24)), mid, "Head", bevel=0.015)
    kit.add(kit.brick((0.62, 0.05, 0.44), center=(0, -0.29, 0.95)), beige, "Head", bevel=0.02)
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.06, 0.46), center=(s * 0.33, -0.29, 0.95)), dark, "Head", bevel=0.01)
    kit.add(kit.box((0.66, 0.06, 0.05), center=(0, -0.29, 0.72)), dark, "Head", bevel=0.01)
    P.eyes(kit, "Head", x=0.15, y=-0.315, z=0.99, size=0.19, iris="#FF8A0A", pupil="round", lid=mid, lid_drop=0.04,
           brow=dark, brow_angle=24)
    kit.add(kit.slope((0.1, 0.08, 0.12), center=(0, -0.34, 0.86), facing="-Y", top=0.25), yellow, "Head", bevel=0.01)
    kit.add(kit.wedge((0.07, 0.06, 0.07), center=(0, -0.36, 0.78), rot=(180, 0, 0), tip=0.2), yellow, "Head", bevel=0.0)
    for s in (-1, 1):
        P.tuft_piece(kit, "Head", (s * 0.27, -0.06, 1.26), (s * 0.35, 0.0, 1.0), 0.2, 0.12, brown)
        P.tuft_piece(kit, "Head", (s * 0.2, -0.02, 1.26), (s * 0.15, 0.1, 1.0), 0.14, 0.1, dark)
    for dx in (-0.16, 0.0, 0.16):  # plumes du crâne
        kit.add(kit.slope((0.12, 0.14, 0.05), center=(dx, 0.12, 1.29), facing="+Y", top=0.2), mid, "Head", bevel=0.006)

    # --- ailes tachetées, queue en éventail, pattes ---
    P.bird_wings(kit, x=0.36, y=0.04, z=0.48, length=0.52, height=0.46, cov=brown, sec=mid, prim=dark, bar=beige,
                 thick=0.1)
    P.tail_fan(kit, "Tail", (0, 0.26, 0.24), n=3, length=0.22, width=0.12, mats=[dark, mid], spread=16, pitch=-40)
    P.bird_feet(kit, x=0.14, y=-0.1, h=0.16, w=0.075, color=feet, claw=claw)
    kit.part("Head", "Head", pivot=(0, 0.0, 0.72))
    return kit.result()
