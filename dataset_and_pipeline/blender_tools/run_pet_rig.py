"""Fabrique un familier animé (n'importe lequel) : la recette du Cerbère (run_cerberus_rig.py) rendue générique.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b --factory-startup ^
        --python dataset_and_pipeline/blender_tools/run_pet_rig.py -- --pet PigeonVilles [--res 1024] [--qa-res 420]

Le familier est décrit par blender_tools/pets/<Id>.py : une fonction build(name) qui renvoie PetKit.result()
(pièces par partie animée, genres de mouvement, pivots, atlas). Ici : high puis low (même recette, finition différente),
cuisson Cycles par atlas, recoupe en pièces, export. Sorties dans baked_assets/pets/<Id>/ :
  <Id>_Rig.fbx (une pièce = une MeshPart, nommées comme les parties), <Id>_<Atlas>_*.png, <Id>_rig.json (pivots,
  genres, phases, boîtes), et qa_renders/pets/<Id>_board.png (repos, pose animée, gros plans) + source/pets/<Id>.blend.
Ensuite : import Studio du .fbx, puis tools/make_wire_script.py <Id> (attributs de mouvement + rangement dans ArtModels).
"""

from __future__ import annotations

import importlib
import json
import math
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
for p in (HERE, HERE / "pets"):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))
os.environ.setdefault("GRGR_PIPELINE_ROOT", str(ROOT))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import auto_pbr_baker as B  # noqa: E402
import block_creatures as BC  # noqa: E402
import pet_kit as K  # noqa: E402
import procedural_geometry_recipes as G  # noqa: E402
import shader_node_library as S  # noqa: E402
import visual_qa_renderer as Q  # noqa: E402

for module in (S, G, B, Q, BC, K):
    importlib.reload(module)

IMPORT_HEIGHT = 6.0  # studs à l'import dans Studio (le jeu remet ensuite le familier à la taille de PetSizes)


def _args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"pet": "PigeonVilles", "res": 1024, "qa_res": 420, "samples": 32, "qa_samples": 40}
    for key, value in zip(argv[::2], argv[1::2]):
        key = key.lstrip("-").replace("-", "_")
        opts[key] = value if key == "pet" else int(value)
    return opts


def _tag(obj, index: int) -> None:
    attr = obj.data.attributes.get("rig_id") or obj.data.attributes.new("rig_id", "INT", "FACE")
    attr.data.foreach_set("value", [index] * len(obj.data.polygons))


def _split(obj, names: list[str]) -> dict:
    out = {}
    for index, part in enumerate(names):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        layer = bm.faces.layers.int.get("rig_id")
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f[layer] != index], context="FACES")
        mesh = bpy.data.meshes.new(part)
        bm.to_mesh(mesh)
        bm.free()
        mesh.transform(obj.matrix_world)
        for mat in obj.data.materials:
            mesh.materials.append(mat)
        piece = bpy.data.objects.new(part, mesh)
        bpy.context.scene.collection.objects.link(piece)
        out[part] = piece
    return out


def _bounds(objs) -> tuple[Vector, Vector]:
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for obj in objs:
        for v in obj.data.vertices:
            co = obj.matrix_world @ v.co
            lo = Vector(map(min, lo, co))
            hi = Vector(map(max, hi, co))
    return lo, hi


def _rot(pivot: Matrix, euler) -> Matrix:
    return pivot @ Euler([math.radians(a) for a in euler], "XYZ").to_matrix().to_4x4() @ pivot.inverted()


def _pose_matrix(name: str, info: dict, parts_info: dict) -> Matrix:
    """Pose de démonstration par genre (comme dans le jeu en pleine action)."""
    kind, pivot = info["kind"], info.get("pivot")
    if pivot is None or kind == "Body":
        return Matrix.Identity(4)
    side = 1 if pivot.translation.x > 0.02 else -1 if pivot.translation.x < -0.02 else 0
    if kind == "Head":
        return _rot(pivot, (10, 0, 24))
    if kind == "Jaw":
        head = parts_info.get(info.get("follows") or "", {})
        base = _rot(head["pivot"], (10, 0, 24)) if head.get("pivot") is not None else Matrix.Identity(4)
        return base @ _rot(pivot, (22, 0, 0))
    if kind in ("Leg", "Arm"):
        return _rot(pivot, (24 if info.get("phase", 0) < 1 else -20, 0, 0))
    if kind == "Wing":
        return _rot(pivot, (0, side * -28, 0))
    if kind in ("Tail", "SwimTail"):
        return _rot(pivot, (8, 0, 26))
    if kind in ("Ear", "Fin", "Leaf"):
        return _rot(pivot, (0, side * -18, 0))
    if kind == "FrogLeg":
        return _rot(pivot, (-28, 0, 0))
    return Matrix.Identity(4)


def main() -> dict:
    opts = _args()
    pet_id = opts["pet"]
    t0 = time.time()
    if bpy.app.background:
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj)
    spec = importlib.import_module(pet_id)
    importlib.reload(spec)

    G.set_detail("high")
    high = spec.build(pet_id + "_high")
    G.set_detail("low")
    low = spec.build(pet_id + "_low")
    G.set_detail("high")
    parts_info = low["parts"]
    out_dir = ROOT / "baked_assets" / "pets" / pet_id
    out_dir.mkdir(parents=True, exist_ok=True)

    parts: dict[str, bpy.types.Object] = {}
    reports = {}
    for atlas, names in low["atlases"].items():
        lows, highs = [], []
        for index, part in enumerate(names):
            lo = G.join(low["rig"][part], f"{part}_low")
            hi = G.join(high["rig"][part], f"{part}_high")
            _tag(lo, index)
            lows.append(lo)
            highs.append(hi)
        lo_all = G.join(lows, f"{pet_id}_{atlas}")
        hi_all = G.join(highs, f"{pet_id}_{atlas}_high")
        reports[atlas] = B.bake_asset(lo_all, f"{pet_id}_{atlas}", high=hi_all, out_dir=out_dir,
                                      resolution=opts["res"], samples=opts["samples"], ao_distance=0.06,
                                      ao_strength=0.35, uv_margin=0.006, margin_px=16, formats=())
        parts.update(_split(bpy.data.objects[f"{pet_id}_{atlas}"], names))
        bpy.data.objects.remove(bpy.data.objects[f"{pet_id}_{atlas}"])
        hi_all.hide_render = hi_all.hide_viewport = True

    lo_b, hi_b = _bounds(parts.values())
    height = hi_b.z - lo_b.z
    rig = {"pet": pet_id, "model_height_blender": round(height, 4), "front": "-Y Blender = -Z Roblox", "parts": {}}
    for name, obj in parts.items():
        a, b = _bounds([obj])
        info = parts_info[name]
        atlas = next(k for k, v in low["atlases"].items() if name in v)
        rig["parts"][name] = {
            "kind": info["kind"],
            "phase": round(float(info.get("phase", 0.0)), 4),
            "follows": info.get("follows"),
            "atlas": atlas,
            "emissive_strength": reports[atlas]["roblox"]["SurfaceAppearance"].get("EmissiveStrength"),
            "triangles": len(obj.data.polygons),
            "center": [round(c, 5) for c in (a + b) / 2],
            "size": [round(c, 5) for c in b - a],
            "pivot": [[round(x, 6) for x in row] for row in info["pivot"]] if info.get("pivot") is not None else None,
        }

    scale = IMPORT_HEIGHT / (height * 100.0)  # sans réglage, Studio lit 1 unité Blender = 100 studs
    rig["fbx_global_scale"] = round(scale, 6)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts.values():
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts.get("Body") or next(iter(parts.values()))
    fbx = out_dir / f"{pet_id}_Rig.fbx"
    bpy.ops.export_scene.fbx(filepath=str(fbx), use_selection=True, object_types={"MESH"}, global_scale=scale,
                             apply_unit_scale=True, use_mesh_modifiers=True, mesh_smooth_type="OFF", use_tspace=True,
                             path_mode="COPY", embed_textures=True, add_leaf_bones=False, axis_forward="-Z", axis_up="Y")
    (out_dir / f"{pet_id}_rig.json").write_text(json.dumps(rig, indent=2, ensure_ascii=False), "utf-8")

    posed = {}
    for name, obj in parts.items():
        dup = obj.copy()
        dup.name = f"{name}_Pose"
        bpy.context.scene.collection.objects.link(dup)
        dup.matrix_world = _pose_matrix(name, parts_info[name], parts_info) @ obj.matrix_world
        posed[name] = dup
    board = ROOT / "qa_renders" / "pets" / f"{pet_id}_board.png"
    board.parent.mkdir(parents=True, exist_ok=True)
    Q.render_qa_grid([
        {"label": f"{pet_id} cuit, {len(parts)} pièces (repos)", "objects": list(parts.values()), "kind": "baked"},
        {"label": "Pose animée", "objects": list(posed.values()), "kind": "baked"},
    ], out_path=board, resolution=opts["qa_res"], samples=opts["qa_samples"])
    for obj in posed.values():
        bpy.data.objects.remove(obj)
    blend = ROOT / "source" / "pets" / f"{pet_id}.blend"
    blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))

    summary = {"pet": pet_id, "seconds": round(time.time() - t0, 1), "height_blender": round(height, 3),
               "parts": len(parts), "triangles": sum(p["triangles"] for p in rig["parts"].values()),
               "atlases": {k: {"uv_coverage_pct": r.get("uv_coverage_pct")} for k, r in reports.items()},
               "board": str(board)}
    print("[PET] " + json.dumps(summary, ensure_ascii=False))
    return summary


if __name__ == "__main__":
    main()
