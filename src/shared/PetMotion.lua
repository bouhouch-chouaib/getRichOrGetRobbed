--!strict
-- Procedural joints use immutable local rest poses. No physics, animation assets or remotes.
local Catalog = require(script.Parent.PetCatalog)
local Motion = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
-- hinge : charnière d'une mâchoire par rapport au pivot de sa tête (genre "Jaw") ; side : -1 / 0 / 1 selon le côté du pivot.
type Joint = { kind: string, pivot: CFrame, phase: number, members: { number }, hinge: CFrame?, side: number }
export type Rig = {
	model: Model,
	parts: { BasePart },
	rest: { CFrame },
	frames: { CFrame },
	joints: { Joint },
	profile: string,
	flying: boolean,
	phase: number,
	pace: number,
	speed: number,
}
local function scaled(cf: CFrame, scale: number): CFrame
	return CF(cf.Position * scale) * cf.Rotation
end
local function phaseFor(id: string): number
	local n = 0
	for i = 1, #id do
		n = (n * 31 + string.byte(id, i)) % 65521
	end
	return n / 65521 * math.pi * 2
end
local legs: { [string]: boolean } = {
	Leg = true,
	Paw = true,
	Haunch = true,
	Claw = true,
	Shin = true,
	Talon = true,
	HindFoot = true,
	Thigh = true,
	ThighCrown = true,
	ThighKeel = true,
	ThighFront = true,
	ThighRear = true,
	Boot = true,
	Foot = true,
}
local arms: { [string]: boolean } = {
	Forearm = true,
	Fist = true,
	Shoulder = true,
	ShoulderCrown = true,
	ShoulderKeel = true,
	ShoulderFront = true,
	ShoulderRear = true,
	BroomHandle = true,
	BroomBristle = true,
}

function Motion.Prepare(m: Model, e: Catalog.Pet, family: string, center: Vector3)
	local scale = m:GetScale()
	local duck = e.Id == "CanardTractopelle"
	local cactus = e.Id == "CactusRonchon"
	local flower = e.Id == "TournesolJoyeux"
		or e.Id == "RoseCristal"
		or e.Id == "LotusEspace"
		or e.Id == "Treflant4Feuilles"
	local children = m:GetChildren()
	local anchors: { BasePart } = {}
	local ears: { BasePart } = {}
	local companions: { Vector3 } = {}
	local function raw(q: BasePart): Vector3
		return q.CFrame.Position / scale + center
	end
	for _, q in ipairs(children) do
		if q:IsA("BasePart") then
			if q.Name == "Leg" or q.Name == "Shin" or q.Name == "Thigh" then
				table.insert(anchors, q)
			end
			if q.Name == "Ear" then
				table.insert(ears, q)
			end
			if q.Name == "Asteroid" or q.Name == "CelestialTwin" then
				table.insert(companions, raw(q))
			end
		end
	end
	for index, q in ipairs(children) do
		if not q:IsA("BasePart") or q == m.PrimaryPart then
			continue
		end
		local n, pos = q.Name, raw(q)
		local stem = n == "Stem"
		local toastSlot = n == "ToastSlot"
		local pot = string.sub(n, 1, 13) == "TerracottaPot" or n == "PotRim"
		local side = if pos.X < 0 then -1 else 1
		local group, kind, pivot, phase = "Body", "Body", CF(), 0
		local authored, authoredPivot = q:GetAttribute("MotionGroup"), q:GetAttribute("MotionPivotRaw")
		if type(authored) == "string" and typeof(authoredPivot) == "CFrame" then
			group, pivot = authored, authoredPivot
			kind = tostring(q:GetAttribute("MotionKind"))
			local value = q:GetAttribute("MotionPhase")
			phase = if type(value) == "number" then value else 0
			-- Mâchoire d'un modèle fait à la main : pivot = celui de sa tête, charnière gardée par rapport à lui.
			local hinge = q:GetAttribute("MotionHingeRaw")
			if typeof(hinge) == "CFrame" then
				q:SetAttribute("MotionHinge", authoredPivot:Inverse() * hinge)
			end
		elseif q:GetAttribute("Spin") then
			group, kind, pivot = "Rotor", "Rotor", CF(pos)
		elseif legs[n] and #anchors > 0 and not duck then
			local nearest, distance = anchors[1], math.huge
			for _, anchor in ipairs(anchors) do
				local delta = (raw(anchor) - pos) * V(1, 0, 1)
				if delta.Magnitude < distance then
					nearest, distance = anchor, delta.Magnitude
				end
			end
			local hip = raw(nearest) + V(0, nearest.Size.Y / scale * 0.44, 0)
			group, kind, pivot = string.format("Leg%.2f_%.2f", hip.X, hip.Z), "Leg", CF(hip)
			phase = if (if family == "Beast" then hip.X * hip.Z else hip.X) < 0 then math.pi else 0
		elseif family == "Frog" and (string.sub(n, 1, 9) == "FoldedLeg" or n == "WebbedToe") then
			group, kind, pivot, phase = "FrogLeg" .. side, "FrogLeg", CF(side * 0.8, -0.4, 0.3), 0
		elseif n == "Foot" and #anchors == 0 then
			group, kind, pivot, phase = "Foot" .. side, "Leg", CF(pos + V(0, 0.2, 0)), if side < 0 then 0 else math.pi
		elseif arms[n] and (family == "Golem" or family == "Dino" or family == "Dragon") then
			group, kind, pivot, phase =
				"Arm" .. side,
				"Arm",
				CF(side * (if e.Id == "GolemDistributeur" then 1.37 else 1), 0.45, 0),
				if side < 0 then 0 else math.pi
		elseif (n == "Ear" or n == "InnerEar") and #ears > 0 then
			local nearest, distance = ears[1], math.huge
			for _, ear in ipairs(ears) do
				local d = (raw(ear) - pos).Magnitude
				if d < distance then
					nearest, distance = ear, d
				end
			end
			local v = raw(nearest)
			group, kind, pivot, phase = string.format("Ear%.2f_%.2f", v.X, v.Z), "Ear", CF(v - V(0, 0.25, 0)), side
		elseif family == "Fish" and (n == "TailFluke" or string.sub(n, 1, 9) == "TailStock") then
			group, kind, pivot = "SwimTail", "SwimTail", CF(0, 0.05, if e.Id == "BaleineGalaxie" then 2.25 else 1.8)
		elseif family == "Fish" and n == "PectoralFin" then
			group, kind, pivot, phase = "Fin" .. side, "Fin", CF(side * 0.8, -0.35, 0), side
		elseif (family == "Dragon" or family == "Dino") and (n == "Tail" or n == "DorsalPlate") then
			group, kind, pivot = "DragonTail", "Tail", CF(0, -0.03, 1.25)
		elseif family == "Bird" and (n == "TailFeather" or n == "CometFeather") then
			group, kind, pivot = "FanTail", "Tail", CF(0, -0.35, 0.65)
		elseif family == "Snake" and e.Id ~= "OuroborosInfini" and (n == "SerpentScale" or n == "ScaleInlay") then
			local segment = math.round(pos.Z / 0.28)
			group, kind, pivot, phase = "Serpent" .. segment, "Serpent", CF(0, 0, segment * 0.28), segment * 0.52
		elseif family == "Kraken" and (n == "Tentacle" or n == "Sucker") then
			local angle = math.round(math.atan2(pos.X, pos.Z) / (math.pi / 4)) * math.pi / 4
			group, kind, pivot, phase =
				"Tentacle" .. angle,
				"Tentacle",
				CF(math.sin(angle) * 0.8, -0.7, math.cos(angle) * 0.8) * A(0, angle, 0),
				angle
		elseif n == "Leaf" or n == "LeafHair" or n == "BerryLeaf" or n == "OrangeLeaf" then
			group, kind, pivot, phase = "Leaf" .. index, "Leaf", CF(pos - V(side * 0.25, 0, 0)), side + pos.Y
		elseif n == "FractalFrond" then
			local level = math.floor(pos.Y / 0.27)
			group, kind, pivot, phase =
				"Frond" .. side .. "_" .. level, "Leaf", CF(0, level * 0.27, 0), side + level * 0.35
		elseif cactus and not pot then
			group, kind, pivot = "Cactus", "Blossom", CF(0, -0.4, 0)
		elseif family == "Plant" and (string.sub(n, 1, 6) == "Canopy" or string.sub(n, 1, 11) == "UpperCanopy") then
			group, kind, pivot = "Canopy", "Canopy", CF(0, 0.7, 0)
		elseif family == "Plant" and (string.sub(n, 1, 11) == "MushroomCap" or n == "CapRim" or n == "CapSpot") then
			group, kind, pivot = "MushroomCap", "Canopy", CF(0, 0.4, 0)
		elseif family == "Plant" and flower and not stem then
			group, kind, pivot = "Blossom", "Blossom", CF(0, 0.4, 0)
		elseif family == "Satellite" and (n == "PanelStrut" or n == "SolarPanel" or n == "SolarCell") then
			group, kind, pivot, phase = "SolarWing" .. side, "SolarWing", CF(side, 0, 0), side
		elseif family == "Washer" and n == "GalaxyDrum" then
			group, kind, pivot = "Drum", "Drum", CF(0, -0.14, -0.95)
		elseif family == "Toaster" and string.sub(n, 1, 5) == "Toast" and not toastSlot then
			group, kind, phase = "Toast" .. (if pos.Z < 0 then -1 else 1), "Toast", if pos.Z < 0 then 0 else 2
		elseif (family == "Rocks" or family == "Eclipse") and #companions > 0 then
			local nearest, distance = companions[1], math.huge
			for _, v in ipairs(companions) do
				local d = (v - pos).Magnitude
				if d < distance then
					nearest, distance = v, d
				end
			end
			group, kind, pivot, phase = "Companion" .. nearest.X, "Companion", CF(nearest), nearest.X * 1.6
		elseif duck and (n == "ExcavatorArm" or n == "ExcavatorForearm" or n == "Bucket") then
			group, kind, pivot = "Excavator", "Excavator", CF(0, 0.4, 0.7)
		end
		q:SetAttribute("MotionGroup", group)
		q:SetAttribute("MotionKind", kind)
		q:SetAttribute("MotionPhase", phase)
		q:SetAttribute("MotionPivot", CF(-center) * pivot)
		q:SetAttribute("MotionRest", scaled(q.CFrame, 1 / scale))
		q:SetAttribute("MotionPivotRaw", nil)
		q:SetAttribute("MotionHingeRaw", nil)
	end
	local species = e.BaseId or e.Id
	m:SetAttribute("MotionFamily", family)
	m:SetAttribute(
		"MotionProfile",
		if species == "BaleineGalaxie" then "Whale" elseif species == "CerbereInfernal" then "Cerberus" else family
	)
	m:SetAttribute("MotionFlying", e.Look.Float == true or family == "Fish" or family == "Dragon" or family == "Spirit")
	m:SetAttribute("MotionPhase", phaseFor(e.Id))
	m:SetAttribute("MotionReady", true)
end

function Motion.Create(m: Model): Rig
	local v = m:GetAttribute("MotionPhase")
	local rig: Rig = {
		model = m,
		parts = {},
		rest = {},
		frames = {},
		joints = {},
		profile = tostring(m:GetAttribute("MotionProfile")),
		flying = m:GetAttribute("MotionFlying") == true,
		phase = if type(v) == "number" then v else 0,
		pace = 0,
		speed = 0,
	}
	local groups: { [string]: Joint } = {}
	for _, q in ipairs(m:GetChildren()) do
		local rest = q:GetAttribute("MotionRest")
		if not q:IsA("BasePart") or typeof(rest) ~= "CFrame" then
			continue
		end
		local index = #rig.parts + 1
		table.insert(rig.parts, q)
		table.insert(rig.rest, rest)
		table.insert(rig.frames, q.CFrame)
		local group = tostring(q:GetAttribute("MotionGroup"))
		local j: Joint? = groups[group]
		if not j then
			local pivot, phase = q:GetAttribute("MotionPivot"), q:GetAttribute("MotionPhase")
			local hinge = q:GetAttribute("MotionHinge")
			local x = if typeof(pivot) == "CFrame" then pivot.Position.X else 0
			local created: Joint = {
				kind = tostring(q:GetAttribute("MotionKind")),
				pivot = if typeof(pivot) == "CFrame" then pivot else CF(),
				phase = if type(phase) == "number" then phase else 0,
				members = {},
				hinge = if typeof(hinge) == "CFrame" then hinge else nil,
				side = if x > 0.05 then 1 elseif x < -0.05 then -1 else 0,
			}
			groups[group] = created
			table.insert(rig.joints, created)
			j = created
		end
		assert(j)
		table.insert(j.members, index)
	end
	return rig
end

-- Tête (Cerbère, 25 oct.) : chacune regarde autour d'elle à son rythme (celles de côté plutôt vers l'extérieur),
-- aboie de temps en temps (relève la tête, gueule grande ouverte), regarde devant et hoche au pas quand il marche.
-- Rotations seules : le mouvement ne dépend pas de la taille du modèle. Renvoie aussi l'aboiement (0 à 1).
local function headPose(j: Joint, t: number, pace: number, walk: number, carried: boolean): (CFrame, number)
	local bark = math.max(0, math.sin(t * 0.45 + j.phase * 1.7) - 0.9) / 0.1
	local calm = (1 - walk * 0.65) * (if carried then 0.4 else 1)
	local yaw = (-j.side * 0.16 + math.sin(t * 0.55 + j.phase) * 0.3 + math.sin(t * 1.3 + j.phase * 2) * 0.08) * calm
	local pitch = math.sin(t * 0.8 + j.phase) * 0.06 * calm + bark * 0.16 + math.sin(pace * 2 + j.phase) * 0.05 * walk
	return A(pitch, yaw, math.sin(t * 0.7 + j.phase) * 0.03 * calm), bark
end

local function jointPose(
	j: Joint,
	t: number,
	pace: number,
	walk: number,
	flying: boolean,
	carried: boolean,
	profile: string
): CFrame
	local wave, kind = math.sin(t * 1.8 + j.phase), j.kind
	if kind == "Head" then
		return (headPose(j, t, pace, walk, carried))
	elseif kind == "Jaw" then
		-- suit sa tête, puis s'ouvre autour de sa charnière : halète, s'ouvre en grand quand la tête aboie
		local head, bark = headPose(j, t, pace, walk, carried)
		local pant = (math.sin(t * 3.2 + j.phase) * 0.5 + 0.5) * 0.08 * (1 - bark)
		local hinge = j.hinge or CF()
		return head * hinge * A(-(pant + bark * 0.42 + walk * 0.04), 0, 0) * hinge:Inverse()
	elseif kind == "Wing" then
		local rate = if flying then 3.5 else 2.5
		local amplitude = if flying then 0.42 else 0.055 + walk * 0.085
		return A(0, 0, j.phase * math.sin(t * rate) * (amplitude + walk * 0.08) * (if carried then 0.45 else 1))
	elseif kind == "Tail" then
		return A(wave * 0.045, math.sin(t * 2.3 + j.phase) * (0.12 + walk * 0.14), 0)
	elseif kind == "Leg" then
		return A(math.sin(pace + j.phase) * walk * (if carried or flying then 0.05 else 0.34), 0, 0)
	elseif kind == "Arm" then
		return A(math.sin(pace + j.phase) * walk * (if carried then 0.02 else 0.2) + wave * 0.025, 0, 0)
	elseif kind == "FrogLeg" then
		return A(math.sin(t * 2) * 0.04 + math.sin(pace) * walk * (if carried then 0.02 else 0.22), 0, 0)
	elseif kind == "Ear" then
		local twitch = math.max(0, math.sin(t * 0.8 + j.phase) - 0.88) / 0.12
		return A(twitch * 0.09, 0, j.phase * twitch * 0.06)
	elseif kind == "SwimTail" then
		local swing = math.sin(t * 2.3) * (0.23 + walk * 0.07)
		return if profile == "Whale" then A(swing, 0, 0) else A(0, swing, 0)
	elseif kind == "Fin" then
		return A(0, wave * 0.06, j.phase * math.sin(t * 2.3) * 0.13)
	elseif kind == "Serpent" then
		return CF(math.sin(t * 2.4 - j.phase) * 0.065, 0, 0) * A(0, math.cos(t * 2.4 - j.phase) * 0.08, 0)
	elseif kind == "Tentacle" then
		return A(wave * 0.16, math.sin(t * 1.4 + j.phase) * 0.09, 0)
	elseif kind == "Leaf" then
		return A(wave * 0.045, 0, math.sin(t * 1.55 + j.phase) * 0.09)
	elseif kind == "Canopy" then
		return A(wave * 0.02, 0, math.sin(t * 1.3) * 0.025)
	elseif kind == "Blossom" then
		return A(wave * 0.025, 0, math.sin(t * 1.45) * 0.055)
	elseif kind == "SolarWing" then
		return A(0, j.phase * math.sin(t * 0.9) * 0.13, j.phase * wave * 0.025)
	elseif kind == "Drum" then
		return A(0, 0, t * 1.6)
	elseif kind == "Rotor" then
		return A(0, t * 12, 0)
	elseif kind == "Toast" then
		return CF(0, math.max(0, math.sin(t * 1.5 + j.phase)) ^ 6 * 0.2, 0)
	elseif kind == "Companion" then
		return CF(0, wave * 0.08, 0) * A(0, wave * 0.06, math.sin(t * 1.2 + j.phase) * 0.05)
	elseif kind == "Excavator" then
		return A(wave * 0.055, 0, 0)
	end
	return CF()
end

function Motion.Pose(rig: Rig, now: number, dt: number, speed: number, carried: boolean, weight: number?): { CFrame }
	local amount = if weight == nil then 1 else math.clamp(weight, 0, 1)
	rig.speed += (math.clamp(speed, 0, 12) - rig.speed) * (1 - math.exp(-math.min(dt, 0.1) * 9))
	local walk = math.clamp(rig.speed / 4, 0, 1)
	rig.pace += math.min(dt, 0.1) * (3.5 + rig.speed * 1.2)
	local t, profile = now + rig.phase, rig.profile
	local breath = math.sin(t * 1.7)
	local body = CF(0, breath * (if rig.flying then 0.1 else 0.014), 0) * A(0, 0, math.sin(t * 1.1) * 0.008)
	if profile == "Plant" then
		body = CF()
	elseif profile == "Slime" or profile == "Frog" then
		body = CF(0, (math.sin(t * 2) + 1) * 0.035, 0) * A(0, 0, breath * 0.013)
	elseif profile == "Top" then
		body = CF(0, breath * 0.06, 0) * A(0, t * 1.5, math.sin(t * 2) * 0.035)
	elseif profile == "Cerberus" then
		-- souffle lourd au repos ; au pas, le corps monte à chaque foulée et roule d'une épaule à l'autre
		body = CF(0, breath * 0.05 + math.abs(math.sin(rig.pace)) * walk * 0.12, 0)
			* A(breath * 0.012 + math.sin(rig.pace * 2) * walk * 0.015, 0, math.sin(rig.pace) * walk * 0.025)
	elseif
		profile == "Remote"
		or profile == "Star"
		or profile == "Moon"
		or profile == "Eclipse"
		or profile == "Rocks"
	then
		body = CF(0, breath * 0.1, 0) * A(math.sin(t) * 0.025, math.sin(t * 0.8) * 0.055, breath * 0.025)
	end
	if carried then
		body = CF(0, breath * 0.012, 0)
	end
	body = CF():Lerp(body, amount)
	local scale = rig.model:GetScale()
	local root = rig.model:GetPivot() * scaled(body, scale)
	for _, j in ipairs(rig.joints) do
		local pivot = scaled(j.pivot, scale)
		local pose = CF():Lerp(jointPose(j, t, rig.pace, walk, rig.flying, carried, profile), amount)
		local transform = root * pivot * scaled(pose, scale) * pivot:Inverse()
		for _, index in ipairs(j.members) do
			rig.frames[index] = transform * scaled(rig.rest[index], scale)
		end
	end
	return rig.frames
end

return Motion
