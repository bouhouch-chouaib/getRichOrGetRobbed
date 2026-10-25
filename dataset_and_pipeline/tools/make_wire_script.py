"""Écrit le script Luau qui branche des familiers importés sur l'animation du jeu (barre MCP execute_luau, Édition).

    python dataset_and_pipeline/tools/make_wire_script.py PigeonVilles ChatRuelle [...] > wire.lua

Avant : Chouaib importe baked_assets/pets/<Id>/<Id>_Rig.fbx (Fichier > Importer 3D) -> Workspace.<Id>_Rig.
Le script : pour chaque familier trouvé, pose sur chaque pièce MotionGroup / MotionKind / MotionPhase / MotionPivotRaw
(+ MotionHingeRaw pour une mâchoire, avec le pivot de la tête qu'elle suit), ajoute la lueur si
baked_assets/pets/<Id>/<Id>_roblox.json donne un masque envoyé ({"emissive": {"<Atlas>": "rbxassetid://..."}}),
range le modèle dans ReplicatedStorage.ArtModels.<Id> (posé au sol, centré) et supprime l'import.
Correspondance des axes mesurée sur l'import (Cerbère, 25 oct.) : Blender (x, y, z) -> Studio (-x, z, y).
Ailes, oreilles, nageoires : la phase devient le côté (-1 / 1) dans Studio, comme le veut PetMotion.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIDED = ("Wing", "Ear", "Fin")


def lua(value) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(round(float(value), 6))
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "{ " + ", ".join(lua(v) for v in value) + " }"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"[{json.dumps(k)}] = {lua(v)}" for k, v in value.items()) + " }"
    raise TypeError(type(value))


def pet_data(pet_id: str) -> dict:
    folder = ROOT / "baked_assets" / "pets" / pet_id
    rig = json.loads((folder / f"{pet_id}_rig.json").read_text("utf-8"))
    extra = folder / f"{pet_id}_roblox.json"
    emissive = json.loads(extra.read_text("utf-8")).get("emissive", {}) if extra.exists() else {}
    parts = {}
    for name, p in rig["parts"].items():
        parts[name] = {"kind": p["kind"], "phase": p["phase"], "follows": p.get("follows"), "atlas": p["atlas"],
                       "strength": p.get("emissive_strength"),
                       "pivot": [row[:4] for row in p["pivot"][:3]] if p.get("pivot") else None}
    # pièce de référence pour placer les pivots : Body, sinon la plus grosse (serpent tout en anneaux animés)
    ref = "Body" if "Body" in rig["parts"] else max(rig["parts"], key=lambda n: math.prod(rig["parts"][n]["size"]))
    body = rig["parts"][ref]
    return {"parts": parts, "ref": ref, "bodyCenter": body["center"], "bodySize": body["size"], "emissive": emissive}


TEMPLATE = r"""-- Généré par dataset_and_pipeline/tools/make_wire_script.py : branche les familiers importés sur PetMotion.
local PETS = __PETS__
local SIDED = { Wing = true, Ear = true, Fin = true }
local art = game.ReplicatedStorage:FindFirstChild("ArtModels") or Instance.new("Folder")
art.Name = "ArtModels"
art.Parent = game.ReplicatedStorage
local report = {}
-- Pièces importées d'un familier : « <Id>__<Pièce> » n'importe où dans le Workspace (import groupé d'un lot,
-- export_lot.py), sinon les pièces du modèle Workspace.<Id>_Rig (import d'un seul familier).
local function sourceParts(petId: string): { [string]: MeshPart }
	local found = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") then
			local owner, piece = string.match(d.Name, "^(.-)__(.+)$")
			if owner == petId then
				found[piece] = d
			end
		end
	end
	if next(found) == nil then
		local single = workspace:FindFirstChild(petId .. "_Rig")
		if single then
			for _, d in single:GetDescendants() do
				if d:IsA("MeshPart") then
					found[d.Name] = d
				end
			end
		end
	end
	return found
end

for petId, data in PETS do
	local found = sourceParts(petId)
	local body = found[data.ref]
	if not body then
		table.insert(report, petId .. " : import introuvable (pièces " .. petId .. "__... ou Workspace." .. petId .. "_Rig)")
		continue
	end
	local bc, bs = data.bodyCenter, data.bodySize
	local centerB = Vector3.new(bc[1], bc[2], bc[3])
	local k = body.Size.Y / bs[3]
	local function mapV(v: Vector3): Vector3
		return Vector3.new(-v.X, v.Z, v.Y)
	end
	local function toCF(m): CFrame
		local p = body.Position + mapV(Vector3.new(m[1][4], m[2][4], m[3][4]) - centerB) * k
		local function col(j)
			return Vector3.new(m[1][j], m[2][j], m[3][j])
		end
		return CFrame.fromMatrix(p, mapV(-col(1)), mapV(col(3)), mapV(col(2)))
	end
	-- boîte de toutes les pièces : le modèle est posé au sol, centré sur l'origine
	local probe = Instance.new("Model")
	for _, part in found do
		part:Clone().Parent = probe
	end
	local cf, size = probe:GetBoundingBox()
	probe:Destroy()
	local shift = CFrame.new(-Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z))
	local model = Instance.new("Model")
	model.Name = petId
	local count, moving = 0, 0
	for pieceName, part in found do
		do
			local q = part:Clone()
			q.Name = pieceName
			for _, c in q:GetChildren() do
				if not c:IsA("SurfaceAppearance") then
					c:Destroy()
				end
			end
			q.CFrame = shift * part.CFrame
			q.Anchored, q.CanCollide, q.CanTouch, q.CanQuery = true, false, false, false
			local info = data.parts[q.Name]
			local sa = q:FindFirstChildOfClass("SurfaceAppearance")
			if info and sa and data.emissive[info.atlas] then
				sa.EmissiveMaskContent = Content.fromUri(data.emissive[info.atlas])
				sa.EmissiveStrength = info.strength or 1
				sa.EmissiveTint = Color3.new(1, 1, 1)
			end
			if info and info.kind ~= "Body" and info.pivot then
				local pivot = shift * toCF(info.pivot)
				local phase = info.phase
				if SIDED[info.kind] then
					phase = if pivot.Position.X >= 0 then 1 else -1
				end
				q:SetAttribute("MotionGroup", q.Name)
				q:SetAttribute("MotionKind", info.kind)
				q:SetAttribute("MotionPhase", phase)
				if info.kind == "Jaw" and info.follows and data.parts[info.follows] then
					q:SetAttribute("MotionPivotRaw", shift * toCF(data.parts[info.follows].pivot))
					q:SetAttribute("MotionHingeRaw", pivot)
				else
					q:SetAttribute("MotionPivotRaw", pivot)
				end
				moving += 1
			end
			q.Parent = model
			count += 1
		end
	end
	model.WorldPivot = CFrame.identity
	model:SetAttribute("FacingYaw", 0)
	model:SetAttribute("Source", "dataset_and_pipeline/blender_tools/pets/" .. petId .. ".py")
	local old = art:FindFirstChild(petId)
	if old then
		old:Destroy()
	end
	model.Parent = art
	-- nettoyage de l'import : les pièces, puis les conteneurs restés vides (<Id>_Rig, le modèle du lot)
	for _, part in found do
		local parent = part.Parent
		part:Destroy()
		while parent and parent ~= workspace and #parent:GetChildren() == 0 do
			local up = parent.Parent
			parent:Destroy()
			parent = up
		end
	end
	local _, msize = model:GetBoundingBox()
	table.insert(report, string.format("%s : %d pièces dont %d animées, %s", petId, count, moving, tostring(msize)))
end
return table.concat(report, "\n")
"""


def main() -> None:
    pets = {pet_id: pet_data(pet_id) for pet_id in sys.argv[1:]}
    if not pets:
        sys.exit(__doc__)
    sys.stdout.buffer.write(TEMPLATE.replace("__PETS__", lua(pets)).encode("utf-8"))  # UTF-8 même sous Windows


if __name__ == "__main__":
    main()
