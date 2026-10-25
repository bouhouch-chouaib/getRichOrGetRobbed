"""Exporte un asset cuit en fichier .mesh natif Roblox pour le VOIR dans Studio sans import ni envoi sur Roblox.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b dataset_and_pipeline/source/cerberus_blocs.blend ^
        --python dataset_and_pipeline/blender_tools/export_studio_mesh.py -- CerbereInfernal

Écrit studio_import/<Asset>.mesh (ignoré par git, se refait en 10 s). Pour l'aperçu dans Studio (25 oct., Cerbère) :
  1. copier le .mesh dans le dossier content de Studio :
     %LOCALAPPDATA%\\Roblox\\Versions\\version-<...>\\content\\claude\\<Asset>.mesh
  2. barre MCP (mode Édition) : AssetService:CreateMeshPartAsync(Content.fromUri("rbxasset://claude/<Asset>.mesh"))
     puis une SurfaceAppearance avec les cartes PNG de baked_assets/ envoyées par l'outil MCP upload_image.
Aperçu local seulement : le MeshPart ne marche que sur ce PC (ne pas publier le jeu avec). Pour le vrai jeu, importer le
.fbx (Fichier > Importer 3D). HttpService (EditableMesh lu sur un serveur local) ne marche pas depuis la barre MCP.

Conventions : (x, y, z) Blender -> (x, z, -y) Roblox (rotation, ordre des sommets gardé) ; V des UV inversé (format
.mesh) ; un sommet par combinaison (position, normale, UV) pour garder les arêtes vives ; maillage centré.
Format .mesh 2.00 : "version 2.00\\n", en-tête <HBBII (12, 36, 12, nb sommets, nb triangles), sommets de 9 float
(position, normale, U, V, 0), puis triangles en 3 uint32.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def export_roblox_mesh(obj: bpy.types.Object, out: Path) -> dict:
    """Fichier .mesh natif Roblox (version 2.00), lisible par Studio en local via rbxasset://."""
    me = obj.data
    me.calc_loop_triangles()
    mw = np.array(obj.matrix_world)
    rot = mw[:3, :3]
    co = np.empty((len(me.vertices), 3))
    me.vertices.foreach_get("co", co.ravel())
    co = co @ rot.T + mw[:3, 3]
    pos = np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)
    pos[:, 1] -= (pos[:, 1].min() + pos[:, 1].max()) / 2
    pos[:, [0, 2]] -= (pos[:, [0, 2]].min(0) + pos[:, [0, 2]].max(0)) / 2
    nl = len(me.loops)
    uv = np.empty((nl, 2))
    me.uv_layers.active.data.foreach_get("uv", uv.ravel())
    nrm = np.empty((nl, 3))
    me.corner_normals.foreach_get("vector", nrm.ravel())
    nrm = nrm @ rot.T
    nrm = np.stack([nrm[:, 0], nrm[:, 2], -nrm[:, 1]], axis=1)
    loop_vert = np.empty(nl, np.int64)
    me.loops.foreach_get("vertex_index", loop_vert)
    nt = len(me.loop_triangles)
    tl = np.empty((nt, 3), np.int64)
    me.loop_triangles.foreach_get("loops", tl.ravel())
    key = np.column_stack([loop_vert, np.round(uv * 65535), np.round(nrm * 32767)]).astype(np.int64)
    _, first, inverse = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inverse = inverse.ravel()
    verts = np.column_stack([pos[loop_vert[first]], nrm[first], uv[first, 0], 1.0 - uv[first, 1],
                             np.zeros(len(first))]).astype("<f4")
    faces = inverse[tl].astype("<u4")
    blob = b"version 2.00\n" + struct.pack("<HBBII", 12, 36, 12, len(verts), nt) + verts.tobytes() + faces.tobytes()
    out.write_bytes(blob)
    return {"verts": len(verts), "tris": nt, "size": [round(float(v), 3) for v in pos.max(0) - pos.min(0)]}


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    asset = argv[0] if argv else "CerbereInfernal"
    out = ROOT / "studio_import"
    out.mkdir(exist_ok=True)
    print(f"[studio] .mesh : {export_roblox_mesh(bpy.data.objects[asset], out / f'{asset}.mesh')}")


if __name__ == "__main__":
    main()
