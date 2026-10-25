-- Branche le Cerbère importé sur l'animation du jeu (barre MCP execute_luau, mode Édition), 25 oct. 2026.
-- Avant : Chouaib importe dataset_and_pipeline/baked_assets/CerbereInfernal_Rig.fbx (Fichier > Importer 3D, réglages
-- par défaut) -> Workspace.CerbereInfernal_Rig, 12 MeshParts nommées comme dans block_creatures.CERBERUS_RIG, chacune
-- avec sa SurfaceAppearance (couleur, relief, rugosité, métal : envoyées par l'importateur).
-- Ce script : pose sur chaque pièce les attributs lus par shared/PetMotion (MotionGroup / MotionKind / MotionPhase /
-- MotionPivotRaw, + MotionHingeRaw pour les mâchoires), ajoute la lueur (EmissiveMaskContent, images envoyées avec
-- l'outil MCP upload_image), range le tout dans ReplicatedStorage.ArtModels.CerbereInfernal et supprime l'import.
-- Données : baked_assets/CerbereInfernal_rig.json (pivots dans le repère Blender). Correspondance mesurée sur
-- l'import : Blender (x, y, z) -> Studio (-x, z, y), échelle = taille Studio / taille Blender (3,2131 pour 13 studs).
-- Pour un autre familier animé : même recette, en changeant RIG, BODY_* et EMISSIVE.

local RIG = {
	Head0 = { kind = "Head", phase = 0.0, pivot = { { 1.0, 0.0, 0.0, 0.0 }, { 0.0, 0.997564, -0.069756, -1.0 }, { 0.0, 0.069756, 0.997564, 2.32 } } },
	Jaw0 = { kind = "Jaw", phase = 0.0, head = "Head0", pivot = { { 1.0, 0.0, 0.0, 0.0 }, { 0.0, 0.997564, -0.069756, -1.291037 }, { 0.0, 0.069756, 0.997564, 2.468059 } } },
	Head1 = { kind = "Head", phase = 2.1, pivot = { { 0.923656, 0.374607, 0.080809, -1.4 }, { -0.373181, 0.927184, -0.032649, -0.32 }, { -0.087156, 0.0, 0.996195, 1.98 } } },
	Jaw1 = { kind = "Jaw", phase = 2.1, head = "Head1", pivot = { { 0.923656, 0.374607, 0.080809, -1.478269 }, { -0.373181, 0.927184, -0.032649, -0.547226 }, { -0.087156, 0.0, 0.996195, 2.123452 } } },
	Head2 = { kind = "Head", phase = 4.2, pivot = { { 0.910069, -0.39825, -0.114767, 1.4 }, { 0.405189, 0.913159, 0.044306, -0.34 }, { 0.087156, -0.086824, 0.992404, 1.9 } } },
	Jaw2 = { kind = "Jaw", phase = 4.2, head = "Head2", pivot = { { 0.910069, -0.39825, -0.114767, 1.477736 }, { 0.405189, 0.913159, 0.044306, -0.549232 }, { 0.087156, -0.086824, 0.992404, 2.061015 } } },
	Tail = { kind = "Tail", phase = 0.0, pivot = { { 1, 0, 0, 0.0 }, { 0, 1, 0, 0.82 }, { 0, 0, 1, 1.32 } } },
	LegFL = { kind = "Leg", phase = 0.0, pivot = { { 1, 0, 0, 0.8 }, { 0, 1, 0, -0.5 }, { 0, 0, 1, 1.02 } } },
	LegFR = { kind = "Leg", phase = math.pi, pivot = { { 1, 0, 0, -0.8 }, { 0, 1, 0, -0.5 }, { 0, 0, 1, 1.02 } } },
	LegBL = { kind = "Leg", phase = math.pi, pivot = { { 1, 0, 0, 0.6 }, { 0, 1, 0, 0.48 }, { 0, 0, 1, 1.08 } } },
	LegBR = { kind = "Leg", phase = 0.0, pivot = { { 1, 0, 0, -0.6 }, { 0, 1, 0, 0.48 }, { 0, 0, 1, 1.08 } } },
}
local BODY_CENTER_B = Vector3.new(-0.00766, -0.20663, 1.78217) -- centre de la boîte de Body dans Blender
local BODY_SIZE_B = Vector3.new(3.31078, 2.28516, 1.89605)
local EMISSIVE = { -- masques de lueur envoyés sur le compte de Chouaib le 25 oct.
	Tetes = "rbxassetid://114868634006714",
	Corps = "rbxassetid://123067838738077",
	Pattes = "rbxassetid://103414224769726",
}
local EMISSIVE_STRENGTH = 3.47 -- baked_assets/CerbereInfernal_<Atlas>_manifest.json

local function atlasOf(name: string): string
	if name:sub(1, 4) == "Head" or name:sub(1, 3) == "Jaw" then
		return "Tetes"
	elseif name:sub(1, 3) == "Leg" then
		return "Pattes"
	end
	return "Corps"
end

local src = workspace:FindFirstChild("CerbereInfernal_Rig")
assert(src, "import introuvable : Workspace.CerbereInfernal_Rig")
local body = src:FindFirstChild("Body", true) :: MeshPart
local k = body.Size.Y / BODY_SIZE_B.Z
local function mapV(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Z, v.Y)
end
local function toCF(m): CFrame
	local p = body.Position + mapV(Vector3.new(m[1][4], m[2][4], m[3][4]) - BODY_CENTER_B) * k
	local function col(j)
		return Vector3.new(m[1][j], m[2][j], m[3][j])
	end
	-- rotation dans Studio = M R M^T : colonnes X, Y, Z = M(-col1), M(col3), M(col2) de Blender
	return CFrame.fromMatrix(p, mapV(-col(1)), mapV(col(3)), mapV(col(2)))
end

-- posé au sol, centré sur l'origine (le pivot du modèle reste l'identité : c'est le repère de MotionPivotRaw)
local cf, size = src:GetBoundingBox()
local shift = CFrame.new(-Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z))

local model = Instance.new("Model")
model.Name = "CerbereInfernal"
for _, part in src:GetDescendants() do
	if part:IsA("MeshPart") then
		local q = part:Clone()
		for _, c in q:GetChildren() do
			if not c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		q.CFrame = shift * part.CFrame
		q.Anchored, q.CanCollide, q.CanTouch, q.CanQuery = true, false, false, false
		local sa = q:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			sa.EmissiveMaskContent = Content.fromUri(EMISSIVE[atlasOf(q.Name)])
			sa.EmissiveStrength = EMISSIVE_STRENGTH
			sa.EmissiveTint = Color3.new(1, 1, 1)
		end
		local rig = RIG[q.Name]
		if rig then
			q:SetAttribute("MotionGroup", q.Name)
			q:SetAttribute("MotionKind", rig.kind)
			q:SetAttribute("MotionPhase", rig.phase)
			if rig.kind == "Jaw" then
				-- même pivot que sa tête (elle la suit), charnière à part
				q:SetAttribute("MotionPivotRaw", shift * toCF(RIG[rig.head].pivot))
				q:SetAttribute("MotionHingeRaw", shift * toCF(rig.pivot))
			else
				q:SetAttribute("MotionPivotRaw", shift * toCF(rig.pivot))
			end
		end
		q.Parent = model
	end
end
model.WorldPivot = CFrame.identity
model:SetAttribute("FacingYaw", 0) -- l'import regarde déjà vers -Z

local art = game.ReplicatedStorage.ArtModels
local old = art:FindFirstChild("CerbereInfernal")
if old then
	old:Destroy()
end
model.Parent = art
src:Destroy()
return "ArtModels.CerbereInfernal : " .. #model:GetChildren() .. " pièces"
