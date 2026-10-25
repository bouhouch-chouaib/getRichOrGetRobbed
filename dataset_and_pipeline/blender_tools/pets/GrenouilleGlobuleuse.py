"""Grenouille Globuleuse (Inhabituel, Animaux) : « Grenouille vert fluo aux yeux énormes. »

Construite en briques LEGO (sans tenons), cubes d'abord : corps trapu en briques empilées qui se resserrent vers le
haut (pentes devant et derrière), ventre jaune-vert pâle, grande bouche en tuile foncée qui fait le tour de l'avant,
taches en tuiles carrées, deux ÉNORMES yeux cubes blancs sur le dessus (paupière verte, grosse pupille carrée noire),
cuisses repliées en briques avec de grands pieds plats à doigts carrés, petits pieds avant.
Parties animées : les yeux (« Head », regardent autour), les pattes arrière (« FrogLeg », petits sauts) ; le corps
rebondit (profil Frog du jeu).
"""

from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.mat("vert", "#52D63D", rough=0.25)
    belly = kit.mat("ventre", "#D8F08C")
    dark = kit.mat("vert_fonce", "#2C8A2A")
    white = kit.mat("blanc", "#F6F6F2", rough=0.15)
    black = kit.mat("pupille", "#101012", rough=0.1)
    shine = kit.mat("reflet", "#FFFFFF", rough=0.05)

    # --- corps trapu : trois étages de briques, pentes devant / derrière en haut ---
    kit.add(kit.brick((0.84, 0.76, 0.26), center=(0, 0.02, 0.27)), green, bevel=0.035)
    kit.add(kit.brick((0.58, 0.06, 0.26), center=(0, -0.38, 0.27)), belly, bevel=0.02)
    kit.add(kit.brick((0.74, 0.66, 0.2), center=(0, 0.04, 0.5)), green, bevel=0.03)
    kit.add(kit.brick((0.62, 0.32, 0.12), center=(0, 0.08, 0.66)), green, bevel=0.02)
    kit.add(kit.slope((0.62, 0.16, 0.12), center=(0, -0.16, 0.66), facing="-Y", top=0.3), green, bevel=0.02)
    kit.add(kit.slope((0.62, 0.16, 0.12), center=(0, 0.32, 0.66), facing="+Y", top=0.3), green, bevel=0.02)
    # grande bouche : tuile foncée sur le devant qui tourne sur les côtés
    kit.add(kit.box((0.64, 0.03, 0.04), center=(0, -0.405, 0.42)), dark, bevel=0.008)
    for s in (-1, 1):
        kit.add(kit.box((0.03, 0.2, 0.04), center=(s * 0.425, -0.29, 0.42)), dark, bevel=0.008)
    # taches carrées sur le dos et les flancs
    for x, y, w in ((0.2, 0.18, 0.11), (-0.16, 0.02, 0.09), (0.02, 0.2, 0.08)):
        kit.add(kit.tile(w, w, center=(x, y, 0.735)), dark, bevel=0.006)
    for s, y in ((1, 0.12), (-1, 0.22)):
        kit.add(kit.box((0.025, 0.1, 0.09), center=(s * 0.432, y, 0.27)), dark, bevel=0.006)

    # --- énormes yeux cubes sur le dessus ---
    for s in (-1, 1):
        x = s * 0.2
        kit.add(kit.brick((0.27, 0.25, 0.25), center=(x, -0.13, 0.86)), white, "Head", bevel=0.04)
        kit.add(kit.brick((0.29, 0.27, 0.07), center=(x, -0.12, 1.0)), green, "Head", bevel=0.02)
        kit.add(kit.slope((0.29, 0.08, 0.06), center=(x, -0.25, 0.995), facing="-Y", top=0.3), green, "Head",
                bevel=0.012)
        kit.add(kit.box((0.13, 0.03, 0.13), center=(x + s * 0.01, -0.26, 0.85)), black, "Head", bevel=0.01)
        kit.add(kit.box((0.04, 0.012, 0.04), center=(x - s * 0.025, -0.278, 0.885)), shine, "Head", bevel=0.0)

    # --- cuisses repliées et grands pieds plats (sauts), petits pieds avant ---
    for s, part in ((1, "LegBL"), (-1, "LegBR")):
        kit.add(kit.brick((0.2, 0.42, 0.22), center=(s * 0.47, 0.12, 0.2), rot=(0, 0, s * -8)), green, part,
                bevel=0.03)
        kit.add(kit.brick((0.26, 0.3, 0.06), center=(s * 0.5, -0.12, 0.03), rot=(0, 0, s * -8)), green, part,
                bevel=0.015)
        for dx in (-0.08, 0.0, 0.08):
            kit.add(kit.brick((0.07, 0.07, 0.05), center=(s * 0.5 + dx, -0.3, 0.03)), belly, part, bevel=0.01)
        kit.part(part, "FrogLeg", pivot=(s * 0.42, 0.25, 0.28))
    for s in (-1, 1):
        kit.add(kit.brick((0.1, 0.1, 0.16), center=(s * 0.22, -0.34, 0.08)), green, bevel=0.015)
        for dx in (-0.04, 0.04):
            kit.add(kit.brick((0.05, 0.06, 0.04), center=(s * 0.22 + dx, -0.42, 0.02)), belly, bevel=0.008)

    kit.part("Head", "Head", pivot=(0, -0.13, 0.72))
    return kit.result()
