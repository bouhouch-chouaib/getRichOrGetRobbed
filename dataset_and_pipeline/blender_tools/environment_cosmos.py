"""Décors du monde Cosmos (6e palier) — « L'Observatoire de l'Astro-Hamster ». Même langage que les autres mondes :
blocs biseautés, tenons sur les faces du dessus de la roche lunaire, du régolithe et du métal de la base.
Charte : map_art_bible_cosmos.json.

**Aucune lueur** (pas d'émission, aucun _Emissive.png à envoyer : avertissement de modération du 25 oct.). Les cristaux
sont des couleurs vives ; la lumière viendra de PointLight posées par le script Studio.

Importé par environment_recipes.catalog("Cosmos") : ajoute ses décors (préfixe « Cosmos_ ») à E.BUILDERS et sa liste
à E.WORLDS["Cosmos"]. Repère : pivot au sol au centre, devant = -Y, 1 unité = 1 stud.
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


def cm() -> dict[str, bpy.types.Material]:
    M = E.mats()
    if "roche_lune_a" in M and M["roche_lune_a"].name in bpy.data.materials:
        return M
    W = S.create_stylized_edge_wear_material
    C = S.create_stylized_crystal_or_gem
    stone = dict(brush_scale=0.22, grain_scale=3.0, edge_radius=0.18, cavity_distance=1.0, bump_strength=0.45)
    plant = dict(brush_scale=0.35, grain_scale=4.0, edge_radius=0.14, cavity_distance=1.0, wear=0.85, roughness=0.55,
                 studs=1.0)
    paint = dict(brush_scale=0.5, edge_radius=0.06, cavity_distance=0.6, wear=0.55, roughness=0.45)
    small = dict(brush_scale=0.6, edge_radius=0.05)
    M.update({
        "roche_lune_a": W("M_RocheLuneA", base="#6A6290", edge="#B4AEDC", cavity="#241E3E", accent="#7A72A0",
                          crackle=0.25, crackle_scale=0.7, wear=0.7, roughness=0.75, **stone),
        "roche_lune_b": W("M_RocheLuneB", base="#585080", edge="#A49ECC", cavity="#1E1834", accent="#686090",
                          crackle=0.25, crackle_scale=0.7, wear=0.7, roughness=0.75, **stone),
        "roche_lune_c": W("M_RocheLuneC", base="#7A74A0", edge="#C8C4EA", cavity="#2A2446", accent="#8A84B0",
                          crackle=0.25, crackle_scale=0.7, wear=0.7, roughness=0.75, **stone),
        "regolithe": W("M_Regolithe", base="#9A94BC", edge="#DCD8F4", cavity="#4A4466", wear=0.7, roughness=0.85,
                       studs=1.0, **stone),
        # roche de météorite : les creux sont roses (cristaux pris dans la roche), sans lueur
        "roche_meteore": W("M_RocheMeteore", base="#3A3048", edge="#7A6A90", cavity="#C04AE0", accent="#4A3E5A",
                           crackle=0.35, crackle_scale=0.9, wear=0.6, roughness=0.7, **stone),
        "mousse_violette": W("M_MousseViolette", base="#B48CFF", edge="#E6D6FF", cavity="#5A3A9A", **plant),
        "mousse_cyan": W("M_MousseCyan", base="#78DCFF", edge="#D6F6FF", cavity="#2A6A9A", **plant),
        "mousse_rose": W("M_MousseRose", base="#FF96F0", edge="#FFD6F8", cavity="#9A3A8A", **plant),
        "tronc_alien": W("M_TroncAlien", base="#9A6EDC", edge="#D6C0FF", cavity="#3E2470", wear=0.7, roughness=0.6,
                         brush_scale=0.4, grain_scale=5.0, edge_radius=0.12, cavity_distance=0.8),
        "feuille_alien_a": W("M_FeuilleAlienA", base="#BE8CFF", edge="#EAD8FF", cavity="#5A3A9A", **plant),
        "feuille_alien_b": W("M_FeuilleAlienB", base="#7850DC", edge="#C2AAFF", cavity="#30186A", **plant),
        "feuille_alien_c": W("M_FeuilleAlienC", base="#FF96F0", edge="#FFD8FA", cavity="#9A3A8A", **plant),
        "champi_cyan": W("M_ChampiCyan", base="#5AE6D2", edge="#C8FFF6", cavity="#1A6A64", **plant),
        "champi_rose": W("M_ChampiRose", base="#FF7AC8", edge="#FFD0EC", cavity="#9A2A6A", **plant),
        "champi_pied": W("M_ChampiPied", base="#E6DCF8", edge="#FFFFFF", cavity="#8A80A8", wear=0.5, roughness=0.6,
                         **small),
        "pois": W("M_PoisBlanc", base="#F4F8FF", edge="#FFFFFF", cavity="#A0A8C0", wear=0.3, roughness=0.5, **small),
        "metal_blanc": W("M_MetalBlanc", base="#E6E8F4", edge="#FFFFFF", cavity="#7A7C98", accent="#D6D8E8", **paint),
        "metal_sombre": W("M_MetalSombre", base="#3A3858", edge="#7A78A0", cavity="#16142A", accent="#46446A", **paint),
        "metal_lune": W("M_MetalLune", base="#8A80B4", edge="#D0CAF0", cavity="#3A3460", accent="#9A90C4", studs=1.0,
                        **paint),
        "rouge_fusee": W("M_RougeFusee", base="#F0463C", edge="#FFA898", cavity="#7A1A14", **paint),
        "cristal_cyan": C("M_CristalCyan", core="#14468A", mid="#78DCFF", rim="#F0FFFF", emission=0.0),
        "cristal_rose": C("M_CristalRose", core="#7A1A6A", mid="#FF96F0", rim="#FFF0FC", emission=0.0),
        "cristal_violet": C("M_CristalViolet", core="#2A1050", mid="#B48CFF", rim="#F0E6FF", emission=0.0),
    })
    return M


ROCK = ("roche_lune_a", "roche_lune_b", "roche_lune_c", "roche_lune_a", "roche_lune_b")
CRYSTALS = ("cristal_cyan", "cristal_rose", "cristal_violet")


def gem(obj: bpy.types.Object, seed: int = 0) -> bpy.types.Object:
    """Attributs du matériau cristal (dégradé pied -> pointe, teinte par facette) pour une pièce qui n'est pas faite
    par G.crystal_cluster : sans eux le cristal sort couleur « cœur » (sombre)."""
    G.write_grad_attribute(obj, "height", offset=0.25, top=0.85)
    G.write_facet_attribute(obj, seed)
    return obj


def star(prefix: str, center, s: float, mat: str = "or"):
    """Étoile à 5 branches debout, face vers -Y (sommet des portes)."""
    M = cm()
    c = Vector(center)
    out = [(bx(f"{prefix}_coeur", (0.9 * s, 0.4 * s, 0.9 * s), (c.x, c.y, c.z - 0.45 * s), (0, 45, 0)), M[mat])]
    for k in range(5):
        a = math.radians(90 + k * 72)
        tip = c + Vector((math.cos(a), 0, math.sin(a))) * 1.25 * s
        out.append((strut(f"{prefix}_branche{k}", c, tip, 0.75 * s, 0.36 * s, taper=(0.15, 0.6), roll_hint=(0, -1, 0)),
                    M[mat]))
    return out


def crystal_bunch(prefix: str, origin, s: float, seed: int, mat: str = "cristal_cyan", count: int = 4):
    M = cm()
    return [(G.crystal_cluster(prefix, count=count, origin=origin, spread=0.7 * s, radius=(0.25 * s, 0.5 * s),
                               height=(0.9 * s, 2.0 * s), seed=seed, tilt=(5, 30)), M[mat])]


# =====================================================================================================================
# Nature de l'astéroïde
# =====================================================================================================================

def asteroid_cliff(name: str, seed: int = 4):
    """Falaise d'astéroïde en gradins : strates de roche lunaire gris-lavande, terrasses de mousse alien à tenons."""
    cm()
    return E.cliff(name, seed=seed, layers=5, layer_h=5.6, strata=ROCK,
                   caps=("mousse_violette", "mousse_cyan", "mousse_rose"), step_back=0.14)


def crystals(name: str, seed: int = 5):
    """Géode : bouquet de cristaux cyan et un plus petit rose sur un socle de roche lunaire."""
    M = cm()
    r = random.Random(seed)
    items = [(hull(f"{name}_socle", r, (5.0, 4.2, 1.4), flat_top=0.6), M["roche_lune_a"]),
             (G.crystal_cluster(f"{name}_grand", count=6, origin=(0, 0, 1.0), spread=1.0, radius=(0.4, 0.75),
                                height=(1.8, 3.8), seed=seed, tilt=(5, 28)), M["cristal_cyan"]),
             (G.crystal_cluster(f"{name}_petit", count=4, origin=(2.0, -1.2, 0.3), spread=0.6, radius=(0.25, 0.45),
                                height=(0.8, 1.6), seed=seed + 3, facing=-0.4, arc=1.6), M["cristal_rose"])]
    low = finish(items, bevel=0.06, max_bevel=0.12, segments=2, angle=20)
    return assemble(name, low), None


def alien_tree(name: str, seed: int = 6, height: float = 13.0):
    """Arbre extraterrestre : tronc lavande qui ondule, deux branches, houppiers en cubes (violet, mauve, rose),
    fruits roses suspendus."""
    M = cm()
    r = random.Random(seed)
    items = [(hull(f"{name}_roche", r, (4.0, 3.6, 1.2), flat_top=0.7), M["roche_lune_b"])]
    pts = [Vector((0, 0, 0.6)), Vector((0.9, 0.2, height * 0.32)), Vector((-0.5, -0.2, height * 0.62)),
           Vector((0.4, 0.1, height * 0.82))]
    w = 1.6
    for k in range(3):
        items.append((strut(f"{name}_tronc{k}", pts[k], pts[k + 1], w, w, taper=(0.82, 0.82)), M["tronc_alien"]))
        if k:  # nœud : bouche le raccord entre deux tronçons
            items.append((bx(f"{name}_noeud{k}", (w * 1.15, w * 1.15, w * 0.9), (pts[k].x, pts[k].y, pts[k].z - w * 0.45),
                             (0, 0, 45)), M["tronc_alien"]))
        w *= 0.82
    crowns = [pts[3] + Vector((0, 0, 1.2))]
    for side in (-1, 1):
        end = pts[2] + Vector((side * 3.6, r.uniform(-0.8, 0.8), 2.2))
        items.append((strut(f"{name}_branche{side}", pts[2], end, 0.8, 0.8, taper=(0.7, 0.7)), M["tronc_alien"]))
        crowns.append(end + Vector((0, 0, 0.6)))
    leaves = ("feuille_alien_a", "feuille_alien_b", "feuille_alien_c")
    for i, c in enumerate(crowns):
        big = 1.0 if i == 0 else 0.8
        # houppier en dôme : 6 gros cubes en couronne + 1 au sommet (volume rond, pas une galette)
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
            items.append((bx(f"{name}_fruit{i}_{k}", (0.7, 0.7, 0.9), (c.x + math.cos(a) * 1.6 * big, c.y + math.sin(a) * 1.6 * big,
                                                                    c.z - 1.9 * big), (0, 0, 45)), M["champi_rose"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def alien_mushrooms(name: str, seed: int = 7):
    """Trois champignons extraterrestres : pieds pâles, chapeaux cyan et rose à pois blancs."""
    M = cm()
    r = random.Random(seed)
    items = [(hull(f"{name}_sol", r, (5.6, 4.6, 1.0), flat_top=0.7), M["regolithe"])]
    for i, (h, rad, x, y, cap) in enumerate(((6.5, 2.6, 0.0, 0.0, "champi_cyan"), (4.2, 1.8, 2.4, 1.2, "champi_rose"),
                                             (3.0, 1.3, -2.2, 1.0, "champi_cyan"))):
        lean = Matrix.Translation((x, y, 0.3)) @ Matrix.Rotation(math.radians(r.uniform(-8, 8)), 4, "X") \
            @ Matrix.Rotation(math.radians(r.uniform(-8, 8)), 4, "Y")
        stem = G.lathe(f"{name}_pied{i}", [(0, 0), (0.55 * rad / 2.6 + 0.25, 0), (0.42 * rad / 2.6 + 0.2, h * 0.8),
                                           (0, h * 0.8)], segments=10)
        top = G.lathe(f"{name}_chapeau{i}", [(0, h * 0.72), (rad, h * 0.72), (rad * 0.96, h * 0.84), (rad * 0.62, h * 0.98),
                                             (0, h * 1.03)], segments=12)
        G.transform(stem, lean)
        G.transform(top, lean)
        items += [(stem, M["champi_pied"]), (top, M[cap])]
        for k in range(4):
            a = k * math.pi / 2 + r.uniform(-0.3, 0.3)
            spot = bx(f"{name}_pois{i}_{k}", (0.32 * rad, 0.32 * rad, 0.14 * rad), (math.cos(a) * rad * 0.55, math.sin(a) * rad * 0.55,
                                                                              h * 0.9), (0, 0, math.degrees(a)))
            G.transform(spot, lean)
            items.append((spot, M["pois"]))
    low = finish(items, bevel=0.08, max_bevel=0.1, segments=2, angle=30)
    return assemble(name, low), None


def moon_rock(name: str, seed: int = 8, size=(9.0, 7.0, 6.0)):
    """Rocher lunaire facetté : éclat posé contre lui, bord de petit cratère sur le dessus, quelques cristaux."""
    M = cm()
    r = random.Random(seed)
    sx, sy, sz = size
    items = [(hull(f"{name}_roche", r, size, flat_top=0.7), M["roche_lune_a"]),
             (hull(f"{name}_eclat", r, (sx * 0.45, sy * 0.45, sz * 0.5), at=(sx * 0.42, -sy * 0.3, 0), rot=(0, 0, 30)),
              M["roche_lune_c"])]
    top = sz * 0.85
    for k in range(8):
        a = k * math.pi / 4
        items.append((bx(f"{name}_cratere{k}", (1.0, 0.6, 0.5), (-0.6 + math.cos(a) * 1.3, 0.3 + math.sin(a) * 1.3, top - 0.1),
                         (0, 0, math.degrees(a) + 90), taper=(0.8, 0.6)), M["regolithe"]))
    items += crystal_bunch(f"{name}_cristaux", (sx * 0.25, -sy * 0.32, sz * 0.25), 0.9, seed + 2, "cristal_cyan", 3)
    low = finish(items, bevel=0.06, max_bevel=0.3, segments=2, angle=20)
    return assemble(name, low), None


def alien_grass(name: str, seed: int = 9):
    cm()
    return E.grass_tuft(name, seed=seed, height=2.8, tones=("feuille_alien_a", "mousse_cyan"))


def meteorite(name: str, seed: int = 10):
    """Météorite tombée : cratère de régolithe en couronne, roche sombre aux creux roses, cristaux qui en sortent."""
    M = cm()
    r = random.Random(seed)
    items = []
    for k in range(12):
        a = k * 2 * math.pi / 12 + r.uniform(-0.1, 0.1)
        items.append((bx(f"{name}_bord{k}", (2.6, 1.6, r.uniform(0.9, 1.5)), (math.cos(a) * 4.4, math.sin(a) * 4.4, -0.3),
                         (r.uniform(14, 24), 0, math.degrees(a) + 90), taper=(0.85, 0.6)), M["regolithe"]))
    items.append((hull(f"{name}_roche", r, (4.6, 4.0, 3.8), points=24, flat_top=0.85, at=(0.3, 0.2, -0.6),
                       rot=(18, -12, 30)), M["roche_meteore"]))
    items.append((hull(f"{name}_eclat", r, (2.0, 1.8, 1.6), at=(-2.4, -1.2, -0.2), rot=(0, 20, 10)), M["roche_meteore"]))
    items += crystal_bunch(f"{name}_cristaux", (0.9, -0.6, 2.2), 1.0, seed + 1, "cristal_rose", 4)
    items += crystal_bunch(f"{name}_cristaux2", (-1.5, 1.4, 0.6), 0.7, seed + 2, "cristal_violet", 3)
    low = finish(items, bevel=0.08, max_bevel=0.2, segments=2, angle=20)
    return assemble(name, low), None


def crystal_spire(name: str, seed: int = 11, height: float = 15.0):
    """Aiguilles de cristal géantes (cyan, violet, rose) penchées sur un socle de roche lunaire."""
    M = cm()
    r = random.Random(seed)
    items = [(hull(f"{name}_socle", r, (8, 7, 2.4), flat_top=0.6), M["roche_lune_b"])]
    for k in range(4):
        h = height * r.uniform(0.5, 1.0) * (1.0 if k else 1.15)
        w = r.uniform(1.8, 2.8)
        a = k * 2.4 + r.uniform(-0.3, 0.3)
        d = 0.0 if k == 0 else r.uniform(1.4, 2.6)
        items.append((gem(hull(f"{name}_aiguille{k}", r, (w, w * r.uniform(0.8, 1.1), h), points=18, flat_top=0.98,
                               at=(math.cos(a) * d, math.sin(a) * d, -0.3),
                               rot=(r.uniform(-14, 14), r.uniform(-14, 14), r.uniform(0, 360))), seed + k), M[CRYSTALS[k % 3]]))
    low = finish(items, bevel=0.06, max_bevel=0.25, segments=2, angle=20)
    return assemble(name, low), None


# =====================================================================================================================
# Base lunaire
# =====================================================================================================================

def star_gate(name: str, seed: int = 12, opening: float = 18.0, pillar_h: float = 13.5, depth: float = 3.2):
    """Porte stellaire : pylônes de métal blanc et sombre à bandes de cristal, arche en anneau (voussoirs alternés,
    clé en cristal), étoile d'or au sommet, deux petits astéroïdes en orbite."""
    M = cm()
    r = random.Random(seed)
    items = []
    r_in = opening / 2
    for side in (-1, 1):
        px = side * (r_in + 1.6)
        items.append((bx(f"{name}_socle{side}", (4.4, depth + 1.2, 1.5), (px, 0, 0)), M["metal_sombre"]))
        z = 1.5
        for k in range(3):
            items.append((bx(f"{name}_bloc{side}_{k}", (3.2, depth, 3.4), (px, 0, z), taper=(0.96, 0.96)),
                          M["metal_blanc"] if k % 2 == 0 else M["metal_lune"]))
            items.append((gem(bx(f"{name}_bande{side}_{k}", (0.5, 0.3, 2.2), (px, -depth / 2 - 0.1, z + 0.6)), k), M["cristal_cyan"]))
            items.append((bx(f"{name}_joint{side}_{k}", (3.4, depth + 0.2, 0.3), (px, 0, z + 3.35)), M["metal_sombre"]))
            z += 3.6
        items.append((bx(f"{name}_chapiteau{side}", (4.2, depth + 0.8, 1.2), (px, 0, z)), M["metal_sombre"]))
    n = 9
    gap = 0.03
    for k in range(n):
        a0 = math.pi - k * math.pi / n - gap / 2
        a1 = math.pi - (k + 1) * math.pi / n + gap / 2
        key = k == n // 2
        piece = ring_sector(f"{name}_voussoir{k}", r_in - 0.2, r_in + (4.2 if key else 3.0), a1, a0,
                            depth + (0.6 if key else 0.0), steps=2, at=(0, 0, pillar_h))
        items.append((gem(piece, k) if key else piece,
                      M["cristal_violet"] if key else (M["metal_blanc"] if k % 2 == 0 else M["metal_sombre"])))
    items += star(f"{name}_etoile", (0, -depth / 2 - 0.5, pillar_h + r_in + 5.6), 1.5)
    for k, (x, z) in enumerate(((-r_in - 4.4, pillar_h + 3.0), (r_in + 4.0, pillar_h + 6.5))):
        items.append((hull(f"{name}_asteroide{k}", r, (1.8, 1.6, 1.6), points=18, flat_top=0.95, at=(x, 0.5, z)),
                      M["roche_lune_c"]))
    low = finish(items, bevel=0.1, max_bevel=0.3, segments=2, angle=25)
    return assemble(name, low), None


def crystal_pylon(name: str, seed: int = 13, height: float = 10.5):
    """Pylône à cristal : trépied de métal, colonne blanche cerclée, griffe d'or qui tient un grand cristal cyan
    (la lumière vient de Roblox)."""
    M = cm()
    r = random.Random(seed)
    items = [(bx(f"{name}_socle", (4.4, 4.4, 1.0), (0, 0, 0)), M["metal_sombre"])]
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.5
        items.append((strut(f"{name}_pied{k}", Vector((math.cos(a) * 1.9, math.sin(a) * 1.9, 1.0)), Vector((0, 0, 3.4)), 0.5, 0.5),
                      M["metal_sombre"]))
    col = G.lathe(f"{name}_colonne", [(0, 1.0), (0.85, 1.0), (0.7, height), (0, height)], segments=10)
    items.append((col, M["metal_blanc"]))
    for k, z in enumerate((3.2, 6.0, height - 0.6)):
        items.append((G.lathe(f"{name}_cercle{k}", [(0, z), (1.05, z), (1.05, z + 0.5), (0, z + 0.5)], segments=10), M["metal_sombre"]))
    for k in range(3):
        a = k * 2 * math.pi / 3
        items.append((strut(f"{name}_griffe{k}", Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, height - 0.1)),
                            Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, height + 1.8)), 0.45, 0.4, taper=(0.6, 0.6)), M["or"]))
    items.append((gem(hull(f"{name}_cristal", r, (2.0, 2.0, 3.6), points=14, flat_top=0.98, at=(0, 0, height + 0.3),
                           rot=(0, 0, 20)), seed), M["cristal_cyan"]))
    low = finish(items, bevel=0.1, max_bevel=0.15, segments=2, angle=25)
    return assemble(name, low), None


def constellation_slab(name: str, seed: int = 14, size=(8.0, 6.0, 1.2)):
    """Dalle de métal lunaire fendue, constellation incrustée en or (étoiles reliées)."""
    M = cm()
    r = random.Random(seed)
    sx, sy, sz = size
    items = []
    cut = r.uniform(-0.6, 0.6)
    for k, ((cx, cy), (w, d)) in enumerate((((-sx / 4 + cut / 2 - 0.05, -sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((-sx / 4 + cut / 2 - 0.05, sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((sx / 4 + cut / 2 + 0.05, 0), (sx / 2 - cut - 0.1, sy - 0.1)))):
        items.append((bx(f"{name}_plaque{k}", (w, d, sz), (cx, cy, r.uniform(-0.12, 0.05)),
                         (r.uniform(-1.2, 1.2), r.uniform(-1.2, 1.2), r.uniform(-1.5, 1.5))), M["metal_lune"]))
    pts = [Vector((-2.6, -1.6, sz)), Vector((-1.2, -0.4, sz)), Vector((0.2, -1.0, sz)), Vector((1.4, 0.4, sz)),
           Vector((2.6, 1.6, sz)), Vector((0.6, 1.8, sz))]
    for k, p in enumerate(pts):
        items.append((bx(f"{name}_astre{k}", (0.55, 0.55, 0.14), (p.x, p.y, p.z - 0.06), (0, 0, 45)), M["or"]))
    for k, (a, b) in enumerate(((0, 1), (1, 2), (2, 3), (3, 4), (3, 5))):
        items.append((strut(f"{name}_trait{k}", pts[a] + Vector((0, 0, 0.02)), pts[b] + Vector((0, 0, 0.02)), 0.16, 0.1,
                            roll_hint=(0, 0, -1)), M["or"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def metal_barrier(name: str, seed: int = 15, length: float = 12.0):
    """Barrière de la base : poteaux sombres coiffés de balises en cristal, deux rails blancs, panneau à bandes."""
    M = cm()
    items = []
    posts = (-length / 2 + 0.4, -length / 6, length / 6, length / 2 - 0.4)
    for k, x in enumerate(posts):
        items.append((bx(f"{name}_poteau{k}", (0.7, 0.7, 2.6), (x, 0, 0)), M["metal_sombre"]))
        items.append((gem(bx(f"{name}_balise{k}", (0.6, 0.6, 0.7), (x, 0, 2.6), (0, 0, 45)), k), M[CRYSTALS[k % 2]]))
    for z in (0.9, 1.9):
        items.append((bx(f"{name}_rail{z}", (length - 0.6, 0.35, 0.35), (0, 0, z)), M["metal_blanc"]))
    for k in range(3):
        x0 = posts[k] + 0.35
        x1 = posts[k + 1] - 0.35
        items.append((bx(f"{name}_panneau{k}", (x1 - x0, 0.15, 0.7), ((x0 + x1) / 2, 0.05, 1.05)), M["metal_lune"]))
        for j in range(3):
            items.append((bx(f"{name}_bande{k}_{j}", (0.35, 0.18, 0.75), (x0 + (j + 0.5) * (x1 - x0) / 3, -0.02, 1.02),
                             (0, 30, 0)), M["mousse_cyan"]))
    low = finish(items, bevel=0.12, max_bevel=0.1, segments=2, angle=30)
    return assemble(name, low), None


def grille_stairs(name: str, seed: int = 16):
    cm()
    return E.stairs(name, seed=seed, step_mat="metal_lune", cheek_mat="metal_sombre")


def rocket(name: str, seed: int = 17):
    """Fusée de l'Astro-Hamster sur son pas de tir : corps blanc, nez et ailerons rouges, hublot, bande d'or,
    tour de lancement en treillis."""
    M = cm()
    items = [(G.lathe(f"{name}_pas", [(0, 0), (4.6, 0), (4.4, 1.0), (0, 1.0)], segments=8), M["metal_sombre"])]
    z0 = 1.8
    body = G.lathe(f"{name}_corps", [(0, z0), (1.5, z0), (1.8, z0 + 1.2), (1.85, z0 + 6.5), (1.55, z0 + 8.6), (0, z0 + 8.6)],
                   segments=12)
    nose = G.lathe(f"{name}_nez", [(0, z0 + 8.5), (1.58, z0 + 8.5), (1.2, z0 + 10.2), (0.55, z0 + 11.4), (0, z0 + 11.9)],
                   segments=12)
    items += [(body, M["metal_blanc"]), (nose, M["rouge_fusee"]),
              (G.lathe(f"{name}_bande", [(0, z0 + 2.4), (1.95, z0 + 2.4), (1.95, z0 + 3.0), (0, z0 + 3.0)], segments=12), M["or"]),
              (G.lathe(f"{name}_tuyere", [(0, z0 - 0.9), (1.2, z0 - 0.9), (0.9, z0 + 0.1), (0, z0 + 0.1)], segments=10),
               M["metal_sombre"])]
    port = G.lathe(f"{name}_hublot", [(0, 0), (0.8, 0), (0.8, 0.35), (0, 0.45)], segments=10)
    G.transform(port, Matrix.Translation((0, -1.7, z0 + 5.6)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    rim = G.lathe(f"{name}_cerclage", [(0.75, 0), (1.05, 0), (1.05, 0.3), (0.75, 0.3)], segments=10, closed=True)
    G.transform(rim, Matrix.Translation((0, -1.62, z0 + 5.6)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    items += [(gem(port, seed), M["cristal_cyan"]), (rim, M["metal_sombre"])]
    for k in range(3):
        a = math.radians(90 + k * 120)
        root = Vector((math.cos(a) * 1.6, math.sin(a) * 1.6, z0 + 2.4))
        tip = Vector((math.cos(a) * 3.4, math.sin(a) * 3.4, z0 - 0.4))
        items.append((strut(f"{name}_aileron{k}", root, tip, 0.35, 2.4, taper=(1.0, 0.5),
                            roll_hint=(-math.sin(a), math.cos(a), 0)), M["rouge_fusee"]))
    tx = 5.0
    for k, (dx, dy) in enumerate(((-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9), (0.9, 0.9))):
        items.append((bx(f"{name}_tour{k}", (0.4, 0.4, 13.0), (tx + dx, dy, 1.0)), M["metal_sombre"]))
    for k in range(4):
        z = 3.0 + k * 3.0
        items.append((bx(f"{name}_palier{k}", (2.3, 2.3, 0.3), (tx, 0, z)), M["rouge_fusee"] if k % 2 else M["metal_sombre"]))
        items.append((strut(f"{name}_croix{k}", Vector((tx - 0.9, -0.95, z - 2.7)), Vector((tx + 0.9, -0.95, z)), 0.22, 0.22),
                      M["metal_sombre"]))
    items.append((strut(f"{name}_bras", Vector((tx - 0.8, 0, z0 + 7.0)), Vector((1.7, 0, z0 + 7.0)), 0.5, 0.5), M["metal_blanc"]))
    low = finish(items, bevel=0.08, max_bevel=0.12, segments=2, angle=30)
    return assemble(name, low), None


def satellite_dish(name: str, seed: int = 18):
    """Antenne parabolique : socle, mât, parabole penchée vers le ciel, bras et récepteur."""
    M = cm()
    items = [(bx(f"{name}_socle", (3.6, 3.6, 1.2), (0, 0, 0)), M["metal_sombre"]),
             (G.lathe(f"{name}_mat", [(0, 1.2), (0.95, 1.2), (0.75, 4.6), (0, 4.6)], segments=10), M["metal_blanc"]),
             (bx(f"{name}_rotule", (1.8, 1.8, 1.2), (0, 0, 4.4)), M["metal_sombre"]),
             (bx(f"{name}_boitier", (1.4, 1.0, 1.6), (1.4, -1.2, 1.2)), M["metal_lune"]),
             (bx(f"{name}_voyant", (0.4, 0.2, 0.4), (1.4, -1.75, 2.2)), M["mousse_cyan"])]
    tilt = Matrix.Translation((0, 0, 5.4)) @ Matrix.Rotation(math.radians(-40), 4, "X")
    dish = G.lathe(f"{name}_parabole", [(0, 0.0), (0.5, 0.05), (2.5, 1.0), (2.7, 1.2), (2.5, 1.3), (0.4, 0.3), (0, 0.25)],
                   segments=16)
    G.transform(dish, tilt)
    items.append((dish, M["metal_blanc"]))
    focus = tilt @ Vector((0, 0, 2.9))
    for k in range(3):
        a = k * 2 * math.pi / 3
        rim = tilt @ Vector((math.cos(a) * 2.45, math.sin(a) * 2.45, 1.15))
        items.append((strut(f"{name}_bras{k}", rim, focus, 0.22, 0.22), M["metal_sombre"]))
    items.append((bx(f"{name}_recepteur", (0.8, 0.8, 0.9), (focus.x, focus.y, focus.z - 0.45)), M["rouge_fusee"]))
    low = finish(items, bevel=0.08, max_bevel=0.1, segments=2, angle=30)
    return assemble(name, low), None


def supply_crates(name: str, seed: int = 19):
    """Caisses de ravitaillement empilées : métal blanc, arêtes sombres, bande cyan ou rouge."""
    M = cm()
    r = random.Random(seed)
    items = []
    for i, (s, x, y, z, yaw, band) in enumerate(((2.4, -1.2, 0, 0, 5, "mousse_cyan"), (2.0, 1.4, 0.4, 0, -12, "rouge_fusee"),
                                                 (1.7, -0.9, 0.2, 2.4, 20, "mousse_cyan"))):
        rot = Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
        parts = [(bx(f"{name}_caisse{i}", (s, s, s), (0, 0, 0)), "metal_blanc"),
                 (bx(f"{name}_bande{i}", (s + 0.08, s + 0.08, 0.4 * s / 2.4), (0, 0, s * 0.45)), band)]
        for k, (dx, dy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
            parts.append((bx(f"{name}_arete{i}_{k}", (0.3, 0.3, s + 0.04), (dx * (s / 2 - 0.1), dy * (s / 2 - 0.1), -0.02)),
                          "metal_sombre"))
        for obj, mat in parts:
            G.transform(obj, rot)
            items.append((obj, M[mat]))
    items += crystal_bunch(f"{name}_cristaux", (2.6, -1.4, 0.0), 0.6, seed, "cristal_rose", 3)
    low = finish(items, bevel=0.1, max_bevel=0.1, segments=2, angle=30)
    return assemble(name, low), None


def ringed_planet(name: str, seed: int = 20, radius: float = 3.4):
    """Planète à anneau sur son socle : sphère en bandes (rose, violet, lavande), anneau penché cyan et or,
    trois griffes d'or sur une roche lunaire."""
    M = cm()
    r = random.Random(seed)
    items = [(hull(f"{name}_roche", r, (6.0, 5.4, 2.2), flat_top=0.6), M["roche_lune_a"]),
             (G.lathe(f"{name}_colonne", [(0, 1.6), (1.1, 1.6), (0.8, 4.2), (0, 4.2)], segments=10), M["metal_sombre"])]
    cz = 4.2 + radius + 0.4
    bands = ("feuille_alien_c", "feuille_alien_a", "feuille_alien_b", "feuille_alien_a", "feuille_alien_c", "feuille_alien_b")
    n = len(bands)
    for k in range(n):
        z0 = -radius + k * 2 * radius / n
        z1 = z0 + 2 * radius / n
        r0 = math.sqrt(max(radius * radius - z0 * z0, 0.0))
        r1 = math.sqrt(max(radius * radius - z1 * z1, 0.0))
        items.append((G.lathe(f"{name}_bande{k}", [(0, z0), (r0, z0), (r1, z1), (0, z1)], segments=16), M[bands[k]]))
        G.transform(items[-1][0], Matrix.Translation((0, 0, cz)))
    ring = G.lathe(f"{name}_anneau", [(radius * 1.35, -0.12), (radius * 1.85, -0.12), (radius * 1.85, 0.12),
                                      (radius * 1.35, 0.12)], segments=20, closed=True)
    G.transform(ring, Matrix.Translation((0, 0, cz)) @ Matrix.Rotation(math.radians(22), 4, "X") @ Matrix.Rotation(math.radians(10), 4, "Y"))
    items.append((gem(ring, seed), M["cristal_cyan"]))
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.3
        items.append((strut(f"{name}_griffe{k}", Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, 4.0)),
                            Vector((math.cos(a) * radius * 0.75, math.sin(a) * radius * 0.75, cz - radius * 0.55)), 0.5, 0.45,
                            taper=(0.6, 0.6)), M["or"]))
    low = finish(items, bevel=0.06, max_bevel=0.1, segments=2, angle=25)
    return assemble(name, low), None


# =====================================================================================================================
# Catalogue
# =====================================================================================================================

COSMOS = {
    "Cosmos_Falaise": (lambda n: asteroid_cliff(n, seed=4), 1024),
    "Cosmos_Cristaux": (lambda n: crystals(n, seed=5), 512),
    "Cosmos_ArbreAlien": (lambda n: alien_tree(n, seed=6), 1024),
    "Cosmos_Champignon": (lambda n: alien_mushrooms(n, seed=7), 1024),
    "Cosmos_Rocher": (lambda n: moon_rock(n, seed=8), 1024),
    "Cosmos_Touffe": (lambda n: alien_grass(n, seed=9), 512),
    "Cosmos_Meteorite": (lambda n: meteorite(n, seed=10), 1024),
    "Cosmos_Aiguille": (lambda n: crystal_spire(n, seed=11), 1024),
    "Cosmos_PorteStellaire": (lambda n: star_gate(n, seed=12), 1024),
    "Cosmos_Pylone": (lambda n: crystal_pylon(n, seed=13), 1024),
    "Cosmos_Dalle": (lambda n: constellation_slab(n, seed=14), 512),
    "Cosmos_Barriere": (lambda n: metal_barrier(n, seed=15), 1024),
    "Cosmos_Escalier": (lambda n: grille_stairs(n, seed=16), 1024),
    "Cosmos_Fusee": (lambda n: rocket(n, seed=17), 1024),
    "Cosmos_Satellite": (lambda n: satellite_dish(n, seed=18), 512),
    "Cosmos_Caisse": (lambda n: supply_crates(n, seed=19), 512),
    "Cosmos_Planete": (lambda n: ringed_planet(n, seed=20), 1024),
}

E.BUILDERS.update(COSMOS)
E.WORLDS["Cosmos"] = list(COSMOS)
