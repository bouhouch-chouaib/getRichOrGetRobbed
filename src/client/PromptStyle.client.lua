--!strict
-- Présentation commune des interactions. Le ProximityPrompt conserve ses contrôles,
-- sa durée d'appui, sa visibilité et sa validation serveur d'origine.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Typography = require(ReplicatedStorage.Shared.Typography)
local UiStyle = require(script.Parent.UiStyle)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local active: { [ProximityPrompt]: () -> () } = {}
local WIDTH, HEIGHT = 150, 40 -- encart discret, touche et action restent lisibles

local function hide(prompt: ProximityPrompt)
	local cleanup = active[prompt]
	if cleanup then
		cleanup()
	end
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	hide(prompt)
	local parent = prompt.Parent
	local adornee: Instance? = parent
	if parent and parent:IsA("Model") then
		adornee = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true)
	end
	if not adornee or not (adornee:IsA("BasePart") or adornee:IsA("Attachment")) then
		return
	end
	local connections: { RBXScriptConnection } = {}
	local gui = Instance.new("BillboardGui")
	gui.Name = "StyledInteraction"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.1, 0)
	gui.AlwaysOnTop, gui.Active, gui.LightInfluence = true, true, 0
	gui.ResetOnSpawn = false
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = UiStyle.Colors.Panel
	button.BackgroundTransparency = 0.3
	button.Parent = gui
	UiStyle.corner(button, 6)
	UiStyle.stroke(button, 1.5, Color3.new(), true)
	local key = Instance.new("TextLabel")
	key.Position, key.Size = UDim2.fromOffset(6, 7), UDim2.fromOffset(26, 26)
	key.TextColor3 = Color3.new(1, 1, 1)
	key.FontFace = Typography.Face
	key.Parent = button
	Typography.Fit(key, 16, 9)
	UiStyle.corner(key, 5)
	UiStyle.stroke(key, 1.5)
	-- Manette : l'image du vrai bouton (X sur Xbox, carré sur PlayStation) à la place de la lettre.
	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromScale(0.9, 0.9)
	glyph.Visible = false
	glyph.Parent = key
	local action = UiStyle.text(button, prompt.ActionText, 14)
	action.Position, action.Size = UDim2.fromOffset(40, 3), UDim2.fromOffset(104, 18)
	action.TextXAlignment = Enum.TextXAlignment.Left
	Typography.Fit(action, 14, 9)
	local object = UiStyle.text(button, prompt.ObjectText, 10, UiStyle.Colors.PanelText)
	object.Position, object.Size = UDim2.fromOffset(40, 22), UDim2.fromOffset(104, 13)
	object.TextXAlignment = Enum.TextXAlignment.Left
	Typography.Fit(object, 10, 8)
	local progress = Instance.new("Frame")
	progress.BorderSizePixel = 0
	progress.AnchorPoint, progress.Position = Vector2.new(0, 1), UDim2.fromScale(0, 1)
	progress.Size = UDim2.new(0, 0, 0, 2)
	progress.Parent = button
	local holding: Tween? = nil
	local pressed: InputObject? = nil
	local function stopProgress()
		if holding then
			holding:Cancel()
			holding = nil
		end
		progress.Size = UDim2.new(0, 0, 0, 2)
	end
	local function release()
		if pressed then
			pressed = nil
			if prompt.Parent then
				prompt:InputHoldEnd()
			end
		end
	end
	local function refresh()
		action.Text, object.Text = prompt.ActionText, prompt.ObjectText
		object.Visible = prompt.ObjectText ~= ""
		action.Position = UDim2.fromOffset(40, if object.Visible then 3 else 11)
		gui.SizeOffset = Vector2.new(prompt.UIOffset.X / WIDTH, prompt.UIOffset.Y / HEIGHT)
		gui.AutoLocalize, action.AutoLocalize, object.AutoLocalize =
			prompt.AutoLocalize, prompt.AutoLocalize, prompt.AutoLocalize
		local words = string.lower(prompt.ActionText .. " " .. prompt.ObjectText)
		local color = if string.find(words, "vol", 1, true) or string.find(words, "duel", 1, true)
			then UiStyle.Colors.Red
			elseif
				string.find(words, "évol", 1, true) or string.find(words, "fusion", 1, true)
			then UiStyle.Colors.Purple
			elseif
				string.find(words, "acheter", 1, true) or string.find(words, "ramasser", 1, true)
			then UiStyle.Colors.Green
			else UiStyle.Colors.Cyan
		key.BackgroundColor3, progress.BackgroundColor3 = color, color
		glyph.Visible = false
		if inputType == Enum.ProximityPromptInputType.Touch then
			key.Text = "ICI"
		elseif inputType == Enum.ProximityPromptInputType.Gamepad then
			local image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
			glyph.Image = image
			glyph.Visible = image ~= ""
			key.Text = if image ~= "" then "" else string.gsub(prompt.GamepadKeyCode.Name, "Button", "")
		else
			local mapped = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
			key.Text = if mapped ~= "" then mapped else prompt.KeyboardKeyCode.Name
		end
	end
	table.insert(connections, prompt.Changed:Connect(refresh))
	table.insert(
		connections,
		prompt.PromptButtonHoldBegan:Connect(function()
			stopProgress()
			if prompt.HoldDuration > 0 then
				local tween = TweenService:Create(
					progress,
					TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
					{ Size = UDim2.new(1, 0, 0, 2) }
				)
				holding = tween
				tween:Play()
			end
		end)
	)
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(stopProgress))
	table.insert(
		connections,
		button.InputBegan:Connect(function(input)
			if pressed then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.Touch
				or (input.UserInputType == Enum.UserInputType.MouseButton1 and prompt.ClickablePrompt)
			then
				pressed = input
				prompt:InputHoldBegin()
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if
				input == pressed
				or (
					pressed
					and input.UserInputType == Enum.UserInputType.MouseButton1
					and pressed.UserInputType == Enum.UserInputType.MouseButton1
				)
			then
				release()
			end
		end)
	)
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(release))
	active[prompt] = function()
		active[prompt] = nil
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		release()
		stopProgress()
		gui:Destroy()
	end
	table.insert(
		connections,
		prompt.Destroying:Connect(function()
			hide(prompt)
		end)
	)
	refresh()
	gui.Parent = playerGui
end

ProximityPromptService.PromptShown:Connect(show)
ProximityPromptService.PromptHidden:Connect(hide)
local function style(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
	end
end
Workspace.DescendantAdded:Connect(style)
for _, instance in ipairs(Workspace:GetDescendants()) do
	style(instance)
end
