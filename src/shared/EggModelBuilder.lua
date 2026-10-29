--!strict
-- Eight original studded eggs. Stepped shells, rectangular ornaments and wedge tips.
-- Origin is the ground; ShellHalf lets the client separate the two halves at hatching.
-- 25 oct. : œufs en briques faits dans Blender (un par rareté, sans néon) : ReplicatedStorage.ArtModels.Eggs.<Rareté>,
-- rangés par le branchement Studio (studio_tools/wire_brick_eggs.lua). L'œuf généré ne sert plus qu'en secours.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)
local S = require(script.Parent.PetSculpt)
local EggModel = {}

-- Copie de l'œuf en briques dans un modèle neuf : son échelle repart de 1 (les clients font ScaleTo(échelle voulue)).
-- Attribut "Handmade" : client/Eggs ne lui ajoute ni lumière, ni étincelles, ni éclats en néon.
local function handmade(rarityId: string): Model?
	local art = ReplicatedStorage:FindFirstChild("ArtModels")
	local eggs = art and art:FindFirstChild("Eggs")
	local source = eggs and eggs:FindFirstChild(rarityId)
	if not source or not source:IsA("Model") or not source.PrimaryPart then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Egg_" .. rarityId
	for _, child in ipairs(source:GetChildren()) do
		local copy = child:Clone()
		copy.Parent = m
		if child == source.PrimaryPart then
			m.PrimaryPart = copy :: BasePart
		end
	end
	m:SetAttribute("Handmade", true)
	return m
end
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB
local GOLD, WHITE = rgb(255, 190, 35), rgb(255, 248, 222)
local colors = {
	rgb(241, 221, 178),
	rgb(112, 207, 90),
	rgb(64, 157, 237),
	rgb(113, 55, 180),
	rgb(255, 185, 39),
	rgb(103, 28, 55),
	rgb(225, 255, 255),
	rgb(29, 22, 55),
}

-- Œuf Citrouille d'Halloween (Config.Halloween) : orange à côtes, tige et feuille, visage sculpté. Mêmes étages et
-- mêmes moitiés (ShellHalf) que les autres pour l'éclosion ; sans lumière ni étincelles (attribut Handmade).
local function pumpkinEgg(): Model
	local brick = handmade("Citrouille")
	if brick then
		return brick
	end
	local m = Instance.new("Model")
	m.Name = "Egg_Citrouille"
	local orange, rib, dark = rgb(255, 128, 24), rgb(222, 96, 16), rgb(52, 30, 20)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, wedge: boolean?): BasePart
		local p = S.part(m, name, size, cf, color, false, wedge)
		p:SetAttribute("ShellHalf", if cf.Position.Y > 1.9 then 1 else -1)
		return p
	end
	local root = part("Root", V(0.1, 0.1, 0.1), CF(), orange)
	root.Transparency = 1
	root:SetAttribute("ShellHalf", 0)
	m.PrimaryPart = root
	for i, layer in ipairs({
		V(1.9, 0.45, 1.8),
		V(2.55, 0.65, 2.35),
		V(2.8, 0.7, 2.6),
		V(2.6, 0.7, 2.4),
		V(2.05, 0.65, 1.9),
		V(1.2, 0.45, 1.15),
	}) do
		local y = ({ 0.225, 0.775, 1.45, 2.15, 2.825, 3.375 })[i]
		part("Shell" .. i, layer, CF(0, y, 0), orange)
		-- Côtes de la citrouille : bandes plus foncées sur les quatre faces.
		part("Rib" .. i, V(0.22, layer.Y, layer.Z + 0.06), CF(0, y, 0), rib)
		part("RibSide" .. i, V(layer.X + 0.06, layer.Y, 0.22), CF(0, y, 0), rib)
	end
	part("Stem", V(0.32, 0.7, 0.32), CF(0, 3.9, 0) * A(0, 0, -0.25), rgb(86, 104, 40))
	part("Leaf", V(0.9, 0.16, 0.55), CF(0.45, 3.75, 0.1) * A(0, 0.3, 0.35), rgb(70, 150, 50), true)
	for _, x in ipairs({ -0.55, 0.55 }) do
		part("Eye", V(0.5, 0.42, 0.12), CF(x, 2.3, -1.25), dark)
	end
	part("Mouth", V(1.4, 0.3, 0.12), CF(0, 1.55, -1.36), dark)
	for _, x in ipairs({ -0.35, 0.35 }) do
		part("Tooth", V(0.22, 0.16, 0.14), CF(x, 1.66, -1.38), orange)
	end
	m:SetAttribute("Handmade", true)
	return m
end

-- look = "Citrouille" : l'œuf d'Halloween (familier d'événement, quelle que soit sa rareté).
function EggModel.Build(rarityId: string, look: string?): Model
	if look == "Citrouille" then
		return pumpkinEgg()
	end
	local brick = handmade(rarityId)
	if brick then
		return brick
	end
	local rank = Config.RarityIndex[rarityId] or 1
	local accent = Config.Rarities[rank].Color
	local shell = colors[rank]
	local m = Instance.new("Model")
	m.Name = "Egg_" .. rarityId
	local function part(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		glow: boolean?,
		wedge: boolean?
	): BasePart
		local p = S.part(m, name, size, cf, color, glow, wedge)
		p:SetAttribute("ShellHalf", if cf.Position.Y > 1.9 then 1 else -1)
		return p
	end
	local root = part("Root", V(0.1, 0.1, 0.1), CF(), shell)
	root.Transparency = 1
	root:SetAttribute("ShellHalf", 0)
	m.PrimaryPart = root
	-- Bevelled silhouette, narrow at the top, with small contrasting seams.
	for i, layer in ipairs({
		V(1.7, 0.45, 1.6),
		V(2.35, 0.65, 2.1),
		V(2.65, 0.7, 2.35),
		V(2.45, 0.7, 2.2),
		V(1.95, 0.65, 1.8),
		V(1.15, 0.45, 1.1),
	}) do
		local y = ({ 0.225, 0.775, 1.45, 2.15, 2.825, 3.375 })[i]
		part("Shell" .. i, layer, CF(0, y, 0), shell:Lerp(WHITE, (i - 1) * 0.025))
	end
	-- Front emblem, mounted clear of the shell and readable from the arena.
	part(
		"EmblemBorder",
		V(0.85, 0.85, 0.12),
		CF(0, 1.8, -1.24) * A(0, 0, math.pi / 4),
		shell:Lerp(rgb(12, 15, 30), 0.45)
	)
	part("Emblem", V(0.56, 0.56, 0.1), CF(0, 1.8, -1.32) * A(0, 0, math.pi / 4), accent, rank >= 3)
	if rank == 1 then
		for _, spot in ipairs({ V(-0.65, 1.1, -1.075), V(0.62, 2.5, -1.12), V(0.52, 0.8, -1.08), V(-0.7, 2.2, 1.12) }) do
			part("Freckle", V(0.32, 0.26, 0.06), CF(spot), rgb(179, 137, 86))
		end
	elseif rank == 2 then
		part("Stem", V(0.25, 0.6, 0.25), CF(0, 3.7, 0) * A(0, 0, -0.2), rgb(55, 102, 35))
		for _, side in ipairs({ -1, 1 }) do
			part(
				"Leaf",
				V(0.95, 0.18, 0.6),
				CF(side * 0.48, 3.75, 0) * A(0, side * 0.3, side * 0.3),
				rgb(41, 153, 55),
				false,
				true
			)
			part("Vine", V(0.17, 1.8, 0.1), CF(side * 0.84, 1.8, -1.2) * A(0, 0, side * 0.15), rgb(44, 132, 57))
		end
	elseif rank == 3 then
		for i = 0, 4 do
			local angle = i * math.pi * 2 / 5
			part(
				"IceCrystal",
				V(0.44, 0.95, 0.5),
				CF(math.cos(angle) * 0.7, 3.3, math.sin(angle) * 0.65) * A(0.2, angle, 0.25),
				rgb(136, 241, 255),
				i == 0,
				true
			)
		end
		for _, side in ipairs({ -1, 1 }) do
			part("FrostPlate", V(0.28, 1.7, 1.5), CF(side * 1.28, 1.5, 0) * A(0, 0, -side * 0.12), rgb(156, 225, 255))
		end
	elseif rank == 4 then
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				part(
					"Amethyst",
					V(0.36, 1.25 - i * 0.18, 0.48),
					CF(side * (1.24 + i * 0.22), 2.1 - i * 0.25, i * 0.25) * A(0, 0, -side * (0.3 + i * 0.25)),
					rgb(202, 109, 255),
					i == 0,
					true
				)
			end
		end
		part("Rune", V(0.14, 0.65, 0.12), CF(0, 2.8, -0.98), rgb(239, 165, 255), true)
	elseif rank == 5 then
		for _, side in ipairs({ -1, 1 }) do
			part("RoyalBand", V(0.26, 2.6, 0.14), CF(side * 0.65, 1.6, -1.18), rgb(255, 225, 108))
		end
		part("CrownBand", V(1.65, 0.24, 1.5), CF(0, 3.45, 0), GOLD)
		for i = -1, 1 do
			part(
				"CrownPoint",
				V(0.36, 0.7 + (if i == 0 then 0.2 else 0), 0.35),
				CF(i * 0.6, 3.85, -0.55),
				GOLD,
				false,
				true
			)
		end
		part("Ruby", V(0.3, 0.35, 0.12), CF(0, 3.53, -0.82), rgb(255, 61, 76), true)
	elseif rank == 6 then
		for _, side in ipairs({ -1, 1 }) do
			part(
				"DragonHorn",
				V(0.48, 1.4, 0.5),
				CF(side * 0.8, 3.6, 0.1) * A(-0.25, 0, -side * 0.3),
				rgb(245, 97, 90),
				false,
				true
			)
			for i = 0, 2 do
				part(
					"DragonScale",
					V(0.68, 0.75, 0.3),
					CF(side * 1.1, 1.1 + i * 0.6, -0.83) * A(0.3, side * 0.6, 0),
					rgb(181 + i * 20, 43, 69),
					false,
					true
				)
			end
			part(
				"MoltenSeam",
				V(0.1, 1.65, 0.1),
				CF(side * 0.48, 1.5, -1.23) * A(0, 0, side * 0.18),
				rgb(255, 113, 68),
				true
			)
		end
	elseif rank == 7 then
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 3 do
				part(
					"Feather",
					V(0.45, 0.18, 1.4 - i * 0.2),
					CF(side * (1.2 + i * 0.3), 2.35 + i * 0.15, 0.2) * A(0.2, side * -0.4, side * 0.5),
					WHITE
				)
			end
		end
		for i = 0, 7 do
			local angle = i * math.pi / 4
			part(
				"Halo",
				V(0.85, 0.12, 0.18),
				CF(math.cos(angle) * 1.05, 4.05, math.sin(angle) * 1.05) * A(0, -angle - math.pi / 2, 0),
				GOLD,
				true
			)
		end
	else
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				part(
					"VoidPlate",
					V(0.6, 0.9, 0.45),
					CF(side * (1.1 + i * 0.18), 2.2 + i * 0.45, 0.12) * A(0, side * 0.3, -side * 0.35),
					rgb(69, 42, 109),
					false,
					true
				)
			end
			part(
				"CosmicRift",
				V(0.12, 2.5, 0.12),
				CF(side * 0.61, 1.85, -1.22) * A(0, 0, side * 0.22),
				rgb(189, 107, 255),
				true
			)
		end
		part("StarVertical", V(0.16, 1.05, 0.16), CF(0, 4.05, 0), GOLD, true)
		part("StarHorizontal", V(0.9, 0.16, 0.16), CF(0, 4.05, 0), GOLD, true)
		for i = 0, 5 do
			local a = i * math.pi / 3
			part(
				"OrbitFragment",
				V(0.24, 0.24, 0.5),
				CF(math.cos(a) * 1.9, 2 + math.sin(a) * 0.65, math.sin(a) * 1.5) * A(a, a, 0.5),
				GOLD,
				true
			)
		end
	end
	return m
end

return EggModel
