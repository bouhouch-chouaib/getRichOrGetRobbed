--!strict
-- ItemOutline : trait sombre et fin autour des objets à jeter posés par terre (29 oct., un joueur sur téléphone : « on voit
-- mal les objets »). Pas de lueur : un contour de dessin animé (Highlight sans remplissage, caché derrière les murs),
-- seulement sur les objets que le joueur peut prendre (arène, objets lâchés, SES bacs), les Config.Items.Outline.MaxItems
-- plus proches : Roblox n'affiche que 31 Highlight à la fois pour tout le jeu. Purement local.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local OUTLINE = Config.Items.Outline
local player = Players.LocalPlayer
local outlined: { [BasePart]: Highlight } = {}

-- Objets libres à portée, du plus proche au plus loin.
local function candidates(origin: Vector3): { BasePart }
	local list: { BasePart } = {}
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return list
	end
	local function scan(folder: Instance?)
		if not folder then
			return
		end
		for _, item in ipairs(folder:GetChildren()) do
			if
				item:IsA("BasePart")
				and item:GetAttribute("IsItem") == true
				and item:GetAttribute("Holder") == nil
				and item:GetAttribute("Consumed") == nil
				and (item.Position - origin).Magnitude <= OUTLINE.Range
			then
				table.insert(list, item)
			end
		end
	end
	scan(map:FindFirstChild("WildItems"))
	scan(map:FindFirstChild("LooseItems"))
	for _, base in ipairs(map:GetChildren()) do
		if base:IsA("Model") and base:GetAttribute("OwnerName") == player.Name then
			scan(base:FindFirstChild("ItemSpawns"))
		end
	end
	table.sort(list, function(a, b)
		return (a.Position - origin).Magnitude < (b.Position - origin).Magnitude
	end)
	return list
end

local function outline(item: BasePart): Highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "ItemOutline"
	highlight.FillTransparency = 1
	highlight.OutlineColor = OUTLINE.Color
	highlight.OutlineTransparency = OUTLINE.Transparency
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = item
	highlight.Parent = item
	return highlight
end

while true do
	task.wait(0.4)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local keep: { [BasePart]: boolean } = {}
	if root and root:IsA("BasePart") then
		local list = candidates(root.Position)
		for index = 1, math.min(#list, OUTLINE.MaxItems) do
			keep[list[index]] = true
		end
	end
	for item, highlight in pairs(outlined) do
		if not keep[item] or not item.Parent then
			highlight:Destroy()
			outlined[item] = nil
		end
	end
	for item in pairs(keep) do
		if not outlined[item] then
			outlined[item] = outline(item)
		end
	end
end
