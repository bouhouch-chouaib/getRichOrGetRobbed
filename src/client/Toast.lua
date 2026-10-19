--!strict
-- Toast : message temporaire en bandeau (16 oct., façon packs « Studs UI ») : une bande de couleur qui s'efface sur les
-- côtés, texte blanc épais à contour noir. Il arrive en grossissant, les plus anciens remontent et s'effacent (3 au
-- plus à l'écran). Utilisable par tous les scripts client : Toast.show("Texte", couleur?)

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ScreenScale = require(script.Parent.ScreenScale)

local Toast = {}

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Toasts"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(gui)

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local HEIGHT = 50
local GAP = 6
local MAX_SHOWN = 3
local LIFETIME = 2.6
-- Au milieu de l'écran : au-dessus du panneau du tutoriel et des capsules de tirage, sous le bandeau d'éclosion.
local BASE_Y = 0.44

type Banner = { frame: Frame, scale: UIScale, slot: number, alive: boolean }
local banners: { Banner } = {}

local function place(banner: Banner)
	TweenService:Create(banner.frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad),
		{ Position = UDim2.new(0.5, 0, BASE_Y, -(banner.slot - 1) * (HEIGHT + GAP)) }):Play()
end

local function remove(banner: Banner)
	if not banner.alive then
		return
	end
	banner.alive = false
	local index = table.find(banners, banner)
	if index then
		table.remove(banners, index)
	end
	local fade = TweenInfo.new(0.3)
	TweenService:Create(banner.scale, fade, { Scale = 0.85 }):Play()
	for _, child in ipairs(banner.frame:GetDescendants()) do
		if child:IsA("TextLabel") then
			TweenService:Create(child, fade, { TextTransparency = 1 }):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, fade, { Transparency = 1 }):Play()
		end
	end
	TweenService:Create(banner.frame, fade, { BackgroundTransparency = 1 }):Play()
	task.delay(0.32, function()
		banner.frame:Destroy()
	end)
end

function Toast.show(message: string, color: Color3?)
	local tint = color or WHITE
	-- Les anciens montent d'une place ; au-delà de MAX_SHOWN, le plus vieux s'en va.
	for _, banner in ipairs(banners) do
		banner.slot += 1
		place(banner)
	end
	while #banners >= MAX_SHOWN do
		remove(banners[#banners])
	end

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, BASE_Y, 0)
	frame.Size = UDim2.fromOffset(980, HEIGHT)
	frame.BorderSizePixel = 0
	-- Bande : la couleur du message, assombrie pour que le texte blanc ressorte, effacée sur les côtés.
	frame.BackgroundColor3 = WHITE
	frame.BackgroundTransparency = 0.1
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.22, 0.05),
		NumberSequenceKeypoint.new(0.78, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Color = ColorSequence.new(tint:Lerp(BLACK, 0.2), tint:Lerp(BLACK, 0.45))
	fade.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(0.74, 0, 0, HEIGHT - 10)
	label.FontFace = Typography.Face
	label.Text = message
	label.TextColor3 = WHITE
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 34
	limit.Parent = label
	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Color = BLACK
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Parent = label
	label.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = frame
	frame.Parent = root
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local banner: Banner = { frame = frame, scale = scale, slot = 1, alive = true }
	table.insert(banners, 1, banner)
	task.delay(LIFETIME, function()
		remove(banner)
	end)
end

return Toast
