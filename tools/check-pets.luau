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
	local wanted = 3.2 * config.Pets.RarityScale[config.RarityIndex[e.Rarity]]
	assert(math.abs(size.Y - wanted) < 0.003, e.Id .. ": height")
	local count, emitters, rate = 0, 0, 0
	for _, q in m:GetDescendants() do
		if q:IsA("BasePart") then
			count += 1
			assert(q.Anchored and not q.CanCollide and not q.CanTouch and not q.CanQuery, e.Id .. ": physics")
			assert(q.Size.X > 0 and q.Size.Y > 0 and q.Size.Z > 0, e.Id .. ": dimensions")
			assert(q.CFrame.Position.Magnitude < 100, e.Id .. ": position")
		elseif q:IsA("ParticleEmitter") then
			emitters += 1
			rate += q.Rate
		end
	end
	assert(count <= 220, e.Id .. ": geometry budget " .. count)
	assert(emitters <= 3 and rate <= 28, e.Id .. ": FX budget")
	if e.Rarity == "Commun" then
		assert(emitters == 0, e.Id .. ": common FX")
	end
	maxParts = math.max(maxParts, count)
	maxRate = math.max(maxRate, rate)
	local geo = geometry(m)
	local again = assert(builder.Build(e.Id))
	assert(serde.encode("json", geo) == serde.encode("json", geometry(again)), e.Id .. ": nondeterministic")
	again:Destroy()
	m:ScaleTo(m:GetScale() * 0.6)
	m:PivotTo(CF(5, 10, -3) * r.CFrame.Angles(0, 0.6, 0))
	local carryBox, carrySize = builder.BodyBounds(m)
	assert((carrySize - size * 0.6).Magnitude < 0.003, e.Id .. ": carry scaling")
	assert((carryBox.Position - V(5, 10, -3)).Magnitude < 0.003, e.Id .. ": carry positioning")
	table.insert(report, { id = e.Id, parts = count, emitters = emitters, rate = rate, size = vec(size) })
	table.insert(meshes, { id = e.Id, name = e.Name, rarity = e.Rarity, parts = geo, size = vec(size) })
	m:Destroy()
end
assert(#report == 75, "Catalogue count")
assert(builder.Build("UnknownPet") == nil, "Unknown id")
for old, new in catalog.Renamed do
	local m = assert(builder.Build(old))
	assert(m.Name == new, "Migration")
	m:Destroy()
end
fs.writeFile(output .. "/pet-geometry.json", serde.encode("json", meshes))
fs.writeFile(output .. "/pet-check-report.json", serde.encode("json", report, true))
print(
	string.format(
		"PASS: %d pets + renamed IDs; deterministic, centered, scaled, noncolliding. Max %d parts, %.1f particles/s.",
		#report,
		maxParts,
		maxRate
	)
)
