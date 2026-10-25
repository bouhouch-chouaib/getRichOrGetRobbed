"""Narval Aurore (Divin, Glace) : « Narval dont la corne projette des aurores boréales. »

En briques LEGO, très détaillé (Divin : or blanc et cristal, aucune lueur) : narval bleu glacier tacheté de gris
perle, ventre blanc, longue corne torsadée en OR BLANC ; de la pointe de la corne s'échappent des voiles d'AURORE en
cristal (vert, turquoise, violet) qui ondulent ; grands yeux doux, sourire, nageoires et queue en éventail.
Il nage dans le ciel. Parties animées : nageoires, queue, voiles d'aurore.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    body = kit.enamel("narval", "#A8D8F6")
    spot = kit.mat("taches", "#7A9AB8")
    belly = kit.mat("ventre", "#F6FBFF")
    whitegold = kit.chrome("corne", tint="#F6F0E0", rough=0.14)
    green = kit.gem("aurore_verte", "#0A4A2A", "#2AE68A", "#E0FFF0")
    teal = kit.gem("aurore_turquoise", "#0A3A4A", "#2AD8E6", "#E0FAFF")
    violet = kit.gem("aurore_violette", "#2A0A5A", "#9A5AFF", "#F0E6FF")

    # --- corps de narval en étages ---
    kit.add(kit.brick((0.56, 0.62, 0.46), center=(0, -0.16, 0.5)), body, bevel=0.07)
    kit.add(kit.brick((0.46, 0.44, 0.38), center=(0, 0.32, 0.52)), body, bevel=0.06)
    kit.add(kit.brick((0.32, 0.3, 0.26), center=(0, 0.64, 0.54)), body, bevel=0.05)
    # ventre blanc qui remonte sur les flancs (pas une planche dessous)
    for y, w, d, z, h in ((-0.16, 0.58, 0.6, 0.35, 0.18), (0.32, 0.48, 0.42, 0.39, 0.14), (0.64, 0.34, 0.28, 0.46, 0.1)):
        kit.add(kit.brick((w, d, h), center=(0, y, z)), belly, bevel=0.03)
    for x, y, z in ((0.15, -0.1, 0.74), (-0.1, 0.1, 0.72), (0.12, 0.36, 0.71), (-0.14, -0.3, 0.73), (0.0, 0.54, 0.67),
                    (0.2, 0.2, 0.7), (-0.18, 0.42, 0.69), (0.04, -0.02, 0.74)):
        kit.add(kit.tile(0.06, 0.06, center=(x, y, z)), spot, bevel=0.0)
    # anneaux d'or blanc entre les étages, diadème de cristaux de glace
    kit.add(kit.brick((0.5, 0.04, 0.42), center=(0, 0.1, 0.52)), whitegold, bevel=0.012)
    kit.add(kit.brick((0.36, 0.04, 0.3), center=(0, 0.49, 0.53)), whitegold, bevel=0.01)
    for k, (x, h) in enumerate(((-0.16, 0.1), (-0.08, 0.14), (0.0, 0.18), (0.08, 0.14), (0.16, 0.1))):
        kit.add(kit.wedge((0.06, 0.06, h), center=(x, -0.36, 0.73 + h / 2), tip=0.1), teal if k % 2 else violet, bevel=0.0)
    kit.add(kit.brick((0.4, 0.08, 0.03), center=(0, -0.36, 0.74)), whitegold, bevel=0.008)

    # --- visage doux, corne d'or blanc torsadée ---
    P.eyes(kit, "Body", x=0.15, y=-0.47, z=0.56, size=0.1, iris="#1E3A8A", pupil="round", tall=1.1)
    P.mouth(kit, "Body", y=-0.471, z=0.4, w=0.12, smile=0.6)
    P.horn(kit, "Body", (0.04, -0.46, 0.66), (0.04, -1.0, 0.35), 0.62, 0.07, [whitegold], segments=6, twist=60)

    # --- voiles d'aurore qui s'échappent de la corne ---
    for k, (mat, dz, dx) in enumerate(((green, 0.08, -0.05), (teal, 0.16, 0.04), (violet, 0.24, -0.02))):
        pts = [(0.06 + dx, -1.0, 0.86 + dz * 0.3), (0.12 + dx, -0.86, 1.0 + dz), (0.04 + dx, -0.66, 1.08 + dz),
               (-0.06 + dx, -0.46, 1.04 + dz)]
        P.chain(kit, "Aurora", pts, 0.1, [mat], height=0.025)
    kit.part("Aurora", "Leaf", pivot=(0.06, -0.96, 0.84), phase=0.7)

    # --- nageoires, queue en éventail ---
    for s, part in ((1, "FinL"), (-1, "FinR")):
        kit.add(kit.slope((0.3, 0.22, 0.05), center=(s * 0.38, -0.24, 0.36), facing="+X" if s > 0 else "-X", top=0.3,
                          rot=(0, s * 20, 0)), spot, part, bevel=0.012)
        kit.add(kit.box((0.3, 0.03, 0.03), center=(s * 0.39, -0.35, 0.38), rot=(0, s * 20, 0)), whitegold, part, bevel=0.0)
        kit.part(part, "Fin", pivot=(s * 0.27, -0.24, 0.4), phase=float(s))
    kit.add(kit.brick((0.18, 0.16, 0.16), center=(0, 0.84, 0.54)), body, "Tail", bevel=0.03)
    for s in (-1, 1):
        kit.add(kit.slope((0.32, 0.2, 0.05), center=(s * 0.18, 0.98, 0.56), facing="+X" if s > 0 else "-X", top=0.3,
                          rot=(0, s * -10, s * 15)), spot, "Tail", bevel=0.012)
    kit.part("Tail", "SwimTail", pivot=(0, 0.78, 0.54))
    return kit.result()
