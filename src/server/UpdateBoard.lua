--!strict
-- UpdateBoard : panneau des nouveautés planté dans l'arène (Workspace.Map.UpdateBoard.Screen, Config.Updates), lisible
-- des deux côtés. Et le message « MISE À JOUR n ! » une fois pour un joueur déjà venu : attribut "NewUpdate" (lu par
-- client/HUD), champ sauvegardé seenUpdate.

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local SessionData = require(script.Parent.SessionData)

local SETTINGS = Config.Updates
local PIXELS_PER_STUD = 30
local GOLD = Color3.fromRGB(255, 205, 50)

local UpdateBoard = {}

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3, alignment: Enum.TextXAlignment): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.FontFace = Typography.Face
	item.TextScaled = true
	item.TextWrapped = true
	item.TextColor3 = color
	item.TextXAlignment = alignment
	item.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = item
	item.Parent = parent
	return item
end

local function buildFace(screen: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.MaxDistance = 300
	gui.Adornee = screen
	label(gui, "NOUVEAUTÉS", UDim2.fromScale(0.15, 0.02), UDim2.fromScale(0.7, 0.14), GOLD, Enum.TextXAlignment.Center)
	for _, x in ipairs({ 0.04, 0.84 }) do
		Icons.image(gui, "Sparkle", UDim2.fromScale(0.12, 0.14), UDim2.fromScale(x, 0.02))
	end
	label(gui, string.format("MISE À JOUR %d", SETTINGS.Number), UDim2.fromScale(0.2, 0.16), UDim2.fromScale(0.6, 0.07),
		Color3.fromRGB(200, 190, 230), Enum.TextXAlignment.Center)
	local count = #SETTINGS.Lines
	local top, bottom = 0.26, 0.86
	local step = (bottom - top) / math.max(count, 1)
	-- Toutes les lignes à la même taille (une phrase longue passe sur 2 lignes au lieu d'être écrite plus petit).
	for index, line in ipairs(SETTINGS.Lines) do
		local y = top + (index - 1) * step
		Icons.image(gui, line.Icon, UDim2.fromScale(0.07, step * 0.85), UDim2.fromScale(0.04, y))
		local text = label(gui, line.Text, UDim2.fromScale(0.13, y), UDim2.fromScale(0.83, step * 0.95), Color3.new(1, 1, 1),
			Enum.TextXAlignment.Left)
		text.TextScaled = false
		text.TextSize = 34
	end
	label(gui, "NOUVELLE MISE À JOUR CHAQUE SAMEDI !", UDim2.fromScale(0.1, 0.89), UDim2.fromScale(0.8, 0.08),
		Color3.fromRGB(120, 255, 120), Enum.TextXAlignment.Center)
	gui.Parent = screen
end

-- Un joueur déjà venu avant cette mise à jour voit le message une fois ; un nouveau joueur ne le voit pas.
local function checkNews(player: Player)
	while player.Parent and not SessionData.IsLoaded(player) do
		task.wait(0.5)
	end
	local data = SessionData.Get(player)
	if not player.Parent or not data or data.seenUpdate >= SETTINGS.Number then
		return
	end
	if data.onboarding.visits > 1 then
		player:SetAttribute("NewUpdate", SETTINGS.Number)
	end
	data.seenUpdate = SETTINGS.Number
end

function UpdateBoard.Init()
	local screen = Workspace:WaitForChild("Map"):WaitForChild("UpdateBoard"):WaitForChild("Screen") :: BasePart
	buildFace(screen, Enum.NormalId.Front)
	buildFace(screen, Enum.NormalId.Back)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(checkNews, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkNews, player)
	end
end

return UpdateBoard
