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
--   │          ◉              │   z -31 : bouton de verrouillage
--   └──────────┐ entrée ┌─────┘
-- [tapis]  [bac]          [bac]  [banc]   dehors, devant : un bac au milieu de chaque moitié de l'avant ; le tapis et
--            AVANT (-Z, trou noir)        le banc aux coins avant, un peu en diagonale

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BaseLayout = {}

local HALF = Config.Arena.BaseSize.X / 2
BaseLayout.HALF = HALF

-- Avant : bouton de verrouillage au milieu.
BaseLayout.Lock = Vector2.new(0, -HALF + 11)

-- Bacs à objets (26 oct., avant : 2 palettes dans la base) : DEHORS, au sol de l'arène, DEVANT la base (29 oct., avant :
-- contre les côtés), au milieu de chaque moitié de l'avant, de part et d'autre de l'entrée, en long le long de la
-- clôture (BIN_YAW). Les objets à jeter y tombent et le joueur les prend en revenant du trou noir, sans entrer chez lui.
-- Taille du bac (X, hauteur du rebord, Z) et hauteur de son fond intérieur, en studs : le modèle ArtModels.BacObjets
-- (Blender, props/BacObjets.py) a les mêmes mesures.
BaseLayout.Bins = { Vector2.new(-(HALF + 7) / 2, -HALF - 5.5), Vector2.new((HALF + 7) / 2, -HALF - 5.5) }
BaseLayout.BIN_YAW = 90 -- degrés : le long côté du bac (Z du modèle) suit la clôture avant
BaseLayout.BIN_SIZE = Vector3.new(7, 2.7, 10)
BaseLayout.BIN_FLOOR = 0.86

-- Stations d'entraînement (29 oct., avant : contre les côtés à z = -4) : DEHORS, aux coins avant, un peu plus en avant
-- que l'ancienne place des bacs ; tapis de course à gauche, banc à droite, tournés en diagonale (la console du tapis
-- regarde l'avant, vers l'extérieur). Position du centre et rotation (degrés autour de Y).
BaseLayout.Treadmill = Vector2.new(-HALF - 10, -HALF + 1)
BaseLayout.Bench = Vector2.new(HALF + 10, -HALF + 1)
BaseLayout.STATION_YAW = 30 -- vers l'extérieur : +30° pour le tapis (gauche), -30° pour le banc (droite)

-- Point d'apparition du propriétaire (et zone sûre), au milieu de la prairie.
BaseLayout.Spawn = Vector2.new(0, 6)

-- Prairie où se promènent les familiers : centre et demi-tailles.
BaseLayout.PetZoneCenter = Vector2.new(0, -3)
BaseLayout.PetZoneHalf = Vector2.new(HALF - 9, 19)

-- Couveuse au fond : un sol de paille, un rebord ouvert au milieu, 2 rangées de 4 nids (30 oct. : une place de la
-- couveuse par nid, Config.Eggs.MaxSlots ; avant 2 x 6).
BaseLayout.IncubatorCenter = Vector2.new(0, HALF - 11)
BaseLayout.IncubatorHalf = Vector2.new(HALF - 8, 8)
BaseLayout.NEST_COLUMNS = 4
BaseLayout.NEST_ROWS = 2
BaseLayout.MAX_NESTS = BaseLayout.NEST_COLUMNS * BaseLayout.NEST_ROWS
local NEST_SPACING = Vector2.new(13, 8)
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
