"""Œuf Commun (couveuse) : œuf crème tacheté de brun, simple et rassurant. Plastique, sans lueur.

Coquille en briques octogonales (base _egg), étages crème et crème clair, couture d'éclosion beige, taches brunes
éparpillées sur les faces, petite pointe brune.
"""

import _egg as E
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    cream = kit.mat("coquille", "#F4E6C6")
    cream2 = kit.mat("coquille_claire", "#FBF2DE")
    tan = kit.mat("couture", "#C8985C")
    spot = kit.mat("taches", "#9A6A3E")

    E.shell(kit, [cream, cream2, cream, cream2, cream, cream2, cream, tan], seam=tan)
    E.on_faces(kit, 1, E.plate(kit), spot, "Bottom", n=4, dz=0.02, start=45, size=(0.1, 0.08))
    E.on_faces(kit, 2, E.plate(kit), spot, "Lower", n=4, dz=-0.04, start=0, size=(0.13, 0.09))
    E.on_faces(kit, 3, E.plate(kit), spot, "Middle", n=4, dz=0.07, start=45, size=(0.15, 0.1))
    E.on_faces(kit, 4, E.plate(kit), spot, "Upper", n=4, dz=-0.04, start=0, size=(0.1, 0.08))
    E.on_faces(kit, 5, E.plate(kit), spot, "Top", n=4, dz=0.03, start=45, size=(0.08, 0.07))
    return kit.result()
