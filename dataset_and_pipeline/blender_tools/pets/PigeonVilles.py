"""Pigeon des villes (Commun, Animaux) : « Pigeon gris au regard vide. »

Construit en briques LEGO (sans tenons), cubes d'abord, d'après lego_refs/PigeonVilles.png : corps en briques
empilées arrondi par des pentes (poitrail devant, croupion derrière), collier carré irisé vert puis violet, tête en
brique gris foncé, yeux ronds sur les côtés (tuiles rondes : regard vide), bec en pente saumon, ailes en briques
plaquées sur les flancs avec deux barres claires, queue en plaques relevées, pattes et pieds orange en briques.
Parties animées : tête (regarde, hoche au pas), ailes, queue, pattes.
"""

from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    grey = kit.mat("gris", "#8F9399")
    dark = kit.mat("tete", "#5B5F66")
    wing = kit.mat("aile", "#7E838A")
    feather = kit.mat("plume", "#55595F")
    white = kit.mat("blanc", "#EEEDE8")
    green = kit.mat("cou_vert", "#2E7D5E", rough=0.18, accent="#4B6FA8")
    purple = kit.mat("cou_violet", "#5E4384", rough=0.18, accent="#2E7D5E")
    eye_ring = kit.mat("tour_oeil", "#C3C7CC")
    pupil = kit.mat("pupille", "#0E0E10", rough=0.12)
    orange = kit.mat("bec_pattes", "#DE7856")

    # --- corps : trois étages de briques, pentes au poitrail et au croupion ---
    kit.add(kit.brick((0.58, 0.62, 0.2), center=(0, 0.06, 0.4)), grey, bevel=0.03)
    kit.add(kit.slope((0.58, 0.16, 0.2), center=(0, -0.33, 0.4), facing="-Y", top=0.35, rot=(180, 0, 0)), grey,
            bevel=0.02)
    kit.add(kit.brick((0.7, 0.86, 0.3), center=(0, 0.06, 0.65)), grey, bevel=0.035)
    kit.add(kit.brick((0.6, 0.5, 0.16), center=(0, -0.02, 0.88)), grey, bevel=0.025)
    kit.add(kit.slope((0.6, 0.18, 0.16), center=(0, -0.36, 0.88), facing="-Y", top=0.3), grey, bevel=0.02)
    kit.add(kit.slope((0.6, 0.3, 0.16), center=(0, 0.38, 0.88), facing="+Y", top=0.2), grey, bevel=0.02)
    kit.add(kit.slope((0.5, 0.22, 0.2), center=(0, 0.6, 0.62), facing="+Y", top=0.3), grey, bevel=0.02)

    # --- collier carré irisé et tête en brique ---
    kit.add(kit.brick((0.44, 0.42, 0.09), center=(0, -0.14, 1.005)), green, bevel=0.018)
    kit.add(kit.brick((0.4, 0.38, 0.09), center=(0, -0.14, 1.095)), purple, bevel=0.018)
    kit.add(kit.brick((0.44, 0.46, 0.36), center=(0, -0.15, 1.32)), dark, "Head", bevel=0.04)
    kit.add(kit.brick((0.38, 0.4, 0.07), center=(0, -0.15, 1.535)), dark, "Head", bevel=0.02)
    kit.add(kit.slope((0.16, 0.18, 0.1), center=(0, -0.45, 1.28), facing="-Y", top=0.3), orange, "Head", bevel=0.012)
    for s in (-1, 1):  # yeux ronds (tuiles rondes LEGO) sur les côtés : le regard vide
        kit.add(kit.disc(0.13, 0.03, center=(s * 0.232, -0.18, 1.35), normal=(s, 0, 0)), eye_ring, "Head", bevel=0.006)
        kit.add(kit.disc(0.1, 0.03, center=(s * 0.248, -0.18, 1.35), normal=(s, 0, 0)), white, "Head", bevel=0.006)
        kit.add(kit.disc(0.062, 0.02, center=(s * 0.266, -0.19, 1.35), normal=(s, 0, 0)), pupil, "Head", bevel=0.0)

    # --- ailes : briques plaquées sur les flancs, pointe en pente vers l'arrière, deux barres claires ---
    for s, part in ((1, "WingL"), (-1, "WingR")):
        x = s * 0.4
        kit.add(kit.brick((0.1, 0.62, 0.38), center=(x, 0.06, 0.68)), wing, part, bevel=0.025)
        kit.add(kit.slope((0.1, 0.24, 0.3), center=(x, 0.49, 0.64), facing="+Y", top=0.25), wing, part, bevel=0.02)
        for dz, mat in ((0.06, white), (-0.06, feather)):
            kit.add(kit.box((0.025, 0.4, 0.055), center=(x + s * 0.06, 0.1, 0.64 + dz), rot=(-14, 0, 0)), mat, part,
                    bevel=0.008)
        kit.part(part, "Wing", pivot=(x - s * 0.03, -0.2, 0.86), phase=float(s))

    # --- queue en plaques relevées, en éventail ---
    for yaw in (-14, 0, 14):
        kit.add(kit.brick((0.17, 0.42, 0.06), center=(yaw * 0.006, 0.74, 0.76), rot=(-28, 0, yaw)), feather, "Tail",
                bevel=0.015)

    # --- pattes et pieds en briques orange ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        x = s * 0.16
        kit.add(kit.brick((0.11, 0.11, 0.24), center=(x, 0.04, 0.18)), orange, part, bevel=0.015)
        for dx, yaw in ((-0.065, 16), (0.0, 0), (0.065, -16)):
            kit.add(kit.brick((0.06, 0.17, 0.055), center=(x + dx, -0.06, 0.028), rot=(0, 0, yaw)), orange, part,
                    bevel=0.01)
        kit.add(kit.brick((0.055, 0.1, 0.05), center=(x, 0.12, 0.025)), orange, part, bevel=0.01)
        kit.part(part, "Leg", pivot=(x, 0.04, 0.3), phase=0.0 if s > 0 else 3.14159)

    kit.part("Head", "Head", pivot=(0, -0.14, 1.14))
    kit.part("Tail", "Tail", pivot=(0, 0.62, 0.7))
    return kit.result()
