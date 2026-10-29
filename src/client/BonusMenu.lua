--!strict
-- BonusMenu : fenêtre BONUS, trois onglets (server/ProgressionController décide de tout) :
--   « Cadeau du jour » : 7 cartes (jour 1 à 7), celle du jour brille, bouton RÉCLAMER ou compte à rebours ;
--   « Quêtes »         : les 3 quêtes du jour (facile, moyenne, difficile), barre d'avancement, bouton RÉCLAMER ;
--   « Codes »          : une case pour taper un code cadeau.
-- État lu dans les attributs du joueur : DailyLast, DailyStreak, Quests (JSON), QuestsDay, Income.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MenuKit = require(script.Parent.MenuKit)
local Sounds = require(script.Parent.Sounds)
local UiStyle = require(script.Parent.UiStyle)

local BonusMenu = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GREY = Color3.fromRGB(150, 150, 160)
local GOLD = UiStyle.Colors.Gold
local MONEY = UiStyle.Colors.Money
local HEADER = Color3.fromRGB(255, 185, 40)
local DIFFICULTY = {
	{ name = "FACILE", color = Color3.fromRGB(110, 220, 90) },
	{ name = "MOYENNE", color = Color3.fromRGB(255, 190, 50) },
	{ name = "DIFFICILE", color = Color3.fromRGB(255, 90, 90) },
}

export type Quest = { id: string, goal: number, progress: number, claimed: boolean }
export type Menu = {
	window: MenuKit.Window,
	refresh: () -> (),
	claimableCount: () -> number,
	dailyReady: () -> boolean,
	openTab: (index: number) -> (),
	codeResult: (ok: boolean, message: string) -> (),
}

local function today(): number
	return math.floor(Workspace:GetServerTimeNow() / 86400)
end

-- Même règle que le serveur (ProgressionController.DailyDay) : jour réclamable aujourd'hui, ou nil.
local function dailyDay(): number?
	local last, streak = MenuKit.number("DailyLast"), MenuKit.number("DailyStreak")
	local now = today()
	if now <= last then
		return nil
	end
	if now == last + 1 and streak > 0 then
		return streak % #Config.Daily.Rewards + 1
	end
	return 1
end

local function quests(): { Quest }
	local raw = player:GetAttribute("Quests")
	if type(raw) ~= "string" or MenuKit.number("QuestsDay") ~= today() then
		return {}
	end
	local ok, list = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(list) == "table" then list else {}
end

local function questText(quest: Quest): string
	for _, def in ipairs(Config.Quests.Pool) do
		if def.Id == quest.id then
			return string.format(def.Text, quest.goal)
		end
	end
	return quest.id
end

-- « +$12.5K  •  3 TIRAGES » : l'argent est estimé avec le revenu actuel (le serveur recalcule au moment du clic).
-- short = petite carte du cadeau du jour : « x3 » sous une image d'œuf (« 3 ŒUFS » ne tenait pas).
local function rewardText(reward: Config.BonusReward, minimum: number, short: boolean?): string
	local parts = {}
	if reward.Seconds then
		local money = math.max(MenuKit.number("Income") * reward.Seconds, minimum)
		table.insert(parts, "+" .. NumberFormat.money(money))
	end
	if reward.Pulls then
		table.insert(parts, if short then "x" .. reward.Pulls else string.format("%d ŒUF%s", reward.Pulls, if reward.Pulls > 1 then "S" else ""))
	end
	if reward.Candy then
		table.insert(parts, string.format("%d BONBONS", reward.Candy))
	end
	return table.concat(parts, "\n")
end

local function untilMidnight(): string
	local left = math.max(0, (today() + 1) * 86400 - Workspace:GetServerTimeNow())
	return string.format("%02d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60)
end

local function label(parent: Instance, value: string, size: number, color: Color3?, position: UDim2, frameSize: UDim2): TextLabel
	local text = UiStyle.text(parent, value, size, color, UiStyle.BODY_FONT)
	text.Position = position
	text.Size = frameSize
	return text
end

function BonusMenu.create(gui: Instance): Menu
	local window = MenuKit.window(gui, "Bonus", Vector2.new(800, 470), HEADER, "Gift")
	local pages: { Frame } = {}
	for index = 1, 3 do
		local page = Instance.new("Frame")
		page.Name = "Page" .. index
		page.BackgroundTransparency = 1
		page.Size = UDim2.fromScale(1, 1)
		page.Visible = index == 1
		page.ZIndex = 2
		page.Parent = window.content
		pages[index] = page
	end

	------------------------------------------------------------------
	-- Cadeau du jour
	------------------------------------------------------------------
	local dailyPage = pages[1]
	label(dailyPage, "REVIENS CHAQUE JOUR : LE CADEAU GROSSIT !", 24, WHITE, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 30))
	local cardRow = Instance.new("Frame")
	cardRow.BackgroundTransparency = 1
	cardRow.Position = UDim2.fromOffset(0, 40)
	cardRow.Size = UDim2.new(1, 0, 0, 230)
	cardRow.Parent = dailyPage
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.Padding = UDim.new(0, 8)
	cardLayout.Parent = cardRow
	-- Carte d'un jour (façon packs « Studs UI ») : « JOUR n », grosse icône, récompense, pastille d'état en bas
	-- (REÇU vert, AUJOURD'HUI doré qui pulse, BLOQUÉ gris). Le jour 7, plus grand, est multicolore.
	type DayCard = { card: Frame, icon: ImageLabel, rays: ImageLabel, chip: TextLabel, reward: TextLabel, scale: UIScale,
		border: UIStroke? }
	local dayCards: { DayCard } = {}
	for day, reward in ipairs(Config.Daily.Rewards) do
		local big = day == #Config.Daily.Rewards
		local card = UiStyle.brightCard(cardRow, UDim2.fromOffset(if big then 124 else 90, 222), if big then GOLD else Color3.fromRGB(80, 160, 255))
		card.LayoutOrder = day
		if big then
			local rainbow = card:FindFirstChildOfClass("UIGradient")
			if rainbow then
				rainbow.Rotation = 45
				rainbow.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)),
					ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 200, 60)),
					ColorSequenceKeypoint.new(0.55, Color3.fromRGB(110, 230, 90)),
					ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 170, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
				})
			end
		end
		label(card, "JOUR " .. day, if big then 28 else 22, WHITE, UDim2.fromOffset(8, 6), UDim2.new(1, -16, 0, 28))
		local iconSize = if big then 84 else 62
		local iconHolder = Instance.new("Frame")
		iconHolder.BackgroundTransparency = 1
		iconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		iconHolder.Position = UDim2.new(0.5, 0, 0, 38 + iconSize / 2)
		iconHolder.Size = UDim2.fromOffset(iconSize, iconSize)
		iconHolder.Parent = card
		local rays = UiStyle.rays(iconHolder, GOLD, iconSize * 1.7, 40)
		rays.Visible = false
		local icon = Icons.image(iconHolder, if big then "Crown" elseif reward.Pulls then "Egg" else "Money", UDim2.fromScale(1, 1))
		icon.ZIndex = 3
		UiStyle.sway(icon, 6)
		local rewardLabel = UiStyle.number(card, "", if big then 20 else 16, WHITE)
		rewardLabel.Position = UDim2.fromOffset(8, 46 + iconSize)
		rewardLabel.Size = UDim2.new(1, -16, 0, if big then 54 else 40) -- jour 7 : l'argent ET les œufs, sur 2 lignes
		rewardLabel.TextWrapped = true
		local chip = UiStyle.text(card, "", 15, WHITE, UiStyle.TITLE_FONT)
		chip.AnchorPoint = Vector2.new(0.5, 1)
		chip.Position = UDim2.new(0.5, 0, 1, -8)
		chip.Size = UDim2.new(1, -12, 0, 26)
		chip.BackgroundTransparency = 0
		chip.BackgroundColor3 = WHITE
		chip.TextScaled = true
		local chipPadding = Instance.new("UIPadding")
		chipPadding.PaddingLeft = UDim.new(0, 6)
		chipPadding.PaddingRight = UDim.new(0, 6)
		chipPadding.PaddingTop = UDim.new(0, 4)
		chipPadding.PaddingBottom = UDim.new(0, 4)
		chipPadding.Parent = chip
		UiStyle.corner(chip, 6)
		UiStyle.stroke(chip, 2.5, BLACK, true)
		local chipShade = UiStyle.gradient(chip, WHITE, WHITE)
		chipShade.Name = "Shade"
		local scale = Instance.new("UIScale")
		scale.Parent = card
		dayCards[day] = { card = card, icon = icon, rays = rays, chip = chip, reward = rewardLabel, scale = scale,
			border = card:FindFirstChildOfClass("UIStroke") }
	end
	local function setChip(chip: TextLabel, text: string, color: Color3)
		chip.Text = text
		local shade = chip:FindFirstChild("Shade")
		if shade and shade:IsA("UIGradient") then
			shade.Color = UiStyle.buttonColors(color)
		end
	end
	local dailyButton = UiStyle.button(dailyPage, "PRENDRE !", UDim2.fromOffset(440, 64), UiStyle.Colors.Green, 32)
	dailyButton.AnchorPoint = Vector2.new(0.5, 1)
	dailyButton.Position = UDim2.new(0.5, 0, 1, -4)
	dailyButton.Activated:Connect(function()
		if dailyDay() then
			Remotes.Bonus:FireServer("Daily")
		else
			Sounds.play("Error")
		end
	end)

	------------------------------------------------------------------
	-- Quêtes du jour
	------------------------------------------------------------------
	local questPage = pages[2]
	local questTimer = label(questPage, "", 22, WHITE, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 28))
	type QuestRow = { title: TextLabel, tag: TextLabel, fill: Frame, count: TextLabel, reward: TextLabel, button: TextButton }
	local rows: { QuestRow } = {}
	for index = 1, Config.Quests.PerDay do
		local panel = UiStyle.panel(questPage, UDim2.new(1, 0, 0, 104))
		panel.Position = UDim2.fromOffset(0, 36 + (index - 1) * 114)
		local tag = UiStyle.text(panel, DIFFICULTY[index].name, 18, DIFFICULTY[index].color, UiStyle.BODY_FONT)
		tag.Position = UDim2.fromOffset(14, 6)
		tag.Size = UDim2.fromOffset(200, 22)
		tag.TextXAlignment = Enum.TextXAlignment.Left
		local title = UiStyle.text(panel, "", 24, WHITE, UiStyle.BODY_FONT)
		title.Position = UDim2.fromOffset(14, 28)
		title.Size = UDim2.new(1, -230, 0, 30)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextScaled = true
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromOffset(14, 66)
		bar.Size = UDim2.new(1, -330, 0, 24)
		bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		UiStyle.corner(bar, 6)
		UiStyle.stroke(bar, 3, BLACK, true)
		bar.Parent = panel
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = DIFFICULTY[index].color
		UiStyle.corner(fill, 6)
		fill.Parent = bar
		local count = UiStyle.number(bar, "", 18, WHITE)
		count.Size = UDim2.fromScale(1, 1)
		count.ZIndex = 3
		local reward = UiStyle.number(panel, "", 18, MONEY)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position = UDim2.new(1, -200, 0, 56)
		reward.Size = UDim2.fromOffset(110, 44)
		reward.TextWrapped = true
		local button = UiStyle.button(panel, "", UDim2.fromOffset(170, 60), GREY, 24)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -14, 0.5, 0)
		button.Activated:Connect(function()
			local quest = quests()[index]
			if quest and not quest.claimed and quest.progress >= quest.goal then
				Remotes.Bonus:FireServer("Quest", index)
			else
				Sounds.play("Error")
			end
		end)
		rows[index] = { title = title, tag = tag, fill = fill, count = count, reward = reward, button = button }
	end

	------------------------------------------------------------------
	-- Codes cadeaux
	------------------------------------------------------------------
	local codePage = pages[3]
	label(codePage, "UN CODE CADEAU ? ÉCRIS-LE ICI !", 30, WHITE, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 40))
	local box = Instance.new("TextBox")
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 100)
	box.Size = UDim2.fromOffset(420, 64)
	box.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	box.ClearTextOnFocus = false
	box.PlaceholderText = "CODE"
	box.PlaceholderColor3 = GREY
	box.Text = ""
	box.TextColor3 = Color3.fromRGB(30, 30, 40)
	box.FontFace = UiStyle.NUMBER_FONT
	box.TextSize = 34
	box.ZIndex = 3
	UiStyle.corner(box, 8)
	UiStyle.stroke(box, 4, BLACK, true)
	box.Parent = codePage
	local codeButton = UiStyle.button(codePage, "VALIDER", UDim2.fromOffset(260, 60), UiStyle.Colors.Green, 30)
	codeButton.AnchorPoint = Vector2.new(0.5, 0)
	codeButton.Position = UDim2.new(0.5, 0, 0, 184)
	local codeMessage = label(codePage, "", 24, WHITE, UDim2.fromOffset(0, 262), UDim2.new(1, 0, 0, 30))
	label(codePage, "LES CODES SONT SUR LA PAGE DU JEU", 18, GREY,
		UDim2.fromOffset(0, 310), UDim2.new(1, 0, 0, 24))
	-- Groupe Roblox (Config.Group) : invitation à le rejoindre, ou confirmation du bonus.
	local groupLine = label(codePage, "", 20, GOLD, UDim2.fromOffset(0, 344), UDim2.new(1, 0, 0, 26))
	groupLine.Visible = Config.Group.Id ~= 0
	local function submit()
		if box.Text == "" then
			return
		end
		Remotes.Bonus:FireServer("Code", box.Text)
	end
	codeButton.Activated:Connect(submit)
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
		end
	end)

	------------------------------------------------------------------

	local function claimableCount(): number
		local count = if dailyDay() then 1 else 0
		for _, quest in ipairs(quests()) do
			if not quest.claimed and quest.progress >= quest.goal then
				count += 1
			end
		end
		return count
	end

	local tabs: MenuKit.Tabs
	local function refresh()
		local percent = math.floor(Config.Group.IncomeBonus * 100 + 0.5)
		groupLine.Text = if player:GetAttribute("InGroup") == true
			then string.format("TU ES DANS LE GROUPE : +%d %% D'ARGENT !", percent)
			else string.format("REJOINS NOTRE GROUPE : +%d %% D'ARGENT POUR TOUJOURS !", percent)
		groupLine.TextColor3 = if player:GetAttribute("InGroup") == true then MONEY else GOLD
		-- Cadeau du jour
		local claimDay = dailyDay()
		local streak = MenuKit.number("DailyStreak")
		local nextDay = claimDay or (streak % #Config.Daily.Rewards + 1)
		for day, ui in ipairs(dayCards) do
			ui.reward.Text = rewardText(Config.Daily.Rewards[day], Config.Daily.MinMoney, day < #Config.Daily.Rewards)
			local done = if claimDay then day < claimDay else day <= streak
			local isToday = claimDay == day
			if done then
				setChip(ui.chip, "REÇU", UiStyle.Colors.Green)
			elseif isToday then
				setChip(ui.chip, "AUJOURD'HUI", GOLD)
			elseif day == nextDay then
				setChip(ui.chip, "DEMAIN", Color3.fromRGB(120, 120, 135))
			else
				setChip(ui.chip, "BLOQUÉ", Color3.fromRGB(120, 120, 135))
			end
			ui.icon.ImageTransparency = if done then 0.45 else 0
			ui.rays.Visible = isToday
			if ui.border then
				ui.border.Color = if isToday then WHITE else BLACK
				ui.border.Thickness = if isToday then 5 else 4
			end
			ui.scale.Scale = 1 -- highlight with color; preserve the spacing between days
		end
		local caption = dailyButton:FindFirstChild("Caption") :: TextLabel
		if claimDay then
			caption.Text = string.format("PRENDRE LE JOUR %d !", claimDay)
			UiStyle.setButtonColor(dailyButton, UiStyle.Colors.Green)
		else
			caption.Text = "PROCHAIN DANS " .. untilMidnight()
			UiStyle.setButtonColor(dailyButton, GREY)
		end

		-- Quêtes
		questTimer.Text = "NOUVEAUX DÉFIS DANS " .. untilMidnight()
		local list = quests()
		for index, row in ipairs(rows) do
			local quest = list[index]
			local buttonCaption = row.button:FindFirstChild("Caption") :: TextLabel
			row.reward.Text = rewardText(Config.Quests.Rewards[index], Config.Quests.MinMoney)
			if not quest then
				row.title.Text = "..."
				row.count.Text = ""
				row.fill.Size = UDim2.fromScale(0, 1)
				buttonCaption.Text = ""
				UiStyle.setButtonColor(row.button, GREY)
				continue
			end
			row.title.Text = questText(quest)
			row.count.Text = string.format("%d / %d", quest.progress, quest.goal)
			TweenService:Create(row.fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.clamp(quest.progress / quest.goal, 0, 1), 1) }):Play()
			if quest.claimed then
				buttonCaption.Text = "FAIT !"
				UiStyle.setButtonColor(row.button, UiStyle.Colors.Cyan)
			elseif quest.progress >= quest.goal then
				buttonCaption.Text = "PRENDRE !"
				UiStyle.setButtonColor(row.button, UiStyle.Colors.Green)
			else
				buttonCaption.Text = "EN COURS"
				UiStyle.setButtonColor(row.button, GREY)
			end
		end

		tabs.setBadge(1, if claimDay then "!" else nil)
		local questsReady = claimableCount() - (if claimDay then 1 else 0)
		tabs.setBadge(2, if questsReady > 0 then tostring(questsReady) else nil)
	end

	tabs = MenuKit.sideTabs(window, {
		{ label = "Cadeau du jour", color = GOLD, icon = "Gift" },
		{ label = "Défis", color = Color3.fromRGB(110, 200, 90), icon = "Trophy" },
		{ label = "Codes", color = Color3.fromRGB(90, 170, 255), icon = "Key" },
	}, function(index: number)
		for pageIndex, page in ipairs(pages) do
			page.Visible = pageIndex == index
		end
		refresh()
	end)

	-- Les comptes à rebours avancent tant que la fenêtre est ouverte.
	task.spawn(function()
		while true do
			task.wait(1)
			if window.isOpen() then
				refresh()
			end
		end
	end)
	window.onOpen(refresh)

	return {
		window = window,
		refresh = refresh,
		claimableCount = claimableCount,
		dailyReady = function()
			return dailyDay() ~= nil
		end,
		openTab = function(index: number)
			window.open()
			tabs.select(index)
		end,
		codeResult = function(ok: boolean, message: string)
			codeMessage.Text = message
			codeMessage.TextColor3 = if ok then MONEY else UiStyle.Colors.Red
			if ok then
				box.Text = ""
			end
		end,
	}
end

return BonusMenu
