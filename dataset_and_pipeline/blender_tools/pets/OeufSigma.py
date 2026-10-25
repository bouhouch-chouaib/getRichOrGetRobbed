"""Œuf Sigma (couveuse) : œuf en or massif, ceinture bleu nuit sertie de gemmes, couronne d'or. Or massif, sans lueur.

Coquille en briques octogonales (base _egg), étages en or massif et or foncé, couture et bande bleu nuit, une gemme
rubis ou saphir sertie d'or sur chaque face du ventre, couronne de pointes d'or et gemme sur la pointe.
"""

import math

import _egg as E
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    gold = kit.gold("or_massif", hammered=0.45)
    deep = kit.gold("or_fonce", tint="#E0A010", hammered=0.5)
    navy = kit.enamel("bleu_nuit", "#1A1E4A")
    ruby = kit.gem("rubis", "#5A0A14", "#FF3A4A", "#FFE0E0")
    sapphire = kit.gem("saphir", "#0A1E5A", "#3A8AFF", "#E0F0FF")

    E.shell(kit, [gold, deep, gold, deep, gold, deep, gold, gold], seam=navy, stripes={4: navy})
    E.on_faces(kit, 3, E.plate(kit), navy, "Middle", n=8, dz=0.02, depth=0.03, size=(0.2, 0.2))
    z, r, _h = E.LAYERS[3]
    d = r * E.FACE + 0.035
    for k in range(8):
        a = math.radians(45 * k)
        kit.add(kit.brick((0.12, 0.06, 0.12), center=(math.sin(a) * d, -math.cos(a) * d, z + 0.02), rot=(0, 45, 45 * k)),
                ruby if k % 2 == 0 else sapphire, "Middle", bevel=0.01)
    # couronne de pointes d'or autour de l'étage 7, gemme au sommet
    zc, rc, hc = E.LAYERS[6]
    for k in range(8):
        a = math.radians(45 * k + 22.5)
        x, y = math.sin(a) * rc * 0.95, -math.cos(a) * rc * 0.95
        kit.add(kit.wedge((0.07, 0.07, 0.2), center=(x, y, zc + hc / 2 + 0.08), tip=0.1), gold, "Top", bevel=0.0)
    kit.add(kit.brick((0.12, 0.12, 0.12), center=(0, 0, 1.9), rot=(45, 0, 45)), ruby, "Top", bevel=0.012)
    return kit.result()
