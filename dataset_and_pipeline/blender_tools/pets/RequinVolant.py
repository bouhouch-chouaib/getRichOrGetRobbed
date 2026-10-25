"""Requin Volant (Mythique, Animaux) : « Grand requin blanc qui lévite, entouré de bulles. »

En briques LEGO, très détaillé : long corps bleu océan qui s'affine en étages vers la queue, ventre blanc qui remonte
sur les flancs, museau en pentes à narines, grande gueule rose à deux rangées de dents blanches, petits yeux noirs
brillants, cinq ouïes, aileron dorsal en coin avec un petit aileron arrière, nageoires pectorales et pelviennes,
grande nageoire caudale en deux lobes, une cicatrice de vieux loup de mer. Il lévite (le jeu le fait flotter).
Parties animées : nageoire caudale (« SwimTail »), nageoires pectorales (« Fin »).
"""

from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    blue = kit.mat("bleu", "#5E92D8")
    top = kit.mat("dos", "#3E6AB0")
    white = kit.mat("ventre", "#F6F8FC")
    gum = kit.mat("gencive", "#FF6A8E")
    mouth = kit.mat("gueule", "#7A1E36")
    teeth = kit.mat("dents", "#FFFFFF", rough=0.12)
    black = kit.mat("oeil", "#0C0E14", rough=0.08)
    shine = kit.mat("reflet", "#FFFFFF", rough=0.05)
    gill = kit.mat("ouies", "#2E4F86")
    scar = kit.mat("cicatrice", "#D8E4F4")

    # --- corps en étages qui s'affinent, dos foncé, ventre blanc qui remonte ---
    kit.add(kit.brick((0.58, 0.62, 0.46), center=(0, -0.24, 0.52)), blue, bevel=0.045)
    kit.add(kit.brick((0.5, 0.42, 0.38), center=(0, 0.28, 0.54)), blue, bevel=0.04)
    kit.add(kit.brick((0.38, 0.3, 0.28), center=(0, 0.62, 0.56)), blue, bevel=0.035)
    kit.add(kit.brick((0.24, 0.22, 0.2), center=(0, 0.86, 0.57)), blue, bevel=0.03)
    kit.add(kit.brick((0.52, 1.0, 0.08), center=(0, 0.04, 0.78)), top, bevel=0.02)
    kit.add(kit.brick((0.48, 1.04, 0.1), center=(0, 0.02, 0.28)), white, bevel=0.025)
    for s in (-1, 1):
        kit.add(kit.box((0.03, 0.8, 0.08), center=(s * 0.29, 0.0, 0.36), rot=(-3, 0, 0)), white, bevel=0.006)
        kit.add(kit.box((0.025, 0.16, 0.025), center=(s * 0.295, -0.3, 0.64), rot=(30, 0, 0)), scar, bevel=0.0)
    # --- museau, gueule rose à deux rangées de dents, yeux, narines, ouïes ---
    kit.add(kit.slope((0.54, 0.3, 0.3), center=(0, -0.7, 0.62), facing="-Y", top=0.2), blue, bevel=0.025)
    kit.add(kit.brick((0.52, 0.28, 0.14), center=(0, -0.68, 0.38)), white, bevel=0.025)
    kit.add(kit.brick((0.44, 0.07, 0.11), center=(0, -0.82, 0.465)), gum, bevel=0.01)
    kit.add(kit.brick((0.38, 0.06, 0.06), center=(0, -0.835, 0.465)), mouth, bevel=0.006)
    for k in range(8):
        x = (k - 3.5) * 0.05
        kit.add(kit.wedge((0.04, 0.03, 0.055), center=(x, -0.86, 0.5), rot=(180, 0, 0), tip=0.15), teeth, bevel=0.0)
        if 0 < k < 7:
            kit.add(kit.wedge((0.035, 0.03, 0.045), center=(x, -0.86, 0.43), tip=0.15), teeth, bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.box((0.035, 0.09, 0.09), center=(s * 0.285, -0.6, 0.62)), black, bevel=0.01)
        kit.add(kit.box((0.01, 0.025, 0.025), center=(s * 0.305, -0.62, 0.645)), shine, bevel=0.0)
        kit.add(kit.box((0.04, 0.03, 0.015), center=(s * 0.12, -0.86, 0.66)), black, bevel=0.0)
        for k in range(5):
            kit.add(kit.box((0.022, 0.025, 0.2 - k * 0.012), center=(s * 0.295, -0.42 + k * 0.06, 0.52)), gill,
                    bevel=0.003)
        kit.add(kit.slope((0.18, 0.14, 0.05), center=(s * 0.22, 0.36, 0.26), facing=P_side(s), top=0.3,
                          rot=(0, s * -20, 0)), top, bevel=0.008)  # pelviennes
    kit.add(kit.wedge((0.09, 0.36, 0.38), center=(0, -0.04, 0.99), tip=0.15), top, bevel=0.012)
    kit.add(kit.wedge((0.06, 0.12, 0.14), center=(0, 0.66, 0.77), tip=0.15), top, bevel=0.008)

    # --- nageoires pectorales (Fin) ---
    for s, part in ((1, "FinL"), (-1, "FinR")):
        kit.add(kit.slope((0.34, 0.22, 0.06), center=(s * 0.42, -0.26, 0.34), facing=P_side(s), top=0.3,
                          rot=(0, s * 20, 0)), top, part, bevel=0.012)
        kit.part(part, "Fin", pivot=(s * 0.27, -0.26, 0.38), phase=float(s))
    # --- nageoire caudale en deux lobes (SwimTail) ---
    kit.add(kit.brick((0.16, 0.18, 0.16), center=(0, 1.02, 0.57)), blue, "Tail", bevel=0.02)
    kit.add(kit.wedge((0.08, 0.32, 0.46), center=(0, 1.18, 0.82), rot=(-32, 0, 0), tip=0.15), top, "Tail", bevel=0.012)
    kit.add(kit.wedge((0.08, 0.24, 0.28), center=(0, 1.16, 0.34), rot=(212, 0, 0), tip=0.15), top, "Tail", bevel=0.012)
    kit.part("Tail", "SwimTail", pivot=(0, 0.94, 0.57))
    return kit.result()


def P_side(s: int) -> str:
    return "+X" if s > 0 else "-X"
