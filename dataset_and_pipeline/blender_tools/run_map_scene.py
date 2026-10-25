"""Scène de contrôle de la carte (phase 1.6) : la carte du jeu habillée avec les décors cuits, rendue dans Blender.

    blender.exe -b --factory-startup --python dataset_and_pipeline/blender_tools/run_map_scene.py -- [options]

Prérequis : run_map_assets.py --world <monde> (décors cuits = ce que Roblox affichera).
Options : --world Prairie|Desert  --samples 64  --hero-res 1600  --tile-res 800  --views hero,aerien,...|none
          --no-layout
Chaque monde (WORLD_CFG) choisit ses décors pour chaque rôle (dalle du sanctuaire, porte des chemins, clôture des
bases, falaise, arbres...), ses couleurs de sol et sa lumière ; le placement (positions, règles de jeu) est commun.
Autres mondes que la Prairie : sorties suffixées (_desert...), placement dans baked_assets/map/<monde>/.
Sorties : qa_renders/map_hero.png (depuis la base 1, face à l'arène), qa_renders/map_aesthetic_board.png
          (6 vues : survol, entrée de base, entrée de l'arène, colline, nuit, depuis le trou),
          baked_assets/map/map_layout.json (positions en coordonnées Roblox pour studio_tools/apply_map_look.lua),
          source/map_scene.blend.

Dimensions = celles du jeu (src/shared/Config.lua, Config.Arena) : sol de rayon 315, trou noir de rayon 40,
8 bases de 84 x 84 à 215 du centre, kiosques entre les bases (angles 22,5° + k x 90°), tableau des scores à 67,5°.
Repère : Blender (x, y, z) = Roblox (x, -z, y) ; un angle Roblox a devient -a dans Blender.

Post-traitement (numpy) = les réglages Roblox de map_art_bible.json : Atmosphere (brume selon la distance, rendu
d'une passe de profondeur), Bloom (seuil, taille, intensité), ColorCorrection (saturation, contraste), exposition.
"""

from __future__ import annotations

import argparse
import importlib
import json
import math
import random
import sys
import time
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import shader_node_library as S  # noqa: E402
import procedural_geometry_recipes as G  # noqa: E402
import visual_qa_renderer as Q  # noqa: E402
import environment_recipes as E  # noqa: E402

for m in (S, G, Q, E):
    importlib.reload(m)

ROOT = HERE.parent
QA = ROOT / "qa_renders"

# --- Config.Arena -----------------------------------------------------------------------------------------------
FLOOR_R, HOLE_R, DOME_R = 315.0, 40.0, 55.0
BASE_COUNT, BASE_RING, BASE_HALF = 8, 215.0, 42.0
WALL_H, WALL_T = 36.0, 10.0
PATH_W = 16.0
WILD = (70.0, 160.0)
STEP = 2 * math.pi / BASE_COUNT
KIOSK_ROBLOX_DEG = [22.5 + 90 * k for k in range(4)]
LEADERBOARD_ROBLOX_DEG = 67.5

# Préréglages = map_art_bible.json -> atmosphere.presets (Prairie) ; map_art_bible_<monde>.json pour les autres
PRAIRIE_LOOKS = {
    "jour": {"sun": 4.2, "sun_color": (1.0, 0.94, 0.84), "sun_elev": 50, "sun_az": 205, "sky_top": "#3E9BFF",
             "sky_horizon": "#D2EAFF", "sky_strength": 1.0, "fog": "#CFE2FF", "fog_density": 0.0005,
             "fog_start": 180, "fog_max": 0.4, "bloom": (1.6, 0.45, 22), "saturation": 0.18, "contrast": 0.08,
             "exposure": 0.05},
    "nuit": {"sun": 1.5, "sun_color": (0.62, 0.72, 1.0), "sun_elev": 38, "sun_az": 120, "sky_top": "#141C52",
             "sky_horizon": "#5A6AC0", "sky_strength": 1.6, "fog": "#4A5698", "fog_density": 0.001,
             "fog_start": 100, "fog_max": 0.6, "bloom": (1.3, 0.6, 26), "saturation": 0.22, "contrast": 0.1,
             "exposure": 0.9},
}

DESERT_LOOKS = {
    "jour": {"sun": 4.6, "sun_color": (1.0, 0.88, 0.72), "sun_elev": 40, "sun_az": 222, "sky_top": "#2E8CE6",
             "sky_horizon": "#FFE6C0", "sky_strength": 1.0, "fog": "#FFE0B0", "fog_density": 0.0007,
             "fog_start": 150, "fog_max": 0.45, "bloom": (1.6, 0.45, 22), "saturation": 0.2, "contrast": 0.1,
             "exposure": 0.0},
    "nuit": {"sun": 1.4, "sun_color": (0.66, 0.70, 1.0), "sun_elev": 36, "sun_az": 120, "sky_top": "#121A4E",
             "sky_horizon": "#6A5AB0", "sky_strength": 1.6, "fog": "#56508E", "fog_density": 0.001,
             "fog_start": 100, "fog_max": 0.55, "bloom": (1.3, 0.6, 26), "saturation": 0.22, "contrast": 0.1,
             "exposure": 0.9},
}

VOLCAN_LOOKS = {
    "jour": {"sun": 3.6, "sun_color": (1.0, 0.72, 0.52), "sun_elev": 32, "sun_az": 230, "sky_top": "#5A6E9E",
             "sky_horizon": "#FF9A64", "sky_strength": 0.9, "fog": "#C8704E", "fog_density": 0.0008,
             "fog_start": 110, "fog_max": 0.45, "bloom": (1.4, 0.55, 24), "saturation": 0.25, "contrast": 0.12,
             "exposure": 0.1},
    "nuit": {"sun": 0.9, "sun_color": (0.9, 0.55, 0.5), "sun_elev": 30, "sun_az": 120, "sky_top": "#140A16",
             "sky_horizon": "#6A2420", "sky_strength": 1.4, "fog": "#3A1A1E", "fog_density": 0.0012,
             "fog_start": 80, "fog_max": 0.6, "bloom": (1.2, 0.7, 28), "saturation": 0.25, "contrast": 0.12,
             "exposure": 0.8},
}

GLACE_LOOKS = {
    # soleil moins fort et exposition plus basse : la neige garde son détail (map_art_bible_glace.json)
    "jour": {"sun": 3.6, "sun_color": (1.0, 0.97, 0.93), "sun_elev": 35, "sun_az": 210, "sky_top": "#5AA8F0",
             "sky_horizon": "#E8F4FF", "sky_strength": 0.9, "fog": "#E0EEFF", "fog_density": 0.0007,
             "fog_start": 130, "fog_max": 0.4, "bloom": (1.6, 0.4, 22), "saturation": 0.24, "contrast": 0.16,
             "exposure": -0.2},
    "nuit": {"sun": 1.3, "sun_color": (0.62, 0.74, 1.0), "sun_elev": 36, "sun_az": 120, "sky_top": "#08142E",
             "sky_horizon": "#1E5A6E", "sky_strength": 1.4, "fog": "#2A3A6A", "fog_density": 0.001,
             "fog_start": 100, "fog_max": 0.55, "bloom": (1.3, 0.6, 26), "saturation": 0.2, "contrast": 0.1,
             "exposure": 0.7},
}

ABYSSES_LOOKS = {
    # sous l'eau : lumière qui tombe d'en haut, brume turquoise dense (map_art_bible_abysses.json)
    "jour": {"sun": 3.2, "sun_color": (0.78, 0.96, 1.0), "sun_elev": 58, "sun_az": 200, "sky_top": "#08345E",
             "sky_horizon": "#2AA6C8", "sky_strength": 0.9, "fog": "#2384A4", "fog_density": 0.0011,
             "fog_start": 90, "fog_max": 0.5, "bloom": (1.4, 0.5, 24), "saturation": 0.32, "contrast": 0.16,
             "exposure": 0.3},
    "nuit": {"sun": 0.9, "sun_color": (0.42, 0.62, 1.0), "sun_elev": 50, "sun_az": 120, "sky_top": "#020A1E",
             "sky_horizon": "#0E3A5A", "sky_strength": 1.2, "fog": "#0A2A44", "fog_density": 0.0015,
             "fog_start": 60, "fog_max": 0.7, "bloom": (1.2, 0.7, 28), "saturation": 0.22, "contrast": 0.12,
             "exposure": 0.95},
}

COSMOS_LOOKS = {
    # espace : ciel violet profond, nébuleuse rose à l'horizon, air peu dense, lumière froide (map_art_bible_cosmos.json)
    "jour": {"sun": 3.6, "sun_color": (0.94, 0.94, 1.0), "sun_elev": 48, "sun_az": 200, "sky_top": "#2A1660",
             "sky_horizon": "#9A6AD8", "sky_strength": 1.0, "fog": "#7A5AB8", "fog_density": 0.0008,
             "fog_start": 120, "fog_max": 0.42, "bloom": (1.3, 0.6, 26), "saturation": 0.28, "contrast": 0.15,
             "exposure": 0.45},
    "nuit": {"sun": 1.0, "sun_color": (0.62, 0.6, 1.0), "sun_elev": 50, "sun_az": 120, "sky_top": "#06031A",
             "sky_horizon": "#2A1658", "sky_strength": 1.2, "fog": "#1A0E3A", "fog_density": 0.0012,
             "fog_start": 80, "fog_max": 0.6, "bloom": (1.2, 0.7, 28), "saturation": 0.25, "contrast": 0.12,
             "exposure": 0.95},
}

DIVIN_LOOKS = {
    # au-dessus des nuages : soleil éclatant, horizon doré, air léger ; scène très claire, exposition retenue
    # (map_art_bible_divin.json)
    "jour": {"sun": 3.2, "sun_color": (1.0, 0.95, 0.84), "sun_elev": 46, "sun_az": 200, "sky_top": "#3A8AE0",
             "sky_horizon": "#FFE0A0", "sky_strength": 1.0, "fog": "#F2EEE6", "fog_density": 0.0007,
             "fog_start": 140, "fog_max": 0.3, "bloom": (0.9, 0.7, 24), "saturation": 0.24, "contrast": 0.22,
             "exposure": -0.45},
    "nuit": {"sun": 1.0, "sun_color": (0.72, 0.76, 1.0), "sun_elev": 50, "sun_az": 120, "sky_top": "#0A1430",
             "sky_horizon": "#3A4A7A", "sky_strength": 1.2, "fog": "#2A3458", "fog_density": 0.0012,
             "fog_start": 80, "fog_max": 0.6, "bloom": (1.2, 0.7, 28), "saturation": 0.18, "contrast": 0.12,
             "exposure": 0.8},
}

# Rôle -> décor, couleurs du sol et lumière de chaque monde. Le code de placement ne connaît que les rôles.
WORLD_CFG = {
    "Prairie": {
        "lib": [("Prairie", None)], "suffix": "", "looks": PRAIRIE_LOOKS, "clouds": 16, "water": "stream",
        "slab": "DalleRunique", "gate": "ArcheAncienne", "flank": "TotemEnergie",
        "between": ("RocherObsidienne_A", "RocherObsidienne_B"), "between_z": -0.3,
        "tuft": "TouffeHerbe", "path_small": ("ChampignonGeant", 0.3, 0.42), "sign": "Pancarte",
        "fence": "Palissade", "stairs": "EscalierPierre", "base_gate": "ArcheAncienne",
        "prop_a": "Caisse", "prop_b": "Tonneau", "hill": "FalaiseGradins",
        "hill_trees": ("ArbreCerisier", ("ArbreMajestueux_A", "ArbreMajestueux_B")),
        "gap_trees": ("ArbreMajestueux_A", "ArbreMajestueux_B", "ArbreCerisier", "ChampignonGeant"),
        "rocks": ("RocherCalcaire_A", "RocherCalcaire_B", "RocherCalcaire_C"), "ruin": "MurRuine",
        "landmark": ("ChampignonGeant",), "bank_rock": "RocherCalcaire_B", "bridge": "PontBois",
        "cliff": "FalaiseGradins", "cliff_trees": ("ArbreCerisier", ("ArbreMajestueux_A", "ArbreMajestueux_B")),
        "far": ("RocherCalcaire_C", "RocherCalcaire_B"), "far_spire": "RocherObsidienne_A",
        "far_scale": ((9, 14), (9, 14), (9, 16)),
        "pets": (("CapybaraZen", -14, -2, 6.0), ("RenardFurtif", 10, 6, 6.5), ("Kitsune3Queues", -2, 12, 8.5),
                 ("ChatRuelle", 18, -12, 5.0), ("PegaseNuageux", -24, 8, 9.0)),
        "colors": {"sol": ("#98E634", "#7FD52C", "#B8E64A", "#A2D83C"), "chemin": ("#F6D680", "#E8C268"),
                   "base_sol": ("#A8E04A", "#8FCF38"), "paille": ("#F2CF6B", "#E4BC52"), "dalle": ("#D8D2C4", "#C6BFB0"),
                   "mur": ("#CA9156", "#B97D49"), "mur_haut": ("#6EDC2A", "#5CCB22"), "loin": "#79C83A"},
    },
    "Desert": {
        # Caisse et Pancarte sont reprises de la Prairie (déjà dans ArtModels.Map)
        "lib": [("Desert", None), ("Prairie", ["Caisse", "Pancarte"])], "suffix": "_desert", "looks": DESERT_LOOKS,
        "clouds": 5, "water": "oasis",
        "slab": "Desert_Dalle", "gate": "Desert_PorteTemple", "flank": "Desert_Obelisque",
        "between": ("Desert_ColonneBrisee", "Desert_ColonneBrisee"), "between_z": -0.2,
        "tuft": "Desert_Touffe", "path_small": ("Desert_CactusTonneau", 0.7, 1.0), "sign": "Pancarte",
        "fence": "Desert_Muret", "stairs": "Desert_Escalier", "base_gate": "Desert_PorteTemple",
        "prop_a": "Caisse", "prop_b": "Desert_Jarre", "hill": "Desert_Mesa",
        "hill_trees": ("Desert_Figuier", ("Desert_Saguaro", "Desert_Saguaro")),
        "gap_trees": ("Desert_Saguaro", "Desert_Palmier", "Desert_Figuier", "Desert_RocherGres_A"),
        "rocks": ("Desert_RocherGres_B", "Desert_RocherGres_A", "Desert_RocherGres_B"), "ruin": "Desert_ColonneBrisee",
        "landmark": ("Desert_ArcheNaturelle", "Desert_Fossile", "Desert_RocherGres_A", "Desert_Auvent"),
        "bank_rock": "Desert_RocherGres_B", "bridge": None,
        "cliff": "Desert_Mesa", "cliff_trees": ("Desert_Palmier", ("Desert_Saguaro", "Desert_Saguaro")),
        "far": ("Desert_Mesa", "Desert_RocherGres_B"), "far_spire": "Desert_RocherGres_A",
        "far_scale": ((2.4, 3.6), (2.0, 2.8), (2.2, 3.4)),  # la mesa fait déjà 36 x 15 x 30 studs
        "pets": (("CactusRonchon", -14, -2, 6.0), ("RenardFurtif", 10, 6, 6.5), ("TRexPoche", -2, 12, 8.5),
                 ("ChatRuelle", 18, -12, 5.0), ("CapybaraZen", -24, 8, 6.0)),
        "colors": {"sol": ("#FAD682", "#EEC46A", "#F6C67A", "#ECB866"), "chemin": ("#D6965A", "#C4844C"),
                   "base_sol": ("#F4D07E", "#E8BE66"), "paille": ("#F2CF6B", "#E4BC52"), "dalle": ("#E6CFA4", "#D8BE90"),
                   "mur": ("#E2A05C", "#CE8C4E"), "mur_haut": ("#FADC8C", "#F0CC78"), "loin": "#E8B670"},
    },
    "Volcan": {
        # Pancarte reprise de la Prairie ; chemins et haut du mur en Neon dans le jeu (glow ici)
        "lib": [("Volcan", None), ("Prairie", ["Pancarte"])], "suffix": "_volcan", "looks": VOLCAN_LOOKS,
        "clouds": 4, "cloud": "#8A7A7E", "water": "lava",
        "slab": "Volcan_Dalle", "gate": "Volcan_PorteForge", "flank": "Volcan_PilierBrasier",
        "between": ("Volcan_Enclume", "Volcan_Eclats"), "between_z": -0.2,
        "tuft": "Volcan_Touffe", "path_small": ("Volcan_Cristaux", 0.5, 0.75), "sign": "Pancarte",
        "fence": "Volcan_Rempart", "stairs": "Volcan_Escalier", "base_gate": "Volcan_PorteForge",
        "prop_a": "Volcan_Chariot", "prop_b": "Volcan_Chaudron", "hill": "Volcan_Orgues",
        "hill_trees": ("Volcan_Cristaux", ("Volcan_ArbreCalcine", "Volcan_ArbreCalcine")),
        "gap_trees": ("Volcan_ArbreCalcine", "Volcan_Cheminee", "Volcan_Cristaux", "Volcan_Eclats"),
        "rocks": ("Volcan_Roche", "Volcan_Eclats", "Volcan_Roche"), "ruin": "Volcan_Cheminee",
        "landmark": ("Volcan_TeteGolem", "Volcan_Grill", "Volcan_Cheminee", "Volcan_Eclats"),
        "bank_rock": "Volcan_Roche", "bridge": None,
        "cliff": "Volcan_Orgues", "cliff_trees": ("Volcan_Cheminee", ("Volcan_ArbreCalcine", "Volcan_ArbreCalcine")),
        "far": ("Volcan_Cheminee", "Volcan_Cheminee"), "far_spire": "Volcan_Eclats",
        "far_scale": ((18.0, 26.0), (18.0, 26.0), (30.0, 40.0)),
        "cliff_alt": ("Volcan_Eclats", (3.6, 3.6, 5.2)),  # cheminées géantes = cônes de volcan de 140-180 studs
        "pets": (("DragonnetObsidienne", -14, -2, 7.0), ("PhenixCendres", 10, 6, 7.5), ("CerbereChiot", -2, 12, 6.5),
                 ("TRexPoche", 18, -12, 7.0), ("RenardFurtif", -24, 8, 6.0)),
        "colors": {"sol": ("#463C40", "#362E32", "#4E4044", "#3E3236"), "chemin": ("#FF781E", "#F0501E"),
                   "base_sol": ("#4E4448", "#3E3438"), "paille": ("#6A5040", "#5A4434"), "dalle": ("#5A5256", "#4A4246"),
                   "mur": ("#3C3238", "#2E262A"), "mur_haut": ("#FF641E", "#F0501E"), "loin": "#2A2226"},
        "glow": {"chemin": 2.2, "mur_haut": 2.2},
    },
    "Glace": {
        "lib": [("Glace", None), ("Prairie", ["Pancarte"])], "suffix": "_glace", "looks": GLACE_LOOKS,
        "clouds": 14, "water": "ice",
        "slab": "Glace_Dalle", "gate": "Glace_PorteGlace", "flank": "Glace_Lanterne",
        "between": ("Glace_Pic", "Glace_Cristaux"), "between_z": -0.2,
        "tuft": "Glace_Touffe", "path_small": ("Glace_Congere", 0.5, 0.8), "sign": "Pancarte",
        "fence": "Glace_Barriere", "stairs": "Glace_Escalier", "base_gate": "Glace_PorteGlace",
        "prop_a": "Glace_Traineau", "prop_b": "Glace_Bonhomme", "hill": "Glace_Glacier",
        "hill_trees": ("Glace_SapinPetit", ("Glace_Sapin", "Glace_Sapin")),
        "gap_trees": ("Glace_Sapin", "Glace_SapinPetit", "Glace_Sapin", "Glace_Igloo"),
        "rocks": ("Glace_Rocher", "Glace_Congere", "Glace_Rocher"), "ruin": "Glace_Igloo",
        "landmark": ("Glace_BlocMammouth", "Glace_Igloo", "Glace_Bonhomme", "Glace_Pic"),
        "bank_rock": "Glace_Rocher", "bridge": None,
        "cliff": "Glace_Glacier", "cliff_trees": ("Glace_SapinPetit", ("Glace_Sapin", "Glace_Sapin")),
        "far": ("Glace_Pic", "Glace_Pic"), "far_spire": "Glace_Pic",
        "far_scale": ((9.0, 13.0), (9.0, 13.0), (12.0, 16.0)),  # pics de glace géants (170-220 studs) au loin
        "cliff_alt": ("Glace_Pic", (3.4, 3.4, 4.6)),
        "pets": (("YetiCalin", -14, -2, 9.0), ("PingouinPatineur", 10, 6, 5.0), ("MorseMoustachu", -2, 12, 7.5),
                 ("MammouthGlacon", 18, -12, 9.5), ("LoupPolaire", -24, 8, 6.5)),
        "colors": {"sol": ("#F0F8FF", "#D6EAFA", "#E6F2FC", "#CCE2F4"), "chemin": ("#96D2F5", "#7CBEEB"),
                   "base_sol": ("#E8F4FC", "#D0E6F6"), "paille": ("#C8B08A", "#B89C74"), "dalle": ("#D8E8F4", "#C8DCEC"),
                   "mur": ("#AAD7F5", "#92C4EC"), "mur_haut": ("#FFFFFF", "#F0F8FF"), "loin": "#E8F2FA"},
    },
    "Abysses": {
        "lib": [("Abysses", None), ("Prairie", ["Pancarte"])], "suffix": "_abysses", "looks": ABYSSES_LOOKS,
        "clouds": 0, "water": "trench",
        "slab": "Abysses_Dalle", "gate": "Abysses_PorteAtlante", "flank": "Abysses_PilierPerle",
        "between": ("Abysses_ColonneEngloutie", "Abysses_Coquillage"), "between_z": -0.2,
        "tuft": "Abysses_Touffe", "path_small": ("Abysses_Anemone", 0.45, 0.65), "sign": "Pancarte",
        "fence": "Abysses_Muret", "stairs": "Abysses_Escalier", "base_gate": "Abysses_PorteAtlante",
        "prop_a": "Abysses_Coffre", "prop_b": "Abysses_Ancre", "hill": "Abysses_Recif",
        "hill_trees": ("Abysses_CorailEventail", ("Abysses_Corail", "Abysses_Algue")),
        "gap_trees": ("Abysses_Algue", "Abysses_Corail", "Abysses_CorailEventail", "Abysses_Algue"),
        "rocks": ("Abysses_Rocher", "Abysses_Anemone", "Abysses_Rocher"), "ruin": "Abysses_ColonneEngloutie",
        "landmark": ("Abysses_Epave", "Abysses_Coquillage", "Abysses_Corail", "Abysses_Coffre"),
        "bank_rock": "Abysses_Rocher", "bridge": None,
        "cliff": "Abysses_Recif", "cliff_trees": ("Abysses_CorailEventail", ("Abysses_Algue", "Abysses_Corail")),
        "far": ("Abysses_Algue", "Abysses_Rocher"), "far_spire": "Abysses_Algue",
        # algues géantes (100-150 studs) et monts sous-marins arrondis qui se perdent dans l'eau
        "far_scale": ((5.0, 7.0), (5.0, 7.0), (7.0, 10.0)),
        "cliff_alt": ("Abysses_Corail", (10.0, 10.0, 14.0)),  # coraux géants (~85 studs) : cassent la ligne des récifs
        "cliff_tree_scale": 1.8,  # forêts d'algues sur les récifs, lisibles depuis l'arène
        "pets": (("PieuvrePirate", -14, -2, 7.0), ("MeduseLampion", 10, 6, 6.0), ("RoiCorail", -2, 12, 8.0),
                 ("CalmarColosse", 18, -12, 9.0), ("LanterneDisco", -24, 8, 5.5)),
        "colors": {"sol": ("#286E82", "#1E5C72", "#2E7A8A", "#24687A"), "chemin": ("#E6D296", "#D2BE82"),
                   "base_sol": ("#2E7A8E", "#22667A"), "paille": ("#C8B07A", "#B89C68"), "dalle": ("#4A8A96", "#3A7A86"),
                   "mur": ("#14466E", "#0E385E"), "mur_haut": ("#3CDCB4", "#30C8A0"), "loin": "#103A52"},
        "glow": {"mur_haut": 1.8},
    },
    "Cosmos": {
        "lib": [("Cosmos", None), ("Prairie", ["Pancarte"])], "suffix": "_cosmos", "looks": COSMOS_LOOKS,
        "clouds": 0, "water": "stardust",
        "slab": "Cosmos_Dalle", "gate": "Cosmos_PorteStellaire", "flank": "Cosmos_Pylone",
        "between": ("Cosmos_Meteorite", "Cosmos_Planete"), "between_z": -0.2,
        "tuft": "Cosmos_Touffe", "path_small": ("Cosmos_Cristaux", 0.4, 0.6), "sign": "Pancarte",
        "fence": "Cosmos_Barriere", "stairs": "Cosmos_Escalier", "base_gate": "Cosmos_PorteStellaire",
        "prop_a": "Cosmos_Caisse", "prop_b": "Cosmos_Satellite", "hill": "Cosmos_Falaise",
        "hill_trees": ("Cosmos_Aiguille", ("Cosmos_ArbreAlien", "Cosmos_Champignon")),
        "gap_trees": ("Cosmos_ArbreAlien", "Cosmos_Champignon", "Cosmos_ArbreAlien", "Cosmos_Cristaux"),
        "rocks": ("Cosmos_Rocher", "Cosmos_Meteorite", "Cosmos_Rocher"), "ruin": "Cosmos_Satellite",
        "landmark": ("Cosmos_Fusee", "Cosmos_Planete", "Cosmos_Aiguille", "Cosmos_Satellite"),
        "bank_rock": "Cosmos_Rocher", "bridge": None,
        "cliff": "Cosmos_Falaise", "cliff_trees": ("Cosmos_Aiguille", ("Cosmos_ArbreAlien", "Cosmos_Cristaux")),
        "cliff_tree_scale": 1.3,
        # aiguilles de cristal géantes et astéroïdes arrondis qui se perdent dans la nébuleuse
        "far": ("Cosmos_Aiguille", "Cosmos_Rocher"), "far_spire": "Cosmos_Aiguille",
        "far_scale": ((6.0, 9.0), (6.0, 9.0), (7.0, 11.0)),
        "cliff_alt": ("Cosmos_Aiguille", (3.6, 3.6, 6.2)),  # aiguilles de cristal (~95 studs) : cassent la ligne des falaises
        "pets": (("AstroHamster", -14, -2, 6.0), ("ChatComete", 10, 6, 7.0), ("AlienGelatine", -2, 12, 6.5),
                 ("LionNebuleuse", 18, -12, 9.0), ("TrouNoirPoche", -24, 8, 6.0)),
        "colors": {"sol": ("#382260", "#2A184E", "#3E2868", "#301C58"), "chemin": ("#78DCFF", "#5ABEFF"),
                   "base_sol": ("#3E2A6A", "#2E1E58"), "paille": ("#9A94BC", "#8A84AC"), "dalle": ("#6E62A0", "#5E5290"),
                   "mur": ("#462878", "#361E64"), "mur_haut": ("#FF78F0", "#F060E0"), "loin": "#241446"},
        "glow": {"chemin": 2.0, "mur_haut": 2.0},
    },
    "Divin": {
        "lib": [("Divin", None), ("Prairie", ["Pancarte"])], "suffix": "_divin", "looks": DIVIN_LOOKS,
        "clouds": 10, "cloud": "#FFFFFF", "water": "spring",
        "slab": "Divin_Dalle", "gate": "Divin_PorteCeleste", "flank": "Divin_Vasque",
        "between": ("Divin_Colonne", "Divin_Statue"), "between_z": -0.2,
        "tuft": "Divin_Touffe", "path_small": ("Divin_Buisson", 0.35, 0.5), "sign": "Pancarte",
        "fence": "Divin_Balustrade", "stairs": "Divin_Escalier", "base_gate": "Divin_PorteCeleste",
        "prop_a": "Divin_Harpe", "prop_b": "Divin_Buisson", "hill": "Divin_Falaise",
        "hill_trees": ("Divin_Statue", ("Divin_ArbreDore", "Divin_Buisson")),
        "gap_trees": ("Divin_ArbreDore", "Divin_Nuage", "Divin_ArbreDore", "Divin_Buisson"),
        "rocks": ("Divin_Rocher", "Divin_Nuage", "Divin_Rocher"), "ruin": "Divin_Colonne",
        "landmark": ("Divin_Temple", "Divin_Fontaine", "Divin_Harpe", "Divin_Temple"),
        "bank_rock": "Divin_Rocher", "bridge": None,
        "cliff": "Divin_Falaise", "cliff_trees": ("Divin_Statue", ("Divin_ArbreDore", "Divin_Nuage")),
        "cliff_tree_scale": 1.3,
        # mer de nuages et tours géantes de la cité céleste au loin
        "far": ("Divin_Nuage", "Divin_Nuage"), "far_spire": "Divin_Tour",
        "far_scale": ((7.0, 11.0), (7.0, 11.0), (5.0, 8.0)),
        "cliff_alt": ("Divin_Tour", (2.6, 2.6, 4.4)),  # tours à coupole d'or (~90 studs) : la ligne des falaises devient une cité
        "pets": (("CherubinHamster", -14, -2, 5.5), ("LicorneCeleste", 10, 6, 7.5), ("GriffonDore", -2, 12, 8.0),
                 ("TitanAureole", 18, -12, 9.0), ("GardienTrouNoir", -24, 8, 9.0)),
        "colors": {"sol": ("#FFFCF0", "#F4ECD6", "#FAF4E2", "#EEE4CC"), "chemin": ("#FFD65A", "#F0BE3C"),
                   "base_sol": ("#FAF2DC", "#EEE2C4"), "paille": ("#E8D8A8", "#D8C890"), "dalle": ("#F2E8D0", "#E2D6BA"),
                   "mur": ("#FAF4E6", "#ECE2CC"), "mur_haut": ("#FFCD3C", "#F0BE30"), "loin": "#FFF4DC"},
        "glow": {"mur_haut": 1.6},
    },
}
W: dict = WORLD_CFG["Prairie"]
LOOKS = PRAIRIE_LOOKS


def top_of(asset: str, scale_z: float) -> float:
    """Hauteur du sommet d'un décor posé à l'échelle verticale scale_z (pour poser des arbres dessus)."""
    return LIB[asset].dimensions.z * scale_z


def _args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--world", default="Prairie")
    p.add_argument("--samples", type=int, default=64)
    p.add_argument("--hero-res", type=int, default=1600)
    p.add_argument("--tile-res", type=int, default=800)
    p.add_argument("--views", default="")
    p.add_argument("--no-layout", action="store_true")
    return p.parse_args(argv)


# =====================================================================================================================
# Bibliothèque de décors cuits + placements
# =====================================================================================================================

LIB: dict[str, bpy.types.Object] = {}
PLACED: list[dict] = []
# Eau et lave : pas des modèles, des pièces Roblox simples (créées par le script Studio), à la même place que la scène.
SURFACES: list[dict] = []


def surface(kind: str, shape: str, x: float, y: float, size_x: float, size_y: float, yaw: float = 0.0) -> None:
    """kind = "water" | "lava" ; shape = "disc" (diamètre size_x) | "block" (size_x le long de son axe, size_y large)."""
    SURFACES.append({"kind": kind, "shape": shape, "blender": [x, y], "size": [size_x, size_y], "yaw": yaw})
SCENE_COLL: bpy.types.Collection | None = None


def lib_blend(world: str) -> Path:
    return ROOT / "source" / ("map_assets.blend" if world == "Prairie" else f"map_assets_{world.lower()}.blend")


def load_library() -> None:
    lib_coll = bpy.data.collections.new("MapLibrary")
    bpy.context.scene.collection.children.link(lib_coll)
    for world, only in W["lib"]:
        wanted = only or E.catalog(world)
        path = lib_blend(world)
        with bpy.data.libraries.load(str(path), link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n in wanted]
        for obj in dst.objects:
            if obj is None:
                continue
            lib_coll.objects.link(obj)
            obj.matrix_world = Matrix.Identity(4)
            obj.hide_render = True
            obj.hide_viewport = True
            LIB[obj.name] = obj
        missing = [n for n in wanted if n not in LIB]
        if missing:
            raise RuntimeError(f"décors absents de {path.name} : {missing} (relancer run_map_assets.py --world {world})")


def put(asset: str, x: float, y: float, z: float = 0.0, yaw: float = 0.0, scale=1.0, zone: str = "",
        collide: bool = False) -> bpy.types.Object:
    """Pose une copie liée (même maillage) ; yaw en degrés autour de Z ; scale = nombre ou (sx, sy, sz)."""
    src = LIB[asset]
    obj = src.copy()
    obj.hide_render = False
    obj.hide_viewport = False
    SCENE_COLL.objects.link(obj)
    s = (scale, scale, scale) if isinstance(scale, (int, float)) else tuple(scale)
    obj.matrix_world = (Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
                        @ Matrix.Diagonal((s[0], s[1], s[2], 1.0)))
    PLACED.append({"asset": asset, "blender": [x, y, z], "yaw": yaw, "scale": list(s), "zone": zone,
                   "collide": collide})
    return obj


def polar(r: float, phi_deg: float) -> tuple[float, float]:
    a = math.radians(phi_deg)
    return r * math.cos(a), r * math.sin(a)


def facing_center(phi_deg: float) -> float:
    """Yaw d'un objet dont le devant (-Y) doit regarder le centre."""
    return phi_deg - 90.0


# =====================================================================================================================
# Matériaux de la scène (non cuits : sol, mur, eau, trou, figurants)
# =====================================================================================================================

def _kit(name):
    mat, kit, bsdf = S._new_material(name, "scene")
    return mat, kit, bsdf


def checker_mat(name: str, a: str, b: str, tile: float, studs: bool = True, sides: bool = False,
                warm: tuple | None = None, rough: float = 0.55, glow: float = 0.0):
    """Damier de dalles (2 tons) + tenons ; warm = (couleur A, couleur B, r0, r1) : réchauffe au-delà de r0.
    glow > 0 : la dalle brille de sa couleur (pièces en Neon dans le jeu, ex. lave des chemins du Volcan)."""
    mat, kit, bsdf = _kit(name)
    obj = kit.texcoord("Object")
    sx, sy, sz = kit.separate(obj)
    cell = kit.math("ADD", kit.math("FLOOR", kit.math("DIVIDE", sx, tile)),
                    kit.math("FLOOR", kit.math("DIVIDE", sy, tile)))
    if sides:
        cell = kit.math("ADD", cell, kit.math("FLOOR", kit.math("DIVIDE", sz, tile)))
    parity = kit.math("ABSOLUTE", kit.math("MODULO", cell, 2.0))
    col = kit.mix(parity, S.color(a), S.color(b))
    if warm:
        r = kit.math("SQRT", kit.math("ADD", kit.math("MULTIPLY", sx, sx), kit.math("MULTIPLY", sy, sy)))
        f = kit.map_range(r, warm[2], warm[3])
        col = kit.mix(f, col, kit.mix(parity, S.color(warm[0]), S.color(warm[1])))
    brush = kit.noise(obj, 0.05, detail=2.0)
    col = kit.mix(kit.math("MULTIPLY", kit.map_range(kit.out(brush, "Fac"), 0.35, 0.65), 0.18), col,
                  S.shade(S.color(a), -0.25))
    normal = None
    if studs:
        h, ring = S.stud_pattern(kit, 1.0, sides=sides)
        col = kit.mix(kit.math("MULTIPLY", ring, 0.4), col, S.shade(S.color(b), -0.3))
        normal = kit.bump(h, strength=1.0, distance=0.1)
    S._finish(mat, kit, bsdf, col, rough, normal, emission_color=col, emission_strength=glow)
    return mat


def flat_mat(name: str, hexcol: str, rough: float = 0.5, emission: float = 0.0, metallic: float = 0.0):
    mat, kit, bsdf = _kit(name)
    c = S.color(hexcol)
    S._finish(mat, kit, bsdf, c, rough, metallic=metallic, emission_color=c, emission_strength=emission)
    return mat


def stripe_mat(name: str, a: str, b: str, width: float = 1.5):
    mat, kit, bsdf = _kit(name)
    sx = kit.separate(kit.texcoord("Object"))[0]
    parity = kit.math("ABSOLUTE", kit.math("MODULO", kit.math("FLOOR", kit.math("DIVIDE", sx, width)), 2.0))
    S._finish(mat, kit, bsdf, kit.mix(parity, S.color(a), S.color(b)), 0.5)
    return mat


def water_mat():
    mat, kit, bsdf = _kit("M_Eau")
    obj = kit.texcoord("Object")
    ripple = kit.noise(obj, 0.35, detail=3.0, distortion=0.6)
    col = kit.mix(kit.map_range(kit.out(ripple, "Fac"), 0.4, 0.7), S.color("#1E9BEA"), S.color("#5FD8FF"))
    normal = kit.bump(kit.out(ripple, "Fac"), strength=0.25, distance=0.2)
    S._finish(mat, kit, bsdf, col, 0.06, normal, emission_color=col, emission_strength=0.12)
    return mat


def vortex_mat():
    """Trou noir : spirale violette lumineuse qui s'assombrit vers le cœur (scène seulement)."""
    mat, kit, bsdf = _kit("M_Vortex")
    sx, sy, _ = kit.separate(kit.texcoord("Object"))
    r = kit.math("SQRT", kit.math("ADD", kit.math("MULTIPLY", sx, sx), kit.math("MULTIPLY", sy, sy)))
    ang = kit.math("ARCTAN2", sy, sx)
    spiral = kit.math("SINE", kit.math("ADD", kit.math("MULTIPLY", ang, 4.0), kit.math("MULTIPLY", r, 0.32)))
    bands = kit.map_range(spiral, 0.2, 0.9)
    depth = kit.map_range(r, 6.0, HOLE_R)
    base = kit.ramp(depth, [(0.0, S.color("#05020D")), (0.35, S.color("#2A0E5E")), (0.75, S.color("#6A2CC8")),
                            (1.0, S.color("#C77DFF"))])
    col = kit.mix(kit.math("MULTIPLY", bands, 0.55), base, S.color("#E2B8FF"))
    S._finish(mat, kit, bsdf, col, 0.3, emission_color=col, emission_strength=1.0)
    kit.set(bsdf, "Emission Strength", kit.math("MULTIPLY", depth, 1.7))
    return mat


def depth_mat():
    mat, kit, bsdf = _kit("M_Profondeur")
    cam = kit.new("ShaderNodeCameraData")
    dist = kit.math("DIVIDE", kit.out(cam, "View Distance"), 1000.0)
    out = next(n for n in mat.node_tree.nodes if n.type == "OUTPUT_MATERIAL")
    emit = kit.new("ShaderNodeEmission")
    kit.set(emit, "Color", dist)
    kit.set(emit, "Strength", 1.0)
    mat.node_tree.links.new(kit.out(emit, "Emission"), S._socket(out.inputs, "Surface"))
    return mat


# =====================================================================================================================
# Géométrie de la scène
# =====================================================================================================================

def mesh_obj(name: str, bm: bmesh.types.BMesh, mat) -> bpy.types.Object:
    obj = G._object_from_bmesh(name, bm)
    for c in obj.users_collection:
        c.objects.unlink(obj)
    SCENE_COLL.objects.link(obj)
    G.assign_material(obj, mat)
    return obj


def disc(name: str, r: float, z: float, mat, segs: int = 160) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=segs, radius=r)
    bmesh.ops.translate(bm, vec=(0, 0, z), verts=bm.verts[:])
    return mesh_obj(name, bm, mat)


def scene_block(name: str, size, at, yaw: float, mat, bevel: float = 0.15, rot=(0, 0, 0), taper=(1, 1)):
    obj = E.bx(name, size, (0, 0, 0), rot, taper)
    E.finish([(obj, mat)], bevel=bevel, max_bevel=0.3, segments=2)
    G.transform(obj, Matrix.Translation(at) @ Matrix.Rotation(math.radians(yaw), 4, "Z"))
    for c in obj.users_collection:
        c.objects.unlink(obj)
    SCENE_COLL.objects.link(obj)
    return obj


def lathe_obj(name, profile, segs, mat, at=(0, 0, 0), closed=False, phase=0.0):
    obj = G.lathe(name, profile, segments=segs, closed=closed, phase=phase)
    G.assign_material(obj, mat)
    G.smooth_by_angle(obj, 35)
    G.transform(obj, Matrix.Translation(at))
    for c in obj.users_collection:
        c.objects.unlink(obj)
    SCENE_COLL.objects.link(obj)
    return obj


def base_xform(phi: float, u: float, v: float) -> tuple[float, float]:
    """Point (u, v) du repère d'une base (v < 0 = vers le trou noir) -> monde Blender."""
    cx, cy = polar(BASE_RING, phi)
    a = math.radians(facing_center(phi))
    return cx + u * math.cos(a) - v * math.sin(a), cy + u * math.sin(a) + v * math.cos(a)


def build_ground(M):
    disc("Sol", FLOOR_R + 12, 0.0, M["sol"])
    for k in range(BASE_COUNT):  # chemins de sable
        phi = -k * 45.0
        a = math.radians(phi)
        bm = bmesh.new()
        r0, r1 = HOLE_R + 9, BASE_RING - BASE_HALF + 1
        corners = [(r0, -PATH_W / 2), (r1, -PATH_W / 2), (r1, PATH_W / 2), (r0, PATH_W / 2)]
        bm.faces.new([bm.verts.new((r * math.cos(a) - t * math.sin(a), r * math.sin(a) + t * math.cos(a), 0.03))
                      for r, t in corners])
        mesh_obj(f"Chemin{k}", bm, M["chemin"])
    lathe_obj("Mur", [(FLOOR_R, -0.5), (FLOOR_R + WALL_T, -0.5), (FLOOR_R + WALL_T, WALL_H), (FLOOR_R, WALL_H)],
              192, M["mur"], closed=True)
    lathe_obj("MurHerbe", [(FLOOR_R - 0.6, WALL_H), (FLOOR_R + WALL_T + 0.6, WALL_H),
                           (FLOOR_R + WALL_T + 0.6, WALL_H + 1.4), (FLOOR_R - 0.6, WALL_H + 1.4)], 192, M["mur_herbe"],
              closed=True)
    disc("SolExterieur", 900, -0.6, M["herbe_loin"], segs=96)


def build_hole(M):
    prof = [(0.0, -16), (3.5, -16), (9, -11), (18, -5.5), (28, -2.0), (36, -0.4), (HOLE_R, 0.02)]
    lathe_obj("TrouNoir", prof, 96, M["vortex"])
    light = bpy.data.lights.new("TrouLumiere", "POINT")
    light.energy = 30000
    light.color = (0.62, 0.32, 1.0)
    light.shadow_soft_size = 6
    lo = bpy.data.objects.new("TrouLumiere", light)
    lo.location = (0, 0, 4)
    SCENE_COLL.objects.link(lo)
    for k in range(24):  # anneau de dalles runiques au ras du sol
        phi = k * 15 + 7.5
        x, y = polar(HOLE_R + 5.0, phi)
        put(W["slab"], x, y, -0.55, phi - 90, (1.12, 1.4, 1.0), "trou")
    for k in range(BASE_COUNT):
        phi = -k * 45.0
        x, y = polar(66, phi)
        put(W["gate"], x, y, 0, facing_center(phi), 1.0, "trou", collide=True)
        for side in (-1, 1):  # totems / obélisques de part et d'autre de la porte
            tx, ty = polar(64, phi + side * 13.5)
            put(W["flank"], tx, ty, 0, phi + 45, 0.9, "trou", collide=True)
        ox, oy = polar(57, phi - 22.5)  # entre deux chemins, avant l'anneau des objets sauvages
        put(W["between"][0] if k % 2 else W["between"][1], ox, oy, W["between_z"], k * 53.0, 0.9 + 0.1 * (k % 3),
            "trou", collide=True)


def build_paths_decor(rnd):
    """Bas-côtés des chemins (anneau des objets sauvages) : touffes et petits champignons, sans collision."""
    for k in range(BASE_COUNT):
        phi = -k * 45.0
        a = math.radians(phi)
        for side in (-1, 1):
            r = WILD[0] + rnd.uniform(0, 8)
            while r < BASE_RING - BASE_HALF - 6:
                t = side * (PATH_W / 2 + rnd.uniform(1.6, 3.4))
                x, y = r * math.cos(a) - t * math.sin(a), r * math.sin(a) + t * math.cos(a)
                if rnd.random() < 0.16:
                    small, s0, s1 = W["path_small"]
                    put(small, x, y, 0, rnd.uniform(0, 360), rnd.uniform(s0, s1), "chemin")
                else:
                    put(W["tuft"], x, y, 0, rnd.uniform(0, 360), rnd.uniform(0.9, 1.5), "chemin")
                r += rnd.uniform(9, 17)
        sx, sy = base_xform(phi, 11, -BASE_HALF - 9)
        put(W["sign"], sx, sy, 0, facing_center(phi) + 180 - 20, 1.0, "chemin")
    for _ in range(46):  # quelques grappes dans la prairie sauvage, entre les chemins
        phi = rnd.uniform(0, 360)
        r = rnd.uniform(WILD[0] + 6, WILD[1])
        off = (phi % 45.0)
        if 6 < off < 39:
            x, y = polar(r, phi)
            put(W["tuft"], x, y, 0, rnd.uniform(0, 360), rnd.uniform(0.8, 1.6), "prairie")


def build_base(M, k: int, hero: bool, rnd):
    phi = -k * 45.0
    cx, cy = polar(BASE_RING, phi)
    yaw = facing_center(phi)
    scene_block(f"Base{k}_Sol", (BASE_HALF * 2, BASE_HALF * 2, 1.0), (cx, cy, 0), yaw, M["base_sol"], bevel=0.05)
    scene_block(f"Base{k}_Paille", (BASE_HALF * 2 - 16, 16, 0.3), (*base_xform(phi, 0, BASE_HALF - 11), 1.0), yaw,
                M["paille"], bevel=0.05)
    # enceinte : palissades sur muret, ouverture de 14 studs au milieu de l'avant
    for side_name, side_yaw, fixed_v, axis in (("avant", 0, -BASE_HALF, "u"), ("fond", 180, BASE_HALF, "u"),
                                               ("gauche", 90, None, -BASE_HALF), ("droite", -90, None, BASE_HALF)):
        for i in range(7):
            s = -36 + 12 * i
            if side_name == "avant" and i == 3:
                continue
            u, v = (s, fixed_v) if fixed_v is not None else (axis, s)
            x, y = base_xform(phi, u, v)
            put(W["fence"], x, y, 0, yaw + side_yaw, 1.0, "base", collide=True)
    ex, ey = base_xform(phi, 0, -BASE_HALF - 2.6)
    put(W["stairs"], ex, ey, 0, yaw, (1.0, 1.0, 0.6), "base")
    ax, ay = base_xform(phi, 0, -BASE_HALF + 0.4)
    put(W["base_gate"], ax, ay, 0, yaw, (0.82, 0.9, 0.82), "base", collide=True)
    for u in (-1, 1):  # palettes à objets : caisses et tonneaux
        px, py = base_xform(phi, u * (BASE_HALF - 10), -BASE_HALF + 10)
        put(W["prop_a"], px, py, 1.0, yaw + rnd.uniform(-8, 8), 1.0, "base")
        qx, qy = base_xform(phi, u * (BASE_HALF - 6), -BASE_HALF + 6)
        put(W["prop_b"], qx, qy, 1.0, rnd.uniform(0, 360), 0.9, "base")
        rx, ry = base_xform(phi, u * (BASE_HALF - 5), BASE_HALF - 24)
        put(W["prop_b"], rx, ry, 1.0, rnd.uniform(0, 360), 0.85, "base")
        sx, sy = base_xform(phi, u * (BASE_HALF - 5.5), BASE_HALF - 29)
        put(W["prop_a"], sx, sy, 1.0, yaw + rnd.uniform(-10, 10), 0.8, "base")
    lx, ly = base_xform(phi, 0, -BASE_HALF + 11)  # bouton de verrouillage
    lathe_obj(f"Base{k}_Verrou", [(0, 1.0), (2.6, 1.0), (2.6, 1.8), (1.9, 1.8), (1.8, 2.6), (0, 2.9)], 12,
              M["verrou"], (lx, ly, 0))
    for n in range(12):  # couveuse : nids et œufs
        col, row = n % 6, n // 6
        nx, ny = base_xform(phi, (col - 2.5) * 11, BASE_HALF - 11 - 4 + row * 8)
        lathe_obj(f"Base{k}_Nid{n}", [(1.5, 1.2), (2.7, 1.2), (2.9, 2.0), (1.4, 2.1)], 9, M["nid"], (nx, ny, 0),
                  closed=True)
        if hero or n % 3 == 0:
            egg = M["oeufs"][(n + k) % len(M["oeufs"])]
            lathe_obj(f"Base{k}_Oeuf{n}", G.egg_profile(3.2, 2.4, rings=10, z0=1.3), 14, egg, (nx, ny, 0))
    if hero:
        add_pets(phi)
        add_avatar(*base_xform(phi, -6, -14), yaw + 20, M)
        add_avatar(*base_xform(phi, 3, -BASE_HALF - 10), yaw + 160, M)


def build_gap(M, k: int, rnd):
    """Entre deux bases : kiosque ou tableau, colline en gradins + forêt, rochers, ruines, ruisseau (une fois)."""
    phi = -(k + 0.5) * 45.0
    roblox_deg = (k + 0.5) * 45.0
    if any(abs(roblox_deg - d) < 1 for d in KIOSK_ROBLOX_DEG):
        add_kiosk(M, phi)
    elif abs(roblox_deg - LEADERBOARD_ROBLOX_DEG) < 1:
        add_leaderboard(M, phi)
    # colline en 2 gradins adossée au mur : un haut (~27 studs) derrière, un bas (~14) devant, arbres sur les sommets
    for dphi, r, scale in ((-7.5, 299, (0.7, 0.75, 0.95)), (0.0, 303, (0.75, 0.75, 1.0)), (7.5, 299, (0.7, 0.75, 0.9)),
                           (-4.0, 281, (0.6, 0.6, 0.5)), (4.0, 281, (0.6, 0.6, 0.45))):
        x, y = polar(r, phi + dphi)
        put(W["hill"], x, y, -0.5, facing_center(phi + dphi) + rnd.uniform(-6, 6), scale, "colline",
            collide=True)
        top = top_of(W["hill"], scale[2]) - 1.0
        for j in range(2 if scale[2] > 0.8 else 1):
            tx, ty = polar(r + 2.5, phi + dphi + rnd.uniform(-3.0, 3.0))
            asset = W["hill_trees"][0] if rnd.random() < 0.2 else rnd.choice(W["hill_trees"][1])
            put(asset, tx, ty, top, rnd.uniform(0, 360), rnd.uniform(0.9, 1.3), "colline", collide=True)
    for j in range(3):
        x, y = polar(rnd.uniform(240, 262), phi + rnd.choice((-1, 1)) * rnd.uniform(5, 11))
        asset = rnd.choice(W["gap_trees"])
        put(asset, x, y, 0, rnd.uniform(0, 360), rnd.uniform(0.8, 1.15), "colline", collide=True)
    for j in range(3):
        x, y = polar(rnd.uniform(228, 270), phi + rnd.uniform(-10, 10))
        put(rnd.choice(W["rocks"]), x, y, -0.4,
            rnd.uniform(0, 360), rnd.uniform(0.8, 1.3), "colline", collide=True)
    x, y = polar(232, phi + rnd.choice((-1, 1)) * 8)
    put(W["ruin"], x, y, 0, facing_center(phi) + rnd.uniform(-30, 30), 1.0, "colline", collide=True)
    mx, my = polar(255, phi + rnd.uniform(-4, 4))
    landmark = W["landmark"][k % len(W["landmark"])]
    put(landmark, mx, my, 0, rnd.uniform(0, 360), rnd.uniform(0.9, 1.2), "colline", collide=True)


def add_stream(M, k: int):
    """Ruisseau du mur jusqu'à une mare, franchi par le pont de bois (entre la base 1 et la base 8)."""
    phi = -(k + 0.5) * 45.0
    a = math.radians(phi)
    bm = bmesh.new()
    pts = []
    for i in range(24):
        r = 312 - i * 4.8
        wig = math.sin(i * 0.55) * 5
        pts.append((r, wig))
    left = [bm.verts.new(((r) * math.cos(a) - (w - 4) * math.sin(a), r * math.sin(a) + (w - 4) * math.cos(a), 0.08))
            for r, w in pts]
    right = [bm.verts.new(((r) * math.cos(a) - (w + 4) * math.sin(a), r * math.sin(a) + (w + 4) * math.cos(a), 0.08))
             for r, w in pts]
    for i in range(len(pts) - 1):
        bm.faces.new((left[i], left[i + 1], right[i + 1], right[i]))
        c0 = (Vector(left[i].co) + Vector(right[i].co)) / 2
        c1 = (Vector(left[i + 1].co) + Vector(right[i + 1].co)) / 2
        d = c1 - c0
        mid = (c0 + c1) / 2
        surface("water", "block", mid.x, mid.y, d.length + 1.0, 8.0, math.degrees(math.atan2(d.y, d.x)))
    mesh_obj("Ruisseau", bm, M["eau"])
    px, py = polar(312 - 23 * 4.8 - 4, phi)
    disc_obj = disc("Mare", 9.5, 0.08, M["eau"], segs=40)
    G.transform(disc_obj, Matrix.Translation((px, py, 0)))
    surface("water", "disc", px, py, 19.0, 19.0)
    r_b = 312 - 12 * 4.8
    bx_, by_ = polar(r_b, phi)
    wig = math.sin(12 * 0.55) * 5
    bx_ -= wig * math.sin(a)
    by_ += wig * math.cos(a)
    if W["bridge"]:
        put(W["bridge"], bx_, by_, 0, phi + 90, 1.0, "colline", collide=True)
    for j in range(6):  # berges en rochers
        r = 312 - (j * 4 + 2) * 4.8
        side = 1 if j % 2 else -1
        x, y = polar(r, phi)
        t = side * 7.5
        put(W["bank_rock"], x - t * math.sin(a), y + t * math.cos(a), -0.6, j * 47.0, 0.45, "colline")


def add_trench(M, k: int, rnd):
    """Fosse des Abysses entre la base 1 et la base 8 (où rôde le Calmar Colosse) : eau sombre, anémones, coraux,
    coquillage géant au bord."""
    phi = -(k + 0.5) * 45.0
    cx, cy = polar(272, phi)
    pit = disc("Fosse", 14.0, 0.08, M["fosse"], segs=48)  # ronde : un cylindre Roblox ne peut pas être ovale
    G.transform(pit, Matrix.Translation((cx, cy, 0)))
    surface("trench", "disc", cx, cy, 28.0, 28.0)
    for j in range(8):
        a = j * 2 * math.pi / 8 + rnd.uniform(-0.2, 0.2)
        x, y = cx + math.cos(a) * 17.5, cy + math.sin(a) * 17.5
        asset = ("Abysses_Corail", "Abysses_Anemone", "Abysses_Rocher", "Abysses_Algue")[j % 4]
        put(asset, x, y, -0.2, rnd.uniform(0, 360), rnd.uniform(0.7, 1.0), "colline",
            collide=asset in ("Abysses_Rocher", "Abysses_Corail"))


def add_stardust_crater(M, k: int, rnd):
    """Cratère de poussière d'étoiles du Cosmos entre la base 1 et la base 8 (où dort le Trou Noir de Poche) : bassin
    violet lumineux (Neon dans Roblox), bord de régolithe, cristaux et météorites autour."""
    phi = -(k + 0.5) * 45.0
    cx, cy = polar(272, phi)
    pool = disc("PoussiereEtoiles", 13.0, 0.08, M["poussiere"], segs=48)  # ronde : un cylindre Roblox ne peut pas être ovale
    G.transform(pool, Matrix.Translation((cx, cy, 0)))
    surface("stardust", "disc", cx, cy, 26.0, 26.0)
    light = bpy.data.lights.new("PoussiereLumiere", "POINT")
    light.energy = 12000
    light.color = (0.7, 0.45, 1.0)
    light.shadow_soft_size = 8
    lo = bpy.data.objects.new("PoussiereLumiere", light)
    lo.location = (cx, cy, 6)
    SCENE_COLL.objects.link(lo)
    for j in range(8):
        a = j * 2 * math.pi / 8 + rnd.uniform(-0.2, 0.2)
        x, y = cx + math.cos(a) * 17.0, cy + math.sin(a) * 17.0
        asset = ("Cosmos_Cristaux", "Cosmos_Rocher", "Cosmos_Champignon", "Cosmos_Meteorite")[j % 4]
        put(asset, x, y, -0.3, rnd.uniform(0, 360), rnd.uniform(0.6, 0.9), "colline",
            collide=asset in ("Cosmos_Rocher", "Cosmos_Meteorite"))


def add_celestial_spring(M, k: int, rnd):
    """Source céleste du Divin entre la base 1 et la base 8 (où le Chérubin Hamster joue de la harpe) : bassin d'eau
    bleu pâle (Glass dans Roblox), margelle de dalles de marbre, arbres d'or, nuages et une harpe."""
    phi = -(k + 0.5) * 45.0
    cx, cy = polar(272, phi)
    pool = disc("SourceCeleste", 13.0, 0.08, M["source"], segs=48)  # ronde : un cylindre Roblox ne peut pas être ovale
    G.transform(pool, Matrix.Translation((cx, cy, 0)))
    surface("spring", "disc", cx, cy, 26.0, 26.0)
    for j in range(8):
        a = j * 2 * math.pi / 8 + rnd.uniform(-0.2, 0.2)
        x, y = cx + math.cos(a) * 17.0, cy + math.sin(a) * 17.0
        asset = ("Divin_ArbreDore", "Divin_Nuage", "Divin_Buisson", "Divin_Harpe")[j % 4]
        put(asset, x, y, -0.2, math.degrees(a) + 90 + rnd.uniform(-15, 15), rnd.uniform(0.7, 0.95), "colline",
            collide=asset in ("Divin_ArbreDore", "Divin_Harpe"))


def add_frozen_lake(M, k: int, rnd):
    """Lac gelé de la Glace entre la base 1 et la base 8 (où patine le Pingouin) : glace lisse, congères, sapins,
    rochers enneigés autour."""
    phi = -(k + 0.5) * 45.0
    cx, cy = polar(272, phi)
    lake = disc("LacGele", 15.0, 0.08, M["glace_lac"], segs=48)  # rond : un cylindre Roblox ne peut pas être ovale
    G.transform(lake, Matrix.Translation((cx, cy, 0)))
    surface("ice", "disc", cx, cy, 30.0, 30.0)
    for j in range(8):
        a = j * 2 * math.pi / 8 + rnd.uniform(-0.2, 0.2)
        x, y = cx + math.cos(a) * 18.5, cy + math.sin(a) * 18.5
        asset = ("Glace_Sapin", "Glace_Congere", "Glace_Rocher", "Glace_SapinPetit")[j % 4]
        put(asset, x, y, -0.2, rnd.uniform(0, 360), rnd.uniform(0.7, 1.1), "colline",
            collide=asset in ("Glace_Sapin", "Glace_Rocher"))


def add_lava_pool(M, k: int, rnd):
    """Mare de lave du Volcan entre la base 1 et la base 8 : cheminées fumantes, cristaux de feu, rochers de basalte."""
    phi = -(k + 0.5) * 45.0
    cx, cy = polar(272, phi)
    pool = disc("MareDeLave", 12.5, 0.08, M["lave"], segs=40)  # ronde : un cylindre Roblox ne peut pas être ovale
    G.transform(pool, Matrix.Translation((cx, cy, 0)))
    surface("lava", "disc", cx, cy, 25.0, 25.0)
    light = bpy.data.lights.new("LaveLumiere", "POINT")
    light.energy = 18000
    light.color = (1.0, 0.45, 0.15)
    light.shadow_soft_size = 8
    lo = bpy.data.objects.new("LaveLumiere", light)
    lo.location = (cx, cy, 6)
    SCENE_COLL.objects.link(lo)
    for j in range(6):
        a = j * 2 * math.pi / 6 + rnd.uniform(-0.2, 0.2)
        x, y = cx + math.cos(a) * 16.5, cy + math.sin(a) * 12.0
        asset = ("Volcan_Cheminee", "Volcan_Roche", "Volcan_Cristaux")[j % 3]
        put(asset, x, y, -0.3, rnd.uniform(0, 360), rnd.uniform(0.7, 1.0), "colline", collide=j % 3 != 2)


def add_oasis(M, k: int, rnd):
    """Oasis du Désert entre la base 1 et la base 8 : mare turquoise, palmiers penchés, figuiers, rochers de grès."""
    phi = -(k + 0.5) * 45.0
    cx, cy = polar(272, phi)
    pond = disc("Oasis", 13.0, 0.08, M["eau"], segs=48)  # ronde : un cylindre Roblox ne peut pas être ovale
    G.transform(pond, Matrix.Translation((cx, cy, 0)))
    surface("water", "disc", cx, cy, 26.0, 26.0)
    for j in range(7):
        a = j * 2 * math.pi / 7 + rnd.uniform(-0.2, 0.2)
        x, y = cx + math.cos(a) * 17.5, cy + math.sin(a) * 12.5
        put("Desert_Palmier", x, y, 0, math.degrees(a) + 180 + rnd.uniform(-20, 20), rnd.uniform(0.9, 1.25), "colline",
            collide=True)
    for j in range(5):
        a = j * 2 * math.pi / 5 + 0.4
        x, y = cx + math.cos(a) * 15.5, cy + math.sin(a) * 11.0
        put(W["bank_rock"] if j % 2 else "Desert_Figuier", x, y, -0.3, rnd.uniform(0, 360), rnd.uniform(0.5, 0.8),
            "colline")


def add_kiosk(M, phi):
    cx, cy = polar(BASE_RING - 12, phi)
    yaw = facing_center(phi)
    scene_block(f"Kiosque{phi}_Sol", (36, 18, 0.3), (cx, cy, 0), yaw, M["dalle"], bevel=0.05)
    for side, awning in ((-1, M["auvent_rouge"]), (1, M["auvent_jaune"])):
        a = math.radians(yaw)
        ox, oy = cx + side * 9 * math.cos(a), cy + side * 9 * math.sin(a)
        scene_block(f"Kiosque{phi}_Comptoir{side}", (11, 4.5, 3.4), (ox, oy, 0.3), yaw, M["bois_kiosque"])
        for px in (-5, 5):
            for py in (-2, 3.5):
                qx = ox + px * math.cos(a) - py * math.sin(a)
                qy = oy + px * math.sin(a) + py * math.cos(a)
                scene_block(f"Kiosque{phi}_Poteau{side}{px}{py}", (0.8, 0.8, 9), (qx, qy, 0.3), yaw, M["bois_kiosque"])
        scene_block(f"Kiosque{phi}_Auvent{side}", (12.4, 7.6, 0.7), (ox, oy, 9.2), yaw, awning, rot=(-10, 0, 0))


def add_leaderboard(M, phi):
    cx, cy = polar(190, phi)
    yaw = facing_center(phi)
    a = math.radians(yaw)
    for side in (-1, 1):
        scene_block(f"Tableau_Poteau{side}", (1.6, 1.6, 22), (cx + side * 11 * math.cos(a), cy + side * 11 * math.sin(a), 0),
                    yaw, M["bois_kiosque"])
    scene_block("Tableau_Panneau", (24, 1.2, 13), (cx, cy, 8), yaw, M["ecran"])


def add_pets(phi):
    """Quelques familiers déjà refaits en briques (baked_assets/pets), pour l'échelle et la vie de la base."""
    for pid, u, v, height in W["pets"]:
        fbx = ROOT / "baked_assets" / "pets" / pid / f"{pid}_Rig.fbx"
        if not fbx.exists():
            continue
        before = set(bpy.data.objects)
        try:
            bpy.ops.import_scene.fbx(filepath=str(fbx))
        except RuntimeError as err:
            print(f"[scene] familier {pid} ignoré : {err}")
            continue
        new = [o for o in bpy.data.objects if o not in before]
        meshes = [o for o in new if o.type == "MESH"]
        for o in new:
            if o.type != "MESH":
                bpy.data.objects.remove(o)
        if not meshes:
            continue
        for o in meshes:
            o.data = o.data.copy()
            o.data.transform(o.matrix_world)
            o.matrix_world = Matrix.Identity(4)
        lo, hi = Q.bounds(meshes)
        s = height / max(hi.z - lo.z, 1e-3)
        x, y = base_xform(phi, u, v)
        m = (Matrix.Translation((x, y, 1.0)) @ Matrix.Rotation(math.radians(facing_center(phi) + u * 4), 4, "Z")
             @ Matrix.Scale(s, 4) @ Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
        for o in meshes:
            o.data.transform(m)
            for c in o.users_collection:
                c.objects.unlink(o)
            SCENE_COLL.objects.link(o)


def add_avatar(x, y, yaw, M):
    """Avatar en blocs (5 studs) : repère d'échelle."""
    parts = [((2.0, 1.0, 2.0), (0, 0, 2.0), M["avatar_haut"]), ((0.95, 1.0, 2.0), (-0.5, 0, 0), M["avatar_bas"]),
             ((0.95, 1.0, 2.0), (0.5, 0, 0), M["avatar_bas"]), ((0.95, 1.0, 2.0), (-1.5, 0, 2.0), M["avatar_peau"]),
             ((0.95, 1.0, 2.0), (1.5, 0, 2.0), M["avatar_peau"]), ((1.2, 1.2, 1.15), (0, 0, 4.0), M["avatar_peau"])]
    for i, (size, (u, v, z), mat) in enumerate(parts):
        a = math.radians(yaw)
        scene_block(f"Avatar_{x:.0f}_{i}", size, (x + u * math.cos(a) - v * math.sin(a),
                                                  y + u * math.sin(a) + v * math.cos(a), z + 1.0), yaw, mat, bevel=0.08)


def build_periphery(rnd):
    """Derrière le mur : 2 couronnes de falaises en gradins (55-75 puis 85-110 studs) qui font de l'arène une cuvette,
    couronnées d'arbres, puis des monts lointains dans la brume."""
    for n, r0, sxy, sz_range in ((40, FLOOR_R + WALL_T + 14, (1.6, 1.3), (1.9, 2.6)),
                                 (34, FLOOR_R + WALL_T + 52, (2.0, 1.6), (3.0, 3.9))):
        for k in range(n):
            phi = k * 360 / n + rnd.uniform(-2, 2) + (4 if r0 > 360 else 0)
            r = r0 + rnd.uniform(0, 8)
            x, y = polar(r, phi)
            sz = rnd.uniform(*sz_range)
            yaw = facing_center(phi) + rnd.uniform(-5, 5)
            alt = W.get("cliff_alt")
            if alt and k % 3 == 1:  # un module sur trois remplacé (casse la répétition des orgues du Volcan)
                put(alt[0], x, y, -1, yaw, (alt[1][0], alt[1][1], alt[1][2] * sz / sz_range[1]), "peripherie")
                continue  # pas d'arbres sur des pointes : ils flotteraient
            put(W["cliff"], x, y, -1, yaw, (sxy[0], sxy[1], sz), "peripherie")
            for j in range(2):
                tx, ty = polar(r + rnd.uniform(3, 7) * sxy[1], phi + rnd.uniform(-3.5, 3.5))
                asset = W["cliff_trees"][0] if rnd.random() < 0.12 else rnd.choice(W["cliff_trees"][1])
                put(asset, tx, ty, top_of(W["cliff"], sz) - 3, rnd.uniform(0, 360),
                    rnd.uniform(1.3, 2.0) * W.get("cliff_tree_scale", 1.0), "peripherie")
    for k in range(18):
        phi = k * 20 + rnd.uniform(-6, 6)
        x, y = polar(rnd.uniform(520, 720), phi)
        put(W["far"][0] if k % 2 else W["far"][1], x, y, -6, rnd.uniform(0, 360),
            tuple(rnd.uniform(*rng) for rng in W["far_scale"]), "lointain")
    for k in range(7):
        phi = k * 51 + 10
        x, y = polar(rnd.uniform(640, 780), phi)
        put(W["far_spire"], x, y, -4, rnd.uniform(0, 360), rnd.uniform(6, 9), "lointain")


def build_clouds(M, rnd):
    for k in range(W["clouds"]):
        phi = rnd.uniform(0, 360)
        x, y = polar(rnd.uniform(520, 1000), phi)
        z = rnd.uniform(190, 300)
        for j in range(rnd.randint(4, 7)):
            s = rnd.uniform(18, 34)
            scene_block(f"Nuage{k}_{j}", (s * 1.6, s, s * 0.6),
                        (x + rnd.uniform(-30, 30), y + rnd.uniform(-20, 20), z + rnd.uniform(-6, 8)),
                        rnd.uniform(0, 90), M["nuage"], bevel=0.12)


# =====================================================================================================================
# Lumière, rendu, post-traitement (réglages Roblox du preset)
# =====================================================================================================================

def setup_world(look: dict) -> None:
    scene = bpy.context.scene
    world = scene.world or bpy.data.worlds.new("Ciel")
    scene.world = world
    if hasattr(world, "use_nodes") and not world.use_nodes:
        world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    kit = S.NodeKit(nt)
    out = kit.new("ShaderNodeOutputWorld")
    bg = kit.new("ShaderNodeBackground")
    coord = kit.new("ShaderNodeTexCoord")
    z = kit.separate(kit.out(coord, "Generated"))[2]
    ramp = kit.ramp(kit.map_range(z, 0.0, 0.55), [(0.0, S.color(look["sky_horizon"])), (1.0, S.color(look["sky_top"]))])
    kit.set(bg, "Color", ramp)
    kit.set(bg, "Strength", look["sky_strength"])
    nt.links.new(kit.out(bg, "Background"), S._socket(out.inputs, "Surface"))
    sun = bpy.data.objects.get("Soleil")
    if sun is None:
        data = bpy.data.lights.new("Soleil", "SUN")
        sun = bpy.data.objects.new("Soleil", data)
        scene.collection.objects.link(sun)
    sun.data.energy = look["sun"]
    sun.data.color = look["sun_color"]
    sun.data.angle = math.radians(3.5)
    elev, az = math.radians(look["sun_elev"]), math.radians(look["sun_az"])
    direction = -Vector((math.cos(elev) * math.cos(az), math.cos(elev) * math.sin(az), math.sin(elev)))
    sun.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def set_camera(pos, target, lens: float) -> None:
    scene = bpy.context.scene
    cam = scene.camera
    if cam is None:
        data = bpy.data.cameras.new("Camera")
        cam = bpy.data.objects.new("Camera", data)
        scene.collection.objects.link(cam)
        scene.camera = cam
    cam.data.lens = lens
    cam.data.clip_end = 3000
    cam.data.clip_start = 0.3
    cam.location = pos
    cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()


def _render_exr(path: Path, w: int, h: int, samples: int, depth: bool = False) -> np.ndarray:
    scene = bpy.context.scene
    vl = bpy.context.view_layer
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    scene.cycles.samples = 1 if depth else samples
    scene.cycles.use_denoising = not depth
    scene.render.film_transparent = depth
    s = scene.render.image_settings
    s.file_format = "OPEN_EXR"
    s.color_depth = "32"
    s.color_mode = "RGBA"
    saved = vl.material_override
    bg = next((n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND"), None)
    strength = bg.inputs["Strength"].default_value if bg else 1.0
    if depth:
        vl.material_override = bpy.data.materials["M_Profondeur"]
        scene.cycles.max_bounces = 0
    try:
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
    finally:
        vl.material_override = saved
        scene.cycles.max_bounces = 8
        if bg:
            bg.inputs["Strength"].default_value = strength
    img = bpy.data.images.load(str(path), check_existing=False)
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    path.unlink(missing_ok=True)
    return arr.reshape(h, w, 4)


def _box_blur(img: np.ndarray, r: int) -> np.ndarray:
    if r < 1:
        return img
    out = img
    for axis in (0, 1):
        pad = [(0, 0)] * img.ndim
        pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis)
        hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
        lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
        out = (hi - lo) / (2 * r + 1)
    return out


def _srgb(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, 12.92 * x, 1.055 * np.power(x, 1 / 2.4) - 0.055)


def grade(rgba: np.ndarray, depth: np.ndarray, look: dict, scale: float) -> np.ndarray:
    """Atmosphere + Bloom + ColorCorrection + exposition, dans cet ordre (comme Roblox)."""
    rgb = rgba[..., :3].astype(np.float32)
    d = depth[..., 0] * 1000.0
    sky = depth[..., 3] < 0.5
    fog = np.clip(1 - np.exp(-np.maximum(d - look["fog_start"], 0) * look["fog_density"]), 0, look["fog_max"])
    fog[sky] = 0.0
    fog_col = np.array(S.color(look["fog"])[:3], dtype=np.float32)
    rgb = rgb * (1 - fog[..., None]) + fog_col * fog[..., None]
    thr, intensity, size = look["bloom"]
    bright = np.maximum(rgb - thr, 0)
    radius = max(int(size * scale), 1)
    glow = bright
    for _ in range(3):
        glow = _box_blur(glow, radius)
    rgb = rgb + glow * intensity
    rgb = rgb * (2.0 ** look["exposure"])
    out = _srgb(rgb)
    lum = (0.2126 * out[..., 0] + 0.7152 * out[..., 1] + 0.0722 * out[..., 2])[..., None]
    out = lum + (out - lum) * (1 + look["saturation"])
    out = (out - 0.5) * (1 + look["contrast"]) + 0.5
    return np.clip(out, 0, 1)


VIEWS = {
    # nom : (position caméra, cible, focale, ambiance)
    "hero": ((292, -34, 40), (20, 14, 2), 22, "jour"),
    "aerien": ((330, -470, 430), (10, -20, 0), 30, "jour"),
    "entree_base": ((150, -26, 7.5), (226, 4, 6), 24, "jour"),
    "entree_arene": ((118, -16, 7), (0, 4, 7), 26, "jour"),
    "colline": ((205, -40, 11), (268, -118, 12), 24, "jour"),
    "nuit": ((292, -34, 40), (20, 14, 2), 22, "nuit"),
    "depuis_trou": ((52, 26, 16), (300, -10, 26), 24, "jour"),
}


def render_view(name: str, w: int, h: int, samples: int) -> np.ndarray:
    pos, target, lens, mood = VIEWS[name]
    look = LOOKS[mood]
    setup_world(look)
    set_camera(pos, target, lens)
    tmp = QA / f"_map_{name}.exr"
    t = time.time()
    color = _render_exr(tmp, w, h, samples)
    depth = _render_exr(QA / f"_map_{name}_z.exr", w, h, 1, depth=True)
    print(f"[scene] vue {name} : {time.time() - t:.0f} s")
    return grade(color, depth, look, w / 1600)


# =====================================================================================================================
# Export du placement pour Roblox
# =====================================================================================================================

def export_layout(path: Path) -> None:
    items = []
    for p in PLACED:
        x, y, z = p["blender"]
        sx, sy, sz = p["scale"]
        items.append({"asset": p["asset"], "position": [round(x, 3), round(z, 3), round(-y, 3)],
                      "yaw_deg": round(p["yaw"] % 360, 2), "scale_xyz": [round(sx, 3), round(sz, 3), round(sy, 3)],
                      "zone": p["zone"], "collide": p["collide"]})
    counts: dict[str, int] = {}
    for it in items:
        counts[it["asset"]] = counts.get(it["asset"], 0) + 1
    data = {
        "frame": "Roblox : position = pied de l'objet (Y = sol), yaw autour de +Y en degrés, scale_xyz dans les axes "
                 "Roblox (X, Y haut, Z). Scène Blender (x, y, z) = Roblox (x, z, -y).",
        "fbx_import": {"mesh_yaw_offset_deg": 180,
                       "note": "Un .fbx du pipeline arrive dans Studio avec Blender (x, y, z) -> Studio (-x, z, y) "
                               "(PIPELINE.md, import du Cerbère) : demi-tour à ajouter au yaw. Non vérifié pour les décors."},
        "counts": dict(sorted(counts.items())),
        "total": len(items),
        "items": items,
        "surfaces_note": "Eau / lave en pièces Roblox : position = centre du dessus au sol, size = (X, épaisseur, Z) "
                         "dans le repère de la pièce, yaw autour de +Y (sans demi-tour : ce ne sont pas des .fbx).",
        "surfaces": [{"kind": s["kind"], "shape": s["shape"],
                      "position": [round(s["blender"][0], 3), 0.13, round(-s["blender"][1], 3)],
                      "size": [round(s["size"][0], 3), 0.26, round(s["size"][1], 3)],
                      "yaw_deg": round(s["yaw"] % 360, 2)} for s in SURFACES],
    }
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"[scene] placement : {path} ({len(items)} décors)")


# =====================================================================================================================

def main() -> None:
    global SCENE_COLL, W, LOOKS
    a = _args()
    W = WORLD_CFG[a.world]
    LOOKS = W["looks"]
    suffix = W["suffix"]
    C = W["colors"]
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    Q._configure(scene, 512, a.samples, True)
    scene.cycles.max_bounces = 8
    SCENE_COLL = bpy.data.collections.new("MapScene")
    scene.collection.children.link(SCENE_COLL)
    load_library()
    rnd = random.Random(2026)
    M = {
        "sol": checker_mat("M_SolArene", C["sol"][0], C["sol"][1], 12, warm=(C["sol"][2], C["sol"][3], 150, 205)),
        "chemin": checker_mat("M_Chemin", *C["chemin"], 8, glow=W.get("glow", {}).get("chemin", 0.0)),
        "base_sol": checker_mat("M_SolBase", *C["base_sol"], 7),
        "paille": checker_mat("M_Paille", *C["paille"], 4),
        "dalle": checker_mat("M_DalleKiosque", *C["dalle"], 6),
        "mur": checker_mat("M_Mur", *C["mur"], 12, sides=True),
        "mur_herbe": checker_mat("M_MurHerbe", *C["mur_haut"], 6, glow=W.get("glow", {}).get("mur_haut", 0.0)),
        "herbe_loin": flat_mat("M_HerbeLoin", C["loin"], 0.8),
        "eau": water_mat(),
        "vortex": vortex_mat(),
        "verrou": flat_mat("M_Verrou", "#F23A3A", 0.35, emission=0.4),
        "nid": checker_mat("M_Nid", "#B07A3A", "#9A6830", 1.0, studs=False),
        "oeufs": [E.mats()["champi_chapeau"], E.mats()["cristal"], E.mats()["or"], E.mats()["feuille_b"],
                  E.mats()["cristal_violet"], E.mats()["points"]],
        "auvent_rouge": stripe_mat("M_AuventRouge", "#E8141A", "#FFFFFF"),
        "auvent_jaune": stripe_mat("M_AuventJaune", "#FFC21A", "#FFFFFF"),
        "bois_kiosque": E.mats()["bois_clair"],
        "ecran": flat_mat("M_Ecran", "#22263A", 0.3, emission=0.2),
        "nuage": flat_mat("M_Nuage", W.get("cloud", "#FFFFFF"), 0.95, emission=0.25),
        "lave": flat_mat("M_LaveScene", "#FF7A1A", 0.3, emission=2.4),
        "glace_lac": flat_mat("M_GlaceLac", "#BEE6FF", 0.05, emission=0.1),
        "fosse": flat_mat("M_Fosse", "#0A2A4A", 0.1, emission=0.15),
        "poussiere": flat_mat("M_PoussiereEtoiles", "#B482FF", 0.3, emission=1.8),
        "source": flat_mat("M_SourceCeleste", "#9AD8FF", 0.05, emission=0.2),
        "avatar_haut": flat_mat("M_AvatarHaut", "#1E7BFF", 0.6),
        "avatar_bas": flat_mat("M_AvatarBas", "#2B2F45", 0.6),
        "avatar_peau": flat_mat("M_AvatarPeau", "#F5CD30", 0.5),
    }
    depth_mat()
    build_ground(M)
    build_hole(M)
    build_paths_decor(rnd)
    for k in range(BASE_COUNT):
        build_base(M, k, hero=(k == 0), rnd=rnd)
    for k in range(BASE_COUNT):
        build_gap(M, k, rnd)
    if W["water"] == "stream":
        add_stream(M, 7)
    elif W["water"] == "oasis":
        add_oasis(M, 7, rnd)
    elif W["water"] == "ice":
        add_frozen_lake(M, 7, rnd)
    elif W["water"] == "trench":
        add_trench(M, 7, rnd)
    elif W["water"] == "stardust":
        add_stardust_crater(M, 7, rnd)
    elif W["water"] == "spring":
        add_celestial_spring(M, 7, rnd)
    else:
        add_lava_pool(M, 7, rnd)
    build_periphery(rnd)
    build_clouds(M, rnd)
    print(f"[scene] construite en {time.time() - t0:.0f} s : {len(PLACED)} décors posés")
    if not a.no_layout:
        folder = ROOT / "baked_assets" / "map" / ("" if a.world == "Prairie" else a.world.lower())
        export_layout(folder / "map_layout.json")
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "source" / f"map_scene{suffix}.blend"), compress=True)

    wanted = [] if a.views == "none" else [v for v in (a.views.split(",") if a.views else VIEWS) if v]
    images = {}
    for name in wanted:
        if name == "hero":
            images[name] = render_view(name, a.hero_res, int(a.hero_res * 9 / 16), a.samples)
            Q._save_rgb(images[name], QA / f"map_hero{suffix}.png")
        else:
            images[name] = render_view(name, a.tile_res, int(a.tile_res * 9 / 16), max(a.samples // 2, 16))
    board_views = [v for v in ("aerien", "entree_base", "entree_arene", "colline", "nuit", "depuis_trou") if v in images]
    if board_views:
        tiles = [images[v] for v in board_views]
        rows = [tiles[i:i + 2] for i in range(0, len(tiles), 2)]
        if len(rows[-1]) < 2:
            rows[-1].append(np.zeros_like(tiles[0]))
        Q._save_rgb(Q._grid(rows, gap=8), QA / f"map_aesthetic_board{suffix}.png")
        (QA / f"map_aesthetic_board{suffix}_report.json").write_text(json.dumps({
            "layout": "2 colonnes, de gauche à droite et de haut en bas", "views": board_views,
            "world": a.world,
            "render": {"engine": "CYCLES", "samples": max(a.samples // 2, 16), "post": "Atmosphere + Bloom + "
                       "ColorCorrection du preset (map_art_bible*.json)"},
            "seconds": round(time.time() - t0, 1)}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[scene] terminé en {time.time() - t0:.0f} s")


main()
