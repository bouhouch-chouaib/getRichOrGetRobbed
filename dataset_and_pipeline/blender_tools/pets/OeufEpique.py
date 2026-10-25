"""Œuf Épique (couveuse) : œuf violet en émail cerclé de chrome, serti de cristaux violets. Chrome et cristal, sans lueur.

Coquille en briques octogonales (base _egg), étages violet et violet clair, couture et deux anneaux chromés, une
gemme de cristal sur chaque face du ventre, petites gemmes au-dessus, pointe en cristal.
"""

import _egg as E
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    violet = kit.enamel("coquille", "#7A3AE6")
    light = kit.enamel("coquille_claire", "#9C66F2")
    chrome = kit.chrome("chrome")
    gem = kit.gem("cristal", "#2A0A5A", "#A06AFF", "#F0E0FF")

    E.shell(kit, [violet, light, violet, light, violet, light, chrome, chrome], seam=chrome,
            stripes={1: chrome, 5: chrome})
    E.on_faces(kit, 3, E.plate(kit), chrome, "Middle", n=8, dz=0.02, depth=0.03, size=(0.2, 0.2))
    E.on_faces(kit, 3, E.diamond(kit), gem, "Middle", n=8, dz=0.02, depth=0.06, size=(0.13, 0.13))
    E.on_faces(kit, 4, E.diamond(kit), gem, "Upper", n=4, start=45, depth=0.05, size=(0.09, 0.09))
    kit.add(kit.cylinder(0.08, 0.22, center=(0, 0, 1.9), rot=(0, 0, 22.5), sides=8, top=0.0), gem, "Top", bevel=0.0)
    return kit.result()
