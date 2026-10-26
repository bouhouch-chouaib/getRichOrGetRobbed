"""Écrit le script Luau qui range les objets à jeter importés dans ReplicatedStorage.ArtModels.Items.<Monde>.<Objet>
(barre MCP execute_luau, mode Édition, après Fichier > Importer 3D du lot) :
    python dataset_and_pipeline/tools/make_items_wire.py Objets_Prairie Objets_Desert [...] > wire_items.lua

Chaque monde est cuit d'un bloc (blender_tools/props/Objets_<Monde>.py, une pièce par objet) : la pièce importée
« Objets_<Monde>__<Objet> » devient une MeshPart seule, à sa taille en studs (1 unité Blender = 1 stud, boîte de la pièce
dans baked_assets/pets/<Id>/<Id>_rig.json ; axes Blender (x, y, z) -> Studio (x, z, y), l'import n'a pas de rotation),
centrée sur l'origine, non ancrée, collisions en boîte (CollisionFidelity Box : l'objet ne roule pas, réglable seulement
dans Studio). server/ItemSpawner la clone pour chaque objet qui apparaît (Config.WorldItems).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TEMPLATE = r"""-- Généré par dataset_and_pipeline/tools/make_items_wire.py : range les objets à jeter importés dans ArtModels.Items.
local SETS = __SETS__
local art = game.ReplicatedStorage:FindFirstChild("ArtModels") or Instance.new("Folder")
art.Name = "ArtModels"
art.Parent = game.ReplicatedStorage
local items = art:FindFirstChild("Items") or Instance.new("Folder")
items.Name = "Items"
items.Parent = art
local report = {}
local imports = {}
for asset, info in SETS do
	local folder = items:FindFirstChild(info.world) or Instance.new("Folder")
	folder.Name = info.world
	folder.Parent = items
	local count = 0
	for _, d in workspace:GetDescendants() do
		if not d:IsA("MeshPart") then
			continue
		end
		local owner, piece = string.match(d.Name, "^(.-)__(.+)$")
		local size = owner == asset and piece and info.parts[piece]
		if not size then
			continue
		end
		local q = d:Clone()
		q.Name = piece
		for _, c in q:GetChildren() do
			if not c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		q.Size = Vector3.new(size[1], size[3], size[2])
		q.CFrame = CFrame.new() * d.CFrame.Rotation
		q.Anchored = false
		q.CanCollide, q.CanQuery, q.CanTouch, q.Massless = true, true, true, false
		local old = folder:FindFirstChild(piece)
		if old then
			old:Destroy()
		end
		q.Parent = folder
		q.CollisionFidelity = Enum.CollisionFidelity.Box
		count += 1
		local rx, ry, rz = d.CFrame:ToEulerAnglesXYZ()
		table.insert(report, string.format("%s.%s : %.2f x %.2f x %.2f studs, rotation import (%.0f, %.0f, %.0f)", info.world, piece,
			q.Size.X, q.Size.Y, q.Size.Z, math.deg(rx), math.deg(ry), math.deg(rz)))
		local lot = d:FindFirstAncestorWhichIsA("Model")
		imports[if lot and lot ~= workspace then lot else d] = true
	end
	if count == 0 then
		table.insert(report, asset .. " : import introuvable (" .. asset .. "__...)")
	end
end
-- La collision en boîte se règle en différé : on attend, puis on vérifie (sinon elle reste en Default).
task.wait(4)
for _, folder in items:GetChildren() do
	for _, q in folder:GetChildren() do
		if q:IsA("MeshPart") and q.CollisionFidelity ~= Enum.CollisionFidelity.Box then
			table.insert(report, "  ! " .. folder.Name .. "." .. q.Name .. " pas en boîte : relancer le script")
		end
	end
end
-- Supprime l'import entier (le lot et ses sous-modèles), y compris s'il a été importé deux fois.
for item in imports do
	local top = item
	while top.Parent and top.Parent ~= workspace do
		top = top.Parent
	end
	if top.Parent then
		top:Destroy()
	end
end
table.sort(report)
return table.concat(report, "\n")
"""


def lua(value) -> str:
    if isinstance(value, (int, float)):
        return repr(round(float(value), 5))
    if isinstance(value, list):
        return "{ " + ", ".join(lua(v) for v in value) + " }"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"[{json.dumps(k)}] = {lua(v)}" for k, v in value.items()) + " }"
    if isinstance(value, str):
        return json.dumps(value)
    raise TypeError(type(value))


def main() -> None:
    sets = {}
    for asset in sys.argv[1:]:
        rig = json.loads((ROOT / "baked_assets" / "pets" / asset / f"{asset}_rig.json").read_text("utf-8"))
        sets[asset] = {"world": asset.split("_", 1)[1], "parts": {k: v["size"] for k, v in rig["parts"].items()}}
    table = "{\n" + "".join(f"\t[{json.dumps(a)}] = {lua(info)},\n" for a, info in sets.items()) + "}"
    sys.stdout.write(TEMPLATE.replace("__SETS__", table))


if __name__ == "__main__":
    main()
