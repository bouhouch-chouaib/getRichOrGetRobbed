"""Décors du monde Glace (4e palier) — « Le Village Givré du Yéti ». Même langage que les autres mondes : blocs
biseautés, tenons sur les faces du dessus de la neige tassée et du bois. Charte : map_art_bible_glace.json.

**Aucune lueur** (pas d'émission, aucun _Emissive.png à envoyer : avertissement de modération du 25 oct.). Les vitres
des lanternes sont une couleur chaude ; la lumière viendra de PointLight posées par le script Studio.

Importé par environment_recipes.catalog("Glace") : ajoute ses décors (préfixe « Glace_ ») à E.BUILDERS et sa liste à
E.WORLDS["Glace"]. Repère : pivot au sol au centre, devant = -Y, 1 unité = 1 stud.
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


def gm() -> dict[str, bpy.types.Material]:
    M = E.mats()
    if "glace_a" in M and M["glace_a"].name in bpy.data.materials:
        return M
    W = S.create_stylized_edge_wear_material
    stone = dict(brush_scale=0.22, grain_scale=3.0, edge_radius=0.18, cavity_distance=1.0, bump_strength=0.4)
    wood = dict(brush_scale=0.5, grain_scale=6.0, edge_radius=0.08, cavity_distance=0.5, wear=0.75)
    plant = dict(brush_scale=0.35, grain_scale=4.0, edge_radius=0.14, cavity_distance=1.0, wear=0.85, roughness=0.6,
                 studs=1.0)
    M.update({
        # glace : creux bleu profond, jamais gris ; peu rugueuse (brillante)
        "glace_a": W("M_GlaceA", base="#A8DCF8", edge="#F0FAFF", cavity="#3E7AC0", accent="#CDEEFF", crackle=0.2,
                     crackle_scale=0.7, wear=0.6, roughness=0.22, **stone),
        "glace_b": W("M_GlaceB", base="#7EC4F0", edge="#E0F4FF", cavity="#2E6AA8", accent="#9AD4F6", crackle=0.2,
                     crackle_scale=0.7, wear=0.6, roughness=0.22, **stone),
        "glace_c": W("M_GlaceC", base="#C8EAFF", edge="#FFFFFF", cavity="#5A94D0", accent="#E0F4FF", crackle=0.15,
                     crackle_scale=0.8, wear=0.6, roughness=0.25, **stone),
        "neige": W("M_Neige", base="#F6FAFF", edge="#FFFFFF", cavity="#A8C4E0", accent="#E8F2FC", wear=0.8,
                   roughness=0.9, studs=1.0, **stone),
        "neige_taille": W("M_NeigeTassee", base="#E8F2FA", edge="#FFFFFF", cavity="#94B4D4", accent="#DCEAF6",
                          crackle=0.12, crackle_scale=0.9, wear=0.6, roughness=0.8, studs=1.0, **stone),
        "roche_froide": W("M_RocheFroide", base="#7A8494", edge="#C0CCDC", cavity="#3A4250", accent="#8A94A8",
                          crackle=0.15, crackle_scale=0.8, wear=0.7, roughness=0.75, **stone),
        "sapin": W("M_Sapin", base="#2E7A5A", edge="#86D8AA", cavity="#123A2A", **plant),
        "sapin_b": W("M_SapinB", base="#3A8E66", edge="#9AE6B8", cavity="#164832", **plant),
        "ecorce_froide": W("M_EcorceFroide", base="#6E4A36", edge="#B08A70", cavity="#2E1C14", wood=1.0, wood_axis="Z",
                           wood_scale=0.8, roughness=0.8, **wood),
        "bois_givre": W("M_BoisGivre", base="#9A6A48", edge="#E4ECF4", cavity="#3A2618", wood=1.0, wood_axis="Z",
                        wood_scale=1.1, roughness=0.7, studs=1.0, **wood),
        "bois_givre_x": W("M_BoisGivreX", base="#946444", edge="#E4ECF4", cavity="#3A2618", wood=1.0, wood_axis="X",
                          wood_scale=1.1, roughness=0.7, studs=1.0, **wood),
        "verre_chaud": W("M_VerreChaud", base="#FFC878", edge="#FFF2D0", cavity="#E08A2A", wear=0.4, roughness=0.3,
                         brush_scale=0.6, edge_radius=0.05),
        "givre_herbe": W("M_HerbeGivre", base="#B8D8E8", edge="#F4FCFF", cavity="#5A8AA8", wear=0.9, roughness=0.6,
                         brush_scale=0.8, edge_radius=0.05, cavity_distance=0.4),
        "givre_herbe_b": W("M_HerbeGivreB", base="#8EBCD4", edge="#E0F4FF", cavity="#3A6A8A", wear=0.9, roughness=0.6,
                           brush_scale=0.8, edge_radius=0.05, cavity_distance=0.4),
        "fourrure": W("M_FourrureMammouth", base="#8A5A3A", edge="#C89A70", cavity="#3A2216", wear=0.7, roughness=0.85,
                      brush_scale=0.6, edge_radius=0.08, cavity_distance=0.5, crackle=0.2, crackle_scale=1.5),
        "ivoire": W("M_Ivoire", base="#F4EAD2", edge="#FFFFFF", cavity="#B8A080", wear=0.5, roughness=0.5,
                    brush_scale=0.6, edge_radius=0.06),
        "laine_rouge": W("M_LaineRouge", base="#E8141A", edge="#FF7070", cavity="#7A0A10", wear=0.4, roughness=0.85,
                         brush_scale=0.6, edge_radius=0.04),
        "carotte": W("M_Carotte", base="#FF8A2A", edge="#FFC27A", cavity="#A84A10", wear=0.4, roughness=0.6,
                     brush_scale=0.6, edge_radius=0.04),
        "charbon_noir": W("M_CharbonNoir", base="#2A2A30", edge="#5A5A66", cavity="#101014", wear=0.4, roughness=0.7,
                          brush_scale=0.6, edge_radius=0.04),
        "cadeau_vert": W("M_CadeauVert", base="#3AC85A", edge="#A0F0B0", cavity="#14602A", wear=0.4, roughness=0.5,
                         brush_scale=0.6, edge_radius=0.05),
        "cadeau_bleu": W("M_CadeauBleu", base="#3A7AF0", edge="#A0C4FF", cavity="#143A80", wear=0.4, roughness=0.5,
                         brush_scale=0.6, edge_radius=0.05),
        "ombre_bleue": W("M_OmbreBleue", base="#1E3A6A", edge="#3A5A8A", cavity="#0A1A34", wear=0.3, roughness=0.8,
                         brush_scale=0.6, edge_radius=0.04),
        "cristal_glace": S.create_stylized_crystal_or_gem("M_CristalGlace", core="#1A4A8A", mid="#8AD8FF", rim="#F0FFFF",
                                                          emission=0.0),
    })
    return M


ICE = ("glace_a", "glace_b", "glace_c", "glace_b", "glace_a")


def icicles(prefix: str, x0: float, x1: float, y: float, z: float, count: int, rnd: random.Random, length=(0.8, 1.8)):
    """Rangée de stalactites (blocs effilés tournés vers le bas) sous une arête, de x0 à x1."""
    M = gm()
    out = []
    for k in range(count):
        x = x0 + (k + 0.5) * (x1 - x0) / count + rnd.uniform(-0.15, 0.15)
        h = rnd.uniform(*length)
        out.append((bx(f"{prefix}_{k}", (0.45, 0.45, h), (x, y, z - h), (180, 0, rnd.uniform(0, 90)), taper=(0.1, 0.1)),
                    M["glace_c"]))
    return out


# =====================================================================================================================
# Nature
# =====================================================================================================================

def glacier(name: str, seed: int = 4):
    """Glacier en gradins : strates de glace bleu ciel / bleu profond qui reculent, terrasses de neige à tenons."""
    gm()
    return E.cliff(name, seed=seed, layers=5, layer_h=5.6, strata=ICE, caps=("neige", "neige", "neige_taille"),
                   step_back=0.13)


def pine(name: str, seed: int = 5, height: float = 14.0):
    """Sapin enneigé : petit tronc, 5 étages de blocs verts qui rétrécissent (tournés d'un étage à l'autre), chacun
    coiffé d'une plaque de neige, pointe enneigée."""
    M = gm()
    r = random.Random(seed)
    items = [(bx(f"{name}_tronc", (1.2, 1.2, height * 0.22), (0, 0, 0)), M["ecorce_froide"])]
    tiers = 5
    z = height * 0.16
    for k in range(tiers):
        t = k / (tiers - 1)
        s = height * (0.52 - 0.36 * t)
        h = height * 0.17
        rz = 45 * (k % 2) + r.uniform(-6, 6)
        items.append((bx(f"{name}_etage{k}", (s, s, h), (0, 0, z), (0, 0, rz), taper=(0.62, 0.62)),
                      M["sapin"] if k % 2 == 0 else M["sapin_b"]))
        items.append((bx(f"{name}_neige{k}", (s * 0.8, s * 0.8, 0.5), (0, 0, z + h * 0.93), (0, 0, rz),
                         taper=(0.8, 0.8)), M["neige"]))
        for j in range(2):  # paquets de neige qui débordent sur les bords
            a = math.radians(rz + 90 * r.randint(0, 3) + 45)
            d = s * 0.42
            items.append((bx(f"{name}_paquet{k}_{j}", (s * 0.22, s * 0.22, 0.4), (math.cos(a) * d, math.sin(a) * d, z + h * 0.15),
                             (0, 0, math.degrees(a))), M["neige"]))
        z += h * 0.78
    items.append((bx(f"{name}_pointe", (height * 0.1, height * 0.1, height * 0.12), (0, 0, z), (0, 0, 45), taper=(0.2, 0.2)),
                  M["neige"]))
    low = finish(items, bevel=0.12, max_bevel=0.3, segments=2, angle=30)
    return assemble(name, low), None


def snowy_rock(name: str, seed: int = 6, size=(9.0, 7.0, 6.0)):
    """Rocher froid à facettes avec un chapeau de neige posé dessus."""
    M = gm()
    r = random.Random(seed)
    sx, sy, sz = size
    items = [(hull(f"{name}_roche", r, size, flat_top=0.7), M["roche_froide"]),
             (hull(f"{name}_eclat", r, (sx * 0.45, sy * 0.45, sz * 0.5), at=(sx * 0.42, -sy * 0.3, 0),
                   rot=(0, 0, 30)), M["roche_froide"]),
             (hull(f"{name}_neige", r, (sx * 0.78, sy * 0.78, 1.3), points=20, flat_top=0.85, at=(0, 0, sz * 0.82)),
              M["neige"])]
    low = finish(items, bevel=0.05, max_bevel=0.3, segments=2, angle=20)
    return assemble(name, low), None


def ice_crystals(name: str, seed: int = 7):
    """Bouquet de cristaux de glace sur un tas de neige (couleur seulement, sans lueur)."""
    M = gm()
    r = random.Random(seed)
    items = [(hull(f"{name}_neige", r, (4.6, 4.2, 1.6), flat_top=0.6), M["neige"]),
             (G.crystal_cluster(f"{name}_grand", count=6, origin=(0, 0, 1.0), spread=1.0, radius=(0.4, 0.75),
                                height=(1.8, 3.8), seed=seed, tilt=(5, 28)), M["cristal_glace"]),
             (G.crystal_cluster(f"{name}_petit", count=4, origin=(2.0, -1.2, 0.3), spread=0.6, radius=(0.25, 0.45),
                                height=(0.8, 1.6), seed=seed + 3, facing=-0.4, arc=1.6), M["cristal_glace"])]
    low = finish(items, bevel=0.06, max_bevel=0.15, segments=2, angle=20)
    return assemble(name, low), None


def snowdrift(name: str, seed: int = 8):
    """Congère : trois bosses de neige aplaties qui se chevauchent."""
    M = gm()
    r = random.Random(seed)
    items = []
    for k, (s, x, y) in enumerate(((1.0, 0, 0), (0.7, 2.6, 0.8), (0.55, -2.2, -0.6))):
        items.append((hull(f"{name}_bosse{k}", r, (5.0 * s, 3.6 * s, 1.8 * s), points=22, flat_top=0.9, at=(x, y, -0.2)),
                      M["neige"]))
    low = finish(items, bevel=0.08, max_bevel=0.2, segments=2, angle=20)
    return assemble(name, low), None


def frost_tuft(name: str, seed: int = 9):
    gm()
    return E.grass_tuft(name, seed=seed, height=2.6, tones=("givre_herbe", "givre_herbe_b"))


def ice_spire(name: str, seed: int = 10, height: float = 14.0):
    """Pics de glace : aiguilles facettées bleues penchées sur un socle de neige."""
    M = gm()
    r = random.Random(seed)
    items = [(hull(f"{name}_socle", r, (8, 7, 2.4), flat_top=0.6), M["neige"])]
    for k in range(4):
        h = height * r.uniform(0.5, 1.0) * (1.0 if k else 1.15)
        w = r.uniform(1.8, 2.8)
        a = k * 2.4 + r.uniform(-0.3, 0.3)
        d = 0.0 if k == 0 else r.uniform(1.4, 2.6)
        items.append((hull(f"{name}_aiguille{k}", r, (w, w * r.uniform(0.8, 1.1), h), points=18, flat_top=0.98,
                           at=(math.cos(a) * d, math.sin(a) * d, -0.3),
                           rot=(r.uniform(-14, 14), r.uniform(-14, 14), r.uniform(0, 360))), M[ICE[k % 3]]))
    low = finish(items, bevel=0.06, max_bevel=0.25, segments=2, angle=20)
    return assemble(name, low), None


def frozen_mammoth(name: str, seed: int = 11):
    """Mammouth pris dans un bloc de glace : la tête, la trompe et les défenses dépassent devant, la queue derrière."""
    M = gm()
    r = random.Random(seed)
    items = [(bx(f"{name}_bloc", (9.0, 7.0, 7.4), (0, 0.6, -0.4), (2, -3, 4), taper=(0.94, 0.94)), M["glace_a"]),
             (bx(f"{name}_neige", (8.2, 6.4, 0.8), (0.1, 0.6, 6.8), (2, -3, 4), taper=(0.9, 0.9)), M["neige"]),
             (bx(f"{name}_tete", (4.2, 2.6, 3.6), (0, -3.6, 2.6), (6, 0, 0), taper=(0.85, 0.85)), M["fourrure"]),
             (bx(f"{name}_toupet", (3.0, 1.6, 1.0), (0, -3.4, 6.0)), M["fourrure"])]
    trunk = [Vector((0, -4.9, 3.4)), Vector((0, -6.0, 2.0)), Vector((0, -6.4, 0.6)), Vector((0, -7.2, 0.0))]
    for k in range(3):
        items.append((strut(f"{name}_trompe{k}", trunk[k], trunk[k + 1], 1.2 - 0.25 * k, 1.1 - 0.25 * k, taper=(0.85, 0.85)),
                      M["fourrure"]))
    for side in (-1, 1):
        tusk = [Vector((side * 1.2, -4.8, 2.4)), Vector((side * 1.8, -6.4, 1.6)), Vector((side * 1.6, -7.6, 2.6)),
                Vector((side * 1.0, -7.8, 3.8))]
        for k in range(3):
            items.append((strut(f"{name}_defense{side}_{k}", tusk[k], tusk[k + 1], 0.55 - 0.1 * k, 0.55 - 0.1 * k,
                                taper=(0.8, 0.8)), M["ivoire"]))
        items.append((bx(f"{name}_oeil{side}", (0.5, 0.25, 0.5), (side * 1.3, -4.95, 3.6)), M["charbon_noir"]))
        items.append((bx(f"{name}_oreille{side}", (1.6, 0.5, 2.0), (side * 2.4, -3.2, 3.0), (0, side * 20, 0)), M["fourrure"]))
    items.append((strut(f"{name}_queue", Vector((0, 4.2, 3.0)), Vector((0, 5.4, 1.6)), 0.4, 0.4), M["fourrure"]))
    for k in range(3):
        items.append((hull(f"{name}_eclat{k}", r, (1.6, 1.4, 1.2), at=(r.uniform(-4, 4), r.uniform(-5.5, -4.2), 0)),
                      M["glace_c"]))
    low = finish(items, bevel=0.12, max_bevel=0.3, segments=2, angle=30)
    return assemble(name, low), None


# =====================================================================================================================
# Village
# =====================================================================================================================

def ice_gate(name: str, seed: int = 12, opening: float = 18.0, pillar_h: float = 13.5, depth: float = 3.2):
    """Porte de glace : piliers de blocs de glace, arche de voussoirs coiffée de neige, stalactites, flocon au sommet."""
    M = gm()
    r = random.Random(seed)
    items = []
    r_in = opening / 2
    for side in (-1, 1):
        px = side * (r_in + 1.6)
        items.append((bx(f"{name}_socle{side}", (4.4, depth + 1.2, 1.5), (px, 0, 0)), M["neige_taille"]))
        z = 1.5
        for k in range(3):
            items.append((bx(f"{name}_bloc{side}_{k}", (3.2, depth, 3.55), (px + r.uniform(-0.1, 0.1), 0, z),
                             (0, 0, r.uniform(-3, 3))), M[("glace_b", "glace_a", "glace_b")[k]]))
            z += 3.6
        items.append((bx(f"{name}_chapiteau{side}", (4.2, depth + 0.8, 1.2), (px, 0, z)), M["neige_taille"]))
    n = 9
    gap = 0.035
    for k in range(n):
        a0 = math.pi - k * math.pi / n - gap / 2
        a1 = math.pi - (k + 1) * math.pi / n + gap / 2
        key = k == n // 2
        items.append((ring_sector(f"{name}_voussoir{k}", r_in - 0.2, r_in + (4.2 if key else 3.4), a1, a0,
                                  depth + (0.6 if key else 0.0), steps=2, at=(0, 0, pillar_h)),
                      M["glace_c"] if key else M[("glace_a", "glace_b")[k % 2]]))
    items.append((ring_sector(f"{name}_neige", r_in + 3.3, r_in + 4.1, 0.05, math.pi - 0.05, depth + 0.4, steps=8,
                              at=(0, 0, pillar_h)), M["neige"]))
    items += icicles(f"{name}_stalactite", -r_in + 1.0, r_in - 1.0, -depth / 2 - 0.1, pillar_h + r_in * 0.55, 7, r,
                     length=(0.8, 2.0))
    for k in range(6):  # flocon au sommet
        a = k * math.pi / 3
        items.append((bx(f"{name}_flocon{k}", (0.35, 0.3, 1.5), (math.sin(a) * 0.7, -depth / 2 - 0.45, pillar_h + r_in + 2.2 + math.cos(a) * 0.7),
                         (0, math.degrees(a), 0)), M["glace_b"]))
    low = finish(items, bevel=0.1, max_bevel=0.3, segments=2, angle=25)
    return assemble(name, low), None


def lantern(name: str, seed: int = 13, height: float = 11.0):
    """Lanterne de village : poteau de bois givré, potence, lanterne de fer aux vitres chaudes, chapeau de neige."""
    M = gm()
    items = [(bx(f"{name}_pied", (2.6, 2.6, 0.8), (0, 0, 0), (0, 0, 45)), M["neige_taille"]),
             (bx(f"{name}_poteau", (0.9, 0.9, height), (0, 0, 0.6)), M["bois_givre"]),
             (bx(f"{name}_potence", (3.2, 0.6, 0.6), (1.2, 0, height - 0.6)), M["bois_givre_x"]),
             (bx(f"{name}_neigepoteau", (1.2, 1.2, 0.45), (0, 0, height + 0.6)), M["neige"])]
    lx = 2.4
    lz = height - 3.4
    items.append((bx(f"{name}_crochet", (0.2, 0.2, 0.9), (lx, 0, lz + 2.2)), M["fer"]))
    items.append((bx(f"{name}_toit", (1.9, 1.9, 0.6), (lx, 0, lz + 1.75), (0, 0, 45), taper=(0.35, 0.35)), M["fer"]))
    items.append((bx(f"{name}_verre", (1.3, 1.3, 1.6), (lx, 0, lz + 0.15)), M["verre_chaud"]))
    for sx in (-1, 1):
        for sy in (-1, 1):
            items.append((bx(f"{name}_montant{sx}{sy}", (0.2, 0.2, 1.7), (lx + sx * 0.68, sy * 0.68, lz + 0.1)), M["fer"]))
    items.append((bx(f"{name}_base", (1.6, 1.6, 0.3), (lx, 0, lz - 0.1)), M["fer"]))
    items.append((bx(f"{name}_neigetoit", (1.2, 1.2, 0.3), (lx, 0, lz + 2.25), (0, 0, 45)), M["neige"]))
    low = finish(items, bevel=0.12, max_bevel=0.12, segments=2, angle=30)
    return assemble(name, low), None


def snow_slab(name: str, seed: int = 14, size=(8.0, 6.0, 1.2)):
    """Dalle de neige tassée fendue, flocon de glace incrusté (6 branches)."""
    M = gm()
    r = random.Random(seed)
    sx, sy, sz = size
    items = []
    cut = r.uniform(-0.6, 0.6)
    for k, ((cx, cy), (w, d)) in enumerate((((-sx / 4 + cut / 2 - 0.05, -sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((-sx / 4 + cut / 2 - 0.05, sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((sx / 4 + cut / 2 + 0.05, 0), (sx / 2 - cut - 0.1, sy - 0.1)))):
        items.append((bx(f"{name}_morceau{k}", (w, d, sz), (cx, cy, r.uniform(-0.12, 0.05)),
                         (r.uniform(-1.2, 1.2), r.uniform(-1.2, 1.2), r.uniform(-1.5, 1.5))), M["neige_taille"]))
    for k in range(6):
        a = k * math.pi / 3
        items.append((bx(f"{name}_branche{k}", (2.2, 0.3, 0.12), (math.cos(a) * 1.1, math.sin(a) * 1.1, sz - 0.05),
                         (0, 0, math.degrees(a))), M["glace_b"]))
        for side in (-1, 1):
            b = a + side * 0.6
            items.append((bx(f"{name}_pointe{k}_{side}", (0.7, 0.22, 0.12),
                             (math.cos(a) * 1.6 + math.cos(b) * 0.3, math.sin(a) * 1.6 + math.sin(b) * 0.3, sz - 0.05),
                             (0, 0, math.degrees(b))), M["glace_b"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def log_fence(name: str, seed: int = 15, length: float = 12.0):
    """Barrière de rondins enneigée : 4 poteaux à chapeau de neige, 3 rondins, neige sur le rondin du haut,
    stalactites dessous (face avant vers -Y)."""
    M = gm()
    r = random.Random(seed)
    items = [(bx(f"{name}_talus", (length, 2.2, 0.8), (0, 0, -0.1), taper=(0.97, 0.75)), M["neige"])]
    for k in range(4):
        px = -length / 2 + 0.5 + k * (length - 1.0) / 3
        items.append((bx(f"{name}_poteau{k}", (1.0, 1.0, 4.6), (px, 0, 0.3), (0, 0, r.uniform(-4, 4))), M["bois_givre"]))
        items.append((bx(f"{name}_chapeau{k}", (1.3, 1.3, 0.5), (px, 0, 4.9), taper=(0.75, 0.75)), M["neige"]))
    for k, z in enumerate((1.4, 2.6, 3.8)):
        items.append((bx(f"{name}_rondin{k}", (length - 0.4, 0.75, 0.75), (0, -0.25, z), (r.uniform(-1, 1), 0, 0)),
                      M["bois_givre_x"]))
    items.append((bx(f"{name}_neigerondin", (length - 0.8, 0.8, 0.35), (0, -0.25, 4.5)), M["neige"]))
    items += icicles(f"{name}_stalactite", -length / 2 + 0.8, length / 2 - 0.8, -0.55, 3.45, 6, r, length=(0.5, 1.1))
    low = finish(items, bevel=0.12, max_bevel=0.14, segments=2, angle=30)
    return assemble(name, low), None


def snow_stairs(name: str, seed: int = 16):
    gm()
    return E.stairs(name, seed=seed, step_mat="neige_taille", cheek_mat="glace_a")


def igloo(name: str, seed: int = 17, radius: float = 5.0):
    """Igloo : dôme de blocs de neige (anneaux à 10 pans), tunnel d'entrée, porte sombre, fenêtre chaude."""
    M = gm()
    r = random.Random(seed)
    prof = [(0, 0)]
    rings = 5
    for k in range(rings + 1):
        a = math.pi / 2 * k / rings
        prof.append((radius * math.cos(a) + (0.0 if k == rings else 0.0), radius * 0.95 * math.sin(a)))
    prof[-1] = (0.0, radius * 0.95)
    dome = G.lathe(f"{name}_dome", prof, segments=10, phase=0.1)
    items = [(dome, M["neige_taille"]),
             (bx(f"{name}_tunnel", (3.4, 3.6, 3.0), (0, -radius - 0.6, 0), taper=(0.85, 1.0)), M["neige_taille"]),
             (bx(f"{name}_porte", (2.0, 0.3, 2.2), (0, -radius - 2.45, 0)), M["ombre_bleue"]),
             (bx(f"{name}_fenetre", (1.2, 0.3, 0.9), (radius * 0.6, -radius * 0.72, 2.0), (0, 0, -38)), M["verre_chaud"])]
    for k in range(4):  # paquets de neige autour
        a = r.uniform(0, 2 * math.pi)
        items.append((hull(f"{name}_tas{k}", r, (1.8, 1.4, 0.9), at=(math.cos(a) * (radius + 1.4), math.sin(a) * (radius + 1.4), -0.1)),
                      M["neige"]))
    low = finish(items, bevel=0.1, max_bevel=0.2, segments=2, angle=20)
    return assemble(name, low), None


def sled(name: str, seed: int = 18):
    """Traîneau de bois rouge chargé de cadeaux : patins recourbés, ridelles, 3 paquets à rubans."""
    M = gm()
    items = []
    for side in (-1, 1):
        y = side * 1.1
        pts = [Vector((-2.4, y, 0.15)), Vector((1.8, y, 0.15)), Vector((2.6, y, 0.7)), Vector((2.5, y, 1.5))]
        for k in range(3):
            items.append((strut(f"{name}_patin{side}_{k}", pts[k], pts[k + 1], 0.3, 0.3), M["fer"]))
        for x in (-1.6, 0.0, 1.4):
            items.append((bx(f"{name}_montant{side}_{x}", (0.3, 0.3, 0.6), (x, y, 0.25)), M["bois_givre"]))
    items.append((bx(f"{name}_plateau", (4.6, 2.6, 0.35), (-0.2, 0, 0.85)), M["laine_rouge"]))
    for side in (-1, 1):
        items.append((bx(f"{name}_ridelle{side}", (4.4, 0.25, 0.7), (-0.2, side * 1.2, 1.2)), M["laine_rouge"]))
    items.append((bx(f"{name}_dossier", (0.3, 2.6, 1.6), (-2.3, 0, 1.2)), M["laine_rouge"]))
    for k, (mat, s, x, y) in enumerate((("cadeau_vert", 1.2, -1.2, -0.4), ("cadeau_bleu", 0.9, 0.2, 0.4),
                                        ("verre_chaud", 0.8, 0.9, -0.5))):
        items.append((bx(f"{name}_cadeau{k}", (s, s, s), (x, y, 1.2), (0, 0, k * 20)), M[mat]))
        items.append((bx(f"{name}_ruban{k}", (s + 0.05, 0.2, s + 0.05), (x, y, 1.18), (0, 0, k * 20)), M["neige"]))
    low = finish(items, bevel=0.12, max_bevel=0.1, segments=2, angle=30)
    return assemble(name, low), None


def snowman(name: str, seed: int = 19):
    """Bonhomme de neige : 3 boules facettées, yeux et boutons de charbon, nez carotte, écharpe rouge, chapeau, bras."""
    M = gm()
    r = random.Random(seed)
    items = []
    z = 0.0
    for k, s in enumerate((3.0, 2.3, 1.7)):
        items.append((hull(f"{name}_boule{k}", r, (s, s, s * 0.95), points=26, flat_top=0.95, at=(0, 0, z - 0.15)),
                      M["neige"]))
        z += s * 0.82
    head_z = 3.0 * 0.82 + 2.3 * 0.82
    for side in (-1, 1):
        items.append((bx(f"{name}_oeil{side}", (0.25, 0.2, 0.25), (side * 0.35, -0.8, head_z + 1.0)), M["charbon_noir"]))
    items.append((bx(f"{name}_nez", (0.32, 1.0, 0.32), (0, -0.95, head_z + 0.62), (90, 0, 0), taper=(0.1, 0.1)), M["carotte"]))
    for k in range(3):
        items.append((bx(f"{name}_bouton{k}", (0.25, 0.2, 0.25), (0, -1.12, 3.0 * 0.82 + 0.3 + k * 0.55)), M["charbon_noir"]))
    items.append((bx(f"{name}_echarpe", (2.0, 2.0, 0.4), (0, 0, head_z - 0.1), (0, 0, 45)), M["laine_rouge"]))
    items.append((bx(f"{name}_pan", (0.5, 0.25, 1.2), (0.6, -0.85, head_z - 1.0), (0, -8, 0)), M["laine_rouge"]))
    items.append((bx(f"{name}_bord", (1.7, 1.7, 0.2), (0, 0, head_z + 1.5)), M["charbon_noir"]))
    items.append((bx(f"{name}_chapeau", (1.1, 1.1, 1.0), (0, 0, head_z + 1.65)), M["charbon_noir"]))
    for side in (-1, 1):
        a = Vector((side * 1.0, 0, 3.0 * 0.82 + 1.0))
        b = a + Vector((side * 1.6, 0, 0.9))
        items.append((strut(f"{name}_bras{side}", a, b, 0.2, 0.2), M["ecorce_froide"]))
    low = finish(items, bevel=0.1, max_bevel=0.1, segments=2, angle=25)
    return assemble(name, low), None


# =====================================================================================================================
# Catalogue
# =====================================================================================================================

GLACE = {
    "Glace_Glacier": (lambda n: glacier(n, seed=4), 1024),
    "Glace_Sapin": (lambda n: pine(n, seed=5, height=15.0), 1024),
    "Glace_SapinPetit": (lambda n: pine(n, seed=21, height=9.0), 512),
    "Glace_Rocher": (lambda n: snowy_rock(n, seed=6), 1024),
    "Glace_Cristaux": (lambda n: ice_crystals(n, seed=7), 512),
    "Glace_Congere": (lambda n: snowdrift(n, seed=8), 512),
    "Glace_Touffe": (lambda n: frost_tuft(n, seed=9), 512),
    "Glace_Pic": (lambda n: ice_spire(n, seed=10), 1024),
    "Glace_BlocMammouth": (lambda n: frozen_mammoth(n, seed=11), 1024),
    "Glace_PorteGlace": (lambda n: ice_gate(n, seed=12), 1024),
    "Glace_Lanterne": (lambda n: lantern(n, seed=13), 512),
    "Glace_Dalle": (lambda n: snow_slab(n, seed=14), 512),
    "Glace_Barriere": (lambda n: log_fence(n, seed=15), 1024),
    "Glace_Escalier": (lambda n: snow_stairs(n, seed=16), 1024),
    "Glace_Igloo": (lambda n: igloo(n, seed=17), 1024),
    "Glace_Traineau": (lambda n: sled(n, seed=18), 512),
    "Glace_Bonhomme": (lambda n: snowman(n, seed=19), 512),
}

E.BUILDERS.update(GLACE)
E.WORLDS["Glace"] = list(GLACE)
