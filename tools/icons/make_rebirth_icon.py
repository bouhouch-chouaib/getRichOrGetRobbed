"""Icône Rebirth (16 oct. 2026) : une boucle de recommencement, deux flèches courbes (rouge et blanche) qui se
poursuivent en cercle, dans le style des icônes ForgeGUI (3D brillant, gros contour bleu nuit).

    python tools/icons/make_rebirth_icon.py assets/icons/forgegui/Rebirth.png
"""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1] if len(sys.argv) > 1 else 'Rebirth.png'
S = 4
N = 256 * S
C = N / 2
NAVY = (22, 24, 52, 255)


def arrow_polygon(a0, a1, r, thick, head_len, head_wide):
    """Bande d'arc de a0 à a1 (degrés, sens horaire écran) + pointe de flèche au bout a1."""
    pts_out, pts_in = [], []
    steps = 60
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts_out.append((C + math.cos(a) * (r + thick / 2), C + math.sin(a) * (r + thick / 2)))
        pts_in.append((C + math.cos(a) * (r - thick / 2), C + math.sin(a) * (r - thick / 2)))
    body = pts_out + pts_in[::-1]
    a = math.radians(a1)
    tip_a = math.radians(a1 + head_len)
    base_out = (C + math.cos(a) * (r + head_wide / 2), C + math.sin(a) * (r + head_wide / 2))
    base_in = (C + math.cos(a) * (r - head_wide / 2), C + math.sin(a) * (r - head_wide / 2))
    tip = (C + math.cos(tip_a) * r, C + math.sin(tip_a) * r)
    return body, [base_out, tip, base_in]


def shape_mask(polys, grow=0):
    m = Image.new('L', (N, N), 0)
    d = ImageDraw.Draw(m)
    for p in polys:
        d.polygon(p, fill=255)
    if grow:
        m = m.filter(ImageFilter.MaxFilter(grow * 2 + 1))
    return m


def shaded(mask, top, bottom, light_dir):
    """Remplit le masque d'un dégradé vertical, puis un reflet blanc étroit sur le haut de la forme."""
    grad = np.zeros((N, N, 3), dtype=float)
    t = np.linspace(0, 1, N)[:, None]
    for c in range(3):
        grad[:, :, c] = top[c] * (1 - t) + bottom[c] * t
    img = Image.fromarray(grad.astype('uint8'), 'RGB').convert('RGBA')
    img.putalpha(mask)
    # Reflet : la forme rétrécie, moins elle-même décalée vers le bas => un liseré clair sur les bords du haut.
    inner = np.array(mask.filter(ImageFilter.MinFilter(5 * S + 1))).astype(int)
    lower = np.zeros_like(inner)
    dy = light_dir[1] * 2
    lower[dy:, :] = inner[:-dy, :]
    rim = (inner - lower).clip(0, 255).astype('uint8')
    gloss = Image.new('RGBA', (N, N), (255, 255, 255, 0))
    gloss.putalpha(Image.fromarray(rim).filter(ImageFilter.GaussianBlur(2 * S)).point(lambda v: int(v * 0.6)))
    img.alpha_composite(gloss)
    return img


R = 80 * S
THICK = 34 * S
HEAD_LEN = 28
HEAD_WIDE = 70 * S
# Flèche rouge : de 200° à 330° (en haut, tourne vers la droite) ; flèche blanche : de 20° à 150° (en bas).
red_body, red_head = arrow_polygon(195, 325, R, THICK, HEAD_LEN, HEAD_WIDE)
white_body, white_head = arrow_polygon(15, 145, R, THICK, HEAD_LEN, HEAD_WIDE)

canvas = Image.new('RGBA', (N, N), (0, 0, 0, 0))
# Ombre portée douce.
shadow = shape_mask([red_body, red_head, white_body, white_head], grow=11 * S)
sh = Image.new('RGBA', (N, N), (0, 0, 0, 0))
sh.putalpha(shadow.filter(ImageFilter.GaussianBlur(6 * S)).point(lambda v: int(v * 0.35)))
canvas.alpha_composite(sh, (0, 6 * S))
# Gros contour bleu nuit.
outline = shape_mask([red_body, red_head, white_body, white_head], grow=9 * S)
ol = Image.new('RGBA', (N, N), NAVY)
ol.putalpha(outline)
canvas.alpha_composite(ol)
# Les deux flèches.
red = shaded(shape_mask([red_body, red_head]), (255, 58, 58), (205, 0, 28), (3 * S, 4 * S))
white = shaded(shape_mask([white_body, white_head]), (255, 255, 255), (178, 190, 222), (3 * S, 4 * S))
canvas.alpha_composite(white)
canvas.alpha_composite(red)
# Fin trait sombre entre les couleurs et le contour (relief).
for m in (shape_mask([red_body, red_head]), shape_mask([white_body, white_head])):
    edge = np.array(m.filter(ImageFilter.MaxFilter(2 * S + 1))).astype(int) - np.array(m).astype(int)
    e = Image.new('RGBA', (N, N), (10, 12, 30, 255))
    e.putalpha(Image.fromarray(edge.clip(0, 255).astype('uint8')))
    canvas.alpha_composite(e)
# Petite étoile dorée au centre (renaissance).
star = []
for i in range(10):
    a = math.radians(-90 + i * 36)
    rr = (28 if i % 2 == 0 else 12) * S
    star.append((C + math.cos(a) * rr, C + math.sin(a) * rr))
sm = shape_mask([star])
so = Image.new('RGBA', (N, N), NAVY)
so.putalpha(sm.filter(ImageFilter.MaxFilter(6 * S + 1)))
canvas.alpha_composite(so)
canvas.alpha_composite(shaded(sm, (255, 236, 110), (240, 160, 20), (2 * S, 3 * S)))

canvas = canvas.resize((256, 256), Image.LANCZOS)
canvas.save(out)
print('ok', out)
