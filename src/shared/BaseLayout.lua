--!strict
-- BaseLayout : le plan d'une base, partagé par la carte (server/MapGenerator), les familiers (shared/PetWander) et
-- les œufs (server/EggController, client/Eggs). Une seule source pour que tout reste aligné.
--
-- Coordonnées locales (X, Z) en studs sur le dessus de la plateforme, (0, 0) = centre. -Z = l'entrée (côté trou
-- noir), +Z = le fond. La base fait Config.Arena.BaseSize (84 x 84 depuis le 15 oct., avant 56 x 56).
--
--                              [CAPSULE]   dehors, derrière la base : capsule d'évolution
--            FOND (+Z)
--   ┌─────────────────────────┐
--   │  COUVEUSE : 2 x 6 nids  │   z  23 .. 39
--   │ ─ ─ ─ ─ ┐     ┌ ─ ─ ─ ─ │   rebord, ouverture au milieu
--   │                         │
--   │   PRAIRIE DES FAMILIERS │   z -22 .. 16 (ils s'y promènent)
--   │          (spawn)        │
--   │ [palette]  ◉   [palette]│   z -32 : 2 palettes à objets, bouton de verrouillage
--   └──────────┐ entrée ┌─────┘
--            AVANT (-Z, trou noir)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BaseLayout = {}

local HALF = Config.Arena.BaseSize.X / 2
BaseLayout.HALF = HALF

-- Avant : bouton de verrouillage au milieu, une palette à objets de chaque côté.
BaseLayout.Lock = Vector2.new(0, -HALF + 11)
BaseLayout.Pallets = { Vector2.new(-HALF + 10, -HALF + 10), Vector2.new(HALF - 10, -HALF + 10) }

-- Point d'apparition du propriétaire (et zone sûre), au milieu de la prairie.
BaseLayout.Spawn = Vector2.new(0, 6)

-- Prairie où se promènent les familiers : centre et demi-tailles.
BaseLayout.PetZoneCenter = Vector2.new(0, -3)
BaseLayout.PetZoneHalf = Vector2.new(HALF - 9, 19)

-- Couveuse au fond : un sol de paille, un rebord ouvert au milieu, 2 rangées de 6 nids.
BaseLayout.IncubatorCenter = Vector2.new(0, HALF - 11)
BaseLayout.IncubatorHalf = Vector2.new(HALF - 8, 8)
BaseLayout.NEST_COLUMNS = 6
BaseLayout.NEST_ROWS = 2
BaseLayout.MAX_NESTS = BaseLayout.NEST_COLUMNS * BaseLayout.NEST_ROWS
local NEST_SPACING = Vector2.new(11, 8)
local NESTS_OFFSET_X = 0

-- Capsule d'évolution (Config.Evolution) : DEHORS, derrière la clôture du fond, côté droit (au sol de l'arène).
-- Le familier qui en sort rentre dans la base par EvolutionExit (la prairie, près de la capsule).
BaseLayout.EvolutionCapsule = Vector2.new(HALF - 14, HALF + 13)
BaseLayout.EvolutionExit = Vector2.new(HALF - 14, 14)

-- Position du nid n (1 = premier rang, à gauche).
function BaseLayout.Nest(index: number): Vector2
	local column = (index - 1) % BaseLayout.NEST_COLUMNS
	local row = (index - 1) // BaseLayout.NEST_COLUMNS
	return Vector2.new(
		NESTS_OFFSET_X + (column - (BaseLayout.NEST_COLUMNS - 1) / 2) * NEST_SPACING.X,
		BaseLayout.IncubatorCenter.Y - NEST_SPACING.Y / 2 + row * NEST_SPACING.Y
	)
end

return BaseLayout
