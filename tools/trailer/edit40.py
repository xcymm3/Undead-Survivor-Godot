"""40-second native promotional cut: five captions, four-player freeze ending."""
from pathlib import Path
import json, subprocess, hashlib, re, wave
import numpy as np
from PIL import Image, ImageDraw
import edit as base
OUT=base.ROOT/'artifacts/trailer40'
FPS=24
CAPTIONS=[(0.8,2.5,"迎击海量尸潮"),(13.4,15.2,"守住最后防线"),(24.4,26.1,"升级永久保留"),(28.4,30.1,"筑起你的防线"),(32.5,34.3,"并肩迎战")]
EDIT=[(0,6,'rifle'),(6,7,'ultimate'),(13,5,'defense'),(18,6,'boss'),(24,4,'upgrade'),(28,4,'build'),(32,8,'team')]
TARGET=OUT/'Undead-Survivor-Trailer-40s-1080p.mp4'

def frame_at(n):
 t=n/FPS
 start,duration,shot=next(row for row in EDIT if row[0]<=t<row[0]+row[1])
 index=min(round((t-start)*FPS),119) if shot=='team' else round((t-start)*FPS)
 with Image.open(OUT/'frames'/shot/f'{index:05d}.jpg') as raw:
  pic=raw.convert('RGB').resize((1920,804),Image.Resampling.LANCZOS)
 pic=pic.point(base.COLOR_LUT)
 pic=base.ImageChops.multiply(pic,base.VIGNETTE)
 im=Image.new('RGB',(1920,1080))
 im.paste(pic,(0,138))
 for a,b,text in CAPTIONS:
  if a<=t<b:
   k=base.smooth(a,a+.18,t)*(1-base.smooth(b-.2,b,t))
   base.title(im,text,804,65,opacity=k,x=102)
 return im

def soundtrack():
 rate=base.RATE
 mix=np.zeros((40*rate,2),np.float32)
 rng=np.random.default_rng(2310)
 chords=[(50,53,57),(46,50,53),(48,52,55),(45,48,52)]
 for bar in range(20):
  at=bar*2
  for j,note in enumerate(chords[(bar//2)%4]): base.add(mix,base.synth(base.midi(note),2.4,'pad'),at,.07,[-.6,0,.6][j])
 t=np.arange(int(.45*rate))/rate
 kick=np.sin(2*np.pi*(45*t+95*.03*(1-np.exp(-t/.03))))*np.exp(-t*11)
 st=np.arange(int(.22*rate))/rate
 snare=(rng.normal(0,.45,len(st))+.25*np.sin(2*np.pi*180*st))*np.exp(-st*23)
 ht=np.arange(int(.07*rate))/rate
 hat=np.diff(rng.normal(0,1,len(ht)),prepend=0)*np.exp(-ht*70)*.12
 for beat in range(78):
  at=beat*.5
  if 6.6<at<7.6: continue
  strength=.75 if 18<=at<24 else 1.1
  base.add(mix,kick,at,.38*strength)
  if beat%2: base.add(mix,snare,at,.2*strength)
  for off in [0,.25]: base.add(mix,hat,at+off,.3*strength,(-1)**beat*.4)
  note=chords[(int(at//2)//2)%4][0]-24+[0,0,12,0,7,0,10,12][beat%8]
  base.add(mix,base.synth(base.midi(note),.42),at,.20*strength)
 for at in [0,6,7.5,13,18,24,28,32,37]:
  tt=np.arange(rate)/rate
  hit=(np.sin(2*np.pi*(32*tt+55*.08*(1-np.exp(-tt/.08))))+rng.normal(0,.15,len(tt)))*np.exp(-tt*5)
  base.add(mix,hit,at,.45)
 capture=json.loads((OUT/'capture.json').read_text(encoding='utf-8'))
 samples={'rifle':base.wavefile('weapon-rifle.wav'),'blade':base.wavefile('blade-swing.wav'),'disco':base.wavefile('disco.wav'),'explosion':base.wavefile('grenade-explosion.wav'),'ultimate_start':base.wavefile('blade-draw.wav'),'world_upgrade':base.wavefile('reload.wav')}
 for start,duration,shot in EDIT:
  for r in capture['records']:
   if r['shot']!=shot: continue
   for cue in r['cues']:
    if cue['kind'] in samples:
     base.add(mix,samples[cue['kind']],start+cue['time'],.52 if cue['kind']=='rifle' else .42,float(rng.uniform(-.15,.15)))
 delay=int(.093*rate)
 mix[delay:,1]+=mix[:-delay,0]*.08
 mix[-rate:]*=np.linspace(1,0,rate)[:,None]
 mix=np.tanh(mix*1.8)*.64
 with wave.open(str(OUT/'soundtrack.wav'),'wb') as w:
  w.setnchannels(2);w.setsampwidth(2);w.setframerate(rate);w.writeframes((mix*32767).astype('<i2').tobytes())
 return OUT/'soundtrack.wav'

def previews():
 times=[1.5,4,6.8,8.2,10,12,14,17,19,21,22.5,23.6,25,27,29,31,33,35,37.5,39.9]
 sheet=Image.new('RGB',(1920,1500))
 d=ImageDraw.Draw(sheet)
 for i,t in enumerate(times):
  im=frame_at(round(t*24));x=i%4*480;y=i//4*300
  sheet.paste(im.resize((480,270)),(x,y));d.text((x+12,y+275),f'{t:.1f}s',font=base.font(18,False),fill='white')
 sheet.save(OUT/'contact-sheet.jpg',quality=95)
 for t in [8.2,10,22.5,25,29,37.5]: frame_at(round(t*24)).save(OUT/f'review-{t}.jpg',quality=97)
 frame_at(959).save(OUT/'poster.jpg',quality=97)

def verify():
 result=subprocess.run([base.FFMPEG,'-hide_banner','-i',str(TARGET),'-f','null','-'],capture_output=True,text=True,encoding='utf-8',errors='replace',creationflags=base.NO_WINDOW)
 (OUT/'decode.log').write_text(result.stderr,encoding='utf-8')
 assert result.returncode==0 and '00:00:40.00' in result.stderr and '1920x1080' in result.stderr and '24 fps' in result.stderr
 audio=subprocess.run([base.FFMPEG,'-hide_banner','-i',str(TARGET),'-af','ebur128=peak=true','-vn','-f','null','-'],capture_output=True,text=True,creationflags=base.NO_WINDOW)
 (OUT/'loudness.log').write_text(audio.stderr,encoding='utf-8')
 peak=float(re.search(r'True peak:\s+Peak:\s+([\d.-]+)',audio.stderr)[1])
 assert peak<=-1
 assert frame_at(37*24).tobytes()==frame_at(959).tobytes()
 freeze=subprocess.run([base.FFMPEG,'-hide_banner','-i',str(TARGET),'-vf','freezedetect=n=-50dB:d=2','-an','-f','null','-'],capture_output=True,text=True,creationflags=base.NO_WINDOW)
 (OUT/'freeze.log').write_text(freeze.stderr,encoding='utf-8')
 assert freeze.returncode==0 and 'freeze_start' in freeze.stderr
 data=json.loads((OUT/'capture.json').read_text(encoding='utf-8'))
 assert not data['errors'] and not any(data['safety'].values())
 assert len(data['records'])==37*FPS
 for _,seconds,shot in EDIT:
  expected=120 if shot=='team' else seconds*FPS
  assert len([r for r in data['records'] if r['shot']==shot])==expected
 assert max(r['kills'] for r in data['records'] if r['shot']=='ultimate')>0
 assert max(r['summoned'] for r in data['records'] if r['shot']=='boss')>0
 assert max(r['team'] for r in data['records'])==4
 assert max(r['ultimate'] for r in data['records'])>0
 assert max(r['level'] for r in data['records'] if r['shot']=='upgrade')>0
 report={'status':'passed','duration':40,'size':[1920,1080],'fps':24,'captions':[x[2] for x in CAPTIONS],'freeze':[37,40],'finalPlayers':4,'nativeFrames':len(data['records']),'truePeakDBTP':peak,'source':json.loads((OUT/'source.json').read_text()),'bytes':TARGET.stat().st_size,'sha256':hashlib.sha256(TARGET.read_bytes()).hexdigest()}
 (OUT/'video-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(report,ensure_ascii=False,indent=2),flush=True)

def render():
 wav=soundtrack()
 args=[base.FFMPEG,'-y','-hide_banner','-loglevel','warning','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','24','-i','pipe:0','-i',str(wav),'-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-threads','2','-c:a','aac','-b:a','256k','-ar','48000','-t','40','-movflags','+faststart',str(TARGET)]
 with (OUT/'encode.log').open('wb') as log:
  p=subprocess.Popen(args,stdin=subprocess.PIPE,stderr=log,creationflags=base.NO_WINDOW)
  try:
   for n in range(960):
    p.stdin.write(frame_at(n).tobytes())
    if n%120==0: print(f'Edit {n/24}/40s',flush=True)
   p.stdin.close()
   assert p.wait()==0
  finally:
   if p.poll() is None:p.terminate();p.wait()
 previews();verify()

if __name__=='__main__':
 import sys
 if '--preview' in sys.argv: previews()
 elif '--verify' in sys.argv:verify()
 else:render()
