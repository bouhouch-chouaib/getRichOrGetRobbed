# Fabrique les textes de la vidéo (PNG 1920 x 1080 transparents) avec la police du jeu (LuckiestGuy).
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT = sys.argv[1]
OUT = sys.argv[2]
W, H = 1920, 1080


def gradient_text(draw_size, text, size, top, bottom, stroke):
    font = ImageFont.truetype(FONT, size)
    box = font.getbbox(text, stroke_width=stroke)
    w, h = box[2] - box[0], box[3] - box[1]
    pad = stroke + 12
    layer = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    origin = (pad - box[0], pad - box[1])
    # contour noir épais
    d.text(origin, text, font=font, fill=(0, 0, 0, 255), stroke_width=stroke, stroke_fill=(0, 0, 0, 255))
    # remplissage en dégradé vertical
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).text(origin, text, font=font, fill=255)
    grad = Image.new("RGBA", layer.size)
    gd = ImageDraw.Draw(grad)
    for y in range(layer.size[1]):
        t = min(1, max(0, (y - pad) / max(1, h)))
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        gd.line([(0, y), (layer.size[0], y)], fill=c + (255,))
    layer.paste(grad, (0, 0), mask)
    # reflet blanc en haut des lettres
    shine = Image.new("L", layer.size, 0)
    ImageDraw.Draw(shine).text((origin[0], origin[1] - size * 0.06), text, font=font, fill=90)
    shine = Image.composite(shine, Image.new("L", layer.size, 0), mask)
    top_half = Image.new("L", layer.size, 0)
    ImageDraw.Draw(top_half).rectangle([0, 0, layer.size[0], pad + h * 0.42], fill=255)
    shine = Image.composite(shine, Image.new("L", layer.size, 0), top_half)
    layer = Image.composite(Image.new("RGBA", layer.size, (255, 255, 255, 255)), layer, shine)
    return layer


def with_shadow(layer, offset=10, blur=8, alpha=150):
    a = layer.split()[3].point(lambda v: alpha if v > 0 else 0)
    sh = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    sh.putalpha(a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", (layer.size[0] + offset, layer.size[1] + offset), (0, 0, 0, 0))
    out.paste(sh, (offset, offset), sh)
    out.paste(layer, (0, 0), layer)
    return out


def place(canvas, layer, cx, cy):
    canvas.paste(layer, (int(cx - layer.size[0] / 2), int(cy - layer.size[1] / 2)), layer)


# Titre de fin : le nom du jeu
logo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
l1 = with_shadow(gradient_text(None, "STEAL PETS", 230, (255, 236, 90), (255, 140, 20), 16))
l2 = with_shadow(gradient_text(None, "& FEED THE BLACK HOLE", 120, (200, 150, 255), (130, 60, 255), 12))
place(logo, l1, W / 2, H / 2 - 95)
place(logo, l2, W / 2, H / 2 + 110)
logo.save(f"{OUT}/title_end.png")

# Légendes courtes (gameplay)
captions = {
    "cap_throw": "THROW STUFF IN THE BLACK HOLE",
    "cap_hatch": "HATCH RARE PETS",
    "cap_carry": "GRAB PETS AND RUN",
    "cap_worlds": "7 WORLDS TO UNLOCK",
}
for name, text in captions.items():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer = with_shadow(gradient_text(None, text, 78, (255, 255, 255), (255, 236, 150), 9), offset=6, blur=5)
    place(img, layer, W / 2, 985)
    img.save(f"{OUT}/{name}.png")
print("ok")
