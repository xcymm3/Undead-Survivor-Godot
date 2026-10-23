"""Encode original isolated prologue frames without changing their scene timing."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path('artifacts/ultimate-entry')
timing = json.loads((root / 'timing.json').read_text(encoding='utf-8'))
frames = [Image.open(file).convert('RGB') for file in sorted(root.glob('frame-*.png'))]
assert len(frames) == timing['frames']
durations = [round((i + 1) * 100 / timing['fps']) * 10 - round(i * 100 / timing['fps']) * 10 for i in range(len(frames))]
frames[0].save(root / 'ultimate-entry.gif', save_all=True, append_images=frames[1:], duration=durations,
               loop=0, optimize=False, disposal=2)
indices = [80, 96, 110, 120, 150, 186, 198, 232, 244, 260, 268, 286]
sheet = Image.new('RGB', (1440, 1280), '#080d17')
draw = ImageDraw.Draw(sheet)
for i, frame in enumerate(indices):
    x, y = (i % 3) * 480, (i // 3) * 320
    sheet.paste(frames[frame].resize((480, 300)), (x, y))
    draw.text((x + 8, y + 301), f'{frame / timing["fps"]:.2f}s | frame {frame}', fill='white')
sheet.save(root / 'contact.png')
print(f'ULTIMATE ENTRY GIF: {len(frames)} original frames, {timing["fps"]} fps')
