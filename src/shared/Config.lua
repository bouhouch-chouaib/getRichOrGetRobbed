--!strict
-- Config : toutes les valeurs d'équilibrage du jeu, au même endroit.
-- Partagé client/serveur (le client en a besoin pour l'arc de lancer et le HUD).

local Config = {}

-- Premier ramassage d'un nouveau profil : œuf Commun garanti, sans attendre une manche.
-- Sa prime finance une première station. La protection anti-vol expire même hors ligne.
Config.Newcomer = {
	PetId = "ChienSaucisse",
	BonusMoney = 500,
	ProtectionSeconds = 300,
}

-- Incubation parallèle, en secondes réelles (continue hors ligne).
-- Chaque œuf a son nid dans la couveuse de la base (shared/BaseLayout : 10 nids, les premiers à éclore d'abord).
-- BuildUp : secondes de montée en tension avant l'éclosion (tremble, s'élève, brille), par rareté (Commun -> Sigma).
-- L'éclosion elle-même est de plus en plus spectaculaire avec la rareté (client/Eggs).
Config.Eggs = {
	Seconds = { Commun = 15, Inhabituel = 30, Rare = 60, Epique = 180, Legendaire = 300, Mythique = 600, Divin = 1200, Sigma = 1800 } :: { [string]: number },
	BuildUp = { 2, 2.5, 3, 3.5, 4, 5, 6, 7 },
	ViewDistance = 140,
}

-- Mutations (16 oct.) : SECRET. Rien dans le jeu n'en parle (pas d'Index, pas de chances affichées) : un familier qui
-- sort d'un tirage GRATUIT (trou noir, duel ; jamais un tirage acheté en Robux, dont les chances doivent être affichées)
-- a une chance infime d'être Doré, Diamant ou Arc-en-ciel. Tirée quand l'œuf est attribué (server/PullRewards), le client
-- ne le sait qu'à l'éclosion : œuf normal, puis surprise énorme (client/Eggs, mutationReveal). Aspect unique
-- (shared/PetModelBuilder, client/RainbowPets), revenu multiplié (Income), annonce à tout le serveur. Se cumule avec
-- l'évolution. Un muté n'est jamais vendu comme doublon : c'est un autre familier (« <Id>__MGold »...).
-- Chance fixe par familier tiré (pas de bonus de chance : les passes Robux ne doivent pas jouer dessus).
export type Mutation = { Id: string, Name: string, Chance: number, Income: number, Color: Color3, Announce: boolean }
Config.Mutations = {
	{ Id = "Gold", Name = "Doré", Chance = 1 / 4000, Income = 2, Color = Color3.fromRGB(255, 200, 40), Announce = true },
	{ Id = "Diamond", Name = "Diamant", Chance = 1 / 25000, Income = 5, Color = Color3.fromRGB(140, 230, 255), Announce = true },
	{ Id = "Rainbow", Name = "Arc-en-ciel", Chance = 1 / 150000, Income = 10, Color = Color3.fromRGB(255, 100, 210), Announce = true },
} :: { Mutation }
Config.MutationIndex = {} :: { [string]: number }
for index, mutation in ipairs(Config.Mutations) do
	Config.MutationIndex[mutation.Id] = index
end

-- Aimant à objets (amélioration "Magnet" de la boutique, en argent du jeu ; le passe Robux est l'aspirateur, Config.Vacuum) :
-- server/ItemInteraction ramasse pour le joueur l'objet le plus proche dans la portée, avec les mêmes règles que [E]
-- (mains / sac libres, pas de familier porté, pas d'arme en main, vivant).
Config.Magnet = {
	Radius = { 7, 10, 13, 16, 20 }, -- studs, portée par niveau (amélioration de la Boutique, en argent du jeu seulement)
	Interval = 0.35, -- secondes entre deux objets attirés
	-- Un objet lancé est exclu de l’aimant jusqu’à un ramassage manuel. Aucun retour en plein vol.
}

-- Aspirateur à objets (passe Robux "Vacuum", 19 oct.) : remplace l'aimant quand il est allumé (même bouton / touche G) :
-- aspire TOUS les objets autour (Radius) très vite (Interval), les objets volent vers le joueur (client/Magnet), et son
-- réservoir permet de porter ExtraCapacity objets de plus.
Config.Vacuum = {
	PassKey = "Vacuum",
	Radius = 32,
	Interval = 0.08,
	ExtraCapacity = 4,
}

-- Marché entre joueurs du même serveur (server/MarketController, fenêtre client/MarketMenu) : on met un familier en vente
-- pour un prix en argent du jeu, les autres l'achètent. Tax = part de l'argent qui disparaît à chaque vente (0 = aucune).
Config.Market = {
	MaxListings = 3, -- ventes en même temps par joueur
	MinPrice = 1,
	MaxPrice = 1e30,
	Tax = 0,
	SuggestedSeconds = 600, -- prix proposé = 10 min du revenu du familier (au moins MinSuggested)
	MinSuggested = 100,
	-- Prix maximum = 1 h du revenu du familier (au moins 6 x MinSuggested) : personne n'achète un familier plus cher que ce
	-- qu'il rapporte pendant un séjour dans un monde (~1 h) ; au-delà, c'était un cadeau d'argent déguisé (un Commun à 1T $).
	-- 25 oct., dataset_and_pipeline/ECONOMY_REPORT.md règle 3.
	MaxPriceSeconds = 3600,
}

-- Prix maximum d'un familier au marché (Config.Market.MaxPriceSeconds).
function Config.GetMarketMaxPrice(petIncome: number): number
	local market = Config.Market
	return math.floor(math.max(market.MinSuggested * market.MaxPriceSeconds / market.SuggestedSeconds, petIncome * market.MaxPriceSeconds))
end

-- Machine d'évolution (couveuse au fond de la base, shared/BaseLayout) : le joueur y met un de ses œufs. Il n'éclot
-- plus tout seul ; plus il reste, plus le familier qui en sortira peut être évolué (3 stades). Le joueur choisit quand
-- l'ouvrir. Hasard : à l'entrée, chaque œuf reçoit en secret un stade maximum (MaxStageWeights) ; quand une tentative
-- d'évolution échoue (ou qu'il atteint Ultime), la machine affiche qu'il n'évoluera plus.
Config.Evolution = {
	Names = { "", "Évolué", "Ultime" }, -- ajouté au nom du familier
	IncomeMultiplier = { 1, 3, 8 }, -- revenu x3 au stade Évolué, x8 au stade Ultime
	SizeMultiplier = { 1, 1.18, 1.36 }, -- un peu plus grand à chaque stade
	MaxStageWeights = { 40, 42, 18 }, -- 40 % n'évolueront pas, 42 % s'arrêteront à Évolué, 18 % iront jusqu'à Ultime
	-- Attente avant chaque tentative (passer au stade 2, puis au stade 3), en multiples de la durée d'éclosion normale
	-- de sa rareté (Config.Eggs.Seconds) : un œuf Commun tente après 1 min puis 3 min, un Sigma après 2 h puis 6 h.
	StageTimeFactor = { 4, 12 },
	TimeJitter = 0.25, -- +/- 25 % au hasard sur chaque attente
	-- Chambres de la capsule : œufs qui évoluent en même temps (+1 par Rebirth, Config.GetCapsuleSlots).
	Slots = 1,
	-- 25 oct. (ECONOMY_REPORT.md règle 15) : un doublon de sa meilleure rareté (au-delà de Config.Loot.KeepCopies) part
	-- dans une chambre libre au lieu d'être vendu. Sans ça, la capsule ne reçoit plus d'œufs en fin de partie.
	DuplicatesToCapsule = true,
	UseDistance = 18, -- studs : distance max pour utiliser la machine
	-- Un familier évolué est aussi plus fort : stats données quand il est équipé (shared/PetStats) et puissance en duel
	-- (shared/DuelStats) x PowerMultiplier.
	PowerMultiplier = { 1, 1.4, 2 },
	-- La capsule suit le niveau du joueur (le monde le plus loin atteint, attribut Tier) : de plus en plus grande et
	-- épique (client/EvolutionMachine), et meilleure. Par monde au-dessus de la Prairie : tentatives SpeedPerTier plus
	-- tôt (-6 %), et UltimeWeightPerTier points de chance passent de « n'évoluera pas » à « Ultime ».
	-- Divin (monde 7) : tentatives 36 % plus tôt, 30 % de chances d'aller jusqu'à Ultime (au lieu de 18 %).
	SpeedPerTier = 0.06,
	UltimeWeightPerTier = 2,
}

-- Durées des phases (secondes).
Config.Durations = {
	Feeding = 45, -- trou noir ouvert
	Digesting = 60, -- trou noir fermé
}

-- Dans Roblox Studio, on raccourcit les phases pour tester vite.
-- Mettre à false pour tester avec les vraies durées.
Config.UseStudioDurations = false
Config.StudioDurations = {
	Feeding = 30,
	Digesting = 20,
}

-- Géométrie de l'arène (studs). Le trou noir est centré en (0, 0, 0), sol à Y = 0.
Config.Arena = {
	FloorRadius = 315,
	HoleRadius = 40, -- rayon de la BlackholeZone (disque 80x80)
	HoleConsumeHeight = 20, -- un item doit être sous cette hauteur au-dessus du trou pour être avalé
	DomeRadius = 55, -- rayon du dôme répulsif pendant la digestion
	BaseCount = 8,
	BaseRingRadius = 215, -- distance du centre au centre des bases (~150 studs entre l'entrée et le trou)
	BaseSize = Vector3.new(84, 1, 84), -- 15 oct. : agrandie (avant 56) ; plan dans shared/BaseLayout
}

-- Apparition des objets (par base occupée). Depuis le 26 oct., ils tombent dans les 2 bacs posés dehors devant la base,
-- de part et d'autre de l'entrée (shared/BaseLayout.Bins) : le joueur les prend sans entrer chez lui.
Config.Items = {
	StarterCount = 5, -- objets offerts dans les bacs à l'arrivée d'un joueur
	SpawnInterval = 2, -- pendant le Feeding, un objet apparaît toutes les 2 s dans chaque base occupée
	MaxPerBase = 12, -- 2 bacs : ~6 objets par bac
	-- Objets "sauvages" dans l'arène (hors des bases), ramassables par tout le monde pendant le Feeding.
	WildInterval = 4, -- un objet sauvage toutes les 4 s
	WildMax = 25,
	WildQuality = 2, -- équivaut à 2 niveaux de Chance : un peu plus précieux que dans les bases
	WildMinRadius = 70, -- hors du dôme
	WildMaxRadius = 160, -- avant les bases (bord intérieur à 173) et les kiosques
	MaxLooseItems = 80, -- au-delà, les plus vieux objets abandonnés sont nettoyés
	QualityBoost = 0.2, -- par niveau de "Chance" : poids des objets précieux ×(1 + 0.2 × niveau)^rang (0,5 avant le 20 oct. : trop fort)
}

export type ItemTier = {
	Id: string,
	Name: string,
	Value: number, -- points rapportés quand il est avalé (× multiplicateur des familiers)
	Weight: number, -- chance d'apparition
	Color: Color3,
	Shape: Enum.PartType,
	Size: number,
	Material: Enum.Material,
}

-- Les 6 rangs d'objets, du moins au plus précieux : chance d'apparition (Weight) et points de base (Value). Chaque monde
-- a ses propres objets pour ces rangs (Config.WorldItems) ; Shape / Size / Color / Material ne servent plus qu'à
-- l'objet de secours en blocs quand le modèle du monde manque dans ArtModels.Items. Sans néon ni étincelles (26 oct.).
Config.ItemTiers = {
	{ Id = "Caillou", Name = "Caillou", Value = 0.25, Weight = 1000, Color = Color3.fromRGB(150, 150, 155), Shape = Enum.PartType.Block, Size = 1.8, Material = Enum.Material.Slate },
	{ Id = "Brique", Name = "Brique", Value = 0.5, Weight = 350, Color = Color3.fromRGB(200, 85, 60), Shape = Enum.PartType.Block, Size = 2.1, Material = Enum.Material.Brick },
	{ Id = "Cristal", Name = "Cristal", Value = 1, Weight = 100, Color = Color3.fromRGB(80, 220, 255), Shape = Enum.PartType.Block, Size = 2, Material = Enum.Material.Glass },
	{ Id = "Lingot", Name = "Lingot d'or", Value = 2.5, Weight = 25, Color = Color3.fromRGB(255, 200, 40), Shape = Enum.PartType.Block, Size = 2.2, Material = Enum.Material.Foil },
	{ Id = "Diamant", Name = "Diamant", Value = 6, Weight = 6, Color = Color3.fromRGB(200, 250, 255), Shape = Enum.PartType.Block, Size = 2, Material = Enum.Material.Glass },
	{ Id = "Meteorite", Name = "Météorite", Value = 15, Weight = 1, Color = Color3.fromRGB(170, 60, 255), Shape = Enum.PartType.Block, Size = 2.6, Material = Enum.Material.Glass },
} :: { ItemTier }

-- Objets à jeter de chaque monde (26 oct., Chouaib : « pour chaque monde, pas les mêmes objets ») : 6 par monde, un par
-- rang de Config.ItemTiers (même chance d'apparition). Modèles en briques sans néon, faits dans Blender
-- (dataset_and_pipeline/blender_tools/props/Objets_<Monde>.py), rangés dans ArtModels.Items.<Monde>.<Id> (fichier du jeu).
-- Points d'un objet = Value de son rang x Points du monde : plus on avance, plus chaque objet rapporte et plus on a de
-- tirages par manche (jusqu'à ln(Points) / ln(1 + Loot.PullCostGrowth) en plus : +4 au Divin). Ce bonus ne donne ni
-- argent (server/BlackholeController : le revenu suit déjà le monde) ni jauge du trou noir (server/BlackholeTiers).
-- Simulateur (economy_simulator.py solo, 120 parties) : 1er Rebirth à 8,4 h au lieu de 8,7 h, 2 à 4 tirages de plus
-- par manche à partir du Volcan.
-- Les objets d'une base sont ceux du monde où est son propriétaire ; un objet sauvage, ceux du monde d'un joueur du
-- serveur tiré au hasard (server/ItemSpawner).
export type WorldItem = { Id: string, Name: string }
export type WorldItemSet = { Points: number, Items: { WorldItem } }
Config.WorldItems = {
	Prairie = { Points = 1, Items = {
		{ Id = "Pomme", Name = "Pomme" }, { Id = "Carotte", Name = "Carotte" }, { Id = "Fromage", Name = "Fromage" },
		{ Id = "PotDeMiel", Name = "Pot de miel" }, { Id = "Trefle", Name = "Trèfle" }, { Id = "RucheDOr", Name = "Ruche d'or" },
	} },
	Desert = { Points = 1.2, Items = {
		{ Id = "Cactus", Name = "Cactus" }, { Id = "Cruche", Name = "Cruche" }, { Id = "Scarabee", Name = "Scarabée" },
		{ Id = "Lampe", Name = "Lampe magique" }, { Id = "ChatSacre", Name = "Chat sacré" }, { Id = "Pyramide", Name = "Pyramide d'or" },
	} },
	Volcan = { Points = 1.4, Items = {
		{ Id = "Charbon", Name = "Charbon" }, { Id = "RocheDeLave", Name = "Roche de lave" }, { Id = "Piment", Name = "Piment" },
		{ Id = "Enclume", Name = "Enclume d'or" }, { Id = "DentDeDragon", Name = "Dent de dragon" }, { Id = "CoeurDeMagma", Name = "Cœur de magma" },
	} },
	Glace = { Points = 1.6, Items = {
		{ Id = "BouleDeNeige", Name = "Boule de neige" }, { Id = "Cornet", Name = "Cornet" }, { Id = "Bonhomme", Name = "Bonhomme de neige" },
		{ Id = "Patin", Name = "Patin d'or" }, { Id = "Flocon", Name = "Flocon" }, { Id = "Couronne", Name = "Couronne" },
	} },
	Abysses = { Points = 1.8, Items = {
		{ Id = "Coquillage", Name = "Coquillage" }, { Id = "EtoileDeMer", Name = "Étoile de mer" }, { Id = "Ancre", Name = "Ancre" },
		{ Id = "Coffre", Name = "Coffre" }, { Id = "Huitre", Name = "Huître perlière" }, { Id = "Trident", Name = "Trident d'or" },
	} },
	Cosmos = { Points = 2, Items = {
		{ Id = "RocheLunaire", Name = "Roche lunaire" }, { Id = "Casque", Name = "Casque" }, { Id = "Fusee", Name = "Fusée" },
		{ Id = "Planete", Name = "Planète" }, { Id = "Soucoupe", Name = "Soucoupe" }, { Id = "Meteorite", Name = "Météorite d'or" },
	} },
	Divin = { Points = 2.4, Items = {
		{ Id = "Plume", Name = "Plume d'ange" }, { Id = "Nuage", Name = "Nuage" }, { Id = "Lyre", Name = "Lyre" },
		{ Id = "Calice", Name = "Calice d'or" }, { Id = "Ailes", Name = "Ailes d'ange" }, { Id = "Soleil", Name = "Soleil d'or" },
	} },
} :: { [string]: WorldItemSet }

-- Jauge du trou noir apportée en moyenne par un objet avalé (server/BlackholeTiers : max(1, valeur)) avec ce niveau de
-- Chance, mêmes poids que server/ItemSpawner. La jauge compte en « objets ordinaires » : valeur / cette moyenne.
function Config.MeanGaugePerItem(quality: number): number
	local boost = 1 + quality * Config.Items.QualityBoost
	local total, gauge = 0, 0
	for index, tier in ipairs(Config.ItemTiers) do
		local weight = tier.Weight * boost ^ (index - 1)
		total += weight
		gauge += weight * math.max(1, tier.Value)
	end
	return gauge / total
end

-- Lancer (côté client). La vitesse max dépend de la Force (attribut "ThrowPower").
Config.Throw = {
	MinRatio = 0.35, -- lancer sans charge = 35 % de la vitesse max
	MaxChargeTime = 1.5,
	UpBias = 0.6, -- ajouté au LookVector de la caméra avant normalisation
	ChargeWalkSpeed = 8,
	ChargeFov = 55,
	DefaultFov = 70,
}

-- Anti-triche des lancers (serveur). Le client simule le vol de l'objet : le serveur vérifie, quand le trou l'avale,
-- qu'il a vraiment été lancé par son propriétaire, depuis une distance atteignable avec sa Force, et récemment.
Config.AntiCheat = {
	RangeMargin = 1.25, -- portée max acceptée = (ThrowPower² / gravité) × marge + bonus
	RangeBonus = 15, -- studs : hauteur de lancer, latence, déplacement pendant la charge
	MaxFlightTime = 8, -- un objet avalé plus de 8 s après son lancer ne rapporte rien
	-- Temps de vol minimal : l'objet ne peut pas aller plus vite que la vitesse de lancer (sinon : téléporté).
	-- Accepté si temps >= (distance / ThrowPower) × ratio - marge (la latence touche le lancer ET l'arrivée).
	MinFlightRatio = 0.9,
	FlightTimeMargin = 0.15,
	MinThrowInterval = 0.12, -- deux lancers plus rapprochés : le second ne rapporte rien
}

-- Éjection par le dôme (vitesses en studs/s).
Config.Knockback = {
	OutwardSpeed = 110,
	UpSpeed = 55,
	ItemOutwardSpeed = 70,
	ItemUpSpeed = 45,
	Cooldown = 1.5,
	SitDuration = 1.5,
}

-- Entraînement : Vitesse (tapis de course) et Force (banc de développé couché).
-- XP pour passer du niveau L au niveau L+1 = XPBase × XPGrowth^L (progression longue).
-- XP gagnée par seconde sur la station = StationRateGrowth^(niveau - 1) (Config.GetStationRate).
-- Stations : 25 niveaux et 10 modèles (Chouaib, 26 oct. : « 10 tapis tous plus spectaculaires ») : un nouveau modèle
-- tous les 2 ou 3 niveaux (Training.ModelStarts, server/StationLooks). Dans un modèle, chaque niveau allume un voyant de
-- plus ; son dernier niveau ajoute une étoile au sommet.
export type StatConfig = { Base: number, PerLevel: number, MaxLevel: number }
export type StationTier = {
	Name: string, -- nom du modèle 3D : ReplicatedStorage.ArtModels.Treadmill_<Name> / Bench_<Name>
	Title: string?, -- nom affiché (accents)
	Main: Color3, -- couleur principale (châssis)
	Dark: Color3, -- pièces sombres (pieds, dessous)
	Accent: Color3, -- voyants, écran, cercle au sol
	Belt: Color3, -- tapis / matelas
	Trim: Color3?, -- liserés
}
Config.Training = {
	Speed = { Base = 16, PerLevel = 0.5, MaxLevel = 60 } :: StatConfig, -- WalkSpeed
	Strength = { Base = 70, PerLevel = 3, MaxLevel = 60 } :: StatConfig, -- vitesse de lancer max
	XPBase = 5,
	XPGrowth = 1.12,
	StationRateGrowth = 1.17, -- niveau 25 : x43 (l'ancien niveau 8 donnait x40)
	ModelStarts = { 1, 3, 6, 8, 11, 13, 16, 18, 21, 23 }, -- 1er niveau de chacun des 10 modèles
	StationLevels = 25,
	-- Tapis de course (19 oct.) : taille par rapport aux premières mesures (trop grand à côté de l'avatar) ; tout le tapis
	-- (zone, décor, modèles de ReplicatedStorage.ArtModels) est réduit d'autant. Flèches sur la bande qui défilent vers
	-- l'arrière (client/TreadmillBelt) : Length = studs entre deux flèches, vitesses en studs / s (à vide / quelqu'un court).
	TreadmillScale = 0.6,
	BeltArrows = { Image = "rbxassetid://131546186740141", Length = 2.4, IdleSpeed = 1.5, RunSpeed = 7, Transparency = 0.15 },
	StationTiers = {
		{ Name = "Bois", Main = Color3.fromRGB(184, 120, 58), Dark = Color3.fromRGB(110, 70, 38), Accent = Color3.fromRGB(90, 230, 80), Belt = Color3.fromRGB(55, 55, 62) },
		{ Name = "Acier", Main = Color3.fromRGB(212, 216, 226), Dark = Color3.fromRGB(94, 102, 122), Accent = Color3.fromRGB(40, 150, 255), Belt = Color3.fromRGB(40, 44, 56) },
		{ Name = "Sport", Main = Color3.fromRGB(232, 40, 58), Dark = Color3.fromRGB(30, 30, 38), Accent = Color3.fromRGB(255, 210, 30), Belt = Color3.fromRGB(34, 34, 40), Trim = Color3.fromRGB(244, 244, 248) },
		{ Name = "Or", Main = Color3.fromRGB(255, 198, 40), Dark = Color3.fromRGB(138, 74, 18), Accent = Color3.fromRGB(255, 120, 30), Belt = Color3.fromRGB(30, 30, 36), Trim = Color3.fromRGB(255, 198, 40) },
		{ Name = "Jade", Main = Color3.fromRGB(30, 154, 90), Dark = Color3.fromRGB(14, 74, 46), Accent = Color3.fromRGB(106, 255, 176), Belt = Color3.fromRGB(16, 30, 24), Trim = Color3.fromRGB(255, 198, 40) },
		{ Name = "Cristal", Main = Color3.fromRGB(36, 40, 64), Dark = Color3.fromRGB(20, 22, 36), Accent = Color3.fromRGB(70, 230, 255), Belt = Color3.fromRGB(14, 16, 28), Trim = Color3.fromRGB(255, 198, 40) },
		{ Name = "Lave", Main = Color3.fromRGB(46, 38, 48), Dark = Color3.fromRGB(20, 16, 20), Accent = Color3.fromRGB(255, 106, 18), Belt = Color3.fromRGB(20, 14, 16), Trim = Color3.fromRGB(255, 194, 58) },
		{ Name = "Royal", Main = Color3.fromRGB(90, 30, 138), Dark = Color3.fromRGB(42, 14, 68), Accent = Color3.fromRGB(255, 210, 58), Belt = Color3.fromRGB(180, 20, 42), Trim = Color3.fromRGB(255, 198, 40) },
		{ Name = "Cosmique", Main = Color3.fromRGB(44, 24, 76), Dark = Color3.fromRGB(20, 10, 36), Accent = Color3.fromRGB(190, 90, 255), Belt = Color3.fromRGB(12, 6, 24), Trim = Color3.fromRGB(255, 130, 235) },
		{ Name = "Celeste", Title = "Céleste", Main = Color3.fromRGB(246, 248, 255), Dark = Color3.fromRGB(200, 210, 230), Accent = Color3.fromRGB(122, 200, 255), Belt = Color3.fromRGB(220, 228, 244), Trim = Color3.fromRGB(255, 198, 40) },
	} :: { StationTier },
	-- Sauvegardes d'avant les 25 niveaux (8 niveaux) : ancien niveau -> nouveau (même XP par seconde à peu près).
	OldStationLevels = { 1, 5, 9, 12, 16, 19, 22, 25 },
	-- Animations (client/TrainingFx) : course sur place et développé couché.
	RunAnimSpeed = 1.3, -- vitesse de l'animation de course sur le tapis (niveau 1)
	BenchRepTime = 1.6, -- secondes par répétition au banc (niveau 1 ; un grognement d'effort à chaque poussée)
	AnimSpeedPerLevel = 0.04, -- chaque niveau de station au-dessus de 1 : on court / pousse 4 % plus vite
}

-- XP par seconde d'une station de ce niveau.
function Config.GetStationRate(level: number): number
	return Config.Training.StationRateGrowth ^ (math.max(level, 1) - 1)
end

-- Modèle (StationTiers) d'une station de ce niveau, rang du niveau dans ce modèle et nombre de niveaux du modèle.
function Config.GetStationTier(level: number): (StationTier, number, number)
	local starts = Config.Training.ModelStarts
	level = math.clamp(level, 1, Config.Training.StationLevels)
	local index = 1
	for i, first in ipairs(starts) do
		if level >= first then
			index = i
		end
	end
	local nextStart = starts[index + 1] or (Config.Training.StationLevels + 1)
	return Config.Training.StationTiers[index], level - starts[index] + 1, nextStart - starts[index]
end

-- Vrai si ce niveau de station est le premier d'un nouveau modèle (son « MODÈLE ... ! », client/UpgradeSigns).
function Config.IsNewStationModel(level: number): boolean
	return level > 1 and table.find(Config.Training.ModelStarts, level) ~= nil
end

-- Tirages : un objet avalé rapporte sa valeur (Config.ItemTiers) × multiplicateur des familiers équipés.
-- Le coût d'un tirage augmente à chaque tirage de la même manche (évite l'emballement).
Config.Loot = {
	PullCost = 2, -- coût du 1er tirage (minimum 1 tirage si score > 0)
	PullCostGrowth = 0.22, -- +22 % de coût à chaque tirage suivant de la manche (8 % avant le 20 oct. : trop de tirages)
	LuckPerPoint = 0.005, -- chaque point augmente un peu le poids des raretés hautes
	MaxLuck = 1, -- au maximum, poids des raretés hautes ×2
	-- Pitié par palier (25 oct., dataset_and_pipeline/ECONOMY_REPORT.md règle 11) : la rareté juste au-dessus de la
	-- meilleure que le joueur possède (œufs compris) est garantie au tirage où PityPercentile des joueurs l'auraient
	-- déjà eue : ln(1 - PityPercentile) / ln(1 - p), p = chance de cette rareté ou mieux (LootEngine.pityAt).
	-- Seuls les 10 % les plus malchanceux en profitent. Avant : un Épique garanti au 60e tirage, jamais atteint.
	PityPercentile = 0.9,
	AnnounceMinRarity = 5, -- annonce serveur à partir de cet index (5 = Légendaire)
	-- Dans une rareté, un familier que le joueur n'a PAS encore a ce poids (1 pour ceux déjà possédés) :
	-- la collection avance bien plus vite. Les chances de chaque rareté ne changent pas.
	NewPetWeight = 5,
	-- Rang de tirage (13 oct.) : selon les tirages faits depuis le début (attribut TotalPulls). Floor = rareté
	-- minimale : un tirage plus bas « monte » à cette rareté (les chances des raretés au-dessus ne changent pas).
	-- Une rareté ne disparaît que si le joueur a découvert TOUS ses familiers (l'Index reste complétable).
	Ranks = {
		{ Pulls = 0, Floor = 1, Name = "APPRENTI" },
		{ Pulls = 150, Floor = 2, Name = "DOMPTEUR" }, -- plus de Communs
		{ Pulls = 600, Floor = 3, Name = "MAÎTRE" }, -- plus d'Inhabituels
	},
	-- Doublons : au-delà de KeepCopies exemplaires d'un même familier, les suivants sont vendus tout de suite
	-- (SellSeconds secondes du revenu de ce familier, x bonus du monde et des passes ; le jeter dans le trou rapporte plus).
	KeepCopies = 5,
	SellSeconds = 300,
	-- Ouverture des tirages (client/PullReveal) : au plus RevealCards capsules montrées une par une, les autres résumées.
	RevealCards = 8,
	RevealStep = 0.28, -- secondes entre deux capsules
	RevealHold = 2.2, -- secondes d'affichage une fois toutes ouvertes
}

-- Familiers.
Config.Pets = {
	ModelStyle = "Sculpted", -- "Legacy" restores imported meshes and the previous primitives.
	AuraDistance = 110, -- particles/lights suspended beyond this camera distance
	AuraUpdateInterval = 0.05, -- one shared 20 Hz visual update
	MotionDistance = 140, -- articulated motion (client/PetMotion) sleeps beyond this camera distance
	MotionNearDistance = 60, -- closer than this: posed every frame
	MotionFarInterval = 0.1, -- between near and sleep distance: posed at 10 Hz
	EquipSlots = 1, -- familiers équipés (multiplicateur de points + stats, suivent le joueur, ne rapportent plus d'argent)
	-- Stats d'un familier équipé (shared/PetStats) : des niveaux de Vitesse et de Force en plus, tant qu'il est équipé.
	-- Levels = total par rareté (Commun -> Sigma), partagé selon la taille : petit = surtout Vitesse, gros = surtout Force.
	EquipBonus = {
		Levels = { 2, 3, 5, 7, 10, 14, 19, 26 },
		SpeedShareSmall = 0.8, -- le plus petit de sa rareté : 80 % en Vitesse
		SpeedShareBig = 0.2, -- le plus gros : 20 % en Vitesse (80 % en Force)
		MaxLevels = 30, -- plafond par stat, tous familiers équipés confondus
	},
	-- Places de la base (+1 par Rebirth) : les familiers placés par le joueur, puis les meilleurs (shared/PetRoster).
	-- Seuls ceux-là sont dans la base et rapportent ; les autres sont « en réserve » (Index, fusion, échanges).
	IncomeSlots = 15,
	-- Taille de chaque familier : voir shared/PetSizes (échelle en « tailles de joueur », de 0,5 à 2,9).
}

-- Monétisation (Robux). Id = numéro du pass / produit créé sur create.roblox.com (0 = pas encore créé : affiché "BIENTÔT").
-- Price = prix affiché par défaut (le vrai prix est lu sur Roblox dès que l'Id est renseigné).
export type MonetizationItem = {
	Key: string,
	Id: number,
	Icon: string, -- nom d'une icône de shared/Icons
	Name: string,
	Description: string,
	Price: number,
	Pulls: number?, -- produits "tirages" : nombre de tirages accordés
	Keys: number?, -- produits "clés" : nombre de clés accordées (Config.Keys)
}

Config.Monetization = {
	GamePasses = {
		{ Key = "DoubleMoney", Id = 2025998871, Icon = "Money", Name = "2X ARGENT", Description = "Revenu et gains d'argent x2, pour toujours.", Price = 399 },
		{ Key = "VIP", Id = 2026292822, Icon = "Crown", Name = "VIP", Description = "+25 % d'argent, étiquette VIP au-dessus de la tête, verrou de base +10 s.", Price = 299 },
		-- Id = 0 tant que le passe n'est pas créé sur Roblox (bouton « Bientôt »).
		{ Key = "Vacuum", Id = 2038180912, Icon = "Vortex", Name = "ASPIRATEUR", Description = "Aspire TOUS les objets autour de toi, très vite, et porte 4 objets de plus. Active-le ou coupe-le avec son bouton (touche G).", Price = 199 },
		{ Key = "ExtraBackpack", Id = 2025176879, Icon = "Backpack", Name = "SAC À DOS +1", Description = "Porte 1 objet de plus.", Price = 149 },
		{ Key = "EquipPlus2", Id = 2025296892, Icon = "Paw", Name = "ÉQUIPEMENT +2", Description = "Équipe 2 familiers de plus.", Price = 799 },
		{ Key = "LuckyLuck", Id = 2026568802, Icon = "Clover", Name = "CHANCE CHANCEUSE", Description = "Meilleure chance à tous tes tirages.", Price = 399 },
	} :: { MonetizationItem },
	Products = {
		{ Key = "AstralAura", Id = 3718429232, Icon = "Sparkle", Name = "AURA ASTRALE", Description = "Cristaux lumineux, étoiles cyan et violettes, et une traînée quand tu cours. Activée automatiquement, pour toujours.", Price = 19 },

		{ Key = "ServerLuck", Id = 3717917081, Icon = "Sparkle", Name = "CHANCE x2 POUR TOUS", Description = "10 minutes de chance x2 pour TOUT le serveur !", Price = 149 },
		{ Key = "Pull1", Id = 3717917143, Icon = "Dice", Name = "1 ŒUF", Description = "1 œuf de familier. Il éclot plus ou moins vite selon sa rareté.", Price = 49, Pulls = 1 },
		{ Key = "Key1", Id = 3718327246, Icon = "Key", Name = "CLÉ", Description = "Ouvre une base FERMÉE pendant 10 s, même si son propriétaire la referme. [E] devant son portail.", Price = 49, Keys = 1 },
		{ Key = "Pull10", Id = 3717917239, Icon = "Gift", Name = "10 ŒUFS", Description = "10 œufs de familiers. Ils éclosent tous en même temps, plus ou moins vite selon leur rareté.", Price = 399, Pulls = 10 },
	} :: { MonetizationItem },
	DoubleMoneyMultiplier = 2,
	VipMoneyMultiplier = 1.25,
	VipLockBonus = 10, -- secondes de verrou en plus
	ExtraBackpack = 1, -- objets portés en plus
	ExtraEquipSlots = 2, -- familiers équipés en plus
	LuckyLuckBonus = 0.5, -- bonus de chance des tirages (voir LootEngine)
	ServerLuckBonus = 1, -- boost serveur : poids des raretés au-dessus de Commun x2
	ServerLuckDuration = 600, -- secondes (un nouvel achat prolonge le boost)
	PullLuck = 0.5, -- chance de base des tirages achetés (= une bonne manche)
	-- Studio uniquement, pour tester sans acheter : clés des passes considérés comme possédés (ex. { "VIP" }).
	StudioTestPasses = {} :: { string },
	-- Roblox donne d'office tous ses passes au créateur du jeu. false : le créateur joue SANS leurs effets
	-- (même partie que ses amis). StudioTestPasses reste utilisable pour tester.
	CreatorOwnsPasses = false,
}

-- Cosmétique du personnage : produit permanent AstralAura, validé par le serveur.
-- Le reçu valide le déblocage sauvegardé dans les améliorations.
Config.PlayerAura = {
	UnlockId = "AstralAura",
	Primary = Color3.fromRGB(72, 232, 255),
	Secondary = Color3.fromRGB(174, 88, 255),
	RunSpeed = 8,
	ViewDistance = 120,
	UpdateInterval = 1 / 30,
	TrailLifetime = 0.5,
	TeleportDistance = 14,
}

-- Traînée quand on court, de la même forme que le « Sentier bleu » de Steal an Egg (relevé sur
-- references/video_chouaib) : une bande unie, large comme les hanches, presque opaque et très longue (client/RunTrail).
-- Pas de texture ni de particules. En blanc (choix de Chouaib), pas leur cyan. L'Aura astrale achetée a sa propre
-- traînée : pas les deux.
Config.RunTrail = {
	Color = Color3.fromRGB(255, 255, 255),
	Start = Color3.fromRGB(255, 255, 255), -- juste derrière le corps
	Width = 1.6, -- studs
	Lifetime = 0.7, -- secondes : longueur de la traînée (1,4 trop long pour Chouaib)
	MinLength = 2, -- studs entre deux points du ruban : trajet grossier, il ne recopie pas chaque petit écart
	Height = -0.2, -- hauteur sous le centre du HumanoidRootPart (la taille)
	LightEmission = 0, -- vérifié en Play : plus haut, l'herbe claire se mélange à la couleur et la pâlit
	TeleportDistance = 14, -- un saut plus grand efface la traînée (sinon un trait à travers la carte)
	UpdateInterval = 1 / 20,
	-- Petits traits de vent autour du coureur : rubans très fins et courts, qui ondulent un peu.
	Wind = {
		Points = { -- départ de chaque trait, autour du HumanoidRootPart (x = côté, y = hauteur, z = vers l'arrière)
			Vector3.new(-1.5, 1.3, 0),
			Vector3.new(1.6, 0.7, 0.2),
			Vector3.new(-1.7, -0.4, 0.3),
			Vector3.new(1.4, -1.2, 0.1),
			Vector3.new(-0.8, 2.1, 0.2),
		},
		Width = 0.16,
		Lifetime = 0.42,
		Transparency = 0, -- au départ du trait (vérifié en Play : plus fin ou plus transparent, on ne le voit pas)
		Wobble = 0.25, -- studs d'ondulation verticale
		MinSpeed = 12, -- studs/s à l'horizontale pour voir le vent (pas en marchant lentement en portant)
	},
}

-- Machine de fusion : Count familiers -> un œuf de la rareté supérieure.
-- Possible jusqu'à MaxFromRarity (6 = Mythique -> Divin). Le Sigma ne s'obtient que par chance.
Config.Fusion = {
	Count = 5,
	MaxFromRarity = 6,
	Costs = { 250, 8e3, 190e3, 3.5e6, 60e6, 1.5e9 }, -- prix en $ selon la rareté fusionnée (index de rareté)
	-- Mutations par la fusion (SECRET, comme Config.Mutations : rien dans le jeu n'en parle). Le familier obtenu :
	--   - tire sa mutation secrète comme un tirage gratuit (PullRewards.RollMutation) ;
	--   - chaque familier muté mis dans la machine a CarryChance de lui passer sa mutation ;
	--   - si les Count familiers ont TOUS la même mutation, il l'a forcément, et UpgradeChance d'avoir la suivante
	--     (5 Dorés -> Doré sûr, 30 % Diamant ; 5 Diamants -> Diamant sûr, 30 % Arc-en-ciel).
	-- On garde la meilleure. Le joueur ne voit qu'un œuf normal : la surprise est à l'éclosion.
	Mutation = {
		CarryChance = 0.12,
		UpgradeChance = 0.3,
	},
}

-- Badges Roblox (server/BadgeController). Id = numéro du badge créé sur create.roblox.com (0 = pas encore créé : ignoré).
-- Images prêtes dans assets/badges (512 x 512). Aucun badge ne parle des mutations (elles restent secrètes).
export type BadgeDef = { Key: string, Id: number, Name: string, Description: string }
Config.Badges = {
	{ Key = "Welcome", Id = 0, Name = "Bienvenue !", Description = "Rejoindre Get Rich Or Get Robbed pour la première fois." },
	{ Key = "FirstHatch", Id = 0, Name = "Premier œuf", Description = "Faire éclore son premier œuf." },
	{ Key = "FirstSteal", Id = 0, Name = "Voleur", Description = "Voler un familier dans une base adverse et le ramener chez soi." },
	{ Key = "DuelWin", Id = 0, Name = "Champion de l'arène", Description = "Gagner un duel de familiers." },
	{ Key = "WorldDesert", Id = 0, Name = "Voyageur", Description = "Atteindre le monde Désert." },
	{ Key = "WorldCosmos", Id = 0, Name = "Explorateur cosmique", Description = "Atteindre le monde Cosmos." },
	{ Key = "WorldDivin", Id = 0, Name = "Divin", Description = "Atteindre le dernier monde : Divin." },
	{ Key = "FirstRebirth", Id = 0, Name = "Renaissance", Description = "Faire son premier Rebirth." },
	{ Key = "Index25", Id = 0, Name = "Collectionneur", Description = "Découvrir 25 familiers différents." },
	{ Key = "Index50", Id = 0, Name = "Grand collectionneur", Description = "Découvrir 50 familiers différents." },
	{ Key = "Index75", Id = 0, Name = "Index complet", Description = "Découvrir les 75 familiers." },
	{ Key = "Ultime", Id = 0, Name = "Évolution ultime", Description = "Obtenir un familier Ultime dans la capsule d'évolution." },
	{ Key = "Sigma", Id = 0, Name = "Légende Sigma", Description = "Obtenir un familier Sigma." },
} :: { BadgeDef }

-- Groupe Roblox : les membres gagnent IncomeBonus de revenu en plus (server/ProgressionController, attribut "InGroup").
-- Id = numéro du groupe (0 = pas de groupe : bonus désactivé et rien n'est affiché).
Config.Group = {
	Id = 0,
	IncomeBonus = 0.1, -- +10 %
}

-- Index (collection) : chaque familier découvert donne une récompense à réclamer une seule fois
-- (fenêtre INDEX, bouton RÉCLAMER) = RewardSeconds secondes de son revenu.
Config.Index = {
	RewardSeconds = 120,
	MinReward = 100,
}

-- Test : dans Roblox Studio uniquement, chaque joueur reçoit 1 exemplaire de chaque familier
-- (pour voir tous les modèles). Mettre à false pour tester la vraie progression.
Config.StudioGiveAllPets = false
-- Test : dans Studio uniquement, ces familiers sont donnés ET équipés à l'arrivée (pour essayer un modèle 3D).
-- Vider la liste ({}) pour désactiver.
Config.StudioTestPets = {} :: { string }

-- Sauvegardes (DataStore). Changer Version remet TOUTES les progressions et le tableau des plus riches à zéro.
-- Dans Studio, tout va dans des magasins séparés (suffixe "_studio") : les tests ne touchent jamais les vrais joueurs.
Config.Save = {
	-- v1 = développement (abandonnées le 10 oct. 2026) ; v2 = tests jusqu'au 19 oct. 2026 ; v3 : tout le monde repart à zéro
	-- le 19 oct. 2026 (demande de Chouaib). Les anciennes sauvegardes restent dans PlayerData_v2 (rien n'est effacé).
	-- v4 : tous les testeurs repartent à zéro le 26 oct. 2026, juste avant l'ouverture au public (demande de Chouaib) ;
	-- leurs sauvegardes restent dans PlayerData_v3 et le tableau des plus riches dans RichestBoard_v3.
	Version = 4,
	-- Studio garde sa propre version : la sauvegarde de test de Chouaib (tous les familiers) n'est pas remise à zéro.
	StudioVersion = 3,
}

-- Tableau des plus riches, planté dans l'arène (tous serveurs confondus, OrderedDataStore).
Config.Leaderboard = {
	Size = 10, -- nombre de joueurs affichés
	RefreshInterval = 60, -- secondes entre deux mises à jour (écriture de l'argent + lecture du classement)
	Angle = 67.5, -- degrés : entre la 2e et la 3e base, là où il n'y a pas de kiosque
	Radius = 190, -- distance au trou noir (juste avant les bases)
}

-- Panneau des nouveautés (29 oct., docs/STRATEGIE_JOUEURS.md B5 ; server/UpdateBoard) : planté dans l'arène comme le
-- tableau des plus riches, il montre ce que la dernière mise à jour apporte. À chaque mise à jour : Number + 1 et
-- de nouvelles lignes (phrases courtes en MAJUSCULES, à ajouter aussi dans shared/LangEn). Un joueur déjà venu reçoit
-- une fois le message « MISE À JOUR n ! » (champ sauvegardé seenUpdate).
export type UpdateLine = { Icon: string, Text: string }
Config.Updates = {
	Number = 1,
	Angle = 337.5, -- degrés : entre la 8e et la 1re base, place libre (kiosques à 22,5 + 90 x k, classement à 67,5)
	Radius = 190,
	Lines = {
		{ Icon = "Gift", Text = "INVITE TES AMIS : 2 ŒUFS CHACUN !" },
		{ Icon = "Sun", Text = "CHAQUE HEURE PILE : TROU NOIR DORÉ, POINTS x2 !" },
		{ Icon = "Egg", Text = "ON TE PRÉVIENT QUAND TES ŒUFS SONT PRÊTS" },
		{ Icon = "Codes", Text = "NOUVEAUX CODES : LAUNCH, BLACKHOLE, THANKS" },
	} :: { UpdateLine },
}

-- Argent : revenu passif des familiers + bonus de fin de digestion.
Config.Economy = {
	-- Chaque point marqué rapporte aussi de l'argent à la digestion : MoneyPerPoint, ou IncomeSecondsPerPoint
	-- secondes du revenu du joueur si c'est plus (l'argent du trou suit la progression).
	MoneyPerPoint = 15,
	IncomeSecondsPerPoint = 0.02,
}

-- Verrouillage de base (bouton au sol, comme Steal a Brainrot).
-- 25 oct. (dataset_and_pipeline/ECONOMY_REPORT.md, étape 2) : cycle fixe. Un passage sur le bouton ferme la base Duration
-- secondes (+ LongBonus avec « Verrou renforcé », + le bonus VIP), et le bouton reste grisé jusqu'à la fin du cycle
-- (Cycle secondes après le passage). On ferme donc une fois par manche (45 s + 60 s = Feeding + digestion), au moment
-- choisi. La base reste ouverte au moins MinOpen secondes par cycle, même avec tous les bonus (le temps d'un débutant pour
-- voler chez son voisin). Avant : 5 s relancées tant qu'on restait sur le bouton, donc fermée pour toujours.
Config.Lock = {
	Duration = 45, -- = la durée du Feeding : on peut aller lancer pendant que la base est fermée
	LongBonus = 10, -- avec l'amélioration "LongLock"
	Cycle = 105, -- = une manche (Feeding + digestion)
	MinOpen = 30,
	ButtonRadius = 4,
}

-- Durée de fermeture d'un passage sur le bouton (bonus compris, plafonnée pour laisser MinOpen secondes ouvertes).
function Config.GetLockDuration(longLock: boolean, vipBonus: number): number
	local lock = Config.Lock
	return math.min(lock.Duration + (if longLock then lock.LongBonus else 0) + vipBonus, lock.Cycle - lock.MinOpen)
end

-- Plafond de revenu (25 oct., ECONOMY_REPORT.md règle 2) : un familier rapporte au plus le revenu de base de la rareté
-- RarityGap au-dessus de la meilleure que le joueur a obtenue LUI-MÊME (œufs : tirages, fusion, capsule, récompenses).
-- Concerne les familiers volés, échangés, achetés ou gagnés en duel : un vol fait gagner au plus un monde d'avance
-- (deux raretés ≈ x6 à x16 de revenu, autant que la montée d'un monde). Calcul : shared/PowerCap.
Config.PowerCap = {
	RarityGap = 2,
}

-- Vol utile et bouclier (25 oct., ECONOMY_REPORT.md règles 7 et 8) : server/StealController.
--   - On ne peut prendre chez un autre que les familiers qui feraient monter son revenu (plafonné) : plus que le moins bon de
--     sa base, ou s'il reste une place. Un vol qui ne rapporte rien au voleur n'est que du harcèlement.
--   - Bouclier : un joueur qui a perdu ShieldLoss de la valeur de sa base en ShieldWindow secondes (vols et familiers jetés
--     au trou) ne peut plus être volé pendant ShieldSeconds secondes (simulateur : jackpots des nouveaux 5,3 -> 0,07 par session).
Config.StealShield = {
	ShieldLoss = 0.1,
	ShieldWindow = 3600,
	ShieldSeconds = 1800,
}

-- Couronne du plus riche (25 oct., ECONOMY_REPORT.md règle 9) : server/CrownController, shared/CrownRules, client/Crown.
--   Le joueur qui a le plus gros revenu du serveur porte une couronne (au-dessus de la tête et sur sa base), dès MinPlayers
--   joueurs. Pour la lui prendre, il faut le dépasser de Hysteresis (sinon elle changerait de tête à chaque seconde).
--   Voler le roi rapporte, en plus du familier, une prime égale à ce que rapporterait de jeter ce familier dans le trou
--   (Config.Sacrifice.IncomeSeconds de son revenu plafonné) : il vaut deux fois plus à prendre chez le roi.
--   Chaque voleur arrêté chez le roi (repris, frappé, trop lent) rapporte au roi la même somme, un compteur et une annonce,
--   au plus MaxDefenseRewardsPerHour fois par heure et une fois par voleur toutes les DefenseCooldown secondes : deux amis
--   ne peuvent pas s'enrichir en se volant exprès (au plus ~+7 % du revenu du roi par heure). Pas de revenu en plus : la
--   domination donne du prestige et du jeu (défendre), pas de boule de neige.
Config.Crown = {
	MinPlayers = 2,
	Hysteresis = 0.1,
	CheckInterval = 2,
	DefenseCooldown = 600,
	MaxDefenseRewardsPerHour = 3,
}

-- Mondes (paliers) : le joueur paie Price pour voyager au monde suivant (server/TierController, fenêtre client/WorldMenu).
-- Tout change pour lui (client/WorldSkin) : l'arène entière s'affiche dans SON monde, sa base dans son monde aux yeux de
-- tous, la musique (Config.Sounds.Playlists[palier]). Chaque monde multiplie son revenu (IncomeMultiplier).
-- Les couleurs et décors de chaque monde sont dans shared/Worlds (pur visuel).
-- RarityBoost (20 oct., docs/PLAN_EQUILIBRAGE.md) : les tirages sont meilleurs dans les mondes plus loin (le plus loin
-- atteint) : le poids de chaque rareté est multiplié par RarityBoost ^ (rang - 1) (Commun x1, Inhabituel x boost...).
export type WorldDef = { Id: string, Name: string, Price: number, IncomeMultiplier: number, RarityBoost: number? }
Config.Worlds = {
	{ Id = "Prairie", Name = "Prairie", Price = 0, IncomeMultiplier = 1, RarityBoost = 1 },
	{ Id = "Desert", Name = "Désert", Price = 200e3, IncomeMultiplier = 1.6, RarityBoost = 1.08 },
	{ Id = "Volcan", Name = "Volcan", Price = 14e6, IncomeMultiplier = 2.5, RarityBoost = 1.17 },
	{ Id = "Glace", Name = "Glace", Price = 450e6, IncomeMultiplier = 4, RarityBoost = 1.27 },
	{ Id = "Abysses", Name = "Abysses", Price = 14e9, IncomeMultiplier = 6.5, RarityBoost = 1.38 },
	{ Id = "Cosmos", Name = "Cosmos", Price = 300e9, IncomeMultiplier = 10, RarityBoost = 1.5 },
	{ Id = "Divin", Name = "Divin", Price = 1.4e12, IncomeMultiplier = 16, RarityBoost = 1.8 },
} :: { WorldDef }

-- Monde (1 à #Config.Worlds) d'un palier quelconque, borné.
-- Index d'un monde à partir de son Id (Config.WorldIndex["Desert"] = 2).
Config.WorldIndex = {} :: { [string]: number }
for index, world in ipairs(Config.Worlds) do
	Config.WorldIndex[world.Id] = index
end

function Config.GetWorld(tier: number): WorldDef
	return Config.Worlds[math.clamp(math.floor(tier), 1, #Config.Worlds)]
end

-- Clés (achat en Robux uniquement, produit "Key1" à 49 R$) : ouvrent une base adverse FERMÉE pendant Duration secondes,
-- même si son propriétaire la referme (server/LockController, bulle client/BaseKeys). Une clé est consommée par usage.
-- Sans clé, la bulle du portail propose d'en acheter une ; elle est utilisée dès que l'achat est validé.
Config.Keys = {
	Duration = 10, -- secondes d'ouverture forcée
	UseDistance = 14, -- distance max au portail (studs, vérifiée par le serveur avec une marge)
	HoldDuration = 0.6, -- temps d'appui sur [E] pour crocheter
	ProtectAfter = 20, -- secondes pendant lesquelles une base qui vient d'être crochetée ne peut pas l'être à nouveau
}

-- Vol de familiers : [E] sur un familier d'une base adverse déverrouillée, à ramener dans sa propre base.
Config.Steal = {
	OnlyDuringDigesting = false, -- false : vol possible à tout moment (nuit comme jour)
	-- La vitesse pendant le transport dépend de la rareté du familier et de la vitesse du propriétaire : Config.Carry.
	MaxCarryTime = 60, -- à vitesse normale ; plus long si on est ralenti (au-delà, le familier est lâché et rentre seul)
	HoldDuration = 0.3, -- temps d'appui sur [E] pour voler
	PromptDistance = 8, -- distance d'affichage de la bulle [E] (studs)
	MaxDistance = 16, -- distance max acceptée par le serveur (marge pour la latence)
	-- Défense : la victime rattrape le voleur et appuie sur [E] ("Reprendre") pour récupérer son familier.
	RecoverPromptDistance = 10, -- distance d'affichage de la bulle "Reprendre" (studs)
	RecoverMaxDistance = 18, -- distance max acceptée par le serveur (les deux joueurs bougent : marge plus large)
}

-- Porter un familier (volé, ou le sien pris dans sa base) : server/StealController.
--   Vitesse = SpeedByRarity[rareté] x min(1, vitesse du propriétaire / vitesse du porteur) (25 oct.,
--   dataset_and_pipeline/ECONOMY_REPORT.md règle 5) : un voleur ne va jamais plus vite que le propriétaire avec un gros
--   butin, et la Force ne compte plus pour porter (elle sert à lancer loin). Avant : poids = taille^3 et Force, qui
--   faisaient disparaître le poids dès qu'on s'entraînait (un Sigma partait dès que son propriétaire était au tapis).
--   SpeedByRarity = 0,95 x 0,876^(rang - 1) : Commun au plafond (MaxSpeed) ; Sigma tout juste volable, à vitesse égale,
--   quand le propriétaire est de l'autre côté du trou (110 / (278 - 10 + 16 x 1,5) = 0,376).
-- Frappé à la batte, éjecté par le dôme, mort ou trop lent : le porteur LÂCHE le familier, qui rentre à pied vers la base
-- de son propriétaire (WalkHomeSpeed) ; n'importe qui peut le ramasser en chemin.
Config.Carry = {
	SpeedByRarity = { 0.95, 0.83, 0.73, 0.64, 0.56, 0.49, 0.43, 0.38 } :: { number }, -- Commun -> Sigma
	MinSpeed = 0.3,
	MaxSpeed = 0.95,
	MaxCarryTime = 180, -- secondes, même très ralenti
	WalkHomeSpeed = 9, -- studs/s, familier lâché qui rentre chez lui
}

-- Jeter un familier porté dans le trou noir (pendant le Feeding, à moins de Range studs du bord) : il est perdu pour
-- son propriétaire (le sien ou celui d'un autre !) et le porteur gagne une récompense selon le familier.
Config.Sacrifice = {
	Range = 22,
	IncomeSeconds = 600, -- argent = 10 min du revenu de ce familier (x bonus du monde et des passes)
	Points = { 2, 4, 8, 15, 30, 60, 120, 240 }, -- points du tour (donc tirages) et jauge du trou, selon la rareté
	-- Geste du lancer (client/PetFollow anime les bras, client/BlackholeFx fait voler le familier) :
	-- élan en arrière jusqu'à WindUp, les mains le lâchent à Release, bras revenus à End (secondes).
	Throw = { WindUp = 0.28, Release = 0.4, End = 0.85 },
}

-- Duels de familiers (server/DuelController, client/DuelClient, client/DuelFx).
--   [F] « Défier » sur un autre joueur -> il accepte -> chacun choisit un familier (raretés proches : MaxRarityGap) et
--   valide (les deux voient le choix de l'autre) -> les deux joueurs sont téléportés dans une arène qui flotte au-dessus
--   du trou noir (visible de toute la map) -> combat automatique, chaque joueur clique pour encourager le sien ->
--   le gagnant tourne la roue (Wheel, cases de même taille) : 1 case sur 8 = repartir avec le familier de l'adversaire.
-- Puissance d'un familier : PV = BaseHP et attaque = BaseAttack, x (1 + PerRarity par rareté au-dessus de Commun),
-- x (1 + SizeBonus x sa place dans la tranche de taille de sa rareté : le plus grand de la tranche a +10 %).
export type WheelSlot = { Kind: string, Label: string, Color: Color3, Seconds: number?, Pulls: number? }
Config.Duel = {
	PromptDistance = 12, -- distance de la bulle « Défier » sur un joueur
	RequestCooldown = 6, -- secondes entre deux défis lancés par le même joueur
	InviteTime = 15, -- secondes pour accepter
	PickTime = 60, -- secondes pour choisir son familier et valider
	MaxRarityGap = 1, -- une rareté d'écart au maximum
	ArenaCenter = Vector3.new(0, 165, 0), -- au-dessus du trou noir
	ArenaSpacing = 120, -- plusieurs duels en même temps : arènes côte à côte
	MaxArenas = 3,
	BaseHP = 150,
	BaseAttack = 12,
	PerRarity = 0.35,
	SizeBonus = 0.1,
	AttackInterval = 0.55, -- les deux familiers frappent chacun leur tour
	Spread = 0.2, -- dégâts x 0,8 à 1,2
	CritChance = 0.12,
	CritMultiplier = 2,
	CheerPerClick = 0.05, -- +5 % de dégâts par clic depuis le dernier coup
	CheerMax = 0.6, -- +60 % au plus
	CheerRate = 8, -- clics comptés par seconde au maximum
	MaxTime = 45, -- au-delà : le familier qui a le plus de PV (en %) gagne
	SpinTime = 4.5, -- durée de la roue
	Wheel = {
		{ Kind = "Pet", Label = "SON FAMILIER !", Color = Color3.fromRGB(255, 205, 50) },
		{ Kind = "Money", Label = "2 MIN D'ARGENT", Color = Color3.fromRGB(110, 235, 40), Seconds = 120 },
		{ Kind = "Pulls", Label = "1 TIRAGE", Color = Color3.fromRGB(54, 204, 254), Pulls = 1 },
		{ Kind = "Money", Label = "5 MIN D'ARGENT", Color = Color3.fromRGB(80, 200, 60), Seconds = 300 },
		{ Kind = "Respin", Label = "RELANCE !", Color = Color3.fromRGB(255, 120, 210) },
		{ Kind = "Money", Label = "2 MIN D'ARGENT", Color = Color3.fromRGB(110, 235, 40), Seconds = 120 },
		{ Kind = "Pulls", Label = "3 TIRAGES", Color = Color3.fromRGB(168, 40, 252), Pulls = 3 },
		{ Kind = "Money", Label = "10 MIN D'ARGENT", Color = Color3.fromRGB(255, 160, 40), Seconds = 600 },
	} :: { WheelSlot },
	MinIncome = 50, -- argent de la roue = revenu du gagnant par seconde (au moins 50 $/s) x Seconds
}

-- Échanges de familiers entre joueurs (server/TradeController, client/TradeClient).
--   [T] « Échanger » sur un joueur -> il accepte -> fenêtre ÉCHANGE : chacun met jusqu'à MaxPets familiers dans son offre
--   (on voit l'offre de l'autre en direct) -> double confirmation anti-arnaque : 1) les deux cliquent PRÊT (les offres
--   sont alors bloquées), 2) après ConfirmDelay secondes, les deux cliquent CONFIRMER. Toute modification annule les
--   validations. Le transfert se fait en une étape côté serveur (et revient en arrière si un familier a disparu).
Config.Trade = {
	PromptDistance = 12,
	RequestCooldown = 6,
	InviteTime = 15,
	MaxPets = 6, -- familiers par offre (exemplaires compris)
	ConfirmDelay = 3, -- secondes de vérification avant que CONFIRMER soit cliquable
	MaxTime = 240, -- un échange ouvert plus longtemps est annulé
}

-- Effets de satisfaction (client/Effects) : points qui s'envolent, ouverture des tirages rares, secousses d'écran.
Config.Effects = {
	RevealMinRarity = 4, -- ouverture animée à partir de cet index de rareté (4 = Épique)
	RevealTime = 3.5, -- durée de l'ouverture (s), fermable avant par un clic
	ShakeKnockback = 1, -- force des secousses (1 = forte)
	ShakeReveal = 0.5,
	ShakeStealAlarm = 0.35,
}

-- Sons et musique (joués par client/Sounds). Tous viennent des banques sous licence de Roblox
-- (APM Music, Pro Sound Effects, DistroKid) : pour changer un son, remplacer son Id ici.
export type SoundDef = { Id: number, Volume: number?, Pitch: number? }

Config.Sounds = {
	MusicVolume = 0.12, -- 13 oct. : baissée deux fois (0,3 puis 0,2)
	EffectsVolume = 0.7,
	MusicFade = 2, -- secondes de fondu entre deux morceaux
	-- Musique par monde (attribut "World" du joueur, client/SoundController) : les morceaux du monde s'enchaînent dans un
	-- ordre mélangé, en fondu. 13 oct. (2e version) : fond musical CALME et peu répétitif (lo-fi, chill-hop, guitare et
	-- piano doux, 1 min 30 à 4 min 30), à la place des ukulélés et des musiques orientales / épiques jugés pénibles.
	-- Bibliothèques sous licence Roblox : APM Music (APMOfficial) et DistroKid (DistrokidOfficial), vérifiées dans le jeu.
	Playlists = {
		{ -- 1 Prairie : guitare acoustique douce
			{ Id = 83546335370083, Volume = 0.7 }, -- "Soft Guitar in the Morning Light", 189 s
			{ Id = 136821672329242, Volume = 0.7 }, -- "Acoustic Guitar in Soft Focus", 183 s
			{ Id = 121991101341350, Volume = 0.7 }, -- "Soft Café Sunshine", 162 s
			{ Id = 9046863253, Volume = 0.6 }, -- "Poolside" (APM), 165 s
		},
		{ -- 2 Désert : chill chaud
			{ Id = 9046862941, Volume = 0.6 }, -- "Sunset Chill (Bed Version)" (APM), 134 s
			{ Id = 89402602954424, Volume = 0.7 }, -- "Pastel Corner Life", 199 s
			{ Id = 136397868028391, Volume = 0.7 }, -- "Warm Hug Melodies", 91 s
			{ Id = 9046691155, Volume = 0.6 }, -- "Drive-In" (APM), 92 s
		},
		{ -- 3 Volcan : chill-hop un peu plus rythmé
			{ Id = 9044974640, Volume = 0.6 }, -- "Straight Chill Hopper" (APM, Chill Hop), 150 s
			{ Id = 140218338777776, Volume = 0.7 }, -- "Lofi Chill 1.9", 145 s
			{ Id = 9046863579, Volume = 0.6 }, -- "City Lights" (APM), 120 s
			{ Id = 1846722291, Volume = 0.6 }, -- "Close To Home B" (APM), 101 s
		},
		{ -- 4 Glace : piano et flûte
			{ Id = 111630371595891, Volume = 0.7 }, -- "Soft piano, gentle flute, ambient guitar", 240 s
			{ Id = 138992141339152, Volume = 0.7 }, -- "Velvet evening melodies", 227 s
			{ Id = 138330265883042, Volume = 0.7 }, -- "Windowlight Coffee Calm", 215 s
		},
		{ -- 5 Abysses : lo-fi feutré
			{ Id = 140195496777664, Volume = 0.7 }, -- "Lofi (Rainy Window Reflections)", 276 s
			{ Id = 140492661889585, Volume = 0.7 }, -- "From morning fog to daylight (lo-fi)", 138 s
			{ Id = 136088611877555, Volume = 0.7 }, -- "Between cases (cozy lo-fi)", 180 s
		},
		{ -- 6 Cosmos : nappes rêveuses
			{ Id = 9046864489, Volume = 0.6 }, -- "Violet Clouds" (APM), 136 s
			{ Id = 9046863579, Volume = 0.6 }, -- "City Lights" (APM), 120 s
			{ Id = 140218338777776, Volume = 0.7 }, -- "Lofi Chill 1.9", 145 s
			{ Id = 140492661889585, Volume = 0.7 }, -- "From morning fog to daylight (lo-fi)", 138 s
		},
		{ -- 7 Divin : lumineux et doux
			{ Id = 9046909601, Volume = 0.6 }, -- "Gonna Be a Good Day - No Drums" (APM), 108 s
			{ Id = 111630371595891, Volume = 0.7 }, -- "Soft piano, gentle flute, ambient guitar", 240 s
			{ Id = 136397868028391, Volume = 0.7 }, -- "Warm Hug Melodies", 91 s
			{ Id = 9046862941, Volume = 0.6 }, -- "Sunset Chill (Bed Version)" (APM), 134 s
		},
	} :: { { SoundDef } },
	MusicDuck = 0.35, -- pendant un petit jingle (changement de phase), la musique descend à 35 %
	Effects = {
		Pickup = { Id = 9119668978, Volume = 0.8 }, -- pop cartoon
		Throw = { Id = 9120711836, Volume = 0.6 }, -- whoosh
		Consume = { Id = 9112752639, Volume = 0.9 }, -- bloup : un objet avalé par le trou noir
		Score = { Id = 9119668796, Volume = 0.5, Pitch = 1.4 }, -- petit pop aigu : points marqués
		Rewards = { Id = 1840076509, Volume = 0.7 }, -- jingle : résultats des tirages
		RareDrop = { Id = 1839881844, Volume = 0.7 }, -- jingle : familier Légendaire+ (annonce, arrivée)
		PetArrival = { Id = 9119668796, Volume = 0.8, Pitch = 0.8 }, -- pop grave : un familier atterrit
		StealStart = { Id = 9120711836, Volume = 0.8, Pitch = 0.8 }, -- whoosh grave : on attrape le familier
		StealAlarm = { Id = 9113085764, Volume = 0.6 }, -- alarme : on vole TON familier
		StealSuccess = { Id = 9038686624, Volume = 0.7 }, -- jingle : vol réussi
		StealFail = { Id = 115475565309914, Volume = 0.7 }, -- jingle raté : vol échoué / familier perdu
		Recovered = { Id = 9038684308, Volume = 0.7 }, -- jingle : familier récupéré
		Lock = { Id = 9113760542, Volume = 0.8 }, -- cliquetis : base verrouillée
		Purchase = { Id = 9044783668, Volume = 0.7 }, -- petit jingle : achat
		LevelUp = { Id = 1844016113, Volume = 0.6 }, -- jingle : niveau de Vitesse / Force
		Knockback = { Id = 9113564868, Volume = 0.8 }, -- paf ! : éjecté par le dôme
		Effort = { Id = 9120416707, Volume = 0.7 }, -- grognement d'effort au banc de muscu (Pro Sound Effects)
		-- Interface (client/UiStyle, client/MenuKit) et retours d'action.
		UiClick = { Id = 9119668978, Volume = 0.45, Pitch = 1.35 }, -- petit « pop » aigu à chaque bouton (Pro Sound Effects)
		WindowOpen = { Id = 9120711836, Volume = 0.35, Pitch = 1.5 }, -- whoosh léger à l'ouverture d'une fenêtre
		Error = { Id = 9119668978, Volume = 0.6, Pitch = 0.55 }, -- pop grave : pas assez d'argent, impossible
		Cash = { Id = 9113728756, Volume = 0.6 }, -- caisse enregistreuse : achat d'une amélioration
		Coins = { Id = 9113704038, Volume = 0.7 }, -- pluie de pièces : récompense d'Index, gros gain
		Tick = { Id = 9118138365, Volume = 0.5 }, -- tic : 5 dernières secondes d'une phase
		FusionDone = { Id = 1841209502, Volume = 0.7 }, -- scintillement : la fusion a réussi
		ModelUnlock = { Id = 9043151109, Volume = 0.6 }, -- jingle : nouveau modèle de tapis / banc
		PhaseFeeding = { Id = 1841324020, Volume = 0.6 }, -- jingle : le trou noir a faim
		PhaseDigesting = { Id = 9045119921, Volume = 0.6 }, -- jingle malicieux : il digère, le moment du vol
		-- Armes (joués en 3D à l'endroit de l'action, entendus par les joueurs proches).
		BatSwing = { Id = 9120711836, Volume = 0.7, Pitch = 0.85 }, -- whoosh de la batte
		BatHit = { Id = 9125380872, Volume = 0.9 }, -- « crac » de batte en bois (Pro Sound Effects)
		GrappleFire = { Id = 9120711836, Volume = 0.8, Pitch = 0.6 }, -- whoosh grave : le crochet part
		GrappleLatch = { Id = 9113760542, Volume = 0.9, Pitch = 1.2 }, -- clac métallique : le crochet accroche
		GrappleReel = { Id = 9118138365, Volume = 0.6, Pitch = 1.8 }, -- cliquetis rapide : la corde se rembobine
		Vanish = { Id = 9120711836, Volume = 0.7, Pitch = 1.9 }, -- fffuit aigu : quelqu'un devient invisible
		Reveal = { Id = 9119668978, Volume = 0.8, Pitch = 0.75 }, -- pop : il réapparaît
		-- Paliers du trou noir (client/BlackholeFx) : mêmes sons de la bibliothèque Roblox que ci-dessus.
		HoleTierUp = { Id = 1839881844, Volume = 0.8 }, -- jingle : le trou noir monte d'un palier
		HoleRumble = { Id = 9113564868, Volume = 0.9, Pitch = 0.45 }, -- paf grave : grondement, éruption
		HoleBonus = { Id = 9119668796, Volume = 0.7, Pitch = 1.8 }, -- pop très aigu : centre x2, combo
		HoleCatch = { Id = 9112752639, Volume = 1, Pitch = 0.6 }, -- gros bloup : un tentacule rattrape un objet
		HoleMeteors = { Id = 9120711836, Volume = 0.9, Pitch = 0.45 }, -- whoosh très grave : météorites
		HoleJackpot = { Id = 9113704038, Volume = 0.9 }, -- pluie de pièces : jackpot
		HoleCollapse = { Id = 1841209502, Volume = 0.9, Pitch = 0.7 }, -- scintillement grave : effondrement
	} :: { [string]: SoundDef },
}

export type ShopItem = {
	Id: string,
	Icon: string, -- nom d'une icône de shared/Icons
	Name: string,
	Description: string,
	MaxLevel: number,
	BasePrice: number,
	PriceGrowth: number, -- prix du niveau L+1 = BasePrice × PriceGrowth^L
}

-- Boutique : améliorations à niveaux. Le niveau est écrit dans l'attribut "Upgrade_<Id>" du Player.
Config.Shop = {
	{ Id = "Treadmill", Icon = "Treadmill", Name = "Tapis de course", Description = "À côté de ta base. Monte dessus : +vitesse. 25 niveaux et 10 modèles, du tapis en bois au tapis céleste : chaque niveau entraîne plus vite.", MaxLevel = 25, BasePrice = 500, PriceGrowth = 2.44 },
	{ Id = "Bench", Icon = "Bench", Name = "Banc de muscu", Description = "À côté de ta base. Allonge-toi dessus : +force (lancers plus loin). 25 niveaux et 10 modèles, du banc en bois au banc céleste.", MaxLevel = 25, BasePrice = 500, PriceGrowth = 2.44 },
	{ Id = "ItemQuality", Icon = "Clover", Name = "Chance", Description = "Plus de lingots, diamants et météorites sur tes palettes (+20 % de chance par niveau sur les objets rares).", MaxLevel = 10, BasePrice = 2000, PriceGrowth = 7.7 },
	{ Id = "Backpack", Icon = "Backpack", Name = "Sac à dos", Description = "Porte un objet de plus à chaque niveau.", MaxLevel = 4, BasePrice = 25e3, PriceGrowth = 150 },
	{ Id = "Magnet", Icon = "Magnet", Name = "Aimant à objets", Description = "Active ou coupe l’aimant avec son bouton. Priorité aux objets qui rapportent le plus. Plus de portée à chaque niveau.", MaxLevel = 5, BasePrice = 20e3, PriceGrowth = 9 },
	{ Id = "LongLock", Icon = "Lock", Name = "Verrou renforcé", Description = "Ta base reste fermée 55 s au lieu de 45 s quand tu passes sur le bouton (une fois par manche).", MaxLevel = 1, BasePrice = 5e6, PriceGrowth = 1 },
	-- Armes (achat unique, voir Config.Weapons) : rangées dans l'inventaire en bas de l'écran (touches 1, 2).
	{ Id = "WeaponBat", Icon = "Bat", Name = "Batte", Description = "ARME : un grand coup de batte qui envoie valser un joueur et lui fait TOUT lâcher (objets, familier volé).", MaxLevel = 1, BasePrice = 2000, PriceGrowth = 1 },
	{ Id = "PowerInvisible", Icon = "Ghost", Name = "Invisibilité", Description = "POUVOIR : 6 s presque invisible pour t'approcher en douce. Se brise dès que tu ramasses, voles, frappes ou te fais toucher. Recharge 45 s.", MaxLevel = 1, BasePrice = 500e3, PriceGrowth = 1 },
	{ Id = "WeaponGrapple", Icon = "Grapple", Name = "Grappin", Description = "ARME : vise un joueur et tire : le crochet l'attrape et le ramène jusqu'à toi. Parfait pour rattraper un voleur !", MaxLevel = 1, BasePrice = 150e3, PriceGrowth = 1 },
} :: { ShopItem }

export type BatDef = {
	SwingTime: number, -- durée du geste complet (s)
	StrikeAt: number, -- moment du coup dans le geste (0 à 1) : la cible est touchée à cet instant
	Word: string, -- onomatopée affichée sur la victime
	Range: number, -- portée en studs
	Push: number, -- vitesse d'éjection horizontale
	Up: number, -- vitesse d'éjection vers le haut
	Stun: number, -- secondes KO (la victime tourne dans les airs puis se relève)
	Cooldown: number, -- secondes entre deux coups
}
export type GrappleDef = {
	Range: number, -- portée du crochet (studs)
	AimCone: number, -- tolérance de visée (degrés autour de la direction visée)
	HookSpeed: number, -- vitesse du crochet en vol (studs/s), pour l'animation
	PullSpeed: number, -- vitesse à laquelle la victime est ramenée
	PullTime: number, -- durée maximale de la traction (s)
	StopDistance: number, -- la victime s'arrête à cette distance devant le tireur
	Cooldown: number,
}

-- Armes de PvP (server/WeaponController, client/WeaponFx). Une arme en main = pas de ramassage d'objet, et inversement.
-- Le combo : le grappin ramène un voleur, la batte lui fait lâcher le familier.
Config.Weapons = {
	Bat = {
		SwingTime = 0.55,
		StrikeAt = 0.45,
		Word = "BONK !",
		Range = 8,
		Push = 95,
		Up = 40,
		Stun = 1.4,
		Cooldown = 1.1,
	} :: BatDef,
	-- 25 oct. (dataset_and_pipeline/ECONOMY_REPORT.md règle 6) : il faut viser. AimCone 14 -> 8 : ~4 studs de marge à
	-- mi-portée (28 studs), la largeur d'un joueur qui porte plus le décalage du ping. Cooldown 5 -> 9 : la moitié du plus
	-- long trajet d'un voleur (Sigma, 18 s) : 2 tirs au plus sur un gros butin, 1 sur un petit. À vérifier à 2 joueurs.
	Grapple = {
		Range = 55,
		AimCone = 8,
		HookSpeed = 220,
		PullSpeed = 85,
		PullTime = 1.1,
		StopDistance = 5,
		Cooldown = 9,
	} :: GrappleDef,
	-- Anciennes armes (sauvegardes d'avant le 13 oct.) : converties à la lecture.
	OldWeapons = { WeaponSlap = { "WeaponBat" }, WeaponPan = { "WeaponBat" }, WeaponShockwave = { "WeaponBat", "WeaponGrapple" } } :: { [string]: { string } },
	-- Pouvoir d'invisibilité (server/PowerController, client/InvisibilityFx). Pensé pour ne pas être frustrant :
	-- court, long à recharger, imparfait (silhouette visible de près, étincelles aux pieds) et brisé par toute action.
	Invisibility = {
		Duration = 6,
		Cooldown = 45, -- compté depuis l'activation
		SelfTransparency = 0.6, -- ce que le joueur voit de lui-même
		FarTransparency = 0.96, -- vu par les autres, de loin : presque rien
		NearTransparency = 0.72, -- vu par les autres à moins de NearDistance : une silhouette fantomatique
		NearDistance = 10,
	},
	HitImmunity = 2, -- secondes pendant lesquelles un joueur touché ne peut pas être retouché (batte et grappin)
	-- Anti-acharnement (25 oct., ECONOMY_REPORT.md étape 2) : au plus MaxHitsPerWindow coups de batte par victime sur
	-- HitWindow secondes (28 % du temps au sol au maximum, au lieu de 70 %). 10 s = le trajet d'un vol (109 studs à 16)
	-- + la réaction + le KO : le temps de se relever et d'agir.
	HitWindow = 10,
	MaxHitsPerWindow = 2,
	RangeMargin = 3, -- studs de marge sur la portée (latence)
}

-- Prix du prochain niveau (nil si niveau max atteint).
-- Récompense d'Index d'un familier (argent).
-- incomeCap : plafond de revenu du joueur (shared/PowerCap) ; nil = pas de plafond.
function Config.GetIndexReward(petId: string, incomeCap: number?): number
	local PetCatalog = require(script.Parent.PetCatalog) :: any
	local income = math.min(PetCatalog.GetIncome(petId), incomeCap or math.huge)
	return math.max(Config.Index.MinReward, math.floor(income * Config.Index.RewardSeconds))
end

function Config.GetUpgradePrice(item: ShopItem, currentLevel: number): number?
	if currentLevel >= item.MaxLevel then
		return nil
	end
	return math.floor(item.BasePrice * item.PriceGrowth ^ currentLevel)
end

-- XP nécessaire pour passer du niveau "level" au suivant.
function Config.GetXPNeeded(level: number): number
	return math.floor(Config.Training.XPBase * Config.Training.XPGrowth ^ level)
end

export type Rarity = {
	Id: string, -- clé sans accent (attributs)
	Name: string, -- nom affiché
	Weight: number, -- poids de tirage (les chances sont normalisées ; voir aussi Config.Worlds[].RarityBoost)
	Color: Color3,
	Multiplier: number, -- bonus de points quand le familier est équipé
	Income: number, -- $/s de base quand le familier est sur un socle (chaque familier a un bonus de 0 à +45 %, cf. PetCatalog.GetIncome)
}

-- Ordre = du plus commun au plus rare.
-- 20 oct. (docs/PLAN_EQUILIBRAGE.md) : revenus lissés (environ x7 d'une rareté à l'autre au lieu de x12 à x100) et
-- raretés hautes bien plus rares au départ ; ce sont les mondes (RarityBoost) qui les rendent accessibles.
Config.Rarities = {
	{ Id = "Commun", Name = "Commun", Weight = 500, Color = Color3.fromRGB(200, 200, 200), Multiplier = 1.1, Income = 2 },
	{ Id = "Inhabituel", Name = "Inhabituel", Weight = 260, Color = Color3.fromRGB(100, 220, 90), Multiplier = 1.2, Income = 14 },
	{ Id = "Rare", Name = "Rare", Weight = 140, Color = Color3.fromRGB(70, 160, 255), Multiplier = 1.35, Income = 100 },
	{ Id = "Epique", Name = "Épique", Weight = 60, Color = Color3.fromRGB(180, 80, 255), Multiplier = 1.6, Income = 700 },
	{ Id = "Legendaire", Name = "Légendaire", Weight = 28, Color = Color3.fromRGB(255, 170, 30), Multiplier = 2, Income = 5e3 },
	{ Id = "Mythique", Name = "Mythique", Weight = 9, Color = Color3.fromRGB(255, 70, 120), Multiplier = 3, Income = 35e3 },
	{ Id = "Divin", Name = "Divin", Weight = 2.5, Color = Color3.fromRGB(120, 255, 245), Multiplier = 5, Income = 250e3 },
	{ Id = "Sigma", Name = "Sigma", Weight = 0.5, Color = Color3.fromRGB(255, 230, 60), Multiplier = 10, Income = 1.75e6 },
} :: { Rarity }

-- Accès rapide : Config.RarityIndex["Epique"] = 4
Config.RarityIndex = {} :: { [string]: number }
for index, rarity in ipairs(Config.Rarities) do
	Config.RarityIndex[rarity.Id] = index
end

Config.BaseColors = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(90, 240, 180),
	Color3.fromRGB(255, 120, 210),
	Color3.fromRGB(250, 230, 90),
	Color3.fromRGB(120, 230, 255),
}

Config.ItemColors = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(120, 255, 120),
	Color3.fromRGB(255, 120, 220),
	Color3.fromRGB(255, 160, 50),
}

-- Paliers du trou noir (server/BlackholeTiers, client/BlackholeFx) : une jauge COMMUNE à tout le serveur se remplit
-- avec les objets avalés (valeur de l'objet, sans multiplicateur des familiers). Pleine, le trou monte d'un palier :
-- nouvel aspect + une petite mécanique, toujours un bonus, jamais une punition. Après le palier 7, Effondrement à la
-- digestion suivante (score du tour x2, familiers offerts aux 3 meilleurs contributeurs) puis retour au palier 1.
-- Wall = 3 couleurs du décor du palier (roches de l'Éruption, anneaux de la Cible, or du Divin...). Le muret autour du
-- trou, lui, prend les couleurs du MONDE de chaque joueur (client/BlackholeFx, shared/Worlds). TopNeon : plus utilisé.
export type HoleTier = {
	Name: string,
	Color: Color3,
	Color2: Color3,
	Hint: string,
	Wall: { Color3 },
	TopNeon: boolean?,
}
Config.Blackhole = {
	-- Jauge à remplir pour quitter chaque palier, pour 1 joueur ; multipliée par (nombre de joueurs) ^ PlayerScaling.
	-- 25 oct. (ECONOMY_REPORT.md règle 13) : la jauge compte en « objets ordinaires » (Config.MeanGaugePerItem), plus en
	-- valeur : le tour ne s'accélère plus avec la Chance (avant : 7 paliers en 5 min en fin de partie). Un joueur lance
	-- 16 à 38 objets par manche. Total x1,26 (555 -> 700) pour qu'à 8 joueurs au maximum (8 x 38 objets) chaque palier dure
	-- au moins une manche : 8 manches x 8 x 38 / 8^0,6 = 699. Tour complet : 14 à 33 min à 8, 32 à 76 min seul.
	GaugeNeed = { 50, 63, 76, 95, 113, 139, 164 },
	PlayerScaling = 0.6,
	Tiers = {
		{ Name = "ÉVEIL", Color = Color3.fromRGB(150, 0, 255), Color2 = Color3.fromRGB(255, 90, 230), Hint = "IL SE RÉVEILLE : NOURRIS-LE !",
			Wall = { Color3.fromRGB(150, 70, 230), Color3.fromRGB(125, 55, 200), Color3.fromRGB(255, 120, 230) } },
		{ Name = "ÉRUPTION", Color = Color3.fromRGB(255, 110, 20), Color2 = Color3.fromRGB(255, 220, 60), Hint = "IL CRACHE DES ROCHES DE LAVE : x3 POINTS !",
			Wall = { Color3.fromRGB(70, 60, 64), Color3.fromRGB(54, 46, 50), Color3.fromRGB(255, 100, 30) }, TopNeon = true },
		{ Name = "CIBLE", Color = Color3.fromRGB(255, 50, 70), Color2 = Color3.fromRGB(255, 255, 255), Hint = "VISE LE MILIEU : POINTS x2 !",
			Wall = { Color3.fromRGB(240, 50, 60), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 205, 40) } },
		{ Name = "ABYSSES", Color = Color3.fromRGB(0, 200, 190), Color2 = Color3.fromRGB(120, 60, 200), Hint = "SES BRAS ATTRAPENT TES LANCERS RATÉS",
			Wall = { Color3.fromRGB(20, 70, 110), Color3.fromRGB(14, 56, 94), Color3.fromRGB(60, 220, 180) }, TopNeon = true },
		{ Name = "GRAVITÉ", Color = Color3.fromRGB(255, 160, 60), Color2 = Color3.fromRGB(110, 190, 255), Hint = "IL ATTIRE LES OBJETS ET FAIT TOMBER DES MÉTÉORITES",
			Wall = { Color3.fromRGB(70, 40, 120), Color3.fromRGB(54, 30, 100), Color3.fromRGB(255, 170, 60) } },
		{ Name = "SUPERNOVA", Color = Color3.fromRGB(120, 230, 255), Color2 = Color3.fromRGB(255, 120, 220), Hint = "LANCE SANS T'ARRÊTER : JUSQU'À x2 !",
			Wall = { Color3.fromRGB(60, 150, 230), Color3.fromRGB(40, 120, 210), Color3.fromRGB(255, 255, 255) } },
		{ Name = "DIVIN", Color = Color3.fromRGB(255, 205, 50), Color2 = Color3.fromRGB(255, 250, 225), Hint = "JACKPOT : x5 PENDANT 10 S !",
			Wall = { Color3.fromRGB(250, 244, 230), Color3.fromRGB(236, 226, 204), Color3.fromRGB(255, 205, 60) } },
	} :: { HoleTier },
	Lava = { Interval = 15, Count = 3, ValueMultiplier = 3, MinRadius = 70, MaxRadius = 125, FlightTime = 2 },
	Target = { Radius = 14, Multiplier = 2 }, -- point d'impact prévu à moins de 14 studs du centre
	Tentacles = { Reach = 14, MaxHeight = 10, MaxAge = 5 }, -- objet lancé tombé à moins de 14 studs du bord, depuis < 5 s
	Gravity = { PullRadius = 150, StopRadius = 52, Speed = 6, MeteorInterval = 18, MeteorCount = 3, MeteorValue = 5 },
	Combo = { Window = 5, Step = 0.25, Max = 2 }, -- +0,25 par lancer réussi à moins de 5 s du précédent, x2 max
	Jackpot = { Duration = 10, Multiplier = 5 },
	Collapse = { ScoreMultiplier = 2, Rewards = { "Legendaire", "Epique", "Epique" } }, -- 1er, 2e, 3e contributeur
}

----------------------------------------------------------------------
-- Rétention (16 oct.) : cadeau du jour, quêtes du jour, codes cadeaux, bonus d'amis, Rebirth.
-- server/ProgressionController (+ server/Quests pour la progression), fenêtres client/BonusMenu et client/RebirthMenu.
-- Les récompenses en argent sont en SECONDES DE REVENU du joueur (attribut "Income") : elles valent autant au début
-- qu'à la fin du jeu. MinMoney = plancher pour un joueur qui ne gagne encore presque rien.
-- Les tirages donnés sont des tirages gratuits (server/PullRewards) : des œufs, comme au trou noir.
----------------------------------------------------------------------

export type BonusReward = { Seconds: number?, Pulls: number? }

-- Cadeau du jour : un par jour (jour UTC), 7 jours d'affilée puis on recommence au jour 1. Un jour manqué = retour au jour 1.
Config.Daily = {
	MinMoney = 500,
	Rewards = {
		{ Seconds = 300 }, -- jour 1 : 5 min de revenu
		{ Pulls = 1 },
		{ Seconds = 900 },
		{ Pulls = 3 },
		{ Seconds = 1800 },
		{ Pulls = 5 },
		{ Seconds = 3600, Pulls = 10 }, -- jour 7 : le gros cadeau
	} :: { BonusReward },
}

-- Quêtes du jour : 3 par jour (facile, moyenne, difficile), tirées au hasard dans Pool (toujours 3 sortes différentes),
-- les mêmes toute la journée. Goals = objectif selon la difficulté. Rewards = récompense selon la difficulté.
export type QuestDef = { Id: string, Text: string, Goals: { number } }
Config.Quests = {
	PerDay = 3,
	Pool = {
		{ Id = "Feed", Text = "JETTE %d OBJETS DANS LE TROU NOIR", Goals = { 25, 60, 150 } },
		{ Id = "Pulls", Text = "GAGNE %d ŒUFS", Goals = { 3, 8, 20 } },
		{ Id = "Hatch", Text = "FAIS ÉCLORE %d ŒUFS", Goals = { 3, 8, 20 } },
		{ Id = "Train", Text = "GAGNE %d NIVEAUX DE VITESSE OU DE FORCE", Goals = { 2, 5, 10 } },
		{ Id = "Upgrade", Text = "ACHÈTE %d FOIS DANS LA BOUTIQUE", Goals = { 1, 3, 6 } },
		{ Id = "Steal", Text = "VOLE %d FAMILIERS AUX AUTRES", Goals = { 1, 2, 4 } },
	} :: { QuestDef },
	Rewards = {
		{ Seconds = 600 }, -- facile : 10 min de revenu
		{ Seconds = 1200, Pulls = 1 },
		{ Seconds = 2400, Pulls = 3 }, -- difficile
	} :: { BonusReward },
	MinMoney = 500,
}

-- Codes cadeaux : à taper dans la fenêtre Bonus (majuscules / minuscules et espaces ignorés), une fois par joueur.
-- Until = date de fin (os.time(), UTC) facultative. Ajouter un code ici puis Publier : il marche tout de suite.
-- Same = le même code dans une autre langue (29 oct. : les codes anglais) : on ne peut prendre que l'un des deux.
export type GiftCode = { Reward: BonusReward, Until: number?, Same: string? }
Config.Codes = {
	LANCEMENT = { Reward = { Seconds = 1800, Pulls = 3 } },
	TROUNOIR = { Reward = { Pulls = 2 } },
	MERCI = { Reward = { Seconds = 900 } },
	LAUNCH = { Reward = { Seconds = 1800, Pulls = 3 }, Same = "LANCEMENT" },
	BLACKHOLE = { Reward = { Pulls = 2 }, Same = "TROUNOIR" },
	THANKS = { Reward = { Seconds = 900 }, Same = "MERCI" },
} :: { [string]: GiftCode }

-- Invitations récompensées (29 oct., docs/STRATEGIE_JOUEURS.md B1) : bouton « INVITE TES AMIS » du HUD
-- (SocialService). Un joueur qui arrive pour la 1re fois par l'invitation de quelqu'un (Player:GetJoinData().
-- ReferredByPlayerId) reçoit NewPlayerReward ; celui qui l'a invité, s'il est sur le même serveur, reçoit FriendReward,
-- une fois par nouvel ami et MaxRewards fois au plus (server/ProgressionController, champ sauvegardé « referral »).
Config.Invite = {
	NewPlayerReward = { Pulls = 2 } :: BonusReward,
	FriendReward = { Pulls = 2 } :: BonusReward,
	MaxRewards = 5,
}

-- Trou noir doré (29 oct., docs/STRATEGIE_JOUEURS.md B3 ; shared/GoldenHour, client/GoldenHour) : rendez-vous toutes
-- les heures pile (heure UTC, la même sur tous les serveurs). Pendant les Minutes premières minutes de chaque heure,
-- les points des objets jetés dans le trou noir sont multipliés par PointsMultiplier (donc plus d'œufs) ; WarnSeconds
-- avant, un compte à rebours s'affiche sous l'horloge. Environ +8 % de points pour qui joue une heure entière.
-- Studio : workspace:SetAttribute("DebugGoldenShift", secondes) avance l'horloge du trou doré (ex. 3600 - os.time() % 3600 - 70).
Config.GoldenHour = {
	Minutes = 5,
	PointsMultiplier = 2,
	WarnSeconds = 60,
}

-- Notifications Roblox (29 oct., docs/STRATEGIE_JOUEURS.md B2 ; shared/NotifyPlan, server/Notifications) : au départ
-- d'un joueur, le serveur prévoit UNE notification (Roblox en laisse passer une par jour et par jeu) : « tes œufs
-- sont prêts » si un œuf finit dans les EggWindow secondes, sinon « ton cadeau du jour t'attend » DailyDelay secondes
-- plus tard. Un serveur du jeu ouvert à ce moment-là l'envoie (MemoryStore) ; si le joueur revient avant, elle est
-- annulée. Le joueur doit avoir accepté (fenêtre de Roblox ouverte par client/HUD après le cadeau du jour).
-- Pour l'activer (Chouaib, Creator Hub) : créer les 4 textes (Engagement → Notifications), copier leurs Asset ID
-- dans Strings ; créer une clé API Open Cloud (droit user.user-notification:write sur ce jeu) et la ranger dans les
-- Secrets du jeu sous le nom Secret ; autoriser les requêtes HTTP (Paramètres du jeu → Sécurité). Tant qu'un Asset
-- ID manque, rien n'est envoyé.
Config.Notifications = {
	Secret = "NotifyKey",
	-- Asset ID des textes (Engagement → Notifications → ⋯ → Copy Asset ID), un par langue ; "" = pas encore créé.
	Strings = {
		-- « 🥚 Tes œufs sont prêts à éclore ! Viens voir ce qui en sort. » (créés le 29 oct.)
		EggReady = { fr = "b52782b0-4426-154e-b077-80d2a79c19db", en = "5286a1d8-b0bc-c74b-9b95-f3ca536b2353" },
		-- « 🎁 Ton cadeau du jour t'attend : jour {day} ! »
		Daily = { fr = "76c974ea-32ee-a541-b1d4-07a4a043fb42", en = "5e1b01f2-51a7-694a-b8d0-d15fd09c311c" },
	} :: { [string]: { fr: string, en: string } },
	EggWindow = 8 * 3600, -- un œuf qui finit au plus 8 h après le départ : notification quand il est prêt
	DailyDelay = 22 * 3600, -- sinon le cadeau du jour, 22 h après le départ (à peu près la même heure le lendemain)
	MinAway = 15 * 60, -- jamais moins de 15 min après le départ
	PollSeconds = 60, -- chaque serveur regarde les notifications à envoyer toutes les minutes
}

-- Bonus d'amis : +10 % de revenu par ami Roblox présent sur le même serveur, jusqu'à 5 amis (+50 %).
Config.Friends = {
	BonusPerFriend = 0.1,
	MaxFriends = 5,
	-- Jeu entre amis (25 oct., ECONOMY_REPORT.md règles 17 à 19, server/Friends, server/StealController) :
	--   - un joueur qui arrive reçoit, si elle est libre, une base voisine de celle d'un ami (server/BaseManager) ;
	--   - refuge : un familier volé peut être rapporté dans la base d'un ami présent (il va quand même au voleur) ;
	--   - escorte : un ami à moins de EscortRadius studs du porteur, et le familier compte comme une rareté plus légère
	--     (Config.Carry.SpeedByRarity, +14 % de vitesse) ; 15 studs = la portée de la batte (8 + 3) avec un peu de marge ;
	--   - « Reprendre » pour un ami : les amis de la victime voient la bulle et peuvent rendre le familier à son propriétaire.
	EscortRadius = 15,
	CheckTimeout = 3, -- secondes au plus pour vérifier les amitiés d'un joueur qui arrive (avant de choisir sa base)
}

-- Rebirth : quand on a atteint le dernier monde, on paie Price(n) pour recommencer en Prairie avec 0 $ et les
-- améliorations de la Boutique à zéro (armes et pouvoir gardés). On GARDE familiers, œufs, mutations, entraînement,
-- clés et achats Robux. En échange, à vie : revenu x(1 + IncomeBonus x rebirths), +ExtraPets familier(s) dans la base
-- (ceux qui rapportent, Config.Pets.IncomeSlots), jusqu'à MaxExtraPets, et +ExtraCapsules chambre(s) dans la capsule
-- d'évolution, jusqu'à MaxExtraCapsules (25 oct., ECONOMY_REPORT.md règle 15 : ce qui fait encore monter le revenu en
-- fin de partie ; la place de base en plus ne rapporte que +2 %).
Config.Rebirth = {
	RequiredTier = 7, -- monde à avoir atteint (7 = Divin, le dernier)
	BasePrice = 4e12, -- prix du 1er Rebirth ($4T) : vers 9 h de jeu (tools/sim-economy.luau)
	-- 25 oct. (ECONOMY_REPORT.md règle 16) : prix(n) = BasePrice x (n + 1) x PriceGrowth^n. Le (n + 1) suit le
	-- multiplicateur de revenu ; 1,62 = croissance de la base par cycle avec les chambres (x1,47, mesurée) x 1,1 (chaque
	-- cycle un peu plus long que le précédent). Cycles simulés : 3,7 h, 3,6 h, 3,7 h, 4,4 h, 5,2 h, 6,4 h (avant : x2,7,
	-- cycles de 6 h puis 9 h dès le 5e Rebirth).
	PriceGrowth = 1.62,
	IncomeBonus = 1, -- +100 % de revenu par Rebirth : x2, x3, x4...
	ExtraPets = 1, -- +1 familier qui rapporte dans la base par Rebirth
	MaxExtraPets = 5,
	ExtraCapsules = 1, -- +1 chambre de capsule d'évolution par Rebirth
	MaxExtraCapsules = 5, -- 6 chambres au plus
	KeepShopItems = { WeaponBat = true, WeaponGrapple = true, PowerInvisible = true }, -- pas remis à zéro
}

function Config.GetRebirthPrice(rebirths: number): number
	return Config.Rebirth.BasePrice * (rebirths + 1) * Config.Rebirth.PriceGrowth ^ rebirths
end

-- Chambres de la capsule d'évolution selon le nombre de Rebirths.
function Config.GetCapsuleSlots(rebirths: number): number
	return Config.Evolution.Slots + math.min(rebirths * Config.Rebirth.ExtraCapsules, Config.Rebirth.MaxExtraCapsules)
end

function Config.GetRebirthMultiplier(rebirths: number): number
	return 1 + Config.Rebirth.IncomeBonus * rebirths
end

-- Familiers qui rapportent (et se baladent) dans la base selon le nombre de Rebirths.
function Config.GetIncomeSlots(rebirths: number): number
	return Config.Pets.IncomeSlots + math.min(rebirths * Config.Rebirth.ExtraPets, Config.Rebirth.MaxExtraPets)
end

Config.Colors = {
	Feeding = Color3.fromRGB(150, 0, 255),
	Digesting = Color3.fromRGB(255, 40, 40),
}

return Config
