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

-- Loot : 1 objet avalé = 1 point.
Config.Loot = {
	PointsPerPull = 5, -- un tirage tous les 5 points (minimum 1 tirage si score > 0)
	LuckPerPoint = 0.04, -- chaque point augmente le poids des raretés hautes
	MaxLuck = 3, -- multiplicateur max = 1 + MaxLuck
}

-- Argent : revenu passif des familiers + bonus de fin de digestion.
Config.Economy = {
	MoneyPerPoint = 10, -- chaque objet avalé rapporte aussi de l'argent à la digestion
	-- Revenu par seconde de chaque familier possédé, par rareté.
	PetIncome = {
		Commun = 1,
		Rare = 5,
		Epique = 25,
		Sigma = 200,
	} :: { [string]: number },
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
	Name: string,
	Weight: number,
	Color: Color3,
}

-- Ordre = du plus commun au plus rare. Poids entiers (total de base = 1000).
Config.Rarities = {
	{ Name = "Commun", Weight = 800, Color = Color3.fromRGB(200, 200, 200) },
	{ Name = "Rare", Weight = 150, Color = Color3.fromRGB(80, 170, 255) },
	{ Name = "Epique", Weight = 49, Color = Color3.fromRGB(190, 90, 255) },
	{ Name = "Sigma", Weight = 1, Color = Color3.fromRGB(255, 200, 40) },
} :: { Rarity }

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
