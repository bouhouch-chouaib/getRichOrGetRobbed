--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(ReplicatedStorage.Shared.Config)
local Expansion = require(ReplicatedStorage.Shared.BaseExpansion)
local Geometry = require(ReplicatedStorage.Shared.BaseFloorGeometry)
local PetWander = require(ReplicatedStorage.Shared.PetWander)
local BaseManager = require(script.Parent.BaseManager)
local SessionData = require(script.Parent.SessionData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Controller = {}
local product: Config.MonetizationItem? = nil
for _, item in ipairs(Config.Monetization.Products) do
	if item.Key == "BaseFloor" then
		product = item
	end
end
function Controller.Init(bases: { Model })
	local states: { [Model]: { folder: Folder, owner: Player?, built: number } } = {}
	for _, base in ipairs(bases) do
		local platform = base:FindFirstChild("BasePart")
		if not platform or not platform:IsA("BasePart") then
			continue
		end
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "UpperFloors", base
		states[base] = { folder = folder, owner = nil, built = 0 }
		local terminal = Instance.new("Part")
		terminal.Name, terminal.Size = "FloorTerminal", Vector3.new(5, 4, 2)
		terminal.Anchored, terminal.Color = true, Color3.fromRGB(60, 190, 255)
		terminal.CFrame = PetWander.groundOf(platform) * CFrame.new(20, 2, -35)
		terminal.Parent = base
		local sign = Instance.new("BillboardGui")
		sign.Adornee, sign.Size, sign.StudsOffsetWorldSpace =
			terminal, UDim2.fromOffset(180, 32), Vector3.new(0, 3.5, 0)
		sign.MaxDistance, sign.LightInfluence = 70, 0
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1, 1)
		label.FontFace, label.TextScaled = require(ReplicatedStorage.Shared.Typography).Face, true
		label.Text, label.TextColor3 = "AGRANDIR LA BASE", Color3.fromRGB(100, 220, 255)
		local outline = Instance.new("UIStroke")
		outline.Thickness, outline.Parent = 2, label
		label.Parent, sign.Parent = sign, terminal
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "Agrandir", "Étages de base"
		prompt.KeyboardKeyCode, prompt.RequiresLineOfSight = Enum.KeyCode.E, false
		prompt:SetAttribute("OpensWindow", "BaseFloors")
		prompt.Parent = terminal
	end
	local function update()
		for base, state in pairs(states) do
			local owner = BaseManager.GetOwner(base)
			local data = if owner then SessionData.Get(owner) else nil
			local count = if data and data.loaded then data.expansion.floors else 0
			if state.owner ~= owner then
				state.folder:ClearAllChildren()
				state.owner, state.built = owner, 0
			end
			local platform = base:FindFirstChild("BasePart")
			if platform and platform:IsA("BasePart") then
				for level = state.built + 1, count do
					local palette = Config.Rarities[math.min(level + 1, #Config.Rarities)].Color
					Geometry.Build(state.folder, PetWander.groundOf(platform), level, palette)
				end
			end
			state.built = count
			base:SetAttribute("FloorsBuilt", count)
		end
	end
	local lastRequest: { [Player]: number } = {}
	Remotes.BaseFloor.OnServerEvent:Connect(function(player: Player, action: unknown)
		if action ~= "Cash" and action ~= "Robux" then
			return
		end
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < 0.5 then
			return
		end
		lastRequest[player] = now
		local data = SessionData.Get(player)
		if not data or not data.loaded then
			return
		end
		if data.expansion.floors >= Expansion.Limit(data.tier) then
			Remotes.BaseFloor:FireClient(player, false, "ATTEINS LE MONDE SUIVANT POUR AJOUTER UN ÉTAGE.")
			return
		end
		if action == "Cash" then
			local ok = SessionData.BuyBaseFloor(player)
			if ok then
				update()
				task.spawn(SessionData.Save, player)
			end
			Remotes.BaseFloor:FireClient(
				player,
				ok,
				if ok then "ÉTAGE CONSTRUIT ! +10 PLACES." else "PAS ASSEZ D’ARGENT."
			)
		elseif product and product.Id > 0 then
			MarketplaceService:PromptProductPurchase(player, product.Id)
		else
			Remotes.BaseFloor:FireClient(player, false, "L’ACHAT ROBUX N’EST PAS ENCORE ACTIVÉ.")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	task.spawn(function()
		while true do
			update()
			task.wait(0.5)
		end
	end)
end
return Controller
