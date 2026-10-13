--!strict
-- MenuKit : socle commun des menus (client/ShopMenu, client/IndexMenu, client/FusionMenu, client/RobuxShop).
--   - une seule fenêtre ouverte à la fois, ouverture animée ;
--   - onglets latéraux collés à droite de la fenêtre (comme « Monde / Limité » dans la référence) ;
--   - lecture des attributs du joueur (argent, familiers, équipés) ;
--   - aperçu 3D d'un familier (silhouette noire s'il n'est pas encore découvert).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetModelBuilder = require(ReplicatedStorage.Shared.PetModelBuilder)
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
	return MenuKit.number("Pet_" .. petId) > 0 or claimed[petId] == true
end

-- Nombre de récompenses d'Index qui attendent.
function MenuKit.claimableCount(): number
	local claimed = MenuKit.claimed()
	local count = 0
	for _, entry in ipairs(PetCatalog.List) do
		if not claimed[entry.Id] and MenuKit.number("Pet_" .. entry.Id) > 0 then
			count += 1
		end
	end
	return count
end

----------------------------------------------------------------------
-- Aperçu 3D
----------------------------------------------------------------------

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

function MenuKit.window(parent: Instance, title: string, size: Vector2, headerColor: Color3): Window
	local built = UiStyle.window(parent, title, size, headerColor)
	local frame = built.frame
	local callbacks: { () -> () } = {}
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
			if not frame.Visible then
				Sounds.play("WindowOpen")
			end
			frame.Visible = true
			built.scale.Scale = 0.6
			TweenService:Create(built.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			for _, callback in ipairs(callbacks) do
				task.spawn(callback)
			end
		end,
		close = function()
			if openWindow == window then
				openWindow = nil
			end
			frame.Visible = false
		end,
		toggle = function()
			if frame.Visible then
				window.close()
			else
				window.open()
			end
		end,
		isOpen = function()
			return frame.Visible
		end,
		onOpen = function(callback: () -> ())
			table.insert(callbacks, callback)
		end,
	}
	built.closeButton.Activated:Connect(window.close)
	return window
end

function MenuKit.closeAll()
	if openWindow then
		openWindow.close()
	end
end

----------------------------------------------------------------------
-- Onglets latéraux
----------------------------------------------------------------------

export type Tab = { label: string, color: Color3 }
export type Tabs = {
	select: (index: number) -> (),
	setBadge: (index: number, value: string?) -> (),
	selected: () -> number,
}

-- Colonne d'onglets à droite de la fenêtre. onSelect(index) est appelé à chaque changement.
function MenuKit.sideTabs(window: Window, tabs: { Tab }, onSelect: (index: number) -> ()): Tabs
	local column = Instance.new("Frame")
	column.Name = "SideTabs"
	column.BackgroundTransparency = 1
	column.Position = UDim2.new(1, 12, 0, 70)
	column.Size = UDim2.new(0, 160, 1, -70)
	column.Parent = window.frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column

	local tabHeight = math.clamp(math.floor((window.frame.Size.Y.Offset - 90) / #tabs) - 8, 34, 64)
	local buttons: { TextButton } = {}
	local badges: { TextLabel } = {}
	local current = 1

	local function refresh()
		for index, button in ipairs(buttons) do
			local active = index == current
			local border = button:FindFirstChild("Border")
			if border and border:IsA("UIStroke") then
				border.Color = if active then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
				border.Thickness = if active then 4 else 3
			end
			button.Size = UDim2.fromOffset(if active then 160 else 146, tabHeight)
		end
	end

	for index, tab in ipairs(tabs) do
		local button = UiStyle.button(column, "", UDim2.fromOffset(146, tabHeight), tab.color, 1)
		button.LayoutOrder = index
		local border = button:FindFirstChildOfClass("UIStroke")
		if border then
			border.Name = "Border"
		end
		local caption = UiStyle.text(button, tab.label, if tabHeight < 44 then 18 else 24, Color3.new(1, 1, 1), UiStyle.BODY_FONT)
		caption.Size = UDim2.new(1, -10, 1, 0)
		caption.Position = UDim2.fromOffset(5, 0)
		caption.TextScaled = true
		caption.ZIndex = 2
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = if tabHeight < 44 then 18 else 24
		limit.Parent = caption
		buttons[index] = button
		badges[index] = UiStyle.badge(button)
		button.Activated:Connect(function()
			current = index
			refresh()
			onSelect(index)
		end)
	end
	refresh()

	return {
		select = function(index: number)
			current = index
			refresh()
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
