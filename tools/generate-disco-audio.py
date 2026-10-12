"""Original three-second disco cue, generated offline with no audio playback."""
import math
import random
import struct
import wave
from pathlib import Path

rate = 22050
randomizer = random.Random(20261012)
samples = []
for index in range(rate * 3):
    time = index / rate
    beat = time % .5
    eighth = time % .25
    step = int(time / .25)
    bass = [130.81, 130.81, 155.56, 174.61, 196, 174.61, 155.56, 116.54][step % 8]
    kick = math.sin(2 * math.pi * (55 * beat + 1.8 * (1 - math.exp(-beat * 55)))) * math.exp(-beat * 32)
    hat = randomizer.uniform(-1, 1) * math.exp(-eighth * 130)
    groove = (math.sin(time * 2 * math.pi * bass) + .2 * math.sin(time * 4 * math.pi * bass)) * math.exp(-eighth * 12)
    chord = sum(math.sin(time * 2 * math.pi * frequency) for frequency in [261.63, 311.13, 392]) / 3
    offbeat = max(0, eighth - .125)
    chord *= math.exp(-offbeat * 35) if eighth >= .125 else 0
    fade = min(1, time / .006, (3 - time) / .03)
    samples.append((.35 * kick + .08 * hat + .23 * groove + .14 * chord) * fade)
peak = max(abs(value) for value in samples)
pcm = b"".join(struct.pack('<h', round(value / peak * .85 * 32767)) for value in samples)
output = Path(__file__).resolve().parents[1] / 'assets/audio/disco.wav'
with wave.open(str(output), 'wb') as handle:
    handle.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    handle.writeframes(pcm)
print('DISCO AUDIO: 3 seconds; original seeded PCM; peak 0.85; no playback')
