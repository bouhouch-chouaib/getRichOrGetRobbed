--!strict
-- Icons : icônes 2D du jeu (style cartoon, gros contour noir), à la place des émojis.
-- 16 oct. 2026 : 25 icônes refaites avec ForgeGUI (style 3D brillant, contour bleu nuit), fichiers et planches dans
-- assets/icons/forgegui (découpées par tools/icons/split_sheet.py). Les autres (Moon, Sun, Gem, Orb...) restent celles
-- dessinées par tools/icons/make_icons.py (assets/icons), envoyées sur Roblox le 13 oct. 2026.
-- Pour en changer une : modifier le script, le relancer, renvoyer l'image (Studio > Asset Manager, ou l'outil MCP
-- upload_image) et remplacer son Id ci-dessous.
--
--   Icons.image(parent, "Money", size?, position?) -> ImageLabel
--   Icons.id("Money")                               -> "rbxassetid://..." (ou nil)

local Icons = {}

local IDS: { [string]: string } = {
	Money = "rbxassetid://120294685654176",
	Speed = "rbxassetid://100047468856973",
	Strength = "rbxassetid://124589074285402",
	Shop = "rbxassetid://113919414219031",
	Index = "rbxassetid://125686942568588",
	Gem = "rbxassetid://84139374110884",
	Moon = "rbxassetid://121659576635942",
	Sun = "rbxassetid://72023085029713",
	Lock = "rbxassetid://94480767029726",
	Clover = "rbxassetid://134744661584434",
	Backpack = "rbxassetid://77822544324446",
	Glove = "rbxassetid://95466240074631",
	Pan = "rbxassetid://131364115437055",
	Staff = "rbxassetid://133667236186744",
	Treadmill = "rbxassetid://97536347003616",
	Bench = "rbxassetid://101740565772948",
	Paw = "rbxassetid://123202543786812",
	Crown = "rbxassetid://105501070074353",
	Sparkle = "rbxassetid://83274576810315",
	Dice = "rbxassetid://125051226501039",
	Gift = "rbxassetid://99816460887795",
	Sprout = "rbxassetid://116798474026167",
	Drop = "rbxassetid://107647214324977",
	Orb = "rbxassetid://106598175990265",
	Flame = "rbxassetid://128273954517653",
	Flower = "rbxassetid://117275542680011",
	Trophy = "rbxassetid://77141479133178",
	Bat = "rbxassetid://79098626399920",
	Grapple = "rbxassetid://122509806695966",
	Ghost = "rbxassetid://137004430827671",
	Key = "rbxassetid://124911338485757",
	Planet = "rbxassetid://128878823846627",
	-- Nouvelles (16 oct., ForgeGUI)
	Egg = "rbxassetid://103958195138100",
	Magnet = "rbxassetid://119453006180668",
	Vortex = "rbxassetid://123384108390618",
	Rebirth = "rbxassetid://119573642945952", -- dessinée par tools/icons/make_rebirth_icon.py
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
	Bonus = "Gift",
	Daily = "Gift",
	Quests = "Trophy",
	Codes = "Key",
	Pulls = "Vortex",
	AutoMagnet = "Magnet",
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
