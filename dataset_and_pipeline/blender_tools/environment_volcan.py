"""Décors du monde Volcan (3e palier) — « La Forge du Titan ». Même langage que la Prairie et le Désert : blocs
biseautés, tenons sur les faces du dessus de la pierre taillée et de la cendre. Charte : map_art_bible_volcan.json.

**Aucune lueur** (pas d'émission, donc aucun _Emissive.png à envoyer : avertissement de modération du 25 oct.). La lave
est une COULEUR (orange-jaune saturé) ; elle apparaît aussi dans les creux du basalte (couleur des creux = orange). La
vraie lumière viendra du Neon déjà en jeu (chemins, haut du mur) et de PointLight posées dans Roblox.

Importé par environment_recipes.catalog("Volcan") : ajoute ses décors (préfixe « Volcan_ ») à E.BUILDERS et sa liste à
E.WORLDS["Volcan"]. Repère : pivot au sol au centre, devant = -Y, 1 unité = 1 stud.
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
from environment_recipes import assemble, bx, finish, hull

# =====================================================================================================================
# Matériaux
# =====================================================================================================================


def vm() -> dict[str, bpy.types.Material]:
    M = E.mats()
    if "basalte" in M and M["basalte"].name in bpy.data.materials:
        return M
    W = S.create_stylized_edge_wear_material
    stone = dict(brush_scale=0.22, grain_scale=3.0, edge_radius=0.18, cavity_distance=1.0, bump_strength=0.5)
    M.update({
        # creux orange = lave entre les pierres (couleur seulement)
        "basalte": W("M_Basalte", base="#2E282C", edge="#6E6268", cavity="#FF5A14", accent="#2E282C", crackle=0.3,
                     crackle_scale=0.6, wear=0.75, roughness=0.7, **stone),
        "basalte_taille": W("M_BasalteTaille", base="#3A3438", edge="#7E7278", cavity="#E04A10", accent="#3A3438",
                            crackle=0.15, crackle_scale=0.8, wear=0.6, roughness=0.66, studs=1.0, **stone),
        "cendre": W("M_Cendre", base="#5A5256", edge="#A49AA0", cavity="#2A2428", wear=0.8, roughness=0.9, studs=1.0,
                    **stone),
        "obsid_v": W("M_ObsidienneVolcan", base="#1E1A26", edge="#9A7AE8", cavity="#FF4A10", accent="#2A2238", wear=0.8,
                     roughness=0.22, **stone),
        "lave": W("M_Lave", base="#FF7A1A", edge="#FFE27A", cavity="#C8320A", accent="#FFA03A", wear=0.5, roughness=0.3,
                  brush_scale=0.45, edge_radius=0.1, cavity_distance=0.6, crackle=0.25, crackle_scale=1.2),
        "lave_coeur": W("M_LaveCoeur", base="#FFC23A", edge="#FFF2B0", cavity="#FF6A1A", wear=0.4, roughness=0.3,
                        brush_scale=0.5, edge_radius=0.06),
        "charbon": W("M_BoisCharbon", base="#2E2624", edge="#6E564C", cavity="#FF5A14", wood=0.9, wood_axis="Z",
                     wood_scale=0.8, roughness=0.85, crackle=0.25, crackle_scale=1.0, brush_scale=0.5, grain_scale=6.0,
                     edge_radius=0.08, cavity_distance=0.5, wear=0.75),
        "cendre_herbe": W("M_HerbeCendre", base="#6A3A30", edge="#C86A4A", cavity="#2A1410", wear=0.9, roughness=0.7,
                          brush_scale=0.8, edge_radius=0.05, cavity_distance=0.4),
        "braise_herbe": W("M_HerbeBraise", base="#B8442A", edge="#FF9A5A", cavity="#4A1A10", wear=0.9, roughness=0.6,
                          brush_scale=0.8, edge_radius=0.05, cavity_distance=0.4),
        "saucisse": W("M_Saucisse", base="#C8603A", edge="#F0A070", cavity="#6A2A1A", wear=0.5, roughness=0.45,
                      brush_scale=0.6, edge_radius=0.06),
        "fer_v": S.create_etched_metal_or_gold("M_FerForge", tint="#5A5E68", rust=0.3, roughness=0.5, scratches=0.6),
        "bronze": S.create_etched_metal_or_gold("M_Bronze", tint="#C8783A", hammered=0.5, rust=0.1),
        "cristal_feu": S.create_stylized_crystal_or_gem("M_CristalFeu", core="#5A0A0A", mid="#FF4A1A", rim="#FFD27A",
                                                        emission=0.0),
    })
    return M


def hexcol(name: str, radius: float, height: float, at=(0, 0, 0), phase: float = 0.0, tilt=(0, 0)) -> bpy.types.Object:
    """Colonne de basalte : prisme hexagonal (révolution à 6 pans), légèrement penché."""
    obj = G.lathe(name, [(0, 0), (radius, 0), (radius * 0.97, height), (0, height)], segments=6, phase=phase)
    return G.transform(obj, Matrix.Translation(at) @ Matrix.Rotation(math.radians(tilt[0]), 4, "X")
                       @ Matrix.Rotation(math.radians(tilt[1]), 4, "Y"))


def flame(prefix: str, base, s: float, rnd: random.Random):
    """Flamme figée en blocs (orange autour, jaune au cœur) : lisible sans lueur."""
    M = vm()
    out = []
    bx_, by_, bz_ = base
    for k, (w, h, dz, mat) in enumerate(((1.6, 1.6, 0.0, "lave"), (1.1, 1.6, 1.2, "lave"), (0.7, 1.4, 2.4, "lave_coeur"),
                                         (0.9, 1.0, 0.5, "lave_coeur"))):
        out.append((bx(f"{prefix}_{k}", (w * s, w * s, h * s), (bx_ + rnd.uniform(-0.15, 0.15) * s,
                                                                  by_ + rnd.uniform(-0.15, 0.15) * s, bz_ + dz * s),
                       (0, 0, rnd.uniform(0, 90)), taper=(0.55, 0.55)), M[mat]))
    return out


# =====================================================================================================================
# Nature
# =====================================================================================================================

def basalt_organs(name: str, seed: int = 3, width: float = 36.0, rows: int = 4):
    """Orgues de basalte en gradins : colonnes hexagonales serrées, basses devant, hautes derrière (~30 studs),
    plaques de cendre à tenons sur une partie des sommets."""
    M = vm()
    r = random.Random(seed)
    items = []
    R = 2.3
    for row in range(rows):
        y = -5.5 + row * R * 1.5
        x = -width / 2 + R + (R * 0.87 if row % 2 else 0)
        while x < width / 2 - R * 0.5:
            h = 9 + row * 6.5 + r.uniform(-2.5, 3.0)
            col = hexcol(f"{name}_col{row}_{len(items)}", R * r.uniform(0.9, 1.05), h, (x, y, -0.5), r.uniform(0, 1),
                         (r.uniform(-2, 2), r.uniform(-2, 2)))
            items.append((col, M["basalte"]))
            if r.random() < 0.45:
                cap = hexcol(f"{name}_cendre{row}_{len(items)}", R * 0.93, 0.5, (x, y, h - 0.55), r.uniform(0, 1))
                items.append((cap, M["cendre"]))
            x += R * 1.74
    # un seul segment de chanfrein : ~45 colonnes à 6 pans, sinon on dépasse 6 000 triangles
    low = finish(items, bevel=0.06, max_bevel=0.25, segments=1, angle=25)
    return assemble(name, low), None


def volcanic_rock(name: str, seed: int = 4):
    vm()
    return E.rock(name, seed=seed, size=(9, 7, 6), kind="basalte")


def obsidian_shards(name: str, seed: int = 5, height: float = 12.0):
    """Éclats d'obsidienne penchés sur un socle de basalte, bouquet de cristaux de feu (sans lueur)."""
    M = vm()
    r = random.Random(seed)
    items = [(hull(f"{name}_socle", r, (8, 7, 3.0), flat_top=0.6), M["basalte"])]
    for k in range(5):
        h = height * r.uniform(0.45, 1.0) * (1.0 if k else 1.15)
        w = r.uniform(1.8, 3.0)
        a = k * 2.4 + r.uniform(-0.3, 0.3)
        d = 0.0 if k == 0 else r.uniform(1.4, 2.8)
        items.append((hull(f"{name}_eclat{k}", r, (w, w * r.uniform(0.8, 1.1), h), points=18, flat_top=0.98,
                           at=(math.cos(a) * d, math.sin(a) * d, -0.4),
                           rot=(r.uniform(-16, 16), r.uniform(-16, 16), r.uniform(0, 360))), M["obsid_v"]))
    items.append((G.crystal_cluster(f"{name}_cristaux", count=5, origin=(3.0, -1.8, 1.2), spread=1.2, radius=(0.35, 0.6),
                                    height=(1.6, 3.2), seed=seed, facing=-0.6, arc=2.0), M["cristal_feu"]))
    low = finish(items, bevel=0.06, max_bevel=0.25, segments=2, angle=20)
    return assemble(name, low), None


def vent(name: str, seed: int = 6):
    """Cheminée volcanique : cône en gradins à 8 pans, cratère rempli de lave, blocs éboulés au pied."""
    M = vm()
    r = random.Random(seed)
    prof = [(0, 0), (4.6, 0), (4.3, 1.4), (3.5, 1.6), (3.3, 3.0), (2.5, 3.2), (2.3, 4.6), (1.7, 4.6), (1.5, 3.7), (0, 3.7)]
    items = [(G.lathe(f"{name}_cone", prof, segments=8, phase=0.2), M["basalte"])]
    items.append((G.lathe(f"{name}_lave", [(0, 3.68), (1.55, 3.68), (1.55, 3.95), (0, 3.95)], segments=8, phase=0.2),
                  M["lave"]))
    items += flame(f"{name}_flamme", (0, 0, 3.9), 0.75, r)
    for k in range(4):
        a = k * math.pi / 2 + r.uniform(-0.3, 0.3)
        items.append((hull(f"{name}_bloc{k}", r, (1.8, 1.6, 1.4), at=(math.cos(a) * 5.0, math.sin(a) * 5.0, 0)),
                      M["basalte"]))
    low = finish(items, bevel=0.08, max_bevel=0.2, segments=2, angle=25)
    return assemble(name, low), None


def charred_tree(name: str, seed: int = 7, height: float = 14.0):
    """Arbre calciné : tronc tordu en sections de charbon (lave dans les fissures), branches nues qui se divisent,
    braises sur quelques bouts de branches."""
    M = vm()
    r = random.Random(seed)
    items = [(bx(f"{name}_pied", (3.6, 3.4, 1.4), (0, 0, -0.2), (0, 0, r.uniform(0, 90)), taper=(0.66, 0.66)), M["charbon"])]
    n = 5
    z = 0.8
    lean_dir = r.uniform(0, 2 * math.pi)
    top = Vector((0, 0, 0))
    for i in range(n):
        t = i / (n - 1)
        s = 2.4 - 1.1 * t
        h = height * 0.55 / n * 1.1
        off = 1.6 * t * t
        cx, cy = math.cos(lean_dir) * off, math.sin(lean_dir) * off
        items.append((bx(f"{name}_tronc{i}", (s, s * 0.9, h), (cx, cy, z), (0, 0, i * 17), taper=(0.86, 0.86)), M["charbon"]))
        z += h * 0.9
        top = Vector((cx, cy, z))
    for k in range(4):
        a = lean_dir + k * math.pi / 2 + r.uniform(-0.4, 0.4)
        base = top - Vector((0, 0, r.uniform(0.6, 2.4)))
        mid = base + Vector((math.cos(a) * 2.8, math.sin(a) * 2.8, r.uniform(2.2, 3.4)))
        items.append((strut(f"{name}_branche{k}", base, mid, 0.8, 0.75, taper=(0.7, 0.7)), M["charbon"]))
        for j in (-1, 1):
            b = a + j * 0.6
            tip = mid + Vector((math.cos(b) * 2.0, math.sin(b) * 2.0, r.uniform(1.2, 2.2)))
            items.append((strut(f"{name}_rameau{k}_{j}", mid, tip, 0.45, 0.42, taper=(0.5, 0.5)), M["charbon"]))
            if r.random() < 0.35:
                items.append((bx(f"{name}_braise{k}_{j}", (0.55, 0.55, 0.55), (tip.x, tip.y, tip.z - 0.2),
                                 (r.uniform(0, 40), r.uniform(0, 40), 0)), M["lave"]))
    for k in range(3):  # fissures de lave dans l'écorce
        a = r.uniform(0, 2 * math.pi)
        zz = r.uniform(1.5, height * 0.4)
        items.append((bx(f"{name}_fissure{k}", (0.35, 0.3, 1.6), (math.cos(a) * 1.05, math.sin(a) * 1.05, zz),
                         (0, 0, math.degrees(a))), M["lave"]))
    low = finish(items, bevel=0.12, max_bevel=0.2, segments=2, angle=30)
    return assemble(name, low), None


def fire_crystals(name: str, seed: int = 8):
    """Bouquet de cristaux de feu sur un rocher de basalte (couleur seulement, sans lueur)."""
    M = vm()
    r = random.Random(seed)
    items = [(hull(f"{name}_rocher", r, (4.4, 4.0, 2.2), flat_top=0.6), M["basalte"]),
             (G.crystal_cluster(f"{name}_grand", count=6, origin=(0, 0, 1.4), spread=1.0, radius=(0.4, 0.75),
                                height=(1.8, 3.8), seed=seed, tilt=(5, 28)), M["cristal_feu"]),
             (G.crystal_cluster(f"{name}_petit", count=4, origin=(2.0, -1.2, 0.4), spread=0.6, radius=(0.25, 0.45),
                                height=(0.8, 1.6), seed=seed + 3, facing=-0.4, arc=1.6), M["cristal_feu"])]
    low = finish(items, bevel=0.06, max_bevel=0.15, segments=2, angle=20)
    return assemble(name, low), None


def ash_tuft(name: str, seed: int = 9):
    vm()
    return E.grass_tuft(name, seed=seed, height=2.6, tones=("cendre_herbe", "braise_herbe"))


# =====================================================================================================================
# Forge
# =====================================================================================================================

def forge_gate(name: str, seed: int = 10, opening: float = 18.0):
    """Porte de forge : piliers de basalte cerclés de fer, linteau en forme d'enclume en bronze, chaînes, emblème."""
    M = vm()
    r = random.Random(seed)
    items = []
    half = opening / 2
    for side in (-1, 1):
        px = side * (half + 2.4)
        items.append((bx(f"{name}_socle{side}", (5.6, 5.0, 1.4), (px, 0, 0)), M["basalte_taille"]))
        z = 1.4
        for k in range(3):
            items.append((bx(f"{name}_bloc{side}_{k}", (4.4, 3.8, 5.4), (px + r.uniform(-0.1, 0.1), 0, z),
                             (0, 0, r.uniform(-2, 2)), taper=(0.96, 0.96)), M["basalte"]))
            items.append((bx(f"{name}_cercle{side}_{k}", (4.7, 4.1, 0.55), (px, 0, z + 4.6)), M["fer_v"]))
            z += 5.45
        items.append((bx(f"{name}_chapiteau{side}", (5.4, 4.8, 1.0), (px, 0, z)), M["bronze"]))
    top = 1.4 + 3 * 5.45 + 1.0
    items.append((bx(f"{name}_linteau", (opening + 4.0, 4.2, 2.6), (0, 0, top)), M["bronze"]))
    for side in (-1, 1):  # cornes de l'enclume
        items.append((bx(f"{name}_corne{side}", (4.8, 3.0, 1.8), (side * (opening / 2 + 4.2), 0, top + 0.8),
                         (0, side * 90, 0), taper=(0.15, 0.6)), M["bronze"]))
    items.append((bx(f"{name}_table", (opening + 2.0, 3.6, 0.8), (0, 0, top + 2.6)), M["fer_v"]))
    emb = G.lathe(f"{name}_embleme", [(0, -0.35), (2.0, -0.35), (2.0, 0.35), (0, 0.35)], segments=8, phase=math.pi / 8)
    G.transform(emb, Matrix.Translation((0, -2.3, top + 1.3)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    items.append((emb, M["fer_v"]))
    items.append((bx(f"{name}_gemme", (1.4, 0.5, 1.4), (0, -2.55, top + 0.6), (0, 45, 0)), M["lave"]))
    for side in (-1, 1):  # chaînes qui pendent du linteau
        for k in range(5):
            items.append((bx(f"{name}_maillon{side}_{k}", (0.5, 0.25, 0.9), (side * (half - 1.5), -1.6, top - 1.1 - k * 0.85),
                             (0, 0, 90 * (k % 2))), M["fer_v"]))
    low = finish(items, bevel=0.1, max_bevel=0.25, segments=2, angle=25)
    return assemble(name, low), None


def brazier_pillar(name: str, seed: int = 11, height: float = 10.0):
    """Pilier-brasier : colonne de basalte hexagonale cerclée de fer, coupe de bronze, braises et flamme figée."""
    M = vm()
    r = random.Random(seed)
    items = [(bx(f"{name}_socle", (4.6, 4.6, 1.2), (0, 0, 0)), M["basalte_taille"]),
             (hexcol(f"{name}_colonne", 1.6, height, (0, 0, 1.1), 0.3), M["basalte"])]
    for k, z in enumerate((3.0, 7.5)):
        items.append((hexcol(f"{name}_cercle{k}", 1.75, 0.55, (0, 0, z), 0.3), M["fer_v"]))
    bowl = G.lathe(f"{name}_coupe", [(0, height + 1.0), (0.9, height + 1.0), (2.2, height + 1.6), (2.5, height + 2.4),
                                     (2.2, height + 2.45), (0, height + 2.0)], segments=8)
    items.append((bowl, M["bronze"]))
    for k in range(6):
        a = k * math.pi / 3
        items.append((bx(f"{name}_braise{k}", (0.8, 0.8, 0.6), (math.cos(a) * 1.0, math.sin(a) * 1.0, height + 1.95),
                         (0, 0, math.degrees(a))), M["lave"]))
    items += flame(f"{name}_flamme", (0, 0, height + 2.1), 1.0, r)
    low = finish(items, bevel=0.1, max_bevel=0.2, segments=2, angle=25)
    return assemble(name, low), None


def anvil(name: str, seed: int = 12):
    """Enclume géante sur une souche de basalte, marteau de forge appuyé contre elle."""
    M = vm()
    r = random.Random(seed)
    items = [(hull(f"{name}_souche", r, (5.2, 4.6, 3.2), flat_top=0.95), M["basalte"]),
             (bx(f"{name}_pied", (3.0, 2.4, 1.6), (0, 0, 3.0), taper=(0.7, 0.8)), M["fer_v"]),
             (bx(f"{name}_corps", (5.2, 2.6, 1.8), (0.4, 0, 4.4)), M["fer_v"]),
             (bx(f"{name}_corne", (3.4, 2.0, 1.4), (4.4, 0, 4.7), (0, 90, 0), taper=(0.1, 0.6)), M["fer_v"]),
             (bx(f"{name}_table", (5.6, 2.8, 0.5), (0.4, 0, 6.1)), M["bronze"])]
    handle_a, handle_b = Vector((-3.6, -1.8, 0)), Vector((-2.6, -1.4, 6.0))
    items.append((strut(f"{name}_manche", handle_a, handle_b, 0.5, 0.5), M["charbon"]))
    items.append((bx(f"{name}_tete", (2.6, 1.4, 1.4), (handle_b.x, handle_b.y, handle_b.z - 0.4), (0, -9, 10)), M["fer_v"]))
    items.append((bx(f"{name}_lingot", (1.8, 0.8, 0.5), (0.6, 0.3, 6.6), (0, 0, 15)), M["lave"]))
    low = finish(items, bevel=0.1, max_bevel=0.2, segments=2, angle=25)
    return assemble(name, low), None


def forge_slab(name: str, seed: int = 13, size=(8.0, 6.0, 1.2)):
    """Dalle de basalte fendue, glyphes de bronze en couronne, cœur de lave."""
    M = vm()
    r = random.Random(seed)
    sx, sy, sz = size
    items = []
    cut = r.uniform(-0.6, 0.6)
    for k, ((cx, cy), (w, d)) in enumerate((((-sx / 4 + cut / 2 - 0.05, -sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((-sx / 4 + cut / 2 - 0.05, sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((sx / 4 + cut / 2 + 0.05, 0), (sx / 2 - cut - 0.1, sy - 0.1)))):
        items.append((bx(f"{name}_morceau{k}", (w, d, sz), (cx, cy, r.uniform(-0.12, 0.05)),
                         (r.uniform(-1.2, 1.2), r.uniform(-1.2, 1.2), r.uniform(-1.5, 1.5))), M["basalte_taille"]))
    for k in range(8):
        a = k * math.pi / 4
        items.append((bx(f"{name}_glyphe{k}", (0.7 if k % 2 else 1.3, 0.3, 0.12), (math.cos(a) * 1.9, math.sin(a) * 1.9, sz - 0.05),
                         (0, 0, math.degrees(a) + 90)), M["bronze"]))
    items.append((bx(f"{name}_coeur", (1.1, 1.1, 0.14), (0, 0, sz - 0.05), (0, 0, 45)), M["lave"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def rampart(name: str, seed: int = 14, length: float = 12.0):
    """Rempart de base : blocs de basalte taillé, chaperon de cendre, piques de fer, bandeau de bronze devant."""
    M = vm()
    r = random.Random(seed)
    items = []
    x = -length / 2
    while x < length / 2 - 0.3:
        w = min(r.uniform(2.6, 3.8), length / 2 - x)
        items.append((bx(f"{name}_bloc{len(items)}", (w - 0.08, 2.0, 2.6), (x + w / 2, 0, 0), (0, 0, r.uniform(-0.8, 0.8)),
                         taper=(0.97, 0.93)), M["basalte_taille"]))
        x += w
    items.append((bx(f"{name}_chaperon", (length, 2.3, 0.5), (0, 0, 2.55)), M["cendre"]))
    items.append((bx(f"{name}_bandeau", (length, 0.25, 0.45), (0, -1.1, 1.6)), M["bronze"]))
    for k in range(7):
        px = -length / 2 + (k + 0.5) * length / 7
        items.append((bx(f"{name}_pique{k}", (0.55, 0.55, 1.8), (px, 0, 3.0), taper=(0.05, 0.05)), M["fer_v"]))
    low = finish(items, bevel=0.12, max_bevel=0.15, segments=2, angle=30)
    return assemble(name, low), None


def basalt_stairs(name: str, seed: int = 15):
    vm()
    return E.stairs(name, seed=seed, step_mat="basalte_taille", cheek_mat="basalte")


def mine_cart(name: str, seed: int = 16):
    """Chariot de minerai : caisse de planches calcinées cerclée de fer, 4 roues, tas de lave refroidie et cristaux."""
    M = vm()
    r = random.Random(seed)
    items = [(bx(f"{name}_caisse", (4.2, 2.8, 2.0), (0, 0, 1.1), taper=(1.08, 1.08)), M["charbon"])]
    for k, z in enumerate((1.2, 2.8)):
        items.append((bx(f"{name}_cercle{k}", (4.4 + 0.1 * k, 3.0 + 0.1 * k, 0.3), (0, 0, z)), M["fer_v"]))
    for sx in (-1, 1):
        for sy in (-1, 1):
            wheel = G.lathe(f"{name}_roue{sx}{sy}", [(0, -0.25), (0.75, -0.25), (0.75, 0.25), (0, 0.25)], segments=10)
            G.transform(wheel, Matrix.Translation((sx * 1.3, sy * 1.55, 0.75)) @ Matrix.Rotation(math.radians(90), 4, "X"))
            items.append((wheel, M["fer_v"]))
    for k in range(5):
        items.append((hull(f"{name}_minerai{k}", r, (1.3, 1.2, 1.0), at=(r.uniform(-1.2, 1.2), r.uniform(-0.7, 0.7), 2.7)),
                      M["lave"] if k % 2 else M["basalte"]))
    items.append((G.crystal_cluster(f"{name}_cristaux", count=3, origin=(0.6, 0.2, 3.0), spread=0.5, radius=(0.2, 0.35),
                                    height=(0.8, 1.4), seed=seed), M["cristal_feu"]))
    low = finish(items, bevel=0.1, max_bevel=0.12, segments=2, angle=25)
    return assemble(name, low), None


def cauldron(name: str, seed: int = 17):
    """Chaudron de forge sur 3 pieds, rempli de lave qui bouillonne."""
    M = vm()
    r = random.Random(seed)
    pot = G.lathe(f"{name}_marmite", [(0, 0.8), (1.0, 0.8), (1.9, 1.5), (2.1, 2.6), (1.8, 3.4), (2.0, 3.6), (1.7, 3.65),
                                      (1.55, 3.2), (0, 3.2)], segments=12)
    items = [(pot, M["fer_v"]),
             (G.lathe(f"{name}_lave", [(0, 3.15), (1.6, 3.15), (1.6, 3.35), (0, 3.35)], segments=12), M["lave"])]
    for k in range(3):
        a = k * 2 * math.pi / 3
        items.append((bx(f"{name}_pied{k}", (0.5, 0.5, 1.4), (math.cos(a) * 1.3, math.sin(a) * 1.3, 0)), M["fer_v"]))
    for k in range(4):
        a = r.uniform(0, 2 * math.pi)
        items.append((bx(f"{name}_bulle{k}", (0.45, 0.45, 0.3), (math.cos(a) * 0.8, math.sin(a) * 0.8, 3.35)), M["lave_coeur"]))
    low = finish(items, bevel=0.06, max_bevel=0.1, segments=2, angle=20)
    return assemble(name, low), None


def giant_grill(name: str, seed: int = 18):
    """Grill géant du Dragon Barbecue : foyer de fer sur pieds, braises, grille, saucisses, cheminée."""
    M = vm()
    r = random.Random(seed)
    items = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            items.append((bx(f"{name}_pied{sx}{sy}", (0.6, 0.6, 3.4), (sx * 4.2, sy * 1.8, 0)), M["fer_v"]))
    items.append((bx(f"{name}_foyer", (9.6, 4.4, 1.6), (0, 0, 3.2), taper=(1.06, 1.1)), M["fer_v"]))
    for k in range(9):
        items.append((hull(f"{name}_braise{k}", r, (1.2, 1.0, 0.6), at=(-4 + k, r.uniform(-1, 1), 4.6)), M["lave"]))
    for k in range(10):  # grille
        x = -4.3 + k * 0.95
        items.append((bx(f"{name}_barreau{k}", (0.22, 4.6, 0.22), (x, 0, 5.15)), M["fer_v"]))
    for k in range(5):  # saucisses
        a = r.uniform(-20, 20)
        items.append((bx(f"{name}_saucisse{k}", (0.8, 3.0, 0.8), (-3.4 + k * 1.7, r.uniform(-0.4, 0.4), 5.35), (0, 0, a),
                         taper=(0.85, 0.85)), M["saucisse"]))
    items.append((bx(f"{name}_cheminee", (1.2, 1.2, 4.0), (4.0, 1.6, 4.8)), M["fer_v"]))
    items.append((bx(f"{name}_chapeau", (1.8, 1.8, 0.4), (4.0, 1.6, 8.8)), M["bronze"]))
    items.append((bx(f"{name}_tablette", (2.6, 3.0, 0.3), (-6.2, 0, 4.4)), M["charbon"]))
    low = finish(items, bevel=0.1, max_bevel=0.12, segments=2, angle=30)
    return assemble(name, low), None


def golem_head(name: str, seed: int = 19):
    """Tête de golem de cendre à demi enterrée (yeux et bouche de lave), une main qui sort du sol à côté."""
    M = vm()
    r = random.Random(seed)
    items = [(bx(f"{name}_crane", (7.4, 6.6, 6.8), (0, 0, -1.2), (r.uniform(-4, 4), 6, 0), taper=(0.86, 0.86)), M["basalte"]),
             (bx(f"{name}_front", (7.0, 1.6, 1.4), (0, -3.2, 3.2), (6, 0, 0)), M["cendre"]),
             (bx(f"{name}_machoire", (6.0, 5.2, 1.8), (0, -0.6, -1.0)), M["basalte"])]
    for side in (-1, 1):
        items.append((bx(f"{name}_oeil{side}", (1.5, 0.5, 1.0), (side * 1.7, -3.35, 2.2)), M["lave"]))
        items.append((bx(f"{name}_pupille{side}", (0.7, 0.3, 0.5), (side * 1.7, -3.55, 2.45)), M["lave_coeur"]))
        items.append((bx(f"{name}_joue{side}", (1.8, 2.6, 2.4), (side * 3.6, -1.6, 0.4), (0, 0, side * 10)), M["cendre"]))
    items.append((bx(f"{name}_bouche", (3.6, 0.5, 0.6), (0, -3.3, 0.6)), M["lave"]))
    items.append((bx(f"{name}_paume", (3.6, 2.6, 1.6), (7.6, -2.0, 0.0), (0, -20, 15)), M["basalte"]))
    for k in range(4):
        items.append((bx(f"{name}_doigt{k}", (0.8, 0.8, 2.6 - abs(k - 1.5) * 0.4), (6.3 + k * 0.9, -2.2, 1.4), (0, -12, 0),
                         taper=(0.8, 0.8)), M["basalte"]))
    low = finish(items, bevel=0.14, max_bevel=0.3, segments=2, angle=30)
    return assemble(name, low), None


# =====================================================================================================================
# Catalogue
# =====================================================================================================================

VOLCAN = {
    "Volcan_Orgues": (lambda n: basalt_organs(n, seed=3), 1024),
    "Volcan_Roche": (lambda n: volcanic_rock(n, seed=4), 1024),
    "Volcan_Eclats": (lambda n: obsidian_shards(n, seed=5), 1024),
    "Volcan_Cheminee": (lambda n: vent(n, seed=6), 1024),
    "Volcan_ArbreCalcine": (lambda n: charred_tree(n, seed=7), 1024),
    "Volcan_Cristaux": (lambda n: fire_crystals(n, seed=8), 512),
    "Volcan_Touffe": (lambda n: ash_tuft(n, seed=9), 512),
    "Volcan_PorteForge": (lambda n: forge_gate(n, seed=10), 1024),
    "Volcan_PilierBrasier": (lambda n: brazier_pillar(n, seed=11), 1024),
    "Volcan_Enclume": (lambda n: anvil(n, seed=12), 1024),
    "Volcan_Dalle": (lambda n: forge_slab(n, seed=13), 512),
    "Volcan_Rempart": (lambda n: rampart(n, seed=14), 1024),
    "Volcan_Escalier": (lambda n: basalt_stairs(n, seed=15), 1024),
    "Volcan_Chariot": (lambda n: mine_cart(n, seed=16), 512),
    "Volcan_Chaudron": (lambda n: cauldron(n, seed=17), 512),
    "Volcan_Grill": (lambda n: giant_grill(n, seed=18), 1024),
    "Volcan_TeteGolem": (lambda n: golem_head(n, seed=19), 1024),
}

E.BUILDERS.update(VOLCAN)
E.WORLDS["Volcan"] = list(VOLCAN)
