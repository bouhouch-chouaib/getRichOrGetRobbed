--!strict
-- LockController : bouton au sol de chaque base (comme Steal a Brainrot).
-- Le propriétaire marche sur le bouton -> la base est fermée pendant Config.Lock.Duration secondes
-- (compte à rebours relancé à chaque passage sur le bouton) :
-- le portail apparaît et tout autre joueur à l'intérieur est expulsé devant l'entrée.
-- Attributs écrits sur la base : "Locked" (bool) et "LockedUntil" (temps serveur).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
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
			local duration = if SessionData.HasUnlock(owner, "LongLock") then Config.Lock.LongDuration else Config.Lock.Duration
			local wasLocked = untilTime ~= nil
			local newUntil = now + duration
			untilTime = newUntil
			lockedUntil[entry.base] = newUntil
			entry.base:SetAttribute("LockedUntil", newUntil)
			if not wasLocked then
				setLocked(entry, true)
			end
		end
	end
	if not untilTime then
		return
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

function LockController.Init(bases: { Model })
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
