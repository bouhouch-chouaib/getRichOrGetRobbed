"""Décors de la carte (phase 1.6) : nature, ruines et mobilier en blocs biseautés — Blender 4.2+ / 5.0.

Même langage que les familiers refaits (blocs chanfreinés de tailles variées, inclinés, empilés) et tenons Roblox sur
les faces tournées vers le haut de la pierre taillée, du bois et des feuillages (docs/DIRECTION_ARTISTIQUE.md). Aucune
primitive posée telle quelle : chaque pièce est un bloc effilé / penché, un profil de révolution à pans ou une enveloppe
convexe facettée, puis Bevel + Weighted Normal. Charte : dataset_and_pipeline/map_art_bible.json.

Chaque constructeur renvoie (low, high) : `low` = maillage de jeu (< 6 000 triangles), `high` = version détaillée à
projeter à la cuisson, ou None (le low est cuit sur lui-même : les tenons, veinures et fissures du shader passent dans
la Normal map). Pivot au sol au centre, devant = -Y, 1 unité = 1 stud.

    import environment_recipes as E
    low, high = E.build("ArbreMajestueux_A")      # ou E.BUILDERS[...] / E.tree(...)
    B.bake_asset(low, "ArbreMajestueux_A", high=high, out_dir=...)
"""

from __future__ import annotations

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import procedural_geometry_recipes as G
import shader_node_library as S
from block_creatures import _matrix, block, stepped_plate

# =====================================================================================================================
# Matériaux (palette de map_art_bible.json)
# =====================================================================================================================

_MATS: dict[str, bpy.types.Material] = {}


def mats() -> dict[str, bpy.types.Material]:
    """Crée une fois les matériaux des décors (échelles de bruit pensées pour des objets de 3 à 40 studs)."""
    if _MATS and all(m.name in bpy.data.materials for m in _MATS.values()):
        return _MATS
    W = S.create_stylized_edge_wear_material
    stone = dict(brush_scale=0.22, grain_scale=3.0, edge_radius=0.18, cavity_distance=1.0, bump_strength=0.45)
    wood = dict(brush_scale=0.5, grain_scale=6.0, edge_radius=0.08, cavity_distance=0.5, wear=0.75)
    leaf = dict(brush_scale=0.35, grain_scale=4.0, edge_radius=0.16, cavity_distance=1.2, wear=0.85, roughness=0.55,
                studs=1.0)
    _MATS.update({
        "calcaire": W("M_Calcaire", base="#E8D2A8", edge="#FFF4DC", cavity="#7E6E9E", accent="#F2B97C", crackle=0.12,
                      crackle_scale=0.9, wear=0.75, roughness=0.78, **stone),
        "calcaire_taille": W("M_CalcaireTaille", base="#E2CBA0", edge="#FFF4DC", cavity="#7E6E9E", accent="#F0C590",
                             crackle=0.15, crackle_scale=0.7, wear=0.6, roughness=0.72, studs=1.0, **stone),
        "obsidienne": W("M_Obsidienne", base="#2E2547", edge="#8C7AE0", cavity="#120E1E", accent="#3C2F66", wear=0.8,
                        roughness=0.28, magma="#B46CFF", magma_core="#F3E2FF", magma_scale=0.22, magma_width=0.035,
                        magma_glow=2.2, **stone),
        "ruine": W("M_PierreRuine", base="#B8B3C8", edge="#F0EEF8", cavity="#5A5577", accent="#8FCB6E", crackle=0.45,
                   crackle_scale=0.6, wear=0.7, roughness=0.75, studs=1.0, **stone),
        "rune": W("M_Rune", base="#5CF2FF", edge="#E6FFFF", cavity="#1A8AA8", wear=0.2, roughness=0.35, emission=2.6,
                  brush_scale=0.6, edge_radius=0.05),
        "bois_clair": W("M_BoisClair", base="#E08A3C", edge="#FFC27A", cavity="#6A3A1E", wood=1.0, wood_axis="Z",
                        wood_scale=1.2, roughness=0.68, studs=1.0, **wood),
        "bois_planche": W("M_BoisPlanche", base="#D9823A", edge="#FFC27A", cavity="#6A3A1E", wood=1.0, wood_axis="X",
                          wood_scale=1.2, roughness=0.68, studs=1.0, **wood),
        "bois_sombre": W("M_BoisSombre", base="#8A5A3A", edge="#C99468", cavity="#3A2216", wood=0.9, wood_axis="Z",
                         wood_scale=1.0, roughness=0.72, **wood),
        "ecorce": W("M_Ecorce", base="#9A6440", edge="#DDA878", cavity="#4A2A1C", wood=1.2, wood_axis="Z",
                    wood_scale=0.7, roughness=0.8, crackle=0.2, crackle_scale=0.8, **wood),
        "feuille_a": W("M_FeuilleA", base="#5ED13A", edge="#D2F56A", cavity="#1F6B3A", **leaf),
        "feuille_b": W("M_FeuilleB", base="#89E83E", edge="#E6FF8A", cavity="#2E7A34", **leaf),
        "feuille_c": W("M_FeuilleC", base="#3FB046", edge="#B8EE62", cavity="#175A36", **leaf),
        "rose_a": W("M_FeuilleRoseA", base="#FF8FC8", edge="#FFE6F3", cavity="#A8407E", **leaf),
        "rose_b": W("M_FeuilleRoseB", base="#FFB3DA", edge="#FFF0F8", cavity="#B05A8C", **leaf),
        "herbe": W("M_Herbe", base="#6FD83A", edge="#D8F870", cavity="#2C7A2E", wear=0.9, roughness=0.6,
                   brush_scale=0.8, edge_radius=0.05, cavity_distance=0.4),
        "champi_chapeau": W("M_ChampiChapeau", base="#FF4FA0", edge="#FFB0DA", cavity="#8A1E5A", wear=0.8,
                            roughness=0.45, studs=1.0, brush_scale=0.4, edge_radius=0.15, cavity_distance=0.8),
        "champi_pied": W("M_ChampiPied", base="#F4E9D8", edge="#FFFFFF", cavity="#B49AA8", wear=0.6, roughness=0.6,
                         brush_scale=0.5, edge_radius=0.1, cavity_distance=0.6),
        "champi_lueur": W("M_ChampiLueur", base="#7CF8FF", edge="#E8FFFF", cavity="#2AA8C8", wear=0.3, roughness=0.4,
                          emission=2.8, brush_scale=0.6, edge_radius=0.08, studs=1.0),
        "points": W("M_PointsBlancs", base="#FFF4FB", edge="#FFFFFF", cavity="#D8B8C8", wear=0.3, roughness=0.5,
                    edge_radius=0.05),
        "fer": S.create_etched_metal_or_gold("M_Fer", tint="#9AA3B5", rust=0.15, roughness=0.42, scratches=0.6),
        "or": S.create_etched_metal_or_gold("M_OrDecor", tint="#FFC830", hammered=0.4),
        "cristal": S.create_stylized_crystal_or_gem("M_CristalTotem", core="#0B3D6B", mid="#38D8FF", rim="#E6FFFF",
                                                    emission=1.6),
        "cristal_violet": S.create_stylized_crystal_or_gem("M_CristalViolet", core="#2A1050", mid="#A86CFF",
                                                           rim="#F0E2FF", emission=1.4),
    })
    return _MATS


# =====================================================================================================================
# Briques de base
# =====================================================================================================================

def bx(name: str, size, at=(0, 0, 0), rot=(0, 0, 0), taper=(1.0, 1.0), shift=(0.0, 0.0)) -> bpy.types.Object:
    """Bloc posé : `at` = centre du dessous (avant rotation)."""
    return block(name, size, (at[0], at[1], at[2] + size[2] / 2), rot, taper, shift)


def hull(name: str, rnd: random.Random, size, points: int = 26, flat_top: float = 0.72,
         at=(0, 0, 0), rot=(0, 0, 0)) -> bpy.types.Object:
    """Enveloppe convexe facettée (rocher taillé) : grandes facettes planes, dessus aplati, pied au sol."""
    sx, sy, sz = size
    bm = bmesh.new()
    for _ in range(points):
        u = rnd.uniform(0, 2 * math.pi)
        v = rnd.uniform(-1.0, 1.0)
        r = math.sqrt(1 - v * v) * rnd.uniform(0.82, 1.0)
        z = min(v * sz / 2, sz / 2 * flat_top)
        bm.verts.new((sx / 2 * r * math.cos(u), sy / 2 * r * math.sin(u), max(z, -sz / 2)))
    for k in range(6):  # pied large : le rocher s'assoit sur le sol
        a = k * math.pi / 3 + rnd.uniform(-0.3, 0.3)
        bm.verts.new((sx / 2 * 0.9 * math.cos(a), sy / 2 * 0.9 * math.sin(a), -sz / 2))
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    junk = list({v for v in res.get("geom_interior", []) + res.get("geom_unused", [])
                 if isinstance(v, bmesh.types.BMVert) and v.is_valid})
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(7), verts=bm.verts[:], edges=bm.edges[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.translate(bm, vec=(0, 0, sz / 2), verts=bm.verts[:])
    obj = G._object_from_bmesh(name, bm)
    return G.transform(obj, _matrix(at, rot))


def ring_sector(name: str, r_in: float, r_out: float, a0: float, a1: float, depth: float, steps: int = 1,
                at=(0, 0, 0)) -> bpy.types.Object:
    """Voussoir : secteur d'anneau dans le plan XZ (arche), épaisseur `depth` en Y, centré sur `at`."""
    bm = bmesh.new()
    rings = []
    for y in (-depth / 2, depth / 2):
        ring = []
        for k in range(steps + 1):
            a = a0 + (a1 - a0) * k / steps
            ring.append(bm.verts.new((at[0] + r_out * math.cos(a), at[1] + y, at[2] + r_out * math.sin(a))))
        for k in range(steps, -1, -1):
            a = a0 + (a1 - a0) * k / steps
            ring.append(bm.verts.new((at[0] + r_in * math.cos(a), at[1] + y, at[2] + r_in * math.sin(a))))
        rings.append(ring)
    n = len(rings[0])
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[1])))
    for k in range(n):
        bm.faces.new((rings[0][k], rings[1][k], rings[1][(k + 1) % n], rings[0][(k + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return G._object_from_bmesh(name, bm)


def _min_dim(obj: bpy.types.Object) -> float:
    d = obj.dimensions
    return max(min(d.x, d.y, d.z), 0.01)


def finish(items, bevel: float = 0.14, max_bevel: float = 0.4, segments: int = 2, angle: float = 30.0):
    """Matériau + Bevel (proportionnel à la plus petite dimension) + Weighted Normal, appliqués."""
    out = []
    for obj, mat in items:
        G.assign_material(obj, mat)
        G.add_bevel_finish(obj, width=min(max_bevel, bevel * _min_dim(obj)), segments=segments, angle_deg=angle)
        out.append(G.apply_modifiers(obj))
    return out


def assemble(name: str, objs) -> bpy.types.Object:
    obj = G.join(list(objs), name)
    G.smooth_by_angle(obj, 30.0)
    return obj


def _magma_everywhere_low(obj: bpy.types.Object, top: float) -> None:
    """Veines lumineuses de l'obsidienne : surtout dans le bas des aiguilles (la lueur « monte » du sol)."""
    G.write_region_attribute(obj, "magma", lambda co: 1.0 - G._smooth01((co.z - top * 0.15) / (top * 0.55)))


# =====================================================================================================================
# Pack nature
# =====================================================================================================================

def rock(name: str, seed: int = 1, size=(9.0, 7.0, 6.0), kind: str = "calcaire"):
    """Rocher calcaire : un gros bloc facetté + 1 ou 2 éclats appuyés. High : facettes ébréchées (Displace)."""
    rnd = random.Random(seed)
    M = mats()
    sx, sy, sz = size

    def pieces(tag):
        r = random.Random(seed)
        out = [hull(f"{name}_{tag}_main", r, size, flat_top=0.7)]
        for k in range(1 + seed % 2):
            s = r.uniform(0.38, 0.55)
            a = r.uniform(0, 2 * math.pi)
            out.append(hull(f"{name}_{tag}_chip{k}", r, (sx * s, sy * s, sz * s * 1.1), flat_top=0.65,
                            at=(math.cos(a) * sx * 0.45, math.sin(a) * sy * 0.45, 0),
                            rot=(r.uniform(-12, 12), r.uniform(-12, 12), r.uniform(0, 360))))
        return out

    low = finish([(p, M[kind]) for p in pieces("low")], bevel=0.05, max_bevel=0.35, segments=2, angle=20)
    high_parts = []
    for p in pieces("high"):
        G.assign_material(p, M[kind])
        G.add_bevel_finish(p, width=min(0.35, 0.05 * _min_dim(p)), segments=3, angle_deg=20)
        G.add_organic_displace(p, texture="VORONOI", strength=0.14, size=1.1, subdiv=2, subdiv_type="SIMPLE",
                               seed=seed)
        high_parts.append(G.apply_modifiers(p))
    del rnd
    return assemble(name, low), assemble(name + "_high", high_parts)


def obsidian(name: str, seed: int = 1, height: float = 13.0):
    """Formation d'obsidienne : aiguilles facettées penchées, veines violettes lumineuses, bouquet de cristaux."""
    M = mats()

    def pieces(tag):
        r = random.Random(seed)
        out = [(hull(f"{name}_{tag}_socle", r, (8, 7, 3.2), flat_top=0.6), M["obsidienne"])]
        for k in range(4 + seed % 2):
            h = height * r.uniform(0.45, 1.0) * (1.0 if k else 1.15)
            w = r.uniform(1.8, 3.0)
            a = k * 2.4 + r.uniform(-0.3, 0.3)
            d = 0.0 if k == 0 else r.uniform(1.4, 2.8)
            out.append((hull(f"{name}_{tag}_aiguille{k}", r, (w, w * r.uniform(0.8, 1.1), h), points=18,
                             flat_top=0.98, at=(math.cos(a) * d, math.sin(a) * d, -0.4),
                             rot=(r.uniform(-16, 16), r.uniform(-16, 16), r.uniform(0, 360))), M["obsidienne"]))
        cl = G.crystal_cluster(f"{name}_{tag}_cristaux", count=5, origin=(3.0, -1.8, 1.2), spread=1.2,
                               radius=(0.35, 0.6), height=(1.6, 3.2), seed=seed, facing=-0.6, arc=2.0)
        out.append((cl, M["cristal_violet"]))
        return out

    low = finish(pieces("low"), bevel=0.06, max_bevel=0.25, segments=2, angle=20)
    high = finish(pieces("high"), bevel=0.06, max_bevel=0.25, segments=3, angle=20)
    low, high = assemble(name, low), assemble(name + "_high", high)
    for o in (low, high):
        _magma_everywhere_low(o, height)
    return low, high


def cliff(name: str, seed: int = 4, width: float = 36.0, depth: float = 14.0, layers: int = 5,
          layer_h: float = 5.6):
    """Falaise modulaire en gradins : strates de calcaire qui reculent, chaque terrasse couronnée d'herbe à tenons."""
    M = mats()
    r = random.Random(seed)
    items = []
    for k in range(layers):
        inset = k * depth * 0.16
        d = depth - inset
        x = -width / 2 + r.uniform(0, 1.5) + k * 0.8
        x_end = width / 2 - k * 1.2
        while x < x_end - 1.0:
            w = min(r.uniform(5.0, 8.5), x_end - x)
            h = layer_h + r.uniform(-0.6, 1.0)
            cy = inset / 2 + r.uniform(-0.5, 0.5)
            rot = (r.uniform(-2.5, 2.5), r.uniform(-2, 2), r.uniform(-4, 4))
            items.append((bx(f"{name}_strate{k}_{len(items)}", (w, d, h), (x + w / 2, cy, k * layer_h - 0.4), rot,
                             taper=(0.94, 0.92), shift=(0, 0.25)), M["calcaire"]))
            if k == layers - 1 or r.random() < 0.85:
                items.append((bx(f"{name}_herbe{k}_{len(items)}", (w * 0.97, d * 0.9, 0.8),
                                 (x + w / 2, cy + 0.2, k * layer_h - 0.4 + h * 0.97), (0, 0, rot[2])),
                              M[r.choice(["feuille_a", "feuille_b"])]))
            x += w * r.uniform(0.86, 0.98)
    low = finish(items, bevel=0.07, max_bevel=0.45, segments=2, angle=25)
    return assemble(name, low), None


def tree(name: str, seed: int = 7, height: float = 22.0, leaves=("feuille_a", "feuille_b", "feuille_c"),
         spread: float = 1.0):
    """Arbre majestueux : tronc tordu en sections biseautées qui tournent, pied évasé et racines, 3 branches,
    canopée en couches de blocs (large en bas, étroite en haut : silhouette « toon » lisible de loin)."""
    M = mats()
    r = random.Random(seed)
    items = []
    n = 6
    bend = r.uniform(2.0, 3.4)
    bend_dir = r.uniform(0, 2 * math.pi)
    trunk_h = height * 0.56
    items.append((bx(f"{name}_pied", (4.8, 4.6, 1.8), (0, 0, -0.2), (0, 0, r.uniform(0, 90)), taper=(0.66, 0.66)),
                  M["ecorce"]))
    z = 0.6
    top = Vector((0, 0, 0))
    for i in range(n):
        t = i / (n - 1)
        s = 3.3 - 1.6 * t
        h = trunk_h / n * 1.1
        off = bend * t * t
        cx, cy = math.cos(bend_dir) * off, math.sin(bend_dir) * off
        lean = math.degrees(math.atan(2 * bend * t / trunk_h)) * 0.8
        items.append((bx(f"{name}_tronc{i}", (s, s * 0.92, h), (cx, cy, z),
                         (lean * math.sin(bend_dir), -lean * math.cos(bend_dir), i * 13 + r.uniform(-4, 4)),
                         taper=(0.88, 0.88)), M["ecorce"]))
        z += h * 0.9
        top = Vector((cx, cy, z))
    for k in range(5):  # racines : partent du pied et plongent dans le sol
        a = k * 2 * math.pi / 5 + r.uniform(-0.3, 0.3)
        length = r.uniform(3.0, 4.0)
        items.append((bx(f"{name}_racine{k}", (length, 1.3, 1.1), (math.cos(a) * 2.2, math.sin(a) * 2.2, -0.35),
                         (0, 16, math.degrees(a)), taper=(0.55, 0.7)), M["ecorce"]))
    tips = []
    for k in range(3):  # branches
        a = bend_dir + 0.9 + k * 2 * math.pi / 3 + r.uniform(-0.4, 0.4)
        length = r.uniform(4.2, 5.4) * spread
        base = top - Vector((0, 0, r.uniform(1.4, 3.0)))
        tilt = r.uniform(50, 64)
        direction = Vector((math.cos(a) * math.sin(math.radians(tilt)), math.sin(a) * math.sin(math.radians(tilt)),
                            math.cos(math.radians(tilt))))
        mid = base + direction * length / 2
        items.append((bx(f"{name}_branche{k}", (1.2, 1.1, length), (mid.x, mid.y, mid.z - length / 2),
                         (0, tilt, math.degrees(a)), taper=(0.6, 0.6)), M["ecorce"]))
        tips.append(base + direction * length)

    def leaf(tag, center, s, tone):
        items.append((bx(f"{name}_{tag}", (s, s * r.uniform(0.88, 1.08), s * r.uniform(0.6, 0.74)),
                         (center.x, center.y, center.z), (r.uniform(-9, 9), r.uniform(-9, 9), r.uniform(0, 90)),
                         taper=(0.84, 0.84)), M[leaves[tone % len(leaves)]]))

    sp = spread
    crown = top + Vector((0, 0, 0.6))
    layers = ((6, 3.6, 5.0, 0.0), (4, 2.3, 4.2, 2.6), (2, 0.9, 3.4, 4.8))  # (blocs, rayon, taille, hauteur)
    for li, (count, rad, size, dz) in enumerate(layers):
        for k in range(count):
            a = k * 2 * math.pi / count + li * 0.5 + r.uniform(-0.25, 0.25)
            c = crown + Vector((math.cos(a) * rad * sp, math.sin(a) * rad * sp, dz * sp + r.uniform(-0.3, 0.3)))
            leaf(f"couronne{li}_{k}", c, size * r.uniform(0.9, 1.1) * sp, li + k)
    for t, tip in enumerate(tips):  # petites grappes au bout des branches
        for k in range(3):
            a = k * 2 * math.pi / 3 + r.uniform(-0.3, 0.3)
            c = tip + Vector((math.cos(a) * 1.5 * sp, math.sin(a) * 1.5 * sp, -0.8 + r.uniform(-0.2, 0.2)))
            leaf(f"grappe{t}_{k}", c, 3.4 * r.uniform(0.9, 1.1) * sp, t + k + 1)
        leaf(f"grappe{t}_haut", tip + Vector((0, 0, 0.9 * sp)), 2.6 * sp, 1)
    low = finish(items, bevel=0.12, max_bevel=0.5, segments=2, angle=25)
    return assemble(name, low), None


def mushroom(name: str, seed: int = 3, height: float = 11.0):
    """Champignon géant : pied cintré, chapeau en gradins à 8 pans, lamelles lumineuses, 2 petits champignons."""
    M = mats()
    r = random.Random(seed)
    items = []

    def one(prefix, scale, at, cap_mat, gill_mat, lean):
        s = scale
        z = 0.0
        for i in range(4):
            w = (1.9 - 0.25 * i) * s
            h = height * 0.19 * s
            items.append((bx(f"{prefix}_pied{i}", (w, w, h), (at[0] + lean * i * 0.25 * s, at[1], z),
                             (0, lean * 4, i * 20), taper=(0.92, 0.92)), M["champi_pied"]))
            z += h * 0.94
        cz = z
        cap = G.lathe(f"{prefix}_chapeau", [(0, cz), (5.8 * s, cz), (6.1 * s, cz + 0.9 * s), (5.0 * s, cz + 1.1 * s),
                                             (4.9 * s, cz + 2.0 * s), (3.3 * s, cz + 2.2 * s), (3.1 * s, cz + 3.0 * s),
                                             (0, cz + 3.0 * s)], segments=8, phase=math.pi / 8)
        G.transform(cap, Matrix.Translation((at[0] + lean * s, at[1], 0)))
        items.append((cap, cap_mat))
        gills = G.lathe(f"{prefix}_lamelles", [(0, cz - 0.35 * s), (5.3 * s, cz - 0.35 * s), (5.3 * s, cz + 0.05),
                                               (0, cz + 0.05)], segments=8, phase=math.pi / 8)
        G.transform(gills, Matrix.Translation((at[0] + lean * s, at[1], 0)))
        items.append((gills, gill_mat))
        return cz, s

    cz, s = one(f"{name}_grand", 1.0, (0, 0), M["champi_chapeau"], M["champi_lueur"], 0.8)
    for k in range(7):  # points blancs posés sur les gradins du chapeau
        a = k * 2 * math.pi / 7 + r.uniform(-0.2, 0.2)
        ring, zz = ((4.2, cz + 2.05) if k % 2 else (5.5, cz + 0.95))
        w = r.uniform(0.9, 1.4)
        items.append((bx(f"{name}_point{k}", (w, w, 0.35), (0.8 + math.cos(a) * ring * 0.92, math.sin(a) * ring * 0.92, zz),
                         (0, 0, math.degrees(a))), M["points"]))
    one(f"{name}_petit1", 0.38, (4.2, -2.6), M["champi_lueur"], M["points"], -0.6)
    one(f"{name}_petit2", 0.28, (-3.6, -3.2), M["champi_chapeau"], M["champi_lueur"], 0.4)
    low = finish(items, bevel=0.1, max_bevel=0.3, segments=2, angle=30)
    return assemble(name, low), None


def grass_tuft(name: str, seed: int = 2, height: float = 3.2):
    """Touffe d'herbe géante : lames effilées qui s'ouvrent en éventail, deux tons."""
    M = mats()
    r = random.Random(seed)
    items = []
    for k in range(11):
        a = k * 2 * math.pi / 11 + r.uniform(-0.25, 0.25)
        d = r.uniform(0.2, 0.9)
        h = height * r.uniform(0.6, 1.1)
        items.append((bx(f"{name}_lame{k}", (0.62, 0.3, h), (math.cos(a) * d, math.sin(a) * d, -0.1),
                         (0, r.uniform(12, 32), math.degrees(a)), taper=(0.12, 0.5)),
                      M["herbe"] if k % 3 else M["feuille_b"]))
    low = finish(items, bevel=0.2, max_bevel=0.06, segments=1, angle=30)
    return assemble(name, low), None


# =====================================================================================================================
# Pack civilisation
# =====================================================================================================================

def ruin_wall(name: str, seed: int = 5, length: float = 16.0, rows: int = 5, brick_h: float = 1.5,
              depth: float = 2.2):
    """Mur en ruine : rangées de pierres décalées, sommet effondré d'un côté, briques manquantes, gravats au sol."""
    M = mats()
    r = random.Random(seed)
    items = []
    for row in range(rows):
        x = -length / 2 - (r.uniform(0.6, 1.6) if row % 2 else 0.0)
        while x < length / 2 - 0.4:
            w = min(r.uniform(2.4, 4.2), length / 2 - x)
            cx = x + w / 2
            t = (cx + length / 2) / length  # 0 à gauche (intact) -> 1 à droite (effondré)
            keep_rows = rows if t < 0.4 else max(1, round(rows - (t - 0.4) / 0.6 * (rows - 1.2)))
            missing = row >= 2 and r.random() < 0.12
            if row < keep_rows and not missing and w > 0.8:
                items.append((bx(f"{name}_pierre{len(items)}", (w - 0.12, depth * r.uniform(0.92, 1.04), brick_h - 0.1),
                                 (cx, r.uniform(-0.12, 0.12), row * brick_h),
                                 (r.uniform(-1.5, 1.5), r.uniform(-1.5, 1.5), r.uniform(-2, 2)),
                                 taper=(r.uniform(0.95, 1), 1)), M["ruine"]))
            x += w
    for k in range(5):  # gravats tombés du côté effondré
        w = r.uniform(1.6, 3.2)
        items.append((bx(f"{name}_gravat{k}", (w, w * 0.7, r.uniform(0.8, 1.3)),
                         (length * 0.25 + r.uniform(0, length * 0.3), r.uniform(-3.6, -1.4) * (1 if k % 2 else -0.8), -0.15),
                         (r.uniform(-12, 12), r.uniform(-12, 12), r.uniform(0, 90))), M["ruine"]))
    low = finish(items, bevel=0.1, max_bevel=0.25, segments=2, angle=30)
    return assemble(name, low), None


def _glyph(prefix: str, center, normal_axis: str, size: float, seed: int, depth: float = 0.25):
    """Rune gravée : barre verticale + 2 ou 3 traits (blocs lumineux plats posés sur une face)."""
    r = random.Random(seed)
    cx, cy, cz = center
    parts = []
    strokes = [(0, 0, 0.18, 1.0)]  # (dx, dz, largeur, hauteur) relatifs à size
    for k in range(r.choice((2, 3))):
        dz = r.uniform(-0.35, 0.35)
        strokes.append((r.choice((-0.22, 0.22)), dz, 0.5, 0.14))
    for k, (dx, dz, w, h) in enumerate(strokes):
        if normal_axis == "Y":
            size_v, at = (w * size, depth, h * size), (cx + dx * size, cy, cz + dz * size - h * size / 2)
        else:
            size_v, at = (depth, w * size, h * size), (cx, cy + dx * size, cz + dz * size - h * size / 2)
        parts.append((bx(f"{prefix}_{k}", size_v, at, (0, 0, r.uniform(-6, 6) if k else 0)), mats()["rune"]))
    return parts


def arch(name: str, seed: int = 9, opening: float = 18.0, pillar_h: float = 13.5, depth: float = 3.2):
    """Arche ancienne : 2 piliers (socle, fûts, chapiteau), 9 voussoirs, clé de voûte runique, runes sur les fûts."""
    M = mats()
    r = random.Random(seed)
    items = []
    r_in = opening / 2
    for side in (-1, 1):
        px = side * (r_in + 1.6)
        items.append((bx(f"{name}_socle{side}", (4.4, depth + 1.2, 1.5), (px, 0, 0)), M["calcaire_taille"]))
        z = 1.5
        for k in range(3):
            items.append((bx(f"{name}_fut{side}_{k}", (3.2, depth, 3.55), (px + r.uniform(-0.1, 0.1), 0, z),
                             (0, 0, r.uniform(-3, 3))), M["ruine"]))
            z += 3.6
        items.append((bx(f"{name}_chapiteau{side}", (4.2, depth + 0.8, 1.2), (px, 0, z)), M["calcaire_taille"]))
        items += _glyph(f"{name}_runefut{side}", (px, -depth / 2 - 0.05, 7.0), "Y", 2.8, seed + side)
    top = pillar_h
    n = 9
    gap = 0.035
    for k in range(n):
        a0 = math.pi - k * math.pi / n - gap / 2
        a1 = math.pi - (k + 1) * math.pi / n + gap / 2
        key = k == n // 2
        piece = ring_sector(f"{name}_voussoir{k}", r_in - 0.2, r_in + (4.4 if key else 3.4), a1, a0,
                            depth + (0.6 if key else 0.0), steps=2, at=(0, 0, top))
        if not key and r.random() < 0.25:  # pierre un peu sortie de l'arc
            G.transform(piece, Matrix.Translation((0, r.uniform(-0.3, 0.3), -0.1)))
        items.append((piece, M["calcaire_taille"] if key else M["ruine"]))
    items += _glyph(f"{name}_runecle", (0, -depth / 2 - 0.35, top + r_in + 2.2), "Y", 2.4, seed + 7)
    low = finish(items, bevel=0.1, max_bevel=0.3, segments=2, angle=25)
    return assemble(name, low), None


def totem(name: str, seed: int = 11, tiers: int = 4):
    """Totem d'énergie : socle, blocs gravés empilés en quinconce, runes lumineuses, bouquet de cristaux cyan."""
    M = mats()
    r = random.Random(seed)
    items = [(bx(f"{name}_socle", (5.6, 5.6, 1.4), (0, 0, 0)), M["calcaire_taille"]),
             (bx(f"{name}_socle2", (4.6, 4.6, 0.8), (0, 0, 1.3), (0, 0, 45)), M["ruine"])]
    z = 2.0
    for k in range(tiers):
        s = 3.6 - 0.25 * k
        h = 2.7
        rz = 45 * (k % 2) + r.uniform(-4, 4)
        items.append((bx(f"{name}_bloc{k}", (s, s, h), (0, 0, z), (0, 0, rz), taper=(0.9, 0.9)),
                      M["ruine"] if k % 2 else M["calcaire_taille"]))
        for f in range(4):  # une rune par face
            a = math.radians(rz + 90 * f)
            d = s * 0.47
            items.append((bx(f"{name}_rune{k}_{f}", (0.9, 0.22, 1.5), (math.cos(a) * d, math.sin(a) * d, z + 0.6),
                             (0, 0, math.degrees(a) + 90)), M["rune"]))
        z += h * 0.98
    items.append((bx(f"{name}_coiffe", (3.4, 3.4, 0.8), (0, 0, z), (0, 0, 45)), M["or"]))
    cl = G.crystal_cluster(f"{name}_cristaux", count=5, origin=(0, 0, z + 0.6), spread=0.9, radius=(0.5, 0.85),
                           height=(2.4, 4.6), seed=seed, tilt=(4, 24))
    items.append((cl, M["cristal"]))
    low = finish(items, bevel=0.1, max_bevel=0.25, segments=2, angle=25)
    return assemble(name, low), None


def rune_slab(name: str, seed: int = 13, size=(8.0, 6.0, 1.2)):
    """Dalle runique fendue : 3 morceaux légèrement décalés, cercle de runes lumineuses incrusté."""
    M = mats()
    r = random.Random(seed)
    sx, sy, sz = size
    items = []
    cut1 = r.uniform(-0.6, 0.6)
    pieces = [((-sx / 4 + cut1 / 2 - 0.05, -sy / 4), (sx / 2 + cut1 - 0.1, sy / 2 - 0.1)),
              ((-sx / 4 + cut1 / 2 - 0.05, sy / 4), (sx / 2 + cut1 - 0.1, sy / 2 - 0.1)),
              ((sx / 4 + cut1 / 2 + 0.05, 0), (sx / 2 - cut1 - 0.1, sy - 0.1))]
    for k, ((cx, cy), (w, d)) in enumerate(pieces):
        items.append((bx(f"{name}_morceau{k}", (w, d, sz), (cx, cy, r.uniform(-0.12, 0.05)),
                         (r.uniform(-1.2, 1.2), r.uniform(-1.2, 1.2), r.uniform(-1.5, 1.5))), M["calcaire_taille"]))
    for k in range(8):
        a = k * math.pi / 4
        items.append((bx(f"{name}_rune{k}", (0.7 if k % 2 else 1.3, 0.3, 0.12),
                         (math.cos(a) * 1.9, math.sin(a) * 1.9, sz - 0.05), (0, 0, math.degrees(a) + 90)), M["rune"]))
    items.append((bx(f"{name}_coeur", (1.0, 1.0, 0.14), (0, 0, sz - 0.05), (0, 0, 45)), M["rune"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def stairs(name: str, seed: int = 15, width: float = 16.0, steps: int = 3, rise: float = 0.6, run: float = 1.8):
    """Escalier de pierre : marches faites de plusieurs blocs taillés, joues latérales, montée vers +Y."""
    M = mats()
    r = random.Random(seed)
    items = []
    for k in range(steps):
        x = -width / 2
        while x < width / 2 - 0.3:
            w = min(r.uniform(3.0, 5.0), width / 2 - x)
            items.append((bx(f"{name}_marche{k}_{len(items)}", (w - 0.08, run * (steps - k), rise),
                             (x + w / 2, k * run / 2 + r.uniform(-0.05, 0.05), k * rise),
                             (0, 0, r.uniform(-0.8, 0.8))), M["calcaire_taille"]))
            x += w
    for side in (-1, 1):
        items.append((bx(f"{name}_joue{side}", (1.6, run * steps, rise * steps + 0.5),
                         (side * (width / 2 + 0.8), 0, 0), taper=(1, 0.75), shift=(0, run * 0.6)), M["ruine"]))
    low = finish(items, bevel=0.12, max_bevel=0.2, segments=2, angle=30)
    return assemble(name, low), None


def crate(name: str, seed: int = 17, s: float = 4.0):
    """Caisse : panneaux de planches, cadre de poutres sombres, croisillon, équerres de fer."""
    M = mats()
    r = random.Random(seed)
    items = [(bx(f"{name}_coeur", (s - 0.3, s - 0.3, s - 0.3), (0, 0, 0.15)), M["bois_planche"])]
    b = 0.55
    h = s / 2
    for ax in range(3):
        for sa in (-1, 1):
            for sb in (-1, 1):
                if ax == 0:
                    items.append((bx(f"{name}_poutre{ax}{sa}{sb}", (s, b, b), (0, sa * (h - b / 2), h + sb * (h - b / 2) - b / 2)),
                                  M["bois_sombre"]))
                elif ax == 1:
                    items.append((bx(f"{name}_poutre{ax}{sa}{sb}", (b, s, b), (sa * (h - b / 2), 0, h + sb * (h - b / 2) - b / 2)),
                                  M["bois_sombre"]))
                else:
                    items.append((bx(f"{name}_poutre{ax}{sa}{sb}", (b, b, s - 2 * b), (sa * (h - b / 2), sb * (h - b / 2), b)),
                                  M["bois_sombre"]))
    for sy in (-1, 1):  # croisillon devant / derrière
        items.append((bx(f"{name}_croix{sy}", (s * 1.18, 0.35, 0.5), (0, sy * (h - 0.05), h - 0.25), (0, 45, 0)),
                      M["bois_sombre"]))
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (0, 1):
                z = sz * (s - 0.9) - 0.05
                items.append((bx(f"{name}_equerre{sx}{sy}{sz}", (0.75, 0.75, 1.0),
                                 (sx * (h - 0.3), sy * (h - 0.3), z)), M["fer"]))
    del r
    low = finish(items, bevel=0.14, max_bevel=0.12, segments=2, angle=30)
    return assemble(name, low), None


def barrel(name: str, seed: int = 19, h: float = 4.6, rad: float = 1.9):
    """Tonneau cerclé : douelles (pans biseautés), couvercle en retrait, 4 cercles de fer, rivets."""
    M = mats()
    prof = [(0, 0.0), (rad * 0.88, 0.0), (rad, h * 0.25), (rad * 1.06, h * 0.5), (rad, h * 0.75), (rad * 0.88, h),
            (rad * 0.76, h), (rad * 0.76, h - 0.22), (0, h - 0.22)]
    body = G.lathe(f"{name}_corps", prof, segments=14)
    items = [(body, M["bois_clair"])]
    for k, t in enumerate((0.1, 0.32, 0.68, 0.9)):
        z = h * t
        rr = G.profile_radius_at(prof[:6], z)
        hoop = G.lathe(f"{name}_cercle{k}", [(rr - 0.05, z - 0.2), (rr + 0.13, z - 0.2), (rr + 0.13, z + 0.2),
                                             (rr - 0.05, z + 0.2)], segments=14, closed=True)
        items.append((hoop, M["fer"]))
    low = finish(items, bevel=0.06, max_bevel=0.08, segments=2, angle=20)
    return assemble(name, low), None


def signpost(name: str, seed: int = 21):
    """Pancarte : poteau à tête pointue, 2 flèches en planches, coins dorés, rivets de fer."""
    M = mats()
    items = [(bx(f"{name}_poteau", (0.9, 0.9, 6.6), (0, 0, 0)), M["bois_sombre"]),
             (bx(f"{name}_tete", (0.9, 0.9, 0.9), (0, 0, 6.6), taper=(0.1, 0.1)), M["bois_sombre"]),
             (bx(f"{name}_pied", (2.0, 2.0, 0.7), (0, 0, 0), (0, 0, 45)), M["calcaire_taille"])]
    for k, (z, flip, w) in enumerate(((4.6, 1, 5.4), (2.9, -1, 4.6))):
        outline = [(-0.6, -0.85), (w - 1.0, -0.85), (w - 0.1, 0.0), (w - 1.0, 0.85), (-0.6, 0.85)]
        if flip < 0:
            outline = [(-u, v) for u, v in reversed(outline)]
        items.append((stepped_plate(f"{name}_fleche{k}", outline, 0.42, center=(0, -0.68, z)), M["bois_planche"]))
        for u in (0.0, flip * (w - 1.6)):
            items.append((bx(f"{name}_coin{k}_{u}", (0.42, 0.2, 0.42), (u, -0.95, z - 0.21)), M["or"]))
    low = finish(items, bevel=0.14, max_bevel=0.1, segments=2, angle=30)
    return assemble(name, low), None


def palisade(name: str, seed: int = 23, length: float = 12.0):
    """Palissade de bastion : muret de pierre biseauté, pieux taillés en pointe, lisse avec bandes de fer."""
    M = mats()
    r = random.Random(seed)
    items = []
    x = -length / 2
    while x < length / 2 - 0.3:
        w = min(r.uniform(2.4, 3.6), length / 2 - x)
        items.append((bx(f"{name}_muret{len(items)}", (w - 0.1, 2.0, 1.9), (x + w / 2, 0, 0),
                         (0, 0, r.uniform(-1, 1)), taper=(0.95, 0.9)), M["calcaire_taille"]))
        x += w
    count = 8
    for k in range(count):
        px = -length / 2 + (k + 0.5) * length / count
        hh = r.uniform(4.0, 4.8)
        rz = r.uniform(-6, 6)
        items.append((bx(f"{name}_pieu{k}", (1.0, 1.0, hh), (px, 0.2, 1.8), (r.uniform(-2, 2), 0, rz)), M["bois_clair"]))
        items.append((bx(f"{name}_pointe{k}", (1.0, 1.0, 1.1), (px, 0.2, 1.8 + hh), (0, 0, rz), taper=(0.08, 0.08)),
                      M["bois_clair"]))
        items.append((bx(f"{name}_bande{k}", (1.15, 0.3, 0.55), (px, -0.48, 4.2)), M["fer"]))
    items.append((bx(f"{name}_lisse", (length, 0.45, 0.8), (0, -0.42, 3.95)), M["bois_sombre"]))
    low = finish(items, bevel=0.12, max_bevel=0.14, segments=2, angle=30)
    return assemble(name, low), None


def bridge(name: str, seed: int = 25, length: float = 18.0, width: float = 7.0, arch_h: float = 1.4):
    """Pont de bois en dos d'âne : planches sur un arc, poutres latérales, poteaux et garde-corps, culées de pierre."""
    M = mats()
    r = random.Random(seed)
    items = []
    n = 13
    span = length - 4.0

    def deck_z(x):
        return 0.9 + arch_h * (1 - (2 * x / span) ** 2)

    for k in range(n):
        x = -span / 2 + (k + 0.5) * span / n
        slope = math.degrees(math.atan(-8 * arch_h * x / span ** 2))
        items.append((bx(f"{name}_planche{k}", (span / n - 0.12, width * r.uniform(0.94, 1.0), 0.45),
                         (x, r.uniform(-0.15, 0.15), deck_z(x) - 0.2), (0, -slope, r.uniform(-1.5, 1.5))),
                      M["bois_planche"]))
    for side in (-1, 1):
        y = side * (width / 2 + 0.3)
        for k in range(4):  # poutre courbe en 4 segments
            x0 = -span / 2 + k * span / 4
            x1 = x0 + span / 4
            xm = (x0 + x1) / 2
            slope = math.degrees(math.atan((deck_z(x1) - deck_z(x0)) / (x1 - x0)))
            items.append((bx(f"{name}_poutre{side}_{k}", (span / 4 + 0.3, 0.7, 0.9), (xm, y, deck_z(xm) - 0.75),
                             (0, -slope, 0)), M["bois_sombre"]))
        for k, x in enumerate((-span / 2 + 0.4, 0.0, span / 2 - 0.4)):
            items.append((bx(f"{name}_poteau{side}_{k}", (0.8, 0.8, 3.0), (x, y, deck_z(x) - 0.3)), M["bois_sombre"]))
            items.append((bx(f"{name}_ferrure{side}_{k}", (0.95, 0.95, 0.4), (x, y, deck_z(x) + 1.7)), M["fer"]))
        for k in range(2):
            x0, x1 = (-span / 2 + 0.4, 0.0) if k == 0 else (0.0, span / 2 - 0.4)
            xm = (x0 + x1) / 2
            slope = math.degrees(math.atan((deck_z(x1) - deck_z(x0)) / (x1 - x0)))
            items.append((bx(f"{name}_rampe{side}_{k}", (x1 - x0 + 0.6, 0.45, 0.5), (xm, y, deck_z(xm) + 2.2),
                             (0, -slope, 0)), M["bois_clair"]))
    for side in (-1, 1):
        items.append((bx(f"{name}_culee{side}", (3.2, width + 2.2, 1.4), (side * (span / 2 + 1.4), 0, 0),
                         taper=(0.9, 0.95)), M["calcaire_taille"]))
    low = finish(items, bevel=0.12, max_bevel=0.14, segments=2, angle=30)
    return assemble(name, low), None


# =====================================================================================================================
# Catalogue : nom d'asset -> (constructeur, résolution de cuisson)
# =====================================================================================================================

BUILDERS = {
    "RocherCalcaire_A": (lambda n: rock(n, seed=1, size=(9, 7, 6)), 1024),
    "RocherCalcaire_B": (lambda n: rock(n, seed=2, size=(6, 6, 7.5)), 1024),
    "RocherCalcaire_C": (lambda n: rock(n, seed=6, size=(14, 9, 5)), 1024),
    "RocherObsidienne_A": (lambda n: obsidian(n, seed=1, height=13), 1024),
    "RocherObsidienne_B": (lambda n: obsidian(n, seed=4, height=9), 1024),
    "FalaiseGradins": (lambda n: cliff(n, seed=4), 1024),
    "ArbreMajestueux_A": (lambda n: tree(n, seed=7), 1024),
    "ArbreMajestueux_B": (lambda n: tree(n, seed=31, height=18, leaves=("feuille_c", "feuille_a", "feuille_b")), 1024),
    "ArbreCerisier": (lambda n: tree(n, seed=12, height=17, leaves=("rose_a", "rose_b", "rose_a"), spread=0.85), 1024),
    "ChampignonGeant": (lambda n: mushroom(n, seed=3), 1024),
    "TouffeHerbe": (lambda n: grass_tuft(n, seed=2), 512),
    "MurRuine": (lambda n: ruin_wall(n, seed=5), 1024),
    "ArcheAncienne": (lambda n: arch(n, seed=9), 1024),
    "TotemEnergie": (lambda n: totem(n, seed=11), 1024),
    "DalleRunique": (lambda n: rune_slab(n, seed=13), 512),
    "EscalierPierre": (lambda n: stairs(n, seed=15), 1024),
    "Caisse": (lambda n: crate(n, seed=17), 512),
    "Tonneau": (lambda n: barrel(n, seed=19), 512),
    "Pancarte": (lambda n: signpost(n, seed=21), 512),
    "Palissade": (lambda n: palisade(n, seed=23), 1024),
    "PontBois": (lambda n: bridge(n, seed=25), 1024),
}


def build(asset: str):
    """Construit l'asset du catalogue : renvoie (low, high | None)."""
    fn, _ = BUILDERS[asset]
    return fn(asset)


__all__ = ["mats", "bx", "hull", "ring_sector", "finish", "assemble", "rock", "obsidian", "cliff", "tree", "mushroom",
           "grass_tuft", "ruin_wall", "arch", "totem", "rune_slab", "stairs", "crate", "barrel", "signpost",
           "palisade", "bridge", "BUILDERS", "build"]
