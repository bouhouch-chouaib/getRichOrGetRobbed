--!strict
-- CarryControls : bouton « JETER DANS LE TROU » quand on porte un familier près du trou noir pendant le Feeding
-- (touche E, manette X, ou toucher le bouton). Il annonce la récompense (Config.Sacrifice : argent selon le revenu du
-- familier, points du tour). Le serveur revérifie tout (server/StealController, Remotes.ThrowPet).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ScreenScale = require(script.Parent.ScreenScale)
local UiStyle = require(script.Parent.UiStyle)

local player = Players.LocalPlayer
local ACTION = "ThrowPetInHole"
local RANGE = Config.Arena.HoleRadius + Config.Sacrifice.Range

local gui = Instance.new("ScreenGui")
gui.Name = "CarryControls"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")
local root = ScreenScale.attach(gui)

local button = UiStyle.button(root, "JETER DANS LE TROU !", UDim2.fromOffset(340, 64), Color3.fromRGB(170, 60, 255), 30)
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -ScreenScale.BOTTOM_RESERVED)
button.Visible = false
local caption = button:FindFirstChild("Caption") :: TextLabel
local reward = UiStyle.text(button, "", 18, UiStyle.Colors.Gold)
-- Au-dessus du bouton (en dessous, il y a la barre d'objets de Roblox).
reward.AnchorPoint = Vector2.new(0.5, 1)
reward.Position = UDim2.new(0.5, 0, 0, -4)
reward.Size = UDim2.new(1.4, 0, 0, 24)

local key = if ScreenScale.isTouch() then "" else "  [E]"
local bound = false

local function throw()
	if button.Visible then
		Remotes.ThrowPet:FireServer()
	end
end

button.Activated:Connect(throw)

local function setBound(on: boolean)
	if on == bound then
		return
	end
	bound = on
	if on then
		ContextActionService:BindActionAtPriority(ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				throw()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	else
		ContextActionService:UnbindAction(ACTION)
	end
end

RunService.Heartbeat:Connect(function()
	local petId = player:GetAttribute("CarryingPet")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local show = false
	if type(petId) == "string" and hrp and hrp:IsA("BasePart") and ReplicatedStorage:GetAttribute("GameState") == "Feeding" then
		show = Vector3.new(hrp.Position.X, 0, hrp.Position.Z).Magnitude <= RANGE
	end
	if show and type(petId) == "string" then
		-- Aperçu de la récompense (le serveur ajoute les bonus des passes).
		local tier = player:GetAttribute("Tier")
		local world = Config.GetWorld(if type(tier) == "number" then tier else 1)
		local money = PetCatalog.GetIncome(petId) * Config.Sacrifice.IncomeSeconds * world.IncomeMultiplier
		local entry = PetCatalog.ById[petId]
		local points = Config.Sacrifice.Points[if entry then Config.RarityIndex[entry.Rarity] or 1 else 1] or 1
		caption.Text = "JETER DANS LE TROU !" .. key
		reward.Text = string.format("+%s  •  +%d POINTS", NumberFormat.money(money), points)
	end
	if button.Visible ~= show then
		button.Visible = show
	end
	setBound(show)
end)
