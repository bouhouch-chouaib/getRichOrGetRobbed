--!strict
-- InvisibilityFx : ce qu'on voit du pouvoir d'invisibilité (server/PowerController décide, attributs du Player
-- "InvisibleUntil" / "InvisibleReadyAt", réglages Config.Weapons.Invisibility).
--   - Le joueur invisible se voit à moitié transparent ; les autres le voient presque pas de loin, mais une silhouette
--     fantomatique apparaît quand ils sont tout près, et de petites étincelles trahissent ses pas.
--   - Son nom, ses étiquettes et ses familiers équipés disparaissent avec lui.
--   - Nuage de fumée + son à la disparition et à la réapparition (vu et entendu par les joueurs proches).
--   - Pour le joueur local : pastille « INVISIBLE 4 s » puis « PRÊT DANS 23 S », message quand c'est prêt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local INVISIBILITY = Config.Weapons.Invisibility
local POWER_ID = "PowerInvisible"
local GHOST = Color3.fromRGB(180, 140, 255)

local player = Players.LocalPlayer

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function invisibleUntil(target: Player): number?
	local value = target:GetAttribute("InvisibleUntil")
	return if type(value) == "number" and value > Workspace:GetServerTimeNow() then value else nil
end

----------------------------------------------------------------------
-- Transparence du personnage, de ses étiquettes et de ses familiers
----------------------------------------------------------------------

local affected: { [Player]: boolean } = {}

local function setLook(target: Player, alpha: number)
	local character = target.Character
	local hidden = alpha >= 0.5
	local function onPart(object: Instance)
		if object:IsA("BasePart") or object:IsA("Decal") then
			(object :: any).LocalTransparencyModifier = alpha
		elseif object:IsA("BillboardGui") then
			-- Étiquettes au-dessus de la tête (VIP, familier volé...) : cachées, puis remises comme avant.
			if hidden then
				if object:GetAttribute("InvisWasEnabled") == nil then
					object:SetAttribute("InvisWasEnabled", object.Enabled)
				end
				object.Enabled = false
			else
				local was = object:GetAttribute("InvisWasEnabled")
				if was ~= nil then
					object.Enabled = was == true
					object:SetAttribute("InvisWasEnabled", nil)
				end
			end
		end
	end
	if character then
		for _, object in ipairs(character:GetDescendants()) do
			onPart(object)
		end
	end
	-- Objets rangés pendant l'invisibilité (l'orbe est rangé tout de suite) : remis visibles à la fin.
	local backpack = target:FindFirstChildOfClass("Backpack")
	if backpack and alpha == 0 then
		for _, object in ipairs(backpack:GetDescendants()) do
			onPart(object)
		end
	end
	local pets = Workspace:FindFirstChild("Pets")
	if pets then
		for _, model in ipairs(pets:GetChildren()) do
			if model:GetAttribute("OwnerUserId") == target.UserId then
				model:SetAttribute("AuraHidden", hidden)
				for _, object in ipairs(model:GetDescendants()) do
					onPart(object)
				end
			end
		end
	end
end

-- Étincelles aux pieds pendant que le joueur invisible se déplace (la contre-attaque : on peut le repérer).
local function footsteps(target: Player, enabled: boolean)
	local root = rootOf(target.Character)
	if not root then
		return
	end
	local emitter = root:FindFirstChild("InvisSparkles")
	if not emitter and enabled then
		local created = Instance.new("ParticleEmitter")
		created.Name = "InvisSparkles"
		created.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		created.Color = ColorSequence.new(GHOST, Color3.new(1, 1, 1))
		created.LightEmission = 1
		created.Lifetime = NumberRange.new(0.4, 0.8)
		created.Speed = NumberRange.new(0.5, 2)
		created.SpreadAngle = Vector2.new(60, 60)
		created.Size = NumberSequence.new(0.35, 0)
		created.Transparency = NumberSequence.new(0.2, 1)
		created.Rate = 10
		created.EmissionDirection = Enum.NormalId.Bottom
		created.Parent = root
		emitter = created
	end
	if emitter and emitter:IsA("ParticleEmitter") then
		local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 3
		emitter.Enabled = enabled and moving
	end
end

RunService.RenderStepped:Connect(function()
	local myRoot = rootOf(player.Character)
	for _, target in ipairs(Players:GetPlayers()) do
		if invisibleUntil(target) then
			local alpha: number
			if target == player then
				alpha = INVISIBILITY.SelfTransparency
			else
				local root = rootOf(target.Character)
				local near = myRoot and root and (myRoot.Position - root.Position).Magnitude <= INVISIBILITY.NearDistance
				alpha = if near then INVISIBILITY.NearTransparency else INVISIBILITY.FarTransparency
			end
			setLook(target, alpha)
			footsteps(target, true)
			affected[target] = true
		elseif affected[target] then
			affected[target] = nil
			setLook(target, 0)
			footsteps(target, false)
		end
	end
end)

Players.PlayerRemoving:Connect(function(target: Player)
	affected[target] = nil
end)

----------------------------------------------------------------------
-- Nuage de fumée à la disparition / réapparition
----------------------------------------------------------------------

local function poof(target: Player, vanish: boolean)
	local root = rootOf(target.Character)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(GHOST, Color3.fromRGB(235, 230, 255))
	smoke.LightEmission = 0.3
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Speed = NumberRange.new(6, 12)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	smoke.Transparency = NumberSequence.new(0.2, 1)
	smoke.Rate = 0
	smoke.Parent = attachment
	smoke:Emit(22)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), GHOST)
	sparkles.LightEmission = 1
	sparkles.Lifetime = NumberRange.new(0.4, 0.7)
	sparkles.Speed = NumberRange.new(10, 18)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.8, 0)
	sparkles.Rate = 0
	sparkles.Parent = attachment
	sparkles:Emit(16)
	Sounds.playAt(if vanish then "Vanish" else "Reveal", root.Position)
	task.delay(1.2, function()
		attachment:Destroy()
	end)
end

local function watch(target: Player)
	local was = target:GetAttribute("InvisibleUntil") ~= nil
	target:GetAttributeChangedSignal("InvisibleUntil"):Connect(function()
		local now = target:GetAttribute("InvisibleUntil") ~= nil
		if now ~= was then
			poof(target, now)
		end
		was = now
	end)
end
Players.PlayerAdded:Connect(watch)
for _, target in ipairs(Players:GetPlayers()) do
	watch(target)
end

----------------------------------------------------------------------
-- Pastille du joueur local : durée restante, puis recharge
----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "InvisibilityHud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(gui)

local pill = UiStyle.panel(root, UDim2.fromOffset(250, 48))
pill.AnchorPoint = Vector2.new(0.5, 1)
pill.Position = UDim2.new(0.5, 0, 1, -ScreenScale.BOTTOM_RESERVED)
pill.BackgroundColor3 = UiStyle.Colors.WindowBody
pill.Visible = false
local pillIcon = Icons.image(pill, "Ghost", UDim2.fromOffset(44, 44), UDim2.fromOffset(4, 2))
pillIcon.ZIndex = 2
local pillText = UiStyle.number(pill, "", 26, GHOST)
pillText.Position = UDim2.fromOffset(52, 0)
pillText.Size = UDim2.new(1, -58, 1, 0)
pillText.TextXAlignment = Enum.TextXAlignment.Left
pillText.ZIndex = 2

local function holdsPower(): boolean
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("WeaponId") == POWER_ID
end

local wasCooling = false
RunService.RenderStepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local untilTime = invisibleUntil(player)
	local readyAt = player:GetAttribute("InvisibleReadyAt")
	local cooling = type(readyAt) == "number" and readyAt > now
	if untilTime then
		pill.Visible = true
		pillText.Text = string.format("INVISIBLE  %d s", math.ceil(untilTime - now))
		pillText.TextColor3 = GHOST
	elseif cooling and holdsPower() then
		pill.Visible = true
		pillText.Text = string.format("PRÊT DANS  %d S", math.ceil((readyAt :: number) - now))
		pillText.TextColor3 = Color3.fromRGB(200, 200, 210)
	else
		pill.Visible = false
	end
	-- Recharge terminée : on le dit au joueur.
	if wasCooling and not cooling then
		Toast.show("INVISIBILITÉ PRÊTE !", GHOST)
	end
	wasCooling = cooling
end)

-- Clic refusé (recharge, familier volé porté) : on explique pourquoi.
local function watchTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("WeaponId") ~= POWER_ID or tool:GetAttribute("PowerWired") then
		return
	end
	tool:SetAttribute("PowerWired", true)
	tool.Activated:Connect(function()
		local readyAt = player:GetAttribute("InvisibleReadyAt")
		local now = Workspace:GetServerTimeNow()
		if player:GetAttribute("CarryingPet") ~= nil then
			Sounds.play("Error")
			Toast.show("PAS AVEC UN FAMILIER DANS LES BRAS !", Color3.fromRGB(255, 90, 90))
		elseif type(readyAt) == "number" and readyAt > now then
			Sounds.play("Error")
			Toast.show(string.format("PAS ENCORE ! ATTENDS %d S", math.ceil(readyAt - now)), Color3.fromRGB(255, 90, 90))
		end
	end)
end

local function watchContainer(container: Instance)
	container.ChildAdded:Connect(watchTool)
	for _, child in ipairs(container:GetChildren()) do
		watchTool(child)
	end
end
player.CharacterAdded:Connect(watchContainer)
if player.Character then
	watchContainer(player.Character)
end
task.spawn(function()
	watchContainer(player:WaitForChild("Backpack"))
end)
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		watchContainer(child)
	end
end)
