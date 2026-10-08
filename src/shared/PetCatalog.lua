--!strict
-- PetCatalog : les 75 familiers du jeu (5 catégories x 15).
-- Id      : clé unique sans espace ni accent (utilisée dans les attributs et pour le modèle 3D).
-- Rarity  : Id d'une rareté de Config.Rarities.
-- Look    : description simplifiée pour le modèle de remplacement (PetModelBuilder).
--           Si ReplicatedStorage.PetModels contient un Model nommé comme l'Id, il est utilisé à la place.
--
-- Shape : "Quadruped" | "Bird" | "Blob" | "Serpent" | "Fish" | "Plant" | "Humanoid" | "Object" | "Dragon"
-- Extra : accessoire ("Wings", "Crown", "Horn", "Propeller", "Hat", "Rings", "ThreeHeads", "Bandana",
--         "Coin", "Pot", "Leaf", "Twin", "Trio", "Tracks", "Cannon", "Exhaust")
-- Effect: particules ("Aura", "Fire", "Sparkles", "Smoke", "Snow", "Bubbles", "Coins", "Spores", "Music", "Steam", "Pulse")

export type Look = {
	Shape: string,
	Body: Color3,
	Detail: Color3,
	Long: boolean?,
	Float: boolean?,
	Neon: boolean?,
	Extra: string?,
	Effect: string?,
	EffectColor: Color3?,
}

export type Pet = {
	Id: string,
	Name: string,
	Rarity: string,
	Category: string,
	Description: string,
	Look: Look,
}

local rgb = Color3.fromRGB

local GOLD = rgb(255, 205, 50)
local WHITE = rgb(245, 245, 245)
local BLACK = rgb(25, 25, 30)

local function pet(id: string, name: string, rarity: string, category: string, description: string, look: Look): Pet
	return { Id = id, Name = name, Rarity = rarity, Category = category, Description = description, Look = look }
end

local A, M, P, H, B = "Animaux", "Fantastiques", "Plantes", "Hybrides", "Absurdes"

local list: { Pet } = {
	-- 🐾 Animaux
	pet("ChienSaucisse", "Chien-Saucisse", "Commun", A, "Teckel brun excessivement long.", { Shape = "Quadruped", Body = rgb(140, 85, 45), Detail = rgb(90, 55, 30), Long = true }),
	pet("ChatRuelle", "Chat de ruelle", "Commun", A, "Chat tigré gris ébouriffé, pansement sur la joue.", { Shape = "Quadruped", Body = rgb(130, 130, 135), Detail = rgb(235, 200, 160), Extra = "Ears" }),
	pet("PigeonVilles", "Pigeon des villes", "Commun", A, "Pigeon gris au regard vide.", { Shape = "Bird", Body = rgb(140, 145, 155), Detail = WHITE }),
	pet("GrenouilleGlobuleuse", "Grenouille Globuleuse", "Inhabituel", A, "Grenouille vert fluo aux yeux énormes.", { Shape = "Blob", Body = rgb(90, 255, 80), Detail = WHITE, Extra = "BigEyes" }),
	pet("HamsterJoufflu", "Hamster Joufflu", "Inhabituel", A, "Hamster roux en boule parfaite.", { Shape = "Blob", Body = rgb(230, 140, 70), Detail = rgb(255, 230, 200), Extra = "Ears" }),
	pet("RenardFurtif", "Renard Furtif", "Rare", A, "Renard orange au bandana rouge.", { Shape = "Quadruped", Body = rgb(240, 120, 40), Detail = WHITE, Extra = "Bandana" }),
	pet("CorbeauVoleur", "Corbeau Voleur", "Rare", A, "Corbeau noir avec une pièce d'or dans le bec.", { Shape = "Bird", Body = BLACK, Detail = GOLD, Extra = "Coin" }),
	pet("HibouGrincheux", "Hibou Grincheux", "Rare", A, "Hibou brun aux sourcils froncés.", { Shape = "Bird", Body = rgb(120, 85, 50), Detail = rgb(230, 200, 150), Extra = "Ears" }),
	pet("LoupPolaire", "Loup Polaire", "Epique", A, "Loup blanc entouré de flocons.", { Shape = "Quadruped", Body = WHITE, Detail = rgb(170, 210, 255), Extra = "Ears", Effect = "Snow" }),
	pet("PanthereNeon", "Panthère Néon", "Epique", A, "Panthère noire aux lignes magenta lumineuses.", { Shape = "Quadruped", Body = BLACK, Detail = rgb(255, 40, 200), Neon = true }),
	pet("TigreBengal", "Tigre du Bengal", "Legendaire", A, "Tigre massif aux rayures dorées.", { Shape = "Quadruped", Body = rgb(245, 140, 30), Detail = GOLD, Neon = true, Effect = "Sparkles", EffectColor = GOLD }),
	pet("AigleRoyal", "Aigle Royal", "Legendaire", A, "Aigle brun couronné de plumes dorées.", { Shape = "Bird", Body = rgb(110, 70, 35), Detail = WHITE, Extra = "Crown", Effect = "Sparkles", EffectColor = GOLD }),
	pet("RequinVolant", "Requin Volant", "Mythique", A, "Grand requin blanc qui lévite, entouré de bulles.", { Shape = "Fish", Body = rgb(150, 165, 180), Detail = WHITE, Float = true, Extra = "Fin", Effect = "Bubbles" }),
	pet("TRexPoche", "T-Rex de Poche", "Divin", A, "Petit tyrannosaure vert pomme aux écailles dorées.", { Shape = "Quadruped", Body = rgb(140, 230, 60), Detail = GOLD, Extra = "Dino", Effect = "Sparkles", EffectColor = GOLD }),
	pet("CapybaraZen", "Le Capybara Zen", "Sigma", A, "Capybara imperturbable, une orange sur la tête.", { Shape = "Quadruped", Body = rgb(160, 110, 70), Detail = rgb(255, 150, 30), Extra = "Hat", Effect = "Aura", EffectColor = GOLD }),

	-- 🐉 Fantastiques
	pet("FeuFollet", "Feu Follet", "Commun", M, "Petite boule de feu bleue flottante.", { Shape = "Blob", Body = rgb(60, 140, 255), Detail = WHITE, Float = true, Neon = true, Effect = "Fire", EffectColor = rgb(80, 160, 255) }),
	pet("SlimeGlgl", "Slime Gl gl", "Commun", M, "Cube de gelée verte transparente.", { Shape = "Blob", Body = rgb(110, 230, 90), Detail = WHITE, Extra = "Cube" }),
	pet("BebeGriffon", "Bébé Griffon", "Inhabituel", M, "Mi-aigle, mi-lionceau, tout duveteux.", { Shape = "Quadruped", Body = rgb(230, 190, 110), Detail = WHITE, Extra = "Wings" }),
	pet("GargouilleMignonne", "Gargouille Mignonne", "Inhabituel", M, "Petite statue de pierre aux ailes de chauve-souris.", { Shape = "Humanoid", Body = rgb(130, 130, 135), Detail = rgb(90, 90, 95), Extra = "Wings" }),
	pet("LicorneBois", "Licorne de Bois", "Rare", M, "Poney marron à la corne en branche torsadée.", { Shape = "Quadruped", Body = rgb(150, 100, 60), Detail = rgb(100, 70, 40), Extra = "Horn" }),
	pet("PhenixCendres", "Phénix de Cendres", "Rare", M, "Oiseau gris qui fume en permanence.", { Shape = "Bird", Body = rgb(110, 110, 115), Detail = rgb(60, 60, 60), Effect = "Smoke" }),
	pet("CerbereChiot", "Cerbère Chiot", "Epique", M, "Chiot noir à trois têtes, collier à clous rouges.", { Shape = "Quadruped", Body = BLACK, Detail = rgb(220, 30, 30), Extra = "ThreeHeads" }),
	pet("DragonnetObsidienne", "Dragonnet d'Obsidienne", "Epique", M, "Petit dragon noir anguleux, brillant comme du verre.", { Shape = "Dragon", Body = rgb(30, 25, 40), Detail = rgb(140, 90, 255) }),
	pet("PegaseNuageux", "Pégase Nuageux", "Legendaire", M, "Cheval blanc aux ailes de nuages.", { Shape = "Quadruped", Body = WHITE, Detail = rgb(210, 230, 255), Extra = "Wings", Float = true }),
	pet("Kitsune3Queues", "Kitsune à 3 Queues", "Legendaire", M, "Renard blanc aux marques rouges et trois queues.", { Shape = "Quadruped", Body = WHITE, Detail = rgb(220, 40, 50), Extra = "Ears", Effect = "Aura", EffectColor = rgb(255, 120, 120) }),
	pet("KrakenBaignoire", "Kraken de Baignoire", "Mythique", M, "Pieuvre violette couronnée, avec un canard en plastique.", { Shape = "Blob", Body = rgb(150, 70, 200), Detail = GOLD, Extra = "Crown", Effect = "Bubbles" }),
	pet("BasilicEmeraude", "Basilic d'Émeraude", "Mythique", M, "Serpent vert fluo aux yeux jaunes hypnotiques.", { Shape = "Serpent", Body = rgb(60, 255, 120), Detail = rgb(255, 230, 0), Neon = true }),
	pet("LeviathanAbyssal", "Léviathan Abyssal", "Divin", M, "Dragon des mers bleu marine, bioluminescence cyan.", { Shape = "Dragon", Body = rgb(20, 40, 110), Detail = rgb(0, 255, 255), Neon = true, Float = true, Effect = "Pulse", EffectColor = rgb(0, 255, 255) }),
	pet("PhenixSolaire", "Phénix Solaire", "Divin", M, "Oiseau majestueux fait de feu pur.", { Shape = "Bird", Body = rgb(255, 120, 20), Detail = rgb(255, 230, 60), Neon = true, Float = true, Effect = "Fire" }),
	pet("OuroborosInfini", "Ouroboros Infini", "Sigma", M, "Serpent d'or holographique qui se mord la queue.", { Shape = "Serpent", Body = GOLD, Detail = WHITE, Neon = true, Float = true, Extra = "Ring", Effect = "Aura", EffectColor = GOLD }),

	-- 🌿 Plantes
	pet("PousseHaricot", "Pousse de Haricot", "Commun", P, "Tige verte sortant d'un tas de terre, avec des yeux.", { Shape = "Plant", Body = rgb(90, 200, 70), Detail = rgb(110, 75, 45), Extra = "Leaf" }),
	pet("CactusRonchon", "Cactus Ronchon", "Commun", P, "Petit cactus grincheux dans un pot.", { Shape = "Plant", Body = rgb(60, 160, 80), Detail = rgb(200, 100, 60), Extra = "Pot" }),
	pet("NavetPeureux", "Navet Peureux", "Inhabituel", P, "Navet blanc qui grelotte.", { Shape = "Plant", Body = rgb(240, 235, 240), Detail = rgb(200, 120, 220), Extra = "Leaf" }),
	pet("TournesolJoyeux", "Tournesol Joyeux", "Inhabituel", P, "Tournesol jaune au grand sourire.", { Shape = "Plant", Body = rgb(255, 210, 30), Detail = rgb(110, 70, 30), Extra = "Flower" }),
	pet("ChampignonVeneneux", "Champignon Vénéneux", "Rare", P, "Amanite rouge à pois blancs.", { Shape = "Plant", Body = rgb(220, 30, 30), Detail = WHITE, Extra = "Mushroom", Effect = "Spores" }),
	pet("CitrouilleSculptee", "Citrouille Sculptée", "Rare", P, "Citrouille d'Halloween éclairée de l'intérieur.", { Shape = "Blob", Body = rgb(255, 130, 20), Detail = rgb(255, 230, 80), Neon = false, Effect = "Fire", EffectColor = rgb(255, 200, 60) }),
	pet("BonsaiMillenaire", "Bonsaï Millénaire", "Epique", P, "Arbre miniature torsadé habité par un esprit bleu.", { Shape = "Plant", Body = rgb(60, 140, 60), Detail = rgb(100, 70, 40), Extra = "Tree", Effect = "Aura", EffectColor = rgb(100, 180, 255) }),
	pet("RoseCristal", "Rose de Cristal", "Epique", P, "Rose taillée dans un diamant bleu azur.", { Shape = "Plant", Body = rgb(80, 170, 255), Detail = rgb(60, 140, 80), Neon = true, Extra = "Flower" }),
	pet("MandragoreHurlante", "Mandragore Hurlante", "Legendaire", P, "Racine humanoïde aux cache-oreilles rouges.", { Shape = "Humanoid", Body = rgb(190, 150, 100), Detail = rgb(220, 30, 30), Extra = "Leaf" }),
	pet("Treflant4Feuilles", "Tréflant à 4 Feuilles", "Legendaire", P, "Gros trèfle émeraude qui sème des pièces d'or.", { Shape = "Plant", Body = rgb(40, 200, 90), Detail = rgb(30, 120, 50), Extra = "Clover", Effect = "Coins" }),
	pet("LotusEspace", "Lotus de l'Espace", "Mythique", P, "Lotus rose flottant avec une mini-galaxie au centre.", { Shape = "Plant", Body = rgb(255, 90, 190), Detail = rgb(120, 80, 255), Float = true, Extra = "Flower", Effect = "Sparkles", EffectColor = rgb(180, 120, 255) }),
	pet("ArbreMondeMiniature", "Arbre-Monde Miniature", "Mythique", P, "Chêne colossal miniature aux racines cyan.", { Shape = "Plant", Body = rgb(70, 150, 60), Detail = rgb(0, 230, 255), Extra = "Tree", Neon = true }),
	pet("CarniflorToxique", "Carniflore Toxique", "Divin", P, "Plante carnivore néon violet et vert acide.", { Shape = "Plant", Body = rgb(170, 40, 255), Detail = rgb(150, 255, 40), Neon = true, Extra = "Jaws", Effect = "Spores", EffectColor = rgb(150, 255, 40) }),
	pet("GraineEtoile", "Graine d'Étoile", "Divin", P, "Pépite dorée lumineuse entourée d'anneaux.", { Shape = "Blob", Body = GOLD, Detail = rgb(255, 250, 200), Neon = true, Float = true, Extra = "Rings", Effect = "Sparkles", EffectColor = GOLD }),
	pet("FougereFibonacci", "La Fougère de Fibonacci", "Sigma", P, "Plante fractale parfaite, d'un blanc aveuglant.", { Shape = "Plant", Body = WHITE, Detail = WHITE, Neon = true, Float = true, Extra = "Fractal", Effect = "Aura", EffectColor = WHITE }),

	-- 🤖 Hybrides
	pet("ChatCoptere", "Chat-Coptère", "Commun", H, "Chat tigré avec une hélice sur la tête.", { Shape = "Quadruped", Body = rgb(230, 150, 60), Detail = rgb(160, 160, 170), Extra = "Propeller", Float = true }),
	pet("TortueBurger", "Tortue-Burger", "Commun", H, "Tortue à la carapace en hamburger.", { Shape = "Quadruped", Body = rgb(110, 180, 80), Detail = rgb(210, 150, 70), Extra = "Burger" }),
	pet("PoissonAmpoule", "Poisson-Ampoule", "Inhabituel", H, "Poisson jaune surmonté d'une ampoule allumée.", { Shape = "Fish", Body = rgb(255, 210, 40), Detail = rgb(255, 255, 200), Float = true, Extra = "Bulb" }),
	pet("CochonTirelire", "Cochon-Tirelire", "Inhabituel", H, "Cochon en céramique rose avec une pièce coincée.", { Shape = "Quadruped", Body = rgb(255, 160, 190), Detail = GOLD, Extra = "Coin" }),
	pet("TasseChien", "Tasse-Chien", "Rare", H, "Carlin beige coincé dans un gros mug.", { Shape = "Object", Body = WHITE, Detail = rgb(220, 190, 140), Extra = "Mug" }),
	pet("CorbeauHorloge", "Corbeau-Horloge", "Rare", H, "Oiseau mécanique noir aux engrenages cuivrés.", { Shape = "Bird", Body = BLACK, Detail = rgb(200, 120, 50), Extra = "Gear" }),
	pet("BananeChien", "Banane-Chien", "Epique", H, "Corps de banane, tête de Golden Retriever.", { Shape = "Quadruped", Body = rgb(255, 225, 60), Detail = rgb(220, 160, 70), Long = true }),
	pet("HibouCamera", "Hibou-Caméra", "Epique", H, "Hibou mécanique blanc aux yeux-objectifs.", { Shape = "Bird", Body = WHITE, Detail = BLACK, Extra = "BigEyes" }),
	pet("RequinTorpille", "Requin-Torpille", "Legendaire", H, "Requin métallique à réacteur enflammé.", { Shape = "Fish", Body = rgb(150, 155, 165), Detail = rgb(255, 120, 20), Float = true, Extra = "Fin", Effect = "Fire" }),
	pet("PegaseMoto", "Pégase-Moto", "Legendaire", H, "Cheval robot crachant de la fumée.", { Shape = "Quadruped", Body = rgb(90, 95, 105), Detail = rgb(255, 100, 20), Extra = "Exhaust", Effect = "Smoke" }),
	pet("DragonGrillePain", "Dragon-Grille-Pain", "Mythique", H, "Dragon cubique en métal brossé qui crache des tartines.", { Shape = "Object", Body = rgb(190, 195, 205), Detail = rgb(200, 140, 60), Extra = "Wings", Effect = "Smoke" }),
	pet("TRexTank", "T-Rex Tank", "Mythique", H, "Dino cyborg avec un canon de char sur le dos.", { Shape = "Quadruped", Body = rgb(70, 120, 60), Detail = rgb(90, 90, 95), Extra = "Cannon" }),
	pet("GolemDistributeur", "Golem Distributeur", "Divin", H, "Golem de pierre au torse en machine à canettes.", { Shape = "Humanoid", Body = rgb(120, 120, 125), Detail = rgb(255, 50, 50), Neon = true, Effect = "Pulse", EffectColor = rgb(255, 80, 80) }),
	pet("LionEnceinte", "Lion Enceinte", "Divin", H, "Lion noir à la crinière en caissons de basses.", { Shape = "Quadruped", Body = BLACK, Detail = rgb(60, 60, 70), Extra = "Mane", Effect = "Pulse", EffectColor = rgb(80, 200, 255) }),
	pet("CanardTractopelle", "Le Canard-Tractopelle", "Sigma", H, "Canard de bain géant sur chenilles en or massif.", { Shape = "Bird", Body = rgb(255, 225, 40), Detail = GOLD, Extra = "Tracks", Effect = "Aura", EffectColor = GOLD }),

	-- 🌌 Absurdes cosmiques (créations originales : aucun nom ni concept repris d'un autre jeu)
	pet("AstroBoulon", "Astro-Boulon", "Commun", B, "Petit robot astronaute tout en boulons, toujours un peu rouillé.", { Shape = "Humanoid", Body = rgb(200, 205, 215), Detail = rgb(60, 140, 255), Extra = "Antennas" }),
	pet("AutrucheFusee", "Autruche-Fusée", "Commun", B, "Autruche pressée avec deux réacteurs sur le dos.", { Shape = "Bird", Body = rgb(240, 230, 220), Detail = rgb(255, 120, 30), Long = true, Effect = "Fire" }),
	pet("MyrtilleLunaire", "Myrtille Lunaire", "Inhabituel", B, "Myrtille bleu nuit couverte de petits cratères.", { Shape = "Blob", Body = rgb(80, 90, 200), Detail = rgb(190, 190, 210), Effect = "Sparkles", EffectColor = rgb(200, 200, 255) }),
	pet("ConciergeCosmique", "Concierge Cosmique", "Inhabituel", B, "Balaie la poussière d'étoiles, mais il en tombe toujours plus.", { Shape = "Humanoid", Body = rgb(70, 90, 160), Detail = rgb(255, 220, 80), Extra = "Hat", Effect = "Sparkles" }),
	pet("MoutonMeteore", "Mouton Météore", "Rare", B, "Mouton laineux qui tombe du ciel en flammes, sans s'inquiéter.", { Shape = "Quadruped", Body = WHITE, Detail = rgb(255, 110, 40), Effect = "Fire" }),
	pet("TelecommandePerdue", "Télécommande Perdue", "Rare", B, "Personne ne sait d'où elle vient. Elle flotte et clignote.", { Shape = "Object", Body = rgb(40, 40, 50), Detail = rgb(255, 60, 60), Float = true, Neon = true, Effect = "Pulse", EffectColor = rgb(255, 60, 60) }),
	pet("SatelliteRonchon", "Satellite Ronchon", "Epique", B, "Satellite cabossé qui grésille dès qu'on lui parle.", { Shape = "Object", Body = rgb(190, 190, 200), Detail = rgb(60, 120, 255), Extra = "Antennas", Float = true, Effect = "Smoke" }),
	pet("PingouinComete", "Pingouin Comète", "Epique", B, "Glisse sur le ventre à toute vitesse, une traînée de comète derrière lui.", { Shape = "Bird", Body = BLACK, Detail = WHITE, Effect = "Sparkles", EffectColor = rgb(120, 220, 255) }),
	pet("BurritoNebuleuse", "Burrito Nébuleuse", "Legendaire", B, "Un burrito tiède qui contient une nébuleuse entière.", { Shape = "Object", Body = rgb(235, 200, 130), Detail = rgb(170, 80, 230), Neon = true, Effect = "Aura", EffectColor = rgb(200, 100, 255) }),
	pet("TrioAsteroides", "Le Trio d'Astéroïdes", "Legendaire", B, "Trois cailloux grognons qui voyagent toujours ensemble.", { Shape = "Humanoid", Body = rgb(110, 100, 95), Detail = rgb(255, 170, 60), Extra = "Trio", Float = true, Effect = "Smoke" }),
	pet("JumeauxEclipse", "Les Jumeaux Éclipse", "Mythique", B, "Le Soleil et la Lune, collés, qui se disputent la vedette.", { Shape = "Object", Body = rgb(255, 200, 40), Detail = rgb(200, 210, 240), Extra = "Twin", Float = true, Effect = "Pulse", EffectColor = rgb(255, 230, 120) }),
	pet("ToupieTrouDeVer", "Toupie Trou-de-Ver", "Mythique", B, "Toupie qui tourne si vite qu'elle aspire tout autour d'elle.", { Shape = "Object", Body = rgb(60, 30, 110), Detail = rgb(0, 230, 255), Float = true, Neon = true, Effect = "Pulse", EffectColor = rgb(0, 230, 255) }),
	pet("MachineQuantique", "Machine à Laver Quantique", "Divin", B, "Essore une galaxie à 3000 tours par seconde.", { Shape = "Object", Body = WHITE, Detail = rgb(90, 60, 200), Neon = true, Effect = "Bubbles", EffectColor = rgb(180, 140, 255) }),
	pet("DragonAurore", "Dragon Aurore", "Divin", B, "Dragon fait d'aurores boréales qui changent de couleur.", { Shape = "Dragon", Body = rgb(60, 220, 160), Detail = rgb(150, 80, 255), Float = true, Effect = "Sparkles", EffectColor = rgb(120, 255, 200) }),
	pet("BaleineGalaxie", "La Baleine Galaxie", "Sigma", B, "Baleine immense qui porte une galaxie entière dans son ventre.", { Shape = "Fish", Body = rgb(30, 40, 110), Detail = rgb(255, 120, 230), Float = true, Effect = "Aura", EffectColor = GOLD }),
}

local Config = require(script.Parent.Config)

local PetCatalog = {}

PetCatalog.List = list
PetCatalog.ById = {} :: { [string]: Pet }

-- Anciens Id -> nouveaux (8 oct. 2026 : familiers renommés, leurs noms reprenaient ceux d'un autre jeu).
-- Les sauvegardes qui contiennent encore un ancien Id sont converties au chargement (SessionData).
PetCatalog.Renamed = {
	SigmaBoy = "AstroBoulon",
	Trenostruzzo = "AutrucheFusee",
	FragolaLaLaLa = "MyrtilleLunaire",
	JobJobJobSahur = "ConciergeCosmique",
	VaquitasSaturnitas = "MoutonMeteore",
	CelularciniViciosini = "TelecommandePerdue",
	LosHotspotsitos = "SatelliteRonchon",
	Tralaledon = "PingouinComete",
	LosTacoritas = "BurritoNebuleuse",
	LosPrimos = "TrioAsteroides",
	KetchuruMusturu = "JumeauxEclipse",
	GaramaMadundung = "ToupieTrouDeVer",
	SpaghettiTualetti = "MachineQuantique",
	DragonCannelloni = "DragonAurore",
	StrawberryElephant = "BaleineGalaxie",
} :: { [string]: string }

-- Id actuel d'un familier (gère les anciens Id renommés).
function PetCatalog.CurrentId(petId: string): string
	return PetCatalog.Renamed[petId] or petId
end
PetCatalog.ByRarity = {} :: { [string]: { Pet } }

for _, entry in ipairs(list) do
	assert(PetCatalog.ById[entry.Id] == nil, "Id de familier en double : " .. entry.Id)
	PetCatalog.ById[entry.Id] = entry
	local bucket = PetCatalog.ByRarity[entry.Rarity]
	if not bucket then
		bucket = {}
		PetCatalog.ByRarity[entry.Rarity] = bucket
	end
	table.insert(bucket, entry)
end

-- Revenu par seconde d'un familier sur un socle : base de sa rareté, +15 % par rang dans sa rareté
-- (ordre du catalogue), pour que chaque familier ait sa propre valeur.
local incomes: { [string]: number } = {}
for rarityId, bucket in pairs(PetCatalog.ByRarity) do
	local rarity = Config.Rarities[Config.RarityIndex[rarityId]]
	for rank, entry in ipairs(bucket) do
		incomes[entry.Id] = if rarity then math.floor(rarity.Income * (1 + (rank - 1) * 0.15)) else 0
	end
end

function PetCatalog.GetIncome(petId: string): number
	return incomes[petId] or 0
end

return PetCatalog
