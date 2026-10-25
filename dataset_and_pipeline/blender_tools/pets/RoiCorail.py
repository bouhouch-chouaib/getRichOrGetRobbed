"""Le Roi Corail (Sigma, Abysses) : « Crabe royal couronné de corail, maître des abysses. »

En briques LEGO, très détaillé (Sigma : or massif et cristal, aucune lueur) : grand crabe rouge corail à carapace
large et bombée (plaques, rebord), yeux sur pédoncules au regard royal, moustache de barbillons, une couronne en OR
MASSIF d'où poussent des branches de corail en cristal rose et orange, cape de velours bleu roi bordée d'or sur le
dos, deux énormes pinces bordées d'or (une plus grosse), six pattes pointues. Il marche de côté comme un vrai crabe.
Parties animées : pinces, six pattes, yeux.
"""

import math

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    coral = kit.enamel("carapace", "#FF5A3A")
    deep = kit.enamel("carapace_fonce", "#C8321E")
    belly = kit.mat("ventre", "#FFD8B0")
    gold = kit.gold("or_massif", hammered=0.45)
    pink = kit.gem("corail_rose", "#8A1A3A", "#FF6AA0", "#FFE0EE")
    orange = kit.gem("corail_orange", "#8A3A0A", "#FF9A3A", "#FFE6C8")
    velvet = kit.enamel("cape", "#1E3ACB")

    # --- carapace large et bombée ---
    kit.add(kit.brick((0.86, 0.6, 0.22), center=(0, 0.04, 0.42)), coral, bevel=0.06)
    kit.add(kit.brick((0.72, 0.5, 0.14), center=(0, 0.06, 0.58)), coral, bevel=0.05)
    kit.add(kit.brick((0.5, 0.36, 0.08), center=(0, 0.08, 0.68)), deep, bevel=0.03)
    kit.add(kit.brick((0.9, 0.64, 0.04), center=(0, 0.04, 0.32)), deep, bevel=0.015)
    kit.add(kit.brick((0.6, 0.44, 0.08), center=(0, 0.04, 0.27)), belly, bevel=0.02)
    # cape de velours bordée d'or
    kit.add(kit.brick((0.56, 0.06, 0.34), center=(0, 0.36, 0.48)), velvet, bevel=0.02)
    kit.add(kit.box((0.58, 0.07, 0.04), center=(0, 0.36, 0.3)), gold, bevel=0.0)

    # --- visage : barbillons, bouche, yeux sur pédoncules ---
    P.mouth(kit, "Body", y=-0.27, z=0.38, w=0.14, smile=0.4)
    for s in (-1, 1):
        kit.add(kit.box((0.02, 0.12, 0.02), center=(s * 0.06, -0.32, 0.36), rot=(0, 0, s * 20)), deep, bevel=0.0)
        part = f"Eye{0 if s > 0 else 1}"
        kit.add(kit.box((0.04, 0.04, 0.16), center=(s * 0.13, -0.2, 0.74)), deep, part, bevel=0.008)
        kit.add(kit.brick((0.1, 0.1, 0.1), center=(s * 0.13, -0.22, 0.86)), kit.mat("blanc_oeil", "#FFFFFF"), part,
                bevel=0.025)
        kit.add(kit.brick((0.05, 0.03, 0.06), center=(s * 0.13, -0.275, 0.86)), kit.mat("pupille", "#14141A"), part,
                bevel=0.008)
        kit.part(part, "Ear", pivot=(s * 0.13, -0.2, 0.68), phase=float(s))

    # --- couronne d'or massif et branches de corail ---
    kit.add(kit.brick((0.36, 0.3, 0.08), center=(0, 0.06, 0.76)), gold, bevel=0.02)
    for k in range(5):
        x = (k - 2) * 0.08
        kit.add(kit.wedge((0.07, 0.06, 0.12), center=(x, -0.08, 0.86), tip=0.1), gold, bevel=0.0)
    for k, (x, mat) in enumerate(((-0.12, pink), (0.0, orange), (0.13, pink))):
        P.horn(kit, "Body", (x, 0.1, 0.8), (x * 2, 0.3, 1.0), 0.26, 0.05, [mat], segments=3, curl=0.4 * (1 if k % 2 else -1))
        P.tuft_piece(kit, "Body", (x, 0.12, 0.92), (x * 4 - 0.3, 0.2, 0.8), 0.1, 0.035, mat)

    # --- deux énormes pinces bordées d'or ---
    for s, part, k in ((1, "ArmL", 1.2), (-1, "ArmR", 0.9)):
        P.chain(kit, part, [(s * 0.4, -0.14, 0.42), (s * 0.54, -0.3, 0.48), (s * 0.56, -0.44, 0.5)], 0.1, [coral, deep])
        kit.add(kit.brick((0.22 * k, 0.24 * k, 0.16 * k), center=(s * 0.56, -0.56, 0.52)), coral, part, bevel=0.04)
        kit.add(kit.wedge((0.1 * k, 0.2 * k, 0.08 * k), center=(s * 0.6, -0.72, 0.56), rot=(90, 0, 0), tip=0.2), deep, part,
                bevel=0.0)
        kit.add(kit.wedge((0.08 * k, 0.16 * k, 0.06 * k), center=(s * 0.5, -0.7, 0.48), rot=(90, 0, 0), tip=0.2), deep, part,
                bevel=0.0)
        kit.add(kit.box((0.23 * k, 0.02, 0.17 * k), center=(s * 0.56, -0.56 - 0.12 * k, 0.52)), gold, part, bevel=0.0)
        kit.part(part, "Arm", pivot=(s * 0.4, -0.14, 0.42), phase=0.0 if s > 0 else math.pi)

    # --- six pattes pointues ---
    for k in range(3):
        for s in (-1, 1):
            part = f"Leg{k}{'L' if s > 0 else 'R'}"
            y = -0.08 + k * 0.16
            P.chain(kit, part, [(s * 0.42, y, 0.36), (s * 0.62, y + 0.02, 0.36), (s * 0.7, y + 0.04, 0.04)], 0.06,
                    [coral, deep])
            kit.part(part, "Leg", pivot=(s * 0.42, y, 0.36), phase=(k % 2) * math.pi + (0 if s > 0 else math.pi))
    return kit.result()
