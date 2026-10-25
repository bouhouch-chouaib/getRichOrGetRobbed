"""Regroupe plusieurs familiers déjà fabriqués (run_pet_rig.py) dans UN seul .fbx : un import Studio par lot.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b --factory-startup ^
        --python dataset_and_pipeline/blender_tools/export_lot.py -- --lot Lot01 --pets ChatRuelle,PigeonVilles

Pour chaque familier : ses pièces cuites sont reprises de source/pets/<Id>.blend, renommées « <Id>__<Pièce> »
(les noms doivent être uniques dans un .fbx), rangées sous un vide « <Id>_Rig », mises à 6 studs de haut et posées
côte à côte. Sortie : baked_assets/lots/<Lot>.fbx. Ensuite : import Studio, puis
tools/make_wire_script.py <Id> ... (il retrouve les pièces « <Id>__... » où qu'elles soient dans le Workspace).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
HEIGHT = 6.0  # studs (le jeu remet ensuite chaque familier à la taille de PetSizes)
SPACING = 9.0


def _args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = dict(zip([a.lstrip("-") for a in argv[::2]], argv[1::2]))
    return {"lot": opts.get("lot", "Lot"), "pets": [p for p in opts.get("pets", "").split(",") if p]}


def main() -> None:
    opts = _args()
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    scene = bpy.context.scene
    exported, report = [], {}
    for index, pet in enumerate(opts["pets"]):
        rig = json.loads((ROOT / "baked_assets" / "pets" / pet / f"{pet}_rig.json").read_text("utf-8"))
        names = list(rig["parts"])
        with bpy.data.libraries.load(str(ROOT / "source" / "pets" / f"{pet}.blend"), link=False) as (_, dst):
            dst.objects = names
        objs = [o for o in dst.objects if o is not None]
        assert len(objs) == len(names), f"{pet} : pièces manquantes dans le .blend"
        lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
        for obj in objs:
            for v in obj.data.vertices:
                co = obj.matrix_world @ v.co
                lo, hi = Vector(map(min, lo, co)), Vector(map(max, hi, co))
        s = HEIGHT / max(hi.z - lo.z, 1e-6)
        base = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        # même similitude (échelle uniforme + translation) pour toutes les pièces : rig.json reste valable
        m = Matrix.Translation((index * SPACING, 0, 0)) @ Matrix.Scale(s, 4) @ Matrix.Translation(-base)
        holder = bpy.data.objects.new(f"{pet}_Rig", None)
        scene.collection.objects.link(holder)
        for obj in objs:
            scene.collection.objects.link(obj)
            obj.data = obj.data.copy()
            obj.data.transform(m @ obj.matrix_world)
            obj.matrix_world = Matrix.Identity(4)
            obj.name = f"{pet}__{obj.name.split('.')[0]}"
            obj.parent = holder
            exported.append(obj)
        report[pet] = len(objs)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in exported:
        obj.select_set(True)
        if obj.parent:
            obj.parent.select_set(True)
    out = ROOT / "baked_assets" / "lots" / f"{opts['lot']}.fbx"
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=str(out), use_selection=True, object_types={"MESH", "EMPTY"}, global_scale=0.01,
                             apply_unit_scale=True, use_mesh_modifiers=True, mesh_smooth_type="OFF", use_tspace=True,
                             path_mode="COPY", embed_textures=True, add_leaf_bones=False, axis_forward="-Z", axis_up="Y")
    print("[LOT] " + json.dumps({"lot": opts["lot"], "fbx": str(out), "pets": report, "mb": round(out.stat().st_size / 1e6, 1)},
                                ensure_ascii=False))


if __name__ == "__main__":
    main()
