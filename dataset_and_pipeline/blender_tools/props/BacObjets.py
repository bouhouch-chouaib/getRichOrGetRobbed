"""Bac à objets (26 oct., Chouaib : « deux bacs de chaque côté de la base où les objets spawneront ») : grande caisse
de marché en planches, ouverte en haut, sans lueur.

Deux bacs par base, dehors contre les côtés, près de l'entrée (shared/BaseLayout.Bins) : les objets à jeter y tombent
et le joueur les prend sans entrer dans sa base. Pièce « Bin » (bois, ferrures) et pièce « Trim » (rebord, chapeaux des
poteaux, losanges) cuite en blanc : le jeu la teinte à la couleur de la base (SurfaceAppearance.Color,
server/MapGenerator). Les collisions (fond, parois) sont des volumes invisibles posés par le jeu.

Repère : 7 studs de large (X), 10 de long (Y Blender = Z Roblox), fond intérieur à 0,86, rebord à 2,7.
"""

from pet_kit import PetKit


def build(name: str) -> dict:
    kit = PetKit(name)
    wood = kit.mat("bois_bac", "#C88A4A", rough=0.55)
    plank = kit.mat("planches_bac", "#DBA060", rough=0.6)
    dark = kit.mat("bois_bac_fonce", "#6E4626", rough=0.6)
    iron = kit.mat("ferrures", "#4A4A58", rough=0.35, metal=0.6)
    trim = kit.enamel("lisere", "#FFFFFF")
    W, L = 3.25, 4.75  # milieu des parois

    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.add(kit.brick((0.9, 0.9, 0.4), center=(sx * 3.0, sy * 4.5, 0.2)), dark, "Bin", bevel=0.08)
    kit.add(kit.brick((7.0, 10.0, 0.4), center=(0, 0, 0.6)), dark, "Bin", bevel=0.08)
    for k in range(6):
        kit.add(kit.brick((0.94, 9.0, 0.06), center=(-2.5 + k * 1.0, 0, 0.84)), plank, "Bin", bevel=0.02)

    # parois : fond sombre et trois planches par paroi, joints visibles
    for s in (-1, 1):
        kit.add(kit.brick((0.36, 9.6, 2.0), center=(s * W, 0, 1.45)), dark, "Bin", bevel=0.04)
        kit.add(kit.brick((6.2, 0.36, 2.0), center=(0, s * L, 1.45)), dark, "Bin", bevel=0.04)
        for z in (0.74, 1.44, 2.14):
            kit.add(kit.brick((0.5, 9.0, 0.64), center=(s * W, 0, z)), wood, "Bin", bevel=0.06)
            kit.add(kit.brick((5.9, 0.5, 0.64), center=(0, s * L, z)), wood, "Bin", bevel=0.06)
    # poteaux d'angle et leurs chapeaux
    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.add(kit.brick((0.9, 0.9, 2.9), center=(sx * W, sy * L, 1.45)), wood, "Bin", bevel=0.08)
            kit.add(kit.brick((1.04, 1.04, 0.24), center=(sx * W, sy * L, 3.0)), trim, "Trim", bevel=0.06)
    # rebord teinté tout autour
    for s in (-1, 1):
        kit.add(kit.brick((0.72, 8.6, 0.22), center=(s * W, 0, 2.6)), trim, "Trim", bevel=0.05)
        kit.add(kit.brick((5.6, 0.72, 0.22), center=(0, s * L, 2.6)), trim, "Trim", bevel=0.05)
    # ferrures : équerres sur les flancs, vis, poignées aux deux bouts
    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.add(kit.brick((0.06, 0.9, 0.22), center=(sx * 3.54, sy * 3.95, 2.14)), iron, "Bin", bevel=0.0)
            kit.add(kit.brick((0.06, 0.9, 0.22), center=(sx * 3.54, sy * 3.95, 0.74)), iron, "Bin", bevel=0.0)
            kit.add(kit.brick((0.9, 0.06, 0.22), center=(sx * 2.45, sy * 5.04, 2.14)), iron, "Bin", bevel=0.0)
            kit.add(kit.brick((0.9, 0.06, 0.22), center=(sx * 2.45, sy * 5.04, 0.74)), iron, "Bin", bevel=0.0)
            for z in (2.14, 0.74):
                kit.add(kit.disc(0.06, 0.04, center=(sx * 3.57, sy * 3.7, z), normal=(sx, 0, 0), sides=8), iron, "Bin",
                        bevel=0.0)
    for sy in (-1, 1):
        kit.add(kit.brick((1.8, 0.14, 0.14), center=(0, sy * 5.35, 1.9)), iron, "Bin", bevel=0.02)
        for sx in (-1, 1):
            kit.add(kit.brick((0.14, 0.34, 0.14), center=(sx * 0.83, sy * 5.17, 1.9)), iron, "Bin", bevel=0.02)
    # grand losange teinté au milieu de chaque flanc (cadre sombre derrière)
    for s in (-1, 1):
        kit.add(kit.brick((0.06, 1.3, 1.3), center=(s * 3.52, 0, 1.44), rot=(45, 0, 0)), dark, "Bin", bevel=0.02)
        kit.add(kit.brick((0.08, 1.0, 1.0), center=(s * 3.55, 0, 1.44), rot=(45, 0, 0)), trim, "Trim", bevel=0.03)
    return kit.result()
