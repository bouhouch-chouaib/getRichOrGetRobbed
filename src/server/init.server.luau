-- Génération de la map "Steal a Brainrot"
-- Bases de chaque côté + chemin central coloré

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Hello)
local GameLoopManager = require(script.Parent.GameLoopManager)

local function newPart(name, size, cframe, color, parent, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildMap()
	-- Dossier racine de la map
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	-- Sol principal
	newPart(
		"Ground",
		Config.GroundSize,
		CFrame.new(0, 0, 0),
		Config.Colors.Ground,
		map,
		Enum.Material.Grass
	)

	-- Chemin central
	local pathLength = Config.GroundSize.Z
	newPart(
		"Path",
		Vector3.new(Config.PathWidth, 0.5, pathLength),
		CFrame.new(0, 1.25, 0),
		Config.Colors.Path,
		map
	)

	-- Bandes décoratives sur le chemin (petits carrés roses)
	local stripeCount = 10
	local stripeSpacing = pathLength / stripeCount
	for i = 1, stripeCount do
		local z = -pathLength / 2 + stripeSpacing * (i - 0.5)
		newPart(
			"PathStripe",
			Vector3.new(Config.PathWidth, 0.6, 4),
			CFrame.new(0, 1.3, z),
			Config.Colors.PathStripe,
			map,
			Enum.Material.Neon
		)
	end

	-- Deux rangées de bases (gauche et droite)
	local totalWidth = Config.BasesPerRow * Config.BaseSize.X
		+ (Config.BasesPerRow - 1) * Config.BaseSpacing
	local startX = -totalWidth / 2 + Config.BaseSize.X / 2

	for row = 0, 1 do
		local side = (row == 0) and -1 or 1
		local xOffset = side * (Config.PathWidth / 2 + Config.BaseOffsetX)

		for i = 1, Config.BasesPerRow do
			local x = startX + (i - 1) * (Config.BaseSize.X + Config.BaseSpacing)
			local colorIndex = ((row * Config.BasesPerRow + i - 1)
				% #Config.Colors.BaseColors) + 1

			local base = newPart(
				"Base_" .. row .. "_" .. i,
				Config.BaseSize,
				CFrame.new(x + xOffset, 1.5, 0),
				Config.Colors.BaseColors[colorIndex],
				map
			)

			-- Bordure néon autour de la base
			local border = Instance.new("SelectionBox")
			border.Adornee = base
			border.Color3 = Config.Colors.Neon
			border.LineThickness = 0.2
			border.Parent = base
		end
	end

	-- Arbres décoratifs sur les bords
	local treePositions = {
		Vector3.new(-180, 0, -80),
		Vector3.new(-180, 0, 80),
		Vector3.new(180, 0, -80),
		Vector3.new(180, 0, 80),
		Vector3.new(-180, 0, 0),
		Vector3.new(180, 0, 0),
	}
	for i, pos in ipairs(treePositions) do
		newPart(
			"TreeTrunk_" .. i,
			Vector3.new(4, 20, 4),
			CFrame.new(pos + Vector3.new(0, 10, 0)),
			Config.Colors.TreeTrunk,
			map,
			Enum.Material.Wood
		)
		newPart(
			"TreeLeaves_" .. i,
			Vector3.new(20, 20, 20),
			CFrame.new(pos + Vector3.new(0, 28, 0)),
			Config.Colors.TreeLeaves,
			map,
			Enum.Material.Grass
		)
	end

	-- Nuages joyeux au-dessus de la map
	local cloudPositions = {
		Vector3.new(-100, 60, -60),
		Vector3.new(100, 70, 40),
		Vector3.new(0, 80, 0),
	}
	for i, pos in ipairs(cloudPositions) do
		newPart(
			"Cloud_" .. i,
			Vector3.new(40, 10, 20),
			CFrame.new(pos),
			Config.Colors.Cloud,
			map,
			Enum.Material.SmoothPlastic
		)
	end

	print("Map 'Steal a Brainrot' générée avec succès !")
end

buildMap()

-- Démarrage de la boucle de jeu (Feeding / Digesting)
GameLoopManager.PhaseChanged.Event:Connect(function(phase, duration)
	print(string.format("[GameLoop] Nouvelle phase : %s (%d s)", phase, duration))
end)

GameLoopManager.start()
