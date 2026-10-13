--!strict
-- ScreenScale : met toute une interface à l'échelle de l'écran (téléphone, tablette, PC).
-- L'interface est dessinée pour un écran de référence 1280 x 720 ; on la réduit sur les petits écrans.
--
--   local root = ScreenScale.attach(screenGui)  -- parenter les éléments à "root" au lieu du ScreenGui
--   ScreenScale.isTouch()                       -- true sur téléphone / tablette
--
-- Astuce : "root" est un Frame plein écran agrandi de 1/scale puis réduit par un UIScale de "scale" :
-- les positions en pourcentage (0.5 = milieu) restent justes, et les tailles en pixels sont réduites.
--
-- Aperçu téléphone (Studio seulement) : workspace:SetAttribute("DebugPhone", Vector2.new(844, 390)) AVANT Play.
-- Chaque interface est alors dessinée dans un cadre de cette taille, en mode tactile, avec les zones du joystick
-- et du bouton de saut de Roblox (dessinées par-dessus) : on voit ce qui se chevauche sur un téléphone.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ScreenScale = {}

local REFERENCE = Vector2.new(1280, 720)
-- Sur tactile, un écran de référence moins haut : l'interface est un peu plus grande (lisible au doigt).
local TOUCH_REFERENCE = Vector2.new(1280, 640)
local MIN_SCALE = 0.5
local MAX_SCALE = 1
local PHONE_INSET = 36 -- px : barre du haut de Roblox sur téléphone (les ScreenGui commencent en dessous)

-- Bas du centre de l'écran laissé libre (pixels de référence) : barre d'objets de Roblox (armes), et sur
-- téléphone le bas des commandes tactiles. Les boutons d'action du bas se posent juste au-dessus.
ScreenScale.BOTTOM_RESERVED = 100
-- Tactile : largeur occupée à gauche par l'argent et les tuiles de menu (client/HUD) ; les fenêtres s'ouvrent à droite.
ScreenScale.TOUCH_LEFT_RESERVED = 330
-- Tactile : largeur laissée libre à droite pour le bouton de saut de Roblox.
ScreenScale.TOUCH_RIGHT_RESERVED = 130

local function debugPhone(): Vector2?
	if not RunService:IsStudio() then
		return nil
	end
	local value = Workspace:GetAttribute("DebugPhone")
	return if typeof(value) == "Vector2" then value else nil
end

function ScreenScale.isTouch(): boolean
	if debugPhone() then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function viewportSize(): Vector2
	local phone = debugPhone()
	if phone then
		return phone
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else REFERENCE
end

function ScreenScale.getScale(): number
	local viewport = viewportSize()
	local reference = if ScreenScale.isTouch() then TOUCH_REFERENCE else REFERENCE
	local scale = math.min(viewport.X / reference.X, viewport.Y / reference.Y)
	return math.clamp(scale, MIN_SCALE, MAX_SCALE)
end

-- Taille de l'espace de dessin (en pixels « de référence ») : sur un téléphone en paysage, environ 1560 x 650.
function ScreenScale.virtualSize(): Vector2
	local viewport = viewportSize()
	local scale = ScreenScale.getScale()
	local inset = if debugPhone() then PHONE_INSET else GuiService:GetGuiInset().Y
	return Vector2.new(viewport.X / scale, (viewport.Y - inset) / scale)
end

-- Zones des commandes tactiles de Roblox (aperçu téléphone) : joystick en bas à gauche, saut en bas à droite.
local previewDrawn = false
local function drawControls(phone: Vector2)
	if previewDrawn then
		return
	end
	previewDrawn = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhonePreviewControls"
	gui.DisplayOrder = 1000
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(phone.X, phone.Y - PHONE_INSET)
	frame.BackgroundTransparency = 1
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = Color3.fromRGB(255, 0, 200)
	border.Parent = frame
	frame.Parent = gui
	local small = math.min(phone.X, phone.Y) <= 500
	local function zone(name: string, size: number, position: UDim2)
		local circle = Instance.new("Frame")
		circle.Name = name
		circle.Size = UDim2.fromOffset(size, size)
		circle.Position = position
		circle.BackgroundColor3 = Color3.new(1, 1, 1)
		circle.BackgroundTransparency = 0.6
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = circle
		circle.Parent = frame
	end
	zone("Thumbstick", if small then 140 else 200, UDim2.new(0, 30, 1, -(if small then 170 else 240)))
	zone("Jump", if small then 70 else 120, UDim2.new(1, -(if small then 95 else 170), 1, -(if small then 90 else 210)))
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function ScreenScale.attach(screenGui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromScale(0, 0)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root

	local phone = debugPhone()
	if phone then
		-- Aperçu : un cadre de la taille du téléphone, au centre de l'écran de Studio.
		local frame = Instance.new("Frame")
		frame.Name = "PhonePreview"
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromOffset(phone.X, phone.Y - PHONE_INSET)
		frame.BackgroundTransparency = 1
		frame.ClipsDescendants = true
		frame.Parent = screenGui
		root.Parent = frame
		task.defer(drawControls, phone)
	else
		root.Parent = screenGui
	end

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
