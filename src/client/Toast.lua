--!strict
-- Toast : gros message cartoon temporaire au centre-bas de l'écran (style Steal a Brainrot).
-- Utilisable par tous les scripts client : Toast.show("Texte", couleur?)

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

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.fromScale(0.5, 0.72)
label.Size = UDim2.fromOffset(800, 50)
label.BackgroundTransparency = 1
label.Font = Enum.Font.LuckiestGuy
label.TextSize = 38
-- Les longs messages (annonces) rétrécissent pour tenir dans la largeur.
label.TextScaled = true
local sizeLimit = Instance.new("UITextSizeConstraint")
sizeLimit.MaxTextSize = 38
sizeLimit.Parent = label
label.TextColor3 = Color3.new(1, 1, 1)
label.Visible = false
label.Parent = ScreenScale.attach(gui)

local outline = Instance.new("UIStroke")
outline.Thickness = 3.5
outline.Color = Color3.new(0, 0, 0)
outline.Parent = label

local scale = Instance.new("UIScale")
scale.Parent = label

local token = 0

function Toast.show(message: string, color: Color3?)
	token += 1
	local current = token

	label.Text = message
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextTransparency = 0
	outline.Transparency = 0
	label.Visible = true
	scale.Scale = 0.5
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	task.delay(1.8, function()
		if current ~= token then
			return
		end
		local fade = TweenInfo.new(0.3)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(outline, fade, { Transparency = 1 }):Play()
		task.delay(0.3, function()
			if current == token then
				label.Visible = false
			end
		end)
	end)
end

return Toast
