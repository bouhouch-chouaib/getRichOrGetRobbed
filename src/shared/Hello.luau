-- Configuration de la map "Steal a Brainrot"
-- Toutes les dimensions sont en studs.

local Config = {}

-- Dimensions générales
Config.GroundSize = Vector3.new(400, 2, 200)   -- sol principal
Config.PathWidth = 40                          -- largeur du chemin central
Config.BaseSize = Vector3.new(50, 1, 50)       -- taille d'une base
Config.BaseSpacing = 20                        -- espace entre deux bases
Config.BasesPerRow = 4                         -- nombre de bases par rangée
Config.BaseOffsetX = 90                        -- distance du chemin aux rangées de bases

-- Palette très colorée et joyeuse
Config.Colors = {
	Ground      = Color3.fromRGB(120, 220, 120),  -- vert tendre
	Path        = Color3.fromRGB(255, 220, 90),   -- jaune soleil
	PathStripe  = Color3.fromRGB(255, 120, 180),  -- rose bonbon
	BaseColors  = {
		Color3.fromRGB(255, 100, 100),  -- rouge corail
		Color3.fromRGB(100, 180, 255),  -- bleu ciel
		Color3.fromRGB(180, 120, 255),  -- violet pastel
		Color3.fromRGB(255, 180, 80),   -- orange mangue
		Color3.fromRGB(120, 255, 200),  -- menthe
		Color3.fromRGB(255, 140, 220),  -- rose
		Color3.fromRGB(255, 240, 120),  -- jaune citron
		Color3.fromRGB(140, 220, 255),  -- turquoise
	},
	TreeTrunk   = Color3.fromRGB(150, 90, 50),
	TreeLeaves  = Color3.fromRGB(80, 200, 100),
	Cloud       = Color3.fromRGB(255, 255, 255),
	Neon        = Color3.fromRGB(255, 80, 200),
}

return Config
