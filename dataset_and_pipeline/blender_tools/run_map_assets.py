"""Construit, cuit et exporte les décors de la carte (phase 1.6), puis une planche de contrôle.

    blender.exe -b --factory-startup --python dataset_and_pipeline/blender_tools/run_map_assets.py -- [options]

Options : --only A,B (assets du catalogue)  --no-bake (formes seules, planche procédurale)  --samples 16
          --sheet-res 360  --sheet-samples 32
Sorties : baked_assets/map/<Asset>_*.png / .fbx / .glb / _manifest.json, baked_assets/map/map_assets_report.json,
          source/map_assets.blend (les low cuits, relus par run_map_scene.py), qa_renders/map_assets_board.png.
"""

from __future__ import annotations

import argparse
import importlib
import json
import math
import sys
import time
from pathlib import Path

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import shader_node_library as S  # noqa: E402
import procedural_geometry_recipes as G  # noqa: E402
import auto_pbr_baker as B  # noqa: E402
import visual_qa_renderer as Q  # noqa: E402
import environment_recipes as E  # noqa: E402

for m in (S, G, B, Q, E):
    importlib.reload(m)

ROOT = HERE.parent
OUT = ROOT / "baked_assets" / "map"


def _args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--only", default="")
    p.add_argument("--no-bake", action="store_true")
    p.add_argument("--samples", type=int, default=16)
    p.add_argument("--sheet-res", type=int, default=360)
    p.add_argument("--sheet-samples", type=int, default=32)
    p.add_argument("--cols", type=int, default=6)
    return p.parse_args(argv)


def contact_sheet(objs, out: Path, res: int, samples: int, cols: int, view: str = "trois_quarts") -> None:
    """Une vignette trois-quarts par asset (ordre du catalogue), grille de `cols` colonnes."""
    scene = bpy.context.scene
    studio = Q.Studio(scene)
    Q._configure(scene, res, samples, True)
    tmp = out.parent / "_tiles_map"
    tmp.mkdir(parents=True, exist_ok=True)
    tiles = []
    try:
        for i, obj in enumerate(objs):
            saved = Q._isolate([obj])
            try:
                studio.frame([obj], view)
                tiles.append(Q.composite(Q._render_to_array(scene, tmp / f"t{i}.png"), Q.KIND_COLORS["baked"]))
            finally:
                Q._restore(saved)
    finally:
        studio.close()
    blank = np.zeros_like(tiles[0])
    rows = [tiles[k:k + cols] + [blank] * (cols - len(tiles[k:k + cols])) for k in range(0, len(tiles), cols)]
    Q._save_rgb(Q._grid(rows), out)
    for f in tmp.glob("*.png"):
        f.unlink()
    tmp.rmdir()


def main() -> None:
    a = _args()
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    names = [n for n in E.BUILDERS if not a.only or n in a.only.split(",")]
    OUT.mkdir(parents=True, exist_ok=True)
    report = {}
    lows = []
    for i, name in enumerate(names):
        t = time.time()
        low, high = E.build(name)
        res = E.BUILDERS[name][1]
        if a.no_bake:
            G.delete(*(o for o in (high,) if o))
            info = {"triangles": G.triangle_count(low, evaluated=False)}
        else:
            info = B.bake_asset(low, name, high=high, out_dir=OUT, resolution=res, samples=a.samples, ao_samples=48,
                                ao_distance=min(2.5, 0.12 * max(low.dimensions)))
            if high:
                G.delete(high)
        info["within_6000"] = info["triangles"] <= 6000
        report[name] = {k: info[k] for k in ("triangles", "within_6000", "size_studs", "uv_overlap_pct", "seconds")
                        if k in info}
        low.location.x = (i % 7) * 30.0
        low.location.y = (i // 7) * 30.0
        lows.append(low)
        print(f"[map] {name}: {info['triangles']} triangles ({time.time() - t:.1f} s)")
    (OUT / "map_assets_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                                                encoding="utf-8")
    if not a.no_bake:
        (ROOT / "source").mkdir(exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "source" / "map_assets.blend"), compress=True)
    board = ROOT / "qa_renders" / ("map_assets_board.png" if not a.no_bake else "map_assets_shapes.png")
    contact_sheet(lows, board, a.sheet_res, a.sheet_samples, a.cols)
    over = [n for n, r in report.items() if not r["within_6000"]]
    print(f"[map] {len(names)} assets en {time.time() - t0:.0f} s ; planche {board}")
    print(f"[map] hors budget 6000 : {over or 'aucun'}")
    print("[map] ordre de la planche (gauche -> droite, haut -> bas) : " + ", ".join(names))


main()
