--!strict
-- At most eight animated eggs per base. Batches incubate in parallel; the label shows the next hatch.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.EggIncubation)
local Builder = require(ReplicatedStorage.Shared.EggModelBuilder)
local Catalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local Toast = require(script.Parent.Toast)
local Sounds = require(script.Parent.Sounds)
local player = Players.LocalPlayer
local visuals = Instance.new("Folder")
visuals.Name, visuals.Parent = "EggVisuals", Workspace

type Shown = {
	model: Model,
	nest: BasePart,
	label: TextLabel,
	bar: Frame,
	gui: BillboardGui,
	particles: ParticleEmitter?,
	born: number,
	rank: number,
}
local shown: { [BasePart]: Shown } = {}

local function remove(anchor: Instance)
	if not anchor:IsA("BasePart") then
		return
	end
	local egg = shown[anchor]
	if egg then
		egg.model:Destroy()
		egg.nest:Destroy()
		shown[anchor] = nil
	end
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or shown[instance] or not instance:IsDescendantOf(Workspace) then
		return
	end
	local rarityId = instance:GetAttribute("Rarity")
	if type(rarityId) ~= "string" or not Config.RarityIndex[rarityId] then
		return
	end
	local rank = Config.RarityIndex[rarityId]
	local rarity = Config.Rarities[rank]
	local model = Builder.Build(rarityId)
	model:PivotTo(instance.CFrame)
	model.Parent = visuals
	local nest = Instance.new("Part")
	nest.Name = "Incubator"
	nest.Size = Vector3.new(4.7, 0.24, 4.4)
	nest.CFrame = instance.CFrame * CFrame.new(0, 0.12, 0)
	nest.Color, nest.Material = rarity.Color:Lerp(Color3.fromRGB(24, 21, 38), 0.65), Enum.Material.Plastic
	nest.TopSurface = Enum.SurfaceType.Studs
	nest.Anchored, nest.CanCollide, nest.CanTouch, nest.CanQuery = true, false, false, false
	nest.Parent = visuals
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee = "Incubation", nest
	gui.Size, gui.StudsOffsetWorldSpace = UDim2.fromOffset(160, 62), Vector3.new(0, 5.3, 0)
	gui.MaxDistance, gui.AlwaysOnTop = 65, false
	gui.Parent = nest
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 48)
	label.Font, label.TextSize = Enum.Font.GothamBold, 15
	label.TextColor3, label.TextStrokeColor3, label.TextStrokeTransparency = rarity.Color, Color3.new(), 0.1
	label.TextWrapped = true
	label.Parent = gui
	local track = Instance.new("Frame")
	track.Position, track.Size = UDim2.fromOffset(20, 51), UDim2.fromOffset(120, 6)
	track.BorderSizePixel, track.BackgroundColor3 = 0, Color3.fromRGB(30, 25, 45)
	track.Parent = gui
	local bar = Instance.new("Frame")
	bar.BorderSizePixel, bar.BackgroundColor3 = 0, rarity.Color
	bar.Size = UDim2.fromScale(0, 1)
	bar.Parent = track
	local particles: ParticleEmitter? = nil
	if rank >= 4 then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(rarity.Color)
		emitter.Rate, emitter.Lifetime, emitter.Speed = 2 + rank, NumberRange.new(0.7, 1.4), NumberRange.new(0.4, 1)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
		emitter.LightEmission = 0.8
		emitter.SpreadAngle = Vector2.new(45, 45)
		emitter.Parent = nest
		particles = emitter
	end
	shown[instance] = {
		model = model,
		nest = nest,
		label = label,
		bar = bar,
		gui = gui,
		particles = particles,
		born = os.clock(),
		rank = rank,
	}
end

CollectionService:GetInstanceAddedSignal("IncubatingEgg"):Connect(add)
CollectionService:GetInstanceRemovedSignal("IncubatingEgg"):Connect(remove)
for _, instance in ipairs(CollectionService:GetTagged("IncubatingEgg")) do
	add(instance)
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 / 30 then
		return
	end
	elapsed = 0
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local time, clock = Workspace:GetServerTimeNow(), os.clock()
	for anchor, egg in pairs(shown) do
		if not anchor:IsDescendantOf(Workspace) then
			remove(anchor)
			continue
		end
		local distance = (camera.CFrame.Position - anchor.Position).Magnitude
		local visible = distance <= Config.Eggs.ViewDistance
		egg.gui.Enabled = visible
		if egg.particles then
			egg.particles.Enabled = visible
		end
		if not visible then
			continue
		end
		local ready = anchor:GetAttribute("ReadyAt")
		local started = anchor:GetAttribute("StartedAt")
		if type(ready) ~= "number" or type(started) ~= "number" then
			continue
		end
		local remaining = math.max(0, ready - time)
		local rawCount = anchor:GetAttribute("Count")
		local count = if type(rawCount) == "number" then rawCount else 1
		egg.label.Text = string.format(
			"ŒUF %s ×%d\n%s",
			TextFormat.upper(Config.Rarities[egg.rank].Name),
			count,
			if remaining > 0 then "Éclosion · " .. Eggs.Time(remaining) else "ÉCLOSION..."
		)
		egg.bar.Size = UDim2.fromScale(math.clamp((time - started) / math.max(ready - started, 1), 0, 1), 1)
		local phase = time * 2 + egg.rank
		local urgent = remaining < 5
		local rock = math.sin(phase * (if urgent then 9 else 1)) * (if urgent then 0.12 else 0.035)
		local age = clock - egg.born
		local arrival = if age < 0.65 then 5 * (1 - age / 0.65) ^ 2 else 0
		local float = if egg.rank >= 4 then 0.15 + math.sin(phase) * 0.1 else 0
		egg.model:PivotTo(
			anchor.CFrame
				* CFrame.new(0, 0.25 + arrival + float, 0)
				* CFrame.Angles(0, math.sin(phase * 0.5) * 0.07, rock)
		)
	end
end)

Remotes.EggHatched.OnClientEvent:Connect(
	function(ownerId: number, rarityId: string, cf: CFrame, pets: { [string]: number })
		local rank = Config.RarityIndex[rarityId]
		if not rank or typeof(cf) ~= "CFrame" then
			return
		end
		local rarity = Config.Rarities[rank]
		if ownerId == player.UserId then
			local count, names = 0, {}
			for id, amount in pairs(pets) do
				local pet = Catalog.ById[id]
				if pet then
					count += amount
					table.insert(names, pet.Name)
				end
			end
			Toast.show(
				if #names == 1
					then string.format("ÉCLOSION : %s ×%d !", TextFormat.upper(names[1]), count)
					else string.format("%d FAMILIERS %s ONT ÉCLOS !", count, TextFormat.upper(rarity.Name)),
				rarity.Color
			)
			Sounds.play("HoleBonus")
		end
		local camera = Workspace.CurrentCamera
		if not camera or (camera.CFrame.Position - cf.Position).Magnitude > Config.Eggs.ViewDistance then
			return
		end
		local shell = Builder.Build(rarityId)
		shell:PivotTo(cf * CFrame.new(0, 0.25, 0))
		shell.Parent = visuals
		for _, child in ipairs(shell:GetChildren()) do
			if child:IsA("BasePart") and child.Name ~= "Root" then
				local half = child:GetAttribute("ShellHalf")
				local side = if half == 1 then 1 else -1
				local localCf = cf:ToObjectSpace(child.CFrame)
				local target = cf
					* CFrame.new(side * 2.1, if side == 1 then 2.8 else 0.45, 0.2)
					* CFrame.Angles(0, 0, -side * 0.65)
					* localCf
				TweenService:Create(
					child,
					TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = target, Transparency = 1 }
				):Play()
			end
		end
		local root = shell.PrimaryPart
		if root then
			local burst = Instance.new("ParticleEmitter")
			burst.Texture, burst.Color =
				"rbxasset://textures/particles/sparkles_main.dds", ColorSequence.new(rarity.Color, Color3.new(1, 1, 1))
			burst.Rate, burst.Lifetime, burst.Speed = 0, NumberRange.new(0.35, 0.8), NumberRange.new(3, 8)
			burst.SpreadAngle = Vector2.new(180, 180)
			burst.LightEmission = 1
			burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
			burst.Parent = root
			burst:Emit(18 + rank * 3)
		end
		Debris:AddItem(shell, 1.2)
	end
)
