--!strict
-- Config : toutes les valeurs d'équilibrage du jeu, au même endroit.
-- Partagé client/serveur (le client en a besoin pour l'arc de lancer et le HUD).

local Config = {}

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
	BaseSize = Vector3.new(56, 1, 56),
}

-- Apparition des objets (par base occupée).
Config.Items = {
	StarterCount = 5, -- objets offerts dans la base à l'arrivée d'un joueur
	SpawnInterval = 2, -- pendant le Feeding, un objet apparaît toutes les 2 s dans chaque base occupée
	MaxPerBase = 12, -- 4 palettes : ~3 objets par palette
	-- Objets "sauvages" dans l'arène (hors des bases), ramassables par tout le monde pendant le Feeding.
	WildInterval = 4, -- un objet sauvage toutes les 4 s
	WildMax = 25,
	WildQuality = 2, -- équivaut à 2 niveaux de Chance : un peu plus précieux que dans les bases
	WildMinRadius = 70, -- hors du dôme
	WildMaxRadius = 170, -- avant les bases et les kiosques
	MaxLooseItems = 80, -- au-delà, les plus vieux objets abandonnés sont nettoyés
	QualityBoost = 0.5, -- par niveau de "Chance" : poids des objets précieux ×(1 + 0.5 × niveau)^rang
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
	Glow: boolean?, -- particules brillantes
}

-- Du moins au plus précieux.
Config.ItemTiers = {
	{ Id = "Caillou", Name = "Caillou", Value = 0.25, Weight = 1000, Color = Color3.fromRGB(150, 150, 155), Shape = Enum.PartType.Block, Size = 1.8, Material = Enum.Material.Slate },
	{ Id = "Brique", Name = "Brique", Value = 0.5, Weight = 350, Color = Color3.fromRGB(200, 85, 60), Shape = Enum.PartType.Block, Size = 2.1, Material = Enum.Material.Brick },
	{ Id = "Cristal", Name = "Cristal", Value = 1, Weight = 100, Color = Color3.fromRGB(80, 220, 255), Shape = Enum.PartType.Block, Size = 2, Material = Enum.Material.Neon },
	{ Id = "Lingot", Name = "Lingot d'or", Value = 2.5, Weight = 25, Color = Color3.fromRGB(255, 200, 40), Shape = Enum.PartType.Block, Size = 2.2, Material = Enum.Material.Foil, Glow = true },
	{ Id = "Diamant", Name = "Diamant", Value = 6, Weight = 6, Color = Color3.fromRGB(200, 250, 255), Shape = Enum.PartType.Block, Size = 2, Material = Enum.Material.Neon, Glow = true },
	{ Id = "Meteorite", Name = "Météorite", Value = 15, Weight = 1, Color = Color3.fromRGB(170, 60, 255), Shape = Enum.PartType.Block, Size = 2.6, Material = Enum.Material.Neon, Glow = true },
} :: { ItemTier }

-- Lancer (côté client). La vitesse max dépend de la Force (attribut "ThrowPower").
Config.Throw = {
	MinRatio = 0.35, -- lancer sans charge = 35 % de la vitesse max
	MaxChargeTime = 1.5,
	UpBias = 0.6, -- ajouté au LookVector de la caméra avant normalisation
	ChargeWalkSpeed = 8,
	ChargeFov = 55,
	DefaultFov = 70,
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
-- XP gagnée par seconde sur la station = StationRates[niveau de la station].
export type StatConfig = { Base: number, PerLevel: number, MaxLevel: number }
Config.Training = {
	Speed = { Base = 16, PerLevel = 0.5, MaxLevel = 60 } :: StatConfig, -- WalkSpeed
	Strength = { Base = 70, PerLevel = 3, MaxLevel = 60 } :: StatConfig, -- vitesse de lancer max
	XPBase = 5,
	XPGrowth = 1.12,
	StationRates = { 1, 2, 3.5, 6, 10 },
	StationMaterials = {
		{ Name = "Bois", Color = Color3.fromRGB(150, 100, 55), Material = Enum.Material.Wood },
		{ Name = "Pierre", Color = Color3.fromRGB(140, 140, 145), Material = Enum.Material.Slate },
		{ Name = "Fer", Color = Color3.fromRGB(180, 185, 195), Material = Enum.Material.DiamondPlate },
		{ Name = "Or", Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Foil },
		{ Name = "Diamant", Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Glass },
	},
	BeltSpeed = 14, -- vitesse du tapis roulant qui repousse le joueur
}

-- Tirages : un objet avalé rapporte sa valeur (Config.ItemTiers) × multiplicateur des familiers équipés.
-- Le coût d'un tirage augmente à chaque tirage de la même manche (évite l'emballement).
Config.Loot = {
	PullCost = 2, -- coût du 1er tirage (minimum 1 tirage si score > 0)
	PullCostGrowth = 0.08, -- +8 % de coût à chaque tirage suivant
	LuckPerPoint = 0.01, -- chaque point augmente un peu le poids des raretés hautes
	MaxLuck = 1, -- au maximum, poids des raretés hautes ×2
	PityPulls = 60, -- au plus tard au 60e tirage sans Épique+, un Épique+ est garanti
	PityMinRarity = 4, -- index de rareté garanti par la pitié (4 = Épique)
	AnnounceMinRarity = 5, -- annonce serveur à partir de cet index (5 = Légendaire)
}

-- Familiers.
Config.Pets = {
	EquipSlots = 1, -- familiers équipés (multiplicateur + suivent le joueur)
	IncomeSlots = 10, -- seuls les N meilleurs familiers de la base rapportent de l'argent
}

-- Machine de fusion : Count familiers d'une même rareté -> 1 familier aléatoire de la rareté au-dessus.
-- Possible jusqu'à MaxFromRarity (6 = Mythique -> Divin). Le Sigma ne s'obtient que par chance.
Config.Fusion = {
	Count = 5,
	MaxFromRarity = 6,
	Costs = { 250, 15e3, 750e3, 40e6, 2.5e9, 250e9 }, -- prix en $ selon la rareté fusionnée (index de rareté)
}

-- Test : dans Roblox Studio uniquement, chaque joueur reçoit 1 exemplaire de chaque familier
-- (pour voir tous les modèles). Mettre à false pour tester la vraie progression.
Config.StudioGiveAllPets = false

-- Argent : revenu passif des familiers + bonus de fin de digestion.
Config.Economy = {
	MoneyPerPoint = 15, -- chaque point marqué rapporte aussi de l'argent à la digestion
}

-- Verrouillage de base (bouton au sol, comme Steal a Brainrot).
Config.Lock = {
	Duration = 5, -- relancé à chaque fois que le propriétaire repasse sur le bouton
	LongDuration = 10, -- avec l'amélioration "LongLock"
	ButtonRadius = 4,
}

export type ShopItem = {
	Id: string,
	Icon: string,
	Name: string,
	Description: string,
	MaxLevel: number,
	BasePrice: number,
	PriceGrowth: number, -- prix du niveau L+1 = BasePrice × PriceGrowth^L
}

-- Boutique : améliorations à niveaux. Le niveau est écrit dans l'attribut "Upgrade_<Id>" du Player.
Config.Shop = {
	{ Id = "Treadmill", Icon = "🏃", Name = "Tapis de course", Description = "À côté de ta base. Cours dessus : +vitesse. Chaque niveau entraîne plus vite.", MaxLevel = 5, BasePrice = 500, PriceGrowth = 120 },
	{ Id = "Bench", Icon = "🏋", Name = "Banc de muscu", Description = "À côté de ta base. Monte dessus : +force (lancers plus loin). Chaque niveau entraîne plus vite.", MaxLevel = 5, BasePrice = 500, PriceGrowth = 120 },
	{ Id = "ItemQuality", Icon = "🍀", Name = "Chance", Description = "Plus de lingots, diamants et météorites sur tes palettes (+50 % de chance par niveau sur les objets rares).", MaxLevel = 10, BasePrice = 2000, PriceGrowth = 18 },
	{ Id = "Backpack", Icon = "🎒", Name = "Sac à dos", Description = "Porte un objet de plus à chaque niveau.", MaxLevel = 4, BasePrice = 25e3, PriceGrowth = 400 },
	{ Id = "LongLock", Icon = "🔒", Name = "Verrou renforcé", Description = "Ta base reste fermée 10 s au lieu de 5 s à chaque passage sur le bouton.", MaxLevel = 1, BasePrice = 5e6, PriceGrowth = 1 },
} :: { ShopItem }

-- Prix du prochain niveau (nil si niveau max atteint).
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
	Weight: number, -- poids de tirage (total = 1000)
	Color: Color3,
	Multiplier: number, -- bonus de points quand le familier est équipé
	Income: number, -- $/s de base quand le familier est sur un socle (chaque familier a un bonus de 0 à +45 %, cf. PetCatalog.GetIncome)
}

-- Ordre = du plus commun au plus rare.
Config.Rarities = {
	{ Id = "Commun", Name = "Commun", Weight = 500, Color = Color3.fromRGB(200, 200, 200), Multiplier = 1.1, Income = 2 },
	{ Id = "Inhabituel", Name = "Inhabituel", Weight = 250, Color = Color3.fromRGB(100, 220, 90), Multiplier = 1.2, Income = 25 },
	{ Id = "Rare", Name = "Rare", Weight = 120, Color = Color3.fromRGB(70, 160, 255), Multiplier = 1.35, Income = 400 },
	{ Id = "Epique", Name = "Épique", Weight = 70, Color = Color3.fromRGB(180, 80, 255), Multiplier = 1.6, Income = 8e3 },
	{ Id = "Legendaire", Name = "Légendaire", Weight = 40, Color = Color3.fromRGB(255, 170, 30), Multiplier = 2, Income = 200e3 },
	{ Id = "Mythique", Name = "Mythique", Weight = 15, Color = Color3.fromRGB(255, 70, 120), Multiplier = 3, Income = 6e6 },
	{ Id = "Divin", Name = "Divin", Weight = 4, Color = Color3.fromRGB(120, 255, 245), Multiplier = 5, Income = 250e6 },
	{ Id = "Sigma", Name = "Sigma", Weight = 1, Color = Color3.fromRGB(255, 230, 60), Multiplier = 10, Income = 25e9 },
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

Config.Colors = {
	Feeding = Color3.fromRGB(150, 0, 255),
	Digesting = Color3.fromRGB(255, 40, 40),
}

return Config
