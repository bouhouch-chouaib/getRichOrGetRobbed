# Musique de fond de la vidéo de la page du jeu, composée et jouée par le code (aucun son externe, aucune mélodie reprise).
# Ambiance « jeu d'aventure sur console portable » : thème joyeux en majeur, arpèges rapides, basse qui rebondit.
#   A : 8 bits (ondes carrées, triangle, bruit), do majeur, 136 BPM
#   B : moderne (cuivres en dents de scie, pizzicati, cordes, tambourin), ré majeur, 130 BPM
# Les deux finissent sur l'accord final au moment du titre de la vidéo (~42,4 s) et s'éteignent à 46 s.
# Usage : python -I make_music.py DOSSIER_DE_SORTIE   -> music_A.wav, music_B.wav (44,1 kHz, stéréo, non normalisés)
import sys
import wave

import numpy as np
from scipy.signal import fftconvolve, lfilter

SR = 44100
TOTAL = 46.0
NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
rng = np.random.default_rng(7)


def midi(name):
    n = NAMES[name[0]]
    i = 1
    if name[i] == "#":
        n += 1
        i += 1
    return 12 * (int(name[i:]) + 1) + n


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# --- Oscillateurs (PolyBLEP : moins de repliement sur les notes aiguës) ---
def polyblep(t, dt):
    y = np.zeros_like(t)
    a = t < dt
    x = t[a] / dt[a] if np.ndim(dt) else t[a] / dt
    y[a] = x + x - x * x - 1
    b = t > 1 - (dt if not np.ndim(dt) else dt)
    if np.ndim(dt):
        x = (t[b] - 1) / dt[b]
    else:
        x = (t[b] - 1) / dt
    y[b] = x * x + x + x + 1
    return y


def phase_of(freq):
    return np.cumsum(freq / SR) % 1.0, freq / SR


def pulse(freq, duty):
    ph, dt = phase_of(freq)
    y = np.where(ph < duty, 1.0, -1.0)
    y += polyblep(ph, dt) - polyblep((ph - duty) % 1.0, dt)
    return y


def saw(freq):
    ph, dt = phase_of(freq)
    return 2 * ph - 1 - polyblep(ph, dt)


def triangle(freq):
    ph, _ = phase_of(freq)
    return 4 * np.abs(ph - 0.5) - 1


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    return lfilter([1 - a], [1, -a], x)


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(n, a, d, s, r_start, r):
    """Enveloppe ADSR : attaque a, déclin d vers s, relâche r à partir de r_start (secondes)."""
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = t > r_start
    e[rel] *= np.exp(-(t[rel] - r_start) / max(r, 1e-4))
    return e


class Mix:
    def __init__(self):
        self.n = int(TOTAL * SR) + SR
        self.dry = np.zeros((2, self.n))
        self.send = np.zeros((2, self.n))  # vers la réverbération

    def add(self, start, sig, gain, pan=0.0, rev=0.0):
        i = int(start * SR)
        if i >= self.n:
            return
        sig = sig[: self.n - i] * gain
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        self.dry[0, i:i + len(sig)] += sig * l * 1.41
        self.dry[1, i:i + len(sig)] += sig * r * 1.41
        if rev:
            self.send[0, i:i + len(sig)] += sig * l * rev
            self.send[1, i:i + len(sig)] += sig * r * rev

    def render(self):
        t = np.arange(int(1.8 * SR)) / SR
        out = self.dry.copy()
        for ch in range(2):
            ir = rng.standard_normal(len(t)) * np.exp(-t * 3.2)
            ir = lowpass(ir, 6000)
            ir[: int(0.012 * SR)] = 0  # petit pré-délai
            out[ch] += fftconvolve(self.send[ch], ir)[: self.n] * 0.035
        out = highpass(out, 35)
        n_end = int(TOTAL * SR)
        out = out[:, :n_end]
        fade = int(1.4 * SR)
        out[:, -fade:] *= np.linspace(1, 0, fade) ** 2
        peak = np.max(np.abs(out))
        out = np.tanh(out / peak * 1.3) / np.tanh(1.3) * 0.89
        return out


# --- Batterie ---
def kick():
    t = np.arange(int(0.28 * SR)) / SR
    f = 48 + 120 * np.exp(-t * 32)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11)
    y[: int(0.004 * SR)] += rng.standard_normal(int(0.004 * SR)) * 0.4
    return y


def snare():
    t = np.arange(int(0.22 * SR)) / SR
    noise = highpass(rng.standard_normal(len(t)), 1500) * np.exp(-t * 20)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 28) * 0.6
    return noise * 0.8 + tone


def hat(decay=85.0, length=0.06):
    t = np.arange(int(length * SR)) / SR
    return highpass(rng.standard_normal(len(t)), 7000) * np.exp(-t * decay)


def crash():
    t = np.arange(int(2.2 * SR)) / SR
    return highpass(rng.standard_normal(len(t)), 4500) * np.exp(-t * 2.4)


# --- Accords et gammes ---
QUAL = {"": [0, 4, 7], "m": [0, 3, 7]}


def chord_tones(name):
    root = name[:2] if len(name) > 1 and name[1] == "#" else name[0]
    q = name[len(root):]
    r = NAMES[root[0]] + (1 if "#" in root else 0)
    return r, QUAL[q]


def third_below(m, scale):
    """Note de la gamme deux degrés plus bas (tierce diatonique) pour la seconde voix."""
    pc = m % 12
    if pc not in scale:
        return m - 3
    i = scale.index(pc)
    j = i - 2
    oct_shift = -12 if j < 0 else 0
    return m - pc + scale[j % 7] + oct_shift


def parse_melody(bars):
    notes = []  # (début en temps, durée en temps, midi ou None)
    for b, bar in enumerate(bars):
        beat = 0.0
        for item in bar:
            name, dur = item
            notes.append((b * 4 + beat, dur, None if name == "-" else midi(name)))
            beat += dur
        assert abs(beat - 4) < 1e-6, f"mesure {b} : {beat} temps"
    return notes


# ====================================================================================
# A : 8 bits, do majeur
# ====================================================================================
A_THEME = [
    [("G4", .5), ("C5", .5), ("E5", .5), ("G5", 1), ("E5", .5), ("G5", 1)],
    [("A5", .5), ("G5", .5), ("F5", .5), ("D5", 1.5), ("B4", 1)],
    [("C5", .5), ("E5", .5), ("A5", 1), ("G5", .5), ("E5", .5), ("C5", 1)],
    [("D5", .5), ("E5", .5), ("F5", 1), ("A5", 1), ("C6", 1)],
    [("E6", 1), ("D6", .5), ("C6", .5), ("G5", 1), ("E5", 1)],
    [("F5", .5), ("G5", .5), ("A5", .5), ("B5", .5), ("D6", 1.5), ("B5", .5)],
    [("A5", 1), ("C6", 1), ("B5", 1), ("D6", 1)],
    [("C6", 2), ("G5", .5), ("E5", .5), ("C5", 1)],
]
A_BRIDGE = [
    [("A4", 1), ("C5", .5), ("E5", 1), ("A5", 1.5)],
    [("G5", .5), ("F5", .5), ("E5", .5), ("F5", 1.5), ("C5", 1)],
    [("E5", 1), ("G5", .5), ("C6", 1), ("B5", .5), ("G5", 1)],
    [("D5", 2), ("B4", .5), ("D5", .5), ("G5", 1)],
    [("C6", 1), ("B5", .5), ("A5", .5), ("E5", 1), ("A5", 1)],
    [("C6", .5), ("A5", .5), ("F5", 1), ("C6", 1), ("A5", 1)],
    [("D6", 1), ("C6", .5), ("A5", .5), ("F5", 1), ("D5", 1)],
    [("G5", .5), ("A5", .5), ("B5", .5), ("C6", .5), ("D6", 1), ("B5", .5), ("G5", .5)],
]
A_CHORDS = (
    [[("C", 4)]]
    + [[("C", 4)], [("G", 4)], [("Am", 4)], [("F", 4)], [("C", 4)], [("G", 4)], [("F", 2), ("G", 2)], [("C", 4)]]
    + [[("Am", 4)], [("F", 4)], [("C", 4)], [("G", 4)], [("Am", 4)], [("F", 4)], [("Dm", 4)], [("G", 4)]]
    + [[("C", 4)], [("G", 4)], [("Am", 4)], [("F", 4)], [("C", 4)], [("G", 4)], [("F", 2), ("G", 2)]]
    + [[("C", 4)]]
)


def song_a():
    bpm = 136.0
    spb = 60 / bpm
    m = Mix()
    scale = [0, 2, 4, 5, 7, 9, 11]
    final_bar = 24
    melody = [[("-", 4)]] + A_THEME + A_BRIDGE + A_THEME[:7] + [[("C6", 4)]]
    notes = parse_melody(melody)
    harmony_from = 17 * 4  # seconde voix sur la reprise

    for beat, dur, n in notes:
        if n is None:
            continue
        sec = dur * spb * (0.92 if beat < final_bar * 4 else 2.2)
        length = int((sec + 0.12) * SR)
        t = np.arange(length) / SR
        vib = 1 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.12) / 0.15, 0, 1)
        sig = pulse(hz(n) * vib, 0.25) * env(length, 0.004, 0.09, 0.72, sec, 0.05)
        m.add(beat * spb, sig, 0.30, 0.0, rev=1.0)
        m.add(beat * spb + 0.75 * spb, sig, 0.08, -0.6)  # écho
        if beat >= harmony_from:
            h = third_below(n, scale)
            hs = pulse(hz(h) * vib, 0.125) * env(length, 0.004, 0.09, 0.7, sec, 0.05)
            m.add(beat * spb, hs, 0.13, 0.35, rev=1.0)

    # arpèges en doubles croches + basse en octaves
    order = [0, 1, 2, 3, 2, 1, 2, 3]
    for bar, chords in enumerate(A_CHORDS):
        beat0 = bar * 4.0
        for chord, beats in chords:
            r, q = chord_tones(chord)
            tones = [60 + r + q[0], 60 + r + q[1], 60 + r + q[2], 72 + r + q[0]]
            if r >= 7:
                tones = [x - 12 for x in tones]
            steps = int(beats * 4) if bar < final_bar else 8
            for k in range(steps):
                n = tones[order[k % 8]] if bar < final_bar else tones[k % 4] + 12 * (k // 4)
                length = int(0.16 * SR)
                sig = pulse(np.full(length, hz(n)), 0.125) * env(length, 0.002, 0.05, 0.25, 0.1, 0.03)
                pan = -0.45 if k % 2 == 0 else 0.45
                m.add((beat0 + k * 0.25) * spb, sig, 0.085 if bar > 0 else 0.11, pan, rev=0.6)
            bass_root = 36 + r if r < 5 else 24 + r
            if bar < final_bar:
                for k in range(int(beats * 2)):
                    n = bass_root + (12 if k % 2 else 0)
                    length = int(0.5 * spb * SR * 0.9)
                    sig = triangle(np.full(length, hz(n))) * env(length, 0.003, 0.2, 0.8, 0.5 * spb * 0.85, 0.02)
                    m.add((beat0 + k * 0.5) * spb, sig, 0.32)
            else:
                length = int(3.4 * SR)
                sig = triangle(np.full(length, hz(bass_root))) * env(length, 0.003, 0.6, 0.6, 2.5, 0.5)
                m.add(beat0 * spb, sig, 0.34)
            beat0 += beats

    # batterie
    k_, s_, h_, c_ = kick(), snare(), hat(), crash()
    for bar in range(final_bar + 1):
        b0 = bar * 4
        if bar in (1, 9, 17, final_bar):
            m.add(b0 * spb, c_, 0.10, 0.2, rev=0.5)
        if bar == final_bar:
            m.add(b0 * spb, k_, 0.55)
            break
        if bar == 0:
            m.add(0, k_, 0.5)
            for k in range(8):  # roulement sur les temps 3 et 4
                m.add((b0 + 2 + k * 0.25) * spb, s_, 0.10 + 0.03 * k, 0.1)
            continue
        for b in (0, 2):
            m.add((b0 + b) * spb, k_, 0.5)
        m.add((b0 + 2.5) * spb, k_, 0.32)
        for b in (1, 3):
            m.add((b0 + b) * spb, s_, 0.27, 0.1, rev=0.4)
        for k in range(8):
            m.add((b0 + k * 0.5) * spb, h_, 0.07 if k % 2 else 0.05, 0.35)
        if 9 <= bar <= 16:
            for k in range(16):
                if k % 2:
                    m.add((b0 + k * 0.25) * spb, hat(40, 0.1), 0.035, -0.3)
        if bar in (8, 16, final_bar - 1):  # petit roulement avant la partie suivante
            for k in range(4):
                m.add((b0 + 3 + k * 0.25) * spb, s_, 0.12 + 0.04 * k, 0.1)
    return m.render()


# ====================================================================================
# B : moderne, ré majeur
# ====================================================================================
B_THEME = [
    [("A4", .5), ("D5", .5), ("F#5", 1), ("A5", 1), ("F#5", 1)],
    [("B5", 1.5), ("A5", .5), ("F#5", 1), ("D5", 1)],
    [("E5", .5), ("F#5", .5), ("G5", 1), ("B5", 1), ("D6", 1)],
    [("C#6", 1.5), ("B5", .5), ("A5", 2)],
    [("F#5", .5), ("A5", .5), ("D6", 1), ("C#6", .5), ("D6", .5), ("E6", 1)],
    [("F#6", 1.5), ("E6", .5), ("C#6", 1), ("A5", 1)],
    [("B5", .5), ("A5", .5), ("G5", .5), ("B5", .5), ("D6", 1), ("B5", 1)],
    [("A5", 1), ("E5", .5), ("F#5", .5), ("G5", .5), ("A5", .5), ("C#6", 1)],
]
B_BRIDGE = [
    [("D6", 1), ("B5", .5), ("G5", .5), ("B5", 1), ("D6", 1)],
    [("E6", 1.5), ("D6", .5), ("C#6", 1), ("A5", 1)],
    [("C#6", 1), ("A5", .5), ("F#5", .5), ("A5", 1), ("C#6", 1)],
    [("D6", 2), ("B5", 1), ("F#5", 1)],
    [("G5", .5), ("B5", .5), ("D6", .5), ("G6", 1.5), ("F#6", .5), ("E6", .5)],
    [("E6", 1), ("C#6", .5), ("A5", .5), ("E6", 1), ("C#6", 1)],
    [("D6", 1), ("F#6", 1), ("E6", 1), ("D6", 1)],
    [("C#6", 1), ("A5", .5), ("B5", .5), ("C#6", .5), ("D6", .5), ("E6", 1)],
]
B_CADENCE = [
    [("B5", 1), ("D6", 1), ("G6", 1), ("F#6", 1)],
    [("E6", 1.5), ("D6", .5), ("C#6", 1), ("E6", 1)],
]
B_CHORDS = (
    [[("D", 4)]]
    + [[("D", 4)], [("Bm", 4)], [("G", 4)], [("A", 4)], [("D", 4)], [("F#m", 4)], [("G", 4)], [("A", 4)]]
    + [[("G", 4)], [("A", 4)], [("F#m", 4)], [("Bm", 4)], [("G", 4)], [("A", 4)], [("Bm", 4)], [("A", 4)]]
    + [[("D", 4)], [("Bm", 4)], [("G", 4)], [("A", 4)], [("G", 4)], [("A", 4)]]
    + [[("D", 4)]]
)


def brass(freq, length, sec):
    """Cuivre de synthèse : dent de scie + une autre à peine désaccordée (battement lent : la note reste pleine)."""
    y = saw(freq) + 0.35 * saw(freq * 1.0008) + 0.3 * pulse(freq * 2, 0.25)
    t = np.arange(length) / SR
    bright = 1800 + 3200 * np.exp(-t * 6) * np.clip(t / 0.03, 0, 1)
    # filtre variable approché par deux passes à la fréquence moyenne de l'attaque puis du maintien
    head = int(min(length, 0.12 * SR))
    out = np.concatenate([lowpass(y[:head], float(bright[:head].mean())), lowpass(y[head:], 1900)]) if head < length else lowpass(y, 3000)
    return out * env(length, 0.025, 0.25, 0.75, sec, 0.08)


def pluck(f, length):
    t = np.arange(length) / SR
    y = np.zeros(length)
    for h, a in ((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.18), (5, 0.1)):
        y += a * np.sin(2 * np.pi * f * h * t) * np.exp(-t * (7 + 5 * h))
    return y * np.clip(t / 0.002, 0, 1)


def song_b():
    bpm = 130.0
    spb = 60 / bpm
    m = Mix()
    scale = [2, 4, 6, 7, 9, 11, 1]
    scale_sorted = sorted(scale)
    final_bar = 23
    melody = [[("-", 4)]] + B_THEME + B_BRIDGE + B_THEME[:4] + B_CADENCE + [[("D6", 4)]]
    notes = parse_melody(melody)
    harmony_from = 17 * 4

    for beat, dur, n in notes:
        if n is None:
            continue
        sec = dur * spb * (0.94 if beat < final_bar * 4 else 2.4)
        length = int((sec + 0.2) * SR)
        t = np.arange(length) / SR
        vib = 1 + 0.005 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
        sig = brass(hz(n) * vib, length, sec)
        m.add(beat * spb, sig, 0.21, 0.0, rev=1.2)
        m.add(beat * spb + 0.75 * spb, sig, 0.045, 0.5)
        if beat >= harmony_from:
            h = third_below(n, scale_sorted)
            m.add(beat * spb, brass(hz(h) * vib, length, sec), 0.08, -0.3, rev=1.2)

    order = [0, 2, 1, 3, 2, 1, 3, 2]
    for bar, chords in enumerate(B_CHORDS):
        beat0 = bar * 4.0
        for chord, beats in chords:
            r, q = chord_tones(chord)
            base = 62 if r < 2 else 50
            tones = [base + (r - 2) % 12 + q[0], base + (r - 2) % 12 + q[1], base + (r - 2) % 12 + q[2], base + (r - 2) % 12 + 12]
            tones = [x if x < 76 else x - 12 for x in tones]
            # pizzicati en doubles croches
            steps = int(beats * 4) if bar < final_bar else 8
            for k in range(steps):
                n = 12 + (tones[order[k % 8]] if bar < final_bar else tones[k % 4] + 12 * (k // 4))
                length = int(0.35 * SR)
                m.add((beat0 + k * 0.25) * spb, pluck(hz(n), length), 0.065 if k % 4 == 0 else 0.045,
                      -0.5 if k % 2 == 0 else 0.5, rev=0.8)
            # nappe de cordes
            sec = beats * spb * (1.0 if bar < final_bar else 1.8)
            length = int((sec + 0.4) * SR)
            pad = np.zeros(length)
            for x in tones[:3]:
                pad += saw(np.full(length, hz(x))) + 0.6 * saw(np.full(length, hz(x) * 1.0015))
            pad = lowpass(lowpass(pad, 1400), 2200) * env(length, 0.18, 0.5, 0.85, sec, 0.3)
            m.add(beat0 * spb, pad, 0.022, 0.0, rev=1.0)
            # basse
            root = 38 + (r - 2) % 12
            if root > 45:
                root -= 12
            if bar < final_bar:
                patt = [0, None, 0, 12, 7, None, 12, 7]
                for k in range(int(beats * 2)):
                    if patt[k % 8] is None:
                        continue
                    n = root + patt[k % 8]
                    length = int(0.5 * spb * SR * 0.95)
                    sig = lowpass(pulse(np.full(length, hz(n)), 0.5), 900) * env(length, 0.004, 0.15, 0.7, 0.5 * spb * 0.85, 0.02)
                    m.add((beat0 + k * 0.5) * spb, sig, 0.30)
            else:
                length = int(3.4 * SR)
                sig = lowpass(pulse(np.full(length, hz(root)), 0.5), 700) * env(length, 0.004, 0.6, 0.6, 2.5, 0.5)
                m.add(beat0 * spb, sig, 0.30)
            beat0 += beats

    k_, s_, h_, c_ = kick(), snare(), hat(), crash()
    for bar in range(final_bar + 1):
        b0 = bar * 4
        if bar in (1, 9, 17, final_bar):
            m.add(b0 * spb, c_, 0.11, -0.2, rev=0.6)
        if bar == final_bar:
            m.add(b0 * spb, k_, 0.55)
            m.add(b0 * spb, s_, 0.25, 0.1, rev=0.8)
            break
        if bar == 0:
            m.add(0, k_, 0.5)
            for k in range(8):
                m.add((b0 + 2 + k * 0.25) * spb, s_, 0.10 + 0.03 * k, 0.1)
            continue
        for b in (0, 1.5, 2):
            m.add((b0 + b) * spb, k_, 0.5 if b != 1.5 else 0.3)
        for b in (1, 3):
            m.add((b0 + b) * spb, s_, 0.26, 0.1, rev=0.6)
        for k in range(16):  # tambourin
            m.add((b0 + k * 0.25) * spb, hat(45, 0.09), 0.05 if k % 4 == 2 else 0.025, 0.4)
        if bar in (8, 16, final_bar - 1):
            for k in range(4):
                m.add((b0 + 3 + k * 0.25) * spb, s_, 0.12 + 0.04 * k, 0.1)
    return m.render()


def save(path, stereo):
    data = (np.clip(stereo.T, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    out = sys.argv[1]
    save(f"{out}/music_A.wav", song_a())
    save(f"{out}/music_B.wav", song_b())
    print("ok")
