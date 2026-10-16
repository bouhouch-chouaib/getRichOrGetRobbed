--!strict
-- RainbowPets : les familiers Arc-en-ciel (mutation, Config.Mutations) changent de couleur en continu. Chaque pièce garde
-- sa place dans le dégradé (attribut "RainbowOffset" posé par shared/PetModelBuilder) et toutes défilent ensemble.
-- Seulement les modèles proches de la caméra, 15 fois par seconde.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SPEED = 0.18 -- tours du cercle des couleurs par seconde
local VIEW_DISTANCE = 160

type Rainbow = { model: Model, parts: { { part: BasePart, offset: number } } }
local rainbows: { [Model]: Rainbow } = {}

local function add(instance: Instance)
	if not instance:IsA("Model") or rainbows[instance] then
		return
	end
	local parts = {}
	for _, descendant in ipairs(instance:GetDescendants()) do
		local offset = descendant:GetAttribute("RainbowOffset")
		if descendant:IsA("BasePart") and type(offset) == "number" then
			table.insert(parts, { part = descendant, offset = offset })
		end
	end
	rainbows[instance] = { model = instance, parts = parts }
end

CollectionService:GetInstanceAddedSignal("RainbowPet"):Connect(add)
CollectionService:GetInstanceRemovedSignal("RainbowPet"):Connect(function(instance: Instance)
	if instance:IsA("Model") then
		rainbows[instance] = nil
	end
end)
for _, instance in ipairs(CollectionService:GetTagged("RainbowPet")) do
	add(instance)
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < 1 / 15 then
		return
	end
	elapsed = 0
	local camera = Workspace.CurrentCamera
	local shift = os.clock() * SPEED
	for model, rainbow in pairs(rainbows) do
		if not model.Parent then
			rainbows[model] = nil
			continue
		end
		-- Les aperçus des fenêtres (ViewportFrame) n'ont pas de caméra du monde : on les anime toujours.
		local inWorld = model:IsDescendantOf(Workspace)
		if inWorld and camera and (model:GetPivot().Position - camera.CFrame.Position).Magnitude > VIEW_DISTANCE then
			continue
		end
		for _, item in ipairs(rainbow.parts) do
			item.part.Color = Color3.fromHSV((item.offset + shift) % 1, 0.75, 1)
		end
	end
end)
