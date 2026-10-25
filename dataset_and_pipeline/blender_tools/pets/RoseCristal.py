"""Rose de Cristal (Épique, Plantes) : « Rose taillée dans un diamant bleu azur. »

En briques LEGO, très détaillée : pot de marbre blanc à bande dorée ; tige verte à épines, deux feuilles à nervures ;
rose de CRISTAL bleu azur brillant et un peu lumineux, trois rangs de pétales (bleu profond au cœur, azur, bleu
glacier au bord) en coupe tournée vers l'avant, sépales verts ; petit visage rêveur au cœur de la rose (yeux à longs
cils, sourire), éclats de cristal autour du pot. Parties animées : la rose (« Head », fière), les deux feuilles.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    marble = kit.mat("marbre", "#F6F6FC", rough=0.15)
    gold = kit.mat("or", "#FFC21E", metal=0.85, rough=0.2)
    soil = kit.mat("terreau", "#3A2414")
    stem = kit.mat("tige", "#2EA83E")
    thorn = kit.mat("epines", "#1E6A2A")
    leaf = kit.mat("feuille", "#34C24A")
    vein = kit.mat("nervure", "#B4F2A0")
    deep = kit.mat("cristal_fonce", "#1E6AF0", rough=0.03, glow=0.5)
    azure = kit.mat("cristal", "#46B4FF", rough=0.03, glow=0.6)
    ice = kit.mat("cristal_clair", "#A6E6FF", rough=0.03, glow=0.8)
    lash = kit.mat("cils", "#0E2A5A")

    # --- pot de marbre à bande dorée, éclats de cristal ---
    top = P.pot(kit, "Body", 0.0, 0.42, 0.3, marble, band=gold, soil=soil)
    for x, y, a in ((0.24, -0.16, 20), (-0.26, -0.1, -30), (0.2, 0.2, 60)):
        kit.add(kit.brick((0.05, 0.05, 0.12), center=(x, y, 0.06), rot=(15, a, 0)), azure, bevel=0.006)

    # --- tige à épines, feuilles ---
    P.chain(kit, "Body", [(0, 0, top), (0.02, 0.0, top + 0.26), (0, -0.02, top + 0.5)], 0.06, [stem])
    for x, z, d in ((0.03, top + 0.12, 1), (-0.03, top + 0.3, -1), (0.03, top + 0.42, 1)):
        P.tuft_piece(kit, "Body", (x, 0, z), (d, 0, 0.3), 0.05, 0.03, thorn)
    for s, part, z in ((1, "LeafL", top + 0.18), (-1, "LeafR", top + 0.34)):
        P.leaf(kit, part, (s * 0.03, 0, z), (s * 1.0, -0.2, 0.35), 0.26, 0.15, leaf, vein, normal=(0, -0.3, 1), droop=0.3)
        kit.part(part, "Leaf", pivot=(s * 0.03, 0, z), phase=0.8 if s > 0 else 2.2)

    # --- la rose de cristal en coupe tournée vers l'avant ---
    cz = top + 0.66
    facing = (0, -0.7, 0.72)
    for s in (-1, 1):
        P.tuft_piece(kit, "Head", (s * 0.04, 0.0, top + 0.5), (s * 0.8, 0.2, 0.5), 0.1, 0.05, stem)
    kit.add(kit.brick((0.2, 0.2, 0.2), center=(0, 0.0, cz - 0.04), rot=(-44, 0, 0)), deep, "Head", bevel=0.04)
    P.petals(kit, "Head", (0, 0.02, cz - 0.06), 6, 0.3, 0.2, [ice, azure], facing=facing, tilt=0.35, start=0.5)
    P.petals(kit, "Head", (0, 0.0, cz - 0.04), 5, 0.24, 0.17, [azure, ice], facing=facing, tilt=0.8)
    P.petals(kit, "Head", (0, -0.02, cz - 0.02), 4, 0.16, 0.13, [deep, azure], facing=facing, tilt=1.4, start=0.8)
    # petit visage rêveur au cœur
    fy, fz = -0.085, cz + 0.02
    for s in (-1, 1):
        kit.add(kit.box((0.05, 0.02, 0.02), center=(s * 0.045, fy, fz), rot=(-44, 0, 0)), lash, "Head", bevel=0.0)
        for k in range(2):
            kit.add(kit.box((0.01, 0.01, 0.03), center=(s * (0.06 + k * 0.012), fy - 0.002, fz + 0.02), rot=(-44, 0, s * 30)),
                    lash, "Head", bevel=0.0)
    kit.add(kit.box((0.05, 0.02, 0.014), center=(0, fy - 0.02, fz - 0.05), rot=(-44, 0, 0)), lash, "Head", bevel=0.0)
    kit.part("Head", "Head", pivot=(0, -0.02, top + 0.5))
    return kit.result()
