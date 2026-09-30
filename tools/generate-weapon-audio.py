"""Generate original weapon cues offline, without recordings or audio playback.

Usage: python tools/generate-weapon-audio.py [--check]
The fixed seeds make PCM bytes reproducible. --check compares the committed WAVs
with regeneration in memory and validates levels, duration, format and variety.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio"
RATE = 44100
PEAK = 0.90


class Cue:
    def __init__(self, duration: float, seed: int):
        self.samples = [0.0] * round(duration * RATE)
        self.rng = random.Random(seed)

    def mix(self, values: list[float], start: float = 0.0, gain: float = 1.0):
        offset = round(start * RATE)
        for i, value in enumerate(values[: len(self.samples) - offset]):
            self.samples[offset + i] += value * gain

    def noise(self, duration, attack, decay, lowpass, highpass=0, gain=1, start=0):
        """Band-limited, independently seeded powder/air/mechanism layer."""
        low = floor = 0.0
        alpha = 1.0 - math.exp(-2 * math.pi * lowpass / RATE)
        floor_alpha = 1.0 - math.exp(-2 * math.pi * highpass / RATE)
        values = []
        for i in range(round(duration * RATE)):
            t = i / RATE
            low += alpha * (self.rng.uniform(-1, 1) - low)
            floor += floor_alpha * (low - floor)
            envelope = min(1, t / attack) * math.exp(-t / decay)
            envelope *= min(1, (duration - t) / .012)
            values.append((low - floor) * envelope)
        self.mix(values, start, gain)

    def body(self, start, duration, frequency, drop, decay, gain):
        """Very short pressure pulse; low harmonics add weight to the report."""
        phase = 0.0
        values = []
        for i in range(round(duration * RATE)):
            t = i / RATE
            phase += 2 * math.pi * (frequency + drop * math.exp(-t / .014)) / RATE
            envelope = min(1, t / .0007) * math.exp(-t / decay)
            envelope *= min(1, (duration - t) / .015)
            values.append((math.sin(phase) + .22 * math.sin(phase * 2.07)) * envelope)
        self.mix(values, start, gain)

    def metal(self, start, duration, frequencies, gain):
        self.noise(duration, .0003, duration / 7, 11000, 1600, gain, start)
        values = []
        for i in range(round(duration * RATE)):
            t = i / RATE
            envelope = min(1, t / .0003) * math.exp(-t / (duration / 6))
            values.append(sum(math.sin(t * 2 * math.pi * f) for f in frequencies)
                          * envelope / len(frequencies))
        self.mix(values, start, gain * .55)

    def echo(self, delay, gain, cutoff):
        """A quiet, softened outdoor reflection of the initial report only."""
        low = 0.0
        alpha = 1.0 - math.exp(-2 * math.pi * cutoff / RATE)
        values = []
        # Do not repeat later slide, bolt or pump actions in the gunshot echo.
        for sample in self.samples[: round(.065 * RATE)]:
            low += alpha * (sample - low)
            values.append(low)
        self.mix(values, delay, gain)

    def pcm(self):
        # Remove DC/subsonic energy before normalization. No hard clipping.
        floor = 0.0
        alpha = 1.0 - math.exp(-2 * math.pi * 28 / RATE)
        values = []
        for value in self.samples:
            floor += alpha * (value - floor)
            values.append(value - floor)
        fade = round(.009 * RATE)
        for i in range(fade):
            values[-1 - i] *= i / fade
        scale = PEAK / max(abs(value) for value in values)
        return b"".join(struct.pack("<h", round(value * scale * 32767)) for value in values)


def synthesize():
    cues = {}

    # Rifle: dry supersonic crack, medium body, short receiver clack.
    c = Cue(.29, 1701)
    c.noise(.06, .00025, .008, 15000, 2400, 1.2)
    c.noise(.20, .0007, .038, 3800, 180, 1.5)
    c.body(.001, .11, 115, 75, .018, .32)
    c.metal(.046, .045, (1450, 2830, 4190), .13)
    c.echo(.088, .18, 1700)
    c.echo(.151, .09, 1000)
    cues["rifle"] = c.pcm()

    # P90: a compact, brighter impulse with little bass and a quick action.
    c = Cue(.15, 1702)
    c.noise(.045, .0002, .006, 16500, 3300, 1.1)
    c.noise(.10, .0004, .019, 6500, 550, 1.25)
    c.body(.001, .05, 190, 65, .009, .17)
    c.metal(.022, .028, (2600, 4570, 6100), .15)
    c.echo(.059, .10, 3100)
    cues["p90"] = c.pcm()

    # Semiautomatic pistol: rounded pop followed by a distinct slide return.
    c = Cue(.25, 1703)
    c.noise(.055, .0005, .011, 9500, 1700, .9)
    c.noise(.14, .0008, .027, 2500, 140, 1.6)
    c.body(.001, .105, 145, 35, .022, .31)
    c.metal(.054, .05, (1780, 3150, 5220), .22)
    c.echo(.092, .14, 2100)
    cues["pistol"] = c.pcm()

    # Revolver: a broad cylinder-gap blast and a heavier, longer low report.
    c = Cue(.46, 1704)
    c.metal(0, .018, (2300, 3980), .16)
    c.noise(.07, .0003, .012, 14000, 1900, 1.05, .002)
    c.noise(.28, .001, .057, 2100, 70, 1.65, .002)
    c.noise(.10, .001, .02, 8200, 2800, .42, .009)
    c.body(.003, .19, 79, 68, .038, .42)
    c.echo(.115, .23, 1800)
    c.echo(.228, .13, 950)
    cues["revolver"] = c.pcm()

    # Pump shotgun: broad powder blast, then rearward/forward pump scrape.
    c = Cue(.69, 1705)
    c.noise(.12, .0007, .019, 11000, 800, 1.2)
    c.noise(.31, .001, .064, 2400, 60, 1.7)
    c.body(.002, .22, 62, 76, .044, .46)
    c.echo(.135, .22, 1300)
    c.noise(.11, .007, .042, 4400, 1000, .15, .275)
    c.metal(.292, .04, (970, 2260, 3950), .16)
    c.noise(.095, .006, .032, 5700, 700, .19, .423)
    c.metal(.471, .04, (1370, 3020, 5640), .20)
    cues["shotgun"] = c.pcm()

    # Bolt rifle: very sharp crack, deep push, distant tail and two bolt ticks.
    c = Cue(.52, 1706)
    c.noise(.065, .00015, .008, 19000, 3800, 1.55)
    c.noise(.32, .0007, .066, 3500, 90, 1.8)
    c.body(.001, .21, 76, 98, .037, .43)
    c.echo(.098, .27, 2900)
    c.echo(.205, .16, 1700)
    c.echo(.333, .07, 850)
    c.metal(.175, .045, (1420, 3480, 5940), .15)
    c.noise(.065, .004, .025, 4800, 850, .14, .195)
    c.metal(.258, .035, (1760, 3860), .18)
    cues["sniper"] = c.pcm()

    # Axe: a heavy, accelerating air sweep and wooden-handle/cloth movement.
    # There is no fake impact on a missed swing.
    c = Cue(.47, 1707)
    low = floor = 0.0
    values = []
    for i in range(len(c.samples)):
        t = i / RATE
        u = t / .47
        cutoff = 450 + 4200 * math.sin(math.pi * u) ** 3
        low += (1 - math.exp(-2 * math.pi * cutoff / RATE)) * (c.rng.uniform(-1, 1) - low)
        floor += .019 * (low - floor)
        envelope = math.sin(math.pi * u) ** 2.4 * (.35 + 1.1 * u)
        values.append((low - floor) * envelope)
    c.mix(values, gain=1.6)
    c.noise(.18, .012, .055, 1100, 85, .28, .025)
    c.body(.145, .12, 72, 18, .05, .038)
    cues["axe"] = c.pcm()

    # Flame: softly ramped pressure hiss and irregular low combustion flutter.
    # Adjacent packets overlap at the weapon's 80 ms firing interval.
    c = Cue(.15, 1708)
    low = mid = 0.0
    values = []
    for i in range(len(c.samples)):
        t = i / RATE
        u = t / .15
        noise = c.rng.uniform(-1, 1)
        low += .019 * (noise - low)
        mid += .43 * (noise - mid)
        envelope = min(1, t / .014) * min(1, (.15 - t) / .043)
        flutter = .65 + .22 * math.sin(2 * math.pi * 39 * t) + .13 * math.sin(2 * math.pi * 67 * t)
        values.append((mid * .28 + low * 3.3) * envelope * flutter)
    c.mix(values)
    cues["flamethrower"] = c.pcm()

    # Automatic shotgun: a compressed bass blast with a fast cycling action.
    c = Cue(.32, 1709)
    c.noise(.07, .0005, .013, 10000, 1300, 1.15)
    c.noise(.21, .0008, .04, 1900, 75, 1.9)
    c.body(.001, .16, 68, 60, .03, .42)
    c.metal(.055, .055, (1100, 2380, 4070), .23)
    c.echo(.105, .20, 1600)
    cues["auto-shotgun"] = c.pcm()

    # Heavy machine gun: hard low punch and a coarse, resonant feed action.
    c = Cue(.25, 1710)
    c.noise(.055, .0003, .009, 12500, 2100, 1.05)
    c.noise(.18, .0008, .031, 1600, 55, 1.9)
    c.body(.001, .12, 66, 55, .025, .48)
    c.metal(.028, .058, (790, 1630, 2950), .26)
    c.metal(.066, .035, (1170, 2520), .12)
    c.echo(.094, .17, 1300)
    cues["heavy-machine-gun"] = c.pcm()
    return cues


def validate(cues, check_files):
    weapons = json.loads((ROOT / "assets/data/rules.json").read_text(encoding="utf-8"))["weapons"]
    assert set(cues) == {weapon["id"] for weapon in weapons}, "Missing or extra weapon cue"
    assert cues == synthesize(), "Synthesis must be deterministic"
    hashes = set()
    for name, pcm in cues.items():
        samples = struct.unpack(f"<{len(pcm) // 2}h", pcm)
        peak = max(abs(value) for value in samples) / 32767
        rms = math.sqrt(sum((value / 32767) ** 2 for value in samples) / len(samples))
        assert .85 < peak < .92, (name, "clipping or missing peak", peak)
        assert .015 < rms < .35, (name, "inaudible or excessive energy", rms)
        assert samples[0] == samples[-1] == 0, (name, "hard boundary click")
        assert abs(sum(samples) / len(samples)) < 50, (name, "DC offset")
        digest = hashlib.sha256(pcm).hexdigest()
        assert digest not in hashes, (name, "duplicate cue")
        hashes.add(digest)
        if check_files:
            with wave.open(str(OUTPUT / f"weapon-{name}.wav"), "rb") as handle:
                assert (handle.getnchannels(), handle.getsampwidth(), handle.getframerate()) == (1, 2, RATE)
                assert handle.readframes(handle.getnframes()) == pcm, (name, "WAV differs from generator")
        print(f"{name:18} {len(samples) / RATE:.2f}s  peak={peak:.3f}  rms={rms:.3f}  sha256={digest[:12]}")
    # Comparing normalized waveform shapes rules out identical PCM with merely a
    # different gain. Different reports also have distinct envelopes/mechanisms.
    normalized = {}
    for name, pcm in cues.items():
        samples = struct.unpack(f"<{len(pcm) // 2}h", pcm)
        norm = math.sqrt(sum(value * value for value in samples))
        normalized[name] = [value / norm for value in samples]
    for a, av in normalized.items():
        for b, bv in normalized.items():
            if a < b:
                correlation = abs(sum(x * y for x, y in zip(av, bv)))
                assert correlation < .9, (a, b, "same waveform shape", correlation)
    print("WEAPON AUDIO: 10 unique cues; deterministic PCM, levels, boundaries and coverage passed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate committed WAVs without writing")
    args = parser.parse_args()
    cues = synthesize()
    if not args.check:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        for name, pcm in cues.items():
            with wave.open(str(OUTPUT / f"weapon-{name}.wav"), "wb") as handle:
                handle.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
                handle.writeframes(pcm)
    validate(cues, check_files=True)


if __name__ == "__main__":
    main()
