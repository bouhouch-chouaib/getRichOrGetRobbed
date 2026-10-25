"""Auto-UV + cuisson PBR (Cycles) + export Roblox — Blender 4.2+ / 5.0.

Roblox ne lit pas les nœuds procéduraux : bake_asset() transforme n'importe quel objet (ou un couple haute / basse
définition) en un maillage de jeu + des textures PNG prêtes pour un SurfaceAppearance :

    {asset}_Color.png      couleur de base x occlusion ambiante (sRGB)
    {asset}_Roughness.png  rugosité (données brutes)
    {asset}_Metalness.png  métal 0 / 1 (données brutes)
    {asset}_Normal.png     normales tangent space OpenGL (+Y), le seul format accepté par Roblox
    {asset}_Emissive.png   masque d'intensité de lueur (si un matériau émet) -> EmissiveMaskContent, EmissiveTint blanc
    {asset}_AO.png         occlusion seule (contrôle)
    {asset}.fbx / .glb     maillage triangulé, UV, matériau cuit
    {asset}_manifest.json  triangles, taille en studs, cartes, réglages SurfaceAppearance conseillés

Méthode : chaque passe couleur / rugosité / métal / occlusion est cuite en EMIT après avoir branché la bonne entrée du
Principled « BAKE_BSDF » (contrat de shader_node_library) sur une Emission. C'est exact quel que soit le réseau de
nœuds, et le métal reste correct (la passe DIFFUSE de Cycles rend un or noir). L'occlusion vient d'un nœud AO
« local » : seul l'asset lui-même compte (pas le sol ni l'objet voisin). Les normales sont une passe NORMAL classique.
Si `high` est fourni, tout est projeté du high vers le low (Selected to Active) : les détails du high (pierre
taillée, surface fondue au voxel) passent dans la Normal map du low décimé.

Exemple (dans Blender, dossier blender_tools dans sys.path) :
    import auto_pbr_baker as B
    report = B.bake_asset(low_obj, "OeufMythique", high=high_obj)
"""

from __future__ import annotations

import json
import math
import os
import time
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

BAKE_BSDF = "BAKE_BSDF"


def pipeline_root() -> Path:
    env = os.environ.get("GRGR_PIPELINE_ROOT")
    if env:
        return Path(env)
    try:
        return Path(__file__).resolve().parents[1]
    except NameError:  # code collé dans la console / le MCP sans __file__
        raise RuntimeError("Définir GRGR_PIPELINE_ROOT (dossier dataset_and_pipeline)")


# =====================================================================================================================
# Préparation du maillage
# =====================================================================================================================

def _select_only(objs, active) -> None:
    view_layer = bpy.context.view_layer
    for o in view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    view_layer.objects.active = active


def _apply_modifiers(obj: bpy.types.Object) -> None:
    if not obj.modifiers:
        return
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = mesh
    if old.users == 0:
        bpy.data.meshes.remove(old)


def prepare_mesh(obj: bpy.types.Object, merge_distance: float = 0.0005, triangulate: bool = True) -> None:
    """Maillage propre : modificateurs appliqués, doublons fusionnés, faces dégénérées dissoutes, normales
    recalculées, triangulé (le tangent space cuit = celui que Roblox recalcule sur des triangles)."""
    _apply_modifiers(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=merge_distance)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=merge_distance * 0.1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if triangulate:
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def unwrap(obj: bpy.types.Object, angle_deg: float = 66.0, island_margin: float = 0.03) -> None:
    """Smart UV Project sans chevauchement (angle_limit en radians dans l'API : 66° -> 1,152)."""
    mesh = obj.data
    while len(mesh.uv_layers) > 1:
        mesh.uv_layers.remove(mesh.uv_layers[-1])
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    _select_only([obj], obj)
    with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=[obj], selected_editable_objects=[obj]):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(angle_deg), island_margin=island_margin,
                                 area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")


def uv_overlap_ratio(obj: bpy.types.Object, grid: int = 512) -> float:
    """Part (0-1) des texels UV couverts par plus d'une face (0 = aucun chevauchement). Rastérisation grossière."""
    mesh = obj.data
    uv = mesh.uv_layers.active.data
    count = np.zeros((grid, grid), dtype=np.uint8)
    for poly in mesh.polygons:
        pts = np.array([uv[i].uv[:] for i in poly.loop_indices]) * (grid - 1)
        if len(pts) < 3:
            continue
        x0, y0 = np.floor(pts.min(0)).astype(int)
        x1, y1 = np.ceil(pts.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, grid - 1), min(y1, grid - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        inside = np.ones_like(xs, dtype=bool)
        sign = None
        for k in range(len(pts)):
            ax, ay = pts[k]
            bx, by = pts[(k + 1) % len(pts)]
            cross = (bx - ax) * (ys - ay) - (by - ay) * (xs - ax)
            s = cross >= 0
            sign = s if sign is None else sign
            inside &= (s == sign)
        count[y0:y1 + 1, x0:x1 + 1] += inside.astype(np.uint8)
    covered = (count > 0).sum()
    return float((count > 1).sum() / covered) if covered else 0.0


def set_origin_bottom_center(obj: bpy.types.Object) -> None:
    """Pivot au sol, au centre (convention du jeu) sans déplacer l'objet dans la scène."""
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs, ys, zs = [c.x for c in corners], [c.y for c in corners], [c.z for c in corners]
    world = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
    local = obj.matrix_world.inverted() @ world
    obj.data.transform(Matrix.Translation(-local))
    obj.matrix_world = obj.matrix_world @ Matrix.Translation(local)


# =====================================================================================================================
# Cycles
# =====================================================================================================================

def enable_gpu(scene: bpy.types.Scene) -> str:
    """Active le GPU s'il existe (CUDA, OptiX, HIP, Metal, oneAPI). GRGR_BAKE_DEVICE=CPU force le processeur."""
    if os.environ.get("GRGR_BAKE_DEVICE", "").upper() == "CPU":
        scene.cycles.device = "CPU"
        return "CPU"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
    except KeyError:
        return "CPU"
    for kind in ("CUDA", "OPTIX", "HIP", "METAL", "ONEAPI"):
        try:
            prefs.compute_device_type = kind
        except TypeError:
            continue
        prefs.get_devices()
        if any(d.type == kind for d in prefs.devices):
            for d in prefs.devices:
                d.use = d.type == kind
            scene.cycles.device = "GPU"
            return kind
    scene.cycles.device = "CPU"
    return "CPU"


def use_cycles(scene: bpy.types.Scene, samples: int, gpu: bool = True) -> dict:
    """Passe en Cycles ; renvoie l'état précédent pour restore_render()."""
    state = {"engine": scene.render.engine}
    try:
        scene.render.engine = "CYCLES"
    except TypeError as err:
        raise RuntimeError(f"Cycles indisponible : {err}") from err
    state.update(samples=scene.cycles.samples, device=scene.cycles.device)
    scene.cycles.samples = samples
    state["backend"] = enable_gpu(scene) if gpu else "CPU"
    return state


def restore_render(scene: bpy.types.Scene, state: dict) -> None:
    try:
        scene.cycles.samples = state.get("samples", scene.cycles.samples)
        scene.cycles.device = state.get("device", scene.cycles.device)
        scene.render.engine = state["engine"]
    except (TypeError, KeyError):
        pass


# =====================================================================================================================
# Branchements temporaires (contrat BAKE_BSDF)
# =====================================================================================================================

def _principled(mat: bpy.types.Material):
    tree = mat.node_tree
    if tree is None:
        return None, None
    bsdf = tree.nodes.get(BAKE_BSDF)
    if bsdf is None or bsdf.type != "BSDF_PRINCIPLED":
        bsdf = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    outputs = [n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"]
    out = next((n for n in outputs if n.is_active_output), outputs[0] if outputs else None)
    return bsdf, out


class _Rewire:
    """Le temps d'une cuisson, la sortie de chaque matériau = Emission(entrée choisie du BSDF, ou AO locale)."""

    def __init__(self, materials, source: str, ao_distance: float = 0.5, ao_samples: int = 32):
        self.materials = [m for m in materials if m is not None and m.node_tree is not None]
        self.source = source
        self.ao_distance = ao_distance
        self.ao_samples = ao_samples
        self._undo: list = []

    def __enter__(self):
        for mat in self.materials:
            tree = mat.node_tree
            bsdf, out = _principled(mat)
            if out is None:
                continue
            surface = out.inputs["Surface"]
            previous = surface.links[0].from_socket if surface.links else None
            emit = tree.nodes.new("ShaderNodeEmission")
            emit.inputs["Strength"].default_value = 1.0
            created = [emit]
            if self.source == "AO":
                ao = tree.nodes.new("ShaderNodeAmbientOcclusion")
                ao.only_local = True
                ao.samples = self.ao_samples
                ao.inputs["Distance"].default_value = self.ao_distance
                ao.inputs["Color"].default_value = (1, 1, 1, 1)
                tree.links.new(ao.outputs["AO"], emit.inputs["Color"])
                created.append(ao)
            elif bsdf is not None:
                socket = bsdf.inputs[self.source]
                if socket.links:
                    tree.links.new(socket.links[0].from_socket, emit.inputs["Color"])
                else:
                    value = socket.default_value
                    emit.inputs["Color"].default_value = tuple(value) if hasattr(value, "__len__") else (value, value, value, 1.0)
            else:
                print(f"[baker] {mat.name} : pas de Principled BSDF, passe {self.source} laissée noire")
                emit.inputs["Color"].default_value = (0, 0, 0, 1)
            tree.links.new(emit.outputs["Emission"], surface)
            self._undo.append((tree, surface, previous, created))
        return self

    def __exit__(self, *exc):
        for tree, surface, previous, created in self._undo:
            for node in created:
                tree.nodes.remove(node)
            if previous is not None:
                tree.links.new(previous, surface)
        return False


def _emits(materials) -> bool:
    for mat in materials:
        bsdf, _ = _principled(mat) if mat else (None, None)
        if bsdf is None:
            continue
        strength = bsdf.inputs["Emission Strength"]
        if strength.links or strength.default_value > 0:
            col = bsdf.inputs["Emission Color"]
            if col.links or any(c > 0 for c in col.default_value[:3]):
                return True
    return False


# =====================================================================================================================
# Images
# =====================================================================================================================

def _float_image(name: str, res: int, data: bool) -> bpy.types.Image:
    old = bpy.data.images.get(name)
    if old is not None:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, res, res, alpha=True, float_buffer=True)
    img.colorspace_settings.is_data = data
    return img


def _pixels(img: bpy.types.Image) -> np.ndarray:
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    return arr.reshape(h, w, 4)


def _linear_to_srgb(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1 / 2.4) - 0.055)


def save_png(arr: np.ndarray, path: Path, data: bool) -> Path:
    """Écrit un tableau HxWx4 (0-1, déjà dans l'espace voulu) en PNG 8 bits."""
    h, w, _ = arr.shape
    img = bpy.data.images.new(path.stem + "_out", w, h, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "Non-Color" if data else "sRGB"
    img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


# =====================================================================================================================
# Cuisson
# =====================================================================================================================

def _bake(kind: str, high, low, cage: float, max_ray: float, margin: int) -> None:
    _select_only([high, low], low)
    with bpy.context.temp_override(active_object=low, object=low, selected_objects=[high, low],
                                   selected_editable_objects=[high, low]):
        bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=cage, max_ray_distance=max_ray,
                            margin=margin, margin_type="EXTEND", use_clear=True, target="IMAGE_TEXTURES",
                            normal_space="TANGENT", normal_r="POS_X", normal_g="POS_Y", normal_b="POS_Z")


def build_baked_material(asset: str, maps: dict[str, Path], emissive_strength: float = 1.0) -> bpy.types.Material:
    """Matériau final du low : les PNG cuits branchés sur un Principled (aperçu Blender + export FBX / GLB)."""
    name = f"M_{asset}_Baked"
    old = bpy.data.materials.get(name)
    if old is not None:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    if hasattr(mat, "use_nodes") and not mat.use_nodes:
        mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    out.location, bsdf.location = (400, 0), (0, 0)
    tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def tex(key: str, y: int, data: bool):
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(str(maps[key]), check_existing=False)
        node.image.colorspace_settings.name = "Non-Color" if data else "sRGB"
        node.location = (-600, y)
        node.label = key
        return node

    color = tex("Color", 300, False)
    tree.links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    tree.links.new(tex("Roughness", 0, True).outputs["Color"], bsdf.inputs["Roughness"])
    tree.links.new(tex("Metalness", -300, True).outputs["Color"], bsdf.inputs["Metallic"])
    nmap = tree.nodes.new("ShaderNodeNormalMap")
    nmap.location = (-250, -600)
    tree.links.new(tex("Normal", -600, True).outputs["Color"], nmap.inputs["Color"])
    tree.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    if "Emissive" in maps:
        mask = tex("Emissive", -900, True)
        mul = tree.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = emissive_strength
        mul.location = (-250, -900)
        tree.links.new(mask.outputs["Color"], mul.inputs[0])
        tree.links.new(color.outputs["Color"], bsdf.inputs["Emission Color"])
        tree.links.new(mul.outputs["Value"], bsdf.inputs["Emission Strength"])
    return mat


def export_asset(obj: bpy.types.Object, asset: str, out_dir: Path, formats=("FBX", "GLB")) -> list[str]:
    """Exporte l'objet seul, pivot à l'origine (mêmes réglages FBX que les modèles de assets/models)."""
    files = []
    saved = obj.matrix_world.copy()
    obj.matrix_world = Matrix.Identity(4)
    _select_only([obj], obj)
    try:
        with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=[obj],
                                       selected_editable_objects=[obj]):
            if "FBX" in formats:
                path = out_dir / f"{asset}.fbx"
                bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"MESH"},
                                         use_mesh_modifiers=True, mesh_smooth_type="OFF", use_tspace=True,
                                         path_mode="COPY", embed_textures=True, add_leaf_bones=False,
                                         axis_forward="-Z", axis_up="Y")
                files.append(path.name)
            if "GLB" in formats:
                path = out_dir / f"{asset}.glb"
                try:
                    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                              export_apply=True, export_yup=True)
                    files.append(path.name)
                except (RuntimeError, TypeError, AttributeError) as err:
                    print(f"[baker] export GLB impossible : {err}")
    finally:
        obj.matrix_world = saved
    return files


def bake_asset(
    low: bpy.types.Object,
    asset: str,
    high: bpy.types.Object | None = None,
    out_dir: Path | str | None = None,
    resolution: int = 1024,
    samples: int = 32,
    ao_samples: int = 64,
    ao_strength: float = 0.55,
    ao_distance: float | None = None,
    cage_extrusion: float | None = None,
    max_ray_distance: float | None = None,
    margin_px: int = 8,
    uv_angle: float = 66.0,
    uv_margin: float = 0.03,
    formats=("FBX", "GLB"),
    gpu: bool = True,
    roughness_offset: float = 0.0,
) -> dict:
    """Prépare, déplie, cuit et exporte `low` (avec les détails de `high` s'il est donné). Renvoie un rapport.

    Après l'appel, `low` porte le matériau cuit (aperçu fidèle à Roblox) et `high` est intact.
    """
    t0 = time.time()
    scene = bpy.context.scene
    out = Path(out_dir) if out_dir else pipeline_root() / "baked_assets"
    out.mkdir(parents=True, exist_ok=True)

    prepare_mesh(low)
    temporary_high = high is None
    if temporary_high:
        high = low.copy()
        high.data = low.data.copy()
        high.name = f"{asset}_bake_source"
        for coll in low.users_collection:
            coll.objects.link(high)
    else:
        _apply_modifiers(high)
    unwrap(low, uv_angle, uv_margin)

    dims = low.dimensions
    size = max(dims.x, dims.y, dims.z, 0.01)
    cage = cage_extrusion if cage_extrusion is not None else (0.004 * size if temporary_high else 0.015 * size)
    max_ray = max_ray_distance if max_ray_distance is not None else cage * 2.5
    ao_dist = ao_distance if ao_distance is not None else 0.08 * size
    high_mats = list({slot.material for slot in high.material_slots if slot.material})
    emissive = _emits(high_mats)

    target = bpy.data.materials.new(f"{asset}_BAKE_TARGET")
    if hasattr(target, "use_nodes") and not target.use_nodes:
        target.use_nodes = True
    target.node_tree.nodes.clear()
    image_node = target.node_tree.nodes.new("ShaderNodeTexImage")
    target.node_tree.nodes.active = image_node
    low.data.materials.clear()
    low.data.materials.append(target)

    state = use_cycles(scene, samples, gpu)
    images: dict[str, bpy.types.Image] = {}
    passes = [("Color", "Base Color", False), ("Roughness", "Roughness", True), ("Metalness", "Metallic", True),
              ("AO", "AO", True)]
    try:
        for key, source, data in passes:
            img = _float_image(f"{asset}_{key}_bake", resolution, data)
            image_node.image = img
            scene.cycles.samples = ao_samples if key == "AO" else samples
            with _Rewire(high_mats, source, ao_distance=ao_dist, ao_samples=max(ao_samples // 2, 8)):
                _bake("EMIT", high, low, cage, max_ray, margin_px)
            images[key] = img
        if emissive:
            img = _float_image(f"{asset}_Emissive_bake", resolution, True)
            image_node.image = img
            scene.cycles.samples = samples
            with _Rewire(high_mats, "Emission Strength"):
                _bake("EMIT", high, low, cage, max_ray, margin_px)
            images["Emissive"] = img
        img = _float_image(f"{asset}_Normal_bake", resolution, True)
        image_node.image = img
        scene.cycles.samples = samples
        _bake("NORMAL", high, low, cage, max_ray, margin_px)
        images["Normal"] = img
    finally:
        restore_render(scene, state)

    # --- post-traitement (numpy) ---
    maps: dict[str, Path] = {}
    color = _pixels(images["Color"])
    ao = _pixels(images["AO"])[..., :1]
    shaded = color.copy()
    shaded[..., :3] = color[..., :3] * (1.0 - ao_strength * (1.0 - ao))
    shaded[..., :3] = _linear_to_srgb(shaded[..., :3])
    shaded[..., 3] = 1.0
    maps["Color"] = save_png(shaded, out / f"{asset}_Color.png", data=False)
    rough = _pixels(images["Roughness"])
    rough[..., :3] = np.clip(rough[..., :1] + roughness_offset, 0, 1)
    rough[..., 3] = 1.0
    maps["Roughness"] = save_png(rough, out / f"{asset}_Roughness.png", data=True)
    metal = _pixels(images["Metalness"])
    metal[..., :3] = metal[..., :1]
    metal[..., 3] = 1.0
    maps["Metalness"] = save_png(metal, out / f"{asset}_Metalness.png", data=True)
    normal = _pixels(images["Normal"])
    normal[..., 3] = 1.0
    maps["Normal"] = save_png(normal, out / f"{asset}_Normal.png", data=True)
    ao_img = np.repeat(_pixels(images["AO"])[..., :1], 4, axis=2)
    ao_img[..., 3] = 1.0
    maps["AO"] = save_png(ao_img, out / f"{asset}_AO.png", data=True)
    emissive_info = None
    if "Emissive" in images:
        # intensité seule : la couleur de la lueur est celle de la ColorMap (contrat de shader_node_library)
        strength = _pixels(images["Emissive"])[..., 0]
        peak = float(strength.max()) or 1.0
        mask = np.repeat((strength / peak)[..., None], 4, axis=2)
        mask[..., 3] = 1.0
        maps["Emissive"] = save_png(mask, out / f"{asset}_Emissive.png", data=True)
        emissive_info = {"EmissiveTint": "#FFFFFF", "EmissiveStrength": round(min(peak, 10.0), 2),
                         "coverage_pct": round(float((strength > peak * 0.25).mean() * 100), 2)}
    for img in images.values():
        bpy.data.images.remove(img)

    # --- matériau cuit + export ---
    baked = build_baked_material(asset, maps, emissive_info["EmissiveStrength"] if emissive_info else 1.0)
    low.data.materials.clear()
    low.data.materials.append(baked)
    bpy.data.materials.remove(target)
    set_origin_bottom_center(low)
    low.name = asset
    files = export_asset(low, asset, out, formats)

    if temporary_high:
        data = high.data
        bpy.data.objects.remove(high)
        bpy.data.meshes.remove(data)
        high = None

    tris = sum(len(p.vertices) - 2 for p in low.data.polygons)
    overlap = uv_overlap_ratio(low)
    report = {
        "asset": asset,
        "triangles": tris,
        "vertices": len(low.data.vertices),
        "size_studs": [round(low.dimensions.x, 3), round(low.dimensions.y, 3), round(low.dimensions.z, 3)],
        "pivot": "sol, au centre",
        "resolution": resolution,
        "uv_overlap_pct": round(overlap * 100, 2),
        "source_materials": sorted(m.name for m in high_mats),
        "presets": sorted({m.get("pipeline_preset", "?") for m in high_mats}),
        "bake": {"backend": state.get("backend"), "samples": samples, "ao_samples": ao_samples, "cage": round(cage, 4),
                 "max_ray": round(max_ray, 4), "ao_distance": round(ao_dist, 4), "ao_strength": ao_strength,
                 "from_high": not temporary_high},
        "maps": {k: p.name for k, p in maps.items()},
        "exports": files,
        "roblox": {
            "MeshPart": f"{asset} (Fichier > Importer 3D, ou le .fbx)",
            "SurfaceAppearance": {
                "ColorMap": maps["Color"].name, "NormalMap": maps["Normal"].name,
                "RoughnessMap": maps["Roughness"].name, "MetalnessMap": maps["Metalness"].name,
                **({"EmissiveMaskContent": maps["Emissive"].name, **emissive_info} if emissive_info else {}),
                "AlphaMode": "Overlay",
            },
            "notes": "Normal map OpenGL (+Y) tangent space ; ColorMap opaque (alpha 1) donc la couleur de la MeshPart "
                     "ne se voit pas ; limite Roblox 20 000 triangles par maillage, budget du pipeline 8 000.",
        },
        "within_budget": tris <= 8000,
        "seconds": round(time.time() - t0, 1),
    }
    (out / f"{asset}_manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[baker] {asset} : {tris} triangles, {len(maps)} cartes, {report['seconds']} s ({state.get('backend')})")
    return report


__all__ = ["pipeline_root", "prepare_mesh", "unwrap", "uv_overlap_ratio", "set_origin_bottom_center", "enable_gpu",
           "use_cycles", "restore_render", "save_png", "build_baked_material", "export_asset", "bake_asset"]
