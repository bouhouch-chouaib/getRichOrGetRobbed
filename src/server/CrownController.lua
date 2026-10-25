--!strict
-- CrownController : la couronne du plus riche du serveur (Config.Crown, ECONOMY_REPORT.md règle 9).
--   - Toutes les Config.Crown.CheckInterval secondes, le plus gros revenu (attribut "Income", server/EconomyController)
--     prend la couronne (shared/CrownRules.Pick). Attributs : ReplicatedStorage "CrownUserId", Player "Crowned" et
--     "CrownDefenses", base "Crowned" (affichés par client/Crown). Annonce : Remotes.StealNotice "Crowned".
--   - server/StealController appelle PayBounty quand on vole le roi (prime pour le voleur) et Defended quand un voleur
--     est arrêté chez lui (récompense du roi, limitée par CrownRules.CanReward, annonce "CrownDefended").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CrownRules = require(ReplicatedStorage.Shared.CrownRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseManager = require(script.Parent.BaseManager)
local SessionData = require(script.Parent.SessionData)

local CrownController = {}

local king: Player? = nil
local defenseLog: CrownRules.DefenseLog = {}

-- Ce joueur porte-t-il la couronne ?
function CrownController.IsCrowned(player: Player): boolean
	return king == player
end

local function setKing(newKing: Player?)
	if newKing == king then
		return
	end
	local old = king
	if old then
		old:SetAttribute("Crowned", nil)
		local base = BaseManager.GetBase(old)
		if base then
			base:SetAttribute("Crowned", nil)
		end
	end
	king = newKing
	defenseLog = {}
	ReplicatedStorage:SetAttribute("CrownUserId", if newKing then newKing.UserId else nil)
	if newKing then
		newKing:SetAttribute("Crowned", true)
		newKing:SetAttribute("CrownDefenses", 0)
		local base = BaseManager.GetBase(newKing)
		if base then
			base:SetAttribute("Crowned", true)
		end
		Remotes.StealNotice:FireAllClients("Crowned", newKing.DisplayName, "", "")
		print(string.format("[Crown] %s est le roi du serveur", newKing.Name))
	end
end

local function refresh()
	local entries: { CrownRules.Entry } = {}
	local byId: { [number]: Player } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local income = player:GetAttribute("Income")
		if SessionData.IsLoaded(player) and type(income) == "number" then
			table.insert(entries, { id = player.UserId, income = income })
			byId[player.UserId] = player
		end
	end
	local id = CrownRules.Pick(entries, if king then king.UserId else nil)
	setKing(if id then byId[id] else nil)
end

-- Un voleur vient de prendre un familier au roi : prime = `bounty` (calculée par StealController, comme un sacrifice).
function CrownController.PayBounty(thief: Player, owner: Player, bounty: number): number
	if owner ~= king or bounty <= 0 then
		return 0
	end
	SessionData.AddMoney(thief, bounty)
	return bounty
end

-- Un voleur vient d'être arrêté chez le roi : `reward` pour le roi (si CrownRules.CanReward), compteur et annonce.
function CrownController.Defended(owner: Player, thief: Player, reward: number)
	if owner ~= king then
		return
	end
	local defenses = owner:GetAttribute("CrownDefenses")
	owner:SetAttribute("CrownDefenses", (if type(defenses) == "number" then defenses else 0) + 1)
	Remotes.StealNotice:FireAllClients("CrownDefended", thief.DisplayName, owner.DisplayName, "")
	local now = Workspace:GetServerTimeNow()
	if reward > 0 and CrownRules.CanReward(defenseLog, thief.UserId, now) then
		table.insert(defenseLog, { at = now, thief = thief.UserId })
		SessionData.AddMoney(owner, reward)
	end
end

function CrownController.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		if player == king then
			setKing(nil)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Crown.CheckInterval)
			local ok, err = pcall(function(): any
				refresh()
				return nil
			end)
			if not ok then
				warn("[CrownController] " .. tostring(err))
			end
		end
	end)
end

return CrownController
