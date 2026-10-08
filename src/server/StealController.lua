--!strict
-- StealController : vol de familiers dans les bases adverses (cœur du genre "Steal a ...").
--
-- Règles (Config.Steal) :
--   - [E] (maintenu) sur un familier qui se balade dans une base adverse DÉVERROUILLÉE, pendant la digestion.
--   - Le voleur le porte dans le dos (attribut "CarryingPet", affiché par client/PetFollow), est ralenti
--     (attribut "SpeedMultiplier") et ne peut plus ramasser d'objet. Un seul familier à la fois.
--   - Arrivé dans SA base : le familier change de propriétaire.
--   - Échec, le familier rentre chez sa victime : voleur KO / mort / réapparu (ItemInteraction.HeldReleased),
--     voleur ou victime qui quitte le serveur, transport trop long (Config.Steal.MaxCarryTime).
--   - Défense : une bulle [E] "Reprendre" est posée sur le voleur ; seule la victime la voit (attribut "CarryingFrom"
--     = UserId de la victime, lu par client/PetFollow, qui entoure aussi le voleur de rouge chez elle). Si elle la
--     valide assez près (vérifié ici), le familier rentre chez elle.
--   - Annonces (Remotes.StealNotice) : la victime est prévenue au début et à la fin du vol ; tout le serveur
--     apprend les vols réussis de rareté >= Config.Loot.AnnounceMinRarity.
--
-- Anti-duplication : pendant le transport, le familier reste à la victime (simplement "réservé", caché de sa base).
-- Le transfert se fait en UNE étape serveur sans attente (RemovePets puis AddPets), seulement si les deux sauvegardes
-- sont chargées (verrou de session tenu), puis les deux profils sont sauvegardés (victime d'abord).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local BasePetsController = require(script.Parent.BasePetsController)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local SessionData = require(script.Parent.SessionData)

local StealController = {}

local STEAL = Config.Steal

-- Résultat envoyé au voleur (Remotes.StealResult) : "Success", "KO", "Timeout", "VictimLeft", "Gone", "Recovered".
export type Outcome = "Success" | "KO" | "Timeout" | "VictimLeft" | "Gone" | "Recovered"

-- Ce que la victime apprend à la fin du vol (Remotes.StealNotice) ; nil = rien à lui dire.
local VICTIM_NOTICE: { [string]: string } = {
	Success = "Stolen",
	Recovered = "Recovered",
	KO = "Returned",
	Timeout = "Returned",
}

type Carry = {
	thief: Player,
	victim: Player,
	victimBase: Model,
	petId: string,
	deadline: number, -- heure serveur limite
	prompt: ProximityPrompt?, -- bulle "Reprendre" posée sur le voleur
}

local carries: { [Player]: Carry } = {} -- voleur -> vol en cours

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Même zone que l'expulsion du verrou (LockController) : le dessus de la plateforme, un peu élargi.
local function isInsideBase(base: Model, position: Vector3): boolean
	local platform = base:FindFirstChild("BasePart")
	if not platform or not platform:IsA("BasePart") then
		return false
	end
	local localPosition = platform.CFrame:PointToObjectSpace(position)
	local half = platform.Size / 2 + Vector3.new(1.5, 0, 1.5)
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y > -3 and localPosition.Y < 25
end

-- Fin du vol (réussi ou non) : le voleur retrouve sa vitesse et ses mains, la réservation est rendue.
local function finish(carry: Carry, outcome: Outcome)
	if carries[carry.thief] ~= carry then
		return -- déjà terminé
	end
	carries[carry.thief] = nil

	if outcome == "Success" then
		-- Transfert en une seule étape, sans aucune attente entre le retrait et l'ajout.
		local ok = SessionData.IsLoaded(carry.victim)
			and SessionData.IsLoaded(carry.thief)
			and SessionData.RemovePets(carry.victim, { [carry.petId] = 1 })
		if ok then
			SessionData.AddPets(carry.thief, { [carry.petId] = 1 })
			BasePetsController.Celebrate(carry.thief, { carry.petId })
		else
			outcome = "Gone" -- la victime ne l'a plus (fusion, équipement...) ou une sauvegarde n'est pas chargée
		end
	end
	BasePetsController.Reserve(carry.victimBase, carry.petId, -1)
	if carry.prompt then
		carry.prompt:Destroy()
	end

	local thief = carry.thief
	local victim = carry.victim
	if thief.Parent then
		thief:SetAttribute("CarryingPet", nil)
		thief:SetAttribute("CarryingUntil", nil)
		thief:SetAttribute("CarryingFrom", nil)
		thief:SetAttribute("SpeedMultiplier", nil)
		SessionData.RefreshSpeed(thief)
		Remotes.StealResult:FireClient(thief, outcome, carry.petId)
	end
	local notice = VICTIM_NOTICE[outcome]
	if notice and victim.Parent then
		Remotes.StealNotice:FireClient(victim, notice, thief.DisplayName, victim.DisplayName, carry.petId)
	end
	if outcome == "Success" then
		local entry = PetCatalog.ById[carry.petId]
		if entry and (Config.RarityIndex[entry.Rarity] or 0) >= Config.Loot.AnnounceMinRarity then
			Remotes.StealNotice:FireAllClients("Announce", thief.DisplayName, victim.DisplayName, carry.petId)
		end
	end
	print(string.format("[Steal] %s -> %s : %s (%s)", victim.Name, thief.Name, carry.petId, outcome))

	if outcome == "Success" then
		-- Les deux profils sont écrits tout de suite : la victime d'abord (si le serveur plantait entre les deux,
		-- le familier serait perdu par le voleur, jamais dupliqué).
		task.spawn(function()
			SessionData.Save(carry.victim)
			SessionData.Save(thief)
		end)
	end
end

-- La victime valide la bulle "Reprendre" posée sur le voleur : vérifiée ici (bon joueur, vivant, assez près).
local function tryRecover(carry: Carry, player: Player)
	if carries[carry.thief] ~= carry or player ~= carry.victim or not isAlive(player) then
		return
	end
	local victimRoot = getRoot(player)
	local thiefRoot = getRoot(carry.thief)
	if not victimRoot or not thiefRoot then
		return
	end
	if (victimRoot.Position - thiefRoot.Position).Magnitude > STEAL.RecoverMaxDistance then
		return
	end
	finish(carry, "Recovered")
end

-- Un joueur valide [E] sur un familier de base : toutes les vérifications sont faites ici.
local function tryStart(anchor: BasePart, thief: Player)
	if carries[thief] then
		return -- un seul familier à la fois
	end
	if STEAL.OnlyDuringDigesting and GameLoopManager.GetState() ~= "Digesting" then
		return
	end
	local victimBase = BasePetsController.GetBaseOf(anchor)
	local victim = victimBase and BaseManager.GetOwner(victimBase)
	local petId = anchor:GetAttribute("PetId")
	if not victimBase or not victim or victim == thief or type(petId) ~= "string" then
		return
	end
	if victimBase:GetAttribute("Locked") == true then
		return
	end
	if not BaseManager.GetBase(thief) or not isAlive(thief) then
		return
	end
	-- Les deux sauvegardes doivent être chargées, sinon le transfert ne serait pas enregistré (risque de copie).
	if not SessionData.IsLoaded(victim) or not SessionData.IsLoaded(thief) then
		return
	end
	-- Un exemplaire non équipé et pas déjà en cours de vol.
	if SessionData.GetSpareCount(victim, petId) - BasePetsController.GetReserved(victimBase, petId) < 1 then
		return
	end
	-- Distance réelle (position officielle du familier, côté serveur), avec une marge pour la latence.
	local root = getRoot(thief)
	local petPosition = BasePetsController.GetPetPosition(anchor)
	if not root or not petPosition then
		return
	end
	local offset = root.Position - petPosition
	if Vector2.new(offset.X, offset.Z).Magnitude > STEAL.MaxDistance then
		return
	end

	-- Les mains doivent être libres : on lâche les objets portés AVANT d'enregistrer le vol
	-- (ReleaseHeld déclenche HeldReleased, qui ferait sinon échouer ce vol tout de suite).
	ItemInteraction.ReleaseHeld(thief)

	local deadline = now() + STEAL.MaxCarryTime
	local carry: Carry = { thief = thief, victim = victim, victimBase = victimBase, petId = petId, deadline = deadline, prompt = nil }
	carries[thief] = carry
	BasePetsController.Reserve(victimBase, petId, 1)
	thief:SetAttribute("CarryingPet", petId)
	thief:SetAttribute("CarryingUntil", deadline)
	thief:SetAttribute("CarryingFrom", victim.UserId) -- la victime seule voit "Reprendre" (client/PetFollow)
	thief:SetAttribute("SpeedMultiplier", STEAL.SpeedMultiplier)
	SessionData.RefreshSpeed(thief)

	-- Bulle "Reprendre" sur le voleur : un simple appui suffit (la victime court après lui).
	local entry = PetCatalog.ById[petId]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RecoverPrompt"
	prompt.ActionText = "Reprendre"
	prompt.ObjectText = if entry then entry.Name else petId
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = STEAL.RecoverPromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		tryRecover(carry, player)
	end)
	prompt.Parent = root
	carry.prompt = prompt

	Remotes.StealNotice:FireClient(victim, "Started", thief.DisplayName, victim.DisplayName, petId)
	print(string.format("[Steal] %s vole %s chez %s", thief.Name, petId, victim.Name))
end

-- Vérifié plusieurs fois par seconde : arrivée dans sa base, temps écoulé, victime partie.
local function update()
	local time = now()
	for thief, carry in pairs(carries) do
		if not carry.victim.Parent then
			finish(carry, "VictimLeft")
		elseif time >= carry.deadline then
			finish(carry, "Timeout")
		else
			local thiefBase = BaseManager.GetBase(thief)
			local root = getRoot(thief)
			if thiefBase and root and isInsideBase(thiefBase, root.Position) then
				finish(carry, "Success")
			end
		end
	end
end

function StealController.Init()
	BasePetsController.PetTriggered:Connect(tryStart)

	-- KO du dôme, mort, réapparition, départ du voleur : le vol échoue.
	ItemInteraction.HeldReleased:Connect(function(player: Player)
		local carry = carries[player]
		if carry then
			finish(carry, "KO")
		end
	end)

	-- La victime part : tous les vols de ses familiers sont annulés.
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, carry in pairs(carries) do
			if carry.victim == player then
				finish(carry, "VictimLeft")
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			update()
		end
	end)
end

return StealController
