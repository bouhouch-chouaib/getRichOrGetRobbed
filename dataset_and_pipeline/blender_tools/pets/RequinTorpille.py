"""Requin-Torpille (Légendaire, Hybrides) : « Requin métallique à réacteur enflammé. »

En briques LEGO, très détaillé : requin-torpille en plaques d'acier brossé rivetées (dos gris foncé, ventre gris
clair), bandes rouge-orange et chevrons sur les flancs, yeux orange LUMINEUX derrière une visière, gueule à dents
d'acier, aileron dorsal et nageoires en tôle, et à l'arrière un RÉACTEUR (tuyère cerclée, flamme orange et jaune
LUMINEUSE qui crépite). Il fonce dans l'air. Parties animées : nageoires, queue, flamme.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    steel = kit.mat("acier", "#A8B0BE", metal=0.75, rough=0.28)
    dark = kit.mat("acier_fonce", "#5E6676", metal=0.75, rough=0.3)
    light = kit.mat("ventre", "#D8DEE8", metal=0.6, rough=0.25)
    red = kit.mat("bandes", "#FF4A1E", rough=0.2)
    rivet = kit.mat("rivets", "#3A404C", metal=0.8, rough=0.3)
    eye = kit.mat("yeux", "#FF8A1E", rough=0.1, glow=2.8)
    visor = kit.mat("visiere", "#2A2E38", rough=0.05)
    teeth = kit.mat("dents", "#EEF2F8", metal=0.8, rough=0.15)
    mouth = kit.mat("gueule", "#2A0E0E")
    flame = kit.mat("flamme", "#FF7A12", rough=0.2, glow=3.0)
    flame2 = kit.mat("flamme_jaune", "#FFE23A", rough=0.2, glow=3.2)

    # --- corps-torpille en étages, dos foncé, ventre clair, bandes et rivets ---
    kit.add(kit.brick((0.56, 0.6, 0.46), center=(0, -0.24, 0.52)), steel, bevel=0.04)
    kit.add(kit.brick((0.5, 0.44, 0.4), center=(0, 0.26, 0.53)), steel, bevel=0.04)
    kit.add(kit.brick((0.4, 0.3, 0.32), center=(0, 0.6, 0.54)), steel, bevel=0.035)
    kit.add(kit.brick((0.52, 1.0, 0.08), center=(0, 0.06, 0.77)), dark, bevel=0.02)
    kit.add(kit.brick((0.46, 0.98, 0.08), center=(0, 0.04, 0.3)), light, bevel=0.02)
    for s in (-1, 1):
        kit.add(kit.box((0.02, 0.7, 0.06), center=(s * 0.285, 0.05, 0.52)), red, bevel=0.0)
        for k in range(3):
            kit.add(kit.box((0.022, 0.06, 0.1), center=(s * 0.29, -0.32 + k * 0.08, 0.62), rot=(30, 0, 0)), red, bevel=0.0)
        for y in (-0.44, -0.1, 0.2, 0.5):
            kit.add(kit.box((0.025, 0.03, 0.03), center=(s * 0.29, y, 0.4)), rivet, bevel=0.0)

    # --- museau, visière, yeux, gueule à dents d'acier ---
    kit.add(kit.slope((0.52, 0.3, 0.3), center=(0, -0.7, 0.6), facing="-Y", top=0.2), steel, bevel=0.025)
    kit.add(kit.brick((0.5, 0.26, 0.14), center=(0, -0.68, 0.38)), light, bevel=0.025)
    kit.add(kit.brick((0.5, 0.05, 0.1), center=(0, -0.56, 0.66)), visor, bevel=0.012)
    for s in (-1, 1):
        kit.add(kit.box((0.12, 0.03, 0.05), center=(s * 0.13, -0.59, 0.66)), eye, bevel=0.006)
        # gros yeux lumineux sur les flancs, dans une monture rivetée
        kit.add(kit.box((0.03, 0.12, 0.12), center=(s * 0.28, -0.56, 0.6)), rivet, bevel=0.01)
        kit.add(kit.box((0.03, 0.08, 0.08), center=(s * 0.29, -0.57, 0.6)), eye, bevel=0.008)
    kit.add(kit.brick((0.42, 0.06, 0.08), center=(0, -0.82, 0.46)), mouth, bevel=0.008)
    for k in range(7):
        x = (k - 3) * 0.055
        kit.add(kit.wedge((0.04, 0.03, 0.05), center=(x, -0.85, 0.49), rot=(180, 0, 0), tip=0.15), teeth, bevel=0.0)
        kit.add(kit.wedge((0.035, 0.03, 0.04), center=(x, -0.85, 0.43), tip=0.15), teeth, bevel=0.0)
    kit.add(kit.wedge((0.08, 0.36, 0.36), center=(0, -0.02, 0.97), tip=0.15), dark, bevel=0.012)

    # --- nageoires en tôle ---
    for s, part in ((1, "FinL"), (-1, "FinR")):
        kit.add(kit.slope((0.34, 0.22, 0.06), center=(s * 0.42, -0.24, 0.36), facing="+X" if s > 0 else "-X", top=0.3,
                          rot=(0, s * 20, 0)), dark, part, bevel=0.012)
        kit.add(kit.box((0.2, 0.03, 0.02), center=(s * 0.42, -0.36, 0.38), rot=(0, s * 20, 0)), red, part, bevel=0.0)
        kit.part(part, "Fin", pivot=(s * 0.27, -0.24, 0.38), phase=float(s))

    # --- queue en tôle et réacteur ---
    kit.add(kit.brick((0.2, 0.18, 0.2), center=(0, 0.82, 0.55)), steel, "Tail", bevel=0.02)
    kit.add(kit.wedge((0.06, 0.26, 0.34), center=(0, 0.92, 0.78), rot=(-35, 0, 0), tip=0.15), dark, "Tail", bevel=0.01)
    kit.add(kit.wedge((0.06, 0.2, 0.24), center=(0, 0.9, 0.34), rot=(215, 0, 0), tip=0.15), dark, "Tail", bevel=0.01)
    kit.part("Tail", "SwimTail", pivot=(0, 0.72, 0.55))
    for s in (-1, 1):
        kit.add(kit.brick((0.16, 0.36, 0.16), center=(s * 0.3, 0.42, 0.62)), dark, bevel=0.03)
        kit.add(kit.brick((0.18, 0.05, 0.18), center=(s * 0.3, 0.62, 0.62)), red, bevel=0.012)
        kit.add(kit.brick((0.1, 0.03, 0.1), center=(s * 0.3, 0.645, 0.62)), mouth, bevel=0.0)
        for k, (length, mat) in enumerate(((0.3, flame), (0.2, flame2))):
            kit.add(kit.wedge((0.12 - k * 0.04, 0.12 - k * 0.04, length), center=(s * 0.3, 0.66 + length / 2, 0.62),
                              rot=(-90, 0, 0), tip=0.1), mat, f"Flame{0 if s > 0 else 1}", bevel=0.0)
        kit.part(f"Flame{0 if s > 0 else 1}", "Leaf", pivot=(s * 0.3, 0.65, 0.62), phase=1.0 + s)
    return kit.result()
