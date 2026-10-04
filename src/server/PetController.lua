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
end

return PetController
