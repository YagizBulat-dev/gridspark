"""Generates GridSpark's background music loops (assets/sounds/music/*.wav).

Usage:  python tool/generate_music.py     (needs numpy + scipy)

Each track is a 16-bar seamless loop: warm detuned pad, soft sub bass,
plucked arpeggio with tempo-synced echo, a sparse lead melody, light drums
and a shared reverb. Tweak TRACKS below and re-run.
"""
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 32000
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds" / "music"


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def _circ(sos, x):
    """Filter as if x were looped forever, so the loop seam has no transient."""
    if len(x) < 20000:  # single notes: normal filtering
        return signal.sosfilt(sos, x)
    n = len(x)
    return signal.sosfilt(sos, np.tile(x, 3))[n:2 * n]


def lp(x, fc, order=2):
    return _circ(signal.butter(order, fc, "low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return _circ(signal.butter(order, fc, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi):
    return signal.sosfilt(signal.butter(2, [lo, hi], "band", fs=SR, output="sos"), x)


def saw(f, n, phase=0.0):
    ph = (phase + f * np.arange(n) / SR) % 1.0
    return 2 * ph - 1


def add(buf, sig, start):
    """Overlap-add with wrap-around so the loop is seamless."""
    n = len(buf)
    i = int(start) % n
    end = i + len(sig)
    if end <= n:
        buf[i:end] += sig
    else:
        buf[i:] += sig[: n - i]
        rest = sig[n - i:]
        while len(rest):
            k = min(len(rest), n)
            buf[:k] += rest[:k]
            rest = rest[k:]


def adsr(n, a, r, hold=None):
    env = np.ones(n)
    na = max(1, int(a * SR))
    nr = max(1, int(r * SR))
    env[:na] = np.linspace(0, 1, na)
    env[-nr:] *= np.linspace(1, 0, nr)
    return env


CHORDS = {
    "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11], "6": [0, 4, 7, 9],
    "maj": [0, 4, 7], "min": [0, 3, 7], "sus": [0, 5, 7], "7": [0, 4, 7, 10],
}


def chord_notes(root, kind, octave_shift=0):
    return [root + i + 12 * octave_shift for i in CHORDS[kind]]


# --- instruments -----------------------------------------------------------

def pad_note(m, dur):
    n = int(dur * SR)
    f = hz(m)
    out = np.zeros(n)
    for cents, ph in ((-9, 0.0), (0, 0.33), (9, 0.66)):
        out += saw(f * 2 ** (cents / 1200), n, ph)
    out += 0.8 * np.sin(2 * np.pi * f * np.arange(n) / SR)
    out = lp(out, 1500)
    return out * adsr(n, 0.7, 1.2) / 3.5


def bass_note(m, dur):
    n = int(dur * SR)
    x = np.arange(n) / SR
    f = hz(m)
    y = np.sin(2 * np.pi * f * x) + 0.35 * np.sin(2 * np.pi * 2 * f * x)
    return lp(y, 400) * adsr(n, 0.01, min(0.25, dur * 0.5))


def pluck(m, dur=0.55):
    n = int(dur * SR)
    f = hz(m)
    raw = saw(f, n) + 0.6 * saw(f * 1.004, n)
    bright = lp(raw, 4200)
    dull = lp(raw, 900)
    k = np.arange(n) / SR
    mix = np.exp(-k / 0.08)
    y = bright * mix + dull * (1 - mix)
    return y * np.exp(-k / 0.22) * adsr(n, 0.004, 0.05) * 0.5


def lead_note(m, dur):
    n = int(dur * SR)
    k = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * k) * np.minimum(1, k / 0.25)
    ph = np.cumsum(hz(m) * vib) / SR
    y = np.sin(2 * np.pi * ph) + 0.28 * np.sin(4 * np.pi * ph) + 0.1 * np.sin(6 * np.pi * ph)
    return y * adsr(n, 0.02, min(0.35, dur * 0.6)) * 0.5


def kick():
    n = int(0.3 * SR)
    k = np.arange(n) / SR
    sweep = 45 + 85 * np.exp(-k * 28)
    y = np.sin(2 * np.pi * np.cumsum(sweep) / SR) * np.exp(-k / 0.11)
    return y + 0.25 * np.exp(-k / 0.004) * np.random.default_rng(1).standard_normal(n)


def hat(open_=False, rng=np.random.default_rng(2)):
    n = int((0.16 if open_ else 0.05) * SR)
    k = np.arange(n) / SR
    return hp(rng.standard_normal(n), 7000) * np.exp(-k / (0.07 if open_ else 0.012)) * 0.5


def snap(rng=np.random.default_rng(3)):
    n = int(0.14 * SR)
    k = np.arange(n) / SR
    body = np.sin(2 * np.pi * 190 * k) * np.exp(-k / 0.03) * 0.4
    return (bp(rng.standard_normal(n), 1400, 6000) * np.exp(-k / 0.045) * 0.6) + body


# --- effects ---------------------------------------------------------------

def reverb(x, seconds=2.4, wet=0.3, damp=4500):
    rng = np.random.default_rng(11)
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * seconds / 5.5))
    ir = lp(ir, damp)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
    ir /= np.sqrt(np.sum(ir ** 2))
    y = signal.fftconvolve(x, ir)
    tail = y[len(x):]
    y = y[: len(x)]
    y[: len(tail)] += tail[: len(y)]  # wrap the tail -> seamless loop
    return (1 - wet) * x + wet * y * 1.2


def echo(x, delay_s, fb=0.38, taps=5, tone=2800):
    d = int(delay_s * SR)
    out = np.zeros_like(x)
    cur = x
    for i in range(1, taps + 1):
        cur = lp(np.roll(cur, d), tone, 1) * fb
        out += cur
    return x + out


# --- arrangement -----------------------------------------------------------

TRACKS = {
    "menu": dict(
        bpm=78, root=57,  # A
        prog=[(0, "m7"), (-4, "maj7"), (3, "maj7"), (-2, "6")],  # Am7 Fmaj7 Cmaj7 G6
        scale=[0, 3, 5, 7, 10], arp="bell", drums=None, lead=0.5, wet=0.42, pad=1.0, gain=0.9,
    ),
    "classic": dict(
        bpm=92, root=48,  # C
        prog=[(0, "maj7"), (-3, "m7"), (5, "maj7"), (7, "6")],  # Cmaj7 Am7 Fmaj7 G6
        scale=[0, 2, 4, 7, 9], arp="eighth", drums="soft", lead=0.7, wet=0.33, pad=0.9, gain=0.95,
    ),
    "timed": dict(
        bpm=120, root=52,  # E
        prog=[(0, "m7"), (-4, "maj7"), (3, "maj"), (10, "sus")],  # Em7 Cmaj7 G D
        scale=[0, 3, 5, 7, 10], arp="sixteenth", drums="drive", lead=0.8, wet=0.26, pad=0.75, gain=1.0,
    ),
    "rising": dict(
        bpm=100, root=50,  # D
        prog=[(0, "m7"), (-4, "maj7"), (3, "maj7"), (-2, "maj")],  # Dm7 Bbmaj7 Fmaj7 C
        scale=[0, 3, 5, 7, 10], arp="sixteenth", drums="build", lead=0.9, wet=0.34, pad=1.0, gain=1.0,
    ),
}


def render(name, cfg):
    rng = np.random.default_rng(abs(hash(name)) % (2 ** 32) if False else sum(map(ord, name)))
    beat = SR * 60 / cfg["bpm"]
    bar = beat * 4
    bars = 16
    n = int(round(bars * bar))
    chord_bars = 2
    chords = [cfg["prog"][(b // chord_bars) % 4] for b in range(0, bars, chord_bars)]

    pad = np.zeros(n)
    bass = np.zeros(n)
    arp = np.zeros(n)
    lead = np.zeros(n)
    drums = np.zeros(n)
    kick_times = []

    for ci, (off, kind) in enumerate(chords):
        start = ci * chord_bars * bar
        root = cfg["root"] + off
        notes = chord_notes(root + 12, kind)
        for m in notes:
            add(pad, pad_note(m, chord_bars * bar / SR + 1.5), start)
        # bass: root on beat 1 of each bar, fifth on the "and" of 3 for movement
        for b in range(chord_bars):
            bstart = start + b * bar
            if cfg["drums"] in ("drive",):
                for e in range(8):
                    m = root - 12 if e % 4 != 3 else root - 5
                    add(bass, bass_note(m, beat / SR * 0.45) * 0.9, bstart + e * beat / 2)
            else:
                add(bass, bass_note(root - 12, beat / SR * 3.2), bstart)
                if cfg["drums"]:
                    add(bass, bass_note(root - 5, beat / SR * 0.8) * 0.7, bstart + 2.5 * beat)

        # arpeggio / bells
        tones = chord_notes(root + 24, kind) + [root + 36]
        if cfg["arp"] == "bell":
            for b in range(chord_bars):
                for q, idx in ((0, 3), (2, 1)):
                    add(arp, pluck(tones[idx % len(tones)] + 12, 1.1) * 0.8, start + b * bar + q * beat)
        else:
            steps = 8 if cfg["arp"] == "eighth" else 16
            pattern = [0, 2, 1, 3, 2, 4, 1, 3] if steps == 8 else [0, 1, 2, 3, 2, 1, 4, 2, 3, 1, 2, 4, 3, 2, 1, 0]
            step_len = bar / steps
            for b in range(chord_bars):
                for s in range(steps):
                    if cfg["arp"] == "sixteenth" and s % 4 == 3 and rng.random() < 0.35:
                        continue  # little gaps keep it human
                    m = tones[pattern[s] % len(tones)]
                    add(arp, pluck(m, 0.4) * (0.75 if s % 2 else 1.0), start + b * bar + s * step_len)

        # sparse lead: random walk on the scale, phrased in 2-bar chunks
        if cfg["lead"] > 0:
            scale_notes = [root + 24 + d for d in cfg["scale"]] + [root + 36 + d for d in cfg["scale"]]
            pos = int(rng.integers(0, len(scale_notes) - 4))
            t = 0.0
            while t < chord_bars * 4 - 0.5:
                if rng.random() < 0.5 * (1.1 - cfg["lead"] * 0.4) and t > 0:
                    t += 1.0  # rest
                    continue
                step = int(rng.choice([-2, -1, -1, 0, 1, 1, 2]))
                pos = int(np.clip(pos + step, 0, len(scale_notes) - 1))
                length = float(rng.choice([1.0, 1.5, 2.0, 3.0]))
                length = min(length, chord_bars * 4 - t)
                add(lead, lead_note(scale_notes[pos], length * beat / SR) * cfg["lead"], start + t * beat)
                t += length + 0.5

    # drums
    mode = cfg["drums"]
    if mode:
        k = kick()
        h = hat()
        ho = hat(True)
        s = snap()
        for b in range(bars):
            bstart = b * bar
            build = b / bars  # 0..1 over the loop (used by "build")
            if mode == "soft":
                hits = [0, 2.5]
                for q in hits:
                    add(drums, k * 0.5, bstart + q * beat); kick_times.append(bstart + q * beat)
                for q in (1, 3):
                    add(drums, s * 0.45, bstart + q * beat)
                for e in range(8):
                    add(drums, h * (0.5 if e % 2 == 0 else 0.9), bstart + e * beat / 2)
            elif mode == "drive":
                for q in range(4):
                    add(drums, k * 0.6, bstart + q * beat); kick_times.append(bstart + q * beat)
                for q in (1, 3):
                    add(drums, s * 0.55, bstart + q * beat)
                for e in range(16):
                    add(drums, h * (0.45 if e % 2 == 0 else 0.8), bstart + e * beat / 4)
                add(drums, ho * 0.9, bstart + 3.5 * beat)
            elif mode == "build":
                if b >= 2:
                    for q in (0, 2):
                        add(drums, k * 0.55, bstart + q * beat); kick_times.append(bstart + q * beat)
                    if build > 0.4:
                        add(drums, k * 0.6, bstart + 3.5 * beat); kick_times.append(bstart + 3.5 * beat)
                if b >= 4:
                    for q in (1, 3):
                        add(drums, s * (0.4 + 0.3 * build), bstart + q * beat)
                dens = 8 if build < 0.5 else 16
                for e in range(dens):
                    add(drums, h * (0.4 + 0.4 * build), bstart + e * bar / dens)

    # mix
    duck = np.ones(n)
    for kt in kick_times:  # gentle side-chain pump on pad/bass
        i = int(kt) % n
        m = min(n - i, int(0.3 * SR))
        duck[i:i + m] *= 1 - 0.35 * np.exp(-np.arange(m) / (0.1 * SR))
    pad_bus = pad * cfg["pad"] * duck
    bass_bus = bass * 0.45 * duck
    arp_bus = echo(arp, 60 / cfg["bpm"] * 0.75, fb=0.4, taps=5)
    lead_bus = echo(lead, 60 / cfg["bpm"] * 0.75, fb=0.35, taps=4)
    music = pad_bus * 0.55 + bass_bus * 0.8 + arp_bus * 0.62 + lead_bus * 0.6
    music = reverb(music, wet=cfg["wet"])
    music = music + drums * 0.55  # drums stay mostly dry
    music = np.tanh(music * 1.4 * cfg["gain"]) / np.tanh(1.4)
    music = hp(music, 40, 1)
    music = music + 0.55 * hp(music, 2500, 1)  # air / presence shelf
    return music


def save(name, x, peak=0.45):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(data) / SR:.1f}s  {len(data) * 2 / 1e6:.1f} MB")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, cfg in TRACKS.items():
        save(name, render(name, cfg))
