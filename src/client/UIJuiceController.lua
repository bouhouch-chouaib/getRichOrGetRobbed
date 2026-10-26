--!strict
-- UIJuiceController : effets des interfaces (« jus », phase 1.8, dataset_and_pipeline/UI_UX_GUIDELINES.md §4),
-- réutilisables par tous les menus :
--   UIJuice.button(button)                 survol 1,06 (rebond), appui 0,92, relâché avec rebond, « pop » au clic ;
--   UIJuice.pop(object, amount?)           l'objet grossit d'un coup puis revient en rebondissant ;
--   UIJuice.denied(target)                 refus (pas assez d'argent) : secousse, éclair rouge, son grave ;
--   UIJuice.purchased(target, from, layer) achat : la carte saute, pièces et étoiles jaillissent de `from` ;
--   UIJuice.countTo(label, from, to, fmt)  compteur qui défile jusqu'à la nouvelle valeur ;
--   UIJuice.followMenus(isOpen)            tant qu'une fenêtre est ouverte, la caméra zoome un peu (FOV).
-- Un objet qu'on secoue ou fait sauter doit avoir son propre support : une grille (UIGridLayout / UIListLayout) place
-- le support, l'effet bouge l'objet DANS ce support (sinon la mise en page annule le mouvement).
-- Un bouton animé ici est créé avec UiStyle.button(..., true) (sans UiStyle.bounce : un seul UIScale par bouton).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Icons = require(ReplicatedStorage.Shared.Icons)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local UiStyle = require(script.Parent.UiStyle)

local UIJuice = {}

UIJuice.HOVER_SCALE = 1.06
UIJuice.PRESS_SCALE = 0.92
UIJuice.FOV_ZOOM = 6 -- degrés de champ de vision en moins pendant qu'une fenêtre est ouverte

local HOVER = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local RED = Color3.fromRGB(255, 40, 40)

-- Le UIScale de l'objet (créé au besoin).
local function scaleOf(object: GuiObject): UIScale
	local found = object:FindFirstChildOfClass("UIScale")
	if found then
		return found
	end
	local scale = Instance.new("UIScale")
	scale.Name = "JuiceScale"
	scale.Parent = object
	return scale
end

function UIJuice.button(button: GuiButton, sound: string?)
	local scale = scaleOf(button)
	-- Au doigt, pas de survol : il resterait coincé après un appui (pas de « sortie » du doigt).
	local hover = not ScreenScale.isTouch()
	local hovered = false
	local held = false
	button.MouseEnter:Connect(function()
		if not hover then
			return
		end
		hovered = true
		UiStyle.sweep(button)
		if not held then
			TweenService:Create(scale, HOVER, { Scale = UIJuice.HOVER_SCALE }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		hovered, held = false, false
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		held = true
		TweenService:Create(scale, PRESS, { Scale = UIJuice.PRESS_SCALE }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		held = false
		TweenService:Create(scale, RELEASE, { Scale = if hovered then UIJuice.HOVER_SCALE else 1 }):Play()
	end)
	button.Activated:Connect(function()
		Sounds.play(sound or "UiClick")
	end)
end

function UIJuice.pop(object: GuiObject, amount: number?)
	local scale = scaleOf(object)
	scale.Scale = 1 + (amount or 0.12)
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
end

-- Éclair coloré par-dessus un objet (mêmes coins arrondis), qui s'efface.
local function flash(target: GuiObject, color: Color3, duration: number)
	local layer = Instance.new("Frame")
	layer.Name = "JuiceFlash"
	layer.BackgroundColor3 = color
	layer.BackgroundTransparency = 0.3
	layer.BorderSizePixel = 0
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 40
	local corner = target:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = layer
	end
	layer.Parent = target
	TweenService:Create(layer, TweenInfo.new(duration, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	task.delay(duration + 0.05, function()
		layer:Destroy()
	end)
end

local shaking: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function UIJuice.denied(target: GuiObject)
	Sounds.play("Error")
	flash(target, RED, 0.45)
	if shaking[target] then
		return
	end
	shaking[target] = true
	local origin = target.Position
	task.spawn(function()
		for _, dx in ipairs({ -12, 10, -8, 6, -3, 0 }) do
			TweenService:Create(target, TweenInfo.new(0.04, Enum.EasingStyle.Sine), { Position = origin + UDim2.fromOffset(dx, 0) }):Play()
			task.wait(0.04)
		end
		target.Position = origin
		shaking[target] = nil
	end)
end

-- Pièces et étoiles qui jaillissent du centre de `from`, dessinées dans `layer` (un cadre qui ne coupe pas ses enfants,
-- au-dessus du contenu). Positions en pourcentage du calque : justes quelle que soit la mise à l'échelle de l'écran.
function UIJuice.burst(from: GuiObject, layer: GuiObject, count: number?)
	local size = layer.AbsoluteSize
	if size.X < 1 or size.Y < 1 then
		return
	end
	local center = from.AbsolutePosition + from.AbsoluteSize / 2 - layer.AbsolutePosition
	local origin = UDim2.fromScale(center.X / size.X, center.Y / size.Y)
	local images = { Icons.id("Money") or "", Icons.id("Sparkle") or "" }
	for index = 1, count or 14 do
		local piece = Instance.new("ImageLabel")
		piece.Name = "JuicePiece"
		piece.BackgroundTransparency = 1
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Image = images[index % #images + 1]
		piece.ScaleType = Enum.ScaleType.Fit
		local side = math.random(22, 38)
		piece.Size = UDim2.fromOffset(side, side)
		piece.Position = origin
		piece.Rotation = math.random(-30, 30)
		piece.ZIndex = layer.ZIndex + 1
		piece.Parent = layer
		-- Vers le haut surtout, en éventail.
		local angle = math.rad(math.random(-160, -20))
		local distance = math.random(70, 150)
		local time = 0.55 + math.random() * 0.35
		local target = origin + UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance)
		TweenService:Create(piece, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = target, Rotation = piece.Rotation + math.random(-120, 120) }):Play()
		TweenService:Create(piece, TweenInfo.new(time * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, time * 0.5),
			{ ImageTransparency = 1, Size = UDim2.fromOffset(side * 0.4, side * 0.4) }):Play()
		task.delay(time + 0.05, function()
			piece:Destroy()
		end)
	end
end

function UIJuice.purchased(target: GuiObject, from: GuiObject?, layer: GuiObject?)
	UIJuice.pop(target, 0.1)
	flash(target, Color3.new(1, 1, 1), 0.3)
	if layer then
		UIJuice.burst(from or target, layer)
	end
end

local counters: { [TextLabel]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Fait défiler le texte de `label` de `from` à `to` (format(nombre) -> texte), ralentit à la fin.
function UIJuice.countTo(label: TextLabel, from: number, to: number, format: (number) -> string, duration: number?)
	local token = (counters[label] or 0) + 1
	counters[label] = token
	local time = duration or 0.6
	local started = os.clock()
	task.spawn(function()
		while counters[label] == token and label.Parent do
			local t = math.min(1, (os.clock() - started) / time)
			label.Text = format(from + (to - from) * (1 - (1 - t) ^ 3))
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Zoom de la caméra tant que isOpen() est vrai (MenuKit.anyOpen : n'importe quelle fenêtre ouverte).
function UIJuice.followMenus(isOpen: () -> boolean)
	local baseFov: number? = nil
	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local open = isOpen()
		if open and not baseFov then
			baseFov = camera.FieldOfView
			TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { FieldOfView = camera.FieldOfView - UIJuice.FOV_ZOOM }):Play()
		elseif not open and baseFov then
			TweenService:Create(camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { FieldOfView = baseFov }):Play()
			baseFov = nil
		end
	end)
end

return UIJuice
