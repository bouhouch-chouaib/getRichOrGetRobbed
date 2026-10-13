--!strict
-- Apply articulated poses after follower/base placement, once per rendered frame.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").Shared
local Motion = require(Shared.PetMotion)
local Config = require(Shared.Config)
type Entry = { rig: Motion.Rig, last: Vector3?, elapsed: number, sleeping: boolean }
local tracked: { [Instance]: Entry } = {}
local function add(instance: Instance)
	if not instance:IsA("Model") or instance:GetAttribute("MotionReady") ~= true then
		return
	end
	tracked[instance] = { rig = Motion.Create(instance), last = nil, elapsed = 0, sleeping = false }
end
CollectionService:GetInstanceAddedSignal("SculptedPetVisual"):Connect(add)
CollectionService:GetInstanceRemovedSignal("SculptedPetVisual"):Connect(function(instance: Instance)
	tracked[instance] = nil
end)
for _, instance in ipairs(CollectionService:GetTagged("SculptedPetVisual")) do
	add(instance)
end
local parts: { BasePart }, frames: { CFrame } = {}, {}
RunService:BindToRenderStep("SculptedPetMotion", Enum.RenderPriority.Last.Value + 1, function(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	table.clear(parts)
	table.clear(frames)
	local now = os.clock()
	for _, entry in pairs(tracked) do
		local m, rig = entry.rig.model, entry.rig
		local root = m.PrimaryPart
		if not root or not m:IsDescendantOf(Workspace) then
			entry.last = nil
			continue
		end
		entry.elapsed += dt
		local position = root.Position
		local distance = (position - camera.CFrame.Position).Magnitude
		local sleeping = distance > Config.Pets.MotionDistance or m:GetAttribute("MotionPaused") == true
		if sleeping and entry.sleeping then
			entry.last = position
			entry.elapsed = 0
			continue
		end
		if
			not sleeping
			and distance > Config.Pets.MotionNearDistance
			and entry.elapsed < Config.Pets.MotionFarInterval
		then
			continue
		end
		local delta = if entry.last then (position - entry.last) * Vector3.new(1, 0, 1) else Vector3.zero
		local speed = if entry.elapsed > 0 and delta.Magnitude < 12 then delta.Magnitude / entry.elapsed else 0
		local override = m:GetAttribute("MotionSpeed")
		if type(override) == "number" then
			speed = override
		end
		local pose = Motion.Pose(
			rig,
			now,
			entry.elapsed,
			speed,
			m:GetAttribute("MotionCarried") == true,
			if sleeping then 0 else 1
		)
		for index, q in ipairs(rig.parts) do
			if q.Parent then
				table.insert(parts, q)
				table.insert(frames, pose[index])
			end
		end
		entry.last = position
		entry.elapsed = 0
		entry.sleeping = sleeping
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
