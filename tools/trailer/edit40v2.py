"""40-second recut: separate black title cards, event-synced score, short ending."""
from pathlib import Path
from functools import lru_cache
import io
import json
import hashlib
import re
import subprocess
import wave
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageChops
import edit as base

OUT = base.ROOT / 'artifacts/trailer40-v2'
TARGET = OUT / 'Undead-Survivor-Trailer-40s-V2-1080p.mp4'
FPS, RATE = 24, base.RATE
HERO_FRAME = 153
CARDS = [(1.5, 3, '迎击海量尸潮'), (11, 12.5, '守住最后防线'),
         (22, 23.5, '升级永久保留'), (26, 27.5, '筑起你的防线'),
         (30, 31.5, '并肩迎战')]
# Start/end, source shot, in-point, initial crop. No speed changes or invented gameplay.
CLIPS = [
    (0, .5, 'rifle', 0, 1.00), (.5, 1, 'rifle', .75, 1.12),
    (1, 1.5, 'rifle', 1.5, 1.03),
    (3, 4, 'rifle', 2, 1.00), (4, 4.5, 'rifle', 3, 1.12),
    (4.5, 5.5, 'rifle', 3.5, 1.02),
    (5.5, 8, 'ultimate', 0, 1.00), (8, 9, 'ultimate', 2.5, 1.10),
    (9, 9.5, 'ultimate', 3.5, 1.00), (9.5, 11, 'ultimate', 4, 1.05),
    (12.5, 14, 'defense', 0, 1.00), (14, 15.5, 'defense', 1.5, 1.10),
    (15.5, 17, 'defense', 3, 1.00),
    (17, 19.5, 'boss', 0, 1.08), (19.5, 22, 'boss', 2.5, 1.00),
    (23.5, 25.5, 'upgrade', 0, 1.00), (25.5, 26, 'upgraded', .25, 1.04),
    (27.5, 28, 'build', 0, 1.00), (28, 29, 'build', .5, 1.11),
    (29, 30, 'build', 1.5, 1.00),
    (31.5, 34, 'team', 0, 1.00), (34, 36, 'team', 2.5, 1.10),
    (36, 38, 'team', 106/FPS, 1.00),
]


@lru_cache(maxsize=6)
def source_frame(shot, number):
    with Image.open(OUT / 'frames' / shot / f'{number:05d}.jpg') as raw:
        pic = raw.convert('RGB').resize((1920, 804), Image.Resampling.LANCZOS)
    return ImageChops.multiply(pic.point(base.COLOR_LUT), base.VIGNETTE)


def frame_at(number):
    t = number / FPS
    canvas = Image.new('RGB', (1920, 1080))
    for start, end, text in CARDS:
        if start <= t < end:
            opacity = base.smooth(start, start + .25, t) * (1 - base.smooth(end - .5, end - 1/FPS, t))
            art = base.text_art(text, 88, (245, 245, 245), True, 9)
            base.title(canvas, text, (1080-art.height)//2, 88, (245, 245, 245), opacity=opacity, tracking=9)
            return canvas
    if t >= 38:
        pic = source_frame('team', HERO_FRAME)
    else:
        start, end, shot, point, zoom = next(row for row in CLIPS if row[0] <= t < row[1])
        pic = source_frame(shot, round((point+t-start)*FPS))
        # Fixed alternate framing makes short cuts legible while preserving the action.
        if zoom > 1:
            expanded = pic.resize((round(1920*zoom), round(804*zoom)), Image.Resampling.LANCZOS)
            x, y = (expanded.width-1920)//2, (expanded.height-804)//2
            pic = expanded.crop((x, y, x+1920, y+804))
    canvas.paste(pic, (0, 138))
    if t >= 39:
        alpha = 1-base.smooth(39, 40-1/FPS, t)
        canvas = canvas.point([round(i*alpha) for i in range(256)]*3)
    return canvas


def mapped_cues():
    records = json.loads((OUT/'capture.json').read_text(encoding='utf-8'))['records']
    result = []
    for start, end, shot, point, _ in CLIPS:
        for record in records:
            if record['shot'] != shot:
                continue
            for cue in record['cues']:
                if cue['kind'] == 'crystal_hit' and shot not in ['defense', 'team']:
                    continue
                if point-1e-6 <= cue['time'] < point+end-start-1e-6:
                    result.append({'kind': cue['kind'], 'time': start+cue['time']-point,
                                   'until': 39 if end == 38 else end, 'shot': shot, 'sourceTime': cue['time']})
    return sorted(result, key=lambda row: row['time'])


def soundtrack():
    rng = np.random.default_rng(20261023)
    music = np.zeros((40*RATE, 2), np.float32)
    effects = np.zeros_like(music)
    cues = mapped_cues()
    chords = [(50, 53, 57), (46, 50, 53), (48, 52, 55), (45, 48, 52)]
    for bar in range(20):
        for j, note in enumerate(chords[0 if bar == 19 else (bar//2)%4]):
            base.add(music, base.synth(base.midi(note), 2.2, 'pad'), bar*2, .052, [-.6, 0, .6][j])
    base.add(music, base.synth(base.midi(26), 2, 'pad'), 38, .12)
    t = np.arange(int(.42*RATE))/RATE
    kick = (np.sin(2*np.pi*(46*t+100*.028*(1-np.exp(-t/.028))))
            + rng.normal(0, .04, len(t))*np.exp(-t*100))*np.exp(-t*12)
    st = np.arange(int(.20*RATE))/RATE
    snare = (rng.normal(0, .4, len(st))+.24*np.sin(2*np.pi*185*st))*np.exp(-st*25)
    ht = np.arange(int(.065*RATE))/RATE
    hat = np.diff(rng.normal(0, 1, len(ht)), prepend=0)*np.exp(-ht*78)*.12
    snaps = []
    gun_times = [c['time'] for c in cues if c['kind'] == 'rifle']
    # Keep gun sounds on the actual rendered events. Move nearby drum attacks to them.
    for beat in range(76):
        at = beat*.5
        if 6 <= at < 7.75:
            continue
        card = any(a <= at < b for a, b, _ in CARDS)
        gain = .24 if card else .9 if 17 <= at < 22 else 1.1
        nearest = min(gun_times, key=lambda x: abs(x-at)) if gun_times else at
        attack = nearest if not card and abs(nearest-at) <= 1.1/FPS else at
        if attack != at:
            snaps.append({'beat': at, 'attack': attack})
        base.add(music, kick, attack, .31*gain)
        if beat%2:
            base.add(music, snare, attack, .18*gain)
        for offset in [0, .25]:
            base.add(music, hat, at+offset, .22*gain, (-1)**beat*.4)
        root = chords[(int(at//2)//2)%4][0]-24
        note = root+[0, 0, 12, 0, 7, 0, 10, 12][beat%8]
        base.add(music, base.synth(base.midi(note), .39), at, .17*gain)
        if not card and at >= 7.75:
            base.add(music, base.synth(base.midi(note+36), .22, 'pluck'), at+.25, .028*gain, (-1)**beat*.5)
    tt = np.arange(RATE)/RATE
    impact = (np.sin(2*np.pi*(31*tt+70*.06*(1-np.exp(-tt/.06))))
              + rng.normal(0, .12, RATE))*np.exp(-tt*7)
    first_blade = min(c['time'] for c in cues if c['kind'] == 'blade')
    accents = [0, 3, first_blade, 12.5, 17, 23.5, 27.5, 31.5, 38]
    accents += [c['time'] for c in cues if c['kind'] == 'explosion']
    for at in accents:
        base.add(music, impact, at, .43)
    # Accelerating roll into the first real blade strike, followed by an uncluttered hit.
    for at in np.arange(first_blade-.5, first_blade-.06, .0625):
        base.add(music, snare, float(at), .08)
    samples = {name: base.wavefile(file) for name, file in {
        'rifle': 'weapon-rifle.wav', 'blade': 'blade-swing.wav',
        'ultimate_start': 'blade-draw.wav', 'disco': 'disco.wav',
        'explosion': 'grenade-explosion.wav', 'world_upgrade': 'reload.wav',
        'crystal_hit': 'enemy-impact.wav', 'build': 'reload.wav'}.items()}
    duck = np.ones(40*RATE, np.float32)
    for cue in cues:
        if cue['kind'] not in samples:
            continue
        sample = samples[cue['kind']]
        # Cut with the shot, except the final gun tails can ring through its freeze.
        count = min(len(sample), round((cue['until']-cue['time'])*RATE))
        sample = sample[:count].copy()
        tail = min(count, round(.012*RATE))
        if tail:
            sample[-tail:] *= np.linspace(1, 0, tail)
        simultaneous = sum(c['kind'] == cue['kind'] and abs(c['time']-cue['time']) < .001 for c in cues)
        volume = .55 if cue['kind'] == 'rifle' else .22 if cue['kind'] == 'crystal_hit' else .47
        gain = volume/np.sqrt(simultaneous)
        base.add(effects, sample, cue['time'], gain, float(rng.uniform(-.18, .18)))
        a = round(cue['time']*RATE)
        length = min(round(.14*RATE), len(duck)-a)
        if length > 0 and cue['kind'] in ['rifle', 'blade', 'explosion', 'ultimate_start']:
            duck[a:a+length] = np.minimum(duck[a:a+length], np.linspace(.55, 1, length))
    # Empty-magazine pause and draw: remove the rhythm bed, preserve the native draw cue.
    duck[round(6.0*RATE):round(7.25*RATE)] *= .12
    click_t = np.arange(round(.065*RATE))/RATE
    dry_click = (np.sin(2*np.pi*1800*click_t)+rng.normal(0, .2, len(click_t)))*np.exp(-click_t*90)
    for at in [6, 6.25]:
        base.add(effects, dry_click, at, .15)
    mix = np.tanh((music*duck[:, None]+effects)*1.5)*.75
    mix[-RATE:] *= np.linspace(1, 0, RATE)[:, None]
    with wave.open(str(OUT/'mix-unmastered.wav'), 'wb') as audio:
        audio.setnchannels(2); audio.setsampwidth(2); audio.setframerate(RATE)
        audio.writeframes((mix*32767).astype('<i2').tobytes())
    (OUT/'audio-cues.json').write_text(json.dumps({'bpm': 120, 'sourceAlignedCues': cues,
        'drumSnaps': snaps, 'firstBladeImpact': first_blade,
        'designedDryClicks': [6, 6.25]}, indent=2), encoding='utf-8')
    return master_audio()


def master_audio():
    raw, target = OUT/'mix-unmastered.wav', OUT/'soundtrack.wav'
    if not raw.exists():
        shutil.copyfile(target, raw)
    # These sharp gun transients overshoot during AAC reconstruction. Keep margin
    # in the PCM master, then measure the actual encoded delivery file below.
    goal = 'loudnorm=I=-14:TP=-4.5:LRA=7'
    first = subprocess.run([base.FFMPEG, '-hide_banner', '-i', str(raw), '-af',
        goal+':print_format=json', '-f', 'null', '-'], capture_output=True,
        text=True, creationflags=base.NO_WINDOW, check=True)
    measured = json.loads(re.search(r'\{\s*"input_i".*?\}', first.stderr, re.S)[0])
    params = ':'.join(f'{key}={measured[value]}' for key, value in {
        'measured_I': 'input_i', 'measured_TP': 'input_tp', 'measured_LRA': 'input_lra',
        'measured_thresh': 'input_thresh', 'offset': 'target_offset'}.items())
    second = subprocess.run([base.FFMPEG, '-y', '-hide_banner', '-i', str(raw), '-af',
        goal+':'+params+':linear=true:print_format=json,volume=1.5dB', '-ar', str(RATE), '-c:a', 'pcm_s16le', str(target)],
        capture_output=True, text=True, creationflags=base.NO_WINDOW, check=True)
    (OUT/'mastering.log').write_text(first.stderr+'\nSECOND PASS\n'+second.stderr, encoding='utf-8')
    with wave.open(str(target)) as audio:
        assert audio.getnframes() == 40*RATE and audio.getframerate() == RATE
    return target


def previews():
    points = [.2, .75, 2.25, 3.5, 5.9, 6.8, 8.2, 10.4, 11.75, 13.5,
              16, 18.5, 20.8, 22.75, 24.4, 26.75, 28.3, 30.75, 32.5, 35,
              37.5, 38.5, 39.5, 39.96]
    sheet = Image.new('RGB', (1920, 1800))
    draw = ImageDraw.Draw(sheet)
    for i, seconds in enumerate(points):
        im = frame_at(min(959, round(seconds*FPS)))
        x, y = i%4*480, i//4*300
        sheet.paste(im.resize((480, 270)), (x, y))
        draw.text((x+12, y+273), f'{seconds:.2f}s', font=base.font(18, False), fill='white')
    sheet.save(OUT/'contact-sheet.jpg', quality=95)
    frame_at(38*FPS).save(OUT/'poster.jpg', quality=97)


def decoded_frame(seconds):
    result = subprocess.run([base.FFMPEG, '-v', 'error', '-ss', str(seconds), '-i', str(TARGET),
        '-frames:v', '1', '-f', 'image2pipe', '-vcodec', 'png', 'pipe:1'],
        capture_output=True, creationflags=base.NO_WINDOW, check=True)
    return Image.open(io.BytesIO(result.stdout)).convert('RGB')


def verify():
    coverage = np.zeros(960, np.int32)
    for start, end, *_ in CLIPS+CARDS+[(38, 40)]:
        coverage[round(start*FPS):round(end*FPS)] += 1
    assert np.all(coverage == 1)
    for a, b, _ in CARDS:
        assert not frame_at(round(a*FPS)).getbbox()
        assert not frame_at(round(b*FPS)-1).getbbox()
        bbox = frame_at(round((a+.5)*FPS)).getbbox()
        assert bbox and bbox[1] > 350 and bbox[3] < 700
    assert frame_at(38*FPS).tobytes() == frame_at(39*FPS-1).tobytes()
    assert not frame_at(959).getbbox()
    data = json.loads((OUT/'capture.json').read_text(encoding='utf-8'))
    source = json.loads((OUT/'source.json').read_text(encoding='utf-8'))
    assert source['revision'] == 2 and not data['errors'] and not any(data['safety'].values())
    for shot, duration in source['shots'].items():
        assert sum(r['shot'] == shot for r in data['records']) == round(duration*FPS)
    for shot in ['defense', 'team']:
        rows = [r for r in data['records'] if r['shot'] == shot]
        assert all(r['structures'] == 0 and r['team'] == 4 for r in rows)
    hero = next(r for r in data['records'] if r['shot'] == 'team' and r['frame'] == HERO_FRAME)
    assert sum(c['kind'] == 'rifle' for c in hero['cues']) == 4
    assert max(r['kills'] for r in data['records'] if r['shot'] == 'ultimate') > 0
    assert max(r['summoned'] for r in data['records'] if r['shot'] == 'boss') > 0
    assert max(r['level'] for r in data['records'] if r['shot'] == 'upgrade') > 0
    assert all(r['level'] == 1 for r in data['records'] if r['shot'] == 'upgraded')
    for shot in ['rifle', 'build']:
        assert any(c['kind'] == 'explosion' for r in data['records'] if r['shot'] == shot for c in r['cues'])
    result = subprocess.run([base.FFMPEG, '-hide_banner', '-i', str(TARGET), '-f', 'null', '-'],
        capture_output=True, text=True, encoding='utf-8', errors='replace', creationflags=base.NO_WINDOW)
    (OUT/'decode.log').write_text(result.stderr, encoding='utf-8')
    assert result.returncode == 0 and '00:00:40.00' in result.stderr and '1920x1080' in result.stderr and '24 fps' in result.stderr
    audio = subprocess.run([base.FFMPEG, '-hide_banner', '-i', str(TARGET), '-af', 'ebur128=peak=true', '-vn', '-f', 'null', '-'],
        capture_output=True, text=True, creationflags=base.NO_WINDOW)
    (OUT/'loudness.log').write_text(audio.stderr, encoding='utf-8')
    peak = float(re.search(r'True peak:\s+Peak:\s+([\d.-]+)', audio.stderr)[1])
    assert audio.returncode == 0 and peak <= -1
    loudness = float(re.search(r'Integrated loudness:\s+I:\s+([\d.-]+)', audio.stderr)[1])
    assert -15 <= loudness <= -13
    frozen = np.asarray(decoded_frame(38.1)).astype(float)
    assert np.mean(np.abs(frozen-np.asarray(decoded_frame(38.9)))) < .5
    assert np.asarray(decoded_frame(39.5)).mean() < frozen.mean()*.75
    assert np.asarray(decoded_frame(959/FPS)).max() <= 3
    report = {'status': 'passed', 'duration': 40, 'size': [1920, 1080], 'fps': FPS,
        'captions': [c[2] for c in CARDS], 'cards': CARDS, 'freeze': [38, 39], 'fadeToBlack': [39, 40],
        'finalPlayers': 4, 'heroSourceFrame': HERO_FRAME, 'crystalShotsHaveStructures': False,
        'truePeakDBTP': peak, 'integratedLUFS': loudness,
        'nativeFrames': len(data['records']), 'source': source, 'bytes': TARGET.stat().st_size,
        'sha256': hashlib.sha256(TARGET.read_bytes()).hexdigest()}
    (OUT/'video-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)


def render():
    wav = soundtrack()
    args = [base.FFMPEG, '-y', '-hide_banner', '-loglevel', 'warning', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
        '-s', '1920x1080', '-r', '24', '-i', 'pipe:0', '-i', str(wav), '-c:v', 'libx264', '-preset', 'fast',
        '-crf', '18', '-pix_fmt', 'yuv420p', '-threads', '2', '-c:a', 'aac', '-b:a', '256k', '-ar', '48000',
        '-t', '40', '-movflags', '+faststart', str(TARGET)]
    with (OUT/'encode.log').open('wb') as log:
        p = subprocess.Popen(args, stdin=subprocess.PIPE, stderr=log, creationflags=base.NO_WINDOW)
        try:
            for n in range(960):
                p.stdin.write(frame_at(n).tobytes())
                if n%120 == 0:
                    print(f'Edit {n/FPS:.1f}/40s', flush=True)
            p.stdin.close()
            assert p.wait() == 0
        finally:
            if p.poll() is None:
                p.terminate(); p.wait()
    previews()
    verify()


if __name__ == '__main__':
    import sys
    if '--master' in sys.argv:
        wav = master_audio()
        temporary = TARGET.with_suffix('.remux.mp4')
        subprocess.run([base.FFMPEG, '-y', '-hide_banner', '-loglevel', 'warning', '-i', str(TARGET),
            '-i', str(wav), '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'copy', '-c:a', 'aac',
            '-b:a', '256k', '-ar', str(RATE), '-t', '40', '-movflags', '+faststart', str(temporary)],
            creationflags=base.NO_WINDOW, check=True)
        temporary.replace(TARGET)
        verify()
    elif '--verify' in sys.argv:
        verify()
    elif '--preview' in sys.argv:
        previews()
    else:
        render()
