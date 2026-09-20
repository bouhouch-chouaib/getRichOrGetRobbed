-- InteractionController : gère le ramassage et le lancer d'objets "Item" côté client.
-- Ramassage : ProximityPromptService.PromptTriggered -> WeldConstraint sur la main droite.
-- Lancer : UserInputService.InputBegan (MouseButton1) -> ApplyImpulse via la caméra.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Référence vers l'item actuellement tenu par le joueur (nil si aucun).
local heldItem = nil
local heldWeld = nil

-- État de la charge du lancer.
local chargeStartTime = 0
local isCharging = false

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
-- chargeTime : durée de maintien du clic (0 à 2 secondes), influence la force du lancer.
local function throwItem(chargeTime)
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
		local direction = (camera.CFrame.LookVector + Vector3.new(0, 0.8, 0)).Unit
		item:ApplyImpulse(direction * item.AssemblyMass * (50 + chargeTime * 100))
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

-- Écoute du clic gauche : démarre la charge si un item est tenu.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if heldItem then
			isCharging = true
			chargeStartTime = os.clock()

			-- Ralentit le joueur pour simuler l'effort de charge.
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 8
				end
			end

			-- Zoom caméra progressif sur 2 secondes.
			local camera = workspace.CurrentCamera
			if camera then
				TweenService:Create(camera, TweenInfo.new(2), { FieldOfView = 50 }):Play()
			end
		end
	end
end)

-- Écoute du relâchement du clic gauche : lance l'item avec la force chargée.
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and isCharging then
		isCharging = false
		local chargeTime = math.clamp(os.clock() - chargeStartTime, 0, 2)

		-- Rétablit la vitesse du joueur.
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 16
			end
		end

		-- Annule le zoom rapidement.
		local camera = workspace.CurrentCamera
		if camera then
			TweenService:Create(camera, TweenInfo.new(0.2), { FieldOfView = 70 }):Play()
		end

		throwItem(chargeTime)
	end
end)
