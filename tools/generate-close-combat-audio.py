"""Generate original procedural close-combat cues; no external recordings."""
import math, random, struct, wave
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/audio'
rate=22050
for index,(name,duration) in enumerate([('shove',.24),('shove-hit',.3),('enemy-windup',.36),('enemy-impact',.22),('enemy-miss',.25),('enemy-step-0',.18),('enemy-step-1',.21),('rear-warning',.3)]):
 rng=random.Random(810+index); samples=[]; low=0.0; phase=0.0
 for i in range(int(rate*duration)):
  t=i/rate; u=t/duration; noise=rng.uniform(-1,1); low=.82*low+.18*noise
  envelope=math.sin(math.pi*u)**.7
  if name.startswith('enemy-step'):
   value=(.7*low+.45*math.sin(2*math.pi*65*t))*math.exp(-u*12)*min(1,t*600)
  elif name=='rear-warning':
   value=(math.sin(2*math.pi*(540*t-420*t*t))*.35+low*.25)*envelope
  elif name=='enemy-windup':
   phase+=2*math.pi*(105-45*u+8*math.sin(t*40))/rate
   value=(.34*math.sin(phase)+.16*math.sin(phase*2)+.45*low)*envelope*(.55+.45*math.sin(t*75)**2)
  elif name in ['enemy-impact','shove-hit']:
   value=(.65*math.sin(2*math.pi*(92*t-90*t*t))+.55*low)*math.exp(-u*7)*min(1,t*500)
  else: value=(noise*.15+low*1.5)*envelope*(.7 if name=='enemy-miss' else 1)
  samples.append(max(-.95,min(.95,value)))
 if name in ['shove','shove-hit'] or name.startswith('enemy-step'):
  peak=max(abs(x) for x in samples);samples=[x*.85/peak for x in samples]
 with wave.open(str(out/(name+'.wav')),'wb') as f:
  f.setparams((1,2,rate,0,'NONE','not compressed')); f.writeframes(b''.join(struct.pack('<h',round(x*32767)) for x in samples))
 print(name, 'peak', round(max(abs(x) for x in samples),3))
