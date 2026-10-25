"""Encode unchanged isolated frames at their recorded simulation cadence."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

for view in ('overview', 'bridge'):
    root = Path('artifacts/forest-bridge') / view
    timing = json.loads((root / 'timing.json').read_text(encoding='utf-8'))
    frames = [Image.open(file).convert('RGB') for file in sorted(root.glob('frame-*.png'))]
    assert len(frames) == timing['frames']
    durations = [round((i + 1) * 100 / timing['fps']) * 10 - round(i * 100 / timing['fps']) * 10 for i in range(len(frames))]
    frames[0].save(root / f'{view}.gif', save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=False, disposal=2)
    sheet = Image.new('RGB', (1440, 960), '#080d17')
    draw = ImageDraw.Draw(sheet)
    for i, frame in enumerate([0, 18, 36, 54, 72, 90, 108, 126, 143]):
        x, y = i % 3 * 480, i // 3 * 320
        sheet.paste(frames[frame].resize((480, 300)), (x, y))
        draw.text((x + 8, y + 302), f'{frame / timing["fps"]:.2f}s | frame {frame}', fill='white')
    sheet.save(root / 'contact.png')
    print(f'FOREST GIF: {view}, {len(frames)} frames, {timing["fps"]} fps')
