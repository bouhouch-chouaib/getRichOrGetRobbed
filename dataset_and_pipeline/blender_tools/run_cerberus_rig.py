"""Cerbère Infernal ANIMÉ (25 oct., 2e version) : 12 pièces qui bougent dans Roblox (shared/PetMotion), 3 textures nettes.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b --factory-startup ^
        --python dataset_and_pipeline/blender_tools/run_cerberus_rig.py -- --res 1024 --qa-res 480 --qa-samples 48

Pourquoi : la 1re version était UN seul maillage (rien ne bougeait) et UNE texture de 1024 px découpée en ~1 000 îlots
minuscules (peau floue et « boueuse » dans Roblox, couleurs qui bavent entre îlots au loin). Ici :
  - pièces (block_creatures.CERBERUS_RIG) : Body, Head0-2, Jaw0-2 (mâchoires du bas), LegFL/FR/BL/BR, Tail ;
  - 3 textures de 1024 (Tetes, Corps, Pattes) au lieu d'une : ~3 fois plus de pixels, marges plus larges ;
  - gueules entrouvertes au repos (14°) : le jeu les ouvre et les referme (halètement, morsures).
Sorties : baked_assets/CerbereInfernal_Rig.fbx (12 objets nommés comme les MeshParts), CerbereInfernal_<Atlas>_*.png,
baked_assets/CerbereInfernal_rig.json (pivots, genres de mouvement, phases), qa_renders/cerberus_rig_board.png (repos
puis pose animée : têtes tournées, gueules ouvertes, pattes en avant), source/cerberus_rig.blend.
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
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
os.environ.setdefault("GRGR_PIPELINE_ROOT", str(ROOT))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import auto_pbr_baker as B  # noqa: E402
import block_creatures as BC  # noqa: E402
import procedural_geometry_recipes as G  # noqa: E402
import shader_node_library as S  # noqa: E402
import visual_qa_renderer as Q  # noqa: E402

for module in (S, G, B, Q, BC):
    importlib.reload(module)

NAME = "CerbereInfernal"
ATLASES = {
    "Tetes": ["Head0", "Jaw0", "Head1", "Jaw1", "Head2", "Jaw2"],
    "Corps": ["Body", "Tail"],
    "Pattes": ["LegFL", "LegFR", "LegBL", "LegBR"],
}
IMPORT_HEIGHT = 13.0  # studs visés à l'import dans Studio (le jeu remet ensuite à la taille de PetSizes)


def _args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"res": 1024, "qa_res": 480, "samples": 32, "qa_samples": 48}
    for key, value in zip(argv[::2], argv[1::2]):
        opts[key.lstrip("-").replace("-", "_")] = int(value)
    return opts


def _tag(obj: bpy.types.Object, index: int) -> None:
    attr = obj.data.attributes.get("rig_id") or obj.data.attributes.new("rig_id", "INT", "FACE")
    attr.data.foreach_set("value", [index] * len(obj.data.polygons))


def _split(obj: bpy.types.Object, names: list[str]) -> dict[str, bpy.types.Object]:
    """Recoupe l'objet cuit en pièces (attribut de face rig_id), dans le repère du monde."""
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


def _pose(parts: dict, pivots: dict) -> dict:
    """Copie posée (comme dans le jeu en pleine action) : chaque tête tourne autour de SON pivot, chaque mâchoire suit
    sa tête puis s'ouvre autour de sa charnière, pattes avant / arrière en diagonale, queue qui balaie."""
    head = {"Head0": (14, 0, 0), "Head1": (6, 0, 26), "Head2": (-4, 0, -22)}
    jaw = {"Jaw0": 26, "Jaw1": 8, "Jaw2": 20}
    legs = {"LegFL": 24, "LegBR": 24, "LegFR": -20, "LegBL": -20}

    def rot(pivot: Matrix, euler) -> Matrix:
        return pivot @ Euler([math.radians(a) for a in euler], "XYZ").to_matrix().to_4x4() @ pivot.inverted()

    posed = {}
    for name, obj in parts.items():
        dup = obj.copy()
        dup.name = f"{name}_Pose"
        bpy.context.scene.collection.objects.link(dup)
        m = Matrix.Identity(4)
        if name.startswith("Head"):
            m = rot(pivots[name], head[name])
        elif name.startswith("Jaw"):
            h = "Head" + name[-1]
            m = rot(pivots[h], head[h]) @ rot(pivots[name], (jaw[name], 0, 0))
        elif name in legs:
            m = rot(pivots[name], (legs[name], 0, 0))
        elif name == "Tail":
            m = rot(pivots[name], (0, 0, 28))
        dup.matrix_world = m @ obj.matrix_world
        posed[name] = dup
    return posed


def main() -> dict:
    opts = _args()
    t0 = time.time()
    if bpy.app.background:
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj)
    else:
        bpy.context.window.scene = bpy.data.scenes.new("Cerberus_Rig")

    G.set_detail("high")
    high = BC.build_blocky_cerberus(NAME + "_high", rig=True, jaw_open=14.0)
    G.set_detail("low")
    low = BC.build_blocky_cerberus(NAME + "_low", rig=True, jaw_open=14.0)
    G.set_detail("high")
    pivots = low["pivots"]
    missing = set(BC.CERBERUS_RIG) - set(low["rig"])
    assert not missing, f"pièces manquantes : {missing}"

    parts: dict[str, bpy.types.Object] = {}
    reports = {}
    for atlas, names in ATLASES.items():
        lows, highs = [], []
        for index, part in enumerate(names):
            lo = G.join(low["rig"][part], f"{part}_low")
            hi = G.join(high["rig"][part], f"{part}_high")
            _tag(lo, index)
            lows.append(lo)
            highs.append(hi)
        lo_all = G.join(lows, f"{NAME}_{atlas}")
        hi_all = G.join(highs, f"{NAME}_{atlas}_high")
        reports[atlas] = B.bake_asset(lo_all, f"{NAME}_{atlas}", high=hi_all, resolution=opts["res"],
                                      samples=opts["samples"], ao_distance=0.12, ao_strength=0.4, uv_margin=0.006,
                                      margin_px=16, formats=())
        parts.update(_split(bpy.data.objects[f"{NAME}_{atlas}"], names))
        bpy.data.objects.remove(bpy.data.objects[f"{NAME}_{atlas}"])
        hi_all.hide_render = hi_all.hide_viewport = True
        print(f"[CERBERE] atlas {atlas} : {reports[atlas]['triangles']} triangles, "
              f"UV {reports[atlas].get('uv_coverage_pct')} %")

    lo_b, hi_b = _bounds(parts.values())
    height = hi_b.z - lo_b.z
    rig = {"model_height_blender": round(height, 4), "front": "-Y Blender = -Z Roblox", "parts": {}}
    for name, obj in parts.items():
        a, b = _bounds([obj])
        rig["parts"][name] = {
            "kind": BC.CERBERUS_RIG[name],
            "phase": round(BC.CERBERUS_PHASES[name], 4),
            "atlas": next(k for k, v in ATLASES.items() if name in v),
            "triangles": len(obj.data.polygons),
            "center": [round(c, 5) for c in (a + b) / 2],
            "size": [round(c, 5) for c in b - a],
            "pivot": [[round(x, 6) for x in row] for row in pivots[name]] if name in pivots else None,
        }

    # FBX : les 12 pièces ensemble, noms = MeshParts du jeu. Échelle : ~13 studs de haut à l'import (mesuré le 25 oct. :
    # sans réglage, Studio lit 1 unité Blender = 100 studs).
    scale = IMPORT_HEIGHT / (height * 100.0)
    rig["fbx_global_scale"] = round(scale, 6)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts.values():
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts["Body"]
    fbx = ROOT / "baked_assets" / f"{NAME}_Rig.fbx"
    bpy.ops.export_scene.fbx(filepath=str(fbx), use_selection=True, object_types={"MESH"}, global_scale=scale,
                             apply_unit_scale=True, use_mesh_modifiers=True, mesh_smooth_type="OFF", use_tspace=True,
                             path_mode="COPY", embed_textures=True, add_leaf_bones=False, axis_forward="-Z", axis_up="Y")
    (ROOT / "baked_assets" / f"{NAME}_rig.json").write_text(json.dumps(rig, indent=2, ensure_ascii=False), "utf-8")

    posed = _pose(parts, pivots)
    qa =Q.render_qa_grid([
        {"label": "Cuit pour Roblox, 12 pièces (repos)", "objects": list(parts.values()), "kind": "baked"},
        {"label": "Pose animée (têtes, gueules, pattes, queue)", "objects": list(posed.values()), "kind": "baked"},
        {"label": "Gros plans des têtes", "objects": list(parts.values()), "kind": "baked",
         "views": ("tetes_face", "tete_gauche", "tete_droite", "dos")},
    ], out_path=ROOT / "qa_renders" / "cerberus_rig_board.png", resolution=opts["qa_res"], samples=opts["qa_samples"])
    for obj in posed.values():
        bpy.data.objects.remove(obj)

    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "source" / "cerberus_rig.blend"))
    summary = {
        "seconds": round(time.time() - t0, 1),
        "height_blender": round(height, 3),
        "fbx": fbx.name,
        "atlases": {k: {"triangles": r["triangles"], "uv_coverage_pct": r.get("uv_coverage_pct"),
                        "emissive_strength": r["roblox"]["SurfaceAppearance"].get("EmissiveStrength")}
                    for k, r in reports.items()},
        "triangles_total": sum(p["triangles"] for p in rig["parts"].values()),
        "clipping": low["clipping"],
        "qa": str(qa.get("path") if isinstance(qa, dict) else qa),
    }
    print("[CERBERE] " + json.dumps(summary, ensure_ascii=False))
    return summary


if __name__ == "__main__":
    main()
