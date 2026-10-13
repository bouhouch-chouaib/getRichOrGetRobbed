# Toise des familiers : dessine les 75 modeles a la meme echelle qu un joueur (1 J = 5 studs).
# 1) lune run tools/check-pets.luau . sortie   2) python tools/pet-size-chart.py sortie toise_raretes.jpg toise_tous.jpg
import json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

base = sys.argv[1]
out1, out2 = sys.argv[2], sys.argv[3]
pets = json.load(open(base + "/pet-geometry.json"))
RAR = ["Commun", "Inhabituel", "Rare", "Epique", "Legendaire", "Mythique", "Divin", "Sigma"]
RNAME = ["Commun", "Inhabituel", "Rare", "Épique", "Légendaire", "Mythique", "Divin", "Sigma"]
RCOL = [(200, 200, 200), (100, 220, 90), (70, 160, 255), (180, 80, 255), (255, 170, 30), (255, 70, 120), (120, 255, 245), (255, 230, 60)]
try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22)
    FONTS = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 15)
    FONTB = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 34)
except Exception:
    FONT = FONTS = FONTB = ImageFont.load_default()

YAW, PITCH = math.radians(-32), math.radians(-12)
cy, sy = math.cos(YAW), math.sin(YAW)
cp, sp = math.cos(PITCH), math.sin(PITCH)
ROT = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]]) @ np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
LIGHT = np.array([-0.4, 0.8, -0.45]); LIGHT /= np.linalg.norm(LIGHT)
FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]


def boxes(parts):
    for q in parts:
        if q["aura"] or q["alpha"] >= 0.95:
            continue
        cf = q["cf"]; pos = np.array(cf[:3]); R = np.array(cf[3:]).reshape(3, 3)
        hs = np.array(q["size"]) / 2
        corners = []
        for x in (-1, 1):
            for y in (-1, 1):
                for z in (-1, 1):
                    corners.append(pos + R @ (hs * np.array([x, y, z])))
        col = np.array(q["color"]) * 255
        yield np.array(corners), col, q["neon"]


def faces_of(parts, offset):
    out = []
    for c, col, neon in boxes(parts):
        c = c + offset
        center = c.mean(axis=0)
        for f in FACES:
            pts = c[list(f)]
            n = np.cross(pts[1] - pts[0], pts[2] - pts[0])
            ln = np.linalg.norm(n)
            if ln < 1e-9:
                continue
            n /= ln
            fc = pts.mean(axis=0)
            if np.dot(n, fc - center) < 0:
                n = -n
            vn = ROT @ n
            if vn[2] > 0:  # facing away (camera looks toward +z in view space)
                continue
            shade = 1.0 if neon else 0.55 + 0.45 * max(0, float(np.dot(n, LIGHT)))
            v = (ROT @ pts.T).T
            out.append((v[:, 2].mean(), v[:, :2], np.clip(col * shade, 0, 255).astype(int)))
    return out


def player_parts():
    skin, shirt, pants = [0.96, 0.8, 0.25], [0.05, 0.53, 0.82], [0.25, 0.7, 0.3]
    def b(name, size, pos, color):
        return {"aura": False, "alpha": 0, "neon": False, "color": color, "size": size,
                "cf": list(pos) + [1, 0, 0, 0, 1, 0, 0, 0, 1], "name": name}
    return [b("LL", [0.9, 2, 0.9], [-0.5, 1, 0], pants), b("RL", [0.9, 2, 0.9], [0.5, 1, 0], pants),
            b("T", [2, 2, 1], [0, 3, 0], shirt), b("LA", [0.9, 2, 0.9], [-1.45, 3, 0], skin),
            b("RA", [0.9, 2, 0.9], [1.45, 3, 0], skin), b("H", [1.1, 1.0, 1.1], [0, 4.5, 0], skin)]


def extent(parts):
    vs = [((ROT @ c.T).T) for c, _, _ in boxes(parts)]
    a = np.vstack(vs)
    return a[:, 0].min(), a[:, 0].max()


def scene(items, scale, title, sub, labels=True):
    # items: list of (parts, label, color, height_studs); stand on y=0 side by side
    placed, x = [], 0.0
    gap = 2.5
    for parts, label, col, h in items:
        lo, hi = extent(parts)
        # model is centered; bottom at -height/2
        allc = np.vstack([c for c, _, _ in boxes(parts)])
        bottom = allc[:, 1].min()
        off = np.array([0.0, -bottom, 0.0])
        lo2, hi2 = extent([dict(p) for p in parts])
        placed.append((parts, off, x - lo2, label, col, h, hi2 - lo2, lo2))
        x += (hi2 - lo2) + gap
    width_st = x
    top_st = max(p[5] for p in placed)
    W = int(width_st * scale) + 80
    H = int(top_st * scale * 1.12) + 170
    img = Image.new("RGB", (W, H), (34, 40, 58))
    d = ImageDraw.Draw(img)
    ground = H - 70
    # grid lines every player height
    for k in range(0, int(top_st / 5) + 2):
        yy = ground - k * 5 * scale
        if yy < 80:
            break
        d.line([(0, yy), (W, yy)], fill=(52, 60, 84), width=1)
        d.text((6, yy - 18), f"{k} J", font=FONTS, fill=(130, 140, 170))
    d.rectangle([0, ground, W, H], fill=(70, 150, 70))
    allf = []
    for parts, off, sx, label, col, h, w, lo in placed:
        fs = faces_of(parts, off)
        for depth, pts, c in fs:
            allf.append((depth, pts, c, sx))
    allf.sort(key=lambda t: -t[0])
    for depth, pts, c, sx in allf:
        poly = [(40 + (p[0] + sx) * scale, ground - p[1] * scale) for p in pts]
        d.polygon(poly, fill=tuple(c), outline=(20, 20, 28))
    if labels:
        for parts, off, sx, label, col, h, w, lo in placed:
            cx = 40 + (sx + lo + w / 2) * scale
            for i, line in enumerate(label.split("\n")):
                tw = d.textlength(line, font=FONTS)
                d.text((cx - tw / 2, ground + 8 + i * 17), line, font=FONTS, fill=col if i == 0 else (240, 240, 240))
    d.text((40, 18), title, font=FONTB, fill=(255, 255, 255))
    d.text((40, 58), sub, font=FONTS, fill=(200, 205, 225))
    return img


byId = {p["id"]: p for p in pets}
# Image 1 : un familier par rareté (le plus grand de chaque tranche) + le joueur, à la même échelle.
picks = []
for i, r in enumerate(RAR):
    group = [p for p in pets if p["rarity"] == r]
    best = max(group, key=lambda p: p["size"][1])
    picks.append((best["parts"], f"{RNAME[i]}\n{best['size'][1] / 5:.1f} J", RCOL[i], best["size"][1]))
items = [(player_parts(), "Joueur\n1 J", (255, 255, 255), 5)] + picks
scene(items, 9, "L'échelle des familiers", "Le plus grand de chaque rareté, à côté d'un joueur (1 J = 5 studs).").save(out1, quality=90)

# Image 2 : tous les familiers, rangés par rareté puis par taille, à la même échelle.
rows = []
for i, r in enumerate(RAR):
    group = sorted([p for p in pets if p["rarity"] == r], key=lambda p: p["size"][1])
    items = [(player_parts(), "Joueur", (255, 255, 255), 5)]
    for p in group:
        items.append((p["parts"], f"{p['size'][1] / 5:.1f} J", RCOL[i], p["size"][1]))
    sc = 14 if i < 3 else (8 if i < 5 else 5)
    rows.append(scene(items, sc, RNAME[i], f"{len(group)} familiers, du plus petit au plus grand"))
Wmax = max(im.width for im in rows)
total = sum(im.height for im in rows)
sheet = Image.new("RGB", (Wmax, total), (34, 40, 58))
y = 0
for im in rows:
    sheet.paste(im, (0, y)); y += im.height
sheet.save(out2, quality=88)
print(Image.open(out1).size, sheet.size)
