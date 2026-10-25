"""Décors du monde Divin (7e palier) — « Le Sanctuaire Céleste du Titan Auréole ». Même langage que les autres mondes :
blocs biseautés, tenons sur les faces du dessus du marbre taillé et de la mousse dorée.
Charte : map_art_bible_divin.json.

**Aucune lueur** (pas d'émission, aucun _Emissive.png à envoyer : avertissement de modération du 25 oct.). Les cristaux
de lumière sont une couleur blanc-or ; la lumière viendra de PointLight chaudes posées par le script Studio.

Importé par environment_recipes.catalog("Divin") : ajoute ses décors (préfixe « Divin_ ») à E.BUILDERS et sa liste
à E.WORLDS["Divin"]. Repère : pivot au sol au centre, devant = -Y, 1 unité = 1 stud.
"""

from __future__ import annotations

import math
import random

import bpy
from mathutils import Matrix, Vector

import environment_recipes as E
import procedural_geometry_recipes as G
import shader_node_library as S
from environment_desert import strut
from environment_recipes import assemble, bx, finish, hull, ring_sector

# =====================================================================================================================
# Matériaux
# =====================================================================================================================


def dm() -> dict[str, bpy.types.Material]:
    M = E.mats()
    if "marbre_a" in M and M["marbre_a"].name in bpy.data.materials:
        return M
    W = S.create_stylized_edge_wear_material
    C = S.create_stylized_crystal_or_gem
    # marbre : les fissures sont dorées (veines d'or), sans lueur
    stone = dict(brush_scale=0.22, grain_scale=3.0, edge_radius=0.18, cavity_distance=1.0, bump_strength=0.35,
                 crackle=0.3, crackle_scale=0.8, wear=0.6, roughness=0.55)
    plant = dict(brush_scale=0.35, grain_scale=4.0, edge_radius=0.14, cavity_distance=1.0, wear=0.85, roughness=0.55,
                 studs=1.0)
    small = dict(brush_scale=0.6, edge_radius=0.05)
    M.update({
        "marbre_a": W("M_MarbreA", base="#F4EEE0", edge="#FFFFFF", cavity="#C8A050", accent="#EAE2D0", **stone),
        "marbre_b": W("M_MarbreB", base="#EAE2CE", edge="#FFFDF6", cavity="#B8904A", accent="#E0D6C0", **stone),
        "marbre_c": W("M_MarbreC", base="#FAF6EC", edge="#FFFFFF", cavity="#CCA858", accent="#F0EADC", **stone),
        "marbre_taille": W("M_MarbreTaille", base="#F2E8D0", edge="#FFFFFF", cavity="#B89A5A", accent="#E8DEC4",
                           studs=1.0, **stone),
        # nuages : ombres bleu-gris (jamais grises sales), pas de tenons
        "nuage": W("M_Nuage", base="#FFFFFF", edge="#FFFFFF", cavity="#B8C8E6", wear=0.3, roughness=0.95,
                   brush_scale=0.5, edge_radius=0.3, cavity_distance=1.6),
        "mousse_doree": W("M_MousseDoree", base="#E8D27A", edge="#FFF4C0", cavity="#8A7230", **plant),
        "herbe_celeste": W("M_HerbeCeleste", base="#F0E2A0", edge="#FFF8D8", cavity="#9A8A4A", **plant),
        "ecorce_blanche": W("M_EcorceBlanche", base="#F2EAD8", edge="#FFFFFF", cavity="#A89878", wear=0.7,
                            roughness=0.6, brush_scale=0.4, grain_scale=5.0, edge_radius=0.12, cavity_distance=0.8,
                            wood=1.0, wood_axis="Z", wood_scale=0.9),
        "feuille_or": W("M_FeuilleOr", base="#FFD24A", edge="#FFF2B0", cavity="#A07A14", **plant),
        "feuille_blanche": W("M_FeuilleBlanche", base="#FFFBF0", edge="#FFFFFF", cavity="#C8BFA0", **plant),
        "laurier": W("M_Laurier", base="#7AB050", edge="#C8E8A0", cavity="#2E5A1E", **plant),
        "fil_or": W("M_FilOr", base="#FFF0B0", edge="#FFFFFF", cavity="#B89A40", wear=0.4, roughness=0.4, **small),
        "cristal_lumiere": C("M_CristalLumiere", core="#B07A10", mid="#FFE08A", rim="#FFFFF0", emission=0.0),
        "eau_celeste": C("M_EauCeleste", core="#2A6AA8", mid="#9AD8FF", rim="#F0FFFF", emission=0.0, veins=0.04),
    })
    return M


MARBLE = ("marbre_a", "marbre_b", "marbre_c", "marbre_a", "marbre_b")


def gem(obj: bpy.types.Object, seed: int = 0) -> bpy.types.Object:
    """Attributs du matériau cristal (dégradé pied -> pointe, teinte par facette) : sans eux le cristal sort sombre."""
    G.write_grad_attribute(obj, "height", offset=0.25, top=0.85)
    G.write_facet_attribute(obj, seed)
    return obj


def sun_disc(prefix: str, center, s: float, rays: int = 10):
    """Soleil d'or debout face à -Y : disque et rayons alternés longs / courts."""
    M = dm()
    c = Vector(center)
    disc = G.lathe(f"{prefix}_disque", [(0, 0), (1.0 * s, 0), (1.0 * s, 0.35 * s), (0, 0.45 * s)], segments=16)
    G.transform(disc, Matrix.Translation(c) @ Matrix.Rotation(math.radians(90), 4, "X"))
    out = [(disc, M["or"])]
    for k in range(rays):
        a = math.radians(90 + k * 360 / rays)
        length = (2.0 if k % 2 == 0 else 1.55) * s
        start = c + Vector((math.cos(a), 0, math.sin(a))) * 0.9 * s
        tip = c + Vector((math.cos(a), 0, math.sin(a))) * length
        out.append((strut(f"{prefix}_rayon{k}", start, tip, 0.45 * s, 0.25 * s, taper=(0.2, 0.8), roll_hint=(0, -1, 0)),
                    M["or"]))
    return out


def fluted_column(name: str, height: float, radius: float, at=(0, 0, 0), phase: float = 0.0):
    """Fût cannelé (lathe à facettes) : renvoie l'objet posé à `at`."""
    col = G.lathe(name, [(0, 0), (radius, 0), (radius * 0.88, height), (0, height)], segments=12, phase=phase)
    return G.transform(col, Matrix.Translation(at))


# =====================================================================================================================
# Nature céleste
# =====================================================================================================================

def marble_cliff(name: str, seed: int = 4):
    """Falaise de marbre en gradins : strates blanc crème veinées d'or, terrasses de nuages et de mousse dorée."""
    dm()
    return E.cliff(name, seed=seed, layers=5, layer_h=5.6, strata=MARBLE, caps=("nuage", "mousse_doree", "nuage"),
                   step_back=0.14)


def cloud_bank(name: str, seed: int = 5, size=(11.0, 8.0, 5.0)):
    """Banc de nuages : boules facettées blanches serrées, plus hautes au centre, base plate."""
    M = dm()
    r = random.Random(seed)
    sx, sy, sz = size
    items = []
    for k in range(7):
        a = k * 2 * math.pi / 7 + r.uniform(-0.3, 0.3)
        d = 0.0 if k == 0 else r.uniform(0.3, 0.5)
        w = r.uniform(0.4, 0.55) * sx * (1.25 if k == 0 else 1.0)
        h = sz * (1.0 if k == 0 else r.uniform(0.55, 0.8))
        items.append((hull(f"{name}_boule{k}", r, (w, w * 0.85, h), points=40, flat_top=0.98,
                           at=(math.cos(a) * d * sx, math.sin(a) * d * sy, -0.2)), M["nuage"]))
    low = finish(items, bevel=0.22, max_bevel=0.9, segments=2, angle=20)
    return assemble(name, low), None


def golden_tree(name: str, seed: int = 6, height: float = 13.0):
    """Arbre d'or : tronc d'écorce blanche qui ondule, deux branches, houppiers en dôme de cubes or et blancs,
    clochettes d'or suspendues."""
    M = dm()
    r = random.Random(seed)
    items = [(hull(f"{name}_socle", r, (4.0, 3.6, 1.0), flat_top=0.7), M["marbre_b"])]
    pts = [Vector((0, 0, 0.6)), Vector((0.8, 0.2, height * 0.32)), Vector((-0.5, -0.2, height * 0.62)),
           Vector((0.3, 0.1, height * 0.82))]
    w = 1.6
    for k in range(3):
        items.append((strut(f"{name}_tronc{k}", pts[k], pts[k + 1], w, w, taper=(0.82, 0.82)), M["ecorce_blanche"]))
        if k:
            items.append((bx(f"{name}_noeud{k}", (w * 1.15, w * 1.15, w * 0.9), (pts[k].x, pts[k].y, pts[k].z - w * 0.45),
                             (0, 0, 45)), M["ecorce_blanche"]))
        w *= 0.82
    crowns = [pts[3] + Vector((0, 0, 1.2))]
    for side in (-1, 1):
        end = pts[2] + Vector((side * 3.6, r.uniform(-0.8, 0.8), 2.2))
        items.append((strut(f"{name}_branche{side}", pts[2], end, 0.8, 0.8, taper=(0.7, 0.7)), M["ecorce_blanche"]))
        crowns.append(end + Vector((0, 0, 0.6)))
    leaves = ("feuille_or", "feuille_blanche", "feuille_or")
    for i, c in enumerate(crowns):
        big = 1.0 if i == 0 else 0.8
        for k in range(7):
            s = r.uniform(2.8, 3.6) * big
            if k < 6:
                a = k * math.pi / 3 + r.uniform(-0.2, 0.2)
                off = Vector((math.cos(a) * 1.9, math.sin(a) * 1.9, r.uniform(-0.4, 0.6))) * big
            else:
                off = Vector((0, 0, 1.9)) * big
            items.append((bx(f"{name}_feuilles{i}_{k}", (s, s, s * 0.9), (c.x + off.x, c.y + off.y, c.z + off.z - s * 0.45),
                             (r.uniform(-12, 12), r.uniform(-12, 12), r.uniform(0, 90))), M[leaves[(i + k) % 3]]))
        for k in range(2):
            a = r.uniform(0, 2 * math.pi)
            bell = G.lathe(f"{name}_cloche{i}_{k}", [(0, 0), (0.55, 0), (0.4, 0.5), (0.2, 0.9), (0, 0.95)], segments=8)
            G.transform(bell, Matrix.Translation((c.x + math.cos(a) * 1.7 * big, c.y + math.sin(a) * 1.7 * big, c.z - 2.4 * big)))
            items.append((bell, M["or"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def topiary(name: str, seed: int = 7):
    """Buisson taillé : jardinière de marbre cerclée d'or, deux cubes de laurier posés en losange."""
    M = dm()
    items = [(bx(f"{name}_jardiniere", (2.6, 2.6, 1.8), (0, 0, 0), taper=(1.15, 1.15)), M["marbre_taille"]),
             (bx(f"{name}_cercle", (3.1, 3.1, 0.35), (0, 0, 1.55)), M["or"]),
             (bx(f"{name}_feuillage0", (2.6, 2.6, 2.6), (0, 0, 1.6), (35, 0, 45)), M["laurier"]),
             (bx(f"{name}_feuillage1", (1.7, 1.7, 1.7), (0, 0, 4.6), (35, 0, 45)), M["laurier"]),
             (bx(f"{name}_pointe", (0.6, 0.6, 0.6), (0, 0, 6.6), (35, 0, 45)), M["or"])]
    low = finish(items, bevel=0.1, max_bevel=0.12, segments=2, angle=30)
    return assemble(name, low), None


def marble_rock(name: str, seed: int = 8, size=(9.0, 7.0, 6.0)):
    """Rocher de marbre facetté veiné d'or, éclat posé contre lui, petit nuage au pied."""
    M = dm()
    r = random.Random(seed)
    sx, sy, sz = size
    items = [(hull(f"{name}_roche", r, size, flat_top=0.7), M["marbre_a"]),
             (hull(f"{name}_eclat", r, (sx * 0.45, sy * 0.45, sz * 0.5), at=(sx * 0.42, -sy * 0.3, 0), rot=(0, 0, 30)),
              M["marbre_c"]),
             (hull(f"{name}_nuage", r, (sx * 0.5, sy * 0.45, sz * 0.32), points=20, flat_top=0.9, at=(-sx * 0.38, -sy * 0.35, -0.1)),
              M["nuage"])]
    low = finish(items, bevel=0.06, max_bevel=0.3, segments=2, angle=20)
    return assemble(name, low), None


def celestial_grass(name: str, seed: int = 9):
    dm()
    return E.grass_tuft(name, seed=seed, height=2.8, tones=("herbe_celeste", "feuille_or"))


def broken_column(name: str, seed: int = 10):
    """Colonne de marbre brisée : base, tambours cannelés (le dernier de travers), chapiteau tombé cerclé d'or,
    couronne de laurier."""
    M = dm()
    r = random.Random(seed)
    items = [(bx(f"{name}_base", (4.4, 4.4, 1.0), (0, 0, 0)), M["marbre_taille"])]
    z = 1.0
    for k in range(3):
        drum = fluted_column(f"{name}_tambour{k}", 2.4, 1.55, phase=k * 0.13)
        G.transform(drum, Matrix.Translation(((0.5 if k == 2 else 0), 0, z)) @ Matrix.Rotation(math.radians((0, 0, 10)[k]), 4, "Y"))
        items.append((drum, M["marbre_a"]))
        z += 2.42
    items.append((bx(f"{name}_chapiteau", (3.6, 3.6, 1.2), (-3.4, 1.4, -0.1), (8, -6, 25), taper=(1.2, 1.2)), M["marbre_b"]))
    items.append((bx(f"{name}_filet", (3.8, 3.8, 0.3), (-3.4, 1.4, 0.95), (8, -6, 25)), M["or"]))
    for k in range(10):
        a = k * 2 * math.pi / 10
        items.append((bx(f"{name}_laurier{k}", (0.9, 0.45, 0.35), (math.cos(a) * 1.55, math.sin(a) * 1.55, 3.4),
                         (0, 25, math.degrees(a) + 90), taper=(0.5, 1.0)), M["laurier"]))
    low = finish(items, bevel=0.1, max_bevel=0.15, segments=2, angle=20)
    return assemble(name, low), None


def sky_tower(name: str, seed: int = 11, height: float = 15.0):
    """Tour céleste : socle, fût de marbre cerclé d'or, fenêtres bleu ciel, balcon, coupole d'or et flèche."""
    M = dm()
    items = [(bx(f"{name}_socle", (5.6, 5.6, 1.4), (0, 0, 0)), M["marbre_taille"]),
             (G.lathe(f"{name}_fut", [(0, 1.4), (2.3, 1.4), (2.0, height), (0, height)], segments=12), M["marbre_a"])]
    for k, z in enumerate((4.0, height * 0.62, height - 0.4)):
        items.append((G.lathe(f"{name}_cercle{k}", [(0, z), (2.45 - k * 0.15, z), (2.45 - k * 0.15, z + 0.5), (0, z + 0.5)],
                              segments=12), M["or"]))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        items.append((gem(bx(f"{name}_fenetre{k}", (0.8, 0.3, 1.8), (math.cos(a) * 2.05, math.sin(a) * 2.05, height * 0.7),
                             (0, 0, math.degrees(a) + 90)), k), M["eau_celeste"]))
    items.append((G.lathe(f"{name}_balcon", [(0, height), (3.0, height), (3.0, height + 0.5), (0, height + 0.5)], segments=12),
                  M["marbre_b"]))
    items.append((G.lathe(f"{name}_coupole", [(0, height + 0.5), (2.2, height + 0.5), (2.0, height + 1.6), (1.3, height + 2.6),
                                              (0, height + 3.1)], segments=12), M["or"]))
    items.append((strut(f"{name}_fleche", Vector((0, 0, height + 3.0)), Vector((0, 0, height + 5.4)), 0.4, 0.4, taper=(0.2, 0.2)),
                  M["or"]))
    low = finish(items, bevel=0.08, max_bevel=0.15, segments=2, angle=25)
    return assemble(name, low), None


# =====================================================================================================================
# Sanctuaire
# =====================================================================================================================

def celestial_gate(name: str, seed: int = 12, opening: float = 18.0, pillar_h: float = 13.5, depth: float = 3.2):
    """Porte céleste : colonnes cannelées sur socles, chapiteaux cerclés d'or, arche de voussoirs blancs et or, clé en
    cristal de lumière, soleil rayonnant au sommet."""
    M = dm()
    items = []
    r_in = opening / 2
    for side in (-1, 1):
        px = side * (r_in + 1.6)
        items.append((bx(f"{name}_socle{side}", (4.4, depth + 1.2, 1.5), (px, 0, 0)), M["marbre_taille"]))
        items.append((fluted_column(f"{name}_colonne{side}", pillar_h - 2.7, 1.5, at=(px, 0, 1.5), phase=0.1), M["marbre_a"]))
        items.append((bx(f"{name}_chapiteau{side}", (4.2, depth + 0.8, 1.2), (px, 0, pillar_h - 1.2)), M["marbre_b"]))
        items.append((bx(f"{name}_filet{side}", (4.4, depth + 1.0, 0.3), (px, 0, pillar_h - 1.35)), M["or"]))
    n = 9
    gap = 0.03
    for k in range(n):
        a0 = math.pi - k * math.pi / n - gap / 2
        a1 = math.pi - (k + 1) * math.pi / n + gap / 2
        key = k == n // 2
        piece = ring_sector(f"{name}_voussoir{k}", r_in - 0.2, r_in + (4.2 if key else 3.0), a1, a0,
                            depth + (0.6 if key else 0.0), steps=2, at=(0, 0, pillar_h))
        items.append((gem(piece, k) if key else piece,
                      M["cristal_lumiere"] if key else (M["marbre_c"] if k % 2 == 0 else M["or"])))
    items += sun_disc(f"{name}_soleil", (0, -depth / 2 - 0.3, pillar_h + r_in + 5.4), 1.4)
    low = finish(items, bevel=0.1, max_bevel=0.3, segments=2, angle=25)
    return assemble(name, low), None


def light_basin(name: str, seed: int = 13, height: float = 10.0):
    """Vasque de lumière : colonne cannelée, coupe d'or, cristal de lumière blanc-or (la lumière vient de Roblox)."""
    M = dm()
    r = random.Random(seed)
    items = [(bx(f"{name}_socle", (4.4, 4.4, 1.2), (0, 0, 0)), M["marbre_taille"]),
             (fluted_column(f"{name}_colonne", height - 0.2, 1.3, at=(0, 0, 1.1), phase=0.2), M["marbre_a"])]
    cup = G.lathe(f"{name}_coupe", [(0, height + 0.8), (0.9, height + 0.8), (2.0, height + 1.6), (2.2, height + 2.2),
                                    (1.9, height + 2.25), (0, height + 1.8)], segments=12)
    items.append((cup, M["or"]))
    items.append((gem(hull(f"{name}_cristal", r, (1.9, 1.9, 3.2), points=14, flat_top=0.98, at=(0, 0, height + 1.7),
                           rot=(0, 0, 20)), seed), M["cristal_lumiere"]))
    low = finish(items, bevel=0.1, max_bevel=0.15, segments=2, angle=25)
    return assemble(name, low), None


def sun_slab(name: str, seed: int = 14, size=(8.0, 6.0, 1.2)):
    """Dalle de marbre fendue, soleil d'or incrusté (disque et rayons à plat)."""
    M = dm()
    r = random.Random(seed)
    sx, sy, sz = size
    items = []
    cut = r.uniform(-0.6, 0.6)
    for k, ((cx, cy), (w, d)) in enumerate((((-sx / 4 + cut / 2 - 0.05, -sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((-sx / 4 + cut / 2 - 0.05, sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((sx / 4 + cut / 2 + 0.05, 0), (sx / 2 - cut - 0.1, sy - 0.1)))):
        items.append((bx(f"{name}_morceau{k}", (w, d, sz), (cx, cy, r.uniform(-0.12, 0.05)),
                         (r.uniform(-1.2, 1.2), r.uniform(-1.2, 1.2), r.uniform(-1.5, 1.5))), M["marbre_taille"]))
    items.append((G.lathe(f"{name}_soleil", [(0, sz - 0.05), (0.9, sz - 0.05), (0.9, sz + 0.08), (0, sz + 0.1)], segments=12),
                  M["or"]))
    for k in range(8):
        a = k * math.pi / 4
        items.append((bx(f"{name}_rayon{k}", (1.0, 0.28, 0.12), (math.cos(a) * 1.6, math.sin(a) * 1.6, sz - 0.05),
                         (0, 0, math.degrees(a)), taper=(0.3, 1.0)), M["or"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def balustrade(name: str, seed: int = 15, length: float = 12.0):
    """Balustrade de marbre : socle et main courante, balustres en vase, poteaux d'angle coiffés d'or."""
    M = dm()
    items = [(bx(f"{name}_socle", (length, 1.4, 0.5), (0, 0, 0)), M["marbre_taille"]),
             (bx(f"{name}_main", (length, 1.3, 0.45), (0, 0, 2.3)), M["marbre_b"])]
    for side in (-1, 1):
        items.append((bx(f"{name}_poteau{side}", (1.2, 1.5, 2.9), (side * (length / 2 - 0.6), 0, 0)), M["marbre_a"]))
        items.append((G.lathe(f"{name}_coiffe{side}", [(0, 2.9), (0.55, 2.9), (0.6, 3.25), (0.3, 3.6), (0, 3.7)], segments=8),
                      M["or"]))
        G.transform(items[-1][0], Matrix.Translation((side * (length / 2 - 0.6), 0, 0)))
    n = 7
    for k in range(n):
        x = -length / 2 + 1.7 + k * (length - 3.4) / (n - 1)
        vase = G.lathe(f"{name}_balustre{k}", [(0, 0.5), (0.4, 0.5), (0.25, 0.8), (0.5, 1.4), (0.22, 2.0), (0.35, 2.3), (0, 2.3)],
                       segments=6)
        G.transform(vase, Matrix.Translation((x, 0, 0)))
        items.append((vase, M["marbre_c"]))
    low = finish(items, bevel=0.1, max_bevel=0.1, segments=2, angle=30)
    return assemble(name, low), None


def marble_stairs(name: str, seed: int = 16):
    dm()
    return E.stairs(name, seed=seed, step_mat="marbre_taille", cheek_mat="marbre_b")


def golden_harp(name: str, seed: int = 17):
    """Harpe d'or géante du Chérubin Hamster : socle de marbre, colonne, console en arc, table d'harmonie, cordes."""
    M = dm()
    items = [(bx(f"{name}_socle", (4.6, 2.6, 0.9), (0, 0, 0)), M["marbre_taille"])]
    col_base, col_top = Vector((-1.6, 0, 0.9)), Vector((-1.6, 0, 9.0))
    items.append((strut(f"{name}_colonne", col_base, col_top, 0.7, 0.7), M["or"]))
    items.append((bx(f"{name}_tete", (1.1, 1.0, 1.0), (col_top.x, 0, col_top.z - 0.3)), M["or"]))
    arc = [col_top]
    for k in range(1, 6):
        t = k / 5
        arc.append(Vector((-1.6 + 3.6 * t, 0, 9.0 - 2.6 * t + math.sin(t * math.pi) * 1.2)))
    for k in range(5):
        items.append((strut(f"{name}_console{k}", arc[k], arc[k + 1], 0.6, 0.55), M["or"]))
    board_base, board_top = Vector((-1.2, 0, 1.0)), arc[-1]
    items.append((strut(f"{name}_table", board_base, board_top, 1.0, 0.8, taper=(0.6, 0.8)), M["ecorce_blanche"]))
    for k in range(8):
        t = (k + 0.5) / 8
        low_pt = board_base.lerp(board_top, t) + Vector((-0.2, 0, 0))
        up_idx = min(5, max(1, round(t * 5)))
        up = arc[up_idx].lerp(arc[up_idx - 1], 0.5) if k % 2 else arc[up_idx]
        top = Vector((low_pt.x, 0, up.z - 0.3))
        if top.z - low_pt.z > 0.6:
            items.append((strut(f"{name}_corde{k}", low_pt, top, 0.12, 0.12), M["fil_or"]))
    low = finish(items, bevel=0.08, max_bevel=0.1, segments=2, angle=30)
    return assemble(name, low), None


def fountain(name: str, seed: int = 18):
    """Fontaine à étages : bassin de marbre, eau céleste, colonne, deux vasques cerclées d'or, jet d'eau."""
    M = dm()
    r = random.Random(seed)
    items = [(G.lathe(f"{name}_bassin", [(0, 0), (5.2, 0), (5.2, 1.4), (4.6, 1.4), (4.6, 0.6), (0, 0.6)], segments=12),
              M["marbre_taille"]),
             (gem(G.lathe(f"{name}_eau0", [(0, 0.6), (4.65, 0.6), (4.65, 1.15), (0, 1.15)], segments=12), seed), M["eau_celeste"]),
             (G.lathe(f"{name}_rebord", [(5.0, 1.35), (5.35, 1.35), (5.35, 1.65), (5.0, 1.65)], segments=12, closed=True), M["or"]),
             (fluted_column(f"{name}_colonne", 3.6, 0.8, at=(0, 0, 1.1)), M["marbre_a"])]
    for k, (z, rad) in enumerate(((4.6, 2.8), (7.4, 1.5))):
        items.append((G.lathe(f"{name}_vasque{k}", [(0, z - 0.6), (0.6, z - 0.6), (rad, z), (rad, z + 0.5), (rad - 0.35, z + 0.5),
                                                    (rad - 0.35, z + 0.15), (0, z + 0.15)], segments=12), M["marbre_b"]))
        items.append((gem(G.lathe(f"{name}_eau{k + 1}", [(0, z + 0.15), (rad - 0.3, z + 0.15), (rad - 0.3, z + 0.4), (0, z + 0.4)],
                                  segments=12), seed + k), M["eau_celeste"]))
        items.append((G.lathe(f"{name}_filet{k}", [(rad - 0.05, z + 0.45), (rad + 0.15, z + 0.45), (rad + 0.15, z + 0.65),
                                                   (rad - 0.05, z + 0.65)], segments=12, closed=True), M["or"]))
        if k == 0:
            items.append((fluted_column(f"{name}_colonne2", 2.4, 0.5, at=(0, 0, z + 0.3)), M["marbre_a"]))
    items.append((gem(hull(f"{name}_jet", r, (0.9, 0.9, 2.6), points=14, flat_top=0.98, at=(0, 0, 7.8)), seed + 5), M["eau_celeste"]))
    low = finish(items, bevel=0.06, max_bevel=0.1, segments=2, angle=35)  # 12 côtés = 30° : pas de biseau sur les arêtes du tour
    return assemble(name, low), None


def winged_orb(name: str, seed: int = 19):
    """Statue : piédestal de marbre cerclé d'or, orbe d'or à deux ailes de plumes, face à -Y."""
    M = dm()
    r = random.Random(seed)
    items = [(bx(f"{name}_marche", (4.6, 4.6, 0.8), (0, 0, 0)), M["marbre_taille"]),
             (bx(f"{name}_pied", (3.2, 3.2, 4.0), (0, 0, 0.8), taper=(0.9, 0.9)), M["marbre_a"]),
             (bx(f"{name}_filet", (3.5, 3.5, 0.35), (0, 0, 4.5)), M["or"]),
             (bx(f"{name}_dessus", (3.6, 3.6, 0.6), (0, 0, 4.8)), M["marbre_b"])]
    orb_z = 7.2
    items.append((hull(f"{name}_orbe", r, (2.8, 2.8, 2.8), points=40, flat_top=0.99, at=(0, 0, orb_z - 1.4)), M["or"]))
    for side in (-1, 1):
        for k in range(5):
            a = math.radians(70 - k * 16)  # du haut (plume longue) vers l'horizontale (plume courte)
            root = Vector((side * (1.1 + k * 0.15), 0.3, orb_z + 0.6 - k * 0.35))
            tip = root + Vector((side * math.cos(a), 0, math.sin(a))) * (4.4 - k * 0.45)
            items.append((strut(f"{name}_plume{side}_{k}", root, tip, 1.5 - k * 0.12, 0.3, taper=(0.45, 0.85),
                                roll_hint=(0, -1, 0)), M["feuille_blanche"] if k % 2 else M["or"]))
    low = finish(items, bevel=0.08, max_bevel=0.12, segments=2, angle=25)
    return assemble(name, low), None


def round_temple(name: str, seed: int = 20):
    """Temple rond : trois marches de marbre, six colonnes cannelées, entablement cerclé d'or, coupole d'or et flèche."""
    M = dm()
    items = []
    for k, rad in enumerate((7.0, 6.2, 5.4)):
        items.append((G.lathe(f"{name}_marche{k}", [(0, k * 0.6), (rad, k * 0.6), (rad, k * 0.6 + 0.6), (0, k * 0.6 + 0.6)],
                              segments=16), M["marbre_taille"]))
    base_z = 1.8
    col_h = 8.0
    for k in range(6):
        a = k * math.pi / 3 + math.pi / 6
        items.append((fluted_column(f"{name}_colonne{k}", col_h, 0.75, at=(math.cos(a) * 4.4, math.sin(a) * 4.4, base_z), phase=0.1),
                      M["marbre_a"]))
    top = base_z + col_h
    items.append((G.lathe(f"{name}_entablement", [(0, top), (5.6, top), (5.6, top + 1.2), (0, top + 1.2)], segments=16), M["marbre_b"]))
    items.append((G.lathe(f"{name}_frise", [(5.55, top + 0.45), (5.75, top + 0.45), (5.75, top + 0.8), (5.55, top + 0.8)],
                          segments=16, closed=True), M["or"]))
    dome = G.lathe(f"{name}_coupole", [(0, top + 1.2), (5.0, top + 1.2), (4.6, top + 2.8), (3.4, top + 4.2), (1.8, top + 5.0),
                                       (0, top + 5.3)], segments=16)
    items.append((dome, M["or"]))
    items.append((strut(f"{name}_fleche", Vector((0, 0, top + 5.2)), Vector((0, 0, top + 7.4)), 0.45, 0.45, taper=(0.2, 0.2)), M["or"]))
    low = finish(items, bevel=0.06, max_bevel=0.12, segments=2, angle=25)
    return assemble(name, low), None


# =====================================================================================================================
# Catalogue
# =====================================================================================================================

DIVIN = {
    "Divin_Falaise": (lambda n: marble_cliff(n, seed=4), 1024),
    "Divin_Nuage": (lambda n: cloud_bank(n, seed=5), 1024),
    "Divin_ArbreDore": (lambda n: golden_tree(n, seed=6), 1024),
    "Divin_Buisson": (lambda n: topiary(n, seed=7), 512),
    "Divin_Rocher": (lambda n: marble_rock(n, seed=8), 1024),
    "Divin_Touffe": (lambda n: celestial_grass(n, seed=9), 512),
    "Divin_Colonne": (lambda n: broken_column(n, seed=10), 1024),
    "Divin_Tour": (lambda n: sky_tower(n, seed=11), 1024),
    "Divin_PorteCeleste": (lambda n: celestial_gate(n, seed=12), 1024),
    "Divin_Vasque": (lambda n: light_basin(n, seed=13), 1024),
    "Divin_Dalle": (lambda n: sun_slab(n, seed=14), 512),
    "Divin_Balustrade": (lambda n: balustrade(n, seed=15), 1024),
    "Divin_Escalier": (lambda n: marble_stairs(n, seed=16), 1024),
    "Divin_Harpe": (lambda n: golden_harp(n, seed=17), 1024),
    "Divin_Fontaine": (lambda n: fountain(n, seed=18), 1024),
    "Divin_Statue": (lambda n: winged_orb(n, seed=19), 1024),
    "Divin_Temple": (lambda n: round_temple(n, seed=20), 1024),
}

E.BUILDERS.update(DIVIN)
E.WORLDS["Divin"] = list(DIVIN)
