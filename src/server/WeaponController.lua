--!strict
-- WeaponController : armes de PvP achetées dans la boutique (Config.Shop, Id "Weapon..."), réglages Config.Weapons.
--   - Une arme achetée est un Tool rangé dans l'inventaire du joueur (barre en bas, touches 1, 2, 3), redonné à
--     chaque réapparition. La possession est le niveau d'amélioration (1 = achetée) : déjà sauvegardé par SessionData.
--   - Clic avec l'arme en main : tous les clients animent le geste (Remotes.WeaponFx "Swing", client/WeaponFx). Au moment
--     fort du geste (StrikeAt), le SERVEUR cherche la cible (le joueur le plus proche devant soi, ou tous ceux autour
--     pour une arme de zone), l'éjecte (Remotes.Knockback avec durée de KO : son client le fait tourner dans les airs) et
--     lui fait tout lâcher (ItemInteraction.ReleaseHeld) : un voleur touché perd le familier qu'il portait (StealController).
--     Impact vu par tous : onomatopée, étoiles (Remotes.WeaponFx "Hit").
--   - Mains : une arme en main empêche de ramasser un objet ou de voler (ItemInteraction, StealController) ; porter
--     un objet ou un familier volé empêche de sortir une arme (rangée tout de suite ici).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ItemInteraction = require(script.Parent.ItemInteraction)
local SessionData = require(script.Parent.SessionData)
local TrainingController = require(script.Parent.TrainingController)

local WeaponController = {}

local WEAPONS = Config.Weapons
local SWING_SOUND = "rbxassetid://" .. Config.Sounds.Effects.Throw.Id
local HIT_SOUND = "rbxassetid://" .. Config.Sounds.Effects.Knockback.Id

local immuneUntil: { [Player]: number } = {}

local shopNames: { [string]: Config.ShopItem } = {}
for _, item in ipairs(Config.Shop) do
	if WEAPONS.List[item.Id] then
		shopNames[item.Id] = item
	end
end

----------------------------------------------------------------------
-- Modèles des armes (pièces simples soudées à la poignée)
----------------------------------------------------------------------

local function piece(tool: Tool, handle: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = material
	part.Shape = shape or Enum.PartType.Block
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	part.Parent = tool
	return part
end

local function makeHandle(tool: Tool, size: Vector3, color: Color3, material: Enum.Material): Part
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = color
	handle.Material = material
	handle.CanCollide = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool
	return handle
end

local BUILDERS: { [string]: (Tool) -> () } = {
	-- Grosse main rouge cartoon.
	WeaponSlap = function(tool: Tool)
		local red = Color3.fromRGB(235, 60, 60)
		local handle = makeHandle(tool, Vector3.new(0.6, 1.2, 0.6), Color3.fromRGB(250, 240, 230), Enum.Material.SmoothPlastic)
		piece(tool, handle, Vector3.new(1.8, 1.9, 0.6), CFrame.new(0, 1.5, 0), red, Enum.Material.SmoothPlastic)
		for index = 0, 3 do
			piece(tool, handle, Vector3.new(0.4, 1.1, 0.5), CFrame.new(-0.66 + index * 0.44, 2.9, 0), red, Enum.Material.SmoothPlastic)
		end
		piece(tool, handle, Vector3.new(0.45, 1, 0.5), CFrame.new(1.15, 1.6, 0) * CFrame.Angles(0, 0, math.rad(-35)), red, Enum.Material.SmoothPlastic)
	end,
	-- Poêle noire au fond violet étoilé.
	WeaponPan = function(tool: Tool)
		local handle = makeHandle(tool, Vector3.new(0.35, 1.8, 0.35), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
		piece(tool, handle, Vector3.new(0.3, 2.8, 2.8), CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(45, 45, 52), Enum.Material.Metal, Enum.PartType.Cylinder)
		local inside = piece(tool, handle, Vector3.new(0.32, 2.3, 2.3), CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 60, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(200, 150, 255)
		sparkles.Parent = inside
	end,
	-- Bâton doré surmonté d'une boule d'énergie.
	WeaponShockwave = function(tool: Tool)
		local handle = makeHandle(tool, Vector3.new(0.35, 3, 0.35), Color3.fromRGB(255, 200, 40), Enum.Material.Foil)
		local orb = piece(tool, handle, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 2, 0), Color3.fromRGB(90, 230, 255), Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = orb.Color
		light.Range = 8
		light.Parent = orb
	end,
}

local function buildTool(weaponId: string): Tool
	local item = shopNames[weaponId]
	local tool = Instance.new("Tool")
	tool.Name = if item then item.Name else weaponId
	tool.ToolTip = if item then item.Description else ""
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponId", weaponId)
	local builder = BUILDERS[weaponId]
	if builder then
		builder(tool)
	end
	-- La poignée (axe Y) dans la main, l'arme dressée vers l'avant.
	tool.Grip = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	local swing = Instance.new("Sound")
	swing.Name = "Swing"
	swing.SoundId = SWING_SOUND
	swing.Volume = 0.6
	swing.Parent = tool:FindFirstChild("Handle")
	return tool
end

----------------------------------------------------------------------
-- Coups
----------------------------------------------------------------------

local function getRoot(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Éjecte la victime loin de "from" et lui fait tout lâcher. Son client la fait tourner dans les airs pendant
-- def.Stun secondes (Remotes.Knockback avec durée de KO) ; tout le monde voit l'impact (Remotes.WeaponFx "Hit").
local function hit(victim: Player, from: Vector3, weaponId: string, def: Config.WeaponDef)
	local character = victim.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = getRoot(character)
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	immuneUntil[victim] = os.clock() + WEAPONS.HitImmunity
	TrainingController.Stop(victim) -- frappé sur le tapis / le banc : il en descend (sinon il serait ancré)

	ItemInteraction.ReleaseHeld(victim) -- objets lâchés ; un vol en cours échoue (StealController)
	if character then
		humanoid:UnequipTools()
	end
	root.CFrame += Vector3.new(0, 1, 0)
	local flat = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	local direction = if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector * -1
	Remotes.Knockback:FireClient(victim, direction * def.Push + Vector3.new(0, def.Up, 0), def.Stun)
	Remotes.WeaponFx:FireAllClients("Hit", victim, weaponId)

	local sound = Instance.new("Sound")
	sound.SoundId = HIT_SOUND
	sound.Volume = 0.9
	sound.Parent = root
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- Onde visible pour tous : anneau qui grandit et s'efface.
local function shockwaveEffect(position: Vector3, radius: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(90, 230, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.Parent = Workspace
	local tween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	})
	tween.Completed:Once(function()
		ring:Destroy()
	end)
	tween:Play()
end

-- Le coup part au moment fort du geste (def.StrikeAt) : on cherche la cible à cet instant-là.
local function strike(player: Player, tool: Tool, weaponId: string, def: Config.WeaponDef)
	local root = getRoot(player.Character)
	if not root or tool.Parent ~= player.Character then
		return
	end
	if def.Area then
		shockwaveEffect(root.Position, def.Range)
	end

	local now = os.clock()
	local reach = def.Range + WEAPONS.RangeMargin
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local best: Player? = nil
	local bestDistance = math.huge
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = getRoot(other.Character)
		if other ~= player and otherRoot and (immuneUntil[other] or 0) <= now then
			local offset = otherRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance <= reach then
				if def.Area then
					hit(other, root.Position, weaponId, def)
				else
					local flat = Vector3.new(offset.X, 0, offset.Z)
					-- Devant soi (cône large) ; tout près, même un peu de côté.
					local inFront = flat.Magnitude < 2.5 or look:Dot(flat.Unit) > 0.2
					if inFront and distance < bestDistance then
						best = other
						bestDistance = distance
					end
				end
			end
		end
	end
	if best then
		hit(best, root.Position, weaponId, def)
	end
end

local function onActivated(player: Player, tool: Tool, weaponId: string, def: Config.WeaponDef)
	local root = getRoot(player.Character)
	if not root or tool.Parent ~= player.Character or not tool.Enabled then
		return
	end
	tool.Enabled = false
	task.delay(def.Cooldown, function()
		tool.Enabled = true
	end)

	-- Le geste est animé par chaque client (client/WeaponFx), le son part avec lui.
	Remotes.WeaponFx:FireAllClients("Swing", player, weaponId)
	local swing = tool:FindFirstChild("Swing", true)
	if swing and swing:IsA("Sound") then
		swing:Play()
	end
	task.delay(def.SwingTime * def.StrikeAt, strike, player, tool, weaponId, def)
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
	for _, item in ipairs(Config.Shop) do
		local def = WEAPONS.List[item.Id]
		if def and SessionData.GetUpgradeLevel(player, item.Id) >= 1 and not hasTool(player, item.Id) then
			local tool = buildTool(item.Id)
			tool.Activated:Connect(function()
				onActivated(player, tool, item.Id, def)
			end)
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
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			watchCharacter(player, player.Character)
		end
		-- Achat dans la boutique, ou sauvegarde chargée après l'arrivée : l'arme apparaît dans l'inventaire.
		for weaponId in pairs(WEAPONS.List) do
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
	end)
end

return WeaponController
