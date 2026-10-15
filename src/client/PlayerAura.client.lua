--!strict
-- Every client renders owned auras. The server validates receipts and saves the permanent unlock.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(RS.Shared.Config)
local Perks = require(RS.Shared.Perks)
local Aura = require(RS.Shared.PlayerAuraVisual)
local rigs: { [Player]: Aura.Rig? } = {}
local elapsed = 0
local function clear(player: Player)
	local rig = rigs[player]
	if rig then
		Aura.Destroy(rig)
		rigs[player] = nil
	end
end
Players.PlayerRemoving:Connect(clear)
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < Config.PlayerAura.UpdateInterval then
		return
	end
	elapsed = 0
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for _, player in ipairs(Players:GetPlayers()) do
		local owned = Perks.HasAura(player)
		local character = player.Character
		local rig: Aura.Rig? = rigs[player]
		if
			rig
			and (
				not owned
				or rig.character ~= character
				or not rig.root:IsDescendantOf(Workspace)
				or rig.humanoid.Health <= 0
			)
		then
			clear(player)
			rig = nil
		end
		if not owned or not character or not character:IsDescendantOf(Workspace) then
			continue
		end
		if not rig then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				continue
			end
			rig = Aura.Create(character)
			rigs[player] = rig
		end
		if not rig then
			continue
		end
		local distance = (camera.CFrame.Position - rig.root.Position).Magnitude
		local invisible = player:GetAttribute("InvisibleUntil")
		local hiddenUntil = if type(invisible) == "number" then invisible else 0
		local firstPerson = player == Players.LocalPlayer
			and (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1
		local visible = Aura.CanShow(owned, rig.humanoid.Health, hiddenUntil, now, distance, firstPerson)
		local velocity = rig.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local state = rig.humanoid:GetState()
		local grounded = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
		local running = Aura.IsRunning(speed, grounded, rig.humanoid.Sit or rig.humanoid.PlatformStand)
		Aura.Update(rig, now + player.UserId % 97, visible, running)
	end
end)
