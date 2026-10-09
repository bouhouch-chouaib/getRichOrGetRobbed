--!strict
-- TrainingController : stations d'entraînement de chaque base (achetées en boutique).
--   Tapis de course (Upgrade "Treadmill") -> XP de Vitesse ; le tapis roule et repousse le joueur.
--   Banc de muscu  (Upgrade "Bench")     -> XP de Force (puissance de lancer).
-- La station est cachée tant que le propriétaire de la base ne l'a pas achetée. Son niveau (1 à 5)
-- change sa matière (bois -> diamant) et multiplie l'XP gagnée (Config.Training.StationRates).
-- Seul le propriétaire de la base peut s'entraîner sur ses stations, à tout moment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TextFormat = require(ReplicatedStorage.Shared.TextFormat)
local BaseManager = require(script.Parent.BaseManager)
local SessionData = require(script.Parent.SessionData)

local TrainingController = {}

local TICK = 0.25

type StationKind = { model: string, upgrade: string, stat: SessionData.Stat, title: string }

local KINDS: { StationKind } = {
	{ model = "Treadmill", upgrade = "Treadmill", stat = "Speed", title = "TAPIS DE COURSE" },
	{ model = "Bench", upgrade = "Bench", stat = "Strength", title = "BANC DE MUSCU" },
}

type Station = {
	base: Model,
	kind: StationKind,
	model: Model,
	zone: BasePart,
	label: TextLabel?,
	sign: BillboardGui?,
	shownLevel: number, -- niveau actuellement affiché (0 = caché)
}

local stations: { Station } = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isOnZone(root: BasePart, zone: BasePart): boolean
	local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z and localPosition.Y > -1 and localPosition.Y < 8
end

-- Affiche / cache la station et applique la matière de son niveau.
local function render(station: Station, level: number)
	if station.shownLevel == level then
		return
	end
	station.shownLevel = level
	local visible = level > 0
	local look = Config.Training.StationMaterials[math.clamp(level, 1, #Config.Training.StationMaterials)]
	for _, part in ipairs(station.model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = if visible then 0 else 1
			part.CanCollide = visible
			part.CanQuery = visible
			if part:GetAttribute("Tint") then
				part.Color = look.Color
				part.Material = look.Material
			end
		end
	end
	if station.sign then
		station.sign.Enabled = visible
	end
	if station.label then
		station.label.Text = string.format("%s\nNIVEAU %d • %s • XP x%s", station.kind.title, level, TextFormat.upper(look.Name), tostring(Config.Training.StationRates[level] or 1))
	end
	-- Le tapis roule en permanence quand il existe (convoyeur vers l'arrière de la base).
	if station.kind.model == "Treadmill" then
		station.zone.AssemblyLinearVelocity = if visible then station.zone.CFrame.LookVector * -Config.Training.BeltSpeed else Vector3.zero
	end
end

local function update()
	for _, station in ipairs(stations) do
		local owner = BaseManager.GetOwner(station.base)
		local level = if owner then SessionData.GetUpgradeLevel(owner, station.kind.upgrade) else 0
		render(station, level)

		if owner and level > 0 then
			local root = getRoot(owner)
			if root and isOnZone(root, station.zone) then
				local rate = Config.Training.StationRates[level] or 1
				SessionData.AddTrainingXP(owner, station.kind.stat, rate * TICK)
			end
		end
	end
end

function TrainingController.Init(bases: { Model })
	for _, base in ipairs(bases) do
		for _, kind in ipairs(KINDS) do
			local model = base:FindFirstChild(kind.model)
			local zone = model and model:FindFirstChild("Zone")
			if model and model:IsA("Model") and zone and zone:IsA("BasePart") then
				local sign = model:FindFirstChild("StationSign")
				local label = sign and sign:FindFirstChild("Label")
				table.insert(stations, {
					base = base,
					kind = kind,
					model = model,
					zone = zone,
					sign = if sign and sign:IsA("BillboardGui") then sign else nil,
					label = if label and label:IsA("TextLabel") then label else nil,
					shownLevel = 0,
				})
			else
				warn("[TrainingController] Station " .. kind.model .. " introuvable dans " .. base.Name)
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(TICK)
			update()
		end
	end)
end

return TrainingController
