--!strict
-- Gamepad : jouer à la manette (Xbox, PlayStation, ou manette branchée sur PC), 29 oct.
--   - croix gauche : va sur les tuiles de menu (Boutique, Index...) ; A ouvre, la croix / le stick se déplacent ;
--   - une fenêtre ouverte prend la sélection (on reste dedans) ; B la ferme et revient sur sa tuile, B encore : on rejoue ;
--   - un cadre doré bien visible autour de ce qui est sélectionné ;
--   - petites images des boutons (croix gauche « MENUS », B sur la croix rouge) seulement quand on joue à la manette.
-- Le reste est fait ailleurs : lancer = gâchette droite (client/InteractionController), bulles = bouton X / carré
-- (client/PromptStyle), aimant = croix droite (client/Magnet), armes = barre d'objets de Roblox (L1 / R1, gâchette droite),
-- grappin visé devant la caméra (client/WeaponFx).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MenuKit = require(script.Parent.MenuKit)
local ScreenScale = require(script.Parent.ScreenScale)
local UiStyle = require(script.Parent.UiStyle)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local hud = playerGui:WaitForChild("HUD")

local GOLD = Color3.fromRGB(255, 214, 70)
local FOCUS_DELAY = 0.35 -- s : la fenêtre finit de s'ouvrir (positions justes) avant qu'on y pose la sélection

local function find(name: string): Instance
	while true do
		local found = hud:FindFirstChild(name, true)
		if found then
			return found
		end
		hud.DescendantAdded:Wait()
	end
end
local menuColumn = find("Left") :: Frame
local menuHandle = find("MenuHandle") :: GuiButton
menuColumn.SelectionGroup = true

-- Cadre de sélection : un contour doré épais (celui de Roblox, gris, se perd sur les tuiles colorées).
do
	local frame = Instance.new("Frame")
	frame.Name = "PadSelection"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	UiStyle.corner(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Color = GOLD
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	playerGui.SelectionImageObject = frame
end

local function isShown(object: GuiObject, stop: Instance): boolean
	local current: Instance? = object
	while current and current ~= stop do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

-- Le bouton le plus en haut à gauche (hors croix de fermeture) : c'est là que la sélection commence. Les onglets
-- de côté (MenuKit.sideTabs) passent après le contenu : on tombe sur « PRENDRE », pas sur un onglet.
local function firstButton(container: Instance, withTabs: boolean?): GuiObject?
	local best: GuiObject? = nil
	local tabs = container:FindFirstChild("SideTabs", true)
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("GuiButton") and descendant.Selectable and descendant.Name ~= "Close"
			and (withTabs or not tabs or not descendant:IsDescendantOf(tabs))
			and descendant.AbsoluteSize.X > 0 and isShown(descendant, container) then
			local current = best
			if not current or descendant.AbsolutePosition.Y < current.AbsolutePosition.Y - 4
				or (math.abs(descendant.AbsolutePosition.Y - current.AbsolutePosition.Y) <= 4
					and descendant.AbsolutePosition.X < current.AbsolutePosition.X) then
				best = descendant
			end
		end
	end
	if not best and not withTabs then
		return firstButton(container, true)
	end
	return best
end

local function selectionIn(container: Instance): boolean
	local selected = GuiService.SelectedObject
	return selected ~= nil and selected:IsDescendantOf(container)
end

-- Tuiles rangées hors de l'écran (poignée « » ») : on sélectionne la poignée pour les ressortir.
local function focusTiles()
	if menuColumn.AbsolutePosition.X + menuColumn.AbsoluteSize.X <= 0 then
		GuiService.SelectedObject = menuHandle
	else
		GuiService.SelectedObject = firstButton(menuColumn)
	end
end

----------------------------------------------------------------------
-- Images des boutons (seulement à la manette)
----------------------------------------------------------------------

local glyphs: { GuiObject } = {}
local function padGlyph(parent: Instance, keyCode: Enum.KeyCode, size: number): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "PadGlyph"
	image.BackgroundTransparency = 1
	image.Image = UserInputService:GetImageForKeyCode(keyCode)
	image.Size = UDim2.fromOffset(size, size)
	image.ZIndex = 8
	image.Parent = parent
	table.insert(glyphs, image)
	return image
end

-- Sous les tuiles : croix gauche + « MENUS ».
local menuHint = Instance.new("Frame")
menuHint.Name = "PadMenuHint"
menuHint.BackgroundTransparency = 1
menuHint.Position = UDim2.new(0, 0, 1, 6)
menuHint.Size = UDim2.new(1, 0, 0, 30)
menuHint.Parent = menuColumn
padGlyph(menuHint, Enum.KeyCode.DPadLeft, 30)
local menuLabel = UiStyle.text(menuHint, "MENUS", 22)
menuLabel.Position = UDim2.fromOffset(36, 0)
menuLabel.Size = UDim2.new(1, -36, 1, 0)
menuLabel.TextXAlignment = Enum.TextXAlignment.Left
table.insert(glyphs, menuHint)

local function refreshGlyphs()
	local shown = ScreenScale.usingGamepad()
	for _, glyph in ipairs(glyphs) do
		if glyph.Parent then
			glyph.Visible = shown and (not glyph:IsA("ImageLabel") or glyph.Image ~= "")
		end
	end
end
UserInputService.LastInputTypeChanged:Connect(refreshGlyphs)

-- B sur la croix rouge de chaque fenêtre.
local function markClose(frame: Frame)
	local close = frame:FindFirstChild("Close", true)
	if close and close:IsA("GuiObject") and not close:FindFirstChild("PadGlyph") then
		local glyph = padGlyph(close, Enum.KeyCode.ButtonB, 34)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.new(0, 0, 1, 0)
	end
	refreshGlyphs()
end
refreshGlyphs()

----------------------------------------------------------------------
-- Fenêtres : la sélection y entre à l'ouverture, revient sur la tuile à la fermeture
----------------------------------------------------------------------

local currentFrame: Frame? = nil
local returnTo: GuiObject? = nil
local openedAt = 0
local lostAt: number? = nil

RunService.Heartbeat:Connect(function()
	local frame = MenuKit.openFrame()
	local now = os.clock()
	if frame ~= currentFrame then
		local previous = currentFrame
		currentFrame = frame
		if frame then
			frame.SelectionGroup = true
			markClose(frame)
			openedAt = now
			lostAt = nil
			local selected = GuiService.SelectedObject
			returnTo = if selected and selected:IsDescendantOf(menuColumn) then selected else returnTo
		elseif previous and ScreenScale.usingGamepad() and (GuiService.SelectedObject == nil or selectionIn(previous)) then
			local back = returnTo
			GuiService.SelectedObject = if back and back.Parent and isShown(back, hud) then back else nil
		end
		if not frame then
			returnTo = nil
		end
	end
	-- Fenêtre ouverte à la manette : la sélection doit y être (au début, et si son bouton a disparu au rafraîchissement).
	if frame and ScreenScale.usingGamepad() and now - openedAt >= FOCUS_DELAY then
		if selectionIn(frame) then
			lostAt = nil
		else
			lostAt = lostAt or now
			if now - (lostAt :: number) >= 0.15 then
				lostAt = nil
				GuiService.SelectedObject = firstButton(frame)
			end
		end
	end
end)

----------------------------------------------------------------------
-- Boutons
----------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if input.KeyCode == Enum.KeyCode.ButtonB then
		-- Roblox enlève déjà la sélection sur B (processed = true) : on ferme en plus la fenêtre ouverte.
		if MenuKit.anyOpen() then
			MenuKit.closeAll()
		end
	elseif input.KeyCode == Enum.KeyCode.DPadLeft and not processed then
		if MenuKit.anyOpen() then
			return
		end
		if selectionIn(menuColumn) or GuiService.SelectedObject == menuHandle then
			GuiService.SelectedObject = nil
		else
			focusTiles()
		end
	end
end)
