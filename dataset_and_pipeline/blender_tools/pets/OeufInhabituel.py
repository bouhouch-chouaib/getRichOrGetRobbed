"""Œuf Inhabituel (couveuse) : œuf vert pomme rayé, une petite pousse sur le dessus. Plastique, sans lueur.

Coquille en briques octogonales (base _egg), étages vert et vert clair en alternance, couture vert sapin, losanges
vert clair tout autour du ventre, petite tige et deux feuilles sur la pointe.
"""

import _egg as E
import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    green = kit.mat("coquille", "#5EC44A")
    light = kit.mat("coquille_claire", "#9EE07A")
    dark = kit.mat("couture", "#2E8A34")
    leaf = kit.mat("feuilles", "#3CB43C")
    vein = kit.mat("nervures", "#1E7A28")
    stem = kit.mat("tige", "#6A9A2E")

    E.shell(kit, [green, light, green, light, green, light, green, dark], seam=dark)
    E.on_faces(kit, 3, E.diamond(kit), light, "Middle", n=8, dz=0.04, size=(0.13, 0.13))
    E.on_faces(kit, 1, E.diamond(kit), dark, "Bottom", n=4, start=45, size=(0.09, 0.09))
    E.on_faces(kit, 5, E.diamond(kit), dark, "Top", n=4, size=(0.08, 0.08))

    # petite pousse sur la pointe
    kit.add(kit.brick((0.06, 0.06, 0.16), center=(0, 0, 1.87)), stem, "Top", bevel=0.012)
    for s in (-1, 1):
        P.leaf(kit, "Top", (s * 0.02, 0, 1.93), (s * 1.0, 0.1, 0.55), 0.26, 0.13, leaf, vein=vein, droop=0.2)
    return kit.result()
