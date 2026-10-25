"""Cerbère Secret « en blocs sculptés » d'après le modèle de Chouaib (25 oct.) : high -> low, cuisson, planche, hero.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b --factory-startup ^
        --python dataset_and_pipeline/blender_tools/run_cerberus_blocks.py -- --res 1024 --qa-res 520 --qa-samples 64

Sorties : baked_assets/CerbereInfernal* (PNG, FBX, GLB, manifeste), qa_renders/cerberus_qa_board.png (+ _report.json),
qa_renders/cerberus_hero.png (sur le piédestal de la phase 1), source/cerberus_blocs.blend. Pas de tenons sur le
familier ; l'aura n'est pas un modèle mais un effet Roblox (voir vfx_tools/ et PIPELINE.md).
"""

from __future__ import annotations

import importlib
import json
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
os.environ.setdefault("GRGR_PIPELINE_ROOT", str(ROOT))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import auto_pbr_baker as B  # noqa: E402
import block_creatures as BC  # noqa: E402
import procedural_geometry_recipes as G  # noqa: E402
import shader_node_library as S  # noqa: E402
import visual_qa_renderer as Q  # noqa: E402

for module in (S, G, B, Q, BC):
    importlib.reload(module)

NAME = "CerbereInfernal"


def _args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"res": 1024, "qa_res": 520, "samples": 32, "qa_samples": 64, "hero_res": 1000}
    for key, value in zip(argv[::2], argv[1::2]):
        opts[key.lstrip("-").replace("-", "_")] = int(value)
    return opts


def main() -> dict:
    opts = _args()
    t0 = time.time()
    if bpy.app.background:
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj)
    else:
        bpy.context.window.scene = bpy.data.scenes.new("Cerberus_Blocs")

    G.set_detail("high")
    high = BC.build_blocky_cerberus(NAME + "_high")
    G.set_detail("low")
    low = BC.build_blocky_cerberus(NAME + "_low")
    G.set_detail("high")
    tris = {"high": G.triangle_count(high["pet"], evaluated=False), "low": G.triangle_count(low["pet"], evaluated=False)}
    print(f"[CERBERE] triangles {tris}, têtes {low['clipping']}")

    report = B.bake_asset(low["pet"], NAME, high=high["pet"], resolution=opts["res"], samples=opts["samples"],
                          ao_distance=0.12, ao_strength=0.4, uv_margin=0.003)
    pet = bpy.data.objects[NAME]
    qa = Q.render_qa_grid([
        {"label": "Procédural (high)", "objects": [high["pet"]], "kind": "procedural"},
        {"label": "Cuit pour Roblox (low)", "objects": [pet], "kind": "baked"},
        {"label": "Cuit : gros plans", "objects": [pet], "kind": "baked",
         "views": ("tetes_face", "tete_gauche", "tete_droite", "dos")},
    ], out_path=ROOT / "qa_renders" / "cerberus_qa_board.png", resolution=opts["qa_res"], samples=opts["qa_samples"])

    with bpy.data.libraries.load(str(ROOT / "source" / "poc_phase1.blend"), link=False) as (_, dst):
        dst.objects = ["PiedestalStylise"]
    ped = dst.objects[0]
    bpy.context.scene.collection.objects.link(ped)
    ped.location = (0, 14, 0)
    hero = pet.copy()
    hero.name = "Hero_" + NAME
    bpy.context.scene.collection.objects.link(hero)
    hero.matrix_world = Matrix.Translation(Vector(ped.location) + Vector((0, 0, 2.36))) @ Matrix.Scale(0.78, 4)
    Q.render_hero([ped, hero], ROOT / "qa_renders" / "cerberus_hero.png", resolution=opts["hero_res"], samples=128,
                  frame=[hero], view="vitrine")

    (ROOT / "source").mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "source" / "cerberus_blocs.blend"), copy=True)
    summary = {"triangles_game": report["triangles"], "triangles_high": tris["high"], "head_clipping": low["clipping"],
               "uv": {"overlap_pct": report["uv_overlap_pct"], "coverage_pct": report["uv_coverage_pct"]},
               "maps": report["maps"], "qa_flags": {r["label"]: sorted({f for v in r["views"].values()
                                                                        for f in v.get("flags", [])}) for r in qa["rows"]},
               "seconds": round(time.time() - t0, 1)}
    (ROOT / "qa_renders" / "cerberus_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
                                                               encoding="utf-8")
    print(f"[CERBERE] {json.dumps(summary, ensure_ascii=False)}")
    return summary


if __name__ == "__main__":
    main()
