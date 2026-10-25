"""Pigeon des villes (Commun, Animaux) : « Pigeon gris au regard vide. »

En briques LEGO, très détaillé, d'après lego_refs/PigeonVilles.png : corps bleu-gris en briques empilées (poitrail
bombé, croupion), cou irisé vert émeraude et violet vif en deux colliers + plaques, tête gris ardoise, bec saumon avec
la morille blanche (cire) des pigeons, gros yeux ronds orange au regard vide sur les côtés, ailes en trois rangs de
plumes avec deux barres noires, queue en éventail à bout foncé, pattes rouge corail à griffes.
Parties animées : tête (hoche au pas), ailes, queue, pattes.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    grey = kit.mat("gris", "#8E9CB8")
    light = kit.mat("gris_clair", "#B3BFD6")
    head = kit.mat("tete", "#5C6684")
    wing = kit.mat("aile", "#7E8CAA")
    dark = kit.mat("plume", "#465070")
    green = kit.mat("cou_vert", "#14C88C", rough=0.15)
    purple = kit.mat("cou_violet", "#A24ED6", rough=0.15)
    beak = kit.mat("bec", "#FF8A6A")
    cere = kit.mat("cire", "#F4F0EA")
    legs = kit.mat("pattes", "#FF5A4A")
    ring = kit.mat("tour_oeil", "#E8EDF5")
    claw = kit.mat("griffes", "#3A3238")

    # --- corps : étages de briques, poitrail bombé, croupion ---
    kit.add(kit.brick((0.56, 0.6, 0.2), center=(0, 0.06, 0.4)), grey, bevel=0.03)
    kit.add(kit.slope((0.56, 0.16, 0.2), center=(0, -0.32, 0.4), facing="-Y", top=0.35, rot=(180, 0, 0)), grey,
            bevel=0.02)
    kit.add(kit.brick((0.7, 0.84, 0.3), center=(0, 0.06, 0.65)), grey, bevel=0.035)
    kit.add(kit.brick((0.5, 0.06, 0.34), center=(0, -0.37, 0.64)), light, bevel=0.02)
    kit.add(kit.brick((0.6, 0.5, 0.16), center=(0, -0.02, 0.88)), grey, bevel=0.025)
    kit.add(kit.slope((0.6, 0.18, 0.16), center=(0, -0.36, 0.88), facing="-Y", top=0.3), grey, bevel=0.02)
    kit.add(kit.slope((0.6, 0.3, 0.16), center=(0, 0.38, 0.88), facing="+Y", top=0.2), grey, bevel=0.02)
    kit.add(kit.slope((0.5, 0.22, 0.22), center=(0, 0.58, 0.62), facing="+Y", top=0.3), grey, bevel=0.02)

    # --- cou irisé : deux colliers + plaques irisées sur la poitrine ---
    kit.add(kit.brick((0.46, 0.44, 0.1), center=(0, -0.14, 1.0)), green, bevel=0.018)
    kit.add(kit.brick((0.42, 0.4, 0.09), center=(0, -0.14, 1.095)), purple, bevel=0.018)
    for s in (-1, 1):
        kit.add(kit.slope((0.16, 0.06, 0.16), center=(s * 0.14, -0.36, 0.92), facing="-Y", top=0.3), green, bevel=0.01)

    # --- tête ardoise, bec saumon avec cire blanche, gros yeux orange sur les côtés ---
    kit.add(kit.brick((0.44, 0.46, 0.36), center=(0, -0.15, 1.31)), head, "Head", bevel=0.04)
    kit.add(kit.brick((0.38, 0.4, 0.07), center=(0, -0.15, 1.525)), head, "Head", bevel=0.02)
    kit.add(kit.slope((0.38, 0.08, 0.07), center=(0, -0.38, 1.525), facing="-Y", top=0.3), head, "Head", bevel=0.01)
    kit.add(kit.brick((0.14, 0.12, 0.08), center=(0, -0.42, 1.3)), beak, "Head", bevel=0.012)
    kit.add(kit.slope((0.12, 0.14, 0.07), center=(0, -0.53, 1.29), facing="-Y", top=0.3), beak, "Head", bevel=0.01)
    kit.add(kit.brick((0.1, 0.08, 0.05), center=(0, -0.41, 1.36)), cere, "Head", bevel=0.01)
    P.side_eyes(kit, "Head", x=0.225, y=-0.2, z=1.36, size=0.15, iris="#FF7A1A", pupil="round", ring=ring)

    # --- ailes en trois rangs à barres noires, queue en éventail, pattes corail ---
    P.bird_wings(kit, x=0.4, y=0.08, z=0.66, length=0.64, height=0.4, cov=wing, sec=grey, prim=dark, bar=dark,
                 thick=0.1)
    P.tail_fan(kit, "Tail", (0, 0.58, 0.72), n=5, length=0.42, width=0.12, mats=[dark, wing, dark], spread=12,
               pitch=-26)
    P.bird_feet(kit, x=0.16, y=0.04, h=0.28, w=0.08, color=legs, claw=claw)
    kit.part("Head", "Head", pivot=(0, -0.14, 1.14))
    return kit.result()
