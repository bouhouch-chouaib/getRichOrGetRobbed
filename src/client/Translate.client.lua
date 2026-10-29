--!strict
-- Translate : pour un joueur dont Roblox n'est pas réglé en français, chaque texte affiché (fenêtres, HUD, panneaux et
-- étiquettes dans la carte, bulles [E]) est remplacé par sa traduction anglaise (shared/Lang) dès qu'il change.
-- Le reste du code continue d'écrire en français : rien d'autre à faire quand on ajoute un texte, sauf l'ajouter à
-- shared/LangEn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Lang = require(ReplicatedStorage.Shared.Lang)

if Lang.isFrench() then
	return
end

-- Dernière valeur écrite par ce script, par objet et par propriété : on ne retraduit pas sa propre écriture.
local written: { [string]: { [Instance]: string } } = {}

local function watch(object: Instance, property: string)
	local mine = written[property]
	if not mine then
		mine = setmetatable({}, { __mode = "k" }) :: any
		written[property] = mine
	end
	local function apply()
		local current = (object :: any)[property] :: string
		if mine[object] == current then
			return
		end
		local translated = Lang.translate(current)
		mine[object] = translated
		if translated ~= current then
			(object :: any)[property] = translated
		end
	end
	apply()
	object:GetPropertyChangedSignal(property):Connect(apply)
end

local function hook(object: Instance)
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		watch(object, "Text")
	elseif object:IsA("TextBox") then
		watch(object, "PlaceholderText")
	elseif object:IsA("ProximityPrompt") then
		watch(object, "ActionText")
		watch(object, "ObjectText")
	end
end

local function cover(root: Instance)
	for _, object in root:GetDescendants() do
		hook(object)
	end
	root.DescendantAdded:Connect(hook)
end

cover(Players.LocalPlayer:WaitForChild("PlayerGui"))
cover(Workspace)
