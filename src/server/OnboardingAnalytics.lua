--!strict
-- Étapes validées côté serveur. L'analytique reste indépendante des récompenses et des sauvegardes.
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local OnboardingAnalytics = {}
local VERSION = 1
local STEPS = { "Loaded", "Pickup", "Scored", "EggReceived", "Hatched", "Upgraded", "Returned" }
local LABELS = {
	"SaveLoaded",
	"FirstItemPickedUp",
	"FirstScoredThrow",
	"FirstEggReceived",
	"FirstEggHatched",
	"FirstUpgradeBought",
	"SecondVisit",
}
local ALLOWED: { [string]: boolean } = {}
for _, key in ipairs(STEPS) do
	ALLOWED[key] = true
end

export type Progress = {
	version: number,
	newPlayer: boolean,
	visits: number,
	stage: number,
	reached: { [string]: boolean },
}
type Session = {
	joinedAt: number,
	progress: Progress?,
	pending: { [string]: number },
	dismissed: boolean,
}
local sessions: { [Player]: Session } = {}
local queue: { () -> () } = {}
local sending = false
local nextWarning = 0

local function send(action: () -> ())
	-- Les événements ne sont acceptés que dans le jeu publié, jamais dans Studio.
	if RunService:IsStudio() then
		return
	end
	if #queue >= 256 then
		return
	end
	table.insert(queue, action)
	if sending then
		return
	end
	sending = true
	task.spawn(function()
		while #queue > 0 do
			local callback = assert(table.remove(queue, 1))
			local ok, err = pcall(function(): boolean
				callback()
				return true
			end)
			if not ok and os.clock() >= nextWarning then
				nextWarning = os.clock() + 60
				warn("[OnboardingAnalytics] Événement non envoyé : " .. tostring(err))
			end
		end
		sending = false
	end)
end

local function cohort(session: Session): string
	local progress = session.progress
	if not progress then
		return "Loading"
	end
	if not progress.newPlayer then
		return "ExistingPlayer"
	end
	return if progress.visits <= 1 then "FirstVisit" else "ReturningPlayer"
end

local function fields(session: Session, detail: string): { [string]: string }
	local progress = session.progress
	return {
		CustomField01 = cohort(session),
		CustomField02 = "Step" .. tostring(if progress then progress.stage else 0),
		CustomField03 = detail,
	}
end

local function custom(player: Player, session: Session, name: string, value: number, detail: string)
	local customFields = fields(session, detail)
	send(function()
		AnalyticsService:LogCustomEvent(player, name, value, customFields)
	end)
end

function OnboardingAnalytics.Restore(saved: unknown, isNew: boolean): Progress
	local progress: Progress = { version = VERSION, newPlayer = isNew, visits = 0, stage = 0, reached = {} }
	if type(saved) ~= "table" then
		return progress
	end
	local record = saved :: { [string]: any }
	if record.version ~= VERSION then
		return progress
	end
	progress.newPlayer = record.newPlayer == true
	if type(record.visits) == "number" and record.visits == record.visits then
		progress.visits = math.clamp(math.floor(record.visits), 0, 1000000)
	end
	if type(record.reached) == "table" then
		for key in pairs(ALLOWED) do
			progress.reached[key] = record.reached[key] == true
		end
	end
	-- Ne pas faire confiance à un numéro d'étape sauvegardé sans ses preuves.
	local contiguous = 0
	while contiguous < #STEPS and progress.reached[STEPS[contiguous + 1]] do
		contiguous += 1
	end
	if type(record.stage) == "number" and record.stage == record.stage then
		progress.stage = math.clamp(math.floor(record.stage), 0, contiguous)
	end
	return progress
end

function OnboardingAnalytics.Snapshot(progress: Progress): Progress
	return {
		version = progress.version,
		newPlayer = progress.newPlayer,
		visits = progress.visits,
		stage = progress.stage,
		reached = table.clone(progress.reached),
	}
end

function OnboardingAnalytics.Joined(player: Player)
	if sessions[player] then
		return
	end
	local session: Session = { joinedAt = os.clock(), progress = nil, pending = {}, dismissed = false }
	sessions[player] = session
	custom(player, session, "SessionJoined", 1, "OnboardingV1")
end

local function flush(player: Player, session: Session)
	local progress = session.progress
	if not progress then
		return
	end
	while progress.stage < #STEPS and progress.reached[STEPS[progress.stage + 1]] do
		progress.stage += 1
		if progress.newPlayer then
			local stage = progress.stage
			local customFields = fields(session, "OnboardingV1")
			send(function()
				AnalyticsService:LogOnboardingFunnelStepEvent(player, stage, LABELS[stage], customFields)
			end)
		end
	end
	player:SetAttribute("OnboardingStage", progress.stage)
end

function OnboardingAnalytics.Mark(player: Player, key: string)
	if not ALLOWED[key] then
		return
	end
	local session = sessions[player]
	if not session then
		return
	end
	local progress = session.progress
	if not progress then
		session.pending[key] = session.pending[key] or math.max(0, os.clock() - session.joinedAt) -- conserver l’heure de l’action
		return
	end
	if progress.reached[key] then
		return
	end
	progress.reached[key] = true
	player:SetAttribute("Onboarding_" .. key, true)
	custom(
		player,
		session,
		"FirstActionSeconds",
		session.pending[key] or math.max(0, os.clock() - session.joinedAt),
		key
	)
	-- Une amélioration achetée avant l'éclosion attend son tour dans le funnel.
	-- Son événement individuel est déjà envoyé : aucune étape précédente n'est inventée.
	flush(player, session)
end

function OnboardingAnalytics.Loaded(player: Player, progress: Progress)
	OnboardingAnalytics.Joined(player)
	local session = sessions[player]
	if session.progress then
		return
	end
	session.progress = progress
	progress.visits += 1
	for key in pairs(ALLOWED) do
		player:SetAttribute("Onboarding_" .. key, progress.reached[key] == true)
	end
	player:SetAttribute("OnboardingStage", progress.stage)
	custom(player, session, "SaveLoadedSeconds", math.max(0, os.clock() - session.joinedAt), "OnboardingV1")
	OnboardingAnalytics.Mark(player, "Loaded")
	if progress.visits > 1 then
		OnboardingAnalytics.Mark(player, "Returned")
	end
	for _, key in ipairs(STEPS) do
		if session.pending[key] then
			OnboardingAnalytics.Mark(player, key)
		end
	end
	table.clear(session.pending)
	flush(player, session)
end

function OnboardingAnalytics.Dismissed(player: Player, skipped: unknown)
	local session = sessions[player]
	if not session or session.dismissed then
		return
	end
	session.dismissed = true
	-- Ce choix du client ne valide aucune étape de gameplay.
	custom(
		player,
		session,
		"TutorialDismissed",
		1,
		if skipped == true then "Skipped" elseif skipped == false then "Finished" else "Unspecified"
	)
end

function OnboardingAnalytics.Leaving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local duration = math.max(0, os.clock() - session.joinedAt)
	local bucket = if duration < 60 then "Under60s" elseif duration <= 180 then "60to180s" else "Over180s"
	custom(player, session, "SessionEndedSeconds", duration, bucket)
	sessions[player] = nil
end

return OnboardingAnalytics
