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
	-- Serveur -> client : (velocity: Vector3) éjection par le dôme, appliquée par le client propriétaire du personnage.
	Knockback = remote("Knockback"),
	-- Serveur -> client : (score: number, pulls: number, results: { [string]: number }, money: number)
	RewardsGranted = remote("RewardsGranted"),
	-- Client -> serveur : (itemId: string) achat d'une amélioration de Config.Shop.
	BuyUpgrade = remote("BuyUpgrade"),
	-- Client -> serveur : (petId: string, equip: boolean) équiper / déséquiper un familier.
	EquipPet = remote("EquipPet"),
	-- Serveur -> tous les clients : (playerName: string, petId: string) gros drop annoncé à tout le serveur.
	Announcement = remote("Announcement"),
	-- Client -> serveur : (rarityIndex: number) fusionner Config.Fusion.Count familiers de cette rareté.
	Fuse = remote("Fuse"),
	-- Serveur -> client : (petId: string) résultat de la fusion.
	FusionResult = remote("FusionResult"),
	-- Serveur -> voleur : (outcome: string, petId: string) fin d'un vol de familier
	-- ("Success", "KO", "Timeout", "VictimLeft", "Gone", "Recovered" : voir server/StealController).
	StealResult = remote("StealResult"),
	-- Serveur -> victime ou tous : (kind: string, thiefName: string, victimName: string, petId: string)
	-- kind : "Started", "Stolen", "Recovered", "Returned" (à la victime), "Announce" (à tous, vol rare réussi).
	StealNotice = remote("StealNotice"),
}
