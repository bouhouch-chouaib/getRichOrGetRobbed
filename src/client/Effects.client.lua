--!strict
-- Effets : petits plus qui rendent le jeu satisfaisant (réglages : Config.Effects). Tout est local au joueur.
--   - Points qui s'envolent : "+2.5" doré là où TON objet a été avalé par le trou noir.
--   - Ouverture animée d'un tirage rare (Épique+, tirages et fusion) : boîte "?" qui tremble, puis le familier en 3D.
--   - Secousses d'écran : éjection par le dôme (forte), ouverture rare (moyenne), on vole ton familier (légère).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)

local EFFECTS = Config.Effects
local GOLD = Color3.fromRGB(255, 220, 60)

local player = Players.LocalPlayer

----------------------------------------------------------------------
-- Secousses d'écran
----------------------------------------------------------------------

type Shake = { intensity: number, start: number, duration: number }
local shakes: { Shake } = {}

local function shake(intensity: number, duration: number)
	table.insert(shakes, { intensity = intensity, start = os.clock(), duration = duration })
end

-- Appliqué juste après la caméra de Roblox, qui recalcule sa position à chaque image : rien ne s'accumule.
RunService:BindToRenderStep("ScreenShake", Enum.RenderPriority.Camera.Value + 1, function()
	if #shakes == 0 then
		return
	end
	local now = os.clock()
	local amount = 0
	for index = #shakes, 1, -1 do
		local item = shakes[index]
		local left = 1 - (now - item.start) / item.duration
		if left <= 0 then
			table.remove(shakes, index)
		else
			amount += item.intensity * left * left
		end
	end
	local camera = Workspace.CurrentCamera
	if amount > 0 and camera then
		local t = now * 30
		camera.CFrame *= CFrame.Angles(
			math.noise(t, 1.3) * amount * 0.04,
			math.noise(t, 7.1) * amount * 0.04,
			math.noise(t, 13.7) * amount * 0.03
		)
	end
end)

Remotes.Knockback.OnClientEvent:Connect(function()
	shake(EFFECTS.ShakeKnockback, 0.6)
end)
Remotes.StealNotice.OnClientEvent:Connect(function(kind: string)
	if kind == "Started" then
		shake(EFFECTS.ShakeStealAlarm, 0.5)
	end
end)

----------------------------------------------------------------------
-- Points qui s'envolent
----------------------------------------------------------------------

-- Texte qui monte et s'efface à un endroit du monde (taille fixe à l'écran, visible de loin).
local function floatText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Attachment")
	anchor.Name = "FloatText"
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(220, 70)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.Adornee = anchor
	sign.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	label.Parent = sign

	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(sign, TweenInfo.new(1.3, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, 9, 0) }):Play()
	local fade = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.8)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(outline, fade, { Transparency = 1 }):Play()
	task.delay(1.4, function()
		anchor:Destroy()
	end)
end

-- Endroits où TES objets viennent d'être avalés (le serveur marque l'objet avant d'ajouter les points).
type Swallow = { position: Vector3, time: number }
local swallowed: { Swallow } = {}
local HOLE_TOP = Vector3.new(0, 6, 0)

local function watchLooseItem(item: Instance)
	if not item:IsA("BasePart") then
		return
	end
	item:GetAttributeChangedSignal("Consumed"):Connect(function()
		if item:GetAttribute("Consumed") and item:GetAttribute("Owner") == player.Name then
			table.insert(swallowed, { position = item.Position, time = os.clock() })
		end
	end)
end
task.spawn(function()
	local loose = Workspace:WaitForChild("Map"):WaitForChild("LooseItems")
	loose.ChildAdded:Connect(watchLooseItem)
	for _, item in ipairs(loose:GetChildren()) do
		watchLooseItem(item)
	end
end)

local function formatPoints(value: number): string
	local rounded = math.floor(value * 10 + 0.5) / 10
	return if rounded == math.floor(rounded) then string.format("+%d", rounded) else string.format("+%.1f", rounded)
end

local lastScore = player:GetAttribute("RoundScore")
player:GetAttributeChangedSignal("RoundScore"):Connect(function()
	local score = player:GetAttribute("RoundScore")
	local previous = if type(lastScore) == "number" then lastScore else 0
	lastScore = score
	if type(score) ~= "number" or score <= previous then
		return -- remise à zéro en début de manche
	end
	-- Le plus ancien objet avalé récemment, sinon au-dessus du trou.
	local position = HOLE_TOP
	while #swallowed > 0 do
		local first = table.remove(swallowed, 1) :: Swallow
		if os.clock() - first.time < 2 then
			position = first.position + Vector3.new(0, 3, 0)
			break
		end
	end
	floatText(position, formatPoints(score - previous), GOLD)
end)

----------------------------------------------------------------------
-- Ouverture animée d'un tirage rare
----------------------------------------------------------------------

local revealGui = Instance.new("ScreenGui")
revealGui.Name = "Reveal"
revealGui.ResetOnSpawn = false
revealGui.IgnoreGuiInset = true
revealGui.DisplayOrder = 20
revealGui.Enabled = false
revealGui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(revealGui)

-- Fond sombre cliquable (un clic ferme l'ouverture).
local backdrop = Instance.new("TextButton")
backdrop.Name = "Backdrop"
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 1
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Parent = root

local center = Instance.new("Frame")
center.Name = "Center"
center.BackgroundTransparency = 1
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.45)
center.Size = UDim2.fromOffset(10, 10)
center.Parent = root

-- Rayons de lumière qui tournent derrière (barres fines, sans image).
local rays = Instance.new("Frame")
rays.Name = "Rays"
rays.BackgroundTransparency = 1
rays.AnchorPoint = Vector2.new(0.5, 0.5)
rays.Position = UDim2.fromScale(0.5, 0.5)
rays.Size = UDim2.fromOffset(700, 700)
rays.Parent = center
local rayBars: { Frame } = {}
for index = 0, 7 do
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Size = UDim2.new(0, 46, 1, 0)
	bar.Rotation = index * 22.5
	bar.BorderSizePixel = 0
	bar.BackgroundTransparency = 1
	local fadeEnds = Instance.new("UIGradient")
	fadeEnds.Rotation = 90
	fadeEnds.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fadeEnds.Parent = bar
	bar.Parent = rays
	table.insert(rayBars, bar)
end

-- La boîte mystère.
local box = Instance.new("TextLabel")
box.Name = "Box"
box.AnchorPoint = Vector2.new(0.5, 0.5)
box.Position = UDim2.fromScale(0.5, 0.5)
box.Size = UDim2.fromOffset(170, 170)
box.Font = Enum.Font.LuckiestGuy
box.Text = "?"
box.TextSize = 110
box.TextColor3 = Color3.new(1, 1, 1)
box.Parent = center
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 24)
	round.Parent = box
	local border = Instance.new("UIStroke")
	border.Thickness = 6
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = box
	local textOutline = Instance.new("UIStroke")
	textOutline.Thickness = 5
	textOutline.Parent = box
end
local boxScale = Instance.new("UIScale")
boxScale.Parent = box

-- Le familier révélé.
local viewport = Instance.new("ViewportFrame")
viewport.Name = "Pet"
viewport.AnchorPoint = Vector2.new(0.5, 0.5)
viewport.Position = UDim2.fromScale(0.5, 0.5)
viewport.Size = UDim2.fromOffset(300, 300)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(200, 200, 200)
viewport.LightColor = Color3.new(1, 1, 1)
viewport.Parent = center
local viewportScale = Instance.new("UIScale")
viewportScale.Parent = viewport
local viewCamera = Instance.new("Camera")
viewCamera.FieldOfView = 40
viewCamera.Parent = viewport
viewport.CurrentCamera = viewCamera

local function bigText(name: string, size: number, y: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.5, y)
	label.Size = UDim2.fromOffset(900, size + 10)
	label.Font = Enum.Font.LuckiestGuy
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	local outline = Instance.new("UIStroke")
	outline.Thickness = math.max(3, size / 12)
	outline.Parent = label
	label.Parent = center
	return label
end
local nameLabel = bigText("PetName", 54, 185)
local rarityLabel = bigText("Rarity", 34, 235)
local headerLabel = bigText("Header", 40, -200)
local textScale = Instance.new("UIScale")
textScale.Parent = nameLabel

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Size = UDim2.fromScale(1, 1)
flash.Parent = root

local queue: { string } = {}
local revealing = false
local revealToken = 0
local spinModel: Model? = nil

local function closeReveal()
	revealToken += 1
	revealGui.Enabled = false
	if spinModel then
		spinModel:Destroy()
		spinModel = nil
	end
	revealing = false
end

-- Confettis : petits carrés colorés projetés depuis le centre.
local function confetti(color: Color3)
	local palette = { color, GOLD, Color3.fromRGB(255, 255, 255), Color3.fromRGB(110, 240, 70), Color3.fromRGB(90, 200, 255) }
	for index = 1, 34 do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5, 0.5)
		piece.Size = UDim2.fromOffset(math.random(10, 18), math.random(6, 12))
		piece.BackgroundColor3 = palette[index % #palette + 1]
		piece.BorderSizePixel = 0
		piece.Rotation = math.random(0, 360)
		piece.Parent = center
		local angle = math.random() * math.pi * 2
		local distance = math.random(220, 480)
		local target = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance + 120)
		local info = TweenInfo.new(math.random(9, 14) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(piece, info, { Position = target, Rotation = piece.Rotation + math.random(-360, 360), BackgroundTransparency = 1 }):Play()
		task.delay(1.5, function()
			piece:Destroy()
		end)
	end
end

local reveal: (petId: string) -> ()

local function nextReveal()
	local petId = table.remove(queue, 1)
	if petId then
		reveal(petId)
	end
end

-- Un clic ferme l'ouverture en cours (la suivante, s'il y en a une, s'enchaîne).
backdrop.Activated:Connect(function()
	closeReveal()
	nextReveal()
end)

reveal = function(petId: string)
	local entry = PetCatalog.ById[petId]
	if not entry then
		return nextReveal()
	end
	revealing = true
	revealToken += 1
	local token = revealToken
	local rarityIndex = Config.RarityIndex[entry.Rarity] or 1
	local rarity = Config.Rarities[rarityIndex]
	local color = rarity.Color

	-- Préparation : boîte à la couleur de la rareté, familier caché, textes vides.
	for _, bar in ipairs(rayBars) do
		bar.BackgroundColor3 = color
		bar.BackgroundTransparency = 0
	end
	rays.Rotation = 0
	box.BackgroundColor3 = color
	box.Visible = true
	box.Rotation = 0
	boxScale.Scale = 0.3
	viewport.Visible = false
	nameLabel.Text = ""
	rarityLabel.Text = ""
	headerLabel.Text = "QUELLE CHANCE !"
	headerLabel.TextColor3 = GOLD
	backdrop.BackgroundTransparency = 1
	flash.BackgroundTransparency = 1
	if spinModel then
		spinModel:Destroy()
	end
	local model = PetModelBuilder.Build(petId)
	if model then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant:Destroy()
			end
		end
		model:PivotTo(CFrame.new())
		model.Parent = viewport
	end
	spinModel = model
	revealGui.Enabled = true

	TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.35 }):Play()
	TweenService:Create(boxScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	-- Suspense : la boîte tremble de plus en plus fort.
	task.spawn(function()
		local startTime = os.clock()
		while os.clock() - startTime < 1.1 and token == revealToken do
			local strength = (os.clock() - startTime) / 1.1
			box.Rotation = math.sin(os.clock() * 40) * (4 + strength * 12)
			boxScale.Scale = 1 + math.abs(math.sin(os.clock() * 12)) * 0.08 * strength
			task.wait()
		end
		if token ~= revealToken then
			return
		end
		-- Éclat : flash, la boîte disparaît, le familier apparaît avec son nom.
		box.Visible = false
		flash.BackgroundTransparency = 0.2
		TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		viewport.Visible = true
		viewportScale.Scale = 0.2
		TweenService:Create(viewportScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		nameLabel.Text = TextFormat.upper(entry.Name)
		nameLabel.TextColor3 = color
		rarityLabel.Text = TextFormat.upper(rarity.Name) .. " !"
		rarityLabel.TextColor3 = color
		textScale.Scale = 0.3
		TweenService:Create(textScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		confetti(color)
		shake(EFFECTS.ShakeReveal, 0.4)
		Sounds.play("RareDrop")

		task.wait(EFFECTS.RevealTime - 1.1)
		if token == revealToken then
			closeReveal()
			nextReveal()
		end
	end)
end

-- Rayons qui tournent et familier qui pivote pendant l'ouverture.
RunService.RenderStepped:Connect(function(dt: number)
	if not revealGui.Enabled then
		return
	end
	rays.Rotation += dt * 25
	local model = spinModel
	if model and viewport.Visible then
		local extent = model:GetExtentsSize().Magnitude
		local angle = os.clock() * 1.2
		viewCamera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle), 0.35, -math.cos(angle)).Unit * extent * 1.4, Vector3.zero)
	end
end)

local function queueReveal(petId: string)
	local entry = PetCatalog.ById[petId]
	if not entry or (Config.RarityIndex[entry.Rarity] or 0) < EFFECTS.RevealMinRarity then
		return
	end
	table.insert(queue, petId)
	if not revealing then
		nextReveal()
	end
end

-- Tirages : on révèle le plus rare obtenu (s'il est au moins Épique).
Remotes.RewardsGranted.OnClientEvent:Connect(function(_score: number, _pulls: number, results: { [string]: number })
	local best: string? = nil
	local bestRank = 0
	for petId in pairs(results) do
		local entry = PetCatalog.ById[petId]
		local rank = if entry then Config.RarityIndex[entry.Rarity] or 0 else 0
		if rank > bestRank then
			best, bestRank = petId, rank
		end
	end
	if best then
		queueReveal(best)
	end
end)
Remotes.FusionResult.OnClientEvent:Connect(queueReveal)
