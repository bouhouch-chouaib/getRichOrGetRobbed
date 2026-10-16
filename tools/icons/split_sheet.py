"""Découpe une planche d'icônes à fond transparent en icônes séparées.

usage: python split_sheet.py planche.png dossier_sortie nom1,nom2,... [taille]
Les icônes sont trouvées par zones opaques connectées (après fusion des petits morceaux proches), triées en lignes
puis de gauche à droite, recadrées en carré avec une marge et redimensionnées (taille, 256 par défaut).
"""
import sys
from PIL import Image
import numpy as np
from scipy import ndimage

src, out, names = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
size = int(sys.argv[4]) if len(sys.argv) > 4 else 256

im = Image.open(src).convert('RGBA')
alpha = np.array(im)[:, :, 3]
mask = alpha > 24
# Fusionne les morceaux d'une même icône (étincelles, lignes de vitesse) séparés de quelques pixels.
grown = ndimage.binary_dilation(mask, iterations=max(6, im.width // 120))
labels, count = ndimage.label(grown)
boxes = ndimage.find_objects(labels)
areas = ndimage.sum(mask, labels, range(1, count + 1))
items = [(b, a) for b, a in zip(boxes, areas) if a > mask.sum() * 0.01]
print('found', len(items), 'icons, expected', len(names))
# Tri en lignes : on regroupe par centre vertical.
items.sort(key=lambda it: (it[0][0].start + it[0][0].stop) / 2)
rows = []
for it in items:
    cy = (it[0][0].start + it[0][0].stop) / 2
    for row in rows:
        ry = (row[0][0][0].start + row[0][0][0].stop) / 2
        if abs(cy - ry) < (row[0][0][0].stop - row[0][0][0].start) * 0.6:
            row.append(it)
            break
    else:
        rows.append([it])
ordered = []
for row in rows:
    row.sort(key=lambda it: it[0][1].start)
    ordered.extend(row)
for (sy, sx), _a in [(it[0], it[1]) for it in ordered]:
    pass
for index, (box, _a) in enumerate(ordered):
    if index >= len(names):
        break
    sy, sx = box
    crop = im.crop((sx.start, sy.start, sx.stop, sy.stop))
    # Ne garder que les pixels de cette icône (pas un bout de la voisine dans le rectangle).
    lab = labels[sy, sx] == labels[sy, sx][labels[sy, sx] > 0].max() if False else None
    w, h = crop.size
    side = int(max(w, h) * 1.08)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(crop, ((side - w) // 2, (side - h) // 2))
    canvas = canvas.resize((size, size), Image.LANCZOS)
    canvas.save(f'{out}/{names[index]}.png')
    print(names[index], (sx.start, sy.start, w, h))
