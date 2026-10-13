--!strict
-- Small, deterministic modelling vocabulary: bevels are stepped blocks, tips are wedges.
-- No uploaded meshes, scripts in assets, or per-stud geometry.
local Sculpt = {}
export type Palette = { body: Color3, detail: Color3, dark: Color3, light: Color3 }
local V, CF = Vector3.new, CFrame.new

-- Author joints while their exact construction pivot is known. Attributes survive cloning/scaling.
function Sculpt.motionSince(m: Model, first: number, group: string, pivot: CFrame, kind: string, phase: number?)
	local children = m:GetChildren()
	for i = first + 1, #children do
		local q = children[i]
		if q:IsA("BasePart") then
			q:SetAttribute("MotionGroup", group)
			q:SetAttribute("MotionPivotRaw", pivot)
			q:SetAttribute("MotionKind", kind)
			q:SetAttribute("MotionPhase", phase or 0)
		end
	end
end

function Sculpt.part(
	m: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	glow: boolean?,
	wedge: boolean?
): BasePart
	local p: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material = if glow then Enum.Material.Neon else Enum.Material.Plastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = true, false, false, false, true
	p.CastShadow = not glow
	p.TopSurface = if not glow
			and size.X > 0.45
			and size.Z > 0.45
		then Enum.SurfaceType.Studs
		else Enum.SurfaceType.Smooth
	p.FrontSurface = if not glow
			and size.X > 0.45
			and size.Y > 0.45
		then Enum.SurfaceType.Studs
		else Enum.SurfaceType.Smooth
	p.BackSurface = p.FrontSurface
	p.LeftSurface = if not glow
			and size.Z > 0.45
			and size.Y > 0.45
		then Enum.SurfaceType.Studs
		else Enum.SurfaceType.Smooth
	p.RightSurface = p.LeftSurface
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

function Sculpt.palette(body: Color3, detail: Color3): Palette
	return {
		body = body,
		detail = detail,
		dark = body:Lerp(Color3.new(0.025, 0.025, 0.055), 0.3),
		light = body:Lerp(Color3.new(1, 0.96, 0.86), 0.22),
	}
end

function Sculpt.mass(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3)
	Sculpt.part(m, name, size * V(1, 0.7, 0.84), cf, color)
	Sculpt.part(
		m,
		name .. "Crown",
		size * V(0.82, 0.24, 0.72),
		cf * CF(0, size.Y * 0.43, 0),
		color:Lerp(Color3.new(1, 1, 1), 0.06)
	)
	Sculpt.part(m, name .. "Keel", size * V(0.8, 0.22, 0.72), cf * CF(0, -size.Y * 0.42, 0), color)
	Sculpt.part(m, name .. "Front", size * V(0.82, 0.6, 0.14), cf * CF(0, -size.Y * 0.025, -size.Z * 0.48), color)
	Sculpt.part(m, name .. "Rear", size * V(0.82, 0.6, 0.14), cf * CF(0, -size.Y * 0.025, size.Z * 0.48), color)
end

function Sculpt.link(
	m: Model,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	depth: number,
	color: Color3,
	glow: boolean?
)
	return Sculpt.part(m, name, V(width, depth, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, glow)
end

function Sculpt.eyes(m: Model, cf: CFrame, width: number, depth: number, fierce: boolean?, iris: Color3?)
	for _, s in ipairs({ -1, 1 }) do
		local e = cf * CF(s * width * 0.27, 0.1, -depth / 2 - 0.035)
		Sculpt.part(m, "EyeSocket", V(width * 0.28, width * 0.3, 0.09), e, Color3.fromRGB(20, 18, 32))
		Sculpt.part(
			m,
			"Iris",
			V(width * 0.19, width * 0.22, 0.055),
			e * CF(0, 0.015, -0.065),
			iris or Color3.fromRGB(250, 248, 229),
			iris ~= nil
		)
		Sculpt.part(
			m,
			"Pupil",
			V(width * 0.075, width * 0.16, 0.035),
			e * CF(-s * width * 0.017, -0.01, -0.105),
			Color3.fromRGB(12, 16, 25)
		)
		Sculpt.part(
			m,
			"Catchlight",
			V(width * 0.06, width * 0.065, 0.025),
			e * CF(-width * 0.035, width * 0.055, -0.13),
			Color3.new(1, 1, 1)
		)
		if fierce then
			Sculpt.part(
				m,
				"Brow",
				V(width * 0.36, width * 0.09, 0.14),
				e * CF(0, width * 0.15, -0.02) * CFrame.Angles(0, 0, s * 0.23),
				Color3.fromRGB(28, 24, 38)
			)
		end
	end
end

function Sculpt.ear(m: Model, cf: CFrame, color: Color3, inside: Color3, floppy: boolean?)
	Sculpt.part(m, "Ear", V(0.46, if floppy then 0.95 else 0.65, 0.36), cf, color, false, not floppy)
	Sculpt.part(m, "InnerEar", V(0.23, if floppy then 0.48 else 0.34, 0.06), cf * CF(0, -0.04, -0.2), inside)
end

function Sculpt.horn(m: Model, cf: CFrame, length: number, color: Color3, glow: boolean?)
	for i = 0, 2 do
		local w = 0.3 * (1 - i * 0.28)
		Sculpt.part(
			m,
			"Horn",
			V(w, length * 0.42, w),
			cf * CF(0, i * length * 0.29, i * i * length * 0.04) * CFrame.Angles(i * 0.18, 0, 0),
			color,
			glow,
			i == 2
		)
	end
end

function Sculpt.wings(m: Model, cf: CFrame, span: number, color: Color3, edge: Color3, glow: boolean?, bat: boolean?)
	for _, s in ipairs({ -1, 1 }) do
		local first = #m:GetChildren()
		local hub = cf * CFrame.Angles(0, -s * 0.18, -s * 0.18)
		Sculpt.part(m, "WingShoulder", V(span * 0.65, 0.35, 0.95), hub * CF(s * span * 0.36, 0, 0), color)
		for i = 0, 4 do
			local x = s * (0.35 + span * (i + 0.6) / 6)
			local z = 0.28 + i * 0.17
			local len = (1.65 - i * 0.19) * (if bat then 0.85 else 1)
			local f = hub * CF(x, -i * 0.065, z) * CFrame.Angles(-0.12, s * (-0.12 + i * 0.1), 0)
			Sculpt.part(
				m,
				if bat then "WingMembrane" else "FlightFeather",
				V(span / 5 + 0.07, 0.16, len),
				f,
				color,
				false,
				bat
			)
			Sculpt.part(m, "WingTip", V(span / 5 * 0.7, 0.12, 0.48), f * CF(0, 0.02, len / 2 - 0.03), edge, glow, true)
		end
		Sculpt.motionSince(m, first, "Wing" .. first, cf * CF(s * 0.25, 0, 0), "Wing", s)
	end
end

function Sculpt.ring(
	m: Model,
	name: string,
	cf: CFrame,
	radius: number,
	thickness: number,
	color: Color3,
	glow: boolean?,
	count: number?
)
	local n = count or 12
	for i = 0, n - 1 do
		local a = i * math.pi * 2 / n
		Sculpt.part(
			m,
			name,
			V(2 * radius * math.tan(math.pi / n) + 0.025, thickness, thickness),
			cf * CFrame.Angles(0, a, 0) * CF(0, 0, -radius),
			color,
			glow
		)
	end
end

function Sculpt.crown(m: Model, cf: CFrame, width: number)
	local gold = Color3.fromRGB(255, 194, 35)
	Sculpt.ring(m, "CrownBand", cf, width * 0.48, 0.18, gold, false, 8)
	for i = 0, 4 do
		local x = (i - 2) * width / 5
		Sculpt.part(
			m,
			"CrownPoint",
			V(width / 6, 0.42 + (if i == 2 then 0.17 else 0), 0.16),
			cf * CF(x, 0.25, -width * 0.43),
			gold,
			false,
			true
		)
	end
	Sculpt.part(
		m,
		"CrownGem",
		V(0.22, 0.26, 0.08),
		cf * CF(0, 0.14, -width * 0.54) * CFrame.Angles(0, 0, math.pi / 4),
		Color3.fromRGB(65, 245, 220),
		true
	)
end

return Sculpt
