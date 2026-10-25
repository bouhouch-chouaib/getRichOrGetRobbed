"""Preuve de concept de la phase 1 : piédestal stylisé + œuf Mythique, modélisés, cuits, exportés, rendus.

En arrière-plan (sans ouvrir Blender) :
    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b --factory-startup ^
        --python dataset_and_pipeline/blender_tools/run_poc.py -- --res 1024 --qa-res 420

Dans le Blender ouvert (MCP Blender, execute_blender_code) : crée une scène « POC_Pipeline » sans toucher aux autres :
    p = r"C:\\...\\dataset_and_pipeline\\blender_tools\\run_poc.py"
    exec(open(p, encoding="utf-8").read(), {"__file__": p, "__name__": "__main__"})

Sorties : baked_assets/ (PNG, FBX, GLB, manifestes), qa_renders/preview.png + qa_report.json + hero.png,
source/poc_phase1.blend.
"""

from __future__ import annotations

import importlib
import json
import math
import os
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
os.environ.setdefault("GRGR_PIPELINE_ROOT", str(ROOT))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import auto_pbr_baker as B  # noqa: E402
import procedural_geometry_recipes as G  # noqa: E402
import shader_node_library as S  # noqa: E402
import visual_qa_renderer as Q  # noqa: E402

for module in (S, G, B, Q):
    importlib.reload(module)


def _args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"res": 1024, "qa_res": 420, "samples": 32, "qa_samples": 48}
    for key, value in zip(argv[::2], argv[1::2]):
        opts[key.lstrip("-").replace("-", "_")] = int(value)
    return opts


def fresh_scene() -> bpy.types.Scene:
    if bpy.app.background:
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj)
        return bpy.context.scene
    scene = bpy.data.scenes.new("POC_Pipeline")
    bpy.context.window.scene = scene
    return scene


def material_swatches(opts: dict) -> dict:
    """Les 4 familles de matériaux sur 4 formes, + la peau cuite (chemin « sans high » du baker) : materials.png."""
    swatches = []
    block = G.lathe("Swatch_Peint", [(0, 0), (1.0, 0), (1.0, 1.4), (0, 1.4)], segments=4, phase=math.pi / 4)
    G.assign_material(block, S.create_stylized_edge_wear_material(
        name="M_Swatch_Peint", base="#E0703A", accent="#F2B53A", crackle=0.5, crackle_scale=2.0, studs=0.5))
    G.add_bevel_finish(block, width=0.08, segments=3)
    swatches.append(block)
    ring = G.lathe("Swatch_Or", G.ring_profile(0.72, 0.3, 0.75, steps=16), segments=40, closed=True)
    G.assign_material(ring, S.create_etched_metal_or_gold(name="M_Swatch_Or", tint="#B8C0CC", scratches=0.8,
                                                          hammered=0.4, rust=0.35))
    G.smooth_by_angle(ring, 60)
    swatches.append(ring)
    pebble = G.lathe("Swatch_Peau", G.egg_profile(1.5, 1.7, rings=16), segments=24)
    G.add_organic_displace(pebble, texture="MUSGRAVE", strength=0.06, size=0.45, subdiv=2)
    G.assign_material(pebble, S.create_organic_scales_or_skin(name="M_Swatch_Peau", base="#2FA84F",
                                                              variation="#0E5A2E", stripes="#C7F05A", cells=9))
    swatches.append(pebble)
    gems = G.crystal_cluster("Swatch_Cristal", count=5, spread=0.45, radius=(0.15, 0.3), height=(0.7, 1.5), seed=4)
    G.assign_material(gems, S.create_stylized_crystal_or_gem(name="M_Swatch_Cristal", core="#06306E", mid="#2FB8FF",
                                                            rim="#DDF8FF", emission=0.6))
    G.add_bevel_finish(gems, width=0.012, segments=1, angle_deg=20)
    swatches.append(gems)
    for i, obj in enumerate(swatches):
        obj.location = (-6 + 4 * i, 30, 0)
        G.apply_modifiers(obj)

    skin_low = G.duplicate(pebble, "Swatch_Peau_cuite")
    skin_low.location.x += 16
    report = B.bake_asset(skin_low, "TestPeauOrganique", out_dir=Path(tempfile.mkdtemp(prefix="grgr_swatch_")),
                          resolution=512, samples=opts["samples"], formats=())
    rows = [{"label": o.name, "objects": [o], "kind": "procedural"} for o in swatches]
    rows.append({"label": "Peau cuite (sans high)", "objects": [bpy.data.objects["TestPeauOrganique"]], "kind": "baked"})
    Q.render_qa_grid(rows, out_path=ROOT / "qa_renders" / "materials.png", resolution=opts["qa_res"] // 2 + 60,
                     samples=opts["qa_samples"], views=("trois_quarts", "detail"))
    return report


def main() -> dict:
    opts = _args()
    t0 = time.time()
    fresh_scene()

    pedestal = G.build_stylized_pedestal()
    egg = G.build_mythic_gem_egg()
    for obj in (egg["high"], egg["low"]):
        obj.location.x += 8.0  # côte à côte dans le .blend ; le high et le low de l'œuf restent superposés

    reports = {
        "PiedestalStylise": B.bake_asset(pedestal["low"], "PiedestalStylise", high=pedestal["high"],
                                         resolution=opts["res"], samples=opts["samples"]),
        "OeufMythique": B.bake_asset(egg["low"], "OeufMythique", high=egg["high"],
                                     resolution=opts["res"], samples=opts["samples"]),
    }
    ped_low = bpy.data.objects["PiedestalStylise"]
    egg_low = bpy.data.objects["OeufMythique"]

    qa = Q.render_qa_grid([
        {"label": "Piédestal procédural", "objects": [pedestal["high"]], "kind": "procedural"},
        {"label": "Piédestal cuit", "objects": [ped_low], "kind": "baked"},
        {"label": "Œuf Mythique procédural", "objects": [egg["high"]], "kind": "procedural"},
        {"label": "Œuf Mythique cuit", "objects": [egg_low], "kind": "baked"},
    ], resolution=opts["qa_res"], samples=opts["qa_samples"])

    hero_egg = egg_low.copy()
    hero_egg.name = "Hero_OeufSurPiedestal"
    G.collection().objects.link(hero_egg)
    hero_egg.location = ped_low.location + Vector((0, 0, pedestal["top_z"]))
    Q.render_hero([ped_low, hero_egg], ROOT / "qa_renders" / "hero.png", resolution=900, samples=96)
    swatch_bake = material_swatches(opts)

    source = ROOT / "source"
    source.mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source / "poc_phase1.blend"), copy=True)
    summary = {"assets": reports, "qa": {"preview": qa["preview"], "rows": [
        {"label": r["label"], "triangles": r["triangles"],
         "flags": sorted({f for v in r["views"].values() for f in v.get("flags", [])})} for r in qa["rows"]]},
        "swatch_bake": {k: swatch_bake[k] for k in ("triangles", "uv_overlap_pct", "maps")},
        "seconds": round(time.time() - t0, 1)}
    (ROOT / "qa_renders" / "poc_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
                                                          encoding="utf-8")
    print(f"[POC] terminé en {summary['seconds']} s")
    return summary


if __name__ == "__main__":
    main()
