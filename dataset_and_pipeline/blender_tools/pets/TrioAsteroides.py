"""Le Trio d'Astéroïdes (Légendaire, Absurdes) : « Trois cailloux grognons qui voyagent toujours ensemble. »

En briques LEGO, très détaillé (Légendaire : filons d'or martelé et cristaux orange, aucune lueur) : un gros astéroïde
grognon au centre et deux plus petits qui tournent autour de lui ; roche brun-gris en blocs irréguliers, cratères,
filons d'OR qui affleurent, cristaux orange ; chacun a sa tête de mauvais poil (sourcils froncés, bouche tordue,
l'un avec une moustache de cailloux). Ils flottent. Parties animées : les deux petits (tournent autour du gros).
"""

import _parts as P
from pet_kit import PetKit


def _rock(kit, part, cx, cy, cz, k, mats, face=True, phase=0.0):
    rock, dark, light, gold, gem = mats
    kit.add(kit.brick((0.5 * k, 0.46 * k, 0.44 * k), center=(cx, cy, cz)), rock, part, bevel=0.06 * k)
    kit.add(kit.brick((0.4 * k, 0.5 * k, 0.36 * k), center=(cx + 0.04 * k, cy, cz + 0.06 * k), rot=(8, 12, 20)), rock, part,
            bevel=0.05 * k)
    kit.add(kit.brick((0.3 * k, 0.3 * k, 0.16 * k), center=(cx - 0.06 * k, cy + 0.04 * k, cz + 0.24 * k), rot=(0, 0, 30)),
            light, part, bevel=0.04 * k)
    kit.add(kit.brick((0.22 * k, 0.24 * k, 0.14 * k), center=(cx + 0.16 * k, cy + 0.06 * k, cz - 0.22 * k)), dark, part,
            bevel=0.03 * k)
    # filons d'or, cristal orange, cratère
    kit.add(kit.box((0.04 * k, 0.03, 0.24 * k), center=(cx + 0.18 * k, cy - 0.235 * k, cz + 0.02 * k), rot=(0, 30, 0)), gold,
            part, bevel=0.0)
    kit.add(kit.box((0.18 * k, 0.03, 0.04 * k), center=(cx - 0.12 * k, cy - 0.235 * k, cz - 0.15 * k), rot=(0, -10, 0)), gold,
            part, bevel=0.0)
    kit.add(kit.brick((0.08 * k, 0.08 * k, 0.14 * k), center=(cx - 0.2 * k, cy + 0.12 * k, cz + 0.26 * k), rot=(20, 15, 0)),
            gem, part, bevel=0.01)
    kit.add(kit.disc(0.07 * k, 0.03, center=(cx + 0.26 * k, cy + 0.1 * k, cz + 0.08 * k), normal=(1, 0, 0), sides=8), dark,
            part, bevel=0.0)
    if face:
        P.eyes(kit, part, x=0.09 * k, y=cy - 0.24 * k, z=cz + 0.06 * k, size=0.1 * k, iris="#2A1A0E", pupil="round",
               lid=dark, lid_drop=0.25, brow=dark, brow_angle=26, tall=0.9, at=cx)
        for j, (dx, dz) in enumerate(((-0.05, -0.1), (0.0, -0.09), (0.05, -0.11))):
            kit.add(kit.box((0.05 * k, 0.02, 0.015), center=(cx + dx * k, cy - 0.241 * k, cz + dz * k),
                            rot=(0, 25 if j % 2 else -25, 0)), dark, part, bevel=0.0)


def build(name: str) -> dict:
    kit = PetKit(name)
    mats = (kit.mat("roche", "#8A7A6E"), kit.mat("roche_fonce", "#5E5248"), kit.mat("roche_claire", "#B0A294"),
            kit.gold("filon"), kit.gem("cristal", "#5A1E0A", "#FF8A2A", "#FFE0C0"))

    # --- le gros grognon au centre, avec sa moustache de cailloux ---
    _rock(kit, "Body", 0.0, 0.0, 0.62, 1.2, mats)
    for s in (-1, 1):
        kit.add(kit.brick((0.12, 0.06, 0.05), center=(s * 0.08, -0.3, 0.6), rot=(0, s * 20, 0)), mats[1], bevel=0.015)

    # --- les deux petits qui tournent autour ---
    _rock(kit, "Moons", 0.62, -0.1, 0.9, 0.62, mats)
    _rock(kit, "Moons", -0.6, 0.12, 0.36, 0.55, mats)
    kit.part("Moons", "Orbit", pivot=(0, 0, 0.62), rot=(8, 0, 0), phase=0.5)
    return kit.result()

