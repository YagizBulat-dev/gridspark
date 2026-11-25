"""Generates GridSpark's sound effects (assets/sounds/sfx/*.wav).

Usage:  python tool/generate_sfx.py      (needs numpy)
Tweak the constants in each function and re-run; no other tooling needed.
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds" / "sfx"
rng = np.random.default_rng(7)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env_exp(n, decay):
    return np.exp(-np.arange(n) / (SR * decay))


def bell(freq, dur=0.35, decay=0.09, bright=1.0):
    """Soft bell: fundamental + two decaying partials."""
    x = t(dur)
    y = (
        np.sin(2 * np.pi * freq * x)
        + 0.35 * bright * np.sin(2 * np.pi * freq * 2.0 * x) * np.exp(-x / (decay * 0.6))
        + 0.15 * bright * np.sin(2 * np.pi * freq * 3.01 * x) * np.exp(-x / (decay * 0.35))
    )
    attack = np.minimum(1, np.arange(len(x)) / (SR * 0.004))
    return y * env_exp(len(x), decay) * attack


def place_at(buf, sig, start):
    i = int(start * SR)
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        prev = (1 - a) * v + a * prev
        y[i] = prev
    return y


def echo(x, delay=0.11, gain=0.28, taps=3):
    out = np.copy(x)
    pad = int(delay * SR)
    for k in range(1, taps + 1):
        d = pad * k
        out[d:] += x[: len(x) - d] * (gain**k)
    return out


def save(name, sig, peak=0.85):
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * peak
    fade = int(0.006 * SR)
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(sig, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(data) / SR:.2f}s")


NOTE = {"C4": 261.63, "E4": 329.63, "G4": 392.0, "A3": 220.0, "E3": 164.81,
        "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "C6": 1046.5,
        "E6": 1318.5, "A4": 440.0}


def make_place():
    """Crisp wooden 'pop': audible on phone speakers (energy 300 Hz - 5 kHz)."""
    x = t(0.14)
    sweep = 330 + 520 * np.exp(-x * 55)          # quick downward pitch slide
    pop = np.sin(2 * np.pi * np.cumsum(sweep) / SR) * np.exp(-x / 0.05)
    low = np.sin(2 * np.pi * 170 * x) * np.exp(-x / 0.035) * 0.25
    click = bp_noise(len(x), 1800, 5200) * np.exp(-x / 0.007) * 0.55
    return pop * 0.85 + low + click


def bp_noise(n, lo, hi):
    from scipy import signal
    sos = signal.butter(2, [lo, hi], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, rng.standard_normal(n))


def make_clear():
    buf = np.zeros(int(SR * 0.7))
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        place_at(buf, bell(NOTE[n], 0.4, 0.10) * (0.8 + 0.07 * i), i * 0.065)
    return echo(buf, 0.09, 0.25, 2)


def make_combo():
    buf = np.zeros(int(SR * 0.85))
    place_at(buf, make_place() * 0.9, 0)
    for i, n in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        place_at(buf, bell(NOTE[n], 0.45, 0.12, 1.3) * (0.7 + 0.08 * i), 0.02 + i * 0.05)
    # octave shimmer
    place_at(buf, bell(NOTE["C6"] * 2, 0.5, 0.15, 0.6) * 0.35, 0.27)
    return echo(buf, 0.08, 0.3, 3)


def make_invalid():
    buf = np.zeros(int(SR * 0.2))
    for k, f in enumerate([360, 285]):
        x = t(0.075)
        sq = np.sign(np.sin(2 * np.pi * f * x)) * 0.55 + np.sin(2 * np.pi * f * x) * 0.45
        sig = lowpass(sq, 2200) * np.exp(-x / 0.045)
        place_at(buf, sig, k * 0.085)
    return buf


def make_refill():
    n = int(SR * 0.24)
    noise = rng.standard_normal(n)
    sweep = np.linspace(500, 3500, n)
    out = np.zeros(n)
    # swish = noise whose brightness rises (crude one-pole with moving cutoff)
    prev = 0.0
    for i in range(n):
        a = np.exp(-2 * np.pi * sweep[i] / SR)
        prev = (1 - a) * noise[i] + a * prev
        out[i] = prev
    shape = np.sin(np.linspace(0, np.pi, n)) ** 2
    pop = place_at_buf(n, bell(880, 0.12, 0.04) * 0.5, 0.17)
    return out * shape * 1.6 + pop


def place_at_buf(n, sig, start):
    b = np.zeros(n)
    place_at(b, sig, start)
    return b


def make_game_over():
    buf = np.zeros(int(SR * 1.2))
    for i, n in enumerate(["E5", "C5", "A4", "E4"]):
        sig = bell(NOTE[n], 0.55, 0.22, 0.5) * (1.0 - 0.1 * i)
        place_at(buf, sig, i * 0.2)
    return echo(buf, 0.14, 0.3, 3)


def make_click():
    x = t(0.06)
    return (np.sin(2 * np.pi * 1000 * x) * 0.6 + np.sin(2 * np.pi * 2000 * x) * 0.2) * np.exp(-x / 0.012)


def make_achievement():
    buf = np.zeros(int(SR * 1.0))
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        place_at(buf, bell(NOTE[n], 0.6, 0.18) * 0.8, i * 0.09)
    for n in ["C5", "E5", "G5"]:  # held chord
        place_at(buf, bell(NOTE[n], 0.6, 0.3, 0.5) * 0.35, 0.38)
    return echo(buf, 0.12, 0.28, 2)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    save("place", make_place())
    save("clear", make_clear())
    save("combo", make_combo())
    save("invalid", make_invalid(), peak=0.6)
    save("tray_refill", make_refill(), peak=0.55)
    save("game_over", make_game_over())
    save("button_click", make_click(), peak=0.55)
    save("achievement", make_achievement())
