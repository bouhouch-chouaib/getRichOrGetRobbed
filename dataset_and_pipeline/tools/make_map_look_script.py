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
# Décors qui éclairent, par monde : asset -> (hauteur relative de la lumière -0,5..0,5, portée, luminosité[, couleur])
# (sans couleur : orange de la lave)
LIGHTS = {
    "Volcan": {"Volcan_PilierBrasier": (0.45, 22, 1.6), "Volcan_Cheminee": (0.3, 18, 1.4),
               "Volcan_Chaudron": (0.35, 12, 1.0)},
    "Glace": {"Glace_Lanterne": (0.25, 20, 1.4), "Glace_Igloo": (-0.1, 14, 1.0)},
    "Abysses": {"Abysses_PilierPerle": (0.42, 20, 1.4, (120, 230, 255)),
                "Abysses_Coquillage": (0.1, 16, 1.2, (150, 240, 255))},
}


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
    w("-- Eau / lave (pièces Roblox, rien à envoyer) : kind, forme, x, y, z (centre), taille X, épaisseur, Z, yaw")
    w("local SURFACES = {")
    for s in layout.get("surfaces", []):
        x, y, z = s["position"]
        sx, sy, sz = s["size"]
        w(f'\t{{ "{s["kind"]}", "{s["shape"]}", {x}, {y}, {z}, {sx}, {sy}, {sz}, {s["yaw_deg"]} }},')
    w("}")
    w("")
    w("-- Décors qui éclairent (PointLight sans ombre, à une hauteur relative de la pièce) : seulement dans leur monde,")
    w("-- client/WorldSkin les éteint pour les joueurs des autres mondes.")
    w("local LIGHTS = {")
    for asset, spec in sorted(LIGHTS.get(world, {}).items()):
        rel, rng, bright = spec[:3]
        color = f", color = Color3.fromRGB({spec[3][0]}, {spec[3][1]}, {spec[3][2]})" if len(spec) > 3 else ""
        w(f"\t{asset} = {{ rel = {rel}, range = {rng}, brightness = {bright}{color} }},")
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

local LAVA_LIGHT = Color3.fromRGB(255, 110, 40)
local SURFACE_LOOK = {
	water = { name = "Eau", color = Color3.fromRGB(47, 168, 255), material = Enum.Material.Glass, transparency = 0.35 },
	lava = { name = "Lave", color = Color3.fromRGB(255, 122, 26), material = Enum.Material.Neon, transparency = 0 },
	-- bleu soutenu : un bleu pâle disparaît sur le sol de neige (vu en jeu le 25 oct.)
	ice = { name = "Glace", color = Color3.fromRGB(110, 190, 240), material = Enum.Material.Ice, transparency = 0 },
	-- fosse des Abysses : eau sombre presque opaque, le sol ne doit pas transparaître
	trench = { name = "Fosse", color = Color3.fromRGB(12, 46, 84), material = Enum.Material.Glass, transparency = 0.12 },
}

local function addLight(part: BasePart, spec)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Lumiere"
	attachment.Position = Vector3.new(0, part.Size.Y * spec.rel, 0)
	local light = Instance.new("PointLight")
	light.Color = spec.color or LAVA_LIGHT
	light.Range = spec.range
	light.Brightness = spec.brightness
	light.Shadows = false
	light.Parent = attachment
	attachment.Parent = part
end

local function makeSurface(parent: Instance, s)
	local kind, shape, x, y, z, sx, sy, sz, yaw = table.unpack(s)
	local look = SURFACE_LOOK[kind]
	local part = Instance.new("Part")
	part.Name = look.name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = look.material
	part.Color = look.color
	part.Transparency = look.transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "disc" then
		part.Shape = Enum.PartType.Cylinder -- axe X : couché pour faire un disque
		part.Size = Vector3.new(sy, sx, sx)
		part.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
	else
		part.Size = Vector3.new(sx, sy, sz)
		part.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
	end
	if kind == "lava" then
		local light = Instance.new("PointLight")
		light.Color = LAVA_LIGHT
		light.Range = 40
		light.Brightness = 2
		light.Shadows = false
		light.Parent = part
	end
	part.Parent = parent
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
		if LIGHTS[asset] and zone ~= "lointain" and zone ~= "peripherie" then -- au loin : inutile et coûteux
			addLight(copy, LIGHTS[asset])
		end
		copy.Parent = group
		placed += 1
	end
	if #SURFACES > 0 then
		local water = Instance.new("Model")
		water.Name = "surfaces"
		for _, s in ipairs(SURFACES) do
			makeSurface(water, s)
		end
		water.Parent = holder
	end
	holder.Parent = root
	local names = {}
	for asset in pairs(missing) do
		table.insert(names, asset)
	end
	return string.format("%d décors posés dans MapDecor.%s (+ %d surfaces d'eau / lave), %d de base ignorés, manquants : %s",
		placed, WORLD, #SURFACES, skipped, #names > 0 and table.concat(names, ", ") or "aucun")
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
