--!strict
-- Aura du Cerbère Secret (essai 1.5, 25 oct. 2026) : flammes noires et rouges qui montent derrière le familier
-- + éclairs orange. Rien n'est dessiné à la main : les deux textures viennent d'effets tout faits du Creator Store
-- (on ne garde que l'image, pas le modèle ni ses scripts) :
--   rbxassetid://935947741  « Black flame tail » (modèle 89194108265492, flammes noires)
--   rbxassetid://9135310747 éclair, planche 4x4 (modèle 12276491211, aura d'éclairs rouges)
-- Les flammes ont un ZOffset négatif : elles passent derrière le corps et dessinent sa silhouette (effet « haki »
-- d'anime) sans cacher la tête. Elles démarrent petites et au-dessus des pattes pour ne pas être coupées par le sol.
-- Moins de particules en qualité graphique basse (téléphone, Studio en arrière-plan) : flammes grandes exprès.
--
-- Usage (Studio, barre MCP ou script) : require(CerbereAura).apply(meshPartDuCerbere)

local CerbereAura = {}

local NS, NSK = NumberSequence.new, NumberSequenceKeypoint.new
local CS, CSK = ColorSequence.new, ColorSequenceKeypoint.new

local FLAME = "rbxassetid://935947741"
local BOLT = "rbxassetid://9135310747"

local function flames(name: string, parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = FLAME
	e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = NumberRange.new(0.7, 1.1)
	e.Speed = NumberRange.new(4, 7)
	e.Acceleration = Vector3.new(0, 4, 0)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Rotation = NumberRange.new(-12, 12)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Squash = NS({ NSK(0, 0), NSK(0.5, 0.15), NSK(1, 0) })
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- Ajoute l'aura sur `body` (le MeshPart du familier). Renvoie la pièce invisible qui porte les effets.
function CerbereAura.apply(body: BasePart): BasePart
	local old = body.Parent and body.Parent:FindFirstChild("AuraVolume")
	if old then
		old:Destroy()
	end
	local h = body.Size.Y
	local vol = Instance.new("Part")
	vol.Name = "AuraVolume"
	vol.Transparency = 1
	vol.CanCollide, vol.CanQuery, vol.CanTouch = false, false, false
	vol.Massless = true
	vol.Anchored = body.Anchored
	vol.Size = Vector3.new(body.Size.X * 1.05, h * 0.4, body.Size.Z * 0.85)
	vol.CFrame = body.CFrame * CFrame.new(0, h * 0.1, 0)
	if not body.Anchored then
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = body, vol
		weld.Parent = vol
	end

	flames("FlammesRouges", vol, {
		Rate = 40,
		Size = NS({ NSK(0, 2.5), NSK(0.4, 7.5), NSK(1, 2) }),
		Transparency = NS({ NSK(0, 1), NSK(0.15, 0.3), NSK(0.7, 0.55), NSK(1, 1) }),
		Color = CS({ CSK(0, Color3.fromRGB(255, 40, 10)), CSK(1, Color3.fromRGB(120, 0, 0)) }),
		LightEmission = 0.5,
		Brightness = 2,
		ZOffset = -3,
	})
	flames("FlammesNoires", vol, {
		Rate = 35,
		Size = NS({ NSK(0, 2), NSK(0.4, 5.5), NSK(1, 1.5) }),
		Transparency = NS({ NSK(0, 1), NSK(0.15, 0), NSK(0.7, 0.25), NSK(1, 1) }),
		Color = CS({ CSK(0, Color3.new(0, 0, 0)), CSK(1, Color3.fromRGB(40, 4, 2)) }),
		LightEmission = 0,
		Brightness = 1,
		ZOffset = -2,
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
	bolt.Size = NS({ NSK(0, 5, 1.5), NSK(1, 5, 1.5) })
	bolt.Squash = NS({ NSK(0, -1.18), NSK(0.67, -0.18), NSK(1, -1.11) })
	bolt.Transparency = NS(0)
	bolt.Color = CS(Color3.fromRGB(255, 90, 30))
	bolt.LightEmission = 1
	bolt.LightInfluence = 0
	bolt.Brightness = 8
	bolt.ZOffset = 3
	bolt.Rotation = NumberRange.new(0, 360)
	bolt.LockedToPart = true
	bolt.Parent = vol

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 70, 30)
	light.Range = 16
	light.Brightness = 1
	light.Parent = vol

	vol.Parent = body.Parent
	return vol
end

return CerbereAura
