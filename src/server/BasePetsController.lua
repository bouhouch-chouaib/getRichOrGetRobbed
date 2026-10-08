--!strict
-- BasePetsController : les familiers qui se baladent dans chaque base, décidés par le SERVEUR.
-- Ce sont les Config.Pets.IncomeSlots meilleurs familiers non équipés du propriétaire (ceux qui rapportent de l'argent,
-- EconomyController.GetTopPets) : une seule créature par espèce, avec sa quantité.
-- Pour chacune, un repère invisible Base_N.Pets.<PetId> (Part ancrée) porte les attributs :
--   PetId, Count (exemplaires), Seed (variation d'animation), Walk (trajet en cours, voir shared/PetWander).
-- Le serveur ne déplace jamais ces repères : les clients calculent la position à partir de "Walk"
-- (client/BasePets) et la position officielle s'obtient avec BasePetsController.GetPetPosition.
-- Chaque repère porte la bulle [E] "Voler" (ProximityPrompt) : le client la fait suivre le familier et ne l'affiche
-- que quand le vol est possible ; la décision reste au serveur (StealController, via PetTriggered).
-- Un exemplaire en cours de vol est "réservé" (Reserve) : il n'est plus affiché dans la base de la victime.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local PetWander = require(ReplicatedStorage.Shared.PetWander)
local BaseManager = require(script.Parent.BaseManager)
local EconomyController = require(script.Parent.EconomyController)

local BasePetsController = {}

-- Déclenché (anchor: BasePart, player: Player) quand un joueur valide la bulle [E] d'un familier de base.
local petTriggered = Instance.new("BindableEvent")
BasePetsController.PetTriggered = petTriggered.Event

type PetState = {
	anchor: BasePart,
	style: PetWander.Style,
	leg: PetWander.Leg,
	nextLegAt: number, -- heure (serveur) du prochain départ
}

type BaseState = {
	base: Model,
	platform: BasePart,
	folder: Folder,
	pets: { [string]: PetState }, -- petId -> état
	reserved: { [string]: number }, -- petId -> exemplaires en cours de vol (cachés)
}

local rng = Random.new()
local states: { [Model]: BaseState } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Familiers à afficher dans la base du joueur : petId -> quantité, dans l'ordre (les meilleurs d'abord).
local function wantedPets(owner: Player?): ({ string }, { [string]: number })
	local order: { string } = {}
	local counts: { [string]: number } = {}
	if owner then
		for _, petId in ipairs(EconomyController.GetTopPets(owner)) do
			if not counts[petId] then
				table.insert(order, petId)
			end
			counts[petId] = (counts[petId] or 0) + 1
		end
	end
	return order, counts
end

local function addPet(state: BaseState, petId: string, count: number)
	local anchor = Instance.new("Part")
	anchor.Name = petId
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	local spot = PetWander.randomSpot(rng)
	anchor.CFrame = PetWander.groundOf(state.platform) * CFrame.new(spot.X, 0.5, spot.Y)
	local leg: PetWander.Leg = { from = spot, to = spot, start = now(), duration = 0 }
	anchor:SetAttribute("PetId", petId)
	anchor:SetAttribute("Count", count)
	anchor:SetAttribute("Seed", rng:NextInteger(0, 1000))
	anchor:SetAttribute("Walk", PetWander.encode(leg))

	local entry = PetCatalog.ById[petId]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Voler"
	prompt.ObjectText = if entry then entry.Name else petId
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.Steal.HoldDuration
	prompt.MaxActivationDistance = Config.Steal.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player: Player)
		petTriggered:Fire(anchor, player)
	end)

	anchor.Parent = state.folder
	state.pets[petId] = {
		anchor = anchor,
		style = PetWander.STYLES[PetWander.styleFor(petId)],
		leg = leg,
		-- Départs décalés pour que les familiers ne bougent pas tous en même temps.
		nextLegAt = now() + rng:NextNumber(0, 2),
	}
end

local function removePet(state: BaseState, petId: string)
	local pet = state.pets[petId]
	if pet then
		pet.anchor:Destroy()
		state.pets[petId] = nil
	end
end

-- Met la base à jour : ajoute / retire des espèces, change les quantités. Les familiers déjà là gardent leur place.
local function syncBase(state: BaseState)
	local order, counts = wantedPets(BaseManager.GetOwner(state.base))
	for petId, count in pairs(counts) do
		counts[petId] = count - (state.reserved[petId] or 0)
	end
	for petId in pairs(state.pets) do
		if (counts[petId] or 0) <= 0 then
			removePet(state, petId)
		end
	end
	for _, petId in ipairs(order) do
		local count = counts[petId]
		local pet = state.pets[petId]
		if count <= 0 then
			continue
		elseif not pet then
			addPet(state, petId, count)
		elseif pet.anchor:GetAttribute("Count") ~= count then
			pet.anchor:SetAttribute("Count", count)
		end
	end
end

-- La base dont ce repère fait partie (nil si ce n'est pas un repère de familier actif).
function BasePetsController.GetBaseOf(anchor: Instance): Model?
	for base, state in pairs(states) do
		local petId = anchor:GetAttribute("PetId")
		local pet = if type(petId) == "string" then state.pets[petId] else nil
		if pet and pet.anchor == anchor then
			return base
		end
	end
	return nil
end

-- Exemplaires de petId en cours de vol dans cette base.
function BasePetsController.GetReserved(base: Model, petId: string): number
	local state = states[base]
	return if state then state.reserved[petId] or 0 else 0
end

-- Réserve (+1, début de vol) ou rend (-1, fin de vol) un exemplaire. La base est mise à jour tout de suite.
function BasePetsController.Reserve(base: Model, petId: string, delta: number)
	local state = states[base]
	if not state then
		return
	end
	local count = (state.reserved[petId] or 0) + delta
	if count > 0 then
		state.reserved[petId] = count
	else
		state.reserved[petId] = nil
	end
	syncBase(state)
end

-- Donne un nouveau trajet aux familiers arrivés au bout du leur (après leur pause).
local function updateWalks()
	local time = now()
	for _, state in pairs(states) do
		for _, pet in pairs(state.pets) do
			if time >= pet.nextLegAt then
				local from = PetWander.positionAt(pet.leg, time)
				local to = PetWander.randomSpot(rng)
				local duration = (to - from).Magnitude / pet.style.speed
				pet.leg = { from = from, to = to, start = time, duration = duration }
				pet.nextLegAt = time + duration + rng:NextNumber(pet.style.minWait, pet.style.maxWait)
				pet.anchor:SetAttribute("Walk", PetWander.encode(pet.leg))
			end
		end
	end
end

-- Position officielle (monde) d'un familier de base, au niveau du sol. nil si ce n'est pas un repère de familier.
function BasePetsController.GetPetPosition(anchor: Instance): Vector3?
	for _, state in pairs(states) do
		local petId = anchor:GetAttribute("PetId")
		local pet = if type(petId) == "string" then state.pets[petId] else nil
		if pet and pet.anchor == anchor then
			local spot = PetWander.positionAt(pet.leg, now())
			return (PetWander.groundOf(state.platform) * CFrame.new(spot.X, 0, spot.Y)).Position
		end
	end
	return nil
end

function BasePetsController.Init(bases: { Model })
	for _, base in ipairs(bases) do
		local platform = base:FindFirstChild("BasePart")
		if platform and platform:IsA("BasePart") then
			local folder = Instance.new("Folder")
			folder.Name = "Pets"
			folder.Parent = base
			states[base] = { base = base, platform = platform, folder = folder, pets = {}, reserved = {} }
		else
			warn("[BasePets] " .. base.Name .. " n'a pas de plateforme : pas de familiers dans cette base.")
		end
	end

	-- Composition des bases : chaque seconde (achats, tirages, fusions, équipement, départs).
	task.spawn(function()
		while true do
			for _, state in pairs(states) do
				syncBase(state)
			end
			task.wait(1)
		end
	end)

	-- Trajets : vérifiés 10 fois par seconde (un attribut n'est écrit qu'au début d'un nouveau trajet).
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			updateWalks()
		end
	end)
end

return BasePetsController
