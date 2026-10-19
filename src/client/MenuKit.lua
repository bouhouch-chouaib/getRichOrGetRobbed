--!strict
-- MenuKit : socle commun des menus (client/ShopMenu, client/IndexMenu, client/FusionMenu, client/RobuxShop).
--   - une seule fenêtre ouverte à la fois ; ouverture animée (16 oct. : elle monte du bas avec un rebond, son icône
--     se balance, le décor derrière devient flou), fermeture rapide qui rétrécit ;
--   - onglets latéraux collés à droite de la fenêtre (comme « Monde / Limité » dans la référence) ;
--   - lecture des attributs du joueur (argent, familiers, équipés) ;
--   - aperçu 3D d'un familier (silhouette noire s'il n'est pas encore découvert).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icons = require(ReplicatedStorage.Shared.Icons)
local LootEngine = require(ReplicatedStorage.Shared.LootEngine)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
local ScreenScale = require(script.Parent.ScreenScale)
local Sounds = require(script.Parent.Sounds)
local UiStyle = require(script.Parent.UiStyle)

local MenuKit = {}

local player = Players.LocalPlayer
MenuKit.player = player

----------------------------------------------------------------------
-- Données du joueur (attributs répliqués par server/SessionData)
----------------------------------------------------------------------

function MenuKit.number(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

function MenuKit.equipped(): { string }
	local list = {}
	local equipped = player:GetAttribute("Equipped")
	if type(equipped) == "string" then
		for petId in string.gmatch(equipped, "[^,]+") do
			table.insert(list, petId)
		end
	end
	return list
end

-- Exemplaires non équipés d'un familier (même calcul que le serveur).
function MenuKit.spare(petId: string): number
	local used = 0
	for _, id in ipairs(MenuKit.equipped()) do
		if id == petId then
			used += 1
		end
	end
	return math.max(0, MenuKit.number("Pet_" .. petId) - used)
end

-- Familiers dont la récompense d'Index a déjà été réclamée.
function MenuKit.claimed(): { [string]: boolean }
	local set = {}
	local value = player:GetAttribute("IndexClaimed")
	if type(value) == "string" then
		for petId in string.gmatch(value, "[^,]+") do
			set[petId] = true
		end
	end
	return set
end

-- Découvert = possédé maintenant, ou déjà réclamé dans l'Index (il reste découvert même s'il a été volé).
function MenuKit.discovered(petId: string, claimed: { [string]: boolean }): boolean
	if MenuKit.number("Pet_" .. petId) > 0 or claimed[petId] == true then
		return true
	end
	-- Une forme évoluée ou mutée possédée fait aussi découvrir l'espèce.
	for _, formId in ipairs(PetCatalog.FormsOf[petId] or {}) do
		if MenuKit.number("Pet_" .. formId) > 0 then
			return true
		end
	end
	return false
end

-- Rareté plancher des tirages du joueur (rang de tirage, shared/LootEngine.floor), comme le serveur la calcule.
function MenuKit.pullFloor(): number
	local claimed = MenuKit.claimed()
	local discovered: { [string]: boolean } = {}
	for _, entry in ipairs(PetCatalog.List) do
		if MenuKit.discovered(entry.Id, claimed) then
			discovered[entry.Id] = true
		end
	end
	return LootEngine.floor(MenuKit.number("TotalPulls"), discovered)
end

-- Nombre de récompenses d'Index qui attendent (formes évoluées comprises).
function MenuKit.claimableCount(): number
	local claimed = MenuKit.claimed()
	local count = 0
	for _, entry in ipairs(PetCatalog.Everything) do
		if not entry.Mutation and not claimed[entry.Id] and MenuKit.number("Pet_" .. entry.Id) > 0 then
			count += 1
		end
	end
	return count
end

----------------------------------------------------------------------
-- Aperçu 3D
----------------------------------------------------------------------

function MenuKit.eggViewport(parent: Instance, rarityId: string): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.Parent = parent
	local model = require(ReplicatedStorage.Shared.EggModelBuilder).Build(rarityId)
	model.Parent = viewport
	local box, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(.5, .3, -1).Unit * size.Magnitude * .95, box.Position)
	camera.Parent, viewport.CurrentCamera = viewport, camera
	return viewport
end

function MenuKit.petViewport(parent: Instance, petId: string, silhouette: boolean): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.Parent = parent
	local model = PetModelBuilder.Build(petId)
	if model then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") or descendant:IsA("BillboardGui") or descendant:GetAttribute("Aura") then
				descendant:Destroy()
			elseif silhouette and descendant:IsA("BasePart") then
				descendant.Color = Color3.fromRGB(20, 20, 30)
				descendant.Material = Enum.Material.SmoothPlastic
			end
		end
		model:PivotTo(CFrame.new())
		model.Parent = viewport
		local bodyBox, bodySize = PetModelBuilder.BodyBounds(model)
		local extent = bodySize.Magnitude
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(bodyBox.Position + Vector3.new(0.6, 0.4, -1).Unit * extent * 0.95, bodyBox.Position)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
	return viewport
end

----------------------------------------------------------------------
-- Fenêtres
----------------------------------------------------------------------

export type Window = {
	frame: Frame,
	header: Frame,
	content: Frame,
	open: () -> (),
	close: () -> (),
	toggle: () -> (),
	isOpen: () -> boolean,
	onOpen: (callback: () -> ()) -> (),
}

local openWindow: Window? = nil

-- Échelle pour que la fenêtre (et ses onglets à droite) tienne dans l'écran, avec une marge. Sur tactile, elle
-- s'ouvre à droite des tuiles de menu du HUD (elles restent visibles et touchables).
local function fit(frame: Frame): number
	local screen = ScreenScale.virtualSize()
	local tabs = if frame:FindFirstChild("SideTabs") then 206 else 0
	local width = frame.Size.X.Offset + tabs
	local height = frame.Size.Y.Offset
	local touch = ScreenScale.isTouch()
	local left = if touch then ScreenScale.TOUCH_LEFT_RESERVED else 0
	local right = if touch then ScreenScale.TOUCH_RIGHT_RESERVED else 0 -- bouton de saut de Roblox
	-- On narrow portrait screens, reserve a proportional strip instead of
	-- consuming almost all the available width with fixed HUD reservations.
	local reserveScale = math.min(1, screen.X * 0.35 / math.max(1, left + right))
	left *= reserveScale
	right *= reserveScale
	local scale = math.max(0.05, math.min(1, (screen.X - left - right - 32) / width, (screen.Y - 64) / height))
	local start = left + (screen.X - left - right - width * scale) / 2
	-- Center the complete window AND its tabs, not just the body.
	frame.Position = UDim2.fromOffset(start + frame.Size.X.Offset * scale / 2, screen.Y / 2 + 12)
	return scale
end

-- Flou du décor derrière une fenêtre ouverte (effet local au joueur).
local blur = Instance.new("BlurEffect")
blur.Name = "MenuBlur"
blur.Size = 0
blur.Parent = Lighting
local BLUR_SIZE = 14
local function setBlur(on: boolean)
	TweenService:Create(blur, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = if on then BLUR_SIZE else 0 }):Play()
end

-- icon : nom d'une icône (shared/Icons) affichée en grand dans l'en-tête.
function MenuKit.window(parent: Instance, title: string, size: Vector2, headerColor: Color3, icon: string?): Window
	local built = UiStyle.window(parent, title, size, headerColor, icon)
	local frame = built.frame
	local callbacks: { () -> () } = {}
	local opened = false
	local token = 0
	local window: Window
	window = {
		frame = frame,
		header = built.header,
		content = built.content,
		open = function()
			if openWindow and openWindow ~= window then
				openWindow.close()
			end
			openWindow = window
			token += 1
			if not opened then
				Sounds.play("WindowOpen")
			end
			opened = true
			frame.Visible = true
			setBlur(true)
			local scale = fit(frame)
			local target = frame.Position
			-- Monte du bas avec un rebond.
			frame.Position = target + UDim2.fromOffset(0, 70)
			built.scale.Scale = 0.7 * scale
			TweenService:Create(built.scale, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = scale }):Play()
			TweenService:Create(frame, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Position = target }):Play()
			local headerIcon = built.icon
			if headerIcon then
				headerIcon.Rotation = -35
				headerIcon.Size = UDim2.fromOffset(40, 40)
				TweenService:Create(headerIcon, TweenInfo.new(0.5, Enum.EasingStyle.Elastic),
					{ Rotation = -10, Size = UDim2.fromOffset(96, 96) }):Play()
			end
			for _, callback in ipairs(callbacks) do
				task.spawn(callback)
			end
		end,
		close = function()
			if openWindow == window then
				openWindow = nil
				setBlur(false)
			end
			if not opened then
				return
			end
			opened = false
			token += 1
			local current = token
			local scale = built.scale.Scale
			TweenService:Create(built.scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = scale * 0.8 }):Play()
			task.delay(0.12, function()
				if current == token then
					frame.Visible = false
				end
			end)
		end,
		toggle = function()
			if opened then
				window.close()
			else
				window.open()
			end
		end,
		isOpen = function()
			return opened
		end,
		onOpen = function(callback: () -> ())
			table.insert(callbacks, callback)
		end,
	}
	-- Refit an already open menu after resizing or rotating the screen.
	if parent:IsA("GuiObject") then
		local resizeConnection = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			task.defer(function()
				if opened and frame.Parent then
					local scale = fit(frame)
					TweenService:Create(built.scale, TweenInfo.new(0), { Scale = scale }):Play()
					TweenService:Create(frame, TweenInfo.new(0), { Position = frame.Position }):Play()
				end
			end)
		end)
		frame.Destroying:Connect(function()
			resizeConnection:Disconnect()
		end)
	end
	built.closeButton.Activated:Connect(window.close)
	-- Fenêtre cachée par un autre script (Visible = false) : elle compte comme fermée (sinon le flou resterait).
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible and opened then
			opened = false
			if openWindow == window then
				openWindow = nil
				setBlur(false)
			end
		end
	end)
	return window
end

-- Une fenêtre est-elle ouverte ?
function MenuKit.anyOpen(): boolean
	return openWindow ~= nil
end

function MenuKit.closeAll()
	if openWindow then
		openWindow.close()
	end
end

----------------------------------------------------------------------
-- Onglets latéraux
----------------------------------------------------------------------

export type Tab = { label: string, color: Color3, icon: string? }
export type Tabs = {
	select: (index: number) -> (),
	setBadge: (index: number, value: string?) -> (),
	selected: () -> number,
}

-- Colonne d'onglets à droite de la fenêtre (16 oct. : refaits façon packs « Studs UI »). Chaque onglet : couleur en
-- relief, tenons, reflet, icône contenue dans sa case, nom en gros. L'onglet choisi se colle à la fenêtre avec
-- une flèche qui pointe dessus, brille (halo + contour blanc) ; les autres sont un peu éteints et décalés, et
-- ressortent au survol. onSelect(index) est appelé à chaque changement.
local TAB_WIDTH = 176
local TAB_OUT = 14 -- décalage vers la droite des onglets non choisis
function MenuKit.sideTabs(window: Window, tabs: { Tab }, onSelect: (index: number) -> ()): Tabs
	local column = Instance.new("Frame")
	column.Name = "SideTabs"
	column.BackgroundTransparency = 1
	column.Position = UDim2.new(1, 6, 0, 70)
	column.Size = UDim2.new(0, TAB_WIDTH + TAB_OUT + 10, 1, -70)
	column.Parent = window.frame

	local gap = 10
	local tabHeight = math.clamp(math.floor((window.frame.Size.Y.Offset - 80) / #tabs) - gap, 36, 66)
	type TabUi = {
		button: TextButton,
		holder: Frame,
		scale: UIScale,
		shade: UIGradient,
		border: UIStroke,
		icon: ImageLabel?,
		caption: TextLabel,
		arrow: Frame,
		glow: ImageLabel,
		color: Color3,
	}
	local items: { TabUi } = {}
	local badges: { TextLabel } = {}
	local current = 1
	local hovered: number? = nil
	local WHITE = Color3.new(1, 1, 1)
	local BLACK = Color3.new(0, 0, 0)

	local function refresh(animate: boolean)
		for index, ui in ipairs(items) do
			local active = index == current
			local hot = hovered == index
			local x = if active then 0 elseif hot then TAB_OUT / 2 else TAB_OUT
			local info = TweenInfo.new(if animate then 0.22 else 0, Enum.EasingStyle.Back)
			TweenService:Create(ui.holder, info, { Position = UDim2.fromOffset(x, (index - 1) * (tabHeight + gap)) }):Play()
			TweenService:Create(ui.scale, info, { Scale = 1 }):Play()
			ui.shade.Color = UiStyle.buttonColors(if active then ui.color
				elseif hot then ui.color:Lerp(Color3.fromRGB(70, 70, 90), 0.2)
				else ui.color:Lerp(Color3.fromRGB(60, 60, 80), 0.45))
			ui.border.Color = if active then WHITE else BLACK
			ui.border.Thickness = if active then 4 else 3
			ui.caption.TextTransparency = if active then 0 else 0.15
			local icon = ui.icon
			if icon then
				icon.ImageTransparency = if active then 0 else 0.2
				local side = tabHeight * 0.72
				TweenService:Create(icon, info, { Size = UDim2.fromOffset(side, side) }):Play()
			end
			ui.arrow.Visible = active
			ui.glow.Visible = active
		end
	end

	for index, tab in ipairs(tabs) do
		-- Support (position animée) > bouton (taille fixe, grossit avec son UIScale).
		local holder = Instance.new("Frame")
		holder.Name = "Tab" .. index
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(TAB_WIDTH, tabHeight)
		holder.Position = UDim2.fromOffset(TAB_OUT, (index - 1) * (tabHeight + gap))
		holder.Parent = column

		-- Halo derrière l'onglet choisi.
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.new(1, 50, 1, 40)
		glow.Image = UiStyle.Textures.Glow
		glow.ImageColor3 = UiStyle.lighter(tab.color, 0.3)
		glow.ImageTransparency = 0.15
		glow.Visible = false
		glow.Parent = holder

		local button = Instance.new("TextButton")
		button.Name = "Button"
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundColor3 = WHITE
		button.Size = UDim2.fromScale(1, 1)
		button.ZIndex = 2
		UiStyle.corner(button, 10)
		local border = UiStyle.stroke(button, 3, BLACK, true)
		border.Name = "Border"
		local shade = UiStyle.gradient(button, WHITE, WHITE)
		shade.Color = UiStyle.buttonColors(tab.color)
		button.Parent = holder
		local scale = Instance.new("UIScale")
		scale.Parent = button

		-- Décor : tenons (taille du bouton, rien ne dépasse), reflet en haut, lèvre sombre en bas, reflet au survol.
		local studs = Instance.new("Frame")
		studs.BackgroundTransparency = 1
		studs.Size = UDim2.fromScale(1, 1)
		studs.ZIndex = 2
		studs.Parent = button
		UiStyle.studs(studs, WHITE, 16, 0.86)
		local shine = Instance.new("Frame")
		shine.BackgroundColor3 = WHITE
		shine.BackgroundTransparency = 0.75
		shine.BorderSizePixel = 0
		shine.Position = UDim2.fromOffset(5, 3)
		shine.Size = UDim2.new(1, -10, 0.32, 0)
		shine.ZIndex = 2
		UiStyle.corner(shine, 6)
		shine.Parent = button
		local lip = Instance.new("Frame")
		lip.BackgroundColor3 = BLACK
		lip.BackgroundTransparency = 0.78
		lip.BorderSizePixel = 0
		lip.AnchorPoint = Vector2.new(0, 1)
		lip.Position = UDim2.fromScale(0, 1)
		lip.Size = UDim2.new(1, 0, 0, 6)
		lip.ZIndex = 2
		UiStyle.corner(lip, 10)
		lip.Parent = button
		UiStyle.addSweep(button, 10)

		-- Icône avec une marge dans chaque onglet.
		local icon: ImageLabel? = nil
		local textLeft = 12
		if tab.icon then
			local image = Icons.image(button, tab.icon, UDim2.fromOffset(tabHeight * 0.72, tabHeight * 0.72))
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Position = UDim2.new(0, tabHeight * 0.45, 0.5, 0)
			image.Rotation = -8
			image.ZIndex = 4
			UiStyle.sway(image, 4)
			icon = image
			textLeft = math.floor(tabHeight * 0.92)
		end
		local caption = UiStyle.text(button, tab.label, 26, WHITE, UiStyle.TITLE_FONT)
		caption.Name = "Caption"
		caption.Position = UDim2.fromOffset(textLeft, 6)
		caption.Size = UDim2.new(1, -textLeft - 40, 1, -12) -- marge avant la pastille rouge à droite
		caption.TextXAlignment = if tab.icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		caption.TextScaled = true
		caption.TextWrapped = false -- une seule ligne : le texte rétrécit pour tenir
		caption.ZIndex = 4
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.min(26, math.floor(tabHeight * 0.48))
		limit.Parent = caption

		-- Flèche blanche à contour noir qui pointe vers la fenêtre.
		local arrow = Instance.new("Frame")
		arrow.Name = "Arrow"
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Position = UDim2.new(0, -2, 0.5, 0)
		arrow.Size = UDim2.fromOffset(18, 18)
		arrow.Rotation = 45
		arrow.BackgroundColor3 = WHITE
		arrow.BorderSizePixel = 0
		arrow.ZIndex = 1
		arrow.Visible = false
		UiStyle.corner(arrow, 3)
		UiStyle.stroke(arrow, 3, BLACK, true)
		arrow.Parent = button

		items[index] = {
			button = button,
			holder = holder,
			scale = scale,
			shade = shade,
			border = border,
			icon = icon,
			caption = caption,
			arrow = arrow,
			glow = glow,
			color = tab.color,
		}
		local badge = UiStyle.badge(button)
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.new(1, -5, 0.5, 0)
		badge.Size = UDim2.fromOffset(22, 22)
		badges[index] = badge

		button.MouseEnter:Connect(function()
			hovered = index
			UiStyle.sweep(button)
			refresh(true)
		end)
		button.MouseLeave:Connect(function()
			if hovered == index then
				hovered = nil
				refresh(true)
			end
		end)
		button.MouseButton1Down:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
		end)
		button.Activated:Connect(function()
			Sounds.play("UiClick")
			current = index
			refresh(true)
			onSelect(index)
		end)
	end
	refresh(false)

	return {
		select = function(index: number)
			current = index
			refresh(true)
			onSelect(index)
		end,
		setBadge = function(index: number, value: string?)
			if badges[index] then
				UiStyle.setBadge(badges[index], value)
			end
		end,
		selected = function()
			return current
		end,
	}
end

return MenuKit
