"""Œuf Mythique (couveuse) : œuf de nacre rosée, filigrane d'or et gemmes roses. Nacre et or, sans lueur.

Coquille en briques octogonales (base _egg), étages en nacre rosée et nacre blanche, couture et anneaux d'or, une gemme
rose sertie d'or sur quatre faces, perles d'or au-dessus, pointe : gemme rose dans une coupelle d'or.
"""

import _egg as E
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    pearl = kit.pearl("nacre", color="#F8E6F0", sheen="#CFE8FF")
    pearl2 = kit.pearl("nacre_blanche", color="#FBF6F8", sheen="#FFD8EC")
    gold = kit.gold("or", hammered=0.25)
    pink = kit.gem("gemme_rose", "#8A0A3A", "#FF5AA0", "#FFE0EE")

    E.shell(kit, [pearl, pearl2, pearl, pearl2, pearl, pearl2, pearl, gold], seam=gold, stripes={1: gold, 5: gold})
    E.on_faces(kit, 3, E.diamond(kit), gold, "Middle", n=4, dz=0.02, depth=0.03, size=(0.24, 0.24))
    E.on_faces(kit, 3, E.diamond(kit), pink, "Middle", n=4, dz=0.02, depth=0.06, size=(0.16, 0.16))
    E.on_faces(kit, 3, E.plate(kit), gold, "Middle", n=4, start=45, dz=0.02, depth=0.04, size=(0.05, 0.05))
    E.on_faces(kit, 4, E.plate(kit), gold, "Upper", n=8, dz=0.0, depth=0.04, size=(0.05, 0.05))
    kit.add(E.octo(kit, 0.12, 0.05, 1.82), gold, "Top", bevel=0.012)
    kit.add(kit.brick((0.1, 0.1, 0.1), center=(0, 0, 1.89), rot=(45, 0, 45)), pink, "Top", bevel=0.012)
    return kit.result()
