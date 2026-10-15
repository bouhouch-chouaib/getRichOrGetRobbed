-- Run with Lune: lune run tools/check-pets.luau <project-directory> <output-directory>
-- Offline construction checks using Roblox data types. Model bounds/scaling are shimmed;
-- this does NOT validate Studio rendering, particles, frame rate or multiplayer gameplay.
-- Run: lune run tools/check-eggs.luau <project-directory> <output-directory>
-- Executes real modules with an in-memory DataStore and Roblox datatype shims.
-- No connection to Roblox, no real purchases. Does not replace a Studio playtest.
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
local config, catalog = loadModule("Config"), loadModule("PetCatalog")
local eggs, builder = loadModule("EggIncubation"), loadModule("EggModelBuilder")
local queue, models, report = {}, {}, {}
local byRank = {}
for rank, rarity in ipairs(config.Rarities) do
	local id = catalog.ByRarity[rarity.Id][1].Id
	byRank[rank] = id
	local egg = assert(eggs.Create(id, 2, 1000, "egg" .. rank))
	assert(egg.readyAt == 1000 + config.Eggs.Seconds[rarity.Id])
	table.insert(queue, egg)
	local m = builder.Build(rarity.Id)
	local top, bottom = 0, 0
	for _, part in ipairs(m:GetChildren()) do
		assert(
			part:IsA("BasePart") and part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery
		)
		assert(part.Size.X > 0 and part.Size.Y > 0 and part.Size.Z > 0)
		if part:GetAttribute("ShellHalf") == 1 then
			top += 1
		elseif part:GetAttribute("ShellHalf") == -1 then
			bottom += 1
		end
	end
	assert(top > 0 and bottom > 0 and m.PrimaryPart.Name == "Root")
	local _, size = m:GetBoundingBox()
	assert(size.X < 5 and size.Y < 5 and size.Z < 5, rarity.Id .. " fits the nest")
	table.insert(
		models,
		{
			id = rarity.Id,
			name = rarity.Name,
			rarity = rarity.Id,
			parts = geometry(m),
			seconds = eggs.Duration(rarity.Id),
		}
	)
	table.insert(report, { rarity = rarity.Id, seconds = eggs.Duration(rarity.Id), parts = #m:GetChildren() })
end
assert(#eggs.Merge(nil, {}) == 0, "old saves migrate without resetting pets")
assert(#eggs.Merge(queue, queue) == 8, "batch IDs merge exactly once")
local bad = { id = "bad", petId = byRank[1], count = 0 / 0, startedAt = 1000, readyAt = 1001 }
assert(#eggs.Merge({ bad }, {}) == 0, "invalid quantities rejected")
assert(not eggs.Create("missing", 1, 1000, "bad"))
local pending, hatched = eggs.Collect(queue, 1014.99)
assert(#pending == 8 and next(hatched) == nil, "never hatch early")
pending, hatched = eggs.Collect(queue, 1015)
assert(#pending == 7 and hatched[byRank[1]] == 2, "hatch at exact deadline")
local again, duplicate = eggs.Collect(pending, 1015)
assert(#again == 7 and next(duplicate) == nil, "repeated ticks cannot duplicate")
local offline = eggs.Merge(serde.decode("json", serde.encode("json", pending)), {})
pending, hatched = eggs.Collect(offline, 10000)
assert(#pending == 0, "all offline deadlines honored")
for rank = 2, 8 do
	assert(hatched[byRank[rank]] == 2)
end
local owned = eggs.Owned({ [byRank[1]] = 3 }, queue)
assert(owned[byRank[1]] == 5, "pending eggs consume duplicate slots")
local summary = eggs.Summary({ queue[1], assert(eggs.Create(byRank[1], 3, 1005, "later")) })
assert(summary.Commun.count == 5 and summary.Commun.readyAt == 1015, "next deadline, not last deadline")
fs.writeFile(output .. "/egg-geometry.json", serde.encode("json", models))
fs.writeFile(output .. "/egg-report.json", serde.encode("json", report, true))

-- Run the actual persistence and reward modules against an in-memory DataStore.
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, f)
			table.insert(callbacks, f)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, f in ipairs(callbacks) do
				f(...)
			end
		end,
	}
end
local tasks = {}
local mockTask = {
	spawn = function(f, ...)
		table.insert(tasks, { f = f, args = { ... } })
	end,
	defer = function() end,
	wait = function() end,
	delay = function() end,
}
local player = r.Instance.new("Player")
player.Name, player.UserId = "EggTest", 1234
player.DisplayName = "EggTest"
player.Parent = r.Instance.new("Folder")
r.implementProperty("Player", "CharacterAdded", function()
	return signal()
end)
r.implementMethod("Player", "Kick", function(_, reason)
	error("Unexpected kick: " .. reason)
end)
local records, failSave, snapshotHook = {}, false, nil
local dataStore = {
	UpdateAsync = function(_, key, transform)
		if failSave then
			error("API access is not enabled (test injected failure)")
		end
		local value = transform(records[key])
		if snapshotHook then
			local hook = snapshotHook
			snapshotHook = nil
			hook()
		end
		if value then
			records[key] = serde.decode("json", serde.encode("json", value))
		end
		return records[key]
	end,
}
local guid = 0
services.DataStoreService = {
	GetDataStore = function()
		return dataStore
	end,
}
services.HttpService = {
	GenerateGUID = function()
		guid += 1
		return "guid" .. guid
	end,
}
services.Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return { player }
	end,
	GetPlayerByUserId = function(_, id)
		return if id == player.UserId then player else nil
	end,
}
services.RunService = {
	IsStudio = function()
		return true
	end,
}
services.ReplicatedStorage = {
	Shared = parent,
	GetAttribute = function()
		return nil
	end,
	SetAttribute = function() end,
}
services.Workspace = {
	GetServerTimeNow = function()
		return os.time()
	end,
}
services.MarketplaceService = { PromptGamePassPurchaseFinished = signal() }
game.JobId = "test"
game.BindToClose = function() end
cache.Remotes = { TutorialDone = { OnServerEvent = signal() }, RewardsGranted = { FireClient = function() end } }
cache.PetStats = {
	Sum = function()
		return { Speed = 0, Strength = 0 }
	end,
}
cache.Icons = {}
loadModule = function(name)
	if cache[name] then
		return cache[name]
	end
	local shared = project .. "/src/shared/" .. name .. ".lua"
	local path = if fs.isFile(shared) then shared else project .. "/src/server/" .. name .. ".lua"
	local env = table.clone(r)
	env.game, env.script, env.require, env.warn, env.task = game, { Parent = parent }, loadModule, warn, mockTask
	env.Random = {
		new = function()
			return {
				NextNumber = function()
					return 0.5
				end,
				NextInteger = function(_, a)
					return a
				end,
			}
		end,
	}
	cache[name] = luau.load(fs.readFile(path), { environment = env, debugName = name })()
	return cache[name]
end
local session = loadModule("SessionData")
session.Init()
session.AddEggs(player, { [byRank[1]] = 2 })
assert(next((session.HatchEggs(player, os.time() + 10000))) == nil, "unloaded profile cannot hatch")
local early = session.GetEggs(player)[1]
records.u_1234 = { pets = { [byRank[2]] = 1 }, eggs = { eggs.Create(byRank[3], 1, 0, "saved") }, money = 100 }
tasks[1].f(table.unpack(tasks[1].args)) -- actual loadPlayer, no autosave loop
assert(session.IsLoaded(player) and #session.GetEggs(player) == 2, "merge pending rewards during async load")
assert(session.GetOwnedPets(player)[byRank[2]] == 1, "old pets untouched")
local rewardOwned = session.GetRewardOwned(player)
assert(rewardOwned[byRank[1]] == 2 and rewardOwned[byRank[3]] == 1)
assert(
	session.GetSpareCount(player, byRank[1]) == 0 and not session.RemovePets(player, { [byRank[1]] = 1 }),
	"unhatched eggs cannot be spent"
)
local firstHatch = session.HatchEggs(player, os.time())
assert(firstHatch[byRank[3]] == 1 and firstHatch[byRank[1]] == nil, "due offline eggs hatch once")
assert(session.Save(player))
assert(#records.u_1234.eggs == 1 and records.u_1234.pets[byRank[3]] == 1, "hatch saved atomically")
snapshotHook = function()
	session.HatchEggs(player, early.readyAt)
end
assert(session.Save(player))
assert(
	#records.u_1234.eggs == 1 and records.u_1234.pets[byRank[1]] == nil,
	"save snapshot cannot contain both egg and hatched credit"
)
assert(session.Save(player))
assert(#records.u_1234.eggs == 0 and records.u_1234.pets[byRank[1]] == 2)
snapshotHook = function()
	session.AddEggs(player, { [byRank[6]] = 1 })
	session.AddReceipt(player, "concurrent-reward")
end
assert(session.Save(player))
assert(
	#records.u_1234.eggs == 0 and not table.find(records.u_1234.receipts, "concurrent-reward"),
	"in-flight save cannot store a receipt before its egg"
)
assert(session.Save(player))
assert(#records.u_1234.eggs == 1 and table.find(records.u_1234.receipts, "concurrent-reward"))

-- Duplicate handling counts eggs, and paid pulls persist eggs before acknowledging receipts.
local rewards = loadModule("PullRewards")
cache.LootEngine.rollPulls = function()
	return { drops = { byRank[1], byRank[1] }, pity = 0, pulls = 2 }
end
session.AddEggs(player, { [byRank[1]] = 2 }) -- 2 pets + 2 eggs, only one more slot remains
local details = rewards.Grant(player, 2, 0)
assert(details.eggs and details.drops[1].Egg and details.drops[2].Sold and details.sold > 0)
assert(session.GetOwnedPets(player)[byRank[1]] == 2 and session.GetRewardOwned(player)[byRank[1]] == 5)
local monetization = loadModule("MonetizationController")
local decision = r.Enum.ProductPurchaseDecision
local info = { PlayerId = 1234, ProductId = 3718429232, PurchaseId = "aura-1" }
assert(monetization.ProcessReceipt(info) == decision.PurchaseGranted)
assert(session.Get(player).upgrades.AstralAura == 1 and records.u_1234.upgrades.AstralAura == 1)
assert(monetization.ProcessReceipt(info) == decision.PurchaseGranted, "duplicate receipt safe")
info.PurchaseId = "aura-2"
failSave = true
assert(monetization.ProcessReceipt(info) == decision.NotProcessedYet, "failed save never acknowledged")
failSave = false
assert(monetization.ProcessReceipt(info) == decision.PurchaseGranted)
local n = session.GetTotalPulls(player)
cache.LootEngine.rollPulls = function()
	return { drops = { byRank[4] }, pity = 0, pulls = 1 }
end
local paid = { PlayerId = 1234, ProductId = 3717917143, PurchaseId = "egg-purchase" }
assert(monetization.ProcessReceipt(paid) == decision.PurchaseGranted)
assert(records.u_1234.totalPulls == n + 1 and records.u_1234.pets[byRank[4]] == nil)
assert(session.GetRewardOwned(player)[byRank[4]] == 1)
assert(monetization.ProcessReceipt(paid) == decision.PurchaseGranted and session.GetTotalPulls(player) == n + 1)

-- A fresh server loads the persisted eggs and hatches them, without crediting them again on the next tick.
services.Players.PlayerRemoving:Fire(player)
cache.SessionData = nil
tasks = {}
local rejoined = loadModule("SessionData")
rejoined.Init()
tasks[1].f(table.unpack(tasks[1].args))
assert(rejoined.IsLoaded(player))
local before = rejoined.GetRewardOwned(player)
rejoined.HatchEggs(player, os.time() + 10000)
assert(#rejoined.GetEggs(player) == 0 and next((rejoined.HatchEggs(player, os.time() + 10000))) == nil)
for id, count in pairs(before) do
	assert(rejoined.GetOwnedPets(player)[id] == count)
end
assert(rejoined.Get(player).upgrades.AstralAura == 1, "permanent aura survives reconnect")

-- Actual controller (15 oct.) : one nest per egg, nests kept until the hatch, one hatch event per egg,
-- the pet leaves its nest, vacant bases clear their nests.
local base = r.Instance.new("Model")
local platform = r.Instance.new("Part")
platform.Name, platform.Size, platform.Parent = "BasePart", config.Arena.BaseSize, base
local owner = player
cache.BaseManager = {
	GetOwner = function()
		return owner
	end,
}
local celebrated = 0
local layout = loadModule("BaseLayout")
cache.BasePetsController = {
	Celebrate = function(_, ids, spots)
		celebrated += #ids
		for _, spot in pairs(spots) do
			assert(math.abs(spot.X) <= layout.HALF and math.abs(spot.Y) <= layout.HALF, "hatch spot inside the base")
		end
	end,
	IsShown = function()
		return true
	end,
}
local hatchEvents, inBaseEvents = 0, 0
cache.Remotes.EggHatched = {
	FireAllClients = function(_, userId, key, rarity, cf, petId, inBase)
		assert(userId == player.UserId and type(key) == "string" and typeof(cf) == "CFrame")
		assert(config.RarityIndex[rarity] and catalog.ById[petId].Rarity == rarity)
		hatchEvents += 1
		if inBase then
			inBaseEvents += 1
		end
	end,
}
cache.Remotes.Announcement = { FireAllClients = function() end }
cache.Remotes.Evolution = { FireAllClients = function() end, OnServerEvent = signal() }

-- Evolution machine (Config.Evolution): one egg leaves the nests, never hatches on its own, evolves up to its
-- secret limit, then hatches as the evolved form chosen by the player.
local now = os.time()
rejoined.AddEggs(player, { [byRank[3]] = 2 })
local lot
for _, egg in ipairs(rejoined.GetEggs(player)) do
	if egg.petId == byRank[3] and egg.count == 2 then
		lot = egg
	end
end
assert(lot, "a lot of two eggs")
assert(rejoined.StartEvolution(player, lot.id .. "#2", now), "egg enters the machine")
assert(not rejoined.StartEvolution(player, lot.id .. "#1", now), "one egg at a time")
local evolving = assert(rejoined.GetEvolving(player))
assert(lot.count == 1 and evolving.count == 1 and evolving.evolve.stage == 1, "only one egg of the lot moved")
assert(#eggs.Units({ evolving }) == 0, "the machine egg has no nest")
local _, hatchedNow = eggs.Collect({ evolving }, now + 10 ^ 7)
assert(next(hatchedNow) == nil, "the machine egg never hatches on its own")
evolving.evolve.maxStage = 2
assert(rejoined.TickEvolution(player, now) == nil, "nothing before the first attempt")
assert(rejoined.TickEvolution(player, evolving.evolve.nextAt) == "Evolved" and evolving.evolve.stage == 2)
assert(rejoined.TickEvolution(player, evolving.evolve.nextAt) == "Maxed" and evolving.evolve.done, "secret limit reached")
assert(rejoined.TickEvolution(player, now + 10 ^ 7) == nil, "no attempt after the limit")
local evolvedId = assert(rejoined.HatchEvolving(player))
assert(evolvedId == byRank[3] .. "__E2" and catalog.ById[evolvedId].Stage == 2, "hatches as the Évolué form")
assert(catalog.GetIncome(evolvedId) == catalog.GetIncome(byRank[3]) * config.Evolution.IncomeMultiplier[2])
assert(rejoined.GetEvolving(player) == nil and rejoined.Get(player).pets[evolvedId] == 1)
local maxed = 0
for i = 1, 1000 do
	if eggs.RollMaxStage((i - 0.5) / 1000) == #config.Evolution.Names then
		maxed += 1
	end
end
assert(maxed > 100 and maxed < 260, "most eggs never reach Ultime")
-- Saved evolution survives a reload.
local saved = eggs.Merge({ { id = "x", petId = byRank[1], count = 1, startedAt = 1, readyAt = 2,
	evolve = { stage = 2, maxStage = 3, nextAt = 99, done = false } } }, {})
assert(saved[1].evolve and saved[1].evolve.stage == 2 and saved[1].evolve.maxStage == 3)
table.clear(rejoined.GetEggs(player))
rejoined.AddEggs(player, { [byRank[1]] = 3, [byRank[8]] = 1 })
local controller = loadModule("EggController")
controller.Init({ base })
mockTask.wait = coroutine.yield
local loop = coroutine.create(tasks[#tasks].f)
assert(coroutine.resume(loop))
local folder = base:FindFirstChild("Eggs")
local nestsUsed = {}
for _, anchor in ipairs(folder:GetChildren()) do
	assert(anchor:GetAttribute("Rarity") and not anchor:GetAttribute("PetId"), "eggs keep their pet secret")
	local nest = anchor:GetAttribute("Nest")
	assert(nest and not nestsUsed[nest], "one egg per nest")
	nestsUsed[nest] = true
end
assert(#folder:GetChildren() == 4, "each egg is shown, not one per rarity")
assert(hatchEvents == 0)
-- A new egg does not move the others.
local before = {}
for _, anchor in ipairs(folder:GetChildren()) do
	before[anchor.Name] = anchor:GetAttribute("Nest")
end
rejoined.AddEggs(player, { [byRank[2]] = 1 })
assert(coroutine.resume(loop))
assert(#folder:GetChildren() == 5)
for name, nest in pairs(before) do
	assert(folder:FindFirstChild(name):GetAttribute("Nest") == nest, "nests are kept until the hatch")
end
for _, egg in ipairs(rejoined.GetEggs(player)) do
	egg.startedAt, egg.readyAt = 0, 0
end
assert(coroutine.resume(loop))
assert(#folder:GetChildren() == 0 and hatchEvents == 5 and celebrated == 3)
assert(inBaseEvents == 3, "one pet per species walks out of its nest")
assert(coroutine.resume(loop))
assert(hatchEvents == 5 and celebrated == 3, "subsequent ticks do not replay hatches")
-- More eggs than nests: the rest wait for a free nest.
rejoined.AddEggs(player, { [byRank[1]] = layout.MAX_NESTS + 3 })
assert(coroutine.resume(loop))
assert(#folder:GetChildren() == layout.MAX_NESTS and folder:GetAttribute("Waiting") == 3)
owner = nil
assert(coroutine.resume(loop))
assert(#folder:GetChildren() == 0, "vacated bases remove all egg visuals")
-- Paid aura builds on both Roblox avatar rigs, runs only on the ground and clears when hidden/teleported.
r.implementMethod("ParticleEmitter", "Clear", function() end)
r.implementMethod("Trail", "Clear", function() end)
local aura = loadModule("PlayerAuraVisual")
for _, feet in ipairs({ { "LeftFoot", "RightFoot" }, { "Left Leg", "Right Leg" } }) do
	local character = r.Instance.new("Model")
	local root = r.Instance.new("Part")
	root.Name, root.Size, root.Parent = "HumanoidRootPart", V(2, 2, 1), character
	local humanoid = r.Instance.new("Humanoid")
	humanoid.Parent = character
	for _, name in ipairs(feet) do
		local foot = r.Instance.new("Part")
		foot.Name, foot.Parent = name, character
	end
	local rig = assert(aura.Create(character))
	assert(#rig.trails == 3 and #rig.shards == 6)
	assert(aura.CanShow(true, 100, 0, 10, 20, false))
	assert(not aura.CanShow(false, 100, 0, 10, 20, false))
	assert(not aura.CanShow(true, 0, 0, 10, 20, false))
	assert(not aura.CanShow(true, 100, 15, 10, 20, false))
	assert(aura.IsRunning(20, true, false) and not aura.IsRunning(20, false, false))
	aura.Update(rig, 10, true, true)
	assert(rig.trails[1].Enabled and rig.particles[1].Enabled)
	root.CFrame = CF(100, 0, 0)
	aura.Update(rig, 11, true, true)
	assert(not rig.trails[1].Enabled, "teleport must not draw a giant trail")
	aura.Update(rig, 12, false, true)
	assert(not rig.particles[1].Enabled and rig.shards[1].Transparency == 1)
	aura.Destroy(rig)
	assert(not character:FindFirstChild("AstralAura"))
end
print("PASS: eggs, persistence, rewards, receipts, replication and R6/R15 player aura")
