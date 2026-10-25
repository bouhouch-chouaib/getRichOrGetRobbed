"""Dragon Aurore (Divin, Absurdes) : « Dragon fait d'aurores boréales qui changent de couleur. »

En briques LEGO, très détaillé (Divin : cristal et or blanc, aucune lueur) : dragon élancé en CRISTAL dont la couleur
passe du vert émeraude au turquoise puis au violet le long du corps, comme une aurore ; crête et ailes en voiles de
cristal dégradé (vert, turquoise, violet), cornes et griffes en OR BLANC, yeux dorés, petit sourire ; longue queue qui
ondule. Il vole. Parties animées : tête, ailes, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.gem("aurore_verte", "#0A4A2A", "#2AE68A", "#E0FFF0")
    teal = kit.gem("aurore_turquoise", "#0A3A4A", "#2AD8E6", "#E0FAFF")
    violet = kit.gem("aurore_violette", "#2A0A5A", "#9A5AFF", "#F0E6FF")
    pink = kit.gem("aurore_rose", "#4A0A3A", "#E65AD8", "#FFE6FA")
    belly = kit.pearl("ventre", color="#E8F6F0", sheen="#D8E6FF")
    whitegold = kit.chrome("or_blanc", tint="#F6F0E0", rough=0.14)

    # --- corps en dégradé d'aurore ---
    P.quad_torso(kit, L=0.86, W=0.42, H=0.3, z=0.66, y0=0.06, main=teal, belly=belly, chest=belly, back=green)
    kit.add(kit.brick((0.26, 0.26, 0.32), center=(0, -0.42, 0.88), rot=(30, 0, 0)), green, bevel=0.025)
    for k, (y, h, mat) in enumerate(((-0.24, 0.2, green), (-0.04, 0.24, teal), (0.16, 0.22, violet), (0.34, 0.16, pink))):
        kit.add(kit.wedge((0.04, 0.16, h), center=(0, y, 0.86 + h / 2), tip=0.1), mat, bevel=0.0)

    # --- tête : museau, cornes en or blanc, yeux dorés ---
    kit.add(kit.brick((0.38, 0.38, 0.3), center=(0, -0.6, 1.08)), green, "Head", bevel=0.03)
    kit.add(kit.brick((0.28, 0.26, 0.16), center=(0, -0.86, 1.0)), teal, "Head", bevel=0.02)
    kit.add(kit.slope((0.28, 0.24, 0.1), center=(0, -0.84, 1.13), facing="-Y", top=0.25), green, "Head", bevel=0.012)
    for s in (-1, 1):
        P.horn(kit, "Head", (s * 0.12, -0.5, 1.22), (s * 0.3, 0.8, 0.8), 0.3, 0.07, [whitegold], segments=3, curl=-0.3)
        kit.add(kit.box((0.03, 0.02, 0.03), center=(s * 0.07, -0.995, 1.04)), kit.mat("narines", "#0A2A1A"), "Head",
                bevel=0.0)
        for j in range(3):
            P.tuft_piece(kit, "Head", (s * 0.2, -0.52 + j * 0.06, 1.06), (s * 1.0, 0.4, 0.3), 0.14 - j * 0.03, 0.05,
                         (teal, violet, pink)[j])
    P.eyes(kit, "Head", x=0.11, y=-0.79, z=1.14, size=0.09, iris="#FFC21E", pupil="slit", lid=green, lid_drop=0.08,
           tall=0.85)
    P.mouth(kit, "Head", y=-0.991, z=0.96, w=0.14, smile=0.5)
    kit.part("Head", "Head", pivot=(0, -0.46, 0.96))

    # --- ailes en voiles d'aurore ---
    P.spread_wings(kit, x=0.22, y=0.0, z=0.86, span=0.78, height=0.5, mats=(teal, violet, pink), style="feather",
                   sweep=25, lift=25)

    # --- pattes à griffes d'or blanc, longue queue qui ondule ---
    P.quad_legs(kit, teal, yf=-0.28, yb=0.36, top_f=0.68, top_b=0.7, length_f=0.62, length_b=0.66, w=0.11, paw=green,
                toe=green, claw=whitegold, x=0.15, toes=3)
    P.chain(kit, "Tail", [(0, 0.48, 0.72), (0, 0.72, 0.66), (0.06, 0.94, 0.64), (0.02, 1.12, 0.72), (-0.04, 1.26, 0.86)],
            0.16, [violet, pink], taper=0.025)
    kit.add(kit.wedge((0.04, 0.16, 0.22), center=(-0.05, 1.32, 0.98), rot=(-30, 0, 0), tip=0.1), green, "Tail", bevel=0.0)
    kit.part("Tail", "Tail", pivot=(0, 0.46, 0.72))
    return kit.result()
