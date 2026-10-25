"""Mesures de la carte pour l'audit économique (ECONOMY_REPORT.md, étape 1).

Lit les constantes dans src/shared/Config.lua (jamais recopiées à la main), refait la géométrie de
server/MapGenerator.lua et shared/BaseLayout.lua, puis calcule :
  - les distances utiles (base -> trou, base -> bases voisines, zone de sacrifice) ;
  - la portée de lancer selon la Force et ce qu'il reste à marcher ;
  - la vitesse de transport d'un familier selon sa rareté et la Force (formule de Config.Carry) ;
  - les temps de trajet d'un voleur et l'issue d'une poursuite (la victime le rattrape-t-elle ?) ;
  - le rendement d'une manche pour un débutant (objets lancés, points, tirages).

    python -I dataset_and_pipeline/economy_map_metrics.py

Hypothèses (à vérifier en jeu) : clôtures de 4 studs enjambées (bases ouvertes, décision du 25 oct.), trajets en
ligne droite, gravité Roblox 196,2, la victime est prévenue au début du vol (Remotes.StealNotice « Started ») et part
après 1,5 s, « Reprendre » marche à 10 studs (Config.Steal.RecoverPromptDistance), le grappin à 55 studs.
"""
import math
import random
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
CONFIG = (ROOT / "src" / "shared" / "Config.lua").read_text(encoding="utf-8")


def block(name: str) -> str:
    """Texte du tableau `Config.<name> = { ... }` (accolades équilibrées)."""
    start = CONFIG.index(f"Config.{name} = {{")
    depth = 0
    for index in range(start, len(CONFIG)):
        if CONFIG[index] == "{":
            depth += 1
        elif CONFIG[index] == "}":
            depth -= 1
            if depth == 0:
                return CONFIG[start:index + 1]
    raise ValueError(name)


def num(text: str, key: str) -> float:
    match = re.search(rf"\b{key}\s*=\s*([-\d.e]+)", text)
    if not match:
        raise KeyError(key)
    return float(match.group(1))


ARENA, CARRY, STEAL, SAC = block("Arena"), block("Carry"), block("Steal"), block("Sacrifice")
TRAINING, DURATIONS, LOOT, WEAPONS = block("Training"), block("Durations"), block("Loot"), block("Weapons")
RING, HOLE, DOME = num(ARENA, "BaseRingRadius"), num(ARENA, "HoleRadius"), num(ARENA, "DomeRadius")
HALF = float(re.search(r"BaseSize = Vector3.new\((\d+)", ARENA).group(1)) / 2
SAC_RANGE = num(SAC, "Range")
STAT = r"{} = \{{ Base = ([\d.]+), PerLevel = ([\d.]+), MaxLevel = (\d+)"
SPEED_BASE, SPEED_PER, SPEED_MAX = (float(x) for x in re.search(STAT.format("Speed"), TRAINING).groups())
STR_BASE, STR_PER, STR_MAX = (float(x) for x in re.search(STAT.format("Strength"), TRAINING).groups())
EQUIP_MAX = num(block("Pets"), "MaxLevels")
W_EXP, PER_CAP, SLOW = num(CARRY, "WeightExponent"), num(CARRY, "StrengthPerCapacity"), num(CARRY, "Slow")
MIN_SPEED, MAX_SPEED = num(CARRY, "MinSpeed"), num(CARRY, "MaxSpeed")
RECOVER = num(STEAL, "RecoverPromptDistance")
GRAPPLE = float(re.search(r"Grapple = \{\s*Range = ([\d.]+)", WEAPONS).group(1))
FEEDING = num(DURATIONS, "Feeding")
PULL_COST, PULL_GROWTH = num(LOOT, "PullCost"), num(LOOT, "PullCostGrowth")
ITEMS = block("Items")
TIERS = [(float(w), float(v)) for v, w in re.findall(r"Value = ([\d.]+), Weight = ([\d.]+)", block("ItemTiers"))]
MONEY_PER_POINT = num(block("Economy"), "MoneyPerPoint")
G = 196.2
INSIDE_MARGIN = 1.5  # StealController.isInsideBase
REACT = 1.5  # secondes avant que la victime parte

# shared/BaseLayout (coordonnées locales, -Z = entrée côté trou noir)
PET_X, PET_Z = (-(HALF - 9), HALF - 9), (-3 - 19, -3 + 19)
SPAWN, GATE, TREADMILL = (0.0, 6.0), (0.0, -HALF), (-HALF - 10, -4.0)
PALLET = (HALF - 10, -HALF + 10)
BANDS = {"Commun": (0.5, 0.65), "Inhabituel": (0.65, 0.8), "Rare": (0.8, 0.95), "Epique": (0.95, 1.15),
         "Legendaire": (1.15, 1.4), "Mythique": (1.4, 1.7), "Divin": (1.75, 2.15), "Sigma": (2.3, 2.9)}  # shared/PetSizes
WALK = {"départ": SPEED_BASE, "entraîné max": SPEED_BASE + SPEED_PER * SPEED_MAX,
        "max + familier": SPEED_BASE + SPEED_PER * (SPEED_MAX + EQUIP_MAX)}
POWER = {"départ": STR_BASE, "niveau 30": STR_BASE + STR_PER * 30, "entraîné max": STR_BASE + STR_PER * STR_MAX,
         "max + familier": STR_BASE + STR_PER * (STR_MAX + EQUIP_MAX)}


def base_frame(i):
    a = i * 2 * math.pi / 8
    back = (math.cos(a), math.sin(a))
    return (RING * back[0], RING * back[1]), (-back[1], back[0]), back


def to_world(i, p):
    c, r, b = base_frame(i)
    return (c[0] + r[0] * p[0] + b[0] * p[1], c[1] + r[1] * p[0] + b[1] * p[1])


def to_local(i, w):
    c, r, b = base_frame(i)
    d = (w[0] - c[0], w[1] - c[1])
    return (d[0] * r[0] + d[1] * r[1], d[0] * b[0] + d[1] * b[1])


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def nearest_inside(i, w):
    lx, lz = to_local(i, w)
    h = HALF + INSIDE_MARGIN
    return to_world(i, (max(-h, min(h, lx)), max(-h, min(h, lz))))


def path_len(a, b, avoid=DOME):
    """Plus court chemin de a à b sans traverser le dôme (disque de rayon `avoid` au centre)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length2 = dx * dx + dy * dy
    t = max(0.0, min(1.0, -(a[0] * dx + a[1] * dy) / length2)) if length2 else 0.0
    if math.hypot(a[0] + t * dx, a[1] + t * dy) >= avoid:
        return math.hypot(dx, dy)
    ra, rb = math.hypot(*a), math.hypot(*b)
    angle = abs(math.atan2(a[0] * b[1] - a[1] * b[0], a[0] * b[0] + a[1] * b[1]))
    arc = angle - math.acos(avoid / ra) - math.acos(avoid / rb)
    return math.sqrt(ra * ra - avoid * avoid) + math.sqrt(rb * rb - avoid * avoid) + avoid * max(arc, 0.0)


def carry_mult(size, power):
    weight = size ** W_EXP
    return max(MIN_SPEED, min(MAX_SPEED, 1 / (1 + SLOW * weight / max(power / PER_CAP, 0.1))))


def random_pet(i=0):
    return to_world(i, (random.uniform(*PET_X), random.uniform(*PET_Z)))


def escapes(pet, target, v_thief, victim, v_victim, radius):
    """Vrai si le voleur atteint sa base avant que la victime arrive à `radius` de lui (ligne droite, poursuite au mieux)."""
    length = dist(pet, target)
    total = length / v_thief
    ux, uy = (target[0] - pet[0]) / length, (target[1] - pet[1]) / length
    for n in range(201):
        t = total * n / 200
        p = (pet[0] + ux * v_thief * t, pet[1] + uy * v_thief * t)
        if dist(p, victim) <= radius + v_victim * max(0.0, t - REACT):
            return False
    return True


def pulls_for(score):
    n, cost, left = 0, PULL_COST, score
    while left >= cost:
        left -= cost
        n += 1
        cost *= 1 + PULL_GROWTH
    return max(1, n) if score > 0 else 0


def median(values):
    ordered = sorted(values)
    return ordered[len(ordered) // 2]


# --- Étape 3 : courbe de vitesse proposée, déduite des repères de la carte (pas encore dans Config.lua)
RARITY_NAMES = list(BANDS)
HOLD = num(STEAL, "HoldDuration")


def landmarks():
    """Où peut se trouver le propriétaire (base 0) quand le vol commence, et sa distance médiane au familier volé."""
    kiosk = (lambda a: (203 * math.cos(a), 203 * math.sin(a)))(-math.pi / 8)  # kiosque de l'autre côté du trajet
    spots = {
        "dans sa base (spawn)": to_world(0, SPAWN),
        "à son tapis": to_world(0, TREADMILL),
        "au kiosque voisin": kiosk,
        "objets sauvages (r 115)": (115.0, 0.0),
        "lance près du trou (r 65)": (65.0, 0.0),
        "de l'autre côté du trou": (-65.0, 0.0),
        "vole 2 bases plus loin": to_world(2, (0, -3)),
    }
    pets = [random_pet() for _ in range(2000)]
    return {name: (spot, median(dist(spot, p) for p in pets)) for name, spot in spots.items()}


def proposed_curve():
    """m(r) = MaxSpeed x q^(r-1). Ancres : Commun au plafond actuel (MaxSpeed) ; Sigma tout juste volable, à vitesse
    égale, quand le propriétaire est de l'autre côté du trou (D* = cette distance)."""
    trips = [path_len(p, nearest_inside(1, p)) for p in (random_pet() for _ in range(2000))]
    d = median(trips)
    far = landmarks()["de l'autre côté du trou"][1]
    lam8 = d / (far - RECOVER + SPEED_BASE * REACT)
    q = (lam8 / MAX_SPEED) ** (1 / (len(BANDS) - 1))
    return [MAX_SPEED * q ** i for i in range(len(BANDS))], d, far, q


def etape3():
    random.seed(3)
    curve, d, far, q = proposed_curve()
    gate_gate = dist(to_world(0, GATE), to_world(1, GATE))
    gate_pet = median(dist(to_world(0, GATE), random_pet()) for _ in range(2000))
    print("== Étape 3. Courbe proposée : vitesse en portant = min(sa vitesse, celle du propriétaire) x m(rareté) ==")
    print(f"trajet médian vers la base voisine d = {d:.0f} studs ; propriétaire « de l'autre côté du trou » à {far:.0f} studs")
    print(f"ancre Sigma : m = d / (D* - Reprendre + vitesse x réaction) = {d:.0f} / ({far:.0f} - {RECOVER:.0f} + {SPEED_BASE:.0f} x {REACT})"
          f" = {curve[-1]:.3f} ; q = {q:.3f} par rareté")
    approach = gate_gate / SPEED_BASE + gate_pet / SPEED_BASE + HOLD
    print(f"contrôle : un débutant met {approach:.1f} s pour aller jusqu'au familier, puis {d / (SPEED_BASE * curve[-1]):.1f} s pour"
          f" rentrer avec un Sigma = {approach + d / (SPEED_BASE * curve[-1]):.0f} s (fenêtre ouverte minimale de l'étape 2 : 30 s)")
    print(f"\n{'rareté':11s} {'m actuel débutant':>17s} {'m actuel entraîné':>17s} {'m proposé':>10s}")
    for i, (rarity, (a, b)) in enumerate(BANDS.items()):
        s = (a + b) / 2
        print(f"{rarity:11s} {carry_mult(s, POWER['départ']):17.2f} {carry_mult(s, POWER['entraîné max']):17.2f} {curve[i]:10.2f}")

    print("\n-- Distance minimale du propriétaire pour qu'un vol réussisse (D*, studs ; vitesse égale, « Reprendre » à 10) --")
    print("   D* = 10 + d / (vitesse du voleur / vitesse du propriétaire) - vitesse du propriétaire x 1,5 s")
    marks = landmarks()
    print("   repères : " + ", ".join(f"{n} {v:.0f}" for n, (_, v) in marks.items()))
    print(f"{'rareté':11s} {'actuel débutants':>17s} {'actuel entraînés':>17s} {'proposé débutants':>18s} {'proposé entraînés':>18s}")
    for i, (rarity, (a, b)) in enumerate(BANDS.items()):
        s = (a + b) / 2
        cells = []
        for lam, w in ((carry_mult(s, POWER["départ"]), SPEED_BASE), (carry_mult(s, POWER["entraîné max"]), WALK["entraîné max"]),
                       (curve[i], SPEED_BASE), (curve[i], WALK["entraîné max"])):
            cells.append(RECOVER + d / lam - w * REACT)
        print(f"{rarity:11s} {cells[0]:17.0f} {cells[1]:17.0f} {cells[2]:18.0f} {cells[3]:18.0f}")

    print("\n-- Vols réussis vers la base voisine selon où est le propriétaire (courbe actuelle -> proposée, sans grappin) --")
    duels = {
        "débutants": (SPEED_BASE, POWER["départ"], SPEED_BASE),
        "entraînés": (WALK["entraîné max"], POWER["entraîné max"], WALK["entraîné max"]),
        "voleur débutant, propriétaire entraîné": (SPEED_BASE, POWER["départ"], WALK["entraîné max"]),
    }
    for duel, (w_t, p_t, w_v) in duels.items():
        print(f"## {duel}")
        print(f"   {'propriétaire':28s} " + " ".join(f"{r[:6]:>13s}" for r in RARITY_NAMES[::2] + [RARITY_NAMES[-1]]))
        for name, (spot, _) in marks.items():
            row = []
            for i in list(range(0, len(BANDS), 2)) + [len(BANDS) - 1]:
                a, b = list(BANDS.values())[i]
                s = (a + b) / 2
                rates = []
                for version in ("actuel", "proposé"):
                    v = w_t * carry_mult(s, p_t) if version == "actuel" else min(w_t, w_v) * curve[i]
                    wins = 0
                    for _ in range(120):
                        pet = random_pet()
                        wins += escapes(pet, nearest_inside(1, pet), v, spot, w_v, RECOVER)
                    rates.append(wins / 120)
                row.append(f"{rates[0] * 100:4.0f}->{rates[1] * 100:3.0f}%")
            print(f"   {name:28s} " + " ".join(f"{c:>13s}" for c in row))

    print("\n-- Temps d'exposition : secondes à porter jusqu'à la base voisine (médiane) --")
    print(f"{'rareté':11s} {'actuel débutant':>16s} {'actuel entraîné':>16s} {'proposé (vitesse 16)':>21s} {'proposé (46)':>13s}")
    for i, (rarity, (a, b)) in enumerate(BANDS.items()):
        s = (a + b) / 2
        print(f"{rarity:11s} {d / (SPEED_BASE * carry_mult(s, POWER['départ'])):16.1f} "
              f"{d / (WALK['entraîné max'] * carry_mult(s, POWER['entraîné max'])):16.1f} "
              f"{d / (SPEED_BASE * curve[i]):21.1f} {d / (WALK['entraîné max'] * curve[i]):13.1f}")

    print("\n-- Interception par les AUTRES joueurs (le porteur est signalé à tous) --")
    print("   tiers placés au hasard sur la carte, partent après 2,5 s, batte à 11 studs ; k = tiers qui veulent intercepter")
    for w in (SPEED_BASE, WALK["entraîné max"]):
        print(f"   ## tout le monde à la vitesse {w:.0f}")
        for i, rarity in enumerate(RARITY_NAMES):
            hits = 0
            trials = 600
            for _ in range(trials):
                pet = random_pet()
                target = nearest_inside(1, pet)
                angle, radius = random.uniform(0, 2 * math.pi), 257 * math.sqrt(random.random())
                third = (radius * math.cos(angle), radius * math.sin(angle))
                hits += not escapes_from(pet, target, w * curve[i], third, w, 11.0, 2.5)
            a = hits / trials
            print(f"   {rarity:11s} un tiers : {a * 100:4.0f} %   k=1 {a * 100:4.0f} %  k=2 {(1 - (1 - a) ** 2) * 100:4.0f} %"
                  f"  k=3 {(1 - (1 - a) ** 3) * 100:4.0f} %")


def escapes_from(pet, target, v_thief, other, v_other, radius, react):
    """Comme escapes(), avec un temps de réaction au choix (un tiers met plus longtemps à réagir que la victime)."""
    length = dist(pet, target)
    total = length / v_thief
    ux, uy = (target[0] - pet[0]) / length, (target[1] - pet[1]) / length
    for n in range(121):
        t = total * n / 120
        p = (pet[0] + ux * v_thief * t, pet[1] + uy * v_thief * t)
        if dist(p, other) <= radius + v_other * max(0.0, t - react):
            return False
    return True


def main():
    if "--etape3" in sys.argv:
        etape3()
        return
    random.seed(1)
    gate = to_world(0, GATE)
    print("== 1. Distances (studs) ==")
    print(f"spawn -> bord du trou : {math.hypot(*to_world(0, SPAWN)) - HOLE:.0f} | entrée -> bord du trou : {math.hypot(*gate) - HOLE:.0f}"
          f" | entrée -> zone de sacrifice : {math.hypot(*gate) - HOLE - SAC_RANGE:.0f}")
    for k in range(1, 5):
        print(f"base 0 -> base {k} : centres {dist(to_world(0, (0, 0)), to_world(k, (0, 0))):.0f}, entrées {dist(gate, to_world(k, GATE)):.0f}")

    print("\n== 2. Portée de lancer (45°) et marche depuis la palette ==")
    pallet = math.hypot(*to_world(0, PALLET))
    for name, power in POWER.items():
        reach = power * power / G
        print(f"Force {name:15s} {power:4.0f} : portée {reach:4.0f} -> marcher {max(0.0, pallet - HOLE - reach):4.0f} studs")
    need = math.sqrt((pallet - HOLE) * G)
    print(f"on lance depuis sa palette dès ThrowPower {need:.0f} (niveau de Force {(need - STR_BASE) / STR_PER:.0f})")

    print("\n== 3. Trajet du voleur, d'un familier au hasard jusqu'à SA base (studs, médiane) ==")
    for k in range(1, 5):
        lengths = sorted(path_len(p, nearest_inside(k, p)) for p in (random_pet() for _ in range(3000)))
        print(f"base à {k} cran(s) : {lengths[1500]:.0f} (min {lengths[0]:.0f}, max {lengths[-1]:.0f})")
    sac = sorted(math.hypot(*random_pet()) - HOLE - SAC_RANGE for _ in range(3000))
    print(f"vers la zone de sacrifice : {sac[1500]:.0f}")

    print("\n== 4. Vitesse de transport (x WalkSpeed), milieu de tranche ==")
    print(f"{'rareté':11s} {'taille':>6s} {'poids':>6s} " + " ".join(f"{n:>15s}" for n in POWER))
    for rarity, (a, b) in BANDS.items():
        s = (a + b) / 2
        print(f"{rarity:11s} {s:6.2f} {s ** W_EXP:6.2f} " + " ".join(f"{carry_mult(s, p):15.2f}" for p in POWER.values()))

    print("\n== 5. Poursuite vers la base voisine : % de vols réussis (sans grappin / avec grappin) ==")
    victims = {"chez elle (spawn)": lambda: to_world(0, SPAWN), "à son tapis": lambda: to_world(0, TREADMILL),
               "lance près du trou": lambda: (65.0, 0.0), "de l'autre côté du trou": lambda: (-65.0, 0.0)}
    duels = [("débutant contre débutant", WALK["départ"], POWER["départ"], WALK["départ"]),
             ("entraîné contre entraîné", WALK["entraîné max"], POWER["entraîné max"], WALK["entraîné max"]),
             ("voleur entraîné, victime débutante", WALK["entraîné max"], POWER["entraîné max"], WALK["départ"])]
    for label, victim in victims.items():
        print(f"-- victime {label}")
        for rarity, (a, b) in BANDS.items():
            s = (a + b) / 2
            cells = []
            for _, w_thief, p_thief, w_victim in duels:
                rates = []
                for radius in (RECOVER, GRAPPLE):
                    wins = 0
                    for _ in range(250):
                        pet = random_pet()
                        wins += escapes(pet, nearest_inside(1, pet), w_thief * carry_mult(s, p_thief), victim(), w_victim, radius)
                    rates.append(f"{wins / 250 * 100:3.0f}%")
                cells.append("/".join(rates))
            print(f"   {rarity:11s} " + "   ".join(f"{d[0]} {c}" for d, c in zip(duels, cells)))

    print("\n== 6. Une manche (Feeding) pour un débutant ==")
    value = sum(w * v for w, v in TIERS) / sum(w for w, _ in TIERS)
    available = num(ITEMS, "MaxPerBase") + FEEDING / num(ITEMS, "SpawnInterval")
    for power in (STR_BASE, 100, 130, need):
        reach = power * power / G
        walk = max(0.0, pallet - HOLE - reach)
        for capacity in (1, 2, 5):
            cycle = 2 * walk / SPEED_BASE + 0.8 * capacity + 0.5
            items = min(available, (1 + max(0.0, (FEEDING - walk / SPEED_BASE) / cycle)) * capacity)
            score = items * value * 1.1 * 1.3  # Commun équipé (x1,1), bonus moyen des paliers du trou (x1,3)
            print(f"Force {power:4.0f}, sac {capacity} : {items:4.1f} objets -> {score:4.1f} points -> {pulls_for(score)} tirage(s), "
                  f"{score * MONEY_PER_POINT:4.0f} $")


if __name__ == "__main__":
    main()
