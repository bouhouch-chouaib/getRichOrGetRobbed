--!strict
-- Quests : quêtes du jour (Config.Quests). Chaque jour (UTC), 3 quêtes de sortes différentes, tirées au hasard mais
-- toujours les mêmes pour un joueur donné ce jour-là : une facile, une moyenne, une difficile. Les autres modules
-- signalent ce que fait le joueur avec Quests.Add(joueur, sorte, quantité) :
--   "Feed" objet avalé par le trou noir (BlackholeController), "Pulls" tirages gagnés (PullRewards),
--   "Hatch" œufs éclos (EggController), "Train" niveaux d'entraînement (TrainingController),
--   "Upgrade" amélioration achetée (EconomyController), "Steal" familier volé (StealController).
-- La récompense se réclame dans la fenêtre Bonus (server/ProgressionController). Ce module ne dépend que de SessionData :
-- n'importe quel module peut l'appeler sans boucle de require.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SessionData = require(script.Parent.SessionData)

local Quests = {}

function Quests.Today(): number
	return math.floor(os.time() / 86400)
end

-- Les 3 quêtes du jour d'un joueur (sans état : même joueur + même jour = mêmes quêtes).
function Quests.Generate(userId: number, day: number): { SessionData.Quest }
	local rng = Random.new(userId * 7919 + day * 104729)
	local pool = table.clone(Config.Quests.Pool)
	for index = #pool, 2, -1 do
		local other = rng:NextInteger(1, index)
		pool[index], pool[other] = pool[other], pool[index]
	end
	local list: { SessionData.Quest } = {}
	for difficulty = 1, math.min(Config.Quests.PerDay, #pool) do
		local def = pool[difficulty]
		table.insert(list, { id = def.Id, goal = def.Goals[math.min(difficulty, #def.Goals)], progress = 0, claimed = false })
	end
	return list
end

-- Refait les quêtes si on a changé de jour. Retourne true si elles ont changé.
function Quests.Ensure(player: Player): boolean
	local data = SessionData.Get(player)
	if not data or not data.loaded then
		return false
	end
	local today = Quests.Today()
	if data.quests.day == today and #data.quests.list > 0 then
		return false
	end
	data.quests = { day = today, list = Quests.Generate(player.UserId, today) }
	return true
end

function Quests.Add(player: Player, kind: string, amount: number)
	if amount <= 0 then
		return
	end
	local data = SessionData.Get(player)
	if not data or not data.loaded then
		return
	end
	local changed = Quests.Ensure(player)
	for _, quest in ipairs(data.quests.list) do
		if quest.id == kind and quest.progress < quest.goal then
			quest.progress = math.min(quest.goal, quest.progress + math.floor(amount))
			changed = true
		end
	end
	if changed then
		SessionData.Sync(player)
	end
end

return Quests
