-- InteractionController : gère le ramassage et le lancer d'objets "Item" côté client.
-- Ramassage : ProximityPromptService.PromptTriggered -> WeldConstraint sur la main droite.
-- Lancer : UserInputService.InputBegan (MouseButton1) -> ApplyImpulse via la caméra.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Dossier contenant les points de l'arc de prédiction.
local trajectoryFolder = Instance.new("Folder")
trajectoryFolder.Name = "Trajectory"
trajectoryFolder.Parent = workspace

-- Points de l'arc de prédiction (petits cubes Neon).
local dots = {}
for i = 1, 15 do
	local dot = Instance.new("Part")
	dot.Name = "Dot" .. i
	dot.Size = Vector3.new(0.4, 0.4, 0.4)
	dot.Anchored = true
	dot.CanCollide = false
	dot.Transparency = 1
	dot.Material = Enum.Material.Neon
	dot.Parent = trajectoryFolder
	dots[i] = dot
end

-- Marqueur de cible affiché à l'impact prévu.
local targetMarker = Instance.new("Part")
targetMarker.Name = "TargetMarker"
targetMarker.Shape = Enum.PartType.Cylinder
targetMarker.Size = Vector3.new(0.2, 4, 4)
targetMarker.Material = Enum.Material.Neon
targetMarker.Color = Color3.fromRGB(255, 0, 0)
targetMarker.Anchored = true
targetMarker.CanCollide = false
targetMarker.Parent = nil

-- Connexion de rendu de l'arc (nil si inactif).
local renderConnection = nil

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

-- Vérifie si le joueur se trouve actuellement sur sa propre base.
-- Retourne true si le joueur est au-dessus de sa BasePart.
local function isOnOwnBase()
	local character = player.Character
	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local map = workspace:FindFirstChild("Map")
	if not map then
		return false
	end

	for _, base in ipairs(map:GetChildren()) do
		if base:IsA("Model") and base.Name:match("^Base%d+$") then
			local basePart = base:FindFirstChild("BasePart")
			if basePart and basePart:IsA("BasePart") then
				-- Vérifie si le joueur est au-dessus de la base (marge verticale).
				local localPos = basePart.CFrame:PointToObjectSpace(root.Position)
				local halfX = basePart.Size.X / 2
				local halfZ = basePart.Size.Z / 2
				if math.abs(localPos.X) <= halfX
					and math.abs(localPos.Z) <= halfZ
					and localPos.Y >= 0
					and localPos.Y <= 30
				then
					return true
				end
			end
		end
	end

	return false
end

-- Relâche et propulse l'item tenu devant le joueur.
-- chargeTime : durée de maintien du clic (0 à 2 secondes), influence la force du lancer.
local function throwItem(chargeTime)
	if not heldItem or not heldWeld then
		return
	end

	-- Interdit de jeter un item depuis sa propre base.
	if isOnOwnBase() then
		print("[Interaction] Impossible de jeter un item depuis sa propre base.")
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

-- Met à jour l'arc de prédiction et le marqueur de cible selon la charge actuelle.
local function updateTrajectory(chargeTime)
	if not heldItem then
		return
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		player.Character,
		heldItem,
		targetMarker,
		workspace:FindFirstChild("Trajectory"),
	}

	local v0 = (workspace.CurrentCamera.CFrame.LookVector + Vector3.new(0, 0.8, 0)).Unit
		* (50 + chargeTime * 100)
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	local currentPos = heldItem.Position

	-- Réinitialise l'affichage.
	targetMarker.Parent = nil
	for _, dot in ipairs(dots) do
		dot.Transparency = 1
	end

	for i = 1, 15 do
		local t = i * 0.15
		local nextPos = heldItem.Position + (v0 * t) + (0.5 * gravity * t * t)

		local rayResult = workspace:Raycast(currentPos, nextPos - currentPos, raycastParams)
		if rayResult then
			targetMarker.CFrame = CFrame.new(rayResult.Position, rayResult.Position + rayResult.Normal)
				* CFrame.Angles(math.pi / 2, 0, 0)
			targetMarker.Parent = workspace
			break
		else
			dots[i].Position = nextPos
			dots[i].Transparency = 0
			currentPos = nextPos
		end
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

			-- Met à jour l'arc de prédiction à chaque image.
			renderConnection = RunService.RenderStepped:Connect(function()
				local ct = math.clamp(os.clock() - chargeStartTime, 0, 2)
				updateTrajectory(ct)
			end)
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

		-- Nettoie l'affichage de l'arc de prédiction.
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		for _, dot in ipairs(dots) do
			dot.Transparency = 1
		end
		targetMarker.Parent = nil

		throwItem(chargeTime)
	end
end)
