--!strict
-- PedestalController : expose physiquement les meilleurs familiers du propriétaire sur les socles
-- de sa base (style Steal a Brainrot), avec leur nom et leur revenu par seconde au-dessus.
-- Ce sont exactement les familiers qui rapportent de l'argent (EconomyController.GetTopPets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local BaseManager = require(script.Parent.BaseManager)
local EconomyController = require(script.Parent.EconomyController)

local PedestalController = {}

type Display = {
	base: Model,
	platform: BasePart,
	pedestals: { BasePart }, -- triés par Index
	folder: Folder,
	signature: string,
}

local displays: { Display } = {}

local function formatIncome(value: number): string
	if value < 10 then
		return string.format("+$%.2f/s", value)
	end
	return string.format("+$%d/s", math.floor(value))
end

local function setSign(pedestal: BasePart, petId: string?)
	local sign = pedestal:FindFirstChild("PetSign")
	if not sign or not sign:IsA("BillboardGui") then
		return
	end
	local entry = petId and PetCatalog.ById[petId]
	sign.Enabled = entry ~= nil
	if not entry then
		return
	end
	local rarity = Config.Rarities[Config.RarityIndex[entry.Rarity]]
	local nameLabel = sign:FindFirstChild("PetName")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = entry.Name:upper()
		nameLabel.TextColor3 = rarity.Color
	end
	local incomeLabel = sign:FindFirstChild("PetIncome")
	if incomeLabel and incomeLabel:IsA("TextLabel") then
		incomeLabel.Text = formatIncome(rarity.Income)
	end
end

local function rebuild(display: Display, top: { string })
	display.folder:ClearAllChildren()
	for index, pedestal in ipairs(display.pedestals) do
		local petId = top[index]
		setSign(pedestal, petId)
		if petId then
			local model = PetModelBuilder.Build(petId)
			if model then
				local height = model:GetExtentsSize().Y
				-- Dessus du socle (cylindre couché : sa hauteur est sur l'axe X local).
				local position = pedestal.Position + Vector3.new(0, pedestal.Size.X / 2 + height / 2, 0)
				local facing = pedestal:GetAttribute("Facing")
				local direction = display.platform.CFrame.RightVector * (if type(facing) == "number" then facing else 1)
				model:PivotTo(CFrame.lookAt(position, position + direction))
				model.Parent = display.folder
			end
		end
	end
end

local function update()
	for _, display in ipairs(displays) do
		local owner = BaseManager.GetOwner(display.base)
		local top = if owner then EconomyController.GetTopPets(owner) else {}
		local signature = table.concat(top, ",")
		if signature ~= display.signature then
			display.signature = signature
			rebuild(display, top)
		end
	end
end

function PedestalController.Init(bases: { Model })
	for _, base in ipairs(bases) do
		local platform = base:FindFirstChild("BasePart")
		local pedestalFolder = base:FindFirstChild("Pedestals")
		if platform and platform:IsA("BasePart") and pedestalFolder then
			local pedestals = {}
			for _, child in ipairs(pedestalFolder:GetChildren()) do
				if child:IsA("BasePart") then
					table.insert(pedestals, child)
				end
			end
			table.sort(pedestals, function(a, b)
				return (a:GetAttribute("Index") :: number? or 0) < (b:GetAttribute("Index") :: number? or 0)
			end)
			local folder = Instance.new("Folder")
			folder.Name = "PedestalPets"
			folder.Parent = base
			table.insert(displays, { base = base, platform = platform, pedestals = pedestals, folder = folder, signature = "" })
		else
			warn("[PedestalController] Socles introuvables dans " .. base.Name)
		end
	end

	task.spawn(function()
		while true do
			update()
			task.wait(1)
		end
	end)
end

return PedestalController
