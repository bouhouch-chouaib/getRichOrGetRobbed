"""Génère le script Studio qui pose les décors d'un monde, à partir du placement exporté par run_map_scene.py.

    python dataset_and_pipeline/tools/make_map_look_script.py [--world Desert]

Prairie -> studio_tools/apply_map_look.lua ; autre monde -> studio_tools/apply_map_look_<monde>.lua.
Entrées : baked_assets/map[/<monde>]/map_layout.json (positions Roblox), les manifestes <Asset>_manifest.json (tailles ;
cherchés dans le dossier du monde puis dans celui de la Prairie, pour les décors partagés comme Caisse), et
map_roblox.json s'il existe (lueurs et couleurs renvoyées à la main). Le script Luau embarque tout (HTTP du jeu coupé).
L'éclairage n'est plus dans ces scripts : il est dans le code du jeu (MapGenerator, DayNightController, Worlds).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "baked_assets" / "map"


def lua_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(float(v), 4))
    return json.dumps(v, ensure_ascii=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--world", default="Prairie")
    world = parser.parse_args().world
    prairie = world == "Prairie"
    folder = MAP if prairie else MAP / world.lower()
    out = ROOT / "studio_tools" / ("apply_map_look.lua" if prairie else f"apply_map_look_{world.lower()}.lua")
    fbx = "baked_assets/map/Decors_Carte.fbx" if prairie else f"baked_assets/map/{world.lower()}/Decors_{world}.fbx"

    layout = json.loads((folder / "map_layout.json").read_text(encoding="utf-8"))
    extra_path = folder / "map_roblox.json"
    extra = json.loads(extra_path.read_text(encoding="utf-8")) if extra_path.exists() else {}
    sizes = {}
    # tous les décors du monde (même ceux que la carte ne pose pas, comme le brasero) : le script doit les ranger
    own = {p.name[: -len("_manifest.json")] for p in folder.glob("*_manifest.json")}
    for asset in sorted({it["asset"] for it in layout["items"]} | own):
        man_path = next(p for p in (folder / f"{asset}_manifest.json", MAP / f"{asset}_manifest.json") if p.exists())
        x, y, z = json.loads(man_path.read_text(encoding="utf-8"))["size_studs"]  # Blender (x, y, z) -> Roblox (x, z, y)
        sizes[asset] = (x, z, y)

    lines = []
    w = lines.append
    w("--!nocheck")
    w(f"-- Décors « niveau studio » du monde {world} dans Studio (mode Édition, barre MCP execute_luau ou rbxm + require).")
    w("-- GÉNÉRÉ par dataset_and_pipeline/tools/make_map_look_script.py (ne pas modifier à la main).")
    w(f"-- Avant : importer {fbx} (Fichier > Importer 3D, réglages par défaut) : les MeshParts")
    w("-- nommées comme les décors arrivent dans le Workspace. Ce script :")
    w("--   1. range ces MeshParts dans ReplicatedStorage.ArtModels.Map.<Asset> (+ lueur / couleur de map_roblox.json) et")
    w("--      supprime l'import (sauvegarder le jeu ensuite : ArtModels n'est que dans le fichier du jeu) ;")
    w(f"--   2. pose les décors de l'arène dans Workspace.MapDecor.{world} (un Model par zone et par huitième de carte,")
    w("--      pour le streaming), sans toucher à Workspace.Map ni aux autres mondes ; les pièces de l'ancien rangement")
    w("--      (directement sous MapDecor) passent dans MapDecor.Prairie. Sans les décors des bases (zone « base ») :")
    w("--      ce sont les dossiers <Monde>Look de server/MapGenerator. client/WorldSkin montre le monde du joueur ;")
    w(f"--   3. MODE = \"remove\" retire Workspace.MapDecor.{world}.")
    w("")
    w(f'local WORLD = "{world}"')
    w('local MODE = "all" -- "all" | "collect" | "decor" | "remove"')
    w("local INCLUDE_BASES = false")
    w(f"local FBX_YAW_OFFSET = {layout['fbx_import']['mesh_yaw_offset_deg']}")
    w("")
    w("-- Couleurs renvoyées à la main (celles de l'import restaient grises) et masques de lueur (map_roblox.json).")
    w("local COLOR_OVERRIDE = {")
    for asset, uri in sorted(extra.get("color_override", {}).items()):
        w(f'\t{asset} = "{uri}",')
    w("}")
    w("local EMISSIVE = {")
    for asset, e in sorted(extra.get("emissive", {}).items()):
        w(f'\t{asset} = {{ id = "{e["EmissiveMaskContent"]}", strength = {e["EmissiveStrength"]} }},')
    w("}")
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
    w('''local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NO_SHADOW = { chemin = true, prairie = true, lointain = true }
local SLIM = { peripherie = true, lointain = true }
local WORLD_IDS = { Prairie = true, Desert = true, Volcan = true, Glace = true, Abysses = true, Cosmos = true, Divin = true }

local function collectImported()
	local art = ReplicatedStorage:FindFirstChild("ArtModels")
	if not art then
		art = Instance.new("Folder")
		art.Name = "ArtModels"
		art.Parent = ReplicatedStorage
	end
	local library = art:FindFirstChild("Map")
	if not library then
		library = Instance.new("Folder")
		library.Name = "Map"
		library.Parent = art
	end
	local moved, containers = 0, {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("MeshPart") and SIZE[inst.Name] and not inst:FindFirstAncestor("MapDecor")
			and not inst:FindFirstAncestor("Map") then
			local top = inst
			while top.Parent ~= Workspace do
				top = top.Parent
			end
			if top ~= inst then
				containers[top] = true
			end
			local old = library:FindFirstChild(inst.Name)
			if old then
				old:Destroy()
			end
			inst.Anchored = true
			local sa = inst:FindFirstChildOfClass("SurfaceAppearance")
			local glow = EMISSIVE[inst.Name]
			if sa and COLOR_OVERRIDE[inst.Name] then
				sa.ColorMapContent = Content.fromUri(COLOR_OVERRIDE[inst.Name])
			end
			if sa and glow then
				sa.EmissiveMaskContent = Content.fromUri(glow.id)
				sa.EmissiveStrength = glow.strength
				sa.EmissiveTint = Color3.new(1, 1, 1)
			end
			inst.Parent = library
			moved += 1
		end
	end
	for container in pairs(containers) do
		if #container:GetDescendants() == 0 or not container:FindFirstChildWhichIsA("BasePart", true) then
			container:Destroy()
		end
	end
	local count, total = 0, 0
	for name in pairs(SIZE) do
		total += 1
		if library:FindFirstChild(name) then
			count += 1
		end
	end
	return string.format("%d décors importés rangés (%d / %d de ce monde dans ArtModels.Map)", moved, count, total)
end

-- Workspace.MapDecor, avec un dossier par monde (l'ancien rangement à plat passe dans MapDecor.Prairie).
local function decorRoot(): Folder
	local root = Workspace:FindFirstChild("MapDecor")
	if not root then
		root = Instance.new("Folder")
		root.Name = "MapDecor"
		root.Parent = Workspace
	end
	local legacy = {}
	for _, child in ipairs(root:GetChildren()) do
		if not WORLD_IDS[child.Name] then
			table.insert(legacy, child)
		end
	end
	if #legacy > 0 then
		local prairie = root:FindFirstChild("Prairie") or Instance.new("Folder")
		prairie.Name = "Prairie"
		prairie.Parent = root
		for _, child in ipairs(legacy) do
			child.Parent = prairie
		end
	end
	return root
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
	local root = decorRoot()
	local old = root:FindFirstChild(WORLD)
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Folder")
	holder.Name = WORLD
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
			group.Parent = holder
			groups[key] = group
		end
		copy.Parent = group
		placed += 1
	end
	holder.Parent = root
	local names = {}
	for asset in pairs(missing) do
		table.insert(names, asset)
	end
	return string.format("%d décors posés dans MapDecor.%s, %d de base ignorés, manquants : %s", placed, WORLD, skipped,
		#names > 0 and table.concat(names, ", ") or "aucun")
end

local report = {}
if MODE == "remove" then
	local root = Workspace:FindFirstChild("MapDecor")
	local old = root and root:FindFirstChild(WORLD)
	if old then
		old:Destroy()
	end
	table.insert(report, "Workspace.MapDecor." .. WORLD .. " retiré")
else
	if MODE == "all" or MODE == "collect" then
		table.insert(report, collectImported())
	end
	if MODE == "all" or MODE == "decor" then
		table.insert(report, placeDecor())
	end
end
print("[MapLook] " .. table.concat(report, " | "))
return table.concat(report, " | ")''')
    out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{out} : {len(layout['items'])} décors, {len(sizes)} assets, {out.stat().st_size // 1024} Ko")


main()
