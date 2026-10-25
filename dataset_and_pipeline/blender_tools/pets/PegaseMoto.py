"""Pégase-Moto (Légendaire, Hybrides) : « Cheval robot crachant de la fumée. »

En briques LEGO, très détaillé : cheval-robot de moto en métal gris anthracite et orange vif : carénage avec phare,
réservoir orange flammé sur le dos, selle noire, guidon chromé ; tête de cheval mécanique à visière orange LUMINEUSE
et naseaux à grille, crinière en ailettes orange ; deux pots d'échappement chromés dans le dos (la fumée sort de là) ;
pattes à vérins chromés et sabots-roues noirs ; petites ailes en ailerons ; queue en câbles. Parties animées : tête,
4 pattes, ailes, queue.
"""

import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    grey = kit.mat("anthracite", "#5A606E", metal=0.6, rough=0.3)
    dark = kit.mat("noir", "#24262E", metal=0.5, rough=0.3)
    orange = kit.mat("orange", "#FF6A12", rough=0.18)
    yellow = kit.mat("flammes", "#FFD21E", rough=0.2)
    chrome = kit.mat("chrome", "#E2E8F2", metal=0.95, rough=0.1)
    seat = kit.mat("selle", "#2A1E1A", rough=0.5)
    visor = kit.mat("visiere", "#FF8A1E", rough=0.1, glow=2.6)
    lamp = kit.mat("phare", "#FFF6C8", rough=0.05, glow=2.4)
    tire = kit.mat("pneu", "#16161A", rough=0.6)

    # --- torse de cheval-moto : carénage, réservoir flammé, selle, guidon ---
    P.quad_torso(kit, L=0.96, W=0.44, H=0.34, z=0.86, y0=0.04, main=grey, belly=dark, chest=grey, back=grey)
    kit.add(kit.brick((0.4, 0.36, 0.18), center=(0, -0.12, 1.1)), orange, bevel=0.05)
    for s in (-1, 1):
        kit.add(kit.wedge((0.02, 0.2, 0.12), center=(s * 0.205, -0.12, 1.08), rot=(0, 0, 90), tip=0.2), yellow, bevel=0.0)
    kit.add(kit.brick((0.32, 0.3, 0.08), center=(0, 0.22, 1.1)), seat, bevel=0.03)
    kit.add(kit.brick((0.5, 0.04, 0.04), center=(0, -0.3, 1.22)), chrome, bevel=0.008)
    kit.add(kit.brick((0.04, 0.04, 0.12), center=(0, -0.3, 1.16)), chrome, bevel=0.008)
    kit.add(kit.brick((0.3, 0.3, 0.42), center=(0, -0.44, 1.12), rot=(28, 0, 0)), grey, bevel=0.04)
    kit.add(kit.brick((0.18, 0.04, 0.14), center=(0, -0.6, 0.98), rot=(28, 0, 0)), lamp, bevel=0.02)
    # pots d'échappement chromés
    for s in (-1, 1):
        kit.add(kit.brick((0.1, 0.42, 0.1), center=(s * 0.27, 0.28, 0.98), rot=(-12, 0, 0)), chrome, bevel=0.025)
        kit.add(kit.brick((0.12, 0.06, 0.12), center=(s * 0.27, 0.5, 1.02)), dark, bevel=0.015)

    # --- tête mécanique : visière lumineuse, naseaux à grille, crinière en ailettes ---
    kit.add(kit.brick((0.34, 0.42, 0.3), center=(0, -0.62, 1.38)), grey, "Head", bevel=0.035)
    kit.add(kit.brick((0.26, 0.26, 0.2), center=(0, -0.9, 1.28)), dark, "Head", bevel=0.03)
    for k in range(3):
        kit.add(kit.box((0.2, 0.02, 0.02), center=(0, -1.035, 1.24 + k * 0.04)), chrome, "Head", bevel=0.0)
    kit.add(kit.brick((0.36, 0.06, 0.08), center=(0, -0.8, 1.44)), visor, "Head", bevel=0.012)
    for s in (-1, 1):
        P.ear(kit, "Head", s, (s * 0.12, -0.52, 1.52), w=0.1, h=0.16, color=grey, inner=orange, tilt=(-8, 10))
    for k in range(5):
        P.tuft_piece(kit, "Head" if k < 2 else "Body", (0, -0.5 + k * 0.12, 1.54 - k * 0.12), (0, 0.6, 0.6), 0.16, 0.08,
                     orange)
    kit.part("Head", "Head", pivot=(0, -0.5, 1.22))

    # --- pattes à vérins chromés, sabots-roues ---
    P.quad_legs(kit, grey, yf=-0.32, yb=0.38, top_f=0.9, top_b=0.94, length_f=0.86, length_b=0.9, w=0.12, paw=tire,
                toe=tire, x=0.15, toes=1)
    for part, x, y in (("LegFL", 0.15, -0.32), ("LegFR", -0.15, -0.32), ("LegBL", 0.15, 0.38), ("LegBR", -0.15, 0.38)):
        kit.add(kit.box((0.04, 0.04, 0.4), center=(x * 1.45, y - 0.04, 0.5)), chrome, part, bevel=0.006)
        kit.add(kit.disc(0.06, 0.03, center=(x * 1.5, y, 0.07), normal=(1 if x > 0 else -1, 0, 0), sides=8), chrome, part,
                bevel=0.0)

    # --- ailes en ailerons, queue en câbles ---
    P.spread_wings(kit, x=0.2, y=-0.1, z=1.0, span=0.5, height=0.3, mats=(grey, orange, chrome), style="feather",
                   sweep=35, lift=12)
    P.chain(kit, "Tail", [(0, 0.5, 0.96), (0, 0.62, 0.84), (0, 0.68, 0.68), (0, 0.66, 0.54)], 0.05, [dark, orange])
    P.chain(kit, "Tail", [(0.05, 0.5, 0.96), (0.07, 0.6, 0.86), (0.09, 0.64, 0.72)], 0.035, [chrome])
    kit.part("Tail", "Tail", pivot=(0, 0.48, 0.96))
    return kit.result()
