--!strict
-- PetSignatureAuras : aura « signature » de quelques familiers (25 oct. 2026), À LA PLACE des auras de rareté de
-- PetSculptedEffects (anneaux, éclats, auréoles en blocs). Une aura ne se modélise pas (Chouaib) : effets tout faits
-- du Creator Store, dont on n'a gardé que les images (ni le modèle, ni ses scripts) :
--   rbxassetid://935947741  flammes noires (« Black flame tail », modèle 89194108265492)
--   rbxassetid://9135310747 éclair, planche 4x4 (aura d'éclairs rouges, modèle 12276491211)
-- Cerbère Infernal : flammes noires et rouges qui montent DERRIÈRE le corps (ZOffset négatif : elles dessinent sa
-- silhouette comme un haki d'anime sans cacher les têtes) + éclairs orange devant. Réglée sur un Cerbère de 12 studs
-- de haut, mise à l'échelle de la taille réelle. Moins de particules en qualité graphique basse (téléphone) : flammes
-- grandes exprès. Photos : dataset_and_pipeline/qa_renders/cerberus_aura_*.jpg.
local Signature = {}

local V, CF = Vector3.new, CFrame.new
local NS, NSK = NumberSequence.new, NumberSequenceKeypoint.new
local CS, CSK = ColorSequence.new, ColorSequenceKeypoint.new

local FLAME = "rbxassetid://935947741"
local BOLT = "rbxassetid://9135310747"
local REFERENCE_HEIGHT = 12 -- studs : hauteur du Cerbère sur lequel l'aura a été réglée

Signature.MaxRate = 120 -- particules / s au total (le budget des auras de rareté est 28)

local function flames(parent: Instance, name: string, k: number, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = FLAME
	e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp -- sinon la flamme est couchée au sol
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = NumberRange.new(0.7, 1.1)
	e.Speed = NumberRange.new(4 * k, 7 * k)
	e.Acceleration = V(0, 4 * k, 0)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Rotation = NumberRange.new(-12, 12)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Squash = NS({ NSK(0, 0), NSK(0.5, 0.15), NSK(1, 0) })
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e:SetAttribute("Aura", true)
	e.Parent = parent
	return e
end

local function cerberus(m: Model, box: CFrame, size: Vector3)
	local k = size.Y / REFERENCE_HEIGHT
	-- Pièce invisible qui donne le volume d'émission : la moitié haute du corps, un peu plus large que lui.
	local volume = Instance.new("Part")
	volume.Name = "AuraVolume"
	volume.Size = V(size.X * 1.05, size.Y * 0.4, size.Z * 0.85)
	volume.CFrame = box * CF(0, size.Y * 0.1, 0)
	volume.Transparency = 1
	volume.Anchored, volume.CanCollide, volume.CanTouch, volume.CanQuery, volume.Massless = true, false, false, false, true
	volume.CastShadow = false
	volume:SetAttribute("Aura", true)
	volume.Parent = m

	flames(volume, "FlammesRouges", k, {
		Rate = 40,
		Size = NS({ NSK(0, 2.5 * k), NSK(0.4, 7.5 * k), NSK(1, 2 * k) }),
		Transparency = NS({ NSK(0, 1), NSK(0.15, 0.3), NSK(0.7, 0.55), NSK(1, 1) }),
		Color = CS({ CSK(0, Color3.fromRGB(255, 40, 10)), CSK(1, Color3.fromRGB(120, 0, 0)) }),
		LightEmission = 0.5,
		Brightness = 2,
		ZOffset = -3 * k,
	})
	flames(volume, "FlammesNoires", k, {
		Rate = 35,
		Size = NS({ NSK(0, 2 * k), NSK(0.4, 5.5 * k), NSK(1, 1.5 * k) }),
		Transparency = NS({ NSK(0, 1), NSK(0.15, 0), NSK(0.7, 0.25), NSK(1, 1) }),
		Color = CS({ CSK(0, Color3.new(0, 0, 0)), CSK(1, Color3.fromRGB(40, 4, 2)) }),
		LightEmission = 0,
		Brightness = 1,
		ZOffset = -2 * k,
	})

	local bolt = Instance.new("ParticleEmitter")
	bolt.Name = "Eclairs"
	bolt.Texture = BOLT
	bolt.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	bolt.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	bolt.Shape = Enum.ParticleEmitterShape.Box
	bolt.Rate = 40
	bolt.Lifetime = NumberRange.new(0.15, 0.25)
	bolt.Speed = NumberRange.new(0, 0)
	bolt.Size = NS({ NSK(0, 5 * k, 1.5 * k), NSK(1, 5 * k, 1.5 * k) })
	bolt.Squash = NS({ NSK(0, -1.18), NSK(0.67, -0.18), NSK(1, -1.11) })
	bolt.Transparency = NS(0)
	bolt.Color = CS(Color3.fromRGB(255, 90, 30))
	bolt.LightEmission = 1
	bolt.LightInfluence = 0
	bolt.Brightness = 8
	bolt.ZOffset = 3 * k
	bolt.Rotation = NumberRange.new(0, 360)
	bolt.LockedToPart = true
	bolt:SetAttribute("Aura", true)
	bolt.Parent = volume

	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = Color3.fromRGB(255, 70, 30)
	light.Range = math.min(16 * k, 40)
	light.Brightness = 1
	light.Shadows = false
	light:SetAttribute("Aura", true)
	light.Parent = volume
end

local builders: { [string]: (Model, CFrame, Vector3) -> () } = {
	CerbereInfernal = cerberus,
}

-- Ce familier (Id de l'espèce) a-t-il une aura signature ?
function Signature.Has(species: string): boolean
	return builders[species] ~= nil
end

-- Pose l'aura signature de l'espèce sur le modèle (box / size : boîte visible du familier, déjà à sa taille).
-- Renvoie false si l'espèce n'en a pas (les auras de rareté s'appliquent alors).
function Signature.Add(m: Model, species: string, box: CFrame, size: Vector3): boolean
	local build = builders[species]
	if not build then
		return false
	end
	build(m, box, size)
	return true
end

return Signature
