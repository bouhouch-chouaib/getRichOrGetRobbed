"""Génère dataset_and_pipeline/studio_tools/apply_map_look.lua à partir du placement exporté par run_map_scene.py.

    python dataset_and_pipeline/tools/make_map_look_script.py

Entrées : baked_assets/map/map_layout.json (positions Roblox), baked_assets/map/<Asset>_manifest.json (tailles),
map_art_bible.json (préréglage d'éclairage « jour_digestion »). Le script Luau embarque tout (le HTTP du jeu est coupé).
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "baked_assets" / "map"
OUT = ROOT / "studio_tools" / "apply_map_look.lua"


def c3(hexcol: str) -> str:
    h = hexcol.lstrip("#")
    return f'Color3.fromHex("{h}")'


def lua_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(float(v), 4))
    if isinstance(v, str) and v.startswith("#"):
        return c3(v)
    return json.dumps(v, ensure_ascii=False)


def main() -> None:
    layout = json.loads((MAP / "map_layout.json").read_text(encoding="utf-8"))
    bible = json.loads((ROOT / "map_art_bible.json").read_text(encoding="utf-8"))
    day = bible["atmosphere"]["presets"]["jour_digestion"]
    sizes = {}
    for asset in sorted({it["asset"] for it in layout["items"]}):
        man = json.loads((MAP / f"{asset}_manifest.json").read_text(encoding="utf-8"))
        x, y, z = man["size_studs"]  # Blender (x, y, z) -> Roblox (x, z, y)
        sizes[asset] = (x, z, y)

    lines = []
    w = lines.append
    w("--!nocheck")
    w("-- Aperçu de la nouvelle carte (phase 1.6) dans Studio, mode Édition, barre MCP execute_luau ou barre de commande.")
    w("-- GÉNÉRÉ par dataset_and_pipeline/tools/make_map_look_script.py (ne pas modifier à la main).")
    w("-- Avant : importer les décors baked_assets/map/<Asset>.fbx (Fichier > Importer 3D) et ranger chaque MeshPart dans")
    w("-- ReplicatedStorage.ArtModels.Map.<Asset> (nom de l'asset). Ce script :")
    w("--   1. applique l'éclairage « jour » de map_art_bible.json (Lighting + Atmosphere, Bloom, ColorCorrection,")
    w("--      DepthOfField, SunRays). Attention : au Play, server/MapGenerator.applyLighting et DayNightController")
    w("--      remettent leurs propres valeurs ; pour garder ce look en jeu il faudra reporter ces valeurs dans le code ;")
    w("--   2. pose les décors dans Workspace.MapDecor (un Model par zone et par huitième de carte, pour le streaming),")
    w("--      sans toucher à Workspace.Map. Par défaut SANS les décors des bases (zone « base ») : les bases sont")
    w("--      construites par MapGenerator au lancement (clôtures, palettes), il faut d'abord adapter ce code ;")
    w("--   3. MODE = \"remove\" retire Workspace.MapDecor.")
    w("-- Non vérifié dans Studio (25 oct.) : import des .fbx des décors, sens du demi-tour (FBX_YAW_OFFSET).")
    w("")
    w('local MODE = "all" -- "all" | "lighting" | "decor" | "remove"')
    w("local INCLUDE_BASES = false")
    w(f"local FBX_YAW_OFFSET = {layout['fbx_import']['mesh_yaw_offset_deg']}")
    w("")
    w("local LIGHTING = {")
    for k, v in day["Lighting"].items():
        if k == "Technology":
            w(f"\tTechnology = Enum.Technology.{v},")
        else:
            w(f"\t{k} = {lua_value(v)},")
    w("}")
    for inst, key in (("Atmosphere", "Atmosphere"), ("BloomEffect", "Bloom"), ("ColorCorrectionEffect", "ColorCorrection"),
                      ("DepthOfFieldEffect", "DepthOfField"), ("SunRaysEffect", "SunRays")):
        props = {k: v for k, v in day[key].items() if k != "note"}
        body = ", ".join(f"{k} = {lua_value(v)}" for k, v in props.items())
        w(f"local {key.upper()} = {{ class = \"{inst}\", props = {{ {body} }} }}")
    w("")
    w("-- Taille de chaque décor dans Roblox (studs, axes X, Y haut, Z) avant mise à l'échelle.")
    w("local SIZE = {")
    for asset, (x, y, z) in sizes.items():
        w(f"\t{asset} = Vector3.new({x}, {y}, {z}),")
    w("}")
    w("")
    w("-- asset, x, y (pied), z, yaw en degrés, échelle X, Y, Z, collision, zone")
    w("local ITEMS = {")
    for it in layout["items"]:
        x, y, z = it["position"]
        sx, sy, sz = it["scale_xyz"]
        w(f'\t{{ "{it["asset"]}", {x}, {y}, {z}, {it["yaw_deg"]}, {sx}, {sy}, {sz}, {lua_value(it["collide"])}, "{it["zone"]}" }},')
    w("}")
    w("")
    w('''local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NO_SHADOW = { chemin = true, prairie = true, lointain = true }
local SLIM = { peripherie = true, lointain = true }

local function applyLighting()
	for key, value in pairs(LIGHTING) do
		pcall(function()
			(Lighting :: any)[key] = value
		end)
	end
	for _, spec in ipairs({ ATMOSPHERE, BLOOM, COLORCORRECTION, DEPTHOFFIELD, SUNRAYS }) do
		local effect = Lighting:FindFirstChildOfClass(spec.class) or Instance.new(spec.class)
		for key, value in pairs(spec.props) do
			pcall(function()
				(effect :: any)[key] = value
			end)
		end
		effect.Parent = Lighting
	end
	return "éclairage « jour » appliqué"
end

local function sectorOf(x: number, z: number): number
	return math.floor(((math.deg(math.atan2(z, x)) + 360) % 360) / 45) + 1
end

local function placeDecor()
	local library = ReplicatedStorage:FindFirstChild("ArtModels")
	library = library and library:FindFirstChild("Map")
	if not library then
		return "ReplicatedStorage.ArtModels.Map introuvable : importer les décors d'abord"
	end
	local old = Workspace:FindFirstChild("MapDecor")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "MapDecor"
	local groups = {}
	local placed, skipped, missing = 0, 0, {}
	for _, item in ipairs(ITEMS) do
		local asset, x, y, z, yaw, sx, sy, sz, collide, zone = table.unpack(item)
		if zone == "base" and not INCLUDE_BASES then
			skipped += 1
			continue
		end
		local source = library:FindFirstChild(asset)
		local part = source and (source:IsA("BasePart") and source or source:FindFirstChildWhichIsA("BasePart", true))
		if not part then
			missing[asset] = true
			continue
		end
		local copy = part:Clone()
		local size = SIZE[asset] * Vector3.new(sx, sy, sz)
		copy.Size = size
		copy.CFrame = CFrame.new(x, y + size.Y / 2, z) * CFrame.Angles(0, math.rad(yaw + FBX_YAW_OFFSET), 0)
		copy.Anchored = true
		copy.CanCollide = collide
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = not NO_SHADOW[zone]
		pcall(function()
			copy.CollisionFidelity = Enum.CollisionFidelity.Box
			copy.RenderFidelity = Enum.RenderFidelity.Automatic
		end)
		local key = zone .. "_" .. sectorOf(x, z)
		local group = groups[key]
		if not group then
			group = Instance.new("Model")
			group.Name = key
			group.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			if SLIM[zone] then
				pcall(function()
					group.LevelOfDetail = Enum.ModelLevelOfDetail.SLIM
				end)
			end
			group.Parent = root
			groups[key] = group
		end
		copy.Parent = group
		placed += 1
	end
	root.Parent = Workspace
	local names = {}
	for asset in pairs(missing) do
		table.insert(names, asset)
	end
	return string.format("%d décors posés, %d de base ignorés, manquants : %s ; StreamingEnabled = %s",
		placed, skipped, #names > 0 and table.concat(names, ", ") or "aucun", tostring(Workspace.StreamingEnabled))
end

local report = {}
if MODE == "remove" then
	local old = Workspace:FindFirstChild("MapDecor")
	if old then
		old:Destroy()
	end
	table.insert(report, "Workspace.MapDecor retiré")
else
	if MODE == "all" or MODE == "lighting" then
		table.insert(report, applyLighting())
	end
	if MODE == "all" or MODE == "decor" then
		table.insert(report, placeDecor())
	end
end
print("[MapLook] " .. table.concat(report, " | "))
return table.concat(report, " | ")''')
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{OUT} : {len(layout['items'])} décors, {len(sizes)} assets, {OUT.stat().st_size // 1024} Ko")


main()
