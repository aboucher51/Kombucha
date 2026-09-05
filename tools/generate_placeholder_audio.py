#!/usr/bin/env python3
"""Generate placeholder audio so the audio code has real files from day one.

Stdlib-only (wave/math/struct). Synthesizes a universal UI SFX set plus two
looping chord-pad music tracks as 22 kHz mono WAVs. Replace with authored
assets at leisure — swapping the files is enough, nothing points at these by
code.

    python3 tools/generate_placeholder_audio.py [output-dir]

Default output: assets/audio/ (sfx/ and music/ subdirectories).
"""
import math
import os
import struct
import sys
import wave

RATE = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(__file__), "..", "assets", "audio")


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print("wrote", path)


def env(i, n, attack=0.005, release=0.25):
    t = i / RATE
    total = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (total - t) / release) if release > 0 else 1.0
    return a * min(1.0, r)


def tone(freq_start, freq_end, dur, vol=0.5, attack=0.005, release=None, harmonics=(1.0,)):
    n = int(dur * RATE)
    release = release if release is not None else dur * 0.6
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = freq_start + (freq_end - freq_start) * t
        phase += 2 * math.pi * f / RATE
        s = sum(h * math.sin(phase * (k + 1)) for k, h in enumerate(harmonics)) / sum(harmonics)
        out.append(s * vol * env(i, n, attack, release))
    return out


def noise_burst(dur, vol=0.3, release=None):
    import random
    random.seed(7)
    n = int(dur * RATE)
    release = release if release is not None else dur
    return [((random.random() * 2 - 1) * vol * env(i, n, 0.001, release)) for i in range(n)]


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] if i < len(p) else 0.0 for p in parts) for i in range(n)]


def chord_loop(freqs, dur, vol=0.16):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(math.sin(2 * math.pi * f * t) * (0.8 + 0.2 * math.sin(2 * math.pi * 0.25 * t + k)) for k, f in enumerate(freqs))
        # gentle loop-friendly fade at both ends
        edge = min(1.0, i / (RATE * 0.5), (n - i) / (RATE * 0.5))
        out.append(s / len(freqs) * vol * edge)
    return out


SFX = {
    "click": tone(900, 700, 0.06, 0.4),
    "back": tone(500, 350, 0.09, 0.4),
    "menu_open": tone(400, 800, 0.12, 0.35),
    "menu_close": tone(800, 400, 0.12, 0.35),
    "hover": tone(1200, 1200, 0.03, 0.2),
    "error": tone(220, 180, 0.2, 0.45, harmonics=(1.0, 0.5)),
    "tab_switch": tone(700, 950, 0.07, 0.35),
    "confirm": mix(tone(600, 900, 0.1, 0.35), tone(900, 1350, 0.14, 0.3, attack=0.06)),
    "notification": mix(tone(880, 880, 0.25, 0.3), tone(1320, 1320, 0.22, 0.2, attack=0.08)),
    "hit": mix(tone(180, 90, 0.15, 0.5, harmonics=(1.0, 0.6, 0.3)), noise_burst(0.08, 0.3)),
    "pickup": tone(600, 1400, 0.22, 0.35),
    "heal": mix(tone(500, 900, 0.3, 0.25, attack=0.05), tone(750, 1350, 0.3, 0.2, attack=0.1)),
}

MUSIC = {
    # A-minor-ish calm loop; tenser suspended loop.
    "theme_calm": mix(chord_loop([220.0, 261.63, 329.63], 8.0),
                      chord_loop([110.0], 8.0, 0.10)),
    "theme_tense": mix(chord_loop([196.0, 233.08, 293.66], 8.0),
                       chord_loop([98.0, 146.83], 8.0, 0.12)),
}

for name, samples in SFX.items():
    write_wav(os.path.join(OUT, "sfx", name + ".wav"), samples)
for name, samples in MUSIC.items():
    write_wav(os.path.join(OUT, "music", name + ".wav"), samples)
