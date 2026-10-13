--!strict
-- Icons : icônes 2D du jeu (style cartoon, gros contour noir), à la place des émojis.
-- Dessinées par tools/icons/make_icons.py (fichiers dans assets/icons), envoyées sur Roblox le 13 oct. 2026 (Bat, Grapple : 14 oct.).
-- Pour en changer une : modifier le script, le relancer, renvoyer l'image (Studio > Asset Manager, ou l'outil MCP
-- upload_image) et remplacer son Id ci-dessous.
--
--   Icons.image(parent, "Money", size?, position?) -> ImageLabel
--   Icons.id("Money")                               -> "rbxassetid://..." (ou nil)

local Icons = {}

local IDS: { [string]: string } = {
	Money = "rbxassetid://91110366747369",
	Speed = "rbxassetid://132477081520067",
	Strength = "rbxassetid://121158244909319",
	Shop = "rbxassetid://101581761518184",
	Index = "rbxassetid://120484593986364",
	Gem = "rbxassetid://84139374110884",
	Moon = "rbxassetid://121659576635942",
	Sun = "rbxassetid://72023085029713",
	Lock = "rbxassetid://115612879795139",
	Clover = "rbxassetid://84937227204758",
	Backpack = "rbxassetid://135010403309652",
	Glove = "rbxassetid://95466240074631",
	Pan = "rbxassetid://131364115437055",
	Staff = "rbxassetid://133667236186744",
	Treadmill = "rbxassetid://76463554286414",
	Bench = "rbxassetid://133620722794765",
	Paw = "rbxassetid://101519963001658",
	Crown = "rbxassetid://102859175789901",
	Sparkle = "rbxassetid://138689117361812",
	Dice = "rbxassetid://140671322908945",
	Gift = "rbxassetid://78096265944480",
	Sprout = "rbxassetid://116798474026167",
	Drop = "rbxassetid://107647214324977",
	Orb = "rbxassetid://106598175990265",
	Flame = "rbxassetid://128273954517653",
	Flower = "rbxassetid://139511093415127",
	Trophy = "rbxassetid://107983506276240",
	Bat = "rbxassetid://92089666736729",
	Grapple = "rbxassetid://122249795654523",
	Ghost = "rbxassetid://105946207492948",
	Key = "rbxassetid://82597263772074",
}

-- Autres noms utiles : raretés (Id de Config.Rarities), améliorations (Config.Shop), produits Robux (Key).
local ALIASES: { [string]: string } = {
	Commun = "Sprout",
	Inhabituel = "Clover",
	Rare = "Drop",
	Epique = "Orb",
	Legendaire = "Flame",
	Mythique = "Flower",
	Divin = "Sparkle",
	Sigma = "Crown",
	ItemQuality = "Clover",
	LongLock = "Lock",
	WeaponBat = "Bat",
	WeaponGrapple = "Grapple",
	PowerInvisible = "Ghost",
	DoubleMoney = "Money",
	VIP = "Crown",
	ExtraBackpack = "Backpack",
	EquipPlus2 = "Paw",
	LuckyLuck = "Clover",
	ServerLuck = "Sparkle",
	Pull1 = "Dice",
	Pull10 = "Gift",
	Key1 = "Key",
	Fusion = "Orb",
	Robux = "Gem",
	Leaderboard = "Trophy",
}

function Icons.id(name: string): string?
	return IDS[name] or IDS[ALIASES[name] or ""]
end

-- Icône carrée dans `parent` (par défaut : tout le parent).
function Icons.image(parent: Instance, name: string, size: UDim2?, position: UDim2?): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.Image = Icons.id(name) or ""
	image.ScaleType = Enum.ScaleType.Fit
	image.Size = size or UDim2.fromScale(1, 1)
	image.Position = position or UDim2.new()
	if parent:IsA("GuiObject") then
		image.ZIndex = parent.ZIndex + 1
	end
	image.Parent = parent
	return image
end

-- Toutes les images (à précharger au démarrage du client : ContentProvider:PreloadAsync).
function Icons.all(): { string }
	local list = {}
	for _, id in pairs(IDS) do
		table.insert(list, id)
	end
	return list
end

return Icons
