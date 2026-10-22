"""Encode isolated, deterministic production-scene frames at their recorded timing."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path('artifacts/demo-endings')
for kind in ('failure', 'victory'):
    directory = root / kind
    timing = json.loads((directory / 'timing.json').read_text(encoding='utf-8'))
    frames = [Image.open(file).convert('RGB') for file in sorted(directory.glob('frame-*.png'))]
    assert len(frames) == timing['frames']
    durations = [round((i + 1) * 100 / timing['fps']) * 10 - round(i * 100 / timing['fps']) * 10 for i in range(len(frames))]
    frames[0].save(root / f'{kind}.gif', save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, optimize=False, disposal=2)
    sheet = Image.new('RGB', (960, 3 * 320), '#171e19')
    draw = ImageDraw.Draw(sheet)
    for index in range(6):
        frame = round(index * (len(frames) - 1) / 5)
        thumb = frames[frame].resize((480, 300))
        x, y = (index % 2) * 480, (index // 2) * 320
        sheet.paste(thumb, (x, y))
        draw.text((x + 8, y + 301), f'{frame / timing["fps"]:.2f}s', fill='white')
    sheet.save(root / f'{kind}-contact.png')
