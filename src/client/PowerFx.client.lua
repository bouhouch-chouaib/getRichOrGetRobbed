--!strict
-- Traînée (Vitesse) et aura (Force) de chaque joueur, selon ses paliers d'entraînement (shared/PowerFx,
-- Config.PowerFx). Rien côté serveur : les paliers se lisent sur les attributs SpeedLevel + SpeedBonus et
-- StrengthLevel + StrengthBonus (server/SessionData). Le joueur voit en plus un jaillissement et un message
-- quand il passe un palier.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(RS.Shared.Config)
local Perks = require(RS.Shared.Perks)
local PowerFx = require(RS.Shared.PowerFx)
local Toast = require(script.Parent.Toast)

local C = Config.PowerFx
local LOCAL = Players.LocalPlayer
local RATE = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then C.TouchRateScale else 1
-- Les attributs arrivent par vagues au chargement : pas de message de palier pendant les premières secondes.
local QUIET_UNTIL = os.clock() + 8

local rigs: { [Player]: PowerFx.Rig } = {}
local seen: { [Player]: { speed: number, strength: number } } = {}

local function number(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function tiers(player: Player): (number, number)
	if C.YieldToAstralAura and Perks.HasAura(player) then
		return 0, 0
	end
	return PowerFx.SpeedTier(number(player, "SpeedLevel") + number(player, "SpeedBonus")),
		PowerFx.StrengthTier(number(player, "StrengthLevel") + number(player, "StrengthBonus"))
end

local function clear(player: Player)
	local rig = rigs[player]
	if rig then
		PowerFx.Destroy(rig)
		rigs[player] = nil
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	clear(player)
	seen[player] = nil
end)

-- Message au joueur quand il gagne un palier (jamais quand il en perd un, ex. familier déséquipé).
local function announce(speed: number, strength: number): boolean
	local before = seen[LOCAL]
	seen[LOCAL] = { speed = speed, strength = strength }
	if not before or os.clock() < QUIET_UNTIL then
		return false
	end
	local gained = false
	if speed > before.speed then
		local tier = C.Speed[speed]
		Toast.show("NOUVELLE TRAÎNÉE : " .. tier.Name .. " !", tier.Color1)
		gained = true
	end
	if strength > before.strength then
		local tier = C.Strength[strength]
		Toast.show("NOUVELLE AURA : " .. tier.Name .. " !", tier.Edge)
		gained = true
	end
	return gained
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < C.UpdateInterval then
		return
	end
	elapsed = 0
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for _, player in ipairs(Players:GetPlayers()) do
		local speed, strength = tiers(player)
		local gained = player == LOCAL and announce(speed, strength)
		local character = player.Character
		local rig: PowerFx.Rig? = rigs[player]
		if
			rig
			and (
				rig.character ~= character
				or rig.speedTier ~= speed
				or rig.strengthTier ~= strength
				or not rig.root:IsDescendantOf(Workspace)
				or rig.humanoid.Health <= 0
			)
		then
			clear(player)
			rig = nil
		end
		if (speed == 0 and strength == 0) or not character or not character:IsDescendantOf(Workspace) then
			continue
		end
		local active: PowerFx.Rig
		if rig then
			active = rig
		else
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				continue
			end
			local created = PowerFx.Create(character, speed, strength, RATE)
			if not created then
				continue
			end
			rigs[player] = created
			active = created
		end
		local distance = (camera.CFrame.Position - active.root.Position).Magnitude
		local firstPerson = player == LOCAL and (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1
		local visible = PowerFx.CanShow(active.humanoid.Health, number(player, "InvisibleUntil"), now, distance, firstPerson)
		local velocity = active.root.AssemblyLinearVelocity
		local running = PowerFx.IsRunning(Vector3.new(velocity.X, 0, velocity.Z).Magnitude, active.humanoid.Sit or active.humanoid.PlatformStand)
		PowerFx.Update(active, now, visible, running)
		if gained and visible then
			PowerFx.Burst(active)
		end
	end
end)
