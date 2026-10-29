--!strict
-- Notifications : notifications Roblox hors du jeu (Config.Notifications, shared/NotifyPlan).
-- Au départ d'un joueur, UNE notification est prévue dans un MemoryStore (clé = UserId : la nouvelle remplace
-- l'ancienne, rangée par heure d'envoi). Chaque serveur regarde chaque minute celles dont l'heure est passée, en
-- réserve une à la fois (jamais envoyée deux fois) et l'envoie par l'API Open Cloud (HttpService, clé API rangée dans
-- les Secrets du jeu). Un joueur qui revient annule la sienne. Tant qu'aucun texte n'est créé (Asset ID vides), rien
-- n'est prévu ni envoyé. Roblox ne la remet qu'aux joueurs de 13 ans et plus qui ont accepté, une par jour au plus.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local NotifyPlan = require(ReplicatedStorage.Shared.NotifyPlan)
local SessionData = require(script.Parent.SessionData)

local Notifications = {}

type Pending = { kind: string, locale: string, params: { [string]: string }, sendAt: number, claimed: string? }

local SETTINGS = Config.Notifications
local URL = "https://apis.roblox.com/cloud/v2/users/%d/notifications"
local DAY = 86400
local map: any = MemoryStoreService:GetSortedMap(if RunService:IsStudio() then "Notify_v1_studio" else "Notify_v1")

local function stringId(kind: string, locale: string): string?
	local ids = SETTINGS.Strings[kind]
	if not ids then
		return nil
	end
	local id = if locale == "fr" then ids.fr else ids.en
	return if id ~= "" then id else nil
end

function Notifications.Enabled(): boolean
	for _, ids in SETTINGS.Strings do
		if ids.fr ~= "" or ids.en ~= "" then
			return true
		end
	end
	return false
end

local function send(userId: number, pending: Pending)
	-- Texte dans la langue du joueur, sinon dans l'autre ; aucun : rien à envoyer.
	local messageId = stringId(pending.kind, pending.locale) or stringId(pending.kind, if pending.locale == "fr" then "en" else "fr")
	if not messageId then
		return
	end
	local payload: { [string]: any } = { message_id = messageId, type = "MOMENT" }
	if next(pending.params) then
		local parameters = {}
		for name, value in pending.params do
			parameters[name] = { string_value = value }
		end
		payload.parameters = parameters
	end
	local ok, result = pcall(function()
		return HttpService:RequestAsync({
			Url = string.format(URL, userId),
			Method = "POST",
			Headers = { ["x-api-key"] = HttpService:GetSecret(SETTINGS.Secret), ["Content-Type"] = "application/json" } :: any,
			Body = HttpService:JSONEncode({
				source = { universe = "universes/" .. game.GameId },
				payload = payload,
				join_experience = { launch_data = "notify_" .. pending.kind },
				analytics_data = { category = pending.kind },
			}),
		})
	end)
	if not ok then
		warn(string.format("[Notifications] Envoi impossible pour %d : %s", userId, tostring(result)))
	elseif not result.Success then
		-- Refusée par Roblox (joueur sans accord, limite du jour, texte modéré...) : on n'insiste pas.
		warn(string.format("[Notifications] %d : %d %s", userId, result.StatusCode, string.sub(result.Body, 1, 200)))
	else
		print(string.format("[Notifications] %s envoyée à %d", pending.kind, userId))
	end
end

-- Au départ (SessionData.OnLeaving, sans attendre) : prévoit la notification du joueur.
local function schedule(player: Player)
	local data = SessionData.Get(player)
	if not data or not data.loaded then
		return
	end
	local now = os.time()
	local plan = NotifyPlan.Plan(data.eggs :: any, data.daily, now) -- NotifyPlan ne lit que readyAt et evolve
	if not plan then
		return
	end
	local okLocale, locale = pcall(function()
		return player.LocaleId
	end)
	local value: Pending = {
		kind = plan.kind,
		locale = if okLocale and string.sub(string.lower(locale), 1, 2) == "fr" then "fr" else "en",
		params = plan.params,
		sendAt = plan.sendAt,
	}
	local key = tostring(player.UserId)
	task.spawn(function()
		local ok, err = pcall(function()
			map:SetAsync(key, value, math.max(plan.sendAt - now, 0) + DAY, plan.sendAt)
		end)
		if not ok then
			warn("[Notifications] Impossible de prévoir la notification de " .. key .. " : " .. tostring(err))
		end
	end)
end

-- Le joueur est revenu : sa notification ne sert plus. Une 2e fois un peu plus tard, au cas où le serveur qu'il vient
-- de quitter l'aurait prévue après son arrivée ici.
local function cancel(player: Player)
	local key = tostring(player.UserId)
	for _, delay in { 0, 30 } do
		task.delay(delay, function()
			pcall(function()
				map:RemoveAsync(key)
			end)
		end)
	end
end

-- Envoie les notifications dont l'heure est passée (au plus 20 par tour).
local function poll()
	local ok, items = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, 20, nil, { sortKey = os.time() })
	end)
	if not ok or type(items) ~= "table" then
		return
	end
	for _, item in items do
		local key = item.key
		local userId = tonumber(key)
		if userId then
			if Players:GetPlayerByUserId(userId) then
				pcall(function()
					map:RemoveAsync(key)
				end)
			else
				-- Réservation : un seul serveur l'envoie (une notification réservée disparaît d'elle-même en 5 min).
				local claimed: Pending? = nil
				pcall(function()
					map:UpdateAsync(key, function(old: any, sortKey: any)
						if type(old) ~= "table" or old.claimed then
							return nil
						end
						old.claimed = game.JobId
						claimed = old
						return old, sortKey
					end, 300)
				end)
				if claimed then
					send(userId, claimed)
					pcall(function()
						map:RemoveAsync(key)
					end)
				end
			end
		end
	end
end

function Notifications.Init()
	if not Notifications.Enabled() then
		return -- textes pas encore créés (Config.Notifications.Strings)
	end
	SessionData.OnLeaving(schedule)
	Players.PlayerAdded:Connect(cancel)
	for _, player in Players:GetPlayers() do
		cancel(player)
	end
	task.spawn(function()
		task.wait(math.random() * SETTINGS.PollSeconds) -- les serveurs ne regardent pas tous en même temps
		while true do
			poll()
			task.wait(SETTINGS.PollSeconds)
		end
	end)
end

return Notifications
