"""36-second revision; reuse approved footage and replace the crystal-only scene."""
from functools import lru_cache
import json
import sys
from PIL import Image, ImageDraw, ImageChops
import edit40v2 as video

video.OUT = video.base.ROOT / 'artifacts/trailer36-v3'
video.TARGET = video.OUT / 'Undead-Survivor-Trailer-36s-V3-1080p.mp4'
video.DURATION = 36
video.FREEZE_START = None
video.FADE_START = video.FINAL_ACCENT = 35
video.FIRE_ACCENT = 1.5
video.CAPTURE_REVISION = 3
video.CARDS = [(0, 1.5, '迎击海量尸潮'), (11, 12.5, '守住最后防线'),
               (22, 23.5, '升级永久保留'), (26, 27.5, '筑起你的防线'),
               (30, 31.5, '并肩迎战')]
video.CLIPS = [
    (1.5, 3, 'rifle', 2, 1.00), (3, 4, 'rifle', 3.5, 1.12),
    (4, 5.5, 'rifle', 4.5, 1.02),
    (5.5, 8, 'ultimate', 0, 1.00), (8, 9, 'ultimate', 2.5, 1.10),
    (9, 9.5, 'ultimate', 3.5, 1.00), (9.5, 11, 'ultimate', 4, 1.05),
    (12.5, 14, 'defense', 0, 1.00), (14, 15.5, 'defense', 1.5, 1.10),
    (15.5, 17, 'defense', 3, 1.00),
    (17, 19.5, 'boss', 0, 1.08), (19.5, 22, 'boss', 2.5, 1.00),
    (23.5, 25.5, 'upgrade', 0, 1.00), (25.5, 26, 'upgraded', .25, 1.04),
    (27.5, 28, 'build', 0, 1.00), (28, 29, 'build', .5, 1.11),
    (29, 30, 'build', 1.5, 1.00),
    (31.5, 33, 'team', 0, 1.00), (33, 34, 'team', 1.5, 1.10),
    (34, 36, 'team', 2.5, 1.00),
]

PREVIOUS = video.base.ROOT / 'artifacts/trailer40-v2'
INPUTS = {}
for shot in {row[2] for row in video.CLIPS}:
    own = video.OUT / 'frames' / shot
    INPUTS[shot] = own if shot == 'defense' or (own/'00000.jpg').exists() else PREVIOUS/'frames'/shot


@lru_cache(maxsize=6)
def source_frame(shot, number):
    with Image.open(INPUTS[shot]/f'{number:05d}.jpg') as raw:
        pic = raw.convert('RGB').resize((1920, 804), Image.Resampling.LANCZOS)
    return ImageChops.multiply(pic.point(video.base.COLOR_LUT), video.base.VIGNETTE)


def previews():
    points = [0, .5, 1.3, 1.75, 3, 5, 6.8, 8.2, 10.4, 11.75, 13.2, 14.75,
              16.6, 18.5, 21.5, 22.75, 24.4, 26.75, 28.8, 30.75, 32.5, 34.5, 35.5, 863/24]
    sheet = Image.new('RGB', (1920, 1800))
    draw = ImageDraw.Draw(sheet)
    for i, seconds in enumerate(points):
        im = video.frame_at(min(863, round(seconds*24)))
        x, y = i%4*480, i//4*300
        sheet.paste(im.resize((480, 270)), (x, y))
        draw.text((x+12, y+273), f'{seconds:.2f}s', font=video.base.font(18, False), fill='white')
    sheet.save(video.OUT/'contact-sheet.jpg', quality=95)
    video.frame_at(round(34.75*24)).save(video.OUT/'poster.jpg', quality=97)


video.source_frame = source_frame
video.previews = previews

if __name__ == '__main__':
    video.OUT.mkdir(exist_ok=True)
    (video.OUT/'inputs.json').write_text(json.dumps({shot: str(path) for shot, path in INPUTS.items()},
        ensure_ascii=False, indent=2), encoding='utf-8')
    if '--verify' in sys.argv:
        video.verify()
    elif '--preview' in sys.argv:
        previews()
    else:
        video.render()
