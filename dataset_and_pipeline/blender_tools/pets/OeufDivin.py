"""Œuf Divin (couveuse) : œuf blanc céleste cerclé d'or blanc, cristaux bleu ciel et petites ailes. Or blanc et
cristal, sans lueur.

Coquille en briques octogonales (base _egg), étages blanc et bleu pâle, couture et anneaux en or blanc, un cristal bleu
ciel sur chaque face du ventre, petites ailes de plumes sur les côtés, pointe en cristal.
"""

import _egg as E
import _parts as P
from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    white = kit.enamel("coquille", "#F6F8FF")
    pale = kit.enamel("coquille_bleutee", "#D8E8FF")
    whitegold = kit.chrome("or_blanc", tint="#F6F0E0", rough=0.16)
    sky = kit.gem("cristal_ciel", "#1E5A9A", "#7AC8FF", "#F0FAFF")
    feather = kit.enamel("plumes", "#FFFFFF")

    E.shell(kit, [white, pale, white, pale, white, pale, white, whitegold], seam=whitegold,
            stripes={1: whitegold, 5: whitegold})
    E.on_faces(kit, 3, E.diamond(kit), sky, "Middle", n=8, dz=0.03, depth=0.06, size=(0.14, 0.14))
    E.on_faces(kit, 4, E.diamond(kit), sky, "Upper", n=4, start=45, depth=0.05, size=(0.09, 0.09))
    # petites ailes de plumes sur les côtés
    P.spread_wings(kit, x=0.52, y=0.08, z=0.98, span=0.72, height=0.52, mats=(feather, pale, whitegold), style="feather",
                   sweep=25, lift=32, parts=("Middle", "Middle"))
    kit.add(kit.cylinder(0.07, 0.24, center=(0, 0, 1.92), rot=(0, 0, 22.5), sides=8, top=0.0), sky, "Top", bevel=0.0)
    return kit.result()
