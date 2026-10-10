--!strict
-- LeaderboardController : tableau des plus riches planté dans l'arène (Workspace.Map.Leaderboard.Screen).
-- Toutes les Config.Leaderboard.RefreshInterval secondes :
--   1. l'argent de chaque joueur du serveur est écrit dans un OrderedDataStore (seulement s'il a changé) ;
--   2. le top Config.Leaderboard.Size de TOUS les serveurs est relu et affiché sur les deux faces du panneau.
-- L'OrderedDataStore ne sert qu'à l'affichage : la vraie sauvegarde reste dans SessionData (verrou de session).
-- Si le DataStore est indisponible (Studio sans accès API), le tableau montre les joueurs du serveur.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local SessionData = require(script.Parent.SessionData)

local SETTINGS = Config.Leaderboard
local IS_STUDIO = RunService:IsStudio()
-- Même règle de nom que SessionData : version + magasin séparé dans Studio.
local STORE_NAME = "RichestBoard_v" .. Config.Save.Version .. (if IS_STUDIO then "_studio" else "")
-- Un OrderedDataStore ne range que des entiers (max 2^63) : on range log10(argent + 1) × SCALE.
-- L'ordre est conservé et ça tient jusqu'aux plus grands nombres du jeu (précision largement suffisante pour l'affichage abrégé).
local SCALE = 1e12
local PIXELS_PER_STUD = 30

local RANK_COLORS = {
	Color3.fromRGB(255, 205, 50), -- or
	Color3.fromRGB(215, 225, 235), -- argent
	Color3.fromRGB(230, 150, 90), -- bronze
}
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local MONEY_COLOR = Color3.fromRGB(120, 255, 120)

type Entry = { userId: number, name: string, money: number }
type Row = { frame: Frame, rank: TextLabel, avatar: ImageLabel, name: TextLabel, money: TextLabel }

local LeaderboardController = {}

local store: OrderedDataStore? = nil
local lastWritten: { [number]: number } = {} -- UserId -> dernière valeur écrite (évite les écritures inutiles)
local names: { [number]: string } = {} -- cache UserId -> nom
local faces: { { rows: { Row }, subtitle: TextLabel } } = {}

local function encode(money: number): number
	return math.floor(math.log10(math.max(money, 0) + 1) * SCALE + 0.5)
end

local function decode(value: number): number
	-- Arrondi : sans lui, 120 $ reviendrait en 119,9999 (affiché "119").
	return math.max(math.floor(10 ^ (value / SCALE) - 1 + 0.5), 0)
end

-- Studio sans "Enable Studio Access to API Services" : inutile de réessayer chaque minute.
local function disableIfNoApi(err: unknown): boolean
	local message = tostring(err)
	if string.find(message, "Studio access to APIs is not allowed", 1, true)
		or string.find(message, "API access is not enabled", 1, true)
	then
		store = nil
		warn("[Leaderboard] Accès API désactivé dans Studio : le tableau affiche seulement les joueurs du serveur.")
		return true
	end
	return false
end

local function getName(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.Name
		return player.Name
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(result) == "string" then
		names[userId] = result
		return result
	end
	return "???" -- pas mis en cache : on réessaiera au prochain rafraîchissement
end

local function styleText(label: TextLabel, color: Color3, alignment: Enum.TextXAlignment)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = color
	label.TextXAlignment = alignment
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
end

-- Construit une face du panneau (titre, sous-titre, lignes vides).
local function buildFace(screen: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.MaxDistance = 300
	gui.Adornee = screen

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromScale(0.05, 0.02)
	title.Size = UDim2.fromScale(0.9, 0.13)
	title.Text = "🏆 LES PLUS RICHES"
	styleText(title, RANK_COLORS[1], Enum.TextXAlignment.Center)
	title.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.fromScale(0.1, 0.15)
	subtitle.Size = UDim2.fromScale(0.8, 0.06)
	subtitle.Text = "Chargement..."
	styleText(subtitle, Color3.fromRGB(200, 190, 230), Enum.TextXAlignment.Center)
	subtitle.Parent = gui

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.23)
	list.Size = UDim2.fromScale(0.92, 0.75)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list

	local rows: { Row } = {}
	for index = 1, SETTINGS.Size do
		local frame = Instance.new("Frame")
		frame.Name = "Row_" .. index
		frame.LayoutOrder = index
		frame.Size = UDim2.new(1, 0, 1 / SETTINGS.Size, -4)
		frame.BackgroundColor3 = if index % 2 == 0 then Color3.fromRGB(60, 50, 88) else Color3.fromRGB(74, 62, 108)
		frame.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = frame

		local rank = Instance.new("TextLabel")
		rank.Name = "Rank"
		rank.Position = UDim2.fromScale(0.01, 0.1)
		rank.Size = UDim2.fromScale(0.09, 0.8)
		rank.Text = "#" .. index
		styleText(rank, RANK_COLORS[index] or TEXT_COLOR, Enum.TextXAlignment.Center)
		rank.Parent = frame

		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.BackgroundTransparency = 1
		avatar.Position = UDim2.fromScale(0.11, 0.05)
		avatar.Size = UDim2.fromScale(0.9, 0.9)
		avatar.SizeConstraint = Enum.SizeConstraint.RelativeYY
		avatar.Parent = frame

		local name = Instance.new("TextLabel")
		name.Name = "PlayerName"
		name.Position = UDim2.fromScale(0.19, 0.12)
		name.Size = UDim2.fromScale(0.5, 0.76)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		styleText(name, TEXT_COLOR, Enum.TextXAlignment.Left)
		name.Parent = frame

		local money = Instance.new("TextLabel")
		money.Name = "Money"
		money.Position = UDim2.fromScale(0.7, 0.12)
		money.Size = UDim2.fromScale(0.28, 0.76)
		styleText(money, MONEY_COLOR, Enum.TextXAlignment.Right)
		money.Parent = frame

		frame.Parent = list
		table.insert(rows, { frame = frame, rank = rank, avatar = avatar, name = name, money = money })
	end

	gui.Parent = screen
	table.insert(faces, { rows = rows, subtitle = subtitle })
end

local function render(entries: { Entry }, subtitle: string)
	for _, face in ipairs(faces) do
		face.subtitle.Text = subtitle
		for index, row in ipairs(face.rows) do
			local entry = entries[index]
			row.frame.Visible = entry ~= nil
			if entry then
				row.name.Text = entry.name
				row.money.Text = NumberFormat.money(entry.money)
				row.avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", entry.userId)
			end
		end
	end
end

-- Écrit l'argent d'un joueur (seulement si sa sauvegarde est chargée et que la valeur a changé).
local function writePlayer(player: Player)
	local data = SessionData.Get(player)
	if not store or not data or not data.loaded then
		return
	end
	local value = encode(data.money)
	local userId = player.UserId
	if lastWritten[userId] == value then
		return
	end
	local currentStore = store :: OrderedDataStore
	local ok, err = pcall(function()
		currentStore:SetAsync("u_" .. userId, value)
	end)
	if ok then
		lastWritten[userId] = value
	elseif not disableIfNoApi(err) then
		warn("[Leaderboard] Écriture impossible pour " .. player.Name .. " : " .. tostring(err))
	end
end

-- Top de tous les serveurs ; nil si le DataStore ne répond pas.
local function readGlobal(): { Entry }?
	if not store then
		return nil
	end
	local currentStore = store :: OrderedDataStore
	local ok, result = pcall(function()
		return currentStore:GetSortedAsync(false, SETTINGS.Size):GetCurrentPage()
	end)
	if not ok then
		if disableIfNoApi(result) then
			return nil
		end
		warn("[Leaderboard] Lecture du classement impossible : " .. tostring(result))
		return nil
	end
	local entries: { Entry } = {}
	for _, item in ipairs(result :: { any }) do
		local userId = tonumber(string.match(tostring(item.key), "^u_(%d+)$"))
		if userId and type(item.value) == "number" then
			table.insert(entries, { userId = userId, name = getName(userId), money = decode(item.value) })
		end
	end
	return entries
end

-- Repli : les joueurs de ce serveur, du plus riche au plus pauvre.
local function readServer(): { Entry }
	local entries: { Entry } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = SessionData.Get(player)
		if data then
			table.insert(entries, { userId = player.UserId, name = player.Name, money = data.money })
		end
	end
	table.sort(entries, function(a, b)
		return a.money > b.money
	end)
	while #entries > SETTINGS.Size do
		table.remove(entries)
	end
	return entries
end

local function refresh()
	for _, player in ipairs(Players:GetPlayers()) do
		writePlayer(player)
	end
	local global = readGlobal()
	if global then
		render(global, "Tous les serveurs • mis à jour chaque minute")
	else
		render(readServer(), "Joueurs de ce serveur")
	end
end

function LeaderboardController.Init()
	local map = Workspace:WaitForChild("Map")
	local screen = map:WaitForChild("Leaderboard"):WaitForChild("Screen") :: BasePart
	buildFace(screen, Enum.NormalId.Front)
	buildFace(screen, Enum.NormalId.Back)

	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Leaderboard] Classement global indisponible, affichage du serveur seulement : " .. tostring(result))
	end

	-- Dernière écriture au départ : l'argent gagné depuis le dernier rafraîchissement compte aussi.
	Players.PlayerRemoving:Connect(function(player)
		writePlayer(player)
		lastWritten[player.UserId] = nil
	end)

	task.spawn(function()
		task.wait(5) -- laisse le temps aux premières sauvegardes de se charger
		while true do
			refresh()
			task.wait(SETTINGS.RefreshInterval)
		end
	end)
end

return LeaderboardController
