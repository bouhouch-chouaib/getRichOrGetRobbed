"""Poisson-Lanterne Disco (Épique, Abysses) : « Sa lanterne est une boule à facettes : la fête au fond de l'océan. »

En briques LEGO, très détaillé (Épique : chrome et cristal, aucune lueur) : poisson-lanterne violet profond à ventre
mauve, énorme gueule souriante pleine de petites dents, gros yeux ronds de fêtard ; sa lanterne pend au bout d'une
tige et c'est une BOULE À FACETTES en carreaux de chrome qui TOURNE ; petites nageoires roses, queue en éventail,
taches de cristal violet sur les flancs. Il nage dans le ciel. Parties animées : boule (tourne), nageoires, queue.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    purple = kit.enamel("violet", "#3A2A8A")
    belly = kit.mat("ventre", "#B48AE6")
    pink = kit.enamel("nageoires", "#FF4AB4")
    chrome = kit.chrome("facettes")
    chrome2 = kit.chrome("facettes_bleues", tint="#B4D8FF")
    gem = kit.gem("taches", "#2A0A5A", "#A06AFF", "#F0E0FF")
    teeth = kit.mat("dents", "#FFFFFF", rough=0.15)
    mouth = kit.mat("gueule", "#1A0A2A")

    # --- corps rond, ventre, taches de cristal ---
    kit.add(kit.brick((0.62, 0.7, 0.56), center=(0, 0.04, 0.5)), purple, bevel=0.08)
    kit.add(kit.brick((0.52, 0.6, 0.66), center=(0, 0.04, 0.5)), purple, bevel=0.07)
    kit.add(kit.brick((0.46, 0.56, 0.08), center=(0, 0.06, 0.18)), belly, bevel=0.025)
    for s in (-1, 1):
        for y, z in ((0.0, 0.62), (0.2, 0.46), (-0.12, 0.4)):
            kit.add(kit.brick((0.03, 0.06, 0.06), center=(s * 0.315, y, z), rot=(45, 0, 0)), gem, bevel=0.006)

    # --- grande gueule souriante, dents, gros yeux ---
    kit.add(kit.brick((0.48, 0.06, 0.16), center=(0, -0.32, 0.38)), mouth, bevel=0.03)
    for k in range(7):
        x = (k - 3) * 0.06
        kit.add(kit.wedge((0.035, 0.03, 0.05), center=(x, -0.35, 0.44), rot=(180, 0, 0), tip=0.15), teeth, bevel=0.0)
        if 0 < k < 6:
            kit.add(kit.wedge((0.035, 0.03, 0.045), center=(x, -0.35, 0.32), tip=0.15), teeth, bevel=0.0)
    P.eyes(kit, "Body", x=0.15, y=-0.33, z=0.62, size=0.13, iris="#FF4AB4", pupil="round", tall=1.15, look=(0, 0.3))

    # --- tige et boule à facettes qui tourne ---
    # (la tige reste fixe : la boule qui tourne doit rester accrochée au bout)
    P.chain(kit, "Body", [(0, -0.1, 0.84), (0, -0.2, 1.02), (0, -0.38, 1.1), (0, -0.52, 1.04)], 0.04, [purple])
    cz = 0.9
    for k in range(8):
        for j in range(3):
            a = 2 * math.pi * k / 8 + j * 0.2
            z = cz + (j - 1) * 0.07
            r = 0.1 if j == 1 else 0.08
            kit.add(kit.brick((0.05, 0.05, 0.06), center=(math.cos(a) * r, -0.52 + math.sin(a) * r, z),
                              rot=(0, 0, math.degrees(a))), chrome if (k + j) % 2 else chrome2, "Ball", bevel=0.004)
    kit.add(kit.brick((0.12, 0.12, 0.2), center=(0, -0.52, cz)), chrome, "Ball", bevel=0.02)
    kit.part("Ball", "Orbit", pivot=(0, -0.52, cz), phase=1.5)

    # --- nageoires roses, queue en éventail ---
    for s, part in ((1, "FinL"), (-1, "FinR")):
        kit.add(kit.wedge((0.2, 0.04, 0.18), center=(s * 0.38, 0.0, 0.42), rot=(0, s * -70, 0), tip=0.2), pink, part,
                bevel=0.006)
        kit.part(part, "Fin", pivot=(s * 0.3, 0.0, 0.44), phase=float(s))
    kit.add(kit.brick((0.16, 0.18, 0.16), center=(0, 0.46, 0.5)), purple, "Tail", bevel=0.03)
    kit.add(kit.wedge((0.06, 0.26, 0.3), center=(0, 0.6, 0.66), rot=(-40, 0, 0), tip=0.2), pink, "Tail", bevel=0.008)
    kit.add(kit.wedge((0.06, 0.26, 0.3), center=(0, 0.6, 0.34), rot=(220, 0, 0), tip=0.2), pink, "Tail", bevel=0.008)
    kit.part("Tail", "SwimTail", pivot=(0, 0.4, 0.5))
    return kit.result()
