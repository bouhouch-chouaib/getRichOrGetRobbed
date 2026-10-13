--!strict
-- Authored silhouettes for the complete catalogue. Front is -Z; units are unscaled studs.
local S = require(script.Parent.PetSculpt)
local Catalog = require(script.Parent.PetCatalog)
local FX = require(script.Parent.PetSculptedEffects)
local Motion = require(script.Parent.PetMotion)
local PetSizes = require(script.Parent.PetSizes)
local Models = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB
local WHITE, BLACK, GOLD, GREEN = rgb(248, 242, 224), rgb(22, 21, 32), rgb(255, 196, 35), rgb(76, 174, 69)
local p, mass, link = S.part, S.mass, S.link
type Pet = Catalog.Pet
type Palette = S.Palette

-- Explicit registry: adding a catalogue entry requires choosing its silhouette.
local families: { [string]: string } = {
	ChienSaucisse = "Beast",
	ChatRuelle = "Beast",
	PigeonVilles = "Bird",
	GrenouilleGlobuleuse = "Frog",
	HamsterJoufflu = "Hamster",
	RenardFurtif = "Beast",
	CorbeauVoleur = "Bird",
	HibouGrincheux = "Bird",
	LoupPolaire = "Beast",
	PanthereNeon = "Beast",
	TigreBengal = "Beast",
	AigleRoyal = "Bird",
	RequinVolant = "Fish",
	TRexPoche = "Dino",
	CapybaraZen = "Beast",
	FeuFollet = "Spirit",
	SlimeGlgl = "Slime",
	BebeGriffon = "Beast",
	GargouilleMignonne = "Golem",
	LicorneBois = "Beast",
	PhenixCendres = "Bird",
	CerbereChiot = "Beast",
	DragonnetObsidienne = "Dragon",
	PegaseNuageux = "Beast",
	Kitsune3Queues = "Beast",
	KrakenBaignoire = "Kraken",
	BasilicEmeraude = "Snake",
	LeviathanAbyssal = "Dragon",
	PhenixSolaire = "Bird",
	OuroborosInfini = "Snake",
	PousseHaricot = "Plant",
	CactusRonchon = "Plant",
	NavetPeureux = "Plant",
	TournesolJoyeux = "Plant",
	ChampignonVeneneux = "Plant",
	CitrouilleSculptee = "Pumpkin",
	BonsaiMillenaire = "Plant",
	RoseCristal = "Plant",
	MandragoreHurlante = "Golem",
	Treflant4Feuilles = "Plant",
	LotusEspace = "Plant",
	ArbreMondeMiniature = "Plant",
	CarniflorToxique = "Plant",
	GraineEtoile = "Star",
	FougereFibonacci = "Plant",
	ChatCoptere = "Beast",
	TortueBurger = "Beast",
	PoissonAmpoule = "Fish",
	CochonTirelire = "Beast",
	TasseChien = "Mug",
	CorbeauHorloge = "Bird",
	BananeChien = "Beast",
	HibouCamera = "Bird",
	RequinTorpille = "Fish",
	PegaseMoto = "Beast",
	DragonGrillePain = "Toaster",
	TRexTank = "Dino",
	GolemDistributeur = "Golem",
	LionEnceinte = "Beast",
	CanardTractopelle = "Bird",
	AstroBoulon = "Golem",
	AutrucheFusee = "Bird",
	MyrtilleLunaire = "Moon",
	ConciergeCosmique = "Golem",
	MoutonMeteore = "Beast",
	TelecommandePerdue = "Remote",
	SatelliteRonchon = "Satellite",
	PingouinComete = "Bird",
	BurritoNebuleuse = "Burrito",
	TrioAsteroides = "Rocks",
	JumeauxEclipse = "Eclipse",
	ToupieTrouDeVer = "Top",
	MachineQuantique = "Washer",
	DragonAurore = "Dragon",
	BaleineGalaxie = "Fish",
}
Models.Families = families

local function teeth(m: Model, cf: CFrame, width: number, count: number)
	for i = 1, count do
		p(
			m,
			"Fang",
			V(width / count * 0.48, 0.25, 0.17),
			cf * CF((i - (count + 1) / 2) * width / count, 0, 0),
			WHITE,
			false,
			true
		)
	end
end

local function muzzle(m: Model, cf: CFrame, width: number, c: Palette, fierce: boolean?)
	mass(m, "Muzzle", V(width * 0.72, 0.45, 0.68), cf * CF(0, -0.2, -0.71), c.light)
	p(m, "Nose", V(width * 0.27, 0.17, 0.14), cf * CF(0, -0.07, -1.1), BLACK)
	p(m, "Mouth", V(width * 0.49, 0.06, 0.07), cf * CF(0, -0.38, -1.07), BLACK)
	if fierce then
		teeth(m, cf * CF(0, -0.41, -1.1), width * 0.6, 4)
	end
end

local function tail(m: Model, start: CFrame, color: Color3, tip: Color3, size: number)
	local first = #m:GetChildren()
	for i = 0, 3 do
		local f = start * CF(0, i * 0.18, i * size * 0.48) * A(-i * 0.16, 0, 0)
		p(
			m,
			"TailSegment",
			V(size * (1 - i * 0.14), size * (1 - i * 0.14), size * 0.68),
			f,
			if i == 3 then tip else color,
			false,
			i == 3
		)
	end
	S.motionSince(m, first, "Tail" .. first, start, "Tail", start.Position.X * 1.8)
end

local function beast(m: Model, e: Pet, c: Palette)
	local id = e.Id
	local horse = id == "LicorneBois" or id == "PegaseNuageux" or id == "PegaseMoto"
	local stout = id == "CapybaraZen" or id == "CochonTirelire" or id == "TortueBurger"
	local long = id == "ChienSaucisse" or id == "BananeChien"
	local fierce = id == "CerbereChiot"
		or id == "LoupPolaire"
		or id == "TigreBengal"
		or id == "LionEnceinte"
		or id == "PanthereNeon"
	local length = if long then 3.6 elseif stout then 2.7 else 2.45
	local width = if stout then 1.8 else 1.55
	local leg = if horse then 1.3 elseif stout or long then 0.65 else 0.95
	mass(m, "Torso", V(width, 1.45, length), CF(0, 0.15, 0.2), c.body)
	p(m, "Belly", V(width * 0.7, 0.2, length * 0.75), CF(0, -0.51, 0.12), c.light)
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -length * 0.3, length * 0.33 }) do
			p(m, "Haunch", V(0.55, 0.65, 0.68), CF(s * width * 0.39, -0.32, z), c.body)
			p(m, "Leg", V(0.37, leg, 0.43), CF(s * width * 0.39, -0.73 - leg * 0.24, z) * A(-0.06, 0, s * 0.04), c.body)
			p(
				m,
				"Paw",
				V(0.53, 0.3, 0.7),
				CF(s * width * 0.39, -0.78 - leg * 0.7, z - 0.12),
				if horse then c.dark else c.light
			)
			if fierce then
				for t = -1, 1 do
					p(
						m,
						"Claw",
						V(0.09, 0.12, 0.19),
						CF(s * width * 0.39 + t * 0.15, -0.85 - leg * 0.7, z - 0.46),
						WHITE,
						false,
						true
					)
				end
			end
		end
	end
	local head = CF(0, if horse then 1.05 else 0.76, -length / 2 + 0.05)
	if horse then
		mass(m, "Neck", V(0.95, 1.7, 0.85), CF(0, 0.6, -length / 2 + 0.4) * A(-0.25, 0, 0), c.body)
	end
	local function headAt(f: CFrame, w: number)
		mass(m, "Head", V(w, 1.18, 1.3), f, c.body)
		muzzle(m, f, w, c, fierce)
		S.eyes(m, f, w, 1.4, fierce, if id == "CerbereChiot" then c.detail else nil)
		for _, s in ipairs({ -1, 1 }) do
			S.ear(
				m,
				f * CF(s * w * 0.38, 0.67, 0.02) * A(0, 0, -s * 0.15),
				c.body,
				c.light,
				id == "ChienSaucisse" or id == "BananeChien"
			)
		end
	end
	headAt(head, if stout then 1.55 else 1.3)
	if id == "CerbereChiot" then
		for _, s in ipairs({ -1, 1 }) do
			headAt(head * CF(s * 1.05, -0.18, 0.24) * A(0, -s * 0.18, 0), 1.05)
			for i = 0, 2 do
				S.horn(m, head * CF(s * (0.5 + i * 0.25), 0.64, 0.45 + i * 0.23) * A(0, 0, -s * 0.55), 0.55, c.dark)
			end
		end
		p(m, "Collar", V(2.2, 0.25, 0.8), head * CF(0, -0.67, 0.25), c.detail)
		for i = -3, 3 do
			p(m, "CollarStud", V(0.15, 0.22, 0.2), head * CF(i * 0.28, -0.66, -0.2), WHITE, false, true)
		end
	elseif id == "Kitsune3Queues" then
		for i = -1, 1 do
			tail(m, CF(i * 0.42, 0.45, length / 2) * A(-0.45, i * 0.6, 0), WHITE, c.detail, 0.64)
		end
		for _, s in ipairs({ -1, 1 }) do
			p(m, "FoxMark", V(0.32, 0.1, 0.08), head * CF(s * 0.43, -0.2, -0.75) * A(0, 0, s * 0.35), c.detail)
		end
	elseif id ~= "TortueBurger" then
		tail(
			m,
			CF(0, 0.35, length / 2) * A(-0.25, 0.15, 0),
			c.body,
			if id == "RenardFurtif" then WHITE else c.detail,
			if horse then 0.4 elseif id == "RenardFurtif" then 0.7 else 0.35
		)
	end
	if id == "ChatRuelle" or id == "ChatCoptere" or id == "TigreBengal" or id == "PanthereNeon" then
		for _, s in ipairs({ -1, 1 }) do
			for i = 0, 3 do
				p(
					m,
					"FlankMark",
					V(0.07, 0.58, 0.14),
					CF(s * (width / 2 + 0.01), 0.22, -0.65 + i * 0.47) * A(0, 0, s * 0.2),
					if id == "PanthereNeon" then c.detail else c.dark,
					id == "PanthereNeon"
				)
			end
		end
	end
	if id == "ChatRuelle" then
		p(m, "Bandage", V(0.34, 0.16, 0.06), head * CF(0.5, -0.27, -0.73) * A(0, 0, -0.2), WHITE)
	end
	if id == "RenardFurtif" then
		p(m, "RedBandana", V(1.4, 0.22, 1), head * CF(0, -0.6, 0.2), rgb(218, 35, 48))
		p(
			m,
			"BandanaKnot",
			V(0.4, 0.55, 0.13),
			head * CF(0, -0.9, -0.35) * A(0, 0, math.pi),
			rgb(218, 35, 48),
			false,
			true
		)
	end
	if horse then
		for i = 0, 4 do
			p(
				m,
				"ManeLock",
				V(0.3, 0.6, 0.32),
				CF(0, 1.05 - i * 0.13, -0.5 + i * 0.28) * A(-0.2, 0, 0),
				c.detail,
				false,
				true
			)
		end
	end
	if id == "BebeGriffon" or id == "PegaseNuageux" then
		S.wings(m, CF(0, 0.9, 0.2), if horse then 2.5 else 1.75, c.detail, c.light, false)
		if id == "BebeGriffon" then
			p(m, "GriffinBeak", V(0.5, 0.5, 0.62), head * CF(0, -0.2, -1.05) * A(math.pi, 0, 0), GOLD, false, true)
		end
	end
	if id == "LicorneBois" then
		S.horn(m, head * CF(0, 0.58, -0.35) * A(-0.3, 0, 0), 1, c.detail)
	end
	if id == "ChatCoptere" then
		p(m, "RotorMast", V(0.18, 0.55, 0.18), head * CF(0, 0.97, 0), c.dark)
		local rotor = p(m, "Rotor", V(2.7, 0.1, 0.28), head * CF(0, 1.26, 0), c.detail)
		rotor:SetAttribute("Spin", 10)
	end
	if id == "CapybaraZen" then
		mass(m, "Orange", V(0.68, 0.65, 0.65), head * CF(0, 1.02, 0), rgb(255, 141, 25))
		p(m, "OrangeLeaf", V(0.45, 0.09, 0.23), head * CF(0.17, 1.39, 0) * A(0, 0, 0.3), GREEN, false, true)
	end
	if id == "CochonTirelire" then
		p(m, "PigSnout", V(0.73, 0.4, 0.18), head * CF(0, -0.13, -1.16), rgb(240, 113, 157))
		for _, s in ipairs({ -1, 1 }) do
			p(m, "Nostril", V(0.12, 0.12, 0.035), head * CF(s * 0.17, -0.12, -1.27), c.dark)
		end
		p(m, "CoinSlot", V(0.8, 0.045, 0.13), CF(0, 0.99, 0.2), BLACK)
		p(m, "SavingsCoin", V(0.55, 0.65, 0.1), CF(0, 1.21, 0.2) * A(0, 0, 0.12), GOLD)
	end
	if id == "TortueBurger" then
		for i, color in ipairs({ rgb(210, 147, 69), GREEN, rgb(228, 49, 39), rgb(255, 211, 55), rgb(89, 48, 32) }) do
			p(m, "BurgerLayer", V(2.05, 0.18, 2.3), CF(0, 0.6 + i * 0.16, 0.18), color)
		end
		mass(m, "Bun", V(2.12, 0.65, 2.4), CF(0, 1.69, 0.18), c.detail)
		for i = 1, 6 do
			p(
				m,
				"Sesame",
				V(0.16, 0.045, 0.08),
				CF(math.sin(i * 2) * 0.65, 2.07, math.cos(i * 2) * 0.78 + 0.18) * A(0, i, 0),
				WHITE
			)
		end
	end
	if id == "BananeChien" then
		for _, s in ipairs({ -1, 1 }) do
			p(m, "BananaPeel", V(0.35, 1.1, 1.6), CF(s * 0.85, 0.5, 0.85) * A(-0.4, 0, -s * 0.25), GOLD, false, true)
		end
		p(m, "BananaStem", V(0.38, 0.5, 0.4), CF(0, 0.6, 2.05) * A(-0.4, 0, 0), c.dark)
	end
	if id == "MoutonMeteore" then
		for i = 0, 7 do
			local a = i * math.pi / 4
			mass(m, "Wool", V(0.7, 0.7, 0.8), CF(math.cos(a) * 0.64, 0.62, math.sin(a) * 0.8), WHITE)
		end
	end
	if id == "LoupPolaire" then
		for _, s in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				p(
					m,
					"FrostRuff",
					V(0.27, 0.8, 0.5),
					head * CF(s * (0.65 + i * 0.12), -0.15, 0.25 + i * 0.18) * A(0, 0, -s * 0.35),
					c.detail,
					false,
					true
				)
			end
		end
	end
	if id == "PegaseMoto" then
		for _, s in ipairs({ -1, 1 }) do
			p(m, "Exhaust", V(0.32, 0.35, 1.55), CF(s * 0.92, 0.18, 0.8), c.dark)
			p(m, "ExhaustCore", V(0.24, 0.27, 0.07), CF(s * 0.92, 0.18, 1.61), c.detail, true)
		end
		S.wings(m, CF(0, 0.65, 0), 1.7, c.body, c.detail, false, true)
	end
	if id == "LionEnceinte" then
		for i = 0, 7 do
			local a = i * math.pi / 4
			local f = head * CF(math.cos(a) * 0.93, math.sin(a) * 0.93, 0.15) * A(0, 0, a - math.pi / 2)
			p(m, "SpeakerCabinet", V(0.65, 0.65, 0.55), f, c.detail)
			S.ring(m, "SpeakerRim", f * CF(0, 0, -0.3) * A(math.pi / 2, 0, 0), 0.23, 0.07, rgb(65, 201, 245), true, 8)
			p(m, "SpeakerCone", V(0.23, 0.23, 0.08), f * CF(0, 0, -0.34), BLACK)
		end
	end
end

local function bird(m: Model, e: Pet, c: Palette)
	local id = e.Id
	local phoenix = id == "PhenixSolaire" or id == "PhenixCendres"
	local owl = id == "HibouGrincheux" or id == "HibouCamera"
	local ostrich = id == "AutrucheFusee"
	local duck = id == "CanardTractopelle"
	mass(m, "Breast", V(1.65, 1.8, 1.5), CF(), c.body)
	mass(m, "Bib", V(1.15, 1.1, 0.27), CF(0, -0.05, -0.69), c.detail)
	local head = CF(0, if ostrich then 2.2 else 1.05, -0.32)
	if ostrich then
		p(m, "LongNeck", V(0.45, 1.8, 0.5), CF(0, 1.2, -0.15) * A(-0.13, 0, 0), c.body)
	end
	mass(m, "Head", V(if owl then 1.55 else 1.3, 1.25, 1.25), head, c.body)
	if owl then
		for _, s in ipairs({ -1, 1 }) do
			p(m, "FaceDisc", V(0.67, 0.75, 0.1), head * CF(s * 0.37, 0, -0.68), c.light)
			S.ear(m, head * CF(s * 0.6, 0.69, 0) * A(0, 0, -s * 0.25), c.body, c.detail)
		end
	end
	S.eyes(m, head, if owl then 1.55 else 1.3, 1.4, owl)
	p(
		m,
		"Beak",
		V(if duck then 0.95 else 0.42, 0.33, if duck then 0.73 else 0.54),
		head * CF(0, -0.24, -0.92) * A(math.pi, 0, 0),
		GOLD,
		false,
		not duck
	)
	local span = if phoenix then 3.3 elseif id == "AigleRoyal" then 2.7 elseif owl then 1.15 else 1.3
	S.wings(m, CF(0, 0.35, 0.1), span, c.body, if phoenix then c.detail else c.light, id == "PhenixSolaire")
	for i = -1, 1 do
		p(
			m,
			"TailFeather",
			V(0.4, 0.16, if phoenix then 2.7 else 1.25),
			CF(i * 0.4, -0.35, if phoenix then 1.7 else 0.99) * A(-0.18, i * 0.16, 0),
			if i == 0 then c.detail else c.body,
			false,
			true
		)
	end
	for _, s in ipairs({ -1, 1 }) do
		p(m, "Shin", V(0.22, if ostrich then 1.5 else 0.53, 0.25), CF(s * 0.43, if ostrich then -1.43 else -1, 0), GOLD)
		for i = -1, 1 do
			p(
				m,
				"Talon",
				V(0.12, 0.13, 0.6),
				CF(s * 0.43 + i * 0.17, if ostrich then -2.21 else -1.29, -0.2) * A(0, i * 0.22, 0),
				GOLD
			)
		end
	end
	if phoenix or id == "AigleRoyal" then
		S.crown(m, head * CF(0, 0.8, 0), 1.1)
	end
	if id == "CorbeauVoleur" then
		p(m, "StolenCoin", V(0.58, 0.58, 0.1), head * CF(0, -0.45, -1.24) * A(0, 0, 0.2), GOLD)
	end
	if id == "CorbeauHorloge" then
		local f = CF(0, 0, -0.92)
		S.ring(m, "ClockGear", f * A(math.pi / 2, 0, 0), 0.48, 0.12, c.detail, false, 12)
		p(m, "ClockFace", V(0.67, 0.67, 0.08), f, WHITE)
		p(m, "HourHand", V(0.08, 0.27, 0.04), f * CF(0, 0.1, -0.08), BLACK)
		p(m, "MinuteHand", V(0.3, 0.055, 0.04), f * CF(0.12, 0, -0.09) * A(0, 0, -0.3), BLACK)
	end
	if id == "HibouCamera" then
		for _, s in ipairs({ -1, 1 }) do
			local f = head * CF(s * 0.43, 0.09, -0.93)
			S.ring(m, "LensBarrel", f * A(math.pi / 2, 0, 0), 0.32, 0.17, BLACK, false, 8)
			p(m, "LensGlass", V(0.37, 0.37, 0.12), f * CF(0, 0, -0.1), rgb(62, 175, 232), true)
		end
	end
	if ostrich then
		for _, s in ipairs({ -1, 1 }) do
			mass(m, "Rocket", V(0.58, 0.65, 1.6), CF(s * 0.7, 0.6, 0.64), rgb(150, 160, 177))
			p(m, "Nozzle", V(0.43, 0.45, 0.2), CF(s * 0.7, 0.6, 1.56), c.detail, true)
		end
	end
	if id == "PingouinComete" then
		p(m, "IceVisor", V(1.38, 0.18, 0.1), head * CF(0, 0.41, -0.76), rgb(92, 222, 255), true)
		for i = 1, 3 do
			p(
				m,
				"CometFeather",
				V(0.16, 0.18, 1.5 + i * 0.25),
				CF((i - 2) * 0.27, -0.2, 1.55) * A(-0.2, 0, 0),
				rgb(120, 220, 255),
				true,
				true
			)
		end
	end
	if duck then
		for _, s in ipairs({ -1, 1 }) do
			p(m, "Track", V(0.7, 0.7, 2.7), CF(s * 0.95, -1.13, 0.15), c.dark)
			for i = 0, 7 do
				p(m, "TrackTread", V(0.81, 0.14, 0.18), CF(s * 0.95, -0.75, -1 + i * 0.32), GOLD)
			end
			for i = 0, 3 do
				p(m, "TrackWheel", V(0.1, 0.4, 0.4), CF(s * 1.33, -1.16, -0.75 + i * 0.6) * A(math.pi / 4, 0, 0), GOLD)
			end
		end
		link(m, "ExcavatorArm", V(0, 0.4, 0.7), V(0, 2.1, 1.9), 0.35, 0.35, GOLD)
		link(m, "ExcavatorForearm", V(0, 2.1, 1.9), V(0, 1.2, 3), 0.3, 0.3, GOLD)
		p(m, "Bucket", V(1.15, 0.65, 0.85), CF(0, 0.95, 3.13), GOLD, false, true)
	end
end

local function fish(m: Model, e: Pet, c: Palette)
	local whale = e.Id == "BaleineGalaxie"
	local len = if whale then 4.6 else 3.7
	mass(m, "Hull", V(if whale then 2.5 else 1.85, if whale then 2.2 else 1.55, len), CF(0, 0, 0), c.body)
	mass(
		m,
		"Jaw",
		V(if whale then 2.15 else 1.6, 0.48, len * 0.55),
		CF(0, -0.56, -0.75),
		if whale then c.light else WHITE
	)
	local head = CF(0, 0.04, -len * 0.3)
	S.eyes(m, head, if whale then 2.4 else 1.8, len * 0.52, not whale, if whale then rgb(133, 218, 255) else nil)
	p(m, "MouthCavity", V(if whale then 1.65 else 1.2, 0.22, 0.08), CF(0, -0.38, -len * 0.565), BLACK)
	if not whale then
		teeth(m, CF(0, -0.35, -len * 0.586), 1.1, 7)
	end
	for _, s in ipairs({ -1, 1 }) do
		p(m, "PectoralFin", V(1.7, 0.23, 1.35), CF(s * 1.38, -0.4, 0) * A(0, s * 0.3, s * 0.23), c.body, false, true)
		p(
			m,
			"TailFluke",
			V(1.3, 0.22, 0.9),
			CF(s * 0.7, 0.1, len / 2 + 0.85) * A(0, -s * 0.4, s * 0.15),
			c.detail,
			false,
			true
		)
		for i = 0, 2 do
			p(m, "Gill", V(0.065, 0.52, 0.1), CF(s * 0.95, -0.01, -0.74 + i * 0.25) * A(0, 0, s * 0.2), c.dark)
		end
	end
	mass(m, "TailStock", V(0.72, 0.65, 1.35), CF(0, 0.05, len / 2 + 0.35), c.body)
	p(m, "DorsalFin", V(0.26, 1.2, 1.5), CF(0, 1.04, 0.4), c.body, false, true)
	if e.Id == "PoissonAmpoule" then
		link(m, "LampStalk", V(0, 0.7, -0.9), V(0, 1.5, -1.3), 0.13, 0.13, c.dark)
		mass(m, "Lamp", V(0.6, 0.6, 0.55), CF(0, 1.8, -1.3), c.detail)
		p(m, "LampCore", V(0.4, 0.4, 0.42), CF(0, 1.8, -1.47), c.detail, true)
	elseif e.Id == "RequinTorpille" then
		for _, s in ipairs({ -1, 1 }) do
			mass(m, "Thruster", V(0.65, 0.65, 1.55), CF(s * 0.98, -0.1, 0.95), c.dark)
			p(m, "HotNozzle", V(0.48, 0.48, 0.13), CF(s * 0.98, -0.1, 1.85), c.detail, true)
		end
	elseif whale then
		S.ring(m, "GalaxyBelt", CF(0, 0.18, 0) * A(0.18, 0, 0.12), 2, 0.08, c.detail, true, 16)
		for i = 1, 12 do
			local s = if i % 2 == 0 then -1 else 1
			p(
				m,
				"Constellation",
				V(0.07, 0.1 + (i % 3) * 0.06, 0.13),
				CF(s * 1.27, 0.05 + math.sin(i) * 0.55, math.cos(i * 1.7) * 1.3),
				if i % 3 == 0 then GOLD else WHITE,
				true
			)
		end
		S.crown(m, CF(0, 1.44, -0.85), 1.4)
	end
end

local function dragon(m: Model, e: Pet, c: Palette, dino: boolean?)
	local sea = e.Id == "LeviathanAbyssal"
	mass(m, "DragonChest", V(2, 2.1, 2.8), CF(0, 0.25, 0.2), c.body)
	for i = 0, 3 do
		p(m, "BellyScale", V(1.35 - i * 0.1, 0.28, 0.16), CF(0, -0.52 + i * 0.38, -1.17), c.light)
	end
	local head = CF(0, 1.5, -1.1)
	mass(m, "Skull", V(1.85, 1.35, 1.65), head, c.body)
	mass(m, "Snout", V(1.55, 0.55, 1.16), head * CF(0, -0.23, -1.05), c.body)
	p(m, "Gape", V(1.31, 0.28, 0.7), head * CF(0, -0.56, -1.07), BLACK)
	p(m, "Jaw", V(1.48, 0.22, 1.12), head * CF(0, -0.77, -1.04), c.light)
	teeth(m, head * CF(0, -0.53, -1.61), 1.35, 7)
	S.eyes(m, head, 1.85, 1.82, true, if dino then GOLD else c.detail)
	for _, s in ipairs({ -1, 1 }) do
		mass(m, "Thigh", V(0.85, 1.25, 1.05), CF(s * 0.97, -0.54, 0.7), c.body)
		p(m, "HindFoot", V(0.84, 0.38, 1.21), CF(s * 0.97, -1.31, 0.29), c.dark)
		p(
			m,
			"Forearm",
			V(0.42, if dino then 0.62 else 1.12, 0.45),
			CF(s * 1.1, if dino then 0.24 else -0.55, -0.82) * A(-0.42, 0, -s * 0.25),
			c.body
		)
		for i = -1, 1 do
			p(m, "Talon", V(0.16, 0.24, 0.36), CF(s * 0.97 + i * 0.24, -1.4, -0.38), WHITE, false, true)
		end
		if not dino then
			S.horn(m, head * CF(s * 0.68, 0.72, 0.32) * A(0.25, 0, -s * 0.3), 1.15, c.detail)
		end
		for i = 0, 2 do
			p(
				m,
				"CheekPlate",
				V(0.35, 0.5, 0.66),
				head * CF(s * (0.81 + i * 0.12), 0, 0.14 + i * 0.25) * A(0, s * 0.25, -s * 0.45),
				c.dark,
				false,
				true
			)
		end
	end
	for i = 0, 6 do
		local w = 0.87 - i * 0.1
		p(
			m,
			"Tail",
			V(w, w, 0.72),
			CF(math.sin(i * 0.38) * 0.8, -0.03 + i * 0.11, 1.55 + i * 0.49) * A(-0.15, -math.cos(i * 0.38) * 0.3, 0),
			c.body
		)
		p(
			m,
			"DorsalPlate",
			V(0.21, 0.7 - i * 0.06, 0.58),
			CF(math.sin(i * 0.38) * 0.8, 0.59 + i * 0.07, 1.44 + i * 0.49),
			c.detail,
			not dino,
			true
		)
	end
	if not dino then
		S.wings(m, CF(0, 1, 0.3), if sea then 2.2 else 3, c.body, c.detail, true, true)
	end
	if e.Id == "DragonAurore" then
		for i = 0, 4 do
			p(
				m,
				"AuroraSail",
				V(0.16, 1.4 - i * 0.17, 0.46),
				CF(0, 1.55 - i * 0.08, 0.5 + i * 0.57) * A(-0.3, 0, 0),
				if i % 2 == 0 then c.detail else rgb(73, 241, 213),
				true,
				true
			)
		end
	end
	if e.Id == "TRexTank" then
		mass(m, "Turret", V(1.55, 0.75, 1.5), CF(0, 1.55, 0.7), c.detail)
		p(m, "Cannon", V(0.45, 0.45, 2.3), CF(0, 1.64, -0.67), c.dark)
		p(m, "MuzzleBrake", V(0.72, 0.62, 0.4), CF(0, 1.64, -1.94), c.detail)
		p(m, "Bore", V(0.37, 0.28, 0.04), CF(0, 1.64, -2.16), BLACK)
	end
end

local function snake(m: Model, e: Pet, c: Palette)
	local ring = e.Id == "OuroborosInfini"
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local f = if ring
			then CF(math.sin(a) * 1.9, math.cos(a) * 1.9, 0) * A(0, 0, -a)
			else CF(math.sin(i * 0.52) * 0.85, -0.2 + i * 0.025, i * 0.28) * A(0, math.cos(i * 0.52) * 0.5, 0)
		local w = if ring then 0.72 else 1 - i * 0.038
		p(m, "SerpentScale", V(w, w, if ring then 0.7 else 0.56), f, c.body)
		p(m, "ScaleInlay", V(w * 0.53, 0.07, 0.29), f * CF(0, w * 0.53, 0), c.detail, true)
	end
	local head = if ring then CF(0, 1.91, -0.35) else CF(0, 0.1, -0.57)
	mass(m, "SerpentHead", V(1.3, 0.95, 1.3), head, c.body)
	S.eyes(m, head, 1.3, 1.45, true, c.detail)
	muzzle(m, head, 1.3, c, true)
	for _, s in ipairs({ -1, 1 }) do
		S.horn(m, head * CF(s * 0.5, 0.5, 0.2) * A(0, 0, -s * 0.3), 0.75, GOLD)
	end
	if ring then
		S.crown(m, head * CF(0, 0.72, 0), 0.9)
	end
end

local function small(m: Model, e: Pet, c: Palette, kind: string)
	local head = CF(0, 0.35, 0)
	if kind == "Slime" then
		local jelly = p(m, "Jelly", V(2.1, 1.65, 1.9), CF(), c.body)
		jelly.Transparency = 0.28
		p(m, "JellyCrown", V(1.8, 0.24, 1.6), CF(0, 0.94, 0), c.light).Transparency = 0.22
		p(m, "JellyCore", V(0.8, 0.8, 0.8), CF(0, 0, 0), c.detail)
		S.eyes(m, CF(0, 0.08, -0.37), 1.5, 1.4)
		return
	end
	mass(m, "Body", V(2, 1.8, 1.8), CF(), c.body)
	if kind == "Frog" then
		for _, s in ipairs({ -1, 1 }) do
			mass(m, "EyeBulge", V(0.75, 0.75, 0.65), CF(s * 0.65, 0.95, -0.46), c.body)
			p(m, "FrogEye", V(0.39, 0.43, 0.12), CF(s * 0.65, 0.99, -0.87), WHITE)
			p(m, "FrogPupil", V(0.18, 0.27, 0.06), CF(s * 0.65, 0.99, -0.96), BLACK)
			mass(m, "FoldedLeg", V(0.8, 0.68, 1.2), CF(s * 1, -0.64, 0.3), c.dark)
			for i = -1, 1 do
				p(m, "WebbedToe", V(0.19, 0.15, 0.6), CF(s * 0.85 + i * 0.2, -0.99, -0.35), c.light, false, true)
			end
		end
		p(m, "FrogSmile", V(1.2, 0.09, 0.06), CF(0, -0.17, -1), BLACK)
	elseif kind == "Hamster" then
		S.eyes(m, head, 1.7, 2)
		for _, s in ipairs({ -1, 1 }) do
			mass(m, "Cheek", V(0.74, 0.73, 0.55), CF(s * 0.56, -0.25, -0.85), c.detail)
			S.ear(m, CF(s * 0.68, 1.1, 0), c.body, c.detail)
			p(m, "Foot", V(0.4, 0.23, 0.6), CF(s * 0.5, -1, -0.4), c.detail)
		end
		p(m, "Tooth", V(0.24, 0.28, 0.13), CF(0, -0.45, -1.18), WHITE)
	elseif kind == "Kraken" then
		S.eyes(m, head, 1.8, 2, true)
		S.crown(m, CF(0, 1.2, 0), 1.3)
		for i = 0, 7 do
			local a = i * math.pi / 4
			local f = CF() * A(0, a, 0)
			for j = 0, 2 do
				p(
					m,
					"Tentacle",
					V(0.45 - j * 0.08, 0.38, 0.65),
					f * CF(0, -0.7 - j * 0.12, 1 + j * 0.45) * A(-j * 0.25, 0, 0),
					c.body
				)
				p(m, "Sucker", V(0.19, 0.08, 0.2), f * CF(0, -0.47 - j * 0.12, 1 + j * 0.45), c.light)
			end
		end
		mass(m, "BathDuck", V(0.58, 0.43, 0.6), CF(1.4, -0.35, -1.1), GOLD)
		p(m, "DuckBeak", V(0.28, 0.14, 0.3), CF(1.4, -0.23, -1.5), rgb(255, 120, 20))
	elseif kind == "Pumpkin" then
		for i = -2, 2 do
			p(m, "PumpkinRib", V(0.3, 1.5 - math.abs(i) * 0.2, 0.14), CF(i * 0.39, 0, -0.95), c.light)
		end
		S.eyes(m, head, 1.8, 2.1, true, c.detail)
		p(m, "CarvedGrin", V(1.14, 0.25, 0.07), CF(0, -0.42, -1.05), BLACK)
		teeth(m, CF(0, -0.35, -1.1), 0.92, 5)
		p(m, "Stem", V(0.32, 0.52, 0.35), CF(0, 1.2, 0) * A(0, 0, -0.2), GREEN)
	elseif kind == "Moon" then
		for i = 0, 5 do
			local a = i * 1.1
			p(
				m,
				"CraterRim",
				V(0.4, 0.4, 0.1),
				CF(math.cos(a) * 0.73, math.sin(a) * 0.63, -0.96) * A(0, 0, a),
				c.detail
			)
			p(m, "Crater", V(0.22, 0.22, 0.12), CF(math.cos(a) * 0.73, math.sin(a) * 0.63, -1.03), c.dark)
		end
		S.eyes(m, CF(0, 0, -0.42), 1.1, 1.5)
		for i = 0, 3 do
			p(
				m,
				"BerryLeaf",
				V(0.3, 0.5, 0.12),
				CF(0, 1, 0) * A(0, i * math.pi / 2, 0) * CF(0, 0.15, -0.2) * A(-0.5, 0, 0),
				GREEN,
				false,
				true
			)
		end
	else
		S.eyes(m, CF(0, 0, -0.25), 1.55, 1.7, false, c.detail)
		for i = 0, 4 do
			local a = i * math.pi * 2 / 5
			S.horn(
				m,
				CF(math.cos(a) * 0.72, 0.7, math.sin(a) * 0.62) * A(0, 0, math.cos(a) * 0.35),
				0.6 + (i % 2) * 0.4,
				c.detail,
				true
			)
		end
		if kind == "Star" then
			S.ring(m, "StellarOrbit", CF() * A(0.4, 0, 0.35), 1.7, 0.1, GOLD, true, 16)
		end
	end
end

local function plant(m: Model, e: Pet, c: Palette)
	local id = e.Id
	if id == "FougereFibonacci" then
		for i = 0, 10 do
			local y = i * 0.27
			local x = math.sin(i * 0.23) * 0.3
			p(m, "FernStem", V(0.16, 0.4, 0.17), CF(x, y, 0) * A(0, 0, -0.13), GOLD)
			for _, s in ipairs({ -1, 1 }) do
				local len = (1 - i / 12) * 1.35
				local first = #m:GetChildren()
				for j = 0, 2 do
					p(
						m,
						"FractalFrond",
						V(len * (1 - j * 0.2), 0.14, 0.28),
						CF(x + s * (len * 0.45 + j * 0.18), y + j * 0.11, 0) * A(0, s * j * 0.2, s * 0.3),
						if j == 0 then c.body else rgb(182, 247, 223),
						j == 2,
						true
					)
				end
				S.motionSince(m, first, "Frond" .. i .. "_" .. s, CF(x, y, 0), "Leaf", s + i * 0.35)
			end
		end
		S.ring(m, "FernOrbit", CF(0, -0.3, 0), 1.3, 0.11, GOLD, true)
		return
	end
	if id == "BonsaiMillenaire" or id == "ArbreMondeMiniature" then
		local big = id == "ArbreMondeMiniature"
		for i = 0, 3 do
			p(
				m,
				"TwistedTrunk",
				V(0.54 - i * 0.06, 0.65, 0.58 - i * 0.05),
				CF(math.sin(i) * 0.24, -0.7 + i * 0.5, 0) * A(0, i * 0.27, math.cos(i) * 0.12),
				rgb(108, 72, 46)
			)
		end
		for _, s in ipairs({ -1, 1 }) do
			link(m, "Branch", V(0, 0.6, 0), V(s * 1, 1.45, 0.13), 0.24, 0.28, rgb(108, 72, 46))
			mass(m, "Canopy", V(1.65, 0.65, 1.4), CF(s * 0.8, 1.64, 0), c.body)
			link(
				m,
				"Root",
				V(0, -0.9, 0),
				V(s * 1.1, -1.2, -0.55),
				0.22,
				0.2,
				if big then c.detail else rgb(108, 72, 46),
				big
			)
		end
		mass(m, "UpperCanopy", V(1.8, 0.7, 1.5), CF(0, 2.14, 0.1), c.light)
		S.eyes(m, CF(0, 0.07, -0.12), 0.48, 0.53, false, if big then c.detail else rgb(85, 206, 255))
		return
	end
	if id == "CactusRonchon" then
		mass(m, "TerracottaPot", V(1.3, 0.8, 1.2), CF(0, -0.85, 0), c.detail)
		p(m, "PotRim", V(1.5, 0.18, 1.4), CF(0, -0.4, 0), c.detail)
		mass(m, "Cactus", V(0.85, 1.65, 0.85), CF(0, 0.5, 0), c.body)
		for _, s in ipairs({ -1, 1 }) do
			p(m, "CactusArm", V(0.7, 0.3, 0.35), CF(s * 0.61, 0.17, 0), c.body)
			p(m, "CactusFinger", V(0.31, 0.7, 0.35), CF(s * 0.9, 0.43, 0), c.body)
		end
		for i = 0, 7 do
			p(
				m,
				"CactusSpine",
				V(0.07, 0.14, 0.1),
				CF(if i % 2 == 0 then -0.3 else 0.3, -0.05 + math.floor(i / 2) * 0.33, -0.47),
				WHITE
			)
		end
		S.eyes(m, CF(0, 0.57, -0.15), 0.85, 0.72, true)
		return
	end
	if id == "ChampignonVeneneux" then
		mass(m, "Stem", V(0.8, 1.4, 0.75), CF(0, -0.25, 0), WHITE)
		mass(m, "MushroomCap", V(2.6, 0.9, 2.2), CF(0, 0.85, 0), c.body)
		p(m, "CapRim", V(2.5, 0.16, 2.05), CF(0, 0.5, 0), c.dark)
		for i = 0, 6 do
			local a = i * 2.4
			p(m, "CapSpot", V(0.3, 0.075, 0.28), CF(math.cos(a) * 0.73, 1.38, math.sin(a) * 0.65), WHITE)
		end
		S.eyes(m, CF(0, -0.2, -0.08), 0.78, 0.8)
		return
	end
	if id == "CarniflorToxique" then
		link(m, "Stalk", V(0, -1, 0), V(0, 0.65, 0.25), 0.42, 0.45, GREEN)
		mass(m, "UpperJaw", V(2.15, 0.95, 1.85), CF(0, 1.15, -0.15) * A(-0.2, 0, 0), c.body)
		mass(m, "LowerJaw", V(1.95, 0.45, 1.8), CF(0, 0.2, -0.3) * A(0.12, 0, 0), c.body)
		p(m, "MouthInterior", V(1.6, 0.35, 1.5), CF(0, 0.61, -0.35), rgb(78, 21, 82))
		teeth(m, CF(0, 0.76, -1.1), 1.85, 9)
		teeth(m, CF(0, 0.5, -1.14) * A(0, 0, math.pi), 1.8, 8)
		S.eyes(m, CF(0, 1.27, -0.42), 1.8, 1.58, true, c.detail)
	else
		local root = id == "NavetPeureux" or id == "PousseHaricot"
		if root then
			mass(m, "RootBulb", V(1.45, 1.6, 1.3), CF(0, -0.15, 0), c.body)
			p(m, "RootTip", V(0.36, 0.6, 0.35), CF(0, -1.13, 0) * A(0, 0, 0.2), c.detail, false, true)
			S.eyes(m, CF(0, 0, -0.11), 1.4, 1.35)
		else
			p(m, "Stem", V(0.22, 1.65, 0.25), CF(0, -0.42, 0), GREEN)
			local lotus = id == "LotusEspace"
			local rose = id == "RoseCristal"
			local clover = id == "Treflant4Feuilles"
			local n = if clover then 4 elseif rose then 7 else 10
			for i = 0, n - 1 do
				local a = i * math.pi * 2 / n
				local f = if lotus
					then CF(math.cos(a) * 0.76, 0.35, math.sin(a) * 0.76) * A(0, -a, 0.5)
					else CF(math.cos(a) * 0.8, 0.8 + math.sin(a) * 0.8, 0) * A(0, 0, a - math.pi / 2)
				mass(
					m,
					"Petal",
					V(if clover then 0.94 else 0.55, if clover then 0.92 else 0.9, if lotus then 0.8 else 0.25),
					f,
					c.body
				)
			end
			if rose then
				for i = 0, 4 do
					p(
						m,
						"CrystalPetal",
						V(0.6, 0.7, 0.23),
						CF(0, 0.85, -0.2) * A(0, 0, i * math.pi * 2 / 5) * CF(0, 0.28, 0),
						c.light,
						false,
						true
					)
				end
			end
			mass(m, "FlowerHeart", V(0.86, 0.86, 0.3), CF(0, 0.8, if lotus then 0 else -0.25), c.detail)
			S.eyes(m, CF(0, 0.8, if lotus then -0.15 else -0.35), 0.75, 0.35)
			if lotus then
				S.ring(m, "GalaxyHeart", CF(0, 1.23, 0) * A(0.2, 0, 0.25), 0.58, 0.08, GOLD, true)
			end
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		p(
			m,
			"Leaf",
			V(0.95, 0.16, 0.48),
			CF(s * 0.5, if id == "NavetPeureux" or id == "PousseHaricot" then 1 else -0.45, 0) * A(0, -s * 0.2, s * 0.5),
			GREEN,
			false,
			true
		)
	end
end

local function golem(m: Model, e: Pet, c: Palette)
	local id = e.Id
	local large = id == "GolemDistributeur"
	mass(m, "Torso", V(if large then 2.2 else 1.5, 1.75, 1.05), CF(), c.body)
	for _, s in ipairs({ -1, 1 }) do
		mass(m, "Shoulder", V(0.7, 0.75, 0.85), CF(s * (if large then 1.37 else 1), 0.43, 0), c.dark)
		p(
			m,
			"Forearm",
			V(0.55, 0.95, 0.65),
			CF(s * (if large then 1.4 else 1.05), -0.45, -0.08) * A(0, 0, s * 0.1),
			c.body
		)
		p(m, "Fist", V(0.65, 0.42, 0.75), CF(s * (if large then 1.43 else 1.1), -1, -0.1), c.detail)
		p(m, "Leg", V(0.6, 0.83, 0.65), CF(s * 0.47, -1.28, 0), c.dark)
		p(m, "Boot", V(0.73, 0.37, 0.97), CF(s * 0.47, -1.88, -0.18), c.body)
	end
	local head = CF(0, 1.35, 0)
	mass(m, "Head", V(1.32, 1.25, 1.12), head, c.body)
	S.eyes(m, head, 1.32, 1.25, id == "GargouilleMignonne", if large then c.detail else nil)
	if large then
		p(m, "VendingFrame", V(1.58, 1.36, 0.16), CF(0, 0, -0.66), c.detail)
		p(m, "VendingGlass", V(1.3, 1.08, 0.1), CF(0, 0.04, -0.77), BLACK)
		for i = 0, 5 do
			p(
				m,
				"Can",
				V(0.25, 0.35, 0.08),
				CF((i % 3 - 1) * 0.38, 0.3 - math.floor(i / 3) * 0.46, -0.86),
				if i % 2 == 0 then rgb(82, 221, 215) else GOLD
			)
		end
		p(m, "Dispenser", V(0.95, 0.16, 0.16), CF(0, -0.67, -0.83), BLACK)
	elseif id == "AstroBoulon" then
		S.ring(m, "HelmetRim", head * CF(0, 0, -0.72) * A(math.pi / 2, 0, 0), 0.59, 0.12, c.detail, false, 8)
		p(m, "ChestPanel", V(0.8, 0.6, 0.11), CF(0, 0, -0.63), c.detail)
		for i = -1, 1 do
			p(m, "PanelButton", V(0.13, 0.13, 0.07), CF(i * 0.22, 0, -0.73), GOLD)
		end
		S.horn(m, head * CF(0.4, 0.65, 0), 0.7, c.detail)
	elseif id == "GargouilleMignonne" then
		S.wings(m, CF(0, 0.6, 0.45), 1.8, c.dark, c.body, false, true)
		for _, s in ipairs({ -1, 1 }) do
			S.horn(m, head * CF(s * 0.43, 0.65, 0.1) * A(0, 0, -s * 0.35), 0.7, c.dark)
		end
	elseif id == "MandragoreHurlante" then
		for _, s in ipairs({ -1, 1 }) do
			p(m, "EarMuff", V(0.28, 0.68, 0.65), head * CF(s * 0.78, 0, 0), c.detail)
		end
		p(m, "Scream", V(0.35, 0.43, 0.08), head * CF(0, -0.31, -0.68), BLACK)
		for i = -1, 1 do
			p(m, "LeafHair", V(0.35, 0.9, 0.2), head * CF(i * 0.3, 0.95, 0) * A(0, 0, -i * 0.25), GREEN, false, true)
		end
	else
		p(m, "CapBrim", V(1.65, 0.13, 1.4), head * CF(0, 0.7, -0.12), c.detail)
		p(m, "Cap", V(1.12, 0.45, 1), head * CF(0, 0.91, 0), c.dark)
		link(m, "BroomHandle", V(1.4, -1.9, -0.8), V(1.2, 1.7, -0.6), 0.13, 0.13, GOLD)
		for i = -2, 2 do
			p(m, "BroomBristle", V(0.13, 0.55, 0.36), CF(1.4 + i * 0.14, -1.86, -0.8), c.detail)
		end
	end
end

local function object(m: Model, e: Pet, c: Palette, kind: string)
	if kind == "Rocks" then
		for i = -1, 1 do
			local first = #m:GetChildren()
			local f = CF(i * 1.2, if i == 0 then 0.4 else 0, 0) * A(0, -i * 0.2, i * 0.1)
			mass(m, "Asteroid", V(1.15, 1.3, 1.1), f, c.body)
			S.eyes(m, f, 1, 1.3, true)
			p(m, "LavaCrack", V(0.09, 0.6, 0.06), f * CF(-0.31, 0.15, -0.63) * A(0, 0, -0.3), c.detail, true)
			S.motionSince(m, first, "Asteroid" .. i, f, "Companion", i * 1.6)
		end
		return
	elseif kind == "Eclipse" then
		for _, s in ipairs({ -1, 1 }) do
			local first = #m:GetChildren()
			local f = CF(s * 0.84, 0, 0)
			mass(m, "CelestialTwin", V(1.55, 1.8, 1.1), f, if s < 0 then c.body else c.detail)
			S.eyes(m, f, 1.3, 1.3, s > 0)
			for i = 0, 5 do
				local a = i * math.pi / 3
				p(
					m,
					"CelestialRay",
					V(0.22, 0.48, 0.23),
					f * CF(math.cos(a) * 0.95, math.sin(a) * 0.98, 0.1) * A(0, 0, a - math.pi / 2),
					if s < 0 then GOLD else WHITE,
					false,
					true
				)
			end
			S.motionSince(m, first, "Twin" .. s, f, "Companion", s * 1.6)
		end
		return
	elseif kind == "Top" then
		for i = 0, 4 do
			local w = 2.4 - math.abs(i - 2) * 0.6
			p(
				m,
				"SpindleTier",
				V(w, 0.33, w),
				CF(0, (i - 2) * 0.32, 0) * A(0, i * 0.15, 0),
				if i % 2 == 0 then c.body else c.detail,
				i % 2 == 1
			)
		end
		p(m, "SpindleTip", V(0.25, 0.65, 0.25), CF(0, -1.03, 0), GOLD, false, true)
		S.ring(m, "Wormhole", CF(0, 0.2, 0) * A(0.25, 0, 0.2), 1.7, 0.09, c.detail, true)
		S.eyes(m, CF(0, 0, -0.55), 1.2, 1.4, true, c.detail)
		return
	elseif kind == "Burrito" then
		mass(m, "Tortilla", V(1.65, 2.6, 1.4), CF() * A(0, 0, -0.1), c.body)
		for i = 0, 4 do
			p(m, "WrapFold", V(1.55, 0.15, 0.12), CF(0, -0.8 + i * 0.31, -0.75) * A(0, 0, 0.18), c.light)
		end
		for i = 0, 6 do
			local a = i * 2.4
			p(
				m,
				"NebulaFilling",
				V(0.35, 0.45, 0.35),
				CF(math.cos(a) * 0.48, 1.36, math.sin(a) * 0.4),
				if i % 2 == 0 then c.detail else rgb(70, 235, 198),
				true
			)
		end
		S.eyes(m, CF(0, 0.4, -0.12), 1.4, 1.5)
		return
	elseif kind == "Mug" then
		p(m, "CupBase", V(1.65, 0.22, 1.5), CF(0, -0.85, 0), c.body)
		for _, s in ipairs({ -1, 1 }) do
			p(m, "CupWall", V(0.17, 1.6, 1.5), CF(s * 0.78, 0, 0), c.body)
			p(m, "CupWall", V(1.4, 1.6, 0.17), CF(0, 0, s * 0.68), c.body)
		end
		S.ring(m, "MugHandle", CF(1.05, 0, 0) * A(0, 0, math.pi / 2), 0.52, 0.19, c.body, false, 8)
		local f = CF(0, 1.02, -0.08)
		mass(m, "PugHead", V(1.2, 1, 1.1), f, c.detail)
		S.eyes(m, f, 1.2, 1.24)
		muzzle(m, f, 1, S.palette(c.detail, c.body))
		for _, s in ipairs({ -1, 1 }) do
			S.ear(m, f * CF(s * 0.56, 0.33, 0), c.dark, c.detail, true)
		end
		return
	end
	local remote = kind == "Remote"
	mass(m, "Chassis", if remote then V(1.1, 2.5, 0.58) else V(2.2, 2.2, 1.55), CF(), c.body)
	if remote then
		for i = 0, 11 do
			p(
				m,
				"Button",
				V(0.19, 0.18, 0.085),
				CF((i % 3 - 1) * 0.27, 0.45 - math.floor(i / 3) * 0.33, -0.36),
				if i < 3 then c.detail else c.light,
				i < 3
			)
		end
		S.eyes(m, CF(0, 0.82, -0.14), 0.87, 0.59, true, c.detail)
	elseif kind == "Satellite" then
		for _, s in ipairs({ -1, 1 }) do
			p(m, "PanelStrut", V(1, 0.15, 0.15), CF(s * 1.42, 0, 0), c.dark)
			p(m, "SolarPanel", V(1.48, 1.7, 0.12), CF(s * 2.12, 0, 0), c.detail)
			for i = 0, 2 do
				for j = 0, 2 do
					p(
						m,
						"SolarCell",
						V(0.39, 0.44, 0.035),
						CF(s * 2.12 + (i - 1) * 0.46, (j - 1) * 0.52, -0.09),
						rgb(20, 49, 112)
					)
				end
			end
		end
		S.eyes(m, CF(0, 0, -0.3), 1.6, 1.3, true)
		S.horn(m, CF(0, 1.1, 0), 1.05, c.detail)
	elseif kind == "Washer" then
		local f = CF(0, -0.14, -0.95) * A(math.pi / 2, 0, 0)
		S.ring(m, "DoorRim", f, 0.72, 0.18, c.detail, false, 12)
		p(m, "Drum", V(1, 1, 0.1), CF(0, -0.14, -0.91), BLACK)
		S.ring(m, "GalaxyDrum", f * CF(0, 0.06, 0), 0.45, 0.08, rgb(192, 135, 255), true, 8)
		p(m, "ControlPanel", V(1.75, 0.3, 0.15), CF(0, 0.83, -0.92), c.detail)
		for i = -2, 2 do
			p(m, "Control", V(0.16, 0.12, 0.05), CF(i * 0.26, 0.83, -1.03), WHITE, true)
		end
	else -- Toaster dragon
		S.eyes(m, CF(0, 0.1, -0.33), 1.65, 1.4, true)
		for _, s in ipairs({ -1, 1 }) do
			p(m, "ToastSlot", V(1.3, 0.06, 0.22), CF(0, 1.25, s * 0.35), BLACK)
			mass(m, "Toast", V(1.1, 0.65, 0.19), CF(0, 1.48, s * 0.35), c.detail)
			p(m, "ToastCrumb", V(0.78, 0.36, 0.04), CF(0, 1.5, s * 0.35 - 0.14), WHITE)
			S.horn(m, CF(s * 0.78, 1.1, 0), 0.7, c.dark)
		end
		S.wings(m, CF(0, 0.5, 0.2), 1.95, c.body, c.detail, false, true)
		teeth(m, CF(0, -0.5, -0.95), 1.3, 6)
	end
	for _, s in ipairs({ -1, 1 }) do
		p(m, "Foot", V(0.42, 0.3, 0.66), CF(s * 0.68, -1.4, -0.14), c.dark)
	end
end

function Models.Build(e: Pet): Model
	local kind = families[e.Id]
	assert(kind, "Missing sculpted pet: " .. e.Id)
	local m = Instance.new("Model")
	m.Name = e.Id
	local root = p(m, "Root", V(0.1, 0.1, 0.1), CF(), WHITE)
	root.Transparency = 1
	m.PrimaryPart = root
	local c = S.palette(e.Look.Body, e.Look.Detail)
	if kind == "Beast" then
		beast(m, e, c)
	elseif kind == "Bird" then
		bird(m, e, c)
	elseif kind == "Fish" then
		fish(m, e, c)
	elseif kind == "Dragon" or kind == "Dino" then
		dragon(m, e, c, kind == "Dino")
	elseif kind == "Snake" then
		snake(m, e, c)
	elseif kind == "Plant" then
		plant(m, e, c)
	elseif kind == "Golem" then
		golem(m, e, c)
	elseif
		kind == "Frog"
		or kind == "Hamster"
		or kind == "Spirit"
		or kind == "Slime"
		or kind == "Kraken"
		or kind == "Pumpkin"
		or kind == "Star"
		or kind == "Moon"
	then
		small(m, e, c, kind)
	else
		object(m, e, c, kind)
	end
	-- Centre visible geometry before adding effects, then apply the size scale (shared/PetSizes).
	local box, size = m:GetBoundingBox()
	for _, d in ipairs(m:GetChildren()) do
		if d:IsA("BasePart") and d ~= root then
			d.CFrame = CF(-box.Position) * d.CFrame
		end
	end
	m:ScaleTo(PetSizes.ScaleFor(e.Id, e.Rarity, size))
	local visualBox, visualSize = m:GetBoundingBox()
	m:SetAttribute("BodyCenter", visualBox.Position / m:GetScale())
	m:SetAttribute("BodySize", visualSize / m:GetScale())
	m:SetAttribute("Float", e.Look.Float == true)
	m:SetAttribute("VisualStyle", "SculptedBlocksV2")
	Motion.Prepare(m, e, kind, box.Position)
	FX.Add(m, e, visualBox, visualSize)
	return m
end

return Models
