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
--
-- Anti-duplication : pendant le transport, le familier reste à la victime (simplement "réservé", caché de sa base).
-- Le transfert se fait en UNE étape serveur sans attente (RemovePets puis AddPets), seulement si les deux sauvegardes
-- sont chargées (verrou de session tenu), puis les deux profils sont sauvegardés (victime d'abord).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local BasePetsController = require(script.Parent.BasePetsController)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local SessionData = require(script.Parent.SessionData)

local StealController = {}

local STEAL = Config.Steal

-- Résultat envoyé au voleur (Remotes.StealResult) : "Success", "KO", "Timeout", "VictimLeft", "Gone".
export type Outcome = "Success" | "KO" | "Timeout" | "VictimLeft" | "Gone"

type Carry = {
	thief: Player,
	victim: Player,
	victimBase: Model,
	petId: string,
	deadline: number, -- heure serveur limite
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
		else
			outcome = "Gone" -- la victime ne l'a plus (fusion, équipement...) ou une sauvegarde n'est pas chargée
		end
	end
	BasePetsController.Reserve(carry.victimBase, carry.petId, -1)

	local thief = carry.thief
	if thief.Parent then
		thief:SetAttribute("CarryingPet", nil)
		thief:SetAttribute("CarryingUntil", nil)
		thief:SetAttribute("SpeedMultiplier", nil)
		SessionData.RefreshSpeed(thief)
		Remotes.StealResult:FireClient(thief, outcome, carry.petId)
	end
	print(string.format("[Steal] %s -> %s : %s (%s)", carry.victim.Name, thief.Name, carry.petId, outcome))

	if outcome == "Success" then
		-- Les deux profils sont écrits tout de suite : la victime d'abord (si le serveur plantait entre les deux,
		-- le familier serait perdu par le voleur, jamais dupliqué).
		task.spawn(function()
			SessionData.Save(carry.victim)
			SessionData.Save(thief)
		end)
	end
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
	carries[thief] = { thief = thief, victim = victim, victimBase = victimBase, petId = petId, deadline = deadline }
	BasePetsController.Reserve(victimBase, petId, 1)
	thief:SetAttribute("CarryingPet", petId)
	thief:SetAttribute("CarryingUntil", deadline)
	thief:SetAttribute("SpeedMultiplier", STEAL.SpeedMultiplier)
	SessionData.RefreshSpeed(thief)
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
