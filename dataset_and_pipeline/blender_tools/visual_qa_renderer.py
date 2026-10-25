"""Validateur visuel (« Visual Self-Correction Loop ») — Blender 4.2+ / 5.0, Cycles.

render_qa_grid() monte un studio photo (éclairage 3 points : clé chaude, contre-jour, débouchage froid, ombre au
sol par shadow catcher), rend chaque sujet sous 4 angles (face, trois-quarts, profil, zoom détail) et assemble une
planche `qa_renders/preview.png`, plus `preview_report.json` (chiffres par vignette : couverture, contraste, détail).

Lecture de la planche : une ligne par sujet, dans l'ordre donné. Bandeau ORANGE en haut d'une vignette = rendu
procédural (nœuds Blender, haute définition) ; bandeau VERT = asset cuit, tel qu'il sera dans Roblox.

OBLIGATOIRE après chaque appel : ouvrir preview.png avec l'outil de lecture d'image (vision) et juger silhouette,
lisibilité des matières, arêtes, écart procédural / cuit. Les chiffres du rapport ne remplacent pas ce regard ; ils
signalent seulement les cas grossiers (vignette plate, objet minuscule, surexposition).

Rendu en « Standard » (pas AgX) : couleurs saturées, plus proches de Roblox que le rendu filmique par défaut.
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
from mathutils import Vector

VIEWS = {
    "face": {"dir": (0.0, -1.0, 0.14), "zoom": 1.0, "aim": 0.0},
    "trois_quarts": {"dir": (0.85, -1.0, 0.5), "zoom": 1.0, "aim": 0.0},
    "profil": {"dir": (1.0, 0.0, 0.14), "zoom": 1.0, "aim": 0.0},
    "detail": {"dir": (-0.6, -1.0, 0.6), "zoom": 0.48, "aim": 0.2},
    # gros plans pour les créatures à plusieurs têtes
    "tetes_face": {"dir": (0.0, -1.0, 0.3), "zoom": 0.55, "aim": 0.22},
    "tete_gauche": {"dir": (-1.0, -0.55, 0.35), "zoom": 0.5, "aim": 0.18},
    "tete_droite": {"dir": (1.0, -0.55, 0.35), "zoom": 0.5, "aim": 0.18},
    "dos": {"dir": (0.35, 1.0, 0.75), "zoom": 0.75, "aim": 0.05},
    "vitrine": {"dir": (0.3, -1.0, 0.38), "zoom": 0.95, "aim": 0.0},  # 3/4 presque de face : les 3 têtes visibles
}
KIND_COLORS = {"procedural": (1.0, 0.55, 0.1), "baked": (0.2, 0.85, 0.35)}
BG_TOP = np.array([0.30, 0.34, 0.45])
BG_BOTTOM = np.array([0.12, 0.13, 0.19])


def _root() -> Path:
    env = os.environ.get("GRGR_PIPELINE_ROOT")
    if env:
        return Path(env)
    return Path(__file__).resolve().parents[1]


def bounds(objs) -> tuple[Vector, Vector]:
    bpy.context.view_layer.update()  # matrix_world est périmée tant que la scène n'est pas réévaluée
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


# =====================================================================================================================
# Studio
# =====================================================================================================================

class Studio:
    """Caméra + 3 lumières + sol attrape-ombres + monde neutre, retirés par close()."""

    def __init__(self, scene: bpy.types.Scene):
        self.scene = scene
        self.coll = bpy.data.collections.new("QA_STUDIO")
        scene.collection.children.link(self.coll)
        self.saved = {"camera": scene.camera, "world": scene.world, "engine": scene.render.engine,
                      "transparent": scene.render.film_transparent, "res": (scene.render.resolution_x, scene.render.resolution_y),
                      "pct": scene.render.resolution_percentage, "filepath": scene.render.filepath,
                      "view": scene.view_settings.view_transform, "look": scene.view_settings.look}
        cam_data = bpy.data.cameras.new("QA_Cam")
        cam_data.lens = 50
        cam_data.sensor_width = 36
        cam_data.clip_end = 1000
        self.camera = bpy.data.objects.new("QA_Cam", cam_data)
        self.coll.objects.link(self.camera)
        scene.camera = self.camera
        self.lights = {}
        for key, (power, tint, size) in {"key": (1.0, (1.0, 0.93, 0.84), 1.2), "fill": (0.32, (0.78, 0.86, 1.0), 2.0),
                                         "rim": (1.25, (0.92, 0.96, 1.0), 0.8)}.items():
            data = bpy.data.lights.new(f"QA_{key}", "AREA")
            data.color = tint
            data.shape = "DISK"
            obj = bpy.data.objects.new(f"QA_{key}", data)
            self.coll.objects.link(obj)
            self.lights[key] = (obj, power, size)
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.0)
        mesh = bpy.data.meshes.new("QA_Floor")
        bm.to_mesh(mesh)
        bm.free()
        self.floor = bpy.data.objects.new("QA_Floor", mesh)
        self.coll.objects.link(self.floor)
        try:
            self.floor.is_shadow_catcher = True
        except AttributeError:
            pass
        world = bpy.data.worlds.new("QA_World")
        if hasattr(world, "use_nodes") and not world.use_nodes:
            world.use_nodes = True
        bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
        bg.inputs["Color"].default_value = (0.42, 0.46, 0.58, 1.0)
        bg.inputs["Strength"].default_value = 0.45
        self.world = world
        scene.world = world

    def frame(self, objs, view: str, energy: float = 1.0, ground=None) -> None:
        """Cadre `objs` ; le sol attrape-ombres va sous `ground` (défaut : objs). Il doit être sous TOUT ce qui est
        rendu : posé plus haut (ex. au pied d'un familier sur un socle), il masque ce qui est dessous."""
        spec = VIEWS[view]
        lo, hi = bounds(objs)
        center = (lo + hi) / 2
        radius = max((hi - lo).length / 2, 0.05)
        height = hi.z - lo.z
        target = center + Vector((0, 0, spec["aim"] * height))
        fov = 2 * math.atan(self.camera.data.sensor_width / 2 / self.camera.data.lens)
        dist = radius / math.sin(fov / 2) * 1.06 * spec["zoom"]
        direction = Vector(spec["dir"]).normalized()
        self.camera.location = target + direction * dist
        self.camera.rotation_euler = (target - self.camera.location).to_track_quat("-Z", "Y").to_euler()
        self.floor.location = (center.x, center.y, bounds(ground)[0].z if ground else lo.z)
        self.floor.scale = (radius * 12, radius * 12, 1)
        # lumières placées par rapport au sujet (pas à la caméra) : l'éclairage ne change pas d'une vue à l'autre
        d = radius * 3.2
        for key, az, el in (("key", -40, 42), ("fill", 65, 14), ("rim", 160, 38)):
            obj, power, size = self.lights[key]
            a, e = math.radians(az), math.radians(el)
            obj.location = center + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * d
            obj.rotation_euler = (center - obj.location).to_track_quat("-Z", "Y").to_euler()
            obj.data.size = size * radius
            # disque émetteur : éclairement au centre ~ P / (pi d²) ; 8 x d² -> ~2,5 W/m² pour la clé
            obj.data.energy = 8.0 * power * energy * d * d

    def close(self) -> None:
        s, saved = self.scene, self.saved
        s.camera = saved["camera"]
        s.world = saved["world"]
        s.render.film_transparent = saved["transparent"]
        s.render.resolution_x, s.render.resolution_y = saved["res"]
        s.render.resolution_percentage = saved["pct"]
        s.render.filepath = saved["filepath"]
        try:
            s.view_settings.view_transform = saved["view"]
            s.view_settings.look = saved["look"]
            s.render.engine = saved["engine"]
        except TypeError:
            pass
        for obj in list(self.coll.objects):
            data = obj.data
            bpy.data.objects.remove(obj)
            for pool in (bpy.data.meshes, bpy.data.lights, bpy.data.cameras):
                if data is not None and data.name in pool and data.users == 0:
                    pool.remove(data)
                    break
        bpy.data.collections.remove(self.coll)
        bpy.data.worlds.remove(self.world)


def _configure(scene: bpy.types.Scene, resolution: int, samples: int, gpu: bool) -> str:
    try:
        scene.render.engine = "CYCLES"
    except TypeError as err:
        raise RuntimeError(f"Cycles indisponible : {err}") from err
    backend = "CPU"
    if gpu:
        try:
            import auto_pbr_baker

            backend = auto_pbr_baker.enable_gpu(scene)
        except ImportError:
            pass
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    try:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    except TypeError:
        pass
    scene.render.film_transparent = True
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    settings = scene.render.image_settings
    settings.file_format = "PNG"
    settings.color_mode = "RGBA"
    settings.color_depth = "8"
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
    except TypeError:
        pass
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    return backend


def _render_to_array(scene: bpy.types.Scene, path: Path) -> np.ndarray:
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(path), check_existing=False)
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    return arr.reshape(h, w, 4)


def _isolate(subject) -> dict:
    """Cache au rendu tout ce qui n'est pas le sujet (ni le studio). Renvoie l'état à restaurer."""
    keep = {o.name for o in subject}
    saved = {}
    for obj in bpy.context.scene.objects:
        if obj.name.startswith("QA_"):
            continue
        saved[obj.name] = obj.hide_render
        obj.hide_render = obj.name not in keep
    return saved


def _restore(saved: dict) -> None:
    for name, hidden in saved.items():
        obj = bpy.data.objects.get(name)
        if obj is not None:
            obj.hide_render = hidden


def composite(rgba: np.ndarray, band: tuple | None = None) -> np.ndarray:
    """Pose le rendu transparent sur un fond en dégradé ; bandeau de couleur en haut si demandé."""
    h, w, _ = rgba.shape
    t = np.linspace(0, 1, h)[:, None, None]  # ligne 0 = bas de l'image (convention Blender)
    bg = BG_BOTTOM * (1 - t) + BG_TOP * t
    bg = np.broadcast_to(bg, (h, w, 3))
    a = rgba[..., 3:4]
    rgb = rgba[..., :3] * a + bg * (1 - a)
    if band is not None:
        rgb = rgb.copy()
        rgb[-max(h // 40, 4):, :, :] = band
    return rgb


def metrics(rgba: np.ndarray) -> dict:
    a = rgba[..., 3]
    mask = a > 0.5
    coverage = float(mask.mean())
    rgb = rgba[..., :3]
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    if not mask.any():
        return {"coverage": 0.0}
    lap = np.abs(4 * lum[1:-1, 1:-1] - lum[:-2, 1:-1] - lum[2:, 1:-1] - lum[1:-1, :-2] - lum[1:-1, 2:])
    inner = mask[1:-1, 1:-1] & mask[:-2, 1:-1] & mask[2:, 1:-1] & mask[1:-1, :-2] & mask[1:-1, 2:]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0)
    result = {
        "coverage": round(coverage, 3),
        "lum_mean": round(float(lum[mask].mean()), 3),
        "lum_std": round(float(lum[mask].std()), 3),
        "detail": round(float(lap[inner].mean()) if inner.any() else 0.0, 4),
        "saturation": round(float(sat[mask].mean()), 3),
    }
    flags = []
    if coverage < 0.06:
        flags.append("objet trop petit dans le cadre")
    if result["lum_std"] < 0.07:
        flags.append("plat : peu de contraste de lumière / matière")
    if result["detail"] < 0.01:
        flags.append("surface sans micro-détail")
    if result["lum_mean"] > 0.85:
        flags.append("surexposé")
    if result["lum_mean"] < 0.1:
        flags.append("sous-exposé")
    result["flags"] = flags
    return result


def _grid(tiles: list[list[np.ndarray]], gap: int = 6) -> np.ndarray:
    rows = len(tiles)
    cols = max(len(r) for r in tiles)
    h, w, _ = tiles[0][0].shape
    out = np.full((rows * h + (rows + 1) * gap, cols * w + (cols + 1) * gap, 3), 0.06, dtype=np.float32)
    for r, row in enumerate(tiles):
        for c, tile in enumerate(row):
            y = (rows - 1 - r) * (h + gap) + gap  # première ligne en haut
            x = c * (w + gap) + gap
            out[y:y + h, x:x + w] = tile
    return out


def _save_rgb(rgb: np.ndarray, path: Path) -> None:
    h, w, _ = rgb.shape
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((h, w, 1), dtype=np.float32)], axis=2)
    img = bpy.data.images.new(path.stem + "_qa", w, h, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "sRGB"
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


# =====================================================================================================================
# API
# =====================================================================================================================

def render_qa_grid(rows: list[dict], out_path: Path | str | None = None, resolution: int = 420, samples: int = 48,
                   views=("face", "trois_quarts", "profil", "detail"), gpu: bool = True) -> dict:
    """rows = [{"label": "Piédestal cuit", "objects": [obj, ...], "kind": "baked" | "procedural",
    "views": (optionnel, sinon `views`)}, ...]. Vues possibles : clés de VIEWS.

    Écrit preview.png (une ligne par sujet, une colonne par vue) et preview_report.json à côté. Renvoie le rapport.
    """
    t0 = time.time()
    scene = bpy.context.scene
    out = Path(out_path) if out_path else _root() / "qa_renders" / "preview.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.parent / "_tiles"
    tmp.mkdir(exist_ok=True)
    studio = Studio(scene)
    backend = _configure(scene, resolution, samples, gpu)
    tiles, report_rows = [], []
    try:
        for i, row in enumerate(rows):
            saved = _isolate(row["objects"])
            row_tiles, row_metrics = [], {}
            try:
                for view in row.get("views", views):
                    studio.frame(row["objects"], view)
                    rgba = _render_to_array(scene, tmp / f"r{i}_{view}.png")
                    row_metrics[view] = metrics(rgba)
                    row_tiles.append(composite(rgba, KIND_COLORS.get(row.get("kind"))))
            finally:
                _restore(saved)
            tiles.append(row_tiles)
            tris = sum(len(p.vertices) - 2 for o in row["objects"] if o.type == "MESH" for p in o.data.polygons)
            report_rows.append({"label": row["label"], "kind": row.get("kind"), "triangles": tris, "views": row_metrics})
    finally:
        studio.close()
    _save_rgb(_grid(tiles), out)
    for f in tmp.glob("*.png"):
        f.unlink()
    tmp.rmdir()
    report = {
        "preview": str(out),
        "layout": {"rows": [r["label"] for r in report_rows], "columns": list(views),
                   "bands": "orange = procédural Blender, vert = cuit (Roblox)"},
        "rows": report_rows,
        "render": {"engine": "CYCLES", "backend": backend, "samples": samples, "resolution": resolution,
                   "view_transform": "Standard", "seconds": round(time.time() - t0, 1)},
        "ACTION_REQUISE": "Ouvrir preview.png avec l'outil de lecture d'image et juger : silhouette lisible de loin, "
                          "matières différenciées, arêtes qui accrochent la lumière, cuit fidèle au procédural, "
                          "rien qui ressemble à un assemblage de primitives. Corriger puis relancer sinon.",
    }
    out.with_name(out.stem + "_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                                                        encoding="utf-8")
    print("=" * 100)
    print(f"[QA] planche : {out}")
    for r in report_rows:
        flags = sorted({f for v in r["views"].values() for f in v.get("flags", [])})
        print(f"[QA] {r['label']:<32} {r['triangles']:>7} tris  {('ALERTES : ' + ', '.join(flags)) if flags else 'ok'}")
    print("[QA] ACTION REQUISE : ouvrir preview.png avec l'outil de lecture d'image avant de continuer.")
    print("=" * 100)
    return report


def render_hero(objects, out_path: Path | str, resolution: int = 1024, samples: int = 96, view: str = "trois_quarts",
                gpu: bool = True, frame=None) -> Path:
    """Une image soignée d'une composition (ex. l'œuf posé sur le piédestal), même studio que la planche.
    frame = objets sur lesquels cadrer (défaut : tous) : cadrer sur le familier laisse le socle déborder du cadre."""
    scene = bpy.context.scene
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    studio = Studio(scene)
    _configure(scene, resolution, samples, gpu)
    saved = _isolate(objects)
    try:
        studio.frame(frame or objects, view, ground=objects)
        rgba = _render_to_array(scene, out.with_name(out.stem + "_raw.png"))
    finally:
        _restore(saved)
        studio.close()
    _save_rgb(composite(rgba), out)
    out.with_name(out.stem + "_raw.png").unlink(missing_ok=True)
    print(f"[QA] image : {out}")
    return out


__all__ = ["VIEWS", "Studio", "bounds", "composite", "metrics", "render_qa_grid", "render_hero"]
