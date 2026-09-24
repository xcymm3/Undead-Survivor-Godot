"""Generate the two distinct, original night-route warning sounds."""

from pathlib import Path
import wave

import numpy as np
from scipy.signal import butter, sosfilt


RATE = 22050
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def smooth_noise(seed: int, seconds: float, low: float, high: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    noise = rng.standard_normal(round(RATE * seconds))
    return sosfilt(butter(3, [low, high], btype="bandpass", fs=RATE, output="sos"), noise)


def envelope(t: np.ndarray, start: float, end: float, attack: float, release: float) -> np.ndarray:
    return np.clip((t - start) / attack, 0, 1) * np.clip((end - t) / release, 0, 1)


def horn() -> np.ndarray:
    """Two overlapping brass calls, with a slow attack and a low falling answer."""
    seconds = 2.8
    t = np.arange(round(RATE * seconds)) / RATE
    result = np.zeros_like(t)
    for start, end, frequency, strength in [(0.0, 1.68, 82.41, 1.0), (1.18, 2.76, 73.42, 0.85)]:
        local = np.maximum(t - start, 0)
        pitch = frequency * (1 - 0.013 * np.minimum(local, 1.5))
        phase = 2 * np.pi * np.cumsum(pitch) / RATE
        brass = sum(
            weight * np.sin(phase * harmonic + harmonic * 0.13)
            for harmonic, weight in [(1, 0.28), (2, 0.49), (3, 0.38), (4, 0.25), (5, 0.14), (6, 0.08)]
        )
        breath = smooth_noise(100 + round(start * 100), seconds, 140, 1100)
        body = brass + breath * 0.09
        result += strength * body * envelope(t, start, end, 0.17, 0.42)
    return result


def growl() -> np.ndarray:
    """One sustained rough throat sound, without percussive pops or bubbles."""
    seconds = 1.55
    t = np.arange(round(RATE * seconds)) / RATE
    frequency = 69 - 13 * t / seconds + 2.2 * np.sin(2 * np.pi * 6.2 * t)
    phase = 2 * np.pi * np.cumsum(frequency) / RATE
    throat = np.zeros_like(t)
    for harmonic in range(1, 22):
        hz = harmonic * 63
        formant = 0.75 * np.exp(-((hz - 290) / 180) ** 2) + 0.65 * np.exp(-((hz - 680) / 280) ** 2)
        throat += formant * np.sin(phase * harmonic + harmonic * 0.24) / harmonic ** 0.55
    rasp = smooth_noise(712, seconds, 110, 850)
    tremolo = 0.8 + 0.2 * np.sin(2 * np.pi * 11.5 * t)
    return (throat * tremolo + rasp * 0.22) * envelope(t, 0, seconds, 0.11, 0.32)


def write(name: str, samples: np.ndarray) -> None:
    samples = samples / max(float(np.max(np.abs(samples))), 1e-9) * 0.84
    pcm = np.round(samples * 32767).astype("<i2")
    with wave.open(str(OUTPUT / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


if __name__ == "__main__":
    write("campaign-horde.wav", horn())
    write("campaign-growl.wav", growl())
