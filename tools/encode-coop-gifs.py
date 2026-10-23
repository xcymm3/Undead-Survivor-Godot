"""Encode original isolated game captures, preserving the recorded frame timing."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path('artifacts/coop-review')
for directory in sorted(root.iterdir()):
    if not directory.is_dir() or not (directory / 'timing.json').exists():
        continue
    timing = json.loads((directory / 'timing.json').read_text(encoding='utf-8'))
    files = sorted(directory.glob('frame-*.png'))
    assert len(files) == timing['frames'], directory
    frames = [Image.open(file).convert('RGB') for file in files]
    durations = [round((i + 1) * 100 / timing['fps']) * 10 - round(i * 100 / timing['fps']) * 10 for i in range(len(frames))]
    frames[0].save(root / f'{directory.name}.gif', save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, optimize=False, disposal=2)
    sheet = Image.new('RGB', (1440, 4 * 320), '#171e19')
    draw = ImageDraw.Draw(sheet)
    for index in range(12):
        frame = round(index * (len(frames) - 1) / 11)
        x, y = (index % 3) * 480, (index // 3) * 320
        sheet.paste(frames[frame].resize((480, 300)), (x, y))
        draw.text((x + 8, y + 301), f'{directory.name} | {frame / timing["fps"]:.2f}s', fill='white')
    sheet.save(root / f'{directory.name}-contact.png')
    with Image.open(root / f'{directory.name}.gif') as gif:
        assert gif.n_frames > 1
    print(f'{directory.name}: {len(frames)} frames -> {root / (directory.name + ".gif")}')
