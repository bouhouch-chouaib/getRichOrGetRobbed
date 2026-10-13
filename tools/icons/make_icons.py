"""Dessine les icônes 2D du jeu (style cartoon Roblox : couleurs vives, ombrages simples, contours noirs épais).

Usage :  python tools/icons/make_icons.py
Sortie : assets/icons/<Nom>.png (256 x 256, fond transparent) + assets/icons/_planche.png (aperçu de toutes).

Chaque icône est dessinée en 1024 x 1024 : chaque forme a son contour noir (OUT), puis toute la silhouette reçoit
un gros contour noir extérieur (BORDER), et l'image est réduite à 256 x 256 (bords lisses).
Ce sont nos propres dessins : aucune image reprise d'un autre jeu.
"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

S = 1024
OUT = 22  # contour des formes
BORDER = 30  # gros contour extérieur de la silhouette
BLACK = (0, 0, 0, 255)
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "icons")
FONT_DIR = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\bouho\AppData\Local\Roblox\Versions\version-9b554450a0fc4e65\content\fonts"


def font(size, name="LuckiestGuy-Regular.ttf"):
    return ImageFont.truetype(os.path.join(FONT_DIR, name), size)


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def shade(color, amount):
    """amount > 0 : plus clair, < 0 : plus sombre."""
    r, g, b, a = color
    if amount >= 0:
        return (int(r + (255 - r) * amount), int(g + (255 - g) * amount), int(b + (255 - b) * amount), a)
    amount = -amount
    return (int(r * (1 - amount)), int(g * (1 - amount)), int(b * (1 - amount)), a)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Calque à part (pour tourner un groupe de formes).
    def layer(self):
        sub = Canvas()
        return sub

    def paste(self, sub, angle=0, center=(S / 2, S / 2)):
        image = sub.img
        if angle:
            image = image.rotate(angle, resample=Image.BICUBIC, center=center)
        self.img = Image.alpha_composite(self.img, image)

    @property
    def d(self):
        return ImageDraw.Draw(self.img)

    def ellipse(self, box, fill, out=OUT):
        self.d.ellipse(box, fill=fill, outline=BLACK if out else None, width=out)

    def circle(self, cx, cy, r, fill, out=OUT):
        self.ellipse((cx - r, cy - r, cx + r, cy + r), fill, out)

    def rrect(self, box, radius, fill, out=OUT):
        self.d.rounded_rectangle(box, radius=radius, fill=fill, outline=BLACK if out else None, width=out)

    def poly(self, points, fill, out=OUT):
        d = self.d
        d.polygon(points, fill=fill)
        if out:
            d.line(points + [points[0]], fill=BLACK, width=out, joint="curve")
            for x, y in points:
                d.ellipse((x - out / 2, y - out / 2, x + out / 2, y + out / 2), fill=BLACK)

    def line(self, points, fill, width):
        d = self.d
        d.line(points, fill=fill, width=width, joint="curve")
        for x, y in (points[0], points[-1]):
            d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=fill)

    def stroke_line(self, points, fill, width, out=OUT):
        """Trait épais coloré avec contour noir."""
        self.line(points, BLACK, width + out * 2)
        self.line(points, fill, width)

    def text(self, xy, value, size, fill, out=14, name="LuckiestGuy-Regular.ttf"):
        self.d.text(xy, value, font=font(size, name), fill=fill, anchor="mm", stroke_width=out, stroke_fill=BLACK)

    def shine(self, box, alpha=150):
        """Reflet blanc (sans contour), posé PAR-DESSUS la couleur (un calque à part, sinon il effacerait)."""
        glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse(box, fill=(255, 255, 255, alpha))
        self.img = Image.alpha_composite(self.img, glow)


def star_points(cx, cy, r_out, r_in, n=5, rotation=-90):
    points = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rotation + i * 180 / n)
        points.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return points


def finish(canvas):
    """Gros contour noir autour de toute la silhouette, puis réduction en 256 x 256."""
    alpha = np.array(canvas.img.split()[-1]) > 20
    yy, xx = np.ogrid[-BORDER : BORDER + 1, -BORDER : BORDER + 1]
    disk = xx * xx + yy * yy <= BORDER * BORDER
    grown = ndimage.binary_dilation(alpha, structure=disk)
    border = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mask = Image.fromarray((grown * 255).astype(np.uint8))
    border.paste(Image.new("RGBA", (S, S), BLACK), (0, 0), mask)
    result = Image.alpha_composite(border, canvas.img)
    return result.resize((256, 256), Image.LANCZOS)


ICONS = {}


def icon(name):
    def register(fn):
        ICONS[name] = fn
        return fn

    return register


# ----------------------------------------------------------------------------------------------------------
# Icônes
# ----------------------------------------------------------------------------------------------------------

GREEN = hexc("5ED63A")
GOLD = hexc("FFC928")


@icon("Money")
def money(c):
    # Trois billets empilés, inclinés, + pièces d'or.
    for index, (dx, dy, angle) in enumerate([(30, 120, 10), (0, 30, 4), (-20, -60, -4)]):
        sub = c.layer()
        x0, y0 = 170 + dx, 380 + dy
        sub.rrect((x0, y0, x0 + 620, y0 + 300), 40, shade(GREEN, -0.08 * (2 - index)))
        sub.rrect((x0 + 40, y0 + 40, x0 + 580, y0 + 260), 26, shade(GREEN, 0.25), out=12)
        sub.circle(x0 + 310, y0 + 150, 88, hexc("3FA92A"), out=12)
        sub.text((x0 + 310, y0 + 160), "$", 150, hexc("D9FFC9"), out=10)
        c.paste(sub, angle, (x0 + 310, y0 + 150))
    for cx, cy in [(760, 760), (650, 820)]:
        c.circle(cx, cy, 120, GOLD)
        c.circle(cx, cy, 78, shade(GOLD, 0.35), out=12)
        c.shine((cx - 80, cy - 90, cx - 20, cy - 40), 170)


@icon("Speed")
def speed(c):
    blue, white, red = hexc("2F9BFF"), hexc("FFFFFF"), hexc("FF4057")
    # Traits de vitesse.
    for y, x0 in [(380, 60), (520, 20), (660, 80)]:
        c.stroke_line([(x0, y), (x0 + 170, y)], hexc("BFE6FF"), 34, out=14)
    # Semelle.
    c.rrect((230, 700, 960, 820), 50, white)
    c.rrect((230, 770, 960, 820), 30, hexc("D7DDE8"), out=0)
    # Tige de la basket.
    c.poly([(270, 720), (290, 420), (470, 330), (560, 470), (760, 540), (930, 610), (950, 720)], blue)
    c.poly([(300, 450), (470, 360), (520, 440), (340, 520)], white, out=14)
    # Bande + lacets.
    c.poly([(420, 690), (560, 520), (650, 560), (520, 700)], red, out=14)
    for x in (600, 680, 760):
        c.stroke_line([(x - 30, 530), (x + 30, 560)], white, 22, out=10)
    c.shine((320, 600, 470, 660), 120)
    # Le « + » (achat de vitesse) en bas à droite, comme les HUD de simulateurs.
    c.circle(800, 300, 120, hexc("FFD43B"))
    c.text((800, 312), "+", 200, white, out=14)


@icon("Strength")
def strength(c):
    grey, dark, red = hexc("C9CED9"), hexc("3B3F4D"), hexc("FF4057")
    c.rrect((170, 470, 854, 554), 40, grey)
    c.shine((220, 485, 600, 510), 140)
    for side in (-1, 1):
        x = 512 + side * 250
        c.rrect((x - 60, 300, x + 60, 724), 40, dark)
        c.rrect((x + side * 70 - 45, 360, x + side * 70 + 45, 664), 30, shade(dark, 0.15))
        c.rrect((x + side * 140 - 30, 450, x + side * 140 + 30, 574), 20, red)
        c.shine((x - 40, 330, x - 5, 470), 90)


@icon("Shop")
def shop(c):
    red, grey, dark = hexc("FF4D5E"), hexc("D7DDE8"), hexc("2E3240")
    # Poignée.
    c.stroke_line([(90, 260), (210, 260), (300, 620)], grey, 46)
    # Panier.
    c.poly([(230, 330), (900, 330), (820, 640), (300, 640)], red)
    c.poly([(270, 380), (850, 380), (800, 580), (320, 580)], shade(red, 0.25), out=12)
    for x in (430, 560, 690):
        c.line([(x, 390), (x - 10, 570)], shade(red, -0.25), 18)
    c.stroke_line([(300, 700), (840, 700)], grey, 40)
    for x in (360, 760):
        c.circle(x, 810, 80, dark)
        c.circle(x, 810, 30, grey, out=10)
    c.shine((300, 400, 420, 460), 140)


@icon("Index")
def index(c):
    blue, page = hexc("2F9BFF"), hexc("FFF8E6")
    c.rrect((220, 170, 820, 880), 50, shade(blue, -0.25))
    c.rrect((270, 190, 840, 850), 30, page)
    for y in range(300, 800, 90):
        c.line([(340, y), (780, y)], hexc("D9CDB0"), 14)
    c.rrect((180, 140, 780, 830), 50, blue)
    c.rrect((180, 140, 290, 830), 40, shade(blue, -0.2))
    c.poly(star_points(530, 470, 170, 75), GOLD)
    c.shine((330, 200, 640, 260), 120)


@icon("Gem")
def gem(c):
    purple = hexc("C93DFF")
    top = [(512, 140), (820, 360), (512, 900), (204, 360)]
    c.poly(top, purple)
    c.poly([(512, 140), (820, 360), (512, 420), (204, 360)], shade(purple, 0.35), out=14)
    c.poly([(512, 420), (820, 360), (512, 900)], shade(purple, -0.2), out=14)
    c.shine((300, 280, 440, 340), 190)
    for cx, cy, r in [(830, 170, 70), (170, 760, 50)]:
        c.poly(star_points(cx, cy, r, r * 0.35, 4, -90), hexc("FFF3B0"), out=12)


@icon("Moon")
def moon(c):
    yellow = hexc("FFE36B")
    sub = c.layer()
    sub.circle(470, 430, 300, yellow)
    sub.circle(390, 380, 60, shade(yellow, -0.12), out=0)
    sub.circle(560, 560, 45, shade(yellow, -0.12), out=0)
    # Découpe du croissant : on efface un disque décalé.
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse((520, 60, 1000, 540), fill=255)
    cut = Image.new("L", (S, S), 0)
    ImageDraw.Draw(cut).ellipse((520 + OUT, 60 + OUT, 1000 - OUT, 540 - OUT), fill=255)
    alpha = np.array(sub.img.split()[-1]).astype(np.int32)
    rgba = np.array(sub.img)
    inner = np.array(cut) > 0
    ring = (np.array(mask) > 0) & ~inner & (alpha > 0)
    rgba[inner] = 0
    rgba[ring] = BLACK
    sub.img = Image.fromarray(rgba.astype(np.uint8))
    c.paste(sub)
    # Nuage devant.
    cloud = hexc("E9EEF8")
    for cx, cy, r in [(450, 760, 130), (620, 700, 160), (780, 770, 120), (330, 800, 100)]:
        c.circle(cx, cy, r, cloud)
    c.rrect((320, 760, 860, 890), 60, cloud, out=0)
    c.d.line([(260, 890), (900, 890)], fill=BLACK, width=OUT)


@icon("Sun")
def sun(c):
    yellow, orange = hexc("FFD43B"), hexc("FF9F1C")
    for i in range(10):
        a = math.radians(i * 36)
        x, y = 512 + math.cos(a) * 380, 512 + math.sin(a) * 380
        c.poly(
            [
                (512 + math.cos(a - 0.17) * 250, 512 + math.sin(a - 0.17) * 250),
                (x, y),
                (512 + math.cos(a + 0.17) * 250, 512 + math.sin(a + 0.17) * 250),
            ],
            orange,
        )
    c.circle(512, 512, 270, yellow)
    c.shine((350, 340, 480, 430), 150)


@icon("Lock")
def lock(c):
    gold, steel = GOLD, hexc("C9CED9")
    c.stroke_line([(330, 470), (330, 330)], steel, 70)
    c.stroke_line([(694, 470), (694, 330)], steel, 70)
    c.d.arc((330 - 35 - OUT, 150 - OUT, 694 + 35 + OUT, 510 + OUT), 180, 360, fill=BLACK, width=70 + 2 * OUT)
    c.d.arc((330 - 35, 150, 694 + 35, 510), 180, 360, fill=steel, width=70)
    c.rrect((200, 440, 824, 900), 70, gold)
    c.rrect((240, 480, 784, 600), 40, shade(gold, 0.3), out=0)
    c.circle(512, 640, 60, hexc("4A3A1A"), out=0)
    c.poly([(480, 650), (544, 650), (570, 790), (454, 790)], hexc("4A3A1A"), out=0)


@icon("Clover")
def clover(c):
    green = hexc("3ED15A")
    c.stroke_line([(560, 560), (700, 900)], hexc("2EA84A"), 46)
    for i in range(4):
        a = math.radians(45 + i * 90)
        cx, cy = 512 + math.cos(a) * 170, 470 + math.sin(a) * 170
        leaf = c.layer()
        leaf.circle(cx - 70, cy, 130, green if i % 2 == 0 else shade(green, 0.1))
        leaf.circle(cx + 70, cy, 130, green if i % 2 == 0 else shade(green, 0.1))
        c.paste(leaf)
    c.circle(512, 470, 70, shade(green, 0.45))
    c.shine((300, 260, 400, 320), 150)


@icon("Backpack")
def backpack(c):
    red, dark, buckle = hexc("FF4D5E"), hexc("B3263B"), GOLD
    c.stroke_line([(380, 230), (380, 140), (644, 140), (644, 230)], dark, 50)
    c.rrect((220, 220, 804, 900), 120, red)
    c.rrect((220, 220, 804, 420), 110, dark)
    c.rrect((310, 520, 714, 830), 60, shade(red, -0.15))
    c.rrect((470, 360, 554, 470), 20, buckle)
    c.rrect((480, 600, 544, 680), 18, buckle)
    c.shine((280, 450, 360, 640), 110)


@icon("Glove")
def glove(c):
    pink, cuff = hexc("FF7AC6"), hexc("FFFFFF")
    for i, x in enumerate((340, 450, 560, 670)):
        top = 220 if i in (1, 2) else 280
        c.rrect((x - 55, top, x + 55, 560), 55, pink)
    c.rrect((270, 400, 740, 760), 120, pink)
    thumb = c.layer()
    thumb.rrect((700, 420, 820, 680), 60, pink)
    c.paste(thumb, -30, (760, 550))
    c.rrect((250, 720, 760, 880), 50, cuff)
    c.shine((320, 470, 420, 620), 120)


@icon("Pan")
def pan(c):
    dark, inner, wood = hexc("3B3F4D"), hexc("6C7285"), hexc("A5652F")
    sub = c.layer()
    sub.rrect((560, 470, 960, 560), 40, wood)
    c.paste(sub, 20, (560, 515))
    c.circle(400, 540, 330, dark)
    c.circle(400, 540, 250, inner, out=14)
    c.circle(330, 470, 70, hexc("FFE36B"), out=12)
    c.shine((250, 330, 380, 390), 120)


@icon("Staff")
def staff(c):
    wood, orb = hexc("A5652F"), hexc("4FE3FF")
    c.stroke_line([(330, 920), (560, 400)], wood, 56)
    c.d.arc((350 - OUT, 110 - OUT, 850 + OUT, 610 + OUT), 200, 340, fill=BLACK, width=40 + 2 * OUT)
    c.d.arc((350, 110, 850, 610), 200, 340, fill=GOLD, width=40)
    c.circle(600, 330, 170, orb)
    c.circle(600, 330, 100, shade(orb, 0.55), out=0)
    for r in (250, 320):
        c.d.arc((600 - r, 330 - r, 600 + r, 330 + r), 300, 30, fill=hexc("BFF6FF"), width=18)


@icon("Treadmill")
def treadmill(c):
    blue, belt, screen = hexc("2F9BFF"), hexc("2E3240"), hexc("6BFF5A")
    c.poly([(120, 760), (880, 600), (920, 700), (160, 880)], blue)
    c.poly([(180, 760), (850, 618), (870, 670), (200, 820)], belt, out=12)
    c.stroke_line([(760, 640), (690, 260)], blue, 44)
    c.rrect((560, 150, 880, 330), 40, blue)
    c.rrect((610, 190, 830, 290), 24, screen, out=12)
    c.shine((610, 170, 760, 200), 120)


@icon("Bench")
def bench(c):
    pad, metal, plate = hexc("FF9F1C"), hexc("C9CED9"), hexc("3B3F4D")
    c.stroke_line([(300, 880), (320, 600)], metal, 40)
    c.stroke_line([(720, 880), (700, 600)], metal, 40)
    c.rrect((180, 560, 860, 680), 50, pad)
    c.shine((220, 575, 600, 610), 130)
    for x in (250, 770):
        c.stroke_line([(x, 560), (x, 260)], metal, 34)
    c.stroke_line([(120, 270), (900, 270)], metal, 34)
    for x in (150, 870):
        c.rrect((x - 45, 160, x + 45, 380), 30, plate)


@icon("Paw")
def paw(c):
    pad = hexc("FF9F1C")
    c.ellipse((290, 470, 734, 860), pad)
    for cx, cy, r in [(250, 400, 95), (400, 250, 105), (624, 250, 105), (774, 400, 95)]:
        c.circle(cx, cy, r, pad)
    c.shine((360, 520, 480, 600), 140)


@icon("Crown")
def crown(c):
    gold = GOLD
    pts = [(160, 780), (160, 330), (340, 520), (512, 230), (684, 520), (864, 330), (864, 780)]
    c.poly(pts, gold)
    c.rrect((140, 700, 884, 860), 40, shade(gold, -0.15))
    for cx, cy in [(160, 320), (512, 220), (864, 320)]:
        c.circle(cx, cy, 55, shade(gold, 0.45))
    for cx, color in [(330, "35A7FF"), (512, "FF3B5C"), (694, "3ED15A")]:
        c.circle(cx, 780, 52, hexc(color), out=14)
    c.shine((240, 420, 330, 560), 130)


@icon("Sparkle")
def sparkle(c):
    c.poly(star_points(470, 540, 380, 110, 4, -90), hexc("FFD43B"))
    c.poly(star_points(470, 540, 200, 60, 4, -90), hexc("FFF6B8"), out=0)
    c.poly(star_points(820, 220, 150, 45, 4, -90), hexc("FFE36B"))
    c.poly(star_points(830, 820, 100, 30, 4, -90), hexc("FFE36B"))


@icon("Dice")
def dice(c):
    white, red, black = hexc("FFFFFF"), hexc("FF4057"), hexc("23252E")
    c.poly([(512, 130), (880, 300), (512, 470), (144, 300)], white)
    c.poly([(144, 300), (512, 470), (512, 900), (144, 730)], hexc("D7DDE8"))
    c.poly([(512, 470), (880, 300), (880, 730), (512, 900)], hexc("BCC4D3"))
    c.ellipse((450, 260, 574, 340), red, out=0)
    for cx, cy in [(260, 470), (400, 700)]:
        c.ellipse((cx - 50, cy - 60, cx + 50, cy + 60), black, out=0)
    for cx, cy in [(620, 560), (700, 640), (780, 720), (780, 470), (620, 800)]:
        c.ellipse((cx - 42, cy - 52, cx + 42, cy + 52), black, out=0)


@icon("Gift")
def gift(c):
    box, ribbon = hexc("A855FF"), GOLD
    c.rrect((180, 450, 844, 900), 40, box)
    c.rrect((140, 330, 884, 480), 40, shade(box, 0.15))
    c.rrect((452, 330, 572, 900), 10, ribbon)
    for side in (-1, 1):
        bow = c.layer()
        bow.ellipse((512 - 60 + side * 150 - 130, 160, 512 - 60 + side * 150 + 130 + 120, 340), ribbon)
        c.paste(bow, side * -15, (512, 320))
    c.circle(512, 320, 60, shade(ribbon, -0.15))


@icon("Sprout")
def sprout(c):
    pot, leaf = hexc("D9773A"), hexc("5ED63A")
    c.stroke_line([(512, 640), (512, 360)], hexc("3FA92A"), 40)
    left = c.layer()
    left.ellipse((180, 260, 520, 460), leaf)
    c.paste(left, 20, (512, 380))
    right = c.layer()
    right.ellipse((504, 180, 860, 390), shade(leaf, 0.1))
    c.paste(right, -25, (512, 320))
    c.poly([(250, 620), (774, 620), (700, 920), (324, 920)], pot)
    c.rrect((220, 580, 804, 680), 30, shade(pot, -0.15))


@icon("Drop")
def drop(c):
    blue = hexc("35A7FF")
    c.poly([(512, 110), (760, 520), (264, 520)], blue, out=0)
    c.circle(512, 620, 260, blue, out=0)
    sub = c.layer()
    sub.poly([(512, 110), (760, 520), (264, 520)], blue)
    c.d.line([(512, 110), (750, 500)], fill=BLACK, width=OUT)
    c.d.line([(512, 110), (274, 500)], fill=BLACK, width=OUT)
    c.d.arc((252, 360, 772, 880), -30, 210, fill=BLACK, width=OUT)
    c.shine((370, 520, 450, 680), 170)


@icon("Orb")
def orb(c):
    glass, core = hexc("D7B8FF"), hexc("A855FF")
    c.rrect((300, 760, 724, 900), 40, GOLD)
    c.circle(512, 460, 330, glass)
    c.circle(512, 480, 190, core, out=0)
    c.circle(470, 430, 90, shade(core, 0.5), out=0)
    c.shine((330, 240, 470, 330), 190)


@icon("Flame")
def flame(c):
    outer, mid, inner = hexc("FF5A1F"), hexc("FF9F1C"), hexc("FFE36B")
    pts = [(512, 90), (700, 380), (820, 600), (760, 830), (512, 930), (264, 830), (204, 600), (330, 420), (420, 520)]
    c.poly(pts, outer)
    c.poly([(512, 330), (650, 560), (700, 720), (512, 860), (324, 720), (380, 560), (450, 620)], mid, out=14)
    c.poly([(512, 560), (600, 700), (512, 820), (424, 700)], inner, out=12)


@icon("Flower")
def flower(c):
    petal, centre = hexc("FF6FA8"), hexc("FFD43B")
    for i in range(5):
        a = math.radians(-90 + i * 72)
        c.circle(512 + math.cos(a) * 220, 512 + math.sin(a) * 220, 170, petal if i % 2 == 0 else shade(petal, 0.12))
    c.circle(512, 512, 150, centre)
    c.shine((440, 430, 510, 480), 170)


@icon("Trophy")
def trophy(c):
    gold = GOLD
    for side in (-1, 1):
        c.d.arc((512 + side * 230 - 150 - OUT, 220 - OUT, 512 + side * 230 + 150 + OUT, 520 + OUT), 0, 360, fill=BLACK, width=40 + 2 * OUT)
        c.d.arc((512 + side * 230 - 150, 220, 512 + side * 230 + 150, 520), 0, 360, fill=gold, width=40)
    c.poly([(250, 160), (774, 160), (700, 520), (512, 620), (324, 520)], gold)
    c.rrect((450, 600, 574, 760), 20, shade(gold, -0.15))
    c.rrect((300, 740, 724, 880), 40, hexc("A5652F"))
    c.poly(star_points(512, 360, 110, 50), shade(gold, 0.45), out=12)


@icon("Bat")
def bat(c):
    wood, dark, tape = hexc("E0A05C"), hexc("B0703A"), hexc("FF4057")
    sub = c.layer()
    # Batte en diagonale : manche fin en bas, fût large en haut.
    sub.rrect((470, 520, 554, 900), 40, hexc("2E3240"))
    sub.rrect((460, 780, 564, 830), 20, tape, out=12)
    sub.rrect((455, 640, 569, 690), 20, tape, out=12)
    sub.poly([(470, 540), (554, 540), (600, 180), (424, 180)], wood)
    sub.ellipse((424, 90, 600, 260), wood)
    sub.rrect((436, 300, 588, 340), 14, tape, out=12)
    sub.ellipse((440, 880, 584, 940), dark)
    sub.shine((455, 150, 500, 420), 140)
    c.paste(sub, -35, (512, 520))
    # Traits de mouvement.
    for y, x0 in [(330, 760), (430, 800), (530, 810)]:
        c.stroke_line([(x0, y), (x0 + 130, y - 40)], hexc("FFF3B0"), 26, out=12)


@icon("Grapple")
def grapple(c):
    blue, dark, steel, rope = hexc("3C96FF"), hexc("2E3240"), hexc("C9CED9"), hexc("A5652F")
    # Corde qui ondule vers le crochet.
    c.d.line([(560, 420), (640, 330), (700, 360), (770, 260)], fill=BLACK, width=26 + 2 * OUT, joint="curve")
    c.d.line([(560, 420), (640, 330), (700, 360), (770, 260)], fill=rope, width=26, joint="curve")
    # Crochet à trois griffes recourbées autour d'un moyeu.
    cx, cy = 790, 230
    for start in (-150, -30, 90):
        box = (cx - 135, cy - 135, cx + 135, cy + 135)
        c.d.arc(box, start, start + 75, fill=BLACK, width=36 + 2 * OUT)
        c.d.arc(box, start, start + 75, fill=steel, width=36)
        a = math.radians(start + 75)
        tx, ty = cx + math.cos(a) * 135, cy + math.sin(a) * 135
        c.circle(tx, ty, 26, steel, out=14)
    c.circle(cx, cy, 72, steel)
    c.circle(cx, cy, 30, hexc("8A93A6"), out=0)
    # Pistolet.
    c.rrect((150, 420, 640, 600), 50, blue)
    c.rrect((150, 470, 640, 510), 10, GOLD, out=12)
    c.rrect((560, 450, 700, 570), 30, steel)
    grip = c.layer()
    grip.rrect((230, 560, 360, 860), 40, dark)
    c.paste(grip, -12, (300, 600))
    c.circle(470, 610, 60, rope)
    c.shine((200, 440, 420, 470), 140)


@icon("Ghost")
def ghost(c):
    body = hexc("C8B4FF")
    # Corps de fantôme : tête ronde, bas ondulé.
    c.poly([(230, 480), (794, 480), (794, 860), (700, 800), (606, 880), (512, 800), (418, 880), (324, 800), (230, 860)], body, out=0)
    c.circle(512, 470, 282, body, out=0)
    pts = [(230, 470), (230, 860), (324, 800), (418, 880), (512, 800), (606, 880), (700, 800), (794, 860), (794, 470)]
    c.d.line(pts, fill=BLACK, width=OUT, joint="curve")
    c.d.arc((230, 188, 794, 752), 180, 360, fill=BLACK, width=OUT)
    c.ellipse((390, 400, 470, 520), hexc("2A1F45"), out=0)
    c.ellipse((554, 400, 634, 520), hexc("2A1F45"), out=0)
    c.ellipse((470, 560, 554, 640), hexc("2A1F45"), out=0)
    c.shine((300, 280, 400, 380), 170)
    for cx, cy, r in [(840, 230, 70), (170, 300, 50)]:
        c.poly(star_points(cx, cy, r, r * 0.35, 4, -90), hexc("FFF3B0"), out=12)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    rendered = []
    for name, fn in ICONS.items():
        canvas = Canvas()
        fn(canvas)
        image = finish(canvas)
        image.save(os.path.join(OUT_DIR, name + ".png"))
        rendered.append((name, image))
    # Planche d'aperçu sur le fond sombre des fenêtres.
    columns = 7
    rows = math.ceil(len(rendered) / columns)
    sheet = Image.new("RGBA", (columns * 270, rows * 300), hexc("2F2E3E"))
    draw = ImageDraw.Draw(sheet)
    for i, (name, image) in enumerate(rendered):
        x, y = (i % columns) * 270 + 7, (i // columns) * 300 + 4
        sheet.alpha_composite(image, (x, y))
        draw.text((x + 128, y + 275), name, font=font(26, "FredokaOne-Regular.ttf"), fill=(255, 255, 255, 255), anchor="mm")
    sheet.save(os.path.join(OUT_DIR, "_planche.png"))
    print("ok", len(rendered))


if __name__ == "__main__":
    main()
