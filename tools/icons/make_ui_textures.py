"""Textures de l'interface (16 oct. 2026), dessinées en blanc / gris pour être teintées dans Roblox (ImageColor3).

    python tools/icons/make_ui_textures.py assets/ui

  Stud.png     : un tenon en relief (reflet en haut à gauche, ombre en bas à droite), à répéter (ScaleType Tile).
  Shards.png   : grands éclats de lumière en diagonale (en-têtes des fenêtres, façon « Studs UI Pack »).
  Rays.png     : rayons de soleil blancs qui s'effacent vers l'extérieur (derrière les offres, les cartes rares).
  Glow.png     : halo rond doux.
  Shadow.png   : ombre douce (9-slice, centre 64..192) sous les fenêtres.
  Shine.png    : reflet diagonal étroit qui balaie les boutons.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

out = Path(sys.argv[1] if len(sys.argv) > 1 else 'assets/ui')
out.mkdir(parents=True, exist_ok=True)
S = 4  # suréchantillonnage


def down(im, size):
    return im.resize(size, Image.LANCZOS)


# Tenon : 64 x 64, ombre portée + cylindre + reflet.
def stud():
    n = 64 * S
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    shadow = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(shadow)
    r = 21 * S
    c = n // 2
    d.ellipse((c - r + 3 * S, c - r + 5 * S, c + r + 3 * S, c + r + 5 * S), fill=(0, 0, 0, 55))
    shadow = shadow.filter(ImageFilter.GaussianBlur(3 * S))
    im.alpha_composite(shadow)
    body = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.ellipse((c - r, c - r, c + r, c + r), fill=(205, 205, 205, 255))
    # dégradé : haut clair, bas sombre
    grad = Image.new('L', (n, n))
    for y in range(n):
        v = int(250 - (y / n) * 70)
        ImageDraw.Draw(grad).line([(0, y), (n, y)], fill=v)
    shade = Image.merge('RGBA', (grad, grad, grad, body.split()[3]))
    im.alpha_composite(shade)
    # reflet
    hl = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(hl)
    d.ellipse((c - r * 0.65, c - r * 0.75, c + r * 0.1, c - r * 0.15), fill=(255, 255, 255, 90))
    hl = hl.filter(ImageFilter.GaussianBlur(2 * S))
    im.alpha_composite(hl)
    # bord sombre
    d = ImageDraw.Draw(im)
    d.ellipse((c - r, c - r, c + r, c + r), outline=(170, 170, 170, 255), width=2 * S)
    down(im, (64, 64)).save(out / 'Stud.png')


def shards():
    w, h = 1024 * 2, 256 * 2
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    polys = [
        ([(0.52, 0), (0.70, 0), (0.58, 1), (0.40, 1)], 70),
        ([(0.74, 0), (0.80, 0), (0.68, 1), (0.62, 1)], 55),
        ([(0.86, 0), (1.0, 0), (1.0, 0.25), (0.83, 1), (0.74, 1)], 45),
        ([(0.10, 0), (0.16, 0), (0.06, 1), (0.0, 1), (0.0, 0.6)], 35),
        ([(0.30, 0), (0.44, 0), (0.30, 1), (0.22, 1)], 28),
    ]
    for pts, a in polys:
        d.polygon([(x * w, y * h) for x, y in pts], fill=(255, 255, 255, a))
    down(im, (1024, 256)).save(out / 'Shards.png')


def rays():
    n = 512 * 2
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = n / 2
    count = 16
    for i in range(count):
        a0 = (i / count) * 2 * math.pi
        a1 = a0 + math.pi / count * 0.9
        d.polygon([(c, c), (c + math.cos(a0) * n, c + math.sin(a0) * n), (c + math.cos(a1) * n, c + math.sin(a1) * n)],
                  fill=(255, 255, 255, 255))
    # s'efface vers l'extérieur
    mask = Image.new('L', (n, n), 0)
    md = ImageDraw.Draw(mask)
    for r in range(int(c), 0, -2):
        v = int(255 * (1 - r / c) ** 1.3)
        md.ellipse((c - r, c - r, c + r, c + r), fill=v)
    alpha = Image.composite(im.split()[3], Image.new('L', (n, n), 0), mask)
    alpha = Image.eval(alpha, lambda v: min(v, 255))
    out_im = Image.new('RGBA', (n, n), (255, 255, 255, 0))
    out_im.putalpha(Image.fromarray(__import__('numpy').minimum(__import__('numpy').array(alpha), __import__('numpy').array(mask))))
    down(out_im, (512, 512)).save(out / 'Rays.png')


def glow():
    n = 256
    im = Image.new('L', (n, n), 0)
    d = ImageDraw.Draw(im)
    c = n / 2
    for r in range(int(c), 0, -1):
        v = int(255 * (1 - r / c) ** 2)
        d.ellipse((c - r, c - r, c + r, c + r), fill=v)
    rgba = Image.new('RGBA', (n, n), (255, 255, 255, 0))
    rgba.putalpha(im)
    rgba.save(out / 'Glow.png')


def shadow():
    n = 256
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((48, 48, n - 48, n - 48), radius=24, fill=(0, 0, 0, 200))
    im = im.filter(ImageFilter.GaussianBlur(18))
    im.save(out / 'Shadow.png')


def shine():
    w, h = 256, 256
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(90, 0), (150, 0), (110, h), (50, h)], fill=(255, 255, 255, 170))
    d.polygon([(165, 0), (185, 0), (145, h), (125, h)], fill=(255, 255, 255, 120))
    im = im.filter(ImageFilter.GaussianBlur(3))
    im.save(out / 'Shine.png')


stud()
shards()
rays()
glow()
shadow()
shine()
print('ok', sorted(p.name for p in out.iterdir()))
