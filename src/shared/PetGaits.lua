--!strict
-- PetGaits : la démarche propre à chaque familier (Chouaib, 25 oct. : « chaque familier doit avoir une manière de
-- bouger et de se déplacer propre à lui »). Une fiche par familier refait en briques (dataset_and_pipeline), lue par :
--   shared/PetWander  : vitesse, pauses et accélération des trajets dans la base (choisis par le serveur) ;
--   client/BasePets   : déplacement du modèle entier (pas, bonds, roulis, ondulation, envol, roue...) ;
--   shared/PetMotion  : gestes des pièces (cadence et amplitude des pattes, tête, queue, ailes, corps).
-- Les familiers sans fiche gardent l'ancien style de leur silhouette (PetWander.styleFor, profils de famille).
-- Distances en studs pour un familier de 6 studs de haut (client/BasePets les met à l'échelle de sa taille).

export type Gait = {
	-- trajets (PetWander)
	speed: number, -- studs / s
	minWait: number, -- pause entre deux trajets (s)
	maxWait: number,
	ease: string, -- "Linear" | "Smooth" | "Dash" (part vite, freine) | "Pounce" (s'approche puis bondit) | "Pulse" (par poussées)
	-- déplacement du modèle entier (client/BasePets)
	hover: number, -- hauteur de vol (0 = au sol)
	perch: boolean?, -- ne vole que pendant les trajets : décolle, puis se pose
	float: number?, -- flottement au repos (amplitude)
	floatRate: number?,
	step: number?, -- longueur d'un pas : une secousse par pas
	bob: number?, -- par pas : saut du corps
	roll: number?, -- par pas : roulis d'une épaule à l'autre
	wiggle: number?, -- par pas : lacet (le corps se tortille)
	rock: number?, -- par pas : tangage (cheval à bascule)
	hop: number?, -- bonds : hauteur
	hopLength: number?, -- bonds : longueur
	pounce: number?, -- bond final (ease « Pounce »)
	sway: number?, -- ondulation sur le côté (en S)
	swayLength: number?,
	lean: number?, -- penché en avant en marchant (rad, négatif = nez vers le bas)
	bank: number?, -- s'incline dans les virages
	drift: number?, -- dérive au hasard autour de sa position
	wheel: boolean?, -- roule comme une roue le long du trajet
	spin: number?, -- tourne sur lui-même au repos (rad / s)
	turn: number?, -- vitesse pour se tourner vers sa destination
	roam: number?, -- longueur maximale d'un trajet (studs) : les casaniers font de petits tours
	-- gestes (PetMotion)
	stride: number, -- cadence des pattes
	swing: number, -- amplitude des pattes
	airSwing: number?, -- amplitude des pattes en vol (0,15 par défaut)
	body: string, -- "Breath" | "Heavy" | "Wobble" | "Pulse" | "Squish" | "Shiver"
	head: string, -- "Look" | "Bob" | "Peck" | "Swivel" | "Howl" | "Roar" | "Sniff" | "Sway" | "Nod" | "Proud"
	tail: string, -- "Sway" | "Wag" | "Flick" | "Swish" | "Fan" | "Stiff" | "Flow"
	wing: string, -- "Flap" | "Glide" | "Buzz" | "Fold" | "Slow" | "Flit" | "Flutter"
	flicker: number?, -- vitesse des flammes / fumée (pièces « Leaf »)
}

local PetGaits = {}

local DEFAULT: Gait = {
	speed = 5,
	minWait = 1,
	maxWait = 4,
	ease = "Smooth",
	hover = 0,
	stride = 1,
	swing = 1,
	body = "Breath",
	head = "Look",
	tail = "Sway",
	wing = "Flap",
}

local function gait(fields: { [string]: any }): Gait
	local g = table.clone(DEFAULT) :: { [string]: any }
	for key, value in pairs(fields) do
		g[key] = value
	end
	return (g :: any) :: Gait
end

PetGaits.ById = {
	-- Animaux --------------------------------------------------------------------------------------------------
	-- chat des rues : rôde au ras du sol, s'approche lentement puis bondit ; queue qui fouette
	ChatRuelle = gait({ speed = 4.5, minWait = 2, maxWait = 6, ease = "Pounce", pounce = 1.3, step = 1.4, bob = 0.05,
		roll = 0.03, lean = -0.06, turn = 4, stride = 0.9, swing = 0.8, tail = "Flick" }),
	-- pigeon : se dandine à petits pas rapides, tête qui avance et recule, picore à l'arrêt
	PigeonVilles = gait({ speed = 3.2, minWait = 1, maxWait = 3.5, ease = "Linear", roam = 7, step = 0.6, bob = 0.08,
		roll = 0.13, stride = 1.9, swing = 1.1, head = "Bob", tail = "Fan", wing = "Fold" }),
	-- grenouille : grands bonds, longues pauses à gonfler la gorge
	GrenouilleGlobuleuse = gait({ speed = 5, minWait = 1.5, maxWait = 5, ease = "Linear", hop = 2.2, hopLength = 3.5,
		stride = 1, swing = 1 }),
	-- chien saucisse : trottine à toute vitesse sur ses pattes courtes, le long corps se tortille, queue qui frétille
	ChienSaucisse = gait({ speed = 6, minWait = 0.5, maxWait = 2.5, ease = "Linear", step = 0.7, bob = 0.06,
		wiggle = 0.12, stride = 2.3, swing = 1.1, head = "Sniff", tail = "Wag" }),
	-- hamster : sprints courts puis freinage, mille petits pas, s'arrête souvent
	HamsterJoufflu = gait({ speed = 7, minWait = 0.5, maxWait = 2.5, ease = "Dash", roam = 12, step = 0.5, bob = 0.12,
		roll = 0.04,
		turn = 10, stride = 2.6, swing = 1.2 }),
	-- renard : trotte en furtif, renifle, et finit par le bond du renard qui chasse la souris
	RenardFurtif = gait({ speed = 5.5, minWait = 1, maxWait = 4, ease = "Pounce", pounce = 1.7, step = 1.3, bob = 0.08,
		lean = -0.05, stride = 1.1, swing = 0.9, head = "Sniff", tail = "Swish" }),
	-- corbeau : avance par petits sauts à pieds joints, picore
	CorbeauVoleur = gait({ speed = 3.5, minWait = 0.8, maxWait = 3, ease = "Linear", roam = 9, hop = 0.7, hopLength = 1.2,
		stride = 1, swing = 0.6, head = "Peck", tail = "Fan", wing = "Fold" }),
	-- hibou : reste perché longtemps, tourne la tête presque à l'envers, ne vole que pour changer de place
	HibouGrincheux = gait({ speed = 6, minWait = 4, maxWait = 9, ease = "Smooth", hover = 4, perch = true,
		head = "Swivel", wing = "Flit", tail = "Fan" }),
	-- loup polaire : trot régulier, hurle de temps en temps
	LoupPolaire = gait({ speed = 6, minWait = 1, maxWait = 4, ease = "Linear", step = 1.8, bob = 0.15, roll = 0.04,
		stride = 1, swing = 1.1, head = "Howl" }),
	-- panthère : glisse sans bruit, très basse, puis bondit
	PanthereNeon = gait({ speed = 5, minWait = 2, maxWait = 6, ease = "Pounce", pounce = 1.4, step = 1.8, bob = 0.04,
		lean = -0.05, turn = 4, stride = 0.8, swing = 0.9, tail = "Flick" }),
	-- tigre : pas lourds et lents, épaules qui roulent, rugit
	TigreBengal = gait({ speed = 4, minWait = 2, maxWait = 6, ease = "Smooth", step = 2.2, bob = 0.06, roll = 0.07,
		turn = 3, stride = 0.75, swing = 1, body = "Heavy", head = "Roar", tail = "Flick" }),
	-- aigle : plane très haut, s'incline dans les virages, quelques battements d'ailes
	AigleRoyal = gait({ speed = 7, minWait = 0.5, maxWait = 2, ease = "Smooth", hover = 6, float = 0.8, floatRate = 0.8,
		bank = 0.5, turn = 2.5, head = "Proud", wing = "Glide", tail = "Fan" }),
	-- requin volant : nage dans l'air en S, coups de queue
	RequinVolant = gait({ speed = 5, minWait = 0.5, maxWait = 2, ease = "Smooth", hover = 3, float = 0.5,
		floatRate = 1.2, sway = 0.6, swayLength = 6, bank = 0.3, turn = 3 }),
	-- T-Rex de poche : pas lourds qui secouent tout, penché en avant, rugit gueule grande ouverte
	TRexPoche = gait({ speed = 3.5, minWait = 1.5, maxWait = 5, ease = "Linear", step = 1.6, bob = 0.14, roll = 0.09,
		wiggle = 0.06, lean = -0.08, stride = 0.8, swing = 1.2, body = "Heavy", head = "Roar", tail = "Stiff" }),
	-- capybara zen : se traîne tranquillement, longues siestes, la tête qui pique du nez
	CapybaraZen = gait({ speed = 2, minWait = 5, maxWait = 12, ease = "Smooth", roam = 8, step = 1.6, bob = 0.06,
		roll = 0.03,
		turn = 2, stride = 0.6, swing = 0.7, head = "Nod" }),
	-- Cerbère Infernal (Sigma du Volcan) : pas lourds, souffle, têtes qui aboient
	CerbereInfernal = gait({ speed = 4, minWait = 1.5, maxWait = 5, ease = "Smooth", step = 2, bob = 0.1, roll = 0.05,
		turn = 3, stride = 0.85, swing = 1, body = "Heavy" }),

	-- Fantastiques ---------------------------------------------------------------------------------------------
	-- feu follet : file d'un coup puis s'arrête, tremblote et dérive, flammes vives
	FeuFollet = gait({ speed = 7, minWait = 0.5, maxWait = 3, ease = "Dash", hover = 2.5, float = 0.5, floatRate = 2.6,
		drift = 0.6, turn = 10, body = "Wobble", flicker = 3 }),
	-- slime : rebondit en tremblotant
	SlimeGlgl = gait({ speed = 4, minWait = 1, maxWait = 4, ease = "Linear", hop = 1, hopLength = 1.6, body = "Squish" }),
	-- bébé griffon : trotte en sautillant, petites ailes qui battent quand il court
	BebeGriffon = gait({ speed = 5.5, minWait = 1, maxWait = 3.5, ease = "Linear", step = 1.2, bob = 0.22, roll = 0.06,
		stride = 1.4, swing = 1.1, wing = "Flutter", tail = "Swish" }),
	-- gargouille : se dandine lourdement sur ses pattes de pierre
	GargouilleMignonne = gait({ speed = 3, minWait = 1.5, maxWait = 5, ease = "Linear", roam = 12, step = 0.9, bob = 0.08,
		roll = 0.15, stride = 1.4, swing = 1, wing = "Fold" }),
	-- licorne : trot dansant, genoux hauts, tête fière
	LicorneBois = gait({ speed = 4.5, minWait = 1, maxWait = 4, ease = "Linear", step = 1.5, bob = 0.3, rock = 0.08,
		stride = 1.1, swing = 1.4, head = "Proud", tail = "Swish" }),
	-- phénix de cendres : petits sauts fatigués, pique du nez, fumée lente
	PhenixCendres = gait({ speed = 2.5, minWait = 2, maxWait = 6, ease = "Linear", roam = 8, hop = 0.5, hopLength = 1,
		head = "Nod", wing = "Fold", tail = "Fan", flicker = 0.7 }),
	-- cerbère chiot : chiot fou, sprints et rebonds, trois têtes curieuses, queue qui frétille
	CerbereChiot = gait({ speed = 6.5, minWait = 0.5, maxWait = 2.5, ease = "Dash", step = 1, bob = 0.25, roll = 0.08,
		turn = 9, stride = 1.6, swing = 1.2, tail = "Wag" }),
	-- dragonnet : vole bas en bourdonnant, file par à-coups, s'incline fort
	DragonnetObsidienne = gait({ speed = 7, minWait = 0.5, maxWait = 2, ease = "Dash", hover = 3, float = 0.4,
		floatRate = 3.2, bank = 0.6, turn = 8, wing = "Buzz" }),
	-- pégase : galope dans le ciel, grands battements lents
	PegaseNuageux = gait({ speed = 6, minWait = 1, maxWait = 3, ease = "Smooth", hover = 4, float = 0.7, floatRate = 1,
		step = 2.4, bob = 0.25, rock = 0.1, bank = 0.3, stride = 1, swing = 1.3, airSwing = 1.2, head = "Proud",
		wing = "Slow", tail = "Flow" }),
	-- kitsune : longs bonds gracieux, trois queues qui ondulent chacune à son rythme
	Kitsune3Queues = gait({ speed = 6, minWait = 1, maxWait = 4, ease = "Linear", hop = 1, hopLength = 3, lean = -0.04,
		stride = 1.2, swing = 1, tail = "Flow" }),
	-- kraken : rampe par poussées de tentacules, monte et redescend
	KrakenBaignoire = gait({ speed = 2.5, minWait = 2, maxWait = 6, ease = "Pulse", roam = 10, step = 2, bob = 0.2, turn = 3,
		body = "Pulse" }),
	-- basilic : ondule en S, tête qui se balance pour hypnotiser
	BasilicEmeraude = gait({ speed = 3, minWait = 1, maxWait = 4, ease = "Smooth", sway = 0.7, swayLength = 4, turn = 3,
		head = "Sway" }),
	-- léviathan : nage dans l'air en grandes vagues, gueule qui s'ouvre
	LeviathanAbyssal = gait({ speed = 4, minWait = 0.5, maxWait = 2.5, ease = "Smooth", hover = 4, float = 1,
		floatRate = 0.7, sway = 0.8, swayLength = 8, bank = 0.3, turn = 2, head = "Roar" }),
	-- phénix solaire : plane majestueusement, grands battements lents, flammes vives
	PhenixSolaire = gait({ speed = 6, minWait = 1, maxWait = 3, ease = "Smooth", hover = 6, float = 1.2,
		floatRate = 0.6, bank = 0.6, turn = 2.5, head = "Proud", wing = "Slow", tail = "Flow", flicker = 2.5 }),
	-- ouroboros : roule comme une roue d'or, tourne lentement sur lui-même à l'arrêt
	OuroborosInfini = gait({ speed = 3, minWait = 2, maxWait = 5, ease = "Smooth", hover = 1, float = 0.4,
		floatRate = 1.2, wheel = true, spin = 0.35 }),

	-- Plantes ---------------------------------------------------------------------------------------------------
	-- pousse de haricot : petits sauts avec son tas de terre, la pousse se balance et regarde partout
	PousseHaricot = gait({ speed = 3, minWait = 1.5, maxWait = 5, ease = "Linear", roam = 8, hop = 0.5, hopLength = 1.2 }),
	-- cactus ronchon : se dandine de mauvaise grâce dans son pot, souvent immobile
	CactusRonchon = gait({ speed = 2.5, minWait = 3, maxWait = 8, ease = "Linear", roam = 8, step = 0.8, bob = 0.05,
		roll = 0.16, turn = 3, stride = 1.2 }),
	-- navet peureux : s'enfuit en courant sur ses petites racines, grelotte à l'arrêt
	NavetPeureux = gait({ speed = 7, minWait = 0.5, maxWait = 3, ease = "Dash", roam = 14, step = 0.45, bob = 0.1,
		roll = 0.05, turn = 12, stride = 2.8, swing = 1.4, body = "Shiver" }),
	-- tournesol : se dandine joyeusement dans son pot, la fleur bien droite vers le soleil
	TournesolJoyeux = gait({ speed = 3, minWait = 2, maxWait = 5, ease = "Smooth", roam = 10, step = 1, bob = 0.1,
		roll = 0.1, head = "Proud" }),
	-- amanite : rebondit comme un ressort
	ChampignonVeneneux = gait({ speed = 3.5, minWait = 1, maxWait = 4, ease = "Linear", roam = 10, hop = 0.8,
		hopLength = 1.4, body = "Squish" }),
	-- citrouille : lourds petits bonds qui tremblotent
	CitrouilleSculptee = gait({ speed = 3, minWait = 1.5, maxWait = 4.5, ease = "Linear", roam = 10, hop = 0.5,
		hopLength = 1.6, body = "Squish" }),
	-- bonsaï : glisse à peine, très lentement ; son esprit flotte autour
	BonsaiMillenaire = gait({ speed = 1.2, minWait = 6, maxWait = 12, ease = "Smooth", roam = 6, step = 1.5, bob = 0.02,
		roll = 0.03, turn = 1.5 }),
	-- rose de cristal : glisse gracieusement et tourne lentement sur elle-même
	RoseCristal = gait({ speed = 2.5, minWait = 2, maxWait = 6, ease = "Smooth", roam = 10, step = 1.2, roll = 0.06,
		spin = 0.25, turn = 2, head = "Proud" }),
	-- mandragore : court en hurlant, bras en l'air
	MandragoreHurlante = gait({ speed = 7.5, minWait = 0.5, maxWait = 2.5, ease = "Dash", step = 0.6, bob = 0.14,
		roll = 0.08, turn = 10, stride = 2.4, swing = 1.4, head = "Roar" }),
	-- tréflant : roule comme une roue en semant ses pièces
	Treflant4Feuilles = gait({ speed = 4, minWait = 1, maxWait = 4, ease = "Smooth", wheel = true, spin = 0.3 }),
	-- lotus de l'espace : flotte et tourne lentement, sa galaxie tourne au-dessus
	LotusEspace = gait({ speed = 2.5, minWait = 1, maxWait = 4, ease = "Smooth", hover = 2.5, float = 0.5,
		floatRate = 0.9, spin = 0.25, bank = 0.2, turn = 2 }),
	-- arbre-monde : avance très lentement par poussées de racines, lourd
	ArbreMondeMiniature = gait({ speed = 1.2, minWait = 8, maxWait = 15, ease = "Pulse", roam = 6, step = 2.4,
		bob = 0.04, roll = 0.04, turn = 1.5, body = "Heavy" }),
	-- carniflore : s'approche et se jette sur sa proie, la mâchoire claque
	CarniflorToxique = gait({ speed = 4, minWait = 1.5, maxWait = 5, ease = "Pounce", roam = 10, pounce = 0.6, step = 1,
		roll = 0.08, turn = 6, head = "Roar" }),
	-- graine d'étoile : flotte, dérive et tourne, ses anneaux tournent en sens inverse
	GraineEtoile = gait({ speed = 3.5, minWait = 1, maxWait = 4, ease = "Smooth", hover = 2, float = 0.6, floatRate = 1.4,
		drift = 0.3, spin = 0.5 }),
	-- fougère de Fibonacci : flotte lentement, ses frondes ondulent
	FougereFibonacci = gait({ speed = 2, minWait = 2, maxWait = 6, ease = "Smooth", hover = 2.5, float = 0.5,
		floatRate = 0.7, spin = 0.15, bank = 0.15, turn = 2, flicker = 0.6 }),

	-- Hybrides --------------------------------------------------------------------------------------------------
	-- chat-coptère : vole en tanguant comme un hélicoptère, pattes qui pendent
	ChatCoptere = gait({ speed = 5, minWait = 1, maxWait = 3.5, ease = "Smooth", hover = 3, float = 0.5, floatRate = 2,
		bank = 0.4, turn = 4, airSwing = 0.6 }),
	-- tortue-burger : avance tout doucement en se balançant sous son burger
	TortueBurger = gait({ speed = 1.8, minWait = 3, maxWait = 8, ease = "Linear", roam = 8, step = 0.9, bob = 0.03,
		roll = 0.07, turn = 2, stride = 0.7, swing = 0.8 }),
	-- poisson-ampoule : nage dans l'air en ondulant, sa lanterne se balance
	PoissonAmpoule = gait({ speed = 3.5, minWait = 1, maxWait = 3.5, ease = "Smooth", hover = 2.5, float = 0.5,
		floatRate = 1.3, sway = 0.5, swayLength = 5, bank = 0.25, turn = 3 }),
	-- cochon-tirelire : trottine en se dandinant, la queue en tire-bouchon frétille
	CochonTirelire = gait({ speed = 4, minWait = 1, maxWait = 4, ease = "Linear", roam = 12, step = 0.7, bob = 0.1,
		roll = 0.1, stride = 1.6, swing = 1, tail = "Wag" }),
	-- tasse-chien : la tasse avance par petits sauts, le carlin regarde partout
	TasseChien = gait({ speed = 3, minWait = 1.5, maxWait = 5, ease = "Linear", roam = 10, hop = 0.4, hopLength = 1 }),
	-- corbeau-horloge : sautille mécaniquement, picore, ses engrenages tournent
	CorbeauHorloge = gait({ speed = 3, minWait = 1, maxWait = 4, ease = "Linear", roam = 10, hop = 0.5, hopLength = 1,
		head = "Peck", wing = "Fold", tail = "Fan" }),
	-- banane-chien : trotte joyeusement en se tortillant, renifle, frétille de la queue
	BananeChien = gait({ speed = 5.5, minWait = 0.5, maxWait = 3, ease = "Linear", step = 1.1, bob = 0.15, roll = 0.05,
		wiggle = 0.06, stride = 1.3, swing = 1.1, head = "Sniff", tail = "Wag" }),
	-- hibou-caméra : reste posé à filmer en tournant la tête, s'envole pour changer de place
	HibouCamera = gait({ speed = 5, minWait = 4, maxWait = 8, ease = "Smooth", hover = 3.5, perch = true, head = "Swivel",
		wing = "Flit", tail = "Fan" }),
	-- requin-torpille : fonce à toute vitesse dans l'air, réacteur à fond
	RequinTorpille = gait({ speed = 9, minWait = 1, maxWait = 3, ease = "Dash", hover = 3, float = 0.4, sway = 0.4,
		swayLength = 8, bank = 0.5, turn = 4, flicker = 3 }),
	-- pégase-moto : galop mécanique, crinière au vent
	PegaseMoto = gait({ speed = 7, minWait = 1, maxWait = 3, ease = "Linear", step = 1.8, bob = 0.22, rock = 0.08,
		roll = 0.03, stride = 1.2, swing = 1.4, head = "Proud", wing = "Fold", tail = "Swish" }),
	-- dragon-grille-pain : se dandine lourdement, bat des ailes, rugit et fait sauter ses tartines
	DragonGrillePain = gait({ speed = 3, minWait = 1.5, maxWait = 4, ease = "Linear", roam = 12, step = 0.8, bob = 0.06,
		roll = 0.12, stride = 1.5, swing = 1, head = "Roar", wing = "Buzz" }),
	-- T-Rex tank : pas lourds qui font trembler, rugit, sa tourelle balaie l'horizon
	TRexTank = gait({ speed = 3, minWait = 2, maxWait = 5, ease = "Linear", step = 1.6, bob = 0.12, roll = 0.08,
		wiggle = 0.05, lean = -0.06, turn = 2.5, stride = 0.8, swing = 1.2, body = "Heavy", head = "Roar", tail = "Stiff" }),
	-- golem distributeur : marche lente et pesante, balance les bras
	GolemDistributeur = gait({ speed = 2.2, minWait = 3, maxWait = 7, ease = "Smooth", step = 1.4, bob = 0.1, roll = 0.1,
		turn = 2, stride = 0.7, swing = 1, body = "Heavy" }),
	-- lion enceinte : se pavane au rythme de ses basses
	LionEnceinte = gait({ speed = 4.5, minWait = 1.5, maxWait = 4, ease = "Linear", step = 1.6, bob = 0.12, roll = 0.05,
		stride = 1, swing = 1.1, tail = "Swish" }),
	-- canard-tractopelle : roule sur ses chenilles sans à-coups, tourne lentement comme un engin, creuse avec son bras
	CanardTractopelle = gait({ speed = 2.5, minWait = 2, maxWait = 5, ease = "Smooth", step = 3, bob = 0.02, rock = 0.02,
		turn = 1.5, head = "Proud" }),

	-- Absurdes ----------------------------------------------------------------------------------------------------
	-- astro-boulon : marche de robot un peu bancale, ça grince
	AstroBoulon = gait({ speed = 3.2, minWait = 1, maxWait = 4, ease = "Linear", roam = 12, step = 0.7, bob = 0.08,
		roll = 0.1, stride = 1.6, swing = 0.9 }),
	-- autruche-fusée : sprints propulsés, penchée en avant, la tête qui va et vient
	AutrucheFusee = gait({ speed = 10, minWait = 0.5, maxWait = 2.5, ease = "Dash", step = 1.6, bob = 0.18, lean = -0.12,
		turn = 8, stride = 1.4, swing = 1.5, head = "Bob", wing = "Flutter", flicker = 3 }),
	-- myrtille lunaire : grands bonds lents comme sur la Lune
	MyrtilleLunaire = gait({ speed = 2.5, minWait = 2, maxWait = 5, ease = "Linear", hop = 1.2, hopLength = 3,
		body = "Squish" }),
	-- concierge cosmique : traîne les pieds en balayant, fatigué
	ConciergeCosmique = gait({ speed = 2, minWait = 3, maxWait = 7, ease = "Smooth", roam = 6, step = 0.6, bob = 0.04,
		roll = 0.06, stride = 1.2, swing = 1.3, head = "Nod" }),
	-- mouton météore : trottine tranquillement, la laine en feu
	MoutonMeteore = gait({ speed = 3.5, minWait = 1.5, maxWait = 4, ease = "Linear", step = 1.2, bob = 0.1, roll = 0.05,
		stride = 1, swing = 1, tail = "Wag", flicker = 2 }),
	-- télécommande perdue : flotte, dérive et tourne sur elle-même, cherche d'où elle vient
	TelecommandePerdue = gait({ speed = 2.5, minWait = 1, maxWait = 4, ease = "Smooth", hover = 2, float = 0.5,
		floatRate = 1.1, drift = 0.4, spin = 0.4 }),
	-- satellite ronchon : gravite lentement en grésillant
	SatelliteRonchon = gait({ speed = 2.5, minWait = 1, maxWait = 4, ease = "Smooth", hover = 3, float = 0.4,
		floatRate = 0.7, spin = 0.3, bank = 0.3, turn = 2, body = "Wobble" }),
	-- pingouin comète : glisse sur le ventre à toute vitesse en zigzag
	PingouinComete = gait({ speed = 9, minWait = 1, maxWait = 3, ease = "Dash", sway = 0.3, swayLength = 6, bank = 0.4,
		turn = 3, wing = "Flutter" }),
	-- burrito nébuleuse : petits sauts mous
	BurritoNebuleuse = gait({ speed = 2.5, minWait = 2, maxWait = 5, ease = "Linear", roam = 10, hop = 0.3,
		hopLength = 0.8, body = "Squish" }),
	-- trio d'astéroïdes : dérivent lentement ensemble, les petits tournent autour du gros
	TrioAsteroides = gait({ speed = 2, minWait = 2, maxWait = 5, ease = "Smooth", hover = 2.5, float = 0.6,
		floatRate = 0.8, turn = 1.5 }),
	-- jumeaux éclipse : flottent en tournant lentement, chacun veut être devant
	JumeauxEclipse = gait({ speed = 2.5, minWait = 1, maxWait = 4, ease = "Smooth", hover = 3, float = 0.5,
		floatRate = 0.6, spin = 0.3 }),
	-- toupie trou-de-ver : tourne à toute vitesse en titubant
	ToupieTrouDeVer = gait({ speed = 4, minWait = 0.5, maxWait = 3, ease = "Smooth", hover = 1.5, float = 0.3, spin = 4,
		drift = 0.3, body = "Wobble" }),
	-- machine à laver quantique : sautille en essorage, tremble de partout
	MachineQuantique = gait({ speed = 2.5, minWait = 1, maxWait = 4, ease = "Linear", roam = 10, hop = 0.35,
		hopLength = 0.7, body = "Shiver" }),
	-- dragon aurore : vol gracieux et lent, grands battements
	DragonAurore = gait({ speed = 5, minWait = 1, maxWait = 3, ease = "Smooth", hover = 4, float = 0.8, floatRate = 0.7,
		bank = 0.5, turn = 2.5, airSwing = 0.3, head = "Proud", wing = "Slow", tail = "Flow" }),
	-- baleine galaxie : nage majestueuse dans le ciel, en grandes ondulations
	BaleineGalaxie = gait({ speed = 3, minWait = 2, maxWait = 5, ease = "Smooth", hover = 4, float = 1, floatRate = 0.4,
		sway = 0.6, swayLength = 10, bank = 0.25, turn = 1.2 }),
} :: { [string]: Gait }

-- Fiche du familier (formes évoluées et mutations comprises : « <Id>__E2 », « <Id>__MGold »...), ou nil.
function PetGaits.For(petId: string): Gait?
	local base = string.match(petId, "^(.-)__") or petId
	return PetGaits.ById[base]
end

return PetGaits
