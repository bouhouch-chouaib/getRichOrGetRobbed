"""Objets à jeter dans le trou noir (26 oct., Chouaib : « pour chaque monde, pas les mêmes objets ») : base commune.

Un fichier par monde (Objets_<Monde>.py) construit ses 6 objets, du plus courant au plus précieux (même ordre que
Config.ItemTiers), côte à côte dans une seule cuisson : une partie par objet (nommée comme l'objet), une seule
texture pour le monde. Le jeu range chaque pièce importée « Objets_<Monde>__<Objet> » dans
ArtModels.Items.<Monde>.<Objet> (tools/make_items_wire.py) et la clone pour chaque objet qui apparaît.

En studs (1 unité Blender = 1 stud), posé au sol (z = 0), 1,6 à 2,7 studs : ça tient dans la main et dans le sac.
Briques LEGO biseautées sans tenons, couleurs saturées, AUCUNE lueur ; la rareté se lit à la matière comme pour les
familiers : plastique (1-2) -> émail / chrome / cristal (3) -> or martelé (4) -> nacre + or (5) -> or massif + gemmes (6).
"""

import math

from mathutils import Matrix

import procedural_geometry_recipes as G
from pet_kit import rot_matrix

SLOT = 4.0  # écart entre deux objets dans la scène de cuisson
FACE = math.cos(math.radians(22.5))  # distance d'une face d'octogone = rayon des coins x FACE


def slot(index: int) -> float:
    """x du centre du i-ème objet (0 à 5)."""
    return (index - 2.5) * SLOT


def octo(kit, r, h, center, rot=(0, 0, 22.5), top=None, sides=8):
    """Brique octogonale verticale (une face vers -Y)."""
    return kit.cylinder(r, h, center=center, rot=rot, sides=sides, top=top)


def stack(kit, x, y, layers, part, z0=0.0, bevel=0.04):
    """Étages octogonaux empilés de bas en haut, layers = [(rayon, hauteur, matériau)] ; renvoie le z du haut."""
    z = z0
    for r, h, mat in layers:
        kit.add(octo(kit, r, h, (x, y, z + h / 2)), mat, part, bevel=min(bevel, h * 0.25))
        z += h
    return z


def ball(kit, center, r, mats, part, n=5, bevel=0.04, squash=1.0, power=0.8):
    """Boule en n étages octogonaux (rayon des coins r) ; mats = un matériau ou un par étage (bas en haut) ;
    power = 1 pour une vraie boule, moins pour un tonneau."""
    if not isinstance(mats, (list, tuple)):
        mats = [mats] * n
    x, y, z = center
    h = 2 * r * squash / n
    for k in range(n):
        t = -1 + (k + 0.5) * 2 / n
        rk = r * max(0.42, math.sqrt(max(0.0, 1 - t * t)) ** power)
        kit.add(octo(kit, rk, h, (x, y, z - r * squash + (k + 0.5) * h)), mats[k], part, bevel=min(bevel, h * 0.25))


def pearl(kit, center, r, mat, part):
    """Perle lisse (sphère ombrée en douceur) : en étages, une perle ressemble à une pile d'assiettes. Seule pièce
    vraiment ronde, comme les pupilles des familiers."""
    profile = [(r * math.sin(math.pi * k / 12), -r * math.cos(math.pi * k / 12)) for k in range(13)]
    obj = G.lathe(kit._id("Perle"), profile, segments=24)
    G.transform(obj, Matrix.Translation(center))
    kit.add(kit._smooth(obj), mat, part, bevel=0.0)


def face_point(x, y, r, angle, z, out=0.0):
    """Point sur la face d'un octogone (rayon des coins r) ; angle en degrés, 0 = avant (-Y), + vers +X."""
    d = r * FACE + out
    a = math.radians(angle)
    return (x + math.sin(a) * d, y - math.cos(a) * d, z)


def on_face(kit, x, y, r, angle, z, w, h, mat, part, thick=0.04, bevel=0.01):
    """Tuile plaquée sur la face d'un octogone (étiquette, reflet, goutte)."""
    c = face_point(x, y, r, angle, z, out=thick / 2 - 0.005)
    return kit.add(kit.box((w, thick, h), center=c, rot=(0, 0, angle)), mat, part, bevel=bevel)


def disc_on_face(kit, x, y, r, angle, z, radius, mat, part, thick=0.05, sides=8):
    """Pastille ronde (octogonale) plaquée sur la face d'un octogone."""
    a = math.radians(angle)
    c = face_point(x, y, r, angle, z, out=thick / 2 - 0.005)
    return kit.add(kit.disc(radius, thick, center=c, normal=(math.sin(a), -math.cos(a), 0), sides=sides), mat, part,
                   bevel=0.0)


def ring(kit, center, r, h, w, mat, part, n=8, bevel=0.02, rot=(0, 0, 0)):
    """Anneau en n briques (rayon r au milieu des briques, largeur w, hauteur h) dans le plan XY, tourné par rot
    (degrés, autour du centre) : couronne, bague, cerclage, anneau de planète."""
    m = rot_matrix(center, rot)
    side = 2 * (r + w / 2) * math.tan(math.pi / n)
    for k in range(n):
        a = 2 * math.pi * k / n
        brick = kit.box((w, side, h))
        G.transform(brick, m @ Matrix.Translation((math.cos(a) * r, math.sin(a) * r, 0)) @ Matrix.Rotation(a, 4, "Z"))
        kit.add(brick, mat, part, bevel=bevel)


def placed(obj, center, rot):
    """Tourne (degrés) puis pose une pièce construite autour de l'origine."""
    return G.transform(obj, rot_matrix(center, rot))
