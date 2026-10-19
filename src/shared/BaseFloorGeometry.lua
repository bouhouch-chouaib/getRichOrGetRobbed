--!strict
-- Terrasses ouvertes et escalier latéral alterné, sans bloquer les palettes ni la couveuse.
local Config = require(script.Parent.Config)
local Geometry = {}
function Geometry.Build(parent: Instance, ground: CFrame, level: number, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Floor" .. level
	model:SetAttribute("Level", level)
	local height = Config.BaseFloors.Height
	local top = level * height
	local function part(name: string, size: Vector3, position: Vector3, tint: Color3): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, ground * CFrame.new(position)
		p.Anchored, p.Color = true, tint
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	part("Deck", Vector3.new(72, 1, 76), Vector3.new(-6, top - 0.5, 0), color)
	for _, z in ipairs({ -26, 30 }) do
		part("Landing", Vector3.new(12, 1, 8), Vector3.new(36, top - 0.5, z), color)
	end
	local dark = Color3.fromRGB(44, 48, 62)
	for _, x in ipairs({ -40, 28 }) do
		for _, z in ipairs({ -24, 36 }) do
			part("Column", Vector3.new(2, height, 2), Vector3.new(x, top - height / 2, z), dark)
		end
	end
	local rail = color:Lerp(Color3.new(1, 1, 1), 0.35)
	for _, z in ipairs({ -38, 38 }) do
		part("Rail", Vector3.new(72, 1, 1), Vector3.new(-6, top + 3, z), rail)
		for x = -40, 28, 17 do
			part("Post", Vector3.new(1, 4, 1), Vector3.new(x, top + 1.5, z), dark)
		end
	end
	part("Rail", Vector3.new(1, 1, 76), Vector3.new(-42, top + 3, 0), rail)
	part("StairGuard", Vector3.new(1, 3, 40), Vector3.new(30, top + 1, 2), rail)
	-- 24 marches de 1,33 stud, assez basses pour l'avatar, sur 48 studs de longueur.
	local direction = if level % 2 == 1 then 1 else -1
	for step = 1, 24 do
		local z = if direction == 1 then -22 + (step - 0.5) * 2 else 26 - (step - 0.5) * 2
		part(
			"Step",
			Vector3.new(8, height / 24, 2),
			Vector3.new(35, (level - 1) * height + (step - 0.5) * height / 24, z),
			dark:Lerp(color, 0.3)
		)
	end
	local trim = part(
		"LevelBand",
		Vector3.new(70, 2, 0.4),
		Vector3.new(-6, top - 1, -38.5),
		color:Lerp(Color3.new(1, 1, 1), 0.4)
	)
	trim.Material = Enum.Material.Neon
	local sign = Instance.new("SurfaceGui")
	sign.Face, sign.CanvasSize = Enum.NormalId.Front, Vector2.new(900, 90)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1, 1)
	label.Text = "ÉTAGE " .. level .. " • +" .. Config.BaseFloors.SlotsPerFloor .. " PLACES"
	label.FontFace = require(script.Parent.Typography).Face
	label.TextScaled, label.TextColor3 = true, Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Parent = 2, label
	label.Parent, sign.Parent = sign, trim
	model.Parent = parent
	return model
end
return Geometry
