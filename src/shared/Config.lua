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
	FloorRadius = 260,
	HoleRadius = 40, -- rayon de la BlackholeZone (disque 80x80)
	HoleConsumeHeight = 20, -- un item doit être sous cette hauteur au-dessus du trou pour être avalé
	DomeRadius = 55, -- rayon du dôme répulsif pendant la digestion
	BaseCount = 8,
	BaseRingRadius = 175, -- distance du centre au centre des bases
	BaseSize = Vector3.new(56, 1, 56),
}

-- Apparition des objets (par base occupée).
Config.Items = {
	Size = 2.5,
	SpawnInterval = 4, -- secondes entre deux apparitions dans une base
	InitialPerBase = 4, -- objets posés d'un coup au début du Feeding
	MaxPerBase = 6,
	MaxLooseItems = 80, -- au-delà, les plus vieux objets abandonnés sont nettoyés
}

-- Lancer (côté client).
Config.Throw = {
	MinSpeed = 45,
	MaxSpeed = 165,
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

-- Statistique de vitesse (entraînement sur le tapis de course).
Config.Speed = {
	Base = 16,
	Max = 50,
	GainPerSecond = 1,
	BeltSpeed = 14, -- vitesse du tapis roulant qui repousse le joueur
}

-- Tirages : 1 objet avalé = 1 point × multiplicateur des familiers équipés.
-- Le coût d'un tirage augmente à chaque tirage de la même manche (évite l'emballement).
Config.Loot = {
	PullCost = 5, -- coût du 1er tirage (minimum 1 tirage si score > 0)
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

-- Test : dans Roblox Studio uniquement, chaque joueur reçoit 1 exemplaire de chaque familier
-- (pour voir tous les modèles). Mettre à false pour tester la vraie progression.
Config.StudioGiveAllPets = true

-- Argent : revenu passif des familiers + bonus de fin de digestion.
Config.Economy = {
	MoneyPerPoint = 10, -- chaque point marqué rapporte aussi de l'argent à la digestion
}

-- Verrouillage de base (bouton au sol, comme Steal a Brainrot).
Config.Lock = {
	Duration = 60,
	LongDuration = 90, -- avec l'amélioration "LongLock"
	ButtonRadius = 4,
}

export type ShopItem = {
	Id: string,
	Name: string,
	Description: string,
	Price: number,
}

-- Catalogue de la boutique (ordre d'affichage). Chaque achat écrit l'attribut "Unlock_<Id>" sur le Player.
Config.Shop = {
	{ Id = "Treadmill", Name = "Tapis de course", Description = "Apparaît derrière ta base. Cours dessus pendant la digestion : +vitesse.", Price = 250 },
	{ Id = "StrongArm", Name = "Bras musclé", Description = "Lancers 25% plus puissants.", Price = 750 },
	{ Id = "LongLock", Name = "Verrou renforcé", Description = "Ta base reste fermée 90 s au lieu de 60 s.", Price = 1500 },
} :: { ShopItem }

Config.StrongArmMultiplier = 1.25

export type Rarity = {
	Id: string, -- clé sans accent (attributs)
	Name: string, -- nom affiché
	Weight: number, -- poids de tirage (total = 1000)
	Color: Color3,
	Multiplier: number, -- bonus de points quand le familier est équipé
	Income: number, -- $/s quand le familier est dans la base
}

-- Ordre = du plus commun au plus rare.
Config.Rarities = {
	{ Id = "Commun", Name = "Commun", Weight = 500, Color = Color3.fromRGB(200, 200, 200), Multiplier = 1.1, Income = 1 },
	{ Id = "Inhabituel", Name = "Inhabituel", Weight = 250, Color = Color3.fromRGB(100, 220, 90), Multiplier = 1.2, Income = 3 },
	{ Id = "Rare", Name = "Rare", Weight = 120, Color = Color3.fromRGB(70, 160, 255), Multiplier = 1.35, Income = 8 },
	{ Id = "Epique", Name = "Épique", Weight = 70, Color = Color3.fromRGB(180, 80, 255), Multiplier = 1.6, Income = 20 },
	{ Id = "Legendaire", Name = "Légendaire", Weight = 40, Color = Color3.fromRGB(255, 170, 30), Multiplier = 2, Income = 50 },
	{ Id = "Mythique", Name = "Mythique", Weight = 15, Color = Color3.fromRGB(255, 70, 120), Multiplier = 3, Income = 150 },
	{ Id = "Divin", Name = "Divin", Weight = 4, Color = Color3.fromRGB(120, 255, 245), Multiplier = 5, Income = 500 },
	{ Id = "Sigma", Name = "Sigma", Weight = 1, Color = Color3.fromRGB(255, 230, 60), Multiplier = 10, Income = 2000 },
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
