--!strict
-- One throttled update for all pets. Viewports are static; distant particles/lights are disabled.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
type Visual = {
	model: Model,
	moving: { BasePart },
	emitters: { ParticleEmitter },
	lights: { PointLight },
	near: boolean?,
}
local tracked: { [Instance]: Visual } = {}
local function add(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local v: Visual = { model = instance, moving = {}, emitters = {}, lights = {}, near = nil }
	for _, d in ipairs(instance:GetDescendants()) do
		if
			d:IsA("BasePart") and (d:GetAttribute("Orbit") or d:GetAttribute("Spin") or d:GetAttribute("PulsePhase"))
		then
			table.insert(v.moving, d)
		elseif d:IsA("ParticleEmitter") then
			table.insert(v.emitters, d)
		elseif d:IsA("PointLight") then
			table.insert(v.lights, d)
		end
	end
	tracked[instance] = v
end
CollectionService:GetInstanceAddedSignal("SculptedPetVisual"):Connect(add)
CollectionService:GetInstanceRemovedSignal("SculptedPetVisual"):Connect(function(i: Instance)
	tracked[i] = nil
end)
for _, i in ipairs(CollectionService:GetTagged("SculptedPetVisual")) do
	add(i)
end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < Config.Pets.AuraUpdateInterval then
		return
	end
	elapsed = 0
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	for _, v in pairs(tracked) do
		local m = v.model
		local root = m.PrimaryPart
		if not root or not m:IsDescendantOf(Workspace) then
			continue
		end
		local distance = (root.Position - camera.CFrame.Position).Magnitude
		local near = distance < Config.Pets.AuraDistance and m:GetAttribute("AuraHidden") ~= true
		if near ~= v.near then
			v.near = near
			for _, em in ipairs(v.emitters) do
				if em.Parent then
					em.Enabled = near
				end
			end
			for _, light in ipairs(v.lights) do
				if light.Parent then
					light.Enabled = near
				end
			end
		end
		if not near then
			continue
		end
		local scale = m:GetScale()
		for _, q in ipairs(v.moving) do
			if not q.Parent then
				continue
			end
			local orbit = q:GetAttribute("Orbit")
			local spin = q:GetAttribute("Spin")
			local phase = q:GetAttribute("PulsePhase")
			if type(orbit) == "number" then
				local r = q:GetAttribute("OrbitRadius")
				local h = q:GetAttribute("OrbitHeight")
				if type(r) == "number" and type(h) == "number" then
					local a = now * 0.55 + orbit
					q.CFrame = root.CFrame
						* CFrame.new(
							math.cos(a) * r * scale,
							(h + math.sin(now * 1.7 + orbit) * 0.12) * scale,
							math.sin(a) * r * scale
						)
						* CFrame.Angles(0, a, math.pi / 4)
				end
			elseif type(spin) == "number" and m:GetAttribute("MotionReady") ~= true then
				local pos = q:GetAttribute("SpinOrigin")
				if typeof(pos) == "Vector3" then
					q.CFrame = root.CFrame * CFrame.new(pos * scale) * CFrame.Angles(0, now * spin, 0)
				end
			elseif type(phase) == "number" then
				local alpha = q:GetAttribute("RestTransparency")
				if type(alpha) == "number" then
					q.Transparency = math.clamp(alpha + math.sin(now * 1.8 + phase) * 0.13, 0, 0.8)
				end
			end
		end
	end
end)
