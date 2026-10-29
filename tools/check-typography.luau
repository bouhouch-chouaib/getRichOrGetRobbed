-- Offline integration of the actual typography and prompt presentation modules.
local r = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local project = process.args[1]
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			listeners[fn] = true
			return {
				Disconnect = function()
					listeners[fn] = nil
				end,
			}
		end,
		Fire = function(_, ...)
			for fn in pairs(listeners) do
				fn(...)
			end
		end,
	}
end
local events = {}
local function event(instance, name)
	events[instance] = events[instance] or {}
	events[instance][name] = events[instance][name] or signal()
	return events[instance][name]
end
for class, names in pairs({
	Instance = { "Changed", "Destroying", "DescendantAdded" },
	GuiObject = { "InputBegan" },
	ProximityPrompt = { "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
}) do
	for _, name in ipairs(names) do
		r.implementProperty(class, name, function(instance)
			return event(instance, name)
		end)
	end
end
r.implementMethod("Instance", "WaitForChild", function(instance, name)
	return assert(instance:FindFirstChild(name))
end)
local begins, ends = 0, 0
r.implementMethod("ProximityPrompt", "InputHoldBegin", function()
	begins += 1
end)
r.implementMethod("ProximityPrompt", "InputHoldEnd", function()
	ends += 1
end)
local services = {}
local env = table.clone(r)
env.game = {
	GetService = function(_, name)
		return assert(services[name], name)
	end,
}
local typography = luau.load(fs.readFile(project .. "/src/shared/Typography.lua"), { environment = env })()
assert(
	typography.Face.Family == "rbxasset://fonts/families/Montserrat.json"
		and typography.Face.Weight == r.Enum.FontWeight.Heavy
)
for _, class in ipairs({ "TextLabel", "TextButton" }) do
	local label = r.Instance.new(class)
	typography.Fit(label, 24)
	typography.Fit(label, 20)
	assert(label.FontFace == typography.Face and label.TextScaled and #label:GetChildren() == 1)
	assert(label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize == 20)
end
local paragraph = r.Instance.new("TextLabel")
paragraph.AutomaticSize = r.Enum.AutomaticSize.Y
typography.Fit(paragraph, 20)
assert(
	not paragraph.TextScaled and #paragraph:GetChildren() == 0,
	"auto-height paragraphs must retain natural wrapping"
)
local player = r.Instance.new("Folder")
local gui = r.Instance.new("PlayerGui")
gui.Parent = player
local workspace = r.Instance.new("Folder")
local part = r.Instance.new("Part")
part.Parent = workspace
local prompt = r.Instance.new("ProximityPrompt")
prompt.ActionText, prompt.ObjectText = "Voler", "Œuf légendaire"
prompt.HoldDuration = 0.6
prompt.ClickablePrompt = true
prompt.Parent = part
services.Players = { LocalPlayer = player }
services.ReplicatedStorage = { Shared = { Typography = "Typography" } }
services.Workspace = workspace
services.ProximityPromptService = { PromptShown = signal(), PromptHidden = signal() }
services.UserInputService = {
	InputEnded = signal(),
	WindowFocusReleased = signal(),
	GetStringForKeyCode = function()
		return "E"
	end,
	-- Pas d'image de bouton : la bulle retombe sur la lettre (« X »).
	GetImageForKeyCode = function()
		return ""
	end,
}
local tweenDuration = 0
services.TweenService = {
	Create = function(_, object, info, properties)
		tweenDuration = info.Time
		return {
			Play = function()
				for k, v in pairs(properties) do
					object[k] = v
				end
			end,
			Cancel = function() end,
		}
	end,
}
local rgb = r.Color3.fromRGB
local style = {
	Colors = {
		Panel = rgb(31, 31, 45),
		PanelText = rgb(220, 220, 235),
		Cyan = rgb(54, 204, 254),
		Red = rgb(232, 30, 36),
		Green = rgb(110, 235, 40),
		Purple = rgb(168, 40, 252),
	},
	corner = function() end,
	stroke = function() end,
}
style.text = function(parent, text, size, color)
	local label = r.Instance.new("TextLabel")
	label.Text, label.TextColor3 = text, color or rgb(255, 255, 255)
	label.Parent = parent
	typography.Fit(label, size)
	return label
end
env.script = { Parent = { UiStyle = "UiStyle" } }
env.require = function(name)
	return if name == "Typography" then typography else style
end
env.TweenInfo = {
	new = function(t)
		return { Time = t }
	end,
}
luau.load(fs.readFile(project .. "/src/client/PromptStyle.client.lua"), { environment = env })()
assert(prompt.Style == r.Enum.ProximityPromptStyle.Custom)
local service = services.ProximityPromptService
local function textFor(value)
	for _, v in ipairs(gui:GetDescendants()) do
		if v:IsA("TextLabel") and v.Text == value then
			return v
		end
	end
	error("Missing text: " .. value)
end
service.PromptShown:Fire(prompt, r.Enum.ProximityPromptInputType.Keyboard)
assert(textFor("E").FontFace == typography.Face and textFor("Œuf légendaire").FontFace == typography.Face)
prompt.ActionText = "Reprendre"
event(prompt, "Changed"):Fire("ActionText")
assert(textFor("Reprendre"))
event(prompt, "PromptButtonHoldBegan"):Fire()
assert(math.abs(tweenDuration - 0.6) < 0.0001)
local button = gui:FindFirstChild("StyledInteraction"):FindFirstChildOfClass("TextButton")
local mouse = { UserInputType = r.Enum.UserInputType.MouseButton1 }
event(button, "InputBegan"):Fire(mouse)
assert(begins == 1)
services.UserInputService.InputEnded:Fire(mouse)
assert(ends == 1)
service.PromptHidden:Fire(prompt)
assert(#gui:GetChildren() == 0)
prompt.ClickablePrompt = false
service.PromptShown:Fire(prompt, r.Enum.ProximityPromptInputType.Touch)
assert(textFor("ICI"))
button = gui:FindFirstChild("StyledInteraction"):FindFirstChildOfClass("TextButton")
event(button, "InputBegan"):Fire(mouse)
assert(begins == 1, "unclickable prompts must ignore mouse input")
event(button, "InputBegan"):Fire({ UserInputType = r.Enum.UserInputType.Touch })
assert(begins == 2, "mobile remains interactive regardless of ClickablePrompt")
service.PromptHidden:Fire(prompt)
assert(ends == 2 and #gui:GetChildren() == 0, "hiding cancels the hold and cleans up")
service.PromptShown:Fire(prompt, r.Enum.ProximityPromptInputType.Gamepad)
assert(textFor("X"))
event(prompt, "Destroying"):Fire()
assert(#gui:GetChildren() == 0)
print("PASS: font/size constraints, automatic-height paragraphs, keyboard/touch/gamepad prompts, holds and cleanup")
