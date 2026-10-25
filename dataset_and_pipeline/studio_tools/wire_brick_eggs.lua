-- Branche les œufs en briques importés (baked_assets/lots/Lot08_Oeufs.fbx, 25 oct.) : barre MCP execute_luau, mode Édition.
-- Pour chaque rareté : les pièces « Oeuf<Rareté>__<Morceau> » du Workspace deviennent ReplicatedStorage.ArtModels.Eggs.<Rareté>
-- (posé au sol sur un Root invisible à l'origine, 3,6 studs de haut comme l'ancien œuf, morceaux Bottom / Lower marqués
-- ShellHalf = -1 et les autres 1 pour l'éclosion). shared/EggModelBuilder le prend à la place de l'œuf généré.
-- Fichier du jeu : sauvegarder dans Studio (Ctrl+S) ensuite.
local EGGS = {
	Commun = "OeufCommun",
	Inhabituel = "OeufInhabituel",
	Rare = "OeufRare",
	Epique = "OeufEpique",
	Legendaire = "OeufLegendaire",
	Mythique = "OeufMythique",
	Divin = "OeufDivin",
	Sigma = "OeufSigma",
}
local LOWER = { Bottom = true, Lower = true }
local HEIGHT = 3.6

local art = game.ReplicatedStorage:FindFirstChild("ArtModels") or Instance.new("Folder")
art.Name = "ArtModels"
art.Parent = game.ReplicatedStorage
local folder = art:FindFirstChild("Eggs") or Instance.new("Folder")
folder.Name = "Eggs"
folder.Parent = art

local report = {}
local imports: { [Instance]: boolean } = {}
for rarity, eggId in EGGS do
	local found: { [string]: MeshPart } = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") then
			local owner, piece = string.match(d.Name, "^(.-)__(.+)$")
			if owner == eggId and piece then
				found[piece] = d
			end
		end
	end
	if next(found) == nil then
		table.insert(report, rarity .. " : import introuvable (" .. eggId .. "__...)")
		continue
	end
	local probe = Instance.new("Model")
	for _, part in found do
		part:Clone().Parent = probe
	end
	local box, size = probe:GetBoundingBox()
	probe:Destroy()
	local shift = CFrame.new(-Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z))

	local model = Instance.new("Model")
	model.Name = rarity
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.1
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
	root:SetAttribute("ShellHalf", 0)
	root.Parent = model
	model.PrimaryPart = root
	local pieces = 0
	for piece, part in found do
		local q = part:Clone()
		q.Name = piece
		for _, c in q:GetChildren() do
			if not c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		q.CFrame = shift * part.CFrame
		q.Anchored, q.CanCollide, q.CanTouch, q.CanQuery = true, false, false, false
		q:SetAttribute("ShellHalf", if LOWER[piece] then -1 else 1)
		q.Parent = model
		pieces += 1
		local lot = part:FindFirstAncestorWhichIsA("Model")
		imports[if lot and lot ~= workspace then lot else part] = true
	end
	model:ScaleTo(HEIGHT / size.Y)
	local old = folder:FindFirstChild(rarity)
	if old then
		old:Destroy()
	end
	model.Parent = folder
	table.insert(report, string.format("%s : %d morceaux, hauteur %.2f", rarity, pieces, select(2, model:GetBoundingBox()).Y))
end
-- les imports bruts ne servent plus
for item in imports do
	if item.Parent then
		item:Destroy()
	end
end
local lot = workspace:FindFirstChild("Lot08_Oeufs")
if lot then
	lot:Destroy()
end
table.sort(report)
return table.concat(report, "\n")
