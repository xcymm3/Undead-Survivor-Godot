"""Deterministic 60-second promotional edit and original electronic score.

Requires Pillow, NumPy, SciPy and imageio-ffmpeg. No app windows are opened.
Raw captures and final media live in artifacts/trailer, outside game resources.
"""
from pathlib import Path
from functools import lru_cache
import argparse
import hashlib
import json
import math
import re
import subprocess
import wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter
from scipy.signal import resample_poly
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/trailer"
FPS, WIDTH, HEIGHT, ACTIVE, TOP, RATE = 24, 1920, 1080, 804, 138, 48000
DURATION = 60
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
IVORY, ORANGE = (244, 238, 220), (255, 104, 45)
CN = ROOT / "assets/fonts/NotoSansCJKsc-Regular.otf"
LATIN = Path("C:/Windows/Fonts/bahnschrift.ttf")
if not LATIN.exists(): LATIN = CN

# Output start, duration, native shot, source in-point. All cuts sit on frame boundaries.
EDIT = [
    (0, .75, "rifle", 1.0), (.75, .75, "axe", 1.5),
    (1.5, .75, "boss", 2.6), (2.25, .75, None, 0),
    (3, 5, "horde", 0), (8, 7, "rifle", 0),
    (15, 2, None, 0), (17, 7, "axe", 0),
    (24, 2, None, 0), (26, 8, "boss", 0),
    (34, 3, "armory", 0), (37, 3, "rifle", 3),
    (40, 2, "axe", 2), (42, 2, "boss", 5),
    (44, 3, "rifle", 2), (47, 5, "finale", 0),
    (52, 3, "finale", 5), (55, 5, None, 0),
]


@lru_cache(maxsize=40)
def font(size, chinese=True):
    return ImageFont.truetype(str(CN if chinese else LATIN), size)


def smooth(a, b, value):
    t = np.clip((value-a)/(b-a), 0, 1)
    return float(t*t*(3-2*t))


@lru_cache(maxsize=30)
def text_art(text, size, color=IVORY, chinese=True, tracking=0):
    face = font(size, chinese)
    box = face.getbbox(text)
    width = math.ceil(face.getlength(text)) + max(0, len(text)-1)*tracking + 32
    height = box[3]-box[1]+32
    image = Image.new("RGBA", (width, height))
    draw = ImageDraw.Draw(image)
    if tracking:
        x = 16
        for char in text:
            draw.text((x,16-box[1]),char,font=face,fill=color,stroke_width=1 if chinese else 0,stroke_fill=color)
            x += face.getlength(char)+tracking
    else:
        draw.text((16,16-box[1]),text,font=face,fill=color,stroke_width=1 if chinese else 0,stroke_fill=color)
    return image


def title(image, text, y, size=94, color=IVORY, opacity=1, scale=1, tracking=0, chinese=True, x=None):
    art = text_art(text, size, color, chinese, tracking)
    if scale != 1:
        art = art.resize((int(art.width*scale), int(art.height*scale)), Image.Resampling.BICUBIC)
    if opacity < 1:
        art = art.copy()
        art.putalpha(art.getchannel("A").point(lambda a: int(a*max(0,opacity))))
    px = (WIDTH-art.width)//2 if x is None else x
    shadow = Image.new("RGBA", art.size, (0,0,0,0))
    shadow.putalpha(art.getchannel("A").point(lambda a: int(a*.65)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(7))
    image.paste(shadow,(px,y+5),shadow)
    image.paste(art,(px,y),art)


Y, X = np.mgrid[0:ACTIVE,0:WIDTH]
v = np.clip(1-.35*((X-WIDTH/2)/(WIDTH/2))**2-.24*((Y-ACTIVE/2)/(ACTIVE/2))**2,.47,1)
VIGNETTE = Image.fromarray((v*255).astype(np.uint8)).convert("RGB")
del X,Y,v
COLOR_LUT = []
for c in range(3):
    COLOR_LUT.extend([int(np.clip(((i/255-.5)*1.14+.5)*[1.02,1.01,1.045][c]*255-2,0,255)) for i in range(256)])
CARD_BG = Image.new("RGB",(WIDTH,HEIGHT),(7,10,14))
for yy in range(TOP,TOP+ACTIVE):
    # Warm light through smoke, concentrated behind the main typography.
    strength = max(0,1-abs(yy-590)/500)
    ImageDraw.Draw(CARD_BG).line((0,yy,WIDTH,yy),fill=(int(8+18*strength),int(11+3*strength),int(15+1*strength)))
CARD_BG = CARD_BG.filter(ImageFilter.GaussianBlur(12))
EMBERS = np.random.default_rng(19).uniform(0,1,(52,5))


def card_background(t):
    image = CARD_BG.copy()
    draw = ImageDraw.Draw(image)
    for x,y,speed,length,phase in EMBERS:
        px = int((x*WIDTH+math.sin(t*.2+phase*6)*35)%WIDTH)
        py = int(TOP+(y*ACTIVE-t*(12+speed*25))%ACTIVE)
        intensity = int(65+60*math.sin(t+phase*6)**2)
        draw.line((px,py,px-2,py+int(2+length*6)),fill=(intensity,intensity//3,16),width=1)
    return image


def source_frame(shot, seconds):
    number = max(0,int(round(seconds*FPS)))
    file = OUT / "frames" / shot / f"{number:05d}.jpg"
    with Image.open(file) as raw:
        native = raw.convert("RGB").resize((WIDTH,ACTIVE),Image.Resampling.LANCZOS)
    native = native.point(COLOR_LUT)
    return ImageChops.multiply(native,VIGNETTE)


def frame_at(number):
    t = number/FPS
    start,duration,shot,inpoint = next(row for row in EDIT if row[0] <= t < row[0]+row[1])
    local = t-start
    if shot:
        image = Image.new("RGB",(WIDTH,HEIGHT))
        native = source_frame(shot,inpoint+local)
        # Tiny controlled punch-ins at montage cuts, with no fabricated scene content.
        if t < 2.25 or 37 <= t < 52:
            zoom = 1.01+.016*(1-smooth(0,.28,local))
            native = native.resize((int(WIDTH*zoom),int(ACTIVE*zoom)),Image.Resampling.BICUBIC)
            image.paste(native,((WIDTH-native.width)//2,TOP+(ACTIVE-native.height)//2))
        else: image.paste(native,(0,TOP))
        draw = ImageDraw.Draw(image)
        draw.rectangle((0,0,WIDTH,TOP-1),fill="black")
        draw.rectangle((0,TOP+ACTIVE,WIDTH,HEIGHT),fill="black")
    else:
        image = card_background(t)

    if 2.25 <= t < 3:
        title(image,"黑夜降临",454,88,opacity=smooth(0,.12,local),tracking=12)
    if 3.6 <= t < 7.7:
        k = smooth(3.6,4.0,t)*(1-smooth(7.4,7.7,t))
        # Lower left keeps the advancing bodies and weapon line unobstructed.
        title(image,"面对海量尸潮",746,76,opacity=k,x=102)
        title(image,"THE HORDE IS COMING",851,25,ORANGE,opacity=k,chinese=False,tracking=5,x=108)
    if 8.15 <= t < 10.2:
        k = smooth(8.15,8.35,t)*(1-smooth(9.95,10.2,t))
        title(image,"火力全开",800,49,opacity=k,x=102)
    if 15 <= t < 17:
        k = smooth(0,.18,local)*(1-smooth(1.7,2,local))
        title(image,"弹药有限",362,82,opacity=k,tracking=12)
        title(image,"战意无穷",496,112,ORANGE,opacity=k,scale=1.04-.04*smooth(0,.35,local),tracking=9)
    if 17.15 <= t < 19.2:
        k = smooth(17.15,17.35,t)*(1-smooth(18.95,19.2,t))
        title(image,"近身，决胜",800,49,opacity=k,x=102)
    if 24 <= t < 26:
        k = smooth(0,.15,local)*(1-smooth(1.7,2,local))
        title(image,"舞王登场",430,112,opacity=k,tracking=16)
        title(image,"THE DEAD DON'T REST",592,29,ORANGE,opacity=k,chinese=False,tracking=8)
    if 26.3 <= t < 28.1:
        k = smooth(26.3,26.55,t)*(1-smooth(27.85,28.1,t))
        title(image,"迪斯科舞王",810,48,opacity=k,x=102)
    if 31 <= t < 33.85:
        k = smooth(31,31.25,t)*(1-smooth(33.6,33.85,t))
        title(image,"召唤尸潮",796,57,opacity=k,x=102)
    if 34 <= t < 37:
        # Gradient over the left third gives text breathing room beside the actual rifle display.
        shade = Image.new("RGBA",(WIDTH,ACTIVE))
        sd = ImageDraw.Draw(shade)
        for xx in range(1100): sd.line((xx,0,xx,ACTIVE),fill=(4,8,12,int(170*(1-xx/1100))))
        image.paste(shade,(0,TOP),shade)
        k = smooth(0,.22,local)*(1-smooth(2.7,3,local))
        title(image,"持续升级",320,93,opacity=k,x=100)
        title(image,"枪械 · 天赋 · 防御工事",450,34,opacity=k,x=110)
        title(image,"BUILD YOUR ADVANTAGE",532,26,ORANGE,opacity=k,chinese=False,tracking=3,x=110)
    if 52.1 <= t < 55:
        k = smooth(52.1,52.45,t)*(1-smooth(54.7,55,t))
        title(image,"坚守到最后一刻",767,78,opacity=k)
    if t >= 55:
        k = smooth(0,.32,local)*(1-smooth(4.55,5,local))
        scale = 1.045-.045*smooth(0,1.1,local)
        title(image,"UNDEAD",287,151,opacity=k,chinese=False,scale=scale,tracking=8)
        title(image,"SURVIVOR",452,174,ORANGE,opacity=k,chinese=False,scale=scale,tracking=4)
        draw = ImageDraw.Draw(image)
        draw.line((690,697,1230,697),fill=tuple(int(c*k) for c in ORANGE),width=2)
        title(image,"第一人称增量 FPS",734,47,opacity=k,tracking=5)
        title(image,"准备迎战",844,28,opacity=k,tracking=14)
        title(image,"游戏引擎画面 · 宣传镜头经过编排",1003,19,(125,132,143),opacity=k)

    # Brief exposure accents on hard cuts, excluding the final readable title hold.
    if local < 1/FPS and start in [0,.75,1.5,8,17,26,37,40,42,44,47,55]:
        wash = Image.new("RGB",image.size,(196,134,72))
        image = Image.blend(image,wash,.11 if start != 55 else .2)
    if t >= 59.55:
        image = Image.blend(image,Image.new("RGB",image.size),smooth(59.55,60,t))
    return image


def add(mix, data, seconds, gain=1, pan=0):
    first = int(round(seconds*RATE))
    if first >= len(mix): return
    if first < 0: data,first = data[-first:],0
    count = min(len(data),len(mix)-first)
    if data.ndim == 1:
        mix[first:first+count,0] += data[:count]*gain*math.sqrt((1-pan)/2)
        mix[first:first+count,1] += data[:count]*gain*math.sqrt((1+pan)/2)
    else: mix[first:first+count] += data[:count]*gain


def wavefile(name):
    with wave.open(str(ROOT/"assets/audio"/name)) as audio:
        dtype = {1:np.uint8,2:np.int16,4:np.int32}[audio.getsampwidth()]
        data = np.frombuffer(audio.readframes(audio.getnframes()),dtype).astype(np.float32)
        data = (data-128)/128 if dtype == np.uint8 else data/float(np.iinfo(dtype).max)
        channels,sr = audio.getnchannels(),audio.getframerate()
    if channels > 1: data = data.reshape(-1,channels).mean(axis=1)
    divisor = math.gcd(RATE,sr)
    return resample_poly(data,RATE//divisor,sr//divisor).astype(np.float32)


def synth(freq, length, kind="bass"):
    t = np.arange(int(length*RATE),dtype=np.float32)/RATE
    if kind == "bass":
        signal = np.sin(2*np.pi*freq*t)+.27*np.sin(4*np.pi*freq*t)+.12*np.sin(6*np.pi*freq*t)
        envelope = np.minimum(t/.012,1)*np.exp(-t*2.8)
    elif kind == "pad":
        signal = sum(np.sin(2*np.pi*freq*ratio*t+phase) for ratio,phase in [(1,0),(1.002,.4),(.999,1.2)])/3
        envelope = np.minimum(t/.4,1)*np.minimum((length-t)/.7,1)
    else:
        signal = np.sin(2*np.pi*freq*t)+.25*np.sin(2*np.pi*freq*2*t)
        envelope = np.minimum(t/.005,1)*np.exp(-t*7)
    return (signal*envelope).astype(np.float32)


def midi(value): return 440*2**((value-69)/12)


def soundtrack():
    mix = np.zeros((DURATION*RATE,2),np.float32)
    rng = np.random.default_rng(1701)
    # Original D-minor score: tension -> heavy drums -> disco boss break -> finale.
    chords = [(50,53,57),(46,50,53),(48,52,55),(45,48,52)]
    for bar in range(30):
        at = bar*2
        chord = chords[(bar//2)%4]
        strength = .052 if at < 8 else .073
        for index,note in enumerate(chord):
            add(mix,synth(midi(note),2.4,"pad"),at,strength,[-.6,0,.6][index])
        add(mix,synth(midi(chord[0]-24),2.0,"pad"),at,.085)
    t = np.arange(int(.42*RATE))/RATE
    phase = 2*np.pi*(48*t+95*.027*(1-np.exp(-t/.027)))
    kick = np.sin(phase)*np.exp(-t*11)+rng.normal(0,.1,len(t))*np.exp(-t*180)
    st = np.arange(int(.23*RATE))/RATE
    snare = (rng.normal(0,1,len(st))*.45+np.sin(2*np.pi*180*st)*.26)*np.exp(-st*22)
    ht = np.arange(int(.075*RATE))/RATE
    noise = rng.normal(0,1,len(ht))
    hat = np.diff(noise,prepend=0)*np.exp(-ht*65)*.15
    for beat in range(110):
        at = beat*.5
        if at < 3 or 15 <= at < 17 or 24 <= at < 26: continue
        intensity = .55 if at < 8 else 1.0 if at < 37 else 1.22
        if beat%4 in [0,2] or 26 <= at < 34: add(mix,kick,at,.38*intensity)
        if beat%4 in [1,3]: add(mix,snare,at,.20*intensity,.05)
        add(mix,hat,at,.29*intensity,-.35)
        add(mix,hat,at+.25,.18*intensity,.35)
        root = chords[(int(at//2)//2)%4][0]-24
        pattern = [0,0,12,0,7,0,10,12] if 26 <= at < 34 else [0,0,0,12,0,7,0,10]
        note = root+pattern[beat%8]
        add(mix,synth(midi(note),.42),at,.19*intensity)
        if at >= 8:
            chord = chords[(int(at//2)//2)%4]
            add(mix,synth(midi(chord[beat%3]+12),.35,"pluck"),at+.25,.055*intensity,(-1)**beat*.45)
    # Trailer hits and risers are synthesized here rather than borrowed from stock music.
    for at in [0,.75,1.5,3,8,15,17,24,26,34,37,40,42,44,47,52,55]:
        tt = np.arange(int(1.1*RATE))/RATE
        hit = np.sin(2*np.pi*(32*tt+55*.08*(1-np.exp(-tt/.08))))*np.exp(-tt*4)
        hit += rng.normal(0,.25,len(tt))*np.exp(-tt*15)
        add(mix,hit,at,.40 if at != 55 else .64)
    for at,length in [(6,2),(13.5,1.5),(22,2),(32,2),(35,2),(50,2),(53,2)]:
        tt = np.arange(int(length*RATE))/RATE
        u = tt/length
        rise = (rng.normal(0,1,len(tt))*.065+np.sin(2*np.pi*(110*tt+190*tt*tt/length))*.045)*u**2
        add(mix,rise,at,.9,-.1)
    data = json.loads((OUT/"capture.json").read_text(encoding="utf-8"))
    cues = {shot:[] for shot in ["horde","rifle","axe","boss","armory","finale"]}
    for record in data["records"]:
        cues[record["shot"]].extend(record["cues"])
    samples = {"rifle":wavefile("weapon-rifle.wav"),"axe":wavefile("weapon-axe.wav"),
               "impact":wavefile("shove-hit.wav"),"disco":wavefile("disco.wav")}
    for start,duration,shot,inpoint in EDIT:
        if not shot: continue
        for event in cues[shot]:
            if inpoint <= event["time"] < inpoint+duration:
                at = start+event["time"]-inpoint
                gain = {"rifle":.72,"axe":.85,"impact":.17,"disco":.38}[event["kind"]]
                add(mix,samples[event["kind"]],at,gain,float(rng.uniform(-.18,.18)))
    # Slow title chord and final decay; short delayed taps widen the score.
    for note in [38,50,53,57]: add(mix,synth(midi(note),4.7,"pad"),55,.09)
    delay = int(.093*RATE)
    mix[delay:,1] += mix[:-delay,0]*.09
    fade = np.ones(len(mix),np.float32)
    fade[-int(.65*RATE):] = np.linspace(1,0,int(.65*RATE))
    mix *= fade[:,None]
    # Smooth compression preserves punch while leaving headroom for AAC true peaks.
    mix = np.tanh(mix*1.8)*.68
    wav = OUT/"soundtrack.wav"
    with wave.open(str(wav),"wb") as result:
        result.setnchannels(2); result.setsampwidth(2); result.setframerate(RATE)
        result.writeframes((mix*32767).astype("<i2").tobytes())
    return wav


def render_video():
    wav = soundtrack()
    target = OUT/"Undead-Survivor-Trailer-60s-1080p.mp4"
    args = [FFMPEG,"-y","-hide_banner","-loglevel","warning","-f","rawvideo","-pixel_format","rgb24",
            "-video_size",f"{WIDTH}x{HEIGHT}","-framerate",str(FPS),"-i","pipe:0","-i",str(wav),
            "-c:v","libx264","-preset","fast","-crf","18","-pix_fmt","yuv420p","-threads","2",
            "-c:a","aac","-b:a","256k","-af","aresample=48000",
            "-ar",str(RATE),"-t",str(DURATION),"-movflags","+faststart",
            "-metadata","title=Undead Survivor — Official Promotional Trailer",
            "-metadata","comment=Native engine footage with staged promotional cameras; original synthesized score.",str(target)]
    with (OUT/"encode.log").open("wb") as log:
        process = subprocess.Popen(args,stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=log,creationflags=NO_WINDOW)
        try:
            for i in range(FPS*DURATION):
                process.stdin.write(frame_at(i).tobytes())
                if i%(FPS*5) == 0: print(f"Edit: {i//FPS}/{DURATION}s",flush=True)
            process.stdin.close()
            if process.wait() != 0: raise RuntimeError((OUT/"encode.log").read_text())
        except BaseException:
            process.stdin.close()
            process.terminate()
            process.wait()
            raise
    print(target,flush=True)


def previews():
    OUT.mkdir(parents=True,exist_ok=True)
    times = [0,.85,1.75,2.65,4.5,7,9,12,16,18,21,25,27,29,31.4,32.5,35,38,41,43,45,49,53,56.5]
    sheet = Image.new("RGB",(4*480,6*300),(10,12,17))
    draw = ImageDraw.Draw(sheet)
    for i,t in enumerate(times):
        image = frame_at(round(t*FPS))
        x,y = i%4*480,i//4*300
        sheet.paste(image.resize((480,270),Image.Resampling.LANCZOS),(x,y))
        draw.text((x+12,y+275),f"{t:05.2f}s",font=font(18,False),fill=IVORY)
    sheet.save(OUT/"contact-sheet.jpg",quality=95)
    frame_at(round(56.5*FPS)).save(OUT/"poster.jpg",quality=97)
    for t in [16,25,31.4,35,53,56.5]: frame_at(round(t*FPS)).save(OUT/f"review-{t}.jpg",quality=97)


def verify():
    target = OUT/"Undead-Survivor-Trailer-60s-1080p.mp4"
    result = subprocess.run([FFMPEG,"-hide_banner","-i",str(target),"-f","null","-"],capture_output=True,text=True,encoding="utf-8",errors="replace",creationflags=NO_WINDOW)
    (OUT/"decode.log").write_text(result.stderr,encoding="utf-8")
    if result.returncode or "1920x1080" not in result.stderr or "24 fps" not in result.stderr or "00:01:00.00" not in result.stderr:
        raise RuntimeError(result.stderr[-4000:])
    audio = subprocess.run([FFMPEG,"-hide_banner","-i",str(target),"-af","ebur128=peak=true","-vn","-f","null","-"],capture_output=True,text=True,encoding="utf-8",errors="replace",creationflags=NO_WINDOW)
    (OUT/"loudness.log").write_text(audio.stderr,encoding="utf-8")
    integrated = re.search(r"Integrated loudness:\s+I:\s+([\d.-]+) LUFS",audio.stderr)
    peak = re.search(r"True peak:\s+Peak:\s+([\d.-]+) dBFS",audio.stderr)
    if audio.returncode or not integrated or not peak: raise RuntimeError("Audio loudness measurement failed")
    loudness, true_peak = float(integrated[1]), float(peak[1])
    if not -19 <= loudness <= -12 or true_peak > -1:
        raise RuntimeError(f"Audio mastering outside delivery range: {loudness} LUFS / {true_peak} dBTP")
    capture = json.loads((OUT/"capture.json").read_text(encoding="utf-8"))
    records = capture["records"]
    assert capture["safety"] == {"pointerLockRequests":0,"fullscreenRequests":0}
    assert not capture["errors"]
    assert len(records) == 40*FPS
    assert max(r["summoned"] for r in records if r["shot"] == "boss") == 26
    for shot in ["rifle","axe","finale"]:
        assert max(r["kills"] for r in records if r["shot"] == shot) > 0
    assert max(r["alive"] for r in records if r["shot"] == "horde") >= 80
    report = {"status":"passed","durationSeconds":60,"size":[1920,1080],"fps":24,
              "nativeSize":[1600,670],"activePicture":[1920,804],"audio":"AAC stereo / 48 kHz / original score + project effects",
              "integratedLoudnessLUFS":loudness,"truePeakDBTP":true_peak,
              "bytes":target.stat().st_size,"sha256":hashlib.sha256(target.read_bytes()).hexdigest(),
              "nativeCaptureFrames":len(records),"bossSummoned":26,
              "combat":{shot:{"kills":max(r["kills"] for r in records if r["shot"] == shot),"shots":max(r["shots"] for r in records if r["shot"] == shot)} for shot in ["rifle","axe","finale"]},
              "visualReview":"See review.md; contact sheet and full-size key frames inspected separately.",
              "boundaries":"Promotional staging and software Web rendering. Does not certify native GPU gameplay, performance or release readiness."}
    (OUT/"video-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps(report,ensure_ascii=False,indent=2),flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview",action="store_true")
    parser.add_argument("--verify",action="store_true")
    args = parser.parse_args()
    if args.verify: verify()
    elif args.preview: previews()
    else: render_video(); previews(); verify()
