# Images des passes Robux pour la page du jeu (Creator Hub -> Monétisation -> Passes -> le passe -> image).
# 512 x 512, fond en rayons de soleil à la couleur du passe, icône du jeu (assets/icons/forgegui) au centre et gros
# texte à la police du jeu (LuckiestGuy) quand il aide à comprendre. Tout l'important reste dans le cercle central.
#   python tools/store/make_pass_images.py <police LuckiestGuy .ttf> <dossier des icônes> <dossier de sortie>
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT, ICONS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
S = 512

# Id du passe (Config.Monetization.GamePasses) : icône, couleur claire, couleur foncée, texte
PASSES = {
    # chaque icône sur une couleur qui la fait ressortir (billets verts sur or, couronne d'or sur rouge...)
    "DoubleMoney": ("Money", (255, 220, 90), (200, 120, 10), "2X"),
    "VIP": ("Crown", (255, 110, 110), (150, 20, 40), "VIP"),
    "Vacuum": ("Vortex", (90, 110, 230), (20, 20, 80), ""),
    "ExtraBackpack": ("Backpack", (110, 235, 220), (10, 120, 120), "+1"),
    "EquipPlus2": ("Paw", (110, 210, 255), (30, 80, 190), "+2"),
    "LuckyLuck": ("Clover", (255, 150, 210), (170, 40, 120), ""),
}


def background(light, dark):
    img = Image.new("RGBA", (S, S), dark + (255,))
    # dégradé radial : clair au centre, foncé sur les bords
    rad = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(rad)
    for r in range(S // 2 + 80, 0, -4):
        v = int(255 * (1 - r / (S / 2 + 80)) ** 0.8)
        d.ellipse([S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r], fill=v)
    img = Image.composite(Image.new("RGBA", (S, S), light + (255,)), img, rad)
    # rayons
    rays = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(rays)
    for i in range(16):
        a0 = i * 2 * math.pi / 16
        a1 = a0 + math.pi / 16
        pts = [(S / 2, S / 2)] + [(S / 2 + 600 * math.cos(a), S / 2 + 600 * math.sin(a)) for a in (a0, a1)]
        d.polygon(pts, fill=46)
    img = Image.composite(Image.new("RGBA", (S, S), (255, 255, 255, 255)), img, rays)
    # tenons discrets en damier, comme le sol du jeu
    studs = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(studs)
    for y in range(16, S, 64):
        for x in range(16 + (32 if (y // 64) % 2 else 0), S, 64):
            d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(255, 255, 255, 26))
    img.alpha_composite(studs)
    # bord sombre
    frame = ImageDraw.Draw(img)
    frame.rounded_rectangle([5, 5, S - 6, S - 6], radius=56, outline=(25, 20, 40, 255), width=12)
    frame.rounded_rectangle([17, 17, S - 18, S - 18], radius=46, outline=light + (255,), width=5)
    return img


def shadowed(layer, offset=10, blur=10, alpha=140):
    a = layer.split()[3].point(lambda v: alpha if v > 20 else 0)
    sh = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    sh.putalpha(a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(sh, (offset, offset))
    out.alpha_composite(layer)
    return out


def big_text(text, size):
    font = ImageFont.truetype(FONT, size)
    stroke = max(8, size // 9)
    box = font.getbbox(text, stroke_width=stroke)
    w, h = box[2] - box[0], box[3] - box[1]
    pad = stroke + 6
    layer = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    origin = (pad - box[0], pad - box[1])
    ImageDraw.Draw(layer).text(origin, text, font=font, fill=(0, 0, 0, 255), stroke_width=stroke, stroke_fill=(0, 0, 0, 255))
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).text(origin, text, font=font, fill=255)
    grad = Image.new("RGBA", layer.size)
    gd = ImageDraw.Draw(grad)
    for y in range(layer.size[1]):
        t = min(1, max(0, (y - pad) / max(1, h)))
        c = (255, int(255 - 45 * t), int(150 - 140 * t))  # blanc-jaune -> or
        gd.line([(0, y), (layer.size[0], y)], fill=c + (255,))
    layer.paste(grad, (0, 0), mask)
    return layer.rotate(8, resample=Image.BICUBIC, expand=True)


os.makedirs(OUT, exist_ok=True)
sheet = Image.new("RGBA", (len(PASSES) * 260, 260), (40, 40, 55, 255))
for i, (key, (icon, light, dark, text)) in enumerate(PASSES.items()):
    img = background(light, dark)
    ic = Image.open(os.path.join(ICONS, icon + ".png")).convert("RGBA")
    size = 330 if text else 380
    ic = ic.resize((size, size), Image.LANCZOS)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    y = (S - size) // 2 - (28 if text else 0)
    layer.alpha_composite(ic, ((S - size) // 2, y))
    img.alpha_composite(shadowed(layer))
    if text:
        t = big_text(text, 150 if len(text) <= 2 else 120)
        img.alpha_composite(shadowed(t, 8, 6, 160), (S - t.width - 40, S - t.height - 34))
    img.convert("RGB").save(os.path.join(OUT, key + ".png"))
    sheet.alpha_composite(img.resize((250, 250), Image.LANCZOS), (i * 260 + 5, 5))
sheet.save(os.path.join(OUT, "_planche.png"))
print("ok", len(PASSES))
