-- Offline checks of the actual server analytics and client tutorial modules.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local project = require("@lune/process").args[1]
local now, studio, fail = 0, false, false
local jobs, events = {}, {}
local warnings = 0
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in ipairs(callbacks) do
				callback(...)
			end
		end,
	}
end
local mockTask = {}
mockTask.spawn = function(fn, ...)
	local args = { ... }
	table.insert(jobs, { at = now, co = coroutine.create(function()
		fn(table.unpack(args))
	end) })
end
mockTask.defer = mockTask.spawn
mockTask.delay = function(delay, fn)
	table.insert(jobs, { at = now + delay, co = coroutine.create(fn) })
end
mockTask.wait = function(delay)
	return coroutine.yield(delay or 0.01)
end
local function advance(seconds)
	local finish = now + seconds
	while true do
		table.sort(jobs, function(a, b)
			return a.at < b.at
		end)
		if #jobs == 0 or jobs[1].at > finish then
			break
		end
		local job = table.remove(jobs, 1)
		now = job.at
		local ok, delay = coroutine.resume(job.co)
		assert(ok, delay)
		if coroutine.status(job.co) ~= "dead" then
			table.insert(jobs, { at = now + delay, co = job.co })
		end
	end
	now = finish
end
local function actor()
	local attributes, signals = {}, {}
	local player = { Parent = true, Name = "Tester", Character = nil }
	function player:GetAttribute(name)
		return attributes[name]
	end
	function player:GetAttributeChangedSignal(name)
		signals[name] = signals[name] or signal()
		return signals[name]
	end
	function player:SetAttribute(name, value)
		local changed = attributes[name] ~= value
		attributes[name] = value
		if changed and signals[name] then
			signals[name]:Fire()
		end
	end
	return player
end
local function record(kind, player, name, value, fields)
	if fail then
		error("Injected AnalyticsService outage")
	end
	table.insert(events, { kind = kind, player = player, name = name, value = value, fields = fields })
end
local services = {
	AnalyticsService = {
		LogCustomEvent = function(_, ...)
			record("custom", ...)
		end,
		LogOnboardingFunnelStepEvent = function(_, player, step, name, fields)
			record("funnel", player, name, step, fields)
		end,
	},
	RunService = {
		IsStudio = function()
			return studio
		end,
	},
}
local env = table.clone(r)
env.game = {
	GetService = function(_, name)
		return assert(services[name], name)
	end,
}
env.task, env.os = mockTask, {
	clock = function()
		return now
	end,
}
env.warn = function()
	warnings += 1
end
local analytics = luau.load(fs.readFile(project .. "/src/server/OnboardingAnalytics.lua"), { environment = env })()
local function count(kind, name, player)
	local n = 0
	for _, event in events do
		if event.kind == kind and (not name or event.name == name) and (not player or event.player == player) then
			n += 1
		end
	end
	return n
end
local p = actor()
analytics.Joined(p)
advance(2)
analytics.Mark(p, "Pickup") -- gameplay before async DataStore finishes
advance(3)
local progress = analytics.Restore(nil, true)
analytics.Loaded(p, progress)
advance(0)
assert(progress.stage == 2 and progress.visits == 1)
for _, event in events do
	if event.name == "FirstActionSeconds" and event.fields.CustomField03 == "Pickup" then
		assert(event.value == 2, "load latency replaced actual pickup time")
	end
end
analytics.Mark(p, "Upgraded") -- shop can occur before a hatch
analytics.Mark(p, "EggReceived") -- daily gift before a successful throw
analytics.Mark(p, "Hatched")
advance(0)
assert(progress.stage == 2, "out-of-order action invented an earlier funnel step")
assert(count("funnel", nil, p) == 2)
analytics.Mark(p, "Scored")
analytics.Mark(p, "Scored")
analytics.Mark(p, "FakeStep")
advance(0)
assert(progress.stage == 6 and count("funnel", nil, p) == 6, "steps must be ordered and deduplicated")
local snapshot = analytics.Snapshot(progress)
snapshot.reached.Pickup = false
assert(progress.reached.Pickup, "save snapshot shares mutable flags")
snapshot = analytics.Snapshot(progress)
analytics.Leaving(p)
advance(0)
analytics.Joined(p)
local restored = analytics.Restore(snapshot, false)
analytics.Loaded(p, restored)
advance(0)
assert(restored.visits == 2 and restored.stage == 7)
assert(count("funnel", nil, p) == 7, "reconnect duplicated old funnel events")
analytics.Dismissed(p, true)
analytics.Dismissed(p, false)
advance(0)
assert(count("custom", "TutorialDismissed", p) == 1)
analytics.Leaving(p)
analytics.Leaving(p)
advance(0)
assert(count("custom", "SessionEndedSeconds", p) == 2)
local legacy = actor()
analytics.Joined(legacy)
local old = analytics.Restore(nil, false)
analytics.Loaded(legacy, old)
analytics.Mark(legacy, "Pickup")
advance(0)
assert(count("funnel", nil, legacy) == 0, "existing players contaminated new-user funnel")
local bad = analytics.Restore(
	{ version = 1, newPlayer = true, visits = 0 / 0, stage = 999, reached = { Hatched = true, Fake = true } },
	false
)
assert(bad.visits == 0 and bad.stage == 0 and bad.reached.Fake == nil)
fail = true
analytics.Mark(legacy, "Scored")
advance(0)
assert(old.reached.Scored and warnings > 0, "analytics outage broke gameplay")
fail, studio = false, true
local before = #events
analytics.Mark(legacy, "EggReceived")
advance(0)
assert(#events == before, "Studio sent live analytics")
studio = false
print(
	"PASS: ordered/persisted milestones, early actions, new/existing cohorts, snapshots, deduplication, failure isolation and Studio exclusion"
)

-- Actual tutorial: no premature completion on egg delivery, resume and skip.
local playerGui = r.Instance.new("Folder")
local terrain = r.Instance.new("Terrain")
local render = signal()
local localPlayer = actor()
function localPlayer:WaitForChild()
	return playerGui
end
local modules = {
	BaseLayout = { IncubatorCenter = r.Vector2.new(0, 31) },
	Remotes = {
		TutorialDone = {
			FireServer = function(_, skipped)
				table.insert(events, { kind = "dismiss", value = skipped })
			end,
		},
	},
	ScreenScale = {
		BOTTOM_RESERVED = 100,
		isTouch = function()
			return false
		end,
		isConsole = function()
			return false
		end,
		attach = function(parent)
			local frame = r.Instance.new("Frame")
			frame.Parent = parent
			return frame
		end,
	},
	Sounds = { play = function() end },
	Toast = { show = function() end },
	Icons = {
		id = function()
			return ""
		end,
		image = function(parentInstance)
			local image = r.Instance.new("ImageLabel")
			image.Parent = parentInstance
			return image
		end,
	},
}
local parent = setmetatable({}, {
	__index = function(_, name)
		return name
	end,
})
services.Players = { LocalPlayer = localPlayer }
services.ReplicatedStorage = {
	Shared = parent,
	GetAttribute = function()
		return "Feeding"
	end,
}
services.RunService.RenderStepped = render
services.GuiService = { SelectedObject = nil }
services.UserInputService = { GamepadEnabled = false }
services.Workspace = {
	Terrain = terrain,
	FindFirstChild = function()
		return nil
	end,
	GetServerTimeNow = function()
		return now
	end,
}
services.TweenService = {
	Create = function(_, object, _, properties)
		return {
			Play = function()
				for key, value in properties do
					object[key] = value
				end
			end,
		}
	end,
}
env.script = { Parent = parent }
env.TweenInfo = {
	new = function()
		return {}
	end,
}
env.os = {
	clock = function()
		return now
	end,
}
env.require = function(name)
	return assert(modules[name], name)
end
modules.MenuKit = {
	anyOpen = function()
		return false
	end,
}
modules.Typography = luau.load(fs.readFile(project .. "/src/shared/Typography.lua"), { environment = env })()
local activated = {}
r.implementProperty("GuiButton", "Activated", function(instance)
	activated[instance] = activated[instance] or signal()
	return activated[instance]
end)
-- Écran « but du jeu » (26 oct.) : il passe avant la 1re étape, et le tutoriel ne démarre qu'après JOUER.
local function pressPlay()
	local goal = assert(playerGui:FindFirstChild("GameGoal"), "goal screen missing")
	assert(goal.Enabled, "goal screen not shown before the tutorial")
	assert(goal:FindFirstChild("Play", true)).Activated:Fire()
	assert(not goal.Enabled, "goal screen stayed open after JOUER")
end
luau.load(fs.readFile(project .. "/src/client/Tutorial.client.lua"), { environment = env })()
advance(10)
local gui = assert(playerGui:FindFirstChild("Tutorial"))
assert(not gui.Enabled, "tutorial appeared before profile loaded")
assert(not playerGui:FindFirstChild("GameGoal").Enabled, "goal screen appeared before profile loaded")
localPlayer:SetAttribute("DataLoaded", true)
advance(2)
assert(not gui.Enabled, "tutorial panel shown over the goal screen")
pressPlay()
assert(gui.Enabled)
localPlayer:SetAttribute("Onboarding_Pickup", true)
localPlayer:SetAttribute("Onboarding_Scored", true)
localPlayer:SetAttribute("Onboarding_EggReceived", true)
advance(4)
assert(gui.Enabled and count("dismiss") == 0, "receiving an egg ended the tutorial")
localPlayer:SetAttribute("Onboarding_Hatched", true)
advance(2.9)
assert(gui.Enabled)
advance(0.2)
assert(not gui.Enabled and count("dismiss") == 1, "actual hatch did not finish tutorial")
print("PASS: tutorial waits for profile and actual hatch, allows reveal before finishing")

-- A reconnect resumes at the egg, and skipping cannot submit a gameplay step.
playerGui:ClearAllChildren()
localPlayer = actor()
function localPlayer:WaitForChild()
	return playerGui
end
services.Players.LocalPlayer = localPlayer
localPlayer:SetAttribute("DataLoaded", true)
localPlayer:SetAttribute("Onboarding_Pickup", true)
localPlayer:SetAttribute("Onboarding_Scored", true)
localPlayer:SetAttribute("Onboarding_EggReceived", true)
luau.load(fs.readFile(project .. "/src/client/Tutorial.client.lua"), { environment = env })()
advance(2)
pressPlay()
gui = assert(playerGui:FindFirstChild("Tutorial"))
local found = false
for _, child in gui:GetDescendants() do
	if child:IsA("TextLabel") and child.Text:find("ŒUF VA ÉCLORE", 1, true) then
		found = true
	end
end
assert(found and gui.Enabled, "reconnect restarted from pickup instead of pending egg")
local skip = gui:FindFirstChild("Skip", true)
skip.Activated:Fire()
assert(not gui.Enabled and count("dismiss") == 2)
assert(events[#events].kind == "dismiss" and events[#events].value == true, "skip reason not sent")
print("PASS: tutorial resumes persisted progress and records skip separately")

-- Joining during digestion: guide toward the starter egg, then the first upgrade.
render = signal()
services.RunService.RenderStepped = render
playerGui:ClearAllChildren()
localPlayer = actor()
function localPlayer:WaitForChild()
	return playerGui
end
services.Players.LocalPlayer = localPlayer
local character = r.Instance.new("Model")
local rootPart = r.Instance.new("Part")
rootPart.Name, rootPart.Position, rootPart.Parent = "HumanoidRootPart", r.Vector3.zero, character
localPlayer.Character = character
local map = r.Instance.new("Folder")
local base = r.Instance.new("Model")
base.Name, base.Parent = "Base_1", map
local eggFolder = r.Instance.new("Folder")
eggFolder.Name, eggFolder.Parent = "Eggs", base
local eggAnchor = r.Instance.new("Part")
eggAnchor.Position, eggAnchor.Parent = r.Vector3.new(25, 3, 10), eggFolder
eggAnchor:SetAttribute("ReadyAt", now + 15)
localPlayer:SetAttribute("BaseIndex", 1)
localPlayer:SetAttribute("DataLoaded", true)
localPlayer:SetAttribute("Onboarding_Pickup", true)
localPlayer:SetAttribute("StarterEggGiven", true)
local phase = "Digesting"
services.ReplicatedStorage.GetAttribute = function()
	return phase
end
services.Workspace.FindFirstChild = function(_, name)
	return if name == "Map" then map else nil
end
luau.load(fs.readFile(project .. "/src/client/Tutorial.client.lua"), { environment = env })()
advance(2)
pressPlay()
render:Fire()
local newestTarget = nil
for _, item in terrain:GetChildren() do
	if item.Name == "TutorialTarget" then
		newestTarget = item
	end
end
assert(newestTarget.WorldPosition.X == 25, "closed hole guidance ignored the starter egg")
localPlayer:SetAttribute("StarterBonusPaid", true)
localPlayer:SetAttribute("Onboarding_Hatched", true)
render:Fire()
gui = playerGui:FindFirstChild("Tutorial")
local upgradeHint = false
for _, item in gui:GetDescendants() do
	if item:IsA("TextLabel") and item.Text:find("BOUTIQUE", 1, true) then
		upgradeHint = true
	end
end
assert(upgradeHint and gui.Enabled, "digestion did not suggest the first affordable upgrade")
local looseItems = r.Instance.new("Folder")
looseItems.Name, looseItems.Parent = "LooseItems", map
local heldItem = r.Instance.new("Part")
heldItem:SetAttribute("Holder", localPlayer.Name)
heldItem.Parent = looseItems
phase = "Feeding"
render:Fire()
assert(newestTarget.WorldPosition.X == 0 and gui.Enabled, "tutorial did not return to learning a throw")
print("PASS: digestion guides to starter egg and upgrade, then resumes the core loop")
