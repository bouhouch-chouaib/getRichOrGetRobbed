"""Décors du monde Désert (2e palier) — même langage que la Prairie (environment_recipes) : blocs biseautés empilés,
tenons sur les faces du dessus de la pierre taillée, du bois et des végétaux. Charte : map_art_bible_desert.json.

**Aucune lueur** dans ce monde (pas d'émission, donc pas de masque _Emissive.png à envoyer : avertissement de
modération du 25 oct. sur ce type d'image). Le turquoise émaillé et l'or tiennent le rôle d'accent.

Importé par environment_recipes.catalog("Desert") : ajoute ses décors (préfixe « Desert_ ») à E.BUILDERS et sa liste à
E.WORLDS["Desert"]. Repère : pivot au sol au centre, devant = -Y, 1 unité = 1 stud.
"""

from __future__ import annotations

import math
import random

import bpy
from mathutils import Matrix, Vector

import environment_recipes as E
import procedural_geometry_recipes as G
import shader_node_library as S
from environment_recipes import assemble, bx, finish, hull, ring_sector

# =====================================================================================================================
# Matériaux (ajoutés au dictionnaire partagé de environment_recipes, pour que ses constructeurs les trouvent)
# =====================================================================================================================


def dm() -> dict[str, bpy.types.Material]:
    M = E.mats()
    if "gres_taille" in M and M["gres_taille"].name in bpy.data.materials:
        return M
    W = S.create_stylized_edge_wear_material
    stone = dict(brush_scale=0.22, grain_scale=3.0, edge_radius=0.18, cavity_distance=1.0, bump_strength=0.45)
    wood = dict(brush_scale=0.5, grain_scale=6.0, edge_radius=0.08, cavity_distance=0.5, wear=0.75)
    plant = dict(brush_scale=0.35, grain_scale=4.0, edge_radius=0.14, cavity_distance=1.0, wear=0.85, roughness=0.55,
                 studs=1.0)
    M.update({
        # strates de canyon (crème, rouge brique, orange, brun rouge)
        "gres_a": W("M_GresStrateA", base="#F0C08A", edge="#FFE6C0", cavity="#8A4A3A", accent="#F6D29E", crackle=0.15,
                    crackle_scale=0.8, wear=0.7, roughness=0.8, **stone),
        "gres_b": W("M_GresStrateB", base="#D06A3A", edge="#F29A64", cavity="#6E2E26", accent="#C85A32", crackle=0.15,
                    crackle_scale=0.8, wear=0.7, roughness=0.8, **stone),
        "gres_c": W("M_GresStrateC", base="#E8955A", edge="#FFC48A", cavity="#7A3E2E", accent="#F0A86A", crackle=0.15,
                    crackle_scale=0.8, wear=0.7, roughness=0.8, **stone),
        "gres_d": W("M_GresStrateD", base="#B8502E", edge="#E07A50", cavity="#5A2420", accent="#A8462A", crackle=0.15,
                    crackle_scale=0.8, wear=0.7, roughness=0.8, **stone),
        "sable_dore": W("M_SableDore", base="#F6D28A", edge="#FFF0C0", cavity="#B08850", wear=0.8, roughness=0.85,
                        studs=1.0, **stone),
        "gres_roche": W("M_GresRoche", base="#E39A5E", edge="#FFD2A0", cavity="#7A3E34", accent="#F2C48A", crackle=0.1,
                        crackle_scale=0.9, wear=0.75, roughness=0.8, **stone),
        "gres_taille": W("M_GresTaille", base="#E6C48E", edge="#FFF0D0", cavity="#8A5A4A", accent="#F0D2A0", crackle=0.15,
                         crackle_scale=0.7, wear=0.6, roughness=0.72, studs=1.0, **stone),
        "turquoise": W("M_TurquoiseEmail", base="#2FB7B0", edge="#A8F0E8", cavity="#13615E", wear=0.4, roughness=0.32,
                       brush_scale=0.5, edge_radius=0.06, cavity_distance=0.4),
        "adobe": W("M_Adobe", base="#D9A06A", edge="#F6D2A0", cavity="#7A4A30", accent="#E2AE78", crackle=0.3,
                   crackle_scale=1.2, wear=0.7, roughness=0.85, studs=1.0, **stone),
        "bois_seche": W("M_BoisSeche", base="#A8743E", edge="#E0B07A", cavity="#4A2E18", wood=1.0, wood_axis="Z",
                        wood_scale=1.1, roughness=0.75, studs=1.0, **wood),
        "bois_seche_x": W("M_BoisSecheX", base="#A06C38", edge="#E0B07A", cavity="#4A2E18", wood=1.0, wood_axis="X",
                          wood_scale=1.1, roughness=0.75, studs=1.0, **wood),
        "cactus": W("M_Cactus", base="#4FB54A", edge="#C2F270", cavity="#1E6A32", **plant),
        "cactus_fonce": W("M_CactusFonce", base="#3C9A40", edge="#9EE060", cavity="#16502A", **plant),
        "fleur": W("M_FleurCactus", base="#FF6FB0", edge="#FFD6EA", cavity="#A83070", wear=0.5, roughness=0.5,
                   brush_scale=0.6, edge_radius=0.05),
        "palme_a": W("M_PalmeA", base="#5CC23C", edge="#D6F87A", cavity="#1E6A2E", **plant),
        "palme_b": W("M_PalmeB", base="#86DA44", edge="#EEFF9A", cavity="#2E7A34", **plant),
        "tronc_palmier": W("M_TroncPalmier", base="#B07A44", edge="#E8B47A", cavity="#5A3A1E", wood=1.0, wood_axis="Z",
                           wood_scale=0.6, roughness=0.8, crackle=0.2, crackle_scale=1.0, **wood),
        "noix": W("M_NoixCoco", base="#7A4A26", edge="#B07A4A", cavity="#3A2010", wear=0.5, roughness=0.7,
                  brush_scale=0.6, edge_radius=0.05),
        "os": W("M_Os", base="#F4EAD2", edge="#FFFFFF", cavity="#A89070", crackle=0.25, crackle_scale=1.2, wear=0.6,
                roughness=0.7, **stone),
        "tissu_rouge": W("M_TissuRouge", base="#E8141A", edge="#FF7070", cavity="#7A0A10", wear=0.4, roughness=0.8,
                         brush_scale=0.6, edge_radius=0.04),
        "tissu_creme": W("M_TissuCreme", base="#FFF4E0", edge="#FFFFFF", cavity="#C8B090", wear=0.4, roughness=0.8,
                         brush_scale=0.6, edge_radius=0.04),
        "argile": W("M_Argile", base="#C8693A", edge="#F0A070", cavity="#6A2A1A", crackle=0.2, crackle_scale=1.5,
                    wear=0.6, roughness=0.75, brush_scale=0.5, edge_radius=0.08, cavity_distance=0.5),
        "herbe_seche": W("M_HerbeSeche", base="#D8C060", edge="#FFF2A8", cavity="#8A7030", wear=0.9, roughness=0.7,
                         brush_scale=0.8, edge_radius=0.05, cavity_distance=0.4),
        "herbe_seche_b": W("M_HerbeSecheB", base="#B8A048", edge="#F0E090", cavity="#706020", wear=0.9, roughness=0.7,
                           brush_scale=0.8, edge_radius=0.05, cavity_distance=0.4),
    })
    return M


STRATA = ("gres_a", "gres_b", "gres_c", "gres_d", "gres_a")


def strut(name: str, a, b, w: float, h: float, taper=(1.0, 1.0), roll_hint=None) -> bpy.types.Object:
    """Bloc tendu du point a au point b (section w x h), effilé vers b. roll_hint = direction où regarde la face
    « -Y » du bloc (par défaut un axe jamais parallèle à la direction)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = bx(name, (w, h, d.length), (0, 0, 0), taper=taper)
    hint = roll_hint or ((0, 1, 0) if abs(d.normalized().x) > 0.8 else (1, 0, 0))
    return G.transform(obj, G.frame_matrix(a, d, roll_hint=hint))


# =====================================================================================================================
# Nature
# =====================================================================================================================

def mesa(name: str, seed: int = 8):
    """Paroi de canyon en gradins raides : strates crème / rouge / orange, terrasses de sable doré."""
    dm()
    return E.cliff(name, seed=seed, layers=5, layer_h=5.6, strata=STRATA, caps=("sable_dore", "sable_dore", "gres_a"),
                   step_back=0.1)


def hoodoo(name: str, seed: int = 3, height: float = 11.0):
    """Cheminée de fée : pied large, colonne qui s'affine, chapeau plus large en équilibre, strates de couleur."""
    M = dm()
    r = random.Random(seed)
    items = [(hull(f"{name}_pied", r, (7, 6.5, 3.2), flat_top=0.85), M["gres_b"])]
    z = 2.4
    for k, (w, h) in enumerate(((4.6, 3.0), (3.6, 2.8), (2.8, height - 9.5))):
        items.append((hull(f"{name}_col{k}", r, (w, w * 0.9, h), points=18, flat_top=0.95, at=(r.uniform(-0.3, 0.3), 0, z)),
                      M[("gres_c", "gres_a", "gres_c")[k]]))
        z += h * 0.9
    items.append((hull(f"{name}_chapeau", r, (6.2, 5.4, 2.4), points=20, flat_top=0.8, at=(0.4, 0, z - 0.2),
                       rot=(r.uniform(-6, 6), r.uniform(-6, 6), 0)), M["gres_d"]))
    items.append((hull(f"{name}_eclat", r, (3.0, 2.6, 2.4), at=(3.6, -1.8, 0), rot=(0, 0, 30)), M["gres_roche"]))
    low = finish(items, bevel=0.05, max_bevel=0.3, segments=2, angle=20)
    return assemble(name, low), None


def low_rocks(name: str, seed: int = 4):
    """Rochers de grès sculptés par le vent (version désert du rocher calcaire)."""
    dm()
    return E.rock(name, seed=seed, size=(10, 7, 5), kind="gres_roche")


def natural_arch(name: str, seed: int = 5, span: float = 18.0):
    """Arche de roche naturelle : deux piles facettées et une voûte continue de blocs de grès qui se chevauchent."""
    M = dm()
    r = random.Random(seed)
    items = []
    rad = span / 2
    leg_h = 7.5
    for side in (-1, 1):
        items.append((hull(f"{name}_pile{side}", r, (7.0, 6.2, leg_h + 2.5), points=22, flat_top=0.95,
                           at=(side * rad, 0, 0)), M["gres_b"]))
    n = 10
    for i in range(n):
        a = math.pi * (i + 0.5) / n
        cx, cz = math.cos(a) * rad, leg_h + math.sin(a) * rad * 0.8
        s = 6.4 - abs(i - (n - 1) / 2) * 0.22
        items.append((hull(f"{name}_voute{i}", r, (s, 5.4, s * 0.85), points=18, flat_top=0.95,
                           at=(cx, 0, cz - s * 0.42), rot=(0, -math.degrees(a) + 90, r.uniform(-6, 6))),
                      M[STRATA[i % 4]]))
    items.append((hull(f"{name}_eboulis", r, (4, 3.5, 2.2), at=(-rad - 5.0, -2, 0)), M["gres_roche"]))
    low = finish(items, bevel=0.05, max_bevel=0.3, segments=2, angle=20)
    return assemble(name, low), None


def saguaro(name: str, seed: int = 6, height: float = 12.0):
    """Grand cactus en blocs : tronc à côtes, deux bras qui remontent, fleurs roses au sommet."""
    M = dm()
    r = random.Random(seed)
    items = []
    seg = 5
    z = 0.0
    for i in range(seg):
        w = 2.6 - 0.12 * i
        h = height / seg
        items.append((bx(f"{name}_tronc{i}", (w, w, h * 1.02), (0, 0, z), (0, 0, r.uniform(-3, 3)), taper=(0.97, 0.97)),
                      M["cactus"]))
        for f in range(4):  # côtes plus sombres sur chaque face
            a = f * math.pi / 2
            items.append((bx(f"{name}_cote{i}_{f}", (0.45, 0.3, h * 0.92), (math.cos(a) * w * 0.5, math.sin(a) * w * 0.5, z + 0.05),
                             (0, 0, math.degrees(a) + 90)), M["cactus_fonce"]))
        z += h
    items.append((bx(f"{name}_dome", (2.0, 2.0, 1.0), (0, 0, z), taper=(0.6, 0.6)), M["cactus"]))
    for side, (zh, reach, up) in ((-1, (4.2, 2.6, 4.0)), (1, (6.2, 2.2, 3.2))):
        items.append((bx(f"{name}_bras{side}", (reach, 1.7, 1.7), (side * (1.3 + reach / 2), 0, zh)), M["cactus"]))
        items.append((bx(f"{name}_monte{side}", (1.7, 1.7, up), (side * (1.3 + reach), 0, zh)), M["cactus"]))
        items.append((bx(f"{name}_bout{side}", (1.3, 1.3, 0.7), (side * (1.3 + reach), 0, zh + up), taper=(0.6, 0.6)),
                      M["cactus"]))
        items.append((bx(f"{name}_fleurbras{side}", (0.7, 0.7, 0.5), (side * (1.3 + reach), 0, zh + up + 0.6)), M["fleur"]))
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        items.append((bx(f"{name}_fleur{k}", (0.8, 0.8, 0.6), (math.cos(a) * 0.7, math.sin(a) * 0.7, z + 0.7),
                         (0, 0, math.degrees(a))), M["fleur"]))
    low = finish(items, bevel=0.14, max_bevel=0.25, segments=2, angle=30)
    return assemble(name, low), None


def barrel_cactus(name: str, seed: int = 7):
    """Trois cactus en tonneau (10 côtes, couronne de fleurs), du plus gros au plus petit."""
    M = dm()
    r = random.Random(seed)
    items = []
    for k, (s, x, y) in enumerate(((1.0, 0, 0), (0.7, 2.6, 1.0), (0.5, -2.0, 1.4))):
        prof = [(0, 0), (1.3 * s, 0), (1.6 * s, 0.9 * s), (1.5 * s, 2.0 * s), (1.0 * s, 2.6 * s), (0, 2.75 * s)]
        body = G.lathe(f"{name}_corps{k}", prof, segments=10, phase=r.uniform(0, 1))
        G.transform(body, Matrix.Translation((x, y, 0)))
        items.append((body, M["cactus"]))
        for f in range(5):
            a = f * 2 * math.pi / 5
            items.append((bx(f"{name}_fleur{k}_{f}", (0.45 * s + 0.15, 0.45 * s + 0.15, 0.35),
                             (x + math.cos(a) * 0.6 * s, y + math.sin(a) * 0.6 * s, 2.55 * s), (0, 0, math.degrees(a))),
                          M["fleur"]))
    low = finish(items, bevel=0.08, max_bevel=0.12, segments=2, angle=20)
    return assemble(name, low), None


def prickly_pear(name: str, seed: int = 9):
    """Figuier de Barbarie : raquettes plates qui s'ouvrent en éventail les unes sur les autres, fruits roses."""
    M = dm()
    r = random.Random(seed)
    items = []
    face = (0, 1, 0)  # face plate tournée vers l'avant (-Y)

    def pad(tag, start, angle, length, width, depth):
        a = math.radians(angle)
        end = Vector(start) + Vector((math.sin(a), r.uniform(-0.15, 0.15), math.cos(a))) * length
        items.append((strut(f"{name}_raquette{tag}", start, end, width, 0.6, taper=(0.8, 1.0), roll_hint=face),
                      M["cactus"] if depth % 2 == 0 else M["cactus_fonce"]))
        return end

    top = pad("0", (0, 0, 0), 0, 3.4, 2.6, 0)
    for k, ang in enumerate((-38, 6, 42)):
        start = top + Vector((math.sin(math.radians(ang)) * 0.9, 0, -0.5))
        mid = pad(f"1_{k}", start, ang, 2.9, 2.2, 1)
        for j, d_ang in enumerate((-26, 24)):
            if k == 1 and j == 0:
                continue
            end = pad(f"2_{k}_{j}", mid - Vector((0, 0, 0.35)), ang + d_ang, 2.2, 1.7, 2)
            items.append((bx(f"{name}_fruit{k}_{j}", (0.55, 0.55, 0.6), (end.x, end.y, end.z - 0.25)), M["fleur"]))
    low = finish(items, bevel=0.15, max_bevel=0.2, segments=2, angle=30)
    return assemble(name, low), None


def palm(name: str, seed: int = 10, height: float = 15.0):
    """Palmier : tronc annelé qui se courbe, 8 palmes en 3 blocs qui retombent, noix de coco."""
    M = dm()
    r = random.Random(seed)
    items = []
    n = 8
    lean = r.uniform(4.0, 6.0)
    pos = Vector((0, 0, 0))
    for i in range(n):
        t = (i + 1) / n
        target = Vector((lean * t * t, 0, height * t))
        d = target - pos
        mid = pos + d / 2
        tilt = math.degrees(math.atan2(d.x, d.z))
        s = 1.9 - 0.08 * i
        items.append((bx(f"{name}_tronc{i}", (s, s, d.length * 1.05), (mid.x, mid.y, mid.z - d.length * 0.525),
                         (0, tilt, i * 22), taper=(0.84, 0.84)), M["tronc_palmier"]))
        pos = target
    top = pos
    for k in range(8):
        a = k * 2 * math.pi / 8 + r.uniform(-0.15, 0.15)
        base = top.copy()
        for j, (length, droop) in enumerate(((3.4, 12), (3.2, 32), (2.8, 58))):
            pitch = droop + r.uniform(-5, 5)
            d = Vector((math.cos(a) * math.cos(math.radians(pitch)), math.sin(a) * math.cos(math.radians(pitch)),
                        -math.sin(math.radians(pitch)))) * length
            mid = base + d / 2
            items.append((bx(f"{name}_palme{k}_{j}", (length * 1.08, 1.5 - 0.3 * j, 0.32),
                             (mid.x, mid.y, mid.z - 0.16), (0, pitch, math.degrees(a)), taper=(0.7, 0.6)),
                          M["palme_a"] if (k + j) % 2 == 0 else M["palme_b"]))
            base = base + d
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.5
        items.append((bx(f"{name}_coco{k}", (0.9, 0.9, 0.9), (top.x + math.cos(a) * 0.8, top.y + math.sin(a) * 0.8, top.z - 1.2),
                         (r.uniform(0, 30), r.uniform(0, 30), 0)), M["noix"]))
    low = finish(items, bevel=0.12, max_bevel=0.2, segments=2, angle=30)
    return assemble(name, low), None


def dry_tuft(name: str, seed: int = 11):
    dm()
    return E.grass_tuft(name, seed=seed, height=2.8, tones=("herbe_seche", "herbe_seche_b"))


def fossil(name: str, seed: int = 12, length: float = 20.0):
    """Squelette fossile géant à demi enterré : colonne de vertèbres en dos d'âne, côtes en arceaux qui retombent
    jusqu'au sable des deux côtés (on passe dessous), gros crâne posé au sol."""
    M = dm()
    r = random.Random(seed)
    items = []
    n = 8
    spine = []
    for i in range(n):
        x = -length / 2 + i * length / (n - 1)
        z = 3.2 + math.sin(i / (n - 1) * math.pi) * 3.0
        spine.append(Vector((x, 0, z)))
        items.append((bx(f"{name}_vertebre{i}", (1.7, 1.9, 1.5), (x, 0, z - 0.75), (0, 0, r.uniform(-6, 6)),
                         taper=(0.8, 0.8)), M["os"]))
        items.append((bx(f"{name}_epine{i}", (0.6, 0.5, 1.4), (x, 0, z + 0.6), taper=(0.4, 0.5)), M["os"]))
    ribs = []
    for i in range(1, n - 1):
        reach = 6.2 - abs(i - (n - 1) / 2) * 0.6
        for side in (-1, 1):
            prev = spine[i] + Vector((0, side * 0.9, -0.2))
            for j, ang in enumerate((40, 100, 155)):
                a = math.radians(ang)
                nxt = Vector((spine[i].x + 0.3 * j, side * (0.9 + math.sin(a) * reach),
                              spine[i].z * (0.5 + 0.5 * math.cos(a)) - 0.4))
                ribs.append((strut(f"{name}_cote{i}_{side}_{j}", prev, nxt, 0.75, 0.6, taper=(0.9, 0.9)), M["os"]))
                prev = nxt
    hx = length / 2 + 3.0
    items.append((bx(f"{name}_crane", (5.2, 4.2, 3.4), (hx, 0, -0.2), (0, -10, 0), taper=(0.8, 0.85)), M["os"]))
    items.append((bx(f"{name}_museau", (4.2, 2.8, 1.9), (hx + 3.8, 0, -0.2), (0, -6, 0), taper=(0.7, 0.8)), M["os"]))
    for side in (-1, 1):
        items.append((bx(f"{name}_orbite{side}", (1.2, 0.4, 1.0), (hx + 0.8, side * 1.85, 1.5)), M["gres_d"]))
    # côtes : un seul segment de chanfrein (36 pièces), le reste en 2 segments
    low = finish(items, bevel=0.14, max_bevel=0.2, segments=2, angle=30) + finish(ribs, bevel=0.14, max_bevel=0.15,
                                                                                   segments=1, angle=30)
    return assemble(name, low), None



# =====================================================================================================================
# Civilisation
# =====================================================================================================================

def _bands(prefix: str, center, size: float, axis: str, seed: int):
    """Hiéroglyphes simplifiés en turquoise émaillé (pas de lueur) : barre + 2 ou 3 traits, posés sur une face."""
    r = random.Random(seed)
    cx, cy, cz = center
    out = []
    strokes = [(0, 0, 0.16, 1.0)] + [(r.choice((-0.22, 0.22)), r.uniform(-0.35, 0.35), 0.45, 0.13) for _ in range(r.choice((2, 3)))]
    for k, (dx, dz, w, h) in enumerate(strokes):
        if axis == "Y":
            size_v, at = (w * size, 0.22, h * size), (cx + dx * size, cy, cz + dz * size - h * size / 2)
        else:
            size_v, at = (0.22, w * size, h * size), (cx, cy + dx * size, cz + dz * size - h * size / 2)
        out.append((bx(f"{prefix}_{k}", size_v, at), dm()["turquoise"]))
    return out


def obelisk(name: str, seed: int = 13, height: float = 16.0):
    """Obélisque : socle en 2 gradins, fût effilé, bandeaux turquoise, hiéroglyphes, pyramidion doré."""
    M = dm()
    items = [(bx(f"{name}_socle", (5.0, 5.0, 1.2), (0, 0, 0)), M["gres_taille"]),
             (bx(f"{name}_socle2", (3.8, 3.8, 0.9), (0, 0, 1.15)), M["gres_taille"])]
    shaft_h = height - 4.2
    items.append((bx(f"{name}_fut", (2.6, 2.6, shaft_h), (0, 0, 2.0), taper=(0.66, 0.66)), M["gres_a"]))
    for k, t in enumerate((0.12, 0.72)):
        w = 2.6 * (1 - 0.34 * t) + 0.2
        items.append((bx(f"{name}_bandeau{k}", (w, w, 0.45), (0, 0, 2.0 + shaft_h * t)), M["turquoise"]))
    for f in range(4):
        a = f * math.pi / 2
        d = 2.6 * (1 - 0.34 * 0.42) / 2 + 0.06
        if f % 2 == 0:
            items += _bands(f"{name}_glyphe{f}", (0, -d if f == 0 else d, 2.0 + shaft_h * 0.42), 2.0, "Y", seed + f)
        else:
            items += _bands(f"{name}_glyphe{f}", (d if f == 1 else -d, 0, 2.0 + shaft_h * 0.42), 2.0, "X", seed + f)
    tip_w = 2.6 * 0.66
    items.append((bx(f"{name}_pyramidion", (tip_w, tip_w, 2.2), (0, 0, 2.0 + shaft_h - 0.05), taper=(0.06, 0.06)), M["or"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def broken_column(name: str, seed: int = 14):
    """Colonne brisée : base, 3 tambours cannelés (le dernier de travers), un tambour tombé, chapiteau au sol."""
    M = dm()
    r = random.Random(seed)
    items = [(bx(f"{name}_base", (4.4, 4.4, 1.0), (0, 0, 0)), M["gres_taille"])]
    z = 1.0
    for k in range(3):
        drum = G.lathe(f"{name}_tambour{k}", [(0, 0), (1.55, 0), (1.5, 2.4), (0, 2.4)], segments=12, phase=k * 0.13)
        tilt = (0, 0, 9)[k]
        G.transform(drum, Matrix.Translation((r.uniform(-0.1, 0.1) + (0.5 if k == 2 else 0), 0, z))
                    @ Matrix.Rotation(math.radians(tilt), 4, "Y"))
        items.append((drum, M["gres_taille"] if k % 2 == 0 else M["gres_a"]))
        z += 2.42
    fallen = G.lathe(f"{name}_tombe", [(0, 0), (1.5, 0), (1.5, 2.4), (0, 2.4)], segments=12)
    G.transform(fallen, Matrix.Translation((3.6, -2.0, 1.45)) @ Matrix.Rotation(math.radians(90), 4, "X")
                @ Matrix.Rotation(math.radians(20), 4, "Y"))
    items.append((fallen, M["gres_a"]))
    items.append((bx(f"{name}_chapiteau", (3.6, 3.6, 1.2), (-3.4, 1.4, -0.1), (8, -6, 25), taper=(1.2, 1.2)), M["gres_taille"]))
    items.append((bx(f"{name}_anneau", (3.4, 3.4, 0.4), (0, 0, 1.0 + 2.42 * 2 - 0.2)), M["turquoise"]))
    low = finish(items, bevel=0.1, max_bevel=0.15, segments=2, angle=20)
    return assemble(name, low), None


def temple_gate(name: str, seed: int = 15, opening: float = 18.0):
    """Porte de temple : 2 pylônes à murs inclinés, linteau et corniche, disque solaire doré à ailes turquoise."""
    M = dm()
    r = random.Random(seed)
    items = []
    half = opening / 2
    pylon_h = 21.0
    for side in (-1, 1):
        px = side * (half + 2.8)
        items.append((bx(f"{name}_pylone{side}", (5.6, 4.6, pylon_h), (px, 0, 0), taper=(0.78, 0.86)), M["gres_taille"]))
        items.append((bx(f"{name}_socle{side}", (6.4, 5.4, 1.0), (px, 0, 0)), M["gres_a"]))
        for k, zb in enumerate((6.0, 13.5)):
            w = 5.6 * (1 - 0.22 * zb / pylon_h)
            items.append((bx(f"{name}_bande{side}_{k}", (w + 0.15, 4.6 * (1 - 0.14 * zb / pylon_h) + 0.15, 0.6), (px, 0, zb)),
                          M["turquoise"] if k == 0 else M["gres_b"]))
        items += _bands(f"{name}_glyphe{side}", (px, -2.25, 9.8), 3.0, "Y", seed + side)
    items.append((bx(f"{name}_linteau", (opening + 9.2, 4.0, 2.6), (0, 0, pylon_h - 1.2)), M["gres_taille"]))
    items.append((bx(f"{name}_corniche", (opening + 10.4, 4.8, 1.0), (0, 0, pylon_h + 1.35), taper=(1.04, 1.06)), M["gres_b"]))
    disc = G.lathe(f"{name}_soleil", [(0, -0.3), (1.9, -0.3), (1.9, 0.3), (0, 0.3)], segments=16)
    G.transform(disc, Matrix.Translation((0, -2.2, pylon_h + 0.1)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    items.append((disc, M["or"]))
    for side in (-1, 1):
        for j, (w, dz) in enumerate(((3.4, 0.5), (2.6, 0.0), (1.8, -0.5))):
            items.append((bx(f"{name}_aile{side}_{j}", (w, 0.3, 0.42), (side * (1.9 + w / 2), -2.15, pylon_h + 0.1 + dz - 0.21)),
                          M["turquoise"]))
    del r
    low = finish(items, bevel=0.1, max_bevel=0.25, segments=2, angle=25)
    return assemble(name, low), None


def sun_slab(name: str, seed: int = 16, size=(8.0, 6.0, 1.2)):
    """Dalle de grès fendue, disque solaire incrusté (rayons turquoise, cœur doré) : la version désert de la dalle
    runique, sans lueur."""
    M = dm()
    r = random.Random(seed)
    sx, sy, sz = size
    items = []
    cut = r.uniform(-0.6, 0.6)
    for k, ((cx, cy), (w, d)) in enumerate((((-sx / 4 + cut / 2 - 0.05, -sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((-sx / 4 + cut / 2 - 0.05, sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((sx / 4 + cut / 2 + 0.05, 0), (sx / 2 - cut - 0.1, sy - 0.1)))):
        items.append((bx(f"{name}_morceau{k}", (w, d, sz), (cx, cy, r.uniform(-0.12, 0.05)),
                         (r.uniform(-1.2, 1.2), r.uniform(-1.2, 1.2), r.uniform(-1.5, 1.5))), M["gres_taille"]))
    for k in range(8):
        a = k * math.pi / 4
        items.append((bx(f"{name}_rayon{k}", (1.1 if k % 2 else 0.6, 0.3, 0.12), (math.cos(a) * 1.9, math.sin(a) * 1.9, sz - 0.05),
                         (0, 0, math.degrees(a))), M["turquoise"]))
    disc = G.lathe(f"{name}_coeur", [(0, sz - 0.06), (1.0, sz - 0.06), (1.0, sz + 0.1), (0, sz + 0.1)], segments=12)
    items.append((disc, M["or"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def adobe_wall(name: str, seed: int = 17, length: float = 12.0):
    """Muret de fort en terre crue : soubassement de grès, mur d'adobe, créneaux, poutres de bois qui dépassent devant."""
    M = dm()
    r = random.Random(seed)
    items = []
    x = -length / 2
    while x < length / 2 - 0.3:
        w = min(r.uniform(3.4, 4.6), length / 2 - x)
        items.append((bx(f"{name}_soubassement{len(items)}", (w - 0.08, 2.1, 0.8), (x + w / 2, 0, 0)), M["gres_taille"]))
        items.append((bx(f"{name}_mur{len(items)}", (w - 0.04, 1.7, 2.6), (x + w / 2, 0.05, 0.75),
                         (0, 0, r.uniform(-0.6, 0.6)), taper=(0.97, 0.92)), M["adobe"]))
        x += w
    merlons = 5
    for k in range(merlons):
        mx = -length / 2 + (k + 0.5) * length / merlons
        items.append((bx(f"{name}_creneau{k}", (1.5, 1.6, 1.1), (mx, 0.05, 3.3), taper=(0.92, 0.92)), M["adobe"]))
    for k in range(3):
        px = -length / 2 + (k + 0.5) * length / 3
        items.append((bx(f"{name}_poutre{k}", (0.6, 2.8, 0.6), (px, -0.4, 2.55)), M["bois_seche"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def sand_stairs(name: str, seed: int = 18):
    dm()
    return E.stairs(name, seed=seed, step_mat="gres_taille", cheek_mat="adobe")


def jars(name: str, seed: int = 19):
    """Deux jarres d'argile (une grande, une petite) à bandeau turquoise."""
    M = dm()
    items = []
    for k, (s, x, y) in enumerate(((1.0, 0, 0), (0.65, 2.1, 0.8))):
        prof = [(0, 0), (0.9 * s, 0), (1.5 * s, 1.0 * s), (1.6 * s, 1.9 * s), (1.0 * s, 3.0 * s), (0.7 * s, 3.4 * s),
                (0.9 * s, 3.7 * s), (0.6 * s, 3.75 * s), (0.6 * s, 3.5 * s), (0, 3.5 * s)]
        body = G.lathe(f"{name}_jarre{k}", prof, segments=12)
        G.transform(body, Matrix.Translation((x, y, 0)))
        items.append((body, M["argile"]))
        rr = 1.62 * s
        band = G.lathe(f"{name}_bande{k}", [(rr - 0.08, 1.75 * s), (rr + 0.06, 1.75 * s), (rr + 0.06, 2.15 * s),
                                             (rr - 0.08, 2.15 * s)], segments=12, closed=True)
        G.transform(band, Matrix.Translation((x, y, 0)))
        items.append((band, M["turquoise"]))
    low = finish(items, bevel=0.06, max_bevel=0.08, segments=2, angle=20)
    return assemble(name, low), None


def awning(name: str, seed: int = 20):
    """Auvent de marché : 4 poteaux de bois sec, toit de bandes rouge / crème en pente, lambrequin, petite table."""
    M = dm()
    items = []
    w, d = 8.0, 6.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = 6.0 if sy < 0 else 5.0
            items.append((bx(f"{name}_poteau{sx}{sy}", (0.5, 0.5, h), (sx * (w / 2 - 0.3), sy * (d / 2 - 0.3), 0)),
                          M["bois_seche"]))
    n = 8
    slope = math.degrees(math.atan(1.0 / d))
    for k in range(n):
        x = -w / 2 + (k + 0.5) * w / n
        items.append((bx(f"{name}_bande{k}", (w / n + 0.02, d + 0.8, 0.22), (x, 0, 5.45), (-slope, 0, 0)),
                      M["tissu_rouge"] if k % 2 == 0 else M["tissu_creme"]))
        items.append((bx(f"{name}_frange{k}", (w / n - 0.05, 0.12, 0.7), (x, -(d / 2 + 0.38), 5.4)),
                      M["tissu_creme"] if k % 2 == 0 else M["tissu_rouge"]))
    items.append((bx(f"{name}_table", (5.0, 2.2, 0.35), (0, 0.6, 2.4)), M["bois_seche_x"]))
    for sx in (-1, 1):
        items.append((bx(f"{name}_pied{sx}", (0.35, 1.8, 2.4), (sx * 2.2, 0.6, 0)), M["bois_seche"]))
    low = finish(items, bevel=0.12, max_bevel=0.12, segments=2, angle=30)
    return assemble(name, low), None


def brazier(name: str, seed: int = 21):
    """Brasero : trépied de fer, coupe dorée, braises en blocs d'argile (le feu et la lumière s'ajoutent dans Roblox)."""
    M = dm()
    items = []
    for k in range(3):
        a = k * 2 * math.pi / 3
        items.append((bx(f"{name}_pied{k}", (0.35, 0.35, 3.4), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0),
                         (math.sin(a) * 10, -math.cos(a) * 10, 0)), M["fer"]))
    bowl = G.lathe(f"{name}_coupe", [(0, 3.0), (0.6, 3.0), (1.4, 3.5), (1.7, 4.1), (1.5, 4.15), (0, 3.7)], segments=10)
    items.append((bowl, M["or"]))
    for k in range(5):
        a = k * 2 * math.pi / 5
        items.append((bx(f"{name}_braise{k}", (0.6, 0.6, 0.45), (math.cos(a) * 0.55, math.sin(a) * 0.55, 3.75),
                         (0, 0, math.degrees(a))), M["argile"]))
    low = finish(items, bevel=0.1, max_bevel=0.08, segments=2, angle=30)
    return assemble(name, low), None


# =====================================================================================================================
# Catalogue
# =====================================================================================================================

DESERT = {
    "Desert_Mesa": (lambda n: mesa(n, seed=8), 1024),
    "Desert_RocherGres_A": (lambda n: hoodoo(n, seed=3), 1024),
    "Desert_RocherGres_B": (lambda n: low_rocks(n, seed=4), 1024),
    "Desert_ArcheNaturelle": (lambda n: natural_arch(n, seed=5), 1024),
    "Desert_Saguaro": (lambda n: saguaro(n, seed=6), 1024),
    "Desert_CactusTonneau": (lambda n: barrel_cactus(n, seed=7), 512),
    "Desert_Figuier": (lambda n: prickly_pear(n, seed=9), 512),
    "Desert_Palmier": (lambda n: palm(n, seed=10), 1024),
    "Desert_Touffe": (lambda n: dry_tuft(n, seed=11), 512),
    "Desert_Fossile": (lambda n: fossil(n, seed=12), 1024),
    "Desert_Obelisque": (lambda n: obelisk(n, seed=13), 1024),
    "Desert_ColonneBrisee": (lambda n: broken_column(n, seed=14), 1024),
    "Desert_PorteTemple": (lambda n: temple_gate(n, seed=15), 1024),
    "Desert_Dalle": (lambda n: sun_slab(n, seed=16), 512),
    "Desert_Muret": (lambda n: adobe_wall(n, seed=17), 1024),
    "Desert_Escalier": (lambda n: sand_stairs(n, seed=18), 1024),
    "Desert_Jarre": (lambda n: jars(n, seed=19), 512),
    "Desert_Auvent": (lambda n: awning(n, seed=20), 1024),
    "Desert_Brasero": (lambda n: brazier(n, seed=21), 512),
}

E.BUILDERS.update(DESERT)
E.WORLDS["Desert"] = list(DESERT)
