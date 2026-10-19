-- Actual StealController: protection must hold even with a direct remote request.
local r = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
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
local world = r.Instance.new("Folder")
local map = r.Instance.new("Folder")
map.Name, map.Parent = "Map", world
r.implementMethod("Instance", "WaitForChild", function(instance, name)
	return assert(instance:FindFirstChild(name))
end)
local promptSignals = {}
r.implementProperty("ProximityPrompt", "Triggered", function(instance)
	promptSignals[instance] = promptSignals[instance] or signal()
	return promptSignals[instance]
end)
local function player(name, id)
	local p = r.Instance.new("Player")
	p.Name, p.DisplayName, p.UserId, p.Parent = name, name, id, world
	local character = r.Instance.new("Model")
	local root, humanoid = r.Instance.new("Part"), r.Instance.new("Humanoid")
	humanoid.Health = 100
	root.Position = r.Vector3.zero
	root.Name, root.Parent, humanoid.Parent = "HumanoidRootPart", character, character
	p.Character = character
	return p
end
local owner, thief = player("Owner", 1), player("Thief", 2)
local base = r.Instance.new("Model")
local platform = r.Instance.new("Part")
platform.Name, platform.Parent = "BasePart", base
local anchor = r.Instance.new("Part")
anchor:SetAttribute("PetId", "Common")
local protected = { [owner] = true, [thief] = true }
local petTriggered, released = signal(), signal()
local pick, throws = signal(), signal()
local reserved = 0
local petPosition = r.Vector3.zero
local modules = {
	Config = {
		Steal = { OnlyDuringDigesting = false, MaxDistance = 15, MaxCarryTime = 30, RecoverPromptDistance = 8 },
		Carry = {
			WeightExponent = 3,
			StrengthPerCapacity = 10,
			Slow = 0.8,
			MinSpeed = 0.3,
			MaxSpeed = 0.95,
			MaxCarryTime = 180,
			WalkHomeSpeed = 9,
		},
		Sacrifice = {},
		Training = { Strength = { Base = 70 } },
		RarityIndex = { Commun = 1 },
		Loot = { AnnounceMinRarity = 5 },
	},
	Perks = {},
	PetCatalog = { ById = { Common = { Rarity = "Commun", Name = "Common" } } },
	PetPath = {
		build = function(a, b)
			return { a, b }
		end,
		encode = function()
			return "path"
		end,
		at = function(points)
			return points[1], r.Vector3.zAxis, false
		end,
	},
	PetSizes = {
		Of = function()
			return 1
		end,
		Radius = function()
			return 1
		end,
	},
	PetWander = {
		groundOf = function()
			return r.CFrame.new()
		end,
	},
	Remotes = {
		PickLoosePet = { OnServerEvent = pick },
		ThrowPet = { OnServerEvent = throws },
		StealNotice = { FireClient = function() end },
		StealResult = { FireClient = function() end },
	},
	BaseManager = {
		GetBase = function()
			return base
		end,
		GetOwner = function()
			return owner
		end,
	},
	BasePetsController = {
		PetTriggered = petTriggered,
		GetBaseOf = function()
			return base
		end,
		GetReserved = function()
			return reserved
		end,
		GetPetPosition = function()
			return petPosition
		end,
		Reserve = function(_, _, change)
			reserved += change
		end,
	},
	BlackholeTiers = {},
	GameLoopManager = {
		GetState = function()
			return "Digesting"
		end,
	},
	ItemInteraction = {
		HeldReleased = released,
		ReleaseHeld = function(p)
			released:Fire(p)
		end,
	},
	PowerController = { Reveal = function() end },
	Quests = {},
	SessionData = {
		IsLoaded = function()
			return true
		end,
		GetSpareCount = function()
			return 1
		end,
		IsNewcomerProtected = function(p)
			return protected[p]
		end,
		EndNewcomerProtection = function(p)
			protected[p] = false
		end,
		RefreshSpeed = function() end,
		OnLeaving = function() end,
	},
}
local parent = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
local services = {
	Players = { PlayerRemoving = signal() },
	ReplicatedStorage = { Shared = parent },
	RunService = { Heartbeat = signal() },
	Workspace = {
		WaitForChild = function()
			return map
		end,
		GetServerTimeNow = function()
			return 100
		end,
	},
}
local env = table.clone(r)
env.game = {
	GetService = function(_, name)
		return assert(services[name], name)
	end,
}
env.script = { Parent = parent }
env.require = function(name)
	return assert(modules[name], name)
end
env.task = { delay = function() end, spawn = function() end }
local steal = luau.load(fs.readFile(project .. "/src/server/StealController.lua"), { environment = env })()
steal.Init()
petTriggered:Fire(anchor, thief)
assert(reserved == 0 and thief:GetAttribute("CarryingPet") == nil, "direct steal bypassed owner protection")
assert(protected[thief], "rejected steal removed attacker's protection")
petPosition = r.Vector3.new(0, 32, 0)
petTriggered:Fire(anchor, owner)
assert(
	reserved == 0 and owner:GetAttribute("CarryingPet") == nil,
	"ground player carried a pet through the upper floor"
)
petPosition = r.Vector3.zero
petTriggered:Fire(anchor, owner)
assert(reserved == 1 and owner:GetAttribute("CarryingOwn"), "protection blocked carrying own pet")
assert(protected[owner], "carrying own pet removed protection")
released:Fire(owner)
local loose = assert(map.LoosePets:FindFirstChild("Common"))
pick:Fire(thief, loose)
assert(thief:GetAttribute("CarryingPet") == nil and loose.Parent, "loose-pet remote bypassed protection")
assert(protected[thief])
protected[owner] = false
thief.Character.HumanoidRootPart.Position = r.Vector3.new(0, 32, 0)
pick:Fire(thief, loose)
assert(
	thief:GetAttribute("CarryingPet") == nil and loose.Parent,
	"upper-floor player grabbed a loose pet through the floor"
)
thief.Character.HumanoidRootPart.Position = r.Vector3.zero
pick:Fire(thief, loose)
assert(thief:GetAttribute("CarryingPet") == "Common" and not protected[thief], "valid theft must end thief protection")
assert(reserved == 1 and not loose.Parent, "loose pickup duplicated the reservation")
print(
	"PASS: actual server rejects protected base/loose theft, permits own carry, preserves shield on rejection and removes it on valid theft"
)
