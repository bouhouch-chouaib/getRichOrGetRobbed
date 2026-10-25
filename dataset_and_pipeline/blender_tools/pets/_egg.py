"""Œufs de la couveuse en briques (25 oct.) : la base commune des 8 œufs (un par rareté, fichiers Oeuf<Rareté>.py).

Coquille en 8 étages de briques octogonales (8 pans, une face vers l'avant), plus larges au milieu, pointe en haut ;
sans tenons, sans lueur. Les étages sont rangés en morceaux (parties) que le jeu fait éclater à l'éclosion :
Bottom / Lower sous la couture d'éclosion, Middle / Upper / Top au-dessus (attribut ShellHalf posé au branchement).
"""

import math

# (centre en z, rayon des coins, hauteur) de bas en haut ; les étages se touchent sans se chevaucher
LAYERS = [
    (0.09, 0.42, 0.18),
    (0.30, 0.60, 0.24),
    (0.56, 0.69, 0.28),
    (0.86, 0.67, 0.32),
    (1.17, 0.58, 0.30),
    (1.44, 0.44, 0.24),
    (1.64, 0.27, 0.16),
    (1.76, 0.14, 0.08),
]
PARTS = ["Bottom", "Bottom", "Lower", "Middle", "Upper", "Top", "Top", "Top"]
SEAM_Z = 0.70  # couture d'éclosion, entre l'étage 3 et l'étage 4
FACE = math.cos(math.radians(22.5))  # distance d'une face = rayon des coins x FACE


def octo(kit, radius, height, z, x=0.0, y=0.0):
    """Brique octogonale (8 pans, une face vers -Y)."""
    return kit.cylinder(radius, height, center=(x, y, z), rot=(0, 0, 22.5), sides=8)


def face_y(layer: int) -> float:
    """Face avant (-Y) d'un étage."""
    return -LAYERS[layer][1] * FACE


def shell(kit, mats, seam=None, stripes=None):
    """La coquille. mats = matériau de chaque étage (liste de 8, ou un seul) ; seam = ceinture de la couture
    d'éclosion ; stripes = {étage: matériau} pour une fine bande au milieu d'un étage (un peu plus large)."""
    if not isinstance(mats, (list, tuple)):
        mats = [mats] * len(LAYERS)
    for k, (z, r, h) in enumerate(LAYERS):
        kit.add(octo(kit, r, h, z), mats[k], PARTS[k], bevel=min(0.045, h * 0.25))
    if seam is not None:
        kit.add(octo(kit, 0.72, 0.07, SEAM_Z), seam, "Lower", bevel=0.018)
    for k, mat in (stripes or {}).items():
        z, r, h = LAYERS[k]
        kit.add(octo(kit, r + 0.025, h * 0.35, z), mat, PARTS[k], bevel=0.012)


def around(n, radius, z, start=0.0):
    """n points répartis sur les faces d'un étage (angles en degrés, 0 = devant)."""
    out = []
    for k in range(n):
        a = math.radians(start + 360.0 * k / n)
        out.append((math.sin(a) * radius, -math.cos(a) * radius, z, 360.0 * k / n + start))
    return out


def on_faces(kit, layer, piece, mat, part, n=8, dz=0.0, depth=0.03, start=0.0, size=(0.12, 0.12)):
    """Une pièce plate (gemme, tache, plaque) posée sur n faces d'un étage, tournée vers l'extérieur."""
    z, r, _h = LAYERS[layer]
    d = r * FACE + depth / 2 - 0.004
    for x, y, zz, yaw in around(n, d, z + dz, start=start):
        obj = piece(size, depth, (x, y, zz), yaw)
        kit.add(obj, mat, part, bevel=min(0.012, depth * 0.4))


def plate(kit):
    """Fabrique de plaque carrée pour on_faces."""
    def make(size, depth, center, yaw):
        return kit.brick((size[0], depth, size[1]), center=center, rot=(0, 0, yaw))
    return make


def diamond(kit):
    """Fabrique de losange (carré tourné de 45°) pour on_faces."""
    def make(size, depth, center, yaw):
        return kit.brick((size[0], depth, size[1]), center=center, rot=(0, 45, yaw))
    return make


__all__ = ["LAYERS", "PARTS", "SEAM_Z", "FACE", "octo", "face_y", "shell", "around", "on_faces", "plate", "diamond"]
