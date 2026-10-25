"""Simulateur économique de Get Rich Or Get Robbed (dataset_and_pipeline/ECONOMY_REPORT.md).

Les valeurs viennent du jeu lui-même : tools/export-economy.luau charge les vrais modules (Config, PetCatalog, PetSizes)
avec Lune et les écrit dans economy_data.json. Les règles (tirages, pitié, rang, œufs, doublons, fusion, revenu des
15 meilleurs, mondes, Boutique, Rebirth) reprennent celles du serveur et de tools/sim-economy.luau.

    python -I dataset_and_pipeline/economy_simulator.py solo [--runs 200] [--hours 30]
    python -I dataset_and_pipeline/economy_simulator.py segments [--runs 200] [--hours 30]
    python -I dataset_and_pipeline/economy_simulator.py cibles [--runs 120] [--hours 11]
    python -I dataset_and_pipeline/economy_simulator.py retention [--runs 150] [--hours 12]
    python -I dataset_and_pipeline/economy_simulator.py serveur [--servers 40] [--hours 2] [--grappin 0.6]
    python -I dataset_and_pipeline/economy_simulator.py balayage [--servers 30] [--hours 1]
    options des règles proposées (tous les modes sauf retention) : --pitie-palier, --capsules-rebirth, --doublons-capsule,
    --rebirth-croissance 1.62

`solo` : même sortie que tools/sim-economy.luau ; avec --no-capsule, mêmes règles (vérifié : mêmes résultats).
`segments` : les dents de scie, monde par monde (montée à l'arrivée, plateau, temps d'attente du monde suivant).
`cibles` : qui a intérêt à voler qui selon l'avancée de chacun (vols utiles, gain du meilleur vol, effet du plafond).
`retention` : pitié (chances réelles, garanties données, malchance extrême), jauge du trou noir, avancée de l'Index.
`serveur` : 8 joueurs sur un serveur (prudent, voleur, nouveau, duo d'amis), vols entre eux, règles actuelles contre
proposées (dataset_and_pipeline/economy_server.py).
`balayage` : les réglages incertains des règles proposées (fenêtre du verrou, bouclier, attention, grappin, plafond).
"""
from __future__ import annotations

import argparse
import copy
import json
import math
import random
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_PATH = ROOT / "dataset_and_pipeline" / "economy_data.json"


def load_data(refresh: bool = True) -> dict:
    """Relit les valeurs du jeu (Lune), ou garde le dernier export si Lune n'est pas là."""
    lune = shutil.which("lune") or str(Path.home() / ".aftman" / "bin" / "lune.exe")
    if refresh and Path(lune).exists():
        subprocess.run([lune, "run", "tools/export-economy.luau", ".", str(DATA_PATH)], cwd=ROOT, check=True,
                       stdout=subprocess.DEVNULL)
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


class Game:
    """Règles fixes du jeu, lues dans les données exportées."""

    def __init__(self, data: dict):
        self.cfg = copy.deepcopy(data["config"])
        cfg = self.cfg
        self.rarities = cfg["Rarities"]
        self.rarity_index = {r["Id"]: i + 1 for i, r in enumerate(self.rarities)}
        self.worlds = cfg["Worlds"]
        self.pets = {p["id"]: p for p in data["pets"]}
        self.incomes: dict[str, float] = data["incomes"]  # toutes les formes (évoluées, mutées) : PetCatalog.GetIncome
        self.base_by_rarity: dict[int, list[str]] = {}
        self.by_world: dict[str, list[str]] = {}
        for pet in data["pets"]:
            if pet.get("world"):
                self.by_world.setdefault(pet["world"], []).append(pet["id"])
            else:
                self.base_by_rarity.setdefault(pet["rarityIndex"], []).append(pet["id"])
        self.shop = {item["Id"]: item for item in cfg["Shop"]}
        self.round = cfg["Durations"]["Feeding"] + cfg["Durations"]["Digesting"]

    # --- revenu, prix
    def income(self, pet_id: str) -> float:
        return self.incomes[pet_id]

    def rarity_of(self, pet_id: str) -> int:
        return self.pets[pet_id.split("__")[0]]["rarityIndex"]

    # --- capsule d'évolution (shared/EggIncubation)
    def max_stage_weights(self, tier: int) -> list[float]:
        evo = self.cfg["Evolution"]
        weights = list(evo["MaxStageWeights"])
        shift = min(weights[0], evo["UltimeWeightPerTier"] * (max(1, tier) - 1))
        weights[0] -= shift
        weights[-1] += shift
        return weights

    def stage_chance(self, stage: int, tier: int) -> float:
        weights = self.max_stage_weights(tier)
        above = sum(w for i, w in enumerate(weights, 1) if i > stage)
        start = sum(w for i, w in enumerate(weights, 1) if i >= stage)
        return above / start if start > 0 else 0.0

    def evolve_delay(self, rarity_id: str, stage: int, roll: float, tier: int) -> float:
        evo = self.cfg["Evolution"]
        factor = evo["StageTimeFactor"][min(stage, len(evo["StageTimeFactor"])) - 1]
        jitter = 1 + (roll * 2 - 1) * evo["TimeJitter"]
        speed = 1 - evo["SpeedPerTier"] * (max(1, tier) - 1)
        return self.cfg["Eggs"]["Seconds"][rarity_id] * factor * jitter * max(0.2, speed)

    def world(self, tier: int) -> dict:
        return self.worlds[max(1, min(len(self.worlds), int(tier))) - 1]

    def upgrade_price(self, item_id: str, level: int) -> float | None:
        item = self.shop[item_id]
        if level >= item["MaxLevel"]:
            return None
        return math.floor(item["BasePrice"] * item["PriceGrowth"] ** level)

    def rebirth_price(self, n: int, growth: float | None = None) -> float:
        """Prix du Rebirth n+1. growth (proposé, étape 4) : prix = base x (n + 1) x growth^n ; sinon Config (base x PriceGrowth^n)."""
        rb = self.cfg["Rebirth"]
        if growth:
            return rb["BasePrice"] * (n + 1) * growth ** n
        return rb["BasePrice"] * rb["PriceGrowth"] ** n

    def rebirth_mult(self, n: int) -> float:
        return 1 + self.cfg["Rebirth"]["IncomeBonus"] * n

    def income_slots(self, n: int) -> int:
        rb = self.cfg["Rebirth"]
        return self.cfg["Pets"]["IncomeSlots"] + min(n * rb["ExtraPets"], rb["MaxExtraPets"])

    def index_reward(self, pet_id: str) -> float:
        idx = self.cfg["Index"]
        return max(idx["MinReward"], math.floor(self.income(pet_id) * idx["RewardSeconds"]))

    # --- objets et tirages (server/ItemSpawner, shared/LootEngine)
    def item_value(self, quality: int) -> float:
        boost = 1 + quality * self.cfg["Items"]["QualityBoost"]
        total = value = 0.0
        for index, tier in enumerate(self.cfg["ItemTiers"]):
            weight = tier["Weight"] * boost ** index
            total += weight
            value += weight * tier["Value"]
        return value / total

    def gauge_per_item(self, quality: int) -> float:
        """Jauge du trou noir apportée par un objet en moyenne : BlackholeTiers.OnScored ajoute max(1, valeur)."""
        boost = 1 + quality * self.cfg["Items"]["QualityBoost"]
        total = value = 0.0
        for index, tier in enumerate(self.cfg["ItemTiers"]):
            weight = tier["Weight"] * boost ** index
            total += weight
            value += weight * max(1.0, tier["Value"])
        return value / total

    def count_pulls(self, score: float) -> int:
        if score <= 0:
            return 0
        loot = self.cfg["Loot"]
        pulls, cost, left = 0, loot["PullCost"], score
        while left >= cost:
            left -= cost
            pulls += 1
            cost *= 1 + loot["PullCostGrowth"]
        return max(1, pulls)

    def luck(self, score: float, bonus: float = 0.0) -> float:
        loot = self.cfg["Loot"]
        return min(score * loot["LuckPerPoint"], loot["MaxLuck"]) + bonus

    def rank(self, total_pulls: int) -> int:
        index = 1
        for i, rank in enumerate(self.cfg["Loot"]["Ranks"]):
            if total_pulls >= rank["Pulls"]:
                index = i + 1
        return index

    def floor(self, total_pulls: int, discovered: set) -> int:
        target = self.cfg["Loot"]["Ranks"][self.rank(total_pulls) - 1]["Floor"]
        floor_index = 1
        while floor_index < target:
            if any(pet not in discovered for pet in self.base_by_rarity.get(floor_index, [])):
                return floor_index
            floor_index += 1
        return floor_index

    def rarity_weights(self, luck: float, floor_index: int, tier: int | None) -> list[float]:
        boost = self.world(tier).get("RarityBoost", 1) if tier else 1
        weights = [(r["Weight"] if i == 0 else r["Weight"] * (1 + luck)) * boost ** i for i, r in enumerate(self.rarities)]
        for index in range(min(floor_index, len(weights)) - 1):
            weights[floor_index - 1] += weights[index]
            weights[index] = 0.0
        return weights

    def roll_rarity(self, rng: random.Random, luck: float, min_index: int, floor_index: int, tier: int | None) -> int:
        weights = self.rarity_weights(luck, floor_index, tier)
        for index in range(min_index - 1):
            weights[index] = 0.0
        roll = rng.random() * sum(weights)
        for index, weight in enumerate(weights):
            roll -= weight
            if roll <= 0 and weight > 0:
                return index + 1
        return len(self.rarities)

    def pool(self, rarity: int, world_id: str | None) -> list[str]:
        pool = list(self.base_by_rarity.get(rarity, []))
        if world_id:
            pool += [p for p in self.by_world.get(world_id, []) if self.pets[p]["rarityIndex"] == rarity]
        return pool

    def pick_pet(self, rng: random.Random, rarity: int, owned: dict, world_id: str | None) -> str:
        new_weight = self.cfg["Loot"]["NewPetWeight"]
        for index in range(rarity, 0, -1):
            bucket = self.pool(index, world_id)
            if bucket:
                weights = [1 if owned.get(p, 0) > 0 else new_weight for p in bucket]
                roll = rng.random() * sum(weights)
                for pet, weight in zip(bucket, weights):
                    roll -= weight
                    if roll <= 0:
                        return pet
                return bucket[-1]
        return next(iter(self.pets))

    def roll_pulls(self, rng, pulls, pity, luck, owned, floor_index, tier, world_id, frontier=None):
        """frontier = (rareté, seuil, compteur) : pitié par palier (proposée à l'étape 4) ; au seuil-ième tirage sans cette
        rareté ou mieux, elle est garantie. Renvoie (tirages, pitié, compteur, garanties du palier, garanties actuelles)."""
        loot = self.cfg["Loot"]
        have = dict(owned)
        drops = []
        count = frontier[2] if frontier else 0
        forced = old_hits = 0
        for _ in range(pulls):
            pity += 1
            count += 1
            min_index = 1
            if "PityPulls" in loot and pity >= loot["PityPulls"]:  # pitié d'avant le 25 oct. (Épique au 60e tirage)
                min_index = loot["PityMinRarity"]
                old_hits += 1
            if frontier and count >= frontier[1]:
                min_index = max(min_index, frontier[0])
                forced += 1
            rarity = self.roll_rarity(rng, luck, min_index, floor_index, tier)
            if "PityPulls" in loot and rarity >= loot["PityMinRarity"]:
                pity = 0
            if frontier and rarity >= frontier[0]:
                count = 0
            pet = self.pick_pet(rng, rarity, have, world_id)
            have[pet] = have.get(pet, 0) + 1
            drops.append(pet)
        return drops, pity, count, forced, old_hits

    def base_species(self) -> list[str]:
        return [p for bucket in self.base_by_rarity.values() for p in bucket]

    def chance_at_least(self, rarity: int, luck: float, floor_index: int, tier: int) -> float:
        weights = self.rarity_weights(luck, floor_index, tier)
        return sum(weights[rarity - 1:]) / sum(weights)

    def frontier_threshold(self, rarity: int, luck: float, floor_index: int, tier: int, percentile: float | None = None) -> int:
        """Tirages après lesquels seuls (1 - percentile) des joueurs n'ont toujours pas cette rareté (loi géométrique)."""
        if percentile is None:
            percentile = self.cfg["Loot"].get("PityPercentile", 0.9)
        p = self.chance_at_least(rarity, luck, floor_index, tier)
        return max(1, math.ceil(math.log(1 - percentile) / math.log(1 - p))) if 0 < p < 1 else 1


# Hypothèses de jeu de tools/sim-economy.luau (un joueur seul, toujours présent).
HOLE = {"Items": 16, "PerBackpack": 3, "PerMagnet": 2, "PerTraining": 0.15, "MaxItems": 38, "Bonus": 1.3}
UPGRADES = ["Treadmill", "Bench", "ItemQuality", "Backpack", "Magnet"]
CHECKPOINTS = [600, 1800, 3600, 7200, 18000, 36000, 72000, 144000]


class SoloRun:
    """Une partie d'un joueur seul : port de tools/sim-economy.luau, manche après manche."""

    def __init__(self, game: Game, rng: random.Random, fusion: bool = True, capsule: bool = True, options: dict | None = None):
        g = self.g = game
        self.rng = rng
        self.fusion = fusion
        self.use_capsule = capsule
        # Règles proposées (pas dans Config.lua) : "pitie_palier", "capsules_rebirth", "doublons_capsule",
        # "rebirth_croissance" (étape 4), "plafond" (règle 2). "record" = False : pas d'historique (serveur, plus rapide).
        self.options = options or {}
        self.capsules: list[dict] = []  # œufs dans les capsules d'évolution (Config.Evolution.Slots places)
        self.frontier_count = 0
        self.forced = 0  # garanties données par la pitié par palier
        self.old_pity_hits = 0  # garanties données par la pitié actuelle (Épique+ au 60e tirage)
        self.gauge: dict[int, float] = {}  # point de contrôle -> jauge du trou noir apportée en une manche
        self.discovered_at: dict[int, int] = {}
        self.scores_by_tier: dict[int, list[tuple[float, int]]] = {}  # avant le 1er Rebirth : (points, tirages) par manche
        start = g.cfg["Newcomer"]["PetId"]
        self.t = 0.0
        self.money = float(g.cfg["Newcomer"]["BonusMoney"])
        self.tier, self.rebirths = 1, 0
        self.up: dict[str, int] = {}
        self.pets: dict[str, int] = {start: 1}
        self.eggs: list[tuple[str, float]] = []
        self.discovered = {start}
        self.claimed: set[str] = set()
        self.pity = 0
        self.total_pulls = 0
        self.events: dict[str, float] = {}
        self.income_at: dict[int, float] = {}
        self.round_stats: dict[int, tuple[float, int]] = {}
        self.sources: dict[str, float] = {}
        # (t, revenu/s, monde, rebirths, dépenses Boutique cumulées, meilleure rareté possédée)
        self.trace: list[tuple[float, float, int, int, float, int]] = []
        self.spent_shop = 0.0
        self.purchases: list[tuple[float, str, int, float, float]] = []  # (t, objet, niveau, prix, revenu/s)
        self.income_now = 0.0
        self.snapshots: dict[int, tuple[list[str], float, int, int]] = {}  # point de contrôle -> (base, revenu/s, monde, rebirths)
        self.self_best = g.rarity_of(start)  # meilleure rareté obtenue soi-même (tirages, fusion, capsule) : règle 2
        self.record = self.options.get("record", True)

    def eff_income(self, pet: str) -> float:
        """Revenu d'un familier pour ce joueur ; règle 2 : au plus le revenu de base de la rareté self_best + 2."""
        value = self.g.income(pet)
        top = self.self_best + self.options.get("plafond_ecart", 2)
        if self.options.get("plafond") and top <= len(self.g.rarities):
            value = min(value, self.g.rarities[top - 1]["Income"])
        return value

    def receive_pet(self, pet: str):
        """Familier volé : il arrive tout de suite dans la collection, sans compter comme obtenu soi-même."""
        self.pets[pet] = self.pets.get(pet, 0) + 1

    def lose_pet(self, pet: str):
        self.pets[pet] -= 1

    def earn(self, source: str, amount: float):
        self.money += amount
        if self.rebirths == 0:
            self.sources[source] = self.sources.get(source, 0.0) + amount

    def mark(self, name: str):
        self.events.setdefault(name, self.t)

    def layout(self):
        g = self.g
        slots = g.income_slots(self.rebirths)
        species = sorted((p for p, c in self.pets.items() if c > 0), key=self.eff_income, reverse=True)
        base, used = [], {}
        for pet in species:
            if len(base) < slots:
                base.append(pet)
                used[pet] = 1
        for pet in species:
            while len(base) < slots and used.get(pet, 0) < self.pets[pet]:
                base.append(pet)
                used[pet] = used.get(pet, 0) + 1
        reserve, equipped, best = {}, None, 0.0
        for pet, count in self.pets.items():
            spare = count - used.get(pet, 0)
            if spare > 0:
                reserve[pet] = spare
                mult = g.rarities[g.rarity_of(pet) - 1]["Multiplier"]
                if mult > best:
                    equipped, best = pet, mult
        if equipped:
            reserve[equipped] -= 1
        return base, equipped, reserve

    def per_second(self, base) -> float:
        g = self.g
        return sum(self.eff_income(p) for p in base) * g.world(self.tier)["IncomeMultiplier"] * g.rebirth_mult(self.rebirths)

    def shop(self):
        g = self.g
        bought = True
        while bought:
            bought = False
            next_world = g.worlds[self.tier] if self.tier < len(g.worlds) else None
            if next_world and self.money >= next_world["Price"]:
                self.money -= next_world["Price"]
                self.tier += 1
                self.purchases.append((self.t, "Monde", self.tier, next_world["Price"], self.income_now))
                self.mark(f"Monde {self.tier} {next_world['Id']}")
                bought = True
            elif not next_world and self.tier >= g.cfg["Rebirth"]["RequiredTier"] and self.money >= g.rebirth_price(self.rebirths, self.options.get("rebirth_croissance")):
                self.rebirths += 1
                self.money, self.tier, self.up = 0.0, 1, {}
                self.mark(f"Rebirth {self.rebirths}")
                bought = True
            else:
                cheapest, price = None, math.inf
                for item in UPGRADES:
                    cost = g.upgrade_price(item, self.up.get(item, 0))
                    if cost is not None and cost < price:
                        cheapest, price = item, cost
                goal = next_world["Price"] if next_world else g.rebirth_price(self.rebirths, self.options.get("rebirth_croissance"))
                if cheapest and price <= 0.3 * self.money and price <= 0.15 * goal:
                    self.money -= price
                    self.spent_shop += price
                    self.up[cheapest] = self.up.get(cheapest, 0) + 1
                    level = self.up[cheapest]
                    self.purchases.append((self.t, cheapest, level, price, self.income_now))
                    if level == g.shop[cheapest]["MaxLevel"]:
                        self.mark(f"{cheapest} max")
                    if cheapest == "Treadmill" and level % 5 == 0:
                        self.mark(f"Tapis niveau {level}")
                    bought = True

    def owned_with_eggs(self) -> dict:
        owned = dict(self.pets)
        for pet, _ in self.eggs:
            owned[pet] = owned.get(pet, 0) + 1
        for cap in self.capsules:
            owned[cap["pet"]] = owned.get(cap["pet"], 0) + 1
        return owned

    def capsule_slots(self) -> int:
        extra = min(self.rebirths, self.g.cfg["Rebirth"]["MaxExtraPets"]) if self.options.get("capsules_rebirth") else 0
        return self.g.cfg["Evolution"]["Slots"] + extra

    def tick_capsule(self):
        """Le joueur y met ses meilleurs œufs, laisse les tentatives se faire, ouvre dès qu'un œuf n'évoluera plus."""
        g = self.g
        while len(self.capsules) < self.capsule_slots() and self.eggs:
            egg = max(self.eggs, key=lambda e: g.income(e[0]))
            if self.options.get("doublons_capsule") and self.pets:
                # Joueur malin : il garde ses capsules pour sa meilleure rareté (les doublons y arrivent, voir step).
                best = max(g.rarity_of(p) for p, c in self.pets.items() if c > 0)
                if g.rarity_of(egg[0]) < best:
                    break
            self.eggs.remove(egg)
            rarity = g.pets[egg[0]]["rarity"]
            self.capsules.append({"pet": egg[0], "ready": egg[1], "stage": 1, "done": False,
                                  "next": max(self.t, egg[1]) + g.evolve_delay(rarity, 1, self.rng.random(), self.tier)})
        for cap in list(self.capsules):
            while not cap["done"] and self.t >= cap["next"]:
                if self.rng.random() < g.stage_chance(cap["stage"], self.tier):
                    cap["stage"] += 1
                    if cap["stage"] >= len(g.cfg["Evolution"]["Names"]):
                        cap["done"] = True
                    else:
                        cap["next"] += g.evolve_delay(g.pets[cap["pet"]]["rarity"], cap["stage"], self.rng.random(), self.tier)
                else:
                    cap["done"] = True
            if cap["done"] and self.t >= cap["ready"]:
                form = cap["pet"] if cap["stage"] == 1 else f"{cap['pet']}__E{cap['stage']}"
                self.pets[form] = self.pets.get(form, 0) + 1
                self.self_best = max(self.self_best, g.rarity_of(form))
                if cap["stage"] > 1:
                    self.mark(f"1er {g.cfg['Evolution']['Names'][cap['stage'] - 1]}")
                self.capsules.remove(cap)

    def step(self, next_check: int) -> int:
        g, cfg = self.g, self.g.cfg
        for egg in [e for e in self.eggs if e[1] <= self.t]:
            self.eggs.remove(egg)
            pet = egg[0]
            self.pets[pet] = self.pets.get(pet, 0) + 1
            self.self_best = max(self.self_best, g.rarity_of(pet))
            if pet not in self.claimed:
                self.claimed.add(pet)
                self.earn("Index", g.index_reward(pet))
        if self.use_capsule:
            self.tick_capsule()
        self.shop()
        base, equipped, reserve = self.layout()
        income = self.income_now = self.per_second(base)
        if self.record:
            best = max(g.rarity_of(p) for p, c in self.pets.items() if c > 0)
            self.trace.append((self.t, income, self.tier, self.rebirths, self.spent_shop, best))
        checkpoint = None
        while next_check < len(CHECKPOINTS) and self.t >= CHECKPOINTS[next_check]:
            self.income_at[CHECKPOINTS[next_check]] = income
            self.snapshots[CHECKPOINTS[next_check]] = (list(base), income, self.tier, self.rebirths)
            self.discovered_at[CHECKPOINTS[next_check]] = len(self.discovered)
            checkpoint = CHECKPOINTS[next_check]
            next_check += 1

        fusion = cfg["Fusion"]
        for rarity in range(1, fusion["MaxFromRarity"] + 1 if self.fusion else 1):
            pool = [p for p, c in reserve.items() if g.rarity_of(p) == rarity for _ in range(c)]
            cost = fusion["Costs"][rarity - 1]
            while len(pool) >= fusion["Count"] and self.money * 0.5 >= cost:
                self.money -= cost
                for _ in range(fusion["Count"]):
                    self.pets[pool.pop()] -= 1
                result = g.pick_pet(self.rng, rarity + 1, self.owned_with_eggs(), None)
                self.eggs.append((result, self.t + cfg["Eggs"]["Seconds"][g.rarities[rarity]["Id"]]))

        up = self.up
        items = min(HOLE["Items"] + HOLE["PerBackpack"] * up.get("Backpack", 0) + HOLE["PerMagnet"] * up.get("Magnet", 0)
                    + HOLE["PerTraining"] * (up.get("Treadmill", 0) + up.get("Bench", 0)), HOLE["MaxItems"])
        mult = g.rarities[g.rarity_of(equipped) - 1]["Multiplier"] if equipped else 1
        score = math.floor(items * g.item_value(up.get("ItemQuality", 0)) * mult * HOLE["Bonus"] * 10) / 10
        pulls = g.count_pulls(score)
        if checkpoint:
            self.round_stats[checkpoint] = (score, pulls)
            # Jauge commune du trou noir : max(1, valeur) par objet avalé, sans multiplicateur (server/BlackholeTiers).
            self.gauge[checkpoint] = items * g.gauge_per_item(up.get("ItemQuality", 0))
        owned = self.owned_with_eggs()
        floor_index = g.floor(self.total_pulls, self.discovered)
        luck = g.luck(score)
        if self.rebirths == 0:
            self.scores_by_tier.setdefault(self.tier, []).append((score, pulls))
        frontier = None
        target = max(g.rarity_of(p) for p in owned) + 1
        # Pitié par palier : règle du jeu depuis le 25 oct. (Config.Loot.PityPercentile), ou forcée par l'option.
        if (self.options.get("pitie_palier") or "PityPercentile" in cfg["Loot"]) and target <= len(g.rarities):
            frontier = (target, g.frontier_threshold(target, luck, floor_index, self.tier), self.frontier_count)
        drops, self.pity, self.frontier_count, forced, old_hits = g.roll_pulls(
            self.rng, pulls, self.pity, luck, owned, floor_index, self.tier, g.world(self.tier)["Id"], frontier)
        self.forced += forced
        self.old_pity_hits += old_hits
        self.total_pulls += pulls
        world = g.world(self.tier)
        for pet in drops:
            self.discovered.add(pet)
            free = self.use_capsule and len(self.capsules) < self.capsule_slots()
            if owned.get(pet, 0) >= cfg["Loot"]["KeepCopies"] and self.options.get("doublons_capsule") and free \
                    and g.rarity_of(pet) >= max(g.rarity_of(p) for p in base):
                # Doublon de sa meilleure rareté : il part dans une capsule libre au lieu d'être vendu.
                ready = self.t + cfg["Eggs"]["Seconds"][g.pets[pet]["rarity"]]
                self.capsules.append({"pet": pet, "ready": ready, "stage": 1, "done": False,
                                      "next": ready + g.evolve_delay(g.pets[pet]["rarity"], 1, self.rng.random(), self.tier)})
            elif owned.get(pet, 0) >= cfg["Loot"]["KeepCopies"]:
                self.earn("Doublons vendus", g.income(pet) * cfg["Loot"]["SellSeconds"] * world["IncomeMultiplier"])
            else:
                owned[pet] = owned.get(pet, 0) + 1
                self.eggs.append((pet, self.t + cfg["Eggs"]["Seconds"][g.pets[pet]["rarity"]]))
                if g.rarity_of(pet) >= 4:  # Épique et plus
                    self.mark(f"1er {g.pets[pet]['rarity']}")
        if not self.events.get("Index : les 75 de base") and all(p in self.discovered for p in g.base_species()):
            self.mark("Index : les 75 de base")
        if len(self.discovered) >= len(g.pets):
            self.mark("Index complet (106)")
        self.earn("Points du trou", score * max(cfg["Economy"]["MoneyPerPoint"], income * cfg["Economy"]["IncomeSecondsPerPoint"]))
        self.earn("Revenu des familiers", income * g.round)
        self.t += g.round
        return next_check

    def play(self, hours: float):
        next_check = 0
        for _ in range(int(hours * 3600 // self.g.round)):
            next_check = self.step(next_check)
        return self


# ----------------------------------------------------------------------------------------------------------------
# Sorties


def duration(seconds):
    if seconds is None:
        return "   jamais"
    return f"{seconds / 60:6.0f} min" if seconds < 3600 else f"{seconds / 3600:6.1f} h  "


def short(n: float) -> str:
    units = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx"]
    i = 0
    while n >= 1000 and i < len(units) - 1:
        n /= 1000
        i += 1
    return f"{n:.3g}{units[i]}"


def pct(values: list, p: float, runs: int):
    """Percentile façon tools/sim-economy.luau : les parties qui n'ont pas atteint l'étape comptent comme « jamais »."""
    ordered = sorted(values)
    index = math.ceil(p * runs)
    return ordered[index - 1] if 0 < index <= len(ordered) else None


def run_many(game: Game, runs: int, hours: float, seed: int = 1234, fusion: bool = True, capsule: bool = True,
             options: dict | None = None) -> list[SoloRun]:
    rng = random.Random(seed)
    return [SoloRun(game, random.Random(rng.random()), fusion, capsule, options).play(hours) for _ in range(runs)]


def report_solo(results: list[SoloRun], runs: int, hours: float, game: Game):
    events: dict[str, list[float]] = {}
    for run in results:
        for name, at in run.events.items():
            events.setdefault(name, []).append(at)
    rows = sorted(events.items(), key=lambda kv: pct(kv[1], 0.5, runs) or math.inf)
    print(f"Simulation : {runs} parties de {hours:g} h de jeu (manche de {game.round:g} s).")
    print(f"{'Étape':26s} {'chanceux':>11s} {'moyen':>11s} {'malchanceux':>11s} {'atteinte':>8s}")
    for name, values in rows:
        print(f"{name:26s} {duration(pct(values, 0.1, runs)):>11s} {duration(pct(values, 0.5, runs)):>11s} "
              f"{duration(pct(values, 0.9, runs)):>11s} {len(values) / runs * 100:7.0f}%")
    print("\nRevenu par seconde (moyen) :")
    for checkpoint in CHECKPOINTS:
        incomes = [r.income_at[checkpoint] for r in results if checkpoint in r.income_at]
        if not incomes:
            continue
        stats = [r.round_stats[checkpoint] for r in results if checkpoint in r.round_stats]
        print(f"  après {duration(checkpoint)} : {short(pct(incomes, 0.5, len(incomes)))}/s   (une manche : "
              f"{short(pct([s[0] for s in stats], 0.5, len(stats)))} points, {pct([s[1] for s in stats], 0.5, len(stats))} tirages)")
    totals: dict[str, float] = {}
    for run in results:
        for source, amount in run.sources.items():
            totals[source] = totals.get(source, 0.0) + amount
    grand = sum(totals.values()) or 1
    print("\nD'où vient l'argent avant le 1er Rebirth :")
    for source, amount in sorted(totals.items()):
        print(f"  {source:22s} {amount / grand * 100:5.1f} %")


def segments_of(run: SoloRun) -> list[dict]:
    """Découpe une partie en séjours dans un monde (Rebirth n, monde k) et mesure la dent de scie de chacun."""
    out, current = [], None
    for t, income, tier, rebirths, spent, _ in run.trace:
        key = (rebirths, tier)
        if current is None or current["key"] != key:
            if current:
                out.append(current)
            current = {"key": key, "t0": t, "points": [], "spent0": spent}
        current["points"].append((t, income, spent))
    if current:
        out.append(current)
    segments = []
    for seg in out[:-1]:  # le dernier séjour n'est pas fini
        points = seg["points"]
        t0, t1 = points[0][0], points[-1][0] + run.g.round
        i0, i1 = points[0][1], points[-1][1]
        span = math.log(i1 / i0) if i0 > 0 and i1 > i0 else 0.0

        def first_time(frac):
            for t, income, _ in points:
                if span == 0 or math.log(max(income, 1e-9) / i0) >= frac * span:
                    return t
            return t1
        t90 = first_time(0.9)
        segments.append({"key": seg["key"], "length": t1 - t0, "growth": i1 / i0 if i0 > 0 else math.inf,
                         "t50": (first_time(0.5) - t0) / (t1 - t0), "plateau": (t1 - t90) / (t1 - t0),
                         "shop_share": (points[-1][2] - seg["spent0"]), "income_end": i1})
    return segments


def report_segments(results: list[SoloRun], game: Game):
    by_key: dict[tuple, list[dict]] = {}
    for run in results:
        for seg in segments_of(run):
            by_key.setdefault(seg["key"], []).append(seg)
    print("Séjour dans chaque monde (médianes) : durée, revenu x pendant le séjour, moment où la moitié de la montée est")
    print("faite (en % du séjour), part du séjour passée sur le plateau (après 90 % de la montée), revenu à la sortie.")
    print(f"{'Rebirth/monde':22s} {'durée':>10s} {'revenu x':>9s} {'mi-montée':>10s} {'plateau':>8s} {'revenu sortie':>14s}")
    for key in sorted(by_key):
        segs = by_key[key]
        n = len(segs)
        med = lambda field: pct([s[field] for s in segs], 0.5, n)
        name = f"R{key[0]} {game.world(key[1])['Id']}"
        print(f"{name:22s} {duration(med('length')):>10s} {med('growth'):9.3g} {med('t50') * 100:9.0f}% "
              f"{med('plateau') * 100:7.0f}% {short(med('income_end')):>14s}")


def report_walls(results: list[SoloRun], game: Game):
    """Avant le 1er Rebirth : meilleure rareté possédée en quittant chaque monde, prix ressenti des achats."""
    names = [r["Id"] for r in game.rarities]
    print("\nMeilleure rareté possédée en quittant chaque monde (avant le 1er Rebirth) : médiane / 90 % des parties / max")
    for tier in range(1, len(game.worlds) + 1):
        best = []
        for run in results:
            exits = [b for t, _, k, n, _, b in run.trace if n == 0 and k == tier]
            if exits:
                best.append(exits[-1])
        if best:
            best.sort()
            print(f"  {game.world(tier)['Id']:8s} {names[best[len(best) // 2] - 1]:11s} {names[best[int(len(best) * 0.9) - 1] - 1]:11s} "
                  f"{names[best[-1] - 1]}")
    print("\nPrix des achats en minutes du revenu du moment (avant le 1er Rebirth, médiane par objet) :")
    rows: dict[str, list[tuple[int, float]]] = {}
    for run in results:
        for t, item, level, price, income in run.purchases:
            if run.events.get("Rebirth 1", math.inf) > t and income > 0:
                rows.setdefault(item, []).append((level, price / income / 60))
    for item, values in rows.items():
        minutes = sorted(v for _, v in values)
        early = sorted(v for lv, v in values if lv <= 5)
        late = sorted(v for lv, v in values if lv > max(lv2 for lv2, _ in values) - 5)
        print(f"  {item:12s} tous {minutes[len(minutes) // 2]:7.2f} min | 5 premiers niveaux {early[len(early) // 2]:7.2f} min"
              f" | 5 derniers {late[len(late) // 2]:7.2f} min")


def steal_gain(game: Game, thief: tuple, pet: str, cap: bool) -> float:
    """Gain de revenu du voleur s'il ajoute `pet` à sa base (à la place de son moins bon), divisé par son revenu.
    cap : règle 2 de l'étape 2 : un familier rapporte au plus le revenu de base de la rareté r + 2 (Config.Rarities,
    r = meilleure rareté du voleur), formes évoluées et mutées comprises. Pas de plafond quand r + 2 dépasse le Sigma."""
    base, income, tier, rebirths = thief
    value = game.income(pet)
    top = max(game.rarity_of(p) for p in base) + 2
    if cap and top <= len(game.rarities):
        value = min(value, game.rarities[top - 1]["Income"])
    low = min(game.income(p) for p in base) if len(base) >= game.income_slots(rebirths) else 0.0
    gain = max(0.0, value - low) * game.world(tier)["IncomeMultiplier"] * game.rebirth_mult(rebirths)
    return gain / income if income > 0 else 0.0


def report_targets(results: list[SoloRun], game: Game):
    """Qui a intérêt à voler qui : pour un voleur et une victime à deux moments de la partie, part des familiers de la
    victime qui feraient monter le revenu du voleur (« vol utile »), et gain du meilleur vol, sans et avec plafond."""
    points = [600, 1800, 3600, 7200, 18000, 36000]
    rng = random.Random(5)
    print("Qui a intérêt à voler qui (médianes sur des paires de parties) :")
    print("  case = part des familiers de la victime utiles au voleur / gain du meilleur vol sans plafond / avec plafond")
    print(f"{'voleur / victime':>16s} " + " ".join(f"{duration(p):>24s}" for p in points))
    for a in points:
        row = []
        for b in points:
            useful, best_raw, best_cap = [], [], []
            for _ in range(60):
                thief = rng.choice(results).snapshots.get(a)
                victim = rng.choice(results).snapshots.get(b)
                if not thief or not victim:
                    continue
                gains = [steal_gain(game, thief, p, False) for p in victim[0]]
                capped = [steal_gain(game, thief, p, True) for p in victim[0]]
                useful.append(sum(1 for x in capped if x > 0) / len(victim[0]))
                best_raw.append(max(gains))
                best_cap.append(max(capped))
            cell = (f"{pct(useful, 0.5, len(useful)) * 100:3.0f}% x{pct(best_raw, 0.5, len(best_raw)):.2g}"
                    f"/x{pct(best_cap, 0.5, len(best_cap)):.2g}") if useful else "-"
            row.append(f"{cell:>24s}")
        print(f"{duration(a):>16s} " + " ".join(row))


def report_retention(game: Game, runs: int, hours: float):
    """Étape 4 : pitié calibrée sur l'espérance des tirages, cadence de la jauge du trou noir, avancée de l'Index."""
    base = run_many(game, runs, hours)
    pity = run_many(game, runs, hours, options={"pitie_palier": True})
    names = [r["Id"] for r in game.rarities]
    print("Chances par tirage (avant le 1er Rebirth) : chance typique du monde (points médians x 0,005), tirages par heure,")
    print("et pour chaque rareté : tirages pour en avoir une avec 1 chance sur 2 / 9 chances sur 10 (loi géométrique).")
    for tier in range(1, len(game.worlds) + 1):
        rounds = [x for run in base for x in run.scores_by_tier.get(tier, [])]
        if not rounds:
            continue
        score = pct([r[0] for r in rounds], 0.5, len(rounds))
        per_hour = sum(r[1] for r in rounds) / len(rounds) * 3600 / game.round
        luck = game.luck(score)
        cells = []
        for rarity in range(4, len(game.rarities) + 1):
            p = game.chance_at_least(rarity, luck, 1, tier)
            n50 = math.ceil(math.log(0.5) / math.log(1 - p))
            cells.append(f"{names[rarity - 1][:6]} {n50}/{game.frontier_threshold(rarity, luck, 1, tier)}")
        print(f"  {game.world(tier)['Id']:8s} chance {luck:4.2f}, {per_hour:5.0f} tirages/h : " + " | ".join(cells))

    for label, results in (("pitié actuelle", base), ("+ pitié par palier", pity)):
        old = sum(r.old_pity_hits for r in results) / len(results)
        forced = sum(r.forced for r in results) / len(results)
        print(f"\n{label} : garanties « Épique+ au 60e tirage » {old:.2f} par partie de {hours:g} h ; garanties du palier {forced:.1f}")
        for name in ["1er Legendaire", "1er Mythique", "1er Divin", "1er Sigma", "Monde 7 Divin", "Rebirth 1"]:
            values = [r.events[name] for r in results if name in r.events]
            if values:
                print(f"  {name:16s} médiane {duration(pct(values, 0.5, len(results)))}  9 sur 10 {duration(pct(values, 0.9, len(results)))}"
                      f"  99 sur 100 {duration(pct(values, 0.99, len(results)))}")

    print("\nJauge commune du trou noir (Config.Blackhole) : points de jauge par joueur et par manche, et durée d'un tour complet")
    print("des 7 paliers (jusqu'à l'effondrement) si tous les joueurs du serveur en sont au même point.")
    need = sum(game.cfg["Blackhole"]["GaugeNeed"])
    scaling = game.cfg["Blackhole"]["PlayerScaling"]
    for checkpoint in CHECKPOINTS[:6]:
        values = [r.gauge[checkpoint] for r in base if checkpoint in r.gauge]
        if not values:
            continue
        g1 = pct(values, 0.5, len(values))
        cycle = {n: need * n ** scaling / (n * g1) * game.round / 60 for n in (1, 4, 8)}
        print(f"  après {duration(checkpoint)} : {g1:5.1f} par manche -> tour complet en {cycle[1]:4.0f} min seul, "
              f"{cycle[4]:3.0f} min à 4, {cycle[8]:3.0f} min à 8")

    print(f"\nIndex (familiers découverts sur {len(game.pets)}, dont {len(game.base_species())} de base) :")
    for checkpoint in CHECKPOINTS[:7]:
        values = [r.discovered_at[checkpoint] for r in base if checkpoint in r.discovered_at]
        if values:
            print(f"  après {duration(checkpoint)} : {pct(values, 0.5, len(values))}")
    for name in ["Index : les 75 de base", "Index complet (106)"]:
        values = [r.events[name] for r in base if name in r.events]
        print(f"  {name:24s} médiane {duration(pct(values, 0.5, len(base)))}, atteint dans {len(values) / len(base) * 100:.0f} % des parties")


def report_server(game: Game, servers: int, hours: float, grapple_hit: float, cap_offset: int):
    sys.path.insert(0, str(Path(__file__).resolve().parent))  # python -I n'ajoute pas le dossier du script
    import economy_server  # même dossier ; importé ici pour éviter une importation circulaire
    economy_server.run_scenarios(game, servers, hours, {"grapple_hit": grapple_hit, "cap_offset": cap_offset})


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("mode", choices=["solo", "segments", "cibles", "retention", "serveur", "balayage"])
    parser.add_argument("--servers", type=int, default=40, help="serveur : nombre de serveurs simulés par scénario")
    parser.add_argument("--grappin", type=float, default=0.6, help="serveur : chance qu'un tir de grappin touche (règle 6)")
    parser.add_argument("--plafond-ecart", type=int, default=2, help="serveur : écart de rareté du plafond (règle 2)")
    parser.add_argument("--second", action="store_true", help="balayage : second balayage (bouclier sur 1 h, duo)")
    parser.add_argument("--runs", type=int, default=200)
    parser.add_argument("--hours", type=float, default=30)
    parser.add_argument("--no-refresh", action="store_true", help="ne pas relire les valeurs du jeu avec Lune")
    parser.add_argument("--no-capsule", action="store_true", help="sans capsule d'évolution (comme tools/sim-economy.luau)")
    parser.add_argument("--pitie-palier", action="store_true", help="règle proposée : pitié par palier (étape 4)")
    parser.add_argument("--capsules-rebirth", action="store_true", help="règle proposée : une capsule de plus par Rebirth")
    parser.add_argument("--doublons-capsule", action="store_true", help="règle proposée : un doublon va dans une capsule libre")
    parser.add_argument("--rebirth-croissance", type=float, default=None,
                        help="règle proposée : prix du Rebirth n+1 = base x (n + 1) x valeur^n (étape 4 : 1,62)")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    game = Game(load_data(refresh=not args.no_refresh))
    if args.mode == "retention":
        report_retention(game, args.runs, args.hours)
        return
    if args.mode == "serveur":
        report_server(game, args.servers, args.hours, args.grappin, args.plafond_ecart)
        return
    if args.mode == "balayage":
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import economy_server
        (economy_server.sweep2 if args.second else economy_server.sweep)(game, args.servers, args.hours)
        return
    options = {"pitie_palier": args.pitie_palier, "capsules_rebirth": args.capsules_rebirth,
               "doublons_capsule": args.doublons_capsule, "rebirth_croissance": args.rebirth_croissance}
    results = run_many(game, args.runs, args.hours, capsule=not args.no_capsule, options=options)
    if args.mode == "solo":
        report_solo(results, args.runs, args.hours, game)
    elif args.mode == "cibles":
        report_targets(results, game)
    else:
        report_segments(results, game)
        report_walls(results, game)


if __name__ == "__main__":
    main()
