--!strict
-- Effects are deliberately outside the body bounds, with a small fixed emitter budget.
local CollectionService = game:GetService("CollectionService")
local S = require(script.Parent.PetSculpt)
local Catalog = require(script.Parent.PetCatalog)
local Config = require(script.Parent.Config)
local Signature = require(script.Parent.PetSignatureAuras)
local FX = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function emitter(
	parent: Instance,
	name: string,
	color: Color3,
	texture: string,
	rate: number,
	size: number,
	speed: number
): ParticleEmitter
	local fx = Instance.new("ParticleEmitter")
	fx.Name = name
	fx.Texture = texture
	fx.Rate = rate
	fx.Lifetime = NumberRange.new(0.65, 1.4)
	fx.Speed = NumberRange.new(speed * 0.5, speed)
	fx.SpreadAngle = Vector2.new(45, 45)
	fx.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.48))
	fx.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.2),
		NumberSequenceKeypoint.new(0.22, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	fx.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.16, 0.38),
		NumberSequenceKeypoint.new(1, 1),
	})
	fx.LightEmission = if texture == SMOKE then 0.25 else 0.75
	fx.LightInfluence = 0.25
	fx.Rotation = NumberRange.new(0, 360)
	fx.RotSpeed = NumberRange.new(-35, 35)
	fx:SetAttribute("Aura", true)
	fx.Parent = parent
	return fx
end

local function auraPart(m: Model, name: string, cf: CFrame, size: Vector3, color: Color3, alpha: number): BasePart
	local q = S.part(m, name, size, cf, color, true)
	q.Transparency = alpha
	q:SetAttribute("Aura", true)
	q:SetAttribute("RestTransparency", alpha)
	return q
end

function FX.Add(m: Model, e: Catalog.Pet, box: CFrame, size: Vector3)
	local root = m.PrimaryPart
	if not root then
		return
	end
	-- Aura signature (shared/PetSignatureAuras) : elle remplace les auras de rareté ci-dessous.
	if Signature.Add(m, e.BaseId or e.Id, box, size) then
		CollectionService:AddTag(m, "SculptedPetVisual")
		return
	end
	local rank = Config.RarityIndex[e.Rarity] or 1
	local color = e.Look.EffectColor or e.Look.Detail
	if e.Id == "BaleineGalaxie" then
		color = Color3.fromRGB(172, 112, 255)
	elseif e.Id == "CerbereChiot" then
		color = Color3.fromRGB(184, 65, 255)
	elseif e.Id == "PanthereNeon" then
		color = Color3.fromRGB(255, 44, 199)
	end
	local h = math.clamp(size.Y / 3, 0.75, 12) -- grows with the pet (shared/PetSizes)
	local radius = math.max(size.X, size.Z) * 0.42
	local bottom = box.Position.Y - size.Y / 2
	local top = box.Position.Y + size.Y / 2
	-- No atmospheric particles for common pets; emissive geometry still identifies fire spirits.
	if rank >= 2 and e.Look.Effect then
		local effect = e.Look.Effect
		local socket = Instance.new("Attachment")
		socket.Name = "ElementSocket"
		socket.Position = V(0, 0, size.Z * 0.23)
		socket:SetAttribute("Aura", true)
		socket.Parent = root
		local tex = if effect == "Fire"
			then FIRE
			elseif effect == "Smoke" or effect == "Steam" or effect == "Spores" then SMOKE
			else SPARK
		local fx = emitter(socket, "Element_" .. effect, color, tex, if rank < 4 then 3 else 6, h * 0.36, h * 1.2)
		if effect == "Snow" then
			fx.Acceleration = V(0, -1.8, 0)
			fx.Speed = NumberRange.new(0.5, 1.2)
		elseif effect == "Fire" then
			fx.Acceleration = V(0, 3, 0)
		elseif effect == "Smoke" then
			fx.Color = ColorSequence.new(Color3.fromRGB(77, 73, 90))
			fx.LightEmission = 0
		elseif effect == "Bubbles" then
			fx.Acceleration = V(0, 1.4, 0)
			fx.Size = NumberSequence.new(h * 0.12, h * 0.28)
		end
	end
	if rank >= 4 then
		-- Two flank emitters leave the face and chest legible, unlike a full opaque volume.
		for _, s in ipairs({ -1, 1 }) do
			local socket = Instance.new("Attachment")
			socket.Name = "AuraFlank"
			socket.Position = V(s * size.X * 0.4, bottom + size.Y * 0.26, size.Z * 0.12)
			socket:SetAttribute("Aura", true)
			socket.Parent = root
			local fx = emitter(
				socket,
				"AuraWisps",
				color,
				if rank == 4 then SMOKE else SPARK,
				math.min(3 + (rank - 4) * 1.3, 8),
				h * 0.48,
				h * 1.2
			)
			fx.Acceleration = V(s * 0.2, 1.3, 0)
		end
		-- Broken octagonal rune circle: no solid luminous slab under the pet.
		for i = 0, 7 do
			local a = i * math.pi / 4
			local q = auraPart(
				m,
				"RuneArc",
				CF(0, bottom + 0.06, 0) * A(0, a, 0) * CF(0, 0, -radius),
				V(radius * 0.48, 0.06, 0.09 * h),
				color,
				0.42
			)
			q:SetAttribute("PulsePhase", a)
		end
		if rank >= 5 then
			local lamp = Instance.new("PointLight")
			lamp.Name = "AuraLight"
			lamp.Color = color
			lamp.Brightness = 0.45
			lamp.Range = math.min(size.Y * 1.4, 40)
			lamp.Shadows = false
			lamp:SetAttribute("Aura", true)
			lamp.Parent = root
		end
		if rank >= 6 then
			for i = 0, 3 do
				local a = i * math.pi / 2
				local q = auraPart(
					m,
					"OrbitShard",
					CF(math.cos(a) * radius, 0, math.sin(a) * radius) * A(0, 0, math.pi / 4),
					V(0.17 * h, 0.4 * h, 0.17 * h),
					color,
					0.14
				)
				q:SetAttribute("Orbit", a)
				q:SetAttribute("OrbitRadius", radius / m:GetScale())
				q:SetAttribute("OrbitHeight", size.Y * 0.12 / m:GetScale())
			end
		end
		if rank >= 7 then
			for i = 0, 11 do
				local a = i * math.pi / 6
				auraPart(
					m,
					"CrownHalo",
					CF(0, top + 0.42 * h, 0) * A(0, a, 0) * CF(0, 0, -radius * 0.48),
					V(radius * 0.21, 0.08 * h, 0.08 * h),
					color:Lerp(Color3.new(1, 1, 1), 0.55),
					0.23
				)
			end
		end
		if rank >= 8 then
			for i = 0, 5 do
				local a = i * math.pi / 3
				local q = auraPart(
					m,
					"AscendantRune",
					CF(math.cos(a) * radius * 1.08, size.Y * 0.05, math.sin(a) * radius * 1.08) * A(0, a, math.pi / 4),
					V(0.24 * h, 0.7 * h, 0.14 * h),
					color,
					0.26
				)
				q:SetAttribute("PulsePhase", a)
			end
		end
	end
	-- Shared animation path also handles propellers without one connection per familiar.
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Spin") then
			d:SetAttribute("SpinOrigin", root.CFrame:ToObjectSpace(d.CFrame).Position / m:GetScale())
		end
	end
	CollectionService:AddTag(m, "SculptedPetVisual")
end

return FX
