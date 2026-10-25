"""Corbeau-Horloge (Rare, Hybrides) : « Oiseau mécanique noir aux engrenages cuivrés. »

En briques LEGO, très détaillé : corbeau mécanique en plaques de métal noir rivetées de cuivre, bec en cuivre, un œil
rouge LUMINEUX et un œil-loupe, une HORLOGE sur le poitrail (cadran crème, graduations, aiguilles qui TOURNENT),
engrenages cuivrés qui tournent sur les ailes, clé de remontage dorée dans le dos (elle tourne), queue en lames,
pattes en tiges articulées. Parties animées : tête, ailes, queue, aiguilles, engrenages, clé.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    black = kit.mat("metal_noir", "#26242C", metal=0.6, rough=0.3)
    plate = kit.mat("plaques", "#3A3844", metal=0.6, rough=0.3)
    copper = kit.mat("cuivre", "#E07A3A", metal=0.85, rough=0.25)
    brass = kit.mat("laiton", "#FFC24A", metal=0.85, rough=0.2)
    face = kit.mat("cadran", "#FFF2D6", rough=0.2)
    tick = kit.mat("graduations", "#2A1A0E")
    red = kit.mat("oeil_rouge", "#FF2A2A", rough=0.1, glow=2.6)
    lens = kit.mat("loupe", "#8AD8FF", rough=0.03)

    # --- corps en plaques rivetées ---
    kit.add(kit.brick((0.52, 0.6, 0.24), center=(0, 0.06, 0.36)), black, bevel=0.03)
    kit.add(kit.brick((0.6, 0.72, 0.3), center=(0, 0.04, 0.6)), black, bevel=0.035)
    kit.add(kit.brick((0.5, 0.5, 0.12), center=(0, 0.0, 0.8)), plate, bevel=0.025)
    kit.add(kit.slope((0.46, 0.22, 0.2), center=(0, 0.48, 0.62), facing="+Y", top=0.3), plate, bevel=0.02)
    for x, z in ((0.27, 0.48), (-0.27, 0.48), (0.27, 0.7), (-0.27, 0.7), (0.0, 0.86)):
        kit.add(kit.box((0.03, 0.03, 0.03), center=(x, -0.33 if z < 0.8 else -0.26, z)), copper, bevel=0.0)

    # --- horloge du poitrail ---
    kit.add(kit.disc(0.17, 0.04, center=(0, -0.335, 0.56), normal=(0, -1, 0), sides=12), copper, bevel=0.0)
    kit.add(kit.disc(0.145, 0.03, center=(0, -0.355, 0.56), normal=(0, -1, 0), sides=12), face, bevel=0.0)
    for k in range(12):
        a = math.radians(30 * k)
        big = k % 3 == 0
        kit.add(kit.box((0.012, 0.01, 0.035 if big else 0.02), center=(math.sin(a) * 0.115, -0.372, 0.56 + math.cos(a) * 0.115),
                        rot=(0, -math.degrees(a), 0)), tick, bevel=0.0)
    kit.add(kit.box((0.022, 0.012, 0.12), center=(0, -0.38, 0.6)), tick, "HandM", bevel=0.0)
    kit.part("HandM", "Orbit", pivot=(0, -0.38, 0.56), rot=(90, 0, 0), phase=-1.2)
    kit.add(kit.box((0.026, 0.012, 0.08), center=(0.0, -0.39, 0.6)), copper, "HandH", bevel=0.0)
    kit.part("HandH", "Orbit", pivot=(0, -0.39, 0.56), rot=(90, 0, 0), phase=-0.1)
    kit.add(kit.box((0.035, 0.015, 0.035), center=(0, -0.397, 0.56)), brass, bevel=0.0)

    # --- tête : bec en cuivre, œil rouge, œil-loupe ---
    kit.add(kit.brick((0.38, 0.4, 0.32), center=(0, -0.16, 1.04)), black, "Head", bevel=0.035)
    kit.add(kit.brick((0.3, 0.34, 0.05), center=(0, -0.14, 1.21)), plate, "Head", bevel=0.012)
    kit.add(kit.brick((0.14, 0.16, 0.1), center=(0, -0.43, 1.0)), copper, "Head", bevel=0.015)
    kit.add(kit.slope((0.12, 0.14, 0.08), center=(0, -0.55, 0.98), facing="-Y", top=0.2), copper, "Head", bevel=0.01)
    kit.add(kit.brick((0.1, 0.03, 0.1), center=(0.1, -0.375, 1.08)), red, "Head", bevel=0.015)
    kit.add(kit.disc(0.065, 0.04, center=(-0.1, -0.38, 1.08), normal=(0, -1, 0), sides=8), brass, "Head", bevel=0.0)
    kit.add(kit.disc(0.045, 0.03, center=(-0.1, -0.395, 1.08), normal=(0, -1, 0), sides=8), lens, "Head", bevel=0.0)
    kit.add(kit.box((0.02, 0.012, 0.02), center=(-0.11, -0.412, 1.08)), tick, "Head", bevel=0.0)
    for k in range(3):
        P.tuft_piece(kit, "Head", ((k - 1) * 0.06, -0.08, 1.23), ((k - 1) * 0.4, 0.8, 0.6), 0.14, 0.05, plate)
    kit.part("Head", "Head", pivot=(0, -0.12, 0.86))

    # --- ailes à engrenages qui tournent ---
    P.bird_wings(kit, x=0.34, y=0.04, z=0.56, length=0.6, height=0.4, cov=black, sec=plate, prim=black, bar=copper,
                 thick=0.1)
    for s in (-1, 1):
        part = f"Gear{0 if s > 0 else 1}"
        P.gear(kit, part, (s * 0.41, -0.02, 0.62), 0.09, 0.03, 8, copper, normal=(s, 0, 0), hub=brass)
        kit.part(part, "Orbit", pivot=(s * 0.41, -0.02, 0.62), rot=(0, s * 90, 0), phase=1.4 * s)

    # --- clé de remontage dans le dos ---
    kit.add(kit.brick((0.04, 0.12, 0.04), center=(0, 0.46, 0.74)), brass, "Key", bevel=0.008)
    for s in (-1, 1):
        kit.add(kit.brick((0.12, 0.03, 0.08), center=(s * 0.07, 0.53, 0.74)), brass, "Key", bevel=0.01)
    kit.part("Key", "Orbit", pivot=(0, 0.46, 0.74), rot=(-90, 0, 0), phase=0.7)

    # --- queue en lames, pattes en tiges ---
    P.tail_fan(kit, "Tail", (0, 0.5, 0.52), n=5, length=0.34, width=0.08, mats=[black, plate], spread=12, pitch=-15)
    P.bird_feet(kit, x=0.14, y=0.06, h=0.24, w=0.06, color=plate, claw=copper)
    return kit.result()
