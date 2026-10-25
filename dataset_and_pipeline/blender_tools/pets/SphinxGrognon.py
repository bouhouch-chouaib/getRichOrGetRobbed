"""Sphinx Grognon (Mythique, Désert) : « Il pose des devinettes, mais ne donne jamais la réponse. »

En briques LEGO, très détaillé (Mythique : nacre et or, aucune lueur) : sphinx couché en pierre de sable dorée, coiffe
égyptienne (némès) à rayures OR et bleu lapis qui retombe sur les épaules, front orné d'un cobra en or, barbe
postiche tressée, visage de chat grognon (yeux mi-clos soulignés de khôl, sourcils froncés, moue), pattes avant
allongées, ventre et pattes en nacre ivoire, queue enroulée. Parties animées : tête, pattes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    stone = kit.mat("pierre", "#E8B85A")
    deep = kit.mat("pierre_fonce", "#C8903A")
    pearl = kit.pearl("ivoire", color="#FFF4E0", sheen="#E8F4FF")
    gold = kit.gold("or", hammered=0.35)
    lapis = kit.enamel("lapis", "#1E4ACB")
    kohl = kit.mat("khol", "#14141E")

    # --- corps couché, pattes avant allongées ---
    kit.add(kit.brick((0.6, 0.86, 0.3), center=(0, 0.1, 0.2)), stone, bevel=0.05)
    kit.add(kit.brick((0.5, 0.6, 0.12), center=(0, 0.16, 0.41)), deep, bevel=0.03)
    kit.add(kit.brick((0.5, 0.8, 0.05), center=(0, 0.08, 0.03)), pearl, bevel=0.015)
    for s, part in ((1, "LegFL"), (-1, "LegFR")):
        kit.add(kit.brick((0.16, 0.5, 0.14), center=(s * 0.17, -0.42, 0.08)), stone, part, bevel=0.035)
        kit.add(kit.brick((0.17, 0.12, 0.1), center=(s * 0.17, -0.68, 0.06)), pearl, part, bevel=0.025)
        kit.part(part, "Leg", pivot=(s * 0.17, -0.2, 0.12), phase=0.0 if s > 0 else 3.14)

    # --- tête de chat grognon sous le némès ---
    kit.add(kit.brick((0.4, 0.36, 0.36), center=(0, -0.24, 0.62)), stone, "Head", bevel=0.045)
    kit.add(kit.brick((0.22, 0.12, 0.12), center=(0, -0.45, 0.54)), pearl, "Head", bevel=0.025)
    P.nose(kit, "Head", y=-0.5, z=0.58, w=0.06, color="#8A4A2A")
    P.eyes(kit, "Head", x=0.1, y=-0.42, z=0.67, size=0.09, iris="#2A8A4A", pupil="slit", lid=deep, lid_drop=0.35,
           brow=kohl, brow_angle=24, tall=0.9)
    for s in (-1, 1):
        kit.add(kit.box((0.06, 0.02, 0.015), center=(s * 0.17, -0.425, 0.65), rot=(0, s * 20, 0)), kohl, "Head", bevel=0.0)
    kit.add(kit.box((0.1, 0.02, 0.02), center=(0, -0.512, 0.5), rot=(0, 0, 0)), kohl, "Head", bevel=0.0)
    # némès rayé or et lapis
    kit.add(kit.brick((0.5, 0.4, 0.12), center=(0, -0.2, 0.84)), gold, "Head", bevel=0.03)
    for k in (1, 3):
        kit.add(kit.box((0.52, 0.04, 0.125), center=(0, -0.34 + k * 0.07, 0.84)), lapis, "Head", bevel=0.0)
    for s in (-1, 1):
        for k in range(4):
            kit.add(kit.brick((0.1, 0.16, 0.08), center=(s * 0.26, -0.24, 0.72 - k * 0.09)), gold if k % 2 == 0 else lapis,
                    "Head", bevel=0.015)
    kit.add(kit.wedge((0.08, 0.06, 0.14), center=(0, -0.42, 0.94), tip=0.2), gold, "Head", bevel=0.0)
    for k in range(3):
        kit.add(kit.brick((0.08 - k * 0.01, 0.06, 0.06), center=(0, -0.48, 0.44 - k * 0.06)), gold if k % 2 == 0 else lapis,
                "Head", bevel=0.01)
    kit.part("Head", "Head", pivot=(0, -0.14, 0.48))

    # --- pattes arrière repliées, queue enroulée ---
    for s in (-1, 1):
        kit.add(kit.brick((0.14, 0.3, 0.2), center=(s * 0.3, 0.32, 0.12)), deep, bevel=0.035)
    P.chain(kit, "Tail", [(0, 0.54, 0.12), (0.16, 0.62, 0.08), (0.3, 0.56, 0.08), (0.34, 0.42, 0.1)], 0.07, [stone, deep])
    kit.add(kit.brick((0.1, 0.1, 0.1), center=(0.35, 0.38, 0.12)), gold, "Tail", bevel=0.02)
    kit.part("Tail", "Tail", pivot=(0, 0.52, 0.12))
    return kit.result()
