-- Généré par dataset_and_pipeline/tools/make_items_wire.py : range les objets à jeter importés dans ArtModels.Items.
local SETS = {
	["Objets_Halloween"] = { ["world"] = "Halloween", ["parts"] = { ["Citrouille"] = { 1.8808, 1.8808, 1.59159 }, ["Lanterne"] = { 3.39345, 3.47645, 2.73541 }, ["Tombe"] = { 1.5, 0.9, 2.09 } } },
}
local art = game.ReplicatedStorage:FindFirstChild("ArtModels") or Instance.new("Folder")
art.Name = "ArtModels"
art.Parent = game.ReplicatedStorage
local items = art:FindFirstChild("Items") or Instance.new("Folder")
items.Name = "Items"
items.Parent = art
local report = {}
local imports = {}
for asset, info in SETS do
	local folder = items:FindFirstChild(info.world) or Instance.new("Folder")
	folder.Name = info.world
	folder.Parent = items
	local count = 0
	for _, d in workspace:GetDescendants() do
		if not d:IsA("MeshPart") then
			continue
		end
		local owner, piece = string.match(d.Name, "^(.-)__(.+)$")
		local size = owner == asset and piece and info.parts[piece]
		if not size then
			continue
		end
		local q = d:Clone()
		q.Name = piece
		for _, c in q:GetChildren() do
			if not c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		q.Size = Vector3.new(size[1], size[3], size[2])
		q.CFrame = CFrame.new() * d.CFrame.Rotation
		q.Anchored = false
		q.CanCollide, q.CanQuery, q.CanTouch, q.Massless = true, true, true, false
		local old = folder:FindFirstChild(piece)
		if old then
			old:Destroy()
		end
		q.Parent = folder
		q.CollisionFidelity = Enum.CollisionFidelity.Box
		count += 1
		local rx, ry, rz = d.CFrame:ToEulerAnglesXYZ()
		table.insert(report, string.format("%s.%s : %.2f x %.2f x %.2f studs, rotation import (%.0f, %.0f, %.0f)", info.world, piece,
			q.Size.X, q.Size.Y, q.Size.Z, math.deg(rx), math.deg(ry), math.deg(rz)))
		local lot = d:FindFirstAncestorWhichIsA("Model")
		imports[if lot and lot ~= workspace then lot else d] = true
	end
	if count == 0 then
		table.insert(report, asset .. " : import introuvable (" .. asset .. "__...)")
	end
end
-- La collision en boîte se règle en différé : on attend, puis on vérifie (sinon elle reste en Default).
task.wait(4)
for _, folder in items:GetChildren() do
	for _, q in folder:GetChildren() do
		if q:IsA("MeshPart") and q.CollisionFidelity ~= Enum.CollisionFidelity.Box then
			table.insert(report, "  ! " .. folder.Name .. "." .. q.Name .. " pas en boîte : relancer le script")
		end
	end
end
-- Supprime l'import entier (le lot et ses sous-modèles), y compris s'il a été importé deux fois.
for item in imports do
	local top = item
	while top.Parent and top.Parent ~= workspace do
		top = top.Parent
	end
	if top.Parent then
		top:Destroy()
	end
end
table.sort(report)
return table.concat(report, "\n")
