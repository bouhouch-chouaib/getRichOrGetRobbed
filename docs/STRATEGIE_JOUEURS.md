# Stratégie : des joueurs qui reviennent, et un jeu qu'on connaît

> Écrite le 29 octobre 2026, jeu public depuis peu (115 visites). À relire chaque lundi.
> Va avec : `PAGE_DU_JEU.md` (page du jeu, publicités), `ANALYTICS_LANCEMENT.md` (ce que le jeu mesure),
> `TEST_REEL.md` (test à 2 joueurs).

## 0. L'idée en 5 lignes

1. Roblox montre un jeu dans « Recommandé pour toi » surtout s'il **garde ses joueurs sur 28 jours**, s'ils
   **viennent avec des amis**, si les parties sont bonnes et s'ils dépensent. Un bon clic sur la miniature ne suffit plus.
2. Donc on **bouche d'abord les fuites** (jeu en anglais, vrai test à 2), **puis** on fait venir du monde.
3. On donne **des raisons de revenir** : œufs qui finissent quand on n'est pas là, notifications, événements à heure fixe.
4. On fait venir des joueurs par **3 portes** : les amis (invitations récompensées), les vidéos courtes (TikTok, Shorts),
   les publicités Roblox.
5. **Une mise à jour par semaine, toujours le même jour.** On regarde les chiffres le lundi et on corrige la plus grosse fuite.

## 1. Ce que Roblox regarde (sources en bas)

| Signal | Ce que ça veut dire pour nous |
|---|---|
| Rétention jour 1, jours 2-7, jours 8-28 | Le joueur revient demain, puis la semaine suivante, puis le mois. **Le plus important.** |
| Joueurs venus avec des amis (co-play) | Invitations, rejoindre un ami, serveurs privés. Le matchmaking ne compte pas. |
| Qualité des parties | Durée de jeu, joueurs qui ne partent pas dans la première minute. |
| Dépenses | Achats Robux (passes, produits). |
| Miniature | Roblox choisit lui-même la meilleure parmi 2 à 5 miniatures actives, pour chaque groupe de joueurs. |

Le tableau de bord du Creator Hub (Analytics) montre l'importance de chaque signal et la comparaison avec les
**jeux similaires** : c'est notre repère, pas des chiffres trouvés sur internet.

## 2. Étape A : boucher les fuites (cette semaine, avant de payer quoi que ce soit)

| # | Quoi | Qui | Pourquoi |
|---|---|---|---|
| A1 | **Le jeu en anglais** : table de traduction anglaise des textes du jeu (`LocalizationTable`), puis vérifier avec un compte réglé en anglais | Claude, puis Chouaib vérifie | La grande majorité des joueurs Roblox ne lit pas le français. La traduction automatique rate les textes fabriqués par le code (« +1 NOM », compteurs). Sans ça, la pub paie des joueurs qui partent. |
| A2 | **Test à 2 vrais comptes + un téléphone** dans le jeu publié (`TEST_REEL.md`) | Chouaib + un ami | Le vol, la batte, le grappin et l'échange n'ont jamais été joués à 2 vrais joueurs. |
| A3 | **Maturité** : la page affiche « Minimum ». Si le questionnaire dit violence « de temps en temps », le refaire avec « répétée » (→ « Léger ») | Chouaib | Une fausse réponse peut faire sanctionner le jeu. |
| A4 | **Badges et groupe** : créer les 13 badges et le groupe Roblox, donner les numéros | Chouaib crée, Claude branche (`Config.Badges`, `Config.Group`) | Les badges donnent des buts ; le groupe sert à prévenir des mises à jour (et donne déjà +10 % de revenu). |
| A5 | **Codes cadeaux en anglais** (`LAUNCH`, `BLACKHOLE`, `THANKS`) à côté des codes français | Claude | Les codes circulent dans les vidéos et les commentaires. |
| A6 | **3 à 5 miniatures actives** (Creator Hub → Miniatures → Accueil) | Chouaib (prompts : `assets/store/PROMPTS.md`) | Roblox teste toutes seules les miniatures et garde la meilleure pour chaque public. Thèmes : un vol en pleine course, une éclosion Divine, le trou noir géant. |

## 3. Étape B : des raisons de revenir (semaines 1 et 2, dans le jeu)

Ce qui existe déjà : cadeau du jour sur 7 jours, 3 défis du jour, œufs qui incubent jusqu'à 30 min, capsule
d'évolution, résumé d'absence, Rebirth, couronne du plus riche, marché, échanges, duels, bonus d'amis.

Ce qui manque, par ordre d'effet attendu :

1. **Invitations récompensées (parrainage).** Bouton « INVITER » dans le HUD (avec « +10 % PAR AMI » écrit dessus).
   Quand l'ami arrive, Roblox donne le numéro de celui qui a invité (`Player:GetJoinData().ReferredByPlayerId`) :
   récompense **une fois par ami invité** (par exemple 1 œuf pour chacun), limitée à 3 à 5 amis, enregistrée dans
   la sauvegarde. Bannière « Referral Rewards » à créer dans le Creator Hub (Engagement). C'est le signal
   « co-play » que Roblox aime le plus.
2. **Notifications Roblox.** Demander l'accord au bon moment (quand un œuf de 30 min part en incubation, pas à
   l'arrivée) avec `ExperienceNotificationService`. Messages (1 par jour au plus, joueurs de 13 ans et plus) :
   « TON ŒUF EST PRÊT ! », « ON T'A VOLÉ UN FAMILIER ! », « TON BOUCLIER EST FINI ». Le jeu a passé les 100 visites
   demandées. Envoi par l'API Open Cloud (à vérifier pendant la mise en place : depuis le serveur du jeu ou par un
   petit outil à part).
3. **Rendez-vous à heure fixe dans le jeu.** Toutes les heures pile, 5 minutes de « PLUIE D'ŒUFS » ou « TROU NOIR
   DORÉ » (points x2), annoncées 1 minute avant. Les joueurs apprennent l'heure et restent jusqu'à elle.
4. **Événements Roblox** (Creator Hub → Engagement → Événements et mises à jour) : un événement par mise à jour et par
   week-end. Les joueurs cliquent « Me prévenir » et reçoivent une notification au début. 10 événements à la fois au plus.
5. **Tableau des nouveautés** dans l'arène : ce qui a changé cette semaine et le jour de la prochaine mise à jour.

## 4. Étape C : faire connaître le jeu (à partir de la semaine 2, une fois A1 et A2 faits)

### C1. Vidéos courtes (TikTok, YouTube Shorts) : la porte principale de ce genre de jeu

- **3 vidéos par semaine**, verticales (9:16), 15 à 30 s, texte en anglais à l'écran, nom du jeu à la fin.
- Le début (1re seconde) doit montrer l'action, pas un titre.
- Idées qui marchent dans les jeux de vol : un vol réussi à la dernière seconde ; un vol raté (coup de batte) ;
  éclosion d'un Sigma ou d'un Divin ; « Commun contre Sigma » ; l'explosion du trou noir ; voler le roi (couronne) ;
  « de 0 à 1 million en 10 minutes ».
- Claude filme dans Studio avec les outils de la vidéo de la page (`tools/video/`) et monte au format vertical ;
  Chouaib poste. Garder la même musique originale (`tools/video/make_music.py`), jamais de son d'un autre jeu.
- Mêmes vidéos sur la page du jeu et dans le groupe.

### C2. Publicités Roblox (Ads Manager)

Règles et première campagne : `PAGE_DU_JEU.md` §7. En bref : objectif « Plays », nouveaux joueurs, petit budget par
jour sur 3 à 5 jours, puis lire la rétention jour 1 avant de remettre de l'argent. Une campagne en plus seulement si
la rétention du jour 1 des joueurs venus par la pub tient face aux « jeux similaires ».

### C3. Créateurs de vidéos Roblox

Chercher des petites chaînes Roblox (1 000 à 50 000 abonnés, français et anglais) qui font des jeux de vol ou de
familiers. Leur proposer : un code cadeau à leur nom, et une annonce dans le groupe. Petites chaînes = plus de réponses.

### C4. Groupe Roblox (et Discord si Chouaib le souhaite)

Un message à chaque mise à jour, les codes, les captures des plus belles éclosions. Discord demande 13 ans et plus et
du temps de modération : seulement si quelqu'un peut s'en occuper.

## 5. Étape D : durer (chaque semaine)

- **Mise à jour chaque samedi à 18 h (heure de Paris)** = midi à New York, 9 h en Californie : Europe et Amérique sont
  là en même temps. Le titre du jeu porte le numéro : `[UPDATE 1] Steal Pets & Feed the Black Hole 🕳️`.
- Chaque mise à jour apporte **une chose qui se voit** : 3 à 5 nouveaux familiers (pipeline Blender, `PIPELINE.md`),
  ou un nouvel objet, ou un événement limité. Plus une correction tirée des chiffres.
- Familiers **limités dans le temps** (disponibles une semaine) : raison de revenir cette semaine-là.

### Calendrier proposé

| Semaine | Mise à jour (samedi) | Pour le faire connaître |
|---|---|---|
| 29 oct. - 1er nov. | A1 à A6 (pas de mise à jour visible, trop court pour Halloween) | Rien de payé |
| 2 - 8 nov. | **UPDATE 1** : invitations + codes anglais + 3 nouveaux familiers | 3 vidéos, groupe |
| 9 - 15 nov. | **UPDATE 2** : notifications + rendez-vous d'heure pile | 1re campagne de pub (petite) |
| 16 - 22 nov. | **UPDATE 3** : familiers limités de la semaine | Créateurs de vidéos, événement Roblox |
| 23 - 29 nov. | **UPDATE 4** : correction de la plus grosse fuite vue dans les chiffres | Pub si la rétention tient |
| 30 nov. - 18 déc. | Préparer **l'événement d'hiver** (monde enneigé ou décor de fête, familiers d'hiver) | Vidéos d'annonce |
| 19 déc. - 4 janv. | **Événement d'hiver** pendant les vacances (le plus de joueurs de l'année) | Événement Roblox, pub plus forte |

## 6. Chaque lundi : lire les chiffres et décider

Creator Hub → le jeu → Analytics (rétention, entonnoir des premières minutes de `ANALYTICS_LANCEMENT.md`, durée de jeu).

| Si on voit… | Alors… |
|---|---|
| Beaucoup partent avant le 1er lancer | Le début est confus : flèches, tutoriel, texte en anglais. |
| Ils lancent mais partent avant le 1er œuf | Le 1er œuf arrive trop tard : le raccourcir. |
| Bonne 1re partie, mais peu reviennent le lendemain | Notifications, œufs plus longs qui finissent quand on est parti, cadeau du jour plus visible. |
| Ils reviennent la 1re semaine puis plus rien | Pas assez de nouveau : mises à jour, familiers limités, objectifs de Rebirth. |
| Beaucoup de vues de la miniature, peu de clics | Changer les miniatures les plus faibles. |
| Téléphone bien pire que PC | Regarder le jeu sur téléphone en premier (la majorité des joueurs Roblox y joue). |

**Une seule grosse correction à la fois**, pour savoir ce qui a marché.

## 7. À ne jamais faire

- Acheter des visites, des likes ou des joueurs robots : le jeu peut être supprimé.
- Donner une récompense en échange d'un like ou d'un favori : on peut le demander, pas le payer.
- Reprendre le nom, les images, les sons ou les personnages d'un autre jeu (même dans les vidéos).
- Mettre de l'argent dans la pub avant A1 et A2.
- Tout changer en même temps.

## 8. Qui fait quoi

| Chouaib | Claude |
|---|---|
| Creator Hub : maturité, miniatures, badges, groupe, bannière de parrainage, événements, pubs | Code : anglais, invitations, notifications, rendez-vous, nouveaux familiers, codes |
| Test à 2 comptes, publier chaque samedi (Studio → Publier) | Vidéos verticales filmées dans Studio, montées |
| Poster les vidéos, répondre aux joueurs | Lire les chiffres avec Chouaib le lundi et proposer la correction |

## Sources

- [Roblox : Optimizing Discovery (juin 2026)](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox) : fenêtre de 28 jours, rétention, co-play, qualité des parties, dépenses.
- [DevForum : algorithme « Recommandé pour toi » amélioré](https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441)
- [Système de récompenses d'invitation](https://create.roblox.com/docs/production/promotion/referral-system) : `ReferredByPlayerId`, bannière, limites.
- [Invitations dans le jeu](https://create.roblox.com/docs/production/promotion/invite-prompts)
- [Notifications d'expérience](https://create.roblox.com/docs/en-us/production/promotion/experience-notifications) et [API Open Cloud](https://create.roblox.com/docs/en-us/cloud/guides/experience-notifications) : 13 ans et plus, 1 par jour, 100 visites minimum.
- [Événements d'expérience](https://create.roblox.com/docs/production/promotion/experience-events) : « Me prévenir », 10 événements au plus.
- [Miniatures personnalisées](https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233) : 2 à 5 miniatures actives.
