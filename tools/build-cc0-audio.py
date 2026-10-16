"""Edit existing CC0 recordings; never synthesizes oscillators or noise.

Build: Python + numpy/scipy. Sources are committed PCM excerpts with provenance.
Check: standard-library only, suitable for the offline CI acceptance gate.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
INPUTS = ROOT / "tools/audio-sources"
OUTPUT = ROOT / "assets/audio"
MANIFEST = ROOT / "assets/data/audio.json"
RATE = 44100


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    sources = json.loads((INPUTS / "index.json").read_text(encoding="utf-8"))
    assert manifest["license"] == sources["license"] == "CC0-1.0"
    assert manifest["builder_sha256"] == sha(Path(__file__))
    assert manifest["sources_index_sha256"] == sha(INPUTS / "index.json")
    for key, source in sources["sources"].items():
        assert sha(ROOT / source["path"]) == source["sha256"], key
        assert sources["packs"][source["pack"]]["license"] == "CC0-1.0"
    for name, digest in manifest["motion_sources"].items():
        assert sha(ROOT / name) == digest, "Animation changed; review audio landmarks: "+name
    hashes = set()
    for name, cue in manifest["cues"].items():
        path = OUTPUT / (name+".wav")
        assert sha(path) == cue["sha256"], name
        assert cue["sources"] and all(key in sources["sources"] for key in cue["sources"])
        with wave.open(str(path)) as audio:
            assert audio.getsampwidth() == 2 and audio.getframerate() == RATE
            channels, frames = audio.getnchannels(), audio.getnframes()
            samples = struct.unpack("<%dh" % (frames*channels), audio.readframes(frames))
        peak = max(abs(x) for x in samples)/32768
        rms = math.sqrt(sum((x/32768)**2 for x in samples)/len(samples))
        assert .01 < peak < .90 and rms > .001, (name, peak, rms)
        assert max(abs(x) for x in samples[:channels]+samples[-channels:]) <= 2, name
        assert abs(frames/RATE-cue["seconds"]) < .00005, name
        assert abs(sum(samples)/len(samples)/32768) < .012, name
        assert cue["sha256"] not in hashes, name
        hashes.add(cue["sha256"])
    rules = json.loads((ROOT / "assets/data/rules.json").read_text(encoding="utf-8"))
    for weapon in rules["weapons"]:
        assert "weapon-"+weapon["id"] in manifest["cues"]
        if weapon["id"] == "axe": continue
        cue = manifest["cues"]["reload-"+weapon["id"]]
        assert abs(cue["seconds"]-weapon["reloadDuration"]) < .00005
        assert all(0 <= event["phase"] <= 1 and event["seconds"] < cue["seconds"] for event in cue["events"])
    print("CC0 AUDIO: %d cues; %d source excerpts; provenance, hashes and PCM checks passed" % (len(manifest["cues"]),len(sources["sources"])))


def build():
    import numpy as np
    from scipy.signal import resample_poly, butter, sosfilt
    cache = {}
    cues = {}
    source_index = json.loads((INPUTS / "index.json").read_text(encoding="utf-8"))
    def read(key):
        if key not in cache:
            with wave.open(str(INPUTS / (key+".wav"))) as w:
                cache[key] = np.frombuffer(w.readframes(w.getnframes()),dtype="<i2").reshape(-1,w.getnchannels()).astype(float)/32768
        return cache[key].copy()
    def part(key, start=0.0, end=None, speed=1.0, duration=None, lowpass=None, anchor_peak=False, trim_leading=False):
        x = read(key)
        x = x[round(start*RATE):round(end*RATE) if end is not None else None]
        if anchor_peak:
            first = max(0,int(np.abs(x).max(axis=1).argmax())-round(.002*RATE))
            x = x[first:]
        elif trim_leading:
            envelope = np.abs(x).max(axis=1)
            first = max(0,int(np.where(envelope > envelope.max()*.12)[0][0])-round(.002*RATE))
            x = x[first:]
        if duration is not None: speed = len(x)/RATE/duration
        if speed != 1:
            # Recorded material is resampled, never regenerated.
            ratio = round(1000/speed)
            x = resample_poly(x,ratio,1000,axis=0)
        x -= x.mean(axis=0)
        x = sosfilt(butter(2,35,fs=RATE,btype="highpass",output="sos"),x,axis=0)
        if lowpass: x = sosfilt(butter(2,lowpass,fs=RATE,output="sos"),x,axis=0)
        fade = min(round(.002*RATE),len(x)//3)
        x[:fade] *= np.linspace(0,1,fade)[:,None]
        tail = min(round(.012*RATE),len(x)//3)
        x[-tail:] *= np.linspace(1,0,tail)[:,None]
        peak = np.abs(x).max()
        return x/max(peak,.0001)
    def emit(name, duration, layers, reason, events=None, stereo=False, peak=.80):
        channels = 2 if stereo else 1
        mix = np.zeros((round(duration*RATE),channels))
        records = []
        used = []
        for key, at, gain, options in layers:
            x = part(key,**options)
            if x.shape[1] != channels:
                x = x.mean(axis=1,keepdims=True) if channels == 1 else np.repeat(x,2,axis=1)
            offset = round(at*RATE)
            count = min(len(x),len(mix)-offset)
            if count <= 0: continue
            mix[offset:offset+count] += x[:count]*gain
            records.append({"source":key,"at":at,"gain":gain,"edit":options})
            used.append(key)
        mix -= mix.mean(axis=0)
        mix *= peak/max(float(np.abs(mix).max()),.0001)
        head = min(round(.001*RATE),len(mix)//3)
        tail = min(round((.35 if stereo else .012)*RATE),len(mix)//3)
        mix[:head] *= np.linspace(0,1,head)[:,None]
        mix[-tail:] *= np.linspace(1,0,tail)[:,None]
        pcm = np.round(mix*32767).astype("<i2")
        path = OUTPUT/(name+".wav")
        with wave.open(str(path),"wb") as w:
            w.setparams((channels,2,RATE,0,"NONE","not compressed"))
            w.writeframes(pcm.tobytes())
        cues[name] = {"seconds":len(pcm)/RATE,"channels":channels,"sha256":sha(path),"sources":list(dict.fromkeys(used)),"edits":records,"reason":reason}
        if events is not None: cues[name]["events"] = events
    def one(name,key,seconds,reason,**options):
        emit(name,seconds,[(key,0,1,options)],reason)
    for i in range(6):
        key = "zombie-"+str(i)
        one("death-"+str(i),key,min(1.8,len(read(key))/RATE+.025),"同一CC0僵尸声包的六个独立短声，减少密集击杀时重复")
    gun_edits = {"rifle":(.40,1.0,None),"p90":(.23,1.05,None),"pistol":(.36,1.0,None),"revolver":(.54,1.0,None),"shotgun":(.67,1.0,None),"sniper":(.70,1.0,None),"auto-shotgun":(.43,1.0,None),"heavy-machine-gun":(.48,.84,5500)}
    for weapon,(duration,speed,lowpass) in gun_edits.items():
        one("weapon-"+weapon,"gun-"+weapon,duration,"实录枪声的首个独立枪响，去前导静音、缩短尾声并保留峰值余量；非对应型号者为明确记录的替代拟音",speed=speed,lowpass=lowpass,end=duration*speed)
    emit("weapon-axe",.56,[("cloth1",.015,.20,{"end":.18}),("swish-7",.193,1,{"speed":.85})],"厚重破风主瞬态对齐0.46阶段的过中线劈砍；衣物声对应起手，命中撞击独立",events=[{"phase":.22,"seconds":.1232,"action":"cut_start"},{"phase":.46,"seconds":.2576,"action":"cut_centre"},{"phase":.66,"seconds":.3696,"action":"cut_end"}])
    one("weapon-flamethrower","flame",.18,"已有CC0燃烧素材截取为短连续喷射片段，渐入渐出控制叠加",start=.08,end=.26)
    emit("blade-draw",1.1,[("cloth1",.025,.15,{"end":.13}),("seax-unsheathe-01",.176,1,{"duration":.638})],"出鞘录音放在拔刀阶段16%至74%的实际抽刀区间")
    emit("blade-sheathe",.95,[("seax-sheathe-01",.361,1,{"duration":.427}),("metalLatch",.789,.22,{"end":.10})],"入鞘录音放在收刀阶段38%至83%，末端短卡扣对应到位")
    for i,key in enumerate(["swish-5","swish-6","swish-8"]):
        emit("blade-swing"+("-"+str(i) if i else ""),.28,[(key,.08,1,{"duration":.16})],"独立挥刀破风，主瞬态位于挥砍有效段；三变体不混入拔刀声")
    for material in ["concrete","wood","grass"]:
        for i in range(3):
            name = "enemy-step-"+str(i) if material == "concrete" else "enemy-step-"+material+"-"+str(i)
            one(name,"step-"+material+"-"+str(i),.20 if material == "concrete" else .30 if material == "wood" else .38,"按桥面木板、坡道石面和场地草地选择对应材质的脚步录音",end=.19 if material == "concrete" else .29 if material == "wood" else .37)
    one("shove","swish-1",.24,"短轻破风，与实际推搡命中声分离",duration=.18)
    emit("shove-hit",.34,[("impactPunch_heavy_000",0,1,{"end":.28}),("cloth2",.025,.17,{"end":.25})],"拳击低频撞击与衣物摩擦，用于身体推搡接触")
    one("enemy-windup","zombie-3",.36,"僵尸短声作为攻击前摇",end=.34)
    one("enemy-miss","swish-10",.25,"攻击挥空仅播放短破风",duration=.20)
    one("enemy-impact","impactPunch_medium_001",.30,"真实接触撞击，用于近战与建筑受击",end=.29)
    one("hurt","impactSoft_heavy_000",.36,"低沉软质受击，避免与铁皮、盾牌撞击混淆",end=.35)
    one("cone-false","plastic-snap",.22,"路障采用塑料卡扣的短促卡裂，区别于金属共鸣",start=.50,end=.63)
    emit("cone-true",.46,[("plastic-snap",0,1,{"start":.64,"end":.89}),("plastic-snap",.16,.55,{"start":.50,"end":.63}),("impactGeneric_light_000",.27,.35,{})],"路障破坏叠加第二次塑料裂响和轻质散落")
    one("bucket-false","impactTin_medium_000",.25,"铁桶采用薄铁皮空腔撞击，保留轻薄共鸣")
    emit("bucket-true",.55,[("impactTin_medium_002",0,1,{}),("impactTin_medium_000",.10,.6,{"speed":.87}),("impactMetal_light_000",.20,.35,{"end":.32})],"铁桶破坏含薄铁皮变形和金属落地尾声")
    one("shield-false","impactMetal_heavy_000",.28,"盾牌使用厚金属低沉重击，与铁桶空腔声分开")
    emit("shield-true",.64,[("impactMetal_heavy_002",0,1,{}),("impactPlate_heavy_002",.07,.7,{}),("impactPlate_light_000",.23,.3,{"end":.38})],"盾牌破坏使用厚板冲击和较重散落")
    emit("football-false",.24,[("impactSoft_medium_000",0,1,{}),("quiver-leather-squeeze-01",.025,.18,{"end":.18})],"橄榄球护具与巨人皮盔使用软垫撞击和皮革挤压，避免金属铃响")
    emit("football-true",.60,[("impactSoft_heavy_000",0,1,{"end":.42}),("quiver-leather-squeeze-06",.06,.35,{"end":.42}),("belt-buckle-01",.34,.25,{})],"软质护具破坏表现束带松脱与落地，区别于塑料和金属破裂")
    # Phase landmarks were read from the existing imported reload tracks and
    # procedural AK/revolver poses; no extra firing or switch animation is added.
    timelines = {
      "rifle":[(.12,"magazine_out","reload-rifle",0,.36),(.88,"magazine_in","reload-rifle",.50,.98)],
      "p90":[(.15,"magazine_release","reload-pistol-airsoft",0,.30),(.67,"magazine_seat","reload-pistol-airsoft",.55,.96)],
      "pistol":[(.17,"magazine_out","reload-pistol",0,.42),(.78,"magazine_in","reload-pistol",.55,.96)],
      "revolver":[(.13,"cylinder_open","metalLatch",0,.16),(.31,"case_eject","metalClick",0,.16),(.67,"speedloader_seat","reload-pistol",.55,.86),(.83,"cylinder_close","metalLatch",.03,.23)],
      "shotgun":[(.22,"shell_handling","cloth1",0,.10),(.64,"shell_seat","metalClick",.05,.18)],
      "sniper":[(.12,"bolt_open","pump",0,.18),(.28,"magazine_out","reload-rifle",0,.32),(.70,"magazine_in","reload-rifle",.55,.91),(.87,"bolt_close","pump",.24,.46)],
      "flamethrower":[(.06,"tank_release","metalLatch",0,.18),(.50,"tank_handling","clothBelt",0,.26),(.94,"tank_clamp","metalLatch",.04,.23)],
      "auto-shotgun":[(.08,"drum_out","reload-rifle",0,.36),(.94,"drum_seat","reload-rifle",.55,.93)],
      "heavy-machine-gun":[(.06,"box_release","metalLatch",0,.18),(.45,"box_handling","clothBelt",0,.30),(.74,"charging_handle_pull","pump",0,.19),(.94,"box_seat","reload-rifle",.55,.93),(.98,"charging_handle_return","pump",.24,.46)]}
    rules = json.loads((ROOT/"assets/data/rules.json").read_text(encoding="utf-8"))
    for w in rules["weapons"]:
        if w["id"] not in timelines: continue
        duration = w["reloadDuration"]
        layers, events = [], []
        for phase,action,key,start,end in timelines[w["id"]]:
            at = phase*duration
            # A cue must finish within its actual animation, including .4s shells.
            contact = not action.endswith("handling")
            layers.append((key,at,1,{"start":start,"end":end,"anchor_peak":contact,"trim_leading":not contact}))
            events.append({"phase":phase,"seconds":at,"action":action,"source":key,"anchor":"peak" if contact else "onset"})
        emit("reload-"+w["id"],duration,layers,"按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止",events)
    emit("ultimate-music",10.0,[("ultimate-music",0,1,{})],"nene原创Rock/Metal短曲中选取38–48秒的高能量段，技能结束前淡出",stereo=True,peak=.70)
    manifest = {"version":1,"license":"CC0-1.0","license_url":source_index["license_url"],"builder_sha256":sha(Path(__file__)),"sources_index_sha256":sha(INPUTS/"index.json"),"death_variants":6,"step_variants":3,"cues":cues}
    motions = ["scripts/ak_rifle.gd","scripts/revolver_model.gd","scripts/blade_motion.gd","scripts/ultimate.gd","scripts/axe_motion.gd"]
    motions += ["assets/models/"+w["id"]+".glb" for w in rules["weapons"] if w["id"] not in ["rifle","revolver","axe"]]
    manifest["motion_sources"] = {name:sha(ROOT/name) for name in motions}
    MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    check()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check",action="store_true")
    args = parser.parse_args()
    check() if args.check else build()
