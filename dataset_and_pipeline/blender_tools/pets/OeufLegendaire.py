"""Œuf Légendaire (couveuse) : œuf ambre cerclé d'or martelé, flammes d'or sur le ventre. Or martelé, sans lueur.

Coquille en briques octogonales (base _egg), étages ambre et orangé, couture et deux anneaux en or martelé, une flamme
d'or (trois pointes) sur quatre faces, rivets d'or au-dessus, pointe dorée.
"""

import math

import _egg as E
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    amber = kit.enamel("coquille", "#FF8C1A")
    light = kit.enamel("coquille_claire", "#FFB040")
    gold = kit.gold("or", hammered=0.4)
    flame = kit.gold("or_mat", tint="#FFC83A", hammered=0.2, rough=0.5)  # or mat : une flamme en or miroir sort sombre

    E.shell(kit, [amber, light, amber, light, amber, light, gold, gold], seam=gold, stripes={1: gold, 5: gold})
    # flammes d'or (trois pointes) devant, derrière et sur les côtés
    z0, r, _h = E.LAYERS[3]
    d = r * E.FACE + 0.02
    for k in range(4):
        a = math.radians(90 * k)
        x, y, yaw = math.sin(a) * d, -math.cos(a) * d, 90 * k
        for dx, h, w in ((-0.07, 0.16, 0.08), (0.0, 0.24, 0.1), (0.07, 0.16, 0.08)):
            cx, cy = x + math.cos(a) * dx, y + math.sin(a) * dx
            kit.add(kit.wedge((w, 0.04, h), center=(cx, cy, z0 - 0.02 + h / 2), rot=(0, 0, yaw), tip=0.1), flame, "Middle",
                    bevel=0.0)
        kit.add(kit.brick((0.24, 0.045, 0.05), center=(x, y, z0 - 0.06), rot=(0, 0, yaw)), gold, "Middle", bevel=0.01)
    E.on_faces(kit, 4, E.plate(kit), gold, "Upper", n=8, dz=0.0, depth=0.04, size=(0.06, 0.06))
    E.on_faces(kit, 2, E.plate(kit), gold, "Lower", n=8, dz=-0.03, depth=0.04, size=(0.06, 0.06))
    return kit.result()
