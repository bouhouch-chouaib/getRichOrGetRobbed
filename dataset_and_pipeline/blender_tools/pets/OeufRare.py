"""Œuf Rare (couveuse) : œuf bleu roi en émail, rayures et étoile blanches. Émail, sans lueur.

Coquille en briques octogonales (base _egg), étages bleu et bleu profond, deux bandes blanches, couture blanche,
grande étoile blanche devant et derrière, petites gouttes blanches sur les côtés, pointe blanche.
"""

import _egg as E
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    blue = kit.enamel("coquille", "#2E7CFF")
    deep = kit.enamel("coquille_fonce", "#1E58C8")
    white = kit.enamel("blanc", "#F6F8FF")

    E.shell(kit, [blue, deep, blue, deep, blue, deep, blue, white], seam=white, stripes={1: white, 5: white})
    # étoile à 8 branches devant et derrière (deux carrés d'épaisseurs différentes : pas de faces confondues)
    z = E.LAYERS[3][0] + 0.02
    for side in (1, -1):
        y = side * (E.LAYERS[3][1] * E.FACE)
        kit.add(kit.brick((0.24, 0.04, 0.24), center=(0, y - side * 0.0, z)), white, "Middle", bevel=0.012)
        kit.add(kit.brick((0.24, 0.055, 0.24), center=(0, y, z), rot=(0, 45, 0)), white, "Middle", bevel=0.012)
    # gouttes sur les côtés
    E.on_faces(kit, 3, E.diamond(kit), white, "Middle", n=4, start=45, dz=0.0, size=(0.1, 0.1))
    E.on_faces(kit, 4, E.diamond(kit), white, "Upper", n=4, start=0, dz=0.0, size=(0.08, 0.08))
    return kit.result()
