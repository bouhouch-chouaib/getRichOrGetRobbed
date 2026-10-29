"""Image du badge « Halloween 2026 » (Config.Badges, Key Halloween2026), 512 x 512, même style que make_badges.py :
disque à rayons (violet de nuit), bord doré, au centre la citrouille sculptée du jeu (rendu Blender de
props/Objets_Halloween.py, assets/icons/halloween_lantern.png) cernée de sombre, deux chauves-souris, « 2026 ».

    python tools/icons/make_badge_halloween.py assets/badges
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out = Path(sys.argv[1] if len(sys.argv) > 1 else 'assets/badges')
out.mkdir(parents=True, exist_ok=True)
N = 512
c = N / 2
INK = (22, 24, 52)
color = (120, 50, 190)


def font(size):
    for name in ('arialbd.ttf', 'seguisb.ttf', 'DejaVuSans-Bold.ttf'):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
light = tuple(min(255, int(v * 0.6 + 255 * 0.4)) for v in color)
dark = tuple(int(v * 0.45) for v in color)
for r in range(int(c), 0, -2):  # disque : clair au centre, nuit au bord
    t = r / c
    col = tuple(int(light[i] * (1 - t) + dark[i] * t) for i in range(3))
    d.ellipse((c - r, c - r, c + r, c + r), fill=col + (255,))
rays = Image.new('RGBA', (N, N), (0, 0, 0, 0))
rd = ImageDraw.Draw(rays)
for i in range(16):
    a0 = i / 16 * 2 * math.pi
    a1 = a0 + math.pi / 32
    rd.polygon([(c, c), (c + math.cos(a0) * N, c + math.sin(a0) * N), (c + math.cos(a1) * N, c + math.sin(a1) * N)],
               fill=(255, 190, 120, 45))
mask = Image.new('L', (N, N), 0)
ImageDraw.Draw(mask).ellipse((0, 0, N, N), fill=255)
rays.putalpha(Image.fromarray(np.minimum(np.array(rays.split()[3]), np.array(mask))))
im.alpha_composite(rays)


def bat(cx, cy, s, angle):
    """Chauve-souris en silhouette (ailes à trois pointes, petites oreilles)."""
    pts = [(-1.0, -0.2), (-0.72, -0.36), (-0.4, -0.3), (-0.16, -0.08), (-0.13, -0.36), (-0.05, -0.18), (0.05, -0.18),
           (0.13, -0.36), (0.16, -0.08), (0.4, -0.3), (0.72, -0.36), (1.0, -0.2), (0.78, 0.08), (0.62, -0.02),
           (0.48, 0.16), (0.32, 0.04), (0.16, 0.22), (0.0, 0.32), (-0.16, 0.22), (-0.32, 0.04), (-0.48, 0.16),
           (-0.62, -0.02), (-0.78, 0.08)]
    a = math.radians(angle)
    poly = [(cx + (x * math.cos(a) - y * math.sin(a)) * s, cy + (x * math.sin(a) + y * math.cos(a)) * s) for x, y in pts]
    ImageDraw.Draw(im).polygon(poly, fill=INK + (235,))


bat(138, 150, 64, -14)
bat(380, 128, 50, 12)

# Bord doré + liseré sombre (comme les autres badges).
d = ImageDraw.Draw(im)
d.ellipse((6, 6, N - 6, N - 6), outline=INK + (255,), width=14)
d.ellipse((18, 18, N - 18, N - 18), outline=(255, 210, 70, 255), width=12)

# Citrouille : rognée, mise à l'échelle, contour sombre épais puis ombre.
src = Image.open('assets/icons/halloween_lantern.png').convert('RGBA')
src = src.crop(src.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox())
w = 262
icon = src.resize((w, int(src.height * w / src.width)), Image.LANCZOS)
x, y = int(c - icon.width / 2), int(c - icon.height / 2 - 44)
alpha = icon.split()[3]
outline = Image.new('RGBA', (icon.width + 24, icon.height + 24), (0, 0, 0, 0))
big = Image.new('L', outline.size, 0)
big.paste(alpha, (12, 12))
big = big.filter(ImageFilter.MaxFilter(15)).point(lambda v: 255 if v > 40 else 0)
outline.paste(Image.new('RGBA', outline.size, INK + (255,)), (0, 0), big)
shadow = Image.new('RGBA', (N, N), (0, 0, 0, 0))
sh = Image.new('RGBA', outline.size, (0, 0, 0, 0))
sh.paste(Image.new('RGBA', outline.size, (0, 0, 0, 110)), (0, 0), big)
shadow.paste(sh, (x - 12 + 6, y - 12 + 12), sh)
im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
im.alpha_composite(outline, (x - 12, y - 12))
im.alpha_composite(icon, (x, y))

# « 2026 » en blanc, gros contour sombre.
label = '2026'
f = font(84)
box = d.textbbox((0, 0), label, font=f, stroke_width=10)
d = ImageDraw.Draw(im)
d.text((c - (box[2] - box[0]) / 2, N - 150), label, font=f, fill=(255, 255, 255, 255), stroke_width=10,
       stroke_fill=INK + (255,))
im.save(out / 'Halloween2026.png')
print('ok', out / 'Halloween2026.png')
