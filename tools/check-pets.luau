-- Run with Lune: lune run tools/check-pets.luau <project-directory> <output-directory>
-- Offline construction checks using Roblox data types. Model bounds/scaling are shimmed;
-- this does NOT validate Studio rendering, particles, frame rate or multiplayer gameplay.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local project = process.args[1] or "."
local output = process.args[2] or "pet-check-output"
if not fs.isDir(output) then
	fs.writeDir(output)
end
local V, CF = r.Vector3.new, r.CFrame.new
local scales = {}
r.implementMethod("Model", "GetScale", function(m)
	return scales[m] or 1
end)
r.implementMethod("Model", "GetPivot", function(m)
	return if m.PrimaryPart then m.PrimaryPart.CFrame else CF()
end)
r.implementMethod("Model", "PivotTo", function(m, cf)
	local delta = cf * m:GetPivot():Inverse()
	for _, q in m:GetDescendants() do
		if q:IsA("BasePart") then
			q.CFrame = delta * q.CFrame
		end
	end
end)
r.implementMethod("Model", "ScaleTo", function(m, value)
	local ratio = value / m:GetScale()
	local pivot = m:GetPivot()
	for _, q in m:GetDescendants() do
		if q:IsA("BasePart") then
			local f = pivot:ToObjectSpace(q.CFrame)
			q.Size *= ratio
			q.CFrame = pivot * CF(f.Position * ratio) * f.Rotation
		elseif q:IsA("Attachment") then
			q.Position *= ratio
		end
	end
	scales[m] = value
end)
r.implementMethod("Model", "GetBoundingBox", function(m)
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	local pivot = m:GetPivot()
	for _, q in m:GetDescendants() do
		if q:IsA("BasePart") then
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local point = pivot:PointToObjectSpace(q.CFrame:PointToWorldSpace(q.Size * V(x, y, z) * 0.5))
						lo = V(math.min(lo.X, point.X), math.min(lo.Y, point.Y), math.min(lo.Z, point.Z))
						hi = V(math.max(hi.X, point.X), math.max(hi.Y, point.Y), math.max(hi.Z, point.Z))
					end
				end
			end
		end
	end
	return pivot * CF((lo + hi) / 2), hi - lo
end)
r.implementProperty("BindableEvent", "Event", function()
	return {}
end)
local services = {
	CollectionService = {
		AddTag = function(_, m, tag)
			m:SetAttribute("TestTag", tag)
		end,
	},
	RunService = {
		IsClient = function()
			return false
		end,
	},
	AssetService = {},
	ReplicatedStorage = r.Instance.new("Folder"),
}
local game = {
	GetService = function(_, name)
		assert(services[name], name)
		return services[name]
	end,
}
local cache = {}
local parent = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
local loadModule
loadModule = function(name)
	if cache[name] then
		return cache[name]
	end
	local env = table.clone(r)
	env.game = game
	env.script = { Parent = parent }
	env.require = loadModule
	env.warn = warn
	local fn =
		luau.load(fs.readFile(project .. "/src/shared/" .. name .. ".lua"), { environment = env, debugName = name })
	cache[name] = fn()
	return cache[name]
end
local catalog = loadModule("PetCatalog")
local config = loadModule("Config")
local builder = loadModule("PetModelBuilder")
local sizes = loadModule("PetSizes")
local motion = loadModule("PetMotion")
local signature = loadModule("PetSignatureAuras")
local motionReport, previews = {}, {}
local previewIds = {
	ChienSaucisse = true,
	DragonAurore = true,
	BaleineGalaxie = true,
	FougereFibonacci = true,
	KrakenBaignoire = true,
	ChatCoptere = true,
	Kitsune3Queues = true,
	TournesolJoyeux = true,
	SatelliteRonchon = true,
}
local function close(a, b, why)
	local x, y = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		assert(math.abs(x[i] - y[i]) < 0.003, why .. " component " .. i)
	end
end
local function vec(v)
	return { v.X, v.Y, v.Z }
end
local function geometry(m)
	local result = {}
	for _, q in m:GetDescendants() do
		if q:IsA("BasePart") and q.Transparency < 1 then
			table.insert(result, {
				name = q.Name,
				size = vec(q.Size),
				cf = { q.CFrame:GetComponents() },
				color = { q.Color.R, q.Color.G, q.Color.B },
				alpha = q.Transparency,
				wedge = q:IsA("WedgePart"),
				aura = q:GetAttribute("Aura") == true,
				neon = q.Material == r.Enum.Material.Neon,
			})
		end
	end
	return result
end
local report, meshes = {}, {}
local maxParts, maxRate = 0, 0
for _, e in catalog.List do
	local m = assert(builder.Build(e.Id))
	assert(m:GetAttribute("VisualStyle") == "SculptedBlocksV2", e.Id .. ": style")
	assert(m.PrimaryPart.Name == "Root" and m.PrimaryPart.Transparency == 1, e.Id .. ": root")
	local box, size = builder.BodyBounds(m)
	assert(box.Position.Magnitude < 0.002, e.Id .. ": centering")
	-- Échelle shared/PetSizes : la hauteur visée, sauf si le familier est trop long (alors la longueur est limitée).
	local band = assert(sizes.Bands[e.Rarity], e.Rarity .. ": size band")
	local j = assert(sizes.Heights[e.Id], e.Id .. ": missing size")
	assert(j >= band[1] and j <= band[2], e.Id .. ": size outside its rarity band")
	local wanted = sizes.Studs(e.Id, e.Rarity)
	local long = math.max(size.X, size.Z)
	assert(size.Y <= wanted + 0.003, e.Id .. ": height")
	assert(long <= sizes.MAX_FOOTPRINT + 0.003 and long <= wanted * sizes.LONG_RATIO + 0.003, e.Id .. ": length")
	assert(
		math.abs(size.Y - wanted) < 0.003
			or math.abs(long - math.min(sizes.MAX_FOOTPRINT, wanted * sizes.LONG_RATIO)) < 0.003,
		e.Id .. ": scale"
	)
	local count, emitters, rate = 0, 0, 0
	for _, q in m:GetDescendants() do
		if q:IsA("BasePart") then
			count += 1
			assert(q.Anchored and not q.CanCollide and not q.CanTouch and not q.CanQuery, e.Id .. ": physics")
			assert(q.Size.X > 0 and q.Size.Y > 0 and q.Size.Z > 0, e.Id .. ": dimensions")
			assert(q.CFrame.Position.Magnitude < 120, e.Id .. ": position")
		elseif q:IsA("ParticleEmitter") then
			emitters += 1
			rate += q.Rate
		end
	end
	assert(count <= 220, e.Id .. ": geometry budget " .. count)
	-- Aura signature (Cerbère Infernal) : 3 émetteurs aussi, mais plus denses que les auras de rareté.
	assert(emitters <= 3 and rate <= (if signature.Has(e.Id) then signature.MaxRate else 28), e.Id .. ": FX budget")
	if e.Rarity == "Commun" then
		assert(emitters == 0, e.Id .. ": common FX")
	end
	maxParts = math.max(maxParts, count)
	maxRate = math.max(maxRate, rate)
	local geo = geometry(m)
	local rig = motion.Create(m)
	assert(#rig.parts > 0 and m:GetAttribute("MotionReady"), e.Id .. ": rig missing")
	for _, q in m:GetChildren() do
		if q:IsA("BasePart") and q ~= m.PrimaryPart and not q:GetAttribute("Aura") then
			assert(typeof(q:GetAttribute("MotionRest")) == "CFrame", e.Id .. ": unrigged " .. q.Name)
		end
	end
	local function restFrame(index)
		local rest = rig.rest[index]
		return m:GetPivot() * CF(rest.Position * m:GetScale()) * rest.Rotation
	end
	local rootBefore = m:GetPivot()
	local moved, kinds = false, {}
	local frames = motion.Pose(rig, 0, 0, 0, false, 0)
	for i, q in rig.parts do
		close(frames[i], q.CFrame, e.Id .. ": initial rest")
	end
	for _, j in rig.joints do
		kinds[j.kind] = true
	end
	local frozen = table.clone(frames)
	for step = 1, 120 do
		frames = motion.Pose(rig, 100000 + step / 30, 1 / 30, if step < 40 then 0 elseif step < 80 then 4 else 0, false)
		for i, q in rig.parts do
			if
				(frames[i].Position - frozen[i].Position).Magnitude > 0.001
				or frames[i].LookVector:Dot(frozen[i].LookVector) < 0.99999
			then
				moved = true
			end
			q.CFrame = frames[i]
			assert(frames[i].Position.Magnitude < size.Magnitude * 3 + 5, e.Id .. ": divergent pose")
		end
		for _, j in rig.joints do
			local first = j.members[1]
			for _, i in j.members do
				close(
					frames[first]:ToObjectSpace(frames[i]),
					restFrame(first):ToObjectSpace(restFrame(i)),
					e.Id .. ": detached " .. j.kind
				)
			end
		end
	end
	assert(moved, e.Id .. ": static pet")
	close(m:GetPivot(), rootBefore, e.Id .. ": root changed by articulation")
	local same = table.clone(motion.Pose(rig, 100004, 0, 0, false))
	for _ = 1, 5 do
		local repeated = motion.Pose(rig, 100004, 0, 0, false)
		for i in rig.parts do
			close(repeated[i], same[i], e.Id .. ": accumulated drift")
		end
	end
	local reset = motion.Pose(rig, 0, 0, 0, false, 0)
	for i, q in rig.parts do
		close(reset[i], restFrame(i), e.Id .. ": paused rest")
		q.CFrame = reset[i]
	end
	local kindNames = {}
	for kind in kinds do
		table.insert(kindNames, kind)
	end
	table.sort(kindNames)
	table.insert(
		motionReport,
		{ id = e.Id, parts = #rig.parts, joints = #rig.joints, kinds = kindNames, passed = true }
	)
	if previewIds[e.Id] then
		local sequence = {}
		local previewRig = motion.Create(m)
		for step = 0, 59 do
			local pose = motion.Pose(previewRig, step / 15, 1 / 15, if e.Id == "ChienSaucisse" then 4 else 0, false)
			for i, q in previewRig.parts do
				q.CFrame = pose[i]
			end
			table.insert(sequence, geometry(m))
		end
		table.insert(previews, { id = e.Id, name = e.Name, size = vec(size), frames = sequence })
		for i, q in rig.parts do
			q.CFrame = reset[i]
		end
	end
	local again = assert(builder.Build(e.Id))
	assert(serde.encode("json", geo) == serde.encode("json", geometry(again)), e.Id .. ": nondeterministic")
	again:Destroy()
	m:ScaleTo(m:GetScale() * 0.6)
	m:PivotTo(CF(5, 10, -3) * r.CFrame.Angles(0, 0.6, 0))
	local carryBox, carrySize = builder.BodyBounds(m)
	assert((carrySize - size * 0.6).Magnitude < 0.003, e.Id .. ": carry scaling")
	assert((carryBox.Position - V(5, 10, -3)).Magnitude < 0.003, e.Id .. ": carry positioning")
	local carried = motion.Pose(rig, 3, 1 / 30, 8, true)
	for i, q in rig.parts do
		q.CFrame = carried[i]
		assert((carried[i].Position - m:GetPivot().Position).Magnitude < size.Magnitude, e.Id .. ": carried rig")
	end
	local carryReset = motion.Pose(rig, 0, 0, 0, true, 0)
	for i in rig.parts do
		close(carryReset[i], restFrame(i), e.Id .. ": scaled/rotated rest")
	end
	table.insert(report, { id = e.Id, parts = count, emitters = emitters, rate = rate, size = vec(size) })
	table.insert(meshes, { id = e.Id, name = e.Name, rarity = e.Rarity, parts = geo, size = vec(size) })
	m:Destroy()
end
assert(#report == #catalog.List and #catalog.List == 106, "Catalogue count (75 de base + 31 exclusifs des mondes)")
assert(builder.Build("UnknownPet") == nil, "Unknown id")
for old, new in catalog.Renamed do
	local m = assert(builder.Build(old))
	assert(m.Name == new, "Migration")
	m:Destroy()
end
fs.writeFile(output .. "/pet-geometry.json", serde.encode("json", meshes))
fs.writeFile(output .. "/pet-check-report.json", serde.encode("json", report, true))
fs.writeFile(output .. "/pet-motion-report.json", serde.encode("json", motionReport, true))
fs.writeFile(output .. "/pet-motion-preview.json", serde.encode("json", previews))
print("PASS: " .. #report .. " animated rigs; 120 frames/pet, rigid groups, no drift, pause/rest, carrying + rotation + rescale.")
print(
	string.format(
		"PASS: %d pets + renamed IDs; deterministic, centered, scaled, noncolliding. Max %d parts, %.1f particles/s.",
		#report,
		maxParts,
		maxRate
	)
)
