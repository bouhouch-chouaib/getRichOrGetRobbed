"""Tapis de course et banc de muscu en briques (25 oct.), 5 modèles chacun (Bois, Acier, Or, Cristal, Cosmique) :
la base commune, appelée par Treadmill_<Niveau>.py et Bench_<Niveau>.py. Sans tenons ni lueur, rareté par la matière.

Version « réaliste » (Chouaib, 25 oct. : « un vrai tapis n'est pas comme ça, pas de barre à l'arrière ») : tapis avec
capot moteur arrondi devant, montants inclinés vers le coureur, console penchée, poignées, marches latérales, rouleaux
et pieds ; banc plat de salle avec coussin rembourré sur une poutre, pied en T, râtelier en tubes percés à crochets en
J et cornes à disques. Plus de portique ni de cristaux autour : le niveau se lit aux couleurs, aux liserés et à
l'emblème du capot / du râtelier.

Mesures en studs, à la taille d'origine (server/StationLooks réduit le tapis x0,6) ; Blender -Y = -Z Roblox (la
console du tapis, la tête du banc). Le jeu garde ses pièces utiles : la bande du tapis (« Zone », 10 x 20, 0,6 de
haut), la barre (z 5, y -3,2) et les disques du banc (animés), les voyants, l'écran et l'étoile (attribut StarY).
"""

import math

from pet_kit import PetKit


def tier_materials(kit, tier):
    """Matières d'un niveau. tier = dict(name, main, dark, accent, trim, finish) ; finish : wood / steel / gold /
    crystal / cosmic."""
    finish = tier["finish"]
    if finish == "wood":
        main = kit.mat("bois", tier["main"], rough=0.55)
        dark = kit.mat("bois_fonce", tier["dark"], rough=0.6)
    elif finish == "steel":
        main = kit.mat("acier", tier["main"], rough=0.35, metal=0.55)
        dark = kit.mat("acier_fonce", tier["dark"], rough=0.4, metal=0.5)
    elif finish == "gold":
        main = kit.gold("or", tint=tier["main"], hammered=0.35, rough=0.3)
        dark = kit.enamel("ambre", tier["dark"])
    else:
        main = kit.enamel("laque", tier["main"])
        dark = kit.enamel("laque_fonce", tier["dark"])
    accent = kit.enamel("accent", tier["accent"])
    trim = kit.gold("lisere", tint=tier["trim"], hammered=0.2, rough=0.35) if tier.get("trim") else accent
    rubber = kit.mat("caoutchouc", "#2A2A30", rough=0.8)
    plastic = kit.mat("plastique_noir", "#3A3A42", rough=0.45)
    chrome = kit.mat("chrome_brosse", "#C8CCD6", rough=0.3, metal=0.7)
    return main, dark, accent, trim, rubber, plastic, chrome


def emblem(kit, part, center, normal_y, tier, accent, trim):
    """Emblème du niveau sur une face qui regarde vers ±Y : feuille (Bois), éclair (Acier), étoile (Or), gemme
    (Cristal), planète à anneau (Cosmique)."""
    x, y, z = center
    finish = {"wood": "wood", "steel": "steel", "sport": "steel", "gold": "gold", "royal": "gold", "celestial": "gold",
              "jade": "crystal", "crystal": "crystal", "lava": "crystal"}.get(tier["theme"], "cosmic")
    d = 0.12 * normal_y
    if finish == "wood":
        kit.add(kit.brick((0.5, 0.12, 0.9), center=(x, y + d, z), rot=(0, 35, 0)), accent, part, bevel=0.04)
        kit.add(kit.brick((0.5, 0.12, 0.9), center=(x + 0.3, y + d, z), rot=(0, -35, 0)), accent, part, bevel=0.04)
    elif finish == "steel":
        kit.add(kit.brick((0.35, 0.12, 1.0), center=(x - 0.1, y + d, z + 0.15), rot=(0, 25, 0)), accent, part, bevel=0.03)
        kit.add(kit.brick((0.35, 0.12, 1.0), center=(x + 0.1, y + d, z - 0.15), rot=(0, 25, 0)), accent, part, bevel=0.03)
    elif finish == "gold":
        kit.add(kit.brick((0.8, 0.12, 0.8), center=(x, y + d, z), rot=(0, 45, 0)), trim, part, bevel=0.03)
        kit.add(kit.brick((0.8, 0.16, 0.8), center=(x, y + d, z)), trim, part, bevel=0.03)
    elif finish == "crystal":
        gem = kit.gem("embleme", "#0A2A3A", tier["accent"], "#F0FAFF")
        kit.add(kit.brick((0.7, 0.18, 0.7), center=(x, y + d, z), rot=(0, 45, 0)), gem, part, bevel=0.03)
        kit.add(kit.brick((1.0, 0.1, 1.0), center=(x, y + d * 0.5, z), rot=(0, 45, 0)), trim, part, bevel=0.03)
    else:
        planet = kit.enamel("planete", tier["trim"])
        kit.add(kit.disc(0.45, 0.18, center=(x, y + d, z), normal=(0, normal_y, 0), sides=12), planet, part, bevel=0.0)
        kit.add(kit.brick((1.4, 0.1, 0.16), center=(x, y + d * 1.4, z), rot=(0, -20, 0)), accent, part, bevel=0.02)


def treadmill(name: str, tier: dict) -> dict:
    kit = PetKit(name)
    main, dark, accent, trim, rubber, plastic, chrome = tier_materials(kit, tier)

    # --- châssis bas sous la bande, rouleaux, pieds ---
    kit.add(kit.brick((10.6, 20.6, 0.35), center=(0, 0.2, 0.18)), plastic, "Frame", bevel=0.08)
    kit.add(kit.cylinder(0.42, 10.3, center=(0, 10.25, 0.45), rot=(0, 90, 0), sides=12), chrome, "Frame", bevel=0.04)
    kit.add(kit.brick((11.6, 0.9, 0.7), center=(0, 10.75, 0.42)), plastic, "Frame", bevel=0.25)
    for s in (-1, 1):
        kit.add(kit.cylinder(0.32, 0.35, center=(s * 5.0, 10.75, 0.18), rot=(0, 0, 22.5), sides=8), rubber, "Frame",
                bevel=0.04)
    # --- marches latérales (là où l'on pose les pieds), avec liseré du niveau ---
    for s in (-1, 1):
        kit.add(kit.brick((1.0, 20.8, 0.75), center=(s * 5.55, 0.3, 0.38)), main, "Frame", bevel=0.2)
        kit.add(kit.brick((0.9, 19.6, 0.08), center=(s * 5.55, 0.3, 0.79)), rubber, "Frame", bevel=0.02)
        kit.add(kit.brick((0.08, 20.0, 0.18), center=(s * 6.07, 0.3, 0.45)), trim, "Frame", bevel=0.02)
    # --- capot moteur arrondi à l'avant, avec l'emblème du niveau ---
    kit.add(kit.box((11.6, 2.8, 1.5), center=(0, -9.9, 0.75), taper=(0.97, 0.75), shift=(0.0, -0.3)), main, "Frame",
            bevel=0.45)
    kit.add(kit.brick((11.0, 0.3, 0.9), center=(0, -11.25, 0.65)), dark, "Frame", bevel=0.12)
    for k in range(5):
        kit.add(kit.brick((0.18, 0.12, 0.5), center=(-4.6 + k * 0.4, -11.4, 0.7)), plastic, "Frame", bevel=0.02)
    emblem(kit, "Frame", (3.6, -11.35, 0.75), -1, tier, accent, trim)

    # --- montants coudés : droits au-dessus du capot, puis penchés vers le coureur ---
    import _parts as P
    for s in (-1, 1):
        x = s * 4.9
        kit.add(kit.brick((1.3, 1.7, 0.5), center=(x, -10.3, 1.3)), dark, "Console", bevel=0.15)
        P.chain(kit, "Console", [(x, -10.3, 1.4), (x, -10.15, 3.4), (x * 0.92, -9.5, 5.6)], 0.95, [main])
    # --- console arrondie, plus étroite que le tapis : panneau avant (écran et voyants posés par le jeu), pupitre
    #     incliné, ailes qui rejoignent les montants, porte-gourdes ---
    kit.add(kit.box((8.4, 2.1, 1.9), center=(0, -9.55, 6.3), taper=(0.94, 0.85)), main, "Console", bevel=0.4)
    kit.add(kit.box((8.6, 1.9, 0.55), center=(0, -9.3, 7.45), rot=(-22, 0, 0), taper=(0.92, 0.75)), dark, "Console",
            bevel=0.22)
    kit.add(kit.brick((6.0, 0.14, 1.4), center=(0, -8.52, 6.15)), plastic, "Console", bevel=0.05)
    for s in (-1, 1):
        kit.add(kit.box((1.6, 1.5, 0.9), center=(s * 4.6, -9.45, 5.85), taper=(0.7, 0.9)), main, "Console", bevel=0.3)
        kit.add(kit.cylinder(0.42, 0.7, center=(s * 3.3, -8.95, 7.95), rot=(0, 0, 22.5), sides=8), plastic, "Console",
                bevel=0.05)
        kit.add(kit.brick((0.7, 0.14, 0.7), center=(s * 3.55, -8.52, 6.1)), accent, "Console", bevel=0.04)
    kit.add(kit.cylinder(0.3, 0.8, center=(3.3, -8.95, 8.55), rot=(0, 0, 22.5), sides=8), accent, "Console", bevel=0.05)
    kit.add(kit.cylinder(0.25, 0.25, center=(-2.6, -8.47, 7.0), rot=(90, 0, 0), sides=8), kit.enamel("cle", "#FF3A3A"),
            "Console", bevel=0.03)
    # --- poignées : barre avant sous la console et deux poignées latérales vers le coureur ---
    kit.add(kit.cylinder(0.28, 9.2, center=(0, -8.3, 5.2), rot=(0, 90, 0), sides=10), chrome, "Console", bevel=0.03)
    for s in (-1, 1):
        x = s * 5.35
        kit.add(kit.cylinder(0.3, 4.6, center=(x, -6.4, 5.3), rot=(90, 0, 0), sides=10), chrome, "Console", bevel=0.03)
        kit.add(kit.cylinder(0.36, 2.0, center=(x, -5.4, 5.3), rot=(90, 0, 0), sides=10), rubber, "Console", bevel=0.03)
        kit.add(kit.brick((0.5, 0.5, 0.9), center=(x, -4.15, 4.9)), chrome, "Console", bevel=0.1)
        kit.add(kit.brick((0.6, 0.6, 0.3), center=(x, -4.15, 4.4)), dark, "Console", bevel=0.08)
    # --- serviette sur la poignée gauche ---
    towel = kit.mat("serviette", "#F4F4F8", rough=0.8)
    kit.add(kit.brick((1.1, 1.6, 0.25), center=(-5.35, -6.8, 5.72)), towel, "Console", bevel=0.06)
    for s in (-1, 1):
        kit.add(kit.brick((0.22, 1.6, 1.3), center=(-5.35 + s * 0.5, -6.8, 5.0)), towel, "Console", bevel=0.05)
    decorate_treadmill(kit, tier, (main, dark, accent, trim, rubber, plastic, chrome))
    return kit.result()


def bench(name: str, tier: dict) -> dict:
    kit = PetKit(name)
    main, dark, accent, trim, rubber, plastic, chrome = tier_materials(kit, tier)
    pad = kit.mat("coussin", tier.get("pad", "#2E2A34"), rough=0.7)
    seam = kit.mat("couture", "#18161C", rough=0.7)

    # --- coussin rembourré sur une poutre d'acier (la tête vers -Y, sous la barre) ---
    kit.add(kit.box((3.0, 9.2, 0.75), center=(0, 1.0, 2.15), taper=(0.93, 1.0)), pad, "Bench", bevel=0.32)
    kit.add(kit.brick((2.8, 0.06, 0.76), center=(0, -1.2, 2.15)), seam, "Bench", bevel=0.0)
    kit.add(kit.brick((2.7, 8.8, 0.25), center=(0, 1.0, 1.66)), dark, "Bench", bevel=0.06)
    kit.add(kit.brick((0.9, 9.4, 0.7), center=(0, 1.2, 1.2)), main, "Bench", bevel=0.18)
    # pied en T sous les pieds du sportif
    kit.add(kit.brick((0.8, 0.8, 1.0), center=(0, 4.9, 0.5)), main, "Bench", bevel=0.15)
    kit.add(kit.cylinder(0.32, 3.4, center=(0, 5.0, 0.32), rot=(0, 90, 0), sides=10), main, "Bench", bevel=0.05)
    for s in (-1, 1):
        kit.add(kit.cylinder(0.36, 0.3, center=(s * 1.75, 5.0, 0.32), rot=(0, 90, 0), sides=10), rubber, "Bench",
                bevel=0.04)
    emblem(kit, "Bench", (0, 5.85, 1.2), 1, tier, accent, trim)

    # --- râtelier derrière la tête : base en U, montants en tubes percés, crochets en J qui tiennent la barre (y -3,2),
    #     traverse avec l'emblème du niveau, cornes à disques ---
    ry = -4.0
    kit.add(kit.cylinder(0.32, 5.6, center=(0, ry, 0.32), rot=(0, 90, 0), sides=10), main, "Rack", bevel=0.05)
    kit.add(kit.cylinder(0.3, 3.0, center=(0, -2.5, 0.3), rot=(90, 0, 0), sides=10), main, "Rack", bevel=0.05)
    kit.add(kit.brick((0.7, 0.7, 1.0), center=(0, -2.8, 0.75)), main, "Rack", bevel=0.12)
    for s in (-1, 1):
        x = s * 2.2
        kit.add(kit.cylinder(0.34, 3.0, center=(x, ry, 0.32), rot=(90, 0, 0), sides=10), main, "Rack", bevel=0.05)
        for y in (ry - 1.45, ry + 1.45):
            kit.add(kit.cylinder(0.38, 0.3, center=(x, y, 0.32), rot=(90, 0, 0), sides=10), rubber, "Rack", bevel=0.04)
        kit.add(kit.brick((0.75, 0.75, 5.9), center=(x, ry, 3.3)), main, "Rack", bevel=0.12)
        kit.add(kit.brick((0.85, 0.85, 0.3), center=(x, ry, 6.35)), trim, "Rack", bevel=0.06)
        for k in range(8):
            kit.add(kit.brick((0.4, 0.12, 0.2), center=(x, ry + 0.4, 1.4 + k * 0.6)), plastic, "Rack", bevel=0.02)
        # crochet en J : bras vers le sportif, lèvre qui retient la barre
        kit.add(kit.brick((0.55, 1.0, 0.25), center=(x, ry + 0.85, 4.7)), dark, "Rack", bevel=0.06)
        kit.add(kit.brick((0.55, 0.2, 0.55), center=(x, ry + 1.3, 4.95)), dark, "Rack", bevel=0.05)
        # corne à disques à l'extérieur du montant, avec un disque rangé
        kit.add(kit.cylinder(0.18, 1.3, center=(x + s * 0.95, ry, 1.6), rot=(0, 90, 0), sides=8), chrome, "Rack", bevel=0.02)
        kit.add(kit.cylinder(1.0, 0.4, center=(x + s * 1.25, ry, 1.6), rot=(0, 90, 0), sides=14), accent, "Rack",
                bevel=0.06)
    kit.add(kit.brick((3.7, 0.3, 0.9), center=(0, ry, 3.6)), dark, "Rack", bevel=0.08)
    emblem(kit, "Rack", (0, ry - 0.15, 3.6), -1, tier, accent, trim)

    # --- petit tableau des voyants au pied du banc (les voyants sont posés par le jeu) ---
    kit.add(kit.brick((1.0, 1.0, 1.2), center=(0, 7.2, 0.6)), main, "Weights", bevel=0.15)
    kit.add(kit.box((7.2, 0.8, 0.6), center=(0, 7.2, 1.45), taper=(0.95, 0.8)), dark, "Weights", bevel=0.12)
    # --- haltères sur leur support ---
    kit.add(kit.brick((1.4, 3.2, 0.3), center=(-5.0, 5.35, 0.62)), main, "Weights", bevel=0.06)
    for s in (-1, 1):
        kit.add(kit.brick((0.3, 3.0, 0.5), center=(-5.0 + s * 0.55, 5.35, 0.25)), dark, "Weights", bevel=0.05)
    for y in (4.5, 6.2):
        kit.add(kit.cylinder(0.16, 2.2, center=(-5.0, y, 1.15), rot=(0, 90, 0), sides=8), chrome, "Weights", bevel=0.02)
        for s in (-1, 1):
            kit.add(kit.cylinder(0.5, 0.55, center=(-5.0 + s * 0.95, y, 1.15), rot=(0, 90, 0), sides=6), accent,
                    "Weights", bevel=0.05)
    # --- arbre à disques ---
    kit.add(kit.cylinder(1.1, 0.3, center=(5.0, 4.5, 0.15), rot=(0, 0, 22.5), sides=8), dark, "Weights", bevel=0.05)
    kit.add(kit.cylinder(0.3, 4.0, center=(5.0, 4.5, 2.2), rot=(0, 0, 0), sides=10), main, "Weights", bevel=0.04)
    for k, (z, r) in enumerate(((1.2, 1.1), (2.4, 0.95), (3.5, 0.75))):
        side = 1 if k % 2 == 0 else -1
        kit.add(kit.cylinder(0.14, 0.9, center=(5.0 + side * 0.45, 4.5, z), rot=(0, 90, 0), sides=8), chrome, "Weights",
                bevel=0.02)
        kit.add(kit.cylinder(r, 0.35, center=(5.0 + side * 0.6, 4.5, z), rot=(0, 90, 0), sides=14),
                accent if k % 2 == 0 else dark, "Weights", bevel=0.05)
    decorate_bench(kit, tier, (main, dark, accent, trim, rubber, plastic, chrome))
    return kit.result()



# ---------------------------------------------------------------------------------------------------------------------
# 10 modèles de plus en plus spectaculaires (Chouaib, 25 oct. : « 10 tapis tous plus spectaculaires au fur et à
# mesure, et la même pour les bancs »). Toujours la machine réaliste en dessous ; le décor vient s'y greffer (rien
# derrière la machine), sans néon : la rareté se lit à la matière.
# ---------------------------------------------------------------------------------------------------------------------

def _flame(kit, part, x, y, z, size, outer, inner):
    """Flamme sculptée (émail orange et jaune, pas de lueur)."""
    for dx, h, w, mat in ((-0.35, 0.9, 0.5, outer), (0.0, 1.4, 0.7, outer), (0.38, 1.0, 0.5, outer), (0.0, 0.8, 0.4, inner)):
        kit.add(kit.wedge((w * size, 0.3 * size, h * size), center=(x + dx * size, y, z + h * size / 2), tip=0.1), mat, part,
                bevel=0.0)


def _crystals(kit, part, x, y, z, height, gem, base):
    kit.add(kit.cylinder(0.7, 0.35, center=(x, y, z + 0.17), rot=(0, 0, 22.5), sides=8), base, part, bevel=0.06)
    for dx, dy, h, tilt in ((0.0, 0.0, height, 0), (0.35, 0.15, height * 0.6, 18), (-0.3, -0.2, height * 0.5, -20)):
        kit.add(kit.cylinder(0.26, h, center=(x + dx, y + dy, z + 0.35 + h / 2), rot=(tilt, tilt * 0.5, 22.5), sides=6,
                             top=0.03), gem, part, bevel=0.0)


def _crown(kit, part, x, y, z, width, gold, gem, spikes=5):
    kit.add(kit.brick((width, 0.5, 0.5), center=(x, y, z)), gold, part, bevel=0.08)
    for k in range(spikes):
        sx = x - width / 2 + 0.3 + k * (width - 0.6) / (spikes - 1)
        h = 0.9 if k % 2 == 0 else 0.6
        kit.add(kit.wedge((0.4, 0.4, h), center=(sx, y, z + 0.25 + h / 2), tip=0.1), gold, part, bevel=0.0)
        if k % 2 == 0:
            kit.add(kit.brick((0.24, 0.24, 0.24), center=(sx, y - 0.22, z + 0.05), rot=(0, 45, 0)), gem, part, bevel=0.03)


def _octo_ring(kit, part, center, radius, mat, plane="XZ", size=0.32):
    cx, cy, cz = center
    side = 2 * radius * math.tan(math.radians(22.5)) + 0.04
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        if plane == "XZ":
            kit.add(kit.brick((side, size, size), center=(cx + math.cos(a) * radius, cy, cz + math.sin(a) * radius),
                              rot=(0, -math.degrees(a) - 90, 0)), mat, part, bevel=0.04)
        else:  # anneau horizontal (XY)
            kit.add(kit.brick((side, size, size), center=(cx + math.cos(a) * radius, cy + math.sin(a) * radius, cz),
                              rot=(0, 0, math.degrees(a) + 90)), mat, part, bevel=0.04)


def _wings(kit, part, x, y, z, span, height, mats):
    """Grandes ailes d'ange en éventail de plumes (planches épaisses dans le plan XZ : bien visibles de face et de
    dos), bord d'attaque doré. x = écart de l'attache depuis le centre, span = longueur de la plus grande plume."""
    feather, under, edge = mats
    for s in (-1, 1):
        kit.add(kit.brick((0.9, 0.5, 0.9), center=(s * x, y, z), rot=(0, 45, 0)), edge, part, bevel=0.08)
        for k in range(6):
            length = span * (0.55 + 0.09 * k)
            angle = math.radians(8 + 13 * k)
            cx = s * (x + math.cos(angle) * length / 2)
            cz = z + math.sin(angle) * length / 2 - 0.2
            mat = feather if k % 2 == 0 else under
            kit.add(kit.brick((length, 0.3, height * 0.22), center=(cx, y + 0.05 * k, cz), rot=(0, -s * math.degrees(angle), 0)),
                    mat, part, bevel=0.1)
        top = math.radians(8 + 13 * 5)
        length = span * 1.0
        kit.add(kit.brick((length, 0.36, 0.16), center=(s * (x + math.cos(top) * length / 2), y + 0.3,
                                                      z + math.sin(top) * length / 2 + height * 0.1),
                          rot=(0, -s * math.degrees(top), 0)), edge, part, bevel=0.05)


def _thruster(kit, part, x, y, z, steel, inner, dark):
    kit.add(kit.cylinder(0.75, 2.2, center=(x, y, z), rot=(90, 0, 0), sides=10), steel, part, bevel=0.08)
    kit.add(kit.cylinder(0.85, 0.3, center=(x, y - 0.9, z), rot=(90, 0, 0), sides=10), dark, part, bevel=0.04)
    kit.add(kit.cylinder(0.75, 0.9, center=(x, y + 1.5, z), rot=(-90, 0, 0), sides=10, top=1.0), dark, part, bevel=0.04)
    kit.add(kit.cylinder(0.55, 0.2, center=(x, y + 1.96, z), rot=(90, 0, 0), sides=10), inner, part, bevel=0.0)


def _floor_plate(kit, part, sx, sy, top, border, gem):
    kit.add(kit.brick((sx, sy, 0.22), center=(0, 0, 0.11)), top, part, bevel=0.08)
    for s in (-1, 1):
        kit.add(kit.brick((sx + 0.1, 0.4, 0.3), center=(0, s * (sy / 2 - 0.2), 0.15)), border, part, bevel=0.06)
        kit.add(kit.brick((0.4, sy, 0.3), center=(s * (sx / 2 - 0.2), 0, 0.15)), border, part, bevel=0.06)
    for sxx in (-1, 1):
        for syy in (-1, 1):
            kit.add(kit.brick((0.6, 0.6, 0.6), center=(sxx * (sx / 2 - 0.3), syy * (sy / 2 - 0.3), 0.45), rot=(0, 0, 45)),
                    gem, part, bevel=0.06)


def decorate_treadmill(kit, tier, m):
    """Décor du niveau sur le tapis réaliste. m = matières (main, dark, accent, trim, rubber, plastic, chrome)."""
    main, dark, accent, trim, rubber, plastic, chrome = m
    level, theme = tier["level"], tier["theme"]
    if level >= 3:
        # carénages latéraux (au-delà des marches), avec liseré
        for s in (-1, 1):
            kit.add(kit.box((0.8, 18.4, 1.3), center=(s * 6.5, 0.6, 0.65), taper=(0.6, 0.97)), main, "Decor", bevel=0.25)
            kit.add(kit.brick((0.1, 17.6, 0.2), center=(s * 6.9, 0.6, 0.55)), trim, "Decor", bevel=0.03)
    if theme == "sport":
        white = kit.enamel("bandes", "#FAFAFA")
        for x in (-1.2, 1.2):
            kit.add(kit.brick((0.7, 2.6, 0.06), center=(x, -9.9, 1.52)), white, "Decor", bevel=0.02)
        # (pas d'aileron à l'arrière : Chouaib ne veut aucune barre derrière la machine)
        for s in (-1, 1):
            kit.add(kit.disc(0.5, 0.15, center=(s * 4.6, -8.75, 5.85), normal=(0, 1, 0), sides=12), plastic, "Decor", bevel=0.0)
            for k in range(3):
                kit.add(kit.brick((0.14, 2.2, 0.5), center=(s * 6.95, -4.0 + k * 2.6, 0.75), rot=(0, 0, 0)), kit.enamel("bandes", "#FAFAFA"),
                        "Decor", bevel=0.03)
    elif theme == "gold":
        _crown(kit, "Decor", 0, -9.4, 8.2, 3.6, trim, accent, spikes=5)
        for k in range(8):
            kit.add(kit.brick((0.22, 0.22, 0.22), center=(-3.5 + k, -11.42, 1.35), rot=(0, 45, 0)), trim, "Decor", bevel=0.03)
    elif theme == "jade":
        gem = kit.gem("jade", "#0A4A2A", "#3AE68A", "#E0FFF0")
        for s in (-1, 1):
            kit.add(kit.brick((1.2, 1.2, 0.4), center=(s * 4.6, -10.4, 1.7)), trim, "Decor", bevel=0.08)
            kit.add(kit.cylinder(0.45, 2.4, center=(s * 4.6, -10.4, 3.1), rot=(0, 0, 45), sides=4, top=0.05), gem, "Decor",
                    bevel=0.0)
        for s in (-1, 1):
            for k in range(5):
                kit.add(kit.brick((0.12, 0.6, 0.6), center=(s * 6.92, -6.0 + k * 3.4, 0.8), rot=(45, 0, 0)), gem, "Decor",
                        bevel=0.03)
        _crown(kit, "Decor", 0, -9.4, 8.2, 3.0, trim, gem, spikes=3)
    elif theme == "crystal":
        gem = kit.gem("cristal", "#0A3A5A", "#46E6FF", "#E8FBFF")
        for s in (-1, 1):
            _crystals(kit, "Decor", s * 4.6, -10.4, 1.5, 3.2, gem, trim)
            for k in range(6):
                kit.add(kit.brick((0.14, 0.7, 0.7), center=(s * 6.92, -7.0 + k * 3.0, 0.8), rot=(45, 0, 0)), gem, "Decor",
                        bevel=0.03)
        for k in range(5):
            h = 1.6 if k == 2 else (1.1 if k in (1, 3) else 0.7)
            kit.add(kit.cylinder(0.3, h, center=(-1.6 + k * 0.8, -9.4, 8.1 + h / 2), rot=(0, 0, 22.5), sides=6, top=0.03),
                    gem, "Decor", bevel=0.0)
        kit.add(kit.brick((4.2, 0.6, 0.35), center=(0, -9.4, 8.05)), trim, "Decor", bevel=0.06)
    elif theme == "lava":
        lava = kit.enamel("lave", "#FF6A12")
        flame_in = kit.enamel("flamme", "#FFD23A")
        for (x, y, z, rx, ry) in ((-3.0, -9.9, 1.52, 0, 30), (2.2, -9.7, 1.52, 0, -40), (-4.5, -9.5, 6.4, 0, 60),
                                  (3.8, -8.5, 6.6, 0, -50)):
            kit.add(kit.brick((1.6, 0.12, 0.14), center=(x, y if z > 2 else y, z), rot=(rx, ry if z > 2 else 0, ry if z <= 2 else 0)),
                    lava, "Decor", bevel=0.02)
        for s in (-1, 1):
            for k in range(5):
                kit.add(kit.wedge((0.5, 0.9, 1.0), center=(s * 6.6, -6.5 + k * 3.6, 1.6), tip=0.1), dark, "Decor", bevel=0.0)
                kit.add(kit.brick((0.08, 0.6, 0.12), center=(s * 6.92, -6.5 + k * 3.6, 0.7)), lava, "Decor", bevel=0.0)
            import _parts as P
            P.horn(kit, "Decor", (s * 4.4, -9.5, 7.4), (s * 0.8, 0.2, 0.9), 1.6, 0.4, [dark, lava], segments=4, curl=0.5)
        _flame(kit, "Decor", 0, -11.2, 1.5, 1.0, lava, flame_in)
    elif theme == "royal":
        velvet = kit.mat("velours", "#B4142A", rough=0.75)
        ruby = kit.gem("rubis", "#5A0A14", "#FF3A4A", "#FFE0E0")
        for s in (-1, 1):
            kit.add(kit.brick((0.92, 19.4, 0.1), center=(s * 5.55, 0.3, 0.84)), velvet, "Decor", bevel=0.02)
            # bannières sous les ailes de la console
            kit.add(kit.brick((1.4, 0.12, 2.6), center=(s * 4.6, -8.55, 4.2)), velvet, "Decor", bevel=0.03)
            kit.add(kit.wedge((1.4, 0.12, 0.7), center=(s * 4.6, -8.55, 2.55), rot=(180, 0, 0), tip=0.05), velvet, "Decor",
                    bevel=0.0)
            kit.add(kit.brick((0.5, 0.14, 0.5), center=(s * 4.6, -8.5, 4.4), rot=(0, 45, 0)), trim, "Decor", bevel=0.03)
            import _parts as P
            P.horn(kit, "Decor", (s * 5.2, -10.6, 1.4), (s * 0.6, -0.4, 0.8), 1.2, 0.35, [trim], segments=4, curl=0.8)
        _crown(kit, "Decor", 0, -9.4, 8.3, 4.4, trim, ruby, spikes=7)
        kit.add(kit.brick((0.5, 0.5, 0.5), center=(0, -9.4, 10.0), rot=(45, 0, 45)), ruby, "Decor", bevel=0.04)
    elif theme == "cosmic":
        planet = kit.enamel("planete", tier["trim_hex"])
        kit.add(kit.brick((0.4, 0.4, 1.4), center=(0, -9.4, 8.6)), dark, "Decor", bevel=0.05)
        for z, r, h in ((9.7, 0.7, 0.5), (10.3, 1.0, 0.7), (10.9, 0.7, 0.5)):
            kit.add(kit.cylinder(r, h, center=(0, -9.4, z), rot=(0, 0, 22.5), sides=8), planet, "Decor", bevel=0.1)
        _octo_ring(kit, "Decor", (0, -9.4, 10.3), 1.7, accent, plane="XY", size=0.25)
        for s in (-1, 1):
            _octo_ring(kit, "Decor", (s * 4.7, -9.9, 3.4), 0.9, trim, plane="XY", size=0.2)
            _thruster(kit, "Decor", s * 3.4, 11.4, 0.9, chrome, accent, dark)
        for x, z in ((-4.0, 8.6), (3.6, 9.4), (-2.4, 10.4)):
            kit.add(kit.brick((0.35, 0.2, 0.35), center=(x, -9.4, z), rot=(0, 45, 0)), trim, "Decor", bevel=0.03)
    elif theme == "celestial":
        gem = kit.gem("cristal_ciel", "#1E5A9A", "#7AC8FF", "#F0FAFF")
        feather = kit.pearl("plumes", color="#FBF8FF", sheen="#D8ECFF")
        _wings(kit, "Decor", 5.0, -9.8, 6.4, 4.2, 2.6, (feather, kit.pearl("plumes_ombre", color="#E8EEFA", sheen="#FFE8B0"), trim))
        _octo_ring(kit, "Decor", (0, -9.4, 10.4), 1.9, trim, plane="XY", size=0.5)
        _floor_plate(kit, "Decor", 16.0, 25.0, kit.pearl("socle", color="#F2F4FA", sheen="#FFE8B0"), trim, gem)
        for s in (-1, 1):
            _crystals(kit, "Decor", s * 4.6, -10.4, 1.5, 2.6, gem, trim)


def decorate_bench(kit, tier, m):
    """Décor du niveau sur le banc réaliste (râtelier en y -4, montants à x ±2,2)."""
    main, dark, accent, trim, rubber, plastic, chrome = m
    theme, ry = tier["theme"], -4.0
    if theme == "sport":
        white = kit.enamel("bandes", "#FAFAFA")
        for x in (-0.6, 0.6):
            kit.add(kit.brick((0.3, 9.0, 0.06), center=(x, 1.0, 2.53)), white, "Decor", bevel=0.02)
    elif theme == "gold":
        for s in (-1, 1):
            kit.add(kit.brick((0.5, 0.5, 0.5), center=(s * 2.2, ry, 6.75), rot=(45, 0, 45)), accent, "Decor", bevel=0.05)
    elif theme == "jade":
        gem = kit.gem("jade", "#0A4A2A", "#3AE68A", "#E0FFF0")
        for s in (-1, 1):
            kit.add(kit.cylinder(0.4, 1.6, center=(s * 2.2, ry, 7.3), rot=(0, 0, 45), sides=4, top=0.04), gem, "Decor", bevel=0.0)
    elif theme == "crystal":
        gem = kit.gem("cristal", "#0A3A5A", "#46E6FF", "#E8FBFF")
        for s in (-1, 1):
            _crystals(kit, "Decor", s * 2.2, ry, 6.5, 2.0, gem, trim)
    elif theme == "lava":
        lava = kit.enamel("lave", "#FF6A12")
        flame_in = kit.enamel("flamme", "#FFD23A")
        for s in (-1, 1):
            _flame(kit, "Decor", s * 2.2, ry, 6.5, 0.8, lava, flame_in)
            for k in range(4):
                kit.add(kit.brick((0.08, 0.1, 0.9), center=(s * 2.2 + 0.38 * s, ry + 0.2, 1.6 + k * 1.1), rot=(0, s * 20, 0)),
                        lava, "Decor", bevel=0.0)
            for y in (ry - 1.2, ry + 1.2):
                kit.add(kit.wedge((0.5, 0.5, 0.8), center=(s * 2.2, y, 0.9), tip=0.1), dark, "Decor", bevel=0.0)
    elif theme == "royal":
        ruby = kit.gem("rubis", "#5A0A14", "#FF3A4A", "#FFE0E0")
        velvet = kit.mat("velours", "#B4142A", rough=0.75)
        _crown(kit, "Decor", 0, ry, 4.3, 2.6, trim, ruby, spikes=5)
        for s in (-1, 1):
            kit.add(kit.brick((1.2, 0.12, 2.0), center=(s * 3.1, ry - 0.2, 4.6)), velvet, "Decor", bevel=0.03)
            kit.add(kit.wedge((1.2, 0.12, 0.6), center=(s * 3.1, ry - 0.2, 3.3), rot=(180, 0, 0), tip=0.05), velvet, "Decor",
                    bevel=0.0)
            kit.add(kit.brick((1.3, 0.3, 0.2), center=(s * 2.75, ry - 0.2, 5.6)), trim, "Decor", bevel=0.03)
    elif theme == "cosmic":
        planet = kit.enamel("planete", tier["trim_hex"])
        for s in (-1, 1):
            for z, r, h in ((7.0, 0.5, 0.4), (7.45, 0.75, 0.5), (7.9, 0.5, 0.4)):
                kit.add(kit.cylinder(r, h, center=(s * 2.2, ry, z), rot=(0, 0, 22.5), sides=8), planet, "Decor", bevel=0.08)
            _octo_ring(kit, "Decor", (s * 2.2, ry, 7.45), 1.2, accent, plane="XY", size=0.18)
        _thruster(kit, "Decor", 0, 6.4, 0.9, chrome, accent, dark)
    elif theme == "celestial":
        gem = kit.gem("cristal_ciel", "#1E5A9A", "#7AC8FF", "#F0FAFF")
        feather = kit.pearl("plumes", color="#FBF8FF", sheen="#D8ECFF")
        _wings(kit, "Decor", 2.6, ry, 5.4, 3.2, 2.2, (feather, kit.pearl("plumes_ombre", color="#E8EEFA", sheen="#FFE8B0"), trim))
        _octo_ring(kit, "Decor", (0, ry, 7.8), 1.4, trim, plane="XY", size=0.4)
        _floor_plate(kit, "Decor", 15.0, 17.5, kit.pearl("socle", color="#F2F4FA", sheen="#FFE8B0"), trim, gem)


TIERS = {
    "Bois": dict(level=1, theme="wood", finish="wood", main="#B8783A", dark="#6E4626", accent="#5AE650", trim=None,
                 pad="#5A2A1E"),
    "Acier": dict(level=2, theme="steel", finish="steel", main="#D4D8E2", dark="#5E667A", accent="#2896FF", trim=None,
                  pad="#24242C"),
    "Sport": dict(level=3, theme="sport", finish="enamel", main="#E8283A", dark="#1E1E26", accent="#FFD21E",
                  trim="#F4F4F8", pad="#1E1E26"),
    "Or": dict(level=4, theme="gold", finish="gold", main="#FFC628", dark="#8A4A12", accent="#FF781E", trim="#FFC628",
               pad="#3A1E12"),
    "Jade": dict(level=5, theme="jade", finish="enamel", main="#1E9A5A", dark="#0E4A2E", accent="#6AFFB0",
                 trim="#FFC628", pad="#0E2A1E"),
    "Cristal": dict(level=6, theme="crystal", finish="enamel", main="#242840", dark="#141624", accent="#46E6FF",
                    trim="#FFC628", pad="#14162A"),
    "Lave": dict(level=7, theme="lava", finish="enamel", main="#2E2630", dark="#141014", accent="#FF6A12",
                 trim="#FFC23A", pad="#1A1012"),
    "Royal": dict(level=8, theme="royal", finish="enamel", main="#5A1E8A", dark="#2A0E44", accent="#FFD23A",
                  trim="#FFC628", pad="#B4142A"),
    "Cosmique": dict(level=9, theme="cosmic", finish="enamel", main="#2C184C", dark="#140A24", accent="#BE5AFF",
                     trim="#FF82EB", pad="#1E0E34", trim_hex="#FF82EB"),
    "Celeste": dict(level=10, theme="celestial", finish="enamel", main="#F6F8FF", dark="#C8D2E6", accent="#7AC8FF",
                    trim="#FFC628", pad="#F6F8FF"),
}
for _t in TIERS.values():
    _t.setdefault("trim_hex", _t["trim"] or _t["accent"])

__all__ = ["treadmill", "bench", "TIERS"]
