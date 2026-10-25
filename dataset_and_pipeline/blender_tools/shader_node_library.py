"""Usine de matériaux PBR procéduraux (Blender 4.2+ / 5.0, moteur Cycles).

Quatre familles de matériaux « jeu stylisé » construites en nœuds, sans aucune texture image :

    create_stylized_edge_wear_material()  peint à la main : arêtes éclaircies, creux assombris, craquelures, tenons
    create_etched_metal_or_gold()         métal / or : micro-rayures, martelé, arêtes polies, creux ternis, rouille
    create_organic_scales_or_skin()       peau / écailles : cellules, variations de teinte, SSS, relief, rayures
    create_stylized_crystal_or_gem()      cristal : dégradé interne, facettes, arêtes lumineuses, Fresnel, cœur émissif

CONTRAT DE CUISSON (lu par auto_pbr_baker) : chaque matériau se termine par UN SEUL Principled BSDF nommé
"BAKE_BSDF", branché directement sur la sortie. Pas de Mix Shader. Le baker lit Base Color, Metallic, Roughness,
Normal et Emission Strength de ce nœud. Tout ce qui doit survivre dans Roblox passe par ces entrées.
Émission : Emission Color = Base Color (Roblox calcule la lueur = ColorMap x masque x EmissiveTint), seule l'intensité
varie (Emission Strength, constante ou masque) ; une lueur d'une autre couleur que la surface ne se cuit pas.

Limites à connaître (Cycles cuit « vu de face », la caméra regarde le long de la normale) :
- Layer Weight / Fresnel ne donne rien à la cuisson (facing = 0) : il enrichit le rendu Blender seulement. Le dégradé
  cuisible du cristal vient de la position (attribut "grad" ou coordonnées Generated) et des arêtes.
- Anisotropie, SSS, Coat : rendu Blender seulement (Roblox ne les a pas). Ils ne faussent pas les cartes cuites.
- Pointiness dépend de la densité du maillage : on l'associe toujours au nœud Bevel (indépendant du maillage).

Attributs de maillage optionnels lus par les matériaux (écrits par procedural_geometry_recipes) :
    "grad"  (float, 0 -> 1)  dégradé interne d'un cristal / d'un œuf (0 = cœur, 1 = pointe ou bord)
    "facet" (float, 0 -> 1)  valeur aléatoire par face, pour que chaque facette de gemme ait sa propre teinte

Toutes les couleurs s'écrivent en hexadécimal sRGB ("#FF4678") ou en tuple sRGB 0-1 ; la conversion en linéaire est
faite ici. 1 unité Blender = 1 stud Roblox : les échelles de bruit sont en « motifs par stud ».
"""

from __future__ import annotations

import math
import warnings
from typing import Iterable, Sequence

import bpy

BAKE_BSDF = "BAKE_BSDF"

Color = tuple[float, float, float, float]
SocketLike = "bpy.types.NodeSocket | float | Sequence[float]"


# =====================================================================================================================
# Couleurs
# =====================================================================================================================

def _srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def color(value, alpha: float = 1.0) -> Color:
    """'#RRGGBB' ou (r, g, b) sRGB 0-1 -> RGBA linéaire (ce qu'attendent les nœuds)."""
    if isinstance(value, str):
        h = value.lstrip("#")
        rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    else:
        rgb = list(value)[:3]
    return (*(_srgb_to_linear(c) for c in rgb), alpha)


def shade(c: Color, factor: float) -> Color:
    """factor > 0 éclaircit vers le blanc, < 0 assombrit vers le noir (en linéaire)."""
    if factor >= 0:
        return (*(x + (1 - x) * factor for x in c[:3]), c[3])
    return (*(x * (1 + factor) for x in c[:3]), c[3])


def desaturate(c: Color, amount: float) -> Color:
    lum = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    return (*(x + (lum - x) * amount for x in c[:3]), c[3])


# =====================================================================================================================
# Petit kit de construction de nœuds
# =====================================================================================================================

def _socket(sockets, key: str):
    for s in sockets:
        if s.identifier == key:
            return s
    for s in sockets:
        if s.name == key and getattr(s, "enabled", True):
            return s
    for s in sockets:
        if s.name == key:
            return s
    raise KeyError(f"socket {key!r} introuvable parmi {[s.identifier for s in sockets]}")


class NodeKit:
    """Crée et relie des nœuds en une ligne. Les entrées acceptent une prise (socket) ou une constante."""

    def __init__(self, tree: bpy.types.NodeTree):
        self.tree = tree
        self.nodes = tree.nodes
        self._texcoord = None
        self._geometry = None

    # --- bases ---
    def new(self, idname: str, label: str | None = None, **props):
        node = self.nodes.new(idname)
        if label:
            node.label = label
        for key, value in props.items():
            setattr(node, key, value)
        return node

    def feed(self, socket, value) -> None:
        """Branche `value` (prise ou constante) dans l'entrée `socket`."""
        if value is None:
            return
        if isinstance(value, bpy.types.NodeSocket):
            self.tree.links.new(value, socket)
            return
        if isinstance(value, (int, float)):
            dv = socket.default_value
            if hasattr(dv, "__len__"):
                n = len(dv)
                socket.default_value = (float(value),) * n if n != 4 else (float(value),) * 3 + (1.0,)
            else:
                socket.default_value = float(value)
            return
        seq = tuple(value)
        n = len(socket.default_value)
        socket.default_value = seq[:n] if len(seq) >= n else seq + (1.0,) * (n - len(seq))

    def set(self, node, key: str, value) -> None:
        self.feed(_socket(node.inputs, key), value)

    def out(self, node, key: str):
        return _socket(node.outputs, key)

    # --- coordonnées partagées ---
    def texcoord(self, output: str = "Object"):
        if self._texcoord is None:
            self._texcoord = self.new("ShaderNodeTexCoord")
        return self.out(self._texcoord, output)

    def geometry(self, output: str):
        if self._geometry is None:
            self._geometry = self.new("ShaderNodeNewGeometry")
        return self.out(self._geometry, output)

    def attribute(self, name: str, output: str = "Fac"):
        node = self.new("ShaderNodeAttribute", label=f"attr {name}", attribute_name=name)
        try:
            node.attribute_type = "GEOMETRY"
        except (AttributeError, TypeError):
            pass
        return self.out(node, output)

    # --- maths ---
    def math(self, op: str, a, b=None, c=None, clamp: bool = False):
        node = self.new("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.feed(node.inputs[0], a)
        if b is not None:
            self.feed(node.inputs[1], b)
        if c is not None:
            self.feed(node.inputs[2], c)
        return self.out(node, "Value")

    def vmath(self, op: str, a, b=None, scale: float | None = None):
        node = self.new("ShaderNodeVectorMath", operation=op)
        self.feed(node.inputs[0], a)
        if b is not None:
            self.feed(node.inputs[1], b)
        if scale is not None:
            self.feed(_socket(node.inputs, "Scale"), scale)
        return self.out(node, "Value" if op in ("DOT_PRODUCT", "LENGTH", "DISTANCE") else "Vector")

    def map_range(self, value, from_min, from_max, to_min=0.0, to_max=1.0, interp: str = "LINEAR", clamp=True):
        node = self.new("ShaderNodeMapRange", interpolation_type=interp, clamp=clamp)
        for key, v in (("Value", value), ("From Min", from_min), ("From Max", from_max), ("To Min", to_min), ("To Max", to_max)):
            self.set(node, key, v)
        return self.out(node, "Result")

    def mix(self, fac, a, b, blend: str = "MIX"):
        node = self.new("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        node.clamp_factor = True
        self.set(node, "Factor_Float", fac)
        self.set(node, "A_Color", a)
        self.set(node, "B_Color", b)
        return self.out(node, "Result_Color")

    def ramp(self, fac, stops: Iterable[tuple[float, Color]], interp: str = "LINEAR"):
        node = self.new("ShaderNodeValToRGB")
        cr = node.color_ramp
        cr.interpolation = interp
        stops = list(stops)
        while len(cr.elements) < len(stops):
            cr.elements.new(0.5)
        for element, (pos, col) in zip(cr.elements, stops):
            element.position = pos
            element.color = col
        self.feed(_socket(node.inputs, "Fac"), fac)
        return self.out(node, "Color")

    def to_bw(self, col):
        node = self.new("ShaderNodeRGBToBW")
        self.feed(node.inputs[0], col)
        return node.outputs[0]

    def separate(self, vector):
        node = self.new("ShaderNodeSeparateXYZ")
        self.feed(node.inputs[0], vector)
        return node.outputs[0], node.outputs[1], node.outputs[2]

    def mapping(self, vector, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1)):
        node = self.new("ShaderNodeMapping", vector_type="POINT")
        self.set(node, "Vector", vector)
        self.set(node, "Location", location)
        self.set(node, "Rotation", rotation)
        self.set(node, "Scale", scale)
        return self.out(node, "Vector")

    # --- textures procédurales ---
    def noise(self, vector, scale: float, detail: float = 4.0, roughness: float = 0.5, distortion: float = 0.0,
              noise_type: str = "FBM", lacunarity: float = 2.0):
        node = self.new("ShaderNodeTexNoise")
        try:
            node.noise_type = noise_type
            node.normalize = True
        except (AttributeError, TypeError):
            pass
        self.set(node, "Vector", vector)
        for key, v in (("Scale", scale), ("Detail", detail), ("Roughness", roughness),
                       ("Distortion", distortion), ("Lacunarity", lacunarity)):
            self.set(node, key, v)
        return node

    def voronoi(self, vector, scale: float, feature: str = "F1", randomness: float = 1.0, detail: float = 0.0):
        node = self.new("ShaderNodeTexVoronoi", feature=feature)
        self.set(node, "Vector", vector)
        self.set(node, "Scale", scale)
        self.set(node, "Randomness", randomness)
        try:
            self.set(node, "Detail", detail)
        except KeyError:
            pass
        return node

    def bump(self, height, strength: float, distance: float, normal=None):
        node = self.new("ShaderNodeBump")
        self.set(node, "Height", height)
        self.set(node, "Strength", strength)
        self.set(node, "Distance", distance)
        if normal is not None:
            self.set(node, "Normal", normal)
        return self.out(node, "Normal")


def _auto_layout(tree: bpy.types.NodeTree) -> None:
    """Range les nœuds en colonnes selon leur distance à la sortie (lisible dans l'éditeur de nœuds)."""
    depth: dict = {}
    outputs = [n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"]
    frontier = [(n, 0) for n in outputs]
    while frontier:
        node, d = frontier.pop()
        if depth.get(node.name, -1) >= d:
            continue
        depth[node.name] = d
        for socket in node.inputs:
            for link in socket.links:
                frontier.append((link.from_node, d + 1))
    rows: dict[int, int] = {}
    for node in tree.nodes:
        d = depth.get(node.name, max(depth.values(), default=0) + 1)
        node.location = (-260 * d, -170 * rows.get(d, 0))
        rows[d] = rows.get(d, 0) + 1


def _new_material(name: str, preset: str):
    """Matériau vide : sortie + Principled « BAKE_BSDF ». Remplace un matériau existant du même nom."""
    old = bpy.data.materials.get(name)
    if old is not None:
        old.name = name + "_old"
    mat = bpy.data.materials.new(name)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", DeprecationWarning)
        if hasattr(mat, "use_nodes") and not mat.use_nodes:
            mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    kit = NodeKit(tree)
    out = kit.new("ShaderNodeOutputMaterial")
    bsdf = kit.new("ShaderNodeBsdfPrincipled")
    bsdf.name = BAKE_BSDF
    bsdf.label = BAKE_BSDF
    tree.links.new(kit.out(bsdf, "BSDF"), _socket(out.inputs, "Surface"))
    mat["pipeline_preset"] = preset
    if old is not None:
        old.user_remap(mat)
        bpy.data.materials.remove(old)
    return mat, kit, bsdf


def _finish(mat, kit: NodeKit, bsdf, base, roughness, normal=None, metallic=None, emission_color=None,
            emission_strength: float = 0.0, extra: dict | None = None):
    kit.set(bsdf, "Base Color", base)
    kit.set(bsdf, "Roughness", roughness)
    if metallic is not None:
        kit.set(bsdf, "Metallic", metallic)
    if normal is not None:
        kit.set(bsdf, "Normal", normal)
    if emission_strength > 0 and emission_color is not None:
        kit.set(bsdf, "Emission Color", emission_color)
        kit.set(bsdf, "Emission Strength", emission_strength)
    for key, value in (extra or {}).items():
        try:
            kit.set(bsdf, key, value)
        except KeyError:
            pass
    _auto_layout(kit.tree)
    # Couleur d'aperçu du mode Solide (sans effet sur le rendu ni la cuisson).
    if isinstance(base, tuple):
        mat.diffuse_color = base
    return mat


# =====================================================================================================================
# Masques partagés (cuisibles)
# =====================================================================================================================

def edge_mask(kit: NodeKit, radius: float = 0.04, width: float = 0.18, pointiness_weight: float = 0.6):
    """1 sur les arêtes vives (convexes), 0 sur les faces planes.

    Nœud Bevel (normale arrondie, indépendante de la densité du maillage) comparé à la vraie normale, + Pointiness
    pour les maillages denses (organique). radius = rayon d'arrondi lu, en studs.
    """
    bevel = kit.new("ShaderNodeBevel", label="edge bevel")
    bevel.samples = 8
    kit.set(bevel, "Radius", radius)
    dot = kit.vmath("DOT_PRODUCT", kit.out(bevel, "Normal"), kit.geometry("Normal"))
    from_bevel = kit.map_range(dot, 1.0, 1.0 - width, 0.0, 1.0)
    point = kit.map_range(kit.geometry("Pointiness"), 0.52, 0.62, 0.0, 1.0)
    return kit.math("MAXIMUM", from_bevel, kit.math("MULTIPLY", point, pointiness_weight))


def cavity_mask(kit: NodeKit, distance: float = 0.25, pointiness_weight: float = 0.5):
    """1 dans les creux (occlusion ambiante locale + concavité), 0 à l'air libre."""
    ao = kit.new("ShaderNodeAmbientOcclusion", label="cavity AO")
    ao.samples = 16
    ao.only_local = True
    kit.set(ao, "Distance", distance)
    occluded = kit.map_range(kit.out(ao, "AO"), 0.92, 0.35, 0.0, 1.0)
    concave = kit.map_range(kit.geometry("Pointiness"), 0.48, 0.38, 0.0, 1.0)
    return kit.math("MAXIMUM", occluded, kit.math("MULTIPLY", concave, pointiness_weight))


def stud_pattern(kit: NodeKit, stud_size: float = 1.0, radius: float = 0.3, softness: float = 0.09,
                 sides: bool = False):
    """Tenons « briques » (coordonnées objet).

    Renvoie (hauteur 0-1 du tenon, anneau sombre 0-1 au pied du tenon). stud_size = pas de la grille en studs
    (1.0 = vrai tenon Roblox ; les familiers utilisent 0.2 dans le jeu). Comme dans Roblox, les tenons ne sont que
    sur les faces tournées vers le haut ; sides=True les projette aussi sur les côtés (triplanaire : ils
    s'ovalisent sur les faces en biais). Le dessus du tenon est légèrement bombé pour accrocher la lumière.
    """
    p = kit.vmath("SCALE", kit.texcoord("Object"), scale=1.0 / stud_size)
    cell = kit.vmath("SUBTRACT", kit.vmath("FRACTION", p), (0.5, 0.5, 0.5))
    n = kit.vmath("ABSOLUTE", kit.texcoord("Normal"))
    planes = [((1, 1, 0), 2)] if not sides else [((0, 1, 1), 0), ((1, 0, 1), 1), ((1, 1, 0), 2)]
    if sides:
        n2 = kit.vmath("MULTIPLY", n, n)
        n4 = kit.vmath("MULTIPLY", n2, n2)
        weights = kit.separate(n4)
        total = kit.math("ADD", kit.math("ADD", weights[0], weights[1]), kit.math("ADD", weights[2], 1e-4))
        weights = [kit.math("DIVIDE", w, total) for w in weights]
    else:
        up = kit.separate(kit.texcoord("Normal"))[2]
        weights = [None, None, kit.map_range(up, 0.6, 0.85, 0.0, 1.0)]
    height = None
    ring = None
    for keep, axis in planes:
        d = kit.vmath("LENGTH", kit.vmath("MULTIPLY", cell, keep))
        top = kit.map_range(d, radius + softness, radius - softness * 0.3, 0.0, 1.0, interp="SMOOTHERSTEP")
        dome = kit.map_range(d, radius, 0.0, 0.0, 0.25, interp="SMOOTHSTEP")
        outer = kit.map_range(d, radius + softness * 2.5, radius + softness, 0.0, 1.0, interp="SMOOTHSTEP")
        h = kit.math("MULTIPLY", kit.math("ADD", top, dome), weights[axis])
        r = kit.math("MULTIPLY", kit.math("SUBTRACT", outer, top, clamp=True), weights[axis])
        height = h if height is None else kit.math("ADD", height, h)
        ring = r if ring is None else kit.math("ADD", ring, r)
    return height, ring


def _sum_heights(kit: NodeKit, parts: list[tuple]):
    total = None
    for socket, weight in parts:
        if socket is None or weight == 0:
            continue
        term = kit.math("MULTIPLY", socket, weight)
        total = term if total is None else kit.math("ADD", total, term)
    return total if total is not None else 0.0


# =====================================================================================================================
# 1. Peint à la main : arêtes éclaircies, creux assombris
# =====================================================================================================================

def create_stylized_edge_wear_material(
    name: str = "M_EdgeWear",
    base="#8C8C96",
    edge=None,
    cavity=None,
    wear: float = 0.6,
    roughness: float = 0.62,
    brush_scale: float = 0.9,
    accent=None,
    grain_scale: float = 14.0,
    edge_radius: float = 0.05,
    cavity_distance: float = 0.3,
    crackle: float = 0.0,
    crackle_scale: float = 2.5,
    studs: float | None = None,
    stud_radius: float = 0.3,
    metallic: float = 0.0,
    emission: float = 0.0,
    bump_strength: float = 0.4,
    **_ignored,
):
    """Matériau « peint à la main » façon jeu stylisé.

    - Grands coups de pinceau (Noise basse fréquence) qui font varier la teinte de base ; `accent` = 2e teinte posée
      en larges taches (ex. pierre bleutée à reflets lilas) pour éviter l'aplat d'une seule couleur.
    - Arêtes éclaircies : Bevel + Pointiness, cassées par un bruit fin (`wear` = quantité d'usure 0-1), passées dans
      un ColorRamp serré pour un liseré net (pas un dégradé flou).
    - Creux assombris : Ambient Occlusion + concavité vers la couleur `cavity`.
    - `crackle` > 0 : craquelures de céramique (Voronoi DISTANCE_TO_EDGE) dans la couleur et le relief.
    - `studs` = pas des tenons en studs (ex. 1.0) pour couvrir la surface de tenons Roblox (relief + anneau sombre).
    """
    mat, kit, bsdf = _new_material(name, "create_stylized_edge_wear_material")
    base_c = color(base)
    edge_c = color(edge) if edge else shade(base_c, 0.45)
    cav_c = color(cavity) if cavity else shade(base_c, -0.6)
    obj = kit.texcoord("Object")

    brush = kit.noise(obj, brush_scale, detail=3.0, roughness=0.55, distortion=0.3)
    brush_fac = kit.map_range(kit.out(brush, "Fac"), 0.3, 0.7)
    col = kit.mix(brush_fac, shade(base_c, -0.18), shade(base_c, 0.12))
    if accent:
        patches = kit.noise(kit.vmath("ADD", obj, (13.7, 5.1, 2.9)), brush_scale * 0.7, detail=2.0, roughness=0.5)
        col = kit.mix(kit.map_range(kit.out(patches, "Fac"), 0.48, 0.68, 0.0, 0.55), col, color(accent))

    grain = kit.noise(obj, grain_scale, detail=6.0, roughness=0.62)
    grain_fac = kit.out(grain, "Fac")

    edges = edge_mask(kit, radius=edge_radius)
    breakup = kit.map_range(grain_fac, 0.32, 0.68, 1.0 - wear, 1.0)
    worn = kit.math("MULTIPLY", edges, breakup)
    edge_paint = kit.map_range(worn, 0.22, 0.42, 0.0, 1.0)
    col = kit.mix(edge_paint, col, edge_c)

    cav = cavity_mask(kit, distance=cavity_distance)
    col = kit.mix(kit.math("MULTIPLY", cav, 0.85), col, cav_c)

    crack_h = None
    if crackle > 0:
        cells = kit.voronoi(kit.vmath("ADD", obj, kit.vmath("SCALE", kit.out(brush, "Color"), scale=0.08)),
                            crackle_scale, feature="DISTANCE_TO_EDGE")
        crack = kit.map_range(kit.out(cells, "Distance"), 0.0, 0.035, 1.0, 0.0)
        crack = kit.math("MULTIPLY", crack, crackle)
        col = kit.mix(kit.math("MULTIPLY", crack, 0.8), col, shade(cav_c, -0.3))
        crack_h = kit.math("MULTIPLY", crack, -1.0)

    stud_h = None
    if studs:
        stud_h, ring = stud_pattern(kit, stud_size=studs, radius=stud_radius)
        col = kit.mix(kit.math("MULTIPLY", stud_h, 0.35), col, shade(base_c, 0.12))
        col = kit.mix(kit.math("MULTIPLY", ring, 0.55), col, shade(base_c, -0.35))

    rough = kit.math("ADD", roughness, kit.map_range(grain_fac, 0.0, 1.0, -0.08, 0.08))
    rough = kit.math("SUBTRACT", rough, kit.math("MULTIPLY", edge_paint, 0.18))
    rough = kit.math("ADD", rough, kit.math("MULTIPLY", cav, 0.15), clamp=True)

    height = _sum_heights(kit, [(grain_fac, 0.25), (kit.out(brush, "Fac"), 0.35), (crack_h, 0.6)])
    normal = kit.bump(height, strength=bump_strength, distance=0.02)
    if stud_h is not None:
        # relief propre aux tenons (vrais petits cylindres, ~0,1 stud de haut), enchaîné sur le relief de surface
        normal = kit.bump(stud_h, strength=1.0, distance=0.1 * studs, normal=normal)
    return _finish(mat, kit, bsdf, col, rough, normal, metallic=metallic, emission_color=col,
                   emission_strength=emission, extra={"Specular IOR Level": 0.45})


# =====================================================================================================================
# 2. Métal gravé / or martelé
# =====================================================================================================================

def create_etched_metal_or_gold(
    name: str = "M_Gold",
    tint="#FFC830",
    scratches: float = 0.5,
    hammered: float = 0.0,
    rust: float = 0.0,
    roughness: float = 0.26,
    anisotropy: float = 0.35,
    edge_polish: float = 0.7,
    tarnish: float = 0.65,
    scratch_scale: float = 1.0,
    hammer_scale: float = 5.0,
    edge_radius: float = 0.03,
    **_ignored,
):
    """Métal (or, cuivre, acier) façon jeu haut de gamme.

    - Micro-rayures : deux bruits étirés et tournés (63°) réduits à de fines lignes, parsemées par un masque ; elles
      montent la Roughness et creusent un peu le relief.
    - `hammered` : cupules d'or martelé (Voronoi SMOOTH_F1) dans le relief et la rugosité.
    - Arêtes polies (plus claires, plus lisses), creux ternis (plus sombres, plus rugueux), `rust` = taches de rouille
      non métalliques.
    - Anisotropie radiale (tangente autour de Z) pour les reflets étirés du rendu Blender.
    """
    mat, kit, bsdf = _new_material(name, "create_etched_metal_or_gold")
    tint_c = color(tint)
    obj = kit.texcoord("Object")

    lines = None
    for angle, stretch in ((0.0, 0.035), (1.1, 0.05)):
        v = kit.mapping(obj, rotation=(0.0, 0.0, angle), scale=(stretch * scratch_scale * 30, scratch_scale * 30, scratch_scale * 30))
        n = kit.noise(v, 1.0, detail=2.0, roughness=0.5)
        line = kit.map_range(kit.math("ABSOLUTE", kit.math("SUBTRACT", kit.out(n, "Fac"), 0.5)), 0.0, 0.018, 1.0, 0.0)
        lines = line if lines is None else kit.math("MAXIMUM", lines, line)
    sparse = kit.map_range(kit.out(kit.noise(obj, 3.0 * scratch_scale, detail=2.0), "Fac"), 0.45, 0.62, 0.0, 1.0)
    scr = kit.math("MULTIPLY", kit.math("MULTIPLY", lines, sparse), scratches)

    hammer_h = None
    hammer_var = 0.0
    if hammered > 0:
        cells = kit.voronoi(obj, hammer_scale, feature="SMOOTH_F1", randomness=0.85)
        dist = kit.out(cells, "Distance")
        hammer_h = kit.math("MULTIPLY", dist, hammered)
        hammer_var = kit.math("MULTIPLY", kit.map_range(dist, 0.0, 0.6, -0.06, 0.08), hammered)

    edges = edge_mask(kit, radius=edge_radius)
    cav = cavity_mask(kit, distance=0.2)
    smudge = kit.out(kit.noise(obj, 2.2, detail=5.0, roughness=0.6), "Fac")

    dark = desaturate(shade(tint_c, -0.72), 0.35)
    col = kit.mix(kit.map_range(smudge, 0.3, 0.7, 0.0, 0.25), tint_c, shade(tint_c, -0.18))
    col = kit.mix(kit.math("MULTIPLY", cav, tarnish), col, dark)
    col = kit.mix(kit.math("MULTIPLY", edges, edge_polish), col, shade(tint_c, 0.35))
    col = kit.mix(kit.math("MULTIPLY", scr, 0.5), col, shade(tint_c, 0.2))

    rough = kit.math("ADD", roughness, kit.math("MULTIPLY", scr, 0.32))
    rough = kit.math("ADD", rough, kit.math("MULTIPLY", cav, 0.3))
    rough = kit.math("SUBTRACT", rough, kit.math("MULTIPLY", edges, 0.14))
    rough = kit.math("ADD", rough, kit.map_range(smudge, 0.0, 1.0, -0.05, 0.07))
    rough = kit.math("ADD", rough, hammer_var, clamp=True)

    metal = 1.0
    if rust > 0:
        rust_mask = kit.map_range(kit.out(kit.noise(obj, 1.6, detail=8.0, roughness=0.7, distortion=0.6), "Fac"),
                                  0.62 - rust * 0.25, 0.68 - rust * 0.25, 0.0, 1.0)
        rust_mask = kit.math("MAXIMUM", rust_mask, kit.math("MULTIPLY", cav, rust))
        rust_col = kit.mix(kit.out(kit.noise(obj, 9.0), "Fac"), color("#8A4A22"), color("#5A2A12"))
        col = kit.mix(rust_mask, col, rust_col)
        rough = kit.mix(rust_mask, rough, 0.85)
        rough = kit.to_bw(rough)
        metal = kit.math("SUBTRACT", 1.0, rust_mask, clamp=True)

    height = _sum_heights(kit, [(scr, -0.25), (hammer_h, 1.0), (smudge, 0.08)])
    normal = kit.bump(height, strength=0.35, distance=0.02)

    tangent = kit.new("ShaderNodeTangent", direction_type="RADIAL", axis="Z")
    extra = {"Anisotropic": anisotropy, "Specular IOR Level": 0.5}
    kit.set(bsdf, "Tangent", kit.out(tangent, "Tangent"))
    return _finish(mat, kit, bsdf, col, rough, normal, metallic=metal, extra=extra)


# =====================================================================================================================
# 3. Peau / écailles organiques
# =====================================================================================================================

def create_organic_scales_or_skin(
    name: str = "M_Skin",
    base="#9646C8",
    variation=None,
    cells: float = 8.0,
    sss: float = 0.15,
    gloss: float = 0.45,
    scale_depth: float = 0.6,
    stripes=None,
    stripe_scale: float = 2.5,
    belly=None,
    emission: float = 0.0,
    warp: float = 0.12,
    **_ignored,
):
    """Peau ou écailles stylisées.

    - Cellules Voronoi déformées par un bruit (`warp`) : chaque écaille a sa propre teinte (entre `base` et
      `variation`), un dôme en relief et un sillon sombre sur son pourtour.
    - Marbrures basse fréquence, creux assombris, crêtes légèrement éclaircies.
    - `stripes` = couleur de rayures (Wave BANDS distordu), `belly` = couleur du ventre (bas de l'objet, Generated Z).
    - SSS (Subsurface Weight) pour le rendu Blender ; la couleur cuite reste celle de la peau.
    """
    mat, kit, bsdf = _new_material(name, "create_organic_scales_or_skin")
    base_c = color(base)
    var_c = color(variation) if variation else shade(base_c, -0.4)
    obj = kit.texcoord("Object")
    warp_noise = kit.noise(obj, 1.5, detail=3.0)
    v = kit.vmath("ADD", obj, kit.vmath("SCALE", kit.vmath("SUBTRACT", kit.out(warp_noise, "Color"), (0.5, 0.5, 0.5)), scale=warp))

    vor = kit.voronoi(v, cells, feature="F1", randomness=0.9)
    cell_rand = kit.separate(kit.out(vor, "Color"))[0]
    dome = kit.map_range(kit.out(vor, "Distance"), 0.0, 0.7, 1.0, 0.0, interp="SMOOTHSTEP")
    border = kit.voronoi(v, cells, feature="DISTANCE_TO_EDGE", randomness=0.9)
    groove = kit.map_range(kit.out(border, "Distance"), 0.0, 0.07, 1.0, 0.0)

    col = kit.mix(kit.math("MULTIPLY", cell_rand, 0.65), base_c, var_c)
    mottle = kit.out(kit.noise(obj, 0.8, detail=4.0, roughness=0.55), "Fac")
    col = kit.mix(kit.map_range(mottle, 0.35, 0.65, 0.0, 0.35), col, shade(base_c, 0.18))

    if stripes:
        wave = kit.new("ShaderNodeTexWave", wave_type="BANDS")
        kit.set(wave, "Vector", v)
        kit.set(wave, "Scale", stripe_scale)
        kit.set(wave, "Distortion", 6.0)
        kit.set(wave, "Detail", 2.0)
        band = kit.map_range(kit.out(wave, "Fac"), 0.55, 0.7, 0.0, 1.0)
        col = kit.mix(band, col, color(stripes))
    if belly:
        _, _, gz = kit.separate(kit.texcoord("Generated"))
        col = kit.mix(kit.map_range(gz, 0.38, 0.22, 0.0, 1.0, interp="SMOOTHSTEP"), col, color(belly))

    col = kit.mix(kit.math("MULTIPLY", groove, 0.55), col, shade(var_c, -0.45))
    cav = cavity_mask(kit, distance=0.25)
    col = kit.mix(kit.math("MULTIPLY", cav, 0.7), col, shade(var_c, -0.6))
    edges = edge_mask(kit, radius=0.06, pointiness_weight=0.8)
    col = kit.mix(kit.math("MULTIPLY", edges, 0.35), col, shade(base_c, 0.3))

    rough = kit.math("ADD", 1.0 - gloss, kit.math("MULTIPLY", groove, 0.2))
    rough = kit.math("ADD", rough, kit.math("MULTIPLY", cav, 0.15), clamp=True)

    height = _sum_heights(kit, [(dome, scale_depth), (groove, -0.4 * scale_depth), (mottle, 0.15)])
    normal = kit.bump(height, strength=0.45, distance=0.03)
    extra = {
        "Subsurface Weight": sss,
        "Subsurface Radius": (1.0, 0.45, 0.3),
        "Subsurface Scale": 0.08,
        "Sheen Weight": 0.15,
        "Specular IOR Level": 0.45,
    }
    return _finish(mat, kit, bsdf, col, rough, normal, emission_color=col, emission_strength=emission, extra=extra)


# =====================================================================================================================
# 4. Cristal / gemme
# =====================================================================================================================

def create_stylized_crystal_or_gem(
    name: str = "M_Crystal",
    core="#2A1050",
    mid="#8C5AFF",
    rim="#E6D8FF",
    emission: float = 0.0,
    gradient: str = "attribute",
    facet_variation: float = 0.35,
    edge_glow: float = 0.85,
    edge_width: float = 0.04,
    fresnel: float = 0.35,
    veins: float = 0.08,
    roughness: float = 0.07,
    **_ignored,
):
    """Cristal stylisé à facettes nettes.

    - Dégradé interne cuisible core -> mid -> rim : attribut "grad" écrit par les recettes (gradient="attribute"),
      ou distance au centre de la boîte englobante (gradient="radial"), ou hauteur (gradient="height").
    - Chaque facette décale le dégradé (attribut "facet") : une gemme aux faces de teintes différentes.
    - Veines internes discrètes (bruit distordu, `veins` 0-1 : au-delà de 0,15 la gemme tourne au marbre).
    - Arêtes de facettes lumineuses (Bevel) : la lumière « accroche » les bords même sur la texture cuite.
      `edge_width` = écart de normale détecté (0,04 ~ facettes à 15-20° d'une gemme ; 0,2 = arêtes vives à 45°+).
    - Fresnel (Layer Weight) vers `rim` : rendu Blender seulement (disparaît à la cuisson, c'est voulu).
    - `emission` > 0 : le cœur brille (Emission Color = dégradé, plus fort au centre) -> carte Emissive dans Roblox.
    """
    mat, kit, bsdf = _new_material(name, "create_stylized_crystal_or_gem")
    core_c, mid_c, rim_c = color(core), color(mid), color(rim)

    if gradient == "attribute":
        inner = kit.attribute("grad")
    elif gradient == "height":
        inner = kit.separate(kit.texcoord("Generated"))[2]
    else:
        centered = kit.vmath("SUBTRACT", kit.texcoord("Generated"), (0.5, 0.5, 0.5))
        inner = kit.math("MULTIPLY", kit.vmath("LENGTH", centered), 1.8)
    facet = kit.attribute("facet")
    shifted = kit.math("ADD", inner, kit.math("MULTIPLY", kit.math("SUBTRACT", facet, 0.5), facet_variation))

    obj = kit.texcoord("Object")
    vein_noise = kit.noise(obj, 1.2, detail=6.0, roughness=0.6, distortion=1.5)
    vein = kit.map_range(kit.out(vein_noise, "Fac"), 0.4, 0.65, -1.0, 1.0)
    shifted = kit.math("ADD", shifted, kit.math("MULTIPLY", vein, veins))

    col = kit.ramp(shifted, [(0.0, shade(core_c, -0.2)), (0.2, core_c), (0.6, mid_c), (1.0, rim_c)])
    edges = edge_mask(kit, radius=0.03, width=edge_width, pointiness_weight=0.0)
    glint = kit.map_range(edges, 0.2, 0.75, 0.0, 1.0)
    col = kit.mix(kit.math("MULTIPLY", glint, edge_glow), col, shade(rim_c, 0.4))

    facing = kit.new("ShaderNodeLayerWeight")
    kit.set(facing, "Blend", 0.35)
    rim_amount = kit.map_range(kit.out(facing, "Facing"), 0.35, 1.0, 0.0, fresnel)
    col = kit.mix(rim_amount, col, rim_c)

    rough = kit.math("ADD", roughness, kit.map_range(kit.out(vein_noise, "Fac"), 0.0, 1.0, -0.03, 0.06), clamp=True)
    height = _sum_heights(kit, [(kit.out(vein_noise, "Fac"), 0.15)])
    normal = kit.bump(height, strength=0.12, distance=0.02)

    extra = {"Specular IOR Level": 0.75, "IOR": 1.6, "Coat Weight": 0.55, "Coat Roughness": 0.03}
    mat = _finish(mat, kit, bsdf, col, rough, normal, metallic=0.0, emission_color=col,
                  emission_strength=emission, extra=extra)
    if emission > 0:
        # le cœur coloré brille, le pied sombre non (masque = ce que Roblox lit dans EmissiveMaskContent)
        glow_mask = kit.map_range(shifted, 0.25, 0.7, 0.15, 1.0)
        kit.set(bsdf, "Emission Strength", kit.math("MULTIPLY", glow_mask, emission))
        _auto_layout(kit.tree)
    return mat


PRESETS = {
    "create_stylized_edge_wear_material": create_stylized_edge_wear_material,
    "create_etched_metal_or_gold": create_etched_metal_or_gold,
    "create_organic_scales_or_skin": create_organic_scales_or_skin,
    "create_stylized_crystal_or_gem": create_stylized_crystal_or_gem,
}


def from_spec(name: str, preset: str, params: dict | None = None):
    """Crée un matériau depuis une ligne de game_design_matrix.json ({"preset": ..., "params": {...}})."""
    params = dict(params or {})
    if preset == "create_etched_metal_or_gold" and "base" in params and "tint" not in params:
        params["tint"] = params.pop("base")
    return PRESETS[preset](name=name, **params)


__all__ = [
    "BAKE_BSDF", "color", "shade", "desaturate", "NodeKit", "edge_mask", "cavity_mask", "stud_pattern",
    "create_stylized_edge_wear_material", "create_etched_metal_or_gold", "create_organic_scales_or_skin",
    "create_stylized_crystal_or_gem", "PRESETS", "from_spec",
]
