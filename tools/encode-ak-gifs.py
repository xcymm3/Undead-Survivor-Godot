"""Encode the original isolated Godot frames at their recorded 20 FPS."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path('artifacts/ak47-review')
for action in ('fire', 'reload', 'shove'):
    directory = root / action
    timing = json.loads((directory / 'timing.json').read_text(encoding='utf-8'))
    frames = [Image.open(p).convert('RGB') for p in sorted(directory.glob('frame-*.png'))]
    assert len(frames) == timing['frames']
    durations = [round((i + 1) * 100 / timing['fps']) * 10 - round(i * 100 / timing['fps']) * 10 for i in range(len(frames))]
    frames[0].save(root / f'ak47-{action}.gif', save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=False, disposal=2)
    sheet = Image.new('RGB', (1440, 4 * 320), '#171e19')
    draw = ImageDraw.Draw(sheet)
    for index in range(12):
        frame = round(index * (len(frames) - 1) / 11)
        x, y = (index % 3) * 480, (index // 3) * 320
        sheet.paste(frames[frame].resize((480, 300)), (x, y))
        draw.text((x + 8, y + 301), f'{action} | {frame / timing["fps"]:.2f}s', fill='white')
    sheet.save(root / f'ak47-{action}-contact.png')
    with Image.open(root / f'ak47-{action}.gif') as gif:
        assert gif.n_frames > 1 and gif.size == (960, 600)
        actual_duration = sum((gif.seek(i) or gif.info.get('duration', 0)) for i in range(gif.n_frames))
        assert actual_duration == sum(durations), (action, actual_duration, sum(durations))
    print(f'{action}: {len(frames)} source frames, {sum(durations)} ms')
