"""Development-only generation of original campaign machinery and warning cues."""
import math
import struct
import wave
from pathlib import Path

root = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
rate = 22050
for name, duration, frequency in [('winch', 1.5, 90), ('horde', 1.0, 310), ('gate', 1.2, 520)]:
    samples = []
    for index in range(int(rate * duration)):
        t = index / rate
        envelope = min(1, t * 20) * min(1, (duration - t) * 8)
        if name == 'winch':
            signal = math.sin(2 * math.pi * frequency * t) * .5 + math.sin(2 * math.pi * 183 * t) * .25
        elif name == 'horde':
            signal = math.sin(2 * math.pi * (frequency * t + 25 * math.sin(t * 7))) * .6
        else:
            signal = math.sin(2 * math.pi * frequency * t) * math.exp(-t * 3) + .25 * math.sin(2 * math.pi * 780 * t)
        samples.append(struct.pack('<h', int(signal * envelope * 12000)))
    with wave.open(str(root / f'campaign-{name}.wav'), 'wb') as output:
        output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        output.writeframes(b''.join(samples))
