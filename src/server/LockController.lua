--!strict
-- LockController : bouton au sol de chaque base (comme Steal a Brainrot).
-- Le propriétaire marche sur le bouton -> la base est fermée pendant Config.Lock.Duration secondes
-- (compte à rebours relancé à chaque passage sur le bouton) :
-- le portail apparaît et tout autre joueur à l'intérieur est expulsé devant l'entrée.
-- Attributs écrits sur la base : "Locked" (bool) et "LockedUntil" (temps serveur).
-- Clé (Config.Keys) : un autre joueur près du portail d'une base FERMÉE l'utilise (Remotes.UseKey, bulle créée par
-- client/BaseKeys) -> la base est ouverte Config.Keys.Duration secondes (attribut "ForcedOpenUntil") : pas d'expulsion,
-- vol possible, même si le propriétaire repasse sur le bouton. Ensuite, elle redevient fermée si le compte à rebours
-- du propriétaire tourne encore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local SessionData = require(script.Parent.SessionData)

local LockController = {}

local TICK = 0.1
local COLOR_OPEN = Color3.fromRGB(220, 50, 50)
local COLOR_LOCKED = Color3.fromRGB(60, 200, 80)

type BaseParts = {
	base: Model,
	platform: BasePart,
	button: BasePart,
	gate: BasePart,
	label: TextLabel?,
}

local entries: { BaseParts } = {}
local lockedUntil: { [Model]: number } = {}
local forcedUntil: { [Model]: number } = {} -- ouverte par une clé jusqu'à cette heure serveur

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function setLocked(entry: BaseParts, locked: boolean)
	entry.base:SetAttribute("Locked", locked)
	entry.gate.Transparency = if locked then 0 else 1
	entry.button.Color = if locked then COLOR_LOCKED else COLOR_OPEN
	if not locked then
		lockedUntil[entry.base] = nil
		entry.base:SetAttribute("LockedUntil", nil)
		if entry.label then
			entry.label.Text = "FERMER LA BASE"
		end
	end
end

-- Base ouverte par une clé : visuellement ouverte, sans toucher au compte à rebours du propriétaire.
local function showForcedOpen(entry: BaseParts)
	entry.base:SetAttribute("Locked", false)
	entry.gate.Transparency = 1
	entry.button.Color = COLOR_OPEN
end

local function isInsideBase(platform: BasePart, position: Vector3): boolean
	local localPosition = platform.CFrame:PointToObjectSpace(position)
	local half = platform.Size / 2 + Vector3.new(1.5, 0, 1.5)
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y > -3 and localPosition.Y < 25
end

local function update(entry: BaseParts, now: number)
	local owner = BaseManager.GetOwner(entry.base)
	local untilTime: number? = lockedUntil[entry.base]

	if untilTime and (not owner or now >= untilTime) then
		setLocked(entry, false)
		untilTime = nil
	end

	-- Fin de l'ouverture par une clé : la base se referme si le propriétaire l'avait fermée entre-temps.
	local forced: number? = forcedUntil[entry.base]
	if forced and (not owner or now >= forced) then
		forcedUntil[entry.base] = nil
		entry.base:SetAttribute("ForcedOpenUntil", nil)
		forced = nil
		if untilTime then
			setLocked(entry, true)
		end
	end

	if not owner then
		return
	end

	-- Le propriétaire marche sur le bouton : (re)lance le compte à rebours.
	local ownerRoot = getRoot(owner)
	if ownerRoot then
		local offset = entry.button.CFrame:PointToObjectSpace(ownerRoot.Position)
		-- Le bouton est un cylindre couché : son axe (hauteur) est l'axe X local.
		local flat = Vector2.new(offset.Y, offset.Z).Magnitude
		if flat <= Config.Lock.ButtonRadius and offset.X > -1 and offset.X < 6 then
			local duration = (if SessionData.HasUnlock(owner, "LongLock") then Config.Lock.LongDuration else Config.Lock.Duration)
				+ Perks.LockBonus(owner) -- passe VIP
			local wasLocked = untilTime ~= nil
			local newUntil = now + duration
			untilTime = newUntil
			lockedUntil[entry.base] = newUntil
			entry.base:SetAttribute("LockedUntil", newUntil)
			if not wasLocked and not forced then
				setLocked(entry, true)
			end
		end
	end
	if not untilTime then
		return
	end

	if forced then
		if entry.label then
			entry.label.Text = string.format("🗝 OUVERTE : %ds", math.ceil(forced - now))
		end
		return -- ouverte par une clé : personne n'est expulsé
	end
	if entry.label and untilTime then
		entry.label.Text = string.format("FERMÉE : %ds", math.ceil(untilTime - now))
	end

	-- Expulse les intrus devant l'entrée.
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= owner then
			local root = getRoot(player)
			local character = player.Character
			if root and character and isInsideBase(entry.platform, root.Position) then
				local outside = entry.platform.CFrame * CFrame.new(0, 4, -entry.platform.Size.Z / 2 - 10)
				character:PivotTo(CFrame.lookAt(outside.Position, outside.Position + outside.LookVector))
			end
		end
	end
end

-- Un joueur utilise une clé sur le portail d'une base fermée : tout est vérifié ici.
local function useKey(player: Player, base: unknown)
	if typeof(base) ~= "Instance" then
		return
	end
	local entry: BaseParts? = nil
	for _, candidate in ipairs(entries) do
		if candidate.base == base then
			entry = candidate
		end
	end
	if not entry then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local owner = BaseManager.GetOwner(entry.base)
	local locked = (lockedUntil[entry.base] or 0) > now
	if not owner or owner == player or not locked or (forcedUntil[entry.base] or 0) > now then
		return
	end
	local root = getRoot(player)
	if not root or (root.Position - entry.gate.Position).Magnitude > Config.Keys.UseDistance + 4 then
		return
	end
	if not SessionData.SpendKey(player) then
		return
	end
	local untilTime = now + Config.Keys.Duration
	forcedUntil[entry.base] = untilTime
	entry.base:SetAttribute("ForcedOpenUntil", untilTime)
	showForcedOpen(entry)
	Remotes.StealNotice:FireClient(owner, "KeyUsed", player.DisplayName, owner.DisplayName, "")
	Remotes.StealNotice:FireClient(player, "KeyOpened", player.DisplayName, owner.DisplayName, "")
	print(string.format("[Lock] %s ouvre la base de %s avec une clé", player.Name, owner.Name))
end

function LockController.Init(bases: { Model })
	Remotes.UseKey.OnServerEvent:Connect(useKey)

	for _, base in ipairs(bases) do
		local platform = base:FindFirstChild("BasePart")
		local button = base:FindFirstChild("LockButton")
		local gate = base:FindFirstChild("Gate")
		local sign = base:FindFirstChild("LockSign")
		local label = sign and sign:FindFirstChild("Label")
		if platform and platform:IsA("BasePart") and button and button:IsA("BasePart") and gate and gate:IsA("BasePart") then
			table.insert(entries, {
				base = base,
				platform = platform,
				button = button,
				gate = gate,
				label = if label and label:IsA("TextLabel") then label else nil,
			})
		else
			warn("[LockController] Pièces manquantes dans " .. base.Name)
		end
	end

	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = Workspace:GetServerTimeNow()
			for _, entry in ipairs(entries) do
				update(entry, now)
			end
		end
	end)
end

return LockController
