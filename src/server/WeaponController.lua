--!strict
-- WeaponController : les deux armes de PvP achetées dans la boutique (Config.Shop), réglages Config.Weapons.
--   - BATTE ("WeaponBat") : clic -> tous les clients animent le grand coup (Remotes.WeaponFx "Swing", client/WeaponFx).
--     Au moment fort du geste (StrikeAt), le SERVEUR cherche le joueur le plus proche devant soi, l'éjecte
--     (Remotes.Knockback avec durée de KO) et lui fait tout lâcher (ItemInteraction.ReleaseHeld) : un voleur touché
--     perd le familier qu'il portait (StealController). Impact vu par tous (Remotes.WeaponFx "Hit").
--   - GRAPPIN ("WeaponGrapple") : clic -> le client envoie la direction visée (Remotes.UseGrapple). Le SERVEUR choisit la
--     cible (joueur dans un cône autour de la visée, à portée, sans mur entre les deux, pas dans sa propre base), puis :
--     tous les clients voient le crochet partir, accrocher et la corde se rembobiner (Remotes.WeaponFx "Grapple"), et la
--     victime est ramenée devant le tireur par son propre client (Remotes.Grappled : il est propriétaire de son
--     personnage, comme pour le Knockback). Raté : le crochet part dans le vide et revient.
--   - Une arme achetée est un Tool rangé dans l'inventaire (touches 1, 2), redonné à chaque réapparition.
--   - Mains : une arme en main empêche de ramasser un objet ou de voler (ItemInteraction, StealController) ; porter
--     un objet ou un familier volé empêche de sortir une arme (rangée tout de suite ici).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local PowerController = require(script.Parent.PowerController)
local SessionData = require(script.Parent.SessionData)
local TrainingController = require(script.Parent.TrainingController)

local WeaponController = {}

local WEAPONS = Config.Weapons
local BAT = WEAPONS.Bat
local GRAPPLE = WEAPONS.Grapple
local SOUNDS = Config.Sounds.Effects

local BAT_ID = "WeaponBat"
local GRAPPLE_ID = "WeaponGrapple"
local POWER_ID = "PowerInvisible" -- pouvoir d'invisibilité (server/PowerController), rangé avec les armes
local WEAPON_IDS = { BAT_ID, GRAPPLE_ID, POWER_ID }

local immuneUntil: { [Player]: number } = {} -- batte : pas deux coups de suite sur le même joueur
local recentHits: { [Player]: { number } } = {} -- batte : heures des derniers coups reçus (Config.Weapons.HitWindow)

-- La batte peut-elle toucher ce joueur maintenant ? Protégé juste après un coup (HitImmunity), et au plus
-- MaxHitsPerWindow coups sur HitWindow secondes (anti-acharnement).
local function canBat(victim: Player, now: number): boolean
	if (immuneUntil[victim] or 0) > now then
		return false
	end
	local hits = recentHits[victim]
	if not hits then
		return true
	end
	local count = 0
	for _, at in ipairs(hits) do
		if now - at < WEAPONS.HitWindow then
			count += 1
		end
	end
	return count < WEAPONS.MaxHitsPerWindow
end
local grappleImmuneUntil: { [Player]: number } = {} -- grappin : pas rattrapé en boucle
local grappleReadyAt: { [Player]: number } = {}

local shopItems: { [string]: Config.ShopItem } = {}
for _, item in ipairs(Config.Shop) do
	shopItems[item.Id] = item
end

----------------------------------------------------------------------
-- Modèles (pièces soudées à la poignée, axe Y de la poignée = axe de l'arme)
----------------------------------------------------------------------

local UP = CFrame.Angles(0, 0, math.pi / 2) -- cylindre dressé sur l'axe Y

local function piece(tool: Tool, handle: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	part.Parent = tool
	return part
end

local function makeHandle(tool: Tool, size: Vector3, color: Color3): Part
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = color
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool
	return handle
end

local function attachment(parent: BasePart, name: string, position: Vector3)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
end

-- Batte de baseball cartoon : manche entouré de ruban, fût en bois qui s'élargit, bande rouge, embout arrondi.
local function buildBat(tool: Tool)
	local wood = Color3.fromRGB(222, 160, 92)
	local woodDark = Color3.fromRGB(176, 112, 58)
	local handle = makeHandle(tool, Vector3.new(0.42, 1.5, 0.42), Color3.fromRGB(40, 40, 46))
	piece(tool, handle, "Knob", Vector3.new(0.3, 0.62, 0.62), CFrame.new(0, -0.85, 0) * UP, Color3.fromRGB(30, 30, 34), Enum.PartType.Cylinder)
	for index, y in ipairs({ -0.45, 0.05, 0.55 }) do
		piece(tool, handle, "Tape" .. index, Vector3.new(0.12, 0.47, 0.47), CFrame.new(0, y, 0) * UP, Color3.fromRGB(230, 60, 60), Enum.PartType.Cylinder)
	end
	piece(tool, handle, "Barrel1", Vector3.new(1.1, 0.5, 0.5), CFrame.new(0, 1.3, 0) * UP, wood, Enum.PartType.Cylinder)
	piece(tool, handle, "Barrel2", Vector3.new(1, 0.66, 0.66), CFrame.new(0, 2.3, 0) * UP, wood, Enum.PartType.Cylinder)
	piece(tool, handle, "Band", Vector3.new(0.22, 0.7, 0.7), CFrame.new(0, 2.9, 0) * UP, Color3.fromRGB(230, 60, 60), Enum.PartType.Cylinder)
	local tip = piece(tool, handle, "Barrel3", Vector3.new(1.3, 0.82, 0.82), CFrame.new(0, 3.65, 0) * UP, wood, Enum.PartType.Cylinder)
	piece(tool, handle, "Cap", Vector3.new(0.82, 0.82, 0.82), CFrame.new(0, 4.3, 0), woodDark, Enum.PartType.Ball)
	-- Points d'accroche de la traînée du coup (client/WeaponFx).
	attachment(handle, "TrailBottom", Vector3.new(0, 1.2, 0))
	attachment(handle, "TrailTop", Vector3.new(0, 4.6, 0))
	tip:SetAttribute("Sweet", true)
end

-- Pistolet-grappin : crosse, corps bleu, gros barillet, bobine de corde, crochet à trois griffes au bout du canon.
-- Repère : poignée sur l'axe Y, canon vers -Z.
local function buildGrapple(tool: Tool)
	local blue = Color3.fromRGB(60, 150, 255)
	local dark = Color3.fromRGB(40, 44, 56)
	local steel = Color3.fromRGB(200, 205, 215)
	local handle = makeHandle(tool, Vector3.new(0.42, 1.1, 0.55), dark)
	piece(tool, handle, "Body", Vector3.new(0.62, 0.72, 2), CFrame.new(0, 0.75, -0.55), blue)
	piece(tool, handle, "Stripe", Vector3.new(0.64, 0.16, 2.02), CFrame.new(0, 0.95, -0.55), Color3.fromRGB(255, 210, 60))
	piece(tool, handle, "Barrel", Vector3.new(1, 0.5, 0.5), CFrame.new(0, 0.75, -1.9) * CFrame.Angles(0, math.pi / 2, 0), steel, Enum.PartType.Cylinder)
	piece(tool, handle, "Spool", Vector3.new(0.5, 0.75, 0.75), CFrame.new(0.45, 0.75, -0.3), Color3.fromRGB(150, 95, 55), Enum.PartType.Cylinder)
	piece(tool, handle, "Trigger", Vector3.new(0.14, 0.32, 0.14), CFrame.new(0, 0.25, -0.35), dark)
	-- Crochet (caché pendant qu'il vole : le client en dessine une copie).
	local claw = Instance.new("Model")
	claw.Name = "Claw"
	local hub = piece(tool, handle, "Hub", Vector3.new(0.44, 0.44, 0.44), CFrame.new(0, 0.75, -2.5), steel, Enum.PartType.Ball)
	hub.Parent = claw
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3
		local prong = piece(tool, handle, "Prong", Vector3.new(0.14, 0.14, 0.62), CFrame.new(0, 0.75, -2.5) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.2, -0.25) * CFrame.Angles(math.rad(35), 0, 0), steel)
		prong.Parent = claw
	end
	claw.Parent = tool
	attachment(handle, "Muzzle", Vector3.new(0, 0.75, -2.35))
end

-- Orbe fantôme (pouvoir d'invisibilité) : sphère violette translucide, cœur lumineux, petits yeux de fantôme.
local function buildOrb(tool: Tool)
	local handle = makeHandle(tool, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(40, 30, 60))
	local shell = piece(tool, handle, "Shell", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 0.75, 0), Color3.fromRGB(190, 150, 255), Enum.PartType.Ball, Enum.Material.Glass)
	shell.Transparency = 0.35
	local core = piece(tool, handle, "Core", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 0.75, 0), Color3.fromRGB(160, 90, 255), Enum.PartType.Ball, Enum.Material.Neon)
	for _, x in ipairs({ -0.17, 0.17 }) do
		piece(tool, handle, "Eye", Vector3.new(0.12, 0.2, 0.08), CFrame.new(x, 0.82, -0.36), Color3.fromRGB(20, 10, 40))
	end
	local light = Instance.new("PointLight")
	light.Color = core.Color
	light.Range = 7
	light.Brightness = 1.2
	light.Parent = core
end

local function buildTool(weaponId: string): Tool
	local item = shopItems[weaponId]
	local tool = Instance.new("Tool")
	tool.Name = if item then item.Name else weaponId
	tool.ToolTip = if item then item.Description else ""
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponId", weaponId)
	if weaponId == POWER_ID then
		buildOrb(tool)
		tool.Grip = CFrame.new(0, 0, 0.2)
	elseif weaponId == BAT_ID then
		buildBat(tool)
		-- Batte dans le prolongement de l'avant-bras (la pose « sur l'épaule » et le coup : client/WeaponFx).
		tool.Grip = CFrame.new(0, -0.55, 0) * CFrame.Angles(math.rad(90), 0, 0)
	else
		buildGrapple(tool)
		-- Canon vers l'avant de la main.
		tool.Grip = CFrame.new(0, -0.1, 0.1)
	end
	return tool
end

----------------------------------------------------------------------
-- Outils communs
----------------------------------------------------------------------

local function getRoot(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- L'arme `weaponId` est-elle en main ?
local function heldTool(player: Player, weaponId: string): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return if tool and tool:GetAttribute("WeaponId") == weaponId then tool else nil
end

-- Son 3D à l'endroit de l'action (entendu par les joueurs proches).
local function soundAt(part: BasePart, name: string)
	local def = SOUNDS[name]
	if not def then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. def.Id
	sound.Volume = def.Volume or 1
	sound.PlaybackSpeed = def.Pitch or 1
	sound.RollOffMaxDistance = 140
	sound.Parent = part
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(8, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Le joueur se tient-il dans sa propre base ? (zone protégée du grappin)
local function isInOwnBase(player: Player, position: Vector3): boolean
	local base = BaseManager.GetBase(player)
	local platform = base and base:FindFirstChild("BasePart")
	if not platform or not platform:IsA("BasePart") then
		return false
	end
	local localPosition = platform.CFrame:PointToObjectSpace(position)
	local half = platform.Size / 2 + Vector3.new(1.5, 0, 1.5)
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y > -3 and localPosition.Y < 25
end

----------------------------------------------------------------------
-- Batte
----------------------------------------------------------------------

-- Éjecte la victime loin de `from` et lui fait tout lâcher. Son client la fait tourner dans les airs pendant
-- BAT.Stun secondes (Remotes.Knockback avec durée de KO) ; tout le monde voit l'impact (Remotes.WeaponFx "Hit").
local function batHit(attacker: Player, victim: Player, from: Vector3)
	local character = victim.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = getRoot(character)
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	immuneUntil[victim] = now + WEAPONS.HitImmunity
	local hits = recentHits[victim] or {}
	table.insert(hits, now)
	while #hits > WEAPONS.MaxHitsPerWindow do
		table.remove(hits, 1)
	end
	recentHits[victim] = hits
	PowerController.Reveal(victim)
	TrainingController.Stop(victim) -- frappé sur le tapis / le banc : il en descend (sinon il serait ancré)
	ItemInteraction.ReleaseHeld(victim) -- objets lâchés ; un vol en cours échoue (StealController)
	humanoid:UnequipTools()
	root.CFrame += Vector3.new(0, 1, 0)
	local flat = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	local direction = if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector * -1
	Remotes.Knockback:FireClient(victim, direction * BAT.Push + Vector3.new(0, BAT.Up, 0), BAT.Stun)
	Remotes.WeaponFx:FireAllClients("Hit", victim, BAT_ID, attacker)
	soundAt(root, "BatHit")
end

-- Le coup part au moment fort du geste : on cherche la cible à cet instant-là.
local function batStrike(player: Player, tool: Tool)
	local root = getRoot(player.Character)
	if not root or tool.Parent ~= player.Character then
		return
	end
	local now = os.clock()
	local reach = BAT.Range + WEAPONS.RangeMargin
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local best: Player? = nil
	local bestDistance = math.huge
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = getRoot(other.Character)
		if other ~= player and otherRoot and isAlive(other) and canBat(other, now) then
			local offset = otherRoot.Position - root.Position
			local distance = offset.Magnitude
			local flat = Vector3.new(offset.X, 0, offset.Z)
			-- Devant soi (cône large) ; tout près, même un peu de côté.
			local inFront = flat.Magnitude < 2.5 or look:Dot(flat.Unit) > 0.25
			if distance <= reach and inFront and distance < bestDistance then
				best = other
				bestDistance = distance
			end
		end
	end
	if best then
		batHit(player, best, root.Position)
	end
end

local function onBatActivated(player: Player, tool: Tool)
	local root = getRoot(player.Character)
	if not root or tool.Parent ~= player.Character or not tool.Enabled then
		return
	end
	tool.Enabled = false
	task.delay(BAT.Cooldown, function()
		tool.Enabled = true
	end)
	PowerController.Reveal(player)
	Remotes.WeaponFx:FireAllClients("Swing", player, BAT_ID)
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		task.delay(BAT.SwingTime * 0.25, soundAt, handle, "BatSwing")
	end
	task.delay(BAT.SwingTime * BAT.StrikeAt, batStrike, player, tool)
end

----------------------------------------------------------------------
-- Grappin
----------------------------------------------------------------------

local function grappleParams(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(exclude)
	local map = Workspace:FindFirstChild("Map")
	for _, name in ipairs({ "LooseItems", "WildItems" }) do
		local folder = map and map:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	params.FilterDescendantsInstances = list
	return params
end

local function onUseGrapple(player: Player, direction: unknown)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local aim = direction :: Vector3
	if aim.Magnitude < 0.5 or aim.Magnitude > 1.5 or aim ~= aim then
		return
	end
	aim = aim.Unit
	local tool = heldTool(player, GRAPPLE_ID)
	local character = player.Character
	local root = getRoot(character)
	local head = character and character:FindFirstChild("Head")
	local now = os.clock()
	if not tool or not root or not head or not head:IsA("BasePart") or not isAlive(player) or now < (grappleReadyAt[player] or 0) then
		return
	end
	grappleReadyAt[player] = now + GRAPPLE.Cooldown
	PowerController.Reveal(player)
	tool.Enabled = false
	task.delay(GRAPPLE.Cooldown, function()
		tool.Enabled = true
	end)

	local origin = head.Position
	local cone = math.cos(math.rad(GRAPPLE.AimCone))
	local best: Player? = nil
	local bestScore = -math.huge
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = getRoot(other.Character)
		if other ~= player and otherRoot and isAlive(other) and (grappleImmuneUntil[other] or 0) <= now then
			local offset = otherRoot.Position - origin
			local distance = offset.Magnitude
			local dot = if distance > 0 then aim:Dot(offset.Unit) else -1
			if distance <= GRAPPLE.Range + WEAPONS.RangeMargin and dot >= cone and not isInOwnBase(other, otherRoot.Position) then
				-- Pas de mur entre les deux.
				local blocked = Workspace:Raycast(origin, offset, grappleParams({ character :: Model, other.Character :: Model }))
				local score = dot - distance / 1000
				if not blocked and score > bestScore then
					best = other
					bestScore = score
				end
			end
		end
	end

	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		soundAt(handle, "GrappleFire")
	end
	if not best then
		-- Raté : le crochet part dans le vide (ou jusqu'au mur) et revient.
		local result = Workspace:Raycast(origin, aim * GRAPPLE.Range, grappleParams({ character :: Model }))
		local point = if result then result.Position else origin + aim * GRAPPLE.Range
		Remotes.WeaponFx:FireAllClients("Grapple", player, GRAPPLE_ID, point, nil)
		return
	end
	local victim = best :: Player
	local victimRoot = getRoot(victim.Character) :: BasePart
	grappleImmuneUntil[victim] = now + GRAPPLE.PullTime + 1.5
	PowerController.Reveal(victim)
	TrainingController.Stop(victim)
	Remotes.WeaponFx:FireAllClients("Grapple", player, GRAPPLE_ID, victimRoot.Position, victim)
	-- Le crochet met un peu de temps à arriver : la traction commence à l'impact.
	local flight = (victimRoot.Position - origin).Magnitude / GRAPPLE.HookSpeed
	task.delay(flight, function()
		if victim.Parent and isAlive(victim) then
			Remotes.Grappled:FireClient(victim, player, GRAPPLE.PullTime)
			local victimPart = getRoot(victim.Character)
			if victimPart then
				soundAt(victimPart, "GrappleLatch")
			end
		end
	end)
end

----------------------------------------------------------------------
-- Inventaire
----------------------------------------------------------------------

local function hasTool(player: Player, weaponId: string): boolean
	local containers: { Instance? } = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for index = 1, 2 do
		local container = containers[index]
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("WeaponId") == weaponId then
					return true
				end
			end
		end
	end
	return false
end

-- Donne au joueur les armes achetées qui ne sont pas déjà dans son inventaire.
local function giveWeapons(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	for _, weaponId in ipairs(WEAPON_IDS) do
		if SessionData.GetUpgradeLevel(player, weaponId) >= 1 and not hasTool(player, weaponId) then
			local tool = buildTool(weaponId)
			if weaponId == BAT_ID then
				tool.Activated:Connect(function()
					onBatActivated(player, tool)
				end)
			elseif weaponId == POWER_ID then
				tool.Activated:Connect(function()
					PowerController.Activate(player)
				end)
			end
			-- Grappin : le clic est lu par le client (il faut la direction visée) -> Remotes.UseGrapple.
			tool.Parent = backpack
		end
	end
end

-- Mains prises (objets portés ou familier volé) : l'arme sortie est rangée tout de suite.
local function watchCharacter(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and (ItemInteraction.GetHeldCount(player) > 0 or player:GetAttribute("CarryingPet") ~= nil) then
			task.defer(function()
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and child.Parent == character then
					humanoid:UnequipTools()
				end
			end)
		end
	end)
	task.defer(giveWeapons, player)
end

function WeaponController.Init()
	Remotes.UseGrapple.OnServerEvent:Connect(onUseGrapple)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			watchCharacter(player, player.Character)
		end
		-- Achat dans la boutique, ou sauvegarde chargée après l'arrivée : l'arme apparaît dans l'inventaire.
		for _, weaponId in ipairs(WEAPON_IDS) do
			player:GetAttributeChangedSignal("Upgrade_" .. weaponId):Connect(function()
				giveWeapons(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		immuneUntil[player] = nil
		recentHits[player] = nil
		grappleImmuneUntil[player] = nil
		grappleReadyAt[player] = nil
	end)
end

return WeaponController
