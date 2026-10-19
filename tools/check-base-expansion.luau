-- Runs actual roster, magnet rules, floor geometry and server base pet placement offline.
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local project = require("@lune/process").args[1]
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
		end,
		Fire = function(_, ...)
			for _, fn in callbacks do
				fn(...)
			end
		end,
	}
end
local bindings = {}
r.implementProperty("BindableEvent", "Event", function(instance)
	bindings[instance] = bindings[instance] or signal()
	return bindings[instance]
end)
r.implementMethod("BindableEvent", "Fire", function(instance, ...)
	bindings[instance]:Fire(...)
end)
local cache, services = {}, {}
local clock = 100
local parent = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
local tasks = {}
local random = {
	NextNumber = function(_, a, b)
		return if a then (a + (b or 1)) / 2 else 0.5
	end,
	NextInteger = function(_, a)
		return a
	end,
}
local load
load = function(name)
	if cache[name] then
		return cache[name]
	end
	local path = project .. "/src/shared/" .. name .. ".lua"
	if not fs.isFile(path) then
		path = project .. "/src/server/" .. name .. ".lua"
	end
	local env = table.clone(r)
	env.game = {
		GetService = function(_, key)
			return assert(services[key], key)
		end,
	}
	env.script = { Parent = parent }
	env.require = load
	env.Random = {
		new = function()
			return random
		end,
	}
	env.os = table.clone(os)
	env.os.clock = function()
		return clock
	end
	env.task = {
		spawn = function(fn)
			table.insert(tasks, fn)
		end,
		wait = function()
			coroutine.yield()
		end,
	}
	cache[name] = luau.load(fs.readFile(path), { environment = env })()
	return cache[name]
end
services.ReplicatedStorage = { Shared = parent }
services.Players = { PlayerRemoving = signal() }
services.RunService = { Heartbeat = signal() }
services.Workspace = {
	GetServerTimeNow = function()
		return 100
	end,
}
local config, catalog = load("Config"), load("PetCatalog")
local expansion, roster, magnet = load("BaseExpansion"), load("PetRoster"), load("MagnetRules")

local function item(value, size, distance)
	local part = r.Instance.new("Part")
	part.Size, part.Position = r.Vector3.one * size, r.Vector3.new(distance, 0, 0)
	part:SetAttribute("Value", value)
	return part
end
local small, big, valuable, thrown = item(1, 2, 1), item(1, 4, 2), item(10, 3, 5), item(100, 6, 1)
local blocked = { [thrown] = true }
assert(magnet.Best({ small, big, valuable, thrown }, r.Vector3.zero, 10, function(p)
	return blocked[p] == true
end) == valuable)
valuable:SetAttribute("Holder", "someone")
assert(magnet.Best({ small, big, valuable, thrown }, r.Vector3.zero, 10, function(p)
	return blocked[p] == true
end) == big)
big:SetAttribute("Consumed", true)
assert(magnet.Best({ small, big }, r.Vector3.zero, 0.5, function()
	return false
end) == nil)
local near = item(1, 2, 0.5)
assert(magnet.Best({ small, near }, r.Vector3.zero, 10, function()
	return false
end) == near)
print("PASS: magnet prefers points, volume and distance; rejects thrown/held/consumed/out-of-range items")

local state = expansion.Restore(nil)
assert(expansion.Buy(state, 1, config.BaseFloors.Prices[1] - 1) == nil and state.floors == 0)
assert(expansion.Buy(state, 1, config.BaseFloors.Prices[1]) == 0 and state.floors == 1)
assert(expansion.Buy(state, 1, 1e20) == nil)
state.credits = 2
assert(expansion.Redeem(state, 1) == 0 and state.credits == 2)
assert(expansion.Redeem(state, 2) == 1 and state.credits == 1 and state.floors == 2)
local restored = expansion.Restore(table.clone(state))
assert(restored.floors == 2 and restored.credits == 1)
assert(expansion.Redeem(restored, 3) == 1 and restored.floors == 3)
assert(expansion.Capacity(0, 3) == 40 and expansion.Capacity(1, 3) == 41)
for i = 2, #config.Worlds do
	assert(config.Worlds[i].Price > config.Worlds[i - 1].Price)
end
assert(config.Worlds[7].Price == 12.5e15)
print("PASS: floor money/caps/credits/reconnect rules and rising world prices")

-- Ten valuable duplicates used to consume every slot and hide a new species.
local high = catalog.ByRarity.Sigma[1].Id
local low = catalog.ByRarity.Commun[1].Id
local selected = roster.Select({ [high] = 10, [low] = 1 }, 10, catalog.GetIncome)
assert(#selected == 10 and table.find(selected, low), "new species hidden by duplicates")
local counts = {}
for _, id in selected do
	counts[id] = (counts[id] or 0) + 1
end
assert(counts[high] == 9 and counts[low] == 1)
local world = r.Instance.new("Folder")
local base = r.Instance.new("Model")
base.Name, base.Parent = "Base_1", world
local platform = r.Instance.new("Part")
platform.Name, platform.CFrame, platform.Size, platform.Parent =
	"BasePart", r.CFrame.new(0, 0.5, 0), config.Arena.BaseSize, base
local player = r.Instance.new("Player")
player.Parent = world
local data = { pets = { [high] = 10, [low] = 1 }, rebirths = 0, expansion = { floors = 0, credits = 0 } }
cache.SessionData = {
	Get = function()
		return data
	end,
	GetSpareCount = function(_, id)
		return data.pets[id] or 0
	end,
}
cache.BaseManager = {
	GetOwner = function()
		return player
	end,
	GetBase = function()
		return base
	end,
}
cache.Remotes = { StealPet = { OnServerEvent = signal() } }
cache.OnboardingAnalytics = { Mark = function() end }
cache.Quests = {}
cache.Perks = {}
local economy, bases = load("EconomyController"), load("BasePetsController")
bases.Init({ base })
bases.Celebrate(player, { low }, { [low] = r.Vector2.new(0, 31) })
assert(bases.IsShown(player, low) and base.Pets:FindFirstChild(low), "actual controller hid new normal hatch")
local evolved = catalog.Variant(low, 2)
data.pets[evolved] = 1
bases.Celebrate(player, { evolved }, { [evolved] = r.Vector2.new(0, 14) })
assert(bases.IsShown(player, evolved), "actual controller hid new evolved hatch")
data.expansion.floors = 1
for _, entry in ipairs(catalog.List) do
	if #economy.GetTopPets(player) >= 20 then
		break
	end
	data.pets[entry.Id] = 1
end
bases.Celebrate(player, { low })
local upper = 0
for _, anchor in base.Pets:GetChildren() do
	local floor = anchor:GetAttribute("Floor")
	if floor > 0 then
		upper += 1
		assert(bases.GetPetPosition(anchor).Y >= config.BaseFloors.Height, "server pet position ignores floor height")
	end
end
assert(upper > 0, "floor expansion did not place any pets upstairs")
print("PASS: actual base controller displays normal/evolved species and positions upper-floor pets")

local geometry = load("BaseFloorGeometry")
for level = 1, 7 do
	local floor = geometry.Build(base, r.CFrame.new(0, 1, 0), level, r.Color3.fromRGB(60, 180, 255))
	local steps, parts = 0, 0
	for _, part in floor:GetChildren() do
		if part:IsA("BasePart") then
			parts += 1
			assert(part.Anchored)
			if part.Name == "Step" then
				steps += 1
				assert(
					part.Size.Y <= 1.5 and part.CFrame.Position.X - part.Size.X / 2 > 30,
					"stairs obstruct deck or have oversized risers"
				)
			end
		end
	end
	assert(steps == 24 and parts < 80)
	assert(math.abs(floor.Deck.CFrame.Position.Y + floor.Deck.Size.Y / 2 - (1 + level * 32)) < 0.001)
end
print("PASS: all seven floor models, deck heights, anchored parts and 24-step stairs")

-- Actual interaction controller: toggle, repeated attraction and long-flight regression.
local instanceSignals = {}
for class, name in pairs({ Player = "CharacterAdded", Humanoid = "Died", ProximityPrompt = "Triggered" }) do
	r.implementProperty(class, name, function(instance)
		instanceSignals[instance] = instanceSignals[instance] or signal()
		return instanceSignals[instance]
	end)
end
player.Name = "MagnetTester"
local character = r.Instance.new("Model")
local root = r.Instance.new("Part")
root.Name, root.Position, root.Parent = "HumanoidRootPart", r.Vector3.zero, character
local human = r.Instance.new("Humanoid")
human.Health, human.Parent = 100, character
player.Character = character
base:SetAttribute("OwnerName", player.Name)
local loose = r.Instance.new("Folder")
loose.Name, loose.Parent = "LooseItems", world
local spawns = r.Instance.new("Folder")
spawns.Name, spawns.Parent = "ItemSpawns", base
services.Workspace.FindFirstChild = function(_, name)
	return if name == "Map" then world else nil
end
services.Players.PlayerAdded = signal()
services.Players.GetPlayers = function()
	return { player }
end
cache.Perks.MagnetLevel = function()
	return 1
end
cache.Perks.ExtraCapacity = function()
	return 0
end
cache.PowerController = { Reveal = function() end }
cache.SessionData.GetUpgradeLevel = function()
	return 3
end
cache.SessionData.GrantStarterEgg = function() end
cache.SessionData.SetMagnetEnabled = function(p, enabled)
	p:SetAttribute("MagnetEnabled", enabled)
end
cache.Remotes.SetMagnet = { OnServerEvent = signal() }
cache.Remotes.ThrowItem = { OnServerEvent = signal() }
local grabbed = {}
cache.Remotes.ItemGrabbed = {
	FireClient = function(_, _, part)
		table.insert(grabbed, part)
	end,
}
local interactions = load("ItemInteraction")
interactions.Init()
local function rock(value, size, distance)
	local part = item(value, size, distance)
	part.Parent = spawns
	local prompt = r.Instance.new("ProximityPrompt")
	prompt.Parent = part
	interactions.Register(part)
	return part, prompt
end
local first = rock(100, 4, 2)
local second = rock(20, 5, 1)
local third = rock(1, 2, 1)
local pulse = coroutine.create(tasks[#tasks])
assert(coroutine.resume(pulse)) -- initial wait
local function tick()
	clock += 1
	local ok, err = coroutine.resume(pulse)
	assert(ok, err)
end
tick()
assert(#grabbed == 0, "purchased magnet started enabled")
cache.Remotes.SetMagnet.OnServerEvent:Fire(player, true)
tick()
assert(grabbed[1] == first, "actual magnet did not prioritize the highest-point rock")
cache.Remotes.ThrowItem.OnServerEvent:Fire(player, first)
assert(interactions.GetThrowInfo(first))
tick()
assert(grabbed[2] == second)
clock += 20
tick()
assert(grabbed[3] == third and #grabbed == 3, "thrown rock returned after old 2s timeout")
tick()
assert(#grabbed == 3)
cache.Remotes.SetMagnet.OnServerEvent:Fire(player, false)
local fourth, prompt = rock(200, 5, 1)
tick()
assert(#grabbed == 3, "disabled magnet still collected")
prompt.Triggered:Fire(player)
assert(grabbed[4] == fourth, "manual pickup stopped working with magnet off")
first:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player)
assert(grabbed[5] == first and interactions.GetThrowInfo(first) == nil, "manual pickup must restore a thrown item")
print("PASS: actual magnet starts off, toggles, prioritizes rocks and never reclaims its thrown item after 20 seconds")

-- Actual expansion controller: terminal, cap before payment, prompt route and base reassignment.
local currentOwner = player
cache.BaseManager.GetOwner = function()
	return currentOwner
end
cache.SessionData.Get = function()
	return data
end
data.loaded, data.money, data.tier = true, 1e12, 1
data.expansion = { floors = 0, credits = 0 }
cache.SessionData.BuyBaseFloor = function()
	local balance = expansion.Buy(data.expansion, data.tier, data.money)
	if balance == nil then
		return false
	end
	data.money = balance
	return true
end
cache.SessionData.Save = function()
	return true
end
local prompts, replies = 0, {}
services.MarketplaceService = {
	PromptProductPurchase = function(_, p, id)
		assert(p == player and id == 123456789)
		prompts += 1
	end,
}
cache.Remotes.BaseFloor = {
	OnServerEvent = signal(),
	FireClient = function(_, _, ok, message)
		table.insert(replies, { ok = ok, message = message })
	end,
}
local floorProduct
for _, product in config.Monetization.Products do
	if product.Key == "BaseFloor" then
		floorProduct = product
	end
end
assert(floorProduct)
local originalId = floorProduct.Id
floorProduct.Id = 123456789 -- test-only ID
local controller = load("BaseFloorController")
controller.Init({ base })
local floorLoop = coroutine.create(tasks[#tasks])
assert(coroutine.resume(floorLoop))
assert(base.FloorTerminal.ProximityPrompt:GetAttribute("OpensWindow") == "BaseFloors")
local function buy(action)
	clock += 1
	cache.Remotes.BaseFloor.OnServerEvent:Fire(player, action)
end
local balance = data.money
buy("invalid")
assert(data.money == balance and #replies == 0)
buy("Cash")
assert(data.expansion.floors == 1 and data.money == balance - config.BaseFloors.Prices[1])
assert(#base.UpperFloors:GetChildren() == 1 and base:GetAttribute("FloorsBuilt") == 1)
balance = data.money
buy("Cash")
buy("Robux")
assert(data.money == balance and prompts == 0 and not replies[#replies].ok, "floor cap permitted payment")
data.tier = 2
buy("Robux")
assert(prompts == 1 and data.expansion.floors == 1, "purchase prompt granted before receipt")
floorProduct.Id = 0
buy("Robux")
assert(prompts == 1 and not replies[#replies].ok, "unconfigured product attempted a real prompt")
currentOwner = nil
assert(coroutine.resume(floorLoop))
assert(#base.UpperFloors:GetChildren() == 0 and base:GetAttribute("FloorsBuilt") == 0)
currentOwner = player
assert(coroutine.resume(floorLoop))
assert(#base.UpperFloors:GetChildren() == 1, "reassigned base failed to restore floors")
floorProduct.Id = originalId
print("PASS: actual floor terminal, cash build, tier cap, Robux route, missing-ID guard and base reassignment")
