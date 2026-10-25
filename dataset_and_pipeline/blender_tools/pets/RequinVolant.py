"""Requin Volant (Mythique, Animaux) : « Grand requin blanc qui lévite, entouré de bulles. »

En briques LEGO : long corps gris-bleu fait de briques qui s'affinent vers la queue, ventre blanc, museau en pente,
grande gueule avec une rangée de dents blanches en coins, petits yeux noirs, ouïes en tuiles, aileron dorsal en coin,
nageoires pectorales en pentes, grande nageoire caudale en deux coins. Il flotte (le jeu le fait léviter).
Parties animées : nageoire caudale (« SwimTail », elle bat), nageoires pectorales (« Fin »).
"""

from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    blue = kit.mat("gris_bleu", "#8E9EB0")
    top = kit.mat("dos", "#6F8196")
    white = kit.mat("ventre", "#F2F4F6")
    teeth = kit.mat("dents", "#FFFFFF", rough=0.15)
    mouth = kit.mat("gueule", "#3A1C22")
    black = kit.mat("oeil", "#101114", rough=0.1)
    gill = kit.mat("ouies", "#5B6A7C")

    # --- corps : briques qui s'affinent vers l'arrière, dos plus foncé, ventre blanc ---
    kit.add(kit.brick((0.56, 0.7, 0.44), center=(0, -0.2, 0.5)), blue, bevel=0.04)
    kit.add(kit.brick((0.48, 0.42, 0.36), center=(0, 0.34, 0.52)), blue, bevel=0.035)
    kit.add(kit.brick((0.34, 0.3, 0.26), center=(0, 0.68, 0.54)), blue, bevel=0.03)
    kit.add(kit.brick((0.5, 0.94, 0.08), center=(0, 0.02, 0.76)), top, bevel=0.02)
    kit.add(kit.brick((0.46, 1.0, 0.08), center=(0, 0.04, 0.27)), white, bevel=0.02)
    # museau en pente, gueule, dents, yeux, ouïes
    kit.add(kit.slope((0.52, 0.3, 0.3), center=(0, -0.68, 0.6), facing="-Y", top=0.25), blue, bevel=0.025)
    kit.add(kit.brick((0.5, 0.26, 0.12), center=(0, -0.66, 0.38)), white, bevel=0.02)
    kit.add(kit.brick((0.42, 0.06, 0.07), center=(0, -0.8, 0.46)), mouth, bevel=0.008)
    for k in range(7):
        x = (k - 3) * 0.058
        kit.add(kit.wedge((0.045, 0.03, 0.06), center=(x, -0.82, 0.48), rot=(180, 0, 0), tip=0.15), teeth, bevel=0.0)
    for s in (-1, 1):
        kit.add(kit.box((0.03, 0.08, 0.08), center=(s * 0.28, -0.58, 0.6)), black, bevel=0.008)
        for k in range(3):
            kit.add(kit.box((0.025, 0.03, 0.2), center=(s * 0.285, -0.38 + k * 0.08, 0.5)), gill, bevel=0.004)
    kit.add(kit.wedge((0.08, 0.34, 0.36), center=(0, 0.0, 0.96), rot=(0, 0, 0), tip=0.15), top, bevel=0.012)

    # --- nageoires pectorales (Fin) ---
    for s, part in ((1, "FinL"), (-1, "FinR")):
        kit.add(kit.slope((0.3, 0.2, 0.06), center=(s * 0.4, -0.24, 0.34), facing="+X" if s > 0 else "-X", top=0.3,
                          rot=(0, s * 18, 0)), top, part, bevel=0.012)
        kit.part(part, "Fin", pivot=(s * 0.26, -0.24, 0.38), phase=float(s))
    # --- nageoire caudale en deux coins (SwimTail) ---
    kit.add(kit.brick((0.2, 0.22, 0.18), center=(0, 0.92, 0.55)), blue, "Tail", bevel=0.02)
    kit.add(kit.wedge((0.08, 0.3, 0.42), center=(0, 1.1, 0.78), rot=(-30, 0, 0), tip=0.15), top, "Tail", bevel=0.012)
    kit.add(kit.wedge((0.08, 0.22, 0.26), center=(0, 1.08, 0.34), rot=(210, 0, 0), tip=0.15), top, "Tail", bevel=0.012)
    kit.part("Tail", "SwimTail", pivot=(0, 0.82, 0.55))
    return kit.result()
