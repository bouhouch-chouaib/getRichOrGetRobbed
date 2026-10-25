--!strict
-- Crown : la couronne du plus riche du serveur (Config.Crown, server/CrownController). Une couronne et « ROI DU SERVEUR »
-- (avec ses défenses) au-dessus de la tête du roi, et un panneau sur sa base. Lit ReplicatedStorage "CrownUserId",
-- Player "CrownDefenses" et l'attribut "Crowned" des bases. Les annonces passent par client/HUD (Remotes.StealNotice).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Icons = require(ReplicatedStorage.Shared.Icons)
local Typography = require(ReplicatedStorage.Shared.Typography)

local GOLD = Color3.fromRGB(255, 205, 50)
local map = Workspace:WaitForChild("Map")

local headTag: BillboardGui? = nil
local baseTag: BillboardGui? = nil

local function label(parent: Instance, text: string, y: number, height: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = UDim2.fromScale(0, y)
	item.Size = UDim2.fromScale(1, height)
	item.FontFace = Typography.Face
	item.TextScaled = true
	item.TextColor3 = color
	item.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = item
	item.Parent = parent
	return item
end

local function clear()
	if headTag then
		headTag:Destroy()
		headTag = nil
	end
	if baseTag then
		baseTag:Destroy()
		baseTag = nil
	end
end

local function defensesText(king: Player): string
	local defenses = king:GetAttribute("CrownDefenses")
	local count = if type(defenses) == "number" then defenses else 0
	return if count > 0 then string.format("ROI DU SERVEUR  •  %d DÉFENSE%s", count, if count > 1 then "S" else "")
		else "ROI DU SERVEUR"
end

local function attachHead(king: Player)
	local character = king.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "CrownTag"
	tag.Adornee = head
	tag.Size = UDim2.fromScale(5, 2.6)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 220
	Icons.image(tag, "Crown", UDim2.fromScale(0.36, 0.62), UDim2.fromScale(0.32, 0))
	local title = label(tag, defensesText(king), 0.62, 0.38, GOLD)
	king:GetAttributeChangedSignal("CrownDefenses"):Connect(function()
		title.Text = defensesText(king)
	end)
	tag.Parent = head
	headTag = tag
end

local function attachBase()
	for _, base in ipairs(map:GetChildren()) do
		local platform = base:FindFirstChild("BasePart")
		if base:IsA("Model") and base:GetAttribute("Crowned") == true and platform and platform:IsA("BasePart") then
			local tag = Instance.new("BillboardGui")
			tag.Name = "CrownBaseTag"
			tag.Adornee = platform
			tag.Size = UDim2.fromScale(16, 4)
			tag.StudsOffsetWorldSpace = Vector3.new(0, 22, 0)
			tag.LightInfluence = 0
			tag.MaxDistance = 400
			Icons.image(tag, "Crown", UDim2.fromScale(0.16, 0.6), UDim2.fromScale(0.42, 0))
			label(tag, "BASE DU ROI  •  PRIME SUR SES FAMILIERS", 0.6, 0.4, GOLD)
			tag.Parent = platform
			baseTag = tag
			return
		end
	end
end

local characterConnection: RBXScriptConnection? = nil

local function refresh()
	clear()
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	local id = ReplicatedStorage:GetAttribute("CrownUserId")
	local king = if type(id) == "number" then Players:GetPlayerByUserId(id) else nil
	if not king then
		return
	end
	attachHead(king)
	attachBase()
	characterConnection = king.CharacterAdded:Connect(function()
		task.wait(0.5) -- la tête arrive avec le personnage
		if headTag then
			headTag:Destroy()
			headTag = nil
		end
		attachHead(king)
	end)
end

ReplicatedStorage:GetAttributeChangedSignal("CrownUserId"):Connect(function()
	task.wait(0.2) -- le serveur pose l'attribut "Crowned" de la base juste après
	refresh()
end)
refresh()
