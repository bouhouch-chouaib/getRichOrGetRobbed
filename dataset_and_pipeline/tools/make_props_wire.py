"""Écrit le script Luau qui range les objets en briques importés (boutique, fusion, capsule, tapis, bancs) dans
ReplicatedStorage.ArtModels.<Id> (barre MCP execute_luau, mode Édition, après Fichier > Importer 3D du lot) :
    python dataset_and_pipeline/tools/make_props_wire.py Shop FusionMachine EvolutionCapsule Treadmill_Bois [...] > wire.lua

Les objets sont modélisés en studs dans Blender (pets/props, 1 unité = 1 stud) : le script remet chaque pièce importée
« <Id>__<Pièce> » à cette taille et place l'origine Blender (le sol, au centre du repère de l'objet) sur le Root du
modèle, d'après la boîte de l'objet dans baked_assets/pets/<Id>/<Id>_rig.json. Correspondance des axes mesurée sur les
imports : Blender (x, y, z) -> Studio (-x, z, y). Les tapis et bancs reçoivent l'attribut StarY (hauteur de l'étoile du
niveau maximal, server/StationLooks).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STAR_Y = {"Treadmill": 9.4, "Bench": 3.2}
# au-dessus des couronnes et de la planète ; au centre de l'auréole du modèle Céleste
STAR_Y_BY_ID = {"Treadmill_Or": 10.5, "Treadmill_Jade": 10.4, "Treadmill_Cristal": 10.6, "Treadmill_Royal": 11.0,
                "Treadmill_Cosmique": 12.0, "Treadmill_Celeste": 10.4}


def bounds(prop_id: str) -> dict:
    rig = json.loads((ROOT / "baked_assets" / "pets" / prop_id / f"{prop_id}_rig.json").read_text("utf-8"))
    lo, hi = [1e9] * 3, [-1e9] * 3
    for part in rig["parts"].values():
        for i in range(3):
            lo[i] = min(lo[i], part["center"][i] - part["size"][i] / 2)
            hi[i] = max(hi[i], part["center"][i] + part["size"][i] / 2)
    center = [(lo[i] + hi[i]) / 2 for i in range(3)]
    size = [hi[i] - lo[i] for i in range(3)]
    star = STAR_Y_BY_ID.get(prop_id) or next((y for prefix, y in STAR_Y.items() if prop_id.startswith(prefix)), None)
    return {"center": [round(v, 5) for v in center], "size": [round(v, 5) for v in size], "star": star}


TEMPLATE = r"""-- Généré par dataset_and_pipeline/tools/make_props_wire.py : range les objets en briques importés dans ArtModels.
local PROPS = __PROPS__
local art = game.ReplicatedStorage:FindFirstChild("ArtModels") or Instance.new("Folder")
art.Name = "ArtModels"
art.Parent = game.ReplicatedStorage
local report = {}
local imports = {}
for propId, info in PROPS do
	local found = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") then
			local owner, piece = string.match(d.Name, "^(.-)__(.+)$")
			if owner == propId and piece then
				found[piece] = d
			end
		end
	end
	if next(found) == nil then
		table.insert(report, propId .. " : import introuvable (" .. propId .. "__...)")
		continue
	end
	local probe = Instance.new("Model")
	for _, part in found do
		part:Clone().Parent = probe
	end
	local box, size = probe:GetBoundingBox()
	probe:Destroy()
	local k = info.size[3] / size.Y -- remet 1 unité Blender = 1 stud
	local target = Vector3.new(-info.center[1], info.center[3], info.center[2]) -- centre de la boîte, origine Blender au sol
	local model = Instance.new("Model")
	model.Name = propId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.2
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
	root.Parent = model
	model.PrimaryPart = root
	local count = 0
	for piece, part in found do
		local q = part:Clone()
		q.Name = piece
		for _, c in q:GetChildren() do
			if not c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		q.Size = part.Size * k
		q.CFrame = CFrame.new((part.Position - box.Position) * k + target) * part.CFrame.Rotation
		q.Anchored, q.CanCollide, q.CanTouch, q.CanQuery = true, false, false, false
		q.Parent = model
		count += 1
		local lot = part:FindFirstAncestorWhichIsA("Model")
		imports[if lot and lot ~= workspace then lot else part] = true
	end
	if info.star then
		model:SetAttribute("StarY", info.star)
	end
	local old = art:FindFirstChild(propId)
	if old then
		old:Destroy()
	end
	model.Parent = art
	local _, finalSize = model:GetBoundingBox()
	table.insert(report, string.format("%s : %d pièces, %.1f x %.1f x %.1f studs", propId, count, finalSize.X, finalSize.Y, finalSize.Z))
end
for item in imports do
	if item.Parent then
		item:Destroy()
	end
end
table.sort(report)
return table.concat(report, "\n")
"""


def lua(value) -> str:
    if value is None:
        return "nil"
    if isinstance(value, (int, float)):
        return repr(round(float(value), 5))
    if isinstance(value, list):
        return "{ " + ", ".join(lua(v) for v in value) + " }"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{k} = {lua(v)}" for k, v in value.items()) + " }"
    raise TypeError(type(value))


def main() -> None:
    props = {pid: bounds(pid) for pid in sys.argv[1:]}
    table = "{\n" + "".join(f"\t[{json.dumps(pid)}] = {lua(info)},\n" for pid, info in props.items()) + "}"
    sys.stdout.write(TEMPLATE.replace("__PROPS__", table))


if __name__ == "__main__":
    main()
