"""Créatures « en blocs sculptés » (style des gros jeux Roblox, ni voxels ni pâte à modeler) — Blender 4.2+ / 5.0.

Leçons du 25 oct. (Cerbère) : pas de tenons sur les familiers, pas de grille de voxels régulière (« Minecraft »),
pas de volumes trop épais. On assemble des blocs chanfreinés de tailles variées, effilés (taper), inclinés, empilés
comme des plaques d'armure, qui suivent les courbes du corps ; détails en petites pièces (rangées de dents, griffes
longues, pointes dorées, oreilles en escalier « pixel »), fissures de lave dans la matière (shader, cuites ensuite).

Briques : block(), stepped_plate(), tooth_row(), claw(), spike_ring(), puis blocky_wolf_head() et
build_blocky_cerberus() (d'après le modèle fourni par Chouaib le 25 oct.). Le niveau de finition suit
procedural_geometry_recipes.set_detail("high" | "low") : même forme, bevels riches pour le high, 1 segment pour le jeu.
"""

from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector, noise

import procedural_geometry_recipes as G
import shader_node_library as S


# =====================================================================================================================
# Briques
# =====================================================================================================================

def _matrix(center=(0, 0, 0), rot=(0, 0, 0)) -> Matrix:
    return Matrix.Translation(Vector(center)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


def block(name: str, size, center=(0, 0, 0), rot=(0, 0, 0), taper=(1.0, 1.0), shift=(0.0, 0.0)) -> bpy.types.Object:
    """Bloc (sx, sy, sz) ; taper = réduction du dessus en x / y (1 = droit), shift = décalage du dessus (penché)."""
    sx, sy, sz = size
    bm = bmesh.new()
    rings = []
    for z, (fx, fy), (dx, dy) in ((-sz / 2, (1.0, 1.0), (0.0, 0.0)), (sz / 2, taper, shift)):
        rings.append([bm.verts.new((sx / 2 * fx * a + dx, sy / 2 * fy * b + dy, z))
                      for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[1])
    for k in range(4):
        bm.faces.new((rings[0][k], rings[0][(k + 1) % 4], rings[1][(k + 1) % 4], rings[1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    obj = G._object_from_bmesh(name, bm)
    return G.transform(obj, _matrix(center, rot))


def stepped_plate(name: str, outline, thickness: float, center=(0, 0, 0), rot=(0, 0, 0)) -> bpy.types.Object:
    """Plaque épaisse au contour en escalier (oreille « pixel ») : outline = [(u, v), ...] dans le plan XZ."""
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new((u, -thickness / 2, v)) for u, v in outline])
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, thickness, 0), verts=moved)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    obj = G._object_from_bmesh(name, bm)
    return G.transform(obj, _matrix(center, rot))


def staircase_spike(width: float, height: float, steps: int = 5, lean: float = 0.0) -> list[tuple[float, float]]:
    """Contour d'une pointe en escalier (les deux bords en marches), pointe décalée de `lean` (oreille couchée).
    Parcours : bord droit de bas en haut, pointe, bord gauche de haut en bas."""
    right, left = [], []
    for k in range(steps):
        hw, off = width / 2 * (1 - k / steps), lean * k / steps
        right += [(off + hw, height * k / steps), (off + hw, height * (k + 1) / steps)]
    for k in reversed(range(steps)):
        hw, off = width / 2 * 0.85 * (1 - k / steps), lean * k / steps
        left += [(off - hw, height * (k + 1) / steps), (off - hw, height * k / steps)]
    return right + [(lean, height * 1.08)] + left


def tooth(name: str, base, direction, length: float, width: float) -> bpy.types.Object:
    """Dent / croc pointu (pyramide à 4 pans légèrement courbée)."""
    base, d = Vector(base), Vector(direction).normalized()
    side = d.cross(Vector((1, 0, 0))) if abs(d.x) < 0.9 else d.cross(Vector((0, 1, 0)))
    pts = [base, base + d * length * 0.55 + side * length * 0.04, base + d * length]
    return G.sweep(name, pts, [(width, width * 0.8), (width * 0.6, width * 0.5), (0.0, 0.0)], n=4, p=1.6,
                   normal_hint=(1, 0, 0))


def claw(name: str, root, direction, length: float = 0.32, width: float = 0.11) -> bpy.types.Object:
    """Griffe longue en bloc : section rectangulaire qui s'affine, recourbée vers le sol, bout émoussé."""
    root, d = Vector(root), Vector(direction).normalized()
    down = Vector((0, 0, -1))
    pts = [root, root + d * length * 0.45, root + d * length * 0.85 + down * length * 0.12,
           root + d * length + down * length * 0.25]
    return G.sweep(name, pts, [(width, width * 0.8, 3.5, 0.0), (width * 0.92, width * 0.72, 3.5, 0.0),
                               (width * 0.6, width * 0.5, 3.0, 0.0), (width * 0.18, width * 0.15, 2.5, 0.0)],
                   n=4, p=3.0, normal_hint=(1, 0, 0), up=(0, 0, 1))


def spike_band(name: str, radius: float, height: float, spikes: int, spike_len: float, sides: int = 8):
    """Bracelet / collier : anneau à pans (fer) + pointes dorées. Repère local : autour de +Z. Renvoie (anneau, pointes)."""
    ring = G.lathe(f"{name}_Anneau", [(radius, -height / 2), (radius + 0.08, -height / 2), (radius + 0.08, height / 2),
                                      (radius, height / 2)], segments=sides, phase=math.pi / sides, closed=True)
    points = []
    for k in range(spikes):
        a = 2 * math.pi * (k + 0.5) / spikes
        d = Vector((math.cos(a), math.sin(a), 0))
        base = d * (radius + 0.06)
        points.append(G.sweep(f"{name}_Pointe{k}", [base, base + d * spike_len * 0.5, base + d * spike_len],
                              [(height * 0.75, height * 0.75), (height * 0.38, height * 0.38), (0.0, 0.0)], n=4, p=1.6,
                              normal_hint=(0, 0, 1)))
    return ring, points


# =====================================================================================================================
# Tête de loup en blocs (d'après le modèle : crâne à plaques, arcade lourde en V, yeux de braise, gueule grande
# ouverte sur deux rangées de dents, oreilles en escalier, crête de cristaux)
# =====================================================================================================================

def blocky_wolf_head(name: str, jaw_open: float = 30.0, crest: bool = True, seed: int = 0) -> list[tuple]:
    """Pièces (objet, clé de matériau) dans le repère de la tête : regarde vers -Y, origine = sous le crâne."""
    P: list[tuple] = []
    P.append((block(f"{name}_Crane", (0.92, 0.72, 0.58), (0, 0.06, 0.37), taper=(0.86, 0.84)), "char"))
    P.append((block(f"{name}_Front", (0.56, 0.42, 0.1), (0, -0.02, 0.69), rot=(-8, 0, 0), taper=(0.9, 0.85)), "char"))
    P.append((block(f"{name}_Nuque", (0.7, 0.3, 0.32), (0, 0.42, 0.24), rot=(14, 0, 0)), "char"))
    for s in (-1, 1):
        # arcade en V (bout extérieur relevé) et œil de braise en biais dans son orbite sombre
        P.append((block(f"{name}_Arcade{s}", (0.5, 0.26, 0.17), (s * 0.24, -0.36, 0.63), rot=(16, s * -13, 0),
                        taper=(0.92, 0.8)), "char"))
        P.append((block(f"{name}_Orbite{s}", (0.34, 0.06, 0.16), (s * 0.24, -0.315, 0.48), rot=(0, s * -14, 0)), "socket"))
        P.append((block(f"{name}_Oeil{s}", (0.27, 0.06, 0.1), (s * 0.24, -0.34, 0.48), rot=(0, s * -16, 0),
                        taper=(0.8, 1.0)), "eye"))
        # joues en plaques évasées
        P.append((block(f"{name}_Joue{s}", (0.22, 0.5, 0.3), (s * 0.43, -0.2, 0.22), rot=(0, s * -6, s * 9),
                        taper=(0.8, 0.9)), "char"))
        # oreille en escalier, couchée vers l'arrière et vers l'extérieur, intérieur sombre
        outline = staircase_spike(0.42, 0.6, steps=5, lean=s * 0.06)
        P.append((stepped_plate(f"{name}_Oreille{s}", outline, 0.09, (s * 0.33, 0.22, 0.6), rot=(-14, s * 16, 0)),
                  "char"))
        inner = [(u * 0.55, v * 0.62) for u, v in outline]
        P.append((stepped_plate(f"{name}_OreilleIn{s}", inner, 0.05, (s * 0.335, 0.165, 0.66), rot=(-14, s * 16, 0)),
                  "socket"))

    # mâchoire du haut (museau) un peu relevée, pont du nez, truffe
    up = _matrix((0, -0.34, 0.27), (-7, 0, 0))
    upper = [
        (block(f"{name}_Museau", (0.62, 0.52, 0.26), (0, -0.28, 0.0), taper=(0.9, 0.95)), "char"),
        (block(f"{name}_Pont", (0.32, 0.44, 0.08), (0, -0.28, 0.165), taper=(0.85, 0.9)), "char"),
        (block(f"{name}_Truffe", (0.32, 0.14, 0.16), (0, -0.56, 0.1), taper=(0.85, 0.8)), "nose"),
    ]
    teeth_up = []
    for s in (-1, 1):
        for k in range(3):
            y = -0.07 - k * 0.12
            teeth_up.append((tooth(f"{name}_DentH{s}{k}", (s * 0.255, y, -0.1), (0, 0, -1), 0.13 + 0.03 * (k % 2), 0.085), "bone"))
        teeth_up.append((tooth(f"{name}_Croc{s}", (s * 0.21, -0.48, -0.1), (0, -0.15, -1), 0.27, 0.12), "bone"))
    for k in range(3):
        teeth_up.append((tooth(f"{name}_DentHF{k}", ((k - 1) * 0.1, -0.51, -0.1), (0, 0, -1), 0.11, 0.08), "bone"))
    for obj, key in upper + teeth_up:
        G.transform(obj, up)
        P.append((obj, key))

    # mâchoire du bas grande ouverte, gorge incandescente, dents du bas
    hinge = _matrix((0, -0.2, 0.12), (jaw_open, 0, 0))
    lower = [(block(f"{name}_Machoire", (0.58, 0.52, 0.17), (0, -0.28, -0.06), taper=(0.92, 0.9)), "char"),
             (block(f"{name}_Menton", (0.4, 0.16, 0.12), (0, -0.48, -0.13)), "char")]
    for s in (-1, 1):
        for k in range(3):
            lower.append((tooth(f"{name}_DentB{s}{k}", (s * 0.23, -0.1 - k * 0.12, 0.02), (0, 0, 1), 0.11 + 0.03 * (k % 2),
                                0.08), "bone"))
        lower.append((tooth(f"{name}_CrocB{s}", (s * 0.19, -0.46, 0.02), (0, 0.1, 1), 0.18, 0.1), "bone"))
    for obj, key in lower:
        G.transform(obj, hinge)
        P.append((obj, key))
    P.append((block(f"{name}_Gorge", (0.48, 0.42, 0.3), (0, -0.4, 0.14), rot=(14, 0, 0)), "throat"))

    if crest:
        cl = G.crystal_cluster(f"{name}_Crete", count=4, origin=(0, 0.05, 0.7), spread=0.16, radius=(0.05, 0.09),
                               height=(0.22, 0.42), tilt=(6, 26), seed=seed + 3)
        P.append((cl, "flame"))
    return P


# =====================================================================================================================
# Le Cerbère (modèle du 25 oct.)
# =====================================================================================================================

CERBERUS_MATERIALS = {
    # 25 oct. (2e version) : base un peu moins sombre et arêtes plus claires pour que les blocs se lisent sous la lumière
    # plus plate de Roblox ; grain plus gros (le grain fin devenait de la bouillie une fois réduit dans le jeu)
    "char": ("create_stylized_edge_wear_material", {"name": "M_CerbereB_Roche", "base": "#36302F", "accent": "#43362F",
             "edge": "#958980", "cavity": "#0B0909", "wear": 0.55, "roughness": 0.62, "edge_radius": 0.025,
             "grain_scale": 9.0, "brush_scale": 1.2, "magma": "#FF5A14", "magma_core": "#FFD45A", "magma_scale": 1.5,
             "magma_width": 0.022, "magma_glow": 3.2}),
    "socket": ("create_stylized_edge_wear_material", {"name": "M_CerbereB_Orbite", "base": "#141010", "edge": "#2E2624",
               "cavity": "#000000", "wear": 0.4, "roughness": 0.5}),
    "eye": ("create_stylized_edge_wear_material", {"name": "M_CerbereB_Yeux", "base": "#FF8A12", "edge": "#FFE07A",
            "cavity": "#E04A00", "wear": 0.3, "roughness": 0.25, "emission": 3.0, "edge_radius": 0.01}),
    "throat": ("create_stylized_edge_wear_material", {"name": "M_CerbereB_Gorge", "base": "#8C1406", "edge": "#FF6A12",
               "cavity": "#2A0404", "wear": 0.5, "roughness": 0.4, "emission": 2.4}),
    "bone": ("create_stylized_edge_wear_material", {"name": "M_CerbereB_Os", "base": "#EAD3A2", "edge": "#FFF6DC",
             "cavity": "#8A6E46", "wear": 0.6, "roughness": 0.4, "edge_radius": 0.01}),
    "nose": ("create_stylized_edge_wear_material", {"name": "M_CerbereB_Truffe", "base": "#161213", "edge": "#4A4240",
             "cavity": "#000000", "wear": 0.5, "roughness": 0.3}),
    "claw": ("create_stylized_edge_wear_material", {"name": "M_CerbereB_Griffes", "base": "#5E5C62", "edge": "#C4C2CA",
             "cavity": "#1A1A1E", "wear": 0.7, "roughness": 0.45, "edge_radius": 0.015}),
    "gold": ("create_etched_metal_or_gold", {"name": "M_CerbereB_Or", "tint": "#F5C451", "scratches": 0.4,
             "roughness": 0.4, "edge_polish": 0.9}),
    "iron": ("create_etched_metal_or_gold", {"name": "M_CerbereB_Fer", "tint": "#3E3A3C", "scratches": 0.7,
             "hammered": 0.4, "roughness": 0.45, "hammer_scale": 9.0}),
    "flame": ("create_stylized_crystal_or_gem", {"name": "M_CerbereB_Cristaux", "core": "#5A0E04", "mid": "#FF5A14",
              "rim": "#FFD08A", "emission": 2.2, "facet_variation": 0.3, "veins": 0.05}),
}

# finition : (largeur de bevel, segments, angle) par clé ; les petites pièces n'ont pas de bevel dans le low
FINISH = {"char": (0.03, 3, 30), "socket": (0.012, 1, 30), "eye": (0.012, 1, 30), "throat": (0.02, 2, 30),
          "bone": (0.008, 1, 25), "nose": (0.02, 2, 30), "claw": (0.012, 2, 30), "gold": (0.008, 1, 25),
          "iron": (0.02, 2, 35), "flame": (0.008, 1, 20)}


def _finish(items: list[tuple], mats: dict) -> list[bpy.types.Object]:
    out = []
    for obj, key, *_ in items:
        if key == "char":
            G.write_region_attribute(obj, "magma", lambda co: G._smooth01((noise.noise(obj.matrix_world @ co * 1.3 + Vector((4.1, 2.7, 9.3))) + 0.05) / 0.3))
        width, seg, angle = FINISH[key]
        out += G._finish_parts([(obj, mats[key])], bevel=width, segments=seg, angle=angle)
    return out


# Pièces animées dans Roblox (shared/PetMotion) : nom de la MeshPart -> genre de mouvement. Les pattes et la queue
# utilisent les mouvements existants (« Leg », « Tail »), les têtes et mâchoires les nouveaux (« Head », « Jaw »).
CERBERUS_RIG = {
    "Body": "Body", "Head0": "Head", "Jaw0": "Jaw", "Head1": "Head", "Jaw1": "Jaw", "Head2": "Head", "Jaw2": "Jaw",
    "LegFL": "Leg", "LegFR": "Leg", "LegBL": "Leg", "LegBR": "Leg", "Tail": "Tail",
}
# phase de chaque pièce : têtes décalées (elles ne regardent jamais au même endroit), pattes en diagonale (trot)
CERBERUS_PHASES = {"Head0": 0.0, "Jaw0": 0.0, "Head1": 2.1, "Jaw1": 2.1, "Head2": 4.2, "Jaw2": 4.2,
                   "LegFL": 0.0, "LegBR": 0.0, "LegFR": math.pi, "LegBL": math.pi, "Tail": 0.0, "Body": 0.0}


# (attache de la tête, lacet, tangage, roulis, échelle, base du cou, rayon du collier). Têtes ~70 % du volume,
# comme sur le modèle ; écarts vérifiés par clipping_report (0 = aucune tête ne traverse sa voisine).
CERBERUS_HEADS = [
    ((0.0, -1.0, 2.32), 0.0, 4.0, 0.0, 1.4, (0.0, -0.55, 1.9), 0.46),
    ((-1.4, -0.32, 1.98), -22.0, 0.0, 5.0, 1.2, (-0.5, -0.45, 1.8), 0.4),
    ((1.4, -0.34, 1.9), 24.0, -5.0, -5.0, 1.18, (0.5, -0.45, 1.75), 0.4),
]


def build_blocky_cerberus(name: str = "CerbereInfernal", seed: int = 5, join_parts: bool = True,
                          heads: list | None = None, rig: bool = False, jaw_open: float | None = None) -> dict:
    """Le Cerbère du modèle : torse en plaques empilées, pattes avant longues et écartées, gros pieds à 4 griffes,
    bracelets et colliers à pointes dorées, trois têtes en blocs gueules ouvertes, crêtes de cristaux.
    Face = -Y, pivot au sol. Renvoie {"pet": objet joint (ou "parts"), "clipping": {...}}.

    rig=True : découpé en pièces animées (CERBERUS_RIG), renvoie {"rig": {pièce: [objets]}, "pivots": {pièce: Matrix}}.
    Pivot = point de rotation dans le repère du monde (tête : base du crâne au bout du cou ; mâchoire : charnière ;
    patte : épaule / hanche ; queue : sa base), orienté comme la pièce (la tête de côté tourne autour de SON axe).
    jaw_open : ouverture des mâchoires au repos (degrés) ; None = gueules grandes ouvertes du modèle de référence."""
    mats = {k: S.PRESETS[p](**dict(params)) for k, (p, params) in CERBERUS_MATERIALS.items()}
    items: list[tuple] = []  # (objet, clé de matériau, pièce animée)
    pivots: dict[str, Matrix] = {}

    def add(obj, key: str, part: str = "Body"):
        items.append((obj, key, part))

    # --- torse : plaques empilées (poitrail en 3 couches), ventre, dos, bosse des épaules ---
    add(block(f"{name}_Poitrail", (1.2, 0.72, 0.86), (0, -0.32, 1.36), rot=(-8, 0, 0), taper=(0.92, 0.9)), "char")
    add(block(f"{name}_Ventre", (1.0, 0.8, 0.62), (0, 0.26, 1.18), rot=(4, 0, 0), taper=(0.95, 0.9)), "char")
    add(block(f"{name}_Dos", (1.06, 0.8, 0.24), (0, 0.22, 1.56), rot=(6, 0, 0), taper=(0.9, 0.92)), "char")
    add(block(f"{name}_Epaules", (1.36, 0.62, 0.36), (0, -0.4, 1.86), rot=(-12, 0, 0), taper=(0.88, 0.85)), "char")
    add(block(f"{name}_Croupe", (0.86, 0.4, 0.5), (0, 0.68, 1.2), rot=(18, 0, 0), taper=(0.85, 0.8)), "char")
    for k, z in enumerate((1.04, 1.3, 1.56)):
        w = 1.26 - 0.1 * k
        add(block(f"{name}_Plaque{k}", (w, 0.2, 0.27), (0, -0.74 - 0.02 * k, z), rot=(-10, 0, 0),
                  taper=(0.94, 0.8), shift=(0, 0.02)), "char")

    # --- pattes avant : longues, écartées, bracelet à pointes, gros pied à 4 griffes ---
    # côté : +X = gauche du chien (il regarde vers -Y)
    for s in (-1, 1):
        leg = "LegFL" if s > 0 else "LegFR"
        pivots[leg] = Matrix.Translation((s * 0.8, -0.5, 1.02))
        add(block(f"{name}_Epaule{s}", (0.56, 0.58, 0.56), (s * 0.7, -0.46, 1.16), rot=(0, s * 12, 0), taper=(0.9, 0.9)),
            "char")
        add(block(f"{name}_Bras{s}", (0.48, 0.48, 0.66), (s * 0.86, -0.62, 0.62), rot=(-6, s * 14, 0), taper=(0.92, 0.95)),
            "char", leg)
        add(block(f"{name}_Poignet{s}", (0.52, 0.52, 0.14), (s * 0.94, -0.7, 0.29), rot=(0, s * 8, 0)), "char", leg)
        add(block(f"{name}_Pied{s}", (0.8, 0.64, 0.22), (s * 0.98, -0.9, 0.11), rot=(0, 0, s * -6), taper=(0.92, 0.85)),
            "char", leg)
        band, points = spike_band(f"{name}_Bracelet{s}", 0.3, 0.17, 6, 0.3)
        place = _matrix((s * 0.9, -0.66, 0.44), (-6, s * 14, 0))
        add(G.transform(band, place), "iron", leg)
        for p in points:
            add(G.transform(p, place), "gold", leg)
        for t, dx in enumerate((-0.27, -0.09, 0.09, 0.27)):
            x = s * 0.98 + dx
            add(block(f"{name}_Doigt{s}{t}", (0.15, 0.22, 0.11), (x, -1.16, 0.13), rot=(-8, 0, 0)), "char", leg)
            add(claw(f"{name}_Griffe{s}{t}", (x, -1.24, 0.12), (dx * 0.4, -1, -0.15), 0.36, 0.12), "claw", leg)
    # --- pattes arrière : plus courtes, repliées, 3 griffes ---
    for s in (-1, 1):
        leg = "LegBL" if s > 0 else "LegBR"
        pivots[leg] = Matrix.Translation((s * 0.6, 0.48, 1.08))
        add(block(f"{name}_Cuisse{s}", (0.46, 0.6, 0.6), (s * 0.6, 0.5, 0.86), rot=(-14, s * 6, 0), taper=(0.9, 0.85)),
            "char", leg)
        add(block(f"{name}_Jarret{s}", (0.34, 0.36, 0.5), (s * 0.66, 0.62, 0.36), rot=(12, s * 6, 0)), "char", leg)
        add(block(f"{name}_PiedAR{s}", (0.54, 0.52, 0.18), (s * 0.68, 0.44, 0.09), taper=(0.92, 0.85)), "char", leg)
        band, points = spike_band(f"{name}_BraceletAR{s}", 0.2, 0.14, 5, 0.22)
        place = _matrix((s * 0.66, 0.62, 0.42), (12, s * 6, 0))
        add(G.transform(band, place), "iron", leg)
        for p in points:
            add(G.transform(p, place), "gold", leg)
        for t, dx in enumerate((-0.15, 0.0, 0.15)):
            add(claw(f"{name}_GriffeAR{s}{t}", (s * 0.68 + dx, 0.17, 0.1), (dx * 0.4, -1, -0.15), 0.24, 0.1), "claw", leg)

    # --- queue : segments dégressifs enchaînés (chaque bloc part du bout du précédent) + cristaux ---
    tip, ang = Vector((0, 0.82, 1.32)), 40.0
    pivots["Tail"] = Matrix.Translation(tip)
    for k in range(4):
        length = 0.3 - 0.03 * k
        d = Vector((0, math.cos(math.radians(ang)), math.sin(math.radians(ang))))
        seg = block(f"{name}_Queue{k}", (0.26 - 0.04 * k, 0.24 - 0.03 * k, length + 0.06), taper=(0.85, 0.85))
        add(G.transform(seg, G.frame_matrix(tip + d * length / 2, d)), "char", "Tail")
        tip, ang = tip + d * length, ang + 12
    tail = G.crystal_cluster(f"{name}_QueueCristaux", count=2, origin=tuple(tip - Vector((0, 0.04, 0.05))), spread=0.06,
                             radius=(0.04, 0.07), height=(0.2, 0.34), tilt=(10, 30), seed=seed + 9)
    add(tail, "flame", "Tail")

    # --- cous, colliers et trois têtes (Alpha au centre, plus grosse et plus haute) ---
    jaw_parts = ("_Machoire", "_Menton", "_DentB", "_CrocB")
    groups: dict[str, list] = {}
    for i, (anchor, yaw, pitch, roll, scale, base, collar_r) in enumerate(heads or CERBERUS_HEADS):
        anchor, base = Vector(anchor), Vector(base)
        mid = base.lerp(anchor, 0.55)
        neck_dir = (anchor - base).normalized()
        neck = block(f"{name}_Cou{i}", (0.6 * scale, 0.55 * scale, (anchor - base).length + 0.25),
                     (0, 0, 0), taper=(0.92, 0.92))
        G.transform(neck, G.frame_matrix(mid, neck_dir))
        add(neck, "char")
        band, points = spike_band(f"{name}_Collier{i}", collar_r, 0.18, 8, 0.32 * scale)
        place = G.frame_matrix(base.lerp(anchor, 0.42), neck_dir)
        add(G.transform(band, place), "iron")
        for p in points:
            add(G.transform(p, place), "gold")
        turn = Matrix.Translation(anchor) @ Euler((math.radians(pitch), math.radians(roll), math.radians(yaw)),
                                                  "XYZ").to_matrix().to_4x4()
        head_m = turn @ Matrix.Scale(scale, 4)
        pivots[f"Head{i}"] = turn
        pivots[f"Jaw{i}"] = Matrix.Translation(head_m @ Vector((0, -0.2, 0.12))) @ turn.to_3x3().to_4x4()
        group = groups.setdefault(("Alpha", "Gauche", "Droite")[i], [])
        opening = jaw_open if jaw_open is not None else (34.0 if i == 0 else 28.0)
        for obj, key in blocky_wolf_head(f"{name}_Tete{i}", jaw_open=opening, crest=i != 1, seed=seed + i):
            G.transform(obj, head_m)
            add(obj, key, f"Jaw{i}" if any(t in obj.name for t in jaw_parts) else f"Head{i}")
            group.append(obj)
    clipping = G.clipping_report(groups)

    if rig:
        parts: dict[str, list] = {}
        for obj, key, part in items:
            parts.setdefault(part, []).extend(_finish([(obj, key)], mats))
        return {"rig": parts, "pivots": pivots, "clipping": clipping, "materials": mats}
    objs = _finish(items, mats)
    if not join_parts:
        return {"parts": objs, "clipping": clipping, "materials": mats}
    return {"pet": G.join(objs, name), "clipping": clipping, "materials": mats}


__all__ = ["block", "stepped_plate", "staircase_spike", "tooth", "claw", "spike_band", "blocky_wolf_head",
           "build_blocky_cerberus", "CERBERUS_MATERIALS", "CERBERUS_RIG", "CERBERUS_PHASES"]
