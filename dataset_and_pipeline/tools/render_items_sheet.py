"""Planche de contrôle des objets à jeter d'un monde (un objet par ligne, vu de face, de 3/4 et de profil), après la
cuisson par run_pet_rig.py (la planche « board » montre les 6 objets ensemble, trop petits pour juger) :

    blender -b --factory-startup --python dataset_and_pipeline/tools/render_items_sheet.py -- Objets_Prairie

Sortie : qa_renders/pets/<Id>_items.png (à ouvrir avec l'outil de lecture d'image). Lance une seule cuisson ou planche
à la fois : les rendus passent par le même dossier qa_renders/pets/_tiles.
"""

import json
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "blender_tools"))

import visual_qa_renderer as Q  # noqa: E402


def main() -> None:
    asset = sys.argv[sys.argv.index("--") + 1]
    rig = json.loads((ROOT / "baked_assets" / "pets" / asset / f"{asset}_rig.json").read_text("utf-8"))
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "source" / "pets" / f"{asset}.blend"))
    rows = [{"label": name, "objects": [bpy.data.objects[name]], "kind": "baked"} for name in rig["parts"]]
    Q.render_qa_grid(rows, out_path=ROOT / "qa_renders" / "pets" / f"{asset}_items.png", resolution=360, samples=32,
                     views=("face", "trois_quarts", "profil"))


main()
