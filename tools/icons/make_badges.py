"""Images des badges Roblox (Config.Badges), 512 x 512, à envoyer quand on crée chaque badge sur create.roblox.com.

    python tools/icons/make_badges.py assets/badges

Roblox affiche les badges en rond : un disque coloré à rayons + bord doré, l'icône du jeu au centre (assets/icons/forgegui),
et un petit chiffre pour les badges de collection.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

out = Path(sys.argv[1] if len(sys.argv) > 1 else 'assets/badges')
out.mkdir(parents=True, exist_ok=True)
ICONS = Path('assets/icons/forgegui')
N = 512

BADGES = {
    'Welcome': ('Gift', (255, 196, 40), None),
    'FirstHatch': ('Egg', (90, 170, 255), None),
    'FirstSteal': ('Paw', (240, 70, 90), None),
    'DuelWin': ('Trophy', (255, 150, 40), None),
    'WorldDesert': ('Planet', (240, 190, 90), None),
    'WorldCosmos': ('Vortex', (120, 70, 220), None),
    'WorldDivin': ('Sparkle', (255, 220, 120), None),
    'FirstRebirth': ('Rebirth', (170, 90, 255), None),
    'Index25': ('Index', (54, 204, 254), '25'),
    'Index50': ('Index', (40, 170, 230), '50'),
    'Index75': ('Index', (30, 130, 210), '75'),
    'Ultime': ('Egg', (255, 205, 50), 'ULTIME'),
    'Sigma': ('Crown', (255, 90, 160), None),
}


def font(size):
    for name in ('arialbd.ttf', 'seguisb.ttf', 'DejaVuSans-Bold.ttf'):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


for key, (icon_name, color, label) in BADGES.items():
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = N / 2
    light = tuple(min(255, int(v * 0.6 + 255 * 0.4)) for v in color)
    dark = tuple(int(v * 0.6) for v in color)
    # Disque : dégradé radial du clair au foncé.
    for r in range(int(c), 0, -2):
        t = r / c
        col = tuple(int(light[i] * (1 - t) + dark[i] * t) for i in range(3))
        d.ellipse((c - r, c - r, c + r, c + r), fill=col + (255,))
    # Rayons.
    rays = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    for i in range(16):
        a0 = i / 16 * 2 * math.pi
        a1 = a0 + math.pi / 32
        rd.polygon([(c, c), (c + math.cos(a0) * N, c + math.sin(a0) * N), (c + math.cos(a1) * N, c + math.sin(a1) * N)],
                   fill=(255, 255, 255, 55))
    mask = Image.new('L', (N, N), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, N, N), fill=255)
    rays.putalpha(Image.fromarray(__import__('numpy').minimum(__import__('numpy').array(rays.split()[3]), __import__('numpy').array(mask))))
    im.alpha_composite(rays)
    # Bord doré + liseré sombre.
    d = ImageDraw.Draw(im)
    d.ellipse((6, 6, N - 6, N - 6), outline=(22, 24, 52, 255), width=14)
    d.ellipse((18, 18, N - 18, N - 18), outline=(255, 210, 70, 255), width=12)
    # Icône.
    icon = Image.open(ICONS / f'{icon_name}.png').convert('RGBA')
    size = 300 if label else 330
    icon = icon.resize((size, size), Image.LANCZOS)
    shadow = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    sh = Image.new('RGBA', icon.size, (0, 0, 0, 120))
    sh.putalpha(icon.split()[3].point(lambda v: int(v * 0.45)))
    y = int(c - size / 2 - (30 if label else 0))
    shadow.paste(sh, (int(c - size / 2) + 6, y + 12), sh)
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
    im.alpha_composite(icon, (int(c - size / 2), y))
    # Chiffre / étoiles : texte blanc à gros contour.
    if label:
        f = font(96 if label[0].isdigit() else 64)
        box = d.textbbox((0, 0), label, font=f, stroke_width=10)
        w = box[2] - box[0]
        d.text((c - w / 2, N - 170), label, font=f, fill=(255, 255, 255, 255), stroke_width=10,
               stroke_fill=(22, 24, 52, 255))
    im.save(out / f'{key}.png')
print('ok', len(BADGES))
