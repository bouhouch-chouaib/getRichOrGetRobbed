-- SessionData : stockage en mémoire des données de session par joueur.
-- Contient la vitesse et l'inventaire de pets (rareté -> quantité).
-- Les données sont perdues au départ du joueur (pas de persistance DataStore).

local SessionData = {}

local Players = game:GetService("Players")

-- Stockage en mémoire : sessionStorage[playerName] = { speed, pets }
local sessionStorage = {}

-- Initialise les données de session d'un joueur.
function SessionData.InitializePlayer(playerName)
	sessionStorage[playerName] = {
		speed = 16,
		pets = {
			Commun = 0,
			Rare = 0,
			Epique = 0,
			Sigma = 0,
		},
	}
end

-- Supprime les données d'un joueur (évite les fuites de mémoire).
function SessionData.RemovePlayer(playerName)
	sessionStorage[playerName] = nil
end

-- Ajoute des pets à l'inventaire d'un joueur.
-- newPets : dictionnaire rareté -> quantité à ajouter.
function SessionData.AddPets(playerName, newPets)
	local playerData = sessionStorage[playerName]
	if not playerData then
		return
	end

	for rarity, count in pairs(newPets) do
		playerData.pets[rarity] = (playerData.pets[rarity] or 0) + count
	end
end

-- Retourne les données de session d'un joueur (ou nil).
function SessionData.GetPlayerData(playerName)
	return sessionStorage[playerName]
end

-- Initialise le système : joueurs déjà présents + connexions PlayerAdded/PlayerRemoving.
function SessionData.Init()
	-- Joueurs déjà connectés au démarrage du serveur.
	for _, player in ipairs(Players:GetPlayers()) do
		SessionData.InitializePlayer(player.Name)
	end

	-- Nouveaux joueurs.
	Players.PlayerAdded:Connect(function(player)
		SessionData.InitializePlayer(player.Name)
	end)

	-- Départs : nettoyage de la mémoire.
	Players.PlayerRemoving:Connect(function(player)
		SessionData.RemovePlayer(player.Name)
	end)
end

return SessionData
