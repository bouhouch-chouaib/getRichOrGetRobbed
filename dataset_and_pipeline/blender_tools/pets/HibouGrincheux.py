"""Hibou Grincheux (Rare, Animaux) : « Hibou brun aux sourcils froncés. »

En briques LEGO : un gros bloc brun (tête et corps d'un seul tenant, comme un vrai hibou), masque facial beige,
grands yeux orange, gros sourcils brun foncé en pentes FRONCÉS vers le centre, petit bec jaune qui pique vers le bas,
aigrettes en coins sur les coins de la tête, ventre beige à chevrons, ailes brunes tachetées, pieds jaunes.
Parties animées : tête (un hibou tourne la tête !), ailes, queue, pattes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    brown = kit.mat("brun", "#785532")
    dark = kit.mat("brun_fonce", "#4A321C")
    beige = kit.mat("beige", "#E6C896")
    yellow = kit.mat("bec", "#E8B23A")
    spot = kit.mat("tache", "#D9B47E")

    # --- corps : bloc trapu, ventre beige à chevrons ---
    kit.add(kit.brick((0.62, 0.56, 0.5), center=(0, 0.04, 0.42)), brown, bevel=0.04)
    kit.add(kit.brick((0.42, 0.06, 0.4), center=(0, -0.25, 0.4)), beige, bevel=0.02)
    for k, z in enumerate((0.3, 0.42, 0.54)):
        for s in (-1, 1):
            kit.add(kit.box((0.09, 0.02, 0.03), center=(s * 0.05, -0.285, z), rot=(0, s * 30, 0)), dark, bevel=0.0)
    kit.add(kit.slope((0.5, 0.16, 0.18), center=(0, 0.34, 0.26), facing="+Y", top=0.3), brown, bevel=0.02)

    # --- tête : grand bloc, masque beige, yeux orange, sourcils froncés, bec, aigrettes ---
    kit.add(kit.brick((0.66, 0.54, 0.46), center=(0, -0.0, 0.92)), brown, "Head", bevel=0.045)
    kit.add(kit.brick((0.56, 0.05, 0.34), center=(0, -0.27, 0.9)), beige, "Head", bevel=0.02)
    P.eyes(kit, "Head", 0.14, -0.295, 0.93, size=0.16, iris="#F08A1C", pupil_w=0.45, pupil_h=0.45, highlight=True)
    for s in (-1, 1):
        kit.add(kit.slope((0.22, 0.1, 0.08), center=(s * 0.14, -0.3, 1.05), facing="-Y", top=0.4,
                          rot=(0, s * -20, 0)), dark, "Head", bevel=0.012)
        kit.add(kit.wedge((0.14, 0.12, 0.2), center=(s * 0.25, 0.0, 1.24), rot=(0, s * 14, 0), tip=0.12), brown,
                "Head", bevel=0.012)
    kit.add(kit.slope((0.08, 0.08, 0.12), center=(0, -0.32, 0.8), facing="-Y", top=0.25), yellow, "Head", bevel=0.01)

    # --- ailes tachetées, petite queue, pieds jaunes ---
    P.bird_wings(kit, brown, x=0.34, y=0.04, z=0.44, length=0.5, height=0.42, thick=0.09, bars=[spot, spot], tip=dark)
    kit.add(kit.brick((0.24, 0.22, 0.06), center=(0, 0.36, 0.18), rot=(-20, 0, 0)), dark, "Tail", bevel=0.012)
    kit.part("Tail", "Tail", pivot=(0, 0.28, 0.22))
    P.bird_legs(kit, yellow, x=0.14, y=-0.08, h=0.12, w=0.09)
    kit.part("Head", "Head", pivot=(0, 0.0, 0.68))
    return kit.result()
