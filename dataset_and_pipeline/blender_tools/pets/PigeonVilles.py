"""Pigeon des villes (Commun, Animaux) : « Pigeon gris au regard vide. »

D'après lego_refs/PigeonVilles.png : gros corps rond en plaques grises, double anneau irisé vert / violet au cou, tête
gris foncé arrondie, gros yeux ronds sur les côtés (regard vide), bec saumon, ailes repliées en coques contre les flancs
avec un arc blanc, queue en éventail relevée, pattes orange trapues. Parties animées : tête (regarde, hoche au pas),
ailes, queue, pattes.
"""

from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    grey = kit.mat("gris", "#8F9399")
    dark = kit.mat("tete", "#5B5F66")
    wing = kit.mat("aile", "#80858C")
    feather = kit.mat("plume", "#55595F")
    white = kit.mat("blanc", "#EEEDE8")
    green = kit.mat("cou_vert", "#2E7D5E", rough=0.18, accent="#4B6FA8")
    purple = kit.mat("cou_violet", "#5E4384", rough=0.18, accent="#2E7D5E")
    eye_ring = kit.mat("tour_oeil", "#C3C7CC")
    pupil = kit.mat("pupille", "#0E0E10", rough=0.12)
    orange = kit.mat("bec_pattes", "#DE7856")

    # --- gros corps rond (le poitrail bombé devant, effilé vers la queue) et cou ---
    kit.add(kit.egg(1.2, 0.84, 0.84, center=(0, 0.08, 0.64), p=2.25, front=0.5, back=0.28), grey)
    kit.add(kit.cylinder(0.27, 0.1, center=(0, -0.14, 1.04)), green, bevel=0.018)
    kit.add(kit.cylinder(0.245, 0.09, center=(0, -0.14, 1.13)), purple, bevel=0.018)

    # --- tête : dôme arrondi, gros yeux ronds sur les côtés, bec en coin ---
    head = [(0.2, 0, -0.02, 0.42, 0.42, 2.6, 0.0), (0.0, 0, 0, 0.46, 0.48, 2.6, 0.0),
            (-0.19, 0, 0, 0.44, 0.46, 2.8, 0.0)]
    kit.add(kit.rounded(head, center=(0, -0.15, 1.38), bulge=(0.35, 0.12)), dark, "Head")
    for s in (-1, 1):
        kit.add(kit.disc(0.13, 0.03, center=(s * 0.228, -0.19, 1.41), normal=(s, 0, 0)), eye_ring, "Head", bevel=0.006)
        kit.add(kit.disc(0.102, 0.03, center=(s * 0.244, -0.19, 1.41), normal=(s, 0, 0)), white, "Head", bevel=0.006)
        kit.add(kit.disc(0.064, 0.02, center=(s * 0.262, -0.2, 1.41), normal=(s, 0, 0)), pupil, "Head", bevel=0.0)
    kit.add(kit.box((0.16, 0.1, 0.21), center=(0, -0.44, 1.33), rot=(80, 0, 0), taper=(0.5, 0.55)), orange, "Head",
            bevel=0.014)

    # --- ailes : coques bombées collées aux flancs, arc blanc + arc foncé ---
    for s, part in ((1, "WingL"), (-1, "WingR")):
        # coque épaisse à moitié rentrée dans le corps, penchée comme son flanc : on ne voit que le bombé
        sec = [(0.56, 0, -0.06, 0.1, 0.22, 2.4, 0.0), (0.34, 0, -0.01, 0.16, 0.5, 2.4, 0.0),
               (0.02, 0, 0, 0.17, 0.6, 2.4, 0.0), (-0.24, 0, 0.02, 0.16, 0.52, 2.4, 0.0),
               (-0.36, 0, 0.04, 0.1, 0.32, 2.4, 0.0)]
        kit.add(kit.rounded(sec, center=(s * 0.34, 0.1, 0.68), rot=(0, -s * 16, 0), bulge=(0.25, 0.3)), wing, part)
        kit.add(kit.band(kit.arc((s * 0.44, 0.04, 0.66), 0.2, 95, 265, steps=12), 0.08, 0.03), white, part, bevel=0.0)
        kit.add(kit.band(kit.arc((s * 0.435, 0.06, 0.66), 0.105, 115, 245, steps=8), 0.065, 0.028), feather, part,
                bevel=0.0)
        kit.part(part, "Wing", pivot=(s * 0.36, -0.16, 0.86), phase=float(s))

    # --- queue en éventail relevée, épaisse ---
    for yaw in (-15, 0, 15):
        kit.add(kit.box((0.17, 0.42, 0.07), center=(yaw * 0.007, 0.78, 0.74), rot=(-30, 0, yaw), taper=(0.92, 1.0)),
                feather, "Tail", bevel=0.016)

    # --- pattes trapues et pieds (3 doigts devant, 1 derrière) ---
    for s, part in ((1, "LegL"), (-1, "LegR")):
        x = s * 0.17
        kit.add(kit.box((0.12, 0.12, 0.24), center=(x, 0.04, 0.18)), orange, part, bevel=0.018)
        for dx, yaw in ((-0.065, 18), (0.0, 0), (0.065, -18)):
            kit.add(kit.box((0.065, 0.18, 0.06), center=(x + dx, -0.06, 0.03), rot=(0, 0, yaw)), orange, part,
                    bevel=0.012)
        kit.add(kit.box((0.06, 0.1, 0.055), center=(x, 0.12, 0.028)), orange, part, bevel=0.012)
        kit.part(part, "Leg", pivot=(x, 0.04, 0.3), phase=0.0 if s > 0 else 3.14159)

    kit.part("Head", "Head", pivot=(0, -0.13, 1.17))
    kit.part("Tail", "Tail", pivot=(0, 0.56, 0.7))
    return kit.result()
