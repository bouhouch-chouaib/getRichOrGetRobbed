-- InteractionController : gère le ramassage et le lancer d'objets "Item" côté client.
-- Ramassage : ProximityPromptService.PromptTriggered -> WeldConstraint sur la main droite.
-- Lancer : UserInputService.InputBegan (MouseButton1) -> ApplyImpulse via la caméra.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Référence vers l'item actuellement tenu par le joueur (nil si aucun).
local heldItem = nil
local heldWeld = nil

-- Retourne la main droite du personnage selon le rig (R6 ou R15).
local function getRightHand(character)
	if not character then
		return nil
	end

	-- R15
	local rightHand = character:FindFirstChild("RightHand")
	if rightHand then
		return rightHand
	end

	-- R6
	local rightArm = character:FindFirstChild("Right Arm")
	if rightArm then
		return rightArm
	end

	return nil
end

-- Soude l'item à la main droite du joueur.
local function grabItem(item)
	local character = player.Character
	if not character then
		return
	end

	local hand = getRightHand(character)
	if not hand then
		return
	end

	-- Si un item est déjà tenu, on le relâche d'abord.
	if heldItem and heldWeld then
		heldWeld:Destroy()
		heldItem = nil
		heldWeld = nil
	end

	-- Aligne parfaitement l'objet sur la main avant de le souder.
	item.CFrame = hand.CFrame

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = item
	weld.Part1 = hand
	weld.Parent = item

	-- TODO: Jouer l'AnimationTrack de levée du bras ici

	-- Désactive le prompt pour éviter un double ramassage.
	local prompt = item:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	-- Désactive la collision pendant la prise en main.
	item.CanCollide = false

	heldItem = item
	heldWeld = weld
end

-- Relâche et propulse l'item tenu devant le joueur.
local function throwItem()
	if not heldItem or not heldWeld then
		return
	end

	local item = heldItem
	local weld = heldWeld

	heldItem = nil
	heldWeld = nil

	weld:Destroy()

	item.CanCollide = true
	item:SetAttribute("Owner", player.Name)

	local camera = workspace.CurrentCamera
	if camera then
		local direction = camera.CFrame.LookVector
		item:ApplyImpulse(direction * item.AssemblyMass * 50)
	end
end

-- Écoute du déclenchement des ProximityPrompt.
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then
		return
	end

	local item = prompt.Parent
	if not item or item.Name ~= "Item" then
		return
	end

	if not item:IsA("BasePart") then
		return
	end

	grabItem(item)
end)

-- Écoute du clic gauche pour lancer l'item tenu.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		throwItem()
	end
end)
