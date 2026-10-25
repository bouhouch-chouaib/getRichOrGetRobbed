"""Morse Moustachu (Épique, Glace) : « Sa moustache givrée fait sa fierté. Ses défenses aussi. »

En briques LEGO, très détaillé (Épique : chrome et cristal, aucune lueur) : gros morse brun cannelle plissé (plis
plus foncés), énorme moustache blanche en brosse givrée de petits cristaux de glace, deux longues défenses ivoire
cerclées de chrome, petits yeux fiers sous des sourcils broussailleux, joues rebondies, nageoires avant et queue
en éventail ; un monocle chromé pour la classe. Parties animées : tête, nageoires, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    brown = kit.mat("peau", "#B47A5A")
    fold = kit.mat("plis", "#8A5438")
    light = kit.mat("museau", "#D8A07A")
    white = kit.mat("moustache", "#FFFFFF", rough=0.5)
    ivory = kit.mat("defenses", "#FFF4DC", rough=0.2)
    chrome = kit.chrome("chrome")
    frost = kit.gem("givre", "#5A9AC8", "#C8EEFF", "#FFFFFF")

    # --- gros corps plissé ---
    kit.add(kit.brick((0.76, 0.9, 0.5), center=(0, 0.08, 0.3)), brown, bevel=0.09)
    kit.add(kit.brick((0.64, 0.6, 0.2), center=(0, -0.04, 0.62)), brown, bevel=0.06)
    for k in range(3):
        kit.add(kit.box((0.78, 0.03, 0.03), center=(0, -0.1 + k * 0.2, 0.56 - k * 0.04)), fold, bevel=0.0)

    # --- tête : moustache givrée, défenses, monocle ---
    kit.add(kit.brick((0.52, 0.44, 0.4), center=(0, -0.4, 0.66)), brown, "Head", bevel=0.07)
    kit.add(kit.brick((0.44, 0.16, 0.2), center=(0, -0.62, 0.56)), light, "Head", bevel=0.05)
    for k in range(9):
        x = (k - 4) * 0.05
        kit.add(kit.wedge((0.05, 0.06, 0.14), center=(x, -0.7, 0.46), rot=(180, 0, 0), tip=0.3), white, "Head", bevel=0.0)
    for x in (-0.14, -0.03, 0.08, 0.17):
        kit.add(kit.brick((0.03, 0.03, 0.03), center=(x, -0.73, 0.5), rot=(45, 45, 0)), frost, "Head", bevel=0.004)
    for s in (-1, 1):
        kit.add(kit.brick((0.07, 0.07, 0.36), center=(s * 0.13, -0.66, 0.26), rot=(-8, 0, 0)), ivory, "Head", bevel=0.02)
        kit.add(kit.brick((0.08, 0.08, 0.03), center=(s * 0.13, -0.65, 0.42)), chrome, "Head", bevel=0.008)
        kit.add(kit.wedge((0.07, 0.07, 0.1), center=(s * 0.13, -0.67, 0.04), rot=(180, 0, 0), tip=0.2), ivory, "Head",
                bevel=0.0)
        kit.add(kit.brick((0.12, 0.05, 0.05), center=(s * 0.11, -0.6, 0.82), rot=(0, s * 15, 0)), white, "Head", bevel=0.015)
    P.eyes(kit, "Head", x=0.11, y=-0.62, z=0.74, size=0.07, iris="#2A1A0E", pupil="round", lid=brown, lid_drop=0.25,
           tall=1.0)
    kit.add(kit.disc(0.055, 0.02, center=(0.11, -0.64, 0.74), normal=(0, -1, 0), sides=12), chrome, "Head", bevel=0.0)
    kit.add(kit.box((0.01, 0.01, 0.16), center=(0.16, -0.64, 0.65), rot=(0, 20, 0)), chrome, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.24, 0.52))

    # --- nageoires avant, queue en éventail ---
    for s, part in ((1, "FinL"), (-1, "FinR")):
        kit.add(kit.slope((0.32, 0.26, 0.06), center=(s * 0.46, -0.24, 0.05), facing="+X" if s > 0 else "-X", top=0.4,
                          rot=(0, s * 10, 0)), fold, part, bevel=0.015)
        kit.part(part, "Fin", pivot=(s * 0.34, -0.24, 0.1), phase=float(s))
    for s in (-1, 1):
        kit.add(kit.slope((0.3, 0.24, 0.05), center=(s * 0.16, 0.66, 0.04), facing="+X" if s > 0 else "-X", top=0.4,
                          rot=(0, 0, s * -20)), fold, "Tail", bevel=0.012)
    kit.part("Tail", "Tail", pivot=(0, 0.5, 0.1))
    return kit.result()

