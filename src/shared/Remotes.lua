--!strict
-- Remotes : accès typé aux RemoteEvents déclarés dans default.project.json
-- (ReplicatedStorage.Remotes). Fonctionne côté client et serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Remotes")

return {
	-- Serveur -> client : (item: BasePart) le serveur a validé le ramassage, le client peut souder l'item.
	ItemGrabbed = folder:WaitForChild("ItemGrabbed") :: RemoteEvent,
	-- Client -> serveur : (item: BasePart) le client vient de lancer l'item qu'il tenait.
	ThrowItem = folder:WaitForChild("ThrowItem") :: RemoteEvent,
	-- Serveur -> client : (velocity: Vector3) éjection par le dôme, appliquée par le client propriétaire du personnage.
	Knockback = folder:WaitForChild("Knockback") :: RemoteEvent,
	-- Serveur -> client : (score: number, pulls: number, results: { [string]: number }, money: number)
	RewardsGranted = folder:WaitForChild("RewardsGranted") :: RemoteEvent,
	-- Client -> serveur : (itemId: string) achat d'une amélioration de Config.Shop.
	BuyUpgrade = folder:WaitForChild("BuyUpgrade") :: RemoteEvent,
}
