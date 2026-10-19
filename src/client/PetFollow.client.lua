--!strict
-- PetFollow : affiche les familiers équipés de TOUS les joueurs, qui les suivent, et le familier que porte un
-- joueur (avec son nom et le temps restant) : tenu à deux mains au-dessus de la tête, bras levés, qui rebondit
-- un peu à chaque pas. Jeté dans le trou (Remotes.HoleEvent "Sacrifice") : grand geste des deux bras (élan en
-- arrière, lancer, accompagnement, Config.Sacrifice.Throw) ; les mains le lâchent à Release et client/BlackholeFx
-- le fait voler depuis là (il retrouve le modèle grâce à l'attribut "HeldBy").
-- Rendu 100 % local (aucune réplication réseau) à partir des attributs "Equipped", "CarryingPet",
-- "CarryingUntil" et "CarryingFrom" de chaque Player.
-- Si le joueur local est la victime ("CarryingFrom" = son UserId) : le voleur est entouré de rouge (visible à
-- travers les murs) et seule la victime voit la bulle [E] "Reprendre" posée par le serveur sur le voleur.

local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local PetSizes = require(ReplicatedStorage.Shared.PetSizes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local Joints = require(script.Parent.Joints)

-- Positions derrière le joueur selon le nombre de familiers équipés (X, Z).
local SLOTS = {
	Vector2.new(0, 4),
	Vector2.new(-3, 3.5),
	Vector2.new(3, 3.5),
	Vector2.new(-1.5, 6.5),
	Vector2.new(1.5, 6.5),
}
local FLOAT_OFFSET = 1.2 -- pour les familiers qui volent
local SMOOTHNESS = 10

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = Workspace

type Follower = { model: Model, float: boolean, current: CFrame?, bottom: number, depth: number }
local followers: { [Player]: { Follower } } = {}

-- Familier porté au-dessus de la tête, posé sur les deux mains.
local CARRY_SCALE = 0.6 -- plus petit que dans la base : un gros familier ne cache pas la vue du porteur
local CARRY_MAX = PetSizes.CARRY_MAX * PetSizes.PLAYER -- studs : hauteur max tenu à bout de bras
local GRIP_LOW = 0.3 -- les mains le serrent sur les côtés, au tiers bas de son corps
local HEAD_GAP = 0.15 -- studs : jamais posé sur la tête
local THROW = Config.Sacrifice.Throw
-- mine : c'est MON familier qu'il porte ; bottom : du pivot du modèle au bas de son corps ; width / height : son corps
type Carried = { model: Model, timer: TextLabel, mine: boolean, bottom: number, width: number, height: number }
local carried: { [Player]: Carried } = {}
-- Lancers en cours (le familier reste dans les mains jusqu'à Release, les bras finissent le geste jusqu'à End).
type Throw = { model: Model?, bottom: number, width: number, height: number, start: number }
local throws: { [Player]: Throw } = {}

local localPlayer = Players.LocalPlayer

local function clear(player: Player)
	local list = followers[player]
	if list then
		for _, follower in ipairs(list) do
			follower.model:Destroy()
		end
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local equipped = player:GetAttribute("Equipped")
	if type(equipped) ~= "string" or equipped == "" then
		return
	end
	local list = {}
	for petId in string.gmatch(equipped, "[^,]+") do
		local model = PetModelBuilder.Build(petId)
		if model then
			-- Les géants de la base sont réduits quand ils suivent le joueur (sinon ils cachent la vue).
			local _, fullSize = PetModelBuilder.BodyBounds(model)
			local followMax = PetSizes.FOLLOW_MAX * PetSizes.PLAYER
			if fullSize.Y > followMax then
				model:ScaleTo(model:GetScale() * followMax / fullSize.Y)
			end
			local bodyBox, bodySize = PetModelBuilder.BodyBounds(model)
			model:SetAttribute("OwnerUserId", player.UserId) -- client/InvisibilityFx
			model.Parent = folder
			table.insert(list, { model = model, float = model:GetAttribute("Float") == true, current = nil,
				bottom = bodySize.Y / 2 - bodyBox.Position.Y, depth = bodySize.Z })
		end
	end
	followers[player] = list
end

local function clearCarried(player: Player)
	local entry = carried[player]
	if entry then
		entry.model:Destroy()
	end
	carried[player] = nil
end

-- Construit le familier porté et son étiquette (nom en couleur de rareté + temps restant).
local function rebuildCarried(player: Player)
	clearCarried(player)
	local petId = player:GetAttribute("CarryingPet")
	if type(petId) ~= "string" then
		return
	end
	local model = PetModelBuilder.Build(petId)
	local entry = PetCatalog.ById[petId]
	local root = model and model.PrimaryPart
	if not model or not entry or not root then
		return
	end
	local _, fullSize = PetModelBuilder.BodyBounds(model)
	model:SetAttribute("MotionCarried", true)
	model:SetAttribute("HeldBy", player.UserId) -- client/BlackholeFx : le lancer part de là
	model:ScaleTo(model:GetScale() * math.min(CARRY_SCALE, CARRY_MAX / math.max(fullSize.Y, 0.1)))
	local bodyBox, size = PetModelBuilder.BodyBounds(model)
	local bottom = size.Y / 2 - model:GetPivot():PointToObjectSpace(bodyBox.Position).Y
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
	local sign = Instance.new("BillboardGui")
	sign.Name = "StolenLabel"
	sign.Adornee = root
	sign.Size = UDim2.fromScale(8, 2.6)
	sign.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.8, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 150
	local function line(text: string, color: Color3, y: number, height: number): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.FontFace = Typography.Face
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		local outline = Instance.new("UIStroke")
		outline.Thickness = 2.5
		outline.Parent = label
		label.Parent = sign
		return label
	end
	local stolen = player:GetAttribute("CarryingOwn") ~= true
	line((if stolen then "VOL ! " else "") .. TextFormat.upper(entry.Name), rarity.Color, 0, 0.55)
	local timer = line("", Color3.fromRGB(255, 90, 90), 0.55, 0.45)
	-- Le voleur lui-même voit son objectif dans la consigne du HUD (l'étiquette serait cachée par le titre).
	sign.Enabled = player ~= localPlayer
	sign.Parent = model

	-- C'est mon familier : le voleur est entouré de rouge, même derrière un mur, pour que je puisse le rattraper.
	local mine = player:GetAttribute("CarryingFrom") == localPlayer.UserId
	if mine and player.Character then
		local highlight = Instance.new("Highlight")
		highlight.Name = "ThiefHighlight"
		highlight.Adornee = player.Character
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = Color3.fromRGB(255, 60, 60)
		highlight.FillTransparency = 0.75
		highlight.OutlineColor = Color3.fromRGB(255, 40, 40)
		highlight.Parent = model -- détruit avec le modèle à la fin du vol
	end

	model.Parent = folder
	carried[player] = { model = model, timer = timer, mine = mine, bottom = bottom, width = size.X, height = size.Y }
end

-- Jeté dans le trou : le familier porté passe dans les lancers (l'attribut CarryingPet s'efface juste après, il ne
-- doit pas le détruire) ; son étiquette et le contour rouge disparaissent tout de suite.
Remotes.HoleEvent.OnClientEvent:Connect(function(kind: string, _from: any, _petId: any, carrier: any)
	if kind ~= "Sacrifice" or typeof(carrier) ~= "Instance" or not carrier:IsA("Player") then
		return
	end
	local entry = carried[carrier]
	local old = throws[carrier]
	if old and old.model then
		old.model:Destroy()
	end
	if entry then
		carried[carrier] = nil
		for _, name in ipairs({ "StolenLabel", "ThiefHighlight" }) do
			local child = entry.model:FindFirstChild(name)
			if child then
				child:Destroy()
			end
		end
		throws[carrier] = { model = entry.model, bottom = entry.bottom, width = entry.width, height = entry.height, start = os.clock() }
	else
		-- Attribut déjà effacé (ordre réseau inhabituel) : on joue quand même le geste, BlackholeFx part de la tête.
		throws[carrier] = { model = nil, bottom = 0, width = 1, height = 1, start = os.clock() }
	end
end)

local function watch(player: Player)
	player:GetAttributeChangedSignal("Equipped"):Connect(function()
		rebuild(player)
	end)
	player:GetAttributeChangedSignal("CarryingPet"):Connect(function()
		rebuildCarried(player)
	end)
	player:GetAttributeChangedSignal("CarryingFrom"):Connect(function()
		rebuildCarried(player)
	end)
	rebuild(player)
	rebuildCarried(player)
end

Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player: Player)
	clear(player)
	clearCarried(player)
	local throw = throws[player]
	if throw and throw.model then
		throw.model:Destroy()
	end
	throws[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end

-- Les vrais modèles 3D (shared/PetMeshes) viennent d'être chargés : on reconstruit ce qui est déjà affiché.
PetModelBuilder.MeshesReady:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		rebuild(player)
		rebuildCarried(player)
	end
end)

----------------------------------------------------------------------
-- Bras : porter à deux mains au-dessus de la tête, puis lancer
--   pitch : bras levé vers l'avant (90 = tendu devant, 180 = au-dessus de la tête, plus = vers l'arrière)
--   roll  : bras penché vers la tête (> 0 = vers l'intérieur), calculé pour que les mains serrent le familier sur
--           ses côtés (gripRoll) ; elbow : coude plié (même sens que pitch)
--   lean  : torse penché (> 0 = en arrière)
----------------------------------------------------------------------

type ArmPose = { pitch: number, roll: number, elbow: number, lean: number }
type ArmKey = { t: number, pose: ArmPose }

local HOLD: ArmPose = { pitch = 168, roll = 14, elbow = 18, lean = 0 }
local THROW_KEYS: { ArmKey } = {
	{ t = 0, pose = HOLD },
	{ t = THROW.WindUp, pose = { pitch = 200, roll = 10, elbow = 45, lean = 12 } }, -- élan : loin derrière la tête
	{ t = THROW.Release, pose = { pitch = 128, roll = 6, elbow = 4, lean = -10 } }, -- lancer : les mains le lâchent
	{ t = THROW.Release + 0.15, pose = { pitch = 72, roll = 4, elbow = 10, lean = -16 } }, -- accompagnement
	{ t = THROW.End, pose = { pitch = 8, roll = 0, elbow = 6, lean = 0 } }, -- retour, bras le long du corps
}

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

local function sampleThrow(t: number): ArmPose
	for index = 1, #THROW_KEYS - 1 do
		local a, b = THROW_KEYS[index], THROW_KEYS[index + 1]
		if t <= b.t then
			local raw = math.clamp((t - a.t) / math.max(b.t - a.t, 1e-3), 0, 1)
			-- Le lancer part sec (accélère jusqu'au lâcher), le reste est adouci.
			local k = if index == 2 then raw * raw else smooth(raw)
			local p, q = a.pose, b.pose
			return {
				pitch = p.pitch + (q.pitch - p.pitch) * k,
				roll = p.roll + (q.roll - p.roll) * k,
				elbow = p.elbow + (q.elbow - p.elbow) * k,
				lean = p.lean + (q.lean - p.lean) * k,
			}
		end
	end
	return THROW_KEYS[#THROW_KEYS].pose
end

-- Inclinaison des bras pour que les mains touchent les côtés d'un familier de cette largeur (d'après la taille de
-- l'avatar : largeur des épaules, longueur des bras).
local function gripRoll(character: Model, width: number): number
	local torso = character:FindFirstChild("UpperTorso")
	local upper = character:FindFirstChild("RightUpperArm")
	local lower = character:FindFirstChild("RightLowerArm")
	local hand = character:FindFirstChild("RightHand")
	if not (torso and upper and lower and hand and torso:IsA("BasePart") and upper:IsA("BasePart")
		and lower:IsA("BasePart") and hand:IsA("BasePart")) then
		return HOLD.roll
	end
	local shoulder = torso.Size.X / 2 + upper.Size.X / 2 -- écart épaule - milieu du corps
	local reach = upper.Size.Y + lower.Size.Y + hand.Size.Y / 2
	local half = math.clamp(width / 2 + hand.Size.X / 2 - 0.1, 0.35, shoulder + 0.8) -- milieu de la main visé
	return math.deg(math.asin(math.clamp((shoulder - half) / reach, -0.6, 0.6)))
end

local function applyArms(character: Model, p: ArmPose)
	for _, side in ipairs({ "Right", "Left" }) do
		local roll = math.rad(if side == "Right" then p.roll else -p.roll)
		local shoulder = Joints.get(character, side .. "UpperArm", side .. "Shoulder")
		if shoulder then
			shoulder.Transform = CFrame.Angles(0, 0, roll) * CFrame.Angles(math.rad(p.pitch), 0, 0)
		end
		local elbow = Joints.get(character, side .. "LowerArm", side .. "Elbow")
		if elbow then
			elbow.Transform = CFrame.Angles(math.rad(p.elbow), 0, 0)
		end
	end
	local waist = Joints.get(character, "UpperTorso", "Waist")
	if waist and p.lean ~= 0 then
		waist.Transform = CFrame.Angles(math.rad(p.lean), 0, 0)
	end
end

-- Après les animations de Roblox (Stepped) : on impose la pose des bras.
RunService.Stepped:Connect(function()
	local now = os.clock()
	for player, entry in pairs(carried) do
		local character = player.Character
		if character then
			applyArms(character, { pitch = HOLD.pitch, roll = gripRoll(character, entry.width), elbow = HOLD.elbow, lean = HOLD.lean })
		end
	end
	for player, throw in pairs(throws) do
		local t = now - throw.start
		local character = player.Character
		if t >= THROW.End then
			if throw.model then
				throw.model:Destroy()
			end
			throws[player] = nil -- les animations normales reprennent d'elles-mêmes
		elseif character then
			-- Les mains gardent leur prise jusqu'au lâcher, puis suivent le geste.
			local p = sampleThrow(t)
			local hold = 1 - math.clamp((t - THROW.WindUp) / (THROW.Release - THROW.WindUp), 0, 1)
			p.roll += (gripRoll(character, throw.width) - HOLD.roll) * hold
			applyArms(character, p)
		end
	end
end)

-- Bas du familier tenu : les mains le serrent au tiers bas de ses côtés, jamais posé sur la tête (sauf pendant
-- l'élan du lancer : il passe derrière la tête, collé aux mains) ; au-dessus de la tête si l'avatar n'a pas de
-- mains R15.
local function gripBottom(character: Model, root: BasePart, height: number, overHead: boolean): Vector3
	local head = character:FindFirstChild("Head")
	local headTop = if head and head:IsA("BasePart") then head.Position.Y + head.Size.Y / 2 else root.Position.Y + 3
	local left = character:FindFirstChild("LeftHand")
	local right = character:FindFirstChild("RightHand")
	if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
		local middle = (left.Position + right.Position) / 2
		local y = middle.Y - height * GRIP_LOW
		return Vector3.new(middle.X, if overHead then math.max(y, headTop + HEAD_GAP) else y, middle.Z)
	end
	local top = if head and head:IsA("BasePart") then head.Position else root.Position
	return Vector3.new(top.X, headTop + 1.2, top.Z)
end

-- Le familier tenu, face à l'avant du porteur, entre ses mains.
local function holdAt(model: Model, character: Model, root: BasePart, bottom: number, height: number, bob: number, overHead: boolean)
	local look = root.CFrame.LookVector
	local flat = CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z))
	model:PivotTo(CFrame.new(gripBottom(character, root, height, overHead) + Vector3.new(0, bottom + bob, 0)) * flat.Rotation)
end

RunService:BindToRenderStep("PetFollowPlacement", Enum.RenderPriority.Last.Value - 10, function(dt: number)
	local now = os.clock()
	local alpha = math.min(1, dt * SMOOTHNESS)
	for player, list in pairs(followers) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		for index, follower in ipairs(list) do
			if root and root:IsA("BasePart") then
				local slot = SLOTS[(index - 1) % #SLOTS + 1]
				local hip = if humanoid then humanoid.HipHeight + (if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0) else 2
				local grounded = -hip - root.Size.Y / 2 + follower.bottom + 0.08
				local height = if follower.float then math.max(FLOAT_OFFSET, grounded + 0.7) + math.sin(now * 2 + index) * 0.4 else grounded
				-- On garde seulement l'orientation horizontale du joueur.
				local look = root.CFrame.LookVector
				local flat = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
				local target = flat * CFrame.new(slot.X, height, math.max(slot.Y, follower.depth * 0.55 + 2.8))
				local current = follower.current or target
				current = current:Lerp(target, alpha)
				follower.current = current
				follower.model:PivotTo(current)
			end
		end
	end

	local serverNow = Workspace:GetServerTimeNow()
	for player, entry in pairs(carried) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			-- Petit rebond à chaque pas quand il marche (le familier pèse dans les bras).
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local bob = if speed > 1 then math.abs(math.sin(now * 9)) * 0.35 * math.min(1, speed / 16) else 0
			holdAt(entry.model, character, root, entry.bottom, entry.height, bob, true)
			-- Bulle "Reprendre" (posée par le serveur) : visible seulement par la victime.
			local prompt = root:FindFirstChild("RecoverPrompt")
			if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled ~= entry.mine then
				prompt.Enabled = entry.mine
			end
		end
		local untilTime = player:GetAttribute("CarryingUntil")
		if type(untilTime) == "number" then
			entry.timer.Text = string.format("%d s", math.max(0, math.ceil(untilTime - serverNow)))
		end
	end

	-- Lancer : le familier suit les mains pendant l'élan, puis disparaît quand BlackholeFx l'a pris en charge.
	for player, throw in pairs(throws) do
		local model = throw.model
		if model then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if now - throw.start >= THROW.Release + 0.05 or not character or not (root and root:IsA("BasePart")) then
				model:Destroy()
				throw.model = nil
			else
				holdAt(model, character, root, throw.bottom, throw.height, 0, false)
			end
		end
	end
end)
