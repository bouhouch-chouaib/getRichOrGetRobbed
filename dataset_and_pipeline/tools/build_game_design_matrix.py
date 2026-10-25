"""Génère dataset_and_pipeline/game_design_matrix.json.

Les statistiques (taille, poids, vitesse de transport, revenu, chance de tirage) sont CALCULÉES à partir du code du jeu
(src/shared/Config.lua, PetCatalog.lua, PetSizes.lua) avec les mêmes formules que le serveur : relancer ce script
après un rééquilibrage pour garder le fichier juste. Les fiches 3D et les repères de recherche sont écrits à la main
plus bas (ART_SPECS, EGG_SHELLS, BENCHMARKS).

    python dataset_and_pipeline/tools/build_game_design_matrix.py
"""

from __future__ import annotations

import json
import re
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / "src" / "shared"
OUT = ROOT / "dataset_and_pipeline" / "game_design_matrix.json"


# --- Lecture du code du jeu -------------------------------------------------------------------------------------

def read(name: str) -> str:
    return (SHARED / name).read_text(encoding="utf-8")


def parse_rarities(config: str) -> list[dict]:
    rarities = []
    pattern = re.compile(
        r'\{ Id = "(\w+)", Name = "([^"]+)", Weight = ([\d.]+), Color = Color3\.fromRGB\((\d+), (\d+), (\d+)\),'
        r" Multiplier = ([\d.]+), Income = ([\d.e]+) \}"
    )
    for m in pattern.finditer(config):
        rarities.append({
            "id": m[1], "name": m[2], "weight": float(m[3]),
            "color": "#%02X%02X%02X" % (int(m[4]), int(m[5]), int(m[6])),
            "multiplier": float(m[7]), "income": float(m[8]),
        })
    assert len(rarities) == 8, "Config.Rarities introuvable ou modifié"
    return rarities


def parse_number(config: str, pattern: str) -> float:
    m = re.search(pattern, config)
    assert m, pattern
    return float(m[1])


def config_block(config: str, name: str) -> str:
    """Texte du tableau `Config.<name> = { ... }` : chercher une valeur DANS le bon tableau (BasePrice, HoldDuration et
    IncomeBonus existent dans plusieurs tableaux ; avant le 25 oct., la matrice prenait le premier venu)."""
    start = config.index(f"Config.{name} = {{")
    depth = 0
    for index in range(start, len(config)):
        if config[index] == "{":
            depth += 1
        elif config[index] == "}":
            depth -= 1
            if depth == 0:
                return config[start:index + 1]
    raise ValueError(name)


def parse_catalog(catalog: str) -> list[dict]:
    pets = []
    for m in re.finditer(r'\b(pet|worldPet)\("(\w+)", "([^"]+)", "(\w+)"', catalog):
        pets.append({"id": m[2], "name": m[3], "rarity": m[4], "world_exclusive": m[1] == "worldPet"})
    assert len(pets) >= 75, "PetCatalog : moins de 75 familiers lus"
    return pets


def parse_sizes(sizes: str) -> tuple[dict[str, float], dict[str, tuple[float, float]], float]:
    heights = {m[1]: float(m[2]) for m in re.finditer(r"^\t(\w+) = ([\d.]+),", sizes, re.M)}
    bands = {m[1]: (float(m[2]), float(m[3])) for m in re.finditer(r"^\t(\w+) = \{ ([\d.]+), ([\d.]+) \},", sizes, re.M)}
    player = parse_number(sizes, r"PetSizes\.PLAYER = (\d+)")
    return heights, bands, player


# --- Fiches 3D écrites à la main ----------------------------------------------------------------------------------
# tier = classement demandé par la mission (Common, Rare, Epic, Mythic, Secret) ; le jeu garde ses 8 raretés.
# preset = fonction de blender_tools/shader_node_library.py ; recipe = fonction de procedural_geometry_recipes.py.

ART_SPECS: list[dict] = [
    # ---------------- Common (jeu : Commun / Inhabituel) ----------------
    {
        "id": "ChienSaucisse", "tier": "Common",
        "silhouette": "Saucisse horizontale 3,2:1, tête ronde surdimensionnée (40 % de la hauteur), 4 pattes courtes en "
                      "bulbes, oreilles tombantes en gouttes. Lecture : une ligne horizontale + un gros rond.",
        "palette": {"primary": "#8C552D", "secondary": "#5A371E", "belly": "#E8B98A", "accent": "#E8141A", "eyes": "#1B1B22"},
        "materials": [
            {"zone": "body", "preset": "create_stylized_edge_wear_material", "params": {"base": "#8C552D", "edge": "#C88A55", "cavity": "#3D2414", "wear": 0.55}},
            {"zone": "collar", "preset": "create_etched_metal_or_gold", "params": {"tint": "#B0B6C2", "scratches": 0.4}},
        ],
        "accessories": ["collier rouge à médaille ronde"], "aura": None,
        "recipe": "organic_blob_body(metaballs capsule) + voxel_fuse + edge_wear", "tri_budget": 3500,
    },
    {
        "id": "AstroBoulon", "tier": "Common",
        "silhouette": "Petit robot trapu : tronc tonneau chanfreiné, tête cube arrondi + visière bombée, 2 antennes à "
                      "boule, bras en tubes courts. Lecture : un tonneau + un hublot.",
        "palette": {"primary": "#C8CDD7", "secondary": "#3C8CFF", "accent": "#FF7A1A", "rust": "#8A4A22", "eyes": "#9CF5FF"},
        "materials": [
            {"zone": "shell", "preset": "create_etched_metal_or_gold", "params": {"tint": "#C8CDD7", "scratches": 0.7, "rust": 0.25}},
            {"zone": "visor", "preset": "create_stylized_crystal_or_gem", "params": {"core": "#0E2A55", "rim": "#9CF5FF"}},
        ],
        "accessories": ["2 antennes à boule", "boulons apparents (bevel 3 segments)"], "aura": None,
        "recipe": "hard_surface_shell(bevel 3 seg, profil 0.7) + weighted_normal", "tri_budget": 3000,
    },
    {
        "id": "MyrtilleLunaire", "tier": "Common",
        "silhouette": "Sphère légèrement écrasée (1:0,85) criblée de cratères en creux, couronne de 5 sépales en étoile "
                      "sur le dessus, petites jambes en gouttes.",
        "palette": {"primary": "#505AC8", "secondary": "#2B2F7A", "crater": "#BEBED2", "accent": "#C8C8FF", "eyes": "#FFFFFF"},
        "materials": [
            {"zone": "skin", "preset": "create_organic_scales_or_skin", "params": {"base": "#505AC8", "variation": "#2B2F7A", "cells": 6.0, "sss": 0.15}},
        ],
        "accessories": ["sépales en étoile"], "aura": {"type": "sparkles", "color": "#C8C8FF"},
        "recipe": "organic_blob_body + displace(voronoi cratères, -0.04)", "tri_budget": 3000,
    },
    {
        "id": "CochonTirelire", "tier": "Common",
        "silhouette": "Tirelire en œuf couché, groin cylindrique chanfreiné, fente à pièce sur le dos avec une pièce qui "
                      "dépasse, 4 pattes en cônes tronqués.",
        "palette": {"primary": "#FFA0BE", "secondary": "#E07A9A", "glaze": "#FFE3EC", "accent": "#FFC830", "cracks": "#7A3A4E"},
        "materials": [
            {"zone": "body", "preset": "create_stylized_edge_wear_material", "params": {"base": "#FFA0BE", "edge": "#FFE3EC", "cavity": "#7A3A4E", "wear": 0.35, "crackle": 0.6}},
            {"zone": "coin", "preset": "create_etched_metal_or_gold", "params": {"tint": "#FFC830", "scratches": 0.5}},
        ],
        "accessories": ["pièce d'or coincée dans la fente"], "aura": None,
        "recipe": "organic_blob_body + bevel du groin + voxel_fuse", "tri_budget": 3000,
        "material_note": "céramique craquelée : réseau Voronoi DISTANCE_TO_EDGE dans la couleur et le relief",
    },
    # ---------------- Rare (jeu : Rare) ----------------
    {
        "id": "RenardFurtif", "tier": "Rare",
        "silhouette": "Renard assis de 3/4, museau en coin, grandes oreilles triangulaires, queue en panache plus grosse "
                      "que le corps, bandana noué.",
        "palette": {"primary": "#F07828", "secondary": "#FFFFFF", "tips": "#2A1A12", "accent": "#D41E2A", "eyes": "#1B1B22"},
        "materials": [
            {"zone": "fur", "preset": "create_organic_scales_or_skin", "params": {"base": "#F07828", "variation": "#C4561A", "cells": 14.0, "sss": 0.1}},
            {"zone": "bandana", "preset": "create_stylized_edge_wear_material", "params": {"base": "#D41E2A", "edge": "#FF6A5A", "cavity": "#5A0A12", "wear": 0.3}},
        ],
        "accessories": ["bandana rouge"], "aura": None,
        "recipe": "organic_blob_body(métaboules) + voxel_fuse + decimate", "tri_budget": 4500,
    },
    {
        "id": "TelecommandePerdue", "tier": "Rare",
        "silhouette": "Télécommande épaisse qui flotte inclinée à 20°, boutons ronds en relief (bevel), LED rouge sur le "
                      "dessus, petits bras en ressorts.",
        "palette": {"primary": "#282832", "secondary": "#4A4A5A", "accent": "#FF3C3C", "buttons": "#E8E8F0"},
        "materials": [
            {"zone": "shell", "preset": "create_stylized_edge_wear_material", "params": {"base": "#282832", "edge": "#6A6A80", "cavity": "#0C0C10", "wear": 0.7}},
            {"zone": "led", "preset": "create_stylized_crystal_or_gem", "params": {"core": "#FF3C3C", "rim": "#FFD0D0", "emission": 2.0}},
        ],
        "accessories": ["LED pulsante", "ressorts"], "aura": {"type": "pulse", "color": "#FF3C3C"},
        "recipe": "hard_surface_shell + boutons en array", "tri_budget": 3500,
    },
    {
        "id": "ChampignonVeneneux", "tier": "Rare",
        "silhouette": "Gros chapeau en dôme (60 % de la masse) à pois en relief, pied trapu en tonneau, collerette "
                      "ondulée, yeux sous le chapeau.",
        "palette": {"primary": "#DC1E1E", "secondary": "#FFFFFF", "stem": "#F2E6D0", "gills": "#C8B496", "accent": "#7CFF6A"},
        "materials": [
            {"zone": "cap", "preset": "create_organic_scales_or_skin", "params": {"base": "#DC1E1E", "variation": "#A01212", "cells": 4.0, "sss": 0.25}},
            {"zone": "stem", "preset": "create_stylized_edge_wear_material", "params": {"base": "#F2E6D0", "edge": "#FFFFFF", "cavity": "#8A7A60", "wear": 0.4}},
        ],
        "accessories": ["pois en relief"], "aura": {"type": "spores", "color": "#7CFF6A"},
        "recipe": "organic_blob_body + displace(clouds) sur la collerette", "tri_budget": 4000,
    },
    {
        "id": "CorbeauHorloge", "tier": "Rare",
        "silhouette": "Oiseau mécanique compact, plumes en plaques de métal superposées, engrenage apparent sur la "
                      "poitrine, clé de remontage dans le dos.",
        "palette": {"primary": "#1E1E26", "secondary": "#C87832", "accent": "#FFD27A", "eyes": "#FF9A2A"},
        "materials": [
            {"zone": "plates", "preset": "create_etched_metal_or_gold", "params": {"tint": "#3A3A46", "scratches": 0.6}},
            {"zone": "gears", "preset": "create_etched_metal_or_gold", "params": {"tint": "#C87832", "scratches": 0.8, "rust": 0.15}},
        ],
        "accessories": ["engrenage", "clé de remontage"], "aura": None,
        "recipe": "hard_surface_shell + engrenages (bmesh extrude)", "tri_budget": 5000,
    },
    # ---------------- Epic (jeu : Épique / Légendaire) ----------------
    {
        "id": "RoseCristal", "tier": "Epic",
        "silhouette": "Rose géante taillée en cristal : pétales en facettes planes (pas de lissage), tige épaisse en "
                      "prisme hexagonal, 2 feuilles en losange. Lecture : une gemme qui fleurit.",
        "palette": {"primary": "#50AAFF", "core": "#0A2A6E", "rim": "#D8F0FF", "stem": "#3C8C50", "accent": "#FFFFFF"},
        "materials": [
            {"zone": "petals", "preset": "create_stylized_crystal_or_gem", "params": {"core": "#0A2A6E", "mid": "#50AAFF", "rim": "#D8F0FF"}},
            {"zone": "stem", "preset": "create_organic_scales_or_skin", "params": {"base": "#3C8C50", "variation": "#1E5A30", "cells": 10.0}},
        ],
        "accessories": [], "aura": {"type": "sparkles", "color": "#D8F0FF"},
        "recipe": "crystal_cluster(facettes plates) + bevel 1 segment", "tri_budget": 5000,
    },
    {
        "id": "DragonnetObsidienne", "tier": "Epic",
        "silhouette": "Petit dragon anguleux : tête en coin, cornes en cristaux, ailes repliées en éventail de plaques, "
                      "queue en pointe de lance. Arêtes vives éclaircies.",
        "palette": {"primary": "#1E1928", "secondary": "#3A2E55", "accent": "#8C5AFF", "eyes": "#C8A0FF"},
        "materials": [
            {"zone": "scales", "preset": "create_organic_scales_or_skin", "params": {"base": "#1E1928", "variation": "#3A2E55", "cells": 18.0, "sss": 0.0, "gloss": 0.25}},
            {"zone": "horns", "preset": "create_stylized_crystal_or_gem", "params": {"core": "#2A1050", "mid": "#8C5AFF", "rim": "#E6D8FF"}},
        ],
        "accessories": ["cornes en cristal violet"], "aura": {"type": "ring", "color": "#8C5AFF"},
        "recipe": "organic_blob_body + crystal_cluster(cornes) + voxel_fuse", "tri_budget": 6000,
    },
    {
        "id": "BurritoNebuleuse", "tier": "Epic",
        "silhouette": "Burrito dodu légèrement plié, galette avec plis (displace) et taches grillées, une nébuleuse "
                      "lumineuse déborde des deux bouts.",
        "palette": {"primary": "#EBC882", "toast": "#9A6A30", "nebula": "#AA50E6", "nebula2": "#FF5AC8", "eyes": "#1B1B22"},
        "materials": [
            {"zone": "tortilla", "preset": "create_stylized_edge_wear_material", "params": {"base": "#EBC882", "edge": "#FFF0C8", "cavity": "#9A6A30", "wear": 0.5}},
            {"zone": "nebula", "preset": "create_stylized_crystal_or_gem", "params": {"core": "#2A0A50", "mid": "#AA50E6", "rim": "#FF5AC8", "emission": 1.5}},
        ],
        "accessories": [], "aura": {"type": "aura", "color": "#C864FF"},
        "recipe": "organic_blob_body + displace(noise ridged) plis", "tri_budget": 5000,
    },
    {
        "id": "TigreBengal", "tier": "Epic",
        "silhouette": "Tigre massif, épaules hautes, grosse tête carrée, pattes épaisses, rayures dorées peintes par "
                      "zones (modèle Blender existant : ArtModels.TigreBengal).",
        "palette": {"primary": "#F58C1E", "stripes": "#FFD23C", "belly": "#FFF4E0", "dark": "#2A1A10", "eyes": "#7CFF6A"},
        "materials": [
            {"zone": "fur", "preset": "create_organic_scales_or_skin", "params": {"base": "#F58C1E", "variation": "#C86A10", "cells": 12.0, "stripes": "#FFD23C"}},
        ],
        "accessories": [], "aura": {"type": "sparkles", "color": "#FFD23C"},
        "recipe": "organic_blob_body(métaboules) + voxel_fuse + decimate", "tri_budget": 6500,
    },
    # ---------------- Mythic (jeu : Mythique / Divin) ----------------
    {
        "id": "JumeauxEclipse", "tier": "Mythic",
        "silhouette": "Deux sphères soudées (soleil 60 % / lune 40 %), le soleil couronné de rayons en pointes "
                      "chanfreinées, la lune cratérisée ; un anneau d'or les ceinture.",
        "palette": {"sun": "#FFC828", "sun_rim": "#FF7A1A", "moon": "#C8D2F0", "moon_dark": "#6A7290", "ring": "#FFD24A"},
        "materials": [
            {"zone": "sun", "preset": "create_stylized_edge_wear_material", "params": {"base": "#FFC828", "edge": "#FFF2A0", "cavity": "#C85A10", "wear": 0.4, "emission": 0.6}},
            {"zone": "moon", "preset": "create_organic_scales_or_skin", "params": {"base": "#C8D2F0", "variation": "#6A7290", "cells": 5.0}},
            {"zone": "ring", "preset": "create_etched_metal_or_gold", "params": {"tint": "#FFD24A", "scratches": 0.5}},
        ],
        "accessories": ["anneau d'or"], "aura": {"type": "pulse", "color": "#FFE678"},
        "recipe": "voxel_fuse(2 sphères + rayons) + bevel", "tri_budget": 6500,
    },
    {
        "id": "ToupieTrouDeVer", "tier": "Mythic",
        "silhouette": "Toupie à 3 étages chanfreinés (lathe/screw), pointe en cristal, disque d'accrétion autour, "
                      "spirale gravée sur le dessus.",
        "palette": {"primary": "#3C1E6E", "secondary": "#00E6FF", "metal": "#C8C8D8", "core": "#05020F"},
        "materials": [
            {"zone": "body", "preset": "create_etched_metal_or_gold", "params": {"tint": "#3C1E6E", "scratches": 0.4}},
            {"zone": "tip", "preset": "create_stylized_crystal_or_gem", "params": {"core": "#05020F", "mid": "#00E6FF", "rim": "#E0FFFF", "emission": 1.2}},
        ],
        "accessories": ["disque d'accrétion"], "aura": {"type": "pulse", "color": "#00E6FF"},
        "recipe": "lathe_profile(screw) + bevel 3 seg + weighted_normal", "tri_budget": 6000,
    },
    {
        "id": "KrakenBaignoire", "tier": "Mythic",
        "silhouette": "Tête de pieuvre en goutte renversée, 6 tentacules courbes en spirale (courbes -> maillage), "
                      "petite couronne d'or penchée, un canard de bain dans un tentacule.",
        "palette": {"primary": "#9646C8", "secondary": "#5A1E8C", "suckers": "#FFB4E6", "crown": "#FFD24A", "duck": "#FFE628"},
        "materials": [
            {"zone": "skin", "preset": "create_organic_scales_or_skin", "params": {"base": "#9646C8", "variation": "#5A1E8C", "cells": 9.0, "sss": 0.35}},
            {"zone": "crown", "preset": "create_etched_metal_or_gold", "params": {"tint": "#FFD24A", "scratches": 0.6}},
        ],
        "accessories": ["couronne d'or", "canard de bain"], "aura": {"type": "bubbles", "color": "#B4E6FF"},
        "recipe": "organic_blob_body + tentacules (courbes bevel) + voxel_fuse", "tri_budget": 7000,
    },
    {
        "id": "PhenixSolaire", "tier": "Mythic",
        "silhouette": "Oiseau dressé, ailes ouvertes en V faites de plumes-lames, longue queue en flammes stylisées "
                      "(rubans pliés), crête en couronne.",
        "palette": {"primary": "#FF7814", "secondary": "#FFE63C", "core": "#FFFFFF", "dark": "#B4280A"},
        "materials": [
            {"zone": "feathers", "preset": "create_organic_scales_or_skin", "params": {"base": "#FF7814", "variation": "#B4280A", "cells": 16.0, "emission": 0.8}},
            {"zone": "flames", "preset": "create_stylized_crystal_or_gem", "params": {"core": "#FF7814", "mid": "#FFE63C", "rim": "#FFFFFF", "emission": 2.5}},
        ],
        "accessories": ["crête en couronne"], "aura": {"type": "fire", "color": "#FFA028"},
        "recipe": "organic_blob_body + plumes en array courbé + voxel_fuse", "tri_budget": 7500,
    },
    # ---------------- Secret (jeu : Sigma) ----------------
    {
        "id": "CapybaraZen", "tier": "Secret",
        "silhouette": "Capybara massif et carré, paupières mi-closes, assis bien droit, une orange posée sur la tête, "
                      "petit nuage de méditation sous lui.",
        "palette": {"primary": "#A06E46", "secondary": "#6E4A2E", "orange": "#FF961E", "leaf": "#3CB450", "aura": "#FFD23C"},
        "materials": [
            {"zone": "fur", "preset": "create_organic_scales_or_skin", "params": {"base": "#A06E46", "variation": "#6E4A2E", "cells": 20.0, "sss": 0.1}},
            {"zone": "orange", "preset": "create_organic_scales_or_skin", "params": {"base": "#FF961E", "variation": "#E0700A", "cells": 40.0, "sss": 0.3}},
        ],
        "accessories": ["orange + feuille", "nuage"], "aura": {"type": "aura", "color": "#FFD23C"},
        "recipe": "organic_blob_body(métaboules) + voxel_fuse + decimate", "tri_budget": 7500,
    },
    {
        "id": "OuroborosInfini", "tier": "Secret",
        "silhouette": "Serpent d'or en anneau parfait qui se mord la queue (courbe circulaire + bevel), écailles en "
                      "relief, yeux émeraude, anneau qui tourne sur lui-même.",
        "palette": {"primary": "#FFD24A", "secondary": "#C89614", "accent": "#28FF8C", "white": "#FFFFFF"},
        "materials": [
            {"zone": "scales", "preset": "create_etched_metal_or_gold", "params": {"tint": "#FFD24A", "scratches": 0.4, "hammered": 0.6}},
            {"zone": "eyes", "preset": "create_stylized_crystal_or_gem", "params": {"core": "#0A5A2A", "mid": "#28FF8C", "rim": "#E0FFE8", "emission": 1.5}},
        ],
        "accessories": [], "aura": {"type": "aura", "color": "#FFD24A"},
        "recipe": "curve_ring(bevel) + displace(voronoi écailles) + weighted_normal", "tri_budget": 7000,
    },
    {
        "id": "CanardTractopelle", "tier": "Secret",
        "silhouette": "Canard de bain géant posé sur des chenilles, bras de pelle articulé à l'avant, tout en or "
                      "martelé ; casque de chantier.",
        "palette": {"primary": "#FFE128", "gold": "#FFC830", "tracks": "#3A3A46", "helmet": "#FF8C1A"},
        "materials": [
            {"zone": "duck", "preset": "create_etched_metal_or_gold", "params": {"tint": "#FFC830", "scratches": 0.5, "hammered": 0.8}},
            {"zone": "tracks", "preset": "create_stylized_edge_wear_material", "params": {"base": "#3A3A46", "edge": "#8A8A9A", "cavity": "#121216", "wear": 0.8}},
        ],
        "accessories": ["chenilles", "pelle", "casque"], "aura": {"type": "aura", "color": "#FFD23C"},
        "recipe": "organic_blob_body + hard_surface_shell(chenilles) ", "tri_budget": 8000,
    },
    {
        "id": "FougereFibonacci", "tier": "Secret",
        "silhouette": "Crosse de fougère en spirale dorée (spirale de Fibonacci), folioles en losanges de plus en plus "
                      "petites, blanc nacré qui irise sur les arêtes.",
        "palette": {"primary": "#F8F8FF", "secondary": "#C8D8FF", "accent": "#FFE6A0", "core": "#9AB4FF"},
        "materials": [
            {"zone": "fronds", "preset": "create_stylized_crystal_or_gem", "params": {"core": "#9AB4FF", "mid": "#F8F8FF", "rim": "#FFFFFF", "emission": 0.5}},
        ],
        "accessories": [], "aura": {"type": "aura", "color": "#FFFFFF"},
        "recipe": "spirale (courbe) + folioles en array + voxel_fuse", "tri_budget": 7500,
    },
]

EGG_SHELLS = [
    {"tier": "Common", "shape": "œuf 1:1,3, coquille lisse à tenons", "palette": {"shell": "#F2EAD8", "spots": "#C8B48C"},
     "preset": "create_stylized_edge_wear_material", "detail": "taches Voronoi douces, arêtes de tenons éclaircies",
     "aura": None},
    {"tier": "Rare", "shape": "œuf 1:1,3 + bande en relief au milieu", "palette": {"shell": "#46A0FF", "band": "#FFFFFF"},
     "preset": "create_organic_scales_or_skin", "detail": "écailles fines, bande chanfreinée", "aura": None},
    {"tier": "Epic", "shape": "œuf 1:1,35 avec 3 cristaux qui percent la coquille", "palette": {"shell": "#B450FF", "crystal": "#E6C8FF"},
     "preset": "create_stylized_crystal_or_gem", "detail": "fissures lumineuses (Voronoi DISTANCE_TO_EDGE)", "aura": {"type": "ring", "color": "#D50BFA"}},
    {"tier": "Mythic", "shape": "œuf 1:1,4 serti dans une monture d'or (4 griffes), facettes de gemme dans la "
     "partie haute, éclats de cristal sur la base", "palette": {"shell": "#FF4678", "core": "#4A0A2A", "rim": "#FFD0DE", "gold": "#FFC830"},
     "preset": "create_stylized_crystal_or_gem + create_etched_metal_or_gold", "detail": "PoC de la phase 1 (run_poc.py)",
     "aura": {"type": "pulse", "color": "#FF4678"}},
    {"tier": "Secret", "shape": "œuf 1:1,4 en verre d'étoiles, anneaux orbitaux d'or martelé, flotte au-dessus du nid",
     "palette": {"shell": "#0A0A1E", "stars": "#FFFFFF", "ring": "#FFD24A"}, "preset": "create_stylized_crystal_or_gem",
     "detail": "ne se montre qu'à l'éclosion (mutations secrètes du jeu)", "aura": {"type": "aura", "color": "#FFFFFF"}},
]

TIERS = [
    {"id": "Common", "game_rarities": ["Commun", "Inhabituel"], "color": "#C8C8C8",
     "visual_budget": {"tris": "2 500 - 3 500", "materials": "1 - 2", "accessories": "0 - 1", "aura": "aucune ou étincelles",
                       "texture": "1024 (512 accepté)", "emission": "interdite"}},
    {"id": "Rare", "game_rarities": ["Rare"], "color": "#46A0FF",
     "visual_budget": {"tris": "3 500 - 5 000", "materials": "2", "accessories": "1", "aura": "particules discrètes",
                       "texture": "1024", "emission": "petits points (LED, yeux)"}},
    {"id": "Epic", "game_rarities": ["Epique", "Legendaire"], "color": "#B450FF",
     "visual_budget": {"tris": "5 000 - 6 500", "materials": "2 - 3", "accessories": "1 - 2", "aura": "anneau au sol + particules",
                       "texture": "1024", "emission": "détails (cristaux)"}},
    {"id": "Mythic", "game_rarities": ["Mythique", "Divin"], "color": "#FF4678",
     "visual_budget": {"tris": "6 000 - 7 500", "materials": "3", "accessories": "2", "aura": "pulsation + rayons",
                       "texture": "1024", "emission": "zones entières"}},
    {"id": "Secret", "game_rarities": ["Sigma"], "color": "#FFE63C",
     "visual_budget": {"tris": "7 000 - 8 000", "materials": "3", "accessories": "2 - 3", "aura": "aura pleine + annonce serveur",
                       "texture": "1024", "emission": "aura + détails"}},
]

BENCHMARKS = {
    "_avertissement": "Chiffres relevés sur des guides de fans (oct. 2026), pas sur des sources officielles ; ils changent "
                      "à chaque mise à jour. Ils servent à calibrer des ordres de grandeur, jamais à copier.",
    "steal_a_brainrot": {
        "tiers_income_per_sec": {"Common": "1 - 14", "Rare": "15 - 75", "Epic": "75 - 325", "Legendary": "200 - 2 300",
                                 "Mythic": "1 400 - 16 500", "God": "10 000 - 295 000", "Secret": "250 000 - 200 M",
                                 "OG": "250 M - 350 M"},
        "tiers_cost": {"Common": "25 - 1,7 K", "Rare": "2 K - 9,7 K", "Epic": "10 K - 47,5 K", "Legendary": "35 K - 345 K",
                       "Mythic": "300 K - 4,9 M", "God": "5 M - 67 M", "Secret": "50 M - 200 B"},
        "cost_over_income_seconds": "~25 à 300 s : un achat se rembourse en quelques minutes",
        "conveyor_guarantees": "un Légendaire toutes les 5 min, un Mythique toutes les 15 min (serveurs publics)",
        "base_lock": "60 s (sources en désaccord : 30 s à l'arrivée puis 60 s ; +10 s par rebirth selon un guide)",
        "carry": "le voleur est ralenti et désarmé ; un seul coup renvoie l'objet volé à sa base",
        "rebirth": "exige de l'argent ET des personnages précis (ex. rebirth 10 : 250 B + un personnage donné)",
        "sources": ["https://allthings.how/steal-a-brainrot-brainrots-rarities-and-prices-full-list/",
                    "https://www.sportskeeda.com/roblox-news/steal-brainrot-rebirth-16-update-guide",
                    "https://games.gg/roblox/guides/steal-a-brainrot-ultimate-beginners-guide/"],
    },
    "steal_an_egg": {
        "loop": "voler des œufs dans des biomes ou chez les autres, les rapporter, les faire éclore, revenu passif",
        "tiers_income_per_sec": {"Common": "1 - 6", "Uncommon": "8 - 12", "Rare": "35 - 220", "Epic": "180 - 1 100",
                                 "Legendary": "1 800 - 15 000", "Mythic": "16 000 - 120 000", "Cosmic": "400 K - 1,5 M",
                                 "Secret": "8 M"},
        "biome_respawn": "œufs des biomes réapparaissent toutes les 4,5 à 5 min (sources en désaccord)",
        "style": "tout en briques à tenons, voxels, couleurs saturées (relevé dans docs/DIRECTION_ARTISTIQUE.md)",
        "sources": ["https://games.gg/roblox/guides/steal-an-egg-all-eggs-pets-and-income-rates/"],
    },
    "pet_simulator_99": {
        "egg_ladder_example": [50, 35, 13, 1.25, 0.7, 0.05],
        "lecture": "3 familiers « communs » font 98 % des tirages ; les grosses versions sont à ~1/80 et ~1/143, la "
                   "très grosse à 1/2 000 : la rareté vient d'un échelon à part, pas d'une longue liste",
        "variants": "passe « œufs magiques » : 10 % doré, 10 % arc-en-ciel (variantes de couleur d'un même familier)",
        "sources": ["https://www.sportskeeda.com/roblox-news/pet-simulator-99-how-get-titanic-spongebob-squarepants",
                    "https://pet-simulator.fandom.com/wiki/Anchor_Egg_(Pet_Simulator_99)",
                    "https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99)"],
    },
    "sols_rng": {
        "rarity_scale": "affichée en « 1 sur X », de 1/2 à 1/3 000 000 000 ; paliers à 1/100 K, 1/1 M, 1/10 M, 1/100 M, 1/1 B",
        "biome_multipliers": {"Windy": 3, "Rainy": 4, "Starfall": 5},
        "presentation": "cinématique de plus en plus longue avec la rareté ; annonce à tout le serveur au-delà de 1/100 M ; "
                        "musique dédiée au-delà de 1/1 B",
        "sources": ["https://allthings.how/sols-rng-aura-tier-list-every-rarity-and-drop-rate-ranked/"],
    },
    "roblox_tech": {
        "surface_appearance": "ColorMap (+ alpha), NormalMap OpenGL tangent space uniquement (plat = 127,127,255), "
                              "RoughnessMap, MetalnessMap (0 ou 1), EmissiveMaskContent ; AlphaMode Overlay par défaut",
        "mesh_limit_tris": 20000,
        "mesh_rules": "maillage étanche, pas d'épaisseur nulle, quads de préférence",
        "sources": ["https://create.roblox.com/docs/art/modeling/surface-appearance",
                    "https://create.roblox.com/docs/art/modeling/specifications"],
    },
}

DESIGN_PRINCIPLES = [
    "Revenu x7 environ d'une rareté à la suivante (jeu : 2 -> 14 -> 100 -> 700 -> 5K -> 35K -> 250K -> 1,75M) ; les "
    "jeux de référence montent de x5 à x10 par palier.",
    "La rareté se lit à 10 m : taille (PetSizes : 0,5 à 2,9 joueurs), aura, émission et nombre d'accessoires montent "
    "avec elle ; un Commun n'émet jamais de lumière.",
    "Plus c'est rare, plus c'est lourd à voler : poids = taille^3, le voleur ralentit (formule Config.Carry).",
    "Révélation proportionnelle à la rareté (Sol's RNG) : éclosion plus longue et annonce serveur pour Mythique+.",
    "Variantes de couleur rares (PS99) = mutations secrètes du jeu (Doré, Diamant, Arc-en-ciel) : le pipeline doit "
    "baker une ColorMap claire pour qu'une teinte puisse être appliquée (SurfaceAppearance.Color / AlphaMode TintMask).",
    "Jamais de bloc Néon pour le volume : l'émission sert aux détails (yeux, LED, cœur de cristal) et passe par "
    "EmissiveMaskContent ou une petite pièce séparée.",
]


# --- Calculs ---------------------------------------------------------------------------------------------------

def main() -> None:
    config, catalog_src, sizes_src = read("Config.lua"), read("PetCatalog.lua"), read("PetSizes.lua")
    rarities = parse_rarities(config)
    rarity_by_id = {r["id"]: r for r in rarities}
    total_weight = sum(r["weight"] for r in rarities)
    pets = parse_catalog(catalog_src)
    heights, bands, player = parse_sizes(sizes_src)

    carry_block = config_block(config, "Carry")
    carry = {
        # Depuis le 25 oct. (ECONOMY_REPORT.md règle 5) : vitesse selon la rareté, plus selon la taille et la Force.
        "by_rarity": [float(x) for x in re.search(r"SpeedByRarity = \{([^}]*)\}", carry_block)[1].split(",")],
        "min": parse_number(carry_block, r"MinSpeed = ([\d.]+)"),
        "max": parse_number(carry_block, r"MaxSpeed = ([\d.]+)"),
    }
    strength_base = parse_number(config, r"Strength = \{ Base = (\d+)")
    strength_max = strength_base + parse_number(config, r"Strength = \{ Base = \d+, PerLevel = (\d+)") * \
        parse_number(config, r"Strength = \{ Base = \d+, PerLevel = \d+, MaxLevel = (\d+)")
    walk_speed = parse_number(config, r"Speed = \{ Base = (\d+)")

    # Rang dans la rareté = ordre du catalogue (PetCatalog.ByRarity : familiers de base puis exclusifs des mondes).
    rank: dict[str, int] = {}
    counter: dict[str, int] = {}
    for pet in sorted(pets, key=lambda p: p["world_exclusive"]):
        counter[pet["rarity"]] = counter.get(pet["rarity"], 0) + 1
        rank[pet["id"]] = counter[pet["rarity"]]
    base_count = {}
    for pet in pets:
        if not pet["world_exclusive"]:
            base_count[pet["rarity"]] = base_count.get(pet["rarity"], 0) + 1
    by_id = {p["id"]: p for p in pets}

    def carry_speed(rarity_index: int) -> float:
        """x vitesse de marche, propriétaire aussi rapide que le porteur (sinon x min(1, sa vitesse / celle du porteur))."""
        return min(max(carry["by_rarity"][rarity_index - 1], carry["min"]), carry["max"])

    creatures = []
    for spec in ART_SPECS:
        pet = by_id[spec["id"]]
        rarity = rarity_by_id[pet["rarity"]]
        band = bands[pet["rarity"]]
        size = heights.get(pet["id"], (band[0] + band[1]) / 2)
        weight = size ** 3  # indicatif : ne sert plus au transport depuis le 25 oct.
        start = strong = carry_speed(rarities.index(rarity) + 1)
        drop = rarity["weight"] / total_weight / base_count[pet["rarity"]]
        entry = {
            "id": pet["id"], "name": pet["name"], "tier": spec["tier"], "game_rarity": pet["rarity"],
            "rarity_color": rarity["color"],
            "stats": {
                "size_player_heights": round(size, 2),
                "height_studs": round(size * player, 2),
                "weight": round(weight, 3),
                "carry_speed_pct_at_start": round(start * 100, 1),
                "walk_speed_penalty_pct_at_start": round((1 - start) * 100, 1),
                "carry_walkspeed_at_start": round(walk_speed * start, 1),
                "carry_speed_pct_max_strength": round(strong * 100, 1),
                "income_per_sec": int(rarity["income"] * (1 + (rank[pet["id"]] - 1) * 0.15)),
                "drop_rate_pct": round(drop * 100, 4),
                "drop_one_in": round(1 / drop),
            },
            "spec_3d": {k: v for k, v in spec.items() if k not in ("id", "tier")},
        }
        entry["spec_3d"]["studs"] = "tenons cuits dans la NormalMap (shader_node_library.add_stud_bump), pas de TextureID"
        entry["spec_3d"]["forbidden"] = ["primitive brute (cube/sphère par défaut)", "matériau Neon pour le volume",
                                         "arête vive sans chanfrein"]
        creatures.append(entry)

    matrix = {
        "meta": {
            "title": "Get Rich Or Get Robbed - matrice game design + direction 3D (phase 1 du pipeline)",
            "generated": date.today().isoformat(),
            "generator": "dataset_and_pipeline/tools/build_game_design_matrix.py",
            "stats_source": "calculées depuis src/shared/Config.lua, PetCatalog.lua, PetSizes.lua (mêmes formules que le serveur)",
            "ip_rule": "Les 20 familiers sont ceux du jeu (créations originales). Aucun nom, personnage, son ou modèle "
                       "des jeux de référence : on n'en garde que des ordres de grandeur et des principes.",
            "drop_rate_note": "chance par tirage gratuit, monde Prairie, familier déjà découvert (x5 s'il est nouveau : "
                              "Config.Loot.NewPetWeight), hors exclusifs des mondes",
            "carry_note": "vitesse de transport = Config.Carry.SpeedByRarity[rareté] x min(1, vitesse du propriétaire / "
                          "vitesse du porteur) (25 oct., ECONOMY_REPORT.md règle 5) : la Force ne compte plus, d'où "
                          "carry_speed_pct_at_start = carry_speed_pct_max_strength ; « weight » (taille^3) est indicatif ; "
                          f"WalkSpeed de base {walk_speed:.0f}, force de départ {strength_base:.0f}, force max {strength_max:.0f}",
        },
        "research_benchmarks": BENCHMARKS,
        "design_principles": DESIGN_PRINCIPLES,
        "tiers": TIERS,
        "game_rarities": [{"id": r["id"], "name": r["name"], "color": r["color"], "draw_chance_pct": round(r["weight"] / total_weight * 100, 3),
                           "base_income_per_sec": r["income"], "base_pets": base_count.get(r["id"], 0)} for r in rarities],
        "creatures": creatures,
        "egg_shells": EGG_SHELLS,
        "core_loop": core_loop(config, walk_speed),
        "material_presets": {
            "create_stylized_edge_wear_material": "peint à la main : arêtes éclaircies (Bevel + Pointiness), creux assombris (AO), "
                                                  "taches Noise ; option craquelures Voronoi (céramique)",
            "create_etched_metal_or_gold": "métal / or : micro-rayures Voronoi + Noise étirés dans Roughness et Bump, martelé "
                                           "(Voronoi SMOOTH_F1), anisotropie pour le rendu Blender, usure claire des arêtes",
            "create_organic_scales_or_skin": "peau / écailles : cellules Voronoi, variations de teinte, SSS léger, relief organique",
            "create_stylized_crystal_or_gem": "cristal : dégradé interne par la position et la courbure (cuisible) + Fresnel "
                                              "Layer Weight (rendu Blender seulement), facettes plates, cœur émissif en option",
        },
    }
    OUT.write_text(json.dumps(matrix, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"OK {OUT.relative_to(ROOT)} : {len(creatures)} familiers, {len(EGG_SHELLS)} coquilles")


def core_loop(config: str, walk_speed: float) -> dict:
    def num(pattern: str, block: str | None = None) -> float:
        return parse_number(config_block(config, block) if block else config, pattern)

    return {
        "_lecture": "« game » = valeur actuelle du jeu (Config.lua) ; « proposed » = mécanique absente des jeux de "
                    "référence comme du jeu, chiffrée pour la phase 2 si on la veut.",
        "phases": {"game": {"feeding_s": num(r"Feeding = (\d+), -- trou noir ouvert"), "digesting_s": num(r"Digesting = (\d+), -- trou noir fermé")}},
        "income": {"game": "revenu/s = Income(rareté) x (1 + 0,15 x (rang - 1)) x évolution (x3 / x8) x mutation (x2 / x5 / x10) "
                            "x monde (1 à 16) x (1 + rebirths) ; seuls les 15 meilleurs de la base rapportent (+1 par rebirth, max +5)"},
        "steal": {
            "game": {"hold_e_s": num(r"HoldDuration = ([\d.]+)", "Steal"), "prompt_distance_studs": num(r"PromptDistance = (\d+)", "Steal"),
                     "max_carry_time_s": num(r"MaxCarryTime = (\d+), -- secondes"), "walk_home_speed": num(r"WalkHomeSpeed = (\d+)"),
                     "drop_on_hit": True},
            "carry_formula": "speed = SpeedByRarity[rareté] x min(1, vitesse du propriétaire / vitesse du porteur) ; "
                             "SpeedByRarity = 0,95 x 0,876^(rang - 1) (Commun 0,95 -> Sigma 0,38)",
        },
        "base_defense": {
            "game": {"lock_s": num(r"Duration = (\d+)", "Lock"),
                     "long_lock_s": num(r"Duration = (\d+)", "Lock") + num(r"LongBonus = (\d+)", "Lock"),
                     "cycle_s": num(r"Cycle = (\d+)", "Lock"), "min_open_s": num(r"MinOpen = (\d+)", "Lock"),
                     "lock_effect": "portail qui expulse les intrus ; un passage sur le bouton ferme la base, puis le bouton "
                                    "reste grisé jusqu'à la fin du cycle (une fermeture par manche, 25 oct.)",
                     "shield": "bouclier : 10 % de la valeur de la base perdus en 1 h -> 30 min sans vol (Config.StealShield)"},
            "reference": "Steal a Brainrot : verrou laser 60 s",
            "proposed_lasers": {
                "_status": "proposed",
                "description": "barrières laser à l'entrée de la base pendant le verrou : traverser = knockback + lâcher le familier",
                "width_studs": 18, "beam_count": 5, "beam_spacing_studs": 1.6, "knockback_impulse": 90,
                "visual": "faisceaux fins (Beam), pas de bloc Néon ; émetteurs = piliers baked (piédestal PoC)",
            },
        },
        "guardians_npc": {
            "_status": "proposed",
            "description": "gardien PNJ optionnel par base (achetable), qui poursuit un voleur porteur d'un familier",
            "aggro_radius_studs": 28, "leash_radius_studs": 60, "lose_sight_s": 3.0,
            "chase_speed": round(walk_speed * 1.1, 1), "chase_speed_note": "x1,1 la WalkSpeed de base : rattrape un voleur chargé "
            "(<= 95 %), jamais un joueur libre entraîné",
            "attack": "1 coup = le voleur lâche le familier (même règle que la batte)", "cooldown_s": 8,
        },
        "rebirth": {
            "game": {"required_world": int(num(r"RequiredTier = (\d+)", "Rebirth")), "base_price": num(r"BasePrice = ([\d.e]+)", "Rebirth"),
                     "price_growth": num(r"PriceGrowth = ([\d.]+)", "Rebirth"), "income_bonus_per_rebirth": num(r"IncomeBonus = ([\d.]+)", "Rebirth"),
                     "formula": "prix(n) = 4e12 x 2,7^n ; revenu x (1 + n) ; +1 familier dans la base par rebirth (max 5)"},
            "reference": "Steal a Brainrot : argent + personnages précis exigés à chaque rebirth",
        },
        "base_structure": {
            "game": {"size_studs": [84, 84], "income_slots": int(num(r"IncomeSlots = (\d+)")), "nests": 12,
                     "layout": "entrée + bouton de verrou, 2 palettes à l'avant, prairie où les familiers se baladent, "
                               "couveuse au fond (12 nids), capsule d'évolution derrière (shared/BaseLayout)"},
            "pedestal_spec": {
                "use": "socle d'exposition (vitrine du meilleur familier, plaque de verrou, émetteur de laser)",
                "footprint_studs": [6, 6], "height_studs": 2.5,
                "silhouette": "base octogonale à 3 marches chanfreinées, colonne courte, plateau à liseré d'or, 4 cristaux d'angle",
                "materials": ["pierre peinte : create_stylized_edge_wear_material", "liseré : create_etched_metal_or_gold",
                              "cristaux : create_stylized_crystal_or_gem"],
                "poc": "construit par run_poc.py (build_stylized_pedestal)",
            },
            "drop_zone": {"game": "le familier volé est posé en entrant dans sa propre base (StealController)"},
        },
    }


if __name__ == "__main__":
    main()
