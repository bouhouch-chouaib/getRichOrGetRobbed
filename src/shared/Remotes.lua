--!strict
-- Remotes : accès typé aux RemoteEvents de ReplicatedStorage.Remotes. Fonctionne côté client et serveur.
-- Ils sont déclarés dans default.project.json, mais le serveur crée aussi ceux qui manqueraient
-- (ex : remote ajouté au projet pendant que "rojo serve" tournait déjà). Le client les attend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local function getFolder(): Instance
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder then
		return folder
	end
	if IS_SERVER then
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Remotes")
end

local folder = getFolder()

local function remote(name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if IS_SERVER then
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		return created
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	-- Serveur -> client : (item: BasePart) le serveur a validé le ramassage, le client peut souder l'item.
	ItemGrabbed = remote("ItemGrabbed"),
	-- Client -> serveur : (item: BasePart) le client vient de lancer l'item qu'il tenait.
	ThrowItem = remote("ThrowItem"),
	-- Serveur -> client : (velocity: Vector3, tumble: number?) éjection (dôme, arme), appliquée par le client propriétaire
	-- du personnage. tumble = durée du KO d'une arme : le personnage tourne dans les airs puis se relève.
	Knockback = remote("Knockback"),
	-- Serveur -> client : (score: number, pulls: number, results: { [string]: number }, money: number)
	RewardsGranted = remote("RewardsGranted"),
	-- Client -> serveur : (itemId: string) achat d'une amélioration de Config.Shop.
	BuyUpgrade = remote("BuyUpgrade"),
	-- Client -> serveur : (petId: string, equip: boolean) équiper / déséquiper un familier.
	EquipPet = remote("EquipPet"),
	-- Serveur -> tous les clients : (playerName: string, petId: string) gros drop annoncé à tout le serveur.
	Announcement = remote("Announcement"),
	-- Client -> serveur : (rarityIndex: number, chosen: { [petId]: count }?) fusionner Config.Fusion.Count familiers de cette
	-- rareté ; chosen = les familiers choisis dans les cases de la machine (sinon le serveur choisit, doublons d'abord).
	Fuse = remote("Fuse"),
	-- Serveur -> client : (petId: string) résultat de la fusion.
	FusionResult = remote("FusionResult"),
	-- Client -> serveur : (petId: string?) réclamer la récompense d'Index d'un familier découvert (nil = toutes).
	ClaimIndex = remote("ClaimIndex"),
	-- Serveur -> client : (money: number, count: number) récompenses d'Index accordées.
	IndexClaimed = remote("IndexClaimed"),
	-- Serveur -> porteur : (outcome: string, petId: string, argent: number, points: number) fin du transport d'un familier
	-- ("Success", "Home", "Sacrificed", "Dropped", "Timeout", "VictimLeft", "Gone", "Recovered" : voir server/StealController).
	StealResult = remote("StealResult"),
	-- Client -> serveur : (anchor: BasePart) le joueur a validé la bulle [E] "Voler" d'un familier de base.
	-- La bulle est créée par le client (client/BasePets) car elle suit le familier chez lui seulement :
	-- une bulle du serveur serait refusée par Roblox dès que le familier s'éloigne de son repère.
	StealPet = remote("StealPet"),
	-- Client -> serveur : () le joueur saute ou touche ARRÊTER pour descendre du tapis / du banc.
	StopTraining = remote("StopTraining"),
	-- Serveur -> tous : effets des armes (client/WeaponFx) :
	--   ("Swing", attaquant, "WeaponBat")                    coup de batte
	--   ("Hit", victime, "WeaponBat", attaquant)             impact
	--   ("Grapple", tireur, "WeaponGrapple", point, victime?) crochet tiré (victime = nil : raté)
	WeaponFx = remote("WeaponFx"),
	-- Client -> serveur : (base: Model) utiliser une clé sur le portail de cette base fermée (server/LockController).
	UseKey = remote("UseKey"),
	-- Client -> serveur : () voyager au monde suivant (server/TierController paie Config.Worlds[palier + 1].Price).
	BuyTier = remote("BuyTier"),
	-- Serveur -> tous : (joueur: Player, palier: number) un joueur vient d'arriver dans un nouveau monde.
	TierReached = remote("TierReached"),
	-- Client -> serveur : (direction: Vector3) tir du grappin dans cette direction (le serveur choisit la cible).
	UseGrapple = remote("UseGrapple"),
	-- Serveur -> victime : (tireur: Player, durée: number) tu es ramené(e) devant le tireur.
	Grappled = remote("Grappled"),
	-- Serveur -> victime ou tous : (kind: string, thiefName: string, victimName: string, petId: string)
	-- kind : "Started", "Stolen", "Recovered", "Dropped" (lâché, il rentre à pied), "Returned" (rentré à la base),
	-- "Sacrificed" (jeté au trou) : au propriétaire ; "Announce" / "AnnounceSacrifice" : à tous, familier rare.
	StealNotice = remote("StealNotice"),
	-- Client -> serveur : () tutoriel terminé ou passé (enregistré dans la sauvegarde).
	TutorialDone = remote("TutorialDone"),
	-- Serveur -> tous : événements des paliers du trou noir (server/BlackholeTiers -> client/BlackholeFx) :
	--   ("TierUp", palier)              le trou noir monte d'un palier
	--   ("Spit")                        il recrache des roches de lave (palier 2)
	--   ("Bullseye", point, joueur)     lancer au centre, x2 (palier 3)
	--   ("Catch", point)                un tentacule rattrape un objet (palier 4)
	--   ("Meteors")                     pluie de météorites (palier 5)
	--   ("Combo", point, joueur, mult)  combo de lancers (palier 6)
	--   ("Jackpot", finServeur)         jackpot x5 (palier 7)
	--   ("CollapseSoon")                jauge du palier 7 pleine
	--   ("Collapse", { noms })          effondrement : retour au palier 1, noms des joueurs récompensés
	--   ("Sacrifice", point, petId, porteur, argent)  un familier est jeté dans le trou (server/StealController)
	HoleEvent = remote("HoleEvent"),
	-- Client -> serveur : (repère: Part) ramasser un familier lâché qui rentre à pied (Workspace.Map.LoosePets).
	PickLoosePet = remote("PickLoosePet"),
	-- Client -> serveur : () jeter dans le trou noir le familier porté (Feeding, près du bord : server/StealController).
	ThrowPet = remote("ThrowPet"),
}
