--!strict
-- Worlds : le visuel des 7 mondes (les prix et bonus sont dans Config.Worlds). Lu par client/WorldSkin.
--   Palette : une couleur par rôle de pièce (attribut "Skin" posé par server/MapGenerator). Un rôle absent garde la
--             couleur de la Prairie. Neon = la pièce brille (lave, cristaux...).
--   Ambience : air (Atmosphere), teinte de l'image (ColorCorrection), nuages, particules qui flottent autour du joueur.
--   Decor : ce qui remplace les arbres (même emplacement) : "Trees", "Cactus", "LavaRock", "IceCrystal", "Coral",
--           "Asteroid", "Pillar".

local Worlds = {}

export type Ambience = {
	AirColor: Color3,
	AirDecay: Color3,
	AirDensity: number,
	Tint: Color3,
	Saturation: number,
	CloudColor: Color3,
	CloudCover: number,
	Particles: string?, -- "Sand", "Embers", "Snow", "Bubbles", "Stars", "Feathers"
}

export type Look = {
	Accent: Color3, -- couleur de la carte du monde (fenêtre Mondes, titre d'arrivée)
	Palette: { [string]: Color3 },
	Neon: { [string]: boolean }?,
	Ambience: Ambience,
	Decor: string,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Worlds.Looks = {
	Prairie = {
		Accent = rgb(110, 214, 42),
		Palette = {},
		-- air et teinte du préréglage « jour » de dataset_and_pipeline/map_art_bible.json (25 oct.)
		Ambience = { AirColor = rgb(207, 226, 255), AirDecay = rgb(122, 150, 208), AirDensity = 0.3, Tint = rgb(255, 250, 240), Saturation = 0.18, CloudColor = rgb(255, 255, 255), CloudCover = 0.55 },
		Decor = "Trees",
	},
	Desert = {
		Accent = rgb(245, 180, 60),
		Palette = {
			GrassA = rgb(250, 214, 130), GrassB = rgb(238, 196, 106),
			PathA = rgb(214, 150, 90), PathB = rgb(196, 132, 76),
			WallA = rgb(226, 160, 92), WallB = rgb(206, 140, 78), WallTop = rgb(250, 220, 140),
			Stone = rgb(236, 200, 140),
			WoodRail = rgb(190, 110, 60), WoodPost = rgb(120, 76, 50), WoodCap = rgb(150, 96, 62),
			Trunk = rgb(70, 160, 70), LeavesA = rgb(80, 180, 80), LeavesB = rgb(60, 150, 60), LeavesC = rgb(110, 200, 90),
		},
		-- air et teinte de dataset_and_pipeline/map_art_bible_desert.json (25 oct.)
		Ambience = { AirColor = rgb(255, 224, 176), AirDecay = rgb(232, 154, 90), AirDensity = 0.32, Tint = rgb(255, 240, 220), Saturation = 0.2, CloudColor = rgb(255, 240, 220), CloudCover = 0.2, Particles = "Sand" },
		Decor = "Cactus",
	},
	Volcan = {
		Accent = rgb(255, 90, 30),
		Palette = {
			GrassA = rgb(70, 60, 64), GrassB = rgb(54, 46, 50),
			PathA = rgb(255, 120, 30), PathB = rgb(240, 80, 20),
			HoleA = rgb(40, 20, 20), HoleB = rgb(28, 14, 14),
			WallA = rgb(60, 50, 56), WallB = rgb(46, 38, 42), WallTop = rgb(255, 100, 30),
			Stone = rgb(90, 80, 84),
			WoodRail = rgb(40, 34, 36), WoodPost = rgb(255, 110, 30), WoodCap = rgb(255, 160, 50),
			Trunk = rgb(40, 34, 36), LeavesA = rgb(70, 60, 64), LeavesB = rgb(54, 46, 50), LeavesC = rgb(255, 110, 30),
		},
		Neon = { PathA = true, PathB = true, WallTop = true, WoodPost = true, WoodCap = true, LeavesC = true },
		Ambience = { AirColor = rgb(255, 150, 100), AirDecay = rgb(120, 40, 30), AirDensity = 0.38, Tint = rgb(255, 215, 195), Saturation = 0.25, CloudColor = rgb(90, 70, 70), CloudCover = 0.6, Particles = "Embers" },
		Decor = "LavaRock",
	},
	Glace = {
		Accent = rgb(110, 210, 255),
		Palette = {
			GrassA = rgb(240, 248, 255), GrassB = rgb(214, 234, 250),
			PathA = rgb(150, 210, 245), PathB = rgb(124, 190, 235),
			WallA = rgb(170, 215, 245), WallB = rgb(146, 196, 236), WallTop = rgb(255, 255, 255),
			Stone = rgb(200, 225, 245),
			WoodRail = rgb(120, 170, 220), WoodPost = rgb(80, 120, 170), WoodCap = rgb(255, 255, 255),
			Trunk = rgb(110, 80, 60), LeavesA = rgb(60, 130, 100), LeavesB = rgb(40, 110, 86), LeavesC = rgb(250, 252, 255),
		},
		Ambience = { AirColor = rgb(220, 240, 255), AirDecay = rgb(150, 190, 230), AirDensity = 0.32, Tint = rgb(225, 240, 255), Saturation = 0.05, CloudColor = rgb(240, 248, 255), CloudCover = 0.7, Particles = "Snow" },
		Decor = "IceCrystal",
	},
	Abysses = {
		Accent = rgb(40, 200, 200),
		Palette = {
			GrassA = rgb(40, 110, 130), GrassB = rgb(30, 92, 114),
			PathA = rgb(230, 210, 150), PathB = rgb(210, 190, 130),
			WallA = rgb(20, 70, 110), WallB = rgb(14, 56, 94), WallTop = rgb(60, 220, 180),
			Stone = rgb(70, 140, 150),
			WoodRail = rgb(255, 120, 140), WoodPost = rgb(30, 60, 90), WoodCap = rgb(255, 170, 90),
			Trunk = rgb(255, 120, 140), LeavesA = rgb(255, 150, 90), LeavesB = rgb(230, 90, 160), LeavesC = rgb(90, 230, 200),
		},
		Neon = { WallTop = true, LeavesC = true },
		Ambience = { AirColor = rgb(80, 180, 210), AirDecay = rgb(20, 70, 120), AirDensity = 0.45, Tint = rgb(190, 235, 245), Saturation = 0.15, CloudColor = rgb(100, 180, 210), CloudCover = 0.2, Particles = "Bubbles" },
		Decor = "Coral",
	},
	Cosmos = {
		Accent = rgb(170, 90, 255),
		Palette = {
			GrassA = rgb(56, 34, 96), GrassB = rgb(42, 24, 78),
			PathA = rgb(120, 220, 255), PathB = rgb(90, 190, 255),
			HoleA = rgb(20, 8, 36), HoleB = rgb(12, 4, 24),
			WallA = rgb(70, 40, 120), WallB = rgb(54, 30, 100), WallTop = rgb(255, 120, 240),
			Stone = rgb(110, 80, 170),
			WoodRail = rgb(140, 90, 255), WoodPost = rgb(30, 16, 60), WoodCap = rgb(120, 230, 255),
			Trunk = rgb(150, 110, 220), LeavesA = rgb(190, 140, 255), LeavesB = rgb(120, 80, 220), LeavesC = rgb(255, 150, 240),
		},
		Neon = { PathA = true, PathB = true, WallTop = true, WoodCap = true },
		Ambience = { AirColor = rgb(150, 110, 255), AirDecay = rgb(40, 20, 90), AirDensity = 0.3, Tint = rgb(225, 210, 255), Saturation = 0.25, CloudColor = rgb(170, 130, 255), CloudCover = 0.15, Particles = "Stars" },
		Decor = "Asteroid",
	},
	Divin = {
		Accent = rgb(255, 215, 80),
		Palette = {
			GrassA = rgb(255, 252, 240), GrassB = rgb(244, 236, 214),
			PathA = rgb(255, 214, 90), PathB = rgb(240, 190, 60),
			HoleA = rgb(255, 240, 200), HoleB = rgb(245, 225, 170),
			WallA = rgb(250, 244, 230), WallB = rgb(236, 226, 204), WallTop = rgb(255, 205, 60),
			Stone = rgb(255, 245, 220),
			WoodRail = rgb(255, 205, 60), WoodPost = rgb(250, 248, 240), WoodCap = rgb(255, 225, 120),
			Trunk = rgb(250, 248, 240), LeavesA = rgb(255, 255, 255), LeavesB = rgb(245, 240, 225), LeavesC = rgb(255, 215, 80),
		},
		Neon = { WallTop = true, LeavesC = true },
		Ambience = { AirColor = rgb(255, 245, 220), AirDecay = rgb(255, 220, 160), AirDensity = 0.28, Tint = rgb(255, 248, 230), Saturation = 0.1, CloudColor = rgb(255, 255, 255), CloudCover = 0.8, Particles = "Feathers" },
		Decor = "Pillar",
	},
} :: { [string]: Look }

return Worlds
