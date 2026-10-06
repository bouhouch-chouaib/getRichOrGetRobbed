--!strict
-- ScreenScale : met toute une interface à l'échelle de l'écran (téléphone, tablette, PC).
-- L'interface est dessinée pour un écran de référence 1280 x 720 ; on la réduit sur les petits écrans.
--
--   local root = ScreenScale.attach(screenGui)  -- parenter les éléments à "root" au lieu du ScreenGui
--   ScreenScale.isTouch()                       -- true sur téléphone / tablette
--
-- Astuce : "root" est un Frame plein écran agrandi de 1/scale puis réduit par un UIScale de "scale" :
-- les positions en pourcentage (0.5 = milieu) restent justes, et les tailles en pixels sont réduites.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ScreenScale = {}

local REFERENCE = Vector2.new(1280, 720)
local MIN_SCALE = 0.5
local MAX_SCALE = 1

function ScreenScale.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function ScreenScale.getScale(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else REFERENCE
	local scale = math.min(viewport.X / REFERENCE.X, viewport.Y / REFERENCE.Y)
	return math.clamp(scale, MIN_SCALE, MAX_SCALE)
end

function ScreenScale.attach(screenGui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromScale(0, 0)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	root.Parent = screenGui

	local function update()
		local scale = ScreenScale.getScale()
		uiScale.Scale = scale
		root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	update()

	local connection: RBXScriptConnection? = nil
	local function watchCamera()
		if connection then
			connection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	return root
end

return ScreenScale
