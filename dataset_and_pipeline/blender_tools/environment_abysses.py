"""Décors du monde Abysses (5e palier) — « Le Royaume Englouti du Roi Corail ». Même langage que les autres mondes :
blocs biseautés, tenons sur les faces du dessus du sable, de la pierre taillée et des coraux.
Charte : map_art_bible_abysses.json.

**Aucune lueur** (pas d'émission, aucun _Emissive.png à envoyer : avertissement de modération du 25 oct.). Les perles
sont une couleur pâle ; la lumière viendra de PointLight cyan posées par le script Studio.

Importé par environment_recipes.catalog("Abysses") : ajoute ses décors (préfixe « Abysses_ ») à E.BUILDERS et sa liste
à E.WORLDS["Abysses"]. Repère : pivot au sol au centre, devant = -Y, 1 unité = 1 stud.
"""

from __future__ import annotations

import math
import random

import bpy
from mathutils import Matrix, Vector

import environment_recipes as E
import procedural_geometry_recipes as G
import shader_node_library as S
from environment_desert import strut
from environment_recipes import assemble, bx, finish, hull, ring_sector

# =====================================================================================================================
# Matériaux
# =====================================================================================================================


def am() -> dict[str, bpy.types.Material]:
    M = E.mats()
    if "roche_mer_a" in M and M["roche_mer_a"].name in bpy.data.materials:
        return M
    W = S.create_stylized_edge_wear_material
    stone = dict(brush_scale=0.22, grain_scale=3.0, edge_radius=0.18, cavity_distance=1.0, bump_strength=0.45)
    wood = dict(brush_scale=0.5, grain_scale=6.0, edge_radius=0.08, cavity_distance=0.5, wear=0.75)
    plant = dict(brush_scale=0.35, grain_scale=4.0, edge_radius=0.14, cavity_distance=1.0, wear=0.85, roughness=0.55,
                 studs=1.0)
    small = dict(brush_scale=0.6, edge_radius=0.05)
    M.update({
        "roche_mer_a": W("M_RocheMerA", base="#2E4A78", edge="#7A9AD0", cavity="#101E3A", accent="#3A5A8A", crackle=0.2,
                         crackle_scale=0.7, wear=0.7, roughness=0.7, **stone),
        "roche_mer_b": W("M_RocheMerB", base="#3A3A7A", edge="#8A8AD0", cavity="#14143A", accent="#4A4A8A", crackle=0.2,
                         crackle_scale=0.7, wear=0.7, roughness=0.7, **stone),
        "roche_mer_c": W("M_RocheMerC", base="#24607A", edge="#6AB0C8", cavity="#0A2A3A", accent="#2E7088", crackle=0.2,
                         crackle_scale=0.7, wear=0.7, roughness=0.7, **stone),
        "sable_mer": W("M_SableMer", base="#E6D296", edge="#FFF2C8", cavity="#9A8A5A", wear=0.7, roughness=0.85,
                       studs=1.0, **stone),
        "pierre_atlante": W("M_PierreAtlante", base="#7AA8B0", edge="#D6F4F4", cavity="#2A4A5A", accent="#8ABAC0",
                            crackle=0.2, crackle_scale=0.8, wear=0.65, roughness=0.65, studs=1.0, **stone),
        "corail_rose": W("M_CorailRose", base="#FF6A8C", edge="#FFC8D8", cavity="#9A2A4A", **plant),
        "corail_orange": W("M_CorailOrange", base="#FF9A4A", edge="#FFD2A0", cavity="#A04A14", **plant),
        "corail_violet": W("M_CorailViolet", base="#B45AE6", edge="#E6C0FF", cavity="#5A1A8A", **plant),
        "corail_jaune": W("M_CorailJaune", base="#FFD24A", edge="#FFF2B0", cavity="#A07A14", **plant),
        "algue": W("M_Algue", base="#2EA88A", edge="#A0F4D6", cavity="#0E4A3A", **plant),
        "algue_b": W("M_AlgueB", base="#46C27A", edge="#B4F8C8", cavity="#145A30", **plant),
        "perle": W("M_Perle", base="#E8F6FF", edge="#FFFFFF", cavity="#9AB4D0", wear=0.4, roughness=0.18, **small),
        "nacre": W("M_Nacre", base="#F6E0F4", edge="#FFFFFF", cavity="#B490C0", wear=0.4, roughness=0.25, **small),
        "coquille": W("M_Coquille", base="#F2A6C8", edge="#FFE8F4", cavity="#9A4A7A", wear=0.6, roughness=0.5,
                      brush_scale=0.5, edge_radius=0.12, cavity_distance=0.6),
        "bois_epave": W("M_BoisEpave", base="#6A4A3A", edge="#7AB8A0", cavity="#2A1E18", wood=1.0, wood_axis="Z",
                        wood_scale=0.9, roughness=0.8, crackle=0.2, crackle_scale=1.0, **wood),
        "bois_epave_x": W("M_BoisEpaveX", base="#644434", edge="#7AB8A0", cavity="#2A1E18", wood=1.0, wood_axis="X",
                          wood_scale=0.9, roughness=0.8, crackle=0.2, crackle_scale=1.0, **wood),
        "voile": W("M_VoileDechiree", base="#D8D0B8", edge="#F2ECDA", cavity="#8A8270", crackle=0.35, crackle_scale=1.2,
                   wear=0.6, roughness=0.9, **small),
        "drapeau": W("M_DrapeauNoir", base="#1E1E24", edge="#4A4A56", cavity="#0A0A0E", wear=0.4, roughness=0.8, **small),
        "blanc": W("M_BlancDrapeau", base="#F0F0F0", edge="#FFFFFF", cavity="#B0B0B0", wear=0.3, roughness=0.6, **small),
        "etoile": W("M_EtoileMer", base="#FF7A3A", edge="#FFC08A", cavity="#A03A14", wear=0.5, roughness=0.6, studs=1.0,
                    **small),
        "corde": W("M_Corde", base="#C8A870", edge="#F0D8A8", cavity="#6A5230", wear=0.6, roughness=0.9, **small),
    })
    return M


ROCK = ("roche_mer_a", "roche_mer_b", "roche_mer_c", "roche_mer_a", "roche_mer_b")
CORALS = ("corail_rose", "corail_orange", "corail_violet", "corail_jaune")


def starfish(prefix: str, center, s: float, yaw: float = 0.0):
    """Étoile de mer : 5 bras plats effilés autour d'un cœur."""
    M = am()
    cx, cy, cz = center
    out = [(bx(f"{prefix}_coeur", (0.6 * s, 0.6 * s, 0.25 * s), (cx, cy, cz), (0, 0, yaw + 36)), M["etoile"])]
    for k in range(5):
        a = math.radians(yaw + k * 72)
        out.append((bx(f"{prefix}_bras{k}", (1.0 * s, 0.4 * s, 0.22 * s),
                       (cx + math.cos(a) * 0.55 * s, cy + math.sin(a) * 0.55 * s, cz), (0, 0, math.degrees(a)),
                       taper=(0.6, 0.6)), M["etoile"]))
    return out


def coral_tuft(prefix: str, base, s: float, rnd: random.Random):
    """Petit bouquet de corail en blocs (pour couvrir piliers, murets, colonnes)."""
    M = am()
    bx_, by_, bz_ = base
    out = []
    for k in range(3):
        mat = M[CORALS[rnd.randint(0, 3)]]
        h = rnd.uniform(0.8, 1.6) * s
        out.append((bx(f"{prefix}_{k}", (0.5 * s, 0.5 * s, h), (bx_ + rnd.uniform(-0.4, 0.4) * s, by_ + rnd.uniform(-0.4, 0.4) * s, bz_),
                       (rnd.uniform(-20, 20), rnd.uniform(-20, 20), rnd.uniform(0, 90)), taper=(0.7, 0.7)), mat))
    return out


# =====================================================================================================================
# Nature
# =====================================================================================================================

def reef(name: str, seed: int = 4):
    """Récif en gradins : strates de roche bleu-violet, terrasses couvertes de coraux à tenons (rose, orange, violet)."""
    am()
    return E.cliff(name, seed=seed, layers=5, layer_h=5.6, strata=ROCK,
                   caps=("corail_rose", "corail_orange", "corail_violet"), step_back=0.12)


def branching_coral(name: str, seed: int = 5, height: float = 8.0):
    """Corail branchu : un pied qui se divise en branches (3 niveaux), bouts plus gros et plus clairs."""
    M = am()
    r = random.Random(seed)
    items = [(hull(f"{name}_pied", r, (2.6, 2.4, 1.2), flat_top=0.7), M["roche_mer_c"])]

    def grow(tag, start: Vector, direction: Vector, length: float, width: float, depth: int):
        end = start + direction.normalized() * length
        items.append((strut(f"{name}_b{tag}", start, end, width, width, taper=(0.85, 0.85)), M["corail_rose"]))
        if depth == 0:
            items.append((bx(f"{name}_bout{tag}", (width * 1.5, width * 1.5, width * 1.3), (end.x, end.y, end.z - width * 0.3),
                             (r.uniform(0, 30), r.uniform(0, 30), r.uniform(0, 90))), M["corail_jaune"]))
            return
        count = 3 if depth == 3 else 2
        base_a = r.uniform(0, 2 * math.pi)
        for k in range(count):
            a = base_a + k * 2 * math.pi / count + r.uniform(-0.4, 0.4)
            spread = r.uniform(0.45, 0.85)
            d = Vector((math.cos(a) * spread, math.sin(a) * spread, 1.0))
            grow(f"{tag}{k}", end, d, length * 0.74, width * 0.74, depth - 1)

    grow("0", Vector((0, 0, 0.6)), Vector((0, 0, 1)), height * 0.3, 1.2, 3)
    low = finish(items, bevel=0.12, max_bevel=0.15, segments=2, angle=30)
    return assemble(name, low), None


def fan_coral(name: str, seed: int = 6, size: float = 7.0):
    """Corail éventail : rayons et arcs en treillis plat (violet), sur un petit pied, face vers -Y."""
    M = am()
    r = random.Random(seed)
    items = [(bx(f"{name}_pied", (1.2, 1.0, 1.4), (0, 0, 0), taper=(0.7, 0.7)), M["roche_mer_b"])]
    base = Vector((0, 0, 1.2))
    rays = 7
    pts = {}
    for k in range(rays):
        a = math.radians(30 + k * 120 / (rays - 1))
        for j, rr in enumerate((size * 0.45, size * 0.8)):
            pts[(k, j)] = base + Vector((math.cos(a) * rr * 0.9, r.uniform(-0.1, 0.1), math.sin(a) * rr))
        items.append((strut(f"{name}_rayon{k}", base, pts[(k, 1)], 0.35, 0.3), M["corail_violet"]))
    for j in range(2):
        for k in range(rays - 1):
            items.append((strut(f"{name}_arc{j}_{k}", pts[(k, j)], pts[(k + 1, j)], 0.3, 0.28), M["corail_violet"]))
    for k in range(rays):
        p = pts[(k, 1)]
        items.append((bx(f"{name}_bout{k}", (0.6, 0.45, 0.6), (p.x, p.y, p.z - 0.3), (0, 0, 45)), M["corail_rose"]))
    low = finish(items, bevel=0.12, max_bevel=0.08, segments=2, angle=30)
    return assemble(name, low), None


def kelp(name: str, seed: int = 7, height: float = 14.0):
    """Algues géantes : 3 tiges qui ondulent, feuilles plates alternées de chaque côté, deux verts."""
    M = am()
    r = random.Random(seed)
    items = [(hull(f"{name}_roche", r, (3.6, 3.2, 1.2), flat_top=0.7), M["roche_mer_a"])]
    for t in range(3):
        a = t * 2 * math.pi / 3 + r.uniform(-0.3, 0.3)
        start = Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, 0.8))
        h = height * r.uniform(0.7, 1.0)
        n = 6
        prev = start
        phase = r.uniform(0, 6)
        for k in range(n):
            z = start.z + (k + 1) * h / n
            p = Vector((start.x + math.sin(phase + k * 0.9) * 0.9, start.y + math.cos(phase + k * 0.7) * 0.6, z))
            items.append((strut(f"{name}_tige{t}_{k}", prev, p, 0.35, 0.35), M["algue"]))
            side = 1 if k % 2 else -1
            items.append((bx(f"{name}_feuille{t}_{k}", (0.3, 1.6, 2.4), (p.x + side * 0.7, p.y, p.z - 1.8),
                             (0, side * 25, math.degrees(a) + 90), taper=(0.4, 0.6)), M["algue_b"] if k % 2 else M["algue"]))
            prev = p
    low = finish(items, bevel=0.1, max_bevel=0.08, segments=2, angle=30)
    return assemble(name, low), None


def anemones(name: str, seed: int = 8):
    """Trois anémones (une grande, deux petites) : disque et deux couronnes de tentacules, bouts jaunes."""
    M = am()
    r = random.Random(seed)
    items = [(hull(f"{name}_roche", r, (4.4, 3.8, 1.0), flat_top=0.7), M["roche_mer_c"])]
    for i, (s, x, y) in enumerate(((1.0, 0, 0), (0.6, 1.9, 1.0), (0.55, -1.7, 1.2))):
        disc = G.lathe(f"{name}_disque{i}", [(0, 0.6), (1.1 * s, 0.6), (1.2 * s, 1.2 * s + 0.6), (0, 1.2 * s + 0.6)], segments=10)
        G.transform(disc, Matrix.Translation((x, y, 0)))
        items.append((disc, M["corail_rose"] if i != 1 else M["corail_violet"]))
        for ring, (rr, n, tilt) in enumerate(((0.9 * s, 10, 35), (0.45 * s, 6, 15))):
            for k in range(n):
                a = k * 2 * math.pi / n + ring * 0.3
                base = Vector((x + math.cos(a) * rr, y + math.sin(a) * rr, 1.2 * s + 0.6))
                tip = base + Vector((math.cos(a) * math.sin(math.radians(tilt)), math.sin(a) * math.sin(math.radians(tilt)),
                                     math.cos(math.radians(tilt)))) * (1.3 * s)
                items.append((strut(f"{name}_tentacule{i}_{ring}_{k}", base, tip, 0.28 * s + 0.08, 0.28 * s + 0.08,
                                    taper=(0.6, 0.6)), M["corail_orange"] if ring else M["corail_rose"]))
                if k % 2 == 0:
                    items.append((bx(f"{name}_bout{i}_{ring}_{k}", (0.22 * s + 0.1,) * 3, (tip.x, tip.y, tip.z - 0.1)),
                                  M["corail_jaune"]))
    low = finish(items, bevel=0.12, max_bevel=0.06, segments=1, angle=30)
    return assemble(name, low), None


def sea_rock(name: str, seed: int = 9, size=(9.0, 7.0, 6.0)):
    """Rocher marin facetté : bernacles, une étoile de mer, un bouquet de corail."""
    M = am()
    r = random.Random(seed)
    sx, sy, sz = size
    items = [(hull(f"{name}_roche", r, size, flat_top=0.7), M["roche_mer_a"]),
             (hull(f"{name}_eclat", r, (sx * 0.45, sy * 0.45, sz * 0.5), at=(sx * 0.42, -sy * 0.3, 0), rot=(0, 0, 30)),
              M["roche_mer_b"])]
    for k in range(7):
        a = r.uniform(0, 2 * math.pi)
        items.append((bx(f"{name}_bernacle{k}", (0.6, 0.6, 0.5), (math.cos(a) * sx * 0.42, math.sin(a) * sy * 0.42, r.uniform(0.5, sz * 0.6)),
                         (r.uniform(-30, 30), r.uniform(-30, 30), 0), taper=(0.5, 0.5)), M["nacre"]))
    items += starfish(f"{name}_etoile", (0.6, -sy * 0.2, sz * 0.86), 1.2, r.uniform(0, 72))
    items += coral_tuft(f"{name}_corail", (-sx * 0.2, sy * 0.15, sz * 0.8), 1.2, r)
    low = finish(items, bevel=0.06, max_bevel=0.3, segments=2, angle=20)
    return assemble(name, low), None


def giant_clam(name: str, seed: int = 10, radius: float = 4.2):
    """Coquillage géant entrouvert : valve du bas en côtes, valve du haut relevée, nacre, grosse perle."""
    M = am()
    r = random.Random(seed)
    prof = [(0, 0.3), (radius * 0.55, 0.0), (radius, 0.9), (radius * 1.02, 1.6), (radius * 0.9, 1.7), (0, 1.0)]
    low_shell = G.lathe(f"{name}_valve_bas", prof, segments=12)
    G.transform(low_shell, Matrix.Diagonal((1.0, 0.82, 1.0, 1.0)))
    nacre = G.lathe(f"{name}_nacre", [(0, 1.05), (radius * 0.86, 1.55), (radius * 0.86, 1.62), (0, 1.12)], segments=12)
    G.transform(nacre, Matrix.Diagonal((1.0, 0.82, 1.0, 1.0)))
    up_shell = G.lathe(f"{name}_valve_haut", [(0, 0.0), (radius * 0.9, 0.0), (radius * 1.0, 0.5), (radius * 0.6, 1.3), (0, 1.5)],
                       segments=12)
    G.transform(up_shell, Matrix.Translation((0, radius * 0.8, 1.6)) @ Matrix.Rotation(math.radians(-55), 4, "X")
                @ Matrix.Translation((0, -radius * 0.8, 0)) @ Matrix.Diagonal((1.0, 0.82, 1.0, 1.0)))
    items = [(low_shell, M["coquille"]), (nacre, M["nacre"]), (up_shell, M["coquille"]),
             (hull(f"{name}_perle", r, (1.9, 1.9, 1.8), points=30, flat_top=0.98, at=(0, -0.4, 1.45)), M["perle"])]
    for k in range(4):
        a = r.uniform(0, 2 * math.pi)
        items.append((hull(f"{name}_sable{k}", r, (1.6, 1.4, 0.6), at=(math.cos(a) * (radius + 0.8), math.sin(a) * (radius + 0.4), -0.1)),
                      M["sable_mer"]))
    low = finish(items, bevel=0.08, max_bevel=0.15, segments=2, angle=20)
    return assemble(name, low), None


def seagrass(name: str, seed: int = 11):
    am()
    return E.grass_tuft(name, seed=seed, height=3.0, tones=("algue", "algue_b"))


# =====================================================================================================================
# Cité engloutie
# =====================================================================================================================

def sunken_column(name: str, seed: int = 12):
    """Colonne atlante engloutie : base, tambours cannelés (le dernier de travers), coraux et étoile de mer dessus."""
    M = am()
    r = random.Random(seed)
    items = [(bx(f"{name}_base", (4.4, 4.4, 1.0), (0, 0, 0)), M["pierre_atlante"])]
    z = 1.0
    for k in range(3):
        drum = G.lathe(f"{name}_tambour{k}", [(0, 0), (1.55, 0), (1.5, 2.4), (0, 2.4)], segments=12, phase=k * 0.13)
        G.transform(drum, Matrix.Translation(((0.5 if k == 2 else 0), 0, z)) @ Matrix.Rotation(math.radians((0, 0, 10)[k]), 4, "Y"))
        items.append((drum, M["pierre_atlante"]))
        z += 2.42
    items.append((bx(f"{name}_chapiteau", (3.6, 3.6, 1.2), (-3.4, 1.4, -0.1), (8, -6, 25), taper=(1.2, 1.2)), M["pierre_atlante"]))
    for k in range(4):
        a = r.uniform(0, 2 * math.pi)
        items += coral_tuft(f"{name}_corail{k}", (math.cos(a) * 1.5, math.sin(a) * 1.5, r.uniform(1.0, z - 0.5)), 1.0, r)
    items += starfish(f"{name}_etoile", (0.5, 0, z + 0.2), 1.0, 20)
    low = finish(items, bevel=0.1, max_bevel=0.15, segments=2, angle=20)
    return assemble(name, low), None


def trident(prefix: str, center, s: float):
    """Trident d'or (hampe, garde, trois dents), à plat sur une face tournée vers -Y."""
    M = am()
    cx, cy, cz = center
    out = [(bx(f"{prefix}_hampe", (0.35 * s, 0.3 * s, 3.0 * s), (cx, cy, cz - 1.5 * s)), M["or"]),
           (bx(f"{prefix}_garde", (1.8 * s, 0.3 * s, 0.35 * s), (cx, cy, cz + 1.35 * s)), M["or"])]
    for dx, h in ((-0.75, 1.2), (0.0, 1.6), (0.75, 1.2)):
        out.append((bx(f"{prefix}_dent{dx}", (0.32 * s, 0.3 * s, h * s), (cx + dx * s, cy, cz + 1.6 * s), taper=(0.2, 1.0)), M["or"]))
    return out


def atlantean_gate(name: str, seed: int = 13, opening: float = 18.0, pillar_h: float = 13.5, depth: float = 3.2):
    """Porte atlante : piliers de pierre couverts de coraux, arche en coquillage (côtes alternées), trident d'or."""
    M = am()
    r = random.Random(seed)
    items = []
    r_in = opening / 2
    for side in (-1, 1):
        px = side * (r_in + 1.6)
        items.append((bx(f"{name}_socle{side}", (4.4, depth + 1.2, 1.5), (px, 0, 0)), M["sable_mer"]))
        z = 1.5
        for k in range(3):
            items.append((bx(f"{name}_bloc{side}_{k}", (3.2, depth, 3.55), (px + r.uniform(-0.1, 0.1), 0, z),
                             (0, 0, r.uniform(-3, 3))), M["pierre_atlante"]))
            items += coral_tuft(f"{name}_corail{side}_{k}", (px + side * 1.5, r.uniform(-1, 1), z + 1.0), 1.0, r)
            z += 3.6
        items.append((bx(f"{name}_chapiteau{side}", (4.2, depth + 0.8, 1.2), (px, 0, z)), M["pierre_atlante"]))
    n = 9
    gap = 0.03
    for k in range(n):
        a0 = math.pi - k * math.pi / n - gap / 2
        a1 = math.pi - (k + 1) * math.pi / n + gap / 2
        key = k == n // 2
        items.append((ring_sector(f"{name}_cote{k}", r_in - 0.2, r_in + (4.4 if key else 3.4), a1, a0,
                                  depth + (0.6 if key else 0.0), steps=2, at=(0, 0, pillar_h)),
                      M["coquille"] if k % 2 == 0 else M["nacre"]))
    items += trident(f"{name}_trident", (0, -depth / 2 - 0.5, pillar_h + r_in + 2.0), 1.1)
    items += starfish(f"{name}_etoile", (-r_in - 1.6, -depth / 2 - 0.4, 6.0), 1.0, 10)
    low = finish(items, bevel=0.1, max_bevel=0.3, segments=2, angle=25)
    return assemble(name, low), None


def pearl_pillar(name: str, seed: int = 14, height: float = 10.0):
    """Pilier à perle : colonne cannelée de pierre atlante, coupe d'or, grosse perle (la lumière vient de Roblox)."""
    M = am()
    r = random.Random(seed)
    items = [(bx(f"{name}_socle", (4.4, 4.4, 1.2), (0, 0, 0)), M["sable_mer"])]
    col = G.lathe(f"{name}_colonne", [(0, 1.1), (1.4, 1.1), (1.25, 1.1 + height), (0, 1.1 + height)], segments=10, phase=0.2)
    items.append((col, M["pierre_atlante"]))
    cup = G.lathe(f"{name}_coupe", [(0, height + 1.0), (0.9, height + 1.0), (1.9, height + 1.7), (2.1, height + 2.3),
                                    (1.8, height + 2.35), (0, height + 1.9)], segments=10)
    items.append((cup, M["or"]))
    items.append((hull(f"{name}_perle", r, (2.4, 2.4, 2.3), points=30, flat_top=0.98, at=(0, 0, height + 1.9)), M["perle"]))
    for k in range(3):
        a = k * 2 * math.pi / 3
        items += coral_tuft(f"{name}_corail{k}", (math.cos(a) * 1.6, math.sin(a) * 1.6, 1.2), 1.1, r)
    low = finish(items, bevel=0.1, max_bevel=0.15, segments=2, angle=25)
    return assemble(name, low), None


def mosaic_slab(name: str, seed: int = 15, size=(8.0, 6.0, 1.2)):
    """Dalle atlante fendue, mosaïque : trident d'or et coquillage turquoise."""
    M = am()
    r = random.Random(seed)
    sx, sy, sz = size
    items = []
    cut = r.uniform(-0.6, 0.6)
    for k, ((cx, cy), (w, d)) in enumerate((((-sx / 4 + cut / 2 - 0.05, -sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((-sx / 4 + cut / 2 - 0.05, sy / 4), (sx / 2 + cut - 0.1, sy / 2 - 0.1)),
                                            ((sx / 4 + cut / 2 + 0.05, 0), (sx / 2 - cut - 0.1, sy - 0.1)))):
        items.append((bx(f"{name}_morceau{k}", (w, d, sz), (cx, cy, r.uniform(-0.12, 0.05)),
                         (r.uniform(-1.2, 1.2), r.uniform(-1.2, 1.2), r.uniform(-1.5, 1.5))), M["pierre_atlante"]))
    items.append((bx(f"{name}_hampe", (0.3, 2.6, 0.12), (0, 0, sz - 0.05)), M["or"]))
    items.append((bx(f"{name}_garde", (1.6, 0.3, 0.12), (0, 1.1, sz - 0.05)), M["or"]))
    for dx in (-0.65, 0.0, 0.65):
        items.append((bx(f"{name}_dent{dx}", (0.25, 0.9, 0.12), (dx, 1.6, sz - 0.05)), M["or"]))
    for k in range(5):
        a = math.radians(200 + k * 35)
        items.append((bx(f"{name}_coquillage{k}", (0.9, 0.25, 0.12), (math.cos(a) * 1.4, -1.6 + math.sin(a) * 0.6 + 0.6, sz - 0.05),
                         (0, 0, math.degrees(a) + 90)), M["corail_violet"]))
    low = finish(items, bevel=0.12, max_bevel=0.18, segments=2, angle=30)
    return assemble(name, low), None


def coral_wall(name: str, seed: int = 16, length: float = 12.0):
    """Muret de base : blocs de pierre atlante, coraux sur le dessus, cordage tendu devant entre deux bittes d'amarrage."""
    M = am()
    r = random.Random(seed)
    items = []
    x = -length / 2
    while x < length / 2 - 0.3:
        w = min(r.uniform(2.6, 3.8), length / 2 - x)
        items.append((bx(f"{name}_bloc{len(items)}", (w - 0.08, 2.0, 2.4), (x + w / 2, 0, 0), (0, 0, r.uniform(-0.8, 0.8)),
                         taper=(0.97, 0.93)), M["pierre_atlante"]))
        x += w
    for k in range(6):
        px = -length / 2 + (k + 0.5) * length / 6
        items += coral_tuft(f"{name}_corail{k}", (px, r.uniform(-0.4, 0.4), 2.35), 1.0, r)
    for side in (-1, 1):
        items.append((bx(f"{name}_bitte{side}", (0.7, 0.7, 2.6), (side * (length / 2 - 0.6), -1.3, 0)), M["bois_epave"]))
    items.append((bx(f"{name}_corde", (length - 1.2, 0.25, 0.25), (0, -1.3, 1.9)), M["corde"]))
    items += starfish(f"{name}_etoile", (1.5, -1.05, 1.2), 0.9, 0)
    low = finish(items, bevel=0.12, max_bevel=0.12, segments=2, angle=30)
    return assemble(name, low), None


def sand_stairs(name: str, seed: int = 17):
    am()
    return E.stairs(name, seed=seed, step_mat="sable_mer", cheek_mat="pierre_atlante")


def treasure_chest(name: str, seed: int = 18):
    """Coffre au trésor ouvert : caisse cerclée d'or, couvercle relevé, pièces d'or qui débordent, perles."""
    M = am()
    r = random.Random(seed)
    items = [(bx(f"{name}_caisse", (3.6, 2.4, 1.8), (0, 0, 0)), M["bois_epave_x"])]
    for x in (-1.3, 0, 1.3):
        items.append((bx(f"{name}_cercle{x}", (0.3, 2.5, 1.85), (x, 0, 0)), M["or"]))
    lid = bx(f"{name}_couvercle", (3.6, 2.4, 0.8), (0, 0, 0), (0, 0, 0), taper=(1.0, 0.7))
    G.transform(lid, Matrix.Translation((0, 1.2, 1.8)) @ Matrix.Rotation(math.radians(-70), 4, "X") @ Matrix.Translation((0, -1.2, 0)))
    items.append((lid, M["bois_epave_x"]))
    for k in range(10):
        items.append((bx(f"{name}_piece{k}", (0.6, 0.6, 0.18), (r.uniform(-1.4, 1.4), r.uniform(-0.9, 0.9), 1.75 + r.uniform(0, 0.4)),
                         (r.uniform(-25, 25), r.uniform(-25, 25), r.uniform(0, 90))), M["or"]))
    for k in range(5):
        items.append((bx(f"{name}_tas{k}", (0.6, 0.6, 0.18), (r.uniform(-2.2, 2.2), r.uniform(-2.0, -1.3), 0.0),
                         (0, 0, r.uniform(0, 90))), M["or"]))
    for k in range(3):
        items.append((hull(f"{name}_perle{k}", r, (0.5, 0.5, 0.5), points=16, at=(r.uniform(-1, 1), r.uniform(-0.5, 0.5), 2.0)), M["perle"]))
    low = finish(items, bevel=0.1, max_bevel=0.08, segments=2, angle=30)
    return assemble(name, low), None


def anchor(name: str, seed: int = 19):
    """Ancre à demi enterrée : verge, jas, anneau, bras recourbés à pattes, chaîne couchée dans le sable."""
    M = am()
    items = [(hull(f"{name}_sable", random.Random(seed), (5.0, 4.0, 1.0), flat_top=0.7), M["sable_mer"])]
    rot = Matrix.Translation((0, 0, 0.4)) @ Matrix.Rotation(math.radians(18), 4, "Y")
    parts = [(bx(f"{name}_verge", (0.6, 0.6, 6.0), (0, 0, 0)), "fer"),
             (bx(f"{name}_jas", (3.4, 0.5, 0.5), (0, 0, 5.2)), "fer"),
             (bx(f"{name}_anneau", (1.2, 0.3, 1.2), (0, 0, 6.0)), "fer")]
    for side in (-1, 1):
        a, b, c = Vector((0, 0, 0.3)), Vector((side * 1.6, 0, 0.6)), Vector((side * 2.3, 0, 1.9))
        parts.append((strut(f"{name}_bras{side}_0", a, b, 0.55, 0.55), "fer"))
        parts.append((strut(f"{name}_bras{side}_1", b, c, 0.5, 0.5), "fer"))
        parts.append((bx(f"{name}_patte{side}", (1.1, 0.4, 1.1), (c.x, 0, c.z - 0.3), (0, side * 40, 0), taper=(0.2, 1.0)), "fer"))
    for obj, mat in parts:
        G.transform(obj, rot)
        items.append((obj, M[mat]))
    for k in range(6):
        items.append((bx(f"{name}_maillon{k}", (0.8, 0.3, 0.5), (1.8 + k * 0.7, -1.2 - k * 0.15, 0.3), (0, 0, 90 * (k % 2) + 15)), M["fer"]))
    low = finish(items, bevel=0.1, max_bevel=0.1, segments=2, angle=30)
    return assemble(name, low), None


def shipwreck(name: str, seed: int = 20, length: float = 20.0):
    """Proue de l'épave de la Pieuvre Pirate : coque en tranches qui s'affinent ET remontent vers l'avant (+X), étrave
    pointue, bastingage, pont, mât brisé, voile en lambeaux, drapeau noir ; penchée et à moitié dans le sable."""
    M = am()
    r = random.Random(seed)
    items = []
    n = 8
    for k in range(n):
        t = k / (n - 1)
        w = 6.4 * (1 - 0.8 * t ** 1.8)
        lift = 2.6 * t ** 2  # la proue remonte
        h = 5.2 - 1.0 * t
        x = -length / 2 + k * length / n
        cx = x + length / n / 2
        items.append((bx(f"{name}_coque{k}", (length / n + 0.15, w, h), (cx, 0, -1.2 + lift), taper=(1.0, 1.18)),
                      M["bois_epave_x"]))
        items.append((bx(f"{name}_bordage{k}", (length / n + 0.2, w * 1.18 + 0.3, 0.45), (cx, 0, -1.2 + lift + h * 0.98)),
                      M["bois_epave"]))
        if k < n - 1:
            for side in (-1, 1):  # bastingage
                items.append((bx(f"{name}_montant{k}_{side}", (0.3, 0.3, 1.2), (cx, side * (w * 0.59 + 0.05), -1.2 + lift + h * 0.98 + 0.4)),
                              M["bois_epave"]))
    items.append((bx(f"{name}_pont", (length * 0.62, 5.6, 0.35), (-length * 0.18, 0, 3.9)), M["bois_epave_x"]))
    tip = Vector((length / 2 + 0.4, 0, 3.4))
    items.append((strut(f"{name}_etrave", Vector((length / 2 - 1.5, 0, 0.4)), tip + Vector((0.8, 0, 1.6)), 0.9, 0.7, taper=(0.5, 0.6)),
                  M["bois_epave"]))
    items.append((strut(f"{name}_beaupre", tip, tip + Vector((3.2, 0, 1.4)), 0.4, 0.4, taper=(0.6, 0.6)), M["bois_epave"]))
    mast_base = Vector((-length * 0.2, 0, 4.1))
    mast_top = mast_base + Vector((1.2, 0.3, 9.0))
    items.append((strut(f"{name}_mat", mast_base, mast_top, 0.75, 0.75, taper=(0.8, 0.8)), M["bois_epave"]))
    items.append((bx(f"{name}_vergue", (0.4, 5.6, 0.4), (mast_top.x - 0.5, 0, mast_top.z - 1.6)), M["bois_epave"]))
    for k in range(3):  # voile en lambeaux
        items.append((bx(f"{name}_voile{k}", (0.15, 1.6, 3.4 - k * 0.7), (mast_top.x - 0.4, -1.8 + k * 1.8, mast_top.z - 5.0 + k * 0.4),
                         (0, r.uniform(-8, 8), 0)), M["voile"]))
    items.append((bx(f"{name}_drapeau", (0.12, 2.2, 1.4), (mast_top.x, 1.2, mast_top.z - 0.6)), M["drapeau"]))
    items.append((bx(f"{name}_crane", (0.14, 0.65, 0.6), (mast_top.x - 0.05, 1.2, mast_top.z - 0.5)), M["blanc"]))
    items += coral_tuft(f"{name}_corail0", (length * 0.15, 3.0, 0.5), 1.5, r)
    items += coral_tuft(f"{name}_corail1", (-length * 0.35, -3.2, 0.2), 1.5, r)
    items += starfish(f"{name}_etoile", (-length * 0.05, -2.4, 4.1), 1.3, 0)
    objs = finish(items, bevel=0.1, max_bevel=0.2, segments=2, angle=30)
    tilt = Matrix.Rotation(math.radians(12), 4, "X") @ Matrix.Rotation(math.radians(-5), 4, "Y")
    for o in objs:
        G.transform(o, tilt)
    return assemble(name, objs), None


# =====================================================================================================================
# Catalogue
# =====================================================================================================================

ABYSSES = {
    "Abysses_Recif": (lambda n: reef(n, seed=4), 1024),
    "Abysses_Corail": (lambda n: branching_coral(n, seed=5), 1024),
    "Abysses_CorailEventail": (lambda n: fan_coral(n, seed=6), 512),
    "Abysses_Algue": (lambda n: kelp(n, seed=7), 1024),
    "Abysses_Anemone": (lambda n: anemones(n, seed=8), 1024),
    "Abysses_Rocher": (lambda n: sea_rock(n, seed=9), 1024),
    "Abysses_Coquillage": (lambda n: giant_clam(n, seed=10), 1024),
    "Abysses_Touffe": (lambda n: seagrass(n, seed=11), 512),
    "Abysses_ColonneEngloutie": (lambda n: sunken_column(n, seed=12), 1024),
    "Abysses_PorteAtlante": (lambda n: atlantean_gate(n, seed=13), 1024),
    "Abysses_PilierPerle": (lambda n: pearl_pillar(n, seed=14), 1024),
    "Abysses_Dalle": (lambda n: mosaic_slab(n, seed=15), 512),
    "Abysses_Muret": (lambda n: coral_wall(n, seed=16), 1024),
    "Abysses_Escalier": (lambda n: sand_stairs(n, seed=17), 1024),
    "Abysses_Coffre": (lambda n: treasure_chest(n, seed=18), 512),
    "Abysses_Ancre": (lambda n: anchor(n, seed=19), 512),
    "Abysses_Epave": (lambda n: shipwreck(n, seed=20), 1024),
}

E.BUILDERS.update(ABYSSES)
E.WORLDS["Abysses"] = list(ABYSSES)
