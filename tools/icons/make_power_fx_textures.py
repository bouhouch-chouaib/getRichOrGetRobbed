"""Textures de la traînée et de l'aura d'entraînement (shared/PowerFx), dessinées par code, blanches sur fond
transparent (le jeu les colore par palier).

    python tools/icons/make_power_fx_textures.py assets/fx

Formes nettes à contour lissé + léger halo : le halo doux seul (UiStyle Glow) disparaît en plein jour, et les
textures de particules de Roblox (fire_main...) font granuleux.
  Flame.png   flamme de dessin animé (pointe qui ondule) : aura de Force
  Ring.png    anneau net avec halo : vague au sol
  Streak.png  trait vertical effilé aux deux bouts : traits de vitesse (particule orientée selon sa vitesse)
  Spark.png   étoile à 4 branches : étincelles et braises
  Trail.png   ruban : cœur clair, bords doux, filets de vent dans la longueur (Trail, U = longueur)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SS = 4  # suréchantillonnage pour des bords lisses


def grid(w, h):
    y, x = np.mgrid[0:h * SS, 0:w * SS].astype(np.float32)
    return (x + 0.5) / (w * SS), (y + 0.5) / (h * SS)


def smoothmin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def shape_alpha(d, edge=0.004, glow=0.0, glow_width=0.05, inner=1.0):
    """d = distance signée (négative dedans). Corps plein + halo extérieur optionnel."""
    body = np.clip(0.5 - d / edge, 0, 1) * inner
    halo = glow * np.exp(-np.maximum(d, 0) / glow_width) * (d > 0)
    return np.clip(body + halo, 0, 1)


def save(alpha, w, h, path, rgb=None):
    a = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8), "L").resize((w, h), Image.LANCZOS)
    if rgb is None:
        img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
        img.putalpha(a)
    else:
        c = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "L").resize((w, h), Image.LANCZOS)
        img = Image.merge("RGBA", (c, c, c, a))
    img.save(path)
    print(path, img.size)


def flame(out):
    w = h = 256
    x, y = grid(w, h)
    u = (x - 0.5) * 2  # -1..1
    v = (1 - y - 0.05) / 0.92  # 0 = bas de la flamme, 1 = pointe (marges en haut et en bas)
    # Demi-largeur d'un seul tenant : fond rond (quart d'ellipse) puis pointe qui s'effile sans cassure
    # (pente nulle au plus large), et qui ondule vers le haut.
    widest, base = 0.38, 0.44
    low = base * np.sqrt(np.clip(1 - ((widest - v) / widest) ** 2, 0, 1))
    t = np.clip((v - widest) / (1 - widest), 0, 1)
    high = base * np.clip(np.cos(t * np.pi / 2), 0, 1) ** 1.3
    half = np.where(v < widest, low, high)
    center = 0.2 * np.sin(t * np.pi * 1.1) * t
    d = (np.abs(u - center) - half) * 0.5
    d = np.where((v < 0) | (v > 1), 1.0, d)
    # Deux tons : la couleur du palier multiplie le gris, donc bord plus sombre et cœur (petite flamme
    # intérieure, plus basse) à pleine couleur. Comme les flammes de dessin animé.
    vi = v * 1.35 + 0.02
    ti = np.clip((vi - widest) / (1 - widest), 0, 1)
    half_in = np.where(vi < widest, base * np.sqrt(np.clip(1 - ((widest - vi) / widest) ** 2, 0, 1)),
                       base * np.clip(np.cos(ti * np.pi / 2), 0, 1) ** 1.3) * 0.55
    d_in = np.where((vi < 0) | (vi > 1), 1.0, (np.abs(u - center * 0.6) - half_in) * 0.5)
    tone = 0.78 + 0.22 * np.clip(0.5 - d_in / 0.006, 0, 1)
    save(shape_alpha(d, edge=0.005, glow=0.35, glow_width=0.03), w, h, out / "Flame.png", rgb=tone)


def ring(out):
    w = h = 256
    x, y = grid(w, h)
    r = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2) * 2  # 0 au centre, 1 au bord
    d = (np.abs(r - 0.8) - 0.055) * 0.5
    a = shape_alpha(d, edge=0.004, glow=0.45, glow_width=0.04)
    a = np.maximum(a, 0.12 * np.clip(1 - r / 0.8, 0, 1) ** 0.5 * (r < 0.8))  # voile léger dedans
    save(a, w, h, out / "Ring.png")


def streak(out):
    w = h = 128
    x, y = grid(w, h)
    u = (x - 0.5) * 2
    v = (y - 0.5) * 2  # le long du trait (vertical)
    half = 0.16 * (1 - np.abs(v) ** 1.6)
    d = (np.abs(u) - half) * 0.5
    a = shape_alpha(d, edge=0.008, glow=0.4, glow_width=0.05)
    a *= np.clip(1 - np.abs(v) ** 4, 0, 1)
    save(a, w, h, out / "Streak.png")


def spark(out):
    w = h = 128
    x, y = grid(w, h)
    u, v = (x - 0.5) * 2, (y - 0.5) * 2
    au, av = np.abs(u), np.abs(v)
    # Étoile à 4 branches : |u|^p + |v|^p avec p < 1 donne des branches fines.
    p = 0.42
    f = (au ** p + av ** p) ** (1 / p)
    d = (f - 0.9) * 0.08
    a = shape_alpha(d, edge=0.004, glow=0.5, glow_width=0.03)
    core = np.exp(-(u ** 2 + v ** 2) / 0.02)
    save(np.maximum(a, core), w, h, out / "Spark.png")


def trail(out):
    w, h = 512, 128
    x, y = grid(w, h)
    v = (y - 0.5) * 2  # à travers le ruban
    body = np.clip(1 - np.abs(v) ** 2.2, 0, 1) * 0.75
    core = np.exp(-(v / 0.18) ** 2) * 0.35
    rng = np.random.default_rng(7)
    lines = np.zeros_like(v)
    for _ in range(9):
        c = rng.uniform(-0.75, 0.75)
        start, length = rng.uniform(0, 0.6), rng.uniform(0.25, 0.6)
        along = np.clip(1 - np.abs((x - start - length / 2) / (length / 2)), 0, 1) ** 0.7
        lines = np.maximum(lines, np.exp(-((v - c) / 0.035) ** 2) * along)
    a = np.clip(body + core + lines * 0.5, 0, 1)
    save(a, w, h, out / "Trail.png")


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/fx")
    out.mkdir(parents=True, exist_ok=True)
    for make in (flame, ring, streak, spark, trail):
        make(out)
