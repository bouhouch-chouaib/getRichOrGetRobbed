--!strict
-- PetSizes : l'échelle des familiers (référentiel unique pour la base, le suivi, le vol et les effets).
--
-- Unité : « J » = la taille d'un avatar Roblox (≈ 5 studs). Un familier de 1 J est grand comme le joueur,
-- un familier de 7 J est un monstre qu'on voit de l'autre bout de la carte.
--
-- Chaque rareté a sa tranche de tailles, sans chevauchement : plus c'est rare, plus c'est grand.
-- Dans une tranche, chaque espèce a SA taille, selon ce qu'elle est (un pigeon est plus petit qu'un chat,
-- un dragon plus grand qu'un hibou). Pour ajouter un familier : choisir sa taille dans la tranche de sa rareté.
--
--   Rareté       Tranche (J)   En studs     Repère
--   Commun       0,7 - 1,0     3,5 - 5      à hauteur d'épaule ... comme le joueur
--   Inhabituel   1,0 - 1,3     5 - 6,5      le joueur, un peu plus
--   Rare         1,3 - 1,7     6,5 - 8,5    on lève la tête
--   Épique       1,8 - 2,4     9 - 12       deux joueurs l'un sur l'autre
--   Légendaire   2,5 - 3,2     12,5 - 16    dépasse la clôture de la base
--   Mythique     3,3 - 4,2     16,5 - 21    un petit immeuble
--   Divin        4,4 - 5,5     22 - 27,5    visible depuis le trou noir
--   Sigma        6,0 - 7,5     30 - 37,5    un titan qui domine la base
--
-- La taille est la HAUTEUR. Les familiers longs (serpents, poissons, baleine) sont limités en longueur
-- (LONG_RATIO x leur taille, MAX_FOOTPRINT au total) pour tenir dans une base de 56 x 56.
local PetSizes = {}

PetSizes.PLAYER = 5 -- studs : hauteur d'un avatar (1 J)
PetSizes.LONG_RATIO = 2 -- longueur max = 2 x la taille
PetSizes.MAX_FOOTPRINT = 52 -- studs : longueur / largeur max au sol (la base fait 56 x 56)
PetSizes.FOLLOW_MAX = 2 -- J : un familier équipé qui suit le joueur ne dépasse pas 2 J (sinon il cache la vue)
PetSizes.CARRY_MAX = 1.4 -- J : un familier volé porté dans le dos ne dépasse pas 1,4 J

PetSizes.Bands = {
	Commun = { 0.7, 1.0 },
	Inhabituel = { 1.0, 1.3 },
	Rare = { 1.3, 1.7 },
	Epique = { 1.8, 2.4 },
	Legendaire = { 2.5, 3.2 },
	Mythique = { 3.3, 4.2 },
	Divin = { 4.4, 5.5 },
	Sigma = { 6.0, 7.5 },
} :: { [string]: { number } }

-- Taille de chaque familier, en J.
PetSizes.Heights = {
	-- Commun (0,7 - 1,0)
	PigeonVilles = 0.7, -- un pigeon reste un pigeon
	FeuFollet = 0.7,
	ChienSaucisse = 0.72, -- bas sur pattes, mais très long
	PousseHaricot = 0.75,
	ChatRuelle = 0.8,
	SlimeGlgl = 0.8,
	TortueBurger = 0.8,
	CactusRonchon = 0.85,
	ChatCoptere = 0.9, -- hélice comprise
	AstroBoulon = 0.95,
	AutrucheFusee = 1.0, -- le grand cou

	-- Inhabituel (1,0 - 1,3)
	GrenouilleGlobuleuse = 1.0,
	HamsterJoufflu = 1.0,
	MyrtilleLunaire = 1.05,
	NavetPeureux = 1.05,
	PoissonAmpoule = 1.1,
	CochonTirelire = 1.15,
	GargouilleMignonne = 1.15,
	BebeGriffon = 1.2,
	TournesolJoyeux = 1.3,
	ConciergeCosmique = 1.3,

	-- Rare (1,3 - 1,7)
	TasseChien = 1.3,
	CorbeauVoleur = 1.35,
	TelecommandePerdue = 1.35,
	RenardFurtif = 1.4,
	HibouGrincheux = 1.4,
	CitrouilleSculptee = 1.4,
	ChampignonVeneneux = 1.45,
	CorbeauHorloge = 1.45,
	PhenixCendres = 1.5,
	MoutonMeteore = 1.55,
	LicorneBois = 1.7, -- un vrai poney

	-- Épique (1,8 - 2,4)
	PingouinComete = 1.8,
	RoseCristal = 1.9,
	HibouCamera = 1.9,
	CerbereChiot = 2.0, -- un « chiot »... à trois têtes
	BonsaiMillenaire = 2.0,
	BananeChien = 2.0,
	PanthereNeon = 2.1,
	LoupPolaire = 2.2,
	DragonnetObsidienne = 2.3,
	SatelliteRonchon = 2.3,

	-- Légendaire (2,5 - 3,2)
	MandragoreHurlante = 2.5,
	BurritoNebuleuse = 2.5,
	Treflant4Feuilles = 2.6,
	TrioAsteroides = 2.7,
	Kitsune3Queues = 2.8,
	RequinTorpille = 2.8,
	AigleRoyal = 2.9,
	TigreBengal = 3.0,
	PegaseMoto = 3.1,
	PegaseNuageux = 3.2,

	-- Mythique (3,3 - 4,2)
	ToupieTrouDeVer = 3.3,
	LotusEspace = 3.4,
	DragonGrillePain = 3.5,
	KrakenBaignoire = 3.6,
	JumeauxEclipse = 3.6,
	BasilicEmeraude = 3.7,
	RequinVolant = 3.8,
	TRexTank = 4.0,
	ArbreMondeMiniature = 4.2, -- « miniature »

	-- Divin (4,4 - 5,5)
	TRexPoche = 4.4, -- « de poche » : le plus petit des Divins, mais déjà 4 joueurs de haut
	GraineEtoile = 4.4,
	MachineQuantique = 4.6,
	CarniflorToxique = 4.8,
	PhenixSolaire = 5.0,
	LionEnceinte = 5.0,
	GolemDistributeur = 5.3,
	LeviathanAbyssal = 5.5,
	DragonAurore = 5.5,

	-- Sigma (6,0 - 7,5)
	CapybaraZen = 6.0,
	OuroborosInfini = 6.5,
	CanardTractopelle = 6.5,
	FougereFibonacci = 7.0,
	BaleineGalaxie = 7.5, -- le plus grand familier du jeu
} :: { [string]: number }

-- Taille d'un familier en J (milieu de la tranche de sa rareté s'il n'est pas dans la table).
function PetSizes.Of(petId: string, rarityId: string?): number
	local h = PetSizes.Heights[petId]
	if h then
		return h
	end
	local band = PetSizes.Bands[rarityId or "Commun"] or PetSizes.Bands.Commun
	return (band[1] + band[2]) / 2
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
