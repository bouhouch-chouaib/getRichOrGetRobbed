--!strict
-- PetSizes : l'échelle des familiers (référentiel unique pour la base, le suivi, le vol et les effets).
--
-- Unité : « J » = la taille d'un avatar Roblox (≈ 5 studs). 1 J = grand comme le joueur.
--
-- Chaque rareté a sa tranche de tailles, sans chevauchement : plus c'est rare, plus c'est grand.
-- Dans une tranche, chaque espèce a SA taille, selon ce qu'elle est (un pigeon est plus petit qu'un chat,
-- un dragon plus grand qu'un hibou). Pour ajouter un familier : choisir sa taille dans la tranche de sa rareté.
-- 13 oct. : échelle resserrée (avant 0,7 à 7,5 J) pour que la base reste lisible même pleine de familiers rares.
--
--   Rareté       Tranche (J)    En studs     Repère
--   Commun       0,5 - 0,65     2,5 - 3,3    à mi-hauteur du joueur
--   Inhabituel   0,65 - 0,8     3,3 - 4
--   Rare         0,8 - 0,95     4 - 4,8      presque le joueur
--   Épique       0,95 - 1,15    4,8 - 5,8    comme le joueur
--   Légendaire   1,15 - 1,4     5,8 - 7      dépasse le joueur
--   Mythique     1,4 - 1,7      7 - 8,5
--   Divin        1,75 - 2,15    8,8 - 10,8   deux fois le joueur
--   Sigma        2,3 - 2,9      11,5 - 14,5  le géant de la base
--
-- La taille est la HAUTEUR. Les familiers longs (serpents, poissons, baleine) sont limités en longueur
-- (LONG_RATIO x leur taille, MAX_FOOTPRINT au total) pour laisser de la place dans la base (56 x 56).
local Config = require(script.Parent.Config)

local PetSizes = {}

PetSizes.PLAYER = 5 -- studs : hauteur d'un avatar (1 J)
PetSizes.LONG_RATIO = 2 -- longueur max = 2 x la taille
PetSizes.MAX_FOOTPRINT = 26 -- studs : longueur / largeur max au sol (la base fait 56 x 56)
PetSizes.FOLLOW_MAX = 1.6 -- J : un familier équipé qui suit le joueur ne dépasse pas 2 J (sinon il cache la vue)
PetSizes.CARRY_MAX = 1 -- J : un familier porté à bout de bras au-dessus de la tête ne dépasse pas 1 J (il cacherait la vue)

PetSizes.Bands = {
	Commun = { 0.5, 0.65 },
	Inhabituel = { 0.65, 0.8 },
	Rare = { 0.8, 0.95 },
	Epique = { 0.95, 1.15 },
	Legendaire = { 1.15, 1.4 },
	Mythique = { 1.4, 1.7 },
	Divin = { 1.75, 2.15 },
	Sigma = { 2.3, 2.9 },
} :: { [string]: { number } }

-- Taille de chaque familier, en J.
PetSizes.Heights = {
	-- Commun (0,5 - 0,65)
	PigeonVilles = 0.5, -- un pigeon reste un pigeon
	FeuFollet = 0.5,
	ChienSaucisse = 0.51, -- bas sur pattes, mais très long
	PousseHaricot = 0.525,
	ChatRuelle = 0.55,
	SlimeGlgl = 0.55,
	TortueBurger = 0.55,
	CactusRonchon = 0.575,
	ChatCoptere = 0.6, -- hélice comprise
	AstroBoulon = 0.625,
	AutrucheFusee = 0.65, -- le grand cou

	-- Inhabituel (0,65 - 0,8)
	GrenouilleGlobuleuse = 0.65,
	HamsterJoufflu = 0.65,
	MyrtilleLunaire = 0.675,
	NavetPeureux = 0.675,
	PoissonAmpoule = 0.7,
	CochonTirelire = 0.725,
	GargouilleMignonne = 0.725,
	BebeGriffon = 0.75,
	TournesolJoyeux = 0.8,
	ConciergeCosmique = 0.8,

	-- Rare (0,8 - 0,95)
	TasseChien = 0.8,
	CorbeauVoleur = 0.819,
	TelecommandePerdue = 0.819,
	RenardFurtif = 0.838,
	HibouGrincheux = 0.838,
	CitrouilleSculptee = 0.838,
	ChampignonVeneneux = 0.856,
	CorbeauHorloge = 0.856,
	PhenixCendres = 0.875,
	MoutonMeteore = 0.894,
	LicorneBois = 0.95, -- un vrai poney

	-- Épique (0,95 - 1,15)
	PingouinComete = 0.95,
	RoseCristal = 0.983,
	HibouCamera = 0.983,
	CerbereChiot = 1.017, -- un « chiot »... à trois têtes
	BonsaiMillenaire = 1.017,
	BananeChien = 1.017,
	PanthereNeon = 1.05,
	LoupPolaire = 1.083,
	DragonnetObsidienne = 1.117,
	SatelliteRonchon = 1.117,

	-- Légendaire (1,15 - 1,4)
	MandragoreHurlante = 1.15,
	BurritoNebuleuse = 1.15,
	Treflant4Feuilles = 1.186,
	TrioAsteroides = 1.221,
	Kitsune3Queues = 1.257,
	RequinTorpille = 1.257,
	AigleRoyal = 1.293,
	TigreBengal = 1.329,
	PegaseMoto = 1.364,
	PegaseNuageux = 1.4,

	-- Mythique (1,4 - 1,7)
	ToupieTrouDeVer = 1.4,
	LotusEspace = 1.433,
	DragonGrillePain = 1.467,
	KrakenBaignoire = 1.5,
	JumeauxEclipse = 1.5,
	BasilicEmeraude = 1.533,
	RequinVolant = 1.567,
	TRexTank = 1.633,
	ArbreMondeMiniature = 1.7, -- « miniature »

	-- Divin (1,75 - 2,15)
	TRexPoche = 1.75, -- « de poche » : le plus petit des Divins
	GraineEtoile = 1.75,
	MachineQuantique = 1.823,
	CarniflorToxique = 1.895,
	PhenixSolaire = 1.968,
	LionEnceinte = 1.968,
	GolemDistributeur = 2.077,
	LeviathanAbyssal = 2.15,
	DragonAurore = 2.15,

	-- Sigma (2,3 - 2,9)
	CapybaraZen = 2.3,
	OuroborosInfini = 2.5,
	CanardTractopelle = 2.5,
	FougereFibonacci = 2.7,
	BaleineGalaxie = 2.9, -- le plus grand familier du jeu
} :: { [string]: number }

-- Taille d'un familier en J (milieu de la tranche de sa rareté s'il n'est pas dans la table). Un familier évolué
-- (« <Id>__E2 », PetCatalog) est plus grand que son espèce : x Config.Evolution.SizeMultiplier.
function PetSizes.Of(petId: string, rarityId: string?): number
	local baseId, stage = string.match(petId, "^(.-)__E(%d)$")
	local multiplier = 1
	if baseId and stage then
		petId = baseId
		multiplier = Config.Evolution.SizeMultiplier[tonumber(stage) or 1] or 1
	end
	local h = PetSizes.Heights[petId]
	if h then
		return h * multiplier
	end
	local band = PetSizes.Bands[rarityId or "Commun"] or PetSizes.Bands.Commun
	return (band[1] + band[2]) / 2 * multiplier
end

-- Taille en studs.
function PetSizes.Studs(petId: string, rarityId: string?): number
	return PetSizes.Of(petId, rarityId) * PetSizes.PLAYER
end

-- Mise à l'échelle d'un corps mesuré (taille en studs avant mise à l'échelle) : hauteur visée,
-- en limitant la longueur des familiers allongés.
function PetSizes.ScaleFor(petId: string, rarityId: string?, body: Vector3): number
	local height = PetSizes.Studs(petId, rarityId)
	local long = math.max(body.X, body.Z, 0.1)
	return math.min(
		height / math.max(body.Y, 0.1),
		height * PetSizes.LONG_RATIO / long,
		PetSizes.MAX_FOOTPRINT / long
	)
end

-- Demi-largeur au sol estimée (studs), sans construire le modèle : sert au serveur (promenade, distance de vol).
-- Un familier typique est à peu près aussi long que haut (x1,2).
function PetSizes.Radius(petId: string, rarityId: string?): number
	return math.min(PetSizes.Studs(petId, rarityId) * 1.2, PetSizes.MAX_FOOTPRINT) / 2
end

return PetSizes
