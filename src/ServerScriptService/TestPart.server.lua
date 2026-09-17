-- Attend que le jeu soit complètement chargé
local baseplate = workspace:WaitForChild("Baseplate")

-- Crée une nouvelle Part
local part = Instance.new("Part")
part.Name = "TestPart"
part.Size = Vector3.new(4, 4, 4)
part.Color = Color3.fromRGB(255, 0, 0)
part.Material = Enum.Material.Plastic
part.Anchored = true
part.CanCollide = true

-- Positionne la Part au-dessus de la Baseplate
part.Position = baseplate.Position + Vector3.new(0, baseplate.Size.Y / 2 + part.Size.Y / 2, 0)

-- Parente la Part au workspace
part.Parent = workspace
