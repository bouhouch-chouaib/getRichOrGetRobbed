--!strict
-- ItemPromptAnchors : garde la bulle "[E] Ramasser" de chaque objet proche juste au-dessus de son centre,
-- même quand l'objet est tombé de travers (l'Attachment "PromptAnchor" tourne avec l'objet, on le recale).
-- Arme en main (Tool équipé) : les bulles "Ramasser" des objets proches sont cachées (on ne peut pas ramasser avec
-- une arme ; le serveur refuse aussi). Elles reviennent dès que l'arme est rangée.
-- Purement local : ne change rien côté serveur.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RANGE = 45 -- seuls les objets proches du joueur sont recalés
local HEIGHT = 1.5 -- studs au-dessus du haut de l'objet

local player = Players.LocalPlayer

local function updateItem(item: Instance, origin: Vector3, armed: boolean)
	if not item:IsA("BasePart") then
		return
	end
	local anchor = item:FindFirstChild("PromptAnchor")
	if not anchor or not anchor:IsA("Attachment") then
		return
	end
	if (item.Position - origin).Magnitude > RANGE then
		return
	end
	-- Même règle que le serveur (bulle active si l'objet n'est porté par personne), sauf arme en main.
	local prompt = anchor:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		local enabled = not armed and item:GetAttribute("Holder") == nil and item:GetAttribute("Consumed") == nil
		if prompt.Enabled ~= enabled then
			prompt.Enabled = enabled
		end
	end
	-- Demi-hauteur réelle de l'objet tourné (projection de sa taille sur l'axe vertical).
	local cf = item.CFrame
	local size = item.Size / 2
	local halfHeight = math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z
	anchor.WorldPosition = item.Position + Vector3.new(0, halfHeight + HEIGHT, 0)
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local map = Workspace:FindFirstChild("Map")
	if not root or not root:IsA("BasePart") or not map then
		return
	end
	local origin = root.Position
	local armed = character:FindFirstChildOfClass("Tool") ~= nil

	for _, folderName in ipairs({ "LooseItems", "WildItems" }) do
		local itemFolder = map:FindFirstChild(folderName)
		if itemFolder then
			for _, item in ipairs(itemFolder:GetChildren()) do
				updateItem(item, origin, armed)
			end
		end
	end
	for _, base in ipairs(map:GetChildren()) do
		local itemSpawns = base:FindFirstChild("ItemSpawns")
		if itemSpawns then
			for _, item in ipairs(itemSpawns:GetChildren()) do
				updateItem(item, origin, armed)
			end
		end
	end
end)
