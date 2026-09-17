"""Generate the original procedural grenade explosion cue; never plays audio."""
import math, random, struct, wave
from pathlib import Path
rng = random.Random(20260914)
sample_rate = 22050
samples = bytearray()
low = 0.0
for i in range(int(sample_rate * 1.15)):
    t = i / sample_rate
    low = low * .88 + rng.uniform(-1, 1) * .12
    envelope = min(1, t / .003) * math.exp(-t * 5)
    value = (low * 2.4 + math.sin(2 * math.pi * (65 * t - 14 * t * t)) * .38) * envelope
    samples.extend(struct.pack('<h', int(max(-1, min(1, value)) * 28000)))
with wave.open(str(Path(__file__).resolve().parents[1] / 'assets/audio/grenade-explosion.wav'), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(sample_rate)
    output.writeframes(samples)

# Original pin/throw swish and short burning-fuse warning, emitted spatially.
for name, duration in [('grenade-throw', .28), ('grenade-fuse', .12)]:
    samples = bytearray()
    low = 0.0
    for i in range(int(sample_rate * duration)):
        t = i / sample_rate
        noise = rng.uniform(-1, 1)
        low = low * .65 + noise * .35
        if name == 'grenade-throw':
            value = (low * .65 + math.sin(2 * math.pi * 2100 * t) * math.exp(-t * 65) * .35) * math.sin(math.pi * t / duration)
        else:
            value = (noise * .12 + math.sin(2 * math.pi * 1350 * t) * .22) * math.sin(math.pi * t / duration) ** 2
        samples.extend(struct.pack('<h', int(max(-1, min(1, value)) * 28000)))
    with wave.open(str(Path(__file__).resolve().parents[1] / ('assets/audio/' + name + '.wav')), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(samples)
