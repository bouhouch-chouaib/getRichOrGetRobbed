"""Kit des familiers « en briques LEGO lisses » (25 oct. 2026), pour tous les familiers du jeu.

Référence de style : images LEGO générées (dataset_and_pipeline/lego_refs/<Id>.png) : pièces en plastique brillant,
SANS tenons (Chouaib), formes rondes faites de plaques empilées, couleurs franches, grands yeux. Chaque familier est un
petit fichier pets/<Id>.py qui assemble ces pièces et dit à quelle partie animée chacune appartient :

    kit = PetKit(name)
    body = kit.mat("corps", "#8F9398")
    kit.add(kit.rounded(...), body)                         # pièce « Body » par défaut
    kit.add(kit.disc(...), kit.mat("oeil", "#F4F4F2"), "Head")
    kit.part("Head", "Head", pivot=(0, 0, 1.05))             # genre de mouvement + point de rotation
    return kit.result()

Genres (shared/PetMotion) : Body, Head, Jaw (charnière = pivot, suit Head<n> via `follows`), Leg, Wing, Tail, Ear,
FrogLeg, Fin, SwimTail, Leaf... Repère Blender : face = -Y, haut = +Z, gauche du familier = +X. run_pet_rig.py fait le
reste (high / low, cuisson, découpe, .fbx, rig.json, planche).
"""

from __future__ import annotations

import math

import bpy
from mathutils import Euler, Matrix, Vector

import block_creatures as BC
import procedural_geometry_recipes as G
import shader_node_library as S


def _hex(c) -> tuple[float, float, float]:
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))


def _tohex(rgb) -> str:
    return "#" + "".join(f"{max(0, min(255, round(v * 255))):02X}" for v in rgb)


def lighten(c: str, amount: float) -> str:
    return _tohex([v + (1 - v) * amount for v in _hex(c)])


def darken(c: str, amount: float) -> str:
    return _tohex([v * (1 - amount) for v in _hex(c)])


def rot_matrix(center=(0, 0, 0), rot=(0, 0, 0)) -> Matrix:
    return Matrix.Translation(Vector(center)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


class PetKit:
    """Collecte les pièces (objet, matériau, partie animée), les pivots et les genres de mouvement d'un familier."""

    def __init__(self, name: str):
        self.name = name
        self.items: list[tuple] = []  # (objet, matériau, partie, biseau)
        self.parts: dict[str, dict] = {"Body": {"kind": "Body", "phase": 0.0, "pivot": None}}
        self.materials: dict[str, bpy.types.Material] = {}
        self.atlases: dict[str, list[str]] | None = None
        self._n = 0

    # --- matériaux ---------------------------------------------------------------------------------------------
    def mat(self, key: str, color: str, rough: float = 0.3, glow: float = 0.0, metal: float = 0.0,
            accent: str | None = None) -> bpy.types.Material:
        """Plastique LEGO : aplat brillant, creux un peu plus sombres, presque pas de grain (le grain fin devient de
        la bouillie une fois réduit dans Roblox), pas d'usure des arêtes : sur les pièces rondes (lisses), l'usure
        éclaircissait toute la surface. glow = lueur (yeux, lave, néon)."""
        if key not in self.materials:
            self.materials[key] = S.create_stylized_edge_wear_material(
                name=f"M_{self.name}_{key}", base=color, edge=lighten(color, 0.12), cavity=darken(color, 0.4),
                accent=accent, wear=0.0, roughness=rough, brush_scale=0.45, grain_scale=4.0, edge_radius=0.012,
                bump_strength=0.08, emission=glow, metallic=metal)
        return self.materials[key]

    # --- formes -----------------------------------------------------------------------------------------------
    def _id(self, label: str) -> str:
        self._n += 1
        return f"{self.name}_{label}{self._n}"

    def box(self, size, center=(0, 0, 0), rot=(0, 0, 0), taper=(1.0, 1.0), shift=(0.0, 0.0), label="Bloc"):
        """Brique droite (block_creatures.block) : taper / shift pour les pentes LEGO."""
        return BC.block(self._id(label), size, center, rot, taper, shift)

    @staticmethod
    def _smooth(obj):
        obj["pet_smooth"] = True  # ombrage lisse au lieu des facettes (pièces rondes), voir result()
        return obj

    def rounded(self, sections, center=(0, 0, 0), rot=(0, 0, 0), axis="-Y", n=18, bulge=(0.2, 0.2), label="Rond"):
        """Volume arrondi le long d'un axe (sections (t, x, z, largeur, hauteur, p, taper) de G.loft) : p = 2
        ellipse, 2,6 « carré arrondi » LEGO, 4 presque carré. Ombrage lisse."""
        obj = G.loft(self._id(label), sections, axis=axis, n=n, bulge=bulge)
        return self._smooth(G.transform(obj, rot_matrix(center, rot)))

    def egg(self, length, width, height, center=(0, 0, 0), rot=(0, 0, 0), p=2.4, front=0.45, back=0.3, n=18,
            steps=10, sag=0.0, label="Oeuf"):
        """Corps « tonneau » rond (profil lisse sur `steps` sections) : front / back = taille relative des bouts
        (0 = pointu, 1 = droit), sag = ventre qui descend vers l'avant (z des sections décalé)."""
        L = length / 2
        sec = []
        for k in range(steps + 1):
            u = 1 - 2 * k / steps  # +1 arrière, -1 avant
            end = back if u > 0 else front
            f = end + (1 - end) * max(0.0, 1 - abs(u) ** 2.2) ** (1 / 2.2)
            sec.append((u * L, 0, -sag * (1 - u) / 2 * height, width * f, height * f, p, 0.0))
        return self.rounded(sec, center, rot, n=n, bulge=(0.3, 0.3), label=label)

    def disc(self, radius, thickness, center=(0, 0, 0), normal=(1, 0, 0), sides=24, label="Disque"):
        """Disque (œil, bouton, roue) : cylindre court dont la face regarde vers `normal`."""
        obj = G.lathe(self._id(label), [(0.0, -thickness / 2), (radius, -thickness / 2), (radius, thickness / 2),
                                        (0.0, thickness / 2)], segments=sides, closed=True)
        return G.transform(obj, G.frame_matrix(center, normal))

    def cylinder(self, radius, height, center=(0, 0, 0), rot=(0, 0, 0), sides=20, top=None, label="Cylindre"):
        """Cylindre vertical (cou, patte, tige), top = rayon du haut (cône si différent)."""
        r2 = radius if top is None else top
        obj = G.lathe(self._id(label), [(0.0, -height / 2), (radius, -height / 2), (r2, height / 2), (0.0, height / 2)],
                      segments=sides, closed=True)
        return G.transform(obj, rot_matrix(center, rot))

    def band(self, points, width, thickness, label="Bande"):
        """Bande plate qui suit un chemin (liseré d'aile, rayure, bouche) : section rectangulaire arrondie."""
        return self._smooth(G.sweep(self._id(label), points, [(width, thickness, 6.0, 0.0)] * len(points), n=8, p=6.0))

    def spike(self, base, direction, length, width, label="Pointe"):
        return BC.tooth(self._id(label), base, direction, length, width)

    def arc(self, center, radius, a0, a1, plane="YZ", steps=10):
        """Points d'un arc de cercle (degrés) dans un plan, pour band()."""
        c = Vector(center)
        pts = []
        for k in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * k / steps)
            u, v = math.cos(a) * radius, math.sin(a) * radius
            pts.append(c + (Vector((0, u, v)) if plane == "YZ" else Vector((u, 0, v)) if plane == "XZ" else Vector((u, v, 0))))
        return pts

    # --- assemblage -------------------------------------------------------------------------------------------
    def add(self, obj, material, part: str = "Body", bevel: float = 0.03):
        """Ajoute une pièce. bevel = largeur du chanfrein (0 pour les très petites pièces)."""
        self.items.append((obj, material, part, bevel))
        if part not in self.parts:
            self.parts[part] = {"kind": "Body", "phase": 0.0, "pivot": None}
        return obj

    def part(self, part: str, kind: str, pivot=(0, 0, 0), rot=(0, 0, 0), phase: float = 0.0, follows: str | None = None):
        """Genre de mouvement d'une partie et son pivot (point de rotation, orienté par rot en degrés). Jaw : pivot =
        charnière, follows = la tête qu'elle suit."""
        entry = self.parts.setdefault(part, {})
        entry.update(kind=kind, phase=phase, pivot=rot_matrix(pivot, rot), follows=follows)

    def result(self) -> dict:
        """Finit les pièces (matériau, chanfrein) et les range par partie : le format de run_pet_rig.py."""
        rig: dict[str, list] = {}
        for obj, material, part, bevel in self.items:
            smooth = bool(obj.get("pet_smooth"))
            done = G._finish_parts([(obj, material)], bevel=0.0 if smooth else bevel, segments=3, angle=30)
            if smooth:
                for o in done:
                    G.smooth_by_angle(o, 70.0)
            rig.setdefault(part, []).extend(done)
        return {"rig": rig, "parts": self.parts, "atlases": self.atlases or {"Corps": list(rig)}}


__all__ = ["PetKit", "lighten", "darken", "rot_matrix"]
