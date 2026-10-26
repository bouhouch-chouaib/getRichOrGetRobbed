--!strict
-- Worlds : le visuel des 7 mondes (les prix et bonus sont dans Config.Worlds). Lu par client/WorldSkin.
--   Palette : une couleur par rôle de pièce (attribut "Skin" posé par server/MapGenerator). Un rôle absent garde la
--             couleur de la Prairie. Neon = la pièce brille (lave, cristaux...).
--   Ambience : air (Atmosphere), teinte de l'image (ColorCorrection), nuages, particules qui flottent autour du joueur.
--   Decor : ce qui remplace les arbres (même emplacement) : "Trees", "Cactus", "LavaRock", "IceCrystal", "Coral",
--           "Asteroid", "Pillar".
--   Sky : ciel du monde, lu par client/WorldSkin. Pour chaque phase (Day = Digesting, Night = Feeding), les valeurs
--         données remplacent celles de Worlds.DayNight (brume et halo de l'air, nuages ; l'heure et la lumière pour
--         l'espace) ; une valeur absente garde celle de la phase. Pas d'image de ciel : la couleur vient de l'air
--         (Atmosphere Color / Decay, rendue visible par Haze), les étoiles, le soleil et la lune du Sky de Roblox.
--   Preview : aperçu du monde dans la fenêtre Mondes (client/WorldMenu) : petite scène 3D faite des décors du monde
--         (ReplicatedStorage.ArtModels.Map, posés par dataset_and_pipeline/studio_tools/apply_map_look*.lua) devant
--         son ciel ; en couleurs si le joueur y est déjà allé, en silhouettes mystérieuses sinon.

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

export type SkyPhase = {
	ClockTime: number?, -- heure vue par le joueur (l'espace reste de nuit pour garder ses étoiles)
	Brightness: number?,
	Exposure: number?,
	Ambient: Color3?,
	OutdoorAmbient: Color3?,
	Haze: number?, -- 0 à 10 : plus c'est haut, plus le ciel prend la couleur de l'air
	Glare: number?,
	CloudCover: number?,
}

export type Sky = {
	Day: SkyPhase,
	Night: SkyPhase,
	Stars: number, -- Sky.StarCount (0 à 5000), visibles quand le ciel est sombre
	SunSize: number?, -- degrés (Roblox : 21)
	MoonSize: number?, -- degrés (Roblox : 11)
	Celestial: boolean?, -- false : ni soleil ni lune (sous l'eau)
}

export type Preview = {
	Back: string, -- falaise du fond (doublée de chaque côté)
	Gate: string, -- porte du monde, au centre
	Sides: { string }, -- un décor de chaque côté de la porte
	SkyTop: Color3,
	SkyHorizon: Color3,
	Stars: boolean?, -- petites étoiles dans le ciel (espace)
}

export type Look = {
	Accent: Color3, -- couleur de la carte du monde (fenêtre Mondes, titre d'arrivée)
	Palette: { [string]: Color3 },
	Neon: { [string]: boolean }?,
	Ambience: Ambience,
	Decor: string,
	Sky: Sky?,
	Preview: Preview?,
}

-- Lumière d'une phase, la même pour tous les mondes (server/DayNightController) ; le ciel de chaque monde en
-- remplace une partie côté client (Look.Sky).
export type DayNight = {
	DayAmount: number, -- 0 nuit, 1 jour : publié en attribut de Lighting pendant le passage, lu par client/WorldSkin
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Exposure: number,
	CloudCover: number, -- nuages du Terrain : moins la nuit, sinon ils sortent gris foncé
	Bloom: { Intensity: number, Size: number, Threshold: number }, -- la nuit, runes et champignons ressortent
	Contrast: number,
	Glare: number, -- halo de l'air autour du soleil
	Haze: number, -- brume de l'horizon
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Préréglages « jour » / « nuit » de dataset_and_pipeline/map_art_bible.json (25 oct.).
Worlds.DayNight = {
	Feeding = { -- nuit : ciel bleu nuit étoilé (début de nuit, jamais noir), arène bien lisible
		DayAmount = 0,
		ClockTime = 19.4,
		Brightness = 2.2,
		Ambient = rgb(150, 155, 190),
		OutdoorAmbient = rgb(165, 170, 210),
		Exposure = 0.4,
		CloudCover = 0.12,
		Bloom = { Intensity = 0.6, Size = 26, Threshold = 1.3 },
		Contrast = 0.1,
		Glare = 0.1,
		Haze = 0.9,
	},
	Digesting = { -- jour : fantastique saturé, soleil un peu plus bas pour des ombres qui modèlent les décors
		DayAmount = 1,
		ClockTime = 14.5,
		Brightness = 2.6,
		Ambient = rgb(120, 120, 120),
		OutdoorAmbient = rgb(142, 142, 150),
		Exposure = 0.05,
		CloudCover = 0.55,
		Bloom = { Intensity = 0.45, Size = 22, Threshold = 1.6 },
		Contrast = 0.08,
		Glare = 0.35,
		Haze = 0.6,
	},
} :: { [string]: DayNight }

Worlds.Looks = {
	Prairie = {
		Accent = rgb(110, 214, 42),
		Palette = {},
		-- air et teinte du préréglage « jour » de dataset_and_pipeline/map_art_bible.json (25 oct.)
		Ambience = { AirColor = rgb(207, 226, 255), AirDecay = rgb(122, 150, 208), AirDensity = 0.3, Tint = rgb(255, 250, 240), Saturation = 0.18, CloudColor = rgb(255, 255, 255), CloudCover = 0.55 },
		Decor = "Trees",
		Preview = { Back = "FalaiseGradins", Gate = "ArcheAncienne", Sides = { "ArbreCerisier", "ChampignonGeant" },
			SkyTop = rgb(90, 160, 235), SkyHorizon = rgb(205, 232, 255) },
		Sky = { Day = {}, Night = {}, Stars = 3000 }, -- ciel bleu à cumulus, celui des préréglages
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
		Preview = { Back = "Desert_Mesa", Gate = "Desert_PorteTemple", Sides = { "Desert_Palmier", "Desert_Saguaro" },
			SkyTop = rgb(110, 170, 220), SkyHorizon = rgb(255, 215, 160) },
		-- ciel chaud et voilé, presque sans nuages, gros soleil ; nuits très étoilées
		Sky = {
			Day = { Haze = 2.3, Glare = 0.7, CloudCover = 0.08 },
			Night = { Haze = 1.1, Glare = 0.1, CloudCover = 0.03 },
			Stars = 5000,
			SunSize = 28,
		},
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
		Preview = { Back = "Volcan_Orgues", Gate = "Volcan_PorteForge", Sides = { "Volcan_ArbreCalcine", "Volcan_PilierBrasier" },
			SkyTop = rgb(60, 30, 30), SkyHorizon = rgb(255, 120, 60) },
		-- ciel de fumée rouge (l'air orangé couvre tout le ciel), nuages sombres, presque pas d'étoiles
		Sky = {
			Day = { Haze = 2.8, Glare = 0.2, CloudCover = 0.7 },
			Night = { Haze = 2.4, Glare = 0.05, CloudCover = 0.55 },
			Stars = 300,
		},
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
		-- saturation 0,12 (avant 0,05 : la neige paraissait terne ; map_art_bible_glace.json, 25 oct.)
		Ambience = { AirColor = rgb(220, 240, 255), AirDecay = rgb(150, 190, 230), AirDensity = 0.32, Tint = rgb(225, 240, 255), Saturation = 0.12, CloudColor = rgb(240, 248, 255), CloudCover = 0.7, Particles = "Snow" },
		Decor = "IceCrystal",
		Preview = { Back = "Glace_Glacier", Gate = "Glace_PorteGlace", Sides = { "Glace_Sapin", "Glace_Lanterne" },
			SkyTop = rgb(110, 170, 230), SkyHorizon = rgb(228, 242, 255) },
		-- ciel pâle et givré, nuages de neige ; nuits polaires très étoilées
		Sky = {
			Day = { Haze = 1.2, Glare = 0.5, CloudCover = 0.7 },
			Night = { Haze = 0.9, Glare = 0.1, CloudCover = 0.2 },
			Stars = 5000,
		},
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
		-- air moins dense (0,45 -> 0,34), teinte moins cyan, saturation 0,15 -> 0,26 : les coraux étaient délavés dans le
		-- bleu (vu en jeu le 25 oct., map_art_bible_abysses.json)
		Ambience = { AirColor = rgb(80, 180, 210), AirDecay = rgb(20, 70, 120), AirDensity = 0.34, Tint = rgb(215, 242, 250), Saturation = 0.26, CloudColor = rgb(100, 180, 210), CloudCover = 0.2, Particles = "Bubbles" },
		Decor = "Coral",
		Preview = { Back = "Abysses_Recif", Gate = "Abysses_PorteAtlante", Sides = { "Abysses_Corail", "Abysses_Algue" },
			SkyTop = rgb(10, 50, 90), SkyHorizon = rgb(60, 180, 210) },
		-- sous l'eau : le « ciel » est la couleur de l'eau, ni nuages, ni étoiles, ni soleil ; la nuit, eau sombre (une
		-- brume forte la rallume en cyan et délave les récifs : vu en jeu le 26 oct.)
		Sky = {
			Day = { Haze = 4, Glare = 0, CloudCover = 0 },
			Night = { Haze = 1.4, Glare = 0, CloudCover = 0 },
			Stars = 0,
			Celestial = false,
		},
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
		Preview = { Back = "Cosmos_Falaise", Gate = "Cosmos_PorteStellaire", Sides = { "Cosmos_ArbreAlien", "Cosmos_Pylone" },
			SkyTop = rgb(12, 6, 30), SkyHorizon = rgb(110, 60, 170), Stars = true },
		-- espace : toujours de nuit pour garder les étoiles et une grosse lune, horizon violet (l'air) ; le jour, la
		-- scène reste éclairée par la lumière ambiante et l'exposition (map_art_bible_cosmos.json)
		Sky = {
			Day = {
				ClockTime = 20.1,
				Brightness = 2.6,
				Exposure = 0.55,
				Ambient = rgb(160, 150, 205),
				OutdoorAmbient = rgb(178, 165, 228),
				Haze = 1.8,
				Glare = 0.3,
				CloudCover = 0,
			},
			Night = { ClockTime = 21.6, Exposure = 0.45, Haze = 1, Glare = 0.1, CloudCover = 0 },
			Stars = 5000,
			MoonSize = 40,
		},
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
		-- saturation 0,1 -> 0,26 et teinte un peu plus dorée : le marbre blanc se confondait avec le sol blanc (vu en jeu
		-- le 26 oct., map_art_bible_divin.json)
		Ambience = { AirColor = rgb(255, 245, 220), AirDecay = rgb(255, 220, 160), AirDensity = 0.28, Tint = rgb(255, 242, 220), Saturation = 0.26, CloudColor = rgb(255, 255, 255), CloudCover = 0.8, Particles = "Feathers" },
		Decor = "Pillar",
		Preview = { Back = "Divin_Falaise", Gate = "Divin_PorteCeleste", Sides = { "Divin_ArbreDore", "Divin_Tour" },
			SkyTop = rgb(70, 140, 230), SkyHorizon = rgb(255, 225, 160) },
		-- ciel doré lumineux, nuages légers, soleil éclatant (trop de nuages : ciel gris couvert, vu en jeu le 26 oct.) ;
		-- le jour, exposition retenue et brume plus légère (sinon tout le marbre tire au blanc)
		Sky = {
			Day = { Exposure = -0.2, Haze = 1.6, Glare = 0.9, CloudCover = 0.4 },
			Night = { Haze = 1.2, Glare = 0.25, CloudCover = 0.25 },
			Stars = 2500,
			SunSize = 30,
		},
	},
} :: { [string]: Look }

return Worlds
