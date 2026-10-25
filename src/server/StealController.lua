--!strict
-- StealController : porter les familiers (cœur du genre "Steal a ...") : les voler, porter les siens, les jeter dans
-- le trou noir, les lâcher.
--
-- Règles (Config.Steal, Config.Carry, Config.Sacrifice) :
--   - [E] (maintenu) sur un familier qui se balade dans une base. Base adverse DÉVERROUILLÉE : on le VOLE. Sa propre
--     base : on le PORTE (pour le jeter dans le trou noir). Mains libres (ni objet ni arme). La bulle est créée par le
--     client (client/BasePets) qui envoie Remotes.StealPet -> BasePetsController.PetTriggered.
--   - Le porteur le tient à deux mains au-dessus de la tête (attribut "CarryingPet", affiché par client/PetFollow) et avance plus ou moins vite
--     selon la rareté du familier, sans dépasser la vitesse du propriétaire (Config.Carry, attribut "SpeedMultiplier").
--     Un seul familier à la fois.
--   - Voleur arrivé dans SA base : le familier change de propriétaire. Propriétaire revenu dans sa base : il le repose.
--   - Près du trou noir pendant le Feeding : Remotes.ThrowPet le JETTE dedans. Il est perdu pour son propriétaire et le
--     porteur gagne argent + points + jauge selon le familier (Config.Sacrifice).
--   - Frappé (batte), éjecté par le dôme, mort, réapparu, parti, ou trop lent (MaxCarryTime) : il LÂCHE le familier.
--     Celui-ci rentre à pied vers la base de son propriétaire (shared/PetPath, client/LoosePets) ; n'importe qui peut le
--     ramasser en chemin (Remotes.PickLoosePet) : le propriétaire le reprend, un autre le vole à son tour.
--   - La victime quitte le jeu pendant un vol : le voleur GAGNE le familier tout de suite ("VictimLeft"), transféré
--     juste avant la dernière sauvegarde de la victime (SessionData.OnLeaving) : quitter ne protège pas ses familiers.
--   - Défense : une bulle [E] "Reprendre" est posée sur le voleur ; seule la victime la voit (attribut "CarryingFrom"
--     = UserId de la victime, lu par client/PetFollow, qui entoure aussi le voleur de rouge chez elle). Si elle la
--     valide assez près (vérifié ici), le familier rentre chez elle. Elle peut aussi le frapper pour qu'il le lâche.
--   - Annonces (Remotes.StealNotice) : le propriétaire est prévenu au début et à la fin d'un vol ; tout le serveur
--     apprend les vols (et les familiers jetés au trou) de rareté >= Config.Loot.AnnounceMinRarity.
--
-- Anti-duplication : pendant le transport (et quand il rentre à pied), le familier reste au propriétaire (simplement
-- "réservé", caché de sa base). Transfert et sacrifice se font en UNE étape serveur sans attente, seulement si les
-- sauvegardes sont chargées (verrou de session tenu), puis les profils sont sauvegardés (propriétaire d'abord).
-- Chaque réservation (BasePetsController.Reserve +1) est rendue exactement une fois : à la fin d'un transport qui ne
-- lâche pas le familier, ou à la fin de son retour à pied (arrivé, ou propriétaire parti).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetPath = require(ReplicatedStorage.Shared.PetPath)
local PetSizes = require(ReplicatedStorage.Shared.PetSizes)
local PetWander = require(ReplicatedStorage.Shared.PetWander)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local BasePetsController = require(script.Parent.BasePetsController)
local BlackholeTiers = require(script.Parent.BlackholeTiers)
local GameLoopManager = require(script.Parent.GameLoopManager)
local ItemInteraction = require(script.Parent.ItemInteraction)
local PowerController = require(script.Parent.PowerController)
local BadgeController = require(script.Parent.BadgeController)
local Quests = require(script.Parent.Quests)
local SessionData = require(script.Parent.SessionData)

local StealController = {}

local STEAL = Config.Steal
local CARRY = Config.Carry
local SACRIFICE = Config.Sacrifice

-- Résultat envoyé au porteur (Remotes.StealResult) :
--   "Success" (volé), "Home" (son familier reposé chez lui), "Sacrificed" (jeté dans le trou), "Dropped" (lâché),
--   "Timeout" (trop lent, lâché), "VictimLeft", "Gone" (le propriétaire ne l'a plus), "Recovered" (repris par la victime).
export type Outcome = "Success" | "Home" | "Sacrificed" | "Dropped" | "Timeout" | "VictimLeft" | "Gone" | "Recovered"

-- Ce que le propriétaire apprend à la fin d'un vol (Remotes.StealNotice) ; nil = rien à lui dire.
local VICTIM_NOTICE: { [string]: string } = {
	Success = "Stolen",
	Recovered = "Recovered",
	Dropped = "Dropped",
	Timeout = "Dropped",
	Sacrificed = "Sacrificed",
}

type Carry = {
	carrier: Player,
	owner: Player, -- celui dont la sauvegarde contient le familier
	ownerBase: Model, -- là où il rentre s'il est lâché
	petId: string,
	own: boolean, -- le porteur est le propriétaire
	deadline: number, -- heure serveur limite
	lastPosition: Vector3, -- dernière position connue du porteur (pour le lâcher même s'il disparaît)
	wasOutside: boolean, -- sorti de sa base depuis le début (on prend son propre familier DANS sa base)
	prompt: ProximityPrompt?, -- bulle "Reprendre" posée sur le voleur
}

type Loose = {
	anchor: Part,
	owner: Player,
	ownerBase: Model,
	petId: string,
	points: { Vector3 },
	start: number,
}

local carries: { [Player]: Carry } = {} -- porteur -> transport en cours
local looses: { [Part]: Loose } = {} -- familiers lâchés qui rentrent à pied
local leaving: { [Player]: boolean } = {} -- joueurs en train de quitter le serveur
local looseFolder: Folder

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

local function present(player: Player): boolean
	return player.Parent ~= nil and not leaving[player]
end

local function rarityIndex(petId: string): number
	local entry = PetCatalog.ById[petId]
	return if entry then Config.RarityIndex[entry.Rarity] or 1 else 1
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

-- Vitesse du porteur (x sa vitesse normale) : selon la rareté du familier, et jamais plus vite que le propriétaire
-- (Config.Carry.SpeedByRarity x min(1, vitesse du propriétaire / vitesse du porteur)).
function StealController.CarrySpeed(player: Player, petId: string, owner: Player?): number
	local entry = PetCatalog.ById[petId]
	local rarity = if entry then Config.RarityIndex[entry.Rarity] or 1 else 1
	local speed = math.clamp(CARRY.SpeedByRarity[rarity] or CARRY.MaxSpeed, CARRY.MinSpeed, CARRY.MaxSpeed)
	if owner and owner ~= player then
		local mine, theirs = player:GetAttribute("Speed"), owner:GetAttribute("Speed")
		if type(mine) == "number" and type(theirs) == "number" and mine > 0 then
			speed *= math.min(1, theirs / mine)
		end
	end
	return speed
end

----------------------------------------------------------------------
-- Familiers lâchés qui rentrent à pied
----------------------------------------------------------------------

local function homeOf(base: Model): Vector3?
	local platform = base:FindFirstChild("BasePart")
	if platform and platform:IsA("BasePart") then
		return PetWander.groundOf(platform).Position
	end
	return nil
end

-- Fin du retour à pied (arrivé, ou propriétaire parti) : la réservation est rendue.
local function endLoose(loose: Loose, arrived: boolean)
	if looses[loose.anchor] ~= loose then
		return
	end
	looses[loose.anchor] = nil
	loose.anchor:Destroy()
	BasePetsController.Reserve(loose.ownerBase, loose.petId, -1)
	if arrived and present(loose.owner) then
		Remotes.StealNotice:FireClient(loose.owner, "Returned", "", loose.owner.DisplayName, loose.petId)
	end
end

-- Le familier tombe par terre à `position` et part vers la base de son propriétaire (la réservation reste).
local function dropLoose(carry: Carry, position: Vector3)
	local home = homeOf(carry.ownerBase)
	if not home or not present(carry.owner) then
		BasePetsController.Reserve(carry.ownerBase, carry.petId, -1)
		return
	end
	local ground = Vector3.new(position.X, 0, position.Z)
	local points = PetPath.build(ground, home)
	local anchor = Instance.new("Part")
	anchor.Name = carry.petId
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.CFrame = CFrame.new(ground)
	anchor:SetAttribute("PetId", carry.petId)
	anchor:SetAttribute("OwnerUserId", carry.owner.UserId)
	anchor:SetAttribute("OwnerName", carry.owner.DisplayName)
	anchor:SetAttribute("Path", PetPath.encode(points))
	anchor:SetAttribute("PathStart", now())
	anchor:SetAttribute("PathSpeed", CARRY.WalkHomeSpeed)
	anchor.Parent = looseFolder
	looses[anchor] = {
		anchor = anchor,
		owner = carry.owner,
		ownerBase = carry.ownerBase,
		petId = carry.petId,
		points = points,
		start = now(),
	}
end

local function loosePosition(loose: Loose): (Vector3, boolean)
	local position, _, done = PetPath.at(loose.points, (now() - loose.start) * CARRY.WalkHomeSpeed)
	return position, done
end

----------------------------------------------------------------------
-- Transport
----------------------------------------------------------------------

-- Récompense d'un familier jeté dans le trou noir : argent, points du tour, jauge commune.
function StealController.SacrificeReward(carrier: Player, petId: string): (number, number)
	local world = Config.GetWorld(SessionData.GetTier(carrier))
	local money = math.floor(
		PetCatalog.GetIncome(petId) * SACRIFICE.IncomeSeconds * world.IncomeMultiplier * Perks.MoneyMultiplier(carrier)
	)
	local points = SACRIFICE.Points[rarityIndex(petId)] or SACRIFICE.Points[1]
	return money, points
end

-- Fin du transport : le porteur retrouve sa vitesse et ses mains ; selon l'issue, le familier change de propriétaire,
-- est perdu dans le trou, rentre chez lui (réservation rendue) ou tombe par terre et rentre à pied (réservation gardée).
local function finish(carry: Carry, outcome: Outcome)
	if carries[carry.carrier] ~= carry then
		return -- déjà terminé
	end
	carries[carry.carrier] = nil

	local carrier = carry.carrier
	local owner = carry.owner
	local transfer = outcome == "Success" or outcome == "VictimLeft"
	local money, points = 0, 0
	if transfer or outcome == "Sacrificed" then
		-- Une seule étape, sans aucune attente entre le retrait et l'ajout.
		local ok = SessionData.IsLoaded(owner)
			and SessionData.IsLoaded(carrier)
			and SessionData.RemovePets(owner, { [carry.petId] = 1 })
		if not ok then
			outcome = "Gone" -- le propriétaire ne l'a plus (fusion, équipement...) ou une sauvegarde n'est pas chargée
		elseif transfer then
			SessionData.AddPets(carrier, { [carry.petId] = 1 })
			Quests.Add(carrier, "Steal", 1)
			BadgeController.Award(carrier, "FirstSteal")
			BasePetsController.Celebrate(carrier, { carry.petId })
		else
			money, points = StealController.SacrificeReward(carrier, carry.petId)
			SessionData.AddMoney(carrier, money)
			SessionData.AddScore(carrier, points)
			BlackholeTiers.AddGauge(carrier, points)
			local root = getRoot(carrier)
			Remotes.HoleEvent:FireAllClients("Sacrifice", if root then root.Position else carry.lastPosition,
				carry.petId, carrier, money)
		end
	end
	local gone = outcome == "Gone"

	if outcome == "Dropped" or outcome == "Timeout" then
		dropLoose(carry, carry.lastPosition)
	else
		BasePetsController.Reserve(carry.ownerBase, carry.petId, -1)
	end
	if carry.prompt then
		carry.prompt:Destroy()
	end

	if carrier.Parent then
		carrier:SetAttribute("CarryingPet", nil)
		carrier:SetAttribute("CarryingUntil", nil)
		carrier:SetAttribute("CarryingFrom", nil)
		carrier:SetAttribute("CarryingOwn", nil)
		carrier:SetAttribute("SpeedMultiplier", nil)
		SessionData.RefreshSpeed(carrier)
		Remotes.StealResult:FireClient(carrier, outcome, carry.petId, money, points)
	end
	local notice = if carry.own then nil else VICTIM_NOTICE[outcome]
	if notice and present(owner) then
		Remotes.StealNotice:FireClient(owner, notice, carrier.DisplayName, owner.DisplayName, carry.petId)
	end
	local lost = (transfer or outcome == "Sacrificed") and not gone
	if lost and not carry.own and rarityIndex(carry.petId) >= Config.Loot.AnnounceMinRarity then
		Remotes.StealNotice:FireAllClients(if transfer then "Announce" else "AnnounceSacrifice", carrier.DisplayName,
			owner.DisplayName, carry.petId)
	end
	print(string.format("[Steal] %s -> %s : %s (%s)", owner.Name, carrier.Name, carry.petId, outcome))

	if lost then
		-- Les profils sont écrits tout de suite : le propriétaire d'abord (si le serveur plantait entre les deux,
		-- le familier serait perdu par le voleur, jamais dupliqué).
		task.spawn(function()
			SessionData.Save(owner)
			if carrier ~= owner then
				SessionData.Save(carrier)
			end
		end)
	end
end

-- La victime valide la bulle "Reprendre" posée sur le voleur : vérifiée ici (bon joueur, vivant, assez près).
local function tryRecover(carry: Carry, player: Player)
	if carries[carry.carrier] ~= carry or player ~= carry.owner or not isAlive(player) then
		return
	end
	local victimRoot = getRoot(player)
	local thiefRoot = getRoot(carry.carrier)
	if not victimRoot or not thiefRoot then
		return
	end
	if (victimRoot.Position - thiefRoot.Position).Magnitude > STEAL.RecoverMaxDistance then
		return
	end
	finish(carry, "Recovered")
end

-- Le joueur peut-il prendre un familier maintenant ? (mains libres, vivant, a une base)
local function canCarry(player: Player): boolean
	if carries[player] or leaving[player] or player:GetAttribute("InDuel") or not BaseManager.GetBase(player) or not isAlive(player) then
		return false
	end
	-- Arme en main : les mains sont prises (server/WeaponController).
	return not (player.Character and player.Character:FindFirstChildOfClass("Tool"))
end

-- Commence le transport (la réservation du familier est déjà faite).
local function beginCarry(carrier: Player, owner: Player, ownerBase: Model, petId: string)
	if carrier ~= owner then SessionData.EndNewcomerProtection(carrier) end
	local own = carrier == owner
	local speed = StealController.CarrySpeed(carrier, petId, owner)
	local root = getRoot(carrier)
	local deadline = now() + math.min(STEAL.MaxCarryTime / speed, CARRY.MaxCarryTime)
	local carry: Carry = {
		carrier = carrier,
		owner = owner,
		ownerBase = ownerBase,
		petId = petId,
		own = own,
		deadline = deadline,
		lastPosition = if root then root.Position else Vector3.zero,
		wasOutside = false,
		prompt = nil,
	}
	-- Les mains doivent être libres : on lâche les objets portés AVANT d'enregistrer le transport
	-- (ReleaseHeld déclenche HeldReleased, qui le ferait sinon échouer tout de suite).
	ItemInteraction.ReleaseHeld(carrier)
	PowerController.Reveal(carrier) -- porter brise l'invisibilité : on s'approche en douce, mais on repart à découvert
	carries[carrier] = carry
	-- CarryingPet en dernier : les clients qui réagissent à son changement lisent déjà les autres attributs.
	carrier:SetAttribute("CarryingUntil", deadline)
	carrier:SetAttribute("CarryingOwn", own)
	carrier:SetAttribute("CarryingFrom", if own then nil else owner.UserId) -- la victime seule voit "Reprendre"
	carrier:SetAttribute("SpeedMultiplier", speed)
	carrier:SetAttribute("CarryingPet", petId)
	SessionData.RefreshSpeed(carrier)

	if not own and root then
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
		Remotes.StealNotice:FireClient(owner, "Started", carrier.DisplayName, owner.DisplayName, petId)
	end
	print(string.format("[Steal] %s porte %s (à %s, vitesse x%.2f)", carrier.Name, petId, owner.Name, speed))
end

-- Un joueur valide [E] sur un familier de base : toutes les vérifications sont faites ici.
local function tryStart(anchor: BasePart, player: Player)
	if not canCarry(player) then
		return
	end
	local base = BasePetsController.GetBaseOf(anchor)
	local owner = base and BaseManager.GetOwner(base)
	local petId = anchor:GetAttribute("PetId")
	if not base or not owner or type(petId) ~= "string" then
		return
	end
	if owner ~= player then
		if SessionData.IsNewcomerProtected(owner) then return end
		if STEAL.OnlyDuringDigesting and GameLoopManager.GetState() ~= "Digesting" then
			return
		end
		if base:GetAttribute("Locked") == true then
			return
		end
	end
	-- Les sauvegardes doivent être chargées, sinon le transfert ne serait pas enregistré (risque de copie).
	if not SessionData.IsLoaded(owner) or not SessionData.IsLoaded(player) then
		return
	end
	-- Un exemplaire non équipé et pas déjà porté.
	if SessionData.GetSpareCount(owner, petId) - BasePetsController.GetReserved(base, petId) < 1 then
		return
	end
	-- Distance réelle (position officielle du familier, côté serveur), avec une marge pour la latence.
	local root = getRoot(player)
	local petPosition = BasePetsController.GetPetPosition(anchor)
	if not root or not petPosition then
		return
	end
	local offset = root.Position - petPosition
	local entry = PetCatalog.ById[petId]
	if Vector2.new(offset.X, offset.Z).Magnitude > STEAL.MaxDistance + PetSizes.Radius(petId, entry and entry.Rarity) then
		return
	end
	BasePetsController.Reserve(base, petId, 1)
	beginCarry(player, owner, base, petId)
end

-- Un joueur ramasse un familier lâché qui rentrait chez lui (le propriétaire le reprend, un autre le vole).
local function tryPickLoose(player: Player, anchor: unknown)
	if typeof(anchor) ~= "Instance" or not anchor:IsA("Part") then
		return
	end
	local loose = looses[anchor]
	if not loose or not canCarry(player) or not present(loose.owner) then
		return
	end
	if not SessionData.IsLoaded(loose.owner) or not SessionData.IsLoaded(player) then
		return
	end
	if player ~= loose.owner and SessionData.IsNewcomerProtected(loose.owner) then return end
	local root = getRoot(player)
	if not root then
		return
	end
	local offset = root.Position - loosePosition(loose)
	local entry = PetCatalog.ById[loose.petId]
	if Vector2.new(offset.X, offset.Z).Magnitude > STEAL.MaxDistance + PetSizes.Radius(loose.petId, entry and entry.Rarity) then
		return
	end
	-- Il passe du sol aux mains du joueur : la réservation dans sa base reste la même.
	looses[anchor] = nil
	anchor:Destroy()
	beginCarry(player, loose.owner, loose.ownerBase, loose.petId)
end

-- Le porteur demande à jeter son familier dans le trou noir (Feeding, assez près du bord).
local function tryThrow(player: Player)
	local carry = carries[player]
	local root = getRoot(player)
	if not carry or not root or not isAlive(player) or GameLoopManager.GetState() ~= "Feeding" then
		return
	end
	local distance = Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude
	if distance > Config.Arena.HoleRadius + SACRIFICE.Range then
		return
	end
	finish(carry, "Sacrificed")
end

-- Vérifié plusieurs fois par seconde : arrivée dans une base, temps écoulé, familiers qui rentrent à pied.
local function update()
	local time = now()
	for carrier, carry in pairs(carries) do
		local root = getRoot(carrier)
		if root then
			carry.lastPosition = root.Position
		end
		if not carry.own and not carry.owner.Parent then
			finish(carry, "VictimLeft")
		elseif time >= carry.deadline then
			finish(carry, "Timeout")
		elseif root then
			local carrierBase = BaseManager.GetBase(carrier)
			local inside = carrierBase ~= nil and isInsideBase(carrierBase, root.Position)
			if not inside then
				carry.wasOutside = true
			elseif carry.wasOutside then
				finish(carry, if carry.own then "Home" else "Success")
			end
		end
	end
	for _, loose in pairs(looses) do
		local _, done = loosePosition(loose)
		if done then
			endLoose(loose, true)
		end
	end
end

-- Le joueur quitte le serveur : ce qu'il portait tombe (ou disparaît si c'était le sien), ses familiers lâchés
-- disparaissent (ils sont toujours dans sa sauvegarde). Appelé par PlayerRemoving ET SessionData.OnLeaving
-- (l'ordre entre les deux n'est pas garanti) : chaque étape ne se fait qu'une fois.
local function onLeaving(player: Player)
	leaving[player] = true
	-- Les voleurs gagnent ses familiers en cours de vol, avant sa dernière sauvegarde.
	for _, carry in pairs(carries) do
		if carry.owner == player and not carry.own then
			finish(carry, "VictimLeft")
		end
	end
	local carry = carries[player]
	if carry then
		finish(carry, "Dropped")
	end
	for _, loose in pairs(looses) do
		if loose.owner == player then
			endLoose(loose, false)
		end
	end
	task.delay(10, function()
		leaving[player] = nil
	end)
end

function StealController.Init()
	local map = Workspace:WaitForChild("Map")
	local folder = Instance.new("Folder")
	folder.Name = "LoosePets"
	folder.Parent = map
	looseFolder = folder

	BasePetsController.PetTriggered:Connect(tryStart)
	Remotes.PickLoosePet.OnServerEvent:Connect(tryPickLoose)
	Remotes.ThrowPet.OnServerEvent:Connect(tryThrow)

	-- Frappé, KO du dôme, mort, réapparition, départ du porteur : il lâche le familier, qui rentre à pied.
	ItemInteraction.HeldReleased:Connect(function(player: Player)
		local carry = carries[player]
		if carry then
			finish(carry, "Dropped")
		end
	end)

	SessionData.OnLeaving(onLeaving)
	Players.PlayerRemoving:Connect(onLeaving)

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
