--!strict
-- NextGoals : les deux objectifs entamés les plus utiles, avec une barre, dans la pile du HUD (ECONOMY_REPORT.md règle 12,
-- calcul dans shared/NextGoals) : prochain monde ou Rebirth, pitié, capsule, Index, familier bridé à libérer.
-- Au retour, un résumé de ce qui a avancé pendant l'absence (attribut "AwaySummary", server/SessionData).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Eggs = require(ReplicatedStorage.Shared.EggIncubation)
local NextGoals = require(ReplicatedStorage.Shared.NextGoals)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PowerCap = require(ReplicatedStorage.Shared.PowerCap)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MenuKit = require(script.Parent.MenuKit)
local Toast = require(script.Parent.Toast)
local UiStyle = require(script.Parent.UiStyle)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local stack = hud:WaitForChild("Root"):WaitForChild("TopStack")

local ROW_HEIGHT = 30
local frame = Instance.new("Frame")
frame.Name = "NextGoals"
frame.LayoutOrder = 5
frame.Size = UDim2.fromOffset(420, ROW_HEIGHT * 2 + 4)
frame.BackgroundTransparency = 1
frame.Visible = false
frame.Parent = stack
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = frame

type Row = { panel: Frame, fill: Frame, text: TextLabel }
local rows: { Row } = {}
for index = 1, 2 do
	local panel = Instance.new("Frame")
	panel.LayoutOrder = index
	panel.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	panel.BackgroundColor3 = UiStyle.Colors.Panel
	panel.BackgroundTransparency = 0.25
	UiStyle.corner(panel, 7)
	panel.Parent = frame
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UiStyle.Colors.Green
	fill.BackgroundTransparency = 0.45
	UiStyle.corner(fill, 7)
	fill.Parent = panel
	local text = UiStyle.text(panel, "", 14, Color3.new(1, 1, 1))
	text.Size = UDim2.new(1, -16, 1, 0)
	text.Position = UDim2.fromOffset(8, 0)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.ZIndex = 3
	table.insert(rows, { panel = panel, fill = fill, text = text })
end

-- Tirages de la dernière manche (pour estimer quand arrivera la garantie de la pitié).
local pullsPerRound = 0
Remotes.RewardsGranted.OnClientEvent:Connect(function(_score: number, pulls: number)
	if type(pulls) == "number" and pulls > 0 then
		pullsPerRound = pulls
	end
end)

-- Prochaine tentative de la capsule de sa base (attributs publiés par server/EggController).
local function capsuleWait(now: number): number?
	local index = player:GetAttribute("BaseIndex")
	local map = Workspace:FindFirstChild("Map")
	local base = map and type(index) == "number" and map:FindFirstChild("Base_" .. index)
	local capsule = base and base:FindFirstChild("EvolutionCapsule")
	local machine = capsule and capsule:FindFirstChild("EvolutionMachine")
	if not machine then
		return nil
	end
	local readyAt, nextAt = machine:GetAttribute("ReadyAt"), machine:GetAttribute("NextAt")
	if type(readyAt) == "number" and readyAt > now then
		return readyAt - now
	end
	return if type(nextAt) == "number" and nextAt > now then nextAt - now else nil
end

-- Le familier bridé qui rapporterait le plus (Config.PowerCap) et la rareté qui le libère ; recalculé toutes les 5 s.
local capped: { name: string?, unlock: number? } = {}
local lastScan = 0
local function scanCapped(selfBest: number?)
	capped = {}
	local best = 0
	for _, entry in ipairs(PetCatalog.Everything) do
		if MenuKit.number("Pet_" .. entry.Id) > 0 and PowerCap.IsCapped(entry.Id, selfBest) then
			local income = PetCatalog.GetIncome(entry.Id)
			if income > best then
				best = income
				capped = { name = entry.Name, unlock = PowerCap.UnlockRarity(entry.Id, selfBest) }
			end
		end
	end
end

local function discoveredCount(): number
	local claimed = MenuKit.claimed()
	local count = 0
	for _, entry in ipairs(PetCatalog.List) do
		if MenuKit.discovered(entry.Id, claimed) then
			count += 1
		end
	end
	return count
end

local function update()
	if player:GetAttribute("DataLoaded") ~= true then
		frame.Visible = false
		return
	end
	local now = Workspace:GetServerTimeNow()
	local selfBest = PowerCap.SelfBestOf(player)
	if os.clock() - lastScan > 5 then
		lastScan = os.clock()
		scanCapped(selfBest)
	end
	local state: NextGoals.State = {
		money = MenuKit.number("Money"),
		income = MenuKit.number("Income"),
		tier = math.max(1, MenuKit.number("Tier")),
		rebirths = MenuKit.number("Rebirths"),
		pity = MenuKit.number("Pity"),
		pityAt = MenuKit.number("PityAt"),
		pityTarget = MenuKit.number("PityTarget"),
		pullsPerRound = pullsPerRound,
		capsuleWait = capsuleWait(now),
		discovered = discoveredCount(),
		totalPets = #PetCatalog.List,
		cappedName = capped.name,
		cappedSelfBest = selfBest,
		cappedUnlock = capped.unlock,
	}
	local picked = NextGoals.Pick(NextGoals.List(state))
	frame.Visible = #picked > 0
	for index, row in ipairs(rows) do
		local goal = picked[index]
		row.panel.Visible = goal ~= nil
		if goal then
			local suffix = if goal.progress then string.format("  •  %d %%", math.floor(goal.progress * 100)) else ""
			if goal.eta then
				suffix ..= "  •  " .. Eggs.Time(goal.eta)
			end
			row.text.Text = goal.label .. suffix
			row.fill.Size = UDim2.fromScale(goal.progress or 0, 1)
		end
	end
end

-- Résumé d'absence (une fois, au chargement) : « 3 ŒUFS ONT ÉCLOS • TA CAPSULE A 2 TENTATIVES À FAIRE ».
local function showAway()
	local summary = player:GetAttribute("AwaySummary")
	if type(summary) ~= "string" then
		return
	end
	local hatched, attempts = string.match(summary, "^(%d+),(%d+)$")
	local parts = {}
	local eggs, tries = tonumber(hatched) or 0, tonumber(attempts) or 0
	if eggs > 0 then
		table.insert(parts, eggs .. (if eggs > 1 then " ŒUFS ONT ÉCLOS" else " ŒUF A ÉCLOS"))
	end
	if tries > 0 then
		table.insert(parts, "TA CAPSULE A FAIT " .. tries .. (if tries > 1 then " ESSAIS" else " ESSAI"))
	end
	if #parts > 0 then
		Toast.show("PENDANT QUE TU N'ÉTAIS PAS LÀ : " .. table.concat(parts, "  •  "), UiStyle.Colors.Cyan)
	end
end
player:GetAttributeChangedSignal("AwaySummary"):Connect(showAway)
showAway()

task.spawn(function()
	while frame.Parent do
		update()
		task.wait(1)
	end
end)
