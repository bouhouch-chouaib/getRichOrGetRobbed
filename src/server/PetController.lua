--!strict
-- PetController : équiper / déséquiper des familiers (validé par SessionData côté serveur).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PetCatalog = require(ReplicatedStorage.Shared.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SessionData = require(script.Parent.SessionData)

local PetController = {}

function PetController.Init()
	Remotes.EquipPet.OnServerEvent:Connect(function(player: Player, petId: unknown, equip: unknown)
		if type(petId) ~= "string" or not PetCatalog.ById[petId] then
			return
		end
		if equip == true then
			SessionData.Equip(player, petId)
		else
			SessionData.Unequip(player, petId)
		end
	end)

	-- Index : récompense d'un familier découvert (ou de tous ceux qui attendent si petId = nil).
	local lastClaim: { [Player]: number } = {}
	Remotes.ClaimIndex.OnServerEvent:Connect(function(player: Player, petId: unknown)
		local now = os.clock()
		if now - (lastClaim[player] or 0) < 0.3 then
			return
		end
		lastClaim[player] = now
		local total, count = 0, 0
		if type(petId) == "string" then
			total = SessionData.ClaimIndex(player, petId)
			count = if total > 0 then 1 else 0
		elseif petId == nil then
			-- Tout réclamer : les espèces et leurs formes évoluées (capsule d'évolution).
			for _, entry in ipairs(PetCatalog.Everything) do
				local reward = SessionData.ClaimIndex(player, entry.Id)
				if reward > 0 then
					total += reward
					count += 1
				end
			end
		end
		if count > 0 then
			Remotes.IndexClaimed:FireClient(player, total, count)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastClaim[player] = nil
	end)

	if RunService:IsStudio() and Config.StudioGiveAllPets then
		local function giveAll(player: Player)
			-- task.defer : SessionData doit avoir créé les données du joueur avant.
			task.defer(function()
				local all = {}
				for _, entry in ipairs(PetCatalog.List) do
					all[entry.Id] = 1
				end
				SessionData.AddPets(player, all)
			end)
		end
		Players.PlayerAdded:Connect(giveAll)
		for _, player in ipairs(Players:GetPlayers()) do
			giveAll(player)
		end
	end

	if RunService:IsStudio() and #Config.StudioTestPets > 0 then
		local function giveTestPets(player: Player)
			-- Petit délai : laisse le chargement de la sauvegarde se faire avant (sinon il écraserait l'équipement).
			task.delay(3, function()
				if not player.Parent then
					return
				end
				for _, petId in ipairs(Config.StudioTestPets) do
					if PetCatalog.ById[petId] then
						SessionData.AddPets(player, { [petId] = 1 })
						SessionData.Equip(player, petId)
					end
				end
			end)
		end
		Players.PlayerAdded:Connect(giveTestPets)
		for _, player in ipairs(Players:GetPlayers()) do
			giveTestPets(player)
		end
	end
end

return PetController
