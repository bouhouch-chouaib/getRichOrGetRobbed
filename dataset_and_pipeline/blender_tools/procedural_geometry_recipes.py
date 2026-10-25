"""Recettes de modélisation procédurale (bmesh + piles de modificateurs), Blender 4.2+ / 5.0.

Règle : aucune primitive par défaut posée telle quelle. Les formes partent de profils (tour / lathe), de courbes
épaissies ou de bmesh construits sommet par sommet, puis passent toujours par une pile de finition :

    add_bevel_finish()      chanfrein riche (>= 3 segments, profil 0.7) + Weighted Normal + lissage par angle
    add_organic_displace()  Subdivision Surface + Displace (texture Clouds / Voronoi / Musgrave)
    voxel_fuse()            fusion de plusieurs pièces : Voxel Remesh + Corrective Smooth (+ zones de matériaux
                            retrouvées par proximité), puis make_low() = Decimate sous un budget de triangles

Haute / basse définition : une recette d'assemblage renvoie {"high": objet détaillé, "low": objet de jeu}. Le baker
(auto_pbr_baker.bake_asset) projette les détails du high sur le low (normales, couleur, rugosité...).

Unités : 1 unité Blender = 1 stud Roblox. Pivot des assets = sol, au centre. Devant = -Y Blender.
Remplacement de `use_auto_smooth` (supprimé en 4.1) : smooth_by_angle() = shade smooth + set_sharp_from_angle().

Attributs écrits pour shader_node_library : "grad" (sommets, 0 -> 1) et "facet" (faces, aléatoire).
"""

from __future__ import annotations

import math
import random
from typing import Iterable, Sequence

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

COLLECTION = "PIPELINE"


# =====================================================================================================================
# Outils de base
# =====================================================================================================================

def collection(name: str = COLLECTION) -> bpy.types.Collection:
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
    scene_coll = bpy.context.scene.collection
    if coll.name not in scene_coll.children and coll is not scene_coll:
        try:
            scene_coll.children.link(coll)
        except RuntimeError:
            pass
    return coll


def _object_from_bmesh(name: str, bm: bmesh.types.BMesh) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    collection().objects.link(obj)
    return obj


def apply_modifiers(obj: bpy.types.Object) -> bpy.types.Object:
    """Applique toute la pile (sans opérateur : marche en arrière-plan comme dans l'interface)."""
    if obj.type == "MESH" and not obj.modifiers:
        return obj
    dg = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(dg)
    mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=dg)
    if obj.type != "MESH":
        name = obj.name
        new = bpy.data.objects.new(name + "_mesh", mesh)
        new.matrix_world = obj.matrix_world
        for coll in obj.users_collection:
            coll.objects.link(new)
        data = obj.data
        bpy.data.objects.remove(obj)
        if data is not None and data.users == 0:
            bpy.data.curves.remove(data)
        new.name = name
        mesh.name = name
        return new
    old = obj.data
    obj.modifiers.clear()
    obj.data = mesh
    if old.users == 0:
        bpy.data.meshes.remove(old)
    mesh.name = obj.name
    return obj


def bake_transform(obj: bpy.types.Object) -> None:
    """Fige la position / rotation / échelle dans les sommets (matrice identité ensuite)."""
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)


def duplicate(obj: bpy.types.Object, name: str | None = None) -> bpy.types.Object:
    new = obj.copy()
    new.data = obj.data.copy()
    new.name = name or obj.name + "_copy"
    collection().objects.link(new)
    return new


def delete(*objs: bpy.types.Object) -> None:
    for obj in objs:
        if obj is None:
            continue
        data = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if isinstance(data, bpy.types.Mesh) and data.users == 0:
            bpy.data.meshes.remove(data)


def join(objs: Sequence[bpy.types.Object], name: str) -> bpy.types.Object:
    """Fusionne des objets maillage en un seul (matériaux et attributs conservés)."""
    objs = [apply_modifiers(o) for o in objs if o is not None]
    if len(objs) == 1:
        objs[0].name = name
        return objs[0]
    target = objs[0]
    view_layer = bpy.context.view_layer
    for o in view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    view_layer.objects.active = target
    with bpy.context.temp_override(active_object=target, object=target, selected_objects=list(objs),
                                   selected_editable_objects=list(objs)):
        bpy.ops.object.join()
    target.name = name
    target.data.name = name
    return target


def assign_material(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    """Un seul matériau sur tout l'objet."""
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.data.polygons.foreach_set("material_index", [0] * len(obj.data.polygons))
    return obj


def smooth_by_angle(obj: bpy.types.Object, angle_deg: float = 30.0) -> None:
    """Équivalent moderne de use_auto_smooth : faces lisses, arêtes vives au-delà de angle_deg."""
    mesh = obj.data
    if hasattr(mesh, "shade_smooth"):
        mesh.shade_smooth()
    else:
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    if hasattr(mesh, "set_sharp_from_angle"):
        mesh.set_sharp_from_angle(angle=math.radians(angle_deg))
    else:  # Blender < 4.1
        mesh.use_auto_smooth = True
        mesh.auto_smooth_angle = math.radians(angle_deg)


def clear_custom_normals(obj: bpy.types.Object) -> None:
    """Retire les normales personnalisées (Weighted Normal, harden) avant de déformer une copie haute définition."""
    mesh = obj.data
    if not getattr(mesh, "has_custom_normals", False):
        return
    attr = mesh.attributes.get("custom_normal")
    if attr is not None:
        mesh.attributes.remove(attr)
        return
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.mesh.customdata_custom_splitnormals_clear()


def shade_flat(obj: bpy.types.Object) -> None:
    mesh = obj.data
    if hasattr(mesh, "shade_flat"):
        mesh.shade_flat()
    else:
        mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))


def triangle_count(obj: bpy.types.Object, evaluated: bool = True) -> int:
    if evaluated:
        dg = bpy.context.evaluated_depsgraph_get()
        mesh = obj.evaluated_get(dg).to_mesh()
        count = sum(len(p.vertices) - 2 for p in mesh.polygons)
        obj.evaluated_get(dg).to_mesh_clear()
        return count
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def surface_area(obj: bpy.types.Object) -> float:
    return sum(p.area for p in obj.data.polygons)


# =====================================================================================================================
# Attributs pour les matériaux
# =====================================================================================================================

def write_facet_attribute(obj: bpy.types.Object, seed: int = 0) -> None:
    rnd = random.Random(seed)
    mesh = obj.data
    attr = mesh.attributes.get("facet") or mesh.attributes.new("facet", "FLOAT", "FACE")
    attr.data.foreach_set("value", [rnd.random() for _ in range(len(mesh.polygons))])


def write_grad_attribute(obj: bpy.types.Object, mode: str = "height", center: Vector | None = None,
                         power: float = 1.0, offset: float = 0.0, top: float = 1.0) -> None:
    """grad par sommet, de `offset` à `top` : "height" (bas -> haut de l'objet) ou "radial" (centre -> bord).
    Garder top < 1 pour qu'une gemme reste saturée : la couleur `rim` n'apparaît alors que sur les arêtes."""
    mesh = obj.data
    coords = [v.co.copy() for v in mesh.vertices]
    if not coords:
        return
    zs = [c.z for c in coords]
    zmin, zmax = min(zs), max(zs)
    values = []
    if mode == "radial":
        c = center or sum(coords, Vector()) / len(coords)
        rmax = max((p - c).length for p in coords) or 1.0
        values = [((p - c).length / rmax) for p in coords]
    else:
        span = (zmax - zmin) or 1.0
        values = [(p.z - zmin) / span for p in coords]
    values = [min(max(offset + (top - offset) * (v ** power), 0.0), 1.0) for v in values]
    attr = mesh.attributes.get("grad") or mesh.attributes.new("grad", "FLOAT", "POINT")
    attr.data.foreach_set("value", values)


# =====================================================================================================================
# Constructeurs de formes (pas de primitives par défaut)
# =====================================================================================================================

def lathe(name: str, profile: Sequence[tuple[float, float]], segments: int = 32, phase: float = 0.0,
          closed: bool = False, twist_alternate: bool = False) -> bpy.types.Object:
    """Solide de révolution autour de Z depuis un profil [(rayon, z), ...] listé du bas vers le haut.

    rayon 0 à une extrémité = pôle. closed=True relie le dernier anneau au premier (tore). twist_alternate=True
    décale un anneau sur deux d'un demi-pas et triangule : taille « brillant » pour les gemmes.
    """
    bm = bmesh.new()
    step = 2 * math.pi / segments
    rings: list[list] = []
    offsets: list[float] = []
    for i, (r, z) in enumerate(profile):
        off = phase + (step / 2 if twist_alternate and i % 2 else 0.0)
        offsets.append(off)
        if r <= 1e-6:
            rings.append([bm.verts.new((0.0, 0.0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(off + k * step), r * math.sin(off + k * step), z))
                          for k in range(segments)])
    pairs = list(zip(range(len(rings) - 1), range(1, len(rings))))
    if closed:
        pairs.append((len(rings) - 1, 0))
    for a, b in pairs:
        lo, up = rings[a], rings[b]
        if len(lo) == 1 and len(up) == 1:
            continue
        for k in range(segments):
            k1 = (k + 1) % segments
            if len(lo) == 1:
                bm.faces.new((lo[0], up[k1], up[k]))
            elif len(up) == 1:
                bm.faces.new((lo[k], lo[k1], up[0]))
            elif twist_alternate and offsets[a] != offsets[b]:
                if offsets[b] > offsets[a]:
                    bm.faces.new((lo[k], lo[k1], up[k]))
                    bm.faces.new((up[k], lo[k1], up[k1]))
                else:
                    bm.faces.new((lo[k], up[k1], up[k]))
                    bm.faces.new((lo[k], lo[k1], up[k1]))
            else:
                bm.faces.new((lo[k], lo[k1], up[k1], up[k]))
    if not closed:
        if len(rings[0]) > 1:
            bm.faces.new(list(reversed(rings[0])))
        if len(rings[-1]) > 1:
            bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _object_from_bmesh(name, bm)


def egg_profile(height: float, width: float, rings: int = 12, bottom_bias: float = 0.12,
                z0: float = 0.0) -> list[tuple[float, float]]:
    """Profil d'œuf (plus large en bas), pôles en bas et en haut."""
    pts = []
    for i in range(rings + 1):
        theta = math.pi * i / rings
        z = z0 + height * (1 - math.cos(theta)) / 2
        r = (width / 2) * math.sin(theta) * (1 + bottom_bias * math.cos(theta))
        pts.append((max(r, 0.0), z))
    return pts


def profile_radius_at(profile: Sequence[tuple[float, float]], z: float) -> float:
    """Rayon d'un profil (monotone en z) à la hauteur z, par interpolation."""
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        if z0 <= z <= z1 and z1 > z0:
            t = (z - z0) / (z1 - z0)
            return r0 + (r1 - r0) * t
    return profile[0][0] if z < profile[0][1] else profile[-1][0]


def ring_profile(radius: float, thickness: float, z: float, steps: int = 12, squash: float = 1.0) -> list:
    """Profil circulaire fermé (pour lathe(closed=True)) : un tore de section `thickness`."""
    return [(radius + thickness * math.cos(2 * math.pi * i / steps),
             z + thickness * squash * math.sin(2 * math.pi * i / steps)) for i in range(steps)]


def curve_tube(name: str, points: Sequence[Sequence[float]], radii: Sequence[float], resolution: int = 10,
               bevel_resolution: int = 4) -> bpy.types.Object:
    """Tube épaissi le long d'une courbe de Bézier (griffes, tentacules, anses), converti en maillage fermé."""
    curve = bpy.data.curves.new(name + "_curve", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_mode = "ROUND"
    curve.bevel_depth = 1.0
    curve.bevel_resolution = bevel_resolution
    curve.resolution_u = resolution
    curve.use_fill_caps = True
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, p, r in zip(spline.bezier_points, points, radii):
        bp.co = Vector(p)
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
        bp.radius = r
    tmp = bpy.data.objects.new(name, curve)
    collection().objects.link(tmp)
    return apply_modifiers(tmp)


def rounded_blob(name: str, radius: float, center: Sequence[float] = (0, 0, 0), u: int = 16, v: int = 10,
                 scale: Sequence[float] = (1, 1, 1)) -> bpy.types.Object:
    """Ellipsoïde construit en bmesh (perles, têtes, ventres) : à fondre avec voxel_fuse, jamais seul."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return _object_from_bmesh(name, bm)


def crystal(name: str, radius: float = 0.3, height: float = 1.2, sides: int = 6, tip: float = 0.32,
            base_scale: float = 0.8, jitter: float = 0.12, seed: int = 0) -> bpy.types.Object:
    """Prisme de cristal irrégulier à pointe, avec attributs grad (pied 0 -> pointe 1) et facet."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    grad = bm.verts.layers.float.new("grad")
    facet = bm.faces.layers.float.new("facet")
    angles = [2 * math.pi * k / sides + rnd.uniform(-0.12, 0.12) for k in range(sides)]

    def ring(z: float, r: float, g: float):
        verts = []
        for a in angles:
            rr = r * (1 + rnd.uniform(-jitter, jitter))
            v = bm.verts.new((rr * math.cos(a), rr * math.sin(a), z))
            v[grad] = g
            verts.append(v)
        return verts

    bottom = ring(-0.08 * height, radius * base_scale, 0.0)
    shoulder = ring(height * (1 - tip), radius, 0.62)
    apex = bm.verts.new((rnd.uniform(-1, 1) * radius * 0.18, rnd.uniform(-1, 1) * radius * 0.18, height))
    apex[grad] = 1.0
    bm.faces.new(list(reversed(bottom)))
    for k in range(sides):
        k1 = (k + 1) % sides
        bm.faces.new((bottom[k], bottom[k1], shoulder[k1], shoulder[k]))
        bm.faces.new((shoulder[k], shoulder[k1], apex))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        f[facet] = rnd.random()
    return _object_from_bmesh(name, bm)


def crystal_cluster(name: str, count: int = 5, origin: Sequence[float] = (0, 0, 0), spread: float = 0.35,
                    radius: tuple[float, float] = (0.12, 0.28), height: tuple[float, float] = (0.5, 1.2),
                    tilt: tuple[float, float] = (8.0, 35.0), seed: int = 0, facing: float | None = None,
                    arc: float = 2 * math.pi) -> bpy.types.Object:
    """Bouquet de cristaux inclinés vers l'extérieur. facing (radians) = direction privilégiée, arc = ouverture."""
    rnd = random.Random(seed)
    parts = []
    for i in range(count):
        r = rnd.uniform(*radius)
        h = rnd.uniform(*height) * (1.0 if i else 1.25)
        c = crystal(f"{name}_{i}", radius=r, height=h, seed=seed * 101 + i)
        base_angle = (facing if facing is not None else 0.0) + (i / max(count, 1) - 0.5) * arc + rnd.uniform(-0.3, 0.3)
        dist = 0.0 if i == 0 else rnd.uniform(0.35, 1.0) * spread
        lean = math.radians(rnd.uniform(*tilt) * (0.4 if i == 0 else 1.0))
        axis = Vector((-math.sin(base_angle), math.cos(base_angle), 0.0))
        m = (Matrix.Translation(Vector(origin) + Vector((math.cos(base_angle) * dist, math.sin(base_angle) * dist, 0.0)))
             @ Matrix.Rotation(lean, 4, axis)
             @ Matrix.Rotation(rnd.uniform(0, 2 * math.pi), 4, "Z"))
        c.data.transform(m)
        parts.append(c)
    return join(parts, name)


# =====================================================================================================================
# Piles de modificateurs
# =====================================================================================================================

def add_bevel_finish(obj: bpy.types.Object, width: float = 0.05, segments: int = 3, profile: float = 0.7,
                     angle_deg: float = 30.0, harden: bool = True, weighted: bool = True) -> bpy.types.Object:
    """Chanfrein riche + Weighted Normal : la lumière accroche les bords comme dans un jeu de studio."""
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = width
    bevel.segments = max(segments, 1)
    bevel.profile = profile
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(angle_deg)
    bevel.use_clamp_overlap = True
    bevel.harden_normals = harden
    try:
        bevel.miter_outer = "MITER_ARC"
    except TypeError:
        pass
    if weighted:
        wn = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        wn.mode = "FACE_AREA"
        wn.weight = 50
        wn.keep_sharp = True
    smooth_by_angle(obj, angle_deg)
    return obj


def _legacy_texture(kind: str, size: float, seed: int, name: str):
    kinds = [e.identifier for e in bpy.types.Texture.bl_rna.properties["type"].enum_items]
    if kind not in kinds:
        kind = "CLOUDS"
    tex = bpy.data.textures.new(name, type=kind)
    tex.noise_scale = size
    bases = ["BLENDER_ORIGINAL", "ORIGINAL_PERLIN", "IMPROVED_PERLIN", "VORONOI_F1", "CELL_NOISE"]
    if kind == "CLOUDS":
        tex.noise_depth = 3
        tex.noise_basis = bases[seed % 3]
    elif kind == "VORONOI":
        tex.distance_metric = "DISTANCE"
        tex.color_mode = "INTENSITY"
        tex.weight_1 = 1.0
    elif kind == "MUSGRAVE":
        tex.musgrave_type = "RIDGED_MULTIFRACTAL"
        tex.noise_intensity = 1.0
        tex.octaves = 4.0
        tex.noise_basis = bases[seed % 3]
    return tex


def add_organic_displace(obj: bpy.types.Object, texture: str = "CLOUDS", strength: float = 0.05,
                         size: float = 0.5, subdiv: int = 2, subdiv_type: str = "CATMULL_CLARK",
                         seed: int = 0, mid_level: float = 0.5) -> bpy.types.Object:
    """Subdivision + Displace par texture procédurale (Clouds, Voronoi, Musgrave) : formes organiques, pierre taillée."""
    if subdiv > 0:
        sub = obj.modifiers.new("Subdivision", "SUBSURF")
        sub.subdivision_type = subdiv_type
        sub.levels = subdiv
        sub.render_levels = subdiv
    disp = obj.modifiers.new("Displace", "DISPLACE")
    disp.texture = _legacy_texture(texture, size, seed, f"{obj.name}_{texture.lower()}")
    disp.strength = strength
    disp.mid_level = mid_level
    disp.texture_coords = "LOCAL"
    return obj


def voxel_fuse(parts: Sequence[bpy.types.Object], name: str, voxel_size: float = 0.04,
               smooth_factor: float = 0.5, smooth_iterations: int = 8, max_faces: int = 1_500_000) -> bpy.types.Object:
    """Fond plusieurs pièces en UNE surface continue (pas de jointure ni d'interpénétration visible).

    Voxel Remesh (taille de voxel en studs) + Corrective Smooth (relâche les marches d'escalier). Les zones de
    matériaux de chaque pièce sont retrouvées ensuite par proximité (le remesh les efface).
    """
    parts = [apply_modifiers(p) for p in parts]
    for p in parts:
        bake_transform(p)
    joined = join(parts, name)
    reference = duplicate(joined, name + "_zones")
    area = surface_area(joined)
    voxel = max(voxel_size, math.sqrt(area / max_faces))
    remesh = joined.modifiers.new("VoxelRemesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0.0
    remesh.use_smooth_shade = True
    smooth = joined.modifiers.new("CorrectiveSmooth", "CORRECTIVE_SMOOTH")
    smooth.factor = smooth_factor
    smooth.iterations = smooth_iterations
    smooth.smooth_type = "LENGTH_WEIGHTED"
    smooth.use_only_smooth = True
    apply_modifiers(joined)
    transfer_material_zones(joined, reference)
    delete(reference)
    smooth_by_angle(joined, 60.0)
    joined["voxel_size"] = voxel
    return joined


def transfer_material_zones(target: bpy.types.Object, source: bpy.types.Object) -> None:
    """Redonne à chaque face de `target` le matériau de la face la plus proche de `source`."""
    src = source.data
    tree = BVHTree.FromPolygons([v.co for v in src.vertices], [tuple(p.vertices) for p in src.polygons])
    src_index = [p.material_index for p in src.polygons]
    target.data.materials.clear()
    for slot in source.material_slots:
        target.data.materials.append(slot.material)
    indices = []
    for poly in target.data.polygons:
        _, _, face, _ = tree.find_nearest(poly.center)
        indices.append(src_index[face] if face is not None else 0)
    target.data.polygons.foreach_set("material_index", indices)


def make_low(high: bpy.types.Object, target_tris: int, name: str | None = None,
             sharp_angle: float = 60.0) -> bpy.types.Object:
    """Copie décimée (Decimate COLLAPSE) sous `target_tris` triangles, pour le jeu."""
    low = duplicate(high, name or high.name.replace("_high", "") + "_low")
    apply_modifiers(low)
    tris = triangle_count(low, evaluated=False)
    if tris > target_tris:
        dec = low.modifiers.new("Decimate", "DECIMATE")
        dec.decimate_type = "COLLAPSE"
        dec.ratio = target_tris / tris
        dec.use_collapse_triangulate = True
        apply_modifiers(low)
    smooth_by_angle(low, sharp_angle)
    return low


# =====================================================================================================================
# Assemblages de référence (preuve de concept de la phase 1)
# =====================================================================================================================

def _mats(defaults: dict, overrides: dict | None):
    import shader_node_library as S

    out = {}
    for key, (preset, params) in defaults.items():
        params = dict(params)
        params.update((overrides or {}).get(key, {}))
        out[key] = S.PRESETS[preset](**params)
    return out


def build_stylized_pedestal(name: str = "PedestalStylise", radius: float = 3.0, seed: int = 3,
                            materials: dict | None = None, studs: float = 1.0) -> dict:
    """Piédestal de base : socle octogonal à 3 marches chanfreinées, colonne, plateau à tenons, liseré d'or,
    4 bouquets de cristaux. Environ 6 x 6 studs au sol, 2,5 studs de haut. Renvoie {"high", "low", "top_z"}."""
    mats = _mats({
        "stone": ("create_stylized_edge_wear_material", {"name": f"M_{name}_Pierre", "base": "#98A2CC", "edge": "#F2F4FF",
                  "accent": "#B7A2E0", "cavity": "#1A1E3C", "wear": 0.85, "roughness": 0.7, "crackle": 0.3, "crackle_scale": 1.4,
                  "edge_radius": 0.09}),
        "plate": ("create_stylized_edge_wear_material", {"name": f"M_{name}_Plateau", "base": "#2F7BFF", "edge": "#9CD0FF",
                  "cavity": "#0B1E5A", "wear": 0.55, "roughness": 0.5, "studs": studs, "edge_radius": 0.04}),
        "gold": ("create_etched_metal_or_gold", {"name": f"M_{name}_Or", "tint": "#FFC830", "scratches": 0.55,
                 "hammered": 0.35, "roughness": 0.24}),
        "crystal": ("create_stylized_crystal_or_gem", {"name": f"M_{name}_Cristal", "core": "#06306E", "mid": "#2FB8FF",
                    "rim": "#DDF8FF", "emission": 0.6}),
    }, materials)
    oct_phase = math.pi / 8
    s = radius / 3.0
    stone_profile = [(0.0, 0.0), (3.0, 0.0), (3.0, 0.42), (2.42, 0.42), (2.42, 0.8), (2.05, 0.8), (2.05, 1.08),
                     (1.62, 1.08), (1.45, 1.22), (1.45, 1.86), (1.62, 1.95), (2.15, 2.05), (2.15, 2.24), (0.0, 2.24)]
    stone = lathe(f"{name}_Pierre", [(r * s, z * s) for r, z in stone_profile], segments=8, phase=oct_phase)
    assign_material(stone, mats["stone"])
    add_bevel_finish(stone, width=0.07 * s, segments=3, profile=0.7, angle_deg=30.0)
    apply_modifiers(stone)

    plate_profile = [(0.0, 2.2), (1.92, 2.2), (1.92, 2.36), (0.0, 2.36)]
    plate = lathe(f"{name}_Plateau", [(r * s, z * s) for r, z in plate_profile], segments=8, phase=oct_phase)
    assign_material(plate, mats["plate"])
    add_bevel_finish(plate, width=0.035 * s, segments=3, angle_deg=30.0)
    apply_modifiers(plate)

    trims = []
    for i, (r, z, t) in enumerate(((2.2, 2.14, 0.075), (1.5, 1.2, 0.06))):
        trim = lathe(f"{name}_Liseré{i}", ring_profile(r * s, t * s, z * s, steps=10, squash=0.8), segments=8,
                     phase=oct_phase, closed=True)
        assign_material(trim, mats["gold"])
        add_bevel_finish(trim, width=0.015 * s, segments=2, angle_deg=40.0)
        apply_modifiers(trim)
        trims.append(trim)

    clusters = []
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        pos = (math.cos(a) * 2.68 * s, math.sin(a) * 2.68 * s, 0.4 * s)
        cl = crystal_cluster(f"{name}_Cristaux{i}", count=3, origin=pos, spread=0.22 * s, radius=(0.1 * s, 0.19 * s),
                             height=(0.45 * s, 0.95 * s), tilt=(10, 28), seed=seed * 10 + i, facing=a, arc=1.6)
        assign_material(cl, mats["crystal"])
        add_bevel_finish(cl, width=0.012 * s, segments=1, angle_deg=20.0, harden=True)
        apply_modifiers(cl)
        clusters.append(cl)

    # Haute définition : pierre taillée à la main (subdivision simple + Displace Clouds), le reste identique.
    stone_high = duplicate(stone, f"{name}_Pierre_high")
    clear_custom_normals(stone_high)
    add_organic_displace(stone_high, texture="CLOUDS", strength=0.05 * s, size=0.35 * s, subdiv=2,
                         subdiv_type="SIMPLE", seed=seed)
    add_organic_displace(stone_high, texture="VORONOI", strength=-0.025 * s, size=0.22 * s, subdiv=0, seed=seed)
    apply_modifiers(stone_high)
    smooth_by_angle(stone_high, 35.0)

    high = join([stone_high, duplicate(plate)] + [duplicate(t) for t in trims] + [duplicate(c) for c in clusters],
                f"{name}_high")
    low = join([stone, plate] + trims + clusters, f"{name}_low")
    return {"high": high, "low": low, "top_z": 2.36 * s}


def build_mythic_gem_egg(name: str = "OeufMythique", egg_height: float = 3.6, egg_width: float = 2.6,
                         seed: int = 7, materials: dict | None = None, setting_tris: int = 2600) -> dict:
    """Œuf Mythique : coquille taillée en gemme (facettes en losanges), serti d'or fondu d'une pièce (coupe +
    bague torsadée + 4 griffes à perles, Voxel Remesh), nid d'éclats de cristal. Renvoie {"high", "low"}."""
    mats = _mats({
        "gem": ("create_stylized_crystal_or_gem", {"name": f"M_{name}_Gemme", "core": "#4A0726", "mid": "#FF2E6A",
                "rim": "#FFC2D6", "emission": 0.9, "facet_variation": 0.45, "edge_glow": 0.9, "edge_width": 0.035}),
        "gold": ("create_etched_metal_or_gold", {"name": f"M_{name}_Or", "tint": "#FFC830", "scratches": 0.5,
                 "hammered": 0.55, "roughness": 0.22, "hammer_scale": 7.0}),
        "shard": ("create_stylized_crystal_or_gem", {"name": f"M_{name}_Eclats", "core": "#2A0438", "mid": "#C43BFF",
                  "rim": "#F6D8FF", "emission": 0.5}),
    }, materials)
    z0 = 0.62
    profile = egg_profile(egg_height, egg_width, rings=9, bottom_bias=0.12, z0=z0)
    fine = egg_profile(egg_height, egg_width, rings=200, bottom_bias=0.12, z0=z0)

    def er(z: float) -> float:
        return profile_radius_at(fine, z)

    shell = lathe(f"{name}_Coquille", profile, segments=12, twist_alternate=True)
    write_facet_attribute(shell, seed)
    write_grad_attribute(shell, mode="height", power=1.2, offset=0.12, top=0.8)
    assign_material(shell, mats["gem"])
    add_bevel_finish(shell, width=0.03, segments=2, profile=0.7, angle_deg=4.0, harden=True)
    apply_modifiers(shell)

    rim_z = z0 + 0.2 * egg_height
    outer = [(0.0, 0.0), (0.98, 0.0), (1.04, 0.07), (0.94, 0.16), (0.46, 0.24), (0.34, 0.36), (0.38, 0.5)]
    zs = [z0 + (rim_z - z0) * t for t in (0.08, 0.3, 0.55, 0.8, 1.0)]
    outer += [(max(er(z), 0.42) + 0.1, z) for z in zs]
    outer += [(er(rim_z) + 0.16, rim_z + 0.03), (er(rim_z) + 0.1, rim_z + 0.1)]
    inner = [(er(z) - 0.03, z) for z in reversed(zs)] + [(0.0, z0 + 0.06)]
    cup = lathe(f"{name}_Coupe", outer + inner, segments=40)
    band = lathe(f"{name}_Bague", ring_profile(er(rim_z) + 0.17, 0.075, rim_z - 0.06, steps=10), segments=40, closed=True)
    parts = [cup, band]
    rnd = random.Random(seed)
    claw_top = z0 + 0.6 * egg_height
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        d = Vector((math.cos(a), math.sin(a), 0.0))
        heights = [rim_z - 0.05, rim_z + 0.35, rim_z + 0.8, claw_top - 0.35, claw_top]
        pts = []
        for j, z in enumerate(heights):
            off = 0.07 if j < len(heights) - 1 else -0.01
            pts.append(d * (er(z) + off) + Vector((0, 0, z)))
        claw = curve_tube(f"{name}_Griffe{i}", [tuple(p) for p in pts], radii=[0.24, 0.19, 0.15, 0.12, 0.1])
        bead = rounded_blob(f"{name}_Perle{i}", 0.17, center=tuple(d * (er(claw_top) + 0.06) + Vector((0, 0, claw_top + 0.08))))
        parts += [claw, bead]
        # petite perle d'appui entre deux griffes, sur la bague
        b = math.pi / 2 * i
        e = Vector((math.cos(b), math.sin(b), 0.0))
        parts.append(rounded_blob(f"{name}_Cabochon{i}", 0.11, center=tuple(e * (er(rim_z) + 0.24) + Vector((0, 0, rim_z - 0.05))),
                                  scale=(1, 1, 0.8)))
    for p in parts:
        assign_material(p, mats["gold"])
    setting_high = voxel_fuse(parts, f"{name}_Serti_high", voxel_size=0.022, smooth_iterations=6)
    setting_low = make_low(setting_high, setting_tris, name=f"{name}_Serti_low")

    shards = []
    for i in range(6):
        a = i * math.pi / 3 + rnd.uniform(-0.25, 0.25)
        pos = (math.cos(a) * 1.05, math.sin(a) * 1.05, 0.0)
        cl = crystal_cluster(f"{name}_Eclat{i}", count=2 if i % 2 else 3, origin=pos, spread=0.2,
                             radius=(0.08, 0.17), height=(0.35, 0.85), tilt=(25, 50), seed=seed * 7 + i,
                             facing=a, arc=0.9)
        shards.append(cl)
    shard_cluster = join(shards, f"{name}_Eclats")
    assign_material(shard_cluster, mats["shard"])
    add_bevel_finish(shard_cluster, width=0.01, segments=1, angle_deg=20.0)
    apply_modifiers(shard_cluster)

    high = join([duplicate(shell), setting_high, duplicate(shard_cluster)], f"{name}_high")
    low = join([shell, setting_low, shard_cluster], f"{name}_low")
    return {"high": high, "low": low}


__all__ = [
    "collection", "apply_modifiers", "bake_transform", "duplicate", "delete", "join", "assign_material",
    "smooth_by_angle", "clear_custom_normals", "shade_flat", "triangle_count", "write_facet_attribute", "write_grad_attribute", "lathe",
    "egg_profile", "profile_radius_at", "ring_profile", "curve_tube", "rounded_blob", "crystal", "crystal_cluster",
    "add_bevel_finish", "add_organic_displace", "voxel_fuse", "transfer_material_zones", "make_low",
    "build_stylized_pedestal", "build_mythic_gem_egg",
]
