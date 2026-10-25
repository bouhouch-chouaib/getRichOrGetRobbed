"""Panthère Néon (Épique, Animaux) : « Panthère noire aux lignes magenta lumineuses. »

En briques LEGO, très détaillée : panthère noire violacée élancée (torse sculpté bas et long, épaules marquées),
circuits de lignes magenta LUMINEUSES sur les flancs, le dos, le front, les joues et les pattes, yeux magenta
lumineux en fente sous un sourcil félin, oreilles courtes à intérieur magenta, museau, truffe, moustaches magenta,
pattes articulées à griffes néon, longue queue noire qui finit en pointe néon. Parties animées : tête, 4 pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.mat("noir", "#1C1830", rough=0.16)
    deep = kit.mat("violet_noir", "#2A2148", rough=0.16)
    neon = kit.mat("neon", "#FF2BD6", rough=0.2, glow=3.2)

    # --- torse élancé, circuits néon ---
    P.quad_torso(kit, L=1.04, W=0.42, H=0.26, z=0.58, y0=0.04, main=black, belly=deep, chest=deep, back=deep, hump=0.4)
    for s in (-1, 1):
        kit.add(kit.box((0.022, 0.72, 0.03), center=(s * 0.222, 0.04, 0.62)), neon, bevel=0.004)
        kit.add(kit.box((0.022, 0.22, 0.03), center=(s * 0.222, -0.27, 0.54), rot=(-30, 0, 0)), neon, bevel=0.004)
        kit.add(kit.box((0.022, 0.24, 0.03), center=(s * 0.222, 0.34, 0.54), rot=(30, 0, 0)), neon, bevel=0.004)
        kit.add(kit.box((0.022, 0.03, 0.12), center=(s * 0.222, 0.0, 0.5)), neon, bevel=0.004)
    kit.add(kit.tile(0.035, 0.62, center=(0, 0.02, 0.733)), neon, bevel=0.004)
    for y in (-0.2, 0.2):
        kit.add(kit.tile(0.2, 0.03, center=(0, y, 0.733)), neon, bevel=0.004)
    kit.add(kit.brick((0.3, 0.24, 0.28), center=(0, -0.44, 0.74), rot=(16, 0, 0)), black, bevel=0.03)

    # --- tête féline, circuits sur le front et les joues, yeux néon ---
    kit.add(kit.brick((0.46, 0.38, 0.3), center=(0, -0.6, 0.9)), black, "Head", bevel=0.035)
    kit.add(kit.brick((0.4, 0.3, 0.06), center=(0, -0.58, 1.07)), deep, "Head", bevel=0.015)
    kit.add(kit.brick((0.28, 0.16, 0.14), center=(0, -0.83, 0.84)), black, "Head", bevel=0.02)
    P.nose(kit, "Head", y=-0.91, z=0.88, w=0.07, color="#3A2A4A")
    P.mouth(kit, "Head", y=-0.912, z=0.8, w=0.12, smile=0.1)
    P.whiskers(kit, "Head", x=0.1, y=-0.88, z=0.85, color="#FF7AE8", n=2, length=0.14)
    kit.add(kit.tile(0.035, 0.26, center=(0, -0.58, 1.103)), neon, "Head", bevel=0.004)
    for s in (-1, 1):
        kit.add(kit.box((0.022, 0.24, 0.03), center=(s * 0.232, -0.62, 0.88)), neon, "Head", bevel=0.004)
        kit.add(kit.slope((0.1, 0.2, 0.12), center=(s * 0.26, -0.64, 0.82), facing=P.side(s), top=0.2), black, "Head",
                bevel=0.012)
        P.ear(kit, "Head", s, (s * 0.16, -0.52, 1.1), w=0.17, h=0.16, color=black, inner=neon, tilt=(0, 10))
    P.eyes(kit, "Head", x=0.12, y=-0.79, z=0.96, size=0.11, iris="#FF4FE0", pupil="slit", lid=black, lid_drop=0.1,
           brow=deep, brow_angle=14, glow=3.2, tall=0.7)

    # --- pattes à bracelets néon et griffes néon, longue queue à bout néon ---
    P.quad_legs(kit, black, yf=-0.32, yb=0.4, top_f=0.58, top_b=0.62, length_f=0.56, length_b=0.6, w=0.12, paw=deep,
                toe=deep, claw=neon, x=0.15, toes=3)
    for leg, x, y, z in (("LegFL", 0.15, -0.32, 0.18), ("LegFR", -0.15, -0.32, 0.18), ("LegBL", 0.15, 0.44, 0.2),
                         ("LegBR", -0.15, 0.44, 0.2)):
        kit.add(kit.box((0.14, 0.14, 0.028), center=(x, y, z)), neon, leg, bevel=0.004)
    P.chain(kit, "Tail", [(0, 0.54, 0.66), (0, 0.76, 0.66), (0, 0.98, 0.72), (0, 1.16, 0.86), (0, 1.26, 1.04),
                          (0, 1.28, 1.18)], 0.1, [black, black, black, black, neon], taper=0.006)
    kit.part("Tail", "Tail", pivot=(0, 0.52, 0.66))
    kit.part("Head", "Head", pivot=(0, -0.46, 0.78))
    return kit.result()
