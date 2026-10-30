--!strict
-- NextGoals : les objectifs entamés montrés dans la pile du HUD (ECONOMY_REPORT.md règle 12, client/NextGoals).
-- Calcul pur (testé par tools/check-steal-rules.luau) : à partir de l'état du joueur, la liste des objectifs avec leur
-- avancée (0 à 1) et le temps qu'il reste (secondes), puis les deux à montrer : celui qui arrivera le plus tôt, et le
-- plus avancé des autres. On se souvient mieux d'une tâche commencée que d'une tâche pas encore lancée : une barre à 70 %
-- retient plus qu'un prix affiché.

local Config = require(script.Parent.Config)
local TextFormat = require(script.Parent.TextFormat)

local NextGoals = {}

export type Goal = { id: string, label: string, progress: number?, eta: number? }
export type State = {
	money: number,
	income: number, -- $/s
	tier: number, -- monde le plus loin atteint
	rebirths: number,
	pity: number, -- tirages depuis la dernière rareté visée (Config.Loot.PityPercentile)
	pityAt: number, -- 0 = rien à garantir
	pityTarget: number,
	pullsPerRound: number, -- tirages de la dernière manche
	capsuleWait: number?, -- secondes avant la prochaine tentative de la capsule (nil = rien en cours)
	discovered: number,
	totalPets: number,
	cappedName: string?, -- le familier bridé qui rapporterait le plus (Config.PowerCap)
	cappedSelfBest: number?, -- meilleure rareté obtenue soi-même
	cappedUnlock: number?, -- rareté à obtenir soi-même pour le libérer
}

local ROUND = Config.Durations.Feeding + Config.Durations.Digesting

function NextGoals.List(state: State): { Goal }
	local goals: { Goal } = {}
	-- Prochain monde, ou le Rebirth (dernier monde, ou monde suivant qui demande plus de Rebirths : Config.Worlds[].Rebirths).
	local nextWorld = Config.Worlds[state.tier + 1]
	local price, label
	if nextWorld and state.rebirths >= Config.GetWorldRebirths(nextWorld) then
		price, label = nextWorld.Price, "MONDE " .. TextFormat.upper(nextWorld.Name)
	elseif state.tier >= Config.Rebirth.RequiredTier then
		price, label = Config.GetRebirthPrice(state.rebirths), "REBIRTH " .. (state.rebirths + 1)
	end
	if price and price > 0 then
		local missing = math.max(0, price - state.money)
		table.insert(goals, {
			id = "world",
			label = label,
			progress = math.clamp(state.money / price, 0, 1),
			eta = if state.income > 0 then missing / state.income else nil,
		})
	end
	-- Pitié par palier : la rareté juste au-dessus de la meilleure.
	local rarity = Config.Rarities[state.pityTarget]
	if rarity and state.pityAt > 0 then
		local left = math.max(1, state.pityAt - state.pity)
		table.insert(goals, {
			id = "pity",
			label = TextFormat.upper(rarity.Name) .. " SÛR DANS " .. left .. " ŒUF" .. (if left > 1 then "S" else ""),
			progress = math.clamp(state.pity / state.pityAt, 0, 1),
			eta = if state.pullsPerRound > 0 then math.ceil(left / state.pullsPerRound) * ROUND else nil,
		})
	end
	-- Capsule d'évolution : la prochaine tentative.
	if state.capsuleWait and state.capsuleWait > 0 then
		table.insert(goals, { id = "capsule", label = "CAPSULE : PROCHAIN ESSAI", eta = state.capsuleWait })
	end
	-- Index.
	if state.totalPets > 0 and state.discovered < state.totalPets then
		table.insert(goals, {
			id = "index",
			label = string.format("INDEX %d / %d", state.discovered, state.totalPets),
			progress = state.discovered / state.totalPets,
		})
	end
	-- Familier bridé à libérer (Config.PowerCap).
	local unlock = if state.cappedUnlock then Config.Rarities[state.cappedUnlock] else nil
	if state.cappedName and unlock then
		table.insert(goals, {
			id = "capped",
			label = TextFormat.upper(state.cappedName) .. " EST BLOQUÉ : TROUVE UN " .. TextFormat.upper(unlock.Name),
			progress = math.clamp((state.cappedSelfBest or 0) / (state.cappedUnlock or 1), 0, 1),
		})
	end
	return goals
end

-- Les deux objectifs à montrer : le plus proche dans le temps, puis le plus avancé des autres (pas encore atteint).
function NextGoals.Pick(goals: { Goal }): { Goal }
	local soonest: Goal? = nil
	for _, goal in ipairs(goals) do
		if goal.eta and goal.eta > 0 and (not soonest or goal.eta < (soonest.eta :: number)) then
			soonest = goal
		end
	end
	local advanced: Goal? = nil
	for _, goal in ipairs(goals) do
		if goal ~= soonest and goal.progress and goal.progress < 1
			and (not advanced or goal.progress > (advanced.progress :: number)) then
			advanced = goal
		end
	end
	local picked = {}
	for _, goal in ipairs({ soonest, advanced } :: { Goal? }) do
		if goal then
			table.insert(picked, goal)
		end
	end
	if #picked < 2 then
		for _, goal in ipairs(goals) do
			if #picked < 2 and not table.find(picked, goal) then
				table.insert(picked, goal)
			end
		end
	end
	return picked
end

return NextGoals
