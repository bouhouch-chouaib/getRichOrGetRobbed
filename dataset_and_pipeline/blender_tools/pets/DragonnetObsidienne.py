"""Dragonnet d'Obsidienne (Épique, Fantastiques) : « Petit dragon noir anguleux, brillant comme du verre. »

En briques LEGO, très détaillé : petit dragon tout en angles, noir obsidienne très brillant (comme du verre), éclats
de cristal violet LUMINEUX en crête sur le dos et la queue, cornes anguleuses violettes, tête à museau en pente,
naseaux, yeux violets lumineux en fente, gueule à crocs, ventre en plaques violet foncé, ailes de chauve-souris
déployées à membranes violettes, pattes à griffes violettes, queue terminée par un cristal.
Parties animées : tête, ailes, 4 pattes, queue. (Il vole un peu : famille Dragon du jeu.)
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    obs = kit.mat("obsidienne", "#1E1A2E", rough=0.04)
    glass = kit.mat("reflet", "#3A3058", rough=0.04)
    crystal = kit.mat("cristal", "#A06AFF", rough=0.05, glow=2.4)
    belly = kit.mat("ventre", "#4A2E86", rough=0.1)
    fang = kit.mat("crocs", "#F0E8FF", rough=0.1)

    # --- corps anguleux, ventre en plaques, crête de cristaux ---
    P.quad_torso(kit, L=0.86, W=0.44, H=0.3, z=0.56, y0=0.06, main=obs, belly=belly, chest=belly, back=glass)
    for y, h in ((-0.2, 0.18), (0.0, 0.22), (0.2, 0.18), (0.38, 0.14)):
        P.tuft_piece(kit, "Body", (0, y, 0.74), (0, 0.4, 1.0), h, 0.1, crystal)
    kit.add(kit.brick((0.26, 0.26, 0.3), center=(0, -0.42, 0.78), rot=(30, 0, 0)), obs, bevel=0.025)

    # --- tête : museau en pente, naseaux, yeux, crocs, cornes ---
    kit.add(kit.brick((0.4, 0.4, 0.3), center=(0, -0.6, 0.98)), obs, "Head", bevel=0.03)
    kit.add(kit.brick((0.3, 0.26, 0.16), center=(0, -0.88, 0.9)), obs, "Head", bevel=0.02)
    kit.add(kit.slope((0.3, 0.24, 0.1), center=(0, -0.86, 1.03), facing="-Y", top=0.25), glass, "Head", bevel=0.012)
    for s in (-1, 1):
        kit.add(kit.box((0.04, 0.03, 0.03), center=(s * 0.08, -1.02, 0.96)), crystal, "Head", bevel=0.0)
        P.horn(kit, "Head", (s * 0.14, -0.5, 1.12), (s * 0.3, 0.7, 0.8), 0.26, 0.07, [crystal], segments=3)
        kit.add(kit.slope((0.08, 0.2, 0.12), center=(s * 0.22, -0.62, 0.88), facing=P.side(s), top=0.2), glass, "Head",
                bevel=0.008)
    P.eyes(kit, "Head", x=0.12, y=-0.8, z=1.04, size=0.1, iris="#B47AFF", pupil="slit", lid=obs, lid_drop=0.1,
           brow=glass, brow_angle=18, glow=2.4, tall=0.75)
    P.mouth(kit, "Head", y=-1.012, z=0.86, w=0.2, smile=0.2, fangs=fang)

    # --- ailes de chauve-souris, pattes, queue à cristal ---
    P.spread_wings(kit, x=0.22, y=0.0, z=0.78, span=0.7, height=0.44, mats=(obs, crystal, crystal), style="bat",
                   sweep=25, lift=28)
    P.quad_legs(kit, obs, yf=-0.28, yb=0.36, top_f=0.6, top_b=0.62, length_f=0.56, length_b=0.6, w=0.12, paw=glass,
                toe=glass, claw=crystal, x=0.15, toes=3)
    P.chain(kit, "Tail", [(0, 0.48, 0.62), (0, 0.72, 0.56), (0, 0.94, 0.52), (0, 1.12, 0.56), (0, 1.26, 0.64)], 0.14,
            [obs, glass], taper=0.02)
    kit.add(kit.brick((0.1, 0.1, 0.2), center=(0, 1.34, 0.72), rot=(-40, 0, 45)), crystal, "Tail", bevel=0.01)
    kit.part("Tail", "Tail", pivot=(0, 0.46, 0.62))
    kit.part("Head", "Head", pivot=(0, -0.46, 0.86))
    return kit.result()
