"""Simulateur de serveur à 8 joueurs (ECONOMY_REPORT.md, étape 5) : économie de chacun + vols entre eux.

Chaque joueur est une partie de economy_simulator.SoloRun (tirages, œufs, revenu, Boutique, mondes, Rebirth) ; ce
module ajoute, à chaque manche, deux phases (Feeding, digestion) où des voleurs tentent des vols. L'issue d'un vol
vient du modèle de poursuite de economy_map_metrics (lignes droites, réaction 1,5 s, « Reprendre » à 10 studs,
grappin à 55), précalculé en tables.

Lancé par : python -I dataset_and_pipeline/economy_simulator.py serveur [--servers 40] [--hours 2]

« actuelles » = les règles d'avant le 25 oct. (verrou permanent, poids et Force, pas de plafond) ; « proposées » = celles
appliquées depuis dans le jeu (lots 1 et 2 de ECONOMY_REPORT.md), comportements codés ici, pas lus dans Config.lua.

Hypothèses de comportement (à remplacer par les vraies mesures de Roblox Analytics quand il y aura des joueurs) :
PROFILES ci-dessous (où est chaque profil, s'il fait attention, s'il ferme sa base, combien il tente de vols).
Niveau d'entraînement d'un joueur = niveau moyen de son tapis et de son banc : < 8 débutant, < 17 moyen, sinon
entraîné (vitesse 16 / 31 / 46, Force 70 / 160 / 250). Le grappin est acheté dès que le joueur a 300K $.
"""
from __future__ import annotations

import copy
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import economy_map_metrics as M  # noqa: E402  (géométrie et poursuites)
from economy_simulator import CHECKPOINTS, Game, SoloRun, duration, pct, short  # noqa: E402

LEVELS = [(16.0, 70.0), (31.0, 160.0), (46.0, 250.0)]  # (vitesse, Force) : débutant, moyen, entraîné
LOCATIONS = {  # où est le propriétaire -> point de economy_map_metrics.landmarks()
    "base": "dans sa base (spawn)", "tapis": "à son tapis", "kiosque": "au kiosque voisin",
    "lance": "lance près du trou (r 65)", "loin": "de l'autre côté du trou", "ailleurs": "vole 2 bases plus loin",
}
GRAPPLE_PRICE = 150e3
GRAPPLE_COOLDOWN = {"actuelles": 5.0, "proposées": 9.0}
ROUND, FEEDING, DIGESTING = 105.0, 45.0, 60.0
# Réglages des règles proposées (balayés par sweep()) : fenêtre ouverte du verrou par manche (C, étape 2), bouclier
# (règle 8 : perte cumulée sur une fenêtre de temps -> protection), chance qu'un tir de grappin touche (règle 6),
# écart du plafond (règle 2), attention des profils (remplace PROFILES[...]["attention"]).
DEFAULT_KNOBS = {"open_seconds": 60.0, "shield_loss": 0.2, "shield_window": 0.0, "shield_seconds": 105.0,
                 "grapple_hit": 0.6, "cap_offset": 2, "attention": {}, "refuge": True, "escort": True, "friend_recover": True}

# Profils. feeding / digesting : (endroit, poids) ; attention : chance de réagir à l'alerte de vol ;
# lock : quand il ferme sa base ; steal_* : tentatives par phase.
PROFILES = {
    "prudent": {"feeding": None, "digesting": [("base", 0.6), ("tapis", 0.4)], "attention": 0.9, "lock": "home",
                "steal_feeding": 0.0, "steal_digesting": 0.0},
    "voleur": {"feeding": None, "digesting": [("ailleurs", 1.0)], "attention": 0.5, "lock": "away",
               "steal_feeding": 0.5, "steal_digesting": 1.0},
    "nouveau": {"feeding": None, "digesting": [("tapis", 0.4), ("kiosque", 0.3), ("base", 0.3)], "attention": 0.5,
                "lock": "sometimes", "steal_feeding": 0.0, "steal_digesting": 0.3},
    "duo": {"feeding": None, "digesting": [("ailleurs", 1.0)], "attention": 0.6, "lock": "away",
            "steal_feeding": 0.0, "steal_digesting": 1.0},
}


# ------------------------------------------------------------------------------------------------------------------
# Tables de poursuite


def build_tables(samples: int = 30, seed: int = 9) -> dict:
    """p10 / p55 (vols réussis sans grappin / si le grappin touche à coup sûr) et durée du trajet, par
    (règles, escorte, rareté, endroit du propriétaire, écart entre les bases, niveau du voleur, niveau du propriétaire)."""
    random.seed(seed)
    curve, _, _, _ = M.proposed_curve()
    marks = M.landmarks()
    sizes = [(a + b) / 2 for a, b in M.BANDS.values()]
    tables = {}
    for rules in ("actuelles", "proposées"):
        for escort in ((False,) if rules == "actuelles" else (False, True)):
            for r in range(8):
                for loc, mark in LOCATIONS.items():
                    spot = marks[mark][0]
                    for off in range(1, 5):
                        for lt, (wt, ft) in enumerate(LEVELS):
                            for lv, (wv, _) in enumerate(LEVELS):
                                if rules == "actuelles":
                                    v = wt * M.carry_mult(sizes[r], ft)
                                else:
                                    v = min(wt, wv) * curve[max(0, r - 1) if escort else r]
                                ok10 = ok55 = 0
                                trips = []
                                for _ in range(samples):
                                    pet = M.random_pet()
                                    target = M.nearest_inside(off, pet)
                                    trips.append(M.path_len(pet, target))
                                    ok10 += escapes_fast(pet, target, v, spot, wv, M.RECOVER)
                                    ok55 += escapes_fast(pet, target, v, spot, wv, M.GRAPPLE)
                                tables[(rules, escort, r + 1, loc, off, lt, lv)] = (
                                    ok10 / samples, ok55 / samples, M.median(trips) / v)
    return tables


def escapes_fast(pet, target, v_thief, victim, v_victim, radius, react=M.REACT, steps=60):
    length = M.dist(pet, target)
    total = length / v_thief
    ux, uy = (target[0] - pet[0]) / length, (target[1] - pet[1]) / length
    for n in range(steps + 1):
        t = total * n / steps
        px, py = pet[0] + ux * v_thief * t, pet[1] + uy * v_thief * t
        if math.hypot(px - victim[0], py - victim[1]) <= radius + v_victim * max(0.0, t - react):
            return False
    return True


# ------------------------------------------------------------------------------------------------------------------
# Joueurs et serveur


class Player:
    def __init__(self, run: SoloRun, profile: str, index: int, slot: int, new: bool):
        self.run = run
        self.profile = profile
        self.index = index  # numéro dans Server.players
        self.slot = slot  # numéro de la base (0 à 7, autour du trou)
        self.friend: int | None = None  # numéro du partenaire
        self.new = new  # profil tout neuf : protection de Config.Newcomer.ProtectionSeconds
        self.protected = new
        self.has_grapple = False
        self.base_cache: list[str] = []
        self.rebirths_start = run.rebirths
        self.shield_until = -1.0
        self.losses: list[tuple[float, float]] = []  # (heure, part du revenu perdue) : bouclier sur perte cumulée
        self.stats = {"tries": 0, "ok": 0, "stolen": 0, "useless_suffered": 0, "loss": 0.0, "jackpots": 0,
                      "bounty": 0.0, "griefs": 0}
        self.income_start = 0.0
        self.tier_start = run.tier

    def level(self) -> int:
        station = (self.run.up.get("Treadmill", 0) + self.run.up.get("Bench", 0)) / 2
        return 0 if station < 8 else 1 if station < 17 else 2

    def income(self) -> float:
        base, _, _ = self.run.layout()
        return self.run.per_second(base)

    def strength(self) -> float:
        """Valeur de la base (somme des revenus des familiers, sans monde ni Rebirth) : ne retombe pas au Rebirth."""
        return base_strength(self.run)


def base_strength(run: SoloRun) -> float:
    base, _, _ = run.layout()
    return sum(run.eff_income(p) for p in base)


class Server:
    def __init__(self, game: Game, tables: dict, rules: str, players: list[Player], rng: random.Random, knobs: dict):
        self.g, self.tables, self.rules, self.players, self.rng = game, tables, rules, players, rng
        self.knobs = knobs
        self.grapple_hit = knobs["grapple_hit"]
        self.cap_offset = knobs["cap_offset"]
        self.proposed = rules == "proposées"
        self.locked: dict[int, bool] = {}
        self.where: dict[int, str] = {}

    def offset(self, a: int, b: int) -> int:
        d = abs(a - b) % 8
        return min(d, 8 - d)

    def phase_location(self, player: Player, phase: str, raiding: bool) -> str:
        if raiding:
            return "ailleurs"
        prof = PROFILES[player.profile]
        if phase == "feeding":
            return "base" if player.level() >= 1 else "lance"  # Force ~160 : on lance depuis sa palette
        roll, acc = self.rng.random(), 0.0
        choices = [c for c in prof["digesting"] if c[0] != "ailleurs"] or [("tapis", 1.0)]
        total = sum(w for _, w in choices)
        for loc, weight in choices:
            acc += weight / total
            if roll <= acc:
                return loc
        return choices[-1][0]

    def is_locked(self, player: Player, phase: str, raiding: bool) -> bool:
        mode = PROFILES[player.profile]["lock"]
        if not self.proposed:
            # Aujourd'hui : fermé tant qu'on reste sur le bouton ; seul le prudent reste chez lui pendant la digestion.
            return phase == "digesting" and mode == "home" and self.where[player.index] == "base"
        # Proposé : fermé L = 105 - C secondes par manche (C = fenêtre ouverte), une fois, au moment choisi :
        # le prudent ferme pendant qu'il lance (Feeding d'abord), le voleur pendant qu'il part voler (digestion d'abord).
        closed = ROUND - self.knobs["open_seconds"]
        if mode == "home":
            share = min(closed, FEEDING) / FEEDING if phase == "feeding" else max(0.0, closed - FEEDING) / DIGESTING
        elif mode == "away":
            share = min(closed, DIGESTING) / DIGESTING if phase == "digesting" else max(0.0, closed - DIGESTING) / FEEDING
        else:  # le nouveau ferme une fois sur trois, pendant qu'il lance
            share = 0.3 * min(closed, FEEDING) / FEEDING if phase == "feeding" else 0.0
        return self.rng.random() < share

    def steal_value(self, thief: Player, victim: Player, pet: str) -> float:
        """Argent que le vol rapporte au voleur en une heure (gain de revenu x 3 600 s)."""
        run = thief.run
        if self.proposed:
            top = run.self_best + self.cap_offset
            value = self.g.income(pet)
            if top <= len(self.g.rarities):
                value = min(value, self.g.rarities[top - 1]["Income"])
        else:
            value = self.g.income(pet)
        base = thief.base_cache
        low = min(run.eff_income(p) for p in base) if len(base) >= self.g.income_slots(run.rebirths) else 0.0
        gain = max(0.0, value - low) * self.g.world(run.tier)["IncomeMultiplier"] * self.g.rebirth_mult(run.rebirths)
        return gain * 3600

    def success(self, thief: Player, victim: Player, rarity: int, escort: bool) -> float:
        """Chance de réussite d'un vol (propriétaire attentif ou non, grappin, ami de la victime)."""
        off = self.offset(thief.slot, victim.slot)
        if self.proposed and self.knobs["refuge"] and thief.friend is not None:  # règle 17 : refuge chez l'ami
            off = min(off, self.offset(self.players[thief.friend].slot, victim.slot))
        escort = escort and self.proposed and self.knobs["escort"]  # règle 18
        p10, p55, trip = self.tables[(self.rules, escort, rarity, self.where[victim.index], off, thief.level(), victim.level())]
        if victim.has_grapple:
            hit = 1.0 if not self.proposed else self.grapple_hit
            shots = 1 + int(trip // GRAPPLE_COOLDOWN[self.rules])
            chase = p55 + (p10 - p55) * (1 - hit) ** shots
        else:
            chase = p10
        attention = self.attention(victim)
        p = attention * chase + (1 - attention)
        if self.proposed and self.knobs["friend_recover"] and victim.friend is not None:  # règle 19 : « Reprendre » pour un ami
            friend = self.players[victim.friend]
            if self.where[friend.index] in ("base", "tapis"):
                f_att = self.attention(friend)
                f_chase = self.tables[(self.rules, escort, rarity, "lance", off, thief.level(), friend.level())][0]
                p *= f_att * f_chase + (1 - f_att)
        return p

    def attention(self, player: Player) -> float:
        return self.knobs["attention"].get(player.profile, PROFILES[player.profile]["attention"])

    def round(self, now: float):
        players = self.players
        for pl in players:
            if not pl.has_grapple and pl.run.money >= 2 * GRAPPLE_PRICE:
                pl.run.money -= GRAPPLE_PRICE
                pl.has_grapple = True
        crown = max(players, key=lambda p: p.income())
        for phase in ("feeding", "digesting"):
            raiders = [pl for pl in players if PROFILES[pl.profile]["steal_" + phase] > self.rng.random()]
            raiding = {pl.index for pl in raiders}
            # Un duo vole ensemble : les deux partent, l'un escorte l'autre.
            for pl in raiders:
                if pl.profile == "duo" and pl.friend is not None:
                    raiding.add(pl.friend)
            for pl in players:
                self.where[pl.index] = self.phase_location(pl, phase, pl.index in raiding)
                self.locked[pl.index] = self.is_locked(pl, phase, pl.index in raiding)
                pl.base_cache, _, _ = pl.run.layout()
            done: set[int] = set()
            for thief in raiders:
                if thief.profile == "duo" and thief.friend in done:
                    continue  # le partenaire escorte ce vol
                escort = thief.profile == "duo" and thief.friend is not None
                self.attempt(thief, crown, now, escort)
                done.add(thief.index)

    def attempt(self, thief: Player, crown: Player, now: float, escort: bool):
        g = self.g
        best, best_ev, grief = None, 0.0, None
        for victim in self.players:
            if victim is thief or victim.index == thief.friend or self.locked[victim.index]:
                continue
            if victim.protected and now < g.cfg["Newcomer"]["ProtectionSeconds"]:
                continue
            if self.proposed and victim.shield_until > now:
                continue
            base = victim.base_cache
            for pet in sorted(set(base)):  # ordre fixe : résultats reproductibles
                r = g.rarity_of(pet)
                p = self.success(thief, victim, r, escort)
                value = self.steal_value(thief, victim, pet)
                bounty = 0.0
                if self.proposed and victim is crown:  # règle 9 : prime = 10 min du revenu (plafonné) du familier
                    capped = min(g.income(pet), g.rarities[min(thief.run.self_best + self.cap_offset, len(g.rarities)) - 1]["Income"])
                    bounty = g.cfg["Sacrifice"]["IncomeSeconds"] * capped
                ev = p * (value + bounty)
                if ev > best_ev:
                    best, best_ev = (victim, pet, p, value, bounty), ev
                if value <= 0 and (grief is None or p > grief[2]):
                    grief = (victim, pet, p, 0.0, 0.0)
        if best is None:
            # Rien d'utile à voler. Aujourd'hui, la quête « Vole N familiers » pousse quand même à voler (1 fois sur 2) ;
            # avec la règle 7 (vol utile), c'est impossible.
            if self.proposed or grief is None or self.rng.random() > 0.5:
                return
            best = grief
            thief.stats["griefs"] += 1
        victim, pet, p, value, bounty = best
        thief.stats["tries"] += 1
        thief.protected = False  # voler met fin à sa propre protection (SessionData.EndNewcomerProtection)
        if self.rng.random() >= p:
            if self.proposed and victim is crown:
                crown.run.money += bounty  # règle 9 : la défense du roi rapporte
            return
        before = victim.income()
        thief_income = max(thief.income(), 1e-9)
        victim.run.lose_pet(pet)
        thief.run.receive_pet(pet)
        thief.base_cache, _, _ = thief.run.layout()
        victim.base_cache, _, _ = victim.run.layout()
        after = victim.income()
        loss = (before - after) / before if before > 0 else 0.0
        thief.stats["ok"] += 1
        thief.run.money += bounty
        thief.stats["bounty"] += bounty
        if value / 3600 / thief_income >= 20:
            thief.stats["jackpots"] += 1
        victim.stats["stolen"] += 1
        victim.stats["loss"] += loss
        if value <= 0:
            victim.stats["useless_suffered"] += 1
        if self.proposed:  # règle 8 : bouclier après une grosse perte (une seule, ou cumulée sur shield_window s)
            victim.losses.append((now, loss))
            recent = sum(l for t, l in victim.losses if now - t <= self.knobs["shield_window"])
            if max(loss, recent) >= self.knobs["shield_loss"]:
                victim.shield_until = now + self.knobs["shield_seconds"]
                victim.losses.clear()


# ------------------------------------------------------------------------------------------------------------------
# Scénarios


SCENARIOS = {
    "mixte": [("nouveau", 0, None), ("voleur", 1, None), ("prudent", 2, None), ("duo", 2, "A"), ("duo", 2, "A"),
              ("prudent", 5, None), ("voleur", 8, None), ("prudent", 12, None)],
    "nouveau chez les vétérans": [("nouveau", 0, None), ("prudent", 5, None), ("voleur", 5, None), ("prudent", 8, None),
                                  ("voleur", 8, None), ("prudent", 12, None), ("voleur", 12, None), ("prudent", 12, None)],
    "duo de nouveaux": [("duo", 0, "A"), ("duo", 0, "A"), ("nouveau", 0, None), ("nouveau", 0, None), ("voleur", 2, None),
                        ("prudent", 2, None), ("voleur", 5, None), ("prudent", 5, None)],
}


def veteran_pool(game: Game, hours_list, size: int, seed: int = 77) -> dict[float, list[SoloRun]]:
    """Parties jouées seul jusqu'à chaque ancienneté (copiées dans les serveurs)."""
    rng = random.Random(seed)
    pool = {}
    for hours in hours_list:
        runs = []
        for _ in range(size):
            run = SoloRun(game, random.Random(rng.random()), options={"record": False})
            run.play(hours)
            runs.append(run)
        pool[hours] = runs
    return pool


def play_server(game, tables, rules, spec, pool, rng, hours, knobs):
    cap_offset = knobs["cap_offset"]
    players = []
    slots = list(range(8))
    if rules == "actuelles":
        rng.shuffle(slots)  # bases attribuées au hasard (la première libre)
    else:
        # Règle 17 : les amis ont des bases voisines (le reste au hasard).
        rest = [s for s in range(8)]
        rng.shuffle(rest)
        slots = rest
        friends = [i for i, (_, _, tag) in enumerate(spec) if tag]
        if len(friends) == 2:
            a, b = friends
            slots[b] = (slots[a] + 1) % 8
            for i in range(8):
                if i not in (a, b) and slots[i] == slots[b]:
                    slots[i] = [s for s in range(8) if s not in slots][0]
    tags = {}
    for i, (profile, hours_played, tag) in enumerate(spec):
        if hours_played == 0:
            run = SoloRun(game, random.Random(rng.random()), options={"record": False})
        else:
            run = copy.deepcopy(rng.choice(pool[hours_played]))
            run.rng = random.Random(rng.random())
        run.options = {"record": False, "plafond": rules == "proposées", "plafond_ecart": cap_offset}
        run.self_best = max(game.rarity_of(p) for p, c in run.pets.items() if c > 0)
        pl = Player(run, profile, i, slots[i], hours_played == 0)
        if tag:
            tags.setdefault(tag, []).append(i)
        players.append(pl)
    for members in tags.values():
        if len(members) == 2:
            players[members[0]].friend, players[members[1]].friend = members[1], members[0]
    for pl in players:
        pl.income_start = pl.income()
        pl.strength_start = pl.strength()
        pl.tier_start = pl.run.tier
    server = Server(game, tables, rules, players, rng, knobs)
    rounds = int(hours * 3600 // ROUND)
    for k in range(rounds):
        for pl in players:
            pl.run.step(len(CHECKPOINTS))
        server.round(k * ROUND)
    return players


def solo_baseline(game: Game, pool: dict, hours: float, seed: int = 5) -> dict[float, float]:
    """Valeur de la base en fin de session / en début, même ancienneté jouée SEUL (sans vols) : la référence."""
    rng = random.Random(seed)
    base = {}
    for played in [0.0] + sorted(pool):
        ratios = []
        for k in range(12):
            if played == 0:
                run = SoloRun(game, random.Random(rng.random()), options={"record": False})
            else:
                run = copy.deepcopy(pool[played][k % len(pool[played])])
                run.rng = random.Random(rng.random())
            start = base_strength(run)
            for _ in range(int(hours * 3600 // ROUND)):
                run.step(len(CHECKPOINTS))
            ratios.append(base_strength(run) / max(start, 1e-9))
        base[played] = sorted(ratios)[len(ratios) // 2]
    return base


_CACHE: dict = {}


def setup(game: Game, hours: float):
    key = hours
    if key not in _CACHE:
        tables = build_tables()
        pool = veteran_pool(game, sorted({h for spec in SCENARIOS.values() for _, h, _ in spec if h > 0}), 10)
        _CACHE[key] = (tables, pool, solo_baseline(game, pool, hours))
    return _CACHE[key]


def run_scenarios(game: Game, servers: int, hours: float, knobs: dict | None = None, names=None, quiet: bool = False,
                  rules_list=("actuelles", "proposées")):
    knobs = {**DEFAULT_KNOBS, **(knobs or {})}
    tables, pool, baseline = setup(game, hours)
    results = {}
    for name, spec in SCENARIOS.items():
        if names and name not in names:
            continue
        for rules in rules_list:
            rng = random.Random(2024)
            rows: dict[tuple, list[Player]] = {}
            leader_gap = []
            for _ in range(servers):
                players = play_server(game, tables, rules, spec, pool, rng, hours, knobs)
                for i, pl in enumerate(players):
                    rows.setdefault((i, spec[i][0], spec[i][1]), []).append(pl)
                start = sorted(p.strength_start for p in players)
                end = sorted(p.strength() for p in players)
                leader_gap.append((start[-1] / max(start[len(start) // 2], 1e-9), end[-1] / max(end[len(end) // 2], 1e-9)))
            results[(name, rules)] = (rows, leader_gap)
            if not quiet:
                print_scenario(name, rules, rows, leader_gap, hours, baseline)
    return results


def summarize(rows, hours, baseline):
    """Par joueur du scénario : vols tentés / réussis / subis par heure, vols inutiles subis, jackpots (gain >= x20)
    par session, valeur de la base en fin de session comparée à la même partie jouée seule (médiane), mondes gagnés."""
    out = []
    for (i, profile, played), pls in sorted(rows.items()):
        n = len(pls)
        mean = lambda key: sum(p.stats[key] for p in pls) / n / hours
        growth = sorted(p.strength() / max(p.strength_start, 1e-9) for p in pls)
        worlds = sorted(p.run.tier - p.tier_start + 7 * (p.run.rebirths - p.rebirths_start) for p in pls)
        out.append({"label": f"{profile} ({played:g} h)" if played else f"{profile} (nouveau)", "tries": mean("tries"),
                    "ok": mean("ok"), "stolen": mean("stolen"), "useless": mean("useless_suffered"),
                    "jackpots": sum(p.stats["jackpots"] for p in pls) / n, "vs_solo": growth[n // 2] / baseline[float(played)],
                    "worlds": worlds[n // 2]})
    return out


def print_scenario(name, rules, rows, leader_gap, hours, baseline):
    print(f"\n=== {name} — règles {rules} ({len(leader_gap)} serveurs, {hours:g} h) ===")
    print(f"{'joueur':24s} {'vols/h':>7s} {'réussis/h':>10s} {'subis/h':>8s} {'inutiles subis/h':>17s}"
          f" {'jackpots':>9s} {'base / seul':>12s} {'mondes +':>9s}")
    for row in summarize(rows, hours, baseline):
        print(f"{row['label']:24s} {row['tries']:7.2f} {row['ok']:10.2f} {row['stolen']:8.2f} {row['useless']:17.2f}"
              f" {row['jackpots']:9.2f} {row['vs_solo']:12.2f} {row['worlds']:9d}")
    starts = sorted(a for a, _ in leader_gap)
    ends = sorted(b for _, b in leader_gap)
    print(f"écart de valeur de base, plus riche / médiane : {starts[len(starts) // 2]:.3g} au début -> "
          f"{ends[len(ends) // 2]:.3g} à la fin")


SWEEP_CONFIGS: list = []  # remplacé par sweep2() pour un second balayage


def sweep2(game: Game, servers: int, hours: float):
    """Second balayage (étape 5) : bouclier sur une heure, et ce qui rend le duo si fort."""
    global SWEEP_CONFIGS
    SWEEP_CONFIGS = [
        ("réglages de l'étape 4", {}),
        ("bouclier : 10 % perdus en 1 h -> 30 min", {"shield_window": 3600.0, "shield_loss": 0.1, "shield_seconds": 1800.0}),
        ("bouclier : 15 % perdus en 1 h -> 15 min", {"shield_window": 3600.0, "shield_loss": 0.15, "shield_seconds": 900.0}),
        ("duo sans escorte", {"escort": False}),
        ("duo sans refuge", {"refuge": False}),
        ("duo sans « Reprendre » pour un ami", {"friend_recover": False}),
        ("duo sans escorte ni refuge", {"escort": False, "refuge": False}),
        ("bouclier 10 %/1 h + duo sans refuge", {"shield_window": 3600.0, "shield_loss": 0.1, "shield_seconds": 1800.0,
                                                "refuge": False}),
    ]
    sweep(game, servers, hours)


def sweep(game: Game, servers: int, hours: float):
    """Balaye les réglages incertains des règles proposées et résume l'effet sur chaque profil."""
    configs = SWEEP_CONFIGS if SWEEP_CONFIGS else [
        ("réglages de l'étape 4", {}),
        ("fenêtre ouverte 30 s", {"open_seconds": 30.0}),
        ("bouclier : 20 % cumulés en 10 min -> 5 min", {"shield_window": 600.0, "shield_seconds": 300.0}),
        ("fenêtre 30 s + bouclier cumulé", {"open_seconds": 30.0, "shield_window": 600.0, "shield_seconds": 300.0}),
        ("défenseurs moins attentifs (prudent 0,8)", {"attention": {"prudent": 0.8}}),
        ("défenseurs très attentifs (prudent 0,97)", {"attention": {"prudent": 0.97}}),
        ("grappin qui touche 4 fois sur 10", {"grapple_hit": 0.4}),
        ("grappin qui touche 8 fois sur 10", {"grapple_hit": 0.8}),
        ("plafond à +1 rareté", {"cap_offset": 1}),
        ("plafond à +3 raretés", {"cap_offset": 3}),
    ]
    setup(game, hours)
    _, _, baseline = setup(game, hours)
    print("Balayage : base / seul = valeur de la base en fin de session divisée par celle de la même partie jouée seule.")
    print("nouveau = nouveau chez les vétérans (base / seul, jackpots par session) ; prudent = les prudents de 12 h du même")
    print("scénario (base / seul, vols subis par heure) ; voleur 8 h (base / seul, vols réussis par heure) ;")
    print("duo = voleur du duo de nouveaux (base / seul) ; écart = plus riche / médiane en fin de session (mixte).")

    def line(label, res, rules):
        newbie = summarize(res[("nouveau chez les vétérans", rules)][0], hours, baseline)
        duo = summarize(res[("duo de nouveaux", rules)][0], hours, baseline)
        gaps = sorted(b for _, b in res[("mixte", rules)][1])
        prudent = [r for r in newbie if r["label"].startswith("prudent (12")]
        thief = [r for r in newbie if r["label"].startswith("voleur (8")][0]
        print(f"{label:44s} nouveau x{newbie[0]['vs_solo']:5.2f} / {newbie[0]['jackpots']:4.2f}"
              f" | prudent x{sum(r['vs_solo'] for r in prudent) / len(prudent):4.2f} / "
              f"{sum(r['stolen'] for r in prudent) / len(prudent):4.2f}"
              f" | voleur x{thief['vs_solo']:4.2f} / {thief['ok']:5.2f} | duo x{duo[0]['vs_solo']:6.2f}"
              f" | écart {gaps[len(gaps) // 2]:5.2f}")

    line("RÈGLES ACTUELLES", run_scenarios(game, servers, hours, quiet=True, rules_list=("actuelles",)), "actuelles")
    for label, knobs in configs:
        line(label, run_scenarios(game, servers, hours, knobs, quiet=True, rules_list=("proposées",)), "proposées")
