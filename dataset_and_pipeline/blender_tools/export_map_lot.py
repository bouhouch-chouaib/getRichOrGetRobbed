"""Regroupe les 21 décors cuits de la carte (source/map_assets.blend) dans UN seul .fbx : un import Studio pour tout.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b --factory-startup ^
        --python dataset_and_pipeline/blender_tools/export_map_lot.py

Chaque décor garde son nom d'asset (le nom de la MeshPart dans Studio), sa vraie taille (global_scale 0,01 : 1 unité
Blender = 1 stud à l'import, comme export_lot.py) et son matériau cuit (textures intégrées au .fbx). Ils sont posés
côte à côte sur une ligne. Sortie : baked_assets/map/Decors_Carte.fbx. Ensuite : Fichier > Importer 3D dans Studio,
puis studio_tools/apply_map_look.lua (il range les MeshParts dans ReplicatedStorage.ArtModels.Map).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import environment_recipes as E  # noqa: E402

ROOT = HERE.parent
GAP = 6.0


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(ROOT / "source" / "map_assets.blend"), link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in E.BUILDERS]
    objs = [o for o in dst.objects if o is not None]
    missing = sorted(set(E.BUILDERS) - {o.name for o in objs})
    assert not missing, f"décors absents de map_assets.blend : {missing}"
    scene = bpy.context.scene
    x = 0.0
    for obj in sorted(objs, key=lambda o: list(E.BUILDERS).index(o.name)):
        scene.collection.objects.link(obj)
        w = obj.dimensions.x
        obj.matrix_world = Matrix.Translation((x + w / 2, 0, 0))
        x += w + GAP
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    out = ROOT / "baked_assets" / "map" / "Decors_Carte.fbx"
    bpy.ops.export_scene.fbx(filepath=str(out), use_selection=True, object_types={"MESH"}, global_scale=0.01,
                             apply_unit_scale=True, use_mesh_modifiers=True, mesh_smooth_type="OFF", use_tspace=True,
                             path_mode="COPY", embed_textures=True, add_leaf_bones=False, axis_forward="-Z", axis_up="Y")
    print("[MAP-LOT] " + json.dumps({"fbx": str(out), "decors": len(objs), "mb": round(out.stat().st_size / 1e6, 1)},
                                    ensure_ascii=False))


main()
